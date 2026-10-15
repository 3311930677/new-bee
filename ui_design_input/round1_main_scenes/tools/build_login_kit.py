"""Build the login-page kit from the 941x1672 login mockup.

Usage:
    python -I build_login_kit.py <login_ref.webp> <out_dir> <review_dir>

The mockup is used whole as the page background (1 art px = 1 screen px, 480 wide).
Things the game draws itself are erased from it first:
  - the grey placeholder text inside the account / password fields (LineEdit draws it),
  - the footer note (a Label, so it can switch to an error message).
Buttons, fields and the avatar disc stay painted; the game lays transparent controls
over them, at the rects written to login_kit.json (art coordinates, 480 wide).
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT_W = 480
# rects in mockup pixels (941 wide): x0, y0, x1, y1
FIELD_TEXT = [(278, 700, 400, 742), (278, 860, 400, 902)]
NOTE = (228, 1452, 712, 1488)
# rects in art pixels (480 wide), measured on the 480 grid review sheet
RECTS = {
    "title": [110, 60, 370, 182],
    "subtitle": [150, 182, 330, 210],
    "paper": [88, 312, 394, 568],
    "account_field": [96, 346, 386, 389],
    "account_text": [138, 348, 352, 387],
    "password_field": [96, 427, 386, 470],
    "password_text": [138, 429, 336, 468],
    "eye": [340, 429, 384, 468],
    "avatar_card": [90, 484, 392, 564],
    "login_btn": [56, 584, 424, 652],
    "login_body": [72, 592, 408, 644],
    "guest_btn": [94, 670, 386, 720],
    "guest_body": [100, 675, 380, 715],
    "note": [100, 738, 380, 762],
}
AVATAR = {"center": [136, 523], "radius": 21}
CONTENT = [56, 768]   # rows that must stay on screen (title top .. note bottom)


def erase(rgb, mask):
    mask = cv2.dilate(mask.astype(np.uint8) * 255, np.ones((5, 5), np.uint8))
    return cv2.inpaint(rgb, mask, 5, cv2.INPAINT_TELEA)


def field_text_mask(rgb):
    lum = rgb.astype(np.int32) @ np.array([299, 587, 114]) // 1000
    bg = cv2.medianBlur(lum.astype(np.uint8), 31).astype(np.int32)
    m = np.zeros(lum.shape, bool)
    for x0, y0, x1, y1 in FIELD_TEXT:
        m[y0:y1, x0:x1] = (lum[y0:y1, x0:x1] < bg[y0:y1, x0:x1] - 18)
    return m


def note_mask(rgb):
    lum = rgb.astype(np.int32) @ np.array([299, 587, 114]) // 1000
    m = np.zeros(lum.shape, bool)
    x0, y0, x1, y1 = NOTE
    m[y0:y1, x0:x1] = lum[y0:y1, x0:x1] > 105
    return m


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    src, out, review = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    os.makedirs(review, exist_ok=True)
    rgb = np.asarray(Image.open(src).convert("RGB")).copy()
    H, W = rgb.shape[:2]
    clean = erase(rgb, field_text_mask(rgb) | note_mask(rgb))

    h = round(H * OUT_W / W)
    bg = Image.fromarray(clean).resize((OUT_W, h), Image.BOX)
    bg.save(os.path.join(out, "login_bg.png"))
    # screens taller than the art: a dim, blurred copy fills above and below (linear, cover)
    bg.resize((40, 71), Image.BOX).filter(ImageFilter.GaussianBlur(2)).point(lambda v: int(v * .55)).save(
        os.path.join(out, "login_backdrop.png"))
    edge = np.asarray(bg).astype(int)
    spec = {
        "art_to_screen": 1, "size": [OUT_W, h], "rects": RECTS, "avatar": AVATAR, "content": CONTENT,
        "sky_color": "%02x%02x%02x" % tuple(edge[:6].reshape(-1, 3).mean(0).round().astype(int)),
        "ground_color": "%02x%02x%02x" % tuple(edge[-6:].reshape(-1, 3).mean(0).round().astype(int)),
    }
    with open(os.path.join(out, "login_kit.json"), "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=1)

    # review: rects over the art, x2
    board = bg.convert("RGB").resize((OUT_W * 2, h * 2), Image.NEAREST)
    d = ImageDraw.Draw(board)
    for name, (x0, y0, x1, y1) in RECTS.items():
        d.rectangle([x0 * 2, y0 * 2, x1 * 2 - 1, y1 * 2 - 1], outline=(0, 255, 255))
        d.text((x0 * 2 + 3, y0 * 2 + 2), name, fill=(255, 255, 0))
    cx, cy = AVATAR["center"]
    r = AVATAR["radius"]
    d.ellipse([(cx - r) * 2, (cy - r) * 2, (cx + r) * 2, (cy + r) * 2], outline=(255, 0, 255))
    board.save(os.path.join(review, "rects_x2.png"))
    Image.fromarray(clean).crop((150, 640, 800, 940)).save(os.path.join(review, "fields_erased_full.png"))
    Image.fromarray(clean).crop((150, 1420, 800, 1520)).save(os.path.join(review, "note_erased_full.png"))
    print("login kit", spec["size"])


if __name__ == "__main__":
    main()
