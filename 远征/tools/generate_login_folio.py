#!/usr/bin/env python3
"""
tools/generate_login_folio.py
Generates the pixel art login panel background texture for '远征' (Expedition).
Canvas size: 408 x 512 pixels.
Theme: Aged parchment/vellum document mounted on a dark iron frame.
"""

import os
import numpy as np
from PIL import Image

def hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
    hex_str = hex_str.lstrip('#')
    return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))

def generate_smooth_noise(width: int, height: int, scale: float, seed: int = 42) -> np.ndarray:
    """Generate smoothly interpolated 2D noise with smoothstep interpolation."""
    np.random.seed(seed)
    gw = int(np.ceil(width / scale)) + 3
    gh = int(np.ceil(height / scale)) + 3
    grid = np.random.rand(gh, gw)
    
    y = np.linspace(0, gh - 3, height)
    x = np.linspace(0, gw - 3, width)
    
    x0 = np.floor(x).astype(int)
    x1 = x0 + 1
    y0 = np.floor(y).astype(int)
    y1 = y0 + 1
    
    sx = x - x0
    sy = y - y0
    # Smoothstep interpolation: 3*s^2 - 2*s^3
    sx = sx * sx * (3.0 - 2.0 * sx)
    sy = sy * sy * (3.0 - 2.0 * sy)
    
    sx = sx[np.newaxis, :]
    sy = sy[:, np.newaxis]
    x0 = x0[np.newaxis, :]
    x1 = x1[np.newaxis, :]
    y0 = y0[:, np.newaxis]
    y1 = y1[:, np.newaxis]
    
    top = grid[y0, x0] * (1.0 - sx) + grid[y0, x1] * sx
    bot = grid[y1, x0] * (1.0 - sx) + grid[y1, x1] * sx
    return top * (1.0 - sy) + bot * sy

def build_login_folio() -> Image.Image:
    W, H = 408, 512
    arr = np.zeros((H, W, 4), dtype=np.uint8)
    arr[:, :, 3] = 255  # Fully opaque canvas

    # =========================================================================
    # Palette definition (strictly conforming to design requirements)
    # =========================================================================
    # Outer iron/steel frame
    C_FRAME_OUTER  = hex_to_rgb("#1a1e28")  # (26, 30, 40)
    C_FRAME_INNER  = hex_to_rgb("#2a3040")  # (42, 48, 64)
    C_FRAME_BEVEL  = hex_to_rgb("#4a5060")  # (74, 80, 96) top-left 1px highlight
    C_FRAME_SHADOW = hex_to_rgb("#11141c")  # (17, 20, 28) bottom-right shadow
    C_FRAME_SEAM   = hex_to_rgb("#161922")  # (22, 25, 34) inner recessed groove

    # 2px gold corner brackets
    C_GOLD_BASE    = hex_to_rgb("#c8a04a")  # (200, 160, 74)
    C_GOLD_HILIGHT = hex_to_rgb("#dfbe68")  # (223, 190, 104) metallic bevel highlight
    C_GOLD_SHADOW  = hex_to_rgb("#9a762e")  # (154, 118, 46) metallic bevel shadow

    # Title header & bottom footer strips
    C_BANNER_BG    = hex_to_rgb("#1e2830")  # (30, 40, 48)
    C_BANNER_GOLD  = hex_to_rgb("#8a7040")  # (138, 112, 64) 1px gold border
    C_BANNER_BEVEL = hex_to_rgb("#2d3944")  # 1px top inner bevel
    C_BANNER_SHD   = hex_to_rgb("#151d24")  # 1px bottom inner bevel

    # Aged parchment area
    C_PARCH_DARK   = hex_to_rgb("#d8c8a0")  # (216, 200, 160) base range lower
    C_PARCH_LIGHT  = hex_to_rgb("#e0d4b4")  # (224, 212, 180) base range upper
    C_PARCH_SPOT   = hex_to_rgb("#c4b48c")  # (196, 180, 140) subtle darker aging spots
    C_PARCH_SPOT_DK= hex_to_rgb("#bcab82")  # (188, 171, 130) deeper aging center

    # Red seal stamp
    C_SEAL_RED     = hex_to_rgb("#8b3020")  # (139, 48, 32) deep red fill
    C_SEAL_BORDER  = hex_to_rgb("#6a2010")  # (106, 32, 16) 1px border
    C_SEAL_EMBLEM  = hex_to_rgb("#bd442e")  # (189, 68, 46) carved insignia highlight

    # =========================================================================
    # 1. Outer 6px dark iron/steel frame
    # =========================================================================
    yy, xx = np.mgrid[0:H, 0:W]
    d_top = yy
    d_bot = H - 1 - yy
    d_lft = xx
    d_rgt = W - 1 - xx
    dist_edge = np.minimum(np.minimum(d_top, d_bot), np.minimum(d_lft, d_rgt))
    in_frame = dist_edge < 6

    # Micro-dither pattern for realistic hammered dark iron
    iron_dither = (((xx % 2) ^ (yy % 2)) * 2 - 1).astype(int)

    # Frame fill
    frame_r = np.full((H, W), C_FRAME_INNER[0], dtype=int) + iron_dither
    frame_g = np.full((H, W), C_FRAME_INNER[1], dtype=int) + iron_dither
    frame_b = np.full((H, W), C_FRAME_INNER[2], dtype=int) + iron_dither

    # Layer 1: transition outer edge (#1a1e28)
    layer1_mask = (dist_edge == 1)
    frame_r[layer1_mask] = np.where((d_top <= 1) | (d_lft <= 1), 38, 20)[layer1_mask]
    frame_g[layer1_mask] = np.where((d_top <= 1) | (d_lft <= 1), 44, 24)[layer1_mask]
    frame_b[layer1_mask] = np.where((d_top <= 1) | (d_lft <= 1), 58, 32)[layer1_mask]

    # Layer 5: inner recessed seam groove (#161922)
    layer5_mask = (dist_edge == 5)
    frame_r[layer5_mask] = C_FRAME_SEAM[0]
    frame_g[layer5_mask] = C_FRAME_SEAM[1]
    frame_b[layer5_mask] = C_FRAME_SEAM[2]

    # Layer 0: outer bevel (1px #4a5060 highlight on top/left, #11141c shadow on bottom/right)
    layer0_mask = (dist_edge == 0)
    top_lft_bevel = layer0_mask & ((d_top == 0) | (d_lft == 0))
    bot_rgt_bevel = layer0_mask & ~((d_top == 0) | (d_lft == 0))

    frame_r[top_lft_bevel] = C_FRAME_BEVEL[0]
    frame_g[top_lft_bevel] = C_FRAME_BEVEL[1]
    frame_b[top_lft_bevel] = C_FRAME_BEVEL[2]

    frame_r[bot_rgt_bevel] = C_FRAME_SHADOW[0]
    frame_g[bot_rgt_bevel] = C_FRAME_SHADOW[1]
    frame_b[bot_rgt_bevel] = C_FRAME_SHADOW[2]

    arr[in_frame, 0] = np.clip(frame_r[in_frame], 0, 255)
    arr[in_frame, 1] = np.clip(frame_g[in_frame], 0, 255)
    arr[in_frame, 2] = np.clip(frame_b[in_frame], 0, 255)

    # =========================================================================
    # 2. Title header area (top ~70px inside frame: y 6..75, height 70px)
    # =========================================================================
    hy_start, hy_end = 6, 75
    header_x0, header_x1 = 6, W - 6  # 6..401

    # Header base fill #1e2830 with subtle dark slate micro-texture
    for y in range(hy_start, hy_end + 1):
        for x in range(header_x0, header_x1):
            if y == hy_start or y == hy_end:
                # 1px gold border top and bottom (#8a7040)
                arr[y, x, :3] = C_BANNER_GOLD
            elif y == hy_start + 1:
                # Top inner metallic highlight
                arr[y, x, :3] = C_BANNER_BEVEL
            elif y == hy_end - 1:
                # Bottom inner shadow
                arr[y, x, :3] = C_BANNER_SHD
            else:
                d = ((x + y * 2) % 3) - 1
                arr[y, x, :3] = (C_BANNER_BG[0] + d, C_BANNER_BG[1] + d, C_BANNER_BG[2] + d)

    # =========================================================================
    # 3. Bottom footer strip (~40px inside frame: y 466..505, height 40px)
    # =========================================================================
    fy_start, fy_end = 466, 505
    for y in range(fy_start, fy_end + 1):
        for x in range(header_x0, header_x1):
            if y == fy_start:
                # 1px gold line at top (#8a7040)
                arr[y, x, :3] = C_BANNER_GOLD
            elif y == fy_start + 1:
                # Top inner highlight
                arr[y, x, :3] = C_BANNER_BEVEL
            elif y == fy_end:
                # Bottom inner shadow
                arr[y, x, :3] = C_BANNER_SHD
            else:
                d = ((x * 2 + y) % 3) - 1
                arr[y, x, :3] = (C_BANNER_BG[0] + d, C_BANNER_BG[1] + d, C_BANNER_BG[2] + d)

    # =========================================================================
    # 4. Aged parchment area (y 76..465, height 390px, width 396px)
    # =========================================================================
    pw = header_x1 - header_x0  # 396
    ph = fy_start - (hy_end + 1)  # 390
    py_start = hy_end + 1  # 76

    # Generate organic multi-octave paper texture
    n_macro = generate_smooth_noise(pw, ph, scale=64.0, seed=101)
    n_med   = generate_smooth_noise(pw, ph, scale=22.0, seed=202)
    n_micro = generate_smooth_noise(pw, ph, scale=7.0, seed=303)

    combined = n_macro * 0.55 + n_med * 0.30 + n_micro * 0.15
    c_min, c_max = combined.min(), combined.max()
    norm_noise = (combined - c_min) / (c_max - c_min + 1e-6)

    # Subtle edge warmth vignette
    pyy, pxx = np.mgrid[0:ph, 0:pw]
    dist_px = np.minimum(pxx, pw - 1 - pxx)
    dist_py = np.minimum(pyy, ph - 1 - pyy)
    dist_p_edge = np.minimum(dist_px, dist_py)
    vignette = np.clip(dist_p_edge / 26.0, 0.0, 1.0)

    # 2x2 Bayer dithering matrix for intentional pixel art look
    bayer_2x2 = np.array([
        [0.0, 0.5],
        [0.75, 0.25]
    ], dtype=float)
    dither_tile = np.tile(bayer_2x2, (ph // 2 + 1, pw // 2 + 1))[:ph, :pw]
    dither_offset = (dither_tile - 0.5) * 2.4

    # Tone interpolation between #d8c8a0 and #e0d4b4
    t = norm_noise * 0.72 + (vignette * 0.28)
    parch_r = C_PARCH_DARK[0] + (C_PARCH_LIGHT[0] - C_PARCH_DARK[0]) * t + dither_offset
    parch_g = C_PARCH_DARK[1] + (C_PARCH_LIGHT[1] - C_PARCH_DARK[1]) * t + dither_offset
    parch_b = C_PARCH_DARK[2] + (C_PARCH_LIGHT[2] - C_PARCH_DARK[2]) * t + dither_offset

    # Subtle shading along outer iron frame border
    rim_mask = dist_p_edge < 8
    rim_factor = 0.94 + 0.06 * (dist_p_edge / 8.0)
    parch_r[rim_mask] *= rim_factor[rim_mask]
    parch_g[rim_mask] *= rim_factor[rim_mask]
    parch_b[rim_mask] *= rim_factor[rim_mask]

    # 2px subtle shadow below header strip (rows 0 and 1: y=76, 77)
    parch_r[0, :] *= 0.75
    parch_g[0, :] *= 0.75
    parch_b[0, :] *= 0.75
    parch_r[1, :] *= 0.88
    parch_g[1, :] *= 0.88
    parch_b[1, :] *= 0.88

    # 2px subtle shadow above footer strip (rows ph-2 and ph-1: y=464, 465)
    parch_r[-2, :] *= 0.88
    parch_g[-2, :] *= 0.88
    parch_b[-2, :] *= 0.88
    parch_r[-1, :] *= 0.75
    parch_g[-1, :] *= 0.75
    parch_b[-1, :] *= 0.75

    arr[py_start:py_start + ph, header_x0:header_x1, 0] = np.clip(parch_r, 0, 255)
    arr[py_start:py_start + ph, header_x0:header_x1, 1] = np.clip(parch_g, 0, 255)
    arr[py_start:py_start + ph, header_x0:header_x1, 2] = np.clip(parch_b, 0, 255)

    # Scattered aging spots (#c4b48c)
    np.random.seed(777)
    num_spots = 80
    spot_xs = np.random.randint(10, pw - 10, size=num_spots)
    spot_ys = np.random.randint(8, ph - 8, size=num_spots)
    for sx, sy in zip(spot_xs, spot_ys):
        py = py_start + sy
        px = header_x0 + sx
        kind = np.random.rand()
        if kind < 0.60:
            arr[py, px, :3] = C_PARCH_SPOT
        elif kind < 0.85:
            arr[py, px, :3] = C_PARCH_SPOT
            if np.random.rand() > 0.5:
                arr[py, px + 1, :3] = C_PARCH_SPOT
            else:
                arr[py + 1, px, :3] = C_PARCH_SPOT
        else:
            arr[py, px, :3] = C_PARCH_SPOT_DK
            arr[py, px + 1, :3] = C_PARCH_SPOT
            arr[py + 1, px, :3] = C_PARCH_SPOT
            arr[py + 1, px + 1, :3] = C_PARCH_SPOT

    # =========================================================================
    # 5. Red official seal/stamp mark (18x18px at bottom-right of parchment)
    # =========================================================================
    seal_w, seal_h = 18, 18
    seal_x0 = 373
    seal_y0 = 436

    for dy in range(seal_h):
        for dx in range(seal_w):
            # Chamfer the 4 outer corner pixels (1px cut)
            if (dx == 0 and dy == 0) or (dx == seal_w - 1 and dy == 0) or \
               (dx == 0 and dy == seal_h - 1) or (dx == seal_w - 1 and dy == seal_h - 1):
                continue
            
            px = seal_x0 + dx
            py = seal_y0 + dy
            
            # 1px border (#6a2010)
            is_border = (dx == 0 or dx == seal_w - 1 or dy == 0 or dy == seal_h - 1) or \
                        ((dx == 1 or dx == seal_w - 2) and (dy == 0 or dy == seal_h - 1)) or \
                        ((dy == 1 or dy == seal_h - 2) and (dx == 0 or dx == seal_w - 1))
            
            if is_border:
                arr[py, px, :3] = C_SEAL_BORDER
            else:
                arr[py, px, :3] = C_SEAL_RED

    # Stylized carved emblem inside seal ("远征" expedition seal insignia)
    seal_inner_art = [
        "..............",
        ".############.",
        ".#..........#.",
        ".#....##....#.",
        ".#...####...#.",
        ".#....##....#.",
        ".#..######..#.",
        ".#.########.#.",
        ".#..##..##..#.",
        ".#..##..##..#.",
        ".#..........#.",
        ".############.",
        "..............",
        "..............",
    ]
    for sy, row_str in enumerate(seal_inner_art):
        for sx, ch in enumerate(row_str):
            if ch == '#':
                px = seal_x0 + 2 + sx
                py = seal_y0 + 2 + sy
                if px < seal_x0 + seal_w - 1 and py < seal_y0 + seal_h - 1:
                    arr[py, px, :3] = C_SEAL_EMBLEM

    # =========================================================================
    # 6. Corner brackets (2px gold #c8a04a L-shaped brackets, each arm 12px long)
    # =========================================================================
    arm_len = 12
    arm_thick = 2
    corners = [
        (0, 0, 1, 1),            # Top-Left
        (W - 1, 0, -1, 1),        # Top-Right
        (0, H - 1, 1, -1),        # Bottom-Left
        (W - 1, H - 1, -1, -1)    # Bottom-Right
    ]

    for cx, cy, dx, dy in corners:
        # Horizontal arm: arm_len long, arm_thick thick
        for step_x in range(arm_len):
            for step_y in range(arm_thick):
                x = cx + step_x * dx
                y = cy + step_y * dy
                if 0 <= x < W and 0 <= y < H:
                    if step_y == 0 and dy == 1:
                        arr[y, x, :3] = C_GOLD_HILIGHT
                    elif step_y == arm_thick - 1 and dy == -1:
                        arr[y, x, :3] = C_GOLD_SHADOW
                    else:
                        arr[y, x, :3] = C_GOLD_BASE

        # Vertical arm: arm_thick wide, arm_len long
        for step_y in range(arm_len):
            for step_x in range(arm_thick):
                x = cx + step_x * dx
                y = cy + step_y * dy
                if 0 <= x < W and 0 <= y < H:
                    if step_x == 0 and dx == 1:
                        arr[y, x, :3] = C_GOLD_HILIGHT
                    elif step_x == arm_thick - 1 and dx == -1:
                        arr[y, x, :3] = C_GOLD_SHADOW
                    else:
                        arr[y, x, :3] = C_GOLD_BASE

    return Image.fromarray(arr, "RGBA")

def main():
    target_path = r"D:\new bee\远征\image\ui\pixel_20261008\login_folio_pixel.png"
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    img = build_login_folio()
    img.save(target_path)
    print(f"Successfully generated and overwritten: {target_path}")
    print(f"Size: {img.size}, Mode: {img.mode}")

if __name__ == "__main__":
    main()
