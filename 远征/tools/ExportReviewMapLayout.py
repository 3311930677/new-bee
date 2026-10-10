from pathlib import Path
import json,math
root=Path(__file__).resolve().parents[1]
cfg=json.loads((root/'data/main_world_maps.json').read_text(encoding='utf-8'))
positions={'lorin_wilds':[200,270],'maple_road':[440,320],'broken_slope':[540,620],'stele_cavern':[280,650],'old_salt_road':[740,300],'shenyuan_port':[1080,280],'tideflat':[1260,490],'tidal_gate':[1090,720],'red_sand_route':[850,640],'frost_post':[780,960],'rift_mine_road':[1080,990],'rift_mine_vault':[1260,1110],'frost_boardwalk':[760,1240],'frost_pass':[1010,1360],'abyss_ring':[1250,1330],'stele_entry':[1220,750],'stele_resonance':[1290,930],'stele_core':[1300,1510]}
maps=cfg['maps'];maps={m['id']:m for m in maps} if isinstance(maps,list) else maps
nodes=[];routes=[];seen=set()
for row in cfg['regions']:
 key=row['id'];nodes.append({'id':key,'name':row['name'],'point':positions[key],'original_point':row['point'],'level':row['level'],'kind':row['kind']})
 for e in maps[key].get('exits',[]):
  to=e.get('to','')
  if to not in positions:continue
  pair=tuple(sorted([key,to]))
  if pair in seen:continue
  seen.add(pair);a,b=positions[key],positions[to];dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy);bend=min(76,length*.22);nx,ny=-dy/length,dx/length
  controls=[[round(a[0]+dx*.3+nx*bend),round(a[1]+dy*.3+ny*bend)],[round(a[0]+dx*.7-nx*bend*.25),round(a[1]+dy*.7-ny*bend*.25)]]
  routes.append({'from':key,'to':to,'controls':controls})
table={'canvas':[1440,1600],'visual_layout_only':True,'nodes':nodes,'routes':routes}
p=root/'assets/ui/full_review_fixes_20261009/map_layout.json';p.write_text(json.dumps(table,ensure_ascii=False,indent=2),encoding='utf-8')
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1600" viewBox="0 0 1440 1600"><rect width="1440" height="1600" fill="#26392f"/>']
for r in routes:
 a,b=positions[r['from']],positions[r['to']];c,d=r['controls'];svg.append(f'<path d="M{a[0]},{a[1]} C{c[0]},{c[1]} {d[0]},{d[1]} {b[0]},{b[1]}" stroke="#d5b78a" stroke-width="12" fill="none"/>')
for i,row in enumerate(nodes):
 x,y=row['point'];svg.append(f'<circle cx="{x}" cy="{y}" r="32" fill="#d8c6a0"/><text x="{x}" y="{y+8}" fill="#201d18" font-size="26" text-anchor="middle">{i+1}</text>')
svg.append('</svg>');(root/'assets/ui/full_review_fixes_20261009/map_guide.svg').write_text(''.join(svg),encoding='utf-8')
print('MAP_LAYOUT',len(nodes),len(routes))
