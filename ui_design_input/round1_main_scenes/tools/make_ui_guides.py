"""UI kit asset spec + layout guides for image generation (single source of truth).

Usage:
    python -I make_ui_guides.py <out_dir> [v1|v3]   (default v1)

Writes:
    ui_kit_spec.json          every asset: sheet, art size, nine-slice margins, game size, guide box
    <sheet>_guide_gpt.png     1536x1024, flat #FF00FF background + grey placement boxes, no text
    <sheet>_guide_check.png   same layout with ids, sizes and nine-slice lines, for review

Art pixels: the game draws UI at 1 art px = 1 screen px (480-wide portrait),
the same density as the maps. Sizes below are in art px = game px.
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
ART_TO_SCREEN = 1
SHEETS = {
    "UI-01_hero_button": {"scale": 2, "rows": [
        [("hero_normal", 304, 72, (32, 16, 32, 16))],
        [("hero_pressed", 304, 72, (32, 16, 32, 16))],
        [("hero_disabled", 304, 72, (32, 16, 32, 16))]]},
    "UI-02_buttons_tabs": {"scale": 2, "rows": [
        [("btn_normal", 128, 48, (16, 12, 16, 12)), ("btn_pressed", 128, 48, (16, 12, 16, 12)), ("btn_disabled", 128, 48, (16, 12, 16, 12))],
        [("tab_normal", 144, 44, (16, 12, 16, 12)), ("tab_selected", 144, 44, (16, 12, 16, 12)), ("btn_round", 56, 56, None)]]},
    "UI-03_panels": {"scale": 2, "rows": [
        [("panel_iron", 256, 256, (48, 48, 48, 48)), ("card_paper", 256, 192, (32, 32, 32, 32))]]},
    "UI-04_plaques": {"scale": 2, "rows": [
        [("plaque_title", 352, 64, (80, 0, 80, 0))],
        [("plaque_small", 192, 40, (40, 0, 40, 0)), ("divider", 240, 20, (48, 0, 48, 0))]]},
    "UI-05_rarity_slots": {"scale": 3, "rows": [
        [("slot_common", 64, 64, None), ("slot_uncommon", 64, 64, None), ("slot_rare", 64, 64, None),
         ("slot_epic", 64, 64, None), ("slot_legend", 64, 64, None)],
        [("slot_empty", 64, 64, None), ("slot_selected", 64, 64, None)]]},
    "UI-06_nav": {"scale": 2.5, "rows": [
        [("nav_base", 480, 88, (64, 0, 64, 0))],
        [("nav_socket", 80, 80, None), ("nav_socket_selected", 80, 80, None),
         ("rail_socket", 56, 60, None), ("rail_socket_selected", 56, 60, None)]]},
    "UI-07_bars": {"scale": 2.5, "rows": [
        [("bar_frame", 200, 20, (20, 0, 20, 0))],
        [("bar_fill_exp", 184, 8, None), ("bar_fill_hp", 184, 8, None)],
        [("currency_capsule", 144, 36, (20, 0, 20, 0)), ("quest_slip", 256, 72, (32, 20, 32, 20))]]},
}

# v3（2026-10-14）：乌漆底 + 旧金细边 + 少量朱红，按主页/设置参考图。沿用 v1 的 id 便于代码直接换皮，
# 新增 pill / group_header / building_tag / 开关 / 滑条 / 步进器 / sortie_medal。
SHEETS_V3 = {
    "UI3-01_primary": {"scale": 2, "rows": [
        [("hero_normal", 304, 72, (40, 18, 40, 18))],
        [("hero_pressed", 304, 72, (40, 18, 40, 18))],
        [("hero_disabled", 304, 72, (40, 18, 40, 18))]]},
    "UI3-02_buttons": {"scale": 2, "rows": [
        [("btn_normal", 128, 48, (16, 12, 16, 12)), ("btn_pressed", 128, 48, (16, 12, 16, 12)), ("btn_disabled", 128, 48, (16, 12, 16, 12))],
        [("tab_normal", 144, 44, (16, 12, 16, 12)), ("tab_selected", 144, 44, (16, 12, 16, 12)),
         ("pill", 128, 44, (44, 10, 20, 10)), ("btn_round", 56, 56, None)]]},
    "UI3-03_panels": {"scale": 2, "rows": [
        [("panel_iron", 256, 256, (48, 48, 48, 48)), ("card_paper", 256, 192, (32, 32, 32, 32))],
        [("group_header", 240, 48, (56, 0, 36, 0))]]},
    "UI3-04_plaques": {"scale": 2, "rows": [
        [("plaque_title", 352, 64, (80, 0, 80, 0))],
        [("plaque_small", 192, 40, (40, 0, 40, 0)), ("building_tag", 160, 40, (44, 0, 24, 0)), ("divider", 240, 20, (48, 0, 48, 0))]]},
    "UI3-05_controls": {"scale": 2, "rows": [
        [("toggle_off", 80, 36, None), ("toggle_on", 80, 36, None)],
        [("slider_track", 240, 12, (12, 0, 12, 0)), ("slider_fill", 232, 6, None)],
        [("slider_knob", 28, 28, None), ("stepper", 160, 40, (40, 0, 40, 0))]]},
    "UI3-06_slots": {"scale": 3, "rows": [
        [("slot_common", 64, 64, None), ("slot_uncommon", 64, 64, None), ("slot_rare", 64, 64, None),
         ("slot_epic", 64, 64, None), ("slot_legend", 64, 64, None)],
        [("slot_empty", 64, 64, None), ("slot_selected", 64, 64, None)]]},
    "UI3-07_nav": {"scale": 2.5, "rows": [
        [("nav_base", 480, 88, (64, 0, 64, 0))],
        [("nav_socket", 80, 80, None), ("nav_socket_selected", 80, 80, None),
         ("rail_socket", 56, 60, None), ("rail_socket_selected", 56, 60, None), ("sortie_medal", 112, 112, None)]]},
    "UI3-08_bars": {"scale": 2.5, "rows": [
        [("bar_frame", 200, 20, (20, 0, 20, 0))],
        [("bar_fill_exp", 184, 8, None), ("bar_fill_hp", 184, 8, None)],
        [("currency_capsule", 144, 36, (40, 0, 20, 0)), ("quest_slip", 256, 72, (40, 20, 24, 20))]]},
}
VERSIONS = {"v1": SHEETS, "v3": SHEETS_V3}


def layout(sheet):
    """Centre every row horizontally and the row block vertically; return item boxes."""
    s = sheet["scale"]
    rows = [[(i, round(w * s), round(h * s), w, h, sl) for i, w, h, sl in row] for row in sheet["rows"]]
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
            l, t, r, btm = (round(v * scale) for v in sl)
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
                l, t, r, btm = (round(v * scale) for v in sl)
                for gx in (x + l, x + w - r):
                    d.line((gx, y, gx, y + h), fill=(255, 60, 60), width=2)
                for gy in (y + t, y + h - btm) if t else ():
                    d.line((x, gy, x + w, gy), fill=(255, 60, 60), width=2)
            game = (b["art"][0] * ART_TO_SCREEN, b["art"][1] * ART_TO_SCREEN)
            d.text((x, y - 14), "%s  art %dx%d  game %dx%d" % (b["id"], *b["art"], *game), fill=(255, 230, 120))
    return img


def main():
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] not in VERSIONS):
        sys.exit(__doc__)
    out = sys.argv[1]
    sheets = VERSIONS[sys.argv[2] if len(sys.argv) == 3 else "v1"]
    os.makedirs(out, exist_ok=True)
    spec = {"art_to_screen": ART_TO_SCREEN, "canvas": list(CANVAS), "background": "#FF00FF", "items": {}}
    for name, sheet in sheets.items():
        boxes = layout(sheet)
        draw(boxes, sheet["scale"], False).save(os.path.join(out, name + "_guide_gpt.png"))
        draw(boxes, sheet["scale"], True).save(os.path.join(out, name + "_guide_check.png"))
        for b in boxes:
            spec["items"][b["id"]] = {"sheet": name, "art": b["art"], "game": [b["art"][0] * ART_TO_SCREEN, b["art"][1] * ART_TO_SCREEN],
                                      "slice": list(b["slice"]) if b["slice"] else None, "guide_box": b["box"]}
        print("%-22s items %d scale %s" % (name, len(boxes), sheet["scale"]))
    with open(os.path.join(out, "ui_kit_spec.json"), "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=1)
    print("total items", len(spec["items"]))


if __name__ == "__main__":
    main()
