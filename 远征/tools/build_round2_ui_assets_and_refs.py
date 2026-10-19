#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Round 2 UI Asset & Reference Sheet Generator
Generates:
1. New pixel-art UI ornaments in assets/ui/kit_20261013/:
   - plaque_header_jade.png (360x42)
   - divider_scroll_ornament.png (320x14)
   - card_frame_parchment.png (256x128)
   - archery_hud_strip.png (440x36)
2. Round 2 High-Craft Pixel-Art Mobile Game UI Reference Sheets in docs/agent_iteration/references/:
   - r2_ref_scroll_header_plaque.png
   - r2_ref_ledger_subcards.png
   - r2_ref_hud_and_route.png
   - r2_ref_popup_and_dialog.png
   - r2_reference_master_board.png
"""
import os
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = r"D:\new bee\远征"
KIT_DIR = os.path.join(ROOT, "assets", "ui", "kit_20261013")
REF_DIR = os.path.join(ROOT, "docs", "agent_iteration", "references")
os.makedirs(KIT_DIR, exist_ok=True)
os.makedirs(REF_DIR, exist_ok=True)

FONT_ART = os.path.join(ROOT, "assets", "fonts", "MaShanZheng-Regular.ttf")
FONT_SERIF = os.path.join(ROOT, "assets", "fonts", "NotoSerifCJKsc-SemiBold.otf")
FONT_BOLD = os.path.join(ROOT, "assets", "fonts", "NotoSansSC-Bold.otf")
FONT_REG = os.path.join(ROOT, "assets", "fonts", "NotoSansSC-Regular.otf")


def load_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def make_plaque_header_jade():
    w, h = 360, 42
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            # Chamfered corners
            if (x + y < 5) or (w - 1 - x + y < 5) or (x + h - 1 - y < 5) or (w - 1 - x + h - 1 - y < 5):
                continue
            # Outer dark bronze rim
            if x in (0, w - 1) or y in (0, h - 1):
                px[x, y] = (28, 22, 18, 245)
                continue
            # Gilded brass frame
            if x in (1, 2, w - 2, w - 3) or y in (1, 2, h - 2, h - 3):
                px[x, y] = (206, 168, 98, 255) if (x + y) % 2 == 0 else (172, 134, 72, 255)
                continue
            # Inner dark jade lacquer gradient with subtle horizontal pixel weave
            t = y / float(h - 1)
            r = int(24 + 12 * math.sin(t * math.pi))
            g = int(52 + 18 * math.sin(t * math.pi))
            b = int(50 + 16 * math.sin(t * math.pi))
            grain = ((x * 7 + y * 13) % 5) - 2
            if y % 4 == 0 and (x // 6) % 2 == 0:
                grain += 3
            px[x, y] = (max(0, min(255, r + grain)), max(0, min(255, g + grain)), max(0, min(255, b + grain)), 248)

    draw = ImageDraw.Draw(img)
    # Inner fine gold rule
    draw.rectangle([5, 5, w - 6, h - 6], outline=(224, 188, 116, 120))
    # Corner fretwork & side cloud-diamond medallions
    for cx, cy in [(14, h // 2), (w - 15, h // 2)]:
        draw.polygon([(cx, cy - 6), (cx + 6, cy), (cx, cy + 6), (cx - 6, cy)], fill=(218, 180, 106, 235), outline=(42, 28, 18, 255))
        draw.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=(168, 56, 42, 255))
    img.save(os.path.join(KIT_DIR, "plaque_header_jade.png"))


def make_divider_scroll_ornament():
    w, h = 320, 14
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cy = h // 2
    # Main tapered bronze-gold rule
    draw.line([(16, cy), (w - 17, cy)], fill=(176, 138, 78, 210), width=1)
    draw.line([(44, cy - 2), (w - 45, cy - 2)], fill=(140, 58, 42, 110), width=1)
    draw.line([(44, cy + 2), (w - 45, cy + 2)], fill=(140, 58, 42, 110), width=1)
    # Center knot medallion
    mx = w // 2
    draw.polygon([(mx, cy - 6), (mx + 8, cy), (mx, cy + 6), (mx - 8, cy)], fill=(198, 156, 86, 245), outline=(92, 64, 34, 255))
    draw.polygon([(mx, cy - 3), (mx + 3, cy), (mx, cy + 3), (mx - 3, cy)], fill=(164, 52, 38, 255))
    # Side diamond stops
    for sx in [mx - 22, mx + 22, 36, w - 37]:
        draw.polygon([(sx, cy - 3), (sx + 3, cy), (sx, cy + 3), (sx - 3, cy)], fill=(186, 146, 82, 225))
    img.save(os.path.join(KIT_DIR, "divider_scroll_ornament.png"))


def make_card_frame_parchment():
    w, h = 256, 128
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            if (x + y < 4) or (w - 1 - x + y < 4) or (x + h - 1 - y < 4) or (w - 1 - x + h - 1 - y < 4):
                continue
            if x in (0, w - 1) or y in (0, h - 1):
                px[x, y] = (86, 66, 42, 235)
                continue
            if x in (1, w - 2) or y in (1, h - 2):
                px[x, y] = (178, 146, 94, 245)
                continue
            # Warm tea-stained rice paper interior
            grain = ((x * 17 + y * 31 + (x * y) % 7) % 9) - 4
            edge_dist = min(x, y, w - 1 - x, h - 1 - y)
            vignette = max(0, 10 - edge_dist) * 2
            r = max(0, min(255, 230 + grain - vignette))
            g = max(0, min(255, 217 + grain - vignette))
            b = max(0, min(255, 188 + grain - vignette))
            px[x, y] = (r, g, b, 248)

    draw = ImageDraw.Draw(img)
    draw.rectangle([4, 4, w - 5, h - 5], outline=(162, 128, 78, 125))
    # Corner brass brackets
    for cx, cy, sx, sy in [(3, 3, 1, 1), (w - 4, 3, -1, 1), (3, h - 4, 1, -1), (w - 4, h - 4, -1, -1)]:
        draw.line([(cx, cy), (cx + 10 * sx, cy)], fill=(142, 104, 54, 230), width=2)
        draw.line([(cx, cy), (cx, cy + 10 * sy)], fill=(142, 104, 54, 230), width=2)
        x0, x1 = sorted([cx + 2 * sx, cx + 4 * sx])
        y0, y1 = sorted([cy + 2 * sy, cy + 4 * sy])
        draw.rectangle([x0, y0, x1, y1], fill=(196, 158, 88, 245))
    img.save(os.path.join(KIT_DIR, "card_frame_parchment.png"))


def make_archery_hud_strip():
    w, h = 440, 36
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            if (x + y < 3) or (w - 1 - x + y < 3) or (x + h - 1 - y < 3) or (w - 1 - x + h - 1 - y < 3):
                continue
            if x in (0, w - 1) or y in (0, h - 1):
                px[x, y] = (18, 14, 12, 240)
                continue
            if x in (1, w - 2) or y in (1, h - 2):
                px[x, y] = (186, 146, 82, 225)
                continue
            grain = ((x * 11 + y * 19) % 5) - 2
            px[x, y] = (28 + grain, 24 + grain, 22 + grain, 218)
    draw = ImageDraw.Draw(img)
    draw.rectangle([4, 4, w - 5, h - 5], outline=(136, 102, 58, 110))
    img.save(os.path.join(KIT_DIR, "archery_hud_strip.png"))


def build_r2_reference_sheets():
    f_art = load_font(FONT_ART, 28)
    f_serif = load_font(FONT_SERIF, 18)
    f_bold = load_font(FONT_BOLD, 16)
    f_sm = load_font(FONT_REG, 14)

    plaque = Image.open(os.path.join(KIT_DIR, "plaque_header_jade.png"))
    divider = Image.open(os.path.join(KIT_DIR, "divider_scroll_ornament.png"))
    subcard = Image.open(os.path.join(KIT_DIR, "card_frame_parchment.png"))
    seal = Image.open(os.path.join(KIT_DIR, "seal_stamps.png"))

    # Sheet 1: Oriental Scroll Header Plaque & Oath Subcards
    s1 = Image.new("RGBA", (480, 800), (20, 18, 16, 255))
    d1 = ImageDraw.Draw(s1)
    d1.rounded_rectangle([20, 52, 460, 744], radius=6, fill=(238, 226, 196, 255), outline=(182, 144, 84, 255), width=3)
    d1.rectangle([28, 60, 452, 736], outline=(146, 62, 44, 90), width=1)
    s1.paste(plaque, (60, 72), plaque)
    d1.text((156, 77), "守碑出行誓约", font=f_art, fill=(246, 225, 178, 255))
    s1.paste(divider, (80, 120), divider)
    d1.text((44, 142), "三誓约可换；本图当日已锁定的誓约不会随切换重置。", font=f_sm, fill=(68, 52, 36, 255))
    for i, (name, desc) in enumerate([
        ("庇护 · 立约", "护送路边旅人到安全点；防御+5%，药剂回复+5%。\n可得守护纹样 · 宠物粮 × 2"),
        ("征伐 · 立约", "击退地图上的誓约前哨；攻击+5%，药剂回复-5%。\n可得前哨纹样 · 强化石 × 2"),
        ("丰收 · 立约", "清理路边障碍、留根采样；完成目标多获培养材料。\n可得行旅营帐纹样 · 强化石 × 2 / 宠物粮 × 1"),
    ]):
        cy = 188 + i * 150
        card_img = subcard.resize((392, 134), Image.Resampling.NEAREST)
        s1.paste(card_img, (44, cy), card_img)
        d1.rounded_rectangle([58, cy + 14, 238, cy + 52], radius=4, fill=(42, 68, 62, 255), outline=(196, 158, 88, 255), width=2)
        d1.text((92, cy + 22), name, font=f_serif, fill=(244, 228, 192, 255))
        d1.text((58, cy + 64), desc, font=f_sm, fill=(58, 46, 32, 255))
        seal_crop = seal.crop((0, 0, 32, 32)).resize((48, 48), Image.Resampling.NEAREST)
        s1.paste(seal_crop, (368, cy + 16), seal_crop)
    s1.save(os.path.join(REF_DIR, "r2_ref_scroll_header_plaque.png"))

    # Sheet 2: Merchant Guild & Commission Ledger Subcards
    s2 = Image.new("RGBA", (480, 800), (18, 24, 22, 255))
    d2 = ImageDraw.Draw(s2)
    d2.rounded_rectangle([20, 56, 460, 744], radius=6, fill=(228, 221, 201, 255), outline=(174, 149, 103, 255), width=3)
    s2.paste(plaque, (60, 74), plaque)
    d2.text((132, 79), "三城保价与延期合约", font=f_art, fill=(246, 225, 178, 255))
    s2.paste(divider, (80, 122), divider)
    d2.text((48, 142), "第 1 游戏日 · 未结 0/2 · 金币 12800", font=f_bold, fill=(53, 102, 83, 255))
    card_lg = subcard.resize((392, 420), Image.Resampling.NEAREST)
    s2.paste(card_lg, (44, 178), card_lg)
    d2.text((64, 196), "沉渊定价盐仓", font=f_serif, fill=(53, 102, 83, 255))
    d2.rounded_rectangle([344, 194, 418, 222], radius=4, fill=(194, 214, 174, 255), outline=(43, 83, 49, 255), width=1)
    d2.text((354, 199), "◆ 可签约", font=f_sm, fill=(43, 83, 49, 255))
    d2.text((64, 238), "货物：盐×2；交到昭元市集\n签约参照货款204金，押金60金，第4日内交付。\n保价：固定利差25金，退押52金。\n自担：利差30–55金，退押60金。", font=f_sm, fill=(53, 68, 59, 255))
    s2.save(os.path.join(REF_DIR, "r2_ref_ledger_subcards.png"))

    # Sheet 3: HUD Strip, Fishing Gauge & Route Status Bar
    s3 = Image.new("RGBA", (480, 800), (22, 18, 16, 255))
    d3 = ImageDraw.Draw(s3)
    d3.rounded_rectangle([24, 120, 456, 610], radius=6, fill=(238, 225, 194, 255), outline=(182, 144, 84, 255), width=3)
    s3.paste(plaque, (60, 62), plaque)
    d3.text((184, 67), "水边垂钓", font=f_art, fill=(246, 225, 178, 255))
    # Ornate Fishing Gauge
    d3.rounded_rectangle([44, 356, 436, 396], radius=4, fill=(32, 54, 56, 255), outline=(188, 150, 86, 255), width=2)
    d3.rectangle([176, 360, 268, 392], fill=(116, 168, 92, 255), outline=(224, 242, 190, 255))
    d3.rectangle([218, 352, 224, 400], fill=(255, 240, 182, 255), outline=(92, 58, 24, 255))
    # Route bottom status bar preview
    d3.rounded_rectangle([24, 656, 456, 756], radius=6, fill=(236, 222, 192, 255), outline=(186, 148, 86, 255), width=3)
    d3.text((48, 674), "生命  460 / 460 · 药剂 ×2 · 祝福 ×0", font=f_bold, fill=(62, 44, 28, 255))
    s3.save(os.path.join(REF_DIR, "r2_ref_hud_and_route.png"))

    # Sheet 4: Camp Gathering & Special Event Framed Illustration
    s4 = Image.new("RGBA", (480, 800), (20, 16, 14, 255))
    d4 = ImageDraw.Draw(s4)
    d4.rounded_rectangle([24, 60, 456, 736], radius=6, fill=(238, 225, 194, 255), outline=(182, 144, 84, 255), width=3)
    s4.paste(plaque, (60, 78), plaque)
    d4.text((152, 83), "一封错送的喜帖", font=f_art, fill=(246, 225, 178, 255))
    s4.paste(divider, (80, 126), divider)
    # Framed illustration box
    d4.rounded_rectangle([148, 148, 332, 324], radius=4, fill=(218, 202, 168, 255), outline=(168, 128, 68, 255), width=2)
    card_story = subcard.resize((384, 164), Image.Resampling.NEAREST)
    s4.paste(card_story, (48, 340), card_story)
    d4.text((64, 358), "老赵把一张红帖塞进你手里：「上面写着请赵老爷\n来提亲。我连姑娘姓什么都不知道！你替我去古道\n问清楚，先别让石头瞧见。」", font=f_sm, fill=(62, 46, 32, 255))
    s4.save(os.path.join(REF_DIR, "r2_ref_popup_and_dialog.png"))

    # Master Board (2x2)
    master = Image.new("RGBA", (960, 1600), (14, 12, 10, 255))
    master.paste(s1, (0, 0))
    master.paste(s2, (480, 0))
    master.paste(s3, (0, 800))
    master.paste(s4, (480, 800))
    master.save(os.path.join(REF_DIR, "r2_reference_master_board.png"))
    print("Round 2 assets and reference sheets generated successfully.")


if __name__ == "__main__":
    make_plaque_header_jade()
    make_divider_scroll_ornament()
    make_card_frame_parchment()
    make_archery_hud_strip()
    build_r2_reference_sheets()
