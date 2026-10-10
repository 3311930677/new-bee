from pathlib import Path
import json,math
task=Path(__file__).resolve().parents[2]
root=task/'远征'/'assets'/'world'/'reference_complete_20261011'
for name in ['source','guides','ready']: (root/name).mkdir(parents=True,exist_ok=True)
town=json.loads((task/'ui_review_input/reference_world_frontend_20261010/playable_prototype/town_neighborhood_layout.json').read_text(encoding='utf-8'))
source=json.loads((task/'远征/data/main_world_maps.json').read_text(encoding='utf-8'))
field=source['maps']['maple_road']
regions={
'lorin_wilds':{'extent':town['world_size'],'layout':town,'routes':town['routes'],'river':{},'version':6},
'maple_road':{'extent':[field['map_cols']*48,field['map_rows']*48],'layout':{},'routes':field['flat_routes'],'river':field['river'],'version':5}}
jobs=[]
for map_id,region in regions.items():
 W,H=region['extent'];cols=2;rows=4;cw=math.ceil(W/cols);ch=math.ceil(H/rows)
 for row in range(rows):
  for col in range(cols):
   x,y=col*cw,row*ch;w,h=min(cw,W-x),min(ch,H-y)
   jobs.append({'id':f'{map_id}_{col}_{row}','map':map_id,'core':[x,y,w,h],'context':[x-32,y-32,w+64,h+64],'master':[2*(w+64),2*(h+64)],'grid':[col,row]})
(root/'layout.json').write_text(json.dumps({'regions':regions,'ground_jobs':jobs},ensure_ascii=False,indent=2),encoding='utf-8')
(root/'baseline_main_world_maps.json').write_text(json.dumps(source,ensure_ascii=False,indent=2),encoding='utf-8')
print('Prepared',len(jobs),'local ground jobs; no formal data changed.')
