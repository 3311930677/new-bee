"""Re-pixelize the GPT-generated Broken Slope assets (stage 3 pre-processing).

Usage:
    python -I pixelize_assets.py <src_dir> <out_dir> [role_sheet.png]

Reads PNGs from src_dir and never writes there. Writes into out_dir:
    processed/<name>.png       art-resolution sprite (1 art px = 1 world px)
    preview/<name>_x4.png      nearest x4 on a neutral background, for review
    density_board_x2.png       all objects + player-sized reference on grass, x2
    metrics.json               per-asset measurements and flags

Pipeline per asset: key out the magenta background -> area-average down to the
spec's art canvas (C-S 256x256, C-W 384x256) using foreground-only colour ->
binarize alpha -> mute saturation per [CALM] -> quantize opaque pixels.
"""
import glob
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageEnhance

ART_SQUARE = 256        # C-S canvas, art pixels
ART_WIDE = 384          # C-W canvas width, art pixels
SATURATION = 0.85       # [CALM]: pull GPT colours toward the muted spec palette
DEFAULT_COLORS = 24
MAX_COLORS = {"bs_g01": 8, "bs_g03": 10, "bs_e01": 12, "bs_r01": 16, "bs_l04": 16}
# Assets whose canvas does not follow C-S / C-W: target art width of the opaque bbox.
BBOX_WIDTH = {"bs_l02_a_gate.png": 320}
TILEABLE = ("bs_g01",)
PREVIEW_BG = (58, 63, 58)
PLAYER_SCALE = 0.54     # broken_slope player_scale in data/main_world_maps.json
CHUNK_FLAG = 1.4        # detected block / expected block above this -> too chunky


def is_key(rgb):
    """Magenta background with GPT's RGB drift (not an exact #FF00FF)."""
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    return (r - g > 70) & (b - g > 70) & (r > 140) & (b > 140)


def block_size(gray):
    """Estimate the apparent drawn-pixel size in source px for x and y.

    Scores each candidate period by how much edge energy lands on its grid lines
    relative to the average; returns [(period, score), (period, score)].
    """
    result = []
    for axis in (1, 0):
        prof = np.abs(np.diff(gray, axis=axis)).mean(axis=1 - axis)
        base = prof.mean() + 1e-9
        best = (0.0, 0.0)
        for period in np.arange(3.0, 14.01, 0.25):
            for off in np.arange(0.0, period, 0.5):
                idx = np.round(np.arange(off, len(prof) - 1, period)).astype(int)
                score = prof[idx].mean() / base
                if score > best[1]:
                    best = (float(period), float(score))
        result.append(best)
    return result


def art_scale(name, w, h, fg):
    if name in BBOX_WIDTH:
        xs = np.nonzero(fg.any(axis=0))[0]
        return BBOX_WIDTH[name] / (xs.max() - xs.min() + 1)
    if abs(w - h) <= 4:
        return ART_SQUARE / w
    return ART_WIDE / w


def downsample(rgb, fg, scale):
    """Area-average using foreground pixels only, so magenta never bleeds in."""
    h, w = fg.shape
    size = (max(1, round(w * scale)), max(1, round(h * scale)))

    def resize(ch):
        return np.asarray(Image.fromarray(ch.astype(np.float32)).resize(size, Image.BOX))

    mask = fg.astype(np.float32)
    cov = resize(mask)
    out = np.zeros((size[1], size[0], 4), np.uint8)
    for c in range(3):
        num = resize(rgb[..., c].astype(np.float32) * mask)
        out[..., c] = np.clip(num / np.maximum(cov, 1e-6), 0, 255).astype(np.uint8)
    out[..., 3] = np.where(cov >= 0.5, 255, 0).astype(np.uint8)
    return out


def quantize(rgba, colors):
    """Mute and quantize opaque pixels only; transparent pixels stay (0,0,0,0)."""
    rgb = rgba[..., :3].copy()
    opaque = rgba[..., 3] > 0
    pixels = rgb[opaque]
    if len(pixels) == 0:
        return rgba
    width = 256
    rows = math.ceil(len(pixels) / width)
    padded = np.concatenate([pixels, np.repeat(pixels[:1], rows * width - len(pixels), axis=0)])
    strip = Image.fromarray(padded.reshape(rows, width, 3))
    strip = ImageEnhance.Color(strip).enhance(SATURATION)
    strip = strip.quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                           dither=Image.Dither.NONE).convert("RGB")
    rgb[opaque] = np.asarray(strip).reshape(-1, 3)[: len(pixels)]
    rgb[~opaque] = 0
    return np.dstack([rgb, rgba[..., 3]])


def seam_ratio(gray):
    """Wrap-edge difference / interior difference; ~1.0 means the tile wraps cleanly."""
    h, w = gray.shape
    edge = (np.abs(gray[:, 0] - gray[:, -1]).mean() + np.abs(gray[0] - gray[-1]).mean()) / 2
    inner = (np.abs(gray[:, w // 2] - gray[:, w // 2 - 1]).mean()
             + np.abs(gray[h // 2] - gray[h // 2 - 1]).mean()) / 2
    return float(edge / (inner + 1e-9))


def preview(rgba, path):
    h, w = rgba.shape[:2]
    bg = Image.new("RGBA", (w, h), PREVIEW_BG + (255,))
    bg.alpha_composite(Image.fromarray(rgba, "RGBA"))
    bg.resize((w * 4, h * 4), Image.NEAREST).save(path)


def player_reference(role_sheet):
    """First 128x128 walk frame, scaled like the game does (nearest, player_scale)."""
    frame = Image.open(role_sheet).convert("RGBA").crop((0, 0, 128, 128))
    side = round(128 * PLAYER_SCALE)
    return frame.resize((side, side), Image.NEAREST)


def density_board(sprites, grass, player, path, width=1600):
    """Lay every object out at 1:1 on tiled grass with a player beside each row."""
    pad = 16
    rows, row, row_w = [], [], player.width + pad * 2
    for name, img in sprites:
        if row and row_w + img.width + pad > width:
            rows.append(row)
            row, row_w = [], player.width + pad * 2
        row.append((name, img))
        row_w += img.width + pad
    if row:
        rows.append(row)
    heights = [max(max(i.height for _, i in r), player.height) + pad * 2 for r in rows]
    board = Image.new("RGBA", (width, sum(heights)), PREVIEW_BG + (255,))
    if grass is not None:
        for y in range(0, board.height, grass.height):
            for x in range(0, board.width, grass.width):
                board.alpha_composite(grass, (x, y))
    y = 0
    for r, rh in zip(rows, heights):
        base = y + rh - pad
        board.alpha_composite(player, (pad, base - player.height))
        x = player.width + pad * 2
        for _, img in r:
            board.alpha_composite(img, (x, base - img.height))
            x += img.width + pad
        y += rh
    board.resize((board.width * 2, board.height * 2), Image.NEAREST).save(path)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, out = sys.argv[1], sys.argv[2]
    role_sheet = sys.argv[3] if len(sys.argv) > 3 else None
    if os.path.abspath(out).startswith(os.path.abspath(src)):
        sys.exit("out_dir must not be inside src_dir")
    for sub in ("processed", "preview"):
        os.makedirs(os.path.join(out, sub), exist_ok=True)

    metrics, objects, grass = {}, [], None
    for path in sorted(glob.glob(os.path.join(src, "*.png"))):
        name = os.path.basename(path)
        prefix = name[:6]
        rgb = np.asarray(Image.open(path).convert("RGB"))
        h, w = rgb.shape[:2]
        tile = name.startswith(TILEABLE)
        fg = np.ones((h, w), bool) if tile else ~is_key(rgb)
        scale = art_scale(name, w, h, fg)
        gray = np.asarray(Image.fromarray(rgb).convert("L")).astype(np.float32)
        (bx, sx), (by, sy) = block_size(gray)
        expected = 1.0 / scale
        chunk = (bx + by) / 2 / expected

        art = quantize(downsample(rgb, fg, scale), MAX_COLORS.get(prefix, DEFAULT_COLORS))
        Image.fromarray(art, "RGBA").save(os.path.join(out, "processed", name))
        preview(art, os.path.join(out, "preview", name.replace(".png", "_x4.png")))

        opaque = art[..., 3] > 0
        info = {
            "source_size": [w, h],
            "art_size": [art.shape[1], art.shape[0]],
            "scale": round(scale, 4),
            "expected_block_px": round(expected, 2),
            "detected_block_px": [bx, by],
            "grid_confidence": [round(sx, 3), round(sy, 3)],
            "chunk_ratio": round(chunk, 2),
            "source_colors": int(len(np.unique(rgb[fg].reshape(-1, 3), axis=0))),
            "art_colors": int(len(np.unique(art[opaque][:, :3], axis=0))),
            "key_fringe_share": 0.0 if tile else round(float((~fg).mean()), 3),
            "flags": [],
        }
        if chunk > CHUNK_FLAG and min(sx, sy) > 1.05:
            info["flags"].append("source pixels coarser than spec; regenerate finer or accept chunkier look")
        if tile:
            info["seam_ratio"] = round(seam_ratio(art[..., :3].mean(axis=2)), 2)
            if info["seam_ratio"] > 1.5:
                info["flags"].append("tile seam visible; needs wrap fix")
            if name.startswith("bs_g01_a"):
                grass = Image.fromarray(art, "RGBA")
        else:
            ys, xs = np.nonzero(opaque)
            crop = art[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]
            objects.append((name, Image.fromarray(crop, "RGBA")))
        metrics[name] = info
        print(f"{name:30s} art {info['art_size']} chunk {info['chunk_ratio']} "
              f"colors {info['art_colors']} {'; '.join(info['flags'])}")

    if role_sheet and objects:
        density_board(objects, grass, player_reference(role_sheet),
                      os.path.join(out, "density_board_x2.png"))
    with open(os.path.join(out, "metrics.json"), "w", encoding="utf-8") as f:
        json.dump(metrics, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
