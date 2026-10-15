"""Cut the Broken Slope sprite sheets into individual sprites at game scale (v2).

Usage:
    python -I build_sprites_v2.py <src_dir> <out_dir> <role_sheet.png>

Density rule (2026-10-12): 1 art pixel = 2 world pixels. Every item is cropped
from its sheet, area-averaged to (target world size / 2) art pixels using its
own foreground only, alpha-binarized, muted and quantized, then upscaled x2 with
nearest so the game can draw it at scale 1.

Writes into out_dir (never into src_dir):
    sprites/<name>.png      world-resolution sprite, origin = bottom centre
    tiles/<name>.png        seamless ground materials, world resolution
    manifest.json           size, sheet, source box, group per sprite
    board.png               all sprites on grass next to a game-scale player
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageEnhance
from scipy import ndimage as ndi

DENSITY = 2             # world px per art px
SATURATION = 0.85       # [CALM]
PLAYER_SCALE = 0.54     # broken_slope player_scale
TILE_ART = 128          # ground material tile, art px (256 world px)

# sheet -> [(name, source centre x, source centre y, "H"|"W", target world px, options)]
# options: group = items sharing one scale (animation frames / state pairs);
#          sat = saturation override; colors = palette size override.
SHEETS = {
    "bs_c01_camp.png": [
        ("camp_tent", 331, 281, "H", 96, {}),
        ("camp_stall", 948, 302, "W", 120, {}),
        ("camp_banner", 1394, 281, "H", 80, {}),
        ("campfire_0", 353, 666, "W", 40, {"group": "campfire"}),
        ("campfire_1", 601, 663, "W", 40, {"group": "campfire"}),
        ("campfire_2", 847, 655, "W", 40, {"group": "campfire"}),
        ("campfire_3", 1092, 677, "W", 40, {"group": "campfire"}),
        ("camp_crate_a", 162, 882, "H", 28, {}),
        ("camp_crate_b", 426, 890, "W", 40, {}),
        ("camp_barrel_a", 704, 872, "H", 32, {}),
        ("camp_barrel_b", 931, 884, "H", 28, {}),
        ("camp_bench", 1272, 891, "W", 48, {}),
    ],
    "bs_e01_fx.png": [
        *[(f"fx_leaf_green_{i}", x, 195, "W", 8, {"group": "leaf_g"})
          for i, x in enumerate((312, 443, 572, 704))],
        *[(f"fx_leaf_rust_{i}", x, 195, "W", 8, {"group": "leaf_r"})
          for i, x in enumerate((858, 987, 1106, 1230))],
        ("fx_firefly_0", 970, 380, "W", 4, {"group": "firefly"}),
        ("fx_firefly_1", 1093, 380, "W", 4, {"group": "firefly"}),
        ("fx_mist", 768, 801, "W", 320, {"colors": 4}),
    ],
    "bs_f01_a_canopy.png": [("fg_canopy_tr", 998, 351, "W", 320, {})],
    "bs_f01_c_canopy.png": [("fg_canopy_tl", 467, 379, "W", 300, {})],
    "bs_f01_b_branches_grass.png": [
        ("fg_branch_a", 373, 290, "W", 200, {}),
        ("fg_branch_b", 380, 733, "W", 200, {}),
        ("fg_grass_a", 1145, 309, "W", 160, {}),
        ("fg_grass_b", 1144, 777, "W", 160, {}),
    ],
    "bs_g02_a_roadside.png": [
        ("edge_h_a", 287, 81, "W", 64, {}),
        ("edge_h_b", 767, 79, "W", 64, {}),
        ("edge_h_c", 1245, 80, "W", 64, {}),
        ("edge_v_a", 561, 318, "H", 64, {}),
        ("edge_v_b", 764, 320, "H", 64, {}),
        ("edge_v_c", 973, 320, "H", 64, {}),
        ("rut_a", 411, 568, "W", 128, {}),
        ("rut_b", 1140, 568, "W", 128, {}),
        ("puddle_a", 224, 736, "W", 56, {}),
        ("puddle_b", 560, 740, "W", 48, {}),
        ("crack_a", 857, 743, "W", 36, {}),
        ("crack_b", 1132, 737, "W", 36, {}),
        ("crack_c", 1387, 749, "W", 28, {}),
        ("root_a", 242, 907, "W", 64, {}),
        ("root_b", 603, 919, "W", 52, {}),
    ],
    "bs_g02_b_meadow.png": [
        *[(f"tuft_{i}", x, y, "H", 16, {}) for i, (x, y) in enumerate(
            ((162, 187), (418, 178), (653, 192), (888, 179), (1130, 206), (1373, 191)))],
        *[(f"flower_{i}", x, 402, "W", 14, {}) for i, x in enumerate((261, 584, 926, 1272))],
        *[(f"pebbles_{i}", x, 613, "W", 18, {}) for i, x in enumerate((165, 467, 744, 1035, 1358))],
        *[(f"leaves_{i}", x, 848, "W", 28, {}) for i, x in enumerate((194, 495, 795))],
        ("tallgrass_a", 1087, 824, "H", 28, {}),
        ("tallgrass_b", 1365, 824, "H", 28, {}),
    ],
    "bs_g03_a_earth_straw.png": [
        *[(f"patch_earth_{i}", x, y, "W", 112, {"sat": 0.62, "colors": 12})
          for i, (x, y) in enumerate(((251, 268), (758, 240), (1289, 260)))],
        *[(f"patch_straw_{i}", x, y, "W", 112, {"sat": 0.78, "colors": 12})
          for i, (x, y) in enumerate(((256, 752), (767, 743), (1289, 755)))],
    ],
    "bs_g03_b_moss_gravel.png": [
        *[(f"patch_moss_{i}", x, y, "W", 112, {"colors": 12})
          for i, (x, y) in enumerate(((259, 268), (775, 280), (1272, 268)))],
        *[(f"patch_gravel_{i}", x, y, "W", 112, {"colors": 12})
          for i, (x, y) in enumerate(((259, 748), (776, 748), (1288, 755)))],
    ],
    "bs_g03_c_leaf_damp.png": [
        *[(f"patch_leaf_{i}", x, y, "W", 104, {"sat": 0.72, "colors": 12})
          for i, (x, y) in enumerate(((255, 290), (771, 284), (1275, 285)))],
        *[(f"patch_damp_{i}", x, y, "W", 104, {"colors": 12})
          for i, (x, y) in enumerate(((262, 758), (767, 757), (1284, 758)))],
    ],
    "bs_l01_a_giant_stele.png": [("stele_giant", 627, 619, "H", 190, {})],
    "bs_l01_b_markers.png": [
        ("stele_fallen_a", 284, 216, "W", 100, {}),
        ("stele_fallen_b", 784, 222, "W", 92, {}),
        ("stele_fallen_c", 1267, 222, "W", 92, {}),
        ("stele_mid_a", 215, 664, "H", 84, {}),
        ("stele_mid_b", 572, 719, "H", 64, {}),
        ("stele_small_a", 868, 794, "H", 40, {}),
        ("stele_small_b", 1131, 807, "H", 40, {}),
        ("cairn", 1377, 829, "H", 30, {}),
    ],
    "bs_l02_a_gate.png": [("gate_cavern", 860, 447, "W", 320, {})],
    "bs_l02_b_cliff_face.png": [
        ("cliff_face_a", 768, 282, "W", 320, {}),
        ("cliff_face_b", 768, 734, "W", 320, {}),
    ],
    "bs_l02_c_cliff_rim.png": [
        ("cliff_rim_a", 517, 371, "W", 320, {}),
        ("cliff_rim_b", 518, 644, "W", 320, {}),
        ("cliff_end_l", 1140, 489, "H", 170, {}),
        ("cliff_end_r", 1388, 487, "H", 170, {}),
    ],
    "bs_l03_a_gully.png": [
        ("gully_a", 768, 298, "W", 320, {}),
        ("gully_b", 768, 733, "W", 320, {}),
    ],
    "bs_l03_b_bridges.png": [
        ("bridge_stone", 336, 294, "W", 96, {}),   # deck must clear the 88 px main road
        ("bridge_wood_broken", 769, 315, "H", 104, {"group": "bridge_wood"}),
        ("bridge_wood_fixed", 1191, 309, "H", 104, {"group": "bridge_wood"}),
        ("gully_end_l", 424, 780, "W", 96, {}),
        ("gully_end_r", 1108, 779, "W", 96, {}),
    ],
    "bs_l04_terrace.png": [
        ("terrace_a", 768, 234, "W", 320, {}),
        ("terrace_b", 768, 486, "W", 320, {}),
        ("terrace_end_l", 264, 769, "W", 64, {}),
        ("terrace_ramp", 768, 766, "W", 160, {}),
        ("terrace_end_r", 1272, 767, "W", 64, {}),
    ],
    "bs_q01_props.png": [
        ("prop_salt_cart", 256, 319, "W", 96, {}),
        ("prop_signpost", 670, 294, "H", 72, {}),
        ("prop_patrol_post", 1013, 301, "H", 64, {}),
        ("prop_rope_post", 1367, 345, "H", 56, {}),
        ("prop_chest_closed", 158, 786, "W", 40, {"group": "chest"}),
        ("prop_chest_open", 445, 759, "W", 40, {"group": "chest"}),
        ("prop_tracks", 750, 784, "W", 40, {}),
        ("prop_wheel", 1078, 784, "W", 40, {}),
        ("prop_spear", 1404, 730, "H", 56, {}),
    ],
    "bs_r01_a_small_medium.png": [
        *[(f"rock_s_{i}", x, y, "W", 18, {"colors": 16})
          for i, (x, y) in enumerate(((295, 299), (606, 305), (929, 299), (1244, 308)))],
        *[(f"rock_m_{i}", x, y, "W", w, {"colors": 16})
          for i, (x, y, w) in enumerate(((161, 690, 44), (480, 681, 40), (782, 667, 36),
                                         (1090, 689, 46), (1392, 686, 38)))],
    ],
    "bs_r01_b_boulders.png": [
        ("boulder_a", 395, 298, "W", 104, {"colors": 16}),
        ("boulder_b", 1133, 289, "W", 108, {"colors": 16}),
        ("boulder_c", 771, 769, "W", 120, {"colors": 16}),
    ],
    "bs_t01_a.png": [("tree_big_a", 627, 617, "H", 220, {})],
    "bs_t01_b.png": [("tree_big_b", 629, 621, "H", 212, {})],
    "bs_t01_c.png": [("tree_big_c", 627, 608, "H", 228, {})],
    "bs_t01_d.png": [("tree_big_d", 627, 630, "H", 216, {})],
    "bs_t01_e_maple.png": [("tree_maple", 629, 623, "H", 200, {"sat": 0.72})],
    "bs_t02_a_broadleaf.png": [
        ("tree_mid_a", 454, 517, "H", 160, {}),
        ("tree_mid_b", 1116, 493, "H", 172, {}),
    ],
    "bs_t02_b_dead.png": [
        ("tree_dead_a", 383, 497, "H", 176, {}),
        ("tree_dead_b", 1144, 520, "H", 164, {}),
    ],
    "bs_t03_a_shrubs.png": [
        ("shrub_a", 278, 270, "W", 56, {}),
        ("shrub_b", 761, 274, "W", 52, {}),
        ("shrub_rust", 1253, 270, "W", 56, {"sat": 0.75}),
        ("shrub_c", 472, 733, "W", 60, {}),
        ("bramble", 1068, 742, "W", 68, {}),
    ],
    "bs_t03_b_ferns.png": [
        ("fern_a", 287, 324, "W", 48, {}),
        ("fern_b", 776, 312, "W", 44, {}),
        ("fern_c", 1274, 324, "W", 48, {}),
        ("grass_tall_a", 517, 743, "H", 36, {}),
        ("grass_tall_b", 1024, 740, "H", 36, {}),
    ],
}

TILES = {
    "bs_g01_a_grass.png": "ground_grass",
    "bs_g01_b_dirtroad.png": "ground_dirt",
    "bs_g01_c_gravel.png": "ground_gravel",
    "bs_g01_d_flagstone.png": "ground_flagstone",
}


def is_key(rgb):
    r, g, b = (rgb[..., i].astype(int) for i in range(3))
    return (r - g > 70) & (b - g > 70) & (r > 140) & (b > 140)


def components(rgb):
    fg = ndi.binary_opening(~is_key(rgb), iterations=2)
    labels, _ = ndi.label(ndi.binary_dilation(fg, iterations=14))
    return fg, labels


def pick(labels, x, y):
    """Smallest component whose bounding box contains (x, y)."""
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


def area_down(rgb, mask, size):
    def resize(ch):
        return np.asarray(Image.fromarray(ch.astype(np.float32)).resize(size, Image.BOX))

    m = mask.astype(np.float32)
    cov = resize(m)
    out = np.zeros((size[1], size[0], 4), np.uint8)
    for c in range(3):
        out[..., c] = np.clip(resize(rgb[..., c] * m) / np.maximum(cov, 1e-6), 0, 255)
    out[..., 3] = np.where(cov >= 0.5, 255, 0)
    return out


def finish(rgba, sat, colors):
    """Mute + quantize opaque pixels, then upscale to world resolution."""
    opaque = rgba[..., 3] > 0
    px = rgba[..., :3][opaque]
    if len(px):
        w = 256
        rows = math.ceil(len(px) / w)
        pad = np.concatenate([px, np.repeat(px[:1], rows * w - len(px), axis=0)])
        strip = ImageEnhance.Color(Image.fromarray(pad.reshape(rows, w, 3))).enhance(sat)
        strip = strip.quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                               dither=Image.Dither.NONE).convert("RGB")
        rgba = rgba.copy()
        rgba[..., :3][opaque] = np.asarray(strip).reshape(-1, 3)[: len(px)]
        rgba[..., :3][~opaque] = 0
    img = Image.fromarray(rgba, "RGBA")
    return img.resize((img.width * DENSITY, img.height * DENSITY), Image.NEAREST)


def build_sheet(path, items, out, manifest):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    fg, labels = components(rgb.astype(np.uint8))
    picked = []
    for name, x, y, axis, world, opt in items:
        idx, sl = pick(labels, x, y)
        mask = (labels[sl] == idx) & fg[sl]
        ys, xs = np.nonzero(mask)
        box = (sl[1].start + xs.min(), sl[0].start + ys.min(),
               sl[1].start + xs.max() + 1, sl[0].start + ys.max() + 1)
        picked.append((name, axis, world, opt, box, idx))

    # One scale per group, taken from the group's first item, so frames/states match.
    group_scale = {}
    for name, axis, world, opt, box, _ in picked:
        dim = (box[3] - box[1]) if axis == "H" else (box[2] - box[0])
        scale = world / DENSITY / dim
        group_scale.setdefault(opt.get("group", name), scale)

    for name, axis, world, opt, box, idx in picked:
        scale = group_scale[opt.get("group", name)]
        x0, y0, x1, y1 = box
        crop = rgb[y0:y1, x0:x1]
        mask = (labels[y0:y1, x0:x1] == idx) & fg[y0:y1, x0:x1]
        size = (max(1, round((x1 - x0) * scale)), max(1, round((y1 - y0) * scale)))
        art = area_down(crop, mask, size)
        img = finish(art, opt.get("sat", SATURATION), opt.get("colors", 24))
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
        img.save(os.path.join(out, "sprites", name + ".png"))
        manifest[name] = {"sheet": os.path.basename(path), "source_box": list(map(int, box)),
                          "size": [img.width, img.height], "group": opt.get("group", "")}


def build_tile(path, name, out, manifest):
    img = Image.open(path).convert("RGB")
    art = img.resize((TILE_ART, TILE_ART), Image.BOX)
    rgba = np.dstack([np.asarray(art), np.full((TILE_ART, TILE_ART), 255, np.uint8)])
    tile = finish(rgba, SATURATION, 10)
    tile.save(os.path.join(out, "tiles", name + ".png"))
    manifest[name] = {"sheet": os.path.basename(path), "size": [tile.width, tile.height], "tile": True}


def board(out, manifest, role_sheet):
    frame = Image.open(role_sheet).convert("RGBA").crop((0, 0, 128, 128))
    side = round(128 * PLAYER_SCALE)
    player = frame.resize((side, side), Image.NEAREST)
    grass = Image.open(os.path.join(out, "tiles", "ground_grass.png")).convert("RGBA")
    sprites = [(n, Image.open(os.path.join(out, "sprites", n + ".png"))) for n, m in manifest.items()
               if not m.get("tile")]
    width, pad = 1500, 12
    rows, row, row_w = [], [], side + pad * 2
    for n, img in sprites:
        if row and row_w + img.width + pad > width:
            rows.append(row)
            row, row_w = [], side + pad * 2
        row.append(img)
        row_w += img.width + pad
    rows.append(row)
    heights = [max(max(i.height for i in r), side) + pad * 2 for r in rows]
    canvas = Image.new("RGBA", (width, sum(heights)))
    for y in range(0, canvas.height, grass.height):
        for x in range(0, width, grass.width):
            canvas.alpha_composite(grass, (x, y))
    y = 0
    for r, h in zip(rows, heights):
        base = y + h - pad
        canvas.alpha_composite(player, (pad, base - side))
        x = side + pad * 2
        for img in r:
            canvas.alpha_composite(img, (x, base - img.height))
            x += img.width + pad
        y += h
    canvas.convert("RGB").save(os.path.join(out, "board.png"))


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    src, out, role_sheet = sys.argv[1:]
    if os.path.abspath(out).startswith(os.path.abspath(src)):
        sys.exit("out_dir must not be inside src_dir")
    for sub in ("sprites", "tiles"):
        os.makedirs(os.path.join(out, sub), exist_ok=True)
    manifest = {}
    for sheet, name in TILES.items():
        build_tile(os.path.join(src, sheet), name, out, manifest)
    for sheet, items in SHEETS.items():
        build_sheet(os.path.join(src, sheet), items, out, manifest)
        print(f"{sheet:30s} {len(items)} sprites")
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    board(out, manifest, role_sheet)
    print("sprites", sum(1 for m in manifest.values() if not m.get("tile")), "tiles", len(TILES))


if __name__ == "__main__":
    main()
