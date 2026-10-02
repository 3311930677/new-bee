"""Analyze source alpha without editing PNGs; register native AtlasTexture bounds."""
from pathlib import Path
from PIL import Image
import numpy as np
import hashlib,json
root=Path(__file__).resolve().parent.parent
rows={}
for name in ['zombie','wolf','spider','treant','skeleton','goblin','lost_beast','shadow_wolf','stele_warden']:
    mon='mon_'+name
    p=root/'image/main_world'/(mon+('.png' if name=='stele_warden' else '_reference_v2.png'))
    im=Image.open(p).convert('RGBA'); a=np.asarray(im)[:,:,3]
    y,x=np.where(a>=128)
    boss=name in ['lost_beast','stele_warden']
    rows[mon]={'path':'res://image/main_world/'+p.name,'source_size':list(im.size),'region':[int(x.min()),int(y.min()),int(x.max()-x.min()+1),int(y.max()-y.min()+1)],'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'map_max_width':168 if boss else 96,'battle_max_width':168 if boss else 128}
    print(mon,im.size,'region',rows[mon]['region'])
(root/'data/monster_art.json').write_text(json.dumps({'monsters':rows},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Change only explicit art fields; geometry/encounter numbers and all IDs stay intact.
p=root/'data/main_world_maps.json'
text=p.read_text(encoding='utf-8')
text=text.replace('"monster_sprite": "res://image/generated_362_xajh/ready/monster/mon_ghost.png",\n      "monster_height": 118,','"monster_sprite": "res://image/main_world/mon_zombie_reference_v2.png",\n      "monster_height": 76,')
text=text.replace('"sprite": "res://image/main_world/mon_lost_beast.png"','"sprite": "res://image/main_world/mon_lost_beast_reference_v2.png"')
text=text.replace('"mon_shadow_wolf": "res://image/main_world/mon_shadow_wolf.png"','"mon_shadow_wolf": "res://image/main_world/mon_shadow_wolf_reference_v2.png"')
p.write_text(text,encoding='utf-8')
