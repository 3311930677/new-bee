"""Build a six-slot Godot walk atlas from anchored pixel-art directional poses."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

from pack_walk_strips_v5 import ROOT, alpha_bbox, union_box, mask_iou

CELL, COLS, ROWS, BASELINE, FPS = 128, 6, 4, 120, 12.0
DIRECTIONS = ("down", "left", "right", "up")
ROLES = (("zs", "pojun"), ("ck", "chuanyang"), ("fs", "shuangyu"), ("fz", "chenxing"))
FRONT_BOOT_BANDS = {"zs": (34, 81), "ck": (47, 79), "fs": (47, 79), "fz": (46, 80)}


def transfer_weight(frame: Image.Image, dy: int, split_y: int = 96) -> Image.Image:
    """Make a distinct 1px weight-transfer pose without moving the planted feet."""
    out = frame.copy()
    if dy < 0:
        out.paste((0, 0, 0, 0), (0, 0, CELL, split_y))
        out.alpha_composite(frame.crop((0, 1, CELL, split_y + 1)), (0, 0))
    else:
        out.paste((0, 0, 0, 0), (0, 0, CELL, split_y + 1))
        out.alpha_composite(frame.crop((0, 0, CELL, split_y)), (0, 1))
    return out


def pack_front_back_keyposes(role_id: str, name: str, direction: str) -> list[Image.Image]:
    source_path = ROOT / "image" / "role" / role_id / "source" / f"{name}_walk_{direction}_strip_v5_alpha.png"
    source = Image.open(source_path).convert("RGBA")
    frames, boxes = [], []
    for col in range(4):
        x0, x1 = round(col * source.width / 4), round((col + 1) * source.width / 4)
        frame = source.crop((x0, 0, x1, source.height))
        frames.append(frame)
        boxes.append(alpha_bbox(frame))
    shared = union_box(boxes)
    width, height = shared[2] - shared[0], shared[3] - shared[1]
    scale = min(116 / width, 112 / height)
    scaled_size = (max(1, round(width * scale)), max(1, round(height * scale)))
    origin = ((CELL - scaled_size[0]) // 2, BASELINE - scaled_size[1])
    packed = []
    for frame in frames:
        sprite = frame.crop(shared).resize(scaled_size, Image.Resampling.NEAREST)
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        cell.alpha_composite(sprite, origin)
        cell = spread_front_boots(cell, role_id)
        if not cell.getchannel("A").crop((0, BASELINE - 8, CELL, BASELINE + 1)).getbbox():
            raise ValueError(f"{role_id}/{direction}: no grounded front/back boot")
        packed.append(cell)
    if len({hashlib.sha256(frame.tobytes()).hexdigest() for frame in packed}) != 4:
        raise ValueError(f"{role_id}/{direction}: expected four unique authored gait poses")
    if mask_iou(packed[0], packed[2]) >= 0.97 or mask_iou(packed[1], packed[3]) >= 0.97:
        raise ValueError(f"{role_id}/{direction}: opposing gait poses are too similar")
    return packed


def spread_front_boots(frame: Image.Image, role_id: str, factor: float = 1.22,
                       y0: int = 105, y1: int = BASELINE) -> Image.Image:
    """Widen the lower front/back stance so both boots read at 64px."""
    x0, x1 = FRONT_BOOT_BANDS[role_id]
    expanded_width = round((x1 - x0) * factor)
    expanded_x = (CELL - expanded_width) // 2
    out = frame.copy()
    for y in range(y0, y1):
        strip = frame.crop((x0, y, x1, y + 1)).resize(
            (expanded_width, 1), Image.Resampling.NEAREST)
        out.paste((0, 0, 0, 0), (x0, y, x1, y + 1))
        out.paste(strip, (expanded_x, y))
    return out


def pack_side_row(role_id: str, name: str, row: int) -> list[Image.Image]:
    source_path = ROOT / "image" / "role" / role_id / "source" / f"{name}_walk_v13.png"
    source = Image.open(source_path).convert("RGBA")
    packed = []
    for col in range(COLS):
        frame = source.crop((col * 256, row * 256, (col + 1) * 256, (row + 1) * 256))
        for y in range(256):
            for x in range(256):
                rgba = frame.getpixel((x, y))
                frame.putpixel((x, y), (rgba[0], rgba[1], rgba[2], 255 if rgba[3] >= 128 else 0))
        reduced = frame.resize((CELL, CELL), Image.Resampling.NEAREST)
        ground_y = next((y for y in range(CELL - 1, 79, -1)
                         if any(reduced.getpixel((x, y))[3] for x in range(CELL))), 0)
        if not ground_y:
            raise ValueError(f"{role_id}/{DIRECTIONS[row]}/{col}: side frame has no boot")
        offset_y = BASELINE - ground_y
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        src_y, dst_y = max(0, -offset_y), max(0, offset_y)
        height = min(CELL - src_y, CELL - dst_y)
        cell.alpha_composite(reduced.crop((0, src_y, CELL, src_y + height)), (0, dst_y))
        if not cell.getchannel("A").crop((0, BASELINE - 8, CELL, BASELINE + 1)).getbbox():
            raise ValueError(f"{role_id}/{DIRECTIONS[row]}/{col}: side boot is not grounded")
        packed.append(cell)
    unique = len({hashlib.sha256(frame.tobytes()).hexdigest() for frame in packed})
    if unique != COLS:
        raise ValueError(f"{role_id}/{DIRECTIONS[row]}: expected six distinct side poses, found {unique}")
    return packed


def sprite_frames_text(texture: str) -> str:
    lines = ['[gd_resource type="SpriteFrames" load_steps=26 format=3]', "",
             f'[ext_resource type="Texture2D" path="{texture}" id="1"]', ""]
    for row in range(ROWS):
        for col in range(COLS):
            index = row * COLS + col
            lines.extend([f'[sub_resource type="AtlasTexture" id="Atlas_{index}"]',
                          'atlas = ExtResource("1")',
                          f'region = Rect2({col * CELL}, {row * CELL}, {CELL}, {CELL})',
                          "filter_clip = true", ""])
    lines.extend(["[resource]", "animations = ["])
    for row, direction in enumerate(DIRECTIONS):
        frame_list = ", ".join(
            '{"duration": 1.0, "texture": SubResource("Atlas_%d")}' % (row * COLS + col)
            for col in range(COLS)
        )
        lines.extend(["{", f'"frames": [{frame_list}],', '"loop": true,',
                      f'"name": &"walk_{direction}",', f'"speed": {FPS}',
                      "}," if row < ROWS - 1 else "}"])
    lines.append("]")
    return "\n".join(lines) + "\n"


def contact_sheet(sheet: Image.Image, path: Path) -> None:
    canvas = Image.new("RGB", (COLS * 256, ROWS * 280), (26, 29, 36))
    draw = ImageDraw.Draw(canvas)
    for row, direction in enumerate(DIRECTIONS):
        for col in range(COLS):
            frame = sheet.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
            scaled = frame.resize((256, 256), Image.Resampling.NEAREST)
            canvas.paste(scaled, (col * 256, row * 280), scaled)
            draw.text((col * 256 + 8, row * 280 + 259), f"{direction} frame {col}", fill="white")
    canvas.save(path)


def main() -> None:
    qa_dir = ROOT / "image" / "role" / "walk_4dir_review" / "qa_v14"
    qa_dir.mkdir(parents=True, exist_ok=True)
    pending = []
    report = {"cell": CELL, "columns": COLS, "rows": ROWS, "fps": FPS,
              "directions": DIRECTIONS,
              "front_back_phases": ["left_contact", "left_weight_transfer", "passing_right",
                                    "right_contact", "right_weight_transfer", "passing_left"],
              "roles": []}

    # Validate all roles before touching any active game assets.
    for role_id, name in ROLES:
        rows = [None, pack_side_row(role_id, name, 1), pack_side_row(role_id, name, 2), None]
        down = pack_front_back_keyposes(role_id, name, "down")
        up = pack_front_back_keyposes(role_id, name, "up")
        rows[0] = [down[0].copy(), transfer_weight(down[0], -1), down[1].copy(),
                   down[2].copy(), transfer_weight(down[2], 1), down[3].copy()]
        rows[3] = [up[0].copy(), transfer_weight(up[0], -1), up[1].copy(),
                   up[2].copy(), transfer_weight(up[2], 1), up[3].copy()]
        for row in (0, 3):
            unique = len({hashlib.sha256(frame.tobytes()).hexdigest() for frame in rows[row]})
            if unique != COLS:
                raise ValueError(f"{role_id}/{DIRECTIONS[row]}: six phases must be visually distinct")
        atlas = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
        for row in range(ROWS):
            for col in range(COLS):
                atlas.alpha_composite(rows[row][col], (col * CELL, row * CELL))
        atlas_path = ROOT / "image" / "role" / role_id / f"{name}_walk_4dir.png"
        role_report = {"id": role_id, "name": name, "atlas": atlas_path.relative_to(ROOT).as_posix(),
                       "side_source": f"image/role/{role_id}/source/{name}_walk_v13.png",
                       "front_back_source": "four authored v5 gait poses with widened lower-body spacing and planted-contact holds"}
        pending.append((atlas_path, atlas, role_report))
        report["roles"].append(role_report)
        contact_sheet(atlas, qa_dir / f"{name}_contact_6x4.png")

    for atlas_path, atlas, _ in pending:
        atlas.save(atlas_path)
        atlas_path.with_name(atlas_path.stem.replace("_4dir", "_frames") + ".tres").write_text(
            sprite_frames_text(f"res://image/role/{atlas_path.parent.name}/{atlas_path.name}"), encoding="utf-8")

    preview_frames = []
    for slot in range(COLS):
        canvas = Image.new("RGB", (4 * 96, 4 * 96), (28, 31, 39))
        draw = ImageDraw.Draw(canvas)
        for role_index, (_, name) in enumerate(ROLES):
            atlas = pending[role_index][1]
            for row, direction in enumerate(DIRECTIONS):
                frame = atlas.crop((slot * CELL, row * CELL, (slot + 1) * CELL, (row + 1) * CELL))
                frame = frame.resize((64, 64), Image.Resampling.NEAREST)
                canvas.paste(frame, (role_index * 96 + 16, row * 96 + 8), frame)
                draw.text((role_index * 96 + 4, row * 96 + 76), f"{name[:4]} {direction[0]}", fill="white")
        preview_frames.append(canvas)
    preview_frames[0].save(qa_dir / "walk_preview_v14_64.gif", save_all=True,
                           append_images=preview_frames[1:], duration=round(1000 / FPS),
                           loop=0, disposal=2)
    (qa_dir / "technical_checks_v14.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("WALK_GAIT_V14_OK: 96 atlas frames; separated front/back boots and one-boot side profiles")


if __name__ == "__main__":
    main()
