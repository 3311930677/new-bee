from PIL import Image
import os
d = r"d:\godot\new bee\远征\image\generated_201_333\ready\ui_kenney"

def stitch(prefix, out):
    l = Image.open(os.path.join(d, prefix + "_horizontalLeft.png")).convert("RGBA")
    m = Image.open(os.path.join(d, prefix + "_horizontalMid.png")).convert("RGBA")
    r = Image.open(os.path.join(d, prefix + "_horizontalRight.png")).convert("RGBA")
    h = max(l.height, m.height, r.height)
    w = l.width + m.width + r.width
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    img.paste(l, (0, 0))
    img.paste(m, (l.width, 0))
    img.paste(r, (l.width + m.width, 0))
    img.save(os.path.join(d, out))
    print(out, img.size)

stitch("barBack", "ui_kenney_hp_back.png")
stitch("barRed", "ui_kenney_hp_fill.png")
