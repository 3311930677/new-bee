from pathlib import Path
import json,math
root=Path(__file__).resolve().parents[2]/'ui_review_input'/'reference_world_frontend_20261010'/'playable_prototype'
path=root/'town_neighborhood_layout.json'
d=json.loads(path.read_text(encoding='utf-8'))
assert d.get('extent_policy')=='fit_content'
align=d.get('extent_alignment',48)
right=max([b['anchor'][0]+b['size'][0]/2 for b in d['buildings']]+[p[0]+86.5 for p in d['trees']]+[d['exit']['sign_at'][0]+32])
bottom=max([b['anchor'][1] for b in d['buildings']]+[p[1]+14 for p in d['trees']]+[i['position'][1]+24 for i in d['reserved_interactions']])
minimum=d['min_world_size'];padding=d['edge_padding']
width=max(minimum[0],math.ceil((right+padding['right'])/align)*align)
height=max(minimum[1],math.ceil((bottom+padding['bottom'])/align)*align)
d['world_size']=[width,height]
d['routes'][0]['points'][-1][1]=height-padding['bottom']
d['extent_calculation']={'rightmost_content':right,'bottommost_content':bottom,'description':'Working extent derived from content plus padding; not a frozen art canvas.'}
path.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Working town extent:',width,height,'; main road:',d['routes'][0]['width'],'; gatehouse removed')
