"""Build the loading-page kit from the 941x1672 loading mockup.

Usage:
    python -I build_loading_kit.py <loading_bg.webp> <out_dir> <review_dir>

The mockup has a progress bar painted in, frozen at 63 %. This script
  1. masks that bar and inpaints it out of the background,
  2. rebuilds the bar as layers the game can drive:
       bar_base.png    every node unlit, empty tube, percent box without text
       bar_fill.png    the lit tube, clipped from the left by progress
       node_<i>.png    lit disc + lantern for node i, shown once progress passes it
  3. downscales all layers together to 480 wide (1 art px = 1 screen px), so they
     stay on one pixel grid, and writes loading_kit.json with their offsets.
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageFilter

OUT_W = 480
ROW0, ROW1 = 1494, 1518          # lit/unlit tube interior rows (inclusive)
TUBE_X0, TUBE_X1 = 118, 772      # tube interior, left diamond to percent box
NODES = [222, 333, 520, 627, 731]
LIT_NODES = NODES[:3]            # lit in the mockup
DISC_R = 16
UNLIT_TILE = (642, 716)          # unlit tube segment between the two grey discs
LIT_TILE = (237, 318)            # lit tube segment between the first two discs
LIT_KEEP_X1 = 495                # mockup lit tube is clean up to here (node 2 glow after)
LANTERN = dict(dx0=-22, dx1=30, y0=1412, y1=1489)
BOX_TEXT = (796, 1486, 884, 1526)  # "63%" inside the percent box


def bar_mask(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = (r * 299 + g * 587 + b * 114) // 1000
    sat = a.max(2) - a.min(2)
    m = ((r - b > 60) & (r > 120)) | ((sat < 40) & (lum > 95)) | ((b - r > 50) & (b > 150))
    band = np.zeros_like(m)
    band[1390:1615, 15:935] = True
    m &= band
    # two lit rock ledges above the bar are not part of it
    m[1385:1428, 555:655] = False
    m[1390:1432, 785:822] = False
    m = m.astype(np.uint8) * 255
    body = np.zeros_like(m)
    body[1484:1530, 28:920] = 255
    m = cv2.bitwise_or(m, body)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
    keep = np.zeros_like(m)
    bid = lab[1505, 400]
    for i in range(1, n):
        if i == bid or st[i, cv2.CC_STAT_AREA] > 400:
            keep[lab == i] = 255
    return cv2.dilate(keep, np.ones((3, 3), np.uint8)) > 0


def tile_rows(src, x0, x1, dst_x0, dst_x1):
    """Columns dst_x0..dst_x1 of the tube rows, tiled from src columns x0..x1."""
    seg = src[ROW0:ROW1 + 1, x0:x1]
    w = x1 - x0
    out = np.zeros((ROW1 - ROW0 + 1, dst_x1 - dst_x0, 3), src.dtype)
    for i in range(dst_x1 - dst_x0):
        out[:, i] = seg[:, (i + dst_x0 - x0) % w]
    return out


def disc_mask(h, w, r):
    yy, xx = np.mgrid[:h, :w]
    return (xx - w // 2) ** 2 + (yy - h // 2) ** 2 <= r * r


def paste(dst_rgb, dst_a, src_rgb, sel, x, y):
    h, w = sel.shape
    dst_rgb[y:y + h, x:x + w][sel] = src_rgb[sel]
    dst_a[y:y + h, x:x + w][sel] = 255


def lantern_box(c):
    return c + LANTERN["dx0"], LANTERN["y0"], c + LANTERN["dx1"], LANTERN["y1"]


def to_silver(rgb):
    lum = rgb.astype(np.float32) @ np.array([0.299, 0.587, 0.114], np.float32)
    v = np.clip(lum * 0.78, 0, 255)
    return np.dstack([v * 0.97, v * 0.97, v * 1.0]).astype(np.uint8)


def shrink(rgba):
    """941-wide RGBA -> 480-wide, premultiplied so edges do not pick up black."""
    img = Image.fromarray(rgba, "RGBA").convert("RGBa")
    h = round(rgba.shape[0] * OUT_W / rgba.shape[1])
    return img.resize((OUT_W, h), Image.BOX).convert("RGBA")


def crop_used(img):
    a = np.asarray(img)[..., 3]
    ys, xs = np.where(a > 8)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    return img.crop(box), box


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    src, out, review = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    os.makedirs(review, exist_ok=True)
    rgb = np.asarray(Image.open(src).convert("RGB")).copy()
    H, W = rgb.shape[:2]
    mask = bar_mask(rgb.astype(np.int32))
    lum = rgb.astype(np.int32) @ np.array([299, 587, 114]) // 1000
    sat = rgb.max(2).astype(np.int32) - rgb.min(2)

    # 1. background without the bar
    bg = cv2.inpaint(rgb, mask.astype(np.uint8) * 255, 6, cv2.INPAINT_TELEA)

    # 2a. base layer: the bar as painted, then everything lit turned unlit
    base = rgb.copy()
    base_a = np.where(mask, 255, 0).astype(np.uint8)
    base[ROW0:ROW1 + 1, TUBE_X0:600] = tile_rows(rgb, *UNLIT_TILE, TUBE_X0, 600)
    d = 2 * DISC_R + 1
    unlit_disc = rgb[1505 - DISC_R:1505 + DISC_R + 1, NODES[3] - DISC_R:NODES[3] + DISC_R + 1]
    lit_disc = rgb[1505 - DISC_R:1505 + DISC_R + 1, NODES[1] - DISC_R:NODES[1] + DISC_R + 1]
    circle = disc_mask(d, d, DISC_R)
    for c in LIT_NODES:
        paste(base, base_a, unlit_disc, circle, c - DISC_R, 1505 - DISC_R)
    # lanterns: drop lit ones, paste the grey lantern of node 3 (same design)
    gx0, gy0, gx1, gy1 = lantern_box(NODES[3])
    grey_sel = mask[gy0:gy1, gx0:gx1] & (sat[gy0:gy1, gx0:gx1] < 45) & (lum[gy0:gy1, gx0:gx1] > 70)
    grey = rgb[gy0:gy1, gx0:gx1]
    for c in LIT_NODES[:2]:
        x0, y0, x1, y1 = lantern_box(c)
        base_a[y0:y1, x0:x1][mask[y0:y1, x0:x1]] = 0
        paste(base, base_a, grey, grey_sel, x0, y0)
    # node 2 is a pagoda with no grey twin: desaturate it in place
    x0, y0, x1, y1 = lantern_box(LIT_NODES[2])
    sel = mask[y0:y1, x0:x1]
    base[y0:y1, x0:x1][sel] = to_silver(rgb[y0:y1, x0:x1])[sel]
    # percent box: remove the painted "63%"
    bx0, by0, bx1, by1 = BOX_TEXT
    text = np.zeros((H, W), np.uint8)
    text[by0:by1, bx0:bx1] = (lum[by0:by1, bx0:bx1] > 110).astype(np.uint8) * 255
    text = cv2.dilate(text, np.ones((3, 3), np.uint8))
    base = cv2.inpaint(base, text, 3, cv2.INPAINT_TELEA)

    # 2b. fill layer: lit tube interior across the whole run
    fill = np.zeros_like(rgb)
    fill_a = np.zeros((H, W), np.uint8)
    fill[ROW0:ROW1 + 1, TUBE_X0:LIT_KEEP_X1] = rgb[ROW0:ROW1 + 1, TUBE_X0:LIT_KEEP_X1]
    fill[ROW0:ROW1 + 1, LIT_KEEP_X1:TUBE_X1] = tile_rows(rgb, *LIT_TILE, LIT_KEEP_X1, TUBE_X1)
    fill_a[ROW0:ROW1 + 1, TUBE_X0:TUBE_X1] = 255
    for c in NODES:   # discs are drawn by the node sprites, keep the tube under them unlit
        fill_a[1505 - DISC_R:1505 + DISC_R + 1, c - DISC_R:c + DISC_R + 1][circle] = 0

    # 2c. node sprites: lit disc + lit lantern
    lit_x0, lit_y0, lit_x1, lit_y1 = lantern_box(NODES[1])
    lit_sel = mask[lit_y0:lit_y1, lit_x0:lit_x1] & (lum[lit_y0:lit_y1, lit_x0:lit_x1] > 60)
    lit_lantern = rgb[lit_y0:lit_y1, lit_x0:lit_x1]
    nodes = []
    for c in NODES:
        n_rgb = np.zeros_like(rgb)
        n_a = np.zeros((H, W), np.uint8)
        x0, y0, x1, y1 = lantern_box(c)
        if c in LIT_NODES:
            sel = mask[y0:y1, x0:x1]
            paste(n_rgb, n_a, rgb[y0:y1, x0:x1], sel, x0, y0)
            paste(n_rgb, n_a, rgb[1505 - DISC_R:1505 + DISC_R + 1, c - DISC_R:c + DISC_R + 1], circle,
                  c - DISC_R, 1505 - DISC_R)
        else:
            paste(n_rgb, n_a, lit_lantern, lit_sel, x0, y0)
            paste(n_rgb, n_a, lit_disc, circle, c - DISC_R, 1505 - DISC_R)
        nodes.append((n_rgb, n_a))

    # 3. downscale on one grid and write
    bg_small = Image.fromarray(bg).resize((OUT_W, round(H * OUT_W / W)), Image.BOX)
    bg_small.save(os.path.join(out, "loading_bg.png"))
    # soft backdrop: fills the extra height on screens taller than the art (scaled up, linear)
    bg_small.crop((0, 0, OUT_W, 120)).resize((24, 40), Image.BOX).filter(ImageFilter.GaussianBlur(1.5)).save(
        os.path.join(out, "loading_backdrop.png"))
    spec = {"art_to_screen": 1, "size": list(bg_small.size), "layers": {}}
    # page fill above / below the art on screens taller than it
    edge = np.asarray(bg_small).astype(int)
    spec["sky_color"] = "%02x%02x%02x" % tuple(edge[:6].reshape(-1, 3).mean(0).round().astype(int))
    spec["ground_color"] = "%02x%02x%02x" % tuple(edge[-6:].reshape(-1, 3).mean(0).round().astype(int))
    k = OUT_W / W
    layers = [("bar_base", base, base_a), ("bar_fill", fill, fill_a)]
    layers += [("node_%d" % i, n, a) for i, (n, a) in enumerate(nodes)]
    small = {}
    for name, l_rgb, l_a in layers:
        img, box = crop_used(shrink(np.dstack([l_rgb, l_a])))
        img.save(os.path.join(out, name + ".png"))
        spec["layers"][name] = {"pos": [box[0], box[1]], "size": [box[2] - box[0], box[3] - box[1]]}
        small[name] = (img, box)
    spec["fill_x"] = [round(TUBE_X0 * k), round(TUBE_X1 * k)]
    spec["node_x"] = [round(c * k) for c in NODES]
    spec["percent_box"] = [round(v * k) for v in BOX_TEXT]
    with open(os.path.join(out, "loading_kit.json"), "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=1)

    # review: bar at 0 %, 50 %, 100 % over the cleaned background, x2
    sheet = []
    y_top, y_bot = 690, 840
    for ratio in (0.0, 0.5, 1.0):
        frame = bg_small.convert("RGBA")
        for name in ("bar_base",):
            img, box = small[name]
            frame.alpha_composite(img, (box[0], box[1]))
        fx0, fx1 = spec["fill_x"]
        cut = fx0 + round((fx1 - fx0) * ratio)
        img, box = small["bar_fill"]
        if cut > box[0]:
            part = img.crop((0, 0, min(img.width, cut - box[0]), img.height))
            frame.alpha_composite(part, (box[0], box[1]))
        for i, nx in enumerate(spec["node_x"]):
            if cut >= nx:
                img, box = small["node_%d" % i]
                frame.alpha_composite(img, (box[0], box[1]))
        sheet.append(frame.crop((0, y_top, OUT_W, y_bot)))
    board = Image.new("RGBA", (OUT_W, (y_bot - y_top + 6) * 3), (255, 0, 255, 255))
    for i, s in enumerate(sheet):
        board.paste(s, (0, i * (y_bot - y_top + 6)))
    board.resize((board.width * 2, board.height * 2), Image.NEAREST).save(os.path.join(review, "bar_states_x2.png"))
    Image.fromarray(bg).crop((0, 1360, W, 1640)).save(os.path.join(review, "bg_erased_full.png"))
    print("loading kit", spec["size"], {k2: v["size"] for k2, v in spec["layers"].items()})


if __name__ == "__main__":
    main()
