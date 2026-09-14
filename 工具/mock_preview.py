"""按 Godot 逻辑在 480x800 画布上合成 Title / CharSelect 预演图，用于校对布局。"""
from PIL import Image, ImageDraw, ImageFont
import os
import math

ROOT = r"d:\new bee\远征"
OUT = r"d:\new bee\工具\preview"
os.makedirs(OUT, exist_ok=True)

W, H = 480, 800
BG = os.path.join(ROOT, "image", "background", "enter.png")
FONT_B = os.path.join(ROOT, "assets", "fonts", "NotoSansSC-Bold.otf")
FONT_R = os.path.join(ROOT, "assets", "fonts", "NotoSansSC-Regular.otf")

GOLD = (240, 192, 96)
GOLD_BRIGHT = (255, 217, 122)
BANNER = (90, 58, 30)
PARCHMENT = (232, 213, 163)
TEXT_DARK = (58, 42, 20)
NAME_GREEN = (140, 232, 140)
LV_ORANGE = (240, 160, 48)
OUTLINE = (26, 15, 6)


def bg_layer(modulate=(1, 1, 1)):
    im = Image.open(BG).convert("RGB")
    s = W / im.width
    im = im.resize((W, int(im.height * s)), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H), (42, 31, 20))
    canvas.paste(im, (0, H - im.height))
    if modulate != (1, 1, 1):
        canvas = Image.blend(canvas, Image.new("RGB", (W, H), (0, 0, 0)), 1 - modulate[0])
    return canvas


def text_c(d, xy, s, size, color, font=FONT_B, anchor="mm", outline=OUTLINE,
           ow=0, spacing=0):
    f = ImageFont.truetype(font, size)
    if spacing:
        total = sum(f.getlength(ch) for ch in s) + spacing * (len(s) - 1)
        x = xy[0] - total / 2 if anchor[0] == "m" else xy[0]
        for ch in s:
            d.text((x, xy[1]), ch, font=f, fill=color, anchor="lm",
                   stroke_width=ow, stroke_fill=outline)
            x += f.getlength(ch) + spacing
    else:
        d.text(xy, s, font=f, fill=color, anchor=anchor,
               stroke_width=ow, stroke_fill=outline)


def round_rect(d, box, radius, fill, outline=None, width=1):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def ellipse(d, cx, cy, rx, ry, fill):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill)


def menu_button(d, x, y, w, text, active=False, size=20):
    h = int(size * 1.35) + 16 + 2
    if active:
        round_rect(d, [x, y, x + w, y + h], 4, (61, 33, 10), GOLD_BRIGHT, 1)
        col = GOLD_BRIGHT
    else:
        round_rect(d, [x, y, x + w, y + h], 4, (41, 26, 13), (96, 77, 40), 1)
        col = GOLD
    d.text((x + w / 2, y + h / 2), text, font=ImageFont.truetype(FONT_B, size),
           fill=col, anchor="mm", stroke_width=2, stroke_fill=OUTLINE)
    return h


# ---------------- Title ----------------
def render_title():
    im = bg_layer()
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    for y in range(H):
        t = max(0.0, (y / H - 0.55) / 0.45)
        od.line([(0, y), (W, y)], fill=(13, 5, 0, int(127 * min(1.0, t))))
    im = Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")
    d = ImageDraw.Draw(im)

    text_c(d, (W / 2, 112), "远征", 84, GOLD_BRIGHT, spacing=36, ow=5)
    text_c(d, (W / 2, 176), "EXPEDITION", 17, (232, 204, 144),
           font=FONT_R, spacing=10, ow=2)

    # 金色分隔线
    y = 202
    d.line([(96, y), (384, y)], fill=(198, 156, 74), width=2)
    d.polygon([(W / 2 - 6, y), (W / 2, y - 6), (W / 2 + 6, y), (W / 2, y + 6)],
              fill=GOLD_BRIGHT)

    x, y, w = 286, 316, 176
    for i, m in enumerate(["开始游戏", "游戏介绍", "游戏设置", "退出游戏"]):
        h = menu_button(d, x, y, w, m, active=(i == 0))
        y += h + 14
    print("Title 菜单末 y =", y)
    im.save(os.path.join(OUT, "title.png"))


# ---------------- CharSelect ----------------
ROLES = [("zs", "pojun", "破军", "战士 · 大剑"),
         ("ck", "chuanyang", "穿杨", "枪骑 · 长枪"),
         ("fs", "shuangyu", "霜语", "法师 · 法杖"),
         ("fz", "chenxing", "晨星", "牧师 · 圣锤")]

CARD_W, CARD_H = 120, 400
CARD_SEP = 0
ROW_Y = 80
PAD_Y = 306
PAD_RX = 44
PAD_RY = 28
SPRITE_SCALE = 1.05
BG_CROP = (40, 13, 440, 680)   # 与 480:800 同比例，避开下方法师


def render_select():
    src = Image.open(BG).convert("RGB").crop(BG_CROP).resize((W, H), Image.LANCZOS)
    base = Image.blend(src, Image.new("RGB", (W, H), (0, 0, 0)), 0.30)
    im = Image.alpha_composite(base.convert("RGBA"),
                               Image.new("RGBA", (W, H), (42, 31, 20, 106)))

    # 横幅
    bw, bh = 260, 52
    tmp = ImageDraw.Draw(im)
    round_rect(tmp, [(W - bw) / 2, 26, (W + bw) / 2, 26 + bh], 4, BANNER, GOLD, 2)
    text_c(tmp, (W / 2, 26 + bh / 2), "选择角色", 28, GOLD_BRIGHT, spacing=10, ow=3)

    total = CARD_W * 4 + CARD_SEP * 3
    x0 = (W - total) / 2

    for i, (rid, fn, name, job) in enumerate(ROLES):
        cx = x0 + i * (CARD_W + CARD_SEP) + CARD_W / 2
        cy = ROW_Y + PAD_Y
        focused = i == 0

        # 圆台（椭圆，透视平台感）
        ellipse(tmp, cx, cy + 6, PAD_RX * 1.05, PAD_RY * 1.05, (0, 0, 0, 90))
        ellipse(tmp, cx, cy, PAD_RX, PAD_RY, (138, 106, 40))
        ellipse(tmp, cx, cy - 3, PAD_RX * 0.8, PAD_RY * 0.8, (201, 164, 74))
        ellipse(tmp, cx, cy - 5, PAD_RX * 0.5, PAD_RY * 0.5, (232, 198, 104))

        # 人物
        sheet = Image.open(os.path.join(ROOT, "image", "role", rid,
                                        f"{fn}_spritesheet.png")).convert("RGBA")
        fs = int(128 * SPRITE_SCALE)
        frame = sheet.crop((0, 0, 128, 128)).resize((fs, fs), Image.NEAREST)
        if not focused:
            a = frame.getchannel("A")
            f = Image.blend(frame.convert("RGB"),
                            Image.new("RGB", frame.size, (70, 66, 78)), 0.35)
            f.putalpha(a)
            frame = f.convert("RGBA")
        anim_y = cy - 6 - 63 * SPRITE_SCALE
        im.alpha_composite(frame, (int(cx - fs / 2), int(anim_y - fs / 2)))

        # 选中光圈（脚下椭圆魔法阵，外扩出圆台）
        if focused:
            arx, ary = 58, 34
            acx, acy = cx, cy + 8
            pts = []
            for k in range(65):
                a = math.tau * k / 64
                pts.append((acx + math.cos(a) * arx, acy + math.sin(a) * ary))
            tmp.line(pts, fill=GOLD_BRIGHT, width=3, joint="curve")
            pts2 = []
            for k in range(65):
                a = math.tau * k / 64
                pts2.append((acx + math.cos(a) * arx * 0.9,
                             acy + math.sin(a) * ary * 0.9))
            tmp.line(pts2, fill=(176, 140, 62), width=2, joint="curve")

        # 名字在圆台下方
        text_c(tmp, (cx, cy + PAD_RY + 16), name, 20, NAME_GREEN,
               outline=(10, 31, 10), ow=3)
        text_c(tmp, (cx, cy + PAD_RY + 37), "LV.1", 13, LV_ORANGE, ow=2)

    # 信息面板
    pw, ph = 430, 190
    px, py = (W - pw) / 2, H - 200
    round_rect(tmp, [px, py, px + pw, py + ph], 6, PARCHMENT, GOLD, 3)
    rn = ImageFont.truetype(FONT_B, 23)
    jb = ImageFont.truetype(FONT_R, 15)
    tmp.text((px + 20, py + 30), "破军", font=rn, fill=BANNER, anchor="lm")
    tmp.text((px + 24 + rn.getlength("破军"), py + 31), "战士 · 大剑", font=jb,
             fill=(122, 90, 46), anchor="lm")
    body = ("杀伐星宿转世的持剑者。\n裂山之力汇聚于巨刃，越是险境越是锋利。\n"
            "前排的坚盾，也是前排的利刃。")
    tmp.multiline_text((px + 20, py + 54), body, font=ImageFont.truetype(FONT_R, 15),
                       fill=TEXT_DARK, spacing=8)
    tmp.text((px + pw / 2, py + ph - 18), "← → 切换 · 再点一次确认",
             font=ImageFont.truetype(FONT_R, 13), fill=(122, 102, 64), anchor="mm")

    im.convert("RGB").save(os.path.join(OUT, "select.png"))
    print("卡片 x0 =", x0, "槽宽 =", CARD_W + CARD_SEP,
          "圆台中心 y =", ROW_Y + PAD_Y, "名字 y =", ROW_Y + PAD_Y + PAD_RY + 14)


render_title()
render_select()
print("done ->", OUT)
