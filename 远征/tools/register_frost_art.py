from pathlib import Path
from PIL import Image
import numpy as np
import hashlib,json,math
root=Path(__file__).resolve().parent.parent
rows={}
for name in ['envoy','guard','miner']:
    p=root/'image/main_world'/f'npc_frost_{name}_idle_reference_v2.png'
    im=Image.open(p).convert('RGBA'); a=np.asarray(im)[:,:,3]; frames=[]
    for i in range(4):
        left=round(i*im.width/4); right=round((i+1)*im.width/4)
        y,x=np.where(a[:,left:right]>=128)
        footx=x[y>=y.max()-6]; center=(int(footx.min())+int(footx.max())+1)/2
        frames.append({'region':[left+int(x.min()),int(y.min()),int(x.max()-x.min()+1),int(y.max()-y.min()+1)],'foot_x':center-int(x.min())})
    h=max(f['region'][3] for f in frames)
    w=2*math.ceil(max(max(f['foot_x'],f['region'][2]-f['foot_x']) for f in frames))+8
    for f in frames:
        _,_,fw,fh=f['region']; f['margin']=[w/2-f['foot_x'],h-fh,w-fw,h-fh]
    x,y,fw,fh=frames[0]['region']; portrait=[x,y,fw,min(fw,round(fh*.43))]
    rows[f'npc_frost_{name}']={'path':'res://image/main_world/'+p.name,'source_size':list(im.size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'canvas':[w,h],'frames':frames,'portrait':portrait,'world_height':76}
    print(name,im.size,'canvas',w,h,'heights',[f['region'][3] for f in frames],'portrait',portrait)
for p in (root/'image/main_world').glob('city_frost_*reference_v2.png'):
    a=np.asarray(Image.open(p).convert('RGBA'))[:,:,3]
    print(p.name,a.shape,'corners',[int(a[y,x]) for y,x in [(0,0),(0,-1),(-1,0),(-1,-1)]],'alpha',int((a==0).sum()),int((a==255).sum()),'top-middle',int(a[0,a.shape[1]//2]))
props={}
for stem in ['city_frost_lodge','city_frost_supply','city_frost_guardhouse','frost_brazier']:
    p=root/'image/main_world'/f'{stem}_reference_v2.png'
    im=Image.open(p).convert('RGBA'); a=np.asarray(im)[:,:,3]
    y,x=np.where(a>=128)
    props[stem]={'path':'res://image/main_world/'+p.name,'region':[int(x.min()),int(y.min()),int(x.max()-x.min()+1),int(y.max()-y.min()+1)],'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
    print(stem,props[stem]['region'],'alpha quartiles',np.percentile(a[a>0],[25,50,75,99]).tolist())
(root/'data/frost_city_art.json').write_text(json.dumps({'npcs':rows,'props':props},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
