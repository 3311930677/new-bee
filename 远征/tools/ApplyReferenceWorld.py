from pathlib import Path
import json, copy
project=Path(__file__).resolve().parents[1]
root=project/'assets/world/reference_complete_20261011'
path=project/'data/main_world_maps.json'
data=json.loads(path.read_text(encoding='utf-8'))
baseline=json.loads((root/'baseline_main_world_maps.json').read_text(encoding='utf-8'))
plan=json.loads((root/'layout.json').read_text(encoding='utf-8'))
layout=plan['regions']['lorin_wilds']['layout']
sprites=json.loads((root/'ready/sprite_manifest.json').read_text(encoding='utf-8'))
for b in layout['buildings']:
    b['size']=sprites['buildings'][b['id']]['size']
    if b['id']=='storehouse':b['anchor'][1]=916;b['approach'][1]=958
    if b['id']=='forge':b['anchor'][1]=940;b['approach'][1]=982
    # Branch paths terminate at the real door, never beneath the roof.
    for route in layout['routes']:
        if route.get('kind')=='front' and route['points'][-1][0]==b['approach'][0] and abs(route['points'][-1][1]-b['approach'][1])<=10:
            route['points'][-1]=b['approach']
layout['routes']=[layout['routes'][0]]
layout['routes'][0]['points'][0][1]=-48
for route in layout['routes'][1:]:
    if len(route['points'])==2:
        a,b=route['points']
        route['points'].insert(1,[(a[0]+b[0])/2,(a[1]+b[1])/2-16])
town=data['maps']['lorin_wilds']
town.update(map_cols=25,map_rows=44,layout_version=6,art_profile='reference_complete',camera_zoom=1.15,player_scale=.65,spawn=layout['spawn'],flat_routes=layout['routes'],plazas=[])
town['minimap_show_roads']=False
town['reference_floor_root']='res://assets/world/natural_ground_20261011/ready/'
town['city_building_positions']={b['id']:b['anchor'] for b in layout['buildings']}
town['city_building_sizes']={b['id']:b['size'] for b in layout['buildings']}
town['city_building_approaches']={b['id']:b['approach'] for b in layout['buildings']}
town['city_passable']=['gate']
town['city_npc_positions']={}
for item in layout['reserved_interactions']:
    if item['kind']=='building':
        town['city_building_positions'][item['id']]=item['position']
        town['city_building_approaches'][item['id']]=item['position']
        town['city_building_sizes'][item['id']]=sprites['props']['ledger']['size']
    elif item['kind']=='npc':town['city_npc_positions'][item['id']]=item['position']
    elif item['kind']=='quest':town['entities'][item['id']]['at']=item['position']
town['city_guest_positions']=layout['guest_slots']
layout['exit'].update(at=[616,140],sign_at=[640,160],authored_sign_position=True,caption_below=True)
layout['arrival_from_field']=[600,300]
town['spawn_points']['from_maple_road']=layout['arrival_from_field']
for e in town['exits']:
    if e['id']=='north_gate':
        e['at']=layout['exit']['at'];e['sign_at']=layout['exit']['sign_at']
        e['authored_sign_position']=True;e['caption_below']=True
# Four encounters keep their original identities/rewards and remain in the south yard.
town['monster_positions']=[[108,2050],[248,2050],[850,2030],[1100,2050]]
town['reference_scenery']=[{'id':'green_tree','at':p,'solid':True} for p in [[350,300],[850,300],[1048,1146],[148,1980],[1048,1890]]]
town['reference_scenery'] += [{'id':a,'at':p,'group':'foliage'} for a,p in [('bush',[92,870]),('bush',[1110,1550]),('fern',[94,1530]),('fern',[1080,830])]]
town['reference_scenery'] += [{'id':'nighttable','at':[728,1298],'group':'props'}]
field=data['maps']['maple_road']
field.update(art_profile='reference_complete',layout_version=5,camera_zoom=1.15,player_scale=.65)
field['flat_routes']=[field['flat_routes'][0]]
field['minimap_show_roads']=False
field['reference_floor_root']='res://assets/world/natural_ground_20261011/ready/'
field['reference_scenery']=[{'id':a,'at':p,'solid':True} for a,p in [('green_tree',[250,1900]),('green_tree',[750,1950]),('green_tree',[295,1430]),('green_tree',[865,1645]),('pine',[90,1180]),('gold_maple',[745,955]),('gold_maple',[285,795]),('red_maple',[265,480]),('red_maple',[730,280]),('red_maple',[865,245])]]
field['reference_scenery'] += [{'id':a,'at':p,'group':g} for a,p,g in [('bush',[300,1830],'foliage'),('bush',[760,1750],'foliage'),('fern',[290,1430],'foliage'),('bush',[725,730],'foliage'),('fern',[325,395],'foliage'),('rocks',[135,1000],'props'),('rocks',[800,1390],'props')]]
# Migration only changes position; all combat, quest, respawn and inventory records survive.
for id in ['lorin_wilds','maple_road']:
    new=data['maps'][id];old=baseline['maps'][id]
    anchors=[{'old':old['spawn'],'new':new['spawn']}]
    for key in ['city_building_positions','city_npc_positions','spawn_points']:
        for name,at in old.get(key,{}).items():
            if name in new.get(key,{}):anchors.append({'old':at,'new':new[key][name]})
    for name,row in old.get('entities',{}).items():
        if name in new.get('entities',{}):anchors.append({'old':row['at'],'new':new['entities'][name]['at']})
    new['position_migration']={'from_version':old.get('layout_version',1),'extent':[old['map_cols']*48,old['map_rows']*48],'anchors':anchors}
    new['background']=new['reference_floor_root']+id+'_floor.png'
    plan['regions'][id]['routes']=new['flat_routes']
    plan['regions'][id]['extent']=[new['map_cols']*48,new['map_rows']*48]
# Guard the functional contract: no IDs, actions, costs, conditions or spawn stats disappear.
for id in ['lorin_wilds','maple_road']:
    old=baseline['maps'][id];new=data['maps'][id]
    assert set(old.get('entities',{}))==set(new.get('entities',{}))
    for name,row in old.get('entities',{}).items():assert {k:v for k,v in row.items() if k!='at'}=={k:v for k,v in new['entities'][name].items() if k!='at'}
    assert [(e['id'],e['to'],e.get('arrival'),e.get('requires_story')) for e in old['exits']]==[(e['id'],e['to'],e.get('arrival'),e.get('requires_story')) for e in new['exits']]
    for key in ['spawn_slots','monster','monster_id','monster_sprite','enemy_spawns','monster_count']:
        if key in old:assert old[key]==new[key]
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(root/'layout.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('REFERENCE_WORLD_DATA_APPLIED original entity/exit/encounter contracts preserved')
