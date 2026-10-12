"""Re-cut magenta-keyed sprite sheets at 1:1 grain for a painted-ground map.

Usage:
    python -I build_keyed_props.py <src_dir> <out_dir> <name> [<name> ...]

Reuses the sheet coordinates and target world sizes from build_sprites_v2.SHEETS,
but area-averages straight to the target size (no x2 pixel doubling) so props match
the fine grain of a painted ground. Only the listed sprite names are written.
"""
import importlib.util
import json
import os
import sys

import numpy as np
from PIL import Image, ImageEnhance
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("bsv2", os.path.join(HERE, "build_sprites_v2.py"))
bsv2 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bsv2)

SATURATION = 0.9


def cut(rgb, labels, fg, x, y, axis, world, scale=None):
    idx, sl = bsv2.pick(labels, x, y)
    mask = (labels[sl] == idx) & fg[sl]
    ys, xs = np.nonzero(mask)
    y0, y1 = sl[0].start + ys.min(), sl[0].start + ys.max() + 1
    x0, x1 = sl[1].start + xs.min(), sl[1].start + xs.max() + 1
    m = (labels[y0:y1, x0:x1] == idx) & fg[y0:y1, x0:x1]
    if scale is None:
        scale = world / ((y1 - y0) if axis == "H" else (x1 - x0))
    size = (max(1, round((x1 - x0) * scale)), max(1, round((y1 - y0) * scale)))
    art = bsv2.area_down(rgb[y0:y1, x0:x1], m, size)
    img = Image.fromarray(art, "RGBA")
    rgb_part = ImageEnhance.Color(img.convert("RGB")).enhance(SATURATION)
    img = Image.merge("RGBA", (*rgb_part.split(), img.split()[3]))
    bbox = img.getbbox()
    return (img.crop(bbox) if bbox else img), scale


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    src, out, wanted = sys.argv[1], sys.argv[2], set(sys.argv[3:])
    if os.path.abspath(out).startswith(os.path.abspath(src)):
        sys.exit("out_dir must not be inside src_dir")
    os.makedirs(out, exist_ok=True)
    manifest = {}
    for sheet, items in bsv2.SHEETS.items():
        picked = [it for it in items if it[0] in wanted]
        if not picked:
            continue
        rgb = np.asarray(Image.open(os.path.join(src, sheet)).convert("RGB")).astype(np.float32)
        fg, labels = bsv2.components(rgb.astype(np.uint8))
        group_scale = {}
        for name, x, y, axis, world, opt in picked:
            group = opt.get("group", name)
            img, s = cut(rgb, labels, fg, x, y, axis, world, group_scale.get(group))
            group_scale.setdefault(group, s)
            img.save(os.path.join(out, name + ".png"))
            manifest[name] = {"sheet": sheet, "size": [img.width, img.height]}
    missing = wanted - set(manifest)
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print("written", len(manifest), "missing", sorted(missing))


if __name__ == "__main__":
    main()
