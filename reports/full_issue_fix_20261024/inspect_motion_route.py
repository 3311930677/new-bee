from pathlib import Path
import json
import sys
root=Path(__file__).resolve().parent
for identifier in sys.argv[1:]:
    data=json.loads((root/identifier/'result.json').read_text(encoding='utf-8'))
    samples=data['records'][-1]['samples']
    rows={}
    for a,b in zip(samples,samples[1:]):
        if sum((x-y)**2 for x,y in zip(a['position'],b['position']))>.01:
            row=rows.setdefault(b['animation'],{'frames':set(),'from':a['position'],'to':b['position'],'samples':0})
            row['frames'].add(b['frame']);row['to']=b['position'];row['samples']+=1
    for row in rows.values():row['frames']=sorted(row['frames'])
    print(identifier,json.dumps(rows))
