"""Slice approved 8x4 alpha walking art into uniform Godot 4 atlases.

This is mechanical cutting/packing, not generation of animation poses.
All artwork comes from imagegen; a single scale is used across each character.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw
from normalize_sprite_sheet import remove_connected_checkerboard

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / 'image' / 'role' / 'walk_4dir_review'
CELL, COLS, ROWS, BASELINE = 128, 8, 4, 120
DIRECTIONS = ('down', 'left', 'right', 'up')
ROLES = (('zs', 'pojun'), ('ck', 'chuanyang'), ('fs', 'shuangyu'), ('fz', 'chenxing'))


def remove_matte_specks(frame: Image.Image) -> tuple[Image.Image, int]:
    """Remove only isolated <=6-pixel matte debris; preserve full sprite parts."""
    frame = frame.copy()
    pixels = frame.load()
    seen, removed = set(), 0
    for y in range(frame.height):
        for x in range(frame.width):
            if (x, y) in seen or pixels[x, y][3] < 32:
                continue
            pending, component = [(x, y)], []
            seen.add((x, y))
            while pending:
                px, py = pending.pop()
                component.append((px, py))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = px + dx, py + dy
                        if (0 <= nx < frame.width and 0 <= ny < frame.height
                                and (nx, ny) not in seen and pixels[nx, ny][3] >= 32):
                            seen.add((nx, ny))
                            pending.append((nx, ny))
            if len(component) <= 6:
                for px, py in component:
                    pixels[px, py] = (0, 0, 0, 0)
                removed += len(component)
    return frame, removed


def component_frames(band: Image.Image) -> list[Image.Image]:
    """Assign connected silhouettes to the nearest nominal cell without clipping overlap."""
    mask = band.getchannel('A').point(lambda v: 255 if v >= 32 else 0)
    mp = mask.load()
    seen, groups = set(), [[] for _ in range(COLS)]
    for y in range(band.height):
        for x in range(band.width):
            if (x, y) in seen or not mp[x, y]:
                continue
            pending, component = [(x, y)], []
            seen.add((x, y))
            while pending:
                px, py = pending.pop()
                component.append((px, py))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = px + dx, py + dy
                        if (0 <= nx < band.width and 0 <= ny < band.height
                                and (nx, ny) not in seen and mp[nx, ny]):
                            seen.add((nx, ny))
                            pending.append((nx, ny))
            cx = sum(p[0] for p in component) / len(component)
            groups[min(COLS - 1, int(cx * COLS / band.width))].extend(component)
    results = []
    source_pixels = band.load()
    for group in groups:
        canvas = Image.new('RGBA', band.size, (0, 0, 0, 0))
        target = canvas.load()
        for x, y in group:
            target[x, y] = source_pixels[x, y]
        results.append(canvas)
    return results


def gap_cuts(projection: list[int], count: int) -> list[int]:
    """Find real empty separators near the expected layout, without clipping feet."""
    size = len(projection)
    cuts = [0]
    for index in range(1, count):
        target = index * size / count
        radius = size / count * 0.22
        lo, hi = max(1, int(target - radius)), min(size - 1, int(target + radius))
        runs, start = [], None
        for pos in range(lo, hi + 1):
            if not projection[pos] and start is None:
                start = pos
            if projection[pos] and start is not None:
                runs.append((start, pos))
                start = None
        if start is not None:
            runs.append((start, hi + 1))
        if not runs:
            raise ValueError(f'No genuine transparent separator near {target}')
        run = min(runs, key=lambda r: abs((r[0] + r[1]) / 2 - target))
        cuts.append((run[0] + run[1]) // 2)
    return cuts + [size]


def sprite_frames(path: Path, texture: str) -> None:
    lines = ['[gd_resource type="SpriteFrames" load_steps=34 format=3]', '',
             f'[ext_resource type="Texture2D" path="{texture}" id="1"]', '']
    for row in range(ROWS):
        for col in range(COLS):
            idx = row * COLS + col
            lines.extend([f'[sub_resource type="AtlasTexture" id="Atlas_{idx}"]',
                          'atlas = ExtResource("1")',
                          f'region = Rect2({col * CELL}, {row * CELL}, {CELL}, {CELL})',
                          'filter_clip = true', ''])
    lines.extend(['[resource]', 'animations = ['])
    for row, direction in enumerate(DIRECTIONS):
        frames = ', '.join('{"duration": 1.0, "texture": SubResource("Atlas_%d")}' % (row * COLS + c) for c in range(COLS))
        lines.extend(['{', f'"frames": [{frames}],', '"loop": true,',
                      f'"name": &"walk_{direction}",', '"speed": 10.0',
                      '},' if row < ROWS - 1 else '}'])
    lines.append(']')
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def contact_sheet(sheet: Image.Image, path: Path) -> None:
    cw, ch = 256, 280
    contact = Image.new('RGB', (COLS * cw, ROWS * ch), (26, 29, 36))
    draw = ImageDraw.Draw(contact)
    for row, direction in enumerate(DIRECTIONS):
        for col in range(COLS):
            f = sheet.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
            f = f.resize((256, 256), Image.Resampling.NEAREST)
            contact.paste(f, (col * cw, row * ch), f)
            draw.text((col * cw + 8, row * ch + 259), f'{direction}  frame {col}', fill='white')
    contact.save(path)


def main() -> None:
    selected = json.loads((REVIEW / 'selected_sources.json').read_text(encoding='utf-8-sig'))
    qa_dir = REVIEW / 'qa'
    qa_dir.mkdir(parents=True, exist_ok=True)
    report = {'cell': CELL, 'columns': COLS, 'rows': ROWS, 'row_order': DIRECTIONS,
              'baseline': BASELINE, 'fps': 10, 'roles': []}
    packed = []
    for role_id, name in ROLES:
        paths = selected[role_id]
        paths = paths if isinstance(paths, list) else [paths] * ROWS
        cache, row_images = {}, []
        for relative in paths:
            if relative not in cache:
                source = ROOT / relative
                im = Image.open(source)
                # Reuse the project's boundary-connected matte cleanup for cutting.
                if 'A' not in im.getbands() or im.getchannel('A').getextrema()[0] == 255:
                    im = remove_connected_checkerboard(im, neutral_floor=100)
                    im.save(source.with_name(source.stem + '_alpha.png'))
                if 'A' not in im.getbands() or im.getchannel('A').getextrema()[0] == 255:
                    raise ValueError(f'{role_id}: approved source must have genuine transparent alpha')
                cache[relative] = im.convert('RGBA')
            row_images.append(cache[relative])
        im = row_images[0]
        if any(other.size != im.size for other in row_images):
            raise ValueError(f'{role_id}: selected rows must share the same grid size')
        w, h = im.size
        if abs(w / h - 2.0) > 0.025:
            raise ValueError(f'{role_id}: source aspect ratio is not the required 8x4 grid')
        extracted, raw_data = [], []
        for row, direction in enumerate(DIRECTIONS):
            row_image = row_images[row]
            full_mask = row_image.getchannel('A').point(lambda v: 255 if v >= 32 else 0)
            y_cuts = gap_cuts(full_mask.getprojection()[1], ROWS)
            band = row_image.crop((0, y_cuts[row], w, y_cuts[row + 1]))
            band_mask = band.getchannel('A').point(lambda v: 255 if v >= 32 else 0)
            try:
                x_cuts = gap_cuts(band_mask.getprojection()[0], COLS)
                row_frames = [row_image.crop((x_cuts[col], y_cuts[row],
                                              x_cuts[col + 1], y_cuts[row + 1]))
                              for col in range(COLS)]
                source_boxes = [(x_cuts[col], y_cuts[row], x_cuts[col + 1], y_cuts[row + 1])
                                for col in range(COLS)]
            except ValueError:
                row_frames = component_frames(band)
                source_boxes = [('connected-components', row, col) for col in range(COLS)]
            for col in range(COLS):
                box = source_boxes[col]
                frame = row_frames[col]
                frame, specks = remove_matte_specks(frame)
                mask = frame.getchannel('A').point(lambda v: 255 if v >= 32 else 0)
                bbox = mask.getbbox()
                if bbox is None:
                    raise ValueError(f'{role_id} {direction} {col}: empty frame')
                margins = [bbox[0], bbox[1], frame.width - bbox[2], frame.height - bbox[3]]
                # A one-pixel transparent separator can legitimately leave zero
                # measured margin on either side. The cut itself is transparent;
                # the standardized destination adds the required safety padding.
                extracted.append(frame.crop(bbox))
                raw_data.append({'direction': direction, 'frame': col, 'source_cell': box,
                                 'source_bbox': bbox, 'source_margins': margins,
                                 'isolated_matte_pixels_removed': specks})
        # One common scale across ALL 32 frames: never independently fit frames.
        scale = min(112 / max(f.height for f in extracted), 116 / max(f.width for f in extracted))
        sheet = Image.new('RGBA', (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
        frames = []
        for idx, (frame, data) in enumerate(zip(extracted, raw_data)):
            new_size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
            frame = frame.resize(new_size, Image.Resampling.NEAREST)
            x, y = (CELL - frame.width) // 2, BASELINE - frame.height
            cell = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
            cell.alpha_composite(frame, (x, y))
            sheet.alpha_composite(cell, ((idx % COLS) * CELL, (idx // COLS) * CELL))
            data.update({'packed_bbox': cell.getbbox(), 'sha256': hashlib.sha256(cell.tobytes()).hexdigest(),
                         'foot_band_sha256': hashlib.sha256(cell.crop((0, 88, CELL, CELL)).tobytes()).hexdigest()})
            frames.append(cell)
        dest = ROOT / 'image' / 'role' / role_id / f'{name}_walk_4dir.png'
        sheet.save(dest)
        sprite_frames(dest.with_name(f'{name}_walk_frames.tres'), f'res://image/role/{role_id}/{dest.name}')
        contact_sheet(sheet, qa_dir / f'{name}_frames.png')
        unique = []
        for row in range(ROWS):
            row_data = raw_data[row * COLS:(row + 1) * COLS]
            n = len(set(d['sha256'] for d in row_data))
            feet = len(set(d['foot_band_sha256'] for d in row_data))
            if n < 6 or feet < 6:
                raise ValueError(f'{role_id} {DIRECTIONS[row]}: insufficient distinct walking/foot frames ({n}/{feet})')
            unique.append({'direction': DIRECTIONS[row], 'unique_frames': n, 'unique_foot_bands': feet})
        report['roles'].append({'id': role_id, 'source': selected[role_id],
                               'output': str(dest.relative_to(ROOT)).replace('\\', '/'),
                               'source_size': im.size, 'size': sheet.size, 'mode': sheet.mode,
                               'common_scale': scale, 'frame_count': len(frames),
                               'row_checks': unique, 'frames': raw_data})
        packed.append(frames)
        print(f'{role_id}: {dest.name}, {sheet.size}, RGBA, 32 frames')
    (qa_dir / 'technical_checks.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    previews = []
    for col in range(COLS):
        canvas = Image.new('RGB', (640, 640), (28, 31, 39))
        draw = ImageDraw.Draw(canvas)
        for role_idx, (_, name) in enumerate(ROLES):
            for row, direction in enumerate(DIRECTIONS):
                frame = packed[role_idx][row * COLS + col]
                canvas.paste(frame, (role_idx * 160 + 16, row * 160 + 8), frame)
                draw.text((role_idx * 160 + 10, row * 160 + 140), f'{name} {direction}', fill='white')
        previews.append(canvas)
    previews[0].save(qa_dir / 'walk_cycles.gif', save_all=True, append_images=previews[1:],
                     duration=100, loop=0, disposal=2)
    print('QA: all 128 frames are present, transparent, inside cell boundaries, and distinct.')


if __name__ == '__main__':
    main()
