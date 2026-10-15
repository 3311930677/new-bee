"""Preview a painted-ground prop layout and check it against gameplay positions.

Usage:
    python -I preview_painted_props.py <ground.png> <sprites_dir> <layout.json> <map_cfg.json> <out.png>

Reports props whose footprint (sprite bottom 30%) comes within the clearance of a
route centre line, monster/boss point, entity, spawn or exit.
"""
import json
import math
import sys

from PIL import Image, ImageDraw

CLEAR = {"route": 0.5, "monster": 46, "boss": 62, "entity": 40, "spawn": 60, "exit": 70}


def seg_dist(px, py, a, b):
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / max(dx * dx + dy * dy, 1e-6)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def foot_points(x, y, w, h):
    top = y - max(6, h * 0.3)
    return [(x + fx * w / 2, fy) for fx in (-1, -0.5, 0, 0.5, 1) for fy in (top, y)]


def main():
    ground_p, sprites, layout_p, cfg_p, out = sys.argv[1:]
    ground = Image.open(ground_p).convert("RGBA")
    with open(layout_p, encoding="utf-8") as f:
        props = json.load(f)["props"]
    with open(cfg_p, encoding="utf-8") as f:
        cfg = json.load(f)
    points = [("monster", m) for m in cfg.get("monster_positions", [])]
    points += [("boss", b["at"]) for b in cfg.get("optional_bosses", [])]
    points += [("entity", e["at"]) for e in cfg.get("entities", {}).values()]
    points += [("spawn", cfg["spawn"])] + [("exit", e["at"]) for e in cfg.get("exits", [])]
    problems = 0
    placed = []
    for name, x, y, solid in props:
        img = Image.open(f"{sprites}/{name}.png").convert("RGBA")
        feet = foot_points(x, y, img.width, img.height)
        for r in cfg["flat_routes"]:
            half = r["width"] / 2
            for a, b in zip(r["points"], r["points"][1:]):
                d = min(seg_dist(px, py, a, b) for px, py in feet)
                if d < half * (1 + CLEAR["route"]) and solid:
                    print(f"ROUTE  {name} at ({x},{y}) {d:.0f}px from route centre (half {half:.0f})")
                    problems += 1
                    break
        for kind, (qx, qy) in points:
            d = min(math.hypot(px - qx, py - qy) for px, py in feet)
            if d < CLEAR[kind]:
                print(f"{kind.upper():6s} {name} at ({x},{y}) {d:.0f}px from {kind} ({qx},{qy})")
                problems += 1
        placed.append((y, name, img, x))
    canvas = ground.copy()
    for y, name, img, x in sorted(placed):
        canvas.alpha_composite(img, (int(x - img.width / 2), int(y - img.height)))
    canvas.convert("RGB").save(out)
    marked = canvas.copy()
    d = ImageDraw.Draw(marked)
    for kind, (qx, qy) in points:
        r = CLEAR[kind]
        d.ellipse((qx - r, qy - r, qx + r, qy + r), outline=(255, 0, 255) if kind != "entity" else (255, 220, 0))
    for r in cfg["flat_routes"]:
        d.line([tuple(p) for p in r["points"]], fill=(255, 0, 0), width=2)
    marked.convert("RGB").save(out.replace(".png", "_marked.png"))
    print("props", len(props), "problems", problems)


if __name__ == "__main__":
    main()
