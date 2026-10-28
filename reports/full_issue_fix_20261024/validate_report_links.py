from pathlib import Path
import json
import re

root=Path(__file__).resolve().parent
links=[]
for name in ['修复验收报告.md','地图物件逐状态验收.md']:
    links+=re.findall(r'\]\(([^)]+)\)',(root/name).read_text(encoding='utf-8'))
missing=[link for link in links if not link.startswith(('http:','https:')) and not (root/link).exists()]
assert not missing, missing
terrain=json.loads((root.parents[1]/'远征/tools/_logs/mount_terrain_results.json').read_text(encoding='utf-8'))
assert terrain['checks']==20 and terrain['failures']==0 and len(terrain['records'])==2
print('REPORT_LINKS_OK',len(links),'TERRAIN_EVIDENCE_OK 20/0')
