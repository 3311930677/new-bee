#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用项目原生高精度像素美术资产（camp_sky.png / shrine.png / stele.png / stonebox.png /
pending_chest.png / barricade.png / lantern.png / windchime.png / nighttable.png）
合成并精修《远征》两大新增小游戏的专属场景贴图、交互精灵与视觉参考图板：

1. 校场射艺 (ArcheryPanel)：
   - assets/ui/minigames/archery_range_bg.png (480x320，月下边城校场演武坪 + 拒马木栏 + 铜灯笼 + 听风铜铃)
   - assets/ui/minigames/archery_target_sprite.png (144x168，原木麻绳三脚架 + 精细草靶五色漆环)
   - assets/ui/minigames/archery_bow_sheet.png (480x120，3帧x160x120 鎏金角弓：待机/半弦/满月甜区翠金气芒)
   - docs/agent_iteration/references/ref_minigame_archery_v2.png
2. 边城古碑共鸣 · 行商鉴宝 (CurioLoreOverlay)：
   - assets/ui/minigames/curio_stage_bg.png (408x212，左：苍古祭坛香炉石阶；右：行商木案灯火鉴宝席)
   - assets/ui/minigames/stele_monument_sheet.png (240x140，2帧x120x140：原生古碑蒙尘态 / 先祖金青铭文共鸣发光态)
   - assets/ui/minigames/curio_chests_sheet.png (288x96，3帧x96x96：蒙尘古石匣 / 鎏金秘宝匣 / 秘宝出世金辉态)
   - docs/agent_iteration/references/ref_minigame_curio_v2.png
"""
import os
import math
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MINI_DIR = os.path.join(ROOT, "assets", "ui", "minigames")
REF_DIR = os.path.join(ROOT, "docs", "agent_iteration", "references")
BEFORE_DIR = os.path.join(ROOT, "docs", "agent_iteration", "screenshots", "before")
AFTER_DIR = os.path.join(ROOT, "docs", "agent_iteration", "screenshots", "after")
READY_DIR = os.path.join(ROOT, "assets", "world", "reference_complete_20261011", "ready")
FONT_PATH = os.path.join(ROOT, "assets", "fonts", "NotoSerifCJKsc-SemiBold.otf")


def load_font(sz: int):
    try:
        return ImageFont.truetype(FONT_PATH, sz)
    except Exception:
        return ImageFont.load_default()


def fit_rgba(im: Image.Image, max_w: int, max_h: int) -> Image.Image:
    im = im.convert("RGBA")
    arr = np.array(im)
    ys, xs = np.where(arr[:, :, 3] > 16)
    if len(xs) > 0:
        im = im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    w, h = im.size
    scale = min(max_w / float(w), max_h / float(h))
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    return im.resize((nw, nh), Image.Resampling.NEAREST)


def build_archery_range_bg() -> Image.Image:
    """
    基于 camp_sky.png（月下边城校场石坪）与 barricade.png / lantern.png / windchime.png
    构建 480x320 校场射艺实景舞台背景。
    """
    camp = Image.open(os.path.join(ROOT, "assets", "ui", "travel_chest_b1", "camp_sky.png")).convert("RGBA")
    cw, ch = camp.size
    # 截取包含弦月远山、城楼拱门、火盆军帐与火光石坪的黄金构图区 (y: 22%..84%)
    crop_box = (0, int(ch * 0.22), cw, int(ch * 0.84))
    bg = camp.crop(crop_box).resize((480, 320), Image.Resampling.BILINEAR)

    # 两侧摆放木拒马围栏 (barricade.png) 强化校场靶场纵深感
    barricade = Image.open(os.path.join(READY_DIR, "barricade.png")).convert("RGBA")
    bar_s = fit_rgba(barricade, 84, 52)
    bar_flip = bar_s.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    bg.alpha_composite(bar_s, (18, 166))
    bg.alpha_composite(bar_flip, (480 - 18 - bar_s.width, 166))

    # 左上角悬挂听风铜铃木架 (windchime.png)，作为风向标底座
    windchime = Image.open(os.path.join(READY_DIR, "windchime.png")).convert("RGBA")
    wc_s = fit_rgba(windchime, 64, 84)
    bg.alpha_composite(wc_s, (14, 34))

    # 右上角悬挂边城铜灯笼 (lantern.png)
    lantern = Image.open(os.path.join(READY_DIR, "lantern.png")).convert("RGBA")
    lan_s = fit_rgba(lantern, 56, 82)
    lan_flip = lan_s.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    bg.alpha_composite(lan_flip, (480 - 14 - lan_flip.width, 34))

    # 在石坪中央绘制透视射道准线与百步刻度暗金标线
    overlay = Image.new("RGBA", (480, 320), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    # 射道左右透视虚线
    for step in range(12):
        t0 = step / 12.0
        t1 = (step + 0.55) / 12.0
        y0 = int(168 + t0 * 118)
        y1 = int(168 + t1 * 118)
        xL0 = int(240 - (48 + t0 * 96))
        xL1 = int(240 - (48 + t1 * 96))
        xR0 = int(240 + (48 + t0 * 96))
        xR1 = int(240 + (48 + t1 * 96))
        draw.line([(xL0, y0), (xL1, y1)], fill=(242, 199, 106, 85), width=2)
        draw.line([(xR0, y0), (xR1, y1)], fill=(242, 199, 106, 85), width=2)

    # 距离横刻线（百步 / 六十步 / 三十步）
    for ry, hw in [(184, 58), (218, 84), (256, 114)]:
        draw.line([(240 - hw, ry), (240 + hw, ry)], fill=(242, 199, 106, 68), width=1)

    # 底部石砌射台暗金压边 (y: 294..320)
    draw.rectangle([0, 296, 479, 319], fill=(22, 15, 11, 215))
    draw.line([(0, 296), (479, 296)], fill=(214, 168, 82, 220), width=2)
    draw.line([(0, 299), (479, 299)], fill=(96, 68, 34, 190), width=1)

    bg.alpha_composite(overlay)
    return bg


def build_archery_target_sprite() -> Image.Image:
    """
    结合 barricade.png 的真实木纹支架与精细像素草靶盘，生成 144x168 箭靶精灵。
    """
    im = Image.new("RGBA", (144, 168), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    px = im.load()

    # 地面柔和接触阴影
    for y in range(132, 162):
        for x in range(18, 126):
            dx = (x - 72) / 50.0
            dy = (y - 147) / 13.0
            d2 = dx * dx + dy * dy
            if d2 < 1.0:
                a = int((1.0 - d2) * 145)
                px[x, y] = (10, 6, 4, a)

    # 从 barricade.png 提取真实像素木桩腿与麻绳捆扎局部作为靶架底座
    bar = Image.open(os.path.join(READY_DIR, "barricade.png")).convert("RGBA")
    bar_legs = fit_rgba(bar, 118, 78)
    im.alpha_composite(bar_legs, ((144 - bar_legs.width) // 2, 82))

    # 在 72x72 像素网格绘制高精度草靶盘，再 2x NEAREST 放大到 132x132 叠在木架上方
    tw, th = 68, 68
    t_cell = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    tpx = t_cell.load()
    cx, cy = 34, 34

    for y in range(tw):
        for x in range(th):
            dx = x - cx
            dy = y - cy
            r = math.hypot(dx, dy)
            if r > 32.5:
                continue
            ang = math.atan2(dy, dx)
            # 顶部冷月光 + 底部火盆暖金受光
            warm_rim = max(0.0, dy / 32.0) * 26.0
            top_shade = max(0.0, -dy / 32.0) * 14.0
            grain = ((x * 5 + y * 3) % 4 - 1.5) * 3.5

            if r > 30.8:
                tpx[x, y] = (28, 16, 10, 255)  # 外轮廓深褐描边
            elif r > 27.2:
                # 编织草靶外圈 + 麻绳纹
                weave = math.sin(ang * 20.0 + r * 0.8) * 14.0
                rr = int(np.clip(174 + weave + warm_rim, 40, 255))
                gg = int(np.clip(132 + weave * 0.8 + warm_rim * 0.6, 30, 255))
                bb = int(np.clip(68 + weave * 0.4, 20, 255))
                tpx[x, y] = (rr, gg, bb, 255)
            elif r > 25.8:
                tpx[x, y] = (62, 38, 22, 255)  # 内木箍
            elif r > 20.6:
                # 2环：古宣羊皮色
                rr = int(np.clip(234 + grain + top_shade, 0, 255))
                gg = int(np.clip(218 + grain + top_shade * 0.8, 0, 255))
                bb = int(np.clip(184 + grain, 0, 255))
                tpx[x, y] = (rr, gg, bb, 255)
            elif r > 15.4:
                # 4环：玄铁乌漆
                rr = int(np.clip(46 + grain + warm_rim * 0.4, 0, 255))
                gg = int(np.clip(50 + grain + warm_rim * 0.3, 0, 255))
                bb = int(np.clip(62 + grain, 0, 255))
                tpx[x, y] = (rr, gg, bb, 255)
            elif r > 10.4:
                # 6环：靛青石色
                rr = int(np.clip(52 + grain, 0, 255))
                gg = int(np.clip(116 + grain + top_shade, 0, 255))
                bb = int(np.clip(174 + grain + top_shade, 0, 255))
                tpx[x, y] = (rr, gg, bb, 255)
            elif r > 5.4:
                # 8环：朱砂赤红
                rr = int(np.clip(214 + grain + warm_rim * 0.5, 0, 255))
                gg = int(np.clip(64 + grain, 0, 255))
                bb = int(np.clip(48 + grain, 0, 255))
                tpx[x, y] = (rr, gg, bb, 255)
            elif r > 1.8:
                # 10环：赤金红心
                tpx[x, y] = (252, 208, 78, 255)
            else:
                # 中心铜钉
                tpx[x, y] = (92, 28, 18, 255)

    # 四角麻绳绑扣
    for deg in [40, 140, 220, 320]:
        rad = math.radians(deg)
        for da in (-0.06, 0.0, 0.06):
            for rr in range(26, 32):
                xx = int(round(cx + math.cos(rad + da) * rr))
                yy = int(round(cy + math.sin(rad + da) * rr))
                if 0 <= xx < tw and 0 <= yy < th:
                    tpx[xx, yy] = (232, 198, 128, 255)

    target_disc = t_cell.resize((136, 136), Image.Resampling.NEAREST)
    im.alpha_composite(target_disc, (4, 2))
    return im


def build_archery_bow_sheet() -> Image.Image:
    """
    240x60 像素网格 (3帧 x 80x60) -> 2x NEAREST 放大为 480x120 (3帧 x 160x120)：
    雕花鎏金牛角反曲弓 + 赤羽长箭（待机 / 半弦 / 满月甜区翠金气芒）
    """
    fw, fh = 80, 60
    sheet = Image.new("RGBA", (fw * 3, fh), (0, 0, 0, 0))

    for f in range(3):
        cell = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        draw = ImageDraw.Draw(cell)
        px = cell.load()
        cx = 40
        pull = [0, 10, 19][f]
        bend = [0, 3, 6][f]

        tip_left = (8 + bend, 25 + bend)
        tip_right = (72 - bend, 25 + bend)
        grip_y = 19 - bend // 2

        for x in range(tip_left[0], tip_right[0] + 1):
            nx = (x - cx) / float(32 - bend)
            arch_y = int(round(grip_y + (nx * nx) * (11 + bend) - (nx ** 4) * 4.5))
            for dy in range(-3, 3):
                yy = arch_y + dy
                if 0 <= yy < fh:
                    if dy in (-3, 2):
                        px[x, yy] = (28, 14, 8, 255)
                    elif abs(x - cx) <= 6:
                        px[x, yy] = (242, 196, 88, 255) if dy == -2 else ((184, 132, 46, 255) if dy == -1 else (118, 52, 28, 255))
                    elif abs(nx) > 0.76:
                        px[x, yy] = (248, 206, 98, 255) if dy <= -1 else (178, 128, 42, 255)
                    else:
                        px[x, yy] = (188, 114, 54, 255) if dy == -2 else ((142, 78, 34, 255) if dy == -1 else (92, 48, 22, 255))

        nock_y = 26 + pull
        draw.line([tip_left, (cx, nock_y)], fill=(238, 226, 198, 255), width=1)
        draw.line([tip_right, (cx, nock_y)], fill=(238, 226, 198, 255), width=1)

        arrow_top_y = 3 + pull // 2
        if f == 2:
            for dx, dy in [(-6, 3), (6, 3), (-5, 0), (5, 0), (0, -2)]:
                draw.line([(cx, arrow_top_y + 3), (cx + dx, arrow_top_y + 3 + dy)], fill=(255, 226, 112, 220), width=1)
        draw.line([(cx, arrow_top_y + 6), (cx, nock_y + 2)], fill=(224, 192, 132, 255), width=2)
        draw.line([(cx - 1, arrow_top_y + 6), (cx - 1, nock_y + 2)], fill=(86, 56, 30, 255), width=1)
        draw.polygon(
            [(cx, arrow_top_y), (cx - 4, arrow_top_y + 7), (cx + 4, arrow_top_y + 7)],
            fill=(228, 238, 250, 255),
            outline=(34, 40, 52, 255),
        )
        for fy in range(nock_y - 7, nock_y + 2):
            span = 2 + (fy - (nock_y - 7)) // 2
            for sx in (-span, span):
                if 0 <= cx + sx < fw and 0 <= fy < fh:
                    px[cx + sx, fy] = (232, 74, 54, 255)

        sheet.paste(cell, (f * fw, 0))

    return sheet.resize((480, 120), Image.Resampling.NEAREST)


def build_curio_stage_bg() -> Image.Image:
    """
    结合 stele_cavern_floor.png + shrine.png（左半幅：边城先祖古碑石坛）
    与 camp_sky.png + nighttable.png + lantern.png（右半幅：行商木案灯火鉴宝席），
    构建 408x212 双舞台实景画布背景。
    """
    stage = Image.new("RGBA", (408, 212), (20, 14, 11, 255))

    # 1. 左半幅 (0..202)：碑窟青石地面 + 祭坛石阶 (shrine.png)
    cavern = Image.open(os.path.join(ROOT, "assets", "world", "maps_rebuild_20261015", "stele_cavern_floor.png")).convert("RGBA")
    cw, ch = cavern.size
    left_bg = cavern.crop((int(cw * 0.18), int(ch * 0.08), int(cw * 0.82), int(ch * 0.45))).resize((202, 212), Image.Resampling.BILINEAR)
    # 压暗上半部营造幽邃夜坛氛围
    left_arr = np.array(left_bg, dtype=np.float32)
    yy = np.mgrid[0:212, 0:202][0].astype(np.float32) / 212.0
    shade = 0.42 + 0.48 * yy
    for c in range(3):
        left_arr[:, :, c] *= shade
    left_bg = Image.fromarray(np.clip(left_arr, 0, 255).astype(np.uint8), "RGBA")

    shrine = Image.open(os.path.join(READY_DIR, "shrine.png")).convert("RGBA")
    shrine_s = fit_rgba(shrine, 192, 148)
    left_bg.alpha_composite(shrine_s, ((202 - shrine_s.width) // 2, 212 - shrine_s.height - 6))
    stage.paste(left_bg, (0, 0))

    # 2. 右半幅 (206..408)：火盆营帐暖光底 + 鉴宝木案 (nighttable.png) + 铜灯笼 (lantern.png)
    camp = Image.open(os.path.join(ROOT, "assets", "ui", "travel_chest_b1", "camp_sky.png")).convert("RGBA")
    right_bg = camp.crop((0, int(camp.height * 0.46), int(camp.width * 0.55), int(camp.height * 0.76))).resize((202, 212), Image.Resampling.BILINEAR)
    right_arr = np.array(right_bg, dtype=np.float32) * 0.72
    right_bg = Image.fromarray(np.clip(right_arr, 0, 255).astype(np.uint8), "RGBA")

    table = Image.open(os.path.join(READY_DIR, "nighttable.png")).convert("RGBA")
    table_s = fit_rgba(table, 188, 96)
    right_bg.alpha_composite(table_s, ((202 - table_s.width) // 2, 118))

    lantern = Image.open(os.path.join(READY_DIR, "lantern.png")).convert("RGBA")
    lan_s = fit_rgba(lantern, 48, 72).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    right_bg.alpha_composite(lan_s, (202 - lan_s.width - 6, 8))
    stage.paste(right_bg, (206, 0))

    # 3. 中央鎏金分栏柱与四周暗金双线框
    draw = ImageDraw.Draw(stage)
    draw.rectangle([201, 0, 206, 211], fill=(58, 38, 20, 255))
    draw.line([(203, 0), (203, 211)], fill=(232, 188, 96, 255), width=2)
    draw.rectangle([0, 0, 407, 211], outline=(214, 168, 82, 255), width=2)
    draw.rectangle([3, 3, 404, 208], outline=(98, 68, 34, 200), width=1)
    return stage


def build_stele_monument_sheet() -> Image.Image:
    """
    直接基于原生高精度 stele.png (assets/world/reference_complete_20261011/ready/stele.png)
    制作 240x140 (2帧 x 120x140) 先祖古碑精灵：
    Frame 0: 苍古蒙尘石碑（带细微古篆刻痕）
    Frame 1: 先祖共鸣激活态（碑面浮现璀璨金青双色铭文 + 环绕灵光星粒）
    """
    stele_raw = Image.open(os.path.join(READY_DIR, "stele.png")).convert("RGBA")
    stele_base = fit_rgba(stele_raw, 108, 126)

    sheet = Image.new("RGBA", (240, 140), (0, 0, 0, 0))
    sx = (120 - stele_base.width) // 2
    sy = 136 - stele_base.height

    for f in range(2):
        cell = Image.new("RGBA", (120, 140), (0, 0, 0, 0))
        draw = ImageDraw.Draw(cell)
        px = cell.load()

        if f == 1:
            # 共鸣态背后柔和暖金光晕
            for y in range(8, 132):
                for x in range(14, 106):
                    d = math.hypot((x - 60) * 1.15, (y - 68) * 0.85)
                    if d < 46.0:
                        a = int(((46.0 - d) / 46.0) ** 1.6 * 125)
                        px[x, y] = (248, 202, 88, a)

        cell.alpha_composite(stele_base, (sx, sy))

        # 在碑面中央雕刻三列先祖古篆像素铭文
        rune_main = (255, 224, 112, 245) if f == 1 else (54, 58, 52, 185)
        rune_glow = (112, 236, 255, 220) if f == 1 else (38, 42, 38, 150)
        cx = 60
        for col_idx, rx in enumerate([cx - 14, cx - 2, cx + 10]):
            for row_i in range(7):
                ry = sy + 24 + row_i * 10
                # 每个铭文字形由 4x6 像素笔画构成
                pattern = (row_i + col_idx) % 3
                draw.rectangle([rx, ry, rx + 3, ry + 1], fill=rune_main)
                draw.rectangle([rx + 1, ry + 2, rx + 2, ry + 5], fill=rune_main)
                if pattern == 0:
                    draw.rectangle([rx - 1, ry + 3, rx + 4, ry + 4], fill=rune_glow)
                elif pattern == 1:
                    draw.rectangle([rx, ry + 5, rx + 3, ry + 6], fill=rune_glow)
                else:
                    draw.point([(rx - 1, ry + 1), (rx + 4, ry + 4)], fill=rune_glow)

        if f == 1:
            # 环绕碑身的悬浮金青灵光粒子
            sparks = [(24, 34), (94, 30), (20, 74), (98, 68), (30, 102), (90, 98), (60, 12)]
            for spx, spy in sparks:
                draw.rectangle([spx - 1, spy - 1, spx + 1, spy + 1], fill=(255, 236, 142, 240))
                draw.point([(spx, spy)], fill=(255, 255, 255, 255))

        sheet.paste(cell, (f * 120, 0))

    return sheet


def build_curio_chests_sheet() -> Image.Image:
    """
    使用原生 stonebox.png（蒙尘古石匣）与 pending_chest.png（鎏金秘宝匣）
    构建 288x96 (3帧 x 96x96) 行商鉴宝匣精灵图集：
    Frame 0: 蒙尘古匣 (stonebox.png)
    Frame 1: 鎏金秘宝匣 (pending_chest.png)
    Frame 2: 秘宝出世态 (pending_chest.png + 璀璨金辉光柱与星芒)
    """
    stonebox = fit_rgba(Image.open(os.path.join(READY_DIR, "stonebox.png")), 82, 68)
    goldchest = fit_rgba(Image.open(os.path.join(ROOT, "assets", "ui", "inventory_quest_20261015", "pending_chest.png")), 88, 76)

    sheet = Image.new("RGBA", (288, 96), (0, 0, 0, 0))

    # Frame 0: 蒙尘古匣
    c0 = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    d0 = ImageDraw.Draw(c0)
    d0.ellipse([10, 72, 86, 88], fill=(10, 6, 4, 145))
    c0.alpha_composite(stonebox, ((96 - stonebox.width) // 2, 84 - stonebox.height))
    sheet.paste(c0, (0, 0))

    # Frame 1: 鎏金秘宝匣
    c1 = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(c1)
    d1.ellipse([8, 72, 88, 88], fill=(10, 6, 4, 155))
    c1.alpha_composite(goldchest, ((96 - goldchest.width) // 2, 86 - goldchest.height))
    sheet.paste(c1, (96, 0))

    # Frame 2: 开启鉴出奇珍（金辉光柱 + 提亮秘宝匣 + 宝石星芒）
    c2 = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    px2 = c2.load()
    for y in range(4, 82):
        for x in range(12, 84):
            d = math.hypot((x - 48) * 1.1, (y - 44) * 0.9)
            if d < 38.0:
                a = int(((38.0 - d) / 38.0) ** 1.5 * 150)
                px2[x, y] = (255, 218, 98, a)
    bright_chest = ImageEnhance.Brightness(goldchest).enhance(1.18)
    c2.alpha_composite(bright_chest, ((96 - bright_chest.width) // 2, 86 - bright_chest.height))
    d2 = ImageDraw.Draw(c2)
    for sx, sy in [(22, 18), (48, 10), (74, 16), (18, 42), (78, 38)]:
        d2.line([(sx - 4, sy), (sx + 4, sy)], fill=(255, 244, 178, 245), width=1)
        d2.line([(sx, sy - 4), (sx, sy + 4)], fill=(255, 244, 178, 245), width=1)
    sheet.paste(c2, (192, 0))

    return sheet


def compose_reference_boards(
    arch_bg: Image.Image,
    arch_target: Image.Image,
    arch_bow: Image.Image,
    curio_bg: Image.Image,
    stele_sheet: Image.Image,
    chests_sheet: Image.Image,
) -> None:
    os.makedirs(REF_DIR, exist_ok=True)
    os.makedirs(BEFORE_DIR, exist_ok=True)

    old_arch = os.path.join(AFTER_DIR, "after_archery.png")
    old_curio = os.path.join(AFTER_DIR, "after_arena_curio.png")
    before_arch_p = os.path.join(BEFORE_DIR, "before_archery_v1.png")
    before_curio_p = os.path.join(BEFORE_DIR, "before_curio_v1.png")
    if os.path.exists(old_arch) and not os.path.exists(before_arch_p):
        shutil.copyfile(old_arch, before_arch_p)
    if os.path.exists(old_curio) and not os.path.exists(before_curio_p):
        shutil.copyfile(old_curio, before_curio_p)

    f_title = load_font(22)
    f_sub = load_font(15)

    # 1. 校场射艺参考图板
    board1 = Image.new("RGBA", (1020, 900), (20, 15, 12, 255))
    d1 = ImageDraw.Draw(board1)
    d1.rectangle([0, 0, 1019, 54], fill=(36, 24, 18, 255))
    d1.text((20, 14), "小游戏精修参考图 1：校场射艺 · 演武靶场（实景火盆校场 + 原木草靶 + 满月角弓）", font=f_title, fill=(242, 199, 106, 255))
    if os.path.exists(before_arch_p):
        board1.paste(Image.open(before_arch_p).convert("RGBA"), (20, 84))
    d1.text((24, 60), "重构前截图：纯色几何块背景，简陋线条弓与靶，缺乏像素质感", font=f_sub, fill=(215, 165, 120, 255))

    ref_arch = Image.open(before_arch_p).convert("RGBA") if os.path.exists(before_arch_p) else Image.new("RGBA", (480, 800), (24, 17, 14, 255))
    ref_arch.paste(arch_bg.resize((480, 406), Image.Resampling.NEAREST), (0, 56))
    ref_arch.alpha_composite(arch_target, (240 - 72, 86))
    ref_arch.alpha_composite(arch_bow.crop((320, 0, 480, 120)), (240 - 80, 344))
    ra_d = ImageDraw.Draw(ref_arch)
    # 标注精修参考要点框
    for bx, by, bw, bh, lbl in [
        (10, 64, 176, 30, "① 听风铜铃+暗金风势牌"),
        (286, 64, 152, 30, "② 可视化雕翎箭囊"),
        (168, 92, 144, 156, "③ 编织草靶+入靶箭羽"),
        (438, 102, 26, 190, "④ 翠金甜区"),
        (160, 348, 160, 108, "⑤ 三帧反曲角弓"),
    ]:
        ra_d.rectangle([bx, by, bx + bw, by + bh], outline=(110, 232, 255, 220), width=2)
        ra_d.rectangle([bx, by - 18, bx + min(bw + 24, 168), by], fill=(16, 28, 38, 235))
        ra_d.text((bx + 4, by - 17), lbl, font=load_font(11), fill=(142, 238, 255, 255))
    board1.paste(ref_arch, (520, 84))
    d1.text((524, 60), "目标参考设计：月下城楼火盆石坪 + 拒马铜灯 + 原木草靶 + 蓄力角弓", font=f_sub, fill=(140, 232, 165, 255))
    board1.save(os.path.join(REF_DIR, "ref_minigame_archery_v2.png"))

    # 2. 古碑鉴宝参考图板
    board2 = Image.new("RGBA", (1020, 900), (20, 15, 12, 255))
    d2 = ImageDraw.Draw(board2)
    d2.rectangle([0, 0, 1019, 54], fill=(36, 24, 18, 255))
    d2.text((20, 14), "小游戏精修参考图 2：边城古碑共鸣 · 行商鉴宝（左坛先祖古碑 + 右席古石匣/鎏金宝匣）", font=f_title, fill=(242, 199, 106, 255))
    if os.path.exists(before_curio_p):
        board2.paste(Image.open(before_curio_p).convert("RGBA"), (20, 84))
    d2.text((24, 60), "重构前截图：仅有一张素色羊皮纸框与纯文字，无古碑与宝匣画面", font=f_sub, fill=(215, 165, 120, 255))

    ref_curio = Image.open(before_curio_p).convert("RGBA") if os.path.exists(before_curio_p) else Image.new("RGBA", (480, 800), (24, 17, 14, 255))
    rc_d = ImageDraw.Draw(ref_curio)
    rc_d.rounded_rectangle([24, 104, 456, 686], radius=8, fill=(228, 214, 192, 255), outline=(142, 102, 58, 255), width=3)
    rc_d.rounded_rectangle([36, 118, 444, 166], radius=4, fill=(32, 20, 13, 255), outline=(184, 140, 70, 255), width=1)
    rc_d.text((52, 132), "顶部状态栏：当前金币 ｜ 已鉴宝进度 2/3 ｜ 古碑共鸣状态", font=load_font(12), fill=(242, 212, 136, 255))
    ref_curio.paste(curio_bg, (36, 174))
    ref_curio.alpha_composite(stele_sheet.crop((120, 0, 240, 140)), (36 + 41, 174 + 36))
    ref_curio.alpha_composite(chests_sheet.crop((0, 0, 96, 96)), (36 + 208, 174 + 66))
    ref_curio.alpha_composite(chests_sheet.crop((192, 0, 288, 96)), (36 + 304, 174 + 62))
    rc_d.rounded_rectangle([36, 394, 444, 576], radius=4, fill=(32, 20, 13, 255), outline=(184, 140, 70, 255), width=1)
    rc_d.rounded_rectangle([48, 408, 112, 472], radius=4, fill=(20, 12, 8, 255), outline=(232, 188, 86, 255), width=2)
    ref_curio.alpha_composite(chests_sheet.crop((192, 0, 288, 96)).resize((48, 48), Image.Resampling.NEAREST), (56, 416))
    rc_d.text((124, 416), "③ 鎏金奇珍展柜槽 + 先祖碑文/鉴宝详录", font=load_font(13), fill=(245, 224, 172, 255))
    rc_d.text((124, 444), "• 上下分栏呈现当前开匣战利品与近期鉴宝记录", font=load_font(12), fill=(212, 188, 142, 255))
    rc_d.line([(48, 516), (432, 516)], fill=(184, 140, 70, 120), width=1)
    rc_d.text((52, 528), "近期鉴宝：第2鉴【霜关古战魂匣】→ 史诗真品【远征戍卫重铠】", font=load_font(12), fill=(218, 192, 138, 255))
    for bx, by, bw, bh, lbl in [
        (38, 176, 198, 208, "① 左舞台：先祖古碑发光共鸣"),
        (240, 176, 202, 208, "② 右舞台：行商双宝匣开封"),
    ]:
        rc_d.rectangle([bx, by, bx + bw, by + bh], outline=(110, 232, 255, 220), width=2)
        rc_d.rectangle([bx + 4, by + 4, bx + bw - 4, by + 24], fill=(16, 28, 38, 235))
        rc_d.text((bx + 8, by + 6), lbl, font=load_font(11), fill=(142, 238, 255, 255))
    board2.paste(ref_curio, (520, 84))
    d2.text((524, 60), "目标参考设计：先祖祭坛古碑发光共鸣 + 古石匣/鎏金秘宝匣开匣鉴宝台", font=f_sub, fill=(140, 232, 165, 255))
    board2.save(os.path.join(REF_DIR, "ref_minigame_curio_v2.png"))


def main() -> None:
    os.makedirs(MINI_DIR, exist_ok=True)
    arch_bg = build_archery_range_bg()
    arch_bg.save(os.path.join(MINI_DIR, "archery_range_bg.png"))

    arch_target = build_archery_target_sprite()
    arch_target.save(os.path.join(MINI_DIR, "archery_target_sprite.png"))

    arch_bow = build_archery_bow_sheet()
    arch_bow.save(os.path.join(MINI_DIR, "archery_bow_sheet.png"))

    curio_bg = build_curio_stage_bg()
    curio_bg.save(os.path.join(MINI_DIR, "curio_stage_bg.png"))

    stele_sheet = build_stele_monument_sheet()
    stele_sheet.save(os.path.join(MINI_DIR, "stele_monument_sheet.png"))

    chests_sheet = build_curio_chests_sheet()
    chests_sheet.save(os.path.join(MINI_DIR, "curio_chests_sheet.png"))

    compose_reference_boards(arch_bg, arch_target, arch_bow, curio_bg, stele_sheet, chests_sheet)
    print("Upgraded minigame pixel-art assets and reference boards generated successfully.")


if __name__ == "__main__":
    main()
