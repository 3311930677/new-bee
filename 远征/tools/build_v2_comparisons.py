#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成《远征》第二轮精修前后对比图（共 5 张高分对比展板），
同时输出到 docs/agent_iteration/screenshots/comparisons/ 与会话制品目录。
"""

import os
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = r"D:\new bee\远征"
BEFORE_DIR = os.path.join(ROOT, "docs", "agent_iteration", "screenshots", "before")
AFTER_DIR = os.path.join(ROOT, "docs", "agent_iteration", "screenshots", "after")
REF_DIR = os.path.join(ROOT, "docs", "agent_iteration", "references")
OUT_DIR = os.path.join(ROOT, "docs", "agent_iteration", "screenshots", "comparisons")
ARTIFACT_DIR = r"C:\Users\Administrator\.gemini\antigravity-cli\brain\d2dd11a5-f500-42f9-9a4f-00dadc083d41"

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(ARTIFACT_DIR, exist_ok=True)

FONT_BOLD_PATH = os.path.join(ROOT, "assets", "fonts", "NotoSerifSC-Bold.otf")
FONT_REG_PATH = os.path.join(ROOT, "assets", "fonts", "NotoSansSC-Regular.otf")


def get_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD_PATH if bold and os.path.exists(FONT_BOLD_PATH) else FONT_REG_PATH
    if os.path.exists(path):
        return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def fit_image(im: Image.Image, target_w: int, target_h: int) -> Image.Image:
    im = im.convert("RGBA")
    scale = min(target_w / float(im.width), target_h / float(im.height))
    nw = max(1, int(round(im.width * scale)))
    nh = max(1, int(round(im.height * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (target_w, target_h), (18, 13, 10, 255))
    canvas.paste(resized, ((target_w - nw) // 2, (target_h - nh) // 2), resized)
    return canvas


def draw_card(
    board: Image.Image,
    x: int,
    y: int,
    w: int,
    h: int,
    tag_text: str,
    tag_color: tuple,
    img_path: str,
    caption_lines: list[str],
    inset_crop: tuple = None,
    source_crop: tuple = None,
) -> None:
    draw = ImageDraw.Draw(board)
    f_tag = get_font(18, bold=True)
    f_cap = get_font(14, bold=False)

    # 卡片底板与描边
    draw.rounded_rectangle([x, y, x + w, y + h], radius=8, fill=(28, 20, 15, 255), outline=tag_color, width=2)
    # 顶部标签栏
    draw.rounded_rectangle([x + 2, y + 2, x + w - 2, y + 38], radius=6, fill=(44, 30, 22, 255))
    draw.text((x + 14, y + 8), tag_text, font=f_tag, fill=tag_color)

    cap_h = 24 * max(1, len(caption_lines)) + 12
    img_area_h = h - 44 - cap_h - 8
    img_area_w = w - 16
    if os.path.exists(img_path):
        im = Image.open(img_path).convert("RGBA")
        if source_crop is not None:
            im = im.crop(source_crop)
        fitted = fit_image(im, img_area_w, img_area_h)
        board.paste(fitted, (x + 8, y + 42))
        draw.rectangle([x + 8, y + 42, x + 8 + img_area_w, y + 42 + img_area_h], outline=(110, 82, 48, 255), width=1)

        if inset_crop is not None:
            # 右下角放大镜特写框
            cx0, cy0, cx1, cy1 = inset_crop
            crop_im = im.crop((cx0, cy0, cx1, cy1)).resize((132, 132), Image.Resampling.NEAREST)
            ix = x + w - 144
            iy = y + 42 + img_area_h - 140
            draw.rectangle([ix - 2, iy - 2, ix + 134, iy + 134], fill=(16, 10, 8, 255), outline=(244, 202, 104, 255), width=2)
            board.paste(crop_im, (ix, iy))
            draw.rectangle([ix, iy, ix + 68, iy + 20], fill=(24, 14, 10, 220))
            draw.text((ix + 4, iy + 2), "2x 局部特写", font=get_font(11, bold=True), fill=(255, 224, 130, 255))

    cy = y + 46 + img_area_h
    for line in caption_lines:
        draw.text((x + 12, cy), line, font=f_cap, fill=(232, 218, 192, 255))
        cy += 22


def save_both(im: Image.Image, filename: str) -> None:
    p1 = os.path.join(OUT_DIR, filename)
    p2 = os.path.join(ARTIFACT_DIR, filename)
    im.convert("RGB").save(p1, "PNG")
    shutil.copyfile(p1, p2)
    print("SAVED:", p1)


def build_board_1_archery() -> None:
    w, h = 1660, 820
    board = Image.new("RGBA", (w, h), (15, 11, 9, 255))
    draw = ImageDraw.Draw(board)
    draw.text((28, 18), "重点精修对比 1：新增小游戏【校场射艺 · 演武靶场】（截图 → 生成参考图 → 实景重构精修）", font=get_font(24, bold=True), fill=(248, 212, 126, 255))
    draw.text((28, 52), "彻底替换旧版简陋几何线条草图：新增月下边城校场像素背景、三帧蓄力鎏金角弓、木架编织草靶、听风铜铃飘带、风偏预判虚线与零裁切排版", font=get_font(15), fill=(208, 190, 158, 255))

    cw = 390
    ch = 716
    gap = 18
    x0 = 24
    y0 = 86

    draw_card(
        board, x0, y0, cw, ch,
        "1. 修改前（旧版几何色块草图）", (232, 126, 104, 255),
        os.path.join(BEFORE_DIR, "before_archery_v1.png"),
        ["• 靶场仅用纯色圆环与简陋折线代替弓箭", "• 缺乏校场实景、箭囊可视化与蓄力打击反馈"]
    )
    draw_card(
        board, x0 + (cw + gap) * 1, y0, cw, ch,
        "2. 视觉参考图（像素靶场精修规范）", (126, 214, 248, 255),
        os.path.join(REF_DIR, "ref_minigame_archery_v2.png"),
        ["• 制定月下演武坪、听风铃、木架草靶与角弓规范", "• 明确顶部暗金风势/箭囊铭牌与右侧甜区蓄力槽"],
        source_crop=(520, 84, 1000, 884),
    )
    draw_card(
        board, x0 + (cw + gap) * 2, y0, cw, ch,
        "3. 修改后 · 逆风预瞄与满弦蓄力", (134, 236, 162, 255),
        os.path.join(AFTER_DIR, "after_archery.png"),
        ["• 实景校场拒马篝火 + 听风铜铃随风势动态飘动", "• 三帧鎏金反曲角弓拉满 + 逆风虚线落点预判"]
    )
    draw_card(
        board, x0 + (cw + gap) * 3, y0, cw, ch,
        "4. 修改后 · 正中红心与雕翎入靶", (255, 218, 108, 255),
        os.path.join(AFTER_DIR, "after_archery_hit.png"),
        ["• 命中后雕翎箭矢真实钉入草靶并随靶盘震颤", "• 描边飘字自动错位防重叠，底部文案完整无裁切"]
    )
    save_both(board, "compare_v2_1_archery_minigame.png")


def build_board_2_curio() -> None:
    w, h = 1320, 820
    board = Image.new("RGBA", (w, h), (15, 11, 9, 255))
    draw = ImageDraw.Draw(board)
    draw.text((28, 18), "重点精修对比 2：新增小游戏【古碑共鸣 · 行商鉴宝】（截图 → 生成参考图 → 双舞台实景重构）", font=get_font(24, bold=True), fill=(248, 212, 126, 255))
    draw.text((28, 52), "将原本纯文字弹窗升级为「先祖古碑石坛 + 行商木案宝匣」双舞台实景交互小游戏，支持点击碑体与宝匣直接触发共鸣与开匣特效", font=get_font(15), fill=(208, 190, 158, 255))

    cw = 412
    ch = 716
    gap = 20
    x0 = 24
    y0 = 86

    draw_card(
        board, x0, y0, cw, ch,
        "1. 修改前（旧版纯文字弹窗）", (232, 126, 104, 255),
        os.path.join(BEFORE_DIR, "before_curio_v1.png"),
        ["• 仅有羊皮纸文字说明与三个按钮，无视觉舞台", "• 看不到古碑形态，也无宝匣开启的鉴宝仪式感"]
    )
    draw_card(
        board, x0 + (cw + gap) * 1, y0, cw, ch,
        "2. 视觉参考图（双舞台实景设计稿）", (126, 214, 248, 255),
        os.path.join(REF_DIR, "ref_minigame_curio_v2.png"),
        ["• 左设青苔红绸先祖古碑坛，右设行商木案双宝匣", "• 下设鎏金奇珍展柜槽与铭文/鉴宝双栏详录"],
        source_crop=(520, 84, 1000, 884),
    )
    draw_card(
        board, x0 + (cw + gap) * 2, y0, cw, ch,
        "3. 修改后 · 古碑铭文发光与宝匣开封", (255, 218, 108, 255),
        os.path.join(AFTER_DIR, "after_arena_curio.png"),
        ["• 碑面鎏金铭文呼吸闪烁，鎏金秘宝匣开封绽放星芒", "• 左侧奇珍展柜实时展示古碑/宝匣像素图标与历史"]
    )
    save_both(board, "compare_v2_2_curio_minigame.png")


def build_board_3_tutorial() -> None:
    w, h = 1680, 860
    board = Image.new("RGBA", (w, h), (15, 11, 9, 255))
    draw = ImageDraw.Draw(board)
    draw.text((28, 18), "重点精修对比 3：11步任务驱动新手教程（全流程自动切换对应页面 + 聚光灯挖空高亮 + 实操演示）", font=get_font(24, bold=True), fill=(248, 212, 126, 255))
    draw.text((28, 52), "解决旧版教程「停留主页不切页、框选空地不知所云」问题：每一步自动打开对应功能面板并置顶聚光灯指引卡，支持一键实操演练", font=get_font(15), fill=(208, 190, 158, 255))

    # 左侧放旧版，右侧放 6 步跨页面流转矩阵 (3x2)
    draw_card(
        board, 24, 86, 380, 748,
        "修改前（停留在主页不切换面板）", (232, 126, 104, 255),
        os.path.join(AFTER_DIR, "after_tutorial.png"),
        ["• 旧版教程讲到任务/战斗/背包时页面不切换", "• 聚光灯只框在主页空处，玩家不知在讲什么"]
    )

    steps = [
        ("第1步：主城城门立姿（实操切五向）", "after_tutorial_step1_home.png", ["自动聚焦城门主角，可一键切换五向立姿"]),
        ("第3步：自动切至【任务卷宗】", "after_tutorial_step3_quest.png", ["自动打开任务卷宗并高亮上方主线传书"]),
        ("第6步：自动切至【校场射艺】试射", "after_tutorial_step6_archery.png", ["自动进入射艺靶场并现场演示十环穿杨"]),
        ("第7步：自动切至【行旅背包】穿戴", "after_tutorial_step7_bag.png", ["自动打开背包选中神兵，高亮词条对比区"]),
        ("第9步：自动切至【地区行路图】", "after_tutorial_step9_map.png", ["自动打开行路图，高亮12区域拓扑与驿车"]),
        ("第10步：自动切至【设置·易职】", "after_tutorial_step10_settings.png", ["自动打开设置常规页，高亮重选角色入口"]),
    ]
    sw = 402
    sh = 366
    gx0 = 424
    gy0 = 86
    for idx, (title, fn, cap) in enumerate(steps):
        col = idx % 3
        row = idx // 3
        draw_card(
            board,
            gx0 + col * (sw + 14),
            gy0 + row * (sh + 16),
            sw,
            sh,
            title,
            (134, 236, 162, 255),
            os.path.join(AFTER_DIR, fn),
            cap,
        )
    save_both(board, "compare_v2_3_tutorial_flow.png")


def build_board_4_settings() -> None:
    w, h = 1320, 820
    board = Image.new("RGBA", (w, h), (15, 11, 9, 255))
    draw = ImageDraw.Draw(board)
    draw.text((28, 18), "重点精修对比 4：设置面板找回并置顶【重选角色 · 易职】双入口（常规页 + 旅人页直达）", font=get_font(24, bold=True), fill=(248, 212, 126, 255))
    draw.text((28, 52), "在设置默认打开的「常规」页顶部新增【角色与旅程】快捷栏，并在「旅人」页名片下方置顶【重选角色】，点击即刻进入四职业营地易职", font=get_font(15), fill=(208, 190, 158, 255))

    cw = 412
    ch = 716
    gap = 20
    x0 = 24
    y0 = 86

    draw_card(
        board, x0, y0, cw, ch,
        "1. 设置 · 常规页（默认打开即见易职）", (134, 236, 162, 255),
        os.path.join(AFTER_DIR, "after_settings_common.png"),
        ["• 打开设置第一屏顶部即见「重选角色 · 易职」", "• 同排提供「新手指引 · 教学」随时重温完整引导"]
    )
    draw_card(
        board, x0 + (cw + gap) * 1, y0, cw, ch,
        "2. 设置 · 旅人页（名片下方置顶易职）", (126, 214, 248, 255),
        os.path.join(AFTER_DIR, "after_settings_profile.png"),
        ["• 旅人名片正下方第一顺位放置重选角色按钮", "• 无需翻找即可查看当前职业并一键切换命途"]
    )
    draw_card(
        board, x0 + (cw + gap) * 2, y0, cw, ch,
        "3. 点击直达 · 四大命途重选角色页", (255, 218, 108, 255),
        os.path.join(AFTER_DIR, "after_createrole.png"),
        ["• 支持破军/穿杨/霜语/晨星四大职业同屏检视", "• 从主城重选角色无损保留等级、金币、背包与主线"]
    )
    save_both(board, "compare_v2_4_settings_reselect.png")


def build_board_5_home_heroes() -> None:
    w, h = 1720, 840
    board = Image.new("RGBA", (w, h), (15, 11, 9, 255))
    draw = ImageDraw.Draw(board)
    draw.text((28, 18), "重点精修对比 5：主页城门下方四职业立绘重构（定制正面3/4主城守望立姿 + 城门暖火受光）", font=get_font(24, bold=True), fill=(248, 212, 126, 255))
    draw.text((28, 52), "彻底替换旧版侧向挥砍战斗大图：专门绘制破军/穿杨/霜语/晨星四职业主城守望精灵（含呼吸帧、五向切换与火盆暖橙边缘受光）", font=get_font(15), fill=(208, 190, 158, 255))

    cw = 320
    ch = 730
    gap = 16
    x0 = 22
    y0 = 86

    # 城门局部放大坐标 (160, 440, 320, 600)
    gate_crop = (160, 440, 320, 600)

    draw_card(
        board, x0, y0, cw, ch,
        "修改前（旧版战斗挥砍大图）", (232, 126, 104, 255),
        os.path.join(BEFORE_DIR, "before_home_zs.png"),
        ["• 直接套用侧向战斗挥砍帧，尺寸偏大挡门洞", "• 冷硬色调与主城夜景石阶火盆光影脱节"],
        inset_crop=gate_crop,
    )
    roles = [
        ("修改后 · 破军（战士）", "after_home_zs.png", ["• 赤金重甲大剑守望立姿", "• 披风与肩甲融入城门火盆暖光"]),
        ("修改后 · 穿杨（枪骑）", "after_home_ck.png", ["• 苍青轻甲长枪猎弓立姿", "• 高挑挺拔，五向轮廓干净利落"]),
        ("修改后 · 霜语（法师）", "after_home_fs.png", ["• 冰蓝星纹织锦长袍与冰晶法杖", "• 法杖冰辉与城门暖火冷暖呼应"]),
        ("修改后 · 晨星（牧师）", "after_home_fz.png", ["• 圣白鎏金礼袍与晨星圣锤", "• 温润圣辉完美融入拱门石阶"]),
    ]
    for idx, (title, fn, cap) in enumerate(roles):
        draw_card(
            board,
            x0 + (cw + gap) * (idx + 1),
            y0,
            cw,
            ch,
            title,
            (255, 218, 108, 255) if idx == 0 else (134, 236, 162, 255),
            os.path.join(AFTER_DIR, fn),
            cap,
            inset_crop=gate_crop,
        )
    save_both(board, "compare_v2_5_home_heroes.png")


if __name__ == "__main__":
    build_board_1_archery()
    build_board_2_curio()
    build_board_3_tutorial()
    build_board_4_settings()
    build_board_5_home_heroes()
    print("ALL V2 COMPARISON BOARDS GENERATED.")
