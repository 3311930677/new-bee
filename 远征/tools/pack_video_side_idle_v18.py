"""Use exact video-derived walk cells as fixed side idle poses, without redrawing."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "image/role/fs"
OUT = ROOT / "shots/walk_idle_video_v18_20261004"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / "shots/walk_video_v17_20261004/direct_extraction_checks.json"
report = json.loads(SOURCE.read_text(encoding="utf-8"))
assert hashlib.sha256(Path(report["video"]).read_bytes()).hexdigest() == report["video_sha256"]
walk = Image.open(ART / "shuangyu_walk_side_video_v17.png").convert("RGBA")
old_idle = Image.open(ART / "shuangyu_idle_side_v16.png").convert("RGBA")
idle = Image.new("RGBA", (256, 128))
choices = {"left": 28, "right": 2}
provenance = {"video": report["video"], "video_sha256": report["video_sha256"],
              "method": "Exact RGBA copies from registered video cutouts; no redrawing or pose changes",
              "note": "The clip contains walking. Use the closest narrow, grounded gait pose as a fixed idle.",
              "directions": {}}
for row, (direction, slot) in enumerate(choices.items()):
    cell = walk.crop((slot * 128, row * 128, (slot + 1) * 128, (row + 1) * 128))
    info = report["directions"][direction]["frames"][slot]
    assert info["rgb_preserved"]
    assert hashlib.sha256(cell.tobytes()).hexdigest() == info["runtime_sha256"]
    idle.paste(cell, (row * 128, 0))
    provenance["directions"][direction] = {
        "walk_slot": slot, "source_frame": info["source_frame"],
        "timestamp_seconds": info["timestamp_seconds"], "runtime_bbox": cell.getbbox(),
        "rgba_sha256": info["runtime_sha256"], "exact_walk_cell_match": True}
idle_path = ART / "shuangyu_idle_side_video_v18.png"
idle.save(idle_path)
saved = Image.open(idle_path).convert("RGBA")
assert saved.tobytes() == idle.tobytes()
resource = ART / "shuangyu_walk_frames.tres"
text = resource.read_text(encoding="utf-8")
backup = OUT / "shuangyu_walk_frames_before_v18.tres"
if not backup.exists():
    backup.write_text(text, encoding="utf-8")
old = 'path="res://image/role/fs/shuangyu_idle_side_v16.png"'
new = 'path="res://image/role/fs/shuangyu_idle_side_video_v18.png"'
assert old in text or new in text
resource.write_text(text.replace(old, new), encoding="utf-8")
(OUT / "idle_source_checks.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2), encoding="utf-8")

# Review the real sequence: walk one cycle, hold a fixed pose, then resume.
frames, durations = [], []
sequence = [(i, False, [30, 30, 40][i % 3]) for i in range(30)]
sequence += [(0, True, 100)] * 12
sequence += [(i, False, [30, 30, 40][i % 3]) for i in range(30)]
for slot, standing, duration in sequence:
    canvas = Image.new("RGB", (880, 370), (35, 43, 53))
    draw = ImageDraw.Draw(canvas)
    draw.text((24, 16), "VIDEO WALK > STOP > WALK", fill="white")
    draw.text((24, 40), "Old idle", fill=(205, 214, 225))
    draw.text((464, 40), "Video idle (same character)", fill=(205, 214, 225))
    draw.text((330, 16), "STOP" if standing else "WALK", fill=(120, 215, 175))
    for row in range(2):
        for col in range(2):
            if standing:
                atlas = old_idle if col == 0 else idle
                cell = atlas.crop((row * 128, 0, (row + 1) * 128, 128))
            else:
                cell = walk.crop((slot * 128, row * 128, (slot + 1) * 128, (row + 1) * 128))
            cell = cell.resize((256, 256), Image.Resampling.NEAREST)
            x = col * 440 + row * 200 + 10
            canvas.paste(cell, (x, 74), cell)
    frames.append(canvas)
    durations.append(duration)
frames[0].save(OUT / "walk_stop_video_v18.gif", save_all=True, append_images=frames[1:],
               duration=durations, loop=0, disposal=2, optimize=False)
sheet = Image.new("RGB", (512, 276), (35, 43, 53))
draw = ImageDraw.Draw(sheet)
for row, (direction, slot) in enumerate(choices.items()):
    cell = idle.crop((row * 128, 0, (row + 1) * 128, 128)).resize((256, 256), Image.Resampling.NEAREST)
    sheet.paste(cell, (row * 256, 20), cell)
    draw.text((row * 256 + 12, 4), f'{direction}: video frame {provenance["directions"][direction]["source_frame"]}', fill="white")
sheet.save(OUT / "video_idle_review.png")
(OUT / "README.md").write_text(
    "# Video side idle v18\n\n"
    "Left: source frame 208 (6.933 s), walk slot 28. Right: source frame 252 (8.400 s), walk slot 2.\n\n"
    "The idle cells are pixel-identical to those video-derived walk cells. No generated pose, "
    "changed costume, recoloring, scaling or repositioning was introduced. The clip has no true "
    "stationary side shot; these narrow, grounded gait poses are held as fixed idle frames.\n\n"
    "Only the idle texture reference in SpriteFrames is replaced. Run this script after rebuilding v17.\n",
    encoding="utf-8")
print("VIDEO_SIDE_IDLE_V18_OK: exact video RGBA; left source 208, right source 252")
