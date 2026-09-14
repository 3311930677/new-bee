# -*- coding: utf-8 -*-
"""
clean_sprites.py —— 修复角色立绘"切割"问题

背景：AI 生成的 512x640 精灵表（4 列 x 5 行，每格 128x128）里，
角色的披风/武器会越过格子边界，且脚底被格子下边缘裁掉。
直接用 128 网格切图 → 每帧混入相邻角色的碎片 + 脚被切 + 各帧中心不一致（待机时左右抖动）。

本脚本做法：
  1. 按透明行检测出每行动作的纵向范围（不再是死板的 128 等分）；
  2. 在行内按透明列找间隙，把该行拆成 4 个角色（间隙不足时按最细处再切）；
  3. 取每个角色真实包围盒（含被切掉的脚），按统一缩放/统一基线重新居中放进 128 格。

输出：
  image/role/<id>/<name>_sheet.png   —— 修好的完整精灵表（第 0 行=待机，已重排，其余行保持原样）
  image/role/<id>/<name>_idle.png    —— 只含 4 帧待机的 512x128 横条（游戏待机动画用）
  工具/tmp/clean_check.png            —— 四角色待机行拼图，便于肉眼核对
"""

import os
from PIL import Image, ImageDraw

BASE = r"d:\new bee\远征\image\role"
TMP = r"d:\new bee\工具\tmp"

ROLES = [("zs", "pojun"), ("ck", "chuanyang"), ("fs", "shuangyu"), ("fz", "chenxing")]

CELL = 128
COLS = 4
ROWS = 5
ALPHA_MIN = 8

SAFE_W = 124      # 角色最大允许宽度（留 2px 余量，保证不出格）
SAFE_H = 118      # 角色最大允许高度
BASELINE = 123    # 脚底所在的 y（格子内坐标）


def col_profile(im, y0, y1):
    px = im.load()
    w = im.size[0]
    prof = []
    for x in range(w):
        n = 0
        for y in range(y0, y1 + 1):
            if px[x, y][3] > ALPHA_MIN:
                n += 1
        prof.append(n)
    return prof


def row_bands(im):
    """返回内容行的 (y0, y1) 列表。"""
    px = im.load()
    w, h = im.size
    empty = []
    for y in range(h):
        if all(px[x, y][3] <= ALPHA_MIN for x in range(w)):
            empty.append(y)
    if not empty:
        return [(0, h - 1)]
    runs = []
    s = p = empty[0]
    for v in empty[1:]:
        if v == p + 1:
            p = v
        else:
            runs.append((s, p))
            s = p = v
    runs.append((s, p))
    bands = []
    prev_end = -1
    for a, b in runs:
        if a - 1 >= prev_end + 1:
            bands.append((prev_end + 1, a - 1))
        prev_end = b
    if prev_end + 1 <= h - 1:
        bands.append((prev_end + 1, h - 1))
    return [b for b in bands if b[1] - b[0] >= 6]


def gaps_in(prof):
    on = [i for i, v in enumerate(prof) if v > 0]
    if not on:
        return []
    gaps = []
    cur = None
    for x, v in enumerate(prof):
        if v == 0:
            if cur is None:
                cur = x
        else:
            if cur is not None:
                gaps.append((cur, x - 1, x - cur))
                cur = None
    inner = [g for g in gaps if g[0] > on[0] and g[1] < on[-1]]
    return inner


def split_segments(prof, n):
    """把一行按间隙拆成 n 段，返回 [(x0, x1), ...]。"""
    on = [i for i, v in enumerate(prof) if v > 0]
    if not on:
        return []
    inner = sorted(gaps_in(prof), key=lambda g: -g[2])
    cuts = sorted(g[0] for g in inner[: n - 1])
    bounds = [on[0]] + cuts + [on[-1] + 1]
    segs = [(bounds[i], bounds[i + 1]) for i in range(len(bounds) - 1)]

    # 间隙不够 → 把最宽的一段在最细处继续切
    while len(segs) < n:
        i = max(range(len(segs)), key=lambda k: segs[k][1] - segs[k][0])
        x0, x1 = segs[i]
        sub = prof[x0:x1]
        lo = (x1 - x0) // 3
        hi = (x1 - x0) * 2 // 3
        if hi <= lo:
            break
        k = min(range(lo, hi), key=lambda t: sub[t])
        segs = segs[:i] + [(x0, x0 + k), (x0 + k, x1)] + segs[i + 1:]
    return segs


def bbox(im, x0, x1, y0, y1):
    px = im.load()
    minx, miny, maxx, maxy = 10 ** 9, 10 ** 9, -1, -1
    for y in range(y0, y1 + 1):
        for x in range(x0, x1):
            if px[x, y][3] > ALPHA_MIN:
                if x < minx:
                    minx = x
                if y < miny:
                    miny = y
                if x > maxx:
                    maxx = x
                if y > maxy:
                    maxy = y
    if maxx < 0:
        return None
    return (minx, miny, maxx, maxy)


def clean_idle_row(im):
    """返回 (新的 512x128 待机行, 调试信息)。"""
    bands = row_bands(im)
    if not bands:
        raise RuntimeError("找不到内容行")
    y0, y1 = bands[0]
    prof = col_profile(im, y0, y1)
    segs = split_segments(prof, COLS)
    if len(segs) != COLS:
        raise RuntimeError("待机行拆不出 4 个角色，得到 %d 段" % len(segs))

    crops = []
    for x0, x1 in segs:
        bb = bbox(im, x0, x1, y0, y1)
        if bb is None:
            crops.append(None)
            continue
        crops.append(im.crop((bb[0], bb[1], bb[2] + 1, bb[3] + 1)))

    sizes = [c.size for c in crops if c is not None]
    max_w = max(s[0] for s in sizes)
    max_h = max(s[1] for s in sizes)
    scale = min(1.0, SAFE_W / float(max_w), SAFE_H / float(max_h))

    out = Image.new("RGBA", (CELL * COLS, CELL), (0, 0, 0, 0))
    for i, c in enumerate(crops):
        if c is None:
            continue
        if scale < 1.0:
            c = c.resize((max(1, int(round(c.width * scale))),
                          max(1, int(round(c.height * scale)))), Image.LANCZOS)
        cx = i * CELL + CELL // 2 - c.width // 2
        cy = BASELINE - c.height
        out.alpha_composite(c, (cx, cy))

    info = "band y[%d..%d] maxW=%d maxH=%d scale=%.3f" % (y0, y1, max_w, max_h, scale)
    return out, info


def main():
    os.makedirs(TMP, exist_ok=True)
    check = Image.new("RGBA", (CELL * COLS, CELL * len(ROLES)), (255, 0, 255, 255))
    for i, (rid, name) in enumerate(ROLES):
        src = os.path.join(BASE, rid, name + "_spritesheet.png")
        im = Image.open(src).convert("RGBA")

        idle, info = clean_idle_row(im)
        print("%-10s %s" % (name, info))

        # 完整精灵表：第 0 行换成修好的待机行，其余行原样保留
        sheet = im.copy()
        sheet.paste(Image.new("RGBA", (CELL * COLS, CELL), (0, 0, 0, 0)), (0, 0))
        sheet.alpha_composite(idle, (0, 0))
        sheet.save(os.path.join(BASE, rid, name + "_sheet.png"))
        idle.save(os.path.join(BASE, rid, name + "_idle.png"))

        check.alpha_composite(idle, (0, i * CELL))

    check = check.convert("RGB").resize((CELL * COLS * 2, CELL * len(ROLES) * 2), Image.NEAREST)
    d = ImageDraw.Draw(check)
    for c in range(1, COLS):
        d.line([(c * CELL * 2, 0), (c * CELL * 2, check.height)], fill=(0, 255, 0), width=1)
    for r in range(1, len(ROLES)):
        d.line([(0, r * CELL * 2), (check.width, r * CELL * 2)], fill=(0, 255, 0), width=1)
    check.save(os.path.join(TMP, "clean_check.png"))
    print("check ->", os.path.join(TMP, "clean_check.png"))


if __name__ == "__main__":
    main()
