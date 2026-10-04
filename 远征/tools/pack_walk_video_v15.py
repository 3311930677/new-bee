"""Register the cleaned video-based six-phase walk to existing game coordinates."""
from pathlib import Path
import json
import shutil
import hashlib
import numpy as np
from PIL import Image, ImageDraw
import cv2

ROOT = Path(__file__).resolve().parents[1]
ROLE = ROOT / 'image' / 'role' / 'fs'
QA = ROOT / 'shots' / 'walk_video_20261003'
DIRECTIONS = ('down', 'left', 'right', 'up')
CELL, COLS, BASELINE, FPS = 128, 6, 120, 12

def clean_alpha(image):
    pixels = np.array(image.convert('RGBA'))
    alpha = (pixels[:, :, 3] >= 128).astype('uint8')
    count, labels, stats, _ = cv2.connectedComponentsWithStats(alpha, 8)
    for label in range(1, count):
        if stats[label, cv2.CC_STAT_AREA] < 8:
            alpha[labels == label] = 0
    pixels[:, :, 3] = alpha * 255
    pixels[alpha == 0] = 0
    return Image.fromarray(pixels)

def preview(old, new):
    frames = []
    for slot in range(COLS):
        canvas = Image.new('RGB', (640, 390), '#252d3a')
        draw = ImageDraw.Draw(canvas)
        draw.text((35, 12), 'Before (64px)', fill='white')
        draw.text((350, 12), 'Video v15 (64px)', fill='white')
        for row, direction in enumerate(DIRECTIONS):
            y = 46+row*84
            draw.text((4, y+23), direction, fill='#e5bd6e')
            draw.line((70, y+65, 630, y+65), fill='#556174')
            for image, x in ((old, 120), (new, 430)):
                tile = image.crop((slot*CELL, row*CELL, (slot+1)*CELL, (row+1)*CELL))
                tile = tile.resize((64, 64), Image.Resampling.NEAREST)
                canvas.paste(tile, (x, y+5), tile)
        frames.append(canvas)
    frames[0].save(QA/'before_after_64.gif', save_all=True, append_images=frames[1:],
                   duration=round(1000/FPS), loop=0, disposal=2)
    large = []
    for slot in range(COLS):
        canvas = Image.new('RGB', (768, 192), '#252d3a')
        draw = ImageDraw.Draw(canvas)
        for row, direction in enumerate(DIRECTIONS):
            tile = new.crop((slot*CELL, row*CELL, (slot+1)*CELL, (row+1)*CELL))
            canvas.paste(tile, (row*192+32, 24), tile)
            draw.text((row*192+70, 165), direction, fill='white')
        large.append(canvas)
    large[0].save(QA/'walk_video_v15_128.gif', save_all=True, append_images=large[1:],
                  duration=round(1000/FPS), loop=0, disposal=2)

def main():
    QA.mkdir(parents=True, exist_ok=True)
    source_path = ROLE/'source'/'shuangyu_walk_video_v15.png'
    source = Image.open(source_path)
    if source.size != (1536, 1024):
        raise ValueError('Expected 6x4 grid of 256px cells')
    cells = [[clean_alpha(source.crop((col*256, row*256, (col+1)*256, (row+1)*256)))
              for col in range(COLS)] for row in range(4)]
    boxes = [frame.getchannel('A').getbbox() for row in cells for frame in row]
    if any(box is None for box in boxes):
        raise ValueError('Empty source cell')
    shared = (min(b[0] for b in boxes), min(b[1] for b in boxes),
              max(b[2] for b in boxes), max(b[3] for b in boxes))
    scale = min(116/(shared[2]-shared[0]), 112/(shared[3]-shared[1]))
    crop_size = (round((shared[2]-shared[0])*scale), round((shared[3]-shared[1])*scale))
    origin = (round(CELL/2-(128-shared[0])*scale), BASELINE-crop_size[1]+1)
    # One shared transform for all 24 cells: never recenter individual silhouettes.
    atlas = Image.new('RGBA', (768, 512))
    report = {'source': source_path.relative_to(ROOT).as_posix(), 'fps': FPS,
              'grid': [6, 4], 'cell': [128, 128], 'shared_crop': shared,
              'scale': scale, 'origin': origin, 'frames': []}
    contact = Image.new('RGB', (1536, 1120), '#252d3a')
    draw = ImageDraw.Draw(contact)
    for row, direction in enumerate(DIRECTIONS):
        packed = []
        for col, frame in enumerate(cells[row]):
            tile = Image.new('RGBA', (CELL, CELL))
            tile.alpha_composite(frame.crop(shared).resize(crop_size, Image.Resampling.NEAREST), origin)
            bbox = tile.getchannel('A').getbbox()
            assert bbox and bbox[0] >= 4 and bbox[2] <= 124 and bbox[1] >= 4 and bbox[3] <= 124, bbox
            assert tile.getchannel('A').crop((0, 113, CELL, 123)).getbbox(), (direction, col, 'ungrounded')
            packed.append(tile)
            atlas.alpha_composite(tile, (col*CELL, row*CELL))
            zoom = tile.resize((256, 256), Image.Resampling.NEAREST)
            contact.paste(zoom, (col*256, row*280), zoom)
            draw.text((col*256+8, row*280+259), f'{direction} {col}', fill='white')
            report['frames'].append({'direction': direction, 'slot': col, 'bbox': bbox,
                                     'sha256': hashlib.sha256(tile.tobytes()).hexdigest()})
        assert len({hashlib.sha256(tile.tobytes()).hexdigest() for tile in packed}) == COLS
    backup = ROLE/'source'/'shuangyu_walk_before_video_v15.png'
    active = ROLE/'shuangyu_walk_4dir.png'
    if not backup.exists():
        shutil.copy2(active, backup)
    old = Image.open(backup).convert('RGBA')
    atlas.save(ROLE/'shuangyu_walk_video_v15.png')
    atlas.save(active)
    contact.save(QA/'walk_video_v15_phases.png')
    preview(old, atlas)
    (QA/'technical_checks.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('VIDEO_WALK_V15_OK: 24 unique RGBA frames; fixed shared anchor; original backed up')

if __name__ == '__main__':
    main()
