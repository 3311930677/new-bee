"""Cut prop sprites for a painted-ground map from RGBA sprite sheets (tideflat first).

Usage:
    python -I build_painted_props.py <src_dir> <out_dir>

Painted grounds are drawn 1:1 with fine grain, so props are area-averaged straight
to their target world size (no x2 pixel doubling) to keep one grain across the map.
Alpha is premultiplied while averaging and binarized afterwards (no soft halo).

Writes out_dir/sprites/<name>.png (origin = bottom centre) and out_dir/manifest.json.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ALPHA_CUT = 128
# sheet -> [(name, centre x, centre y in the sheet, "W"|"H", target world px)]
SHEETS = {
    "TF-P01_boats.png": [("tf_boat", 644, 465, "W", 170), ("tf_rowboat", 634, 1022, "W", 90)],
    "TF-P02_driftwood.png": [
        ("tf_drift_large_a", 327, 426, "W", 120), ("tf_drift_large_b", 948, 450, "W", 110),
        ("tf_drift_small_a", 244, 997, "W", 64), ("tf_drift_small_b", 670, 1002, "W", 60),
        ("tf_drift_small_c", 1070, 1017, "W", 52)],
    "TF-P03_posts.png": [
        ("tf_gauge_a", 433, 237, "H", 64), ("tf_gauge_b", 832, 239, "H", 64),
        ("tf_piles_a", 222, 672, "W", 44), ("tf_piles_b", 637, 658, "W", 44), ("tf_piles_c", 1053, 669, "W", 44),
        ("tf_bollard_a", 409, 1058, "W", 34), ("tf_bollard_b", 851, 1065, "W", 34)],
    "TF-P04_fishing_props_v2.png": [
        ("tf_net_rack", 438, 258, "W", 96), ("tf_cargo_crate", 1020, 369, "W", 48),
        ("tf_crab_pot_a", 369, 739, "W", 32), ("tf_crab_pot_b", 892, 738, "W", 32),
        ("tf_barrel_a", 367, 1074, "H", 30), ("tf_barrel_b", 889, 1074, "H", 30)],
    "TF-P05_rocks.png": [
        ("tf_rock_l_a", 309, 354, "W", 100), ("tf_rock_l_b", 934, 395, "W", 96),
        ("tf_rock_m_a", 164, 804, "W", 44), ("tf_rock_m_b", 479, 793, "W", 40),
        ("tf_rock_m_c", 777, 803, "W", 46), ("tf_rock_m_d", 1088, 807, "W", 42),
        ("tf_rock_s_a", 175, 1109, "W", 18), ("tf_rock_s_b", 482, 1104, "W", 20),
        ("tf_rock_s_c", 775, 1098, "W", 16), ("tf_rock_s_d", 1086, 1109, "W", 20)],
    "TF-P06_grass.png": [
        ("tf_grass_a", 158, 451, "H", 44), ("tf_grass_b", 476, 431, "H", 46),
        ("tf_grass_c", 808, 471, "H", 40), ("tf_grass_d", 1117, 446, "H", 44),
        ("tf_samphire_a", 234, 990, "W", 34), ("tf_samphire_b", 645, 930, "W", 32),
        ("tf_samphire_c", 1051, 1016, "W", 30)],
    "TF-P07_boardwalk.png": [("tf_boardwalk", 685, 651, "W", 140)],
}


def pick(labels, x, y):
    best = None
    for i, sl in enumerate(ndi.find_objects(labels), 1):
        if sl is None or not (sl[1].start <= x < sl[1].stop and sl[0].start <= y < sl[0].stop):
            continue
        area = (sl[0].stop - sl[0].start) * (sl[1].stop - sl[1].start)
        if best is None or area < best[0]:
            best = (area, i, sl)
    if best is None:
        raise ValueError(f"no sprite at ({x},{y})")
    return best[1], best[2]


def area_down(rgba, size):
    """Premultiplied box average, then hard alpha."""
    a = rgba[..., 3:4] / 255.0
    pre = np.concatenate([rgba[..., :3] * a, a * 255.0], axis=2).astype(np.float32)
    chans = [np.asarray(Image.fromarray(pre[..., c]).resize(size, Image.BOX)) for c in range(4)]
    alpha = chans[3] / 255.0
    out = np.zeros((size[1], size[0], 4), np.uint8)
    for c in range(3):
        out[..., c] = np.clip(chans[c] / np.maximum(alpha, 1e-6), 0, 255)
    out[..., 3] = np.where(chans[3] >= ALPHA_CUT, 255, 0)
    out[out[..., 3] == 0, :3] = 0
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, out = sys.argv[1:]
    if os.path.abspath(out).startswith(os.path.abspath(src)):
        sys.exit("out_dir must not be inside src_dir")
    os.makedirs(os.path.join(out, "sprites"), exist_ok=True)
    manifest = {}
    for sheet, items in SHEETS.items():
        rgba = np.asarray(Image.open(os.path.join(src, sheet)).convert("RGBA")).astype(np.float32)
        fg = rgba[..., 3] >= ALPHA_CUT
        labels, _ = ndi.label(ndi.binary_dilation(fg, iterations=10))
        for name, x, y, axis, world in items:
            idx, sl = pick(labels, x, y)
            mask = (labels[sl] == idx) & fg[sl]
            ys, xs = np.nonzero(mask)
            y0, y1 = sl[0].start + ys.min(), sl[0].start + ys.max() + 1
            x0, x1 = sl[1].start + xs.min(), sl[1].start + xs.max() + 1
            crop = rgba[y0:y1, x0:x1].copy()
            crop[~((labels[y0:y1, x0:x1] == idx) & fg[y0:y1, x0:x1])] = 0  # drop neighbours' fringe
            dim = (y1 - y0) if axis == "H" else (x1 - x0)
            s = world / dim
            size = (max(1, round((x1 - x0) * s)), max(1, round((y1 - y0) * s)))
            img = Image.fromarray(area_down(crop, size), "RGBA")
            bbox = img.getbbox()
            img = img.crop(bbox) if bbox else img
            img.save(os.path.join(out, "sprites", name + ".png"))
            manifest[name] = {"sheet": sheet, "source_box": [int(x0), int(y0), int(x1), int(y1)],
                              "size": [img.width, img.height]}
        print(f"{sheet:30s} {len(items)} sprites")
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
