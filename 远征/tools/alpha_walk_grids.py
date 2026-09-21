"""行走网格抠黑底（复刻方案 Task 1.5 收尾）。

背景：A3 的行走网格是**纯黑底**生成的（batch1 的 ready 成品没做抠图），
代码一接上就能看见角色背后一块黑方块——回归跑不出来，只有截图能看见。

做法：从四角**洪水填充**（只清与边缘连通的近黑像素），而不是全图按阈值抠。
理由：人物的轮廓是深棕 (41,13,4)、头发与靴子里也有近黑像素——全图抠会把描边
和头发一起吃掉；洪水填充遇到描边就停下，人物内部的黑原样保留。

产物同时写回两处：batch1 的 ready 成品（保持"成品=可用"的口径，重跑拷贝步骤
不会把黑底带回来）与运行时批次目录 image/generated_362_xajh/ready/role/。

用法：python tools/alpha_walk_grids.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "assets_regen" / "batch1" / "walk_grid" / "ready"
DST_DIR = ROOT / "image" / "generated_362_xajh" / "ready" / "role"
CLASSES = ("zs", "ls", "fs")

CELL_W, CELL_H = 128, 200   # 640×800 的 5 列 × 4 行网格
COLS, ROWS = 5, 4
FLOOD_THRESH = 22   # 通道峰值低于它才算背景（背景实测 0~5，发色/描边 20+）
NEAR_BLACK = 8      # 收尾清理：贴着透明且近乎全黑的孤立小块
SEPARATOR_MAX = 60  # 格间分隔线的亮度上限（实测 31；人物描边 41 在边界带上不出现）
EDGE_MAX = 100      # 图集最外一圈的亮度上限（实测底边 76 的浅棕线）


def key_black(img: Image.Image) -> Image.Image:
    """自己写 BFS，不用 PIL 的 floodfill：后者以**种子像素**为基准比色，
    图集四角一旦不是纯黑（网格线/噪点）就只填掉一个角——实测只清了 6.8%。
    这里按"通道峰值 < 阈值"判定，并对每个格子都播种，图集怎么画都不会漏。"""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    dark = bytearray(w * h)
    for y in range(h):
        row = y * w
        for x in range(w):
            r, g, b, _a = px[x, y]
            if r < FLOOD_THRESH and g < FLOOD_THRESH and b < FLOOD_THRESH:
                dark[row + x] = 1

    seen = bytearray(w * h)
    stack: list[tuple[int, int]] = []

    def seed(x: int, y: int) -> None:
        if 0 <= x < w and 0 <= y < h and dark[y * w + x] and not seen[y * w + x]:
            seen[y * w + x] = 1
            stack.append((x, y))

    for x in range(w):          # 图像上下沿
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):          # 图像左右沿
        seed(0, y)
        seed(w - 1, y)
    for row in range(ROWS):     # 每个格子的四角都要播：格间那 2px 分隔线可能把背景切开
        for col in range(COLS):
            cx, cy = col * CELL_W, row * CELL_H
            for dx, dy in ((1, 1), (CELL_W - 2, 1), (1, CELL_H - 2), (CELL_W - 2, CELL_H - 2)):
                seed(cx + dx, cy + dy)

    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                i = ny * w + nx
                if dark[i] and not seen[i]:
                    seen[i] = 1
                    stack.append((nx, ny))

    for y in range(h):
        row = y * w
        for x in range(w):
            if seen[row + x]:
                px[x, y] = (0, 0, 0, 0)

    # 格间分隔线：提示词要求"格间留 2px 分隔线"，实际画成了灰褐 (31,22,21)——
    # 比背景亮、比描边暗，既过不了阈值、也判定不成背景，会跟着角色一起被画出来。
    # 边界位置是已知的（单元格 128×200），所以按几何清除：只清**边界带上够暗**的像素，
    # 人物离边界远（格高 200、角色约 100），不会误伤。
    def clear_dark(x: int, y: int, limit: int) -> None:
        r, g, b, _a = px[x, y]
        if max(r, g, b) < limit:
            px[x, y] = (0, 0, 0, 0)

    for k in range(1, COLS):
        for y in range(h):
            for x in (k * CELL_W - 1, k * CELL_W, k * CELL_W + 1):
                clear_dark(x, y, SEPARATOR_MAX)
    for k in range(1, ROWS):
        for x in range(w):
            for y in (k * CELL_H - 1, k * CELL_H, k * CELL_H + 1):
                clear_dark(x, y, SEPARATOR_MAX)
    for y in range(h):                      # 图集最外一圈（实测底边是 (76,57,51) 的浅棕线）
        for x in (0, 1, w - 2, w - 1):
            clear_dark(x, y, EDGE_MAX)
    for x in range(w):
        for y in (0, 1, h - 2, h - 1):
            clear_dark(x, y, EDGE_MAX)

    # 收尾：被描边包围的孤立近黑小块（比如两腿之间）也清掉——只清"贴着透明"的，
    # 人物内部的深色（头发 m≈20+、描边 m≈41）动不到
    for _ in range(3):
        victims = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0 or max(r, g, b) >= NEAR_BLACK:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                        victims.append((x, y))
                        break
        if not victims:
            break
        for x, y in victims:
            px[x, y] = (0, 0, 0, 0)
    return img


def main() -> None:
    DST_DIR.mkdir(parents=True, exist_ok=True)
    done = []
    for cls in CLASSES:
        src = SRC_DIR / f"a3_{cls}_walk_grid_640x800.png"
        if not src.exists():
            print(f"SKIP 缺源文件 {src}")
            continue
        out = key_black(Image.open(src))
        out.save(src)                      # 成品回写：重跑拷贝步骤不会把黑底带回来
        dst = DST_DIR / f"a3_{cls}_walk_grid.png"
        out.save(dst)
        opaque = sum(1 for p in out.convert("RGBA").get_flattened_data() if p[3] > 0)
        done.append(f"a3_{cls}_walk_grid 前景 {opaque} px")
    print(f"WALK_ALPHA_OK {len(done)} 张")
    for d in done:
        print("  " + d)


if __name__ == "__main__":
    main()
