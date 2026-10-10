from pathlib import Path
import re,json
root=Path(__file__).resolve().parents[2]/'ui_review_input'/'reference_world_frontend_20261010'/'outputs'
doc=(root/'IMAGE_PROMPTS_ALL.md').read_text(encoding='utf-8')
neighborhood=json.loads((root.parent/'playable_prototype'/'town_neighborhood_layout.json').read_text(encoding='utf-8'))
production=root.parents[2]/'远征/assets/world/reference_complete_20261011/layout.json'
if production.exists():neighborhood=json.loads(production.read_text(encoding='utf-8'))['regions']['lorin_wilds']['layout']
building_sizes={b['id']:b['size'] for b in neighborhood['buildings']}
facility_prompts={'D3':'hall','D4':'archive','D5':'kennel','D6':'barracks','D7':'storehouse','D8':'stable','D9':'shrine','D10':'forge'}
styles={key:re.search(r'\*\*\{'+key+r'\}[^\n]*\n> ([^\n]+)',doc).group(1) for key in ['MAP','PROP','BLD','CHAR','ART','UIKIT','NEG']}
entries=[]
for m in re.finditer(r'\*\*((?:[A-EG]|P)\d+) ([^\n]+)\*\*\n> ([^\n]+)',doc):
    ident,title,body=m.groups()
    negatives=styles['NEG']
    if ident=='G5':
        negatives=', '.join(x.strip() for x in negatives.split(',') if x.strip() not in ['UI','frame','border'])
    text=body
    for key,value in styles.items():
        text=text.replace('{'+key+'}',negatives if key=='NEG' else value)
    if 'Avoid:' not in text:
        text+='\nAvoid: '+negatives
    if ident in ['A13','A14']:
        text=text.replace('One local view, not a compressed entire region.','Full-region concept overview only; not a runtime ground texture.')
    if ident.startswith('A') and ident not in ['A3','A5','A13','A14']:
        text+='\nLocal-view calibration: logical480x1067, requested master960x2134; never stretch this view to a full960-wide region.'
    if ident.startswith('G') and ident!='G5':
        text+='\nBackground requested master960x2134 for logical480x1067. Actor and interface are separate runtime overlays.'
    if ident.startswith('B'):
        text+='\nTwo-dimensional painted pixel color clusters, low contrast. Register actual tile size and test opposite-edge seams; do not assume generated art tiles perfectly.'
    if ident in facility_prompts:
        width,height=building_sizes[facility_prompts[ident]]
        text+=f'\nNeighborhood constraint: complete visible silhouette {width}x{height} logical world units; requested2x object artwork {2*width}x{2*height}, plus clear transparent margin outside this object box. Include eaves, steps and accessories inside the silhouette. Bottom-center step anchor. Preserve the adult door scale; do not downscale another building to fill this lot. Any silhouette change requires rechecking nearby houses and the door approach.'
    entries.append({'id':ident,'title':title,'kind':'edit' if ident in ['A3','A5'] else 'generate','prompt':text,'status':'candidate recipe','reference':'original forest; replace with approved sample references only after sample review'})
for m in re.finditer(r'^\| (F\d+) \| ([^|]+) \| ([^|]+) \|$',doc,re.M):
    ident,title,body=m.groups()
    entries.append({'id':ident,'title':title.strip(),'kind':'generate','prompt':styles['CHAR']+' '+body.strip()+'\nAvoid: '+styles['NEG'],'status':'needs enemy configuration' if ident=='F11' else 'candidate recipe','reference':'existing hero identity/proportion reference + approved forest style'})
ids=[e['id'] for e in entries]
assert len(ids)==len(set(ids)),ids
for e in entries:
    assert not re.search(r'\{(?:MAP|PROP|BLD|CHAR|ART|UIKIT|NEG)\}',e['prompt']),e['id']
entries.sort(key=lambda e:('ABCDE FGP'.replace(' ','').index(e['id'][0]),int(e['id'][1:])))
for e in entries:
    if e['id']=='B1':
        e['status']='three variants: choose one grass tone before generation'
out={'version':3,'seed_supported':False,'source':'IMAGE_PROMPTS_ALL.md','recipes':entries}
out['version']=5
out['preflight_required']=True
out['town_layout']='远征/assets/world/reference_complete_20261011/layout.json (production); prototype is historical'
out['runtime_texel_world_size']=.5
out['camera_zoom']=1.15
out['extent_policy']=neighborhood['extent_policy']
out['exit_presentation']='one roadside signpost; no gatehouse'
for e in entries:
    if e['id']=='P2':
        e['status']='requires an explicit world crop and road geometry guide before generation'
(root/'IMAGE_PROMPTS_EXPANDED.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
lines=['# Expanded image prompt recipes','', 'Generated from IMAGE_PROMPTS_ALL.md; actual tool calls are logged separately.','']
for e in entries:
    lines+=['## '+e['id']+' '+e['title'],'',e['prompt'],'']
(root/'IMAGE_PROMPTS_EXPANDED.md').write_text('\n'.join(lines),encoding='utf-8')
print('Expanded recipes:',len(entries),'; unresolved style placeholders:0; F11 intentionally deferred')
