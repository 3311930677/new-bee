"""Fetch verified official Android 15 image via configured local proxy, isolated AVD."""
from pathlib import Path
import hashlib
import json
import shutil
import urllib.request
import winreg
import xml.etree.ElementTree as ET
import zipfile

root = Path(__file__).resolve().parent
sdk = Path(r'D:\new-bee\tools\android-sdk-mobile')
xml = ET.parse(sdk / 'downloads/sys-img-android.xml').getroot()
package = next(p for p in xml if p.tag.endswith('remotePackage') and p.get('path') == 'system-images;android-35;default;x86_64')
complete = package.find('archives/archive/complete')
expected_size = int(complete.findtext('size'))
expected_hash = complete.findtext('checksum')
url = 'https://dl.google.com/android/repository/sys-img/android/' + complete.findtext('url')
key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r'Software\Microsoft\Windows\CurrentVersion\Internet Settings')
assert winreg.QueryValueEx(key, 'ProxyEnable')[0] == 1
proxy = winreg.QueryValueEx(key, 'ProxyServer')[0]
opener = urllib.request.build_opener(urllib.request.ProxyHandler({'http':'http://' + proxy, 'https':'http://' + proxy}))
archive = sdk / 'downloads/android15-aosp-x86_64.zip'
if not archive.exists() or archive.stat().st_size != expected_size:
    request = urllib.request.Request(url)
    written = archive.stat().st_size if archive.exists() else 0
    if written: request.add_header('Range', f'bytes={written}-')
    with opener.open(request, timeout=60) as source:
        if source.status != 206: written = 0
        with archive.open('ab' if written else 'wb') as output:
            prior = written // (50*1024*1024)
            while chunk := source.read(1024*1024):
                output.write(chunk); written += len(chunk)
                if written // (50*1024*1024) != prior:
                    prior = written // (50*1024*1024)
                    print('DOWNLOAD', written, '/', expected_size, flush=True)
assert archive.stat().st_size == expected_size
assert hashlib.sha1(archive.read_bytes()).hexdigest() == expected_hash
destination = sdk / 'system-images/android-35/default'
destination.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(archive) as source:
    for member in source.infolist():
        target = (destination / member.filename).resolve()
        assert target.is_relative_to(destination.resolve())
    source.extractall(destination)
avd_name = 'Yuanzheng_FullFix_Android15'
avd = sdk / 'avd' / (avd_name + '.avd')
avd.mkdir(exist_ok=True)
if not (avd / 'config.ini').exists():
    config = (sdk / 'avd/Yuanzheng_FullFix_20261025.avd/config.ini').read_text()
    config = config.replace('android-37.0', 'android-35').replace('hw.lcd.density=420', 'hw.lcd.density=240').replace('hw.lcd.height=2400', 'hw.lcd.height=1280').replace('hw.lcd.width=1080', 'hw.lcd.width=720').replace('hw.ramSize=6144', 'hw.ramSize=4096').replace('disk.dataPartition.size=8G', 'disk.dataPartition.size=4G')
    (avd / 'config.ini').write_text(config, encoding='utf-8')
    (sdk / 'avd' / (avd_name + '.ini')).write_text('avd.ini.encoding=UTF-8\npath=' + str(avd) + '\ntarget=android-35\n')
record = {'official_url':url, 'size':expected_size, 'sha1':expected_hash, 'avd':avd_name, 'proxy_source':'Windows configured proxy'}
(root / 'android15_environment.json').write_text(json.dumps(record, indent=2))
print('ANDROID15_ENVIRONMENT_READY', json.dumps(record), flush=True)
