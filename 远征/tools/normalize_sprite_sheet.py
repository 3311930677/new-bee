#!/usr/bin/env python3
"""Convert an AI 4x5 sprite grid into a fixed-size transparent Godot sheet."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def _background_candidate(rgb: tuple[int, int, int]) -> bool:
    """Recognize the light neutral checkerboard baked into some generated images."""
    r, g, b = rgb
    return min(r, g, b) >= 150 and max(r, g, b) - min(r, g, b) <= 8


def remove_connected_checkerboard(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    seen = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if seen[index] or not _background_candidate(pixels[x, y][:3]):
            return
        seen[index] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (*pixels[x, y][:3], 0)
        if x:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    return rgba


def build_sheet(source: Image.Image, columns: int, rows: int, cell_size: int) -> Image.Image:
    width, height = source.size
    output = Image.new("RGBA", (columns * cell_size, rows * cell_size), (0, 0, 0, 0))

    for row in range(rows):
        y0 = round(row * height / rows)
        y1 = round((row + 1) * height / rows)
        for column in range(columns):
            x0 = round(column * width / columns)
            x1 = round((column + 1) * width / columns)
            frame = source.crop((x0, y0, x1, y1))
            frame = frame.resize((cell_size, cell_size), Image.Resampling.NEAREST)
            output.alpha_composite(frame, (column * cell_size, row * cell_size))

    return output


def build_icon(sheet: Image.Image, cell_size: int) -> Image.Image:
    frame = sheet.crop((0, 0, cell_size, cell_size))
    content_box = frame.getbbox()
    if content_box is None:
        return Image.new("RGBA", (cell_size, cell_size), (0, 0, 0, 0))
    content = frame.crop(content_box)
    side = max(content.size)
    icon = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    icon.alpha_composite(content, ((side - content.width) // 2, (side - content.height) // 2))
    return icon.resize((cell_size, cell_size), Image.Resampling.LANCZOS)


def write_sprite_frames(path: Path, texture_path: str, cell_size: int) -> None:
    lines = [
        "[gd_resource type=\"SpriteFrames\" load_steps=22 format=2]",
        "",
        f"[ext_resource path=\"{texture_path}\" type=\"Texture\" id=1]",
        "",
    ]
    for index in range(20):
        x = (index % 4) * cell_size
        y = (index // 4) * cell_size
        lines.extend([
            f"[sub_resource type=\"AtlasTexture\" id={index + 1}]",
            "atlas = ExtResource( 1 )",
            f"region = Rect2( {x}, {y}, {cell_size}, {cell_size} )",
        ])
    animations = (("idle", True, 5.0), ("attack", False, 10.0), ("cast", False, 8.0), ("hit", False, 10.0), ("death", False, 6.0))
    lines.extend(["", "[resource]", "animations = [ "])
    for animation_index, (name, loop, speed) in enumerate(animations):
        first = animation_index * 4 + 1
        frames = ", ".join(f"SubResource( {frame} )" for frame in range(first, first + 4))
        comma = "," if animation_index < len(animations) - 1 else ""
        lines.extend([
            "{",
            f"\"frames\": [ {frames} ],",
            f"\"loop\": {'true' if loop else 'false'},",
            f"\"name\": \"{name}\",",
            f"\"speed\": {speed}",
            f"}} {comma}",
        ])
    lines.append("]")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--rows", type=int, default=5)
    parser.add_argument("--cell-size", type=int, default=128)
    parser.add_argument("--icon", type=Path)
    parser.add_argument("--spriteframes", type=Path)
    parser.add_argument("--texture-path")
    args = parser.parse_args()

    source = remove_connected_checkerboard(Image.open(args.input))
    sheet = build_sheet(source, args.columns, args.rows, args.cell_size)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    if args.icon:
        args.icon.parent.mkdir(parents=True, exist_ok=True)
        build_icon(sheet, args.cell_size).save(args.icon)
    if args.spriteframes:
        if not args.texture_path:
            parser.error("--texture-path is required with --spriteframes")
        args.spriteframes.parent.mkdir(parents=True, exist_ok=True)
        write_sprite_frames(args.spriteframes, args.texture_path, args.cell_size)


if __name__ == "__main__":
    main()
