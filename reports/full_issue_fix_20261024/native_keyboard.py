import json,time
from pathlib import Path
import run_android_audit as audit
root=Path(__file__).resolve().parent
assert audit.text('shell','getprop','ro.kernel.qemu')=='1'
audit.adb('shell','input','tap','300','700')
time.sleep(1.2)
audit.adb('shell','input','text','test1234')
audit.command('native_keyboard_open','probe');audit.pull('native_keyboard_open')
opened=json.loads((root/'native_keyboard_open/result.json').read_text(encoding='utf-8'))['final']
assert opened['keyboard_height']>0,opened['focus']
assert 'Password' in opened['focus'],opened['focus']
audit.adb('shell','input','keyevent','4');time.sleep(.8)
audit.command('native_keyboard_closed','probe');audit.pull('native_keyboard_closed')
closed=json.loads((root/'native_keyboard_closed/result.json').read_text(encoding='utf-8'))['final']
assert closed['keyboard_height']==0
print('NATIVE_KEYBOARD_OK height',opened['keyboard_height'],'focus',opened['focus'])
