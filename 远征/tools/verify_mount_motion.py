"""Read-only QA of actual moving renders, with cropped review contact sheets."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
folder = root / 'shots/body_mount_motion_20261004'
rows = json.loads((root / 'tools/_logs/mount_motion_qa.json').read_text(encoding='utf-8'))
assert len(rows) == 64 and len({r['image'] for r in rows}) == 64
for row in rows:
    assert set(row['frames']) == {0, 1, 2} and all(row[k] for k in ['moving', 'rider_visible', 'mount_visible'])
for mount in ['horse', 'bear']:
    for height in [800, 1067]:
        sheet = Image.new('RGB', (800, 800), '#192426')
        for role_index, role in enumerate(['zs', 'ck', 'fs', 'fz']):
            for direction_index, direction in enumerate(['down', 'left', 'right', 'up']):
                row = next(r for r in rows if r['image'] == f'{mount}_{role}_{direction}_{height}.png')
                x, y = row['foot']
                with Image.open(folder / row['image']) as source:
                    assert source.size == (480, height)
                    crop = source.crop((int(x)-100, int(y)-160, int(x)+100, int(y)+20)).convert('RGB')
                sheet.paste(crop, (direction_index*200, role_index*200+20))
                ImageDraw.Draw(sheet).text((direction_index*200+8, role_index*200+3), f'{role} {direction}', fill='white')
        sheet.save(folder / f'matrix_{mount}_{height}.jpg', quality=95)
print('MOUNT_MOTION_QA_OK 64 moving renders, three frames each')
