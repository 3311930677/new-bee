"""Restore generated UI kit sheets to clean pixel-art assets driven by ui_kit_spec.json.

Usage:
    python -I restore_ui_kit.py <src_dir> <spec.json> <out_dir>

Per item: key out the magenta family -> pick the generated component whose centre is
closest to the spec guide box -> area-average (foreground only) to the spec art size ->
binarize alpha -> quantize. Items in the same group share one outline (majority vote of
their alpha masks) so states and rarity tiers line up exactly. Writes:
    art/<id>.png      spec art size (1 art px)
    game/<id>.png     x2 nearest, what Godot loads (1 art px = 2 screen px)
    report.json       aspect error and colour count per item
    preview.png       every game-size item on a dark board, x1
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

GROUPS = {
    "hero": ["hero_normal", "hero_pressed", "hero_disabled"],
    "btn": ["btn_normal", "btn_pressed", "btn_disabled"],
    "tab": ["tab_normal", "tab_selected"],
    "slot": ["slot_common", "slot_uncommon", "slot_rare", "slot_epic", "slot_legend", "slot_empty", "slot_selected"],
    "nav_socket": ["nav_socket", "nav_socket_selected"],
    "rail_socket": ["rail_socket", "rail_socket_selected"],
}
COLORS = 32


def key(rgb):
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    return (r - g > 60) & (b - g > 60) & (r > 120) & (b > 120)


def components(rgb):
    fg = ndi.binary_opening(~key(rgb), iterations=1)
    labels, n = ndi.label(ndi.binary_dilation(fg, iterations=6))
    boxes = []
    for i, sl in enumerate(ndi.find_objects(labels), 1):
        m = (labels[sl] == i) & fg[sl]
        if m.sum() < 400:
            continue
        ys, xs = np.nonzero(m)
        boxes.append((i, sl[1].start + xs.min(), sl[0].start + ys.min(), sl[1].start + xs.max() + 1, sl[0].start + ys.max() + 1))
    return fg, labels, boxes


def area_down(rgb, mask, size):
    def rs(ch):
        return np.asarray(Image.fromarray(ch.astype(np.float32)).resize(size, Image.BOX))
    m = mask.astype(np.float32)
    cov = rs(m)
    out = np.zeros((size[1], size[0], 4), np.uint8)
    for c in range(3):
        out[..., c] = np.clip(rs(rgb[..., c] * m) / np.maximum(cov, 1e-6), 0, 255)
    out[..., 3] = np.where(cov >= 0.5, 255, 0)
    return out


def quantize(rgba):
    op = rgba[..., 3] > 0
    px = rgba[..., :3][op]
    if len(px) == 0:
        return rgba, 0
    w = 256
    rows = math.ceil(len(px) / w)
    pad = np.concatenate([px, np.repeat(px[:1], rows * w - len(px), axis=0)])
    q = Image.fromarray(pad.reshape(rows, w, 3)).quantize(COLORS, method=Image.Quantize.MEDIANCUT,
                                                         dither=Image.Dither.NONE).convert("RGB")
    out = rgba.copy()
    out[..., :3][op] = np.asarray(q).reshape(-1, 3)[: len(px)]
    out[..., :3][~op] = 0
    return out, int(len(np.unique(out[..., :3][op], axis=0)))


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    src, spec_path, out = sys.argv[1:]
    for sub in ("art", "game"):
        os.makedirs(os.path.join(out, sub), exist_ok=True)
    with open(spec_path, encoding="utf-8") as f:
        spec = json.load(f)
    items = spec["items"]
    by_sheet = {}
    for item_id, it in items.items():
        by_sheet.setdefault(it["sheet"], []).append(item_id)

    art, report = {}, {}
    for sheet, ids in by_sheet.items():
        rgb = np.asarray(Image.open(os.path.join(src, sheet + ".png")).convert("RGB")).astype(np.float32)
        fg, labels, boxes = components(rgb.astype(np.uint8))
        used = set()
        for item_id in ids:
            gx, gy, gw, gh = items[item_id]["guide_box"]
            cx, cy = gx + gw / 2, gy + gh / 2
            cand = [b for b in boxes if b[0] not in used]
            best = min(cand, key=lambda b: math.hypot((b[1] + b[3]) / 2 - cx, (b[2] + b[4]) / 2 - cy))
            used.add(best[0])
            idx, x0, y0, x1, y1 = best
            mask = (labels[y0:y1, x0:x1] == idx) & fg[y0:y1, x0:x1]
            aw, ah = items[item_id]["art"]
            art[item_id] = area_down(rgb[y0:y1, x0:x1], mask, (aw, ah))
            src_ratio = (x1 - x0) / (y1 - y0)
            report[item_id] = {"sheet": sheet, "source_box": [int(x0), int(y0), int(x1 - x0), int(y1 - y0)],
                               "aspect_error": round(abs(src_ratio / (aw / ah) - 1), 3)}

    # One outline per group: majority vote of members' alpha.
    for group, ids in GROUPS.items():
        stack = np.stack([art[i][..., 3] > 0 for i in ids])
        shared = stack.sum(0) * 2 >= len(ids)
        for i in ids:
            a = art[i]
            a[..., 3] = np.where(shared, 255, 0)
            report[i]["group"] = group

    tiles = []
    for item_id, a in art.items():
        q, n = quantize(a)
        report[item_id]["colors"] = n
        img = Image.fromarray(q, "RGBA")
        img.save(os.path.join(out, "art", item_id + ".png"))
        big = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
        big.save(os.path.join(out, "game", item_id + ".png"))
        tiles.append((item_id, big))

    width, pad = 1000, 16
    x = y = pad
    row_h = 0
    places = []
    for item_id, img in tiles:
        if x + img.width + pad > width:
            x = pad
            y += row_h + pad
            row_h = 0
        places.append((img, x, y))
        x += img.width + pad
        row_h = max(row_h, img.height)
    board = Image.new("RGBA", (width, y + row_h + pad), (30, 27, 34, 255))
    for img, px, py in places:
        board.alpha_composite(img, (px, py))
    board.convert("RGB").save(os.path.join(out, "preview.png"))
    with open(os.path.join(out, "report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
    worst = sorted(report.items(), key=lambda kv: -kv[1]["aspect_error"])[:5]
    print("items", len(art), "| worst aspect error:", ", ".join("%s %.2f" % (k, v["aspect_error"]) for k, v in worst))


if __name__ == "__main__":
    main()
