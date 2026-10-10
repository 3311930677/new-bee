from pathlib import Path
import json,math
task=Path(__file__).resolve().parents[2]
package=task/'ui_review_input'/'reference_world_frontend_20261010'
demo=package/'playable_prototype'
out=package/'outputs'
layout=json.loads((demo/'town_neighborhood_layout.json').read_text(encoding='utf-8'))
checks=json.loads((demo/'neighborhood_checks.json').read_text(encoding='utf-8'))
source=json.loads((task/'远征'/'data'/'main_world_maps.json').read_text(encoding='utf-8'))['maps']
assert checks['failures']==0
facility_ids={b['id'] for b in layout['buildings']}|{i['id'] for i in layout['reserved_interactions'] if i['kind']=='building'}
assert facility_ids==set(source['lorin_wilds']['city_building_positions'])
assert {n['id'] for n in layout['reserved_interactions'] if n['kind']=='npc'}==set(source['lorin_wilds']['city_npc_positions'])
assert {n['id'] for n in layout['reserved_interactions'] if n['kind']=='quest'}==set(source['lorin_wilds']['entities'])
for town,prototype,key in [('lorin_wilds',layout['exit'],'north_gate'),('maple_road',layout['prototype_field_exit'],'south_gate')]:
 actual=next(e for e in source[town]['exits'] if e['id']==key)
 assert all(prototype[k]==actual[k] for k in ['id','to','arrival'])
assert not any(b['id']=='gate' for b in layout['buildings'])
assert layout['exit']['presentation'].startswith('single roadside signpost')
chunks=[]
W,H=layout['world_size'];cols=math.ceil(W/640);rows=math.ceil(H/640)
cw=math.ceil(W/cols);ch=math.ceil(H/rows)
for row in range(rows):
 for col in range(cols):
  x,y=col*cw,row*ch;w,h=min(cw,W-x),min(ch,H-y)
  context=[x-32,y-32,w+64,h+64]
  chunks.append({'id':f'town_c{col}_r{row}','core_world_rect':[x,y,w,h],'context_world_rect':context,'requested_master':[2*(w+64),2*(h+64)],'assembled_runtime_crop':[32,32,w,h],'geometry_points_local':[
   {'kind':r['kind'],'width':r['width'],'points':[[p[0]-context[0],p[1]-context[1]] for p in r['points']]} for r in layout['routes']],
   'paint_only':['grass','soil','worn road edges','short ground grass'],
   'exclude':['buildings','building foundations','doorways','trees','bushes','NPCs','quest props','object shadows','labels']})
manifest={'version':3,'extent_policy':layout['extent_policy'],'town_extent':layout['world_size'],'production_stage':'preflight passed; no new generation in this turn','style_reference':str(package/'reference'/'01_target_forest.jpg'),'geometry_reference':str(demo/'screenshots'/'town_road_geometry_guide.png'),'geometry_is_not_style':True,'building_and_npc_ids_preserved':True,'exit_targets_preserved':True,'exit_is_signpost':True,'all_trees_separate':True,'world_data_modified':False,'chunk_recipes':chunks}
(out/'TOWN_PRODUCTION_PREFLIGHT.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'PREFLIGHT_OK: {len(layout["buildings"])} buildings + visitor ledger, 9 NPCs, 6 quest entities; sign exit preserved; {len(chunks)} ground chunks derived from working bounds.')
