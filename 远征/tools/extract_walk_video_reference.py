"""Extract timestamped video poses without inventing or redrawing animation."""
from pathlib import Path
import json
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'shots' / 'walk_video_20261003'
VIDEO = Path(r'C:\Users\tsz\Downloads\video_20261003_204732.mp4')
# Avoid direction transitions and the late left-facing shot's clipped staff.
TIMES = {
    'down': [0.10, 0.23, 0.37, 0.50, 0.63, 0.77],
    'left': [5.10, 5.30, 5.50, 5.70, 5.90, 6.10],
    'right': [8.00, 8.20, 8.40, 8.60, 8.80, 9.00],
    'up': [3.10, 3.23, 3.37, 3.50, 3.63, 3.77],
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(str(VIDEO))
    fps = cap.get(cv2.CAP_PROP_FPS)
    grid = Image.new('RGB', (1536, 1024), (180, 180, 180))
    labels = Image.new('RGB', (1536, 1120), (28, 31, 39))
    draw = ImageDraw.Draw(labels)
    manifest = {'video': str(VIDEO), 'fps': fps, 'directions': list(TIMES), 'frames': []}
    for row, (direction, times) in enumerate(TIMES.items()):
        for col, seconds in enumerate(times):
            frame_index = round(seconds * fps)
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
            ok, bgr = cap.read()
            if not ok:
                raise RuntimeError(f'Cannot decode {frame_index}')
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            # Blue/color bounds locate the character and exclude the watermark.
            hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
            mask = ((hsv[:, :, 1] > 65) & (hsv[:, :, 2] > 45)).astype('uint8')
            mask[:400] = 0
            mask[1550:] = 0
            ys, xs = np.where(mask)
            x, y = int(xs.min()), int(ys.min())
            x1, y1 = int(xs.max()+1), int(ys.max()+1)
            box = (max(0, x-50), max(0, y-60), min(1080, x1+50), min(1600, y1+70))
            image = Image.fromarray(rgb).crop(box)
            # Video zoom is removed before the cleanup reference is constructed.
            scale = min(224 / image.width, 230 / image.height)
            sprite = image.resize((round(image.width*scale), round(image.height*scale)), Image.Resampling.LANCZOS)
            cell = Image.new('RGB', (256, 256), (180, 180, 180))
            cell.paste(sprite, ((256-sprite.width)//2, 244-sprite.height))
            cell.save(OUT / f'{direction}_{col}_raw.png')
            grid.paste(cell, (col*256, row*256))
            labels.paste(cell, (col*256, row*280))
            draw.text((col*256+8, row*280+259), f'{direction} {col}: {frame_index/fps:.3f}s / #{frame_index}', fill='white')
            manifest['frames'].append({'direction': direction, 'slot': col, 'frame': frame_index,
                                       'seconds': frame_index/fps, 'crop': list(box)})
    cap.release()
    grid.save(OUT / 'extracted_6x4_raw.png')
    labels.save(OUT / 'extracted_keyframes_labeled.png')
    (OUT / 'source_frames.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print('Extracted 24 actual video frames: down / left / right / up')

if __name__ == '__main__':
    main()
