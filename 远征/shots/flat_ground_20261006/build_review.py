from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
BEFORE = ROOT / 'shots/map_background_audit_20261005'
data = json.loads((ROOT / 'data/main_world_maps.json').read_text(encoding='utf-8'))
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22)
small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 16)
names = {k: v['name'] for k, v in data['maps'].items()}

def sheet(entries, name, title, cols=3, width=280, height=467):
    rows = (len(entries) + cols - 1) // cols
    canvas = Image.new('RGB', (cols*(width+16)+16, rows*(height+44)+62), '#202c32')
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 14), title, font=font, fill='#e5d9b3')
    for i, (path, caption) in enumerate(entries):
        x, y = 16 + i % cols*(width+16), 58+i//cols*(height+44)
        shot = Image.open(path).convert('RGB')
        shot.thumbnail((width, height), Image.Resampling.LANCZOS)
        canvas.paste(shot, (x+(width-shot.width)//2, y))
        draw.text((x, y+height+6), caption, font=small, fill='#e4e8de')
    canvas.save(OUT/name)

sheet([(OUT/'spawn_800'/f'{m}.png', names[m]) for m in ['maple_road','broken_slope','frost_boardwalk']],
      'flat_ground_samples.png', '平面地表实机样例 · 浅色路线 / 深色底地')
sheet([(folder/'spawn_800'/f'{m}.png', names[m]+' · '+label)
       for m in ['maple_road','broken_slope'] for folder,label in [(BEFORE,'修改前'),(OUT,'修改后')]],
      'before_after.png', '枫林古道与断碑坡 · 相同出生点对照', cols=4, width=240, height=400)
ids = list(data['maps'])
for page in range(3):
    sheet([(OUT/'overview'/f'{m}.png', names[m]) for m in ids[page*6:page*6+6]],
          f'map_overviews_{page+1}.png', f'主世界平面地表 · {page+1}/3', height=364)
themes = json.loads((ROOT/'data/maps.json').read_text(encoding='utf-8'))['themes']
sheet([(OUT/'center_800'/f'exp_{t}.png', cfg['name']) for t,cfg in themes.items()],
      'expedition_materials.png', '历练八种配色与材质 · 固定种子 7', cols=4, width=240, height=400)
state_names = {'rift_mine_vault_rooms':'矿井 · 机关开启', 'rift_mine_vault_rescued':'矿井 · 通风获救',
               'tidal_gate_sealed':'水闸 · 积水封锁', 'tidal_gate_bridge':'水闸 · 栈桥开放',
               'tidal_gate_cargo':'水闸 · 暗渠开放', 'stele_core_lit':'碑心 · 三声点亮'}
sheet([(OUT/'overview'/f'{m}.png', label) for m,label in state_names.items()],
      'mechanism_states.png', '平面地表上的机关状态', height=364)
records = json.loads((OUT/'capture_index.json').read_text(encoding='utf-8'))
states = json.loads((OUT/'state_capture_index.json').read_text(encoding='utf-8'))
assert len(records) == 96 and len(states) == 24
for r in records + states:
    image = Image.open(ROOT/r['path'].removeprefix('res://'))
    assert list(image.size) == r['size'], r['path']
assert all(r['mine_ground_z'] == -9 for r in states if r['id'].startswith('rift_mine'))
print('FLAT_REVIEW_OK 120 native captures; 8 comparison sheets')
