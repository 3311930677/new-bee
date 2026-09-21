"""把 AI 重生成的地图图集切成引擎能直接吃的素材（复刻方案 Task 1.5 / asset-regen §七）。

H2 = 4×4 地表图集（256×256，单元 64）→ 主题地砖 48×48（TileSet 的 tile_size）
H3 = 4×4 装饰散件图集（256×256，单元 64，纯黑底）→ 抠黑底 + 裁到实体外框 + 缩到设计尺寸

产物直接写进 AI 批次目录 `image/generated_362_xajh/ready/map/`，文件名与 maps.json 的
tiles/decos 字面一致：MapScene 先按名问 G.res_tex，命中就用 AI 素材，否则回落旧目录。
这样换画风与"改表"完全解耦，任何一张没切好都能单独回退。

用法：python tools/slice_map_atlas.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHEET_H2 = ROOT / "image" / "generated_362_xajh" / "ready" / "map" / "h2_grass_tileset.png"
SHEET_H3 = ROOT / "image" / "generated_362_xajh" / "ready" / "map" / "h3_map_deco_atlas.png"
OUT = ROOT / "image" / "generated_362_xajh" / "ready" / "map"

CELL = 64          # 图集单元
COLS = 4
TILE = 48          # 引擎地砖尺寸（maps.json 的 TileSet tile_size）

# H2 第 1 行 = 草地 base 四种细微噪点变体 → 枫林郊野的三张地砖
H2_GROUND = [("001_tile_forest_1", (0, 0)), ("002_tile_forest_2", (1, 0)),
             ("003_tile_forest_3", (2, 0))]

# H3 的 16 格是**素材目录**不是位掩码表：(列, 行) 与产出名/目标尺寸逐条对拍，
# 不靠"猜第几格是哪个"——切错一格就是路边多一段没有过渡的土带。
H3_DECOS = [
    ("028_deco_forest_tree", (0, 0), 128),      # 圆冠大树（现有旧素材 125×125）
    ("029_deco_forest_deadtree", (1, 0), 128),  # 秋色树（旧 105×105）
    ("031_deco_forest_shrub", (2, 0), 48),      # 灌木（旧 41×42）
    ("035_deco_snow_pine", (0, 1), 128),        # 松树（旧 115×115，雪原用）
    ("032_deco_forest_grass", (2, 1), 32),      # 草丛（旧 27×28）
    ("030_deco_forest_rocks", (0, 3), 64),      # 灰圆石（旧 59×50）
]

BLACK_THRESHOLD = 26   # 黑底抠图阈值：三通道都低于它视为背景（留一点余量防锯齿边）

# 现有路面套件（4×4 = 16 块位掩码地形，N1/E2/S4/W8 的出口位之和即格号）
OLD_PATH_SHEET = ROOT / "image" / "map_proc" / "025_tile_forest_path_sheet_00_15.png"
REBASED_SHEET = "025_tile_forest_path_sheet_00_15"
ROAD_BIAS = 8          # r > g + 8 视为土路：土路偏红棕、草地偏绿，这个判据够用且不看色号


def cell_box(col: int, row: int) -> tuple[int, int, int, int]:
    return col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL


def chroma_black(img: Image.Image) -> Image.Image:
    """黑底 → 透明。硬边（alpha 只有 0/255），不做半透明过渡：像素画不需要羽化。"""
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if r < BLACK_THRESHOLD and g < BLACK_THRESHOLD and b < BLACK_THRESHOLD:
                px[x, y] = (0, 0, 0, 0)
    return img


def crop_to_content(img: Image.Image) -> Image.Image:
    box = img.getbbox()
    return img.crop(box) if box else img


def fit(img: Image.Image, target_h: int) -> Image.Image:
    """按高度等比缩到目标高度（散件的"高"才是它在场景里的存在感）"""
    if target_h <= 0 or img.height == target_h:
        return img
    w = max(1, round(img.width * target_h / img.height))
    return img.resize((w, target_h), Image.Resampling.NEAREST)


def rebase_path_sheet(grass: Image.Image) -> Image.Image:
    """把现有路面套件的草底换成 AI 新草地、**保留原土路形状**。

    为什么不是简单丢掉路面：那张 4×4 是正经的位掩码表（16 格对应 N1/E2/S4/W8 的出口组合），
    而 H2 图集只是个"素材目录"（4 草 + 2 路 + 过渡 + 水 + 石），凑不出三岔/四岔。
    所以路形沿用旧的、草底换新的——路带不会在满屏新草上割出一条旧绿的色带。
    """
    if not OLD_PATH_SHEET.exists():
        return None
    old = Image.open(OLD_PATH_SHEET).convert("RGB")
    out = Image.new("RGB", old.size)
    op, np_, gp = old.load(), out.load(), grass.convert("RGB").load()
    for y in range(old.height):
        for x in range(old.width):
            r, g, b = op[x, y]
            # 土路：保留原像素（含磨损与描边）；草底：换成新草地的同相位像素
            np_[x, y] = (r, g, b) if r > g + ROAD_BIAS else gp[x % TILE, y % TILE]
    return out


def main() -> None:
    h2 = Image.open(SHEET_H2).convert("RGBA")
    h3 = Image.open(SHEET_H3).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    made = []

    for name, (col, row) in H2_GROUND:
        tile = h2.crop(cell_box(col, row)).resize((TILE, TILE), Image.Resampling.NEAREST)
        tile.save(OUT / f"{name}.png")
        made.append(f"{name}.png {tile.size[0]}x{tile.size[1]}")

    rebased = rebase_path_sheet(Image.open(OUT / "001_tile_forest_1.png"))
    if rebased is not None:
        rebased.save(OUT / f"{REBASED_SHEET}.png")
        made.append(f"{REBASED_SHEET}.png {rebased.size[0]}x{rebased.size[1]}（草底已换新，路形沿用）")

    for name, (col, row), target_h in H3_DECOS:
        deco = fit(crop_to_content(chroma_black(h3.crop(cell_box(col, row)))), target_h)
        deco.save(OUT / f"{name}.png")
        made.append(f"{name}.png {deco.size[0]}x{deco.size[1]}")

    print(f"SLICE_MAP_OK {len(made)} 张 -> {OUT}")
    for m in made:
        print("  " + m)


if __name__ == "__main__":
    main()
