"""七世界地表换色板：把 AI 草地按主题重着色，滚出其余地貌的地砖与路面（复刻方案 Task 1.5）。

背景：AI 只重生成了一套草地（H2/H3），其余 7 个世界的素材还是旧画风的中世纪写实产物，
于是"打完枫林郊野进凛雪原"会当场换画风。素材方案 §H 的口径是"同一管线换色板"——
保留 AI 那套的**明度结构（噪点、草簇、过渡）**，只换色相/饱和/明度，一局的世界观就统一了。

为什么按 HSL 重着色而不是重新生成或换调色板索引：
- 重生成：7 个世界 × 3 变体 × 路面表，成本与环境都不允许；
- 按亮度排序映射到目标色阶（palette rank）：要先猜目标色阶里的每一档该配谁，
  反而比"只动色相/饱和/明度"更容易把细节压平；
- HSL：结构一字不动、像素数量不变、抖动/过渡全留着，每主题只要三个数。

产物写进 AI 批次目录，靠 MapScene/CityScene 的 `_map_tex()`（先问 `G.res_tex` 再回落）
自动生效——7 个主题的 maps.json **一个字都不用改**。

用法：python tools/theme_ground.py
"""

from __future__ import annotations

import colorsys
from pathlib import Path

from PIL import Image

from slice_map_atlas import (OUT, SHEET_H3, cell_box, chroma_black, crop_to_content,
                             fit, rebase_path_sheet)

# (主题, 色相°, 饱和倍率, 明度增益, 地砖首号, 路面表目标名)
# 色相一律给绝对值：草地原本在 70°（黄绿），不覆盖的话雪原会变成"黄绿色的雪"。
THEMES = [
    ("snow",    205, 0.11, 1.46, 4,  "026_tile_snow_path_sheet_00_15"),      # 凛雪原：冷白蓝
    ("volcano", 12,  0.50, 0.52, 7,  "027_tile_volcano_lava_sheet_00_15"),   # 赤焰岭：焦黑偏暖
    ("tomb",    45,  0.22, 1.04, 10, ""),                                     # 黄城废墟：灰沙
    ("desert",  38,  0.85, 1.24, 13, ""),                                     # 流沙关：亮沙
    ("glacier", 195, 0.30, 1.18, 16, ""),                                     # 千岁冰原：冰蓝
    ("abyss",   278, 0.70, 0.46, 19, ""),                                     # 龙怒渊：暗紫
    ("castle",  220, 0.10, 0.96, 22, ""),                                     # 希望之都：青灰石
]

# 主题前缀 → maps.json 里的地砖命名（0=首号）
TILE_NAMES = {
    "snow": "tile_snow", "volcano": "tile_volcano", "tomb": "tile_tomb",
    "desert": "tile_desert", "glacier": "tile_glacier", "abyss": "tile_abyss",
    "castle": "tile_castle",
}

# 散件换主题色：(H3 单元, 产出名, 色相, 饱和倍率, 明度增益, 目标高)
# 只用 AI 已经画好的形状——形状是靠不出来的，颜色可以换。目标高与旧素材同档：
# 树 128、石/雪堆 64，改高度会让同一片地图里的大小关系错位。
THEMED_DECOS = [
    ((0, 1), "035_deco_snow_pine",        165, 0.34, 1.06, 128),  # 凛雪原：挂霜松（原本是夏天的绿松）
    ((0, 3), "038_deco_volcano_lavarock", 8,  0.65, 0.44, 64),    # 赤焰岭：火山岩
    ((0, 3), "045_deco_desert_sandstone", 40, 0.75, 1.18, 64),    # 流沙关：砂岩
    ((2, 1), "037_deco_snow_snowdrift",   205, 0.10, 1.45, 64),   # 凛雪原：雪堆（草丛压成白团）
]


def remap(img: Image.Image, hue_deg: float, sat_scale: float, lum_gain: float) -> Image.Image:
    """保结构换色：色相归到目标值、饱和按倍率缩放、明度按增益伸缩。"""
    out = img.convert("RGBA")
    px = out.load()
    hh = hue_deg / 360.0
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            _h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            nr, ng, nb = colorsys.hls_to_rgb(hh, min(1.0, l * lum_gain), min(1.0, s * sat_scale))
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return out


def main() -> None:
    base = [Image.open(OUT / f"{n}.png").convert("RGBA") for n in
            ("001_tile_forest_1", "002_tile_forest_2", "003_tile_forest_3")]
    h3 = Image.open(SHEET_H3).convert("RGBA")
    made = []

    for theme, hue, sat, gain, first, sheet in THEMES:
        for i, tile in enumerate(base):
            out = remap(tile, hue, sat, gain)
            name = "%03d_%s_%d" % (first + i, TILE_NAMES[theme], i + 1)
            out.save(OUT / f"{name}.png")
            made.append(name)
        if sheet:
            # 路面表沿用旧的那张（16 格位掩码，草底换成这个主题的新地表）
            from slice_map_atlas import OLD_PATH_SHEET
            src = OLD_PATH_SHEET.with_name(f"{sheet}.png")
            if src.exists():
                rebased = rebase_path_sheet(remap(base[0], hue, sat, gain), old_sheet=src)
                if rebased is not None:
                    rebased.save(OUT / f"{sheet}.png")
                    made.append(sheet)

    for (col, row), name, hue, sat, gain, target_h in THEMED_DECOS:
        deco = fit(crop_to_content(chroma_black(h3.crop(cell_box(col, row)))), target_h)
        remap(deco, hue, sat, gain).save(OUT / f"{name}.png")
        made.append(name)

    print(f"THEME_GROUND_OK {len(made)} 张 -> {OUT}")
    for m in made:
        print("  " + m)


if __name__ == "__main__":
    main()
