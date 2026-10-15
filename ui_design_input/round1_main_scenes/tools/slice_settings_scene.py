"""Cut the settings-page scene layers and icons from the 480-wide settings mockups.

Usage:
    python -I slice_settings_scene.py <ref_dir> <out_dir> <review_dir>

Adds to the kit written by slice_settings_kit.py (does not touch those files):
    bg_top.png        night scene + panel top rail; tab strip and help text cleared
    bg_mid.png        a text-free band of the panel (side frames + fill), tiled vertically
    bg_bottom.png     railing, lantern, flowers; the mockup has no text here
    back.png / back_pressed.png      the diamond back key
    profile_card.png                 traveller card, name/avatar erased, ring kept
    ib_<id>.png       icon inside its square box, cut whole (box frame included)
    ic_<id>.png       cream icon, alpha keyed, for tabs / sections / buttons
    scene.json        sizes, nine-slice for profile_card, avatar ring centre/radius
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

C, P, S = "settings_common_480.png", "settings_profile_480.png", "settings_save_480.png"

# whole icon boxes (x, y, w, h) — common page rows
BOXES = {
    "music": (C, (34, 263, 35, 34)),
    "sound": (C, (34, 317, 35, 34)),
    "mute":  (C, (34, 372, 35, 34)),
    "shake": (C, (34, 530, 36, 35)),
    "story": (C, (34, 586, 36, 35)),
    "speed": (C, (34, 643, 36, 35)),
}
# keyed icons: generous search box (x0, y0, x1, y1); tightened to the cream pixels
ICONS = {
    "tab_common":  (C, (40, 124, 82, 160)),
    "tab_profile": (C, (196, 126, 232, 162)),
    "tab_save":    (C, (342, 126, 378, 162)),
    "sec_sound":   (C, (34, 204, 74, 236)),
    "sec_battle":  (C, (34, 466, 74, 504)),
    "sec_name":    (P, (32, 316, 70, 354)),
    "sec_journey": (P, (32, 562, 70, 600)),
    "sec_backup":  (S, (34, 204, 70, 234)),
    "sec_restore": (S, (34, 342, 70, 375)),
    "sec_reset":   (S, (32, 592, 70, 627)),
    "btn_avatar":  (P, (48, 500, 90, 540)),
    "btn_prologue": (P, (48, 620, 90, 656)),
    "btn_role":    (P, (48, 680, 90, 716)),
    "chevron":     (P, (414, 506, 438, 534)),
    "btn_copy":    (S, (166, 252, 204, 292)),
    "btn_paste":   (S, (186, 450, 222, 486)),
    "btn_import":  (S, (188, 505, 226, 541)),
    "btn_reset":   (S, (174, 645, 212, 682)),
    "pencil":      (S, (44, 400, 70, 430)),
    "orn":         (P, (158, 441, 180, 461)),
}
TOP_H = 177                    # rows 0..176: scene + panel top rail
MID = (691, 700)               # rows between the last card and the caption: frames + fill only
BOTTOM_Y = 716                 # railing piece starts below the last caption
BACK = (12, 12, 52, 54)        # x, y, w, h
DIAMOND = (37, 38, 23)         # centre x, y and |dx|+|dy| radius of the back key
HELP = (399, 19, 68, 36)       # btn_small frame; only the text inside is cleared
HELP_TEXT = (406, 25, 54, 24)
TABS = (16, 110, 450, 61)      # tab strip region (rows 110..170), game tabs cover it
CARD = (18, 193, 445, 107)     # traveller card
RING_C, RING_R = (85, 248), 38
CARD_TEXT = (138, 210, 132, 76)


def keyed(img, box):
    """Cream glyph pixels of img inside box -> tight RGBA crop."""
    x0, y0, x1, y1 = box
    a = np.asarray(img.crop(box)).astype(int)
    lum = a.mean(2)
    m = (lum > 118) & (a[..., 0] - a[..., 2] > 22)
    ys, xs = np.where(m)
    if len(xs) == 0:
        raise SystemExit("no icon pixels in %s" % (box,))
    bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    rgba = np.dstack([a, np.where(m, 255, 0)]).astype(np.uint8)[by0:by1, bx0:bx1]
    return Image.fromarray(rgba, "RGBA"), (x0 + bx0, y0 + by0)


def erase(rgb, rects, radius=4):
    mask = np.zeros(rgb.shape[:2], np.uint8)
    for x, y, w, h in rects:
        mask[y:y + h, x:x + w] = 255
    return cv2.inpaint(rgb, mask, radius, cv2.INPAINT_TELEA)


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    ref, out, review = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    os.makedirs(review, exist_ok=True)
    imgs = {n: Image.open(os.path.join(ref, n)).convert("RGB") for n in (C, P, S)}
    common = np.asarray(imgs[C]).copy()
    spec = {"art_to_screen": 1, "items": {}}

    def save(name, im, **extra):
        im.save(os.path.join(out, name + ".png"))
        spec["items"][name] = dict(size=list(im.size), **extra)

    # back key: the diamond with its arrow; pressed = darker, 1 px lower
    # back key: only the diamond (|dx|+|dy| <= r) is opaque, so the pressed state darkens the key, not a square
    x, y, w, h = BACK
    yy, xx = np.mgrid[:h, :w]
    inside = (np.abs(xx + x - DIAMOND[0]) + np.abs(yy + y - DIAMOND[1]) <= DIAMOND[2]).astype(np.uint8) * 255
    crop = common[y:y + h, x:x + w]
    back = Image.fromarray(np.dstack([crop, inside]), "RGBA")
    save("back", back, pos=[x, y])
    dark = (crop.astype(np.float32) * 0.7).astype(np.uint8)
    save("back_pressed", Image.fromarray(np.dstack([dark, inside]), "RGBA"), pos=[x, y])
    # top scene with everything interactive erased (the game draws those at the same rects)
    # back key and title stay baked (static); the game draws back.png exactly over it.
    top = common[:TOP_H].copy()
    hx, hy, hw, hh = HELP_TEXT
    top[hy:hy + hh, hx:hx + hw] = np.median(top[hy:hy + hh, hx:hx + 3].reshape(-1, 3), 0)
    # tab strip: blend each column from the scene row above it to the panel rail below it
    tx, ty, tw, th = TABS
    # the row above is blurred along x first, so the gaps between tabs show no streaks
    above = cv2.blur(top[ty - 1:ty, :].astype(np.float32), (61, 1))[0, tx:tx + tw]
    below = top[ty + th, tx:tx + tw].astype(np.float32)
    for i in range(th):
        k = (i + 1) / (th + 1)
        top[ty + i, tx:tx + tw] = (above * (1 - k) + below * k).astype(np.uint8)
    sky = "%02x%02x%02x" % tuple(top[:4].reshape(-1, 3).mean(0).round().astype(int))
    save("bg_top", Image.fromarray(top), help=list(HELP), tabs=list(TABS), back=list(BACK), sky=sky)
    save("bg_mid", Image.fromarray(common[MID[0]:MID[1]]))
    bottom = common[BOTTOM_Y:].copy()
    band = bottom[:8, :320].astype(int)
    stray = ((band.mean(2) > 80) & (band[..., 0] - band[..., 2] > 20)).astype(np.uint8) * 255
    full = np.zeros(bottom.shape[:2], np.uint8)
    full[:8, :320] = cv2.dilate(stray, np.ones((3, 3), np.uint8))
    bottom = cv2.inpaint(bottom, full, 3, cv2.INPAINT_TELEA)
    save("bg_bottom", Image.fromarray(bottom))

    # traveller card: erase name lines, fill ring interior (avatar is drawn there, circle-clipped)
    prof = np.asarray(imgs[P]).copy()
    prof = erase(prof, [CARD_TEXT], 4)
    yy, xx = np.mgrid[:prof.shape[0], :prof.shape[1]]
    inside = (xx - RING_C[0]) ** 2 + (yy - RING_C[1]) ** 2 <= (RING_R - 1) ** 2
    prof[inside] = (226, 209, 167)
    x, y, w, h = CARD
    save("profile_card", Image.fromarray(prof[y:y + h, x:x + w]),
         slice=[150, 12, 170, 12], ring=[RING_C[0] - x, RING_C[1] - y, RING_R - 1],
         text=[CARD_TEXT[0] - x, CARD_TEXT[1] - y])

    for name, (src, (x, y, w, h)) in BOXES.items():
        save("ib_" + name, imgs[src].crop((x, y, x + w, y + h)))
    for name, (src, box) in ICONS.items():
        im, pos = keyed(imgs[src], box)
        save("ic_" + name, im, pos=list(map(int, pos)))

    with open(os.path.join(out, "scene.json"), "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=1)

    # review: the scene assembled at 480x800 + every icon, x2
    board = Image.new("RGB", (480 + 200, 800), (255, 0, 255))
    mid = Image.fromarray(common[MID[0]:MID[1]])
    bot = Image.fromarray(common[BOTTOM_Y:])
    y = TOP_H
    while y < 800 - bot.height:
        board.paste(mid, (0, y))
        y += mid.height
    board.paste(Image.fromarray(top), (0, 0))
    board.paste(bot, (0, 800 - bot.height))
    board.paste(back, BACK[:2], back)
    board.paste(Image.open(os.path.join(out, "profile_card.png")), (0, 300))
    yy = 8
    xx = 488
    for name in list(BOXES) + list(ICONS):
        key = ("ib_" if name in BOXES else "ic_") + name
        im = Image.open(os.path.join(out, key + ".png")).convert("RGBA")
        if xx + im.width > 676:
            xx, yy = 488, yy + 44
        board.paste(im, (xx, yy), im)
        xx += im.width + 8
    board.resize((board.width * 2, board.height * 2), Image.NEAREST).save(os.path.join(review, "scene_x2.png"))
    print("scene items", len(spec["items"]))


if __name__ == "__main__":
    main()
