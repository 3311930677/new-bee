"""Read-only inventory and integrity audit for Godot 4.7 PCK/APK artifacts."""
import hashlib
import json
from pathlib import Path
import struct
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
BLOCKED = ('tools/', 'docs/', 'shots/', 'exports/', 'Godot/', 'assets_regen/',
           'src/preview/', 'image/role_lpc/', 'image/role_pixel_studio/',
           'image/role/zs/source/', 'image/role/ck/source/', 'image/role/fs/source/',
           'image/role/fz/source/', 'image/role/walk_4dir_review/', 'assets/source/', 'assets/role/')
REQUIRED = ('data/main_world_maps.json', 'data/story_quests.json', 'data/side_quests.json',
            'data/world_commissions.json', 'data/trade_contracts.json', 'data/camp_gathering.json',
            'data/run_events.json', 'data/dungeon_trials.json', 'data/oaths.json', 'project.binary')

def pck_inventory(path):
    rows = []
    with path.open('rb') as stream:
        magic, version, major, minor, patch, flags, base, directory = struct.unpack('<6I2Q', stream.read(40))
        assert magic == 0x43504447 and version in (3, 4) and (major, minor, patch) == (4, 7, 2)
        assert not flags & 1, 'Unexpected encrypted directory'
        stream.seek(directory)
        count, = struct.unpack('<I', stream.read(4))
        for _ in range(count):
            length, = struct.unpack('<I', stream.read(4))
            assert 0 < length < 32768
            name = stream.read(length).rstrip(b'\0').decode('utf-8').removeprefix('res://')
            offset, size = struct.unpack('<2Q', stream.read(16))
            digest = stream.read(16)
            file_flags, = struct.unpack('<I', stream.read(4))
            assert not file_flags, 'Unexpected encrypted or removed entry'
            rows.append((name, base + offset, size, digest))
        assert not any(name.startswith(BLOCKED) for name, *_ in rows), 'Work files leaked into package'
        names = {name for name, *_ in rows}
        assert set(REQUIRED) <= names, 'Production data missing: ' + str(set(REQUIRED) - names)
        for name, offset, size, digest in rows:
            stream.seek(offset)
            content = stream.read(size)
            assert len(content) == size and hashlib.md5(content).digest() == digest, 'Corrupt entry: ' + name
            if name.startswith('data/') and (ROOT / name).is_file():
                assert content == (ROOT / name).read_bytes(), 'Stale packaged data: ' + name
    return {'files': len(rows), 'bytes': path.stat().st_size, 'required_data': list(REQUIRED),
            'excluded_work_files': True, 'all_entry_checksums': True}

def apk_inventory(path):
    with ZipFile(path) as archive:
        assert archive.testzip() is None, 'APK CRC failure'
        names = archive.namelist()
        assert any(name.startswith('lib/arm64-v8a/') for name in names), 'ARM64 engine absent'
        assert not any(name.startswith(('lib/x86/', 'lib/x86_64/', 'lib/armeabi-v7a/')) for name in names)
        resources = {name.removeprefix('assets/'): name for name in names if name.startswith('assets/')}
        assert set(REQUIRED) <= resources.keys(), 'APK production data absent'
        assert not any(name.startswith(BLOCKED) for name in resources), 'APK contains work files'
        for name, archived_name in resources.items():
            if name.startswith('data/') and (ROOT / name).is_file():
                assert archive.read(archived_name) == (ROOT / name).read_bytes(), 'Stale APK data: ' + name
    return {'entries': len(names), 'bytes': path.stat().st_size, 'crc': True, 'arm64_only': True,
            'required_data': True, 'excluded_work_files': True}

if __name__ == '__main__':
    report = {'windows_pck': pck_inventory(ROOT / 'exports/windows/Yuanzheng.pck')}
    apk = ROOT / 'exports/android/Yuanzheng-debug.apk'
    if apk.exists(): report['android_apk'] = apk_inventory(apk)
    output = ROOT / 'tools/_logs/export_inventory.json'
    output.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('EXPORT_INVENTORY_OK', json.dumps(report))
