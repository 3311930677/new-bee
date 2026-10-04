"""Direct video cutouts. Prepare contact sheets before choosing chronological cycles."""
from pathlib import Path
import argparse
import hashlib
import json

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "shots/three_roles_video_20261004"
DIRECTIONS = ["down", "left", "right", "up"]
CYCLES = {
    "fz": {"down": (22, 35), "left": (191, 30), "right": (250, 25), "up": (115, 24)},
    "ck": {"down": (25, 24), "left": (274, 26), "right": (317, 24), "up": (129, 25)},
    "zs": {"down": (15, 24), "left": (229, 30), "right": (319, 28), "up": (115, 27)},
}
IDLE_SOURCE = {
    "fz": {"down": 34, "left": 191, "right": 274, "up": 119},
    "ck": {"down": 37, "left": 282, "right": 329, "up": 133},
    "zs": {"down": 26, "left": 237, "right": 326, "up": 141},
}
ROLES = {
    "fz": {"name": "chenxing", "video": "1791088166056..mp4", "green": False,
           "ranges": {"down": [4, 65], "up": [85, 164], "left": [180, 233], "right": [250, 315]}},
    "ck": {"name": "chuanyang", "video": "1791088493611..mp4", "green": False,
           "ranges": {"down": [5, 95], "up": [116, 183], "left": [252, 306], "right": [316, 360]}},
    "zs": {"name": "pojun", "video": "1791088685824..mp4", "green": True,
           "ranges": {"down": [5, 66], "up": [88, 172], "left": [195, 275], "right": [290, 360]}}
}


def cutout(rgb, green, role):
    h, w = rgb.shape[:2]
    crop = (int(w * .05), int(h * .04), int(w * .95), int(h * .97))
    a = rgb[crop[1]:crop[3], crop[0]:crop[2]].copy()
    r, g, b = [a[:, :, i].astype(np.int16) for i in range(3)]
    spread = np.ptp(a.astype(np.int16), axis=2)
    low = a.min(axis=2)
    if green:
        possible_bg = (g > r * 1.25) & (b > r * 1.15) & (abs(g - b) < 32) & (r < 95)
    else:
        possible_bg = (spread <= 22) & (low >= 180)
    hsv = cv2.cvtColor(a, cv2.COLOR_RGB2HSV)
    colored = (hsv[:, :, 1] > 65) & (hsv[:, :, 2] > 55) & ~possible_bg
    yy, xx = np.where(colored)
    ground = np.arange(a.shape[0])[:, None] >= np.percentile(yy, 99.8) - 30
    if green:
        possible_bg |= ground & (spread < 34) & (low < 100) & (g >= r + 6) & (b >= r + 6)
    else:
        possible_bg |= ground & (spread <= 20) & (low >= 60) & (low < 185)
    _, labels, _, _ = cv2.connectedComponentsWithStats(possible_bg.astype("uint8"), 4)
    exterior = np.unique(np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1])))
    foreground = (~np.isin(labels, exterior[exterior != 0])).astype("uint8")
    if role == "ck":
        # White background gaps under the moving ponytail can be enclosed by
        # the silhouette. Keep the silver spear blade above this band intact.
        band = (np.arange(a.shape[0])[:, None] > a.shape[0] * .30) & (np.arange(a.shape[0])[:, None] < a.shape[0] * .78)
        foreground[(spread <= 10) & (low >= 215) & band] = 0
    n, components, stats, _ = cv2.connectedComponentsWithStats(foreground, 8)
    largest = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    alpha = (components == largest).astype("uint8") * 255
    result = np.dstack((a, alpha))
    result[alpha == 0] = 0
    assert np.array_equal(result[:, :, :3][alpha > 0], a[alpha > 0])
    return Image.fromarray(result), crop


def prepare(roles_selected=None, reuse=False):
    OUT.mkdir(exist_ok=True, parents=True)
    for role, cfg in ROLES.items():
        if roles_selected and role not in roles_selected:
            continue
        folder = OUT / role
        folder.mkdir(exist_ok=True)
        path = ROOT.parent / cfg["video"]
        cap = cv2.VideoCapture(str(path))
        fps = cap.get(cv2.CAP_PROP_FPS)
        report = {"video": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                  "fps": fps, "role": role, "directions": {}}
        decoded = {}
        cached = json.loads((folder / "extraction.json").read_text()) if reuse else None
        index = 0
        while not reuse:
            ok, bgr = cap.read()
            if not ok:
                break
            if any(start <= index <= end for start, end in cfg["ranges"].values()):
                decoded[index] = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            index += 1
        cap.release()
        for direction, (start, end) in cfg["ranges"].items():
            dest = folder / direction
            dest.mkdir(exist_ok=True)
            cuts, records = [], []
            for index in range(start, end + 1):
                if reuse:
                    cut = Image.open(dest / f"source_{index:03d}.png").convert("RGBA")
                    crop = cached["directions"][direction]["frames"][index - start]["crop"]
                else:
                    cut, crop = cutout(decoded[index], cfg["green"], role)
                bbox = cut.getchannel("A").getbbox()
                cuts.append(cut)
                records.append({"frame": index, "time": index / fps, "crop": crop,
                                "bbox": bbox, "original_rgb_preserved": True})
                if not reuse:
                    cut.save(dest / f"source_{index:03d}.png")
            indices = np.array([rec["frame"] for rec in records])
            boxes = np.array([rec["bbox"] for rec in records])
            # Fit slow camera drift across the whole shot, preserving per-frame gait.
            heights = boxes[:, 3] - boxes[:, 1]
            widths = boxes[:, 2] - boxes[:, 0]
            height_trend = np.polyval(np.polyfit(indices, heights, 1), indices)
            scales = 110 / height_trend
            center = (boxes[:, 0] + boxes[:, 2]) / 2
            center_trend = np.polyval(np.polyfit(indices, center, 1), indices)
            floor_trend = np.polyval(np.polyfit(indices, boxes[:, 3], 1), indices)
            cycle_start, cycle_count = CYCLES[role][direction]
            selected = (indices >= cycle_start) & (indices < cycle_start + cycle_count)
            extent = max(np.max(((center_trend - boxes[:, 0]) * scales)[selected]), np.max(((boxes[:, 2] - center_trend) * scales)[selected]))
            factor = min(1, 60 / extent, 116 / np.max(((floor_trend - boxes[:, 1]) * scales)[selected]))
            bottom_excursion = np.max(((boxes[:, 3] - floor_trend) * scales)[selected])
            if bottom_excursion > 0:
                factor = min(factor, 4 / bottom_excursion)
            scales *= factor
            tiles = []
            for i, (rec, cut) in enumerate(zip(records, cuts)):
                scale = scales[i]
                reduced = cut.resize((round(cut.width * scale), round(cut.height * scale)), Image.Resampling.NEAREST)
                origin = (round(64 - center_trend[i] * scale), round(120 - floor_trend[i] * scale))
                tile = Image.new("RGBA", (128, 128))
                tile.alpha_composite(reduced, origin)
                bbox = tile.getchannel("A").getbbox()
                if selected[i]:
                    assert bbox and min(bbox[:2]) >= 2 and max(bbox[2:]) <= 126, (role, direction, rec["frame"], bbox)
                rec.update(scale=scale, origin=origin, runtime_bbox=bbox,
                           rgba_sha256=hashlib.sha256(tile.tobytes()).hexdigest())
                tile.save(dest / f"packed_{rec['frame']:03d}.png")
                tiles.append(tile)
            data = [np.array(t.crop((16, 86, 112, 125))).astype(float) / 255 for t in tiles]
            periods = []
            for period in range(18, min(40, len(data) - 8)):
                errors = [(float(np.mean(abs(data[i] - data[i + period]))), start + i)
                          for i in range(len(data) - period)]
                periods.append({"period": period, "mean": float(np.mean([x[0] for x in errors])),
                                "best_pairs": sorted(errors)[:5]})
            periods.sort(key=lambda p: p["mean"])
            report["directions"][direction] = {"range": [start, end], "frames": records, "period_search": periods}
            for offset in range(0, len(tiles), 36):
                sheet = Image.new("RGB", (6 * 192, 6 * 216), "#29323d")
                draw = ImageDraw.Draw(sheet)
                for j, tile in enumerate(tiles[offset:offset + 36]):
                    scaled = tile.resize((192, 192), Image.Resampling.NEAREST)
                    x, y = j % 6 * 192, j // 6 * 216
                    sheet.paste(scaled, (x, y), scaled)
                    draw.text((x + 8, y + 194), f"#{start + offset + j} {(start + offset + j)/fps:.3f}s", fill="white")
                sheet.save(folder / f"{direction}_{offset//36}.png")
            print(role, direction, "periods", [(p["period"], round(p["mean"], 4)) for p in periods[:5]])
        (folder / "extraction.json").write_text(json.dumps(report, indent=2), encoding="utf-8")


def pack():
    import shutil
    all_rows = {}
    all_idles = {}
    for role, cfg in ROLES.items():
        folder = OUT / role
        data = json.loads((folder / "extraction.json").read_text())
        assert hashlib.sha256(Path(data["video"]).read_bytes()).hexdigest() == data["sha256"]
        columns = max(count for start, count in CYCLES[role].values())
        atlas = Image.new("RGBA", (columns * 128, 512))
        idles = Image.new("RGBA", (512, 128))
        rows, idle_cells = {}, {}
        provenance = {"video": data["video"], "sha256": data["sha256"], "fps": data["fps"],
                      "method": "consecutive original frames; background matte only; uniform camera registration; nearest sampling; no synthesis",
                      "directions": {}}
        subs, animations = [], []
        for row, direction in enumerate(DIRECTIONS):
            start, count = CYCLES[role][direction]
            records = {rec["frame"]: rec for rec in data["directions"][direction]["frames"]}
            tiles = []
            chosen_records = []
            for slot, source in enumerate(range(start, start + count)):
                tile = Image.open(folder / direction / f"packed_{source:03d}.png").convert("RGBA")
                rec = records[source]
                assert rec["original_rgb_preserved"]
                assert hashlib.sha256(tile.tobytes()).hexdigest() == rec["rgba_sha256"]
                atlas.paste(tile, (slot * 128, row * 128))
                tiles.append(tile)
                chosen_records.append(dict(rec, slot=slot))
                subs.append(f'[sub_resource type="AtlasTexture" id="Walk_{direction}_{slot}"]\natlas = ExtResource("1")\nregion = Rect2({slot*128}, {row*128}, 128, 128)\nfilter_clip = true\n')
            assert len(set(rec["rgba_sha256"] for rec in chosen_records)) > count * .75
            idle_slot = IDLE_SOURCE[role][direction] - start
            assert 0 <= idle_slot < count
            idle = tiles[idle_slot]
            idles.paste(idle, (row * 128, 0))
            subs.append(f'[sub_resource type="AtlasTexture" id="Idle_{direction}"]\natlas = ExtResource("2")\nregion = Rect2({row*128}, 0, 128, 128)\nfilter_clip = true\n')
            references = ', '.join('{"duration": 1.0, "texture": SubResource("Walk_%s_%d")}' % (direction, slot) for slot in range(count))
            animations.append('{\n"frames": [' + references + '],\n"loop": true,\n"name": &"walk_' + direction + '",\n"speed": 24.0\n}')
            animations.append('{\n"frames": [{"duration": 1.0, "texture": SubResource("Idle_' + direction + '")}],\n"loop": false,\n"name": &"idle_' + direction + '",\n"speed": 1.0\n}')
            provenance["directions"][direction] = {"source_range": [start, start + count - 1],
                                                  "count": count, "frames": chosen_records,
                                                  "idle_source_frame": IDLE_SOURCE[role][direction],
                                                  "idle_walk_slot": idle_slot, "idle_matches_walk_pixels": True}
            rows[direction] = tiles
            idle_cells[direction] = idle
        art = ROOT / "image/role" / role
        name = cfg["name"]
        walk_name = name + "_walk_video_v19.png"
        idle_name = name + "_idle_video_v19.png"
        atlas.save(art / walk_name)
        idles.save(art / idle_name)
        resource = art / (name + "_walk_frames.tres")
        backup = folder / (name + "_walk_frames_before_v19.tres")
        if not backup.exists():
            shutil.copy2(resource, backup)
        text = f'[gd_resource type="SpriteFrames" load_steps={3 + len(subs)} format=3]\n\n'
        text += f'[ext_resource type="Texture2D" path="res://image/role/{role}/{walk_name}" id="1"]\n'
        text += f'[ext_resource type="Texture2D" path="res://image/role/{role}/{idle_name}" id="2"]\n\n'
        text += '\n'.join(subs) + '\n[resource]\nanimations = [' + ',\n'.join(animations) + ']\n'
        text += 'metadata/direct_video = true\n'
        for direction in DIRECTIONS:
            text += f'metadata/idle_walk_start_{direction} = {IDLE_SOURCE[role][direction] - CYCLES[role][direction][0]}\n'
        resource.write_text(text, encoding="utf-8")
        (folder / "runtime_source_checks.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")
        all_rows[role] = rows
        all_idles[role] = idle_cells
    # All twelve directions at actual source cadence, then a held video idle,
    # then restart from the very same source pose used for idle.
    previews = []
    for tick in range(108):
        canvas = Image.new("RGB", (1000, 650), "#29323d")
        draw = ImageDraw.Draw(canvas)
        standing = 48 <= tick < 72
        draw.text((20, 12), "ORIGINAL VIDEO CUTOUTS / " + ("STOP" if standing else "WALK"), fill="white")
        for col, direction in enumerate(DIRECTIONS):
            draw.text((160 + col * 210, 36), direction.upper(), fill="white")
        for row, role in enumerate(["zs", "ck", "fz"]):
            draw.text((12, 135 + row * 192), ROLES[role]["name"], fill="white")
            for col, direction in enumerate(DIRECTIONS):
                tiles = all_rows[role][direction]
                if standing:
                    tile = all_idles[role][direction]
                else:
                    slot = tick % len(tiles) if tick < 48 else (tick - 72 + IDLE_SOURCE[role][direction] - CYCLES[role][direction][0]) % len(tiles)
                    tile = tiles[slot]
                large = tile.resize((192, 192), Image.Resampling.NEAREST)
                canvas.paste(large, (120 + col * 210, 64 + row * 192), large)
        previews.append(canvas)
    durations = [round((i+1)*1000/24/10)*10 - round(i*1000/24/10)*10 for i in range(108)]
    previews[0].save(OUT / "three_roles_walk_stop_v19.gif", save_all=True, append_images=previews[1:],
                     duration=durations, loop=0, disposal=2, optimize=False)
    previews[48].save(OUT / "three_roles_video_idle_v19.png")
    (OUT / "README.md").write_text(
        "# Three roles: direct video v19\n\n"
        "Each direction uses a consecutive source range at the original 24 FPS. "
        "No generated images, optical-flow interpolation, reversed frames or mirrored directions. "
        "Background removal, uniform camera registration and nearest-neighbor resize only. "
        "The original videos have no dedicated four-direction stationary shots; idle holds "
        "a narrow, grounded pose copied exactly from that character's own walk cycle.\n\n"
        "Source ranges, timestamps, crop bounds, registration and RGBA hashes are in "
        "each role's runtime_source_checks.json. Previous resource bindings are backed up beside it. "
        "The fs assets and its 7 FPS front/back playback are preserved.\n",
        encoding="utf-8")
    print("THREE_ROLES_PACKED: 322 consecutive video frames, 12 matching video idle poses")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--roles", nargs="*")
    parser.add_argument("--reuse", action="store_true")
    parser.add_argument("--pack", action="store_true")
    args = parser.parse_args()
    if args.pack:
        pack()
    else:
        prepare(args.roles, args.reuse)
