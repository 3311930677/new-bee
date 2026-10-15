"""Read-only analysis of original PNG sheets; never modifies image pixels."""
import json
import importlib.util
from pathlib import Path
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parent
spec = json.loads((root / 'ui_kit_spec.json').read_text(encoding='utf-8-sig'))
loader = importlib.util.spec_from_file_location('restorer', r'D:\new-bee\ui_design_input\round1_main_scenes\tools\restore_ui_kit.py')
restorer = importlib.util.module_from_spec(loader)
loader.loader.exec_module(restorer)
results = {}
for sheet in dict.fromkeys(it['sheet'] for it in spec['items'].values()):
    im = Image.open(root / (sheet + '.png'))
    rgb = np.asarray(im.convert('RGB'))
    fg, labels, boxes = restorer.components(rgb)
    bg = restorer.key(rgb)
    exact = (rgb == (255,0,255)).all(axis=2)
    row = {'format':im.format, 'canvas':list(im.size), 'components':len(boxes), 'background_exact_percent':round(float(exact[bg].mean()*100),3), 'items':{}}
    used=set()
    for name,it in spec['items'].items():
        if it['sheet'] != sheet: continue
        gx,gy,gw,gh=it['guide_box']
        cx,cy=gx+gw/2,gy+gh/2
        cand=[b for b in boxes if b[0] not in used]
        if not cand:
            row['items'][name]={'error':'missing component'}
            continue
        b=min(cand,key=lambda b:((b[1]+b[3])/2-cx)**2+((b[2]+b[4])/2-cy)**2)
        idx,x0,y0,x1,y1=b
        used.add(idx)
        aw,ah=it['art']
        row['items'][name]={'guide_box':it['guide_box'], 'source_box':[int(x0),int(y0),int(x1-x0),int(y1-y0)], 'aspect_error':round(abs((x1-x0)/(y1-y0)/(aw/ah)-1),4), 'overflow_px':[max(0,gx-x0),max(0,gy-y0),max(0,x1-gx-gw),max(0,y1-gy-gh)]}
    results[sheet]=row
results = json.loads(json.dumps(results, default=lambda v: int(v)))
(root/'generation_qa.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(results,ensure_ascii=False))
