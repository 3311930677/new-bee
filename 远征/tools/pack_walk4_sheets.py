"""Pack approved 4x4 keyframe walking art into active Godot 4 assets."""
from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

from normalize_sprite_sheet import remove_connected_checkerboard
from pack_walk_sheets import remove_matte_specks

ROOT = Path(__file__).resolve().parents[1]
CELL, COLS, ROWS, BASELINE, FPS = 128, 4, 4, 120, 8.0
DIRECTIONS = ("down", "left", "right", "up")
ROLES = (
    ("zs", "pojun", "pojun_walk4_keyframes_v4.png"),
    ("ck", "chuanyang", "chuanyang_walk4_keyframes_v4.png"),
    ("fs", "shuangyu", "shuangyu_walk4_keyframes_v4.png"),
    ("fz", "chenxing", "chenxing_walk4_keyframes_v4.png"),
)


def remove_dark_border_background(image: Image.Image) -> Image.Image:
    """Remove a near-black background connected to the canvas border."""
    image = image.convert("RGBA")
    px, width, height = image.load(), image.width, image.height
    seen = bytearray(width * height)
    pending: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if seen[index]:
            return
        r, g, b, _ = px[x, y]
        if max(r, g, b) > 42 or max(r, g, b) - min(r, g, b) > 18:
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
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        if x:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)
    return image


def clean_source(path: Path) -> Image.Image:
    image = remove_connected_checkerboard(Image.open(path), neutral_floor=100)
    if image.getchannel("A").getextrema()[0] == 255:
        image = remove_dark_border_background(image)
    if image.getchannel("A").getextrema()[0] == 255:
        raise ValueError(f"{path.name}: generated background could not be removed")
    image.save(path.with_name(path.stem + "_alpha.png"))
    return image


def write_sprite_frames(path: Path, texture: str) -> None:
    lines = ['[gd_resource type="SpriteFrames" load_steps=18 format=3]', '',
             f'[ext_resource type="Texture2D" path="{texture}" id="1"]', '']
    for row in range(ROWS):
        for col in range(COLS):
            index = row * COLS + col
            lines.extend([f'[sub_resource type="AtlasTexture" id="Atlas_{index}"]',
                          'atlas = ExtResource("1")',
                          f'region = Rect2({col * CELL}, {row * CELL}, {CELL}, {CELL})',
                          'filter_clip = true', ''])
    lines.extend(['[resource]', 'animations = ['])
    for row, direction in enumerate(DIRECTIONS):
        frames = ', '.join('{"duration": 1.0, "texture": SubResource("Atlas_%d")}'
                           % (row * COLS + col) for col in range(COLS))
        lines.extend(['{', f'"frames": [{frames}],', '"loop": true,',
                      f'"name": &"walk_{direction}",', f'"speed": {FPS}',
                      '},' if row < ROWS - 1 else '}'])
    lines.append(']')
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


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
    qa_dir = ROOT / "image" / "role" / "walk_4dir_review" / "qa_v4"
    qa_dir.mkdir(parents=True, exist_ok=True)
    report = {"cell": CELL, "columns": COLS, "rows": ROWS,
              "directions": DIRECTIONS, "fps": FPS, "roles": []}
    packed_roles = []
    for role_id, name, source_name in ROLES:
        source = ROOT / "image" / "role" / role_id / "source" / source_name
        image = clean_source(source)
        extracted, frame_data = [], []
        for row, direction in enumerate(DIRECTIONS):
            for col in range(COLS):
                box = (round(col * image.width / COLS), round(row * image.height / ROWS),
                       round((col + 1) * image.width / COLS), round((row + 1) * image.height / ROWS))
                frame, specks = remove_matte_specks(image.crop(box))
                bbox = frame.getchannel("A").point(lambda value: 255 if value >= 32 else 0).getbbox()
                if bbox is None:
                    raise ValueError(f"{role_id} {direction} frame {col} is empty")
                extracted.append(frame.crop(bbox))
                frame_data.append({"direction": direction, "frame": col, "source_cell": box,
                                   "source_bbox": bbox, "isolated_pixels_removed": specks})
        scale = min(112 / max(frame.height for frame in extracted),
                    116 / max(frame.width for frame in extracted))
        sheet = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
        packed = []
        for index, (frame, data) in enumerate(zip(extracted, frame_data)):
            size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
            frame = frame.resize(size, Image.Resampling.NEAREST)
            cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            cell.alpha_composite(frame, ((CELL - frame.width) // 2, BASELINE - frame.height))
            bbox = cell.getbbox()
            if bbox is None or min(bbox[0], bbox[1], CELL - bbox[2], CELL - bbox[3]) < 4:
                raise ValueError(f"{role_id} frame {index}: insufficient packed margin {bbox}")
            sheet.alpha_composite(cell, ((index % COLS) * CELL, (index // COLS) * CELL))
            data.update({"packed_bbox": bbox,
                         "sha256": hashlib.sha256(cell.tobytes()).hexdigest(),
                         "foot_sha256": hashlib.sha256(cell.crop((0, 88, CELL, CELL)).tobytes()).hexdigest()})
            packed.append(cell)
        for row, direction in enumerate(DIRECTIONS):
            sequence = frame_data[row * COLS:(row + 1) * COLS]
            if len({item["sha256"] for item in sequence}) != COLS:
                raise ValueError(f"{role_id} {direction}: duplicate full frame")
            if len({item["foot_sha256"] for item in sequence}) != COLS:
                raise ValueError(f"{role_id} {direction}: duplicate foot frame")
        output = ROOT / "image" / "role" / role_id / f"{name}_walk_4dir.png"
        sheet.save(output)
        write_sprite_frames(output.with_name(f"{name}_walk_frames.tres"),
                            f"res://image/role/{role_id}/{output.name}")
        contact_sheet(sheet, qa_dir / f"{name}_frames.png")
        report["roles"].append({"id": role_id, "source": str(source.relative_to(ROOT)).replace('\\', '/'),
                                "output": str(output.relative_to(ROOT)).replace('\\', '/'),
                                "source_size": image.size, "output_size": sheet.size,
                                "common_scale": scale, "frames": frame_data})
        packed_roles.append(packed)
        print(f"{role_id}: {output.name}, {sheet.size}, 16 frames")
    (qa_dir / "technical_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    gifs = []
    for frame_index in range(COLS):
        canvas = Image.new("RGB", (640, 640), (28, 31, 39))
        draw = ImageDraw.Draw(canvas)
        for role_index, (_, name, _) in enumerate(ROLES):
            for row, direction in enumerate(DIRECTIONS):
                frame = packed_roles[role_index][row * COLS + frame_index]
                canvas.paste(frame, (role_index * 160 + 16, row * 160 + 8), frame)
                draw.text((role_index * 160 + 10, row * 160 + 140), f"{name} {direction}", fill="white")
        gifs.append(canvas)
    gifs[0].save(qa_dir / "walk_cycles_v4.gif", save_all=True, append_images=gifs[1:],
                 duration=125, loop=0, disposal=2)
    print("WALK4_QA_OK: 64 unique frames packed; 4 roles x 4 directions x 4 gait keys")


if __name__ == "__main__":
    main()
