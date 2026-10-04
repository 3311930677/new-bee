"""Independently re-decode source videos and verify every exported foreground pixel."""
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

from build_three_video_walks import OUT, ROOT, ROLES, DIRECTIONS

total = 0
results = {}
for role, cfg in ROLES.items():
    folder = OUT / role
    report = json.loads((folder / "runtime_source_checks.json").read_text())
    source = Path(report["video"])
    assert hashlib.sha256(source.read_bytes()).hexdigest() == report["sha256"]
    atlas = Image.open(ROOT / f'image/role/{role}/{cfg["name"]}_walk_video_v19.png').convert("RGBA")
    idle_atlas = Image.open(ROOT / f'image/role/{role}/{cfg["name"]}_idle_video_v19.png').convert("RGBA")
    wanted = {}
    for row, direction in enumerate(DIRECTIONS):
        info = report["directions"][direction]
        indices = [frame["frame"] for frame in info["frames"]]
        assert indices == list(range(info["source_range"][0], info["source_range"][1] + 1))
        for rec in info["frames"]:
            wanted[rec["frame"]] = (row, direction, rec)
        idle_slot = info["idle_walk_slot"]
        idle = idle_atlas.crop((row * 128, 0, (row + 1) * 128, 128))
        walking = atlas.crop((idle_slot * 128, row * 128, (idle_slot + 1) * 128, (row + 1) * 128))
        assert idle.tobytes() == walking.tobytes()
    cap = cv2.VideoCapture(str(source))
    index = 0
    verified = []
    while True:
        ok, bgr = cap.read()
        if not ok:
            break
        if index in wanted:
            row, direction, rec = wanted[index]
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            x0, y0, x1, y1 = rec["crop"]
            raw = Image.fromarray(rgb[y0:y1, x0:x1])
            scaled = raw.resize((round(raw.width * rec["scale"]), round(raw.height * rec["scale"])), Image.Resampling.NEAREST)
            expected = Image.new("RGB", (128, 128))
            expected.paste(scaled, tuple(rec["origin"]))
            slot = rec["slot"]
            exported = atlas.crop((slot * 128, row * 128, (slot + 1) * 128, (row + 1) * 128))
            a = np.array(exported)
            mask = a[:, :, 3] > 0
            assert np.array_equal(a[:, :, :3][mask], np.array(expected)[mask]), (role, direction, index)
            assert np.all(a[~mask] == 0)
            assert set(np.unique(a[:, :, 3])) == {0, 255}
            assert hashlib.sha256(exported.tobytes()).hexdigest() == rec["rgba_sha256"]
            bbox = exported.getchannel("A").getbbox()
            assert bbox and min(bbox[:2]) >= 2 and max(bbox[2:]) <= 126
            verified.append(index)
        index += 1
    cap.release()
    assert set(verified) == set(wanted)
    total += len(verified)
    results[role] = {"source_sha256": report["sha256"], "verified_original_rgb_frames": len(verified),
                     "continuous_ranges": True, "idle_pixel_match": True, "transparent_background": True,
                     "no_runtime_clipping": True}
fs_resource = (ROOT / "image/role/fs/shuangyu_walk_frames.tres").read_text(encoding="utf-8")
if 'metadata/video_source_manifest' in fs_resource:
    import re
    fs_report = json.loads((ROOT / "shots/shuangyu_front_back_video_v20_20261004/runtime_source_checks.json").read_text())
    speeds = dict(re.findall(r'"name": &"([^"]+)",\s*"speed": ([\d.]+)', fs_resource))
    for direction in ["up", "down"]:
        assert abs(fs_report["directions"][direction]["count"] / float(speeds["walk_" + direction]) - 6 / 7) < 1e-8
else:
    for direction in ["up", "down"]:
        assert f'"name": &"walk_{direction}",\n"speed": 7.0' in fs_resource
(OUT / "independent_pixel_verification.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
print(f"THREE_VIDEO_PIXELS_OK: {total} original RGB frames; chronological ranges; 12 exact idle copies; fs slow gait preserved")
