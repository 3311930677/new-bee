"""Create four reference-preserving walk rows with Pixel Art Studio.

Uses the approved right-facing test; authors left/front/back lower-body anatomy
against the original directional references. Installation is a separate step.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
import sys
from collections import deque

from PIL import Image, ImageDraw, ImageChops, ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools/pixel-art-studio/scripts'))
from pixelstudio import Sprite

ap=argparse.ArgumentParser()
ap.add_argument('--pass-number',type=int,default=3)
arg=ap.parse_args()
WORK=OUT/f'four_review/pass_{arg.pass_number}'
PARTS=WORK/'parts';PARTS.mkdir(parents=True,exist_ok=True)
BACKUP=OUT/'backup';BACKUP.mkdir(exist_ok=True)
original_path=ROOT/'远征/image/role/zs/pojun_walk_4dir.png'
saved_original=BACKUP/'pojun_walk_4dir.original.png'
if not saved_original.exists():
    shutil.copy2(original_path,saved_original)
    shutil.copy2(ROOT/'远征/image/role/zs/pojun_walk_frames.tres',BACKUP/'pojun_walk_frames.original.tres')
original=Image.open(saved_original).convert('RGBA')
N=8;DURATION=110;GROUND=120
DIRS=['down','left','right','up']
BOB=[0,1,0,-1,0,1,0,-1]
poses=[]

def clean_islands(im,min_area=5):
    """Remove only disconnected flecks, not connected armor or blade pixels."""
    im=im.copy();p=im.load();seen=set()
    for y in range(im.height):
        for x in range(im.width):
            if (x,y) in seen or p[x,y][3]<64:continue
            q=deque([(x,y)]);seen.add((x,y));group=[]
            while q:
                a,b=q.popleft();group.append((a,b))
                for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
                    c,d=a+dx,b+dy
                    if 0<=c<im.width and 0<=d<im.height and (c,d) not in seen and p[c,d][3]>=64:
                        seen.add((c,d));q.append((c,d))
            if len(group)<min_area:
                for a,b in group:p[a,b]=(0,0,0,0)
    for y in range(im.height):
        for x in range(im.width):
            if p[x,y][3]<64:p[x,y]=(0,0,0,0)
    return im

def sample_part(src,points,name):
    m=Image.new('L',(128,128));ImageDraw.Draw(m).polygon(points,fill=255)
    im=src.copy();im.putalpha(ImageChops.multiply(src.getchannel('A'),m))
    im=clean_islands(im,2)
    im.save(PARTS/name)
    return im

def paste_art(s,im,pos,origin,name):
    dest=PARTS/name;im.save(dest)
    s.paste_png(dest,round(pos[0]-origin[0]),round(pos[1]-origin[1]))

def tube(s,a,b,r1,r2,far=False,steel=True):
    vx,vy=b[0]-a[0],b[1]-a[1];ln=max(.1,math.hypot(vx,vy));ux,uy=vx/ln,vy/ln;nx,ny=-uy,ux
    pt=[(round(a[0]+nx*r1),round(a[1]+ny*r1)),(round(a[0]-nx*r1),round(a[1]-ny*r1)),(round(b[0]-nx*r2),round(b[1]-ny*r2)),(round(b[0]+nx*r2),round(b[1]+ny*r2))]
    s.polygon(pt,'#18151a')
    m=Image.new('L',(128,128));ImageDraw.Draw(m).polygon(pt,fill=255);bb=m.getbbox()
    if not bb:return
    for y in range(bb[1],bb[3]):
        for x in range(bb[0],bb[2]):
            if not m.getpixel((x,y)):continue
            u=max(0,min(1,((x-a[0])*ux+(y-a[1])*uy)/ln));r=r1*(1-u)+r2*u
            side=((x-a[0])*nx+(y-a[1])*ny)/max(1,r)
            if abs(side)>.84:continue
            # Native-resolution shaded clusters, matching charcoal plate armor.
            profile=[(27,25,29),(36,34,38),(47,45,49),(59,57,60),(76,73,73),(67,64,64),(48,44,45),(32,28,29)]
            idx=max(0,min(7,round((side+1)*3.5)))
            c=profile[idx]
            if not steel:c=tuple(round(v*.8) for v in c)
            if far:c=(round(c[0]*.74),round(c[1]*.76),round(c[2]*.82))
            s.px(x,y,c)
    if steel:
        t=.8;cx=a[0]+vx*t;cy=a[1]+vy*t;r=r1*(1-t)+r2*t
        s.line(round(cx+nx*r*.7),round(cy+ny*r*.7),round(cx-nx*r*.7),round(cy-ny*r*.7),'#b58525' if far else '#d3a13a')

def knee_ik(hip,ankle,l1=9,l2=13,face=-1):
    vx,vy=ankle[0]-hip[0],ankle[1]-hip[1];actual=max(.1,math.hypot(vx,vy));d=min(actual,l1+l2-.1)
    along=(l1*l1-l2*l2+d*d)/(2*d);height=math.sqrt(max(0,l1*l1-along*along));ux,uy=vx/actual,vy/actual
    return round(hip[0]+along*ux+face*height*uy),round(hip[1]+along*uy-face*height*ux)

def new_left():
    src=original.crop((0,128,128,256));src=clean_islands(src,4)
    body=src.copy();cape=Image.new('RGBA',(128,128));mask=Image.new('L',(128,128))
    ImageDraw.Draw(mask).polygon([(78,66),(103,77),(123,89),(119,107),(104,101),(92,101),(79,86)],fill=255)
    for y in range(128):
        for x in range(128):
            c=src.getpixel((x,y));r,g,b,a=c
            is_cape=a>0 and mask.getpixel((x,y)) and r>g*1.6 and r>b*1.5
            if is_cape:cape.putpixel((x,y),c);body.putpixel((x,y),(0,0,0,0))
            if 51<=x<=82 and y>=94:body.putpixel((x,y),(0,0,0,0))
    body.save(PARTS/'left_body.png');cape.save(PARTS/'left_cape.png')
    knee=sample_part(src,[(59,97),(67,96),(72,100),(71,105),(66,108),(60,107),(57,102)],'left_knee.png')
    boot=sample_part(src,[(56,112),(65,110),(73,113),(77,117),(76,120),(55,120),(52,118),(52,115)],'left_boot.png')
    # Native body height is already close to the approved right-facing test.
    dx,dy=1,0
    ankle_positions=[(54,113),(58,113),(63,113),(68,113),(73,113),(73,108),(64,106),(56,109)]
    s=Sprite(128,128,snap=False)
    for i in range(N):
        if i:s.add_frame(copy=False,duration=DURATION)
        details=[]
        for far in [True,False]:
            phase=(i+4)%N if far else i
            hip=(65+dx+(2 if far else 0),94+BOB[i])
            ax,ay=ankle_positions[phase];ankle=(ax+dx,ay+dy)
            k=knee_ik(hip,ankle,9.5,13,-1)
            s.layer('far_leg' if far else 'near_leg')
            tube(s,hip,k,4.5,4.3,far,False);tube(s,k,ankle,4.3,3.8,far)
            im=knee.copy()
            if far:
                px=im.load()
                for yy in range(128):
                    for xx in range(128):
                        r,g,b,a=px[xx,yy]
                        if a:px[xx,yy]=(round(r*.73),round(g*.75),round(b*.8),a)
            paste_art(s,im,k,(65,102),f'left_knee_{i}_{far}.png')
            bp=boot.copy()
            if far:
                px=bp.load()
                for yy in range(128):
                    for xx in range(128):
                        r,g,b,a=px[xx,yy]
                        if a:px[xx,yy]=(round(r*.73),round(g*.75),round(b*.8),a)
            roll=[0,0,0,-8,-13,14,8,8][phase] if arg.pass_number>=2 else 0
            bp=bp.rotate(-roll,resample=Image.Resampling.NEAREST,center=(65,113))
            by=GROUND-(bp.getbbox()[3]-1) if phase<=4 else ankle[1]-113
            file=PARTS/f'left_boot_{i}_{far}.png';bp.save(file);s.paste_png(file,ankle[0]-65,by)
            details.append({'far':far,'hip':hip,'knee':k,'ankle':ankle})
        # Preserve cape and entire original upper body, including sword and hand.
        s.layer('cape');s.paste_png(PARTS/'left_cape.png',dx,dy+BOB[(i-1)%N])
        s.layer('original_body_and_weapon');s.paste_png(PARTS/'left_body.png',dx,dy+BOB[i])
        poses.append({'direction':'left','frame':i,'parts':details})
    s.set_duration(DURATION,frames='all');s.tag('walk_left',1,8)
    return s

def new_vertical(direction):
    up=direction=='up';row=3 if up else 0
    src=clean_islands(original.crop((0,row*128,128,row*128+128)),5)
    if up and arg.pass_number >= 2:
        # The original rear blade has disconnected transparent holes. Restitch
        # only its steel silhouette; keep the original hilt and gripping hand.
        src.save(PARTS/'up_before_blade_cleanup.png')
        blade=Sprite(128,128,snap=False)
        blade.paste_png(PARTS/'up_before_blade_cleanup.png')
        blade.polygon([(94,82),(126,88),(127,115),(94,115),(90,94)],None)
        blade.polygon([(92,82),(105,88),(118,99),(121,105),(113,102),(99,92),(90,87)],'#2b292d')
        blade.polygon([(93,83),(104,89),(115,98),(118,102),(113,100),(100,91),(92,86)],'#514b4d')
        blade.line(93,83,104,89,'#b6ada2')
        blade.line(104,89,117,100,'#b6ada2')
        blade.line(92,87,100,92,'#8c8176')
        blade.line(100,92,113,101,'#8c8176')
        blade.line(113,101,120,104,'#c8bdb0')
        src=blade.composite(1)
    body=src.copy();cape=Image.new('RGBA',(128,128))
    for y in range(128):
        for x in range(128):
            r,g,b,a=src.getpixel((x,y))
            if up:
                cape_area=(7<=x<=59 and 60<=y<=100) or (70<=x<=92 and 56<=y<=101)
                erase=37<=x<=91 and y>=90
                preserve=False
            else:
                cape_area=(x<44 and 53<=y<=98) or (84<=x<=100 and 64<=y<=83)
                erase=35<=x<=90 and y>=86
                preserve=59<=x<=66 and y<=101
            is_cape=a>0 and cape_area and r>g*1.8 and r>b*1.6
            if is_cape:cape.putpixel((x,y),(r,g,b,a));body.putpixel((x,y),(0,0,0,0))
            if erase and not preserve:body.putpixel((x,y),(0,0,0,0))
    body.save(PARTS/f'{direction}_body.png');cape.save(PARTS/f'{direction}_cape.png')
    if up:
        knee=sample_part(src,[(47,93),(55,92),(59,96),(58,103),(50,105),(46,101)],'up_knee.png')
        boot=sample_part(src,[(48,108),(56,107),(60,113),(60,118),(42,118),(42,115),(46,111)],'up_boot.png')
        knee_origin=(52,98);boot_origin=(51,110);dy=7;hips=[(51,90),(74,90)]
    else:
        knee=sample_part(src,[(46,88),(53,86),(58,91),(57,99),(51,103),(45,99),(43,94)],'down_knee.png')
        boot=sample_part(src,[(48,107),(56,105),(61,110),(64,114),(63,118),(43,118),(43,112)],'down_boot.png')
        knee_origin=(51,94);boot_origin=(53,110);dy=9 if arg.pass_number>=3 else 12;hips=[(51,86),(74,86)]
    dx=0
    lifts=[0,0,0,0,0,4,7,3]
    spread=[2,1,0,-1,-2,-2,0,1]
    s=Sprite(128,128,snap=False)
    for i in range(N):
        if i:s.add_frame(copy=False,duration=DURATION)
        details=[]
        # Both front/back legs are authored, not a mirror of a side walk.
        for leg in [1,0]:
            phase=(i+4)%N if leg else i
            hip=(hips[leg][0],hips[leg][1]+dy+BOB[i])
            ankle_x=hips[leg][0]+spread[phase]*(1 if leg else -1)
            ankle=(ankle_x,112-lifts[phase])
            k=(round(hip[0]+(ankle[0]-hip[0])*.4),round(hip[1]+(ankle[1]-hip[1])*.49)- (1 if phase>=5 else 0))
            s.layer(f'leg_{leg}')
            tube(s,hip,k,5.1,4.7,leg==1,False);tube(s,k,ankle,4.9,4.2,leg==1)
            # Compact knee armor is reconstructed from the original metal plate.
            paste_art(s,knee,k,knee_origin,f'{direction}_knee_{i}_{leg}.png')
            bp=boot.copy()
            # Front and back views need opposite foot foreshortening on swing.
            if phase>=5 and arg.pass_number>=2:
                roll=(-5 if leg==0 else 5) * (1 if not up else -1)
                bp=bp.rotate(roll,resample=Image.Resampling.NEAREST,center=boot_origin)
            if phase<=4:by=GROUND-(bp.getbbox()[3]-1)
            else:by=GROUND-lifts[phase]-(bp.getbbox()[3]-1)
            file=PARTS/f'{direction}_boot_{i}_{leg}.png';bp.save(file)
            s.paste_png(file,ankle[0]-boot_origin[0],by)
            details.append({'leg':leg,'phase':phase,'hip':hip,'knee':k,'ankle':ankle,'lift':lifts[phase]})
        s.layer('cape');s.paste_png(PARTS/f'{direction}_cape.png',dx,dy+BOB[(i-1)%N])
        s.layer('original_body_and_weapon');s.paste_png(PARTS/f'{direction}_body.png',dx,dy+BOB[i])
        poses.append({'direction':direction,'frame':i,'parts':details})
    s.set_duration(DURATION,frames='all');s.tag('walk_'+direction,1,8)
    return s

sprites={'down':new_vertical('down'),'left':new_left(),'up':new_vertical('up')}
right_sheet=Image.open(OUT/'pojun_walk_right_8.png').convert('RGBA')
rows={d:[sprites[d].composite(i+1) for i in range(N)] for d in sprites}
rows['right']=[right_sheet.crop((i*128,0,(i+1)*128,128)) for i in range(N)]

sheet=Image.new('RGBA',(1024,512))
for r,d in enumerate(DIRS):
    for i,f in enumerate(rows[d]):sheet.alpha_composite(f,(i*128,r*128))
sheet.save(WORK/'pojun_walk_4dir.png')

# Engine resource uses this game's 128px cells and down/left/right/up row order.
# This deliberately follows the existing game contract instead of shrinking art
# to the skill's optional 64px LPC layout.
res=['[gd_resource type="SpriteFrames" load_steps=34 format=3]','',
     '[ext_resource type="Texture2D" path="res://image/role/zs/pojun_walk_4dir.png" id="1"]','']
for r,d in enumerate(DIRS):
    for i in range(N):
        n=r*N+i
        res += [f'[sub_resource type="AtlasTexture" id="Atlas_{n}"]','atlas = ExtResource("1")',
                f'region = Rect2({128*i}, {128*r}, 128, 128)','filter_clip = true','']
res+=['[resource]','animations = [']
for r,d in enumerate(DIRS):
    frames=', '.join('{"duration": 1.0, "texture": SubResource("Atlas_%d")}'%(r*N+i) for i in range(N))
    res+=['{',f'"frames": [{frames}],','"loop": true,',f'"name": &"walk_{d}",',f'"speed": {1000/DURATION:.6f}','}'+(',' if r<3 else '')]
res+= [']','']
(WORK/'pojun_walk_frames.tres').write_text('\n'.join(res),encoding='utf-8')

font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
names={'down':'向下','left':'向左','right':'向右','up':'向上'}
gif=[]
for i in range(N):
    panel=Image.new('RGB',(1040,330),'#263340');draw=ImageDraw.Draw(panel)
    for r,d in enumerate(DIRS):
        draw.text((r*260+16,12),names[d],font=font,fill='#edf4f8')
        f=rows[d][i].resize((256,256),Image.Resampling.NEAREST)
        panel.paste(f,(r*260,44),f)
    draw.text((16,307),'破军 · Pixel Art Studio · 四方向行走试作',font=font,fill='#bacddc')
    gif.append(panel)
gif[0].save(WORK/'four_directions.gif',save_all=True,append_images=gif[1:],duration=DURATION,loop=0,disposal=2)
gif[0].save(WORK/'four_directions.png')
for d,s in sprites.items():
    s.save_project(WORK/f'pojun_{d}.pxproj.json')
    s.preview(WORK/f'{d}_contact.png',scale=3,cols=4,bg='#303b4a')
    s.save_gif(WORK/f'{d}.gif',scale=3,bg='#303b4a')

checks={'source_backup_sha256':hashlib.sha256(saved_original.read_bytes()).hexdigest(),
        'frame_size':[128,128],'atlas_size':[1024,512],'frame_count_per_direction':N,
        'order':DIRS,'duration_ms':DURATION,'poses':poses,'pass':arg.pass_number,
        'directions':{d:{'unique_frames':len(set(hashlib.sha256(im.tobytes()).hexdigest() for im in rows[d])),
                         'bounding_boxes':[im.getbbox() for im in rows[d]]} for d in DIRS}}
(WORK/'checks.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
if arg.pass_number>=3:
    for d in DIRS:
        assert checks['directions'][d]['unique_frames']==8
        assert all(b[0]>0 and b[1]>0 and b[2]<128 and b[3]<128 for b in checks['directions'][d]['bounding_boxes'])
    for name in ['pojun_walk_4dir.png','pojun_walk_frames.tres','four_directions.gif','four_directions.png','checks.json']:
        shutil.copy2(WORK/name,OUT/name)
print(json.dumps({k:v for k,v in checks.items() if k!='poses'},ensure_ascii=False))
