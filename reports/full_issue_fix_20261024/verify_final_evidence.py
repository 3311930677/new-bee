"""Check scope and artifact integrity; leaves visual judgment to rendered review."""
from pathlib import Path
import json,hashlib
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
REPORT=Path(__file__).resolve().parent
PROJECT=ROOT/'远征'
mounts=json.loads((REPORT/'mount_preparation.json').read_text(encoding='utf-8'))
assert len(mounts)==32
assert not json.loads((REPORT/'mount_rejected.json').read_text(encoding='utf-8'))
for row in mounts:
    assert row['unique_frames']==24
    path=PROJECT/row['texture'].removeprefix('res://')
    assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']
    im=Image.open(path).convert('RGBA')
    assert im.size==(768,1152)
    alpha_min,alpha_max=im.getchannel('A').getextrema()
    assert alpha_min==0 and alpha_max>=240
    for y in range(6):
        for x in range(4):
            bbox=im.crop((x*192,y*192,(x+1)*192,(y+1)*192)).getchannel('A').getbbox()
            assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<192 and bbox[3]<192
result=json.loads((PROJECT/'tools/_logs/integrated_mount_results.json').read_text(encoding='utf-8'))
assert result['failures']==0 and len(result['records'])==8
for actor in result['records']:
    assert len(actor['animations'])==12
    for animation in actor['animations']:
        count={'idle':4,'walk':8,'run':12}[animation['animation'].split('_')[0]]
        assert set(animation['seen'])==set(range(count))
ui=json.loads((PROJECT/'tools/_logs/full_issue_fix_ui_results.json').read_text(encoding='utf-8'))
maps=json.loads((PROJECT/'tools/_logs/asset_completion_results.json').read_text(encoding='utf-8'))
assert ui['failures']==0 and maps['failures']==0 and len(maps['maps'])==34
props=json.loads((PROJECT/'tools/_logs/map_prop_states_results.json').read_text(encoding='utf-8'))
assert props['failures']==0 and props['objects']==34 and len(props['records'])==136
assert all(row['visible']==row['expected_visible'] for row in props['records'])
summary={'mount_sheets':32,'authored_cels':768,'runtime_animations':96,'ui_checks':ui['checks'],'map_cases':34,'map_checks':maps['checks'],'prop_objects':34,'prop_state_cases':136,'prop_state_checks':props['checks']}
(REPORT/'scope_integrity.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print('FINAL_EVIDENCE_OK',summary)
