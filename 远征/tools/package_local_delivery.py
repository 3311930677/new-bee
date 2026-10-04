"""Package the already verified Windows build and check the delivery archive."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path(__file__).resolve().parents[1]
archive = root / 'exports/Yuanzheng-0.2.0-Windows.zip'
files = ['windows/Yuanzheng.exe', 'windows/Yuanzheng.pck', '试玩说明.txt']
with ZipFile(archive, 'w', compression=ZIP_DEFLATED, compresslevel=1) as bundle:
    for name in files:
        bundle.write(root / 'exports' / name, arcname=name)
with ZipFile(archive) as bundle:
    assert bundle.testzip() is None and set(bundle.namelist()) == set(files)
digest = hashlib.sha256()
with archive.open('rb') as stream:
    for block in iter(lambda: stream.read(8*1024*1024), b''):
        digest.update(block)
report = {'bytes':archive.stat().st_size, 'sha256':digest.hexdigest(), 'crc':True}
(root / 'tools/_logs/windows_delivery_archive.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('WINDOWS_DELIVERY_ZIP_OK', json.dumps(report))
