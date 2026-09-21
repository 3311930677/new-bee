"""Crop fixed avatar portraits from the six generated role anchor images."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


def clear_edge_black(image: Image.Image, threshold: int = 24) -> Image.Image:
    rgba = image.convert("RGBA")
    px = rgba.load()
    seen = bytearray(rgba.width * rgba.height)
    queue: deque[tuple[int, int]] = deque()

    def add(x: int, y: int) -> None:
        idx = y * rgba.width + x
        if seen[idx]:
            return
        r, g, b, a = px[x, y]
        if a == 0 or max(r, g, b) <= threshold:
            seen[idx] = 1
            queue.append((x, y))

    for x in range(rgba.width):
        add(x, 0)
        add(x, rgba.height - 1)
    for y in range(rgba.height):
        add(0, y)
        add(rgba.width - 1, y)

    while queue:
        x, y = queue.popleft()
        px[x, y] = (0, 0, 0, 0)
        if x:
            add(x - 1, y)
        if x + 1 < rgba.width:
            add(x + 1, y)
        if y:
            add(x, y - 1)
        if y + 1 < rgba.height:
            add(x, y + 1)
    return rgba


def crop_avatar(source: Path, output: Path, box: tuple[int, int, int, int]) -> None:
    image = clear_edge_black(Image.open(source))
    crop = image.crop(box).resize((96, 96), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(crop)
    draw.rectangle((0, 0, 95, 95), outline=(43, 32, 22, 255), width=1)
    output.parent.mkdir(parents=True, exist_ok=True)
    crop.save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    specs = {
        "zs_nan": ("batch0_v2/ready/a1_zs_nan_anchor_v2_transparent_512x768.png", (260, 345, 420, 505)),
        "zs_nv": ("batch1/anchors/ready/a1_zs_nv_anchor_512x768.png", (255, 345, 415, 505)),
        "fs_nan": ("batch1/anchors/ready/a1_fs_nan_anchor_512x768.png", (258, 350, 418, 510)),
        "fs_nv": ("batch1/anchors/ready/a1_fs_nv_anchor_512x768.png", (264, 375, 424, 535)),
        "ls_nan": ("batch1/anchors/ready/a1_ls_nan_anchor_512x768.png", (155, 345, 315, 505)),
        "ls_nv": ("batch1/anchors/ready/a1_ls_nv_anchor_512x768.png", (230, 300, 390, 460)),
    }
    for role_id, (name, box) in specs.items():
        crop_avatar(args.source_dir / name, args.output_dir / f"a4_{role_id}_avatar_96x96.png", box)
        print(f"AVATAR_OK: {role_id}")


if __name__ == "__main__":
    main()
