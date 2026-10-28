"""Validate current integrated actor evidence, not the retired split-rider fixture."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
result = json.loads((root / 'tools/_logs/integrated_mount_results.json').read_text(encoding='utf-8'))
assert result['failures'] == 0
assert {(r['mount'], r['role']) for r in result['records']} == {(m, r) for m in ['horse','bear'] for r in ['zs','ck','fs','fz']}
for row in result['records']:
    assert len(row['animations']) == 12
    for animation in row['animations']:
        action, direction = animation['animation'].split('_')
        assert direction in ['down','left','right','up']
        assert set(animation['seen']) == set(range({'idle':4,'walk':8,'run':12}[action]))
        screenshot = root / 'shots/full_issue_fix_20261024/mount' / (row['mount'] + '_' + row['role'] + '_' + animation['animation'] + '.png')
        assert screenshot.is_file(), screenshot
print('MOUNT_MOTION_QA_OK 8 integrated actors, 96 sequential idle/walk/run states')
