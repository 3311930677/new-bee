"""Freeze the same ready-before-source resource precedence used by the editor.

Exported packages must not depend on platform directory enumeration or remap names.
Run before exporting after adding named generated resources.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
BATCHES = ['generated_001_100','generated_101_200','generated_201_333',
           'generated_334_341','generated_342_353','generated_362_xajh']

def build():
    index = {}
    for phase in ['ready', 'source']:
        for batch in BATCHES:
            folder = ROOT / 'image' / batch / phase
            paths = sorted(folder.glob('*/*.png')) + sorted(folder.glob('*.png')) if phase == 'ready' else sorted(folder.glob('*.png'))
            for path in paths:
                key = path.name.split('_', 1)[1] if phase == 'source' and path.name.split('_', 1)[0].isdigit() else path.name
                index.setdefault(key, 'res://' + path.relative_to(ROOT).as_posix())
    target = ROOT / 'data' / 'resource_manifest.json'
    target.write_text(json.dumps(index, ensure_ascii=False, indent=2, sort_keys=True)+'\n', encoding='utf-8')
    print(f'RESOURCE_MANIFEST_OK entries={len(index)}')
    return index

if __name__ == '__main__':
    build()
