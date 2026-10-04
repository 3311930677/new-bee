"""Direct chronological front/back cutouts; preserve the authored slow gait cycle."""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

from analyze_side_video_v17 import extract

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "shots/shuangyu_front_back_video_v20_20261004"
ART = ROOT / "image/role/fs"
VIDEO = Path(r"C:\Users\tsz\Downloads\video_20261003_204732.mp4")
RANGES = {"down": (3, 86), "up": (92, 131)}
CYCLES = {"down": (35, 33), "up": (99, 31)}
IDLE_SOURCE = {"down": 63, "up": 121}
GAIT_SECONDS = 6 / 7  # Previous six-frame animation at the user's chosen 7 FPS.


def prepare():
    OUT.mkdir(exist_ok=True, parents=True)
    cap = cv2.VideoCapture(str(VIDEO))
    report = {"video": str(VIDEO), "sha256": hashlib.sha256(VIDEO.read_bytes()).hexdigest(),
              "source_fps": cap.get(cv2.CAP_PROP_FPS), "directions": {}}
    for direction, (start, end) in RANGES.items():
        folder = OUT / direction
        folder.mkdir(exist_ok=True)
        cuts, records = [], []
        cap.set(cv2.CAP_PROP_POS_FRAMES, start)
        for index in range(start, end + 1):
            ok, bgr = cap.read()
            assert ok
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            cut, crop = extract(rgb)
            mask = np.array(cut)[:, :, 3] > 0
            original = rgb[crop[1]:crop[3], crop[0]:crop[2]]
            assert np.array_equal(np.array(cut)[:, :, :3][mask], original[mask])
            cut.save(folder / f"source_{index:03d}.png")
            records.append({"source_frame": index, "timestamp_seconds": index / report["source_fps"],
                            "crop": crop, "bbox": cut.getchannel("A").getbbox(), "original_rgb_preserved": True})
            cuts.append(cut)
        indices = np.array([rec["source_frame"] for rec in records])
        boxes = np.array([rec["bbox"] for rec in records])
        heights = boxes[:, 3] - boxes[:, 1]
        height_trend = np.polyval(np.polyfit(indices, heights, 1), indices)
        center_trend = np.polyval(np.polyfit(indices, (boxes[:, 0] + boxes[:, 2]) / 2, 1), indices)
        floor_trend = np.polyval(np.polyfit(indices, boxes[:, 3], 1), indices)
        scales = 110 / height_trend
        extent = max(np.max((center_trend - boxes[:, 0]) * scales), np.max((boxes[:, 2] - center_trend) * scales))
        factor = min(1, 60 / extent, 116 / np.max((floor_trend - boxes[:, 1]) * scales))
        excursion = np.max((boxes[:, 3] - floor_trend) * scales)
        if excursion > 0:
            factor = min(factor, 4 / excursion)
        scales *= factor
        tiles = []
        for i, (rec, cut) in enumerate(zip(records, cuts)):
            scale = scales[i]
            reduced = cut.resize((round(cut.width * scale), round(cut.height * scale)), Image.Resampling.NEAREST)
            origin = (round(64 - center_trend[i] * scale), round(120 - floor_trend[i] * scale))
            tile = Image.new("RGBA", (128, 128))
            tile.alpha_composite(reduced, origin)
            bbox = tile.getchannel("A").getbbox()
            assert bbox and min(bbox[:2]) >= 2 and max(bbox[2:]) <= 126, (direction, rec["source_frame"], bbox)
            tile.save(folder / f"packed_{rec['source_frame']:03d}.png")
            rec.update(scale=scale, origin=origin, runtime_bbox=bbox, rgba_sha256=hashlib.sha256(tile.tobytes()).hexdigest())
            tiles.append(tile)
        legs = [np.array(im.crop((24, 87, 104, 125))).astype(float) / 255 for im in tiles]
        periods = []
        for period in range(18, min(44, len(tiles) - 4)):
            errors = [(float(np.mean(abs(legs[i] - legs[i + period]))), start + i) for i in range(len(legs) - period)]
            periods.append({"period": period, "mean": float(np.mean([p[0] for p in errors])), "best_pairs": sorted(errors)[:5]})
        periods.sort(key=lambda p: p["mean"])
        report["directions"][direction] = {"range": [start, end], "frames": records, "period_search": periods}
        for offset in range(0, len(tiles), 36):
            sheet = Image.new("RGB", (6 * 192, 6 * 216), "#29323d")
            draw = ImageDraw.Draw(sheet)
            for j, tile in enumerate(tiles[offset:offset + 36]):
                x, y = j % 6 * 192, j // 6 * 216
                im = tile.resize((192, 192), Image.Resampling.NEAREST)
                sheet.paste(im, (x, y), im)
                draw.text((x + 6, y + 195), f"{direction} #{start+offset+j}", fill="white")
            sheet.save(OUT / f"{direction}_{offset//36}.png")
        print(direction, [(p["period"], round(p["mean"], 4), p["best_pairs"][:2]) for p in periods[:4]])
    cap.release()
    (OUT / "extraction.json").write_text(json.dumps(report, indent=2), encoding="utf-8")


def pack():
    report = json.loads((OUT / "extraction.json").read_text())
    assert hashlib.sha256(VIDEO.read_bytes()).hexdigest() == report["sha256"]
    resource = ART / "shuangyu_walk_frames.tres"
    backup = OUT / "shuangyu_walk_frames_before_v20.tres"
    if not backup.exists():
        shutil.copy2(resource, backup)
    text = backup.read_text(encoding="utf-8")
    columns = max(count for start, count in CYCLES.values())
    atlas = Image.new("RGBA", (columns * 128, 256))
    idle_atlas = Image.new("RGBA", (256, 128))
    manifest = {"video": str(VIDEO), "sha256": report["sha256"], "source_fps": 30,
                "method": "consecutive original RGB frames; neutral matte removal; uniform camera registration; nearest resize; no generated poses",
                "vertical_gait_cycle_seconds": GAIT_SECONDS, "previous_cadence": "6 frames / 7 FPS",
                "directions": {}, "preserved_side_assets": {}}
    subs = []
    animations = []
    tiles_by_direction = {}
    for row, direction in enumerate(["down", "up"]):
        start, count = CYCLES[direction]
        records = {rec["source_frame"]: rec for rec in report["directions"][direction]["frames"]}
        chosen_records = []
        tiles = []
        for slot, index in enumerate(range(start, start + count)):
            rec = dict(records[index], slot=slot)
            tile = Image.open(OUT / direction / f"packed_{index:03d}.png").convert("RGBA")
            assert hashlib.sha256(tile.tobytes()).hexdigest() == rec["rgba_sha256"]
            atlas.paste(tile, (slot * 128, row * 128))
            tiles.append(tile)
            chosen_records.append(rec)
            subs.append(f'[sub_resource type="AtlasTexture" id="Video_{direction}_{slot}"]\natlas = ExtResource("4_video_vertical")\nregion = Rect2({slot*128}, {row*128}, 128, 128)\nfilter_clip = true\n')
        idle_slot = IDLE_SOURCE[direction] - start
        idle_atlas.paste(tiles[idle_slot], (row * 128, 0))
        subs.append(f'[sub_resource type="AtlasTexture" id="Idle_{direction}"]\natlas = ExtResource("5_idle_vertical")\nregion = Rect2({row*128}, 0, 128, 128)\nfilter_clip = true\n')
        fps = count / GAIT_SECONDS
        refs = ', '.join('{"duration": 1.0, "texture": SubResource("Video_%s_%d")}' % (direction, slot) for slot in range(count))
        replacement = '{\n"frames": [' + refs + '],\n"loop": true,\n"name": &"walk_' + direction + f'",\n"speed": {fps:.12g}\n' + '}'
        pattern = r'\{\n"frames": \[[^\n]*\],\n"loop": true,\n"name": &"walk_' + direction + r'",\n"speed": [\d.]+\n\}'
        text, changed = re.subn(pattern, replacement, text)
        assert changed == 1
        animations.append('{\n"frames": [{"duration": 1.0, "texture": SubResource("Idle_' + direction + '")}],\n"loop": false,\n"name": &"idle_' + direction + '",\n"speed": 1.0\n}')
        manifest["directions"][direction] = {"source_range": [start, start + count - 1], "count": count,
                                              "playback_fps": fps, "atlas_row": row, "atlas_size": [columns * 128, 256],
                                              "idle_source_frame": IDLE_SOURCE[direction], "idle_walk_slot": idle_slot,
                                              "idle_matches_walk_pixels": True, "frames": chosen_records}
        tiles_by_direction[direction] = tiles
    atlas.save(ART / "shuangyu_walk_vertical_video_v20.png")
    idle_atlas.save(ART / "shuangyu_idle_vertical_video_v20.png")
    for index in list(range(6)) + list(range(18, 24)):
        text, removed = re.subn(r'\[sub_resource type="AtlasTexture" id="Atlas_' + str(index) + r'"\]\n.*?(?=\[)', '', text, flags=re.S)
        assert removed == 1
    text = re.sub(r'\[ext_resource type="Texture2D" path="res://image/role/fs/shuangyu_walk_4dir.png" id="1"\]\n\n', '', text)
    ext = '[ext_resource type="Texture2D" path="res://image/role/fs/shuangyu_walk_vertical_video_v20.png" id="4_video_vertical"]\n'
    ext += '[ext_resource type="Texture2D" path="res://image/role/fs/shuangyu_idle_vertical_video_v20.png" id="5_idle_vertical"]\n\n'
    first = text.index('[sub_resource')
    text = text[:first] + ext + text[first:]
    text = text.replace('[resource]', '\n'.join(subs) + '\n[resource]', 1)
    end = text.rfind(']')
    text = text[:end] + ',\n' + ',\n'.join(animations) + '\n' + text[end:]
    text += '\nmetadata/direct_video = true\nmetadata/video_source_manifest = "res://shots/shuangyu_front_back_video_v20_20261004/runtime_source_checks.json"\n'
    text += f'metadata/vertical_gait_cycle_seconds = {GAIT_SECONDS:.12g}\n'
    sides = json.loads((ROOT / "shots/walk_video_v17_20261004/direct_extraction_checks.json").read_text())
    side_atlas = Image.open(ART / "shuangyu_walk_side_video_v17.png").convert("RGBA")
    side_idle = Image.open(ART / "shuangyu_idle_side_video_v18.png").convert("RGBA")
    for row, direction in enumerate(["left", "right"]):
        idle_slot = 28 if direction == "left" else 2
        info = sides["directions"][direction]
        manifest["directions"][direction] = {"count": 30, "playback_fps": 30, "atlas_row": row, "atlas_size": [3840, 256],
                                              "idle_walk_slot": idle_slot, "source_range": info["source_range"], "frames": info["frames"]}
        tiles_by_direction[direction] = [side_atlas.crop((slot*128, row*128, (slot+1)*128, (row+1)*128)) for slot in range(30)]
        assert side_idle.crop((row*128, 0, (row+1)*128, 128)).tobytes() == tiles_by_direction[direction][idle_slot].tobytes()
    for direction, info in manifest["directions"].items():
        text += f'metadata/idle_walk_start_{direction} = {info["idle_walk_slot"]}\n'
    steps = 1 + text.count('[ext_resource') + text.count('[sub_resource')
    text = re.sub(r'load_steps=\d+', f'load_steps={steps}', text, count=1)
    resource.write_text(text, encoding="utf-8")
    for name in ["shuangyu_walk_side_video_v17.png", "shuangyu_idle_side_video_v18.png"]:
        manifest["preserved_side_assets"][name] = hashlib.sha256((ART / name).read_bytes()).hexdigest()
    (OUT / "runtime_source_checks.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    verify_original_pixels(manifest)
    previews = []
    for tick in range(192):
        standing = 96 <= tick < 144
        canvas = Image.new("RGB", (820, 260), "#29323d")
        draw = ImageDraw.Draw(canvas)
        draw.text((15, 12), 'SHUANGYU / VIDEO ORIGINALS / ' + ('STOP' if standing else 'WALK'), fill="white")
        for col, direction in enumerate(["down", "left", "right", "up"]):
            info = manifest["directions"][direction]
            if standing:
                slot = info["idle_walk_slot"]
            else:
                slot = int(tick * info["playback_fps"] / 60) % info["count"] if tick < 96 else (int((tick - 144) * info["playback_fps"] / 60) + info["idle_walk_slot"]) % info["count"]
            tile = tiles_by_direction[direction][slot].resize((192, 192), Image.Resampling.NEAREST)
            canvas.paste(tile, (col * 205 + 5, 40), tile)
            draw.text((col * 205 + 74, 240), direction.upper(), fill="white")
        previews.append(canvas)
    duration = [round((i+1)*100/60)*10 - round(i*100/60)*10 for i in range(192)]
    previews[0].save(OUT / "shuangyu_4dir_video_v20.gif", save_all=True, append_images=previews[1:], duration=duration, loop=0, disposal=2)
    previews[96].save(OUT / "shuangyu_4dir_video_idle_v20.png")
    (OUT / "README.md").write_text(
        "# Shuangyu direct front/back v20\n\n"
        "Down: source 35..67 (33 continuous frames). Up: 99..129 (31 continuous frames). "
        "Idle: down 63, up 121, exact copies of the corresponding walk cells. "
        "No synthesized or interpolated frames. Side image assets are unchanged.\n\n"
        "The previous user-selected cadence was a six-frame cycle at 7 FPS (6/7 second). "
        "With 33/31 consecutive frames, playback is 38.5 / 36.1666667 FPS to keep that same gait period. "
        "Translation speed is unchanged. Every opaque exported RGB pixel was independently compared "
        "with its corresponding original video frame after the recorded uniform registration.\n",
        encoding="utf-8")
    print("SHUANGYU_VERTICAL_V20_OK: 64 consecutive original video frames; exact video idles; prior slow gait period preserved")


def verify_original_pixels(manifest):
    wanted = {}
    for row, direction in enumerate(["down", "up"]):
        info = manifest["directions"][direction]
        assert [rec["source_frame"] for rec in info["frames"]] == list(range(info["source_range"][0], info["source_range"][1] + 1))
        for rec in info["frames"]:
            wanted[rec["source_frame"]] = (row, rec)
        assert abs(info["count"] / info["playback_fps"] - GAIT_SECONDS) < 1e-10
    atlas = Image.open(ART / "shuangyu_walk_vertical_video_v20.png").convert("RGBA")
    idle = Image.open(ART / "shuangyu_idle_vertical_video_v20.png").convert("RGBA")
    cap = cv2.VideoCapture(str(VIDEO))
    index = 0
    verified = 0
    while index <= max(wanted):
        ok, bgr = cap.read()
        assert ok
        if index in wanted:
            row, rec = wanted[index]
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            x0, y0, x1, y1 = rec["crop"]
            raw = Image.fromarray(rgb[y0:y1, x0:x1])
            scaled = raw.resize((round(raw.width * rec["scale"]), round(raw.height * rec["scale"])), Image.Resampling.NEAREST)
            expected = Image.new("RGB", (128, 128))
            expected.paste(scaled, tuple(rec["origin"]))
            slot = rec["slot"]
            tile = atlas.crop((slot*128, row*128, (slot+1)*128, (row+1)*128))
            a = np.array(tile)
            mask = a[:, :, 3] > 0
            assert np.array_equal(a[:, :, :3][mask], np.array(expected)[mask])
            assert np.all(a[~mask] == 0)
            assert hashlib.sha256(tile.tobytes()).hexdigest() == rec["rgba_sha256"]
            verified += 1
        index += 1
    cap.release()
    assert verified == len(wanted)
    for row, direction in enumerate(["down", "up"]):
        slot = manifest["directions"][direction]["idle_walk_slot"]
        assert idle.crop((row*128, 0, (row+1)*128, 128)).tobytes() == atlas.crop((slot*128, row*128, (slot+1)*128, (row+1)*128)).tobytes()
    (OUT / "independent_pixel_verification.json").write_text(json.dumps({"verified_original_rgb_frames": verified,
        "chronological_ranges": True, "idle_matches_walk_pixels": True, "gait_cycle_seconds": GAIT_SECONDS,
        "source_video_sha256": manifest["sha256"], "preserved_side_assets": manifest["preserved_side_assets"]}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack", action="store_true")
    args = parser.parse_args()
    if args.pack:
        pack()
    else:
        prepare()
