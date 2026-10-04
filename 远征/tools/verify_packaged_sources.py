"""Ensure a fresh Git checkout contains the source of every packaged resource."""
import json
import struct
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
repo = root.parent
tracked = {p.decode('utf-8') for p in subprocess.check_output(['git', 'ls-files', '-z'], cwd=repo).split(b'\0') if p}
names = []
with (root / 'exports/windows/Yuanzheng.pck').open('rb') as stream:
    header = struct.unpack('<6I2Q', stream.read(40))
    stream.seek(header[-1])
    count, = struct.unpack('<I', stream.read(4))
    for _ in range(count):
        length, = struct.unpack('<I', stream.read(4))
        names.append(stream.read(length).rstrip(b'\0').decode('utf-8').removeprefix('res://'))
        stream.seek(36, 1)
required = set()
for name in names:
    if name.startswith('.godot/'):
        continue
    if name == 'project.binary':
        required.add('project.godot')
        continue
    if name.endswith('.import'):
        required.update([name, name.removesuffix('.import')])
    elif name.endswith('.remap'):
        required.add(name.removesuffix('.remap'))
    elif (root / name).is_file():
        required.add(name)
missing = sorted(name for name in required if root.name + '/' + name not in tracked)
out = root / 'tools/_logs/packaged_source_audit.json'
out.write_text(json.dumps({'required':len(required),'missing':missing}, ensure_ascii=True, indent=2), encoding='utf-8')
assert not missing, 'Packaged source absent from Git: ' + json.dumps(missing, ensure_ascii=True)
print('PACKAGED_SOURCES_OK', len(required), 'source files available in Git')
