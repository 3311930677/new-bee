"""List explicit runtime/test/doc changes without staging source media or exports."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = Path(__file__).resolve().parents[1].name + '/'
raw = subprocess.check_output(['git', 'status', '--porcelain=v1', '-z', '--untracked-files=all'], cwd=ROOT)
paths = [item.decode('utf-8')[3:] for item in raw.split(b'\0') if item]
selected = []
for path in paths:
    if path == '.gitignore':
        selected.append(path)
        continue
    if not path.startswith(GAME):
        continue
    local = path[len(GAME):]
    include = local in ['.gitignore', 'project.godot', 'icon.svg', 'export_presets.cfg']
    include |= local.startswith(('data/', 'src/', 'assets/audio/', 'assets/fonts/', 'assets/ui/',
                                  'image/main_world/', 'image/background/', 'image/map_proc/', 'image/mounts/'))
    include |= local.startswith('image/generated_362_xajh/ready/')
    include |= local.startswith('image/role/') and '/source/' not in local and '/walk_4dir_review/' not in local
    include |= local.startswith('tools/') and local.count('/') == 1 and Path(local).suffix in ['.gd', '.uid', '.tscn', '.py', '.ps1', '.cmd']
    include |= local.startswith('docs/plans/2026-10-') and Path(local).suffix == '.md'
    include |= local.startswith(('shots/three_roles_video_20261004/', 'shots/shuangyu_front_back_video_v20_20261004/')) and local.endswith('/runtime_source_checks.json')
    if local.startswith('src/preview/') and local not in ['src/preview/WalkActor.gd', 'src/preview/WalkActor.gd.uid']:
        include = False
    if include:
        selected.append(path)
assert not any('/exports/' in p or '/_logs/' in p or p.endswith(('.mp4', '.zip', '.keystore')) for p in selected)
assert all((ROOT / p).is_file() for p in selected), 'Review deletions separately'
out = Path(__file__).parent / '_logs/body_commit_manifest.json'
out.write_text(json.dumps(selected, ensure_ascii=True, indent=2), encoding='utf-8')
out.with_suffix('.nul').write_bytes(b'\0'.join(p.encode('utf-8') for p in selected)+b'\0')
print('BODY_MANIFEST_READY', len(selected), 'files', sum((ROOT / p).stat().st_size for p in selected), 'bytes')
