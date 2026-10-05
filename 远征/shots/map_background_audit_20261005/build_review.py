from pathlib import Path
import json
import hashlib
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
data = json.loads((ROOT / 'data/main_world_maps.json').read_text(encoding='utf-8'))
theme_data = json.loads((ROOT / 'data/maps.json').read_text(encoding='utf-8'))
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 19)
small = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 13)
names = {k: v['name'] for k, v in data['maps'].items()}
names.update({'exp_' + k: v['name'] for k, v in theme_data['themes'].items()})
names.update({'rift_mine_vault_rooms': '矿井 · 机关房开启', 'rift_mine_vault_rescued': '矿井 · 通风与获救',
              'tidal_gate_sealed': '水闸 · 积水封锁', 'tidal_gate_bridge': '水闸 · 栈桥开放',
              'tidal_gate_cargo': '水闸 · 暗渠开放', 'stele_core_lit': '碑心 · 符阵点亮',
              'rift_mine_vault_layer_probe': '仅独立预览调整层级'})
ids = list(data['maps'])

def sheet(keys, view, filename, title, width=300, height=390, cols=3):
    rows = (len(keys) + cols - 1) // cols
    canvas = Image.new('RGB', (cols * (width + 16) + 16, rows * (height + 52) + 64), '#18262e')
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 14), title, font=font, fill='#f2dfb4')
    for i, key in enumerate(keys):
        x, y = 16 + i % cols * (width + 16), 52 + i // cols * (height + 52)
        image = Image.open(OUT / view / (key + '.png')).convert('RGB')
        image.thumbnail((width, height), Image.Resampling.LANCZOS)
        canvas.paste(image, (x + (width - image.width) // 2, y))
        draw.text((x, y + height + 3), names[key], font=font, fill='#f0e4c8')
        draw.text((x, y + height + 27), key, font=small, fill='#99b6bf')
    canvas.save(OUT / filename)

for page in range(3):
    group = ids[page * 6: page * 6 + 6]
    sheet(group, 'overview', f'world_overview_{page+1}.png', f'当前主世界地图 {page+1}/3 · 全图原生渲染 · 缩小用于比较')
    sheet(group, 'center_800', f'world_phone_{page+1}.png', f'当前主世界地图 {page+1}/3 · 480×800 中部视角', 240, 400)
themes = ['exp_' + k for k in theme_data['theme_order']]
sheet(themes, 'center_800', 'expedition_phone.png', '当前历练八地貌 · 480×800 中部视角 · 固定种子 7', 240, 400, 4)
sheet(['broken_slope', 'old_salt_road', 'tideflat', 'frost_boardwalk', 'rift_mine_vault', 'stele_core'],
      'center_1067', 'representative_long_phone.png', '代表地图 · 480×1067 长屏中部视角', 240, 534)

sources = []
for key, cfg in data['maps'].items():
    paths = []
    if cfg.get('background'):
        paths.append(cfg['background'])
    else:
        paths.extend(theme_data['asset_dir'] + '/' + t + '.png' for t in theme_data['themes'][cfg['theme']]['tiles'])
    info = []
    for ref in paths:
        base = ROOT / ref.removeprefix('res://')
        refined = base.parent / 'refined' / base.name
        actual = refined if refined.exists() else base
        img = Image.open(actual)
        info.append({'configured': ref, 'actual': str(actual.relative_to(ROOT)), 'size': img.size})
    sources.append({'id': key, 'name': cfg['name'], 'background_sources': info,
                    'theme': cfg['theme'], 'tint': cfg.get('tint'),
                    'authored_ground': cfg.get('authored_ground', False),
                    'spawn': cfg['spawn'], 'exits': cfg['exits']})

assets = []
for key in theme_data['theme_order']:
    canvas = Image.new('RGB', (720, 264), '#263841')
    draw = ImageDraw.Draw(canvas)
    draw.text((8, 4), theme_data['themes'][key]['name'], font=font, fill='white')
    for i, tile in enumerate(theme_data['themes'][key]['tiles']):
        p = ROOT / 'image/map_proc/refined' / (tile + '.png')
        if not p.exists(): p = ROOT / 'image/map_proc' / (tile + '.png')
        tile_image = Image.open(p).convert('RGB')
        dims = tile_image.size
        tile_image = tile_image.resize((192, 192), Image.Resampling.NEAREST)
        canvas.paste(tile_image, (i * 240 + 8, 34))
        draw.text((i * 240 + 8, 234), f'{tile} · {dims[0]}×{dims[1]}', font=small, fill='white')
    assets.append(canvas)
gallery = Image.new('RGB', (720, len(assets) * 264), '#263841')
for i, img in enumerate(assets): gallery.paste(img, (0, i * 264))
gallery.save(OUT / 'terrain_source_gallery.png')
fingerprints = {}
for rel in ['data/maps.json', 'data/main_world_maps.json', 'src/explore/MapScene.gd',
            'src/explore/ThirdActGround.gd', 'src/explore/FourthActGround.gd']:
    fingerprints[rel] = hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()
(OUT / 'source_manifest.json').write_text(json.dumps({'maps': sources, 'source_sha256': fingerprints}, ensure_ascii=False, indent=2), encoding='utf-8')
records = json.loads((OUT / 'capture_index.json').read_text(encoding='utf-8'))
assert len(records) == 96
for row in records:
    path = ROOT / row['path'].removeprefix('res://')
    assert Image.open(path).size == tuple(row['size']), row
if (OUT / 'state_capture_index.json').exists():
    states = json.loads((OUT / 'state_capture_index.json').read_text(encoding='utf-8'))
    assert len(states) == 24
    for row in states:
        assert Image.open(ROOT / row['path'].removeprefix('res://')).size == tuple(row['size'])
    sheet(['rift_mine_vault_rooms', 'rift_mine_vault_rescued', 'tidal_gate_sealed',
           'tidal_gate_bridge', 'tidal_gate_cargo', 'stele_core_lit'],
          'overview', 'state_overview.png', '机关状态补查 · 全图原生渲染 · 状态由隔离演示档设置')
    print(f'{len(states)} additional state captures verified.')
if (OUT / 'layer_probe_index.json').exists():
    probe = json.loads((OUT / 'layer_probe_index.json').read_text(encoding='utf-8'))
    assert len(probe) == 4
    for row in probe:
        assert row['mine_ground_present'] and row['mine_ground_z'] == 0
        assert Image.open(ROOT / row['path'].removeprefix('res://')).size == tuple(row['size'])
    sheet(['rift_mine_vault_rooms', 'rift_mine_vault_layer_probe'], 'overview',
          'mine_layer_diagnosis.png', '矿井地表层级诊断 · 左为当前游戏 · 右为独立预览，未应用到游戏', 360, 468, 2)
    print(f'{len(probe)} layer diagnosis captures verified.')
print(f'Review sheets saved; {len(records)} captures verified; {len(sources)} main world maps.')
