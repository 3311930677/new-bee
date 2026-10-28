"""Start only the isolated full-fix AVD, preserving both AVD data directories."""
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent
sdk = Path(r'D:\new-bee\tools\android-sdk-mobile')
mode = sys.argv[1] if len(sys.argv) > 1 else 'swangle'
avd_name = sys.argv[2] if len(sys.argv) > 2 else 'Yuanzheng_FullFix_20261025'
env = os.environ.copy()
env.update(ANDROID_AVD_HOME=str(sdk / 'avd'), ANDROID_USER_HOME=str(sdk / 'user'),
           ANDROID_SDK_ROOT=str(sdk), ANDROID_ADB_SERVER_PORT='5038')
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
args = [str(sdk / 'emulator/emulator.exe'), '-avd', avd_name,
        '-gpu', mode, '-no-snapshot', '-no-boot-anim', '-no-window', '-no-audio',
        '-memory', '4096', '-cores', '4']
with (root / ('emulator_' + mode + '_stdout.log')).open('w') as out, (root / ('emulator_' + mode + '_stderr.log')).open('w') as err:
    process = subprocess.Popen(args, env=env, stdout=out, stderr=err,
                               startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW)
record = {'pid': process.pid, 'args': args, 'mode': mode}
(root / 'owned_emulator.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps(record))
