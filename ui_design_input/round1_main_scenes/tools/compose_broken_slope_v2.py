"""Offline composite of Broken Slope with the v2 sprites, for review before touching the game.

Usage:
    python -I compose_broken_slope_v2.py <sprites_v2_dir> <main_world_maps.json> <before_shots_dir> <role_sheet.png> <out_dir>

Lays the map out from the real config (flat_routes, spawn, exits, monsters, entities),
then renders the same camera views CaptureBrokenSlope.gd shoots in the game
(zoom 1.15, camera offset (0,-34), limits = map rect) and pairs each with the
in-game "before" shot.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

MAP_W, MAP_H = 960, 1248
DENSITY = 2
ZOOM = 1.15
CAM_OFFSET_Y = -34
PLAYER_SCALE = 0.54
SEED = 20261012

# Layout decisions for the v2 sample (world px).
ROUTE_FIXES = {(1, 1): [355, 962]}      # west loop vertex lifted off the gully band
GULLY_Y = 1010                          # water centre line
TERRACE_BASE = 575                      # ledge bottom; ramp centred where all routes meet
RAMP_X = 415
CLIFF_BASE = 175
STELE_AT = (800, 640)
VIEWS = [("spawn", 480, 1040), ("gully", 480, 990), ("camp", 560, 880),
         ("stele", 560, 760), ("terrace", 415, 600), ("north_gate", 480, 230)]


def value_noise(shape, cell, rng):
    gh, gw = shape[0] // cell + 2, shape[1] // cell + 2
    grid = Image.fromarray(rng.random((gh, gw)).astype(np.float32))
    return np.asarray(grid.resize((gw * cell, gh * cell), Image.BILINEAR))[: shape[0], : shape[1]] * 2 - 1


def route_ratio(routes, px, py):
    """Distance to the nearest route centre line, divided by that route's half width."""
    best = np.full(np.shape(px), np.inf, np.float32)
    for route in routes:
        half = float(route["width"]) / 2
        pts = route["points"]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            dx, dy = bx - ax, by - ay
            t = np.clip(((px - ax) * dx + (py - ay) * dy) / max(dx * dx + dy * dy, 1e-6), 0, 1)
            d = np.hypot(px - (ax + t * dx), py - (ay + t * dy)) / half
            best = np.minimum(best, d)
    return best


def tiled(tile, rng):
    """Tile a seamless texture over the map; random mirror flips keep seams continuous
    while breaking the wallpaper repeat."""
    t = np.asarray(tile.convert("RGB"))
    out = np.zeros((MAP_H, MAP_W, 3), np.uint8)
    for ty in range(0, MAP_H, t.shape[0]):
        for tx in range(0, MAP_W, t.shape[1]):
            v = t[:, ::-1] if rng.random() < 0.5 else t
            v = v[::-1] if rng.random() < 0.5 else v
            h, w = min(t.shape[0], MAP_H - ty), min(t.shape[1], MAP_W - tx)
            out[ty: ty + h, tx: tx + w] = v[:h, :w]
    return out


class Composer:
    def __init__(self, sprite_dir, cfg, role_sheet):
        self.dir = sprite_dir
        self.cfg = cfg
        self.rng = np.random.default_rng(SEED)
        self.routes = json.loads(json.dumps(cfg["flat_routes"]))
        for (ri, pi), point in ROUTE_FIXES.items():
            self.routes[ri]["points"][pi] = point
        self.avoid = [tuple(p) for p in cfg.get("monster_positions", [])]
        self.avoid += [tuple(b["at"]) for b in cfg.get("optional_bosses", [])]
        self.entities = [tuple(e["at"]) for e in cfg.get("entities", {}).values()]
        self.ground_items, self.sorted_items, self.fg_items, self.points = [], [], [], []
        self.role_sheet = role_sheet
        self.cache = {}

    def sprite(self, name):
        if name not in self.cache:
            self.cache[name] = Image.open(os.path.join(self.dir, "sprites", name + ".png")).convert("RGBA")
        return self.cache[name]

    def ratio_at(self, x, y):
        return float(route_ratio(self.routes, np.array([x], np.float32), np.array([y], np.float32))[0])

    def clear(self, x, y, road=1.25, mon=72, ent=56, spacing=0):
        if self.ratio_at(x, y) < road:
            return False
        if any(math.hypot(x - a, y - b) < mon for a, b in self.avoid):
            return False
        if any(math.hypot(x - a, y - b) < ent for a, b in self.entities):
            return False
        if abs(y - GULLY_Y) < 48 or abs(y - (TERRACE_BASE - 16)) < 30 or y < CLIFF_BASE + 20:
            return False
        if spacing and any(math.hypot(x - a, y - b) < spacing for a, b in self.points):
            return False
        return True

    # Placement: x = centre, y = bottom (sprite origin used in game).
    def put(self, layer, name, x, y):
        layer.append((name, int(round(x)), int(round(y))))

    def scatter(self, layer, names, count, zone, spacing, **clear_kw):
        x0, y0, x1, y1 = zone
        placed, tries = 0, 0
        while placed < count and tries < count * 60:
            tries += 1
            x, y = self.rng.uniform(x0, x1), self.rng.uniform(y0, y1)
            if not self.clear(x, y, spacing=spacing, **clear_kw):
                continue
            self.put(layer, names[int(self.rng.integers(len(names)))], x, y)
            self.points.append((x, y))
            placed += 1

    def ground(self):
        ah, aw = MAP_H // DENSITY, MAP_W // DENSITY
        ys, xs = np.mgrid[0:ah, 0:aw].astype(np.float32)
        px, py = (xs + 0.5) * DENSITY, (ys + 0.5) * DENSITY
        ratio = route_ratio(self.routes, px, py)
        low = value_noise((ah, aw), 12, self.rng)
        mid = value_noise((ah, aw), 3, self.rng)
        road = ratio < 1 + 0.16 * low + 0.07 * mid
        lip = road & ~ndi.binary_erosion(road, iterations=1)
        worn = ratio < 0.42 + 0.12 * low
        flag = road & ((py < 330 + 50 * low) | ((py < 420) & (mid > 0.35)))

        def up(mask):
            return np.repeat(np.repeat(mask, DENSITY, 0), DENSITY, 1)

        grass = tiled(Image.open(os.path.join(self.dir, "tiles", "ground_grass.png")), self.rng)
        dirt = tiled(Image.open(os.path.join(self.dir, "tiles", "ground_dirt.png")), self.rng)
        stone = tiled(Image.open(os.path.join(self.dir, "tiles", "ground_flagstone.png")), self.rng)
        img = np.where(up(road)[..., None], np.where(up(flag)[..., None], stone, dirt), grass).astype(np.float32)
        img[up(lip)] *= 0.72
        img[up(worn & ~flag)] *= 1.06
        self.road_mask = road
        return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")

    def layout(self):
        g, s = self.ground_items, self.sorted_items
        # Gully across the map, bridges where routes / bridge entities cross it.
        for i, x in enumerate(range(0, MAP_W, 320)):
            strip = self.sprite("gully_a" if i % 2 == 0 else "gully_b")
            self.put(g, "gully_a" if i % 2 == 0 else "gully_b", x + 160, GULLY_Y + strip.height // 2)
        stone = self.sprite("bridge_stone")
        self.put(g, "bridge_stone", 480, GULLY_Y + stone.height // 2)
        wood = self.sprite("bridge_wood_broken")
        for e in ("first_order_walk_bridge", "first_order_ride_bridge"):
            at = self.cfg["entities"][e]["at"]
            self.put(g, "bridge_wood_broken", at[0], GULLY_Y + wood.height // 2)

        # Terrace ledge with the ramp at the route junction.
        ramp = self.sprite("terrace_ramp")
        left_end, right_start = RAMP_X - ramp.width // 2, RAMP_X + ramp.width // 2
        for x in range(left_end - 320, -320, -320):
            self.put(s, "terrace_b", x + 160, TERRACE_BASE)
        self.put(s, "terrace_a", left_end - 160, TERRACE_BASE)
        self.put(s, "terrace_ramp", RAMP_X, TERRACE_BASE)
        for i, x in enumerate(range(right_start, MAP_W, 320)):
            self.put(s, "terrace_b" if i % 2 == 0 else "terrace_a", x + 160, TERRACE_BASE)

        # North cliff with the cavern gate at the north exit.
        self.put(s, "gate_cavern", 480, CLIFF_BASE)
        face = self.sprite("cliff_face_a")
        rim = self.sprite("cliff_rim_a")
        for x, f, r in ((160, "cliff_face_a", "cliff_rim_a"), (800, "cliff_face_b", "cliff_rim_b")):
            self.put(s, r, x, CLIFF_BASE - face.height + 6)
            self.put(s, f, x, CLIFF_BASE)

        # Landmark stele and the stele field on the upper slope.
        self.put(s, "stele_giant", *STELE_AT)
        for name, x, y in (("stele_fallen_a", 215, 270), ("stele_fallen_b", 700, 250),
                           ("stele_mid_a", 640, 470), ("stele_mid_b", 285, 640),
                           ("stele_fallen_c", 105, 600), ("stele_small_a", 600, 380),
                           ("stele_small_b", 360, 470), ("cairn", 560, 230)):
            if self.clear(x, y, road=1.15, mon=64):
                self.put(s, name, x, y)
                self.points.append((x, y))
            else:
                print("skip", name, x, y)

        # Camp around the trade stall at (475,930).
        for name, x, y in (("campfire_0", 405, 888), ("camp_crate_b", 560, 860),
                           ("camp_barrel_a", 584, 866), ("camp_tent", 700, 900),
                           ("camp_banner", 770, 905), ("camp_bench", 400, 920)):
            self.put(s, name, x, y)

        # Forest framing both edges, with gaps at monster clearings.
        for name, x, y in (("tree_big_a", 30, 300), ("tree_big_c", 80, 470), ("tree_big_b", 20, 760),
                           ("tree_big_d", 70, 945), ("tree_maple", 90, 1215),
                           ("tree_big_b", 935, 300), ("tree_big_c", 900, 530), ("tree_big_a", 945, 940),
                           ("tree_maple", 870, 1225), ("tree_big_d", 960, 700),
                           ("tree_mid_a", 250, 1190), ("tree_mid_b", 720, 1180),
                           ("tree_dead_a", 300, 330), ("tree_dead_b", 680, 600)):
            self.put(s, name, x, y)
            self.points.append((x, y))

        self.scatter(s, ["shrub_a", "shrub_b", "shrub_c", "shrub_rust"], 12, (20, 200, 940, 1240), 70)
        self.scatter(s, ["fern_a", "fern_b", "fern_c", "grass_tall_a", "grass_tall_b"], 10, (20, 200, 940, 1240), 60)
        self.scatter(s, ["rock_m_0", "rock_m_1", "rock_m_2", "rock_m_3", "rock_m_4"], 8, (20, 200, 940, 1240), 70)
        self.scatter(s, ["boulder_a", "boulder_c"], 2, (30, 620, 930, 900), 140, road=1.6)
        self.scatter(g, ["patch_moss_0", "patch_moss_1", "patch_gravel_0", "patch_gravel_2"], 6,
                     (40, 200, 920, 540), 150, road=1.05, mon=0, ent=0)
        self.scatter(g, ["patch_earth_0", "patch_earth_1", "patch_straw_0", "patch_straw_1", "patch_damp_0"], 7,
                     (40, 600, 920, 960), 150, road=1.05, mon=0, ent=0)
        self.scatter(g, ["patch_leaf_0", "patch_leaf_1", "patch_straw_2"], 4,
                     (40, 1060, 920, 1240), 150, road=1.05, mon=0, ent=0)
        self.scatter(g, [f"tuft_{i}" for i in range(6)], 46, (10, 190, 950, 1245), 24, road=1.02, mon=0, ent=24)
        self.scatter(g, [f"pebbles_{i}" for i in range(5)], 18, (10, 190, 950, 1245), 30, road=1.0, mon=0, ent=24)
        self.scatter(g, [f"flower_{i}" for i in range(4)], 8, (10, 190, 950, 1245), 60, road=1.4, mon=0, ent=24)
        self.scatter(g, ["leaves_0", "leaves_1", "leaves_2"], 5, (10, 1050, 950, 1245), 60, road=1.1, mon=0, ent=0)
        self.scatter(g, ["rock_s_0", "rock_s_1", "rock_s_2", "rock_s_3"], 10, (10, 190, 950, 1245), 40, road=1.05, mon=0, ent=24)

        # Foreground framing (drawn above everything, like the game's canopy layer).
        self.put(self.fg_items, "fg_canopy_tl", self.sprite("fg_canopy_tl").width // 2, self.sprite("fg_canopy_tl").height)
        tr = self.sprite("fg_canopy_tr")
        self.put(self.fg_items, "fg_canopy_tr", MAP_W - tr.width // 2, tr.height)
        for x in range(0, MAP_W + 160, 160):
            self.put(self.fg_items, "fg_grass_a" if (x // 160) % 2 == 0 else "fg_grass_b", x + 80, MAP_H)

    def blit(self, canvas, items):
        for name, x, y in items:
            img = self.sprite(name)
            canvas.alpha_composite(img, (x - img.width // 2, y - img.height)) if (
                0 <= x - img.width // 2 and x + img.width // 2 <= canvas.width and y - img.height >= 0 and y <= canvas.height
            ) else self._clipped(canvas, img, x - img.width // 2, y - img.height)

    @staticmethod
    def _clipped(canvas, img, left, top):
        layer = Image.new("RGBA", canvas.size)
        layer.paste(img, (left, top), img)
        canvas.alpha_composite(layer)

    def player(self):
        frame = Image.open(self.role_sheet).convert("RGBA").crop((0, 0, 128, 128))
        side = round(128 * PLAYER_SCALE)
        return frame.resize((side, side), Image.NEAREST), round(121 * PLAYER_SCALE)

    def render(self):
        canvas = self.ground()
        self.layout()
        self.blit(canvas, self.ground_items)
        player, feet = self.player()
        spawn = self.cfg["spawn"]
        marked = list(self.sorted_items)
        marked.sort(key=lambda it: it[2])
        self.blit(canvas, marked)
        self.blit(canvas, self.fg_items)
        return canvas, player, feet

    def view(self, canvas, player, feet, x, y):
        w, h = 480 / ZOOM, 800 / ZOOM
        cx = min(max(x, w / 2), MAP_W - w / 2)
        cy = min(max(y + CAM_OFFSET_Y, h / 2), MAP_H - h / 2)
        frame = canvas.copy()
        frame.alpha_composite(player, (int(x - player.width / 2), int(y - feet)))
        box = (int(round(cx - w / 2)), int(round(cy - h / 2)), int(round(cx + w / 2)), int(round(cy + h / 2)))
        return frame.crop(box).resize((480, 800), Image.NEAREST)


def label(img, text):
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 8 * len(text) + 12, 20), fill=(0, 0, 0))
    d.text((6, 4), text, fill=(255, 255, 255))
    return img


def main():
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    sprite_dir, cfg_path, before_dir, role_sheet, out = sys.argv[1:]
    os.makedirs(out, exist_ok=True)
    with open(cfg_path, encoding="utf-8") as f:
        cfg = json.load(f)["maps"]["broken_slope"]
    comp = Composer(sprite_dir, cfg, role_sheet)
    canvas, player, feet = comp.render()
    full = canvas.copy()
    full.alpha_composite(player, (int(cfg["spawn"][0] - player.width / 2), int(cfg["spawn"][1] - feet)))
    full.convert("RGB").save(os.path.join(out, "map_full_1x.png"))
    for name, x, y in VIEWS:
        after = comp.view(canvas, player, feet, x, y).convert("RGB")
        after.save(os.path.join(out, f"{name}_after.png"))
        pair = Image.new("RGB", (976, 800), (20, 20, 20))
        before_path = os.path.join(before_dir, f"{name}_hud.png")
        if os.path.exists(before_path):
            pair.paste(label(Image.open(before_path).convert("RGB"), "BEFORE (game)"), (0, 0))
        pair.paste(label(after, "AFTER v2 (offline)"), (496, 0))
        pair.save(os.path.join(out, f"{name}_compare.png"))
    overview = full.resize((round(MAP_W * 0.64), round(MAP_H * 0.64)), Image.NEAREST).convert("RGB")
    overview.save(os.path.join(out, "overview_after.png"))
    print("items ground", len(comp.ground_items), "sorted", len(comp.sorted_items), "fg", len(comp.fg_items))


if __name__ == "__main__":
    main()
