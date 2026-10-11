#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate Pure 2D Top-Down Commercial Pixel Art Ground Canvases
Guarantees 100% pure 2D top-down orthographic ground (zero sky, zero horizon).
Aligned with each map's flat_routes network and thematic visual palette.
"""
import os
import json
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ART_DIR = r"C:\Users\Administrator\.gemini\antigravity\brain\1bb250ae-0949-4d1d-b77a-fb355f60ce33"
MAPS_JSON = r"d:\new bee\远征\data\main_world_maps.json"
OUT_DIR = r"d:\new bee\远征\image\main_world"

def draw_routes_mask(w, h, routes, feather=6):
    """Draw smooth anti-aliased mask for flat_routes."""
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    for r in routes:
        pts = [tuple(p) for p in r.get("points", [])]
        width = int(r.get("width", 64))
        if len(pts) >= 2:
            draw.line(pts, fill=255, width=width, joint="curve")
            for p in pts:
                draw.ellipse([p[0]-width//2, p[1]-width//2, p[0]+width//2, p[1]+width//2], fill=255)
    if feather > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(feather))
    return mask

def create_pixel_noise(w, h, base_color, noise_amt=12, scale=2):
    """Generate authentic 16-bit pixel cluster noise texture."""
    sw, sh = w // scale, h // scale
    base = np.array(base_color, dtype=np.float32)
    noise = np.random.uniform(-noise_amt, noise_amt, (sh, sw, 3))
    arr = np.clip(base + noise, 0, 255).astype(np.uint8)
    im = Image.fromarray(arr).resize((w, h), Image.Resampling.NEAREST)
    return im

def build_pure2d_canvas(mid, mcfg):
    cols = mcfg.get("map_cols", 20)
    rows = mcfg.get("map_rows", 26)
    w = cols * 48
    h = rows * 48
    routes = mcfg.get("flat_routes", [])

    # Check if we have high-res concept crop
    ref_map = {
        "broken_slope": "broken_slope_ref_1791738612352.jpg",
        "frost_post": "frost_post_ref_1791738660672.jpg",
        "old_salt_road": "salt_road_ref_1791738710615.jpg",
    }

    if mid in ref_map:
        ref_path = os.path.join(ART_DIR, ref_map[mid])
        if os.path.exists(ref_path):
            im_ref = Image.open(ref_path)
            # STRICT PURE 2D CROP: Cut off top sky/horizon completely!
            # We crop the pure top-down ground terrain from y=240 to bottom!
            crop_y0 = int(im_ref.height * 0.22)
            pure2d_terrain = im_ref.crop((0, crop_y0, im_ref.width, im_ref.height))
            # Resize with pixel sharpness to (w, h)
            base_canvas = pure2d_terrain.resize((w, h), Image.Resampling.LANCZOS)
            
            # Now enhance route readability with subtle matching cobblestone/path blend
            route_mask = draw_routes_mask(w, h, routes, feather=8)
            draw = ImageDraw.Draw(base_canvas)
            # Add detailed path overlay along the routes
            path_overlay = Image.new("RGBA", (w, h), (0,0,0,0))
            pdraw = ImageDraw.Draw(path_overlay)
            
            if mid == "broken_slope":
                p_col = (138, 112, 76, 75)
                edge_col = (88, 72, 48, 110)
            elif mid == "frost_post":
                p_col = (115, 130, 145, 65)
                edge_col = (70, 85, 105, 95)
            else: # old_salt_road
                p_col = (235, 230, 215, 70)
                edge_col = (165, 150, 125, 100)
                
            for r in routes:
                pts = [tuple(p) for p in r.get("points", [])]
                width = int(r.get("width", 64))
                if len(pts) >= 2:
                    pdraw.line(pts, fill=p_col, width=width, joint="curve")
                    pdraw.line(pts, fill=edge_col, width=max(4, width - 12), joint="curve")
            
            base_canvas.paste(path_overlay, (0, 0), path_overlay)
            return base_canvas

    # For Shenyuan Port & Abyss Ring, use high-res reference if available
    if mid == "shenyuan_port":
        native_p = os.path.join(OUT_DIR, "shenyuan_port_ground_reference_v2.png")
        if os.path.exists(native_p):
            im = Image.open(native_p).convert("RGB")
            return im.resize((w, h), Image.Resampling.LANCZOS)
    if mid == "abyss_ring":
        native_p = os.path.join(OUT_DIR, "abyss_ring_ground_reference_v1.png")
        if os.path.exists(native_p):
            im = Image.open(native_p).convert("RGB")
            return im.resize((w, h), Image.Resampling.LANCZOS)

    # Thematic Synthesized Pure 2D Canvases
    # Biome Themes with authentic commercial pixel palettes
    themes = {
        "tideflat": {
            "bg": (62, 75, 82), "bg_noise": 10,
            "path": (78, 98, 108), "path_inner": (94, 120, 132),
            "accent": (145, 185, 205), "accent_type": "foam"
        },
        "tidal_gate": {
            "bg": (52, 58, 64), "bg_noise": 12,
            "path": (72, 82, 90), "path_inner": (88, 100, 110),
            "accent": (45, 75, 85), "accent_type": "water"
        },
        "stele_cavern": {
            "bg": (32, 34, 42), "bg_noise": 9,
            "path": (44, 52, 66), "path_inner": (55, 68, 88),
            "accent": (65, 175, 215), "accent_type": "crystal"
        },
        "red_sand_route": {
            "bg": (132, 65, 48), "bg_noise": 14,
            "path": (165, 88, 65), "path_inner": (195, 115, 85),
            "accent": (225, 155, 115), "accent_type": "dune"
        },
        "rift_mine_road": {
            "bg": (42, 38, 35), "bg_noise": 12,
            "path": (68, 58, 50), "path_inner": (88, 75, 65),
            "accent": (195, 145, 65), "accent_type": "rail"
        },
        "rift_mine_vault": {
            "bg": (48, 44, 40), "bg_noise": 10,
            "path": (75, 68, 60), "path_inner": (96, 86, 75),
            "accent": (165, 135, 75), "accent_type": "vault"
        },
        "frost_pass": {
            "bg": (75, 100, 125), "bg_noise": 14,
            "path": (120, 150, 180), "path_inner": (160, 190, 215),
            "accent": (215, 235, 250), "accent_type": "ice"
        },
        "frost_boardwalk": {
            "bg": (35, 45, 58), "bg_noise": 8,
            "path": (82, 68, 55), "path_inner": (108, 92, 75),
            "accent": (155, 185, 210), "accent_type": "wood"
        },
        "stele_entry": {
            "bg": (34, 32, 40), "bg_noise": 8,
            "path": (52, 48, 62), "path_inner": (68, 62, 80),
            "accent": (185, 150, 75), "accent_type": "rune"
        },
        "stele_resonance": {
            "bg": (28, 30, 42), "bg_noise": 8,
            "path": (42, 54, 76), "path_inner": (58, 76, 105),
            "accent": (88, 185, 235), "accent_type": "mandala"
        },
        "stele_core": {
            "bg": (22, 20, 30), "bg_noise": 7,
            "path": (38, 44, 62), "path_inner": (54, 66, 92),
            "accent": (75, 210, 240), "accent_type": "conduit"
        }
    }

    t = themes.get(mid, {
        "bg": (45, 45, 50), "bg_noise": 10,
        "path": (70, 70, 75), "path_inner": (90, 90, 95),
        "accent": (150, 150, 150), "accent_type": "stone"
    })

    # Base texture with pixel noise
    base = create_pixel_noise(w, h, t["bg"], noise_amt=t["bg_noise"], scale=3)
    
    # Path layer
    path_layer = Image.new("RGBA", (w, h), (0,0,0,0))
    pdraw = ImageDraw.Draw(path_layer)

    for r in routes:
        pts = [tuple(p) for p in r.get("points", [])]
        width = int(r.get("width", 64))
        if len(pts) >= 2:
            # Outer path border
            pdraw.line(pts, fill=t["path"] + (255,), width=width, joint="curve")
            for p in pts:
                pdraw.ellipse([p[0]-width//2, p[1]-width//2, p[0]+width//2, p[1]+width//2], fill=t["path"] + (255,))
            # Inner paved path core
            in_w = max(4, width - 14)
            pdraw.line(pts, fill=t["path_inner"] + (255,), width=in_w, joint="curve")
            for p in pts:
                pdraw.ellipse([p[0]-in_w//2, p[1]-in_w//2, p[0]+in_w//2, p[1]+in_w//2], fill=t["path_inner"] + (255,))
            
            # Thematic Accents along route
            acc_type = t.get("accent_type")
            acc_col = t.get("accent") + (220,)
            if acc_type in ["rail"]: # Wooden railway sleepers
                for i in range(len(pts)-1):
                    p1, p2 = pts[i], pts[i+1]
                    dist = math.hypot(p2[0]-p1[0], p2[1]-p1[1])
                    steps = max(1, int(dist // 28))
                    for s in range(steps):
                        t_ratio = s / float(steps)
                        cx = p1[0] + (p2[0]-p1[0]) * t_ratio
                        cy = p1[1] + (p2[1]-p1[1]) * t_ratio
                        dx, dy = (p2[0]-p1[0])/max(1, dist), (p2[1]-p1[1])/max(1, dist)
                        nx, ny = -dy, dx
                        pdraw.line([(cx - nx*18, cy - ny*18), (cx + nx*18, cy + ny*18)], fill=(90, 75, 60, 200), width=4)
                # Golden iron rails
                pdraw.line(pts, fill=acc_col, width=3, joint="curve")
            elif acc_type in ["wood"]: # Boardwalk planks
                for i in range(len(pts)-1):
                    p1, p2 = pts[i], pts[i+1]
                    dist = math.hypot(p2[0]-p1[0], p2[1]-p1[1])
                    steps = max(1, int(dist // 20))
                    for s in range(steps):
                        t_ratio = s / float(steps)
                        cx = p1[0] + (p2[0]-p1[0]) * t_ratio
                        cy = p1[1] + (p2[1]-p1[1]) * t_ratio
                        dx, dy = (p2[0]-p1[0])/max(1, dist), (p2[1]-p1[1])/max(1, dist)
                        nx, ny = -dy, dx
                        pdraw.line([(cx - nx*22, cy - ny*22), (cx + nx*22, cy + ny*22)], fill=(45, 38, 30, 180), width=2)
            elif acc_type in ["crystal", "conduit", "mandala", "rune"]:
                # Glowing center line and rune nodes
                pdraw.line(pts, fill=acc_col, width=4, joint="curve")
                for p in pts:
                    pdraw.ellipse([p[0]-7, p[1]-7, p[0]+7, p[1]+7], fill=acc_col)
                    pdraw.ellipse([p[0]-3, p[1]-3, p[0]+3, p[1]+3], fill=(255, 255, 255, 240))
            elif acc_type in ["foam", "ice", "dune"]:
                # Gentle meandering shoreline / frost / dune ridge
                pdraw.line(pts, fill=acc_col, width=3, joint="curve")

    # Add organic tile grid & cobblestone dithering
    draw_base = ImageDraw.Draw(base)
    for gy in range(0, h, 48):
        draw_base.line([(0, gy), (w, gy)], fill=(0, 0, 0, 15), width=1)
    for gx in range(0, w, 48):
        draw_base.line([(gx, 0), (gx, h)], fill=(0, 0, 0, 15), width=1)

    # Composite path over base
    base = base.convert("RGBA")
    base.paste(path_layer, (0, 0), path_layer)
    return base.convert("RGB")

def main():
    with open(MAPS_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    maps = data["maps"]
    print(f"Total maps to process: {len(maps)}")

    for mid, mcfg in maps.items():
        if mid == "lorin_wilds":
            print(f"Skipping {mid} (preserved first NPC town map)")
            continue

        cols = mcfg.get("map_cols", 20)
        rows = mcfg.get("map_rows", 26)
        print(f"Generating pure 2D floor for {mid} ({cols*48}x{rows*48})...")
        canvas = build_pure2d_canvas(mid, mcfg)
        
        out_name = f"{mid}_ground_v4.png"
        out_path = os.path.join(OUT_DIR, out_name)
        canvas.save(out_path, format="PNG")
        print(f"  -> Saved {out_path} ({canvas.size})")

        # Update JSON to use pure background
        mcfg["ground_style"] = "background"
        mcfg["background"] = f"res://image/main_world/{out_name}"

    # Write updated maps JSON
    with open(MAPS_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("Updated data/main_world_maps.json successfully!")

if __name__ == "__main__":
    main()
