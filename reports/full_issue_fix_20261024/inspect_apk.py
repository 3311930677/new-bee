from pathlib import Path
import zipfile

root = Path(__file__).resolve().parent
with zipfile.ZipFile(root / 'Yuanzheng-fullfix.apk') as apk:
    names = apk.namelist()
    print('ZIP_ENTRIES', len(names))
    print('NATIVE', [name for name in names if name.endswith('.so')])
    print('FULLFIX', [name for name in names if 'full_issue_fix_20261024' in name][:15])
    print('DATA', [name for name in names if any(key in name for key in ['mount_animation_', 'asset_completion_', 'pet_showcase_'])])
    print('QA', [name for name in names if 'src/qa/' in name][:8])
    print('SOURCES', [name for name in names if 'full_issue_fix_20261024/source/' in name or 'completion_20261024/source/' in name])
