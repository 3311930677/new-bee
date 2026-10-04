"""Pack matched side standing/walk poses; preserve active front and rear pixels."""
from pathlib import Path
import json, shutil, re
import numpy as np
import cv2
from PIL import Image, ImageDraw
from pack_walk_video_v15 import clean_alpha

ROOT = Path(__file__).resolve().parents[1]
ROLE = ROOT/'image'/'role'/'fs'
QA = ROOT/'shots'/'walk_side_v16_20261004'

def face_anchor(tile):
    a = np.array(tile)
    r, g, b, alpha = [a[:, :, i].astype(float) for i in range(4)]
    skin = ((r > 130) & (r > g*1.12) & (g > b*1.1) & (alpha > 128)).astype('uint8')
    skin[int(tile.height*.55):] = 0
    n, labels, stats, centers = cv2.connectedComponentsWithStats(skin, 8)
    label = 1+np.argmax(stats[1:, cv2.CC_STAT_AREA])
    return tuple(centers[label])

def main():
    QA.mkdir(parents=True, exist_ok=True)
    source_path = ROLE/'source'/'shuangyu_side_v16_draft.png'
    source = Image.open(source_path).convert('RGBA')
    rows = []
    for row in range(2):
        rows.append([clean_alpha(source.crop((round(col*source.width/7), round(row*source.height/2),
                        round((col+1)*source.width/7), round((row+1)*source.height/2)))) for col in range(7)])
    boxes = [tile.getchannel('A').getbbox() for row in rows for tile in row]
    scale = min(108/max(b[2]-b[0] for b in boxes), 110/max(b[3]-b[1] for b in boxes))
    packed = []
    report = {'source': str(source_path.relative_to(ROOT)), 'scale': scale, 'directions': {}}
    for row, direction in enumerate(('left', 'right')):
        anchors = [face_anchor(tile) for tile in rows[row]]
        # Register by the face, never by a changing cape/weapon silhouette.
        reference_y = float(np.median([p[1] for p in anchors]))
        ground = max(b[3] for b in boxes[row*7:(row+1)*7])-1
        row_packed = []
        for col, tile in enumerate(rows[row]):
            face_x, face_y = anchors[col]
            x = round((54 if row == 0 else 74)-face_x*scale)
            y = round(120-ground*scale+(reference_y-face_y)*scale)
            scaled = tile.resize((round(tile.width*scale), round(tile.height*scale)), Image.Resampling.NEAREST)
            frame = Image.new('RGBA', (128,128))
            frame.alpha_composite(scaled, (x,y))
            bbox = frame.getchannel('A').getbbox()
            assert bbox and bbox[0]>=3 and bbox[2]<=125 and bbox[1]>=3 and bbox[3]<=124, (direction,col,bbox)
            assert frame.getchannel('A').crop((0,114,128,124)).getbbox(), (direction,col,'ground')
            row_packed.append(frame)
        packed.append(row_packed)
        report['directions'][direction] = {'face_anchors': anchors, 'source_ground': ground}
    active = ROLE/'shuangyu_walk_4dir.png'
    backup = ROLE/'source'/'shuangyu_walk_before_side_v16.png'
    if not backup.exists(): shutil.copy2(active, backup)
    old = Image.open(backup).convert('RGBA')
    new = old.copy()
    idle = Image.new('RGBA', (256,128))
    for row in range(2):
        idle.alpha_composite(packed[row][0], (row*128,0))
        for col in range(6):
            new.paste(packed[row][col+1], (col*128,(row+1)*128))
    for row in (0,3):
        assert old.crop((0,row*128,768,(row+1)*128)).tobytes() == new.crop((0,row*128,768,(row+1)*128)).tobytes()
    new.save(ROLE/'shuangyu_walk_side_v16.png')
    idle.save(ROLE/'shuangyu_idle_side_v16.png')
    new.save(active)
    resource_path = ROLE/'shuangyu_walk_frames.tres'
    resource_backup = QA/'shuangyu_walk_frames_before_v16.tres'
    if not resource_backup.exists(): shutil.copy2(resource_path, resource_backup)
    text = resource_backup.read_text(encoding='utf-8')
    text = text.replace('load_steps=26', 'load_steps=29')
    extra = '[ext_resource type="Texture2D" path="res://image/role/fs/shuangyu_idle_side_v16.png" id="2_idle"]\n'
    text = text.replace('[sub_resource type="AtlasTexture" id="Atlas_0"]', extra+'\n[sub_resource type="AtlasTexture" id="Atlas_0"]',1)
    idle_resources = ''
    for i,direction in enumerate(('left','right')):
        idle_resources += f'[sub_resource type="AtlasTexture" id="Idle_{direction}"]\natlas = ExtResource("2_idle")\nregion = Rect2({i*128}, 0, 128, 128)\nfilter_clip = true\n\n'
    text = text.replace('[resource]', idle_resources+'[resource]',1)
    for direction in ('left','right'):
        idle_anim = '{\n"frames": [{"duration": 1.0, "texture": SubResource("Idle_%s")}],\n"loop": false,\n"name": &"idle_%s",\n"speed": 1.0\n}' % (direction,direction)
        text = text.rstrip()[:-1]+',\n'+idle_anim+'\n]\n'
    resource_path.write_text(text, encoding='utf-8')
    preview = []
    # Two full walks followed by a real pause, then start again.
    phases = list(range(6))*2+[None]*8
    for slot in phases:
        canvas = Image.new('RGB',(720,340),'#252d3a')
        draw = ImageDraw.Draw(canvas)
        draw.text((50,12),'V15: passing pose on stop',fill='white')
        draw.text((385,12),'V16: separate side standing',fill='white')
        for row,direction in enumerate(('left','right')):
            y = 38+row*146
            draw.text((10,y+55),direction,fill='#e5bd6e')
            before_slot = 1 if slot is None else slot
            before = old.crop((before_slot*128,(row+1)*128,(before_slot+1)*128,(row+2)*128))
            after = packed[row][0 if slot is None else slot+1]
            for frame,x in ((before,140),(after,480)):
                canvas.paste(frame,(x,y),frame)
            draw.text((350,y+118),'STOP / IDLE' if slot is None else 'WALK',fill='white')
        preview.append(canvas)
    preview[0].save(QA/'walk_stop_comparison.gif',save_all=True,append_images=preview[1:],duration=round(1000/12),loop=0,disposal=2)
    contact = Image.new('RGB',(7*192,2*224),'#252d3a')
    draw = ImageDraw.Draw(contact)
    for row in range(2):
        for col in range(7):
            tile = packed[row][col].resize((192,192),Image.Resampling.NEAREST)
            contact.paste(tile,(col*192,row*224),tile)
            draw.text((col*192+8,row*224+196),('left' if row==0 else 'right')+(' IDLE' if col==0 else f' walk {col-1}'),fill='white')
    contact.save(QA/'side_idle_walk_phases.png')
    (QA/'packing_checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('SIDE_V16_PACK_OK: front/back unchanged; 12 side walk frames + 2 independent standing poses')

if __name__ == '__main__': main()
