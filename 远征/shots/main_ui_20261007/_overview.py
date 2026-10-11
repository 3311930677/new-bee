# 主要界面总览：把本目录截图拼成一张 contact sheet。
# 用法：python shots/main_ui_20261007/_overview.py
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

SRC = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(SRC, "_overview.png")
CELL_W, CELL_H = 150, 250
LABEL_H = 16
COLS = 6
BG = (26, 24, 20)
FG = (214, 204, 184)


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in (r"C:\Windows\Fonts\consola.ttf", r"C:\Windows\Fonts\msyh.ttc"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main() -> None:
    names = sorted(f[:-4] for f in os.listdir(SRC)
                   if f.endswith(".png") and not f.startswith("_"))
    if not names:
        print("no shots")
        return
    rows = (len(names) + COLS - 1) // COLS
    pad = 8
    cw, ch = CELL_W + pad, CELL_H + LABEL_H + pad
    out = Image.new("RGB", (COLS * cw + pad, rows * ch + pad), BG)
    draw = ImageDraw.Draw(out)
    font = load_font(13)
    for i, name in enumerate(names):
        img = Image.open(os.path.join(SRC, name + ".png")).convert("RGB")
        img = img.resize((CELL_W, CELL_H), Image.LANCZOS)
        x, y = pad + (i % COLS) * cw, pad + (i // COLS) * ch
        out.paste(img, (x, y))
        draw.text((x, y + CELL_H + 2), name[:24], fill=FG, font=font)
    out.save(OUT)
    print("->", OUT, out.size, len(names), "shots")


if __name__ == "__main__":
    main()
