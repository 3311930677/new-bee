"""Apply the reviewed two-map layout, retaining IDs, quest rules and rewards."""
from pathlib import Path
import json,copy,math
root=Path(__file__).resolve().parents[1];out=root/'shots/reference_rebuild_20261010';out.mkdir(parents=True,exist_ok=True)
p=root/'data/main_world_maps.json';data=json.loads(p.read_text(encoding='utf8'));before=copy.deepcopy(data)
backup=out/'baseline_layout.json'
if not backup.exists():backup.write_text(json.dumps(before,ensure_ascii=False,indent=2),encoding='utf8')
maps=data['maps'];maps={m['id']:m for m in maps} if isinstance(maps,list) else maps
town=maps['lorin_wilds'];field=maps['maple_road']
old={id:copy.deepcopy(maps[id]) for id in ['lorin_wilds','maple_road']}
def route(points,width=128):return dict(points=points,width=width)
town.update(map_rows=40,layout_version=5,camera_zoom=1.0,player_scale=.65,reference_art=True,spawn=[500,1050],spawn_points={'from_maple_road':[480,450]})
town['city_building_positions']={'gate':[480,300],'stable':[170,480],'barracks':[790,470],'storehouse':[170,720],'forge':[800,740],'hall':[360,850],'archive':[200,1320],'kennel':[770,1330],'shrine':[480,1500]}
town['city_npc_positions']={'npc_guard':[420,435],'npc_stablemaster':[275,570],'npc_mentor':[700,590],'npc_smith':[870,840],'npc_steward':[450,990],'npc_child':[320,1110],'npc_warden':[560,1210],'npc_scribe':[110,1440],'npc_keeper':[650,1450]}
town['city_guest_positions']=[[400,1190],[470,1270]]
town['monster_positions']=[[110,1650],[300,1680],[660,1680],[850,1650]]
town['reference_doors']={'gate':[480,400],'stable':[200,560],'barracks':[790,560],'storehouse':[170,800],'forge':[780,820],'hall':[360,950],'archive':[200,1420],'kennel':[740,1430],'shrine':[480,1440]}
town['reference_building_sizes']={'hall':[320,230],'gate':[380,280]}
for e in town['exits']:
 if e['id']=='north_gate':e['at']=[480,250]
town['exit']=[480,250]
town_entities={'a4_secret_oralbook_step_1':[330,450],'a4_secret_oralbook_feedback_0':[290,1450],'a4_rel_nighttable_step_1':[590,920],'a4_rel_nighttable_step_4':[640,1135],'a4_rel_nighttable_step_5':[745,1135],'a4_rel_nighttable_feedback_0':[690,1190]}
for key,point in town_entities.items():town['entities'][key]['at']=point
town['flat_routes']=[route([[480,250],[470,560],[570,730],[540,900],[500,1050],[500,1260],[480,1460],[480,1640]],144),route([[470,560],[275,570],[200,560]],88),route([[470,560],[700,590],[790,560]],88),route([[550,740],[170,800]],88),route([[550,780],[780,820],[870,840]],88),route([[540,980],[450,990],[360,950]],88),route([[500,1260],[200,1420],[110,1440]],88),route([[500,1320],[650,1450],[740,1430]],88),route([[480,1460],[300,1600],[110,1650]],64),route([[480,1460],[660,1600],[850,1650]],64)]
town['plazas']=[{'rect':[300,930,450,340]}]
field.update(map_rows=44,layout_version=4,camera_zoom=1.0,player_scale=.65,reference_art=True,spawn=[480,1860],spawn_points={'from_city':[480,1860],'from_broken_slope':[480,270],'from_old_salt_road':[840,985]})
field['monster_positions']=[[200,1460],[780,1560],[760,680],[200,820],[760,420]]
field['monster_height']=52
field['river']={'y':1230,'half':32,'points':[[0,1200],[960,1260]],'crossing':[464,536]}
exit_points={'south_gate':[480,1990],'north_path':[480,150],'east_salt_path':[940,970]}
for e in field['exits']:e['at']=exit_points[e['id']]
field['exit']=[480,150]
field_entities={'a1_chime':[210,1640],'a1_roots_b':[660,1720],'a1_trade_bridge_step_1':[430,1300],'a1_trade_bridge_step_2':[575,1300],'a1_trade_bridge_step_3':[500,1235],'a1_trade_bridge_feedback_0':[500,1160],'act1_waystone_cache':[230,1080],'trade_maple_post':[625,1050],'a1_postrider':[730,1080],'a4_waylight':[540,640],'a1_roots_a':[240,600]}
for key,point in field_entities.items():field['entities'][key]['at']=point
field['flat_routes']=[route([[480,1990],[480,1860],[510,1700],[440,1530],[500,1350],[500,1230],[500,1100],[570,1000],[480,820],[540,640],[470,420],[480,270],[480,150]],124),route([[500,1040],[700,1000],[840,985],[940,970]],80),route([[480,1650],[330,1660],[210,1640]],44),route([[510,1720],[660,1720]],44),route([[500,1090],[360,1060],[230,1080]],44),route([[540,1000],[625,1050],[730,1080]],64),route([[500,620],[360,600],[240,600]],44)]
for id,row in [('lorin_wilds',town),('maple_road',field)]:
 row['clear_rects']=[[e['at'][0]-54,e['at'][1]-54,108,108] for e in row['entities'].values()]
 row['reference_migration']={}
 for kind in ['spawn_points','city_npc_positions','city_building_positions']:
  for key,point in old[id].get(kind,{}).items():
   if key in row.get(kind,{}):row['reference_migration'][kind+':'+key]={'old':point,'new':row[kind][key]}
 row['reference_migration']['spawn']={'old':old[id]['spawn'],'new':row['spawn']}
 for key,e in old[id].get('entities',{}).items():row['reference_migration']['entity:'+key]={'old':e['at'],'new':row['entities'][key]['at']}
 for a,b in zip(old[id]['exits'],row['exits']):
  assert {k:v for k,v in a.items() if k!='at'}=={k:v for k,v in b.items() if k!='at'}
  row['reference_migration']['exit:'+a['id']]={'old':a['at'],'new':b['at']}
 if id=='maple_road':
  assert min(math.dist(a,b) for a in row['spawn_points'].values() for b in row['monster_positions'])>=300
 for key,e in row['entities'].items():assert {k:v for k,v in e.items() if k!='at'}=={k:v for k,v in old[id]['entities'][key].items() if k!='at'}
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
for id,row in maps.items():
 if id not in old:
  original=before['maps'][id] if isinstance(before['maps'],dict) else next(m for m in before['maps'] if m['id']==id)
  assert row==original
(out/'migration_table.json').write_text(json.dumps({id:maps[id]['reference_migration'] for id in old},ensure_ascii=False,indent=2),encoding='utf8')
print('REFERENCE_LAYOUT_OK 2 maps; exits,conditions,quest IDs and other regions retained')
