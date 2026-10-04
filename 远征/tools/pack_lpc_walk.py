"""Pack the official Universal LPC exports into project-sized walk atlases."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
import zipfile
import io
import hashlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'image' / 'role_lpc'
ROLES = [('zs', 'pojun', '破军', 'Spiked'), ('ck', 'chuanyang', '穿杨', 'High ponytail'),
         ('fs', 'shuangyu', '霜语', 'Long'), ('fz', 'chenxing', '晨星', 'Long')]
DIRS = ['down', 'left', 'right', 'up']
SOURCE_ROWS = [2, 1, 3, 0]
review = OUT / 'review'
review.mkdir(exist_ok=True)
checks = []
packed = []
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 20)

for role, slug, name, expected_hair in ROLES:
    folder = OUT / role
    candidates = sorted(folder.glob('lpc*animations*.zip'), key=lambda p: p.stat().st_mtime)
    if not candidates:
        raise RuntimeError(f'Missing actual generator export: {role}')
    with zipfile.ZipFile(candidates[-1]) as z:
        config = json.loads(z.read('character.json'))
        assert config['selections']['hair']['name'].startswith(expected_hair), role
        (folder / 'character.json').write_bytes(z.read('character.json'))
        (folder / 'credits.txt').write_bytes(z.read('credits/credits.txt'))
        (folder / 'credits.csv').write_bytes(z.read('credits/credits.csv'))
        (folder / 'source-walk.png').write_bytes(z.read('standard/walk.png'))
        src = Image.open(io.BytesIO(z.read('standard/walk.png'))).convert('RGBA')
    assert src.height == 256 and src.width >= 576, src.size
    atlas = Image.new('RGBA', (1152, 512))
    hashes = []
    for row, source_row in enumerate(SOURCE_ROWS):
        for col in range(9):
            tile = src.crop((col * 64, source_row * 64, (col + 1) * 64, (source_row + 1) * 64))
            assert tile.getbbox() is not None, (role, row, col)
            atlas.paste(tile.resize((128, 128), Image.Resampling.NEAREST), (col * 128, row * 128))
            if col:
                hashes.append(hashlib.sha256(tile.tobytes()).hexdigest())
        assert len(set(hashes[-8:])) >= 6, (role, row, 'insufficient distinct walk poses')
    png = folder / f'{slug}_walk_4dir.png'
    atlas.save(png)
    lines = ['[gd_resource type="SpriteFrames" load_steps=38 format=3]', '',
             f'[ext_resource type="Texture2D" path="res://image/role_lpc/{role}/{png.name}" id="1"]', '']
    for row in range(4):
        for col in range(9):
            lines += [f'[sub_resource type="AtlasTexture" id="Atlas_{row}_{col}"]',
                      'atlas = ExtResource("1")', f'region = Rect2({col*128}, {row*128}, 128, 128)',
                      'filter_clip = true', '']
    lines += ['[resource]', 'animations = [']
    anims=[]
    for row,direction in enumerate(DIRS):
        for kind,cols,speed in [('walk',range(1,9),12.0),('idle',[0],1.0)]:
            frames=', '.join('{"duration": 1.0, "texture": SubResource("Atlas_%d_%d")}'%(row,col) for col in cols)
            anims.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s_%s",\n"speed": %.1f\n}'%(frames,kind,direction,speed))
    lines += [',\n'.join(anims),']']
    (folder / f'{slug}_walk_frames.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    checks.append({'role':role,'name':name,'size':list(atlas.size),'walk_frames':32,'idle_frames':4,
                   'unique_walk_poses':len(set(hashes)), 'generator_url':config['url'],
                   'sha256':hashlib.sha256(png.read_bytes()).hexdigest()})
    packed.append(atlas)

frames=[]
for phase in range(8):
    card=Image.new('RGB',(760,730),'#19232e')
    draw=ImageDraw.Draw(card)
    draw.text((24,16),'四位主角 · Universal LPC 行走试用',font=font,fill='#eef1e8')
    draw.text((24,47),'每方向 8 帧 / 原生 64px 放大 2 倍 / 最近邻像素显示',font=font,fill='#a6b2bb')
    for i,(_,_,name,_) in enumerate(ROLES):
        x=100+i*162
        draw.text((x+25,91),name,font=font,fill='#e1c796')
        for row,direction in enumerate(['朝下','朝左','朝右','朝上']):
            y=128+row*142
            if i==0: draw.text((15,y+48),direction,font=font,fill='#a6b2bb')
            draw.rounded_rectangle((x-1,y-1,x+129,y+129),8,fill='#293642',outline='#3c4c58')
            tile=packed[i].crop(((phase+1)*128,row*128,(phase+2)*128,(row+1)*128))
            card.paste(tile,(x,y),tile)
    frames.append(card)
frames[0].save(review/'four_roles.png')
frames[0].save(review/'four_roles.gif',save_all=True,append_images=frames[1:],duration=85,loop=0)
(OUT/'technical_checks.json').write_text(json.dumps(checks,indent=2,ensure_ascii=False),encoding='utf-8')
print('LPC_PACK_OK: 4 roles, 128 walk frames, 16 idle poses, transparent atlases and credits retained.')
