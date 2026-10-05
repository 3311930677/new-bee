"""Install only the Pojun trial and its reviewable original backup."""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
GAME=ROOT/'远征'
DEST=GAME/'image/role/zs'
TRIAL=GAME/'image/role_pixel_studio/zs'
BACK=TRIAL/'original'
BACK.mkdir(parents=True,exist_ok=True)
im=Image.open(OUT/'pojun_walk_4dir.png')
assert im.size==(1024,512) and im.mode=='RGBA'
checks=json.loads((OUT/'checks.json').read_text(encoding='utf-8'))
assert checks['frame_count_per_direction']==8
assert all(v['unique_frames']==8 for v in checks['directions'].values())
original_png=OUT/'backup/pojun_walk_4dir.original.png'
original_frames=OUT/'backup/pojun_walk_frames.original.tres'
shutil.copy2(original_png,BACK/'pojun_walk_4dir.png')
old=original_frames.read_text(encoding='utf-8')
old=old.replace('res://image/role/zs/pojun_walk_4dir.png','res://image/role_pixel_studio/zs/original/pojun_walk_4dir.png')
(BACK/'pojun_walk_frames.tres').write_text(old,encoding='utf-8')
for name in ['pojun_walk_4dir.png','pojun_walk_frames.tres']:
    shutil.copy2(OUT/name,DEST/name)
    shutil.copy2(OUT/name,TRIAL/name)
for name in ['four_directions.gif','four_directions.png','checks.json']:
    shutil.copy2(OUT/name,TRIAL/name)
(TRIAL/'review').mkdir(exist_ok=True)
(TRIAL/'install.json').write_text(json.dumps({'source_backup':str(OUT/'backup'),
    'installed_png_sha256':hashlib.sha256((DEST/'pojun_walk_4dir.png').read_bytes()).hexdigest(),
    'original_png_sha256':hashlib.sha256(original_png.read_bytes()).hexdigest(),
    'changed_resources':['res://image/role/zs/pojun_walk_4dir.png','res://image/role/zs/pojun_walk_frames.tres'],
    'rows':['down','left','right','up'],'frames_per_direction':8},ensure_ascii=False,indent=2),encoding='utf-8')
print('Installed four-direction Pojun walk and original comparison backup.')
