"""Pack separately generated four-frame direction strips into active Godot assets.

Unlike the older packer, every direction uses one shared union crop. This keeps
the pelvis/torso anchor fixed across its four frames instead of recentering each
silhouette around changing hair, cape, robe, or weapon pixels.
"""
from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

from pack_walk4_sheets import write_sprite_frames
from pack_walk_sheets import remove_matte_specks

ROOT = Path(__file__).resolve().parents[1]
CELL, COLS, ROWS, BASELINE = 128, 4, 4, 120
DIRECTIONS = ("down", "left", "right", "up")
ROLES = (
    ("zs", "pojun"),
    ("ck", "chuanyang"),
    ("fs", "shuangyu"),
    ("fz", "chenxing"),
)


def remove_border_background(image: Image.Image) -> Image.Image:
    """Flood-remove baked neutral checkerboard or near-black border background."""
    rgba = image.convert("RGBA")
    if rgba.getchannel("A").getextrema()[0] < 255:
        return rgba
    pixels = rgba.load()
    width, height = rgba.size
    seen = bytearray(width * height)
    pending: deque[tuple[int, int]] = deque()

    def background(x: int, y: int) -> bool:
        r, g, b, _ = pixels[x, y]
        neutral_light = min(r, g, b) >= 96 and max(r, g, b) - min(r, g, b) <= 18
        near_black = max(r, g, b) <= 45 and max(r, g, b) - min(r, g, b) <= 20
        return neutral_light or near_black

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if seen[index] or not background(x, y):
            return
        seen[index] = 1
        pending.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)
    while pending:
        x, y = pending.popleft()
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        if x:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)
    return rgba


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(lambda value: 255 if value >= 32 else 0).getbbox()
    if bbox is None:
        raise ValueError("empty sprite frame")
    return bbox


def union_box(boxes: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int]:
    return (min(box[0] for box in boxes), min(box[1] for box in boxes),
            max(box[2] for box in boxes), max(box[3] for box in boxes))


def mask_iou(first: Image.Image, second: Image.Image) -> float:
    a = first.getchannel("A").crop((0, 88, CELL, CELL)).point(lambda v: 1 if v >= 32 else 0)
    b = second.getchannel("A").crop((0, 88, CELL, CELL)).point(lambda v: 1 if v >= 32 else 0)
    av, bv = list(a.get_flattened_data()), list(b.get_flattened_data())
    intersection = sum(1 for x, y in zip(av, bv) if x and y)
    union = sum(1 for x, y in zip(av, bv) if x or y)
    return intersection / union if union else 1.0


def contact_sheet(sheet: Image.Image, path: Path) -> None:
    canvas = Image.new("RGB", (COLS * 256, ROWS * 280), (26, 29, 36))
    draw = ImageDraw.Draw(canvas)
    for row, direction in enumerate(DIRECTIONS):
        for col in range(COLS):
            frame = sheet.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
            frame = frame.resize((256, 256), Image.Resampling.NEAREST)
            canvas.paste(frame, (col * 256, row * 280), frame)
            draw.text((col * 256 + 8, row * 280 + 259), f"{direction} frame {col}", fill="white")
    canvas.save(path)


def main() -> None:
    qa_dir = ROOT / "image" / "role" / "walk_4dir_review" / "qa_v5"
    qa_dir.mkdir(parents=True, exist_ok=True)
    report = {"method": "separate direction strips with shared union anchor",
              "cell": CELL, "columns": COLS, "rows": ROWS,
              "directions": DIRECTIONS, "fps": 8.0, "roles": []}
    packed_roles: list[list[Image.Image]] = []

    for role_id, name in ROLES:
        direction_data = []
        max_width = max_height = 0
        for direction in DIRECTIONS:
            source = ROOT / "image" / "role" / role_id / "source" / f"{name}_walk_{direction}_strip_v5.png"
            cleaned = remove_border_background(Image.open(source))
            clean_path = source.with_name(source.stem + "_alpha.png")
            cleaned.save(clean_path)
            frames = []
            boxes = []
            for col in range(COLS):
                x0 = round(col * cleaned.width / COLS)
                x1 = round((col + 1) * cleaned.width / COLS)
                frame, _ = remove_matte_specks(cleaned.crop((x0, 0, x1, cleaned.height)))
                frames.append(frame)
                boxes.append(alpha_bbox(frame))
            shared = union_box(boxes)
            cropped = [frame.crop(shared) for frame in frames]
            max_width = max(max_width, shared[2] - shared[0])
            max_height = max(max_height, shared[3] - shared[1])
            direction_data.append({"direction": direction, "source": source,
                                   "source_size": cleaned.size, "shared_crop": shared,
                                   "frames": cropped, "source_frame_boxes": boxes})

        scale = min(116 / max_width, 112 / max_height)
        sheet = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
        packed: list[Image.Image] = []
        role_report = {"id": role_id, "name": name, "common_scale": scale, "directions": []}
        for row, item in enumerate(direction_data):
            shared = item["shared_crop"]
            shared_width = max(1, round((shared[2] - shared[0]) * scale))
            shared_height = max(1, round((shared[3] - shared[1]) * scale))
            x_anchor = (CELL - shared_width) // 2
            y_anchor = BASELINE - shared_height
            row_frames = []
            frame_report = []
            for col, frame in enumerate(item["frames"]):
                resized = frame.resize((shared_width, shared_height), Image.Resampling.NEAREST)
                cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
                cell.alpha_composite(resized, (x_anchor, y_anchor))
                bbox = alpha_bbox(cell)
                if min(bbox[0], bbox[1], CELL - bbox[2], CELL - bbox[3]) < 4:
                    raise ValueError(f"{role_id} {item['direction']} frame {col}: insufficient margin {bbox}")
                ground_band = cell.getchannel("A").crop((0, BASELINE - 8, CELL, BASELINE + 1))
                if not ground_band.getbbox():
                    raise ValueError(f"{role_id} {item['direction']} frame {col}: no support foot near ground")
                sheet.alpha_composite(cell, (col * CELL, row * CELL))
                row_frames.append(cell)
                packed.append(cell)
                frame_report.append({"frame": col, "source_bbox": item["source_frame_boxes"][col],
                                     "packed_bbox": bbox,
                                     "sha256": hashlib.sha256(cell.tobytes()).hexdigest()})
            iou_02 = mask_iou(row_frames[0], row_frames[2])
            iou_13 = mask_iou(row_frames[1], row_frames[3])
            if iou_02 >= 0.97 or iou_13 >= 0.97:
                raise ValueError(f"{role_id} {item['direction']}: opposing gait keys too similar ({iou_02:.3f}, {iou_13:.3f})")
            role_report["directions"].append({
                "direction": item["direction"],
                "source": str(item["source"].relative_to(ROOT)).replace("\\", "/"),
                "source_size": item["source_size"], "shared_crop": shared,
                "anchor": [x_anchor, y_anchor], "foot_iou_0_2": round(iou_02, 4),
                "foot_iou_1_3": round(iou_13, 4), "frames": frame_report,
            })

        output = ROOT / "image" / "role" / role_id / f"{name}_walk_4dir.png"
        sheet.save(output)
        write_sprite_frames(output.with_name(f"{name}_walk_frames.tres"),
                            f"res://image/role/{role_id}/{output.name}")
        contact_sheet(sheet, qa_dir / f"{name}_frames.png")
        role_report["output"] = str(output.relative_to(ROOT)).replace("\\", "/")
        report["roles"].append(role_report)
        packed_roles.append(packed)
        print(f"{role_id}: {output.name}, 16 anchored frames")

    (qa_dir / "technical_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    large_gif, actual_gif = [], []
    for frame_index in range(COLS):
        large = Image.new("RGB", (640, 640), (28, 31, 39))
        actual = Image.new("RGB", (384, 384), (28, 31, 39))
        draw_large, draw_actual = ImageDraw.Draw(large), ImageDraw.Draw(actual)
        for role_index, (_, name) in enumerate(ROLES):
            for row, direction in enumerate(DIRECTIONS):
                frame = packed_roles[role_index][row * COLS + frame_index]
                large.paste(frame, (role_index * 160 + 16, row * 160 + 8), frame)
                draw_large.text((role_index * 160 + 8, row * 160 + 140), f"{name} {direction}", fill="white")
                small = frame.resize((64, 64), Image.Resampling.NEAREST)
                actual.paste(small, (role_index * 96 + 16, row * 96 + 8), small)
                draw_actual.text((role_index * 96 + 4, row * 96 + 75), f"{name[:4]} {direction[0]}", fill="white")
        large_gif.append(large)
        actual_gif.append(actual)
    large_gif[0].save(qa_dir / "walk_cycles_v5.gif", save_all=True, append_images=large_gif[1:],
                      duration=125, loop=0, disposal=2)
    actual_gif[0].save(qa_dir / "walk_cycles_v5_actual64.gif", save_all=True,
                       append_images=actual_gif[1:], duration=125, loop=0, disposal=2)
    print("WALK_STRIPS_V5_OK: 64 grounded, anchored frames packed")


if __name__ == "__main__":
    main()
