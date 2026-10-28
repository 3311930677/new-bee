"""Consolidate final accepted jobs and preserve source masters in the ignored folder."""
from pathlib import Path
import hashlib
import json
import shutil

report = Path(__file__).resolve().parent
project = report.parents[1] / '远征'
assets = project / 'assets/full_issue_fix_20261024'
manifest_path = assets / 'generation_manifest.json'
original = json.loads(manifest_path.read_text(encoding='utf-8'))
jobs = []

def add(identifier, prompt, master, texture=None):
    source = Path(master)
    destination = assets / 'source' / (identifier + '.png')
    if not destination.exists(): shutil.copy2(source, destination)
    assert hashlib.sha256(source.read_bytes()).digest() == hashlib.sha256(destination.read_bytes()).digest()
    entry = {'id':identifier, 'prompt':prompt, 'generated_master':str(source),
             'workspace_master':destination.relative_to(project).as_posix(),
             'master_sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}
    if texture:
        ready = project / texture.removeprefix('res://')
        entry.update(texture=texture, texture_sha256=hashlib.sha256(ready.read_bytes()).hexdigest())
    jobs.append(entry)

login = next(row for row in original['jobs'] if row['id'] == 'login_background')
add('login_background', login['prompt'], login.get('generated_master', login.get('source')),
    'res://assets/full_issue_fix_20261024/ready/login_background.png')
for row in json.loads((report / 'mount_sources.json').read_text(encoding='utf-8')):
    identifier = '_'.join(row[k] for k in ['mount','role','direction'])
    add(identifier, row['prompt'], row['path'], 'res://assets/full_issue_fix_20261024/ready/' + identifier + '.png')
    for supplement in row.get('supplements', []):
        add(identifier + '_supplement_' + str(supplement['indices'][0]), supplement['prompt'], supplement['path'])
        jobs[-1]['replaced_cel_indices'] = supplement['indices']
for row in json.loads((report / 'fish_preparation.json').read_text(encoding='utf-8')):
    add('itm_' + row['id'], row['prompt'], row['path'], row['texture'])
manifest = {'mode':'built-in imagegen', 'scope':'Final accepted masters only; runtime uses ready assets; source excluded by .gdignore.', 'jobs':jobs}
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('FINAL_PROVENANCE_OK', len(jobs), 'masters;', sum('texture' in row for row in jobs), 'runtime images')
