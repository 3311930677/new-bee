# -*- coding: utf-8 -*-
"""
Build Round 1 pixel-art UI scenic banners, ornamental scroll textures,
and Round 1 mature mobile game pixel-art UI reference design sheets.
"""
import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter

PROJ = r"D:\new bee\远征"
KIT_DIR = os.path.join(PROJ, "assets", "ui", "kit_20261013")
SET_DIR = os.path.join(PROJ, "assets", "ui", "settings_20261014")
INTRO_DIR = os.path.join(PROJ, "assets", "ui", "introduction_20261015")
REF_DIR = os.path.join(PROJ, "docs", "agent_iteration", "references")
os.makedirs(KIT_DIR, exist_ok=True)
os.makedirs(REF_DIR, exist_ok=True)

FONT_ART = os.path.join(PROJ, "assets", "fonts", "MaShanZheng-Regular.ttf")
FONT_SERIF = os.path.join(PROJ, "assets", "fonts", "NotoSerifCJKsc-SemiBold.otf")
FONT_NUM = os.path.join(PROJ, "assets", "fonts", "ZCOOLQingKeHuangYou-Regular.ttf")
FONT_SANS = os.path.join(PROJ, "assets", "fonts", "NotoSansSC-Regular.otf")
FONT_BOLD = os.path.join(PROJ, "assets", "fonts", "NotoSansSC-Bold.otf")


def fnt(path, size):
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return ImageFont.load_default()


def make_scenic_banner(src_rel, crop_box, tint_rgb, vignette_alpha=150, accent_gold=True, out_name="banner.png", size=(260, 64)):
    src_path = os.path.join(PROJ, src_rel)
    w, h = size
    # Pixel-art intermediate resolution (half-res nearest neighbor for crisp pixel clusters)
    pw, ph = w // 2, h // 2
    if os.path.exists(src_path):
        im = Image.open(src_path).convert("RGBA")
        iw, ih = im.size
        cx0 = int(iw * crop_box[0])
        cy0 = int(ih * crop_box[1])
        cx1 = int(iw * crop_box[2])
        cy1 = int(ih * crop_box[3])
        cropped = im.crop((cx0, cy0, max(cx0 + 16, cx1), max(cy0 + 16, cy1)))
        small = cropped.resize((pw, ph), Image.Resampling.BILINEAR)
    else:
        small = Image.new("RGBA", (pw, ph), (28, 22, 34, 255))

    # Quantize slightly & apply mood tint + vignette in pixel space
    px = small.load()
    tr, tg, tb = tint_rgb
    for y in range(ph):
        for x in range(pw):
            r, g, b, a = px[x, y]
            # Blend with mood tint
            r = int(r * 0.78 + tr * 0.22)
            g = int(g * 0.78 + tg * 0.22)
            b = int(b * 0.78 + tb * 0.22)
            # Quantize to 24 steps for authentic 16-bit/32-bit pixel palette feel
            r = (r // 6) * 6
            g = (g // 6) * 6
            b = (b // 6) * 6
            # Edge darkening (left/right/top/bottom vignette)
            dx = abs(x - pw * 0.5) / (pw * 0.5)
            dy = abs(y - ph * 0.5) / (ph * 0.5)
            edge = min(1.0, (dx * dx * 0.65 + dy * dy * 0.55))
            dark = 1.0 - edge * (vignette_alpha / 255.0)
            # Left side slightly darker for text readability
            if x < pw * 0.55:
                left_factor = 0.62 + 0.38 * (x / (pw * 0.55))
                dark *= left_factor
            r = max(0, min(255, int(r * dark)))
            g = max(0, min(255, int(g * dark)))
            b = max(0, min(255, int(b * dark)))
            px[x, y] = (r, g, b, 255)

    out = small.resize((w, h), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(out)
    # Ornate pixel frame around the banner
    draw.rectangle([0, 0, w - 1, h - 1], outline=(24, 18, 14, 255))
    draw.rectangle([1, 1, w - 2, h - 2], outline=(168, 134, 78, 220))
    draw.rectangle([2, 2, w - 3, h - 3], outline=(42, 30, 22, 200))
    if accent_gold:
        # 4 corner brass pixel brackets
        for cx, cy, sx, sy in [(2, 2, 1, 1), (w - 3, 2, -1, 1), (2, h - 3, 1, -1), (w - 3, h - 3, -1, -1)]:
            draw.line([(cx, cy), (cx + 8 * sx, cy)], fill=(235, 202, 132, 255))
            draw.line([(cx, cy), (cx, cy + 8 * sy)], fill=(235, 202, 132, 255))
            draw.point((cx + 2 * sx, cy + 2 * sy), fill=(248, 225, 168, 255))

    out_path = os.path.join(KIT_DIR, out_name)
    out.save(out_path)
    return out_path


def build_all_banners():
    # 1. Shop header banner (warm forge/market lantern glow)
    make_scenic_banner(
        "image/main_world/city_market_reference_v2.png",
        (0.08, 0.22, 0.92, 0.62),
        (210, 145, 75),
        vignette_alpha=135,
        out_name="shop_header_banner.png",
    )
    # 2. Exchange header banner (martial arena honor supplies)
    make_scenic_banner(
        "image/battle/art_v2/castle_throne.png",
        (0.05, 0.18, 0.95, 0.56),
        (195, 130, 70),
        vignette_alpha=140,
        out_name="exchange_header_banner.png",
    )
    # 3. Gacha header banner (mystic spirit shrine summoning)
    make_scenic_banner(
        "image/background/art_v2/camp_bluehour.png",
        (0.05, 0.12, 0.95, 0.52),
        (135, 110, 210),
        vignette_alpha=130,
        out_name="gacha_header_banner.png",
    )
    # 4. Activity header banner (autumn lantern festival & frontier bulletin)
    make_scenic_banner(
        "image/background/courtyard_visual_v2.png",
        (0.06, 0.16, 0.94, 0.54),
        (215, 150, 85),
        vignette_alpha=130,
        out_name="activity_header_banner.png",
    )
    # 5. Trade header banner (caravan post & silk road market)
    make_scenic_banner(
        "image/main_world/city_market_reference_v2.png",
        (0.10, 0.30, 0.90, 0.70),
        (185, 155, 95),
        vignette_alpha=135,
        out_name="trade_header_banner.png",
    )
    # 6. Picker header banner (blessing stele & ancient runes)
    make_scenic_banner(
        "image/battle/art_v2/forest_clearing.png",
        (0.08, 0.18, 0.92, 0.58),
        (110, 185, 155),
        vignette_alpha=135,
        out_name="picker_header_banner.png",
    )
    # 7. Ceremony header banner (forged epic weapon & golden anvil)
    make_scenic_banner(
        "image/main_world/city_forge_reference_v2.png",
        (0.08, 0.20, 0.92, 0.60),
        (230, 150, 70),
        vignette_alpha=130,
        out_name="ceremony_header_banner.png",
    )


def nine_slice_paste(canvas, tex, rect, margin=16):
    x0, y0, w, h = [int(v) for v in rect]
    if w <= 0 or h <= 0:
        return
    tw, th = tex.size
    m = min(margin, tw // 3, th // 3, w // 3, h // 3)
    if m <= 1:
        resized = tex.resize((w, h), Image.Resampling.NEAREST)
        canvas.alpha_composite(resized, (x0, y0))
        return
    xs = [0, m, tw - m, tw]
    ys = [0, m, th - m, th]
    xd = [0, m, w - m, w]
    yd = [0, m, h - m, h]
    patch = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for iy in range(3):
        for ix in range(3):
            sw, sh = xs[ix + 1] - xs[ix], ys[iy + 1] - ys[iy]
            dw, dh = xd[ix + 1] - xd[ix], yd[iy + 1] - yd[iy]
            if sw > 0 and sh > 0 and dw > 0 and dh > 0:
                sub = tex.crop((xs[ix], ys[iy], xs[ix + 1], ys[iy + 1])).resize((dw, dh), Image.Resampling.NEAREST)
                patch.paste(sub, (xd[ix], yd[iy]))
    canvas.alpha_composite(patch, (x0, y0))


def build_reference_sheets():
    panel_iron = Image.open(os.path.join(KIT_DIR, "panel_iron.png")).convert("RGBA")
    plaque_title = Image.open(os.path.join(KIT_DIR, "plaque_title.png")).convert("RGBA")
    quest_slip = Image.open(os.path.join(KIT_DIR, "quest_slip.png")).convert("RGBA")
    detail_parch = quest_slip
    item_slot = Image.open(os.path.join(KIT_DIR, "slot_rare.png")).convert("RGBA")
    item_slot_sel = Image.open(os.path.join(KIT_DIR, "slot_legend.png")).convert("RGBA")
    seal_src = os.path.join(PROJ, "assets", "ui", "battle_settle", "seal_stamps.png")
    seals = Image.open(seal_src).convert("RGBA")
    seals.save(os.path.join(KIT_DIR, "seal_stamps.png"))
    seal_red = seals.crop((0, 0, 56, 56)).resize((40, 40), Image.Resampling.NEAREST)

    btn_row = Image.open(os.path.join(SET_DIR, "btn_row.png")).convert("RGBA")
    section_bar = Image.open(os.path.join(SET_DIR, "section.png")).convert("RGBA")
    btn_red = Image.open(os.path.join(INTRO_DIR, "button_red.png")).convert("RGBA")
    btn_dark = Image.open(os.path.join(INTRO_DIR, "button_dark.png")).convert("RGBA")
    tab_active = btn_red
    tab_idle = btn_dark

    bg_town = Image.open(os.path.join(PROJ, "image", "background", "courtyard_visual_v2.png")).convert("RGBA").resize((480, 800), Image.Resampling.NEAREST)
    bg_camp = Image.open(os.path.join(PROJ, "image", "background", "art_v2", "camp_bluehour.png")).convert("RGBA").resize((480, 800), Image.Resampling.NEAREST)

    # ---- Reference 1: Oriental Parchment Scroll & City Notice Modal ----
    r1 = bg_town.copy()
    veil = Image.new("RGBA", (480, 800), (14, 11, 16, 195))
    r1.alpha_composite(veil)
    nine_slice_paste(r1, panel_iron, (24, 76, 432, 648), 28)
    nine_slice_paste(r1, detail_parch, (40, 108, 400, 548), 24)
    plaque = plaque_title.resize((256, 54), Image.Resampling.NEAREST)
    r1.alpha_composite(plaque, (112, 60))
    r1.alpha_composite(seal_red, (382, 120))
    d1 = ImageDraw.Draw(r1)
    d1.text((178, 70), "城务布告栏", font=fnt(FONT_ART, 28), fill=(246, 228, 188, 255))
    d1.text((64, 126), "边城日常事务与悬赏布告 · 冷却完毕即可支取", font=fnt(FONT_SANS, 15), fill=(108, 86, 56, 255))
    for i, (t, sub, act) in enumerate([
        ("每日签到 · 边城点卯", "连续 3 日 · 赠金币×180 与行旅干粮", "领取"),
        ("物资征收 · 铁匠铺配给", "今日份额已备齐 · 强化石×4", "领取"),
        ("演武操练 · 校场陪练", "与守城教头切磋一局 · 荣誉+60", "前往"),
        ("城门巡防 · 枫林哨探", "协助闻叔核验北门路引 · 远征币+45", "领取"),
    ]):
        ry = 160 + i * 96
        nine_slice_paste(r1, quest_slip, (54, ry, 372, 86), 16)
        nine_slice_paste(r1, item_slot, (66, ry + 15, 56, 56), 10)
        d1.text((134, ry + 16), t, font=fnt(FONT_SERIF, 18), fill=(58, 42, 26, 255))
        d1.text((134, ry + 46), sub, font=fnt(FONT_SANS, 14), fill=(110, 90, 62, 255))
        nine_slice_paste(r1, btn_red if act == "领取" else btn_dark, (326, ry + 22, 86, 42), 12)
        d1.text((352, ry + 31), act, font=fnt(FONT_SERIF, 16), fill=(248, 232, 198, 255))
    nine_slice_paste(r1, btn_dark, (160, 666, 160, 44), 14)
    d1.text((208, 677), "返回城内", font=fnt(FONT_SERIF, 17), fill=(242, 226, 192, 255))
    r1_path = os.path.join(REF_DIR, "r1_ref_parchment_modal.png")
    r1.save(r1_path)

    # ---- Reference 2: Merchant Guild & Trade Commission Ledger ----
    r2 = bg_town.copy()
    r2.alpha_composite(veil)
    nine_slice_paste(r2, panel_iron, (18, 42, 444, 716), 28)
    plaque2 = plaque_title.resize((260, 52), Image.Resampling.NEAREST)
    r2.alpha_composite(plaque2, (110, 26))
    trade_ban = Image.open(os.path.join(KIT_DIR, "trade_header_banner.png")).convert("RGBA").resize((404, 68), Image.Resampling.NEAREST)
    r2.alpha_composite(trade_ban, (38, 84))
    d2 = ImageDraw.Draw(r2)
    d2.text((168, 36), "商路 · 断碑营地", font=fnt(FONT_ART, 26), fill=(246, 228, 188, 255))
    d2.text((54, 96), "行旅日 第 1 日", font=fnt(FONT_NUM, 18), fill=(245, 220, 155, 255))
    d2.text((196, 96), "钱袋 12800 金", font=fnt(FONT_NUM, 18), fill=(248, 206, 108, 255))
    d2.text((342, 96), "行囊 3 / 28", font=fnt(FONT_NUM, 18), fill=(220, 232, 215, 255))
    for ti, tname in enumerate(["货市", "运单", "驿站"]):
        tx = 38 + ti * 136
        nine_slice_paste(r2, tab_active if ti == 0 else tab_idle, (tx, 160, 130, 42), 12)
        d2.text((tx + 46, 170), tname, font=fnt(FONT_SERIF, 17), fill=(248, 232, 196, 255))
    nine_slice_paste(r2, detail_parch, (38, 208, 404, 468), 22)
    r2.alpha_composite(seal_red, (388, 218))
    for i, (gname, buy_p, sell_p, stock) in enumerate([
        ("谷物 · 边城秋粮", "77", "59", "3 / 6"),
        ("青盐 · 沉渊结晶", "116", "89", "3 / 6"),
        ("霜草 · 寒谷药材", "66", "49", "8 / 3"),
        ("玄铁 · 矿道精料", "216", "166", "2 / 5"),
    ]):
        ry = 248 + i * 68
        nine_slice_paste(r2, quest_slip, (52, ry, 376, 60), 14)
        nine_slice_paste(r2, item_slot, (60, ry + 6, 48, 48), 10)
        d2.text((118, ry + 10), gname, font=fnt(FONT_SERIF, 17), fill=(54, 40, 24, 255))
        d2.text((118, ry + 34), f"买入 {buy_p} 金 · 卖出 {sell_p} 金", font=fnt(FONT_NUM, 16), fill=(112, 84, 46, 255))
        d2.text((338, ry + 20), stock, font=fnt(FONT_NUM, 18), fill=(52, 92, 68, 255))
    nine_slice_paste(r2, btn_red, (256, 616, 82, 42), 12)
    nine_slice_paste(r2, btn_dark, (344, 616, 82, 42), 12)
    d2.text((280, 626), "买入", font=fnt(FONT_SERIF, 16), fill=(248, 232, 196, 255))
    d2.text((368, 626), "卖出", font=fnt(FONT_SERIF, 16), fill=(238, 224, 192, 255))
    nine_slice_paste(r2, btn_dark, (160, 692, 160, 44), 14)
    d2.text((208, 702), "返回市集", font=fnt(FONT_SERIF, 17), fill=(242, 226, 192, 255))
    r2_path = os.path.join(REF_DIR, "r1_ref_merchant_ledger.png")
    r2.save(r2_path)

    # ---- Reference 3: Dark Ironwood Pavilion Shop & Exchange ----
    r3 = bg_camp.copy()
    r3.alpha_composite(veil)
    nine_slice_paste(r3, panel_iron, (20, 48, 440, 704), 28)
    r3.alpha_composite(plaque2, (110, 30))
    shop_ban = Image.open(os.path.join(KIT_DIR, "shop_header_banner.png")).convert("RGBA").resize((400, 68), Image.Resampling.NEAREST)
    r3.alpha_composite(shop_ban, (40, 90))
    d3 = ImageDraw.Draw(r3)
    d3.text((192, 40), "军需物资铺", font=fnt(FONT_ART, 28), fill=(246, 228, 188, 255))
    d3.text((56, 104), "边城铁匠与随军行商直供 · 购入与回收明码标价", font=fnt(FONT_SANS, 14), fill=(236, 220, 186, 255))
    d3.text((56, 128), "当前持有：12,800 金币 · 900 荣誉", font=fnt(FONT_NUM, 17), fill=(248, 204, 106, 255))
    for i, (iname, hold, buy_c, sell_c) in enumerate([
        ("强化石 · 锻兵基料", "持有 99", "购 120 金", "售 48 金"),
        ("精炼石 · 淬火灵矿", "持有 105", "购 260 金", "售 104 金"),
        ("宠物粮 · 灵兽口粮", "持有 100", "购 90 金", "售 36 金"),
        ("资质果 · 启灵朱果", "持有 101", "购 420 金", "售 168 金"),
        ("进化晶石 · 破界晶核", "持有 0", "购 600 金", "售 240 金"),
    ]):
        ry = 172 + i * 94
        nine_slice_paste(r3, btn_row, (40, ry, 400, 84), 16)
        nine_slice_paste(r3, item_slot_sel if i == 0 else item_slot, (52, ry + 14, 56, 56), 10)
        d3.text((120, ry + 14), iname, font=fnt(FONT_SERIF, 18), fill=(244, 228, 194, 255))
        d3.text((120, ry + 44), f"{hold}  |  {buy_c} · {sell_c}", font=fnt(FONT_NUM, 15), fill=(214, 192, 148, 255))
        nine_slice_paste(r3, btn_red, (286, ry + 22, 68, 40), 10)
        nine_slice_paste(r3, btn_dark, (360, ry + 22, 68, 40), 10)
        d3.text((304, ry + 31), "购入", font=fnt(FONT_SERIF, 15), fill=(248, 232, 196, 255))
        d3.text((378, ry + 31), "出售", font=fnt(FONT_SERIF, 15), fill=(224, 212, 186, 255))
    nine_slice_paste(r3, btn_dark, (160, 684, 160, 44), 14)
    d3.text((208, 694), "返回主城", font=fnt(FONT_SERIF, 17), fill=(242, 226, 192, 255))
    r3_path = os.path.join(REF_DIR, "r1_ref_pavilion_shop.png")
    r3.save(r3_path)

    # ---- Reference 4: Travel Chest & Character Growth Workshop ----
    r4 = bg_camp.copy()
    nine_slice_paste(r4, section_bar, (12, 10, 456, 50), 14)
    d4 = ImageDraw.Draw(r4)
    d4.text((68, 20), "人物养成 · 修行总览", font=fnt(FONT_ART, 26), fill=(246, 228, 188, 255))
    nine_slice_paste(r4, btn_row, (20, 74, 236, 188), 16)
    d4.text((36, 88), "破军 · 战士  Lv.12", font=fnt(FONT_SERIF, 18), fill=(246, 220, 162, 255))
    for si, (sk, sv) in enumerate([("生命", "807"), ("攻击", "93"), ("防御", "43"), ("暴击", "8.1%"), ("速度", "1.05")]):
        d4.text((36, 120 + si * 26), sk, font=fnt(FONT_SANS, 15), fill=(196, 182, 156, 255))
        d4.text((168, 118 + si * 26), sv, font=fnt(FONT_NUM, 17), fill=(246, 232, 200, 255))
    # Lower ornate ironwood chest tray
    nine_slice_paste(r4, panel_iron, (8, 296, 464, 496), 28)
    nine_slice_paste(r4, section_bar, (24, 314, 432, 38), 12)
    d4.text((42, 322), "修行建议 · 天赋尚有 1 点可分配", font=fnt(FONT_SERIF, 16), fill=(245, 208, 125, 255))
    for i, (rtitle, rsub, rbadge) in enumerate([
        ("装备整备", "兵刃 +3 · 铠甲 +2 · 宝饰 +1", "可强化"),
        ("天赋修习", "狂战 / 坚壁 / 迅捷 · 可分配 1 点", "分配天赋"),
        ("技能研习", "裂山 · 破阵 · 回风斩 · 精研 1 门", "可研习"),
        ("灵宠养成", "已收 3 / 10 · 岩龟 Lv.5 协战中", "去喂养"),
        ("坐骑与称号", "烈焰马 1 阶 · 佩戴「初出茅庐」", "已穿戴"),
    ]):
        ry = 362 + i * 78
        nine_slice_paste(r4, btn_row, (24, ry, 432, 70), 16)
        nine_slice_paste(r4, item_slot, (36, ry + 11, 48, 48), 10)
        d4.text((96, ry + 12), rtitle, font=fnt(FONT_SERIF, 18), fill=(244, 228, 194, 255))
        d4.text((96, ry + 38), rsub, font=fnt(FONT_SANS, 14), fill=(192, 176, 146, 255))
        nine_slice_paste(r4, btn_red if i < 2 else btn_dark, (336, ry + 17, 104, 36), 10)
        d4.text((356, ry + 24), rbadge, font=fnt(FONT_SERIF, 15), fill=(248, 232, 196, 255))
    r4_path = os.path.join(REF_DIR, "r1_ref_chest_workshop.png")
    r4.save(r4_path)

    # Master 2x2 board
    board = Image.new("RGB", (960, 1660), (16, 14, 20))
    bd = ImageDraw.Draw(board)
    for idx, (p, title) in enumerate([
        (r1_path, "R1 Ref A: Oriental Parchment & City Modal"),
        (r2_path, "R1 Ref B: Merchant Guild & Trade Ledger"),
        (r3_path, "R1 Ref C: Dark Ironwood Pavilion & Shop"),
        (r4_path, "R1 Ref D: Travel Chest & Growth Workshop"),
    ]):
        r, c = divmod(idx, 2)
        x, y = c * 480, r * 830
        bd.rectangle([x, y, x + 479, y + 29], fill=(38, 30, 44))
        bd.text((x + 12, y + 6), title, font=fnt(FONT_BOLD, 15), fill=(245, 220, 155))
        im = Image.open(p).convert("RGB")
        board.paste(im, (x, y + 30))
    board_path = os.path.join(REF_DIR, "r1_reference_master_board.png")
    board.save(board_path)
    print("Saved Round 1 banners and reference sheets:", board_path)


if __name__ == "__main__":
    build_all_banners()
    build_reference_sheets()
