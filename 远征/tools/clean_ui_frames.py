"""
tools/clean_ui_frames.py
Cleans inner slots of master_loading_gauge and master_expedition_banner so that
dynamic text, percentage, and progress fills can be rendered with 100% precision by Godot.
"""

from PIL import Image, ImageDraw
import numpy as np

GAUGE_PATH = "D:/new bee/远征/image/ui/pixel_20261008/master_loading_gauge.png"
BANNER_PATH = "D:/new bee/远征/image/ui/pixel_20261008/master_expedition_banner.png"

def clean_gauge():
    im = Image.open(GAUGE_PATH).convert("RGBA")
    draw = ImageDraw.Draw(im)
    w, h = im.size
    
    # Groove channel area: x=116..308, y=26..38 (approximately in 416x66 scale)
    # Let's inspect the coordinates of the channel
    # In 416x66:
    # Groove box: x=118..308, y=27..38
    # Fill the groove with dark granite/iron channel
    draw.rectangle([118, 26, 310, 39], fill=(12, 16, 22, 255))
    # Bevel lines
    draw.line([118, 26, 310, 26], fill=(6, 8, 12, 255))
    draw.line([118, 39, 310, 39], fill=(36, 48, 60, 255))
    # Scale tick marks
    for x in range(130, 305, 20):
        draw.line([x, 28, x, 31], fill=(68, 54, 32, 255))
        draw.line([x, 34, x, 37], fill=(68, 54, 32, 255))
        
    # Percentage circle socket: center at around x=348, y=34, r=16
    draw.ellipse([334, 20, 362, 48], fill=(14, 18, 24, 255))
    draw.ellipse([334, 20, 362, 48], outline=(160, 118, 40, 255))
    draw.ellipse([335, 21, 361, 47], outline=(218, 168, 62, 255))
    draw.ellipse([337, 23, 359, 45], outline=(10, 14, 18, 255))
    
    # Clear "LOADING" text below circle (y=50..62, x=320..380)
    draw.rectangle([320, 49, 376, 62], fill=(28, 34, 42, 255))
    # Outer dark iron border around it
    draw.line([320, 62, 376, 62], fill=(14, 18, 22, 255))

    im.save("D:/new bee/远征/image/ui/pixel_20261008/relic_gauge_clean.png")
    print("Saved relic_gauge_clean.png")

def clean_banner():
    # 416 x 264 atlas (each state 88px high)
    atlas = Image.open(BANNER_PATH).convert("RGBA")
    w, h = 416, 88
    
    clean_atlas = Image.new("RGBA", (w, h * 3), (0, 0, 0, 0))
    
    for s_idx in range(3):
        y_off = s_idx * h
        frame = atlas.crop((0, y_off, w, y_off + h))
        draw = ImageDraw.Draw(frame)
        dy = 2 if s_idx == 2 else 0
        
        # Center jade area: x=126..336, y=20+dy..54+dy
        # Clean out "继续旅程" text with smooth jade texture
        draw.rectangle([126, 20 + dy, 336, 52 + dy], fill=(22, 54, 52, 255))
        # Inner jade subtle grid/grain
        for x in range(128, 335, 4):
            for y in range(22 + dy, 51 + dy, 4):
                draw.point((x + (y % 8), y), fill=(30, 72, 70, 140))
        # Top inner edge highlight
        draw.line([126, 20 + dy, 336, 20 + dy], fill=(42, 92, 88, 255))
        draw.line([126, 52 + dy, 336, 52 + dy], fill=(12, 34, 32, 255))
        
        # Bottom parchment tag: x=148..314, y=56+dy..76+dy
        # Clean out "昭元边城" text with parchment paper texture
        draw.rectangle([148, 56 + dy, 314, 76 + dy], fill=(234, 218, 182, 255))
        # Paper texture lines
        for y in range(57 + dy, 75 + dy, 2):
            draw.line([150, y, 312, y], fill=(244, 230, 200, 255))
        draw.rectangle([148, 56 + dy, 314, 76 + dy], outline=(156, 128, 88, 255))
        
        clean_atlas.paste(frame, (0, y_off))
        
    clean_atlas.save("D:/new bee/远征/image/ui/pixel_20261008/expedition_banner_clean.png")
    print("Saved expedition_banner_clean.png")

if __name__ == "__main__":
    clean_gauge()
    clean_banner()
