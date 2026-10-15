"""主城首页素材还原：品红源图 -> 高清插画 PNG（2026-10-15 起不再做纯像素化）。

用法（在 远征/ 目录下）：python tools/build_town_home_assets.py
输入：assets/ui/home/source/*_source.png（生图原件，不修改）
输出：assets/ui/home/*.png（游戏尺寸的 HD 倍分辨率，TownHome 按 1/HD 缩放、线性过滤显示）
      shots/town_home_20261013/assets_review.png（放大核对图）
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/ui/home/source"
OUT = ROOT / "assets/ui/home"
REVIEW = ROOT / "shots/town_home_20261013"
SCALE = 2  # 美术像素 -> 游戏像素（布局仍按美术像素计）
HD = 2     # 输出贴图分辨率 = 游戏像素 × HD；直接从源图缩，不量化、不二值化透明

# 背景：月下山城的阶梯要塞（1024×1536，2:3）。整幅宽度等比缩到 240 美术像素宽，不裁不拉伸；
# 窗口比原图更高（3:5、9:16、9:20），向上用顶行夜空补、向下按广场砖纹周期平铺补。
BG_SOURCE = "home_bg_fortress_source.png"
BG_ART_W = 240
BG_TALL_TOP = 100     # 美术像素（=200 游戏像素）
BG_TALL_BOTTOM = 100  # 美术像素

ICON_NAMES = [
    "mail", "quest", "notice", "tavern",
    "anvil", "market", "gate", "arena",
    "hero", "party", "banner", "settings",
]


# ---------- 通用 ----------
def load_rgb(name: str) -> np.ndarray:
    return np.asarray(Image.open(SRC / name).convert("RGB")).astype(np.float32)


def magenta_mask(a: np.ndarray) -> np.ndarray:
    """前景掩码。品红底有轻微色差，按色族容差判定，再向内收 2 像素去掉粉色描边。"""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bg = (r > 165) & (b > 165) & (g < 125) & (np.abs(r - b) < 80)
    fg = ~bg
    fg = ndimage.binary_opening(fg, iterations=1)
    return ndimage.binary_erosion(fg, iterations=2)


def components(fg: np.ndarray, min_area: int = 900, join: int = 6) -> list[tuple[int, int, int, int]]:
    lab, _ = ndimage.label(ndimage.binary_dilation(fg, iterations=join))
    boxes = []
    for s in ndimage.find_objects(lab):
        x0, y0, x1, y1 = s[1].start, s[0].start, s[1].stop, s[0].stop
        if (x1 - x0) * (y1 - y0) >= min_area:
            boxes.append((x0, y0, x1, y1))
    return boxes


def downsample(rgb: np.ndarray, alpha: np.ndarray, size: tuple[int, int]) -> Image.Image:
    """预乘 alpha 的高质量缩小，保留半透明抗锯齿边。size 为美术像素，实际输出 × SCALE × HD。"""
    w, h = size[0] * SCALE * HD, size[1] * SCALE * HD
    pre = rgb * alpha[..., None]
    pre_img = [Image.fromarray(pre[..., c]).resize((w, h), Image.LANCZOS) for c in range(3)]
    a_img = Image.fromarray(alpha.astype(np.float32)).resize((w, h), Image.LANCZOS)
    av = np.clip(np.asarray(a_img), 0, 1)
    out = np.zeros((h, w, 4), np.uint8)
    safe = np.maximum(av, 1e-6)
    for c in range(3):
        out[..., c] = np.clip(np.asarray(pre_img[c]) / safe, 0, 255).astype(np.uint8)
    out[..., 3] = np.round(av * 255).astype(np.uint8)
    out[av < 1 / 255] = 0
    return Image.fromarray(out, "RGBA")


def quantize_rgba(images: list[Image.Image], colors: int) -> list[Image.Image]:
    """HD 版不再量化（保留原图渐变）；保留函数签名，方便以后切回像素版。"""
    return images


def _quantize_rgba_pixel(images: list[Image.Image], colors: int) -> list[Image.Image]:
    opaque = [np.asarray(im)[np.asarray(im)[..., 3] > 0][:, :3] for im in images]
    pixels = np.concatenate([p for p in opaque if len(p)], 0)
    strip = Image.fromarray(pixels.reshape(-1, 1, 3).astype(np.uint8), "RGB")
    pal = strip.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.NONE)
    result = []
    for im in images:
        arr = np.asarray(im)
        q = Image.fromarray(arr[..., :3]).quantize(palette=pal, dither=Image.NONE).convert("RGB")
        merged = np.dstack([np.asarray(q), arr[..., 3]])
        merged[merged[..., 3] == 0] = 0
        result.append(Image.fromarray(merged.astype(np.uint8), "RGBA"))
    return result


def fit_piece(rgb, fg, box, scale) -> Image.Image:
    x0, y0, x1, y1 = box
    w = max(1, round((x1 - x0) * scale))
    h = max(1, round((y1 - y0) * scale))
    return downsample(rgb[y0:y1, x0:x1], fg[y0:y1, x0:x1].astype(np.float32), (w, h))


def place(piece: Image.Image, canvas: tuple[int, int], anchor: str = "center", dy: int = 0) -> Image.Image:
    k = SCALE * HD
    cw, ch = canvas[0] * k, canvas[1] * k
    out = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    x = (cw - piece.width) // 2
    y = (ch - piece.height) // 2 if anchor == "center" else ch - piece.height
    out.alpha_composite(piece, (x, y + dy * k))
    return out


def game(im: Image.Image) -> Image.Image:
    """素材已是输出分辨率，原样返回。"""
    return im


def save(im: Image.Image, name: str, manifest: dict, art: Image.Image | None = None) -> None:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    manifest[name] = {"game": [im.width // HD, im.height // HD], "file": list(im.size), "hd": HD}


# ---------- 各素材 ----------
def plaza_period(a: np.ndarray, lo: int = 6, hi: int = 40, probe: int = 24) -> int:
    """广场砖纹的竖直周期：让末段 probe 行与上移 p 行后的内容差异最小。"""
    tail = a[-probe:].astype(np.float32)
    best, best_err = lo, 1e18
    for p in range(lo, hi + 1):
        err = float(np.abs(a[-probe - p:-p].astype(np.float32) - tail).mean())
        if err < best_err:
            best, best_err = p, err
    return best


def build_background(manifest: dict) -> Image.Image:
    """整幅原图等比缩到 480×HD 宽（不裁不拉伸、不量化）。高屏版向上补夜空、向下按广场砖纹周期平铺。"""
    src = Image.open(SRC / BG_SOURCE).convert("RGB")
    W, H = src.size
    k = SCALE * HD
    out_w = BG_ART_W * k
    out_h = round(H * out_w / W)
    art = src.resize((out_w, out_h), Image.LANCZOS)
    save(art, "home_bg.png", manifest, art)

    a = np.asarray(art)
    top = np.repeat(a[:1], BG_TALL_TOP * k, axis=0)
    period = plaza_period(a, lo=6 * k, hi=40 * k, probe=24 * k)
    tile = a[-period:]
    need = BG_TALL_BOTTOM * k
    bottom = np.concatenate([tile] * int(np.ceil(need / period)), 0)[:need]
    tall = Image.fromarray(np.concatenate([top, a, bottom], 0))
    save(tall, "home_bg_tall.png", manifest, tall)
    manifest["home_bg_tall.png"]["core_offset_game"] = BG_TALL_TOP * SCALE
    sky = a[0].reshape(-1, 3)
    vals, counts = np.unique(sky, axis=0, return_counts=True)
    manifest["background_source"] = {
        "file": BG_SOURCE, "source_size": [W, H], "file_size": [out_w, out_h],
        "plaza_period_file": period, "sky_color": "%02x%02x%02x" % tuple(int(v) for v in vals[counts.argmax()]),
    }
    return art


def build_icons(manifest: dict) -> list[Image.Image]:
    rgb = load_rgb("home_icons_source.png")
    fg = magenta_mask(rgb)
    boxes = components(fg)
    assert len(boxes) == 12, f"图标数量 {len(boxes)} != 12"
    # 按行带（每行约 1/3 高）再按 x 排序
    h = rgb.shape[0]
    boxes.sort(key=lambda b: (int(((b[1] + b[3]) / 2) // (h / 3)), b[0]))
    review = []
    for art_size in (16, 20):
        pieces = []
        for box in boxes:
            bw, bh = box[2] - box[0], box[3] - box[1]
            s = art_size / max(bw, bh)
            pieces.append(place(fit_piece(rgb, fg, box, s), (art_size, art_size)))
        pieces = quantize_rgba(pieces, 10)
        for name, p in zip(ICON_NAMES, pieces):
            save(game(p), f"icons/{name}_{art_size * SCALE}.png", manifest, p)
        review.extend(pieces)
    return review


def build_emblem(manifest: dict) -> list[Image.Image]:
    rgb = load_rgb("expedition_emblem_source.png")
    fg = magenta_mask(rgb)
    boxes = sorted(components(fg), key=lambda b: b[0])
    assert len(boxes) == 3, f"徽章数量 {len(boxes)} != 3"
    art_h = 56
    normal_box = boxes[0]
    s = art_h / (normal_box[3] - normal_box[1])
    size = (round((normal_box[2] - normal_box[0]) * s), art_h)
    pieces = []
    for box in boxes:
        x0, y0, x1, y1 = box
        pieces.append(downsample(rgb[y0:y1, x0:x1], fg[y0:y1, x0:x1].astype(np.float32), size))
    # 三态共用普通态外轮廓；按下态整体下移 1 美术像素
    mask = np.asarray(pieces[0])[..., 3]
    unified = []
    for p in pieces:
        arr = np.asarray(p).copy()
        arr[..., 3] = mask
        unified.append(Image.fromarray(arr, "RGBA"))
    unified = quantize_rgba(unified, 28)
    canvas = (size[0], size[1] + 1)
    states = []
    for i, p in enumerate(unified):
        k = SCALE * HD
        c = Image.new("RGBA", (canvas[0] * k, canvas[1] * k), (0, 0, 0, 0))
        c.alpha_composite(p, (0, k if i == 1 else 0))
        states.append(c)
    for name, p in zip(("normal", "pressed", "disabled"), states):
        save(game(p), f"expedition_{name}.png", manifest, p)
    return states


def build_hero(manifest: dict) -> list[Image.Image]:
    rgb = load_rgb("hero_town_source.png")
    fg = magenta_mask(rgb)
    boxes = components(fg)
    assert len(boxes) == 8, f"角色帧数量 {len(boxes)} != 8"
    h = rgb.shape[0]
    boxes.sort(key=lambda b: (int(((b[1] + b[3]) / 2) // (h / 2)), b[0]))
    frame = (24, 32)
    tallest = max(b[3] - b[1] for b in boxes)
    s = (frame[1] - 1) / tallest
    pieces = [place(fit_piece(rgb, fg, b, s), frame, "bottom") for b in boxes]
    pieces = quantize_rgba(pieces, 28)
    # 顶栏头像：从正面第 1 帧源图截头肩，避免用棕发的旧破军头像
    x0, y0, x1, _ = boxes[0]
    side = round((x1 - x0) * 0.72)
    cx = (x0 + x1) // 2
    hx0, hy0 = cx - side // 2, max(0, y0 - 6)
    head = downsample(rgb[hy0:hy0 + side, hx0:hx0 + side],
                      fg[hy0:hy0 + side, hx0:hx0 + side].astype(np.float32), (28, 28))
    head = quantize_rgba([head], 24)[0]
    save(game(head), "avatar_portrait.png", manifest, head)
    for row, name in ((0, "hero_town_idle.png"), (1, "hero_town_walk_back.png")):
        k = SCALE * HD
        strip = Image.new("RGBA", (frame[0] * 4 * k, frame[1] * k), (0, 0, 0, 0))
        for i in range(4):
            strip.alpha_composite(pieces[row * 4 + i], (i * frame[0] * k, 0))
        save(game(strip), name, manifest, strip)
        manifest[name]["frame_game"] = [frame[0] * SCALE, frame[1] * SCALE]
    return pieces


def build_fire(manifest: dict) -> list[Image.Image]:
    rgb = load_rgb("fire_source.png")
    fg = magenta_mask(rgb)
    lab, n = ndimage.label(fg)
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    # 每帧只取主体火焰（最大的 6 块），丢弃散落火星
    keep = np.argsort(sizes)[::-1][:6] + 1
    objs = ndimage.find_objects(lab)
    frames = sorted(((objs[k - 1], k) for k in keep), key=lambda t: t[0][1].start)
    base = max(o[0].stop for o, _ in frames)
    widest = max(o[1].stop - o[1].start for o, _ in frames)
    tallest = max(base - o[0].start for o, _ in frames)
    out = {}
    review = []
    # xs 对应背景里 4 像素宽的小火盆/烽火，s 对应城门前 6 像素宽的大火盆
    for label, art_w in (("xs", 4), ("s", 6)):
        s = art_w / widest
        canvas = (art_w + 1, round(tallest * s) + 1)
        pieces = []
        for (sl, k) in frames:
            only = lab == k
            x0, x1 = sl[1].start, sl[1].stop
            y0 = sl[0].start
            p = downsample(rgb[y0:base, x0:x1], only[y0:base, x0:x1].astype(np.float32),
                           (max(1, round((x1 - x0) * s)), max(1, round((base - y0) * s))))
            pieces.append(place(p, canvas, "bottom"))
        pieces = quantize_rgba(pieces, 6)
        k = SCALE * HD
        strip = Image.new("RGBA", (canvas[0] * 6 * k, canvas[1] * k), (0, 0, 0, 0))
        for i, p in enumerate(pieces):
            strip.alpha_composite(p, (i * canvas[0] * k, 0))
        name = f"fire_{label}.png"
        save(game(strip), name, manifest, strip)
        manifest[name]["frame_game"] = [canvas[0] * SCALE, canvas[1] * SCALE]
        review.extend(pieces)
    return review


def build_avatar(manifest: dict) -> list[Image.Image]:
    rgb = load_rgb("avatar_frame_badge_source.png")
    fg = magenta_mask(rgb)
    boxes = sorted(components(fg), key=lambda b: b[0])
    assert len(boxes) == 2, f"头像件数 {len(boxes)} != 2"
    frame_box, badge_box = boxes
    fs = 40 / max(frame_box[2] - frame_box[0], frame_box[3] - frame_box[1])
    frame = place(fit_piece(rgb, fg, frame_box, fs), (40, 40))
    bs = min(16 / (badge_box[2] - badge_box[0]), 12 / (badge_box[3] - badge_box[1]))
    badge = place(fit_piece(rgb, fg, badge_box, bs), (16, 12))
    frame, badge = quantize_rgba([frame, badge], 14)
    save(game(frame), "avatar_frame.png", manifest, frame)
    save(game(badge), "level_badge.png", manifest, badge)
    return [frame, badge]


def review_sheet(groups: list[list[Image.Image]], path: Path, zoom: int = 1) -> None:
    rows = []
    for g in groups:
        w = sum(p.width for p in g) + 2 * (len(g) + 1)
        h = max(p.height for p in g) + 4
        row = Image.new("RGBA", (w, h), (60, 52, 46, 255))
        x = 2
        for p in g:
            row.alpha_composite(p, (x, 2))
            x += p.width + 2
        rows.append(row)
    W = max(r.width for r in rows)
    sheet = Image.new("RGBA", (W, sum(r.height for r in rows)), (40, 36, 32, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height
    sheet.resize((W * zoom, sheet.height * zoom), Image.NEAREST).save(path)


def main() -> None:
    manifest: dict = {}
    REVIEW.mkdir(parents=True, exist_ok=True)
    build_background(manifest)
    icons = build_icons(manifest)
    emblem = build_emblem(manifest)
    hero = build_hero(manifest)
    fire = build_fire(manifest)
    avatar = build_avatar(manifest)
    (OUT / "home_assets_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    review_sheet([icons[:12], icons[12:], emblem, hero, fire, avatar], REVIEW / "assets_review.png")
    print("TOWN_HOME_ASSETS_OK", len(manifest))


if __name__ == "__main__":
    main()
