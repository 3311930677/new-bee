"""
tools/build_pixel_art_system.py
Generates authentic, high-craftsmanship pure pixel art UI assets for 远征.
Adheres strictly to the game's 480x800 pixel grid and palette harmony.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = "D:/new bee/远征/image/ui/pixel_20261008"
ICON_DIR = "D:/new bee/远征/assets/ui/pixel_polish"
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(ICON_DIR, exist_ok=True)

# ----------------- PALETTE DEFINITIONS -----------------
C_TRANS = (0, 0, 0, 0)
C_SHADOW_DEEP = (10, 14, 18, 255)
C_SHADOW_MID  = (18, 24, 30, 255)
C_IRON_DARK   = (24, 34, 42, 255)
C_IRON_MID    = (38, 52, 64, 255)
C_IRON_LIGHT  = (56, 74, 90, 255)
C_STEEL_EDGE  = (84, 108, 128, 255)

C_GOLD_SHADOW = (78, 48, 16, 255)
C_GOLD_DEEP   = (130, 84, 26, 255)
C_GOLD_BASE   = (194, 142, 48, 255)
C_GOLD_LIGHT  = (238, 192, 88, 255)
C_GOLD_BRIGHT = (255, 232, 148, 255)
C_GOLD_WHITE  = (255, 250, 218, 255)

C_BRONZE_DARK = (58, 38, 20, 255)
C_BRONZE_BASE = (120, 82, 44, 255)
C_BRONZE_LGT  = (176, 128, 76, 255)

C_JADE_DEEP   = (18, 44, 38, 255)
C_JADE_BASE   = (38, 86, 72, 255)
C_JADE_LIGHT  = (68, 144, 122, 255)
C_JADE_MINT   = (142, 214, 186, 255)

C_VELLUM_DARK = (142, 120, 86, 255)
C_VELLUM_BASE = (212, 194, 156, 255)
C_VELLUM_LGT  = (242, 230, 202, 255)
C_VELLUM_WHT  = (252, 246, 228, 255)

C_CYAN_DEEP   = (18, 64, 88, 255)
C_CYAN_BASE   = (38, 128, 168, 255)
C_CYAN_LIGHT  = (86, 204, 240, 255)
C_CYAN_WHITE  = (214, 248, 255, 255)

C_PURPLE_DEEP = (44, 18, 72, 255)
C_PURPLE_BASE = (108, 44, 168, 255)
C_PURPLE_LGT  = (178, 92, 248, 255)
C_PURPLE_WHT  = (238, 198, 255, 255)

C_RED_DEEP    = (72, 18, 18, 255)
C_RED_BASE    = (168, 36, 36, 255)
C_RED_LIGHT   = (234, 68, 68, 255)
C_RED_WHITE   = (255, 186, 186, 255)


def draw_pixel_box(draw, x0, y0, w, h, bg_color, border_outer, border_inner_hi, border_inner_sh):
    """Draws a chiseled 9-slice pixel bevel box."""
    # Background fill
    draw.rectangle([x0, y0, x0 + w - 1, y0 + h - 1], fill=bg_color)
    # Outer 1px border
    draw.rectangle([x0, y0, x0 + w - 1, y0 + h - 1], outline=border_outer)
    # Top and Left inner highlight
    draw.line([x0 + 1, y0 + 1, x0 + w - 2, y0 + 1], fill=border_inner_hi)
    draw.line([x0 + 1, y0 + 1, x0 + 1, y0 + h - 2], fill=border_inner_hi)
    # Bottom and Right inner shadow
    draw.line([x0 + 1, y0 + h - 2, x0 + w - 2, y0 + h - 2], fill=border_inner_sh)
    draw.line([x0 + w - 2, y0 + 1, x0 + w - 2, y0 + h - 2], fill=border_inner_sh)


def draw_rivet(draw, cx, cy, c_light=C_GOLD_BRIGHT, c_base=C_GOLD_BASE, c_dark=C_GOLD_SHADOW):
    """Draws a 3x3 pixel metallic rivet."""
    draw.point((cx, cy), fill=c_light)
    draw.point((cx - 1, cy), fill=c_base)
    draw.point((cx, cy - 1), fill=c_base)
    draw.point((cx + 1, cy), fill=c_dark)
    draw.point((cx, cy + 1), fill=c_dark)


def draw_brass_corner(draw, x0, y0, x1, y1, size=8):
    """Draws decorative pixel brass corner brackets."""
    # Top-left
    draw.line([x0, y0, x0 + size, y0], fill=C_GOLD_BRIGHT)
    draw.line([x0, y0, x0, y0 + size], fill=C_GOLD_BRIGHT)
    draw.line([x0 + 1, y0 + 1, x0 + size - 1, y0 + 1], fill=C_GOLD_BASE)
    draw.line([x0 + 1, y0 + 1, x0 + 1, y0 + size - 1], fill=C_GOLD_BASE)
    draw.point((x0 + 2, y0 + 2), fill=C_GOLD_WHITE)

    # Top-right
    draw.line([x1 - size, y0, x1, y0], fill=C_GOLD_BRIGHT)
    draw.line([x1, y0, x1, y0 + size], fill=C_GOLD_SHADOW)
    draw.line([x1 - size + 1, y0 + 1, x1 - 1, y0 + 1], fill=C_GOLD_BASE)
    draw.line([x1 - 1, y0 + 1, x1 - 1, y0 + size - 1], fill=C_GOLD_DEEP)
    draw.point((x1 - 2, y0 + 2), fill=C_GOLD_WHITE)

    # Bottom-left
    draw.line([x0, y1 - size, x0, y1], fill=C_GOLD_BASE)
    draw.line([x0, y1, x0 + size, y1], fill=C_GOLD_SHADOW)
    draw.line([x0 + 1, y1 - size + 1, x0 + 1, y1 - 1], fill=C_GOLD_DEEP)
    draw.line([x0 + 1, y1 - 1, x0 + size - 1, y1 - 1], fill=C_GOLD_SHADOW)
    draw.point((x0 + 2, y1 - 2), fill=C_GOLD_LIGHT)

    # Bottom-right
    draw.line([x1 - size, y1, x1, y1], fill=C_GOLD_SHADOW)
    draw.line([x1, y1 - size, x1, y1], fill=C_GOLD_SHADOW)
    draw.line([x1 - size + 1, y1 - 1, x1 - 1, y1 - 1], fill=C_GOLD_DEEP)
    draw.line([x1 - 1, y1 - size + 1, x1 - 1, y1 - 1], fill=C_GOLD_DEEP)
    draw.point((x1 - 2, y1 - 2), fill=C_GOLD_DEEP)


# =========================================================================
# 1. PIXEL LOADING GAUGE (iron & brass relic chassis + glowing crystal fill)
# =========================================================================
def build_loading_gauge():
    w, h = 416, 66
    im = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(im)

    # 1. Outer drop shadow
    draw.rectangle([2, 4, w - 3, h - 1], fill=(4, 8, 12, 140))
    draw.rectangle([4, 6, w - 5, h - 1], fill=(2, 4, 6, 80))

    # 2. Main chassis body (slate-iron with chamfered corners)
    # Chamfered octagon path
    c = 6
    chassis_pts = [
        (c, 2), (w - 1 - c, 2),
        (w - 1, 2 + c), (w - 1, h - 3 - c),
        (w - 1 - c, h - 3), (c, h - 3),
        (0, h - 3 - c), (0, 2 + c)
    ]
    draw.polygon(chassis_pts, fill=C_IRON_DARK)

    # Inner subtle dither/metallic grain
    for y in range(4, h - 5, 2):
        draw.line([c + 2, y, w - c - 3, y], fill=(C_IRON_MID[0], C_IRON_MID[1], C_IRON_MID[2], 90))

    # Outer border outline
    draw.polygon(chassis_pts, outline=C_SHADOW_DEEP)

    # Inner bevel highlight (top-left) and shadow (bottom-right)
    draw.line([c, 3, w - 1 - c, 3], fill=C_STEEL_EDGE)
    draw.line([1, 2 + c, 1, h - 3 - c], fill=C_IRON_LIGHT)
    draw.line([c, h - 4, w - 1 - c, h - 4], fill=C_SHADOW_DEEP)
    draw.line([w - 2, 2 + c, w - 2, h - 3 - c], fill=C_SHADOW_DEEP)

    # Corner brass braces
    draw_brass_corner(draw, 3, 4, w - 4, h - 6, size=14)

    # Decorative Rivets along top and bottom
    for rx in range(48, w - 48, 40):
        draw_rivet(draw, rx, 8, C_GOLD_BRIGHT, C_GOLD_BASE, C_GOLD_SHADOW)
        draw_rivet(draw, rx, h - 10, C_GOLD_LIGHT, C_GOLD_DEEP, C_GOLD_SHADOW)

    # 3. Status Plate / Header Area (Center top)
    header_w, header_h = 240, 20
    hx = (w - header_w) // 2
    hy = 10
    draw.rectangle([hx, hy, hx + header_w - 1, hy + header_h - 1], fill=C_SHADOW_DEEP)
    draw.rectangle([hx, hy, hx + header_w - 1, hy + header_h - 1], outline=C_GOLD_DEEP)
    draw.line([hx + 1, hy + 1, hx + header_w - 2, hy + 1], fill=C_GOLD_LIGHT)

    # 4. Inset Channel for the crystal blade (Recessed groove)
    gx, gy, gw, gh = 46, 38, 300, 14
    # Groove shadow
    draw.rectangle([gx - 1, gy - 1, gx + gw, gy + gh], fill=C_SHADOW_DEEP)
    draw.rectangle([gx, gy, gx + gw - 1, gy + gh - 1], fill=(12, 16, 20, 255))
    # Groove inner bevel (dark on top, lit on bottom)
    draw.line([gx, gy, gx + gw - 1, gy], fill=(6, 8, 10, 255))
    draw.line([gx, gy, gx, gy + gh - 1], fill=(6, 8, 10, 255))
    draw.line([gx, gy + gh - 1, gx + gw - 1, gy + gh - 1], fill=(42, 54, 66, 255))
    # Runic scale marks along the channel
    for tx in range(gx + 25, gx + gw - 10, 25):
        draw.line([tx, gy + 1, tx, gy + 4], fill=C_GOLD_SHADOW)
        draw.line([tx, gy + gh - 4, tx, gy + gh - 2], fill=C_GOLD_SHADOW)

    # 5. Right socket for percentage badge
    px, py, pw, ph = 356, 34, 48, 22
    draw.rectangle([px, py, px + pw - 1, py + ph - 1], fill=C_SHADOW_DEEP)
    draw.rectangle([px, py, px + pw - 1, py + ph - 1], outline=C_GOLD_BASE)
    draw.line([px + 1, py + 1, px + pw - 2, py + 1], fill=C_GOLD_BRIGHT)
    draw.line([px + 1, py + ph - 2, px + pw - 2, py + ph - 2], fill=C_GOLD_SHADOW)

    # Left ornament (sword pommel / compass eye)
    cx, cy = 25, 45
    draw.rectangle([cx - 9, cy - 9, cx + 9, cy + 9], fill=C_GOLD_BASE, outline=C_GOLD_SHADOW)
    draw.rectangle([cx - 7, cy - 7, cx + 7, cy + 7], fill=C_GOLD_DEEP)
    draw.line([cx - 8, cy - 8, cx + 8, cy - 8], fill=C_GOLD_BRIGHT)
    draw.line([cx - 8, cy - 8, cx - 8, cy + 8], fill=C_GOLD_BRIGHT)
    # Center jewel
    draw.rectangle([cx - 4, cy - 4, cx + 4, cy + 4], fill=C_CYAN_DEEP)
    draw.point((cx - 1, cy - 1), fill=C_CYAN_WHITE)
    draw.point((cx, cy - 1), fill=C_CYAN_LIGHT)
    draw.point((cx - 1, cy), fill=C_CYAN_LIGHT)
    draw.point((cx, cy), fill=C_CYAN_BASE)

    im.save(os.path.join(OUT_DIR, "loading_gauge_pixel.png"))
    print("Saved loading_gauge_pixel.png")


def build_loading_fill():
    """Generates the multi-toned glowing crystal blade progress fill (300 x 14)."""
    w, h = 300, 14
    im = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(im)

    # Core crystal body
    draw.rectangle([0, 0, w - 1, h - 1], fill=C_CYAN_BASE)

    # Multi-tier dithering & specular glow
    # Top highlight line
    draw.line([0, 0, w - 1, 0], fill=C_CYAN_WHITE)
    draw.line([0, 1, w - 1, 1], fill=C_CYAN_LIGHT)
    # Mid-body energy bands
    for x in range(0, w, 4):
        draw.point((x, 3), fill=C_CYAN_WHITE)
        draw.point((x + 1, 3), fill=C_CYAN_LIGHT)
        draw.point((x + 2, 4), fill=C_CYAN_WHITE)
    # Bottom deep shade
    draw.line([0, h - 2, w - 1, h - 2], fill=C_CYAN_DEEP)
    draw.line([0, h - 1, w - 1, h - 1], fill=(8, 32, 48, 255))

    # Right tip (pointed crystal spearhead)
    # We will let the runner clip it or draw the runner diamond
    im.save(os.path.join(OUT_DIR, "loading_fill_pixel.png"))
    print("Saved loading_fill_pixel.png")


# =========================================================================
# 2. MASTERWORK PIXEL EXPEDITION BANNER ("继续旅程" 416 x 88)
# =========================================================================
def build_expedition_banner():
    w, h = 416, 88
    # We create an atlas with 3 states vertically: Normal (y=0..87), Hover (y=88..175), Pressed (y=176..263)
    atlas = Image.new("RGBA", (w, h * 3), C_TRANS)

    for state_idx, state in enumerate(["normal", "hover", "pressed"]):
        y_offset = state_idx * h
        im = Image.new("RGBA", (w, h), C_TRANS)
        draw = ImageDraw.Draw(im)

        dy = 2 if state == "pressed" else 0
        is_hover = (state == "hover")

        # 1. Drop shadow
        if state != "pressed":
            draw.rectangle([4, 6, w - 5, h - 1], fill=(2, 6, 10, 140))
            draw.rectangle([6, 8, w - 7, h - 1], fill=(0, 2, 4, 80))
        else:
            draw.rectangle([4, 6, w - 5, h - 1], fill=(2, 6, 10, 70))

        # 2. Main banner body (deep imperial obsidian-teal with chiseled wings)
        cut = 10
        body_pts = [
            (cut, 2 + dy), (w - 1 - cut, 2 + dy),
            (w - 1, 2 + cut + dy), (w - 1, h - 5 - cut + dy),
            (w - 1 - cut, h - 5 + dy), (cut, h - 5 + dy),
            (0, h - 5 - cut + dy), (0, 2 + cut + dy)
        ]
        # Main fill: deep green-slate jade
        bg = C_JADE_DEEP if not is_hover else (24, 58, 50, 255)
        draw.polygon(body_pts, fill=bg)

        # Subtle diagonal fabric / steel weave texture
        for ix in range(cut, w - cut, 4):
            for iy in range(4 + dy, h - 6 + dy, 4):
                draw.point((ix + (iy % 8), iy), fill=(32, 72, 62, 100))

        # Outer border
        border_gold = C_GOLD_BRIGHT if is_hover else C_GOLD_BASE
        draw.polygon(body_pts, outline=C_SHADOW_DEEP)

        # Inner chiseled gold frame
        inner_pts = [
            (cut + 1, 3 + dy), (w - 2 - cut, 3 + dy),
            (w - 2, 3 + cut + dy), (w - 2, h - 6 - cut + dy),
            (w - 2 - cut, h - 6 + dy), (cut + 1, h - 6 + dy),
            (1, h - 6 - cut + dy), (1, 3 + cut + dy)
        ]
        draw.polygon(inner_pts, outline=border_gold)

        # Top highlight and bottom shade
        draw.line([cut + 2, 4 + dy, w - cut - 3, 4 + dy], fill=C_GOLD_WHITE if is_hover else C_GOLD_BRIGHT)
        draw.line([cut + 2, h - 7 + dy, w - cut - 3, h - 7 + dy], fill=C_GOLD_SHADOW)

        # Brass corner reinforcements
        draw_brass_corner(draw, 2, 3 + dy, w - 3, h - 6 + dy, size=16)

        # 3. Left Medallion: Embossed 8-Pointed Travel Compass Rose
        cx, cy = 48, 44 + dy
        r = 28
        # Outer ring
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=C_SHADOW_DEEP, outline=C_GOLD_BASE)
        draw.ellipse([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], fill=C_IRON_DARK, outline=C_GOLD_DEEP)
        draw.ellipse([cx - r + 4, cy - r + 4, cx + r - 4, cy + r - 4], fill=C_JADE_DEEP)

        # 8-pointed star compass
        # Cardinal points
        for angle_deg in [0, 90, 180, 270]:
            rad = math.radians(angle_deg)
            rad_cw = math.radians(angle_deg + 45)
            p_tip = (int(cx + math.cos(rad) * 22), int(cy + math.sin(rad) * 22))
            p_left = (int(cx + math.cos(rad - math.pi / 2) * 6), int(cy + math.sin(rad - math.pi / 2) * 6))
            p_right = (int(cx + math.cos(rad + math.pi / 2) * 6), int(cy + math.sin(rad + math.pi / 2) * 6))
            # Halves: light & dark
            draw.polygon([(cx, cy), p_tip, p_left], fill=C_GOLD_WHITE if is_hover else C_GOLD_BRIGHT)
            draw.polygon([(cx, cy), p_tip, p_right], fill=C_GOLD_DEEP)

        # Diagonal points (smaller)
        for angle_deg in [45, 135, 225, 315]:
            rad = math.radians(angle_deg)
            p_tip = (int(cx + math.cos(rad) * 15), int(cy + math.sin(rad) * 15))
            p_left = (int(cx + math.cos(rad - math.pi / 2) * 4), int(cy + math.sin(rad - math.pi / 2) * 4))
            p_right = (int(cx + math.cos(rad + math.pi / 2) * 4), int(cy + math.sin(rad + math.pi / 2) * 4))
            draw.polygon([(cx, cy), p_tip, p_left], fill=C_GOLD_LIGHT)
            draw.polygon([(cx, cy), p_tip, p_right], fill=C_GOLD_SHADOW)

        # Center jewel (Glowing ruby in compass center)
        draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=C_RED_BASE, outline=C_GOLD_WHITE)
        draw.point((cx - 1, cy - 1), fill=C_RED_WHITE)

        # 4. Destination Sub-Plate (Inset Cartouche at bottom-center)
        # Position: x=100..340, y=52..72
        bx0, by0, bw, bh = 104, 52 + dy, 240, 22
        draw.rectangle([bx0, by0, bx0 + bw - 1, by0 + bh - 1], fill=C_SHADOW_DEEP)
        draw.rectangle([bx0, by0, bx0 + bw - 1, by0 + bh - 1], outline=C_GOLD_DEEP)
        draw.line([bx0 + 1, by0 + 1, bx0 + bw - 2, by0 + 1], fill=(22, 54, 46, 255))
        draw.line([bx0 + 1, by0 + bh - 2, bx0 + bw - 2, by0 + bh - 2], fill=C_GOLD_SHADOW)
        # Decorative end diamonds
        draw.point((bx0 + 4, by0 + bh // 2), fill=C_GOLD_LIGHT)
        draw.point((bx0 + bw - 5, by0 + bh // 2), fill=C_GOLD_LIGHT)

        # 5. Right Forward Chevron
        arr_x, arr_y = 376, 44 + dy
        chevron = [
            (arr_x - 6, arr_y - 12), (arr_x + 4, arr_y), (arr_x - 6, arr_y + 12),
            (arr_x - 1, arr_y + 12), (arr_x + 9, arr_y), (arr_x - 1, arr_y - 12)
        ]
        draw.polygon(chevron, fill=C_GOLD_BRIGHT if is_hover else C_GOLD_BASE)
        draw.line([arr_x + 4, arr_y, arr_x + 9, arr_y], fill=C_GOLD_WHITE)

        atlas.paste(im, (0, y_offset))

    atlas.save(os.path.join(OUT_DIR, "expedition_banner_pixel.png"))
    print("Saved expedition_banner_pixel.png")


# =========================================================================
# 3. TITLE SCREEN MENU BOARD & BUTTONS (260 x 52 each)
# =========================================================================
def build_title_menu_buttons():
    w, h = 260, 52
    # Atlas for 4 buttons (Normal, Hover, Pressed)
    # Buttons:
    # 0: 开始游戏 (Prominent Gold/Jade Frame)
    # 1: 游戏介绍 (Fine Carved Wood)
    # 2: 游戏设置 (Fine Carved Wood)
    # 3: 退出游戏 (Fine Carved Wood)
    atlas = Image.new("RGBA", (w * 3, h * 4), C_TRANS)

    button_configs = [
        {"title": "开始游戏", "primary": True, "icon": "gate"},
        {"title": "游戏介绍", "primary": False, "icon": "book"},
        {"title": "游戏设置", "primary": False, "icon": "gear"},
        {"title": "退出游戏", "primary": False, "icon": "exit"}
    ]

    for b_idx, cfg in enumerate(button_configs):
        for s_idx, state in enumerate(["normal", "hover", "pressed"]):
            x_offset = s_idx * w
            y_offset = b_idx * h

            im = Image.new("RGBA", (w, h), C_TRANS)
            draw = ImageDraw.Draw(im)

            dy = 2 if state == "pressed" else 0
            is_hover = (state == "hover")
            is_primary = cfg["primary"]

            # Shadow
            if state != "pressed":
                draw.rectangle([2, 4, w - 3, h - 1], fill=(4, 6, 8, 140))
            else:
                draw.rectangle([2, 4, w - 3, h - 1], fill=(4, 6, 8, 70))

            # Main Button Body
            c = 4
            pts = [
                (c, 1 + dy), (w - 1 - c, 1 + dy),
                (w - 1, 1 + c + dy), (w - 1, h - 3 - c + dy),
                (w - 1 - c, h - 3 + dy), (c, h - 3 + dy),
                (0, h - 3 - c + dy), (0, 1 + c + dy)
            ]

            if is_primary:
                bg = C_JADE_DEEP if not is_hover else (28, 68, 58, 255)
                edge = C_GOLD_BRIGHT if is_hover else C_GOLD_BASE
            else:
                bg = C_IRON_DARK if not is_hover else (32, 44, 56, 255)
                edge = C_GOLD_LIGHT if is_hover else (74, 92, 108, 255)

            draw.polygon(pts, fill=bg)
            draw.polygon(pts, outline=C_SHADOW_DEEP)

            # Bevel edges
            draw.line([c, 2 + dy, w - c - 1, 2 + dy], fill=edge)
            draw.line([1, 1 + c + dy, 1, h - 4 - c + dy], fill=edge)
            draw.line([c, h - 4 + dy, w - c - 1, h - 4 + dy], fill=C_SHADOW_DEEP)
            draw.line([w - 2, 1 + c + dy, w - 2, h - 4 - c + dy], fill=C_SHADOW_DEEP)

            # Corner fittings
            draw_brass_corner(draw, 1, 2 + dy, w - 2, h - 4 + dy, size=8)

            # Left Icon Background Slot (32x32 area)
            ix, iy = 10, 10 + dy
            draw.rectangle([ix, iy, ix + 31, iy + 31], fill=C_SHADOW_DEEP)
            draw.rectangle([ix, iy, ix + 31, iy + 31], outline=C_GOLD_DEEP if is_primary else (56, 70, 84, 255))
            draw.line([ix + 1, iy + 1, ix + 30, iy + 1], fill=C_GOLD_LIGHT if is_primary else C_STEEL_EDGE)

            # Draw the specialized pixel icon inside slot:
            ic_type = cfg["icon"]
            cx, cy = ix + 16, iy + 16
            if ic_type == "gate":
                # Open City Gate / Castle Arch
                draw.rectangle([cx - 8, cy - 8, cx + 8, cy + 8], fill=C_GOLD_DEEP)
                draw.rectangle([cx - 5, cy - 4, cx + 5, cy + 8], fill=C_SHADOW_DEEP)
                draw.line([cx - 8, cy - 8, cx + 8, cy - 8], fill=C_GOLD_BRIGHT)
                draw.point((cx - 8, cy - 10), fill=C_GOLD_WHITE)
                draw.point((cx + 8, cy - 10), fill=C_GOLD_WHITE)
            elif ic_type == "book":
                # Ancient Chronicle Tome
                draw.rectangle([cx - 7, cy - 8, cx + 7, cy + 8], fill=C_BRONZE_BASE)
                draw.line([cx - 7, cy - 8, cx + 7, cy - 8], fill=C_VELLUM_WHT)
                draw.line([cx - 7, cy + 8, cx + 7, cy + 8], fill=C_VELLUM_WHT)
                draw.line([cx, cy - 8, cx, cy + 8], fill=C_GOLD_BRIGHT)
                draw.point((cx + 2, cy), fill=C_RED_LIGHT)  # Bookmark ribbon
            elif ic_type == "gear":
                # Brass Astrolabe / Gear
                draw.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=C_GOLD_BASE, outline=C_GOLD_SHADOW)
                draw.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=C_SHADOW_DEEP)
                for gx in [-7, 7]: draw.point((cx + gx, cy), fill=C_GOLD_BRIGHT)
                for gy in [-7, 7]: draw.point((cx, cy + gy), fill=C_GOLD_BRIGHT)
            elif ic_type == "exit":
                # Sheathed Dagger / Hearth
                draw.line([cx - 6, cy + 6, cx + 6, cy - 6], fill=C_STEEL_EDGE, width=2)
                draw.point((cx - 6, cy + 6), fill=C_GOLD_BRIGHT)  # Pommel
                draw.line([cx - 1, cy + 3, cx - 3, cy + 1], fill=C_GOLD_BASE, width=2)  # Crossguard

            # Right hover diamond indicator
            if is_hover:
                rx, ry = w - 18, 25 + dy
                draw.polygon([(rx, ry - 6), (rx + 6, ry), (rx, ry + 6), (rx - 6, ry)], fill=C_GOLD_BRIGHT)
                draw.point((rx, ry), fill=C_GOLD_WHITE)

            atlas.paste(im, (x_offset, y_offset))

    atlas.save(os.path.join(OUT_DIR, "title_menu_buttons_pixel.png"))
    print("Saved title_menu_buttons_pixel.png")


# =========================================================================
# 4. GLORIOUS PIXEL ART TITLE LOGO ("远征 · 昭元行旅录" 360 x 140)
# =========================================================================
def build_title_logo():
    w, h = 360, 140
    im = Image.new("RGBA", (w, h), C_TRANS)
    draw = ImageDraw.Draw(im)

    # 1. Background atmospheric glow / soft pixel vignette behind logo
    for r in range(48, 8, -4):
        alpha = int((50 - r) * 1.8)
        draw.ellipse([w // 2 - r * 3, h // 2 - r, w // 2 + r * 3, h // 2 + r], fill=(18, 38, 48, alpha))

    # 2. Symmetrical Wing / Dragon Flourish Filigree
    cx = w // 2
    cy = 54
    # Wing Left
    for step in range(16):
        wx = cx - 70 - step * 6
        wy = cy - int(math.sin(step * 0.25) * 22) + (step // 3)
        draw.rectangle([wx - 2, wy - 1, wx + 2, wy + 1], fill=C_GOLD_BASE)
        draw.point((wx, wy - 1), fill=C_GOLD_BRIGHT)
        draw.point((wx, wy + 1), fill=C_GOLD_SHADOW)
    # Wing Right
    for step in range(16):
        wx = cx + 70 + step * 6
        wy = cy - int(math.sin(step * 0.25) * 22) + (step // 3)
        draw.rectangle([wx - 2, wy - 1, wx + 2, wy + 1], fill=C_GOLD_BASE)
        draw.point((wx, wy - 1), fill=C_GOLD_BRIGHT)
        draw.point((wx, wy + 1), fill=C_GOLD_SHADOW)

    # 3. Render "远征" in bold dimensional chiseled typography
    # Use ZCOOLQingKeHuangYou or NotoSansSC-Bold
    font_path = "D:/new bee/远征/assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf"
    if not os.path.exists(font_path):
        font_path = "D:/new bee/远征/assets/fonts/NotoSansSC-Bold.otf"

    f_large = ImageFont.truetype(font_path, 68)

    text = "远征"
    bbox = draw.textbbox((0, 0), text, font=f_large)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (w - tw) // 2
    ty = 16

    # Deep Drop Shadow (multi-step for 3D extrusion)
    for sx, sy in [(0, 4), (0, 3), (1, 3), (-1, 3), (0, 2), (1, 2), (-1, 2), (2, 2), (-2, 2)]:
        draw.text((tx + sx, ty + sy), text, font=f_large, fill=C_SHADOW_DEEP)

    # Dark Outline / Bevel base
    for ox in [-2, -1, 0, 1, 2]:
        for oy in [-2, -1, 0, 1, 2]:
            if abs(ox) + abs(oy) > 0:
                draw.text((tx + ox, ty + oy), text, font=f_large, fill=C_GOLD_SHADOW)

    # Lower shade facet
    draw.text((tx, ty + 1), text, font=f_large, fill=C_GOLD_DEEP)
    # Mid gold body
    draw.text((tx, ty), text, font=f_large, fill=C_GOLD_BASE)
    # Top highlight facet
    draw.text((tx, ty - 1), text, font=f_large, fill=C_GOLD_LIGHT)
    # Specular glint
    draw.text((tx, ty - 2), text, font=f_large, fill=C_GOLD_WHITE)

    # Center jewel between 远 and 征
    gem_x, gem_y = cx, 48
    draw.polygon([(gem_x, gem_y - 8), (gem_x + 6, gem_y), (gem_x, gem_y + 8), (gem_x - 6, gem_y)], fill=C_CYAN_BASE, outline=C_GOLD_WHITE)
    draw.point((gem_x - 1, gem_y - 2), fill=C_CYAN_WHITE)

    # 4. Floating Subtitle Plaque ("昭元行旅录")
    sub_w, sub_h = 196, 26
    sub_x = (w - sub_w) // 2
    sub_y = 98

    # Plaque shadow
    draw.rectangle([sub_x + 2, sub_y + 3, sub_x + sub_w - 1, sub_y + sub_h + 1], fill=(4, 8, 12, 160))
    # Plaque Body (dark slate jade)
    draw.rectangle([sub_x, sub_y, sub_x + sub_w - 1, sub_y + sub_h - 1], fill=C_JADE_DEEP)
    draw.rectangle([sub_x, sub_y, sub_x + sub_w - 1, sub_y + sub_h - 1], outline=C_GOLD_BASE)
    draw.line([sub_x + 1, sub_y + 1, sub_x + sub_w - 2, sub_y + 1], fill=C_GOLD_BRIGHT)
    draw.line([sub_x + 1, sub_y + sub_h - 2, sub_x + sub_w - 2, sub_y + sub_h - 2], fill=C_GOLD_SHADOW)

    # Left/Right ribbon end tails
    draw.polygon([(sub_x - 10, sub_y + sub_h // 2), (sub_x, sub_y), (sub_x, sub_y + sub_h)], fill=C_GOLD_DEEP)
    draw.line([(sub_x - 10, sub_y + sub_h // 2), (sub_x, sub_y)], fill=C_GOLD_BRIGHT)
    draw.polygon([(sub_x + sub_w + 10, sub_y + sub_h // 2), (sub_x + sub_w, sub_y), (sub_x + sub_w, sub_y + sub_h)], fill=C_GOLD_SHADOW)
    draw.line([(sub_x + sub_w + 10, sub_y + sub_h // 2), (sub_x + sub_w, sub_y)], fill=C_GOLD_BASE)

    # Subtitle Text "昭元行旅录"
    font_sub_path = "D:/new bee/远征/assets/fonts/NotoSerifCJKsc-SemiBold.otf"
    f_sub = ImageFont.truetype(font_sub_path, 15)
    sub_text = "昭 元 行 旅 录"
    sbbox = draw.textbbox((0, 0), sub_text, font=f_sub)
    stw = sbbox[2] - sbbox[0]
    stx = (w - stw) // 2
    sty = sub_y + 3

    # Shadow & Text
    draw.text((stx + 1, sty + 1), sub_text, font=f_sub, fill=C_SHADOW_DEEP)
    draw.text((stx, sty), sub_text, font=f_sub, fill=C_GOLD_BRIGHT)

    im.save(os.path.join(OUT_DIR, "title_logo_pixel.png"))
    print("Saved title_logo_pixel.png")


# =========================================================================
# 5. PIXEL PASSPORT FOLIO (Login / Registry Card 408 x 512)
# =========================================================================
def build_login_folio():
    import sys
    sys.path.insert(0, os.path.dirname(__file__))
    from generate_login_folio import build_login_folio as gen_folio
    im = gen_folio()
    im.save(os.path.join(OUT_DIR, "login_folio_pixel.png"))
    print("Saved login_folio_pixel.png")



# =========================================================================
# 6. MASTER 32x32 PIXEL ICONS (Currencies, Badges, Navigation)
# =========================================================================
def build_pixel_icons():
    icons = {}

    # --- 1. COIN (Gold coin with sunburst) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    draw.ellipse([3, 3, 28, 28], fill=C_GOLD_SHADOW)
    draw.ellipse([4, 4, 27, 27], fill=C_GOLD_BASE, outline=C_GOLD_DEEP)
    draw.ellipse([7, 7, 24, 24], outline=C_GOLD_BRIGHT)
    # Center square / sun
    draw.rectangle([12, 12, 19, 19], fill=C_GOLD_DEEP, outline=C_GOLD_WHITE)
    draw.point((14, 14), fill=C_GOLD_WHITE)
    icons["coin"] = im

    # --- 2. EXPEDITION (Jade compass token) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    draw.ellipse([3, 3, 28, 28], fill=C_JADE_DEEP)
    draw.ellipse([4, 4, 27, 27], fill=C_JADE_BASE, outline=C_GOLD_BASE)
    # Needle
    draw.polygon([(16, 6), (19, 16), (16, 26), (13, 16)], fill=C_GOLD_BRIGHT, outline=C_GOLD_SHADOW)
    draw.polygon([(16, 6), (16, 26), (13, 16)], fill=C_RED_BASE)
    draw.ellipse([14, 14, 18, 18], fill=C_GOLD_WHITE)
    icons["expedition"] = im

    # --- 3. SOUL (Luminescent Amethyst Shard) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    pts = [(16, 2), (26, 12), (22, 28), (10, 28), (6, 12)]
    draw.polygon(pts, fill=C_PURPLE_BASE, outline=C_PURPLE_DEEP)
    # Facets
    draw.polygon([(16, 2), (16, 16), (6, 12)], fill=C_PURPLE_LGT)
    draw.polygon([(16, 2), (26, 12), (16, 16)], fill=C_PURPLE_WHT)
    draw.polygon([(16, 16), (22, 28), (10, 28)], fill=C_PURPLE_DEEP)
    draw.point((15, 6), fill=(255, 255, 255, 255))
    icons["soul"] = im

    # --- 4. HONOR (Golden Laurel Medal) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    # Crimson ribbon
    draw.polygon([(8, 2), (13, 14), (6, 18), (3, 2)], fill=C_RED_BASE)
    draw.polygon([(24, 2), (19, 14), (26, 18), (29, 2)], fill=C_RED_DEEP)
    # Gold medal
    draw.ellipse([6, 10, 26, 30], fill=C_GOLD_BASE, outline=C_GOLD_SHADOW)
    draw.ellipse([9, 13, 23, 27], fill=C_GOLD_LIGHT, outline=C_GOLD_BRIGHT)
    # Laurel star
    draw.point((16, 20), fill=C_GOLD_WHITE)
    icons["honor"] = im

    # --- 5. SWORDS (竞技: Crossed Gladius Swords) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    # Blade 1: top-left to bottom-right
    draw.line([5, 5, 26, 26], fill=C_STEEL_EDGE, width=3)
    draw.line([5, 5, 26, 26], fill=(240, 246, 255, 255), width=1)
    # Blade 2: top-right to bottom-left
    draw.line([26, 5, 5, 26], fill=C_STEEL_EDGE, width=3)
    draw.line([26, 5, 5, 26], fill=(240, 246, 255, 255), width=1)
    # Guards & Pommels
    draw.rectangle([7, 21, 11, 25], fill=C_GOLD_BASE)
    draw.rectangle([21, 21, 25, 25], fill=C_GOLD_BASE)
    draw.point((4, 28), fill=C_RED_LIGHT)
    draw.point((28, 28), fill=C_RED_LIGHT)
    icons["swords"] = im

    # --- 6. SUMMON (召唤: Glowing Astral Talisman) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    draw.ellipse([4, 4, 27, 27], fill=C_CYAN_DEEP, outline=C_GOLD_BASE)
    draw.ellipse([7, 7, 24, 24], fill=(22, 68, 88, 255), outline=C_CYAN_LIGHT)
    # Pulsing core
    draw.polygon([(16, 9), (22, 16), (16, 23), (10, 16)], fill=C_CYAN_WHITE)
    # Orbiting spark motes
    draw.point((8, 11), fill=C_GOLD_WHITE)
    draw.point((24, 11), fill=C_GOLD_WHITE)
    draw.point((16, 26), fill=C_GOLD_WHITE)
    icons["summon"] = im

    # --- 7. EXCHANGE (兑换: Antique Balance Scales) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    # Center pillar
    draw.line([16, 4, 16, 28], fill=C_GOLD_BASE, width=2)
    draw.rectangle([14, 27, 18, 29], fill=C_GOLD_SHADOW)
    # Beam
    draw.line([6, 9, 26, 9], fill=C_GOLD_BRIGHT, width=2)
    draw.point((16, 7), fill=C_GOLD_WHITE)
    # Left pan
    draw.line([6, 11, 3, 19], fill=C_GOLD_BASE)
    draw.line([8, 11, 11, 19], fill=C_GOLD_BASE)
    draw.arc([3, 17, 11, 23], 0, 180, fill=C_GOLD_BRIGHT)
    # Right pan
    draw.line([26, 11, 23, 19], fill=C_GOLD_BASE)
    draw.line([24, 11, 27, 19], fill=C_GOLD_BASE)
    draw.arc([21, 17, 29, 23], 0, 180, fill=C_GOLD_BRIGHT)
    icons["exchange"] = im

    # --- 8. SPARK (活动: Wax-Sealed Courier Scroll) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    draw.rectangle([5, 6, 27, 22], fill=C_VELLUM_BASE, outline=C_VELLUM_DARK)
    draw.line([6, 7, 26, 7], fill=C_VELLUM_WHT)
    # Envelope flap lines
    draw.line([5, 6, 16, 16], fill=C_VELLUM_DARK)
    draw.line([27, 6, 16, 16], fill=C_VELLUM_DARK)
    # Red wax seal in center
    draw.ellipse([12, 12, 20, 20], fill=C_RED_BASE, outline=C_GOLD_BASE)
    draw.point((15, 15), fill=C_RED_WHITE)
    icons["spark"] = im

    # --- 9. WORLD (世界: Rolled Nautical Map) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    draw.rectangle([4, 6, 27, 25], fill=C_VELLUM_BASE, outline=C_BRONZE_DARK)
    draw.line([5, 7, 26, 7], fill=C_VELLUM_WHT)
    # Island & route dots
    draw.polygon([(8, 12), (14, 10), (12, 18), (7, 16)], fill=C_JADE_BASE)
    draw.polygon([(18, 16), (24, 14), (22, 22), (17, 20)], fill=C_JADE_BASE)
    draw.line([12, 14, 18, 17], fill=C_RED_BASE)
    # Compass star in top right
    draw.point((23, 10), fill=C_GOLD_DEEP)
    icons["world"] = im

    # --- 10. BAG (背包: Leather Rucksack) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    # Bag body
    draw.rectangle([5, 10, 26, 27], fill=C_BRONZE_BASE, outline=C_BRONZE_DARK)
    # Top flap
    draw.polygon([(4, 10), (27, 10), (25, 17), (6, 17)], fill=C_BRONZE_LGT, outline=C_BRONZE_DARK)
    # Brass straps & buckles
    draw.line([10, 10, 10, 27], fill=C_GOLD_BASE)
    draw.line([21, 10, 21, 27], fill=C_GOLD_BASE)
    draw.rectangle([9, 16, 11, 18], fill=C_GOLD_BRIGHT)
    draw.rectangle([20, 16, 22, 18], fill=C_GOLD_BRIGHT)
    # Top handle
    draw.arc([11, 5, 20, 13], 180, 0, fill=C_BRONZE_DARK)
    icons["bag"] = im

    # --- 11. GROWTH (养成: Mandrake Sprout & Training Sigil) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    # Pot / Base runic stone
    draw.polygon([(8, 18), (23, 18), (20, 28), (11, 28)], fill=C_IRON_MID, outline=C_SHADOW_DEEP)
    draw.line([9, 19, 22, 19], fill=C_GOLD_BASE)
    # Sprouting emerald leaves
    draw.polygon([(15, 18), (10, 9), (16, 13)], fill=C_JADE_MINT, outline=C_JADE_DEEP)
    draw.polygon([(16, 18), (22, 8), (17, 13)], fill=C_JADE_LIGHT, outline=C_JADE_DEEP)
    draw.line([15, 14, 15, 18], fill=C_JADE_DEEP)
    # Golden glow particles
    draw.point((8, 8), fill=C_GOLD_BRIGHT)
    draw.point((24, 7), fill=C_GOLD_BRIGHT)
    icons["growth"] = im

    # --- 12. BOOK (图鉴: Illuminated Codex) ---
    im = Image.new("RGBA", (32, 32), C_TRANS)
    draw = ImageDraw.Draw(im)
    draw.rectangle([5, 5, 26, 27], fill=C_IRON_DARK, outline=C_SHADOW_DEEP)
    draw.line([5, 5, 26, 5], fill=C_GOLD_BASE)
    draw.line([5, 27, 26, 27], fill=C_GOLD_BASE)
    # Spine on left
    draw.rectangle([5, 5, 8, 27], fill=C_RED_BASE)
    # Gold emblem on cover
    draw.polygon([(17, 11), (22, 16), (17, 21), (12, 16)], fill=C_GOLD_BRIGHT, outline=C_GOLD_DEEP)
    draw.point((17, 16), fill=C_CYAN_LIGHT)
    icons["book"] = im

    # Save all to both OUT_DIR and ICON_DIR
    for name, icon_img in icons.items():
        icon_img.save(os.path.join(OUT_DIR, f"icon_{name}.png"))
        icon_img.save(os.path.join(ICON_DIR, f"{name}.png"))
        # Also copy to assets/ui/pixel_icons/
        icon_img.save(f"D:/new bee/远征/assets/ui/pixel_icons/{name}.png")
    print(f"Generated and saved {len(icons)} pixel icons.")


if __name__ == "__main__":
    print("Building Core Pixel Art System Assets...")
    build_loading_gauge()
    build_loading_fill()
    build_expedition_banner()
    build_title_menu_buttons()
    build_title_logo()
    build_login_folio()
    build_pixel_icons()
    print("All Pixel Art Assets successfully created!")
