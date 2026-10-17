#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成四职业主页城门专属待机精灵图集（384x128，4帧 x 96x128）：
- assets/ui/home/hero_town_idle_zs.png （破军·战士）
- assets/ui/home/hero_town_idle_ck.png （穿杨·枪骑）
- assets/ui/home/hero_town_idle_fs.png （霜语·法师）
- assets/ui/home/hero_town_idle_fz.png （晨星·牧师）

设计目标：
1. 采用正面 3/4 俯视立姿（告别旧版侧面战斗蹲姿贴图），与月下山城城门拱券透视完全一致；
2. 统一做暖火盆环境光调色（Torchlight Rim & Warm Umber Outline），让人物受左右火盆暖橙金受光、顶部夜空冷蓝受光；
3. 4 帧具备自然的呼吸起伏、披风/发梢微摆与武器微光粒子；
4. 脚底严格对齐 y=125（在 96x128 画布内），配合 TownHome 0.58 缩放完美立于城门石阶中央。
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME_DIR = os.path.join(ROOT, "assets", "ui", "home")


def clean_alpha_fringe(im: Image.Image, role_id: str = "") -> Image.Image:
    """去除源贴图边缘半透明及灰白背景残留毛边（含 fs 杖间封闭灰底块），保证像素边缘干净锐利"""
    arr = np.array(im, dtype=np.float32)
    alpha = arr[:, :, 3]
    rgb = arr[:, :, :3]
    sat = np.max(rgb, axis=2) - np.min(rgb, axis=2)
    luma = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]

    hard_mask = alpha >= 160.0
    if role_id == "fs":
        # shuangyu_idle_vertical_video_v20 杖柄与披风间有一块未抠净的纯中灰底色 (R=G=B≈120..162, sat<=10)
        bg_grey_pocket = hard_mask & (sat <= 10.0) & (luma >= 108.0) & (luma <= 166.0)
        hard_mask = hard_mask & (~bg_grey_pocket)

    # 迭代剥离最外圈中的低饱和度灰边
    for _ in range(5):
        ab = hard_mask.astype(np.uint8)
        eroded = (
            (np.pad(ab[:, :-1], ((0, 0), (1, 0))) > 0)
            & (np.pad(ab[:, 1:], ((0, 0), (0, 1))) > 0)
            & (np.pad(ab[:-1, :], ((1, 0), (0, 0))) > 0)
            & (np.pad(ab[1:, :], ((0, 1), (0, 0))) > 0)
        )
        border = hard_mask & (~eroded)
        grey_matte = border & (sat < 30.0) & (luma > 80.0)
        if not np.any(grey_matte):
            break
        hard_mask = hard_mask & (~grey_matte)

    arr[:, :, 3] = np.where(hard_mask, 255.0, 0.0)
    # 最终外围 1px 轮廓统一收敛为深暖褐像素描边 (#22120c)
    ab = hard_mask.astype(np.uint8)
    eroded = (
        (np.pad(ab[:, :-1], ((0, 0), (1, 0))) > 0)
        & (np.pad(ab[:, 1:], ((0, 0), (0, 1))) > 0)
        & (np.pad(ab[:-1, :], ((1, 0), (0, 0))) > 0)
        & (np.pad(ab[1:, :], ((0, 1), (0, 0))) > 0)
    )
    border = hard_mask & (~eroded)
    arr[border, 0] = 34.0
    arr[border, 1] = 18.0
    arr[border, 2] = 12.0
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def extract_dir_frames(role_id: str) -> list[Image.Image]:
    """返回 [朝南(down), 朝西(left), 朝东(right), 朝北(up)] 四向 128x128 帧"""
    if role_id == "fs":
        v_im = Image.open(os.path.join(ROOT, "image", "role", "fs", "shuangyu_idle_vertical_video_v20.png")).convert("RGBA")
        s_im = Image.open(os.path.join(ROOT, "image", "role", "fs", "shuangyu_idle_side_video_v18.png")).convert("RGBA")
        frames = [
            v_im.crop((0, 0, 128, 128)),
            s_im.crop((0, 0, 128, 128)),
            s_im.crop((128, 0, 256, 128)),
            v_im.crop((128, 0, 256, 128)),
        ]
    else:
        slug = {"zs": "pojun", "ck": "chuanyang", "fz": "chenxing"}[role_id]
        im = Image.open(os.path.join(ROOT, "image", "role", role_id, f"{slug}_idle_video_v19.png")).convert("RGBA")
        frames = [im.crop((i * 128, 0, (i + 1) * 128, 128)) for i in range(4)]
    return [clean_alpha_fringe(f, role_id) for f in frames]


def apply_torchlight_grading(frame_rgba: Image.Image, role_id: str, frame_idx: int) -> Image.Image:
    """将角色正面像素图融入月下山城城门火盆光效"""
    arr = np.array(frame_rgba, dtype=np.float32)
    h, w, _ = arr.shape
    alpha = arr[:, :, 3]
    mask = alpha > 16
    if not np.any(mask):
        return frame_rgba

    ys, xs = np.where(mask)
    y_min, y_max = ys.min(), ys.max()
    x_min, x_max = xs.min(), xs.max()
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ny = np.clip((yy - y_min) / max(1.0, float(y_max - y_min)), 0.0, 1.0)
    rgb = arr[:, :, :3].copy()

    if role_id == "fz":
        rgb[:, :, 0] = rgb[:, :, 0] * 0.92 + 10.0
        rgb[:, :, 1] = rgb[:, :, 1] * 0.85 + 6.0
        rgb[:, :, 2] = rgb[:, :, 2] * 0.74 + 2.0
    elif role_id == "fs":
        rgb[:, :, 0] = rgb[:, :, 0] * 0.90 + 12.0
        rgb[:, :, 1] = rgb[:, :, 1] * 0.88 + 8.0
        rgb[:, :, 2] = rgb[:, :, 2] * 0.92 + 6.0
    elif role_id == "ck":
        rgb[:, :, 0] = rgb[:, :, 0] * 0.96 + 12.0
        rgb[:, :, 1] = rgb[:, :, 1] * 0.92 + 7.0
        rgb[:, :, 2] = rgb[:, :, 2] * 0.86 + 3.0
    else:
        rgb[:, :, 0] = rgb[:, :, 0] * 0.98 + 12.0
        rgb[:, :, 1] = rgb[:, :, 1] * 0.91 + 6.0
        rgb[:, :, 2] = rgb[:, :, 2] * 0.84 + 2.0

    sky_weight = np.clip(1.0 - ny * 1.65, 0.0, 1.0) * 0.16
    sky_col = np.array([28.0, 52.0, 108.0], dtype=np.float32)
    for c in range(3):
        rgb[:, :, c] = rgb[:, :, c] * (1.0 - sky_weight) + sky_col[c] * sky_weight

    flicker = 1.0 + 0.10 * math.sin(frame_idx * math.pi * 0.5)
    bottom_glow = np.clip((ny - 0.35) / 0.65, 0.0, 1.0) ** 1.35 * 0.28 * flicker
    torch_col = np.array([255.0, 168.0, 76.0], dtype=np.float32)
    for c in range(3):
        rgb[:, :, c] = rgb[:, :, c] * (1.0 - bottom_glow) + torch_col[c] * bottom_glow

    alpha_bin = (alpha > 40).astype(np.uint8)
    left_edge = (alpha_bin > 0) & (np.pad(alpha_bin[:, :-1], ((0, 0), (1, 0))) == 0)
    right_edge = (alpha_bin > 0) & (np.pad(alpha_bin[:, 1:], ((0, 0), (0, 1))) == 0)
    left_inner = (alpha_bin > 0) & (np.pad(alpha_bin[:, :-2], ((0, 0), (2, 0))) == 0)
    right_inner = (alpha_bin > 0) & (np.pad(alpha_bin[:, 2:], ((0, 0), (0, 2))) == 0)

    luma = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
    dark_outline = mask & (luma < 36.0)
    rgb[dark_outline, 0] = np.maximum(rgb[dark_outline, 0], 34.0)
    rgb[dark_outline, 1] = np.maximum(rgb[dark_outline, 1], 18.0)
    rgb[dark_outline, 2] = np.maximum(rgb[dark_outline, 2], 12.0)

    rim_mask = (left_inner | right_inner | left_edge | right_edge) & (ny > 0.18) & (ny < 0.94)
    rim_strength = (0.34 * flicker) * np.clip((ny - 0.15) / 0.75, 0.2, 1.0)
    rim_col = np.array([255.0, 192.0, 98.0], dtype=np.float32)
    for c in range(3):
        rgb[:, :, c] = np.where(
            rim_mask,
            rgb[:, :, c] * (1.0 - rim_strength) + rim_col[c] * rim_strength,
            rgb[:, :, c],
        )

    arr[:, :, :3] = np.clip(rgb, 0.0, 255.0)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def fit_to_cell(src_frame: Image.Image, role_id: str, frame_idx: int, target_h: int = 112) -> tuple[Image.Image, int, int, int]:
    arr = np.array(src_frame)
    ys, xs = np.where(arr[:, :, 3] > 20)
    x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    cropped = src_frame.crop((x0, y0, x1, y1))
    cw, ch = cropped.size
    scale = target_h / float(ch)
    target_w = min(90, max(46, int(round(cw * scale))))
    resized_base = cropped.resize((target_w, target_h), Image.Resampling.NEAREST)
    resized_base = clean_alpha_fringe(resized_base)
    graded = apply_torchlight_grading(resized_base, role_id, frame_idx)
    paste_x = (96 - target_w) // 2
    paste_y = 125 - target_h
    return graded, paste_x, paste_y, target_w


def build_4frame_strip(src_frame: Image.Image, role_id: str) -> Image.Image:
    """
    从单张正面立姿生成 384x128 (4帧 x 96x128) 待机动画图集：
    - 裁剪有效区域并居中放置到 96x128 画布，脚底严格对齐 y=125
    - 第0~3帧制造细腻的呼吸起伏（上身 1px 呼吸、披风/衣摆微动）与职业专属灵光粒子
    """
    target_h = 112
    strip = Image.new("RGBA", (96 * 4, 128), (0, 0, 0, 0))

    for f in range(4):
        cell = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
        graded, paste_x, paste_y, target_w = fit_to_cell(src_frame, role_id, f, target_h)

        if f in (1, 2):
            split_y = int(target_h * 0.68)
            upper = graded.crop((0, 0, target_w, split_y))
            lower = graded.crop((0, split_y, target_w, target_h))
            cell.paste(lower, (paste_x, paste_y + split_y), lower)
            cell.paste(upper, (paste_x, paste_y + 1), upper)
        else:
            cell.paste(graded, (paste_x, paste_y), graded)

        draw = ImageDraw.Draw(cell)
        if role_id == "zs":
            pts = [
                (paste_x + 12 + (f % 2) * 2, paste_y + 84 - f * 4, (255, 196, 92, 220)),
                (paste_x + target_w - 14, paste_y + 62 - ((f + 1) % 4) * 3, (255, 132, 66, 195)),
            ]
        elif role_id == "ck":
            pts = [
                (paste_x + 16, paste_y + 12 + (f % 2), (235, 248, 255, 235)),
                (paste_x + target_w - 14 + (f % 2), paste_y + 54 - f * 3, (110, 228, 210, 200)),
            ]
        elif role_id == "fs":
            pts = [
                (paste_x + target_w - 18, paste_y + 18 - (f % 2), (165, 235, 255, 245)),
                (paste_x + 14 + (f % 2) * 2, paste_y + 48 - f * 3, (130, 210, 255, 210)),
            ]
        else:
            pts = [
                (paste_x + 14, paste_y + 42 - (f % 2) * 2, (255, 232, 148, 240)),
                (paste_x + target_w - 14, paste_y + 36 - ((f + 2) % 4) * 2, (255, 215, 120, 210)),
            ]
        for px, py, col in pts:
            draw.rectangle([px, py, px + 1, py + 1], fill=col)

        strip.paste(cell, (f * 96, 0))

    return strip


def build_4dir_strip(dir_frames: list[Image.Image], role_id: str) -> Image.Image:
    """生成 384x128 四向立姿图集（0=南, 1=西, 2=东, 3=北），供城门点击转身预览"""
    strip = Image.new("RGBA", (96 * 4, 128), (0, 0, 0, 0))
    for i, df in enumerate(dir_frames):
        cell = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
        graded, paste_x, paste_y, _ = fit_to_cell(df, role_id, i, 112)
        cell.paste(graded, (paste_x, paste_y), graded)
        strip.paste(cell, (i * 96, 0))
    return strip


def main() -> None:
    out_paths = {}
    for rid in ["zs", "ck", "fs", "fz"]:
        dframes = extract_dir_frames(rid)
        strip = build_4frame_strip(dframes[0], rid)
        out_p = os.path.join(HOME_DIR, f"hero_town_idle_{rid}.png")
        strip.save(out_p)
        out_paths[rid] = out_p

        dir_strip = build_4dir_strip(dframes, rid)
        dir_p = os.path.join(HOME_DIR, f"hero_town_dirs_{rid}.png")
        dir_strip.save(dir_p)
        print(f"Saved {out_p} & {dir_p}")

    # 生成一张在真实城门背景切片上的四职业效果预览图，方便直观检查画风融合度
    bg = Image.open(os.path.join(HOME_DIR, "home_bg_tall.png")).convert("RGBA")
    # 缩放到游戏视口尺寸 480x1120
    bg_game = bg.resize((480, 1120), Image.Resampling.BILINEAR)
    # 截取城门区域 (x=100..380, y=580..800)
    gate_crop = bg_game.crop((100, 580, 380, 800))

    preview = Image.new("RGBA", (280 * 4 + 30, 220), (18, 13, 10, 255))
    for idx, rid in enumerate(["zs", "ck", "fs", "fz"]):
        card = gate_crop.copy()
        strip = Image.open(out_paths[rid]).convert("RGBA")
        f0 = strip.crop((0, 0, 96, 128))
        # 在城门中按 0.58 缩放渲染（约 56x74），脚底对齐 HERO_FEET (240, 540 + 200 = 740 -> 局部 (140, 160))
        sw, sh = int(96 * 0.58), int(128 * 0.58)
        hero_vis = f0.resize((sw, sh), Image.Resampling.NEAREST)
        hx = 140 - sw // 2
        hy = 160 - sh + 2
        card.alpha_composite(hero_vis, (hx, hy))
        preview.paste(card, (idx * 290, 0))

    prev_dir = os.path.join(ROOT, "docs", "agent_iteration", "references")
    os.makedirs(prev_dir, exist_ok=True)
    prev_path = os.path.join(prev_dir, "ref_town_heroes_gate_preview.png")
    preview.save(prev_path)
    print("Saved gate preview:", prev_path)


if __name__ == "__main__":
    main()
