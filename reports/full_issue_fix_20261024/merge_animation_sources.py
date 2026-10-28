import json
from pathlib import Path
root=Path(__file__).resolve().parent
jobs=json.loads((root/'mount_sources.json').read_text(encoding='utf-8'))
jobs+=json.loads((root/'recovered_horse_sources.json').read_text(encoding='utf-8'))
for path in sorted(root.glob('generated_*.json')):jobs.append(json.loads(path.read_text(encoding='utf-8')))
for path in sorted(root.glob('replacement_*.json')):jobs.append(json.loads(path.read_text(encoding='utf-8')))
rows={('_'.join(j[k] for k in ['mount','role','direction'])):j for j in jobs}
for path in sorted(root.glob('augmentation_*.json'))+sorted(root.glob('augmentation2_*.json')):
    if path.name=='augmentation_jobs.json':continue
    supplement=json.loads(path.read_text(encoding='utf-8'))
    key='_'.join(supplement[k] for k in ['mount','role','direction'])
    rows[key].setdefault('supplements',[])
    rows[key]['supplements']=[s for s in rows[key]['supplements'] if s['indices']!=supplement['indices']]+[supplement]
(root/'mount_sources.json').write_text(json.dumps(list(rows.values()),ensure_ascii=False,indent=2),encoding='utf-8')
print('Unique animation source sheets:',len(rows))
