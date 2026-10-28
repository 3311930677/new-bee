"""Prepare selected imagegen outputs without changing their subjects or alpha.

Run with the bundled Python. Source images stay ignored by Godot; ready sprites
are cropped to alpha bounds and sampled onto the game's fixed pixel grid.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
import shutil

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT / 'assets/completion_20261024'

def prepare():
    jobs = json.loads((ROOT / 'generation_manifest.json').read_text('utf-8'))['jobs']
    for folder in ['source', 'ready/equipment', 'ready/items', 'ready/home', 'ready/world']:
        (ROOT / folder).mkdir(parents=True, exist_ok=True)
    (ROOT / 'source/.gdignore').touch()
    manifest = {}
    rows = []
    for job in jobs:
        key = job['id']
        src = Path(job['source'])
        copy = ROOT / 'source' / (key + '.png')
        if not copy.exists():
            shutil.copy2(src, copy)
        im = Image.open(copy).convert('RGBA')
        bounds = im.getchannel('A').point(lambda a: 255 if a > 16 else 0).getbbox()
        if not bounds:
            raise ValueError(f'Empty alpha: {key}')
        im = im.crop(bounds)
        if key.startswith('tpl_'):
            group, size = 'equipment', 64
        elif key.startswith('itm_'):
            group, size = 'items', 64
        elif key.startswith('home_'):
            group, size = 'home', 32
        else:
            group, size = 'world', 256 if key == 'rune_dais' else 128
        scale = (size - 4) / max(im.size)
        dims = tuple(max(1, round(v * scale)) for v in im.size)
        sprite = im.resize(dims, Image.Resampling.NEAREST)
        # Icon canvases keep stable gutters; ground props keep their natural aspect.
        if group != 'world':
            canvas = Image.new('RGBA', (size, size))
            canvas.alpha_composite(sprite, ((size - dims[0]) // 2, (size - dims[1]) // 2))
            sprite = canvas
        dest = ROOT / 'ready' / group / (key + '.png')
        sprite.save(dest)
        manifest[key] = {'file': 'res://' + dest.relative_to(PROJECT).as_posix()}
        job['ready'] = dest.relative_to(PROJECT).as_posix()
        job['alpha_bounds'] = list(bounds)
        job['size'] = list(sprite.size)
        rows.append((key, sprite))
    # Existing complete world sprites: use their real regions, not inventory badges.
    for atlas, regions in {
        'image/main_world/art_v2/story_props_atlas.png': {
            'mine_cart': [81,178,334,258], 'brazier': [546,82,239,355],
            'rope_post': [84,946,287,294], 'tide_cargo': [517,1383,302,263],
        },
        'image/main_world/art_v2/props_atlas.png': {
            'vent': [456,933,399,350]},
        'image/main_world/art_v2/return_props_atlas.png': {
            'lantern': [66,22,193,349],
            'letter_prop': [406,160,273,197], 'rune_stone': [424,408,243,314],
            'road_ledger': [27,736,324,310], 'tide_board': [404,745,278,314]},
    }.items():
        for key, rect in regions.items():
            manifest[key] = {'file': 'res://' + atlas, 'rect': rect}
    for key, file in {
        'notice': 'assets/world/reference_complete_20261011/ready/signpost.png',
        'bridge': 'assets/world/reference_complete_20261011/ready/bridge.png',
        'ledger': 'assets/world/reference_complete_20261011/ready/ledger.png',
        'boat': 'image/main_world/tideflat_props/tf_rowboat.png',
        'smoke': 'image/generated_001_100/source/064_deco_bg_mist.png',
    }.items():
        manifest[key] = {'file': 'res://' + file}
    manifest['bridge_planks'] = {'file': 'res://assets/world/reference_complete_20261011/ready/bridge.png', 'rect': [34,72,78,35]}
    (PROJECT / 'data/asset_completion_20261024.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', 'utf-8')
    (ROOT / 'generation_manifest.json').write_text(json.dumps({'mode': 'built-in imagegen', 'jobs': jobs}, ensure_ascii=False, indent=2) + '\n', 'utf-8')
    labels = {
        'tpl_sword_starfall':'陨星破阵重剑','tpl_spear_windpiercer':'朔风贯影长枪',
        'tpl_staff_glacierheart':'凝霜观星法杖','tpl_hammer_dawnlight':'破晓圣辉战锤',
        'tpl_armor_expedition':'远征戍卫重铠','tpl_acc_archery_ring':'穿杨听风扳指',
        'itm_frost_letter':'霜关来信','itm_mine_record':'矿道记录','itm_gate_stamp':'关印',
        'itm_frost_reply':'霜关回信','itm_veil_seal':'冰幕封印','itm_frost_nameplate':'矿工名牌',
        'itm_frost_parcel':'驿路包裹','home_coin':'金币','home_expedition':'远征币',
        'home_soul':'魂晶','home_honor':'荣誉','home_bag':'背包','home_food':'小聚',
        'rune_dais':'铭文石台','rune_channel':'导音刻槽','salt_trace':'盐晶与水痕',
        'beast_tracks':'兽迹','boot_tracks':'人类足迹','ground_fissure':'石缝与冰裂',
        'ground_scuff':'树根擦痕','work_helmet':'矿工帽','mine_wheel':'通风手轮',
        'turtle_tracks':'岩龟足迹','rubbing_page':'岩纹拓片','shallow_flood':'浅水与岸线',
        'supply_sack':'补给袋','cargo_tag':'货签',
    }
    groups = [('装备 · 6 张',lambda k:k.startswith('tpl_')),
              ('任务物品 · 7 张，覆盖 9 个物品 ID',lambda k:k.startswith('itm_')),
              ('首页图标 · 6 张',lambda k:k.startswith('home_')),
              ('地图与机关 · 14 张',lambda k:not k.startswith(('tpl_','itm_','home_')))]
    cols, cell_w, cell_h = 6, 200, 155
    height = sum(44 + ((sum(1 for key,_ in rows if match(key))+5)//6)*cell_h for _,match in groups)
    sheet = Image.new('RGB', (cols * cell_w, height), '#232b30')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 16)
    heading = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22)
    top = 0
    for title, match in groups:
        draw.text((18,top+8),title,font=heading,fill='#ebd3a1')
        top += 44
        selected = [(key,sprite) for key,sprite in rows if match(key)]
        for i,(key,sprite) in enumerate(selected):
            factor = min(150/sprite.width,110/sprite.height)
            sprite = sprite.resize((max(1,round(sprite.width*factor)),max(1,round(sprite.height*factor))),Image.Resampling.NEAREST)
            x,y = i%cols*cell_w,top+i//cols*cell_h
            sheet.paste(sprite,(x+(cell_w-sprite.width)//2,y+(118-sprite.height)//2),sprite)
            label = labels.get(key,key)
            length = draw.textlength(label,font=font)
            draw.text((x+(cell_w-length)//2,y+124),label,font=font,fill='#e8d7b4')
        top += ((len(selected)+5)//6)*cell_h
    report = PROJECT.parent / 'reports/asset_completion_20261024'
    report.mkdir(parents=True, exist_ok=True)
    sheet.save(report / 'asset_preview.png')
    print(f'Prepared {len(jobs)} generated assets, {len(manifest)} texture keys')

if __name__ == '__main__':
    prepare()
