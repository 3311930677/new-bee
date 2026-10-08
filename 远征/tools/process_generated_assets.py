"""
tools/process_generated_assets.py
Processes AI generated pixel artwork:
- Removes white background using flood fill from edges to preserve interior whites
- Crops and scales to exact game dimensions
- Generates normal, hover, pressed button states
"""

import os
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

BRAIN_DIR = "C:/Users/Administrator/.gemini/antigravity/brain/51ddb207-600f-4110-af3c-d7395f7fbc70"
OUT_DIR = "D:/new bee/远征/image/ui/pixel_20261008"
os.makedirs(OUT_DIR, exist_ok=True)

def remove_background_flood(img, tol=235):
    """Removes outer background starting from corners using flood fill."""
    im = img.convert("RGBA")
    w, h = im.size
    arr = np.array(im)
    r, g, b, a = arr[:,:,0], arr[:,:,1], arr[:,:,2], arr[:,:,3]
    
    # Is white or near white
    is_white = (r >= tol) & (g >= tol) & (b >= tol)
    
    # Mask of visited pixels
    visited = np.zeros((h, w), dtype=bool)
    
    # BFS from 4 corners and perimeter
    from collections import deque
    q = deque()
    
    for x in range(w):
        if is_white[0, x]: q.append((0, x)); visited[0, x] = True
        if is_white[h-1, x]: q.append((h-1, x)); visited[h-1, x] = True
    for y in range(h):
        if is_white[y, 0]: q.append((y, 0)); visited[y, 0] = True
        if is_white[y, w-1]: q.append((y, w-1)); visited[y, w-1] = True
        
    while q:
        cy, cx = q.popleft()
        for dy, dx in [(-1,0), (1,0), (0,-1), (0,1)]:
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if is_white[ny, nx]:
                    visited[ny, nx] = True
                    q.append((ny, nx))
                    
    # Set visited background to transparent
    arr[visited, 3] = 0
    return Image.fromarray(arr)

def process_logo():
    path = os.path.join(BRAIN_DIR, "pixel_title_logo_1791398270702.jpg")
    if not os.path.exists(path):
        print("Logo not found:", path)
        return
    im = Image.open(path)
    clean = remove_background_flood(im, tol=235)
    bbox = clean.getbbox()
    cropped = clean.crop(bbox)
    
    # Target size: width 360, aspect preserved
    target_w = 360
    target_h = int(cropped.size[1] * target_w / cropped.size[0])
    scaled = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    out_path = os.path.join(OUT_DIR, "master_title_logo.png")
    scaled.save(out_path)
    print("Saved logo:", out_path, scaled.size)
    
    # Also save to image/ui/expedition_wordmark_pixel.png so anything loading it directly gets pixel art
    scaled.save("D:/new bee/远征/image/ui/expedition_wordmark_pixel.png")

def process_loading_gauge():
    path = os.path.join(BRAIN_DIR, "pixel_loading_gauge_1791398452413.jpg")
    if not os.path.exists(path):
        print("Gauge not found:", path)
        return
    im = Image.open(path)
    clean = remove_background_flood(im, tol=230)
    bbox = clean.getbbox()
    cropped = clean.crop(bbox)
    
    # Target width 416, height 66
    target_w = 416
    target_h = 66
    scaled = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    out_path = os.path.join(OUT_DIR, "master_loading_gauge.png")
    scaled.save(out_path)
    print("Saved loading gauge:", out_path, scaled.size)

def process_expedition_banner():
    path = os.path.join(BRAIN_DIR, "pixel_expedition_banner_1791398499241.jpg")
    if not os.path.exists(path):
        print("Banner not found:", path)
        return
    im = Image.open(path)
    clean = remove_background_flood(im, tol=230)
    bbox = clean.getbbox()
    cropped = clean.crop(bbox)
    
    # Target width 416, height 88
    target_w = 416
    target_h = 88
    scaled = cropped.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # Build 3-state atlas (Normal, Hover, Pressed)
    atlas = Image.new("RGBA", (target_w, target_h * 3), (0, 0, 0, 0))
    
    # 1. Normal
    atlas.paste(scaled, (0, 0))
    
    # 2. Hover (slight golden glow / brightness boost)
    hover_im = scaled.copy()
    enhancer = np.array(hover_im, dtype=np.float32)
    enhancer[:, :, :3] = np.clip(enhancer[:, :, :3] * 1.12 + 8, 0, 255)
    hover_final = Image.fromarray(enhancer.astype(np.uint8))
    atlas.paste(hover_final, (0, target_h))
    
    # 3. Pressed (shifted down by 2px)
    pressed_im = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    pressed_scaled = scaled.crop((0, 0, target_w, target_h - 2))
    pressed_im.paste(pressed_scaled, (0, 2))
    atlas.paste(pressed_im, (0, target_h * 2))
    
    out_path = os.path.join(OUT_DIR, "master_expedition_banner.png")
    atlas.save(out_path)
    print("Saved expedition banner atlas:", out_path, atlas.size)

def build_pixel_title_board():
    """Generates the Title Screen Sandalwood & Brass Menu Board (280 x 260)"""
    from generate_title_menu_board import generate_title_menu_board
    out_path = os.path.join(OUT_DIR, "title_menu_board.png")
    generate_title_menu_board(out_path)


if __name__ == "__main__":
    process_logo()
    process_loading_gauge()
    process_expedition_banner()
    build_pixel_title_board()
    print("All processed successfully!")
