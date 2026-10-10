from pathlib import Path
import json,math,collections
root=Path(__file__).resolve().parents[2]/'ui_review_input'/'reference_world_frontend_20261010'/'playable_prototype'
d=json.loads((root/'town_neighborhood_layout.json').read_text(encoding='utf-8'))
W,H=d['world_size']
def box(b):
 x,y=b['anchor'];w,h=b['size'];return (x-w/2,y-h,x+w/2,y)
def distance(a,b):
 return math.hypot(max(a[0]-b[2],b[0]-a[2],0),max(a[1]-b[3],b[1]-a[3],0))
checks=[];pairs=[];obstacles=[]
for b in d['buildings']:
 r=box(b);checks.append({'test':b['id']+' complete silhouette inside map','pass':r[0]>=0 and r[1]>=0 and r[2]<=W and r[3]<=H})
 if not b.get('passable'):
  x,y=b['anchor'];w,h=b['size'];obstacles.append((x-w*.45,y-48,x+w*.45,y-8))
 elif b.get('portal_width'):
  x,y=b['anchor'];w,h=b['size'];p=b['portal_width']
  obstacles.extend([(x-w/2,y-48,x-p/2,y-8),(x+p/2,y-48,x+w/2,y-8)])
for i,a in enumerate(d['buildings']):
 for b in d['buildings'][i+1:]:
  gap=distance(box(a),box(b));pairs.append({'a':a['id'],'b':b['id'],'gap':round(gap,2)})
  checks.append({'test':a['id']+' / '+b['id']+' roof gap','pass':gap>=d['min_roof_gap']})
for x,y in d['trees']:
 r=(x-86.5,y-192,x+86.5,y)
 for b in d['buildings']:
  checks.append({'test':f'tree {x},{y} / '+b['id']+' roof avoidance','pass':distance(r,box(b))>=d['min_roof_gap']})
 obstacles.append((x-14,y-14,x+14,y+14))
for item in d.get('reserved_interactions',[]):
 if item.get('kind')=='npc':
  x,y=item['position'];obstacles.append((x-12,y-12,x+12,y+12))
def blocked(p,pad=12):
 x,y=p
 return x<pad or y<pad or x>W-pad or y>H-pad or any(a-pad<x<c+pad and b-pad<y<e+pad for a,b,c,e in obstacles)
step=8;cols=W//step;rows=H//step
def cell(p):return (round(p[0]/step),round(p[1]/step))
start=cell(d['spawn']);seen={start};q=collections.deque([start])
while q:
 x,y=q.popleft()
 for nx,ny in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
  n=(nx,ny)
  if n in seen or nx<0 or ny<0 or nx>=cols or ny>=rows or blocked((nx*step,ny*step)):continue
  seen.add(n);q.append(n)
for b in d['buildings']:
 checks.append({'test':b['id']+' door approach reachable','pass':cell(b['approach']) in seen and not blocked(b['approach'])})
for item in d.get('reserved_interactions',[]):
 if item.get('kind')=='npc':
  x,y=item['position'];stand=(x,y+36)
  checks.append({'test':item['id']+' conversation stand reachable','pass':cell(stand) in seen and not blocked(stand)})
 else:
  checks.append({'test':item['id']+' reserved interaction reachable','pass':cell(item['position']) in seen and not blocked(item['position'])})
checks.append({'test':'north exit reachable from town spawn','pass':cell(d['exit']['at']) in seen and not blocked(d['exit']['at'])})
checks.append({'test':'arrival from field avoids immediate exit retrigger','pass':cell(d['arrival_from_field']) in seen and math.dist(d['exit']['at'],d['arrival_from_field'])>d['exit']['radius']+80})
for i,a in enumerate(d['buildings']):
 for n in d.get('reserved_interactions',[]):
  if n.get('kind')=='npc':
   checks.append({'test':a['id']+' / '+n['id']+' interaction separation','pass':math.dist(a['approach'],n['position'])>=58+n.get('radius',52)})
for i,a in enumerate(d.get('reserved_interactions',[])):
 for b in d.get('reserved_interactions',[])[i+1:]:
  checks.append({'test':a['id']+' / '+b['id']+' interaction separation','pass':math.dist(a['position'],b['position'])>=a.get('radius',52)+b.get('radius',52)})
for i,p in enumerate(d.get('guest_slots',[])):
 checks.append({'test':'guest slot '+str(i)+' reachable','pass':cell(p) in seen and not blocked(p)})
for a,b in zip(d['routes'][0]['points'],d['routes'][0]['points'][1:]):
 steps=max(1,math.ceil(math.dist(a,b)/8))
 for i in range(steps+1):
  x=a[0]+(b[0]-a[0])*i/steps;y=a[1]+(b[1]-a[1])*i/steps
  if y>450:
   for bld in d['buildings']:
    r=box(bld)
    if r[1]<=y<=r[3]:checks.append({'test':'main road stays outside '+bld['id']+' roof','pass':x-d['routes'][0]['width']/2>=r[2]+24 or x+d['routes'][0]['width']/2<=r[0]-24})
for route in d['routes']:
 for a,b in zip(route['points'],route['points'][1:]):
  steps=max(1,math.ceil(math.dist(a,b)/8))
  for i in range(steps+1):
   p=[a[j]+(b[j]-a[j])*i/steps for j in [0,1]]
   if blocked(p):
    checks.append({'test':'route centerline clearance','pass':False,'point':p})
    break
minimum=min(pairs,key=lambda x:x['gap'])
results={'checks':checks,'roof_pairs':pairs,'min_roof_gap':minimum,'reachable_cells':len(seen),'grid_step':step,'actor_clearance':12,'failures':sum(not c['pass'] for c in checks)}
(root/'neighborhood_checks.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'checks':len(checks),'failures':results['failures'],'minimum':minimum,'failed':[c for c in checks if not c['pass']]},ensure_ascii=False))
raise SystemExit(bool(results['failures']))
