#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Round 3 UI Asset & Reference Sheet Generator (Final Craft & Typography Perfection)
Generates:
1. Refined pixel-art UI ornaments in assets/ui/kit_20261013/:
   - speaker_nameplate_jade.png (240x32)
   - route_status_seal.png (48x48)
2. Round 3 Final Polish Reference Sheets in docs/agent_iteration/references/:
   - r3_ref_clean_parchment_margins.png
   - r3_ref_avatar_and_city_header.png
   - r3_ref_npc_dialog_nameplate.png
   - r3_ref_save_modal_and_ledger.png
   - r3_reference_master_board.png
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


def make_speaker_nameplate_jade():
    w, h = 240, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            if (x + y < 4) or (w - 1 - x + y < 4) or (x + h - 1 - y < 4) or (w - 1 - x + h - 1 - y < 4):
                continue
            if x in (0, w - 1) or y in (0, h - 1):
                px[x, y] = (24, 18, 14, 245)
                continue
            if x in (1, w - 2) or y in (1, h - 2):
                px[x, y] = (204, 166, 96, 255)
                continue
            fade = 1.0 - 0.25 * (x / float(w))
            px[x, y] = (int(28 * fade), int(58 * fade), int(56 * fade), 242)
    draw = ImageDraw.Draw(img)
    draw.polygon([(10, h // 2 - 4), (14, h // 2), (10, h // 2 + 4), (6, h // 2)], fill=(224, 186, 110, 255))
    img.save(os.path.join(KIT_DIR, "speaker_nameplate_jade.png"))


def build_r3_reference_sheets():
    f_art = load_font(FONT_ART, 28)
    f_art_lg = load_font(FONT_ART, 34)
    f_serif = load_font(FONT_SERIF, 18)
    f_bold = load_font(FONT_BOLD, 16)
    f_sm = load_font(FONT_REG, 14)

    plaque = Image.open(os.path.join(KIT_DIR, "plaque_header_jade.png"))
    divider = Image.open(os.path.join(KIT_DIR, "divider_scroll_ornament.png"))
    subcard = Image.open(os.path.join(KIT_DIR, "card_frame_parchment.png"))
    nameplate = Image.open(os.path.join(KIT_DIR, "speaker_nameplate_jade.png"))

    # Sheet 1: Clean 14px Breathing Room on Parchment & Dark-Jade Plaque Header
    s1 = Image.new("RGBA", (480, 800), (18, 16, 14, 255))
    d1 = ImageDraw.Draw(s1)
    # Outer dark-iron + gold rim outside the parchment content area
    d1.rounded_rectangle([16, 50, 464, 746], radius=6, fill=(28, 34, 38, 255), outline=(204, 164, 92, 255), width=3)
    d1.rounded_rectangle([24, 58, 456, 738], radius=4, fill=(241, 234, 215, 255), outline=(184, 148, 86, 255), width=2)
    d1.rectangle([28, 62, 452, 734], outline=(140, 59, 43, 70), width=1)
    s1.paste(plaque, (60, 74), plaque)
    d1.text((156, 79), "守碑出行誓约", font=f_art, fill=(246, 225, 178, 255))
    s1.paste(divider, (80, 120), divider)
    d1.text((42, 140), "三誓约可换；本图当日已锁定的誓约不会随切换重置。\n每张野外图每日一个目标，报酬不含剧情首通物。", font=f_sm, fill=(58, 44, 30, 255))
    for i, (t_name, t_desc) in enumerate([
        ("庇护 · 立约", "护送路边旅人到安全点；防御+5%，攻击-5%，药剂回复+5%。\n可得守护纹样 · 宠物粮 × 2"),
        ("征伐 · 立约", "击退地图上的誓约前哨；攻击+5%，药剂回复-5%。\n可得前哨纹样 · 强化石 × 2"),
        ("丰收 · 立约", "清理路边障碍、留根采样；完成目标多获一份普通培养材料。\n可得行旅营帐纹样 · 强化石 × 2 / 宠物粮 × 1"),
    ]):
        cy = 196 + i * 146
        c_img = subcard.resize((396, 132), Image.Resampling.NEAREST)
        s1.paste(c_img, (42, cy), c_img)
        d1.rounded_rectangle([56, cy + 12, 246, cy + 52], radius=4, fill=(36, 58, 56, 255), outline=(198, 160, 90, 255), width=2)
        d1.text((96, cy + 20), t_name, font=f_serif, fill=(246, 228, 190, 255))
        d1.text((56, cy + 64), t_desc, font=f_sm, fill=(58, 44, 30, 255))
    s1.save(os.path.join(REF_DIR, "r3_ref_clean_parchment_margins.png"))

    # Sheet 2: Avatar Panel & City Built Panel Imperial Dark-Jade Header Contrast
    s2 = Image.new("RGBA", (480, 800), (16, 20, 22, 255))
    d2 = ImageDraw.Draw(s2)
    d2.rounded_rectangle([40, 110, 440, 684], radius=6, fill=(24, 32, 36, 255), outline=(204, 164, 92, 255), width=3)
    d2.rounded_rectangle([48, 118, 432, 676], radius=4, fill=(240, 230, 207, 255), outline=(184, 150, 88, 255), width=2)
    # Dark-Jade Header Band
    d2.rectangle([50, 120, 430, 212], fill=(29, 54, 53, 255), outline=(200, 160, 80, 255), width=2)
    d2.text((68, 134), "◆ 昭元行旅录 · 命途印记", font=f_sm, fill=(216, 197, 154, 255))
    d2.text((68, 158), "旅人小像", font=f_art_lg, fill=(244, 223, 181, 255))
    # Portrait pedestal
    d2.rounded_rectangle([182, 238, 298, 354], radius=6, fill=(24, 42, 42, 255), outline=(212, 174, 98, 255), width=3)
    d2.text((172, 372), "当前使用：自定义图片", font=f_bold, fill=(69, 61, 44, 255))
    d2.rounded_rectangle([68, 468, 412, 514], radius=4, fill=(35, 71, 70, 255), outline=(198, 160, 88, 255), width=2)
    d2.text((186, 480), "选择本机图片", font=f_serif, fill=(244, 228, 192, 255))
    d2.rounded_rectangle([68, 526, 412, 570], radius=4, fill=(221, 208, 177, 255), outline=(150, 120, 72, 255), width=2)
    d2.text((178, 538), "用上次上传的图", font=f_serif, fill=(69, 61, 44, 255))
    s2.save(os.path.join(REF_DIR, "r3_ref_avatar_and_city_header.png"))

    # Sheet 3: Bottom NPC Dialogue Card with Dark-Jade Speaker Nameplate
    s3 = Image.new("RGBA", (480, 800), (24, 30, 24, 255))
    d3 = ImageDraw.Draw(s3)
    d3.rounded_rectangle([20, 604, 460, 764], radius=6, fill=(28, 34, 38, 255), outline=(204, 164, 92, 255), width=3)
    d3.rounded_rectangle([26, 610, 454, 758], radius=4, fill=(241, 234, 215, 255), outline=(184, 148, 86, 255), width=2)
    s3.paste(nameplate, (38, 618), nameplate)
    d3.text((58, 622), "小满 · 城中孩童", font=f_serif, fill=(246, 228, 186, 255))
    d3.rounded_rectangle([38, 656, 114, 732], radius=4, fill=(32, 57, 56, 255), outline=(212, 174, 98, 255), width=2)
    d3.text((126, 658), "我的风铃！风一吹就响的那个……昨天\n在古道玩，回来就找不到了。你帮我看\n看，好不好？", font=f_sm, fill=(58, 42, 20, 255))
    s3.save(os.path.join(REF_DIR, "r3_ref_npc_dialog_nameplate.png"))

    # Sheet 4: Save Recovery Modal & Frost Herb Contract Final Polish
    s4 = Image.new("RGBA", (480, 800), (18, 20, 22, 255))
    d4 = ImageDraw.Draw(s4)
    d4.rounded_rectangle([36, 176, 444, 624], radius=6, fill=(28, 34, 38, 255), outline=(204, 164, 92, 255), width=3)
    d4.rounded_rectangle([44, 184, 436, 616], radius=4, fill=(241, 234, 215, 255), outline=(184, 148, 86, 255), width=2)
    s4.paste(plaque, (60, 196), plaque)
    d4.text((142, 201), "请使用更新版本读取", font=f_art, fill=(246, 225, 178, 255))
    s4.paste(divider, (80, 242), divider)
    c_modal = subcard.resize((364, 260), Image.Resampling.NEAREST)
    s4.paste(c_modal, (58, 262), c_modal)
    d4.text((74, 280), "此存档来自更新的游戏版本，已兼容读取可识别\n的进度。\n\n为保留全部投入与未知字段，本版本暂不允许继\n续写盘。\n\n请用更新版本继续，或导入本版本支持的旧档。", font=f_sm, fill=(58, 44, 30, 255))
    d4.rounded_rectangle([76, 544, 226, 588], radius=4, fill=(221, 208, 177, 255), outline=(150, 120, 72, 255), width=2)
    d4.text((118, 556), "返回标题", font=f_serif, fill=(58, 44, 30, 255))
    d4.rounded_rectangle([250, 544, 400, 588], radius=4, fill=(35, 71, 70, 255), outline=(198, 160, 88, 255), width=2)
    d4.text((292, 556), "导入旧档", font=f_serif, fill=(244, 228, 192, 255))
    s4.save(os.path.join(REF_DIR, "r3_ref_save_modal_and_ledger.png"))

    master = Image.new("RGBA", (960, 1600), (14, 12, 10, 255))
    master.paste(s1, (0, 0))
    master.paste(s2, (480, 0))
    master.paste(s3, (0, 800))
    master.paste(s4, (480, 800))
    master.save(os.path.join(REF_DIR, "r3_reference_master_board.png"))
    print("Round 3 assets and reference sheets generated successfully.")


if __name__ == "__main__":
    make_speaker_nameplate_jade()
    build_r3_reference_sheets()
