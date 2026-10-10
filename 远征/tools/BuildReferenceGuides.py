from pathlib import Path
import json
root=Path(__file__).resolve().parents[1];a=root/'assets/world/reference_rebuild_20261010';(a/'source').mkdir(parents=True,exist_ok=True)
d=json.loads((root/'data/main_world_maps.json').read_text(encoding='utf8'));maps=d['maps'];maps={m['id']:m for m in maps} if isinstance(maps,list) else maps
patches={'maple_road':[0,1020,960,1092],'lorin_wilds':[0,580,960,860]}
for id,(ox,oy,w,h) in patches.items():
 row=maps[id];svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 {oy} {w} {h}"><rect x="0" y="{oy}" width="{w}" height="{h}" fill="#7ba150"/>']
 if id=='lorin_wilds':svg.append('<path d="M300 940 Q490 910 750 940 L750 1220 Q550 1310 300 1200 Z" fill="#c3b79b"/>')
 for r in row['flat_routes']:
  pts=' '.join(f'{x},{y}' for x,y in r['points']);svg.append(f'<polyline points="{pts}" fill="none" stroke="#d6bf83" stroke-width="{r["width"]}" stroke-linejoin="round" stroke-linecap="round"/>')
 if id=='maple_road':svg.append('<path d="M0 1200 L960 1260" stroke="#789da3" stroke-width="64"/>');svg.append('<path d="M500 1175 L500 1290" stroke="#c1b494" stroke-width="72"/>')
 svg.append('</svg>');(a/(id+'_guide.svg')).write_text(''.join(svg),encoding='utf8')
(a/'patches.json').write_text(json.dumps(patches,indent=2),encoding='utf8')
print('REFERENCE_GUIDES_OK 2 sample patches, actual suggested route coordinates')
