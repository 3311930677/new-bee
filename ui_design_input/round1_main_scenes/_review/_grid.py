import sys
from PIL import Image, ImageDraw
src, out, x0, y0, x1, y1, k = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:8])
im = Image.open(src).convert("RGB").crop((x0, y0, x1, y1))
im = im.resize((im.width * k, im.height * k), Image.NEAREST)
d = ImageDraw.Draw(im)
for x in range(x0 - x0 % 10 + 10, x1, 10):
    d.line(((x - x0) * k, 0, (x - x0) * k, 6 if x % 50 else 14), fill=(0, 255, 255))
    if x % 50 == 0: d.text(((x - x0) * k + 2, 0), str(x), fill=(0, 255, 255))
for y in range(y0 - y0 % 10 + 10, y1, 10):
    d.line((0, (y - y0) * k, 6 if y % 50 else 14, (y - y0) * k), fill=(255, 0, 255))
    if y % 50 == 0: d.text((2, (y - y0) * k + 2), str(y), fill=(255, 0, 255))
im.save(out)
