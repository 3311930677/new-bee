"""远征商业化重构线框：480x800 逻辑坐标，与游戏视口一致。仅用于评审示意，不进游戏。"""
from PIL import Image, ImageDraw, ImageFont

ROOT = "D:/new-bee/远征/assets/fonts/"
REG, BOLD, SERIF = ROOT + "NotoSansSC-Regular.otf", ROOT + "NotoSansSC-Bold.otf", ROOT + "NotoSerifCJKsc-SemiBold.otf"
W, H = 480, 800
NIGHT = (23, 20, 26)
FACE = (34, 30, 38)
SEL = (47, 40, 50)
GROOVE = (16, 13, 20)
GOLD = (201, 151, 63)
BGOLD = (242, 199, 106)
CREAM = (243, 227, 192)
MUTED = (150, 138, 124)
RED = (155, 42, 28)
RED_D = (110, 26, 18)
JADE = (85, 216, 168)
PAPER = (236, 222, 193)
INK = (59, 42, 26)
RAR = {"普通": (200, 194, 180), "精良": (111, 191, 115), "稀有": (90, 166, 232), "史诗": (176, 122, 232), "传说": (240, 177, 74)}
_fc = {}


def font(size, kind="reg"):
    key = (size, kind)
    if key not in _fc:
        _fc[key] = ImageFont.truetype({"reg": REG, "bold": BOLD, "serif": SERIF}[kind], size)
    return _fc[key]


class WF:
    def __init__(self, bg=NIGHT):
        self.im = Image.new("RGB", (W, H), bg)
        self.d = ImageDraw.Draw(self.im, "RGBA")

    def stage(self, x, y, w, h, label="", top=(52, 62, 92), bottom=(28, 26, 40)):
        for i in range(h):
            t = i / max(1, h - 1)
            c = tuple(int(top[k] * (1 - t) + bottom[k] * t) for k in range(3))
            self.d.line([(x, y + i), (x + w - 1, y + i)], fill=c)
        for k in range(-h, w, 18):
            self.d.line([(x + k, y + h), (x + k + h, y)], fill=(255, 255, 255, 10))
        if label:
            self.text(x + w / 2, y + 10, label, 12, (200, 200, 220, 170), anchor="ma")

    def panel(self, x, y, w, h, kind="face", r=6, border=None, alpha=255):
        fill = {"face": FACE, "night": NIGHT, "groove": GROOVE, "sel": SEL, "paper": PAPER, "glass": (20, 16, 24)}[kind]
        if kind == "glass":
            alpha = 205
        b = border if border is not None else (GOLD if kind != "groove" else (90, 70, 46))
        self.d.rounded_rectangle([x, y, x + w, y + h], r, fill=fill + (alpha,), outline=b, width=1)
        if kind in ("face", "sel", "glass"):
            self.d.rounded_rectangle([x + 3, y + 3, x + w - 3, y + h - 3], max(1, r - 2), outline=(201, 151, 63, 60), width=1)

    def btn(self, x, y, w, h, label, kind="primary", sub=None, size=None):
        if kind == "primary":
            for i in range(h):
                t = i / max(1, h - 1)
                c = tuple(int(RED[k] * (1 - t) + RED_D[k] * t) for k in range(3))
                self.d.line([(x, y + i), (x + w, y + i)], fill=c)
            self.d.rectangle([x, y, x + w, y + h], outline=BGOLD, width=2)
            self.d.rectangle([x + 4, y + 4, x + w - 4, y + h - 4], outline=(242, 199, 106, 90), width=1)
            col = CREAM
        elif kind == "gold":
            self.d.rectangle([x, y, x + w, y + h], fill=(196, 150, 72), outline=(255, 230, 160), width=2)
            col = INK
        elif kind == "secondary":
            self.d.rectangle([x, y, x + w, y + h], fill=(38, 32, 40), outline=GOLD, width=1)
            self.d.rectangle([x + 3, y + 3, x + w - 3, y + h - 3], outline=(201, 151, 63, 70), width=1)
            col = CREAM
        else:  # ghost
            self.d.rectangle([x, y, x + w, y + h], outline=(201, 151, 63, 120), width=1)
            col = BGOLD
        fs = size or (20 if h >= 52 else 16)
        if sub:
            self.text(x + w / 2, y + h / 2 - 9, label, fs, col, "serif", anchor="mm")
            self.text(x + w / 2, y + h / 2 + 13, sub, 12, col if kind != "primary" else (240, 200, 170), anchor="mm")
        else:
            self.text(x + w / 2, y + h / 2, label, fs, col, "serif" if fs >= 18 else "bold", anchor="mm")

    def text(self, x, y, t, size=15, color=CREAM, kind="reg", anchor="la"):
        self.d.text((x, y), t, font=font(size, kind), fill=color, anchor=anchor)

    def circle(self, cx, cy, r, label=None, kind="face", sub=None, lsize=13):
        fill = {"face": (30, 26, 34), "gold": (196, 150, 72), "red": RED, "dark": (14, 12, 18)}[kind]
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=BGOLD, width=2)
        self.d.ellipse([cx - r + 4, cy - r + 4, cx + r - 4, cy + r - 4], outline=(242, 199, 106, 80), width=1)
        if label:
            self.text(cx, cy, label, lsize, INK if kind == "gold" else CREAM, "bold", anchor="mm")
        if sub:
            self.text(cx, cy + r + 4, sub, 12, CREAM, "bold", anchor="ma")

    def slot(self, x, y, s, rar="普通", label=None, badge=None):
        c = RAR[rar]
        self.d.rectangle([x, y, x + s, y + s], fill=(c[0] // 6, c[1] // 6, c[2] // 6), outline=c, width=2)
        self.d.rectangle([x + 6, y + 6, x + s - 6, y + s - 6], fill=(c[0] // 3, c[1] // 3, c[2] // 3))
        if label:
            self.text(x + s / 2, y + s / 2, label, 12 if s < 70 else 14, CREAM, "bold", anchor="mm")
        if badge:
            self.text(x + s - 4, y + s - 4, badge, 11, CREAM, "bold", anchor="rd")

    def bar(self, x, y, w, h, ratio, color=JADE, track=(12, 10, 14)):
        self.d.rectangle([x, y, x + w, y + h], fill=track, outline=(90, 70, 46))
        if ratio > 0:
            self.d.rectangle([x + 1, y + 1, x + 1 + int((w - 2) * ratio), y + h - 1], fill=color)

    def dot(self, x, y):
        self.d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(226, 64, 44), outline=(255, 220, 200))

    def topbar(self, title, right=None):
        self.d.rectangle([0, 0, W, 56], fill=(16, 13, 20, 240))
        self.d.line([(0, 56), (W, 56)], fill=GOLD)
        self.d.polygon([(26, 12), (42, 28), (26, 44), (10, 28)], outline=BGOLD, fill=(38, 32, 40))
        self.text(26, 27, "‹", 20, BGOLD, "bold", anchor="mm")
        self.text(52, 28, title, 22, CREAM, "serif", anchor="lm")
        x = W - 10
        for chip in reversed(right or []):
            tw = font(13, "bold").getlength(chip) + 22
            x -= tw
            self.d.rounded_rectangle([x, 16, x + tw, 40], 12, fill=(10, 8, 12), outline=(201, 151, 63, 160))
            self.text(x + tw / 2, 28, chip, 13, CREAM, "bold", anchor="mm")
            x -= 6

    def tabs(self, y, names, active=0, h=40, dots=()):
        n = len(names)
        w = (W - 24) / n
        self.d.rectangle([12, y, W - 12, y + h], fill=(16, 13, 20))
        for i, nm in enumerate(names):
            x = 12 + i * w
            if i == active:
                self.d.rectangle([x + 2, y + 2, x + w - 2, y + h - 2], fill=SEL)
                self.d.line([(x + 10, y + h - 3), (x + w - 10, y + h - 3)], fill=BGOLD, width=2)
            self.text(x + w / 2, y + h / 2, nm, 15, BGOLD if i == active else MUTED, "bold", anchor="mm")
            if i in dots:
                self.dot(x + w - 12, y + 9)

    def tag(self, n, x, y):
        self.d.ellipse([x - 11, y - 11, x + 11, y + 11], fill=(255, 214, 64), outline=(30, 20, 10), width=2)
        self.text(x, y, str(n), 13, (30, 20, 10), "bold", anchor="mm")

    def handle(self, y):
        self.d.rounded_rectangle([W / 2 - 24, y + 6, W / 2 + 24, y + 10], 2, fill=(201, 151, 63, 170))

    def figure(self, cx, feet, h, label, color=(120, 140, 190)):
        """占位人物剪影：头+身+影子，标注为'立绘/像素角色'位。"""
        self.d.ellipse([cx - h * 0.35, feet - 8, cx + h * 0.35, feet + 8], fill=(0, 0, 0, 90))
        hw = h * 0.22
        self.d.rounded_rectangle([cx - hw, feet - h * 0.72, cx + hw, feet], 10, fill=color + (230,))
        self.d.ellipse([cx - h * 0.14, feet - h, cx + h * 0.14, feet - h * 0.72], fill=color + (230,))
        self.text(cx, feet - h * 0.36, label, 12, (20, 20, 30), "bold", anchor="mm")

    def save(self, path):
        self.im.save(path)


def compare(before, wf_path, out, title, note=""):
    a = Image.open(before).convert("RGB")
    b = Image.open(wf_path).convert("RGB")
    if a.size != (W, H):
        a = a.resize((W, int(a.height * W / a.width))).crop((0, 0, W, H))
    pad, head = 16, 84
    im = Image.new("RGB", (W * 2 + pad * 3, H + head + pad), (12, 10, 14))
    d = ImageDraw.Draw(im)
    d.text((pad, 12), title, font=font(22, "serif"), fill=BGOLD)
    d.text((pad, head - 24), "现状（2026-10-28 实拍）", font=font(14, "bold"), fill=(255, 255, 255))
    d.text((W + pad * 2, head - 24), "重构线框（示意，非最终美术）", font=font(14, "bold"), fill=(255, 214, 64))
    if note:
        d.text((W * 2 + pad * 2, head - 22), note, font=font(12), fill=MUTED, anchor="ra")
    im.paste(a, (pad, head))
    im.paste(b, (W + pad * 2, head))
    im.save(out)
