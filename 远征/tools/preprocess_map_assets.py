# preprocess_map_assets.py —— 地图素材离线预处理（一次性工具）
# 输入：image/map/*.png（1254×1254 整幅 AI 图，部分白底无 alpha）
# 输出：image/map_proc/*.png
#   tile  → 48×48（整体 LANCZOS 缩放，RGB）
#   sheet → 192×192（4×4 格，每格 48）
#   deco  → 边缘洪水填充去底色 → 内容裁边 → 按类别规范高度缩放（RGBA）
from __future__ import annotations

import os
import sys
from collections import deque

from PIL import Image

SRC = os.path.join(os.path.dirname(__file__), "..", "image", "map")
DST = os.path.join(os.path.dirname(__file__), "..", "image", "map_proc")

TILE_SIZE = 48
SHEET_SIZE = 192  # 4×4 × 48

# deco 目标高度（游戏内 px，48px 格子体系）
DECO_HEIGHTS = {
    "028_deco_forest_tree": 125,
    "029_deco_forest_deadtree": 105,
    "030_deco_forest_rocks": 50,
    "031_deco_forest_shrub": 42,
    "032_deco_forest_grass": 28,
    "033_deco_forest_ruin": 100,
    "034_deco_forest_bones": 36,
    "035_deco_snow_pine": 115,
    "036_deco_snow_icecrystal": 70,
    "037_deco_snow_snowdrift": 48,
    "038_deco_volcano_lavarock": 55,
    "039_deco_volcano_bones": 36,
    "040_deco_volcano_geyser": 75,
    "041_deco_tomb_gravestone": 58,
    "042_deco_tomb_coffin": 48,
    "043_deco_tomb_brazier": 68,
    "044_deco_cactus": 72,          # 容错键，实际见下
    "044_deco_desert_cactus": 72,
    "045_deco_desert_sandstone": 62,
    "046_deco_desert_drywell": 66,
    "047_deco_glacier_icespire": 105,
}

FLOOD_TOL = 46  # 边缘洪水填充颜色容差（分量差之和≈×3；需覆盖白→浅灰渐变底）


def _corner_color(img: Image.Image) -> tuple[int, int, int]:
    """取四角众数作为底色（RGBA 输入，忽略已透明角）。"""
    w, h = img.size
    pts = [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]
    cols = []
    for p in pts:
        r, g, b, a = img.getpixel(p)
        if a > 200:
            cols.append((r, g, b))
    if not cols:
        return (255, 255, 255)
    cols.sort()
    return cols[len(cols) // 2]


def _despeckle(img: Image.Image, min_area: int = 10) -> Image.Image:
    """删除孤立小连通块（alpha>128 且面积 < min_area 的散点噪声）。"""
    w, h = img.size
    px = img.load()
    comp = [-1] * (w * h)
    sizes: list[int] = []
    members: list[list[int]] = []
    for y0 in range(h):
        for x0 in range(w):
            i0 = y0 * w + x0
            if comp[i0] != -1 or px[x0, y0][3] <= 128:
                continue
            cid = len(sizes)
            area = 0
            mem: list[int] = []
            q: deque[tuple[int, int]] = deque([(x0, y0)])
            comp[i0] = cid
            while q:
                x, y = q.popleft()
                area += 1
                mem.append(y * w + x)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        ni = ny * w + nx
                        if comp[ni] == -1 and px[nx, ny][3] > 128:
                            comp[ni] = cid
                            q.append((nx, ny))
            sizes.append(area)
            members.append(mem)
    for cid, mem in enumerate(members):
        if sizes[cid] < min_area:
            for i in mem:
                x, y = i % w, i // w
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    return img


def _defringe(img: Image.Image, bg: tuple[int, int, int]) -> Image.Image:
    """去白边：贴透明区 2px 内的像素按与底色色距线性降 alpha（消除抗锯齿白晕）。"""
    w, h = img.size
    px = img.load()
    near: set[tuple[int, int]] = set()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                               (2, 0), (-2, 0), (0, 2), (0, -2),
                               (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        near.add((nx, ny))
    span = 3 * 90.0
    for x, y in near:
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        diff = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
        na = int(min(255.0, diff / span * 255.0))
        if na < a:
            px[x, y] = (r, g, b, na)
    return img


def remove_bg(img: Image.Image) -> Image.Image:
    """从四边洪水填充，把与底色相近的连通区域置透明（保留内部相近色），再去边晕。"""
    img = img.convert("RGBA")
    w, h = img.size
    bg = _corner_color(img)
    # 四边样本本身透明 → 已有 alpha，直接返回
    if all(img.getpixel(p)[3] < 60 for p in
           [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]):
        return img
    px = img.load()
    seen = bytearray(w * h)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, a = px[x, y]
        # 可吞噬：近底色 / 半透明灰雾（低饱和且 alpha≤170，AI 图常见整幅灰雾）
        fog = a <= 170 and (max(r, g, b) - min(r, g, b)) < 26
        if a < 60 or fog or (abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])) <= FLOOD_TOL * 3:
            px[x, y] = (r, g, b, 0)
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    img = _despeckle(img)
    return _defringe(img, bg)


def trim(img: Image.Image, pad: int = 2) -> Image.Image:
    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        return img
    l, t, r, b = bbox
    l = max(0, l - pad)
    t = max(0, t - pad)
    r = min(img.width, r + pad)
    b = min(img.height, b + pad)
    return img.crop((l, t, r, b))


def process_tile(path: str, out: str) -> None:
    img = Image.open(path).convert("RGB")
    img = img.resize((TILE_SIZE, TILE_SIZE), Image.LANCZOS)
    img.save(out)


def process_sheet(path: str, out: str) -> None:
    img = Image.open(path).convert("RGB")
    img = img.resize((SHEET_SIZE, SHEET_SIZE), Image.LANCZOS)
    img.save(out)


def process_deco(path: str, out: str, target_h: int) -> tuple[int, int, bool]:
    img = Image.open(path)
    had_alpha = img.mode in ("RGBA", "LA")
    img = remove_bg(img)
    img = trim(img)
    if img.height == 0:
        raise RuntimeError("空内容：" + path)
    w = max(1, round(img.width * target_h / img.height))
    img = img.resize((w, target_h), Image.LANCZOS)
    img.save(out)
    return w, target_h, had_alpha


def main() -> int:
    os.makedirs(DST, exist_ok=True)
    n_tile = n_sheet = n_deco = 0
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".png"):
            continue
        stem = name[:-4]
        src = os.path.join(SRC, name)
        dst = os.path.join(DST, name)
        if "_path_sheet_" in stem or "_lava_sheet_" in stem:
            process_sheet(src, dst)
            n_sheet += 1
        elif stem.split("_")[1] == "tile":
            process_tile(src, dst)
            n_tile += 1
        else:
            target_h = DECO_HEIGHTS.get(stem, 64)
            w, h, had_alpha = process_deco(src, dst, target_h)
            tag = "alpha" if had_alpha else "去底"
            print(f"  {name}: → {w}×{h}（{tag}）")
            n_deco += 1
    print(f"完成：tile×{n_tile} sheet×{n_sheet} deco×{n_deco} → {DST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
