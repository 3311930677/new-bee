"""Slice the 480-wide re-pixelized settings mockups into a 1:1 nine-slice UI kit.

Usage:
    python -I slice_settings_kit.py <ref_dir> <out_dir>

ref_dir holds settings_{common,profile,save}_480.png from pixelize_settings_ref.py.
Every frame in the mockups has text or an icon baked into its middle, so a frame is
rebuilt as  left cap + a text-free strip of its own middle + right cap  (and the same
vertically when "clean_y" is given). Godot tiles that middle, so text never repeats.
Writes:
    <id>.png              the asset (1 art px = 1 screen px)
    settings_kit.json     size and nine-slice margins per asset
    check_x4.png          every source rect, caps and clean strip outlined, x4
    preview.png           the assets on a dark board, x2
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

C, P, S = "settings_common_480.png", "settings_profile_480.png", "settings_save_480.png"
# id: source, rect (x, y, w, h), slice (l, t, r, b), clean_x (x0, x1) in source coords,
# clean_y optional. Rects were measured from edge profiles of the 480 px images.
KIT = {
    "tab_selected": dict(src=C, rect=(20, 116, 146, 50), slice=(14, 10, 14, 14), clean_x=(140, 150)),
    "tab_normal":   dict(src=C, rect=(172, 122, 142, 47), slice=(14, 10, 14, 10), clean_x=(290, 300)),
    "section":      dict(src=C, rect=(14, 197, 452, 44), slice=(16, 8, 48, 8), clean_x=(190, 230)),
    "btn_primary":  dict(src=S, rect=(23, 248, 434, 48), slice=(72, 8, 72, 8), clean_x=(110, 150)),
    "btn_danger":   dict(src=S, rect=(23, 640, 434, 45), slice=(72, 8, 72, 8), clean_x=(110, 150)),
    "btn_row":      dict(src=P, rect=(22, 493, 436, 53), slice=(12, 8, 12, 8), clean_x=(250, 330)),
    "row_card":     dict(src=C, rect=(21, 248, 439, 112), slice=(10, 10, 10, 10), clean_x=(200, 240),
                         clean_y=(310, 320)),
    "input":        dict(src=S, rect=(36, 396, 407, 40), slice=(8, 8, 8, 8), clean_x=(250, 300)),
    "btn_small":    dict(src=C, rect=(399, 19, 68, 36), slice=(8, 8, 8, 8), clean_x=(403, 405)),
    "icon_box":     dict(src=C, rect=(34, 263, 35, 34), slice=(6, 6, 6, 6), clean_x=(37, 39), clean_y=(266, 268)),
    "step_btn":     dict(src=C, rect=(282, 643, 43, 35), slice=(6, 6, 6, 6), clean_x=(286, 288)),
    "switch_off":   dict(src=C, rect=(390, 374, 56, 31)),
    "switch_on":    dict(src=C, rect=(390, 531, 56, 31)),
    # Slider knob sits on the track, so everything close to the panel colour inside its
    # box is keyed to alpha; the track pixels left of / right of it fall outside the box.
    "grabber":      dict(src=C, rect=(314, 267, 18, 24), key_bg=(2, 2)),
}


def rebuild(img, it):
    x, y, w, h = it["rect"]
    crop = img.crop((x, y, x + w, y + h))
    if "key_bg" in it:
        a = np.asarray(crop).astype(int)
        bg = a[it["key_bg"][1], it["key_bg"][0]]
        alpha = np.where(np.abs(a - bg).sum(2) > 45, 255, 0).astype(np.uint8)
        return Image.fromarray(np.dstack([a.astype(np.uint8), alpha]), "RGBA")
    if "slice" not in it:
        return crop
    l, t, r, b = it["slice"]
    cx0, cx1 = it["clean_x"]
    strip = img.crop((cx0, y, cx1, y + h))
    out = Image.new("RGB", (l + strip.width + r, h))
    out.paste(crop.crop((0, 0, l, h)), (0, 0))
    out.paste(strip, (l, 0))
    out.paste(crop.crop((w - r, 0, w, h)), (l + strip.width, 0))
    if "clean_y" in it:
        cy0, cy1 = (v - y for v in it["clean_y"])
        mid = out.crop((0, cy0, out.width, cy1))
        v = Image.new("RGB", (out.width, t + mid.height + b))
        v.paste(out.crop((0, 0, out.width, t)), (0, 0))
        v.paste(mid, (0, t))
        v.paste(out.crop((0, h - b, out.width, h)), (0, t + mid.height))
        out = v
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    ref, out = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    imgs = {n: Image.open(os.path.join(ref, n)).convert("RGB") for n in (C, P, S)}
    checks = {n: im.resize((im.width * 4, im.height * 4), Image.NEAREST) for n, im in imgs.items()}
    spec, tiles = {}, []
    for item_id, it in KIT.items():
        a = rebuild(imgs[it["src"]], it)
        a.save(os.path.join(out, item_id + ".png"))
        spec[item_id] = {"size": list(a.size), "slice": list(it.get("slice", []))}
        tiles.append((item_id, a))
        d = ImageDraw.Draw(checks[it["src"]])
        x, y, w, h = it["rect"]
        d.rectangle((x * 4, y * 4, (x + w) * 4 - 1, (y + h) * 4 - 1), outline=(0, 255, 0))
        if "slice" in it:
            l, t, r, b = it["slice"]
            d.line(((x + l) * 4, y * 4, (x + l) * 4, (y + h) * 4), fill=(255, 0, 255))
            d.line(((x + w - r) * 4, y * 4, (x + w - r) * 4, (y + h) * 4), fill=(255, 0, 255))
            cx0, cx1 = it["clean_x"]
            d.rectangle((cx0 * 4, y * 4 + 2, cx1 * 4, (y + h) * 4 - 3), outline=(0, 200, 255))
    for n, im in checks.items():
        im.save(os.path.join(out, "check_x4_" + n.split("_")[1] + ".png"))
    with open(os.path.join(out, "settings_kit.json"), "w", encoding="utf-8") as f:
        json.dump({"art_to_screen": 1, "items": spec}, f, ensure_ascii=False, indent=1)
    pad, yy, board_w = 8, 8, 480
    rows = []
    for item_id, a in tiles:
        rows.append((a, yy))
        yy += a.height + pad
    board = Image.new("RGB", (board_w, yy), (24, 22, 30))
    for a, py in rows:
        board.paste(a, (pad, py), a if a.mode == "RGBA" else None)
    board.resize((board_w * 2, yy * 2), Image.NEAREST).save(os.path.join(out, "preview.png"))
    print("items", len(spec), {k: v["size"] for k, v in spec.items()})


if __name__ == "__main__":
    main()
