#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成「战斗胜败结算」「驿路与传世」「演武校场」三套成熟像素RPG复合风格素材、目标参考图板与多轮演进对比长图。
核心升级：
1. 彻底摒弃程序化几何圆圈与 1px 单线黑框，100% 融合项目原生像素九宫格与雕花资产
   （settings_20261014 / kit_20261013 / introduction_20261015 / minigames）。
2. 引入四重字体层次：
   - 毛笔行书 (MaShanZheng-Regular.ttf)：主匾额、大印章、对决「战」字
   - 宋刻衬线 (NotoSerifCJKsc-SemiBold.otf)：分栏横幅、卡片主标题、主次按钮
   - 硬朗展示数字体 (ZCOOLQingKeHuangYou-Regular.ttf)：战报四维大数字、战利品数量、段位分、保底计数、等级
   - 清晰黑体 (NotoSansSC-Regular/Bold.otf)：次要说明、战术要点
3. 生成篆刻朱砂方印 (seal_stamps.png：凯旋/整备/武魁/传世) 与演武擂台对决实景底板 (arena_duel_stage.png)。
"""

import os
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = r"D:\new bee\远征"
SETTLE_DIR = os.path.join(ROOT, "assets", "ui", "battle_settle")
JOURNEY_DIR = os.path.join(ROOT, "assets", "ui", "journey_relic")
ARENA_DIR = os.path.join(ROOT, "assets", "ui", "arena_v2")
REF_DIR = os.path.join(ROOT, "docs", "agent_iteration", "references")
BEFORE_DIR = os.path.join(ROOT, "docs", "agent_iteration", "screenshots", "before")
AFTER_DIR = os.path.join(ROOT, "docs", "agent_iteration", "screenshots", "after")
COMP_DIR = os.path.join(ROOT, "docs", "agent_iteration", "screenshots", "comparisons")

SET_KIT = os.path.join(ROOT, "assets", "ui", "settings_20261014")
UI_KIT = os.path.join(ROOT, "assets", "ui", "kit_20261013")
INTRO_KIT = os.path.join(ROOT, "assets", "ui", "introduction_20261015")
MINI_DIR = os.path.join(ROOT, "assets", "ui", "minigames")
READY_DIR = os.path.join(ROOT, "image", "world_props_20261012", "ready")
PIXEL_ICONS = os.path.join(ROOT, "assets", "ui", "pixel_icons")
FONT_DIR = os.path.join(ROOT, "assets", "fonts")


def load_project_font(kind: str, size: int) -> ImageFont.FreeTypeFont:
    mapping = {
        "art": os.path.join(FONT_DIR, "MaShanZheng-Regular.ttf"),
        "serif": os.path.join(FONT_DIR, "NotoSerifCJKsc-SemiBold.otf"),
        "display": os.path.join(FONT_DIR, "ZCOOLQingKeHuangYou-Regular.ttf"),
        "bold": os.path.join(FONT_DIR, "NotoSansSC-Bold.otf"),
        "reg": os.path.join(FONT_DIR, "NotoSansSC-Regular.otf"),
    }
    p = mapping.get(kind, mapping["reg"])
    if os.path.exists(p):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()


def safe_open(path: str, fallback_size=(64, 64)) -> Image.Image:
    if os.path.exists(path):
        return Image.open(path).convert("RGBA")
    return Image.new("RGBA", fallback_size, (0, 0, 0, 0))


def trim_alpha(im: Image.Image) -> Image.Image:
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else im


def fit_rgba(im: Image.Image, max_w: int, max_h: int, nearest=True) -> Image.Image:
    im = trim_alpha(im)
    if im.width == 0 or im.height == 0:
        return Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0))
    scale = min(max_w / im.width, max_h / im.height)
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resample = Image.Resampling.NEAREST if nearest else Image.Resampling.LANCZOS
    return im.resize((nw, nh), resample)


def nine_slice_paste(src: Image.Image, dst_size: tuple[int, int], margins: tuple[int, int, int, int]) -> Image.Image:
    """将九宫格像素素材缩放/平铺到目标尺寸，保留像素边角质感"""
    tw, th = dst_size
    ml, mt, mr, mb = margins
    sw, sh = src.size
    out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))

    sx = [0, ml, sw - mr, sw]
    sy = [0, mt, sh - mb, sh]
    dx = [0, ml, max(ml, tw - mr), tw]
    dy = [0, mt, max(mt, th - mb), th]

    for iy in range(3):
        for ix in range(3):
            w = dx[ix + 1] - dx[ix]
            h = dy[iy + 1] - dy[iy]
            if w <= 0 or h <= 0:
                continue
            patch = src.crop((sx[ix], sy[iy], sx[ix + 1], sy[iy + 1]))
            if patch.width > 0 and patch.height > 0:
                patch_resized = patch.resize((w, h), Image.Resampling.NEAREST)
                out.alpha_composite(patch_resized, (dx[ix], dy[iy]))
    return out


def find_generated_sprite(prefix: str) -> Image.Image:
    gen_dir = os.path.join(ROOT, "image", "generated")
    if os.path.exists(gen_dir):
        for fn in sorted(os.listdir(gen_dir)):
            if fn.startswith(prefix) and fn.endswith(".png"):
                return safe_open(os.path.join(gen_dir, fn))
    hd_dir = os.path.join(ROOT, "assets", "ui", "full_review_fixes_20261009", "pet_show")
    if os.path.exists(hd_dir):
        for fn in sorted(os.listdir(hd_dir)):
            if fn.startswith(prefix) and fn.endswith(".png"):
                return safe_open(os.path.join(hd_dir, fn))
    return Image.new("RGBA", (64, 64), (0, 0, 0, 0))


def _make_single_seal(txt: str, bg_col: tuple, ink_col: tuple, rng) -> Image.Image:
    f_seal = load_project_font("art", 22)
    stamp = Image.new("RGBA", (56, 56), (0, 0, 0, 0))
    d = ImageDraw.Draw(stamp)
    d.rectangle([6, 6, 49, 49], fill=bg_col, outline=(242, 182, 112, 255), width=2)
    d.rectangle([9, 9, 46, 46], outline=ink_col, width=1)
    for cx, cy in [(6, 6), (48, 6), (6, 48), (48, 48)]:
        d.rectangle([cx, cy, cx + 1, cy + 1], fill=(0, 0, 0, 0))
    d.text((28, 28), txt, font=f_seal, fill=ink_col, anchor="mm")
    arr = np.array(stamp)
    noise = rng.random((56, 56))
    mask = (arr[:, :, 3] > 0) & (noise < 0.08)
    arr[mask, 3] = np.clip(arr[mask, 3].astype(np.int32) - 90, 40, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA").rotate(5, resample=Image.Resampling.NEAREST, expand=False)


def build_seal_stamps() -> Image.Image:
    """构建 224x56 (4帧x56x56) 传统朱砂篆刻方印：凯旋 / 整备 / 武魁 / 传世"""
    sheet = Image.new("RGBA", (224, 56), (0, 0, 0, 0))
    words = [
        ("凯旋", (196, 44, 34, 245), (255, 232, 198, 255)),
        ("整备", (152, 56, 44, 240), (244, 218, 190, 255)),
        ("武魁", (202, 48, 36, 245), (255, 236, 196, 255)),
        ("传世", (192, 64, 32, 245), (255, 238, 198, 255)),
    ]
    rng = np.random.default_rng(20261018)
    for idx, (txt, bg_col, ink_col) in enumerate(words):
        stamp = _make_single_seal(txt, bg_col, ink_col, rng)
        sheet.alpha_composite(stamp, (idx * 56, 0))
    return sheet


def _make_scenic_banner_frame(w: int, h: int) -> Image.Image:
    """使用 btn_row 九宫格云锦底板 + reading_panel 雕花金角构建无双环重影的实景横幅底框"""
    btn_row = safe_open(os.path.join(SET_KIT, "btn_row.png"), (104, 53))
    base = nine_slice_paste(btn_row, (w, h), (16, 12, 16, 12))
    return base


def _overlay_gold_corners(base: Image.Image) -> Image.Image:
    w, h = base.size
    prof = safe_open(os.path.join(SET_KIT, "profile_card.png"), (445, 107))
    frame_only = nine_slice_paste(prof, (w, h), (28, 12, 28, 12))
    f_arr = np.array(frame_only)
    edge_mask = np.zeros((h, w), dtype=bool)
    edge_mask[:5, :] = True
    edge_mask[-5:, :] = True
    edge_mask[:, :5] = True
    edge_mask[:, -5:] = True
    edge_mask[:18, :18] = True
    edge_mask[:18, -18:] = True
    edge_mask[-18:, :18] = True
    edge_mask[-18:, -18:] = True
    f_arr[~edge_mask, 3] = 0
    base.alpha_composite(Image.fromarray(f_arr, "RGBA"))
    return base


def _apply_text_zone_shade(base: Image.Image) -> Image.Image:
    """在 x:88..324 压一层柔和深色渐变，确保左侧与中部的多字体文案、血条100%高对比清晰"""
    w, h = base.size
    arr = np.array(base, dtype=np.float32)
    xx = np.arange(w, dtype=np.float32)[None, :]
    shade = np.ones((1, w), dtype=np.float32)
    mask_zone = (xx >= 88) & (xx <= 324)
    t = np.clip((xx - 88.0) / 236.0, 0.0, 1.0)
    factor = 0.50 + 0.50 * np.clip((t - 0.62) / 0.38, 0.0, 1.0)
    shade = np.where(mask_zone, factor, 1.0)
    arr[6 : h - 6, :, :3] = arr[6 : h - 6, :, :3] * shade[:, :, None]
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def build_victory_header_banner(seals: Image.Image) -> Image.Image:
    """构建 404x108 战斗胜利像素实景横幅（云锦金角底框 + 林间祭坛 + 角色/灵兽凯旋 + 勋章金环）"""
    w, h = 404, 108
    base = _make_scenic_banner_frame(w, h)

    # 右半幅叠入林间晨曦战场与祭坛实景
    battle_bg = safe_open(os.path.join(ROOT, "image", "battle", "art_v2", "forest_clearing.png"), (w, h))
    bw, bh = battle_bg.size
    scenic = battle_bg.crop((int(bw * 0.1), int(bh * 0.22), int(bw * 0.9), int(bh * 0.65))).resize((246, h - 8), Image.Resampling.NEAREST)
    scenic = ImageEnhance.Brightness(scenic).enhance(0.96)
    s_arr = np.array(scenic, dtype=np.float32)
    xx = np.linspace(0.0, 1.0, scenic.width)[None, :]
    alpha_ramp = np.clip((xx - 0.12) / 0.42, 0.0, 1.0)
    s_arr[:, :, 3] = s_arr[:, :, 3] * alpha_ramp * 0.86
    scenic = Image.fromarray(s_arr.astype(np.uint8), "RGBA")
    base.alpha_composite(scenic, (w - 250, 4))

    # 祭坛、红枫与灵兽点缀右侧实景舞台（向右微移，避开左侧文案）
    landmarks = safe_open(os.path.join(ROOT, "assets", "ui", "travel_chest_b3", "landmarks.png"), (1448, 1086))
    if landmarks.width >= 1086:
        maple_sp = fit_rgba(landmarks.crop((362, 35, 724, 362)), 68, 64)
        base.alpha_composite(maple_sp, (w - 118, 22))
    pet = fit_rgba(find_generated_sprite("pet_rockturtle_hd"), 50, 50)
    base.alpha_composite(pet, (w - 74, 44))

    base = _apply_text_zone_shade(base)

    # 左侧勋章金环：叠入 sortie_medal 与主角英姿
    medal = safe_open(os.path.join(UI_KIT, "sortie_medal.png"), (84, 84)).resize((80, 80), Image.Resampling.NEAREST)
    base.alpha_composite(medal, (14, 14))
    hero_sheet = safe_open(os.path.join(ROOT, "image", "role", "zs", "pojun_idle.png"), (256, 64))
    if hero_sheet.width >= 64:
        frame_w = hero_sheet.width // 4
        hero_f0 = hero_sheet.crop((0, 0, frame_w, hero_sheet.height))
        hero_sp = fit_rgba(hero_f0, 56, 56)
        base.alpha_composite(hero_sp, (14 + (80 - hero_sp.width) // 2, 14 + (80 - hero_sp.height) // 2 - 2))

    _overlay_gold_corners(base)
    seal0 = seals.crop((0, 0, 56, 56)).resize((46, 46), Image.Resampling.NEAREST)
    base.alpha_composite(seal0, (w - 54, 8))
    return base


def build_defeat_header_banner(seals: Image.Image) -> Image.Image:
    """构建 404x108 战斗战败像素实景横幅（月夜残碑 + 孤灯营寨 + 折戟铁章 + 整备朱印）"""
    w, h = 404, 108
    base = _make_scenic_banner_frame(w, h)

    # 右侧叠入古碑与孤灯营寨
    stele_sheet = safe_open(os.path.join(MINI_DIR, "stele_monument_sheet.png"), (240, 140))
    stele0 = stele_sheet.crop((0, 0, min(120, stele_sheet.width), stele_sheet.height))
    stele_sp = fit_rgba(stele0, 72, 82)
    base.alpha_composite(stele_sp, (w - 124, 14))

    base = _apply_text_zone_shade(base)

    # 左侧勋章环：冷铁暗金质感 + 护盾双剑徽记
    medal = safe_open(os.path.join(UI_KIT, "sortie_medal.png"), (84, 84)).resize((80, 80), Image.Resampling.NEAREST)
    medal_desat = ImageEnhance.Color(medal).enhance(0.45)
    medal_dark = ImageEnhance.Brightness(medal_desat).enhance(0.82)
    base.alpha_composite(medal_dark, (14, 14))

    shield_ic = fit_rgba(safe_open(os.path.join(SET_KIT, "ic_sec_battle.png")), 40, 40)
    base.alpha_composite(shield_ic, (14 + (80 - shield_ic.width) // 2, 14 + (80 - shield_ic.height) // 2))

    _overlay_gold_corners(base)
    seal1 = seals.crop((56, 0, 112, 56)).resize((46, 46), Image.Resampling.NEAREST)
    base.alpha_composite(seal1, (w - 54, 8))
    return base


def build_reward_badge_icons() -> Image.Image:
    """构建 192x48 (4帧x48x48) 战利品槽位图标（金币/远征币/灵魂石/历练经验，采用 kit_20261013 品质框）"""
    sheet = Image.new("RGBA", (192, 48), (0, 0, 0, 0))
    slots = ["slot_legend.png", "slot_uncommon.png", "slot_epic.png", "slot_rare.png"]
    icons = [
        os.path.join(PIXEL_ICONS, "coin.png"),
        os.path.join(PIXEL_ICONS, "expedition.png"),
        os.path.join(PIXEL_ICONS, "soul.png"),
        os.path.join(PIXEL_ICONS, "book.png"),
    ]
    for idx, (s_fn, ic_path) in enumerate(zip(slots, icons)):
        slot_im = safe_open(os.path.join(UI_KIT, s_fn), (48, 48)).resize((48, 48), Image.Resampling.NEAREST)
        ic_im = fit_rgba(safe_open(ic_path), 28, 28)
        slot_im.alpha_composite(ic_im, ((48 - ic_im.width) // 2, (48 - ic_im.height) // 2))
        sheet.alpha_composite(slot_im, (idx * 48, 0))
    return sheet


def build_journey_travel_banner(seals: Image.Image) -> Image.Image:
    """构建 404x102 驿路行辕实景横幅（云锦金角底框 + 边城驿站/红枫古道地标 + 金环车马徽 + 驿路朱砂印）"""
    w, h = 404, 102
    base = _make_scenic_banner_frame(w, h)

    landmarks = safe_open(os.path.join(ROOT, "assets", "ui", "travel_chest_b3", "landmarks.png"), (1448, 1086))
    if landmarks.width >= 1086:
        maple_sp = fit_rgba(landmarks.crop((362, 35, 724, 362)), 68, 64)
        town_sp = fit_rgba(landmarks.crop((0, 33, 362, 362)), 78, 72)
        base.alpha_composite(maple_sp, (w - 134, 20))
        base.alpha_composite(town_sp, (w - 94, 16))

    base = _apply_text_zone_shade(base)

    medal = safe_open(os.path.join(UI_KIT, "sortie_medal.png"), (84, 84)).resize((76, 76), Image.Resampling.NEAREST)
    base.alpha_composite(medal, (14, 13))
    if landmarks.width >= 362:
        emblem_sp = fit_rgba(landmarks.crop((0, 33, 362, 362)), 48, 48)
        base.alpha_composite(emblem_sp, (14 + (76 - emblem_sp.width) // 2, 13 + (76 - emblem_sp.height) // 2))

    _overlay_gold_corners(base)
    rng = np.random.default_rng(20261019)
    seal_trv = _make_single_seal("驿路", (188, 52, 36, 245), (255, 236, 198, 255), rng).resize((44, 44), Image.Resampling.NEAREST)
    base.alpha_composite(seal_trv, (w - 50, 8))
    return base


def build_journey_hunt_banner(seals: Image.Image) -> Image.Image:
    """构建 404x102 传世圣坛实景横幅（古碑圣坛 + 归路圣鹿 + 神兵赤金勋章 + 传世朱印）"""
    w, h = 404, 102
    base = _make_scenic_banner_frame(w, h)

    # 右半幅叠入古碑鉴宝圣坛实景
    stage_bg = safe_open(os.path.join(MINI_DIR, "curio_stage_bg.png"), (408, 212))
    sw, sh = stage_bg.size
    scenic = stage_bg.crop((0, int(sh * 0.08), sw, int(sh * 0.78))).resize((236, h - 8), Image.Resampling.NEAREST)
    s_arr = np.array(scenic, dtype=np.float32)
    xx = np.linspace(0.0, 1.0, scenic.width)[None, :]
    s_arr[:, :, 3] = s_arr[:, :, 3] * np.clip((xx - 0.10) / 0.38, 0.0, 1.0) * 0.85
    base.alpha_composite(Image.fromarray(s_arr.astype(np.uint8), "RGBA"), (w - 240, 4))

    deer = fit_rgba(find_generated_sprite("pet_return_deer_hd"), 66, 66)
    base.alpha_composite(deer, (w - 102, 18))

    base = _apply_text_zone_shade(base)

    # 左侧赤金勋章 + 传世双剑
    medal = safe_open(os.path.join(UI_KIT, "sortie_medal.png"), (84, 84)).resize((76, 76), Image.Resampling.NEAREST)
    base.alpha_composite(medal, (14, 13))
    swords = fit_rgba(safe_open(os.path.join(SET_KIT, "ic_sec_battle.png")), 40, 40)
    base.alpha_composite(swords, (14 + (76 - swords.width) // 2, 13 + (76 - swords.height) // 2))

    _overlay_gold_corners(base)
    seal3 = seals.crop((168, 0, 224, 56)).resize((44, 44), Image.Resampling.NEAREST)
    base.alpha_composite(seal3, (w - 50, 8))
    return base


def build_relic_showcase_icons() -> Image.Image:
    """构建 192x64 (3帧x64x64) 传世神兵 / 归路圣鹿 / 驿路行辕 品质槽徽记"""
    sheet = Image.new("RGBA", (192, 64), (0, 0, 0, 0))
    slot_leg = safe_open(os.path.join(UI_KIT, "slot_legend.png"), (64, 64)).resize((64, 64), Image.Resampling.NEAREST)
    slot_ep = safe_open(os.path.join(UI_KIT, "slot_epic.png"), (64, 64)).resize((64, 64), Image.Resampling.NEAREST)
    slot_ra = safe_open(os.path.join(UI_KIT, "slot_rare.png"), (64, 64)).resize((64, 64), Image.Resampling.NEAREST)

    # Frame 0: 传世神兵
    c0 = slot_leg.copy()
    sw = fit_rgba(safe_open(os.path.join(SET_KIT, "ic_sec_battle.png")), 40, 40)
    c0.alpha_composite(sw, ((64 - sw.width) // 2, (64 - sw.height) // 2))
    sheet.alpha_composite(c0, (0, 0))

    # Frame 1: 归路圣鹿
    c1 = slot_ep.copy()
    deer = fit_rgba(find_generated_sprite("pet_return_deer_hd"), 46, 46)
    c1.alpha_composite(deer, ((64 - deer.width) // 2, (64 - deer.height) // 2))
    sheet.alpha_composite(c1, (64, 0))

    # Frame 2: 驿路车马
    c2 = slot_ra.copy()
    horse = fit_rgba(safe_open(os.path.join(ROOT, "image", "mount", "mount_horse.png")), 44, 44)
    c2.alpha_composite(horse, ((64 - horse.width) // 2, (64 - horse.height) // 2))
    sheet.alpha_composite(c2, (128, 0))
    return sheet


def build_arena_duel_stage(seals: Image.Image) -> Image.Image:
    """构建 404x138 演武校场实景对决擂台底板（校场靶场实景 + 旌旗垂幡金角框 + 左右石砌战台）"""
    w, h = 404, 138
    range_bg = safe_open(os.path.join(MINI_DIR, "archery_range_bg.png"), (w, h))
    rw, rh = range_bg.size
    bg = range_bg.crop((0, int(rh * 0.12), rw, int(rh * 0.88))).resize((w, h), Image.Resampling.NEAREST)
    bg = ImageEnhance.Brightness(bg).enhance(0.88)

    # 压一层深色演武场暗角，突出左右对决角色与中央战印
    arr = np.array(bg, dtype=np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    vignette = np.clip(1.0 - 0.35 * (((xx - w * 0.5) / (w * 0.55)) ** 2 + ((yy - h * 0.5) / (h * 0.6)) ** 2), 0.55, 1.0)
    arr[:, :, :3] = arr[:, :, :3] * vignette[:, :, None]
    # 底部石阶铭牌暗带
    arr[h - 30 : h, :, :3] = arr[h - 30 : h, :, :3] * 0.32
    bg = Image.fromarray(arr.astype(np.uint8), "RGBA")

    # 左右演武石台底座
    pool = safe_open(os.path.join(ROOT, "assets", "ui", "travel_chest_b1", "stage_pool.png"), (120, 32))
    p_resized = fit_rgba(pool, 124, 34)
    bg.alpha_composite(p_resized, (28, h - 52))
    bg.alpha_composite(p_resized, (w - 28 - p_resized.width, h - 52))

    # 叠入 reading_panel 的赤金垂幡与金角边框
    reading = safe_open(os.path.join(INTRO_KIT, "reading_panel.png"), (492, 199))
    r_frame = nine_slice_paste(reading, (w, h), (48, 98, 48, 25))
    r_arr = np.array(r_frame)
    inner_mask = np.zeros((h, w), dtype=bool)
    inner_mask[8 : h - 8, 38 : w - 38] = True
    r_arr[inner_mask, 3] = (r_arr[inner_mask, 3].astype(np.float32) * 0.15).astype(np.uint8)
    bg.alpha_composite(Image.fromarray(r_arr, "RGBA"))

    # 中央对决金章底座
    medal = safe_open(os.path.join(UI_KIT, "sortie_medal.png"), (64, 64)).resize((54, 54), Image.Resampling.NEAREST)
    bg.alpha_composite(medal, ((w - 54) // 2, 26))
    return bg


def build_reference_sheets(vic_banner, def_banner, badge_sheet, travel_banner, hunt_banner, relic_icons, arena_stage, seals):
    """使用项目真实四重字体与九宫格像素素材，生成三张高水准目标设计参考图板"""
    f_art_lg = load_project_font("art", 28)
    f_art_md = load_project_font("art", 22)
    f_serif_lg = load_project_font("serif", 20)
    f_serif_md = load_project_font("serif", 16)
    f_serif_sm = load_project_font("serif", 14)
    f_disp_lg = load_project_font("display", 22)
    f_disp_md = load_project_font("display", 18)
    f_reg_sm = load_project_font("reg", 13)

    panel_iron = safe_open(os.path.join(UI_KIT, "panel_iron.png"), (256, 256))
    plaque_title = safe_open(os.path.join(UI_KIT, "plaque_title.png"), (264, 96))
    sec_bar = safe_open(os.path.join(SET_KIT, "section.png"), (104, 44))
    btn_row = safe_open(os.path.join(SET_KIT, "btn_row.png"), (104, 53))
    quest_slip = safe_open(os.path.join(UI_KIT, "quest_slip.png"), (256, 72))
    button_red = safe_open(os.path.join(INTRO_KIT, "button_red.png"), (236, 76))
    button_dark = safe_open(os.path.join(INTRO_KIT, "button_dark.png"), (236, 76))

    # 1. 战斗结算目标设计图板
    b1 = Image.new("RGBA", (1040, 880), (16, 13, 18, 255))
    d1 = ImageDraw.Draw(b1)
    d1.rectangle([0, 0, 1039, 52], fill=(28, 20, 24, 255))
    d1.line([(0, 52), (1039, 52)], fill=(214, 168, 86, 255), width=2)
    d1.text((24, 26), "战斗结算精修参考图（四重字体层次 + 像素九宫格木铁雕花 + 凯旋/整备朱砂篆印）", font=f_serif_lg, fill=(248, 218, 142), anchor="lm")

    for idx, (is_win, x0) in enumerate([(True, 28), (False, 532)]):
        card = nine_slice_paste(panel_iron, (480, 780), (36, 36, 36, 36))
        plq = plaque_title.resize((310, 56), Image.Resampling.NEAREST)
        card.alpha_composite(plq, (85, 14))
        cd = ImageDraw.Draw(card)
        cd.text((240, 42), "凯 旋 战 报" if is_win else "折 戟 整 备", font=f_art_lg, fill=(255, 232, 168) if is_win else (240, 196, 172), anchor="mm")
        card.alpha_composite(vic_banner if is_win else def_banner, (38, 80))
        cd.text((146, 108), "破军行者", font=f_serif_md, fill=(255, 242, 212), anchor="lm")
        cd.text((224, 108), "Lv.18", font=f_disp_md, fill=(255, 212, 118), anchor="lm")
        cd.text((146, 136), "残存生命 632/810 · 岩龟" if is_win else "残存生命 0/810 · 岩龟", font=f_reg_sm, fill=(142, 232, 168) if is_win else (232, 152, 138), anchor="lm")

        s1 = nine_slice_paste(sec_bar, (404, 38), (16, 8, 48, 8))
        card.alpha_composite(s1, (38, 198))
        cd.text((78, 217), "四维战功录", font=f_serif_md, fill=(246, 232, 204), anchor="lm")

        stats = [("战斗用时", "14.6", "秒"), ("最高单击", "685", "伤害"), ("我方输出", "2840", "总伤"), ("承受伤害", "412", "战损")]
        for si, (k, v, u) in enumerate(stats):
            sx = 38 + (si % 2) * 206
            sy = 244 + (si // 2) * 58
            st_box = nine_slice_paste(btn_row, (198, 52), (12, 8, 12, 8))
            card.alpha_composite(st_box, (sx, sy))
            cd.text((sx + 14, sy + 26), k, font=f_serif_sm, fill=(204, 190, 166), anchor="lm")
            cd.text((sx + 148, sy + 25), v, font=f_disp_lg, fill=(255, 222, 132), anchor="rm")
            cd.text((sx + 154, sy + 26), u, font=f_reg_sm, fill=(186, 174, 154), anchor="lm")

        s2 = nine_slice_paste(sec_bar, (404, 38), (16, 8, 48, 8))
        card.alpha_composite(s2, (38, 368))
        cd.text((78, 387), "凯旋战利品" if is_win else "破敌整备策", font=f_serif_md, fill=(246, 232, 204), anchor="lm")

        if is_win:
            r_items = [("金币", "+480"), ("远征币", "+36"), ("灵魂石", "+8"), ("历练经验", "+320")]
            for ri, (rn, rv) in enumerate(r_items):
                rx = 38 + ri * 103
                ry = 414
                r_box = nine_slice_paste(btn_row, (95, 118), (12, 8, 12, 8))
                card.alpha_composite(r_box, (rx, ry))
                ic = badge_sheet.crop((ri * 48, 0, (ri + 1) * 48, 48))
                card.alpha_composite(ic, (rx + 23, ry + 10))
                cd.text((rx + 47, ry + 74), rn, font=f_serif_sm, fill=(226, 214, 192), anchor="mm")
                cd.text((rx + 47, ry + 98), rv, font=f_disp_lg, fill=(255, 218, 116), anchor="mm")
        else:
            tips = [
                ("铁匠锻造", "前往铁匠铺强化武器防具、精炼高阶词条"),
                ("灵兽协战", "喂养与升星出战灵兽，分担承伤补充护盾"),
                ("招式药剂", "调整破绽爆发技能衔接，备齐药剂再战"),
            ]
            for ti, (tk, tv) in enumerate(tips):
                ty = 414 + ti * 42
                slip = nine_slice_paste(quest_slip, (404, 38), (28, 10, 16, 10))
                card.alpha_composite(slip, (38, ty))
                cd.text((72, ty + 19), tk, font=f_serif_sm, fill=(92, 42, 24), anchor="lm")
                cd.text((142, ty + 19), tv, font=f_reg_sm, fill=(62, 46, 32), anchor="lm")

        cta = button_red.resize((248, 52), Image.Resampling.NEAREST) if is_win else button_dark.resize((248, 52), Image.Resampling.NEAREST)
        card.alpha_composite(cta, (116, 568))
        cd.text((240, 594), "继 续 征 途" if is_win else "整 备 再 战", font=f_serif_lg, fill=(255, 242, 212), anchor="mm")
        b1.alpha_composite(card, (x0, 72))

    b1.convert("RGB").save(os.path.join(REF_DIR, "ref_battle_settlement_v2.png"), "PNG")

    # 2. 演武校场目标设计图板
    b3 = Image.new("RGBA", (540, 880), (16, 13, 18, 255))
    d3 = ImageDraw.Draw(b3)
    d3.rectangle([0, 0, 539, 52], fill=(28, 20, 24, 255))
    d3.line([(0, 52), (539, 52)], fill=(214, 168, 86, 255), width=2)
    d3.text((20, 26), "演武校场精修参考图（擂台实景对决 + 朱砂武魁印 + 四重字体）", font=f_serif_md, fill=(248, 218, 142), anchor="lm")

    acard = nine_slice_paste(panel_iron, (480, 780), (36, 36, 36, 36))
    plq = plaque_title.resize((300, 54), Image.Resampling.NEAREST)
    acard.alpha_composite(plq, (90, 14))
    ad = ImageDraw.Draw(acard)
    ad.text((240, 41), "演 武 校 场", font=f_art_lg, fill=(255, 232, 168), anchor="mm")
    acard.alpha_composite(arena_stage, (38, 78))
    ad.text((240, 131), "战", font=f_art_md, fill=(255, 236, 188), anchor="mm")
    ad.text((120, 198), "我方 · 破军行者 Lv.12", font=f_serif_sm, fill=(238, 226, 200), anchor="mm")
    ad.text((360, 198), "对手 · 演武傀儡 Lv.12", font=f_serif_sm, fill=(246, 208, 152), anchor="mm")

    rk_box = nine_slice_paste(btn_row, (404, 92), (16, 10, 16, 10))
    acard.alpha_composite(rk_box, (38, 224))
    seal2 = seals.crop((112, 0, 168, 56)).resize((46, 46), Image.Resampling.NEAREST)
    acard.alpha_composite(seal2, (384, 232))
    ad.text((104, 248), "铜印", font=f_serif_lg, fill=(255, 234, 186), anchor="lm")
    ad.text((162, 248), "1000", font=f_disp_lg, fill=(255, 212, 112), anchor="lm")
    ad.text((218, 249), "分 · 连胜 0", font=f_reg_sm, fill=(206, 194, 172), anchor="lm")
    ad.text((104, 286), "段位晋升 · 铜印 -> 银印（还差 100 分）", font=f_reg_sm, fill=(188, 216, 196), anchor="lm")

    sl1 = nine_slice_paste(quest_slip, (198, 44), (24, 8, 14, 8))
    sl2 = nine_slice_paste(quest_slip, (198, 44), (24, 8, 14, 8))
    acard.alpha_composite(sl1, (38, 326))
    acard.alpha_composite(sl2, (244, 326))
    ad.text((64, 348), "赛季荣誉 900 · 再胜3场+10", font=f_serif_sm, fill=(84, 42, 24), anchor="lm")
    ad.text((270, 348), "0胜 0负 · 胜率 0%", font=f_serif_sm, fill=(84, 42, 24), anchor="lm")

    b_reroll = button_dark.resize((134, 50), Image.Resampling.NEAREST)
    b_start = button_red.resize((258, 54), Image.Resampling.NEAREST)
    acard.alpha_composite(b_reroll, (38, 384))
    acard.alpha_composite(b_start, (184, 382))
    ad.text((105, 409), "换 对 手", font=f_serif_md, fill=(238, 224, 198), anchor="mm")
    ad.text((313, 409), "开 始 切 磋", font=f_serif_lg, fill=(255, 242, 210), anchor="mm")

    s_act = nine_slice_paste(sec_bar, (404, 36), (16, 8, 48, 8))
    acard.alpha_composite(s_act, (38, 448))
    ad.text((76, 466), "校场武备与古碑奇珍", font=f_serif_md, fill=(246, 232, 204), anchor="lm")

    f1 = nine_slice_paste(btn_row, (198, 74), (14, 10, 14, 10))
    f2 = nine_slice_paste(btn_row, (198, 74), (14, 10, 14, 10))
    acard.alpha_composite(f1, (38, 492))
    acard.alpha_composite(f2, (244, 492))
    ad.text((98, 518), "校场射艺", font=f_serif_md, fill=(255, 232, 182), anchor="lm")
    ad.text((98, 542), "挽弓测风 · 赢演武荣誉", font=f_reg_sm, fill=(192, 180, 160), anchor="lm")
    ad.text((304, 518), "古碑鉴宝", font=f_serif_md, fill=(255, 232, 182), anchor="lm")
    ad.text((304, 542), "参悟铭文 · 鉴古匣秘宝", font=f_reg_sm, fill=(192, 180, 160), anchor="lm")

    b_back = button_dark.resize((180, 44), Image.Resampling.NEAREST)
    acard.alpha_composite(b_back, (150, 582))
    ad.text((240, 604), "返 回 主 城", font=f_serif_md, fill=(238, 224, 198), anchor="mm")

    b3.alpha_composite(acard, (30, 72))
    b3.convert("RGB").save(os.path.join(REF_DIR, "ref_arena_v2.png"), "PNG")


def build_comparison_boards():
    os.makedirs(COMP_DIR, exist_ok=True)
    f_h1 = load_project_font("serif", 22)
    f_sub = load_project_font("bold", 14)

    a_vic = os.path.join(AFTER_DIR, "after_battle_victory.png")
    a_def = os.path.join(AFTER_DIR, "after_battle_defeat.png")
    a_trv = os.path.join(AFTER_DIR, "after_journey_travel.png")
    a_hnt = os.path.join(AFTER_DIR, "after_journey_hunt.png")
    a_arn = os.path.join(AFTER_DIR, "after_arena.png")

    if os.path.exists(a_vic) and os.path.exists(a_def):
        b1 = Image.new("RGBA", (2020, 910), (16, 12, 18, 255))
        d1 = ImageDraw.Draw(b1)
        d1.rectangle([0, 0, 2019, 54], fill=(34, 24, 28, 255))
        d1.line([(0, 54), (2019, 54)], fill=(214, 168, 86, 255), width=2)
        d1.text((24, 27), "战斗结算（战胜 / 战败）多轮精修前后实机对比图板（九宫格木铁雕花 + 朱砂篆印 + 四重字体层次）", font=f_h1, fill=(248, 216, 132), anchor="lm")
        cols1 = [
            ("重构前：战斗胜利（右侧裁切溢出、纯白底单字体）", os.path.join(BEFORE_DIR, "before_battle_victory.png"), (214, 146, 128)),
            ("精修后：战斗胜利（木匾毛笔题名 + 实景金环横幅 + 品质槽战利品）", a_vic, (132, 218, 158)),
            ("重构前：战斗战败（右侧裁切溢出、无整备指引）", os.path.join(BEFORE_DIR, "before_battle_defeat.png"), (214, 146, 128)),
            ("精修后：战斗战败（月夜残碑横幅 + 四维战功录 + 羊皮卷整备三策）", a_def, (132, 218, 158)),
        ]
        for idx, (label, path, col) in enumerate(cols1):
            cx = 20 + idx * 500
            d1.text((cx, 74), label, font=f_sub, fill=col, anchor="lm")
            im = safe_open(path, (480, 800)).resize((480, 800))
            b1.alpha_composite(im, (cx, 92))
        b1.convert("RGB").save(os.path.join(COMP_DIR, "comp_battle_settlement_v2.png"), "PNG")

    if os.path.exists(a_trv) and os.path.exists(a_hnt):
        b2 = Image.new("RGBA", (2020, 910), (16, 12, 18, 255))
        d2 = ImageDraw.Draw(b2)
        d2.rectangle([0, 0, 2019, 54], fill=(34, 24, 28, 255))
        d2.line([(0, 54), (2019, 54)], fill=(214, 168, 86, 255), width=2)
        d2.text((24, 27), "驿路与传世（已探索地点 / 传世挑战）多轮精修前后实机对比图板（云锦九宫格 + 羊皮签条 + 四重字体）", font=f_h1, fill=(248, 216, 132), anchor="lm")
        cols2 = [
            ("重构前：已探索地点（旧白纸单列按钮堆叠）", os.path.join(BEFORE_DIR, "before_journey_travel.png"), (214, 146, 128)),
            ("精修后：已探索地点（木匾毛笔题名 + 驿站实景 + 云锦/羊皮行辕卡）", a_trv, (132, 218, 158)),
            ("重构前：传世挑战（纯文字列表无首领与神兵圣鹿立绘）", os.path.join(BEFORE_DIR, "before_journey_hunt.png"), (214, 146, 128)),
            ("精修后：传世挑战（圣坛实景 + 雕花保底槽 + 首领/神兵/圣鹿展柜）", a_hnt, (132, 218, 158)),
        ]
        for idx, (label, path, col) in enumerate(cols2):
            cx = 20 + idx * 500
            d2.text((cx, 74), label, font=f_sub, fill=col, anchor="lm")
            im = safe_open(path, (480, 800)).resize((480, 800))
            b2.alpha_composite(im, (cx, 92))
        b2.convert("RGB").save(os.path.join(COMP_DIR, "comp_journey_relic_v2.png"), "PNG")

    if os.path.exists(a_arn):
        r1_arn = os.path.join(AFTER_DIR, "r1_arena.png")
        r2_arn = os.path.join(AFTER_DIR, "r2_arena.png")
        b3 = Image.new("RGBA", (2020, 910), (16, 12, 18, 255))
        d3 = ImageDraw.Draw(b3)
        d3.rectangle([0, 0, 2019, 54], fill=(34, 24, 28, 255))
        d3.line([(0, 54), (2019, 54)], fill=(214, 168, 86, 255), width=2)
        d3.text((24, 27), "演武场 UI 三轮迭代精修演进实机对比图板（重构前 -> 第一轮 -> 第二轮 -> 第三轮终版）", font=f_h1, fill=(248, 216, 132), anchor="lm")
        cols3 = [
            ("重构前：旧演武场（白纸单框 + 无擂台实景与角色对决）", os.path.join(BEFORE_DIR, "before_arena.png"), (214, 146, 128)),
            ("第一轮：九宫格云锦底板 + 四重字体层次重构", r1_arn if os.path.exists(r1_arn) else a_arn, (238, 198, 118)),
            ("第二轮：加入演武擂台对决舞台 + 角色与傀儡/镜影实景同台", r2_arn if os.path.exists(r2_arn) else a_arn, (152, 214, 238)),
            ("第三轮终版：鎏金木匾 + 武魁朱砂印 + 射艺/鉴宝双展卡 + 栏杆灯火", a_arn, (132, 218, 158)),
        ]
        for idx, (label, path, col) in enumerate(cols3):
            cx = 20 + idx * 500
            d3.text((cx, 74), label, font=f_sub, fill=col, anchor="lm")
            im = safe_open(path, (480, 800)).resize((480, 800))
            b3.alpha_composite(im, (cx, 92))
        b3.convert("RGB").save(os.path.join(COMP_DIR, "comp_arena_evolution_v2.png"), "PNG")


def main():
    os.makedirs(SETTLE_DIR, exist_ok=True)
    os.makedirs(JOURNEY_DIR, exist_ok=True)
    os.makedirs(ARENA_DIR, exist_ok=True)
    os.makedirs(REF_DIR, exist_ok=True)

    seals = build_seal_stamps()
    vic_banner = build_victory_header_banner(seals)
    def_banner = build_defeat_header_banner(seals)
    badge_sheet = build_reward_badge_icons()

    seals.save(os.path.join(SETTLE_DIR, "seal_stamps.png"), "PNG")
    vic_banner.save(os.path.join(SETTLE_DIR, "victory_header_banner.png"), "PNG")
    def_banner.save(os.path.join(SETTLE_DIR, "defeat_header_banner.png"), "PNG")
    badge_sheet.save(os.path.join(SETTLE_DIR, "reward_badge_icons.png"), "PNG")

    travel_banner = build_journey_travel_banner(seals)
    hunt_banner = build_journey_hunt_banner(seals)
    relic_icons = build_relic_showcase_icons()

    travel_banner.save(os.path.join(JOURNEY_DIR, "journey_travel_banner.png"), "PNG")
    hunt_banner.save(os.path.join(JOURNEY_DIR, "journey_hunt_banner.png"), "PNG")
    relic_icons.save(os.path.join(JOURNEY_DIR, "relic_showcase_icons.png"), "PNG")

    arena_stage = build_arena_duel_stage(seals)
    arena_stage.save(os.path.join(ARENA_DIR, "arena_duel_stage.png"), "PNG")

    build_reference_sheets(vic_banner, def_banner, badge_sheet, travel_banner, hunt_banner, relic_icons, arena_stage, seals)
    build_comparison_boards()
    print("ASSETS_AND_REFERENCES_V3_OK")


if __name__ == "__main__":
    main()
