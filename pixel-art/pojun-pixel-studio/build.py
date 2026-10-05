"""A reference-preserving, articulated walk test using Pixel Art Studio.

Only the lower-body anatomy is restaged. The source face, hair, armor, hands,
and sword remain image layers; no diffusion model or whole-image walk preset.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
import sys

from PIL import Image, ImageDraw, ImageChops, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
TOOL = ROOT / 'tools/pixel-art-studio'
sys.path.insert(0, str(TOOL / 'scripts'))
from pixelstudio import Sprite

parser = argparse.ArgumentParser()
parser.add_argument('--pass-number', type=int, default=3)
args = parser.parse_args()
VERSION = args.pass_number
WORK = OUT / f'review/pass_{VERSION}'
WORK.mkdir(parents=True, exist_ok=True)
PARTS = WORK / 'parts'
PARTS.mkdir(exist_ok=True)

SOURCE = OUT / 'backup/pojun_walk_4dir.original.png'
if not SOURCE.exists():
    SOURCE = ROOT / '远征/image/role/zs/pojun_walk_4dir.png'
source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
src = Image.open(SOURCE).convert('RGBA').crop((0, 256, 128, 384))
src.save(OUT / 'original_right.png')

# Remove isolated ground residue from the existing input, retaining body pixels.
src_clean = src.copy()
ImageDraw.Draw(src_clean).rectangle((0, 106, 127, 127), fill=(0, 0, 0, 0))

body = src_clean.copy()
body_px = body.load()
cape = Image.new('RGBA', (128, 128))
cape_px = cape.load()
cape_region = Image.new('L', (128, 128))
ImageDraw.Draw(cape_region).polygon([(53,44),(61,59),(54,75),(45,82),(33,85),(26,78),(18,89),(8,76),(14,64),(29,56),(46,50)],fill=255)
for y in range(128):
    for x in range(128):
        r, g, b, a = src_clean.getpixel((x, y))
        # Behind the shoulder, the original cape is a separate follow-through layer.
        is_cape = a > 0 and cape_region.getpixel((x,y)) > 0 and r > g * 1.4 and r > b * 1.5 and r > 25
        if is_cape:
            cape_px[x, y] = (r, g, b, a)
            body_px[x, y] = (0, 0, 0, 0)
        if 49 <= x <= 79 and 78 <= y <= 105 and not is_cape:
            body_px[x, y] = (0, 0, 0, 0)
body.save(PARTS / 'body.png')
cape.save(PARTS / 'cape.png')

def part_mask(points, filename):
    mask = Image.new('L', (128, 128))
    ImageDraw.Draw(mask).polygon(points, fill=255)
    out = src_clean.copy()
    out.putalpha(ImageChops.multiply(src_clean.getchannel('A'), mask))
    out.save(PARTS / filename)
    return out

# Preserve the metal kneecap and boot's actual pixel shading from the reference.
knee_art = part_mask([(66, 76), (71, 76), (75, 80), (74, 86), (70, 88), (64, 86), (64, 80)], 'knee.png')
boot_art = part_mask([(61, 92), (66, 91), (71, 93), (76, 96), (78, 99), (76, 101), (59, 101), (57, 98), (58, 94)], 'boot.png')

DX, DY = -3, 19
GROUND = 120
N = 8
DURATION = 110
# Contact -> planted foot moves rearward -> toe-off -> swing -> next contact.
ankles = [(73, 94), (69, 94), (64, 94), (59, 94), (54, 94), (55, 90), (63, 88), (71, 90)]
bob = [0, 1, 0, -1, 0, 1, 0, -1]

def tint(im, far=False):
    if not far:
        return im
    out = im.copy()
    p = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = p[x, y]
            if a:
                p[x, y] = (round(r * .62), round(g * .65), round(b * .74), a)
    return out

def joint(hip, ankle, l1=None, l2=None):
    # Short upper legs match the reference's compact armored chibi proportions.
    l1 = (8.5 if VERSION >= 3 else 11.5) if l1 is None else l1
    l2 = (11.5 if VERSION >= 3 else 13) if l2 is None else l2
    vx, vy = ankle[0] - hip[0], ankle[1] - hip[1]
    d = math.hypot(vx, vy)
    d = min(d, l1 + l2 - .2)
    along = (l1*l1 - l2*l2 + d*d) / (2*d)
    height = math.sqrt(max(0, l1*l1 - along*along))
    ux, uy = vx / math.hypot(vx, vy), vy / math.hypot(vx, vy)
    # Knee bends toward the facing direction, +x, including on the swing leg.
    return (round(hip[0] + along * ux + height * uy), round(hip[1] + along * uy - height * ux))

def tube(s, a, b, r1, r2, far, material='steel'):
    vx, vy = b[0] - a[0], b[1] - a[1]
    length = max(.1, math.hypot(vx, vy))
    ux, uy = vx / length, vy / length
    nx, ny = -uy, ux
    pts = [(round(a[0]+nx*r1), round(a[1]+ny*r1)),
           (round(a[0]-nx*r1), round(a[1]-ny*r1)),
           (round(b[0]-nx*r2), round(b[1]-ny*r2)),
           (round(b[0]+nx*r2), round(b[1]+ny*r2))]
    s.polygon(pts, '#17151a' if not far else '#111219')
    mask = Image.new('L', (128,128)); ImageDraw.Draw(mask).polygon(pts,fill=255)
    bx = mask.getbbox()
    if not bx:
        return
    # Texture coordinates use the original armor ramp; shade stays attached to limb.
    for y in range(bx[1], bx[3]):
        for x in range(bx[0], bx[2]):
            if not mask.getpixel((x,y)):
                continue
            px, py = x-a[0], y-a[1]
            v = max(0, min(1, (px*ux+py*uy)/length))
            radius = r1*(1-v)+r2*v
            across = (px*nx+py*ny)/max(1,radius)
            if abs(across) > .82 or v > .97:
                continue
            if VERSION == 1:
                tx = max(56, min(64, round(60+across*4)))
                ty = 84 + round(v*8) if material == 'steel' else 80 + round(v*5)
                c = src_clean.getpixel((tx,ty))
            else:
                # Keep a coherent shin highlight rather than stretching gold trim
                # and silhouette-edge pixels into disconnected texture fragments.
                tx = max(55, min(69, round(62+across*8)))
                c = src_clean.getpixel((tx,89))
                if material == 'cloth':
                    c = (round(c[0]*.78),round(c[1]*.78),round(c[2]*.83),255)
            if far:
                c = (round(c[0]*.62),round(c[1]*.65),round(c[2]*.74),c[3])
            if c[3] > 0:
                s.px(x,y,c)
    # Curved gold edging is a connected cluster, not dithering.
    if material == 'steel':
        t = .80
        cx,cy = a[0]+vx*t,a[1]+vy*t
        radius=r1*(1-t)+r2*t
        gold = '#997021' if far else '#d5a63f'
        s.line(round(cx+nx*radius*.70),round(cy+ny*radius*.70),round(cx-nx*radius*.70),round(cy-ny*radius*.70),gold)

def draw_leg(s, index, far=False):
    phase = (index+4)%N if far else index
    ax, ay = ankles[phase]
    ax += -1 if far else 0
    hip = (60 if far else 64, 78+bob[index])
    ankle = (ax, ay)
    k = joint(hip, ankle)
    hip = (hip[0]+DX,hip[1]+DY)
    knee = (k[0]+DX,k[1]+DY)
    ankle = (ankle[0]+DX,ankle[1]+DY)
    tube(s,hip,knee,4.5 if far else 5.3,4.1 if far else 4.8,far,'cloth')
    tube(s,knee,ankle,4.2 if far else 4.9,3.5 if far else 4.0,far)
    # Small original kneecap, translated onto the new articulated knee position.
    kp = tint(knee_art,far)
    kp_path = PARTS / f'knee_{index}_{int(far)}.png'; kp.save(kp_path)
    s.paste_png(kp_path, knee[0]-69, knee[1]-82)
    bp=tint(boot_art,far)
    if VERSION >= 3:
        roll = [0,0,0,10,16,-16,-8,-10][phase]
        bp = bp.rotate(-roll,resample=Image.Resampling.NEAREST,center=(63,94))
        if phase <= 4:
            # Plant the toe at the established ground line while the heel lifts.
            boot_bottom = bp.getbbox()[3] - 1
            by = GROUND - boot_bottom
        else:
            by = ankle[1]-94
    else:
        by = ankle[1]-94
    bp_path=PARTS / f'boot_{index}_{int(far)}.png';bp.save(bp_path)
    s.paste_png(bp_path,ankle[0]-63,by)
    return {'hip':hip,'knee':knee,'ankle':ankle,'planted':phase<=4,'phase':phase}

sprite = Sprite(128,128,snap=False)
poses=[]
for i in range(N):
    if i:
        sprite.add_frame(copy=False,duration=DURATION)
    sprite.layer('far_leg')
    far=draw_leg(sprite,i,True)
    sprite.layer('cape')
    sprite.paste_png(PARTS/'cape.png',DX,DY+bob[(i-1)%N])
    sprite.layer('near_leg')
    near=draw_leg(sprite,i,False)
    sprite.layer('original_upper_body_and_sword')
    sprite.paste_png(PARTS/'body.png',DX,DY+bob[i])
    poses.append({'index':i,'body_offset':[DX,DY+bob[i]],'near':near,'far':far})

sprite.set_duration(DURATION,frames='all')
sprite.tag('walk_right',1,N)
sprite.save_spritesheet(WORK/'pojun_walk_right_8.png',layout='horizontal',padding=0)
sprite.save_spritesheet(WORK/'pojun_walk_right_8@4x.png',layout='horizontal',padding=0,scale=4)
sprite.save_gif(WORK/'pojun_walk_right.gif',scale=4,bg='#303b4a')
sprite.save_project(WORK/'pojun_walk_right.pxproj.json')
sprite.preview(WORK/'contact.png',scale=3,cols=4,bg='#303b4a')
sprite.save_silhouette(WORK/'silhouette.png')

# One static original and the new walk, in a shared, uncropped comparison preview.
font_path=Path('C:/Windows/Fonts/msyh.ttc')
font=ImageFont.truetype(str(font_path),18) if font_path.exists() else ImageFont.load_default()
static=Image.new('RGBA',(128,128));static.alpha_composite(src_clean,(DX,DY))
compare=[]
for i in range(N):
    panel=Image.new('RGB',(800,445),'#263340')
    d=ImageDraw.Draw(panel)
    d.text((45,15),'原版参考',font=font,fill='#e9eff5')
    d.text((435,15),'Pixel Art Studio · 8 帧行走测试',font=font,fill='#e9eff5')
    for im,x in [(static,45),(sprite.composite(i+1),435)]:
        big=im.resize((384,384),Image.Resampling.NEAREST)
        panel.paste(big,(x-20,50),big)
    d.text((435,415),f'{i+1}/8',font=font,fill='#a9bed0')
    compare.append(panel)
compare[0].save(WORK/'comparison.gif',save_all=True,append_images=compare[1:],duration=DURATION,loop=0,disposal=2)
compare[0].save(WORK/'comparison.png')
source_hash_after=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
checks={'tool':'Gamezxz/pixel-art-studio','pass':VERSION,'source_sha256':source_hash,
        'source_unchanged':source_hash==source_hash_after,'frame_size':[128,128],
        'frame_count':N,'duration_ms':DURATION,'poses':poses,
        'unique_frames':len(set(hashlib.sha256(sprite.composite(i+1).tobytes()).hexdigest() for i in range(N))),
        'bounding_boxes':[sprite.composite(i+1).getbbox() for i in range(N)],
        'method':'original upper-body layers; separately articulated and shaded legs; original knee/boot samples',
        'palette_policy':'Preserve source colors instead of reducing the original game artwork to a new style.'}
(WORK/'checks.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
if VERSION >= 3:
    for name in ['pojun_walk_right_8.png','pojun_walk_right_8.json','pojun_walk_right_8@4x.png',
                 'pojun_walk_right.gif','pojun_walk_right.pxproj.json','comparison.gif',
                 'comparison.png','checks.json']:
        shutil.copy2(WORK/name,OUT/name)
print(json.dumps({k:v for k,v in checks.items() if k not in ['poses','bounding_boxes']},ensure_ascii=False))
