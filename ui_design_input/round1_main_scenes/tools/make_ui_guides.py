"""UI kit asset spec + layout guides for image generation (single source of truth).

Usage:
    python -I make_ui_guides.py <out_dir>

Writes:
    ui_kit_spec.json          every asset: sheet, art size, nine-slice margins, game size, guide box
    <sheet>_guide_gpt.png     1536x1024, flat #FF00FF background + grey placement boxes, no text
    <sheet>_guide_check.png   same layout with ids, sizes and nine-slice lines, for review

Art pixels: the game draws UI at 1 art px = 2 screen px (480-wide portrait).
"scale" is how large each art pixel is drawn in the generation canvas; grain is
restored afterwards by resampling every item to its art size, so the guide only
fixes proportions and placement.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

CANVAS = (1536, 1024)
GAP = 64
MAGENTA = (255, 0, 255)
BOX = (190, 190, 190)
CORNER = (150, 150, 150)

# sheet -> scale, rows of (id, art_w, art_h, nine-slice (l, t, r, b) in art px or None)
SHEETS = {
    "UI-01_hero_button": {"scale": 4, "rows": [
        [("hero_normal", 152, 36, (16, 8, 16, 8))],
        [("hero_pressed", 152, 36, (16, 8, 16, 8))],
        [("hero_disabled", 152, 36, (16, 8, 16, 8))]]},
    "UI-02_buttons_tabs": {"scale": 4, "rows": [
        [("btn_normal", 64, 24, (8, 6, 8, 6)), ("btn_pressed", 64, 24, (8, 6, 8, 6)), ("btn_disabled", 64, 24, (8, 6, 8, 6))],
        [("tab_normal", 72, 22, (8, 6, 8, 6)), ("tab_selected", 72, 22, (8, 6, 8, 6)), ("btn_round", 28, 28, None)]]},
    "UI-03_panels": {"scale": 4, "rows": [
        [("panel_iron", 128, 128, (24, 24, 24, 24)), ("card_paper", 128, 96, (16, 16, 16, 16))]]},
    "UI-04_plaques": {"scale": 4, "rows": [
        [("plaque_title", 176, 32, (40, 0, 40, 0))],
        [("plaque_small", 96, 20, (20, 0, 20, 0)), ("divider", 120, 10, (24, 0, 24, 0))]]},
    "UI-05_rarity_slots": {"scale": 6, "rows": [
        [("slot_common", 32, 32, None), ("slot_uncommon", 32, 32, None), ("slot_rare", 32, 32, None),
         ("slot_epic", 32, 32, None), ("slot_legend", 32, 32, None)],
        [("slot_empty", 32, 32, None), ("slot_selected", 32, 32, None)]]},
    "UI-06_nav": {"scale": 5, "rows": [
        [("nav_base", 240, 44, (32, 0, 32, 0))],
        [("nav_socket", 40, 40, None), ("nav_socket_selected", 40, 40, None),
         ("rail_socket", 28, 30, None), ("rail_socket_selected", 28, 30, None)]]},
    "UI-07_bars": {"scale": 5, "rows": [
        [("bar_frame", 100, 10, (10, 0, 10, 0))],
        [("bar_fill_exp", 92, 4, None), ("bar_fill_hp", 92, 4, None)],
        [("currency_capsule", 72, 18, (10, 0, 10, 0)), ("quest_slip", 128, 36, (16, 10, 16, 10))]]},
}


def layout(sheet):
    """Centre every row horizontally and the row block vertically; return item boxes."""
    s = sheet["scale"]
    rows = [[(i, w * s, h * s, w, h, sl) for i, w, h, sl in row] for row in sheet["rows"]]
    heights = [max(it[2] for it in row) for row in rows]
    total_h = sum(heights) + GAP * (len(rows) - 1)
    if total_h > CANVAS[1] - GAP:
        raise ValueError("sheet too tall")
    y = (CANVAS[1] - total_h) // 2
    boxes = []
    for row, rh in zip(rows, heights):
        row_w = sum(it[1] for it in row) + GAP * (len(row) - 1)
        if row_w > CANVAS[0] - GAP:
            raise ValueError("row too wide: " + row[0][0])
        x = (CANVAS[0] - row_w) // 2
        for item_id, gw, gh, w, h, sl in row:
            boxes.append({"id": item_id, "box": [x, y + (rh - gh) // 2, gw, gh], "art": [w, h], "slice": sl})
            x += gw + GAP
        y += rh + GAP
    return boxes


def draw(boxes, scale, check):
    img = Image.new("RGB", CANVAS, (24, 22, 28) if check else MAGENTA)
    d = ImageDraw.Draw(img)
    for b in boxes:
        x, y, w, h = b["box"]
        d.rectangle((x, y, x + w - 1, y + h - 1), fill=BOX)
        sl = b["slice"]
        if sl:
            l, t, r, btm = (v * scale for v in sl)
            for cx, cy in ((x, y), (x + w - r, y), (x, y + h - btm), (x + w - r, y + h - btm)):
                cw = l if cx == x else r
                ch = t if cy == y else btm
                if cw and ch:
                    d.rectangle((cx, cy, cx + cw - 1, cy + ch - 1), fill=CORNER)
            if l and r and not t:  # horizontal three-slice: mark both caps
                d.rectangle((x, y, x + l - 1, y + h - 1), fill=CORNER)
                d.rectangle((x + w - r, y, x + w - 1, y + h - 1), fill=CORNER)
        if check:
            if sl:
                l, t, r, btm = (v * scale for v in sl)
                for gx in (x + l, x + w - r):
                    d.line((gx, y, gx, y + h), fill=(255, 60, 60), width=2)
                for gy in (y + t, y + h - btm) if t else ():
                    d.line((x, gy, x + w, gy), fill=(255, 60, 60), width=2)
            game = (b["art"][0] * 2, b["art"][1] * 2)
            d.text((x, y - 14), "%s  art %dx%d  game %dx%d" % (b["id"], *b["art"], *game), fill=(255, 230, 120))
    return img


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    spec = {"art_to_screen": 2, "canvas": list(CANVAS), "background": "#FF00FF", "items": {}}
    for name, sheet in SHEETS.items():
        boxes = layout(sheet)
        draw(boxes, sheet["scale"], False).save(os.path.join(out, name + "_guide_gpt.png"))
        draw(boxes, sheet["scale"], True).save(os.path.join(out, name + "_guide_check.png"))
        for b in boxes:
            spec["items"][b["id"]] = {"sheet": name, "art": b["art"], "game": [b["art"][0] * 2, b["art"][1] * 2],
                                      "slice": list(b["slice"]) if b["slice"] else None, "guide_box": b["box"]}
        print("%-22s items %d scale %d" % (name, len(boxes), sheet["scale"]))
    with open(os.path.join(out, "ui_kit_spec.json"), "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=1)
    print("total items", len(spec["items"]))


if __name__ == "__main__":
    main()
