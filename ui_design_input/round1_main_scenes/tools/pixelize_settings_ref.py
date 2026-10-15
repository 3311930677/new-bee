"""Re-pixelize the settings-page reference mockups to the game's 1:1 pixel grid.

Usage:
    python -I pixelize_settings_ref.py <src_dir> <out_dir>

The mockups are 941x1672 (9:16) painted 'pixel-look' images without a real grid.
Each one is area-averaged to 480 px wide (1 art px = 1 screen px), quantized to a
limited palette without dither, and written as:
    <name>_480.png     art resolution, what slicing works from
    <name>_x3.png      nearest x3 for review
"""
import glob
import os
import sys

from PIL import Image

WIDTH = 480
COLORS = 48


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, out = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(src, "*.webp")) + glob.glob(os.path.join(src, "*.png"))):
        name = os.path.splitext(os.path.basename(path))[0]
        img = Image.open(path).convert("RGB")
        h = round(img.height * WIDTH / img.width)
        small = img.resize((WIDTH, h), Image.BOX)
        q = small.quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
        q.save(os.path.join(out, name + "_480.png"))
        q.resize((WIDTH * 3, h * 3), Image.NEAREST).save(os.path.join(out, name + "_x3.png"))
        print(name, img.size, "->", q.size)


if __name__ == "__main__":
    main()
