"""Original 32px illustrated navigation icons and quiet background variants.
Regenerate with Python/Pillow + the local Pixel Art Studio (no generated raster).
"""
from pathlib import Path
import sys, json
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/pixel-art-studio/scripts'))
from pixelstudio import Sprite
OUT = ROOT / '远征/assets/ui/pixel_icons'
OUT.mkdir(parents=True, exist_ok=True)
HERE = Path(__file__).parent
DARK='#262739'; EDGE='#51424b'; GOLD='#d49b54'; LIGHT='#f7df9c'
BLUE='#66a9be'; PALE='#b9dcd2'; RED='#b75354'; GREEN='#70a36b'; PURPLE='#a783ba'

def icon(key):
    s=Sprite(32,32)
    r=s.rect; p=s.polygon; l=s.line; e=s.ellipse
    if key=='world':
        p([(3,9),(11,5),(21,8),(28,4),(28,24),(21,28),(11,25),(3,28)],DARK)
        p([(4,10),(10,7),(10,23),(4,25)],GOLD)
        p([(12,7),(20,10),(20,25),(12,23)],LIGHT)
        p([(22,10),(26,7),(26,23),(22,25)],PALE)
        l(7,14,7,20,EDGE); l(14,13,18,17,GREEN); l(18,17,15,21,GREEN)
        r(23,15,25,17,BLUE)
    elif key in ('swords','hammer','shield'):
        if key=='swords':
            p([(4,3),(9,5),(25,22),(23,25),(6,9)],DARK)
            p([(5,4),(8,6),(22,21),(21,23),(7,8)],PALE)
            l(8,7,23,22,BLUE); l(19,26,26,19,GOLD); l(24,25,28,29,EDGE)
            p([(28,3),(23,5),(7,22),(9,25),(26,9)],DARK)
            p([(27,4),(24,6),(10,21),(11,23),(25,8)],LIGHT)
            l(11,26,5,20,GOLD); l(7,25,3,29,EDGE)
        elif key=='hammer':
            p([(7,3),(18,3),(27,11),(24,16),(14,11),(10,8),(5,10)],DARK)
            p([(9,4),(17,4),(25,11),(23,13),(13,8),(7,8)],BLUE)
            l(10,5,17,5,PALE)
            p([(15,11),(19,14),(10,29),(6,27)],DARK)
            p([(16,13),(17,15),(9,27),(8,26)],GOLD)
        else:
            p([(5,6),(16,2),(27,6),(26,20),(21,27),(16,30),(8,25),(5,19)],DARK)
            p([(7,7),(16,4),(25,7),(24,19),(20,25),(16,28),(10,23),(7,18)],GOLD)
            p([(10,9),(16,7),(22,9),(21,18),(16,24),(11,19)],BLUE)
            l(16,9,16,20,PALE); l(12,14,20,14,PALE)
    elif key=='book':
        r(5,4,26,27,DARK); r(7,4,26,25,EDGE); r(8,3,25,23,PURPLE)
        r(9,3,11,23,GOLD); r(12,5,23,21,RED)
        r(12,24,26,25,LIGHT); r(13,8,21,9,LIGHT)
        p([(16,12),(19,15),(16,19),(13,15)],GOLD)
        l(5,8,5,27,GOLD); r(22,22,24,29,RED)
    elif key=='bag':
        r(11,3,20,10,DARK); r(13,5,18,8,GOLD)
        p([(8,8),(24,8),(27,12),(26,28),(6,28),(5,12)],DARK)
        r(7,10,24,26,EDGE); r(8,11,23,19,GOLD); r(8,21,23,25,RED)
        r(14,16,18,21,DARK); r(15,17,17,19,LIGHT)
        l(9,24,21,24,GOLD); r(6,14,8,23,RED); r(23,14,25,23,RED)
    elif key=='growth':
        p([(15,11),(17,11),(18,26),(14,26)],DARK); r(15,12,16,25,GREEN)
        p([(15,17),(6,15),(3,9),(3,5),(10,5),(15,10)],DARK)
        p([(13,14),(7,12),(5,7),(10,7),(13,10)],GREEN); l(6,7,13,13,PALE)
        p([(17,12),(21,5),(28,3),(28,10),(23,15),(17,16)],DARK)
        p([(19,12),(22,7),(26,5),(26,10),(22,13)],GREEN)
        l(19,13,25,7,LIGHT); e(6,24,25,29,EDGE); e(8,24,23,27,GOLD)
    elif key in ('gem','summon','spark'):
        p([(16,2),(25,11),(24,21),(16,29),(7,21),(6,11)],DARK)
        p([(16,4),(23,12),(22,20),(16,26),(9,20),(8,12)],PURPLE if key=='summon' else BLUE)
        p([(16,4),(16,17),(8,12)],PALE); p([(16,17),(23,12),(22,20)],BLUE)
        p([(16,17),(22,20),(16,26)],PURPLE); l(16,4,23,12,LIGHT)
        if key=='summon':
            e(2,25,29,30,GOLD,fill=False); r(2,13,3,14,LIGHT); r(28,7,29,8,LIGHT)
    elif key=='exchange':
        p([(3,8),(23,8),(23,4),(30,11),(23,17),(23,13),(3,13)],DARK)
        p([(4,9),(24,9),(24,7),(28,11),(24,14),(24,12),(4,12)],LIGHT)
        p([(29,19),(9,19),(9,15),(2,22),(9,28),(9,24),(29,24)],DARK)
        p([(28,20),(8,20),(8,18),(4,22),(8,25),(8,23),(28,23)],BLUE)
    elif key=='settings':
        p([(12,2),(20,2),(21,7),(25,8),(28,6),(31,12),(27,15),(27,20),(30,23),(26,28),(22,26),(20,30),(12,30),(11,26),(6,27),(2,22),(6,19),(5,14),(2,11),(6,6),(10,8)],DARK)
        e(6,6,25,25,GOLD); e(8,7,23,22,LIGHT); e(11,10,21,20,DARK); e(13,12,19,18,BLUE)
    elif key=='crown':
        p([(3,8),(9,13),(16,3),(23,13),(29,8),(26,27),(6,27)],DARK)
        p([(5,10),(10,15),(16,6),(22,15),(27,10),(25,23),(7,23)],GOLD)
        l(8,23,24,23,LIGHT); r(8,25,24,26,GOLD)
        p([(16,12),(19,16),(16,20),(13,16)],RED); r(15,14,16,16,LIGHT)
    elif key=='paw':
        e(4,4,10,12,DARK); e(12,1,19,10,DARK); e(22,5,28,13,DARK)
        e(5,5,9,10,GOLD); e(13,2,18,8,LIGHT); e(23,6,27,11,GOLD)
        p([(9,15),(15,11),(20,13),(27,22),(25,28),(19,29),(15,26),(9,28),(4,24)],DARK)
        p([(10,16),(15,13),(19,15),(25,22),(23,26),(18,26),(15,24),(9,26),(6,23)],GOLD)
        p([(10,18),(15,15),(19,17),(20,21),(13,22)],LIGHT)
    elif key=='mount':
        p([(9,28),(7,20),(11,10),(9,3),(14,7),(21,4),(23,12),(28,16),(25,21),(21,20),(19,28)],DARK)
        p([(10,26),(9,20),(14,9),(19,7),(21,13),(25,16),(24,18),(18,15),(16,26)],GOLD)
        p([(12,9),(10,5),(15,8),(21,5),(20,8)],RED); r(18,11,19,12,DARK)
        l(10,22,17,24,RED); r(9,27,20,29,EDGE)
    elif key in ('coin','save','food','sound','help','person','door'):
        if key=='coin':
            e(5,2,26,29,DARK); e(6,3,25,27,GOLD); e(8,4,23,24,LIGHT); e(10,7,21,23,GOLD)
            r(14,10,17,18,EDGE); r(13,13,19,15,EDGE); l(8,7,10,5,LIGHT)
        elif key=='save':
            r(4,3,27,28,DARK); r(6,4,25,26,BLUE); r(9,4,23,12,LIGHT); r(19,5,21,10,EDGE)
            r(8,16,23,25,PALE); l(10,19,20,19,EDGE); l(10,22,20,22,EDGE)
        elif key=='food':
            e(3,8,29,27,DARK); e(4,8,28,24,GOLD); e(6,10,26,21,LIGHT)
            l(9,12,11,17,EDGE); l(16,11,18,17,EDGE); l(23,12,24,16,EDGE)
        elif key=='door':
            p([(6,28),(6,9),(11,3),(23,3),(27,9),(27,28)],DARK)
            r(8,10,25,27,GOLD); p([(9,10),(13,5),(21,5),(24,10)],GOLD)
            r(11,11,22,27,EDGE); r(12,12,20,26,BLUE); r(18,20,20,21,LIGHT)
        elif key=='sound':
            p([(3,12),(10,12),(19,5),(19,27),(10,20),(3,20)],DARK)
            p([(5,14),(11,14),(17,9),(17,23),(11,18),(5,18)],GOLD)
            l(23,10,26,13,PALE); l(26,13,26,20,PALE); l(26,20,23,23,PALE)
        elif key=='person':
            e(10,3,21,14,DARK); e(12,4,20,11,LIGHT)
            p([(12,14),(21,14),(26,20),(27,28),(5,28),(6,20)],DARK)
            p([(12,16),(20,16),(24,22),(24,26),(8,26),(9,21)],BLUE)
        else:
            e(3,3,28,28,DARK); e(5,4,26,25,BLUE); e(9,8,22,14,LIGHT)
            r(8,12,13,16,BLUE); p([(18,12),(22,12),(19,19),(14,19),(14,16)],LIGHT)
            r(14,22,17,24,LIGHT)
    else:
        # Directional UI controls keep a very clear silhouette.
        p([(7,16),(18,5),(21,8),(13,16),(21,24),(18,27)],DARK)
        p([(9,16),(18,7),(19,8),(11,16),(19,24),(18,25)],LIGHT)
    # Pass 2: tiny material highlights; distinguish spark from crystal.
    if key=='spark':
        s.clear()
        p([(16,2),(19,12),(29,16),(19,19),(16,29),(12,19),(2,16),(12,12)],DARK)
        p([(16,4),(18,13),(27,16),(18,18),(16,27),(13,18),(4,16),(13,13)],LIGHT)
        p([(16,12),(20,16),(16,20),(12,16)],GOLD)
    if key=='bag':
        l(10,12,21,12,LIGHT); r(10,22,12,22,GOLD); r(20,22,22,22,GOLD)
    if key=='book':
        l(12,6,22,6,LIGHT); l(8,5,8,21,LIGHT); r(13,25,24,25,GOLD)
    if key=='settings':
        for x,y in [(12,3),(22,7),(26,16),(21,25),(8,23),(4,12)]: r(x,y,x+2,y+2,GOLD)
    if key=='mount': l(14,9,17,8,LIGHT); l(11,25,16,25,LIGHT)
    s.harden_alpha()
    s.save_png(OUT/(key+'.png'))
    return s.composite(1)

KEYS=['world','swords','book','growth','bag','exchange','summon','settings','paw','mount','crown','hammer','shield','gem','spark','coin','save','food','sound','help','person','door','back','forward']
sheet=Image.new('RGBA',(6*128,4*148),'#242b38')
draw=ImageDraw.Draw(sheet)
for i,key in enumerate(KEYS):
    im=icon(key)
    if key=='forward':
        im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT); im.save(OUT/(key+'.png'))
    x=(i%6)*128; y=(i//6)*148
    sheet.alpha_composite(im.resize((128,128),Image.Resampling.NEAREST),(x,y))
    draw.text((x+5,y+129),key,fill='#f7df9c')
sheet.convert('RGB').save(HERE/'preview.png')

# Only scenery; do not touch live character or walk assets.
bgout=ROOT/'远征/image/background/refined'
bgout.mkdir(exist_ok=True)
reports=[]
for filename in ['home.png','enter.png','courtyard_visual_v2.png']:
    source=ROOT/'远征/image/background'/filename
    original=Image.open(source).convert('RGB')
    # A median pass removes single-pixel salt while retaining hard pixel clusters.
    target=original.resize((240,400),Image.Resampling.BOX).filter(ImageFilter.MedianFilter(3))
    target=target.quantize(colors=64,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGB')
    temp=HERE/('quiet_'+filename); target.save(temp)
    sprite=Sprite.from_png(temp,scale=1)
    sprite.dedupe_colors(tol=5)
    sprite.despeckle(min_cluster=2)
    sprite.save_png(bgout/filename,scale=2)
    reports.append({'source':str(source),'output':str(bgout/filename),'grid':'240x400','max_colors':64,'filter':'median3 + PixelStudio dedupe5/despeckle2','original_size':original.size})
(HERE/'assets.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
print('Created',len(KEYS),'original pixel icons and',len(reports),'scenery variants')
