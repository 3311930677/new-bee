"""Use one consecutive original video cycle per side, with no image synthesis."""
from pathlib import Path
import json,re,hashlib,shutil
import cv2
import numpy as np
from PIL import Image,ImageDraw
from analyze_side_video_v17 import ROOT,OUT,VIDEO
from register_video_side_v17 import CYCLES

ROLE=ROOT/'image'/'role'/'fs'
COUNT,FPS=30,30

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    report={'video':str(VIDEO),'video_sha256':digest(VIDEO),'method':'direct original RGB extraction; neutral matte removal; uniform camera registration; nearest sampling',
            'fps':FPS,'frame_count_per_side':COUNT,'period_seconds':1.0,'directions':{}}
    registration=json.loads((OUT/'registration.json').read_text())
    cap=cv2.VideoCapture(str(VIDEO))
    atlas=Image.new('RGBA',(COUNT*128,256))
    source_panels=[[],[]]
    rows=[]
    for row,(direction,(start,end)) in enumerate(CYCLES.items()):
        metrics=[m for m in registration[direction] if start<=m['frame']<=end]
        crops={r['frame']:r for r in json.loads((OUT/f'{direction}_source.json').read_text())}
        bases=[Image.open(OUT/direction/f"registered_{m['frame']:03d}.png").convert('RGBA') for m in metrics]
        offset_y=min(round(121-float(np.median([im.getchannel('A').getbbox()[3] for im in bases]))),
                     124-max(im.getchannel('A').getbbox()[3] for im in bases))
        frames=[]
        records=[]
        for col,(m,base) in enumerate(zip(metrics,bases)):
            index=m['frame']
            tile=Image.new('RGBA',(128,128))
            tile.alpha_composite(base,(0,offset_y))
            bbox=tile.getchannel('A').getbbox()
            assert bbox and bbox[0]>=4 and bbox[2]<=124 and bbox[1]>=4 and bbox[3]<=124,(direction,index,bbox)
            atlas.alpha_composite(tile,(col*128,row*128))
            frames.append(tile)
            # Re-decode independently and prove the foreground RGB comes from
            # this exact source frame, before camera scaling and registration.
            cap.set(cv2.CAP_PROP_POS_FRAMES,index)
            ok,bgr=cap.read()
            assert ok
            rgb=cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB)
            crop=crops[index]['crop']
            original=rgb[crop[1]:crop[3],crop[0]:crop[2]]
            cut=np.array(Image.open(OUT/direction/f'{index:03d}.png'))
            mask=cut[:,:,3]>0
            assert np.array_equal(cut[:,:,:3][mask],original[mask]),'foreground RGB was modified'
            scaled=Image.fromarray(original).resize((round(original.shape[1]*m['scale']),round(original.shape[0]*m['scale'])),Image.Resampling.NEAREST)
            raw=Image.new('RGB',(128,128),tuple(int(v) for v in original[0,0]))
            raw.paste(scaled,(m['origin'][0],m['origin'][1]+offset_y))
            source_panels[row].append(raw)
            records.append({'slot':col,'source_frame':index,'timestamp_seconds':index/30,'crop':crop,
                            'registration':m,'shared_floor_shift':offset_y,'runtime_bbox':bbox,
                            'rgb_preserved':True,'runtime_sha256':hashlib.sha256(tile.tobytes()).hexdigest()})
        assert len(frames)==COUNT and len({r['runtime_sha256'] for r in records})==COUNT
        rows.append(frames)
        report['directions'][direction]={'source_range':[start,end],'frames':records}
    cap.release()
    active=ROLE/'shuangyu_walk_4dir.png'
    backup=ROLE/'source'/'shuangyu_walk_before_direct_v17.png'
    if not backup.exists():shutil.copy2(active,backup)
    legacy=Image.open(backup).convert('RGBA')
    for row in range(2):
        for slot in range(6):legacy.paste(rows[row][slot*5],(slot*128,(row+1)*128))
    legacy.save(active)
    atlas_path=ROLE/'shuangyu_walk_side_video_v17.png'
    atlas.save(atlas_path)
    resource=ROLE/'shuangyu_walk_frames.tres'
    resource_backup=OUT/'shuangyu_walk_frames_before_v17.tres'
    if not resource_backup.exists():shutil.copy2(resource,resource_backup)
    text=resource_backup.read_text(encoding='utf-8')
    # Front/rear and the existing independent standing resources remain intact.
    for index in range(6,18):
        text=re.sub(r'\[sub_resource type="AtlasTexture" id="Atlas_'+str(index)+r'"\]\n.*?(?=\[)', '',text,flags=re.S)
    ext='[ext_resource type="Texture2D" path="res://image/role/fs/shuangyu_walk_side_video_v17.png" id="3_video"]\n\n'
    first=text.index('[sub_resource')
    text=text[:first]+ext+text[first:]
    subs=''
    for row,direction in enumerate(('left','right')):
        for col in range(COUNT):
            subs+=f'[sub_resource type="AtlasTexture" id="Video_{direction}_{col}"]\natlas = ExtResource("3_video")\nregion = Rect2({col*128}, {row*128}, 128, 128)\nfilter_clip = true\n\n'
        frames=', '.join('{"duration": 1.0, "texture": SubResource("Video_%s_%d")}'%(direction,col) for col in range(COUNT))
        pattern=r'\{\n"frames": \[.*?\],\n"loop": true,\n"name": &"walk_'+direction+r'",\n"speed": [\d.]+\n\}'
        # Match only one animation object: prevent crossing earlier front frames.
        pattern=r'\{\n"frames": \[[^\n]*\],\n"loop": true,\n"name": &"walk_'+direction+r'",\n"speed": [\d.]+\n\}'
        text,n=re.subn(pattern,'{\n"frames": ['+frames+'],\n"loop": true,\n"name": &"walk_'+direction+'",\n"speed": '+str(float(FPS))+'\n}',text)
        assert n==1,(direction,n)
    text=text.replace('[resource]',subs+'[resource]',1)
    steps=1+text.count('[ext_resource')+text.count('[sub_resource')
    text=re.sub(r'load_steps=\d+',f'load_steps={steps}',text,count=1)
    resource.write_text(text,encoding='utf-8')
    # Source and result show the same chronological frames at the same cadence.
    previews=[]
    old=Image.open(backup).convert('RGBA')
    for col in range(COUNT):
        canvas=Image.new('RGB',(930,530),'#28313e')
        draw=ImageDraw.Draw(canvas)
        for x,label in [(28,'Original video'),(350,'Direct cutout V17'),(670,'Previous V16')]:draw.text((x,12),label,fill='white')
        for row,direction in enumerate(('left','right')):
            y=40+row*240
            raw=source_panels[row][col].resize((192,192),Image.Resampling.NEAREST)
            new=rows[row][col].resize((192,192),Image.Resampling.NEAREST)
            # Previous 6-frame animation, with its original 12 FPS, for comparison.
            old_slot=(col*12//FPS)%6
            prior=old.crop((old_slot*128,(row+1)*128,(old_slot+1)*128,(row+2)*128)).resize((192,192),Image.Resampling.NEAREST)
            canvas.paste(raw,(30,y))
            canvas.paste(new,(350,y),new)
            canvas.paste(prior,(670,y),prior)
            draw.text((30,y+204),f"{direction} video #{CYCLES[direction][0]+col} / {(CYCLES[direction][0]+col)/30:.3f}s",fill='white')
        previews.append(canvas)
    durations=[30,30,40]*10
    previews[0].save(OUT/'video_vs_cutout_v17.gif',save_all=True,append_images=previews[1:],duration=durations,loop=0,disposal=2)
    for row,direction in enumerate(('left','right')):
        contact=Image.new('RGB',(10*192,3*216),'#28313e')
        draw=ImageDraw.Draw(contact)
        for col,tile in enumerate(rows[row]):
            image=tile.resize((192,192),Image.Resampling.NEAREST)
            x,y=(col%10)*192,(col//10)*216
            contact.paste(image,(x,y),image)
            draw.text((x+8,y+193),f"#{CYCLES[direction][0]+col} slot {col}",fill='white')
        contact.save(OUT/f'{direction}_cycle_v17.png')
    (OUT/'direct_extraction_checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('DIRECT_VIDEO_V17_OK: 60 consecutive original RGB frames; 30 FPS; one-second side loops; zero generated leg pixels')

if __name__=='__main__':main()
