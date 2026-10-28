"""Verify exported resources, architecture, QA exclusion and equipment-only icon diff."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import zipfile

report = Path(__file__).resolve().parent
root = report.parents[1]
project = root / '远征'
evidence = []
for filename, architecture, qa in [('Yuanzheng-fullfix.apk','arm64-v8a',False),('Yuanzheng-fullfix-audit.apk','x86_64',True)]:
    path = report / filename
    with zipfile.ZipFile(path) as apk:
        names = set(apk.namelist())
        assert {n.split('/')[1] for n in names if n.startswith('lib/') and n.endswith('.so')} == {architecture}
        assert bool([n for n in names if n.startswith('assets/src/qa/')]) == qa
        assert not [n for n in names if re.search(r'assets/(?:assets/(?:full_issue_fix_20261024|completion_20261024)/source/|tools/|shots/)', n)]
        for data in ['resource_manifest.json','equip.json','exchange.json','asset_completion_20261024.json','mount_animation_20261024.json','pet_showcase_anchors.json']:
            assert apk.read('assets/data/' + data) == (project / 'data' / data).read_bytes(), (filename, data)
        count = 0
        for folder in ['completion_20261024', 'full_issue_fix_20261024']:
            for texture in (project / 'assets' / folder / 'ready').rglob('*.png'):
                resource = texture.relative_to(project).as_posix()
                import_name = 'assets/' + resource + '.import'
                assert import_name in names, (filename, resource)
                remap = apk.read(import_name).decode('utf-8')
                imported = re.findall(r'path(?:\.[\w]+)?="res://([^"]+\.ctex)"', remap)
                assert imported, resource
                for target in imported:
                    assert 'assets/' + target in names, (filename, resource, target)
                    assert len(apk.read('assets/' + target)) > 100, resource
                count += 1
        evidence.append({'apk':filename,'architecture':architecture,'size':path.stat().st_size,
                         'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'ready_textures':count,
                         'data_identical':True,'qa_included':qa,'new_source_masters_excluded':True})
before = json.loads(subprocess.check_output(['git','show','HEAD:远征/data/equip.json'], cwd=root))
after = json.loads((project / 'data/equip.json').read_text(encoding='utf-8'))
changed = []
for left, right in zip(before['templates'],after['templates'],strict=True):
    a = dict(left); b = dict(right)
    if a.pop('icon',None) != b.pop('icon',None): changed.append(right['id'])
    assert a == b, right['id']
assert len(changed) == 6
other_before = dict(before); other_before.pop('templates')
other_after = dict(after); other_after.pop('templates')
assert other_before == other_after
(report / 'apk_integrity.json').write_text(json.dumps({'packages':evidence,'equipment_changed_icons_only':changed}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('APK_INTEGRITY_OK', json.dumps(evidence), 'equipment icon-only', len(changed))
