"""Draw layout guides for a main-world map straight from main_world_maps.json.

Usage:
    python -I make_layout_guide.py <main_world_maps.json> <map_id> <design.json> <out_dir>

design.json holds the art-layout decisions that are not in the game config
(pools, sea edge, embankment, landmark zones), all in world pixels.

Writes:
    <map_id>_guide_annotated.png   960x1248, labels + gameplay markers, for review
    <map_id>_guide_gpt.png         1024x1536, flat colour blocks only, no text,
                                   attached to the image prompt as a layout reference
"""
import json
import os
import sys

from PIL import Image, ImageDraw

GPT_SIZE = (1024, 1536)
COL = {
    "ground": (196, 186, 150), "road": (150, 118, 80), "pool": (70, 120, 120),
    "sea": (40, 80, 96), "surf": (210, 222, 210), "wall": (90, 92, 96), "grass": (120, 136, 90),
    "salt": (232, 232, 222), "lair": (180, 200, 205), "gate": (30, 30, 34),
    "plaza": (150, 146, 132), "gully": (52, 78, 80),
}


def draw_routes(d, routes, colour, scale=1.0):
    for r in routes:
        w = int(r["width"] * scale)
        pts = [(x * scale, y * scale) for x, y in r["points"]]
        d.line(pts, fill=colour, width=w, joint="curve")
        for x, y in pts:
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=colour)


def draw_design(d, design, sx, sy):
    def rect(r):
        x, y, w, h = r
        return (x * sx, y * sy, (x + w) * sx, (y + h) * sy)

    def ell(c):
        x, y, rx, ry = c
        return ((x - rx) * sx, (y - ry) * sy, (x + rx) * sx, (y + ry) * sy)

    for r in design.get("sea", []):
        d.rectangle(rect(r), fill=COL["sea"])
    for r in design.get("surf", []):
        d.rectangle(rect(r), fill=COL["surf"])
    for r in design.get("gully", []):
        d.rectangle(rect(r), fill=COL["gully"])
    for r in design.get("plaza", []):
        d.ellipse(ell(r), fill=COL["plaza"])
    for r in design.get("grass", []):
        d.ellipse(ell(r), fill=COL["grass"])
    for r in design.get("salt", []):
        d.ellipse(ell(r), fill=COL["salt"])
    for r in design.get("lair", []):
        d.ellipse(ell(r), fill=COL["lair"])
    for c in design.get("pools", []):
        d.ellipse(ell(c), fill=COL["pool"])
    for r in design.get("walls", []):
        d.rectangle(rect(r), fill=COL["wall"])
    for r in design.get("gate", []):
        d.rectangle(rect(r), fill=COL["gate"])


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    cfg_path, map_id, design_path, out = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    with open(cfg_path, encoding="utf-8") as f:
        cfg = json.load(f)["maps"][map_id]
    with open(design_path, encoding="utf-8") as f:
        design = json.load(f)
    if "ground_color" in design:
        COL["ground"] = tuple(design["ground_color"])
    w, h = int(cfg["map_cols"]) * 48, int(cfg["map_rows"]) * 48
    # Art layout may reshape the paths; gameplay coordinates (exits, monsters, entities) stay as in cfg.
    if "routes" in design:
        cfg = dict(cfg, flat_routes=design["routes"])

    # Annotated review guide at world resolution.
    img = Image.new("RGB", (w, h), COL["ground"])
    d = ImageDraw.Draw(img)
    draw_design(d, design, 1, 1)
    draw_routes(d, cfg["flat_routes"], COL["road"])
    for x in range(0, w, 48):
        d.line((x, 0, x, h), fill=(0, 0, 0), width=1) if x % 240 == 0 else None
    for y in range(0, h, 240):
        d.line((0, y, w, y), fill=(0, 0, 0), width=1)
        d.text((2, y + 2), str(y), fill=(0, 0, 0))
    for r in design.get("block", []):
        x, y, bw, bh = r
        d.rectangle((x, y, x + bw, y + bh), outline=(220, 30, 30), width=3)
    for mx, my in cfg.get("monster_positions", []):
        d.ellipse((mx - 40, my - 40, mx + 40, my + 40), outline=(200, 0, 0), width=2)
        d.text((mx - 12, my - 6), "MON", fill=(200, 0, 0))
    for b in cfg.get("optional_bosses", []):
        bx, by = b["at"]
        d.ellipse((bx - 56, by - 56, bx + 56, by + 56), outline=(160, 0, 160), width=3)
        d.text((bx - 14, by - 6), "BOSS", fill=(160, 0, 160))
    task_labels = []
    for index, e in enumerate(cfg.get("entities", {}).values(), 1):
        ex, ey = e["at"]
        d.rectangle((ex - 4, ey - 4, ex + 4, ey + 4), fill=(255, 220, 0), outline=(0, 0, 0))
        label = f"P{index:02d}"
        for dx, dy in [(10, -6), (-32, -6), (10, -24), (-32, -24),
                       (10, 16), (-32, 16), (36, -6), (-58, -6),
                       (10, -42), (-32, -42), (36, 32), (-58, 32)]:
            box = (ex + dx - 2, ey + dy - 2, ex + dx + 23, ey + dy + 12)
            if not any(box[0] < b[2] and box[2] > b[0] and
                       box[1] < b[3] and box[3] > b[1] for b in task_labels):
                break
        task_labels.append(box)
        d.line((ex, ey, ex + dx + 10, ey + dy + 5), fill=(85, 65, 0), width=1)
        d.rectangle(box, fill=(255, 242, 178))
        d.text((ex + dx, ey + dy), label, fill=(45, 35, 0))
    sx, sy = cfg["spawn"]
    d.ellipse((sx - 10, sy - 10, sx + 10, sy + 10), fill=(0, 160, 255))
    d.text((sx + 12, sy - 6), "SPAWN", fill=(0, 90, 200))
    for ex in cfg.get("exits", []):
        x, y = ex["at"]
        d.rectangle((x - 52, y - 44, x + 52, y + 44), outline=(0, 120, 255), width=3)
        d.text((x - 40, y - 6), "EXIT " + ex["id"], fill=(0, 60, 160))
    for label, (lx, ly) in design.get("labels", {}).items():
        d.text((lx, ly), label, fill=(20, 20, 20))
    img.save(os.path.join(out, f"{map_id}_guide_annotated.png"))

    # Clean GPT layout reference: colour blocks only. Uniform scale to the canvas width so
    # nothing is squashed; the map sits centred and the bands above/below are spare ground
    # that gets cropped away (crop box printed below).
    s = GPT_SIZE[0] / w
    pad = (GPT_SIZE[1] - h * s) / 2
    band = Image.new("RGB", (GPT_SIZE[0], round(h * s)), COL["ground"])
    bd = ImageDraw.Draw(band)
    draw_design(bd, design, s, s)
    draw_routes(bd, cfg["flat_routes"], COL["road"], s)
    # Spare bands are plain ground so they never suggest extra roads or walls.
    gpt = Image.new("RGB", GPT_SIZE, COL["ground"])
    gpt.paste(band, (0, round(pad)))
    gpt.save(os.path.join(out, f"{map_id}_guide_gpt.png"))
    print("guides written", w, h, "| gpt map area y", round(pad), "to", round(pad) + band.height,
          "| scale back", round(1 / s, 4))


if __name__ == "__main__":
    main()
