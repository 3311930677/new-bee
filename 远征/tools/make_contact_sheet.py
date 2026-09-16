# make_contact_sheet.py —— 拼图复核预处理结果：tiles 3×8 平铺 + decos 棋盘格底
from __future__ import annotations

import os

from PIL import Image

SRC = os.path.join(os.path.dirname(__file__), "..", "image", "map_proc")
OUT = os.path.join(os.path.dirname(__file__), "..", "image", "map_proc", "_contact.png")


def checker(size: tuple[int, int], cell: int = 8) -> Image.Image:
    img = Image.new("RGB", size, (160, 160, 160))
    px = img.load()
    for y in range(size[1]):
        for x in range(size[0]):
            if (x // cell + y // cell) % 2 == 0:
                px[x, y] = (200, 200, 200)
    return img


def main() -> None:
    tiles = []
    decos = []
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".png") or name.startswith("_"):
            continue
        stem = name[:-4]
        if "_sheet_" in stem:
            continue
        if stem.split("_")[1] == "tile":
            tiles.append(name)
        else:
            decos.append(name)

    # tiles：每张 3×3 平铺预览拼缝，横排 6 张一组
    tpw = 6 * (48 * 3 + 10) + 10
    tph = ((len(tiles) + 5) // 6) * (48 * 3 + 24) + 10
    timg = Image.new("RGB", (tpw, tph), (40, 36, 30))
    for i, name in enumerate(tiles):
        t = Image.open(os.path.join(SRC, name)).convert("RGB")
        prev = Image.new("RGB", (48 * 3, 48 * 3))
        for yy in range(3):
            for xx in range(3):
                prev.paste(t, (xx * 48, yy * 48))
        cx = 10 + (i % 6) * (48 * 3 + 10)
        cy = 10 + (i // 6) * (48 * 3 + 24)
        timg.paste(prev, (cx, cy))

    # decos：棋盘格底 + 居中摆放
    dpw = 7 * 140 + 10
    dph = ((len(decos) + 6) // 7) * 150 + 10
    dimg = checker((dpw, dph))
    for i, name in enumerate(decos):
        d = Image.open(os.path.join(SRC, name)).convert("RGBA")
        cx = 10 + (i % 7) * 140 + 70
        cy = 10 + (i // 7) * 150 + 140
        dimg.paste(d, (cx - d.width // 2, cy - d.height), d)

    out = Image.new("RGB", (max(tpw, dpw), tph + dph + 10), (24, 22, 18))
    out.paste(timg, (0, 0))
    out.paste(dimg, (0, tph + 10))
    out.save(OUT)
    print("→", os.path.abspath(OUT), out.size)


if __name__ == "__main__":
    main()
