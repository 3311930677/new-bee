"""Convert generated artwork to a constrained native-pixel presentation.

The image is cropped to the requested aspect ratio, reduced to a logical game
resolution, palette-quantized without dithering, then enlarged with nearest
neighbor. Optional edge-connected black removal is intended for sprites/UI that
were generated on a black matte.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def parse_size(value: str) -> tuple[int, int]:
    try:
        width, height = value.lower().split("x", 1)
        result = int(width), int(height)
    except (ValueError, TypeError) as exc:
        raise argparse.ArgumentTypeError("size must be WIDTHxHEIGHT") from exc
    if result[0] <= 0 or result[1] <= 0:
        raise argparse.ArgumentTypeError("size values must be positive")
    return result


def center_crop(image: Image.Image, aspect: float) -> Image.Image:
    current = image.width / image.height
    if current > aspect:
        width = round(image.height * aspect)
        left = (image.width - width) // 2
        return image.crop((left, 0, left + width, image.height))
    height = round(image.width / aspect)
    top = (image.height - height) // 2
    return image.crop((0, top, image.width, top + height))


def clear_edge_black(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    seen = bytearray(rgba.width * rgba.height)
    queue: deque[tuple[int, int]] = deque()

    def add(x: int, y: int) -> None:
        index = y * rgba.width + x
        if seen[index]:
            return
        color = pixels[x, y]
        if color[3] == 0 or max(color[:3]) <= threshold:
            seen[index] = 1
            queue.append((x, y))

    for x in range(rgba.width):
        add(x, 0)
        add(x, rgba.height - 1)
    for y in range(rgba.height):
        add(0, y)
        add(rgba.width - 1, y)

    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        if x:
            add(x - 1, y)
        if x + 1 < rgba.width:
            add(x + 1, y)
        if y:
            add(x, y - 1)
        if y + 1 < rgba.height:
            add(x, y + 1)
    return rgba


def contain_transparent(
    image: Image.Image, logical: tuple[int, int], padding: int
) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if not bbox:
        raise ValueError("no foreground remains after background removal")
    crop = image.crop(bbox)
    inner = logical[0] - padding * 2, logical[1] - padding * 2
    scale = min(inner[0] / crop.width, inner[1] / crop.height)
    size = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
    crop = crop.resize(size, Image.Resampling.BOX)
    canvas = Image.new("RGBA", logical, (0, 0, 0, 0))
    canvas.alpha_composite(crop, ((logical[0] - size[0]) // 2, logical[1] - padding - size[1]))
    return canvas


def quantize(image: Image.Image, colors: int, transparent: bool) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    rgb = rgba.convert("RGB")
    result = rgb.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    result.putalpha(alpha if transparent else Image.new("L", result.size, 255))
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--logical", type=parse_size, required=True)
    parser.add_argument("--final", type=parse_size, required=True)
    parser.add_argument("--colors", type=int, required=True)
    parser.add_argument("--transparent-black", action="store_true")
    parser.add_argument("--black-threshold", type=int, default=24)
    parser.add_argument("--padding", type=int, default=2)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    if args.transparent_black:
        source = clear_edge_black(source, args.black_threshold)
        logical = contain_transparent(source, args.logical, args.padding)
    else:
        source = center_crop(source, args.logical[0] / args.logical[1])
        logical = source.resize(args.logical, Image.Resampling.BOX)
    logical = quantize(logical, args.colors, args.transparent_black)
    final = logical.resize(args.final, Image.Resampling.NEAREST)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    final.save(args.output)
    print(
        f"PIXELATE_OK: {args.input.name} logical={args.logical[0]}x{args.logical[1]} "
        f"colors={args.colors} final={args.final[0]}x{args.final[1]}"
    )


if __name__ == "__main__":
    main()
