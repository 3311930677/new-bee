from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

# Proof sheets only: screenshots are captured unchanged from the actual game renderer.
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
BEFORE = ROOT / 'shots/refined_ground_20261006'
data = json.loads((ROOT / 'data/main_world_maps.json').read_text(encoding='utf-8'))
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22)
small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 16)
names = {mid: cfg['name'] for mid, cfg in data['maps'].items()}


def sheet(entries, filename, title, cols=3, width=320, height=534):
    rows = (len(entries) + cols - 1) // cols
    canvas = Image.new('RGB', (cols * (width + 16) + 16, rows * (height + 38) + 60), '#202c32')
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 13), title, font=font, fill='#e5d9b3')
    for i, (path, caption) in enumerate(entries):
        x, y = 16 + i % cols * (width + 16), 56 + i // cols * (height + 38)
        image = Image.open(path).convert('RGB')
        image.thumbnail((width, height), Image.Resampling.LANCZOS)
        canvas.paste(image, (x + (width - image.width) // 2, y))
        draw.text((x, y + height + 5), caption, font=small, fill='#e4e8de')
    canvas.save(OUT / filename)


sheet([(OUT / 'spawn_800' / f'{mid}.png', names[mid])
       for mid in ['maple_road', 'broken_slope', 'frost_boardwalk']],
      'soft_edges_samples.png', '路沿细化 · 游戏实机')
sheet([(folder / 'spawn_800' / f'{mid}.png', names[mid] + ' · ' + label)
       for mid in ['maple_road', 'broken_slope']
       for folder, label in [(BEFORE, '上一版'), (OUT, '本次修改')]],
      'before_after.png', '路沿与纹理细化对照', cols=4, width=240, height=400)
ids = list(data['maps'])
for page in range(3):
    sheet([(OUT / 'overview' / f'{mid}.png', names[mid]) for mid in ids[page * 6:page * 6 + 6]],
          f'map_overviews_{page + 1}.png', f'主世界路线 · {page + 1}/3', width=240, height=312)
themes = json.loads((ROOT / 'data/maps.json').read_text(encoding='utf-8'))['themes']
sheet([(OUT / 'center_800' / f'exp_{theme}.png', cfg['name']) for theme, cfg in themes.items()],
      'expedition_materials.png', '历练路线 · 八种地貌', cols=4, width=240, height=400)
records = json.loads((OUT / 'capture_index.json').read_text(encoding='utf-8'))
assert len(records) == 96
for record in records:
    image = Image.open(ROOT / record['path'].removeprefix('res://'))
    assert list(image.size) == record['size'], record['path']
print('SOFT_EDGES_REVIEW_OK 96 native captures; 6 proof sheets')
