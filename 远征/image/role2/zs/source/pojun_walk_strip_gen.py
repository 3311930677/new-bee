# -*- coding: utf-8 -*-
"""破军行走序列帧生成器：基于 pojun_icon.png 原图像素做部件切割 + 程序化步态动画。
输出: 8帧右向行走条图 / 镜像左向 / 预览GIF / 部件分解图(校验用)
"""
import os
from PIL import Image, ImageDraw

SRC = r"D:\new-bee\远征\image\role2\zs\pojun_icon.png"
OUT_DIR = r"D:\new-bee\远征\image\role2\zs"
TMP = r"D:\xajh\.tmp_sprite"
CELL = 128
N_FRAMES = 8
Y_SHIFT = 10          # 全体下移, 使落地基线 = y120 (与既有 walk_4dir 约定一致)

# ---------------- 部件切割 (x0,y0,x1,y1 含端点) ----------------
# 优先级: cape > leg_out > leg_in, 重叠区归高优先级部件
CAPE_BOX    = (8, 62, 26, 89)    # 披风: 左侧红布, 右缘x26(垂直边), 挂点(26,62)
LEG_OUT_BOX = (19, 84, 43, 111)  # 外侧腿: 护膝圆盘+护胫+靴 (靴底y110)
LEG_IN_BOX  = (61, 93, 80, 107)  # 内侧腿: 护胫+靴 (靴底y106), 上方手/护手/红布留在身体层
BOXES = [("cape", CAPE_BOX), ("leg_out", LEG_OUT_BOX), ("leg_in", LEG_IN_BOX)]

def cut_pieces(im):
    """按优先级把像素分到部件, 其余归 body。返回(body, cape, leg_out, leg_in)。"""
    w, h = im.size
    src = im.load()
    parts = {name: Image.new("RGBA", im.size, (0, 0, 0, 0)) for name, _ in BOXES}
    parts["body"] = Image.new("RGBA", im.size, (0, 0, 0, 0))
    dst = {name: parts[name].load() for name in parts}
    for y in range(h):
        for x in range(w):
            p = src[x, y]
            if p[3] < 40:
                continue
            owner = "body"
            for name, (bx0, by0, bx1, by1) in BOXES:
                if bx0 <= x <= bx1 and by0 <= y <= by1:
                    owner = name
                    break
            dst[owner][x, y] = p
    def cr(box):
        x0, y0, x1, y1 = box
        return parts[{"cape": "cape", "leg_out": "leg_out", "leg_in": "leg_in"}[
            [n for n, b in BOXES if b == box][0]]].crop((x0, y0, x1 + 1, y1 + 1))
    return parts["body"], cr(CAPE_BOX), cr(LEG_OUT_BOX), cr(LEG_IN_BOX)

# ---------------- 逐行剪切变换 ----------------
def shear_piece(piece, top_dx, mid_dx, mid_row_frac, bot_dx):
    """分段线性剪切: 顶部行偏移top_dx, 中段行偏移mid_dx, 底部行偏移bot_dx。
    返回新图及左右扩展边距。"""
    w, h = piece.size
    margin = 4 + max(abs(top_dx), abs(mid_dx), abs(bot_dx))
    out = Image.new("RGBA", (w + margin * 2, h), (0, 0, 0, 0))
    mid_row = int(h * mid_row_frac)
    for ry in range(h):
        if ry <= mid_row:
            t = ry / max(mid_row, 1)
            dx = top_dx + (mid_dx - top_dx) * t
        else:
            t = (ry - mid_row) / max(h - 1 - mid_row, 1)
            dx = mid_dx + (bot_dx - mid_dx) * t
        dx = int(round(dx))
        if dx == 0:
            out.alpha_composite(piece.crop((0, ry, w, ry + 1)), (margin, ry))
        else:
            out.alpha_composite(piece.crop((0, ry, w, ry + 1)), (margin + dx, ry))
    return out, margin

def place(canvas, piece, x, y):
    canvas.alpha_composite(piece, (int(x), int(y)))

def fill_enclosed_holes(img, passes=6):
    """封闭的内部透明缝(部件剪切后遗留)用邻近不透明像素膨胀填充。"""
    w, h = img.size
    px = img.load()
    # 从边界flood fill 标记外部背景
    outside = [[False] * w for _ in range(h)]
    from collections import deque
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if px[x, y][3] < 40 and not outside[y][x]:
                outside[y][x] = True; dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if px[x, y][3] < 40 and not outside[y][x]:
                outside[y][x] = True; dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not outside[ny][nx] and px[nx, ny][3] < 40:
                outside[ny][nx] = True; dq.append((nx, ny))
    # 膨胀填充: 内部透明像素若四邻有不透明像素则复制其颜色
    for _ in range(passes):
        fills = []
        for y in range(h):
            for x in range(w):
                if px[x, y][3] >= 40 or outside[y][x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] >= 40:
                        r, g, b, _ = px[nx, ny]
                        fills.append((x, y, (r, g, b, 255)))
                        break
        if not fills:
            break
        for x, y, c in fills:
            px[x, y] = c
    return img

def fill_open_slits(img, x_min=36, y_min=86):
    """填充甲裙/部件交界处因位移加宽的<=2px开放细缝(填暗色当阴影)。
    x<36(披风/发区)不处理, 保留原图锯齿边缘设计。"""
    w, h = img.size
    px = img.load()

    def near_left(x, y):
        for i in (1, 2):
            if x - i >= 0 and px[x - i, y][3] >= 40:
                return px[x - i, y]
        return None

    def near_right(x, y):
        for i in (1, 2):
            if x + i < w and px[x + i, y][3] >= 40:
                return px[x + i, y]
        return None

    def near_vert(x, y):
        for i in (1, 2):
            if y - i >= 0 and px[x, y - i][3] >= 40:
                return px[x, y - i]
            if y + i < h and px[x, y + i][3] >= 40:
                return px[x, y + i]
        return None

    for y in range(y_min, h):
        for x in range(x_min, w):
            if px[x, y][3] >= 40:
                continue
            L, R = near_left(x, y), near_right(x, y)
            V = near_vert(x, y)
            if L and R and V:
                # 取左右较暗者作阴影色
                cand = [L, R]
                darkest = min(cand, key=lambda p: p[0] + p[1] + p[2])
                r, g, b = darkest[0], darkest[1], darkest[2]
                px[x, y] = (r // 2, g // 2, b // 2, 255)
    return img# ---------------- 步态参数 (每帧) ----------------
# 外腿周期: 接触->负重->经过->蹬地->离地->摆动->前伸->触地前
LEG_OUT_PHASE = [  # (脚底剪切dx, 抬腿dy)
    (+5, 0), (+2, 0), (-2, 0), (-5, 1),   # F0-F3 接触/负重/经过/蹬地
    (-5, 2), (-1, 5), (+3, 2), (+5, 1),   # F4-F7 离地/摆动/前伸/触地前
]
LEG_IN_PHASE = LEG_OUT_PHASE[4:] + LEG_OUT_PHASE[:4]   # 相位差4帧
BODY_BOB = [+2, 0, -2, 0, +2, 0, -2, 0]                # 身体起伏(+为下): 接触沉/经过顶, 对称
CAPE_SWAY = [-2, -1, 0, +1, +2, +1, 0, -1]             # 披风底部摆动(正弦波)

def build_frame(body, cape, lout, lin, f):
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    bob = BODY_BOB[f]

    # 1) 披风 (最底层): 挂点(顶部)固定, 底部随风摆
    cs = CAPE_SWAY[f]
    cape_s, m = shear_piece(cape, 0, (cs * 3) // 4, 0.35, cs)
    place(canvas, cape_s, CAPE_BOX[0] - m, CAPE_BOX[1] + Y_SHIFT + bob)

    # 2) 外侧腿: 髋部固定, 脚底剪切=步幅; 整体抬腿dy
    s_dx, dy = LEG_OUT_PHASE[f]
    lout_s, m = shear_piece(lout, 0, s_dx // 2, 0.55, s_dx)
    place(canvas, lout_s, LEG_OUT_BOX[0] - m, LEG_OUT_BOX[1] + Y_SHIFT - dy)

    # 3) 内侧腿
    s2_dx, dy2 = LEG_IN_PHASE[f]
    lin_s, m2 = shear_piece(lin, 0, s2_dx // 2, 0.55, s2_dx)
    place(canvas, lin_s, LEG_IN_BOX[0] - m2, LEG_IN_BOX[1] + Y_SHIFT - dy2)

    # 4) 身体(头/躯干/剑/臂/甲裙) 最上层, 随起伏上下移动
    place(canvas, body, 0, Y_SHIFT + bob)
    # 5) 封闭缝隙补洞 + 部件交界细缝阴影填充(含披风-腰带摆动缝)
    fill_enclosed_holes(canvas)
    fill_open_slits(canvas, x_min=3, y_min=46)
    return canvas

def make_strip(frames):
    strip = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.alpha_composite(fr, (i * CELL, 0))
    return strip

def debug_parts(body, cape, lout, lin):
    """部件分解校验图: 4行, 分别为 body/cape/leg_out/leg_in (红色高亮)"""
    W, H = CELL, CELL * 4
    sheet = Image.new("RGBA", (W, H), (40, 40, 60, 255))
    rows = [(body, (0, 0, 0, 0)), (cape, (255, 0, 0, 90)),
            (lout, (0, 200, 0, 90)), (lin, (0, 120, 255, 90))]
    for i, (pc, tint) in enumerate(rows):
        canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        if pc.size == (CELL, CELL):
            canvas.alpha_composite(pc)
        else:
            box = {"cape": CAPE_BOX, "leg_out": LEG_OUT_BOX, "leg_in": LEG_IN_BOX}[rows[i][0] if False else ["body","cape","leg_out","leg_in"][i]]
            canvas.alpha_composite(pc, (box[0], box[1]))
        # tint
        mask = canvas.split()[3]
        tinted = Image.new("RGBA", (CELL, CELL), tint)
        canvas.alpha_composite(tinted, (0, 0))  # fallback
        sheet.alpha_composite(canvas, (0, i * CELL))
    return sheet

def main():
    os.makedirs(TMP, exist_ok=True)
    im = Image.open(SRC).convert("RGBA")
    body, cape, lout, lin = cut_pieces(im)

    # 部件校验图
    dbg = Image.new("RGBA", (CELL * 4, CELL), (40, 40, 60, 255))
    layers = []
    canvas = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    canvas.alpha_composite(body); layers.append(canvas)
    for pc, box in [(cape, CAPE_BOX), (lout, LEG_OUT_BOX), (lin, LEG_IN_BOX)]:
        c = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        c.alpha_composite(pc, (box[0], box[1]))
        layers.append(c)
    tints = [(255, 255, 255, 255), (255, 60, 60, 255), (60, 255, 60, 255), (80, 150, 255, 255)]
    for i, (lay, tn) in enumerate(zip(layers, tints)):
        bgc = Image.new("RGBA", (CELL, CELL), tn)
        bgc.alpha_composite(lay)
        # 相减显示: 只显示该部件
        solo = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        solo.alpha_composite(lay)
        dbg.alpha_composite(solo, (i * CELL, 0))
        d = ImageDraw.Draw(dbg)
        d.text((i * CELL + 4, 4), ["body", "cape", "leg_out", "leg_in"][i], fill=(255, 255, 0, 255))
    dbg.save(os.path.join(TMP, "parts_debug.png"))

    frames = [build_frame(body, cape, lout, lin, f) for f in range(N_FRAMES)]

    # 主输出: 右向8帧条图
    strip = make_strip(frames)
    strip.save(os.path.join(OUT_DIR, "pojun_walk_strip.png"))

    # 左向 = 镜像
    strip_l = make_strip([f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames])
    strip_l.save(os.path.join(OUT_DIR, "pojun_walk_strip_left.png"))

    # 预览GIF (10fps)
    gif_frames = []
    for fr in frames:
        bg = Image.new("RGBA", (CELL, CELL), (120, 120, 130, 255))
        bg.alpha_composite(fr)
        gif_frames.append(bg.convert("RGB"))
    gif_frames[0].save(os.path.join(OUT_DIR, "pojun_walk_preview.gif"),
                       save_all=True, append_images=gif_frames[1:], duration=100, loop=0, disposal=2)

    # 帧接4倍放大校验图
    S = 3
    sheet = Image.new("RGBA", (CELL * S * 4, CELL * S * 2), (255, 255, 255, 255))
    for i, fr in enumerate(frames):
        bg = Image.new("RGBA", (CELL, CELL), (255, 255, 255, 255))
        bg.alpha_composite(fr)
        r, c = i // 4, i % 4
        sheet.alpha_composite(bg.resize((CELL * S, CELL * S), Image.Resampling.NEAREST),
                              (c * CELL * S, r * CELL * S))
    sheet.save(os.path.join(TMP, "frames_review.png"))
    print("done:", os.path.join(OUT_DIR, "pojun_walk_strip.png"))

if __name__ == "__main__":
    main()
