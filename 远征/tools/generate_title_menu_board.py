"""
generate_title_menu_board.py
Generates a precise pixel art PNG texture for the title menu board background.

Specifications:
- Dimensions: exactly 280x260 pixels (RGBA)
- Semi-transparent dark panel (base color rgba(14, 18, 26, 200))
- Subtle vertical stripe texture: alternating columns of slightly different alpha (197 / 203)
- Outer border: 1px thin dark edge #0a0e14
- Inner highlight: 1px subtle bevel highlight on top-left edges (rgba(255, 255, 255, 25))
- Gold accent corners: small L-shaped gold brackets (#b89050) at all 4 corners, arms 8px long, 1px thick
- Top & bottom gold lines: 1px gold line (#8a7040) along top and bottom edges
- No horizontal ruled lines
"""

import os
from PIL import Image

OUT_PATH = r"D:\new bee\远征\image\ui\pixel_20261008\title_menu_board.png"
WIDTH = 280
HEIGHT = 260

def generate_title_menu_board(out_path: str = OUT_PATH) -> Image.Image:
    """Generate the title menu board texture and save to out_path."""
    w, h = WIDTH, HEIGHT
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pixels = im.load()

    # 1. Base dark panel with subtle vertical wood grain (alternating column alpha)
    # Base color rgba(14, 18, 26, 200); alternating alpha 197 vs 203 (mean = 200)
    for y in range(h):
        for x in range(w):
            alpha = 197 if (x % 2 == 0) else 203
            pixels[x, y] = (14, 18, 26, alpha)

    # 2. Outer border: 1px thin dark edge #0a0e14
    c_dark_border = (10, 14, 20, 255)
    for x in range(w):
        pixels[x, 0] = c_dark_border
        pixels[x, h - 1] = c_dark_border
    for y in range(h):
        pixels[0, y] = c_dark_border
        pixels[w - 1, y] = c_dark_border

    # 3. Top and bottom gold accent lines: #8a7040 (138, 112, 64)
    c_gold_line = (138, 112, 64, 255)
    for x in range(1, w - 1):
        pixels[x, 1] = c_gold_line
        pixels[x, h - 2] = c_gold_line

    # 4. Inner highlight: 1px subtle bevel highlight on top-left edges, rgba(255, 255, 255, 25)
    # Blend formula: result = c_orig * (1 - a_hl) + 255 * a_hl
    alpha_hl = 25 / 255.0
    for x in range(1, w - 1):
        r, g, b, a = pixels[x, 1]
        nr = round(r * (1.0 - alpha_hl) + 255.0 * alpha_hl)
        ng = round(g * (1.0 - alpha_hl) + 255.0 * alpha_hl)
        nb = round(b * (1.0 - alpha_hl) + 255.0 * alpha_hl)
        pixels[x, 1] = (nr, ng, nb, a)

    for y in range(1, h - 1):
        r, g, b, a = pixels[1, y]
        nr = round(r * (1.0 - alpha_hl) + 255.0 * alpha_hl)
        ng = round(g * (1.0 - alpha_hl) + 255.0 * alpha_hl)
        nb = round(b * (1.0 - alpha_hl) + 255.0 * alpha_hl)
        pixels[1, y] = (nr, ng, nb, a)

    # 5. Gold accent corners: small L-shaped gold brackets (#b89050) at all 4 corners
    # Color #b89050 -> (184, 144, 80, 255); arms 8px long, 1px thick
    c_gold_corner = (184, 144, 80, 255)
    arm = 8

    # Top-Left corner: vertex at (1, 1)
    for x in range(1, 1 + arm):
        pixels[x, 1] = c_gold_corner
    for y in range(1, 1 + arm):
        pixels[1, y] = c_gold_corner

    # Top-Right corner: vertex at (w - 2, 1)
    for x in range(w - 1 - arm, w - 1):
        pixels[x, 1] = c_gold_corner
    for y in range(1, 1 + arm):
        pixels[w - 2, y] = c_gold_corner

    # Bottom-Left corner: vertex at (1, h - 2)
    for x in range(1, 1 + arm):
        pixels[x, h - 2] = c_gold_corner
    for y in range(h - 1 - arm, h - 1):
        pixels[1, y] = c_gold_corner

    # Bottom-Right corner: vertex at (w - 2, h - 2)
    for x in range(w - 1 - arm, w - 1):
        pixels[x, h - 2] = c_gold_corner
    for y in range(h - 1 - arm, h - 1):
        pixels[w - 2, y] = c_gold_corner

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    im.save(out_path)
    print(f"Successfully generated title menu board: {out_path} ({im.size[0]}x{im.size[1]})")
    return im

if __name__ == "__main__":
    generate_title_menu_board()
