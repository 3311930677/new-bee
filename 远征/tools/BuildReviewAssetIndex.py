from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1];assets=root/'assets/ui/full_review_fixes_20261009'
regions={}
def atlas(file,columns,rows,names):
 im=Image.open(assets/file).convert('RGBA')
 for i,name in enumerate(names):
  x,y=(i%columns)*im.width//columns,(i//columns)*im.height//rows
  box=im.getchannel('A').crop((x,y,x+im.width//columns,y+im.height//rows)).getbbox()
  regions[name]={'file':file,'source_size':list(im.size),'rect':[x+box[0],y+box[1],box[2]-box[0],box[3]-box[1]]}
templates=json.loads((root/'data/equip.json').read_text(encoding='utf-8'))['templates']
for i in range(4):atlas('items%d.png'%(i+1),4,3 if i<3 else 2,[t['id'] for t in templates[i*12:(i+1)*12]])
skills=json.loads((root/'data/skills.json').read_text(encoding='utf-8'))
atlas('skills.png',5,4,[s['id'] for s in skills[:20]])
pets=json.loads((root/'data/pets.json').read_text(encoding='utf-8'))
atlas('pets.png',5,2,[p['id'] for p in pets])
for name in ['chest','niche']:
 im=Image.open(assets/(name+'.png'));regions[name]={'file':name+'.png','source_size':list(im.size),'rect':[0,0,im.width,im.height]}
im=Image.open(assets/'showcase.png').convert('RGBA')
for name,a,b in [('showcase_frame',0,int(im.height*.78)),('pedestal',int(im.height*.78),im.height)]:
 box=im.getchannel('A').crop((0,a,im.width,b)).getbbox();regions[name]={'file':'showcase.png','source_size':list(im.size),'rect':[box[0],a+box[1],box[2]-box[0],box[3]-box[1]]}
(assets/'source_regions.json').write_text(json.dumps(regions,indent=2),encoding='utf-8')
for pet in pets:
 file='pet_show/'+pet['id']+'.png'
 if (assets/file).exists():regions[pet['id']]={'file':file,'source_size':[64,64],'rect':[0,0,64,64]}
if (assets/'map.png').exists():
 im=Image.open(assets/'map.png');regions['map']={'file':'map.png','source_size':list(im.size),'rect':[0,0,im.width,im.height]}
(assets/'regions.json').write_text(json.dumps(regions,indent=2),encoding='utf-8')
