import json
from pathlib import Path
import time
import run_android_audit as audit

root=Path(__file__).resolve().parent
audit.launch('portrait_16_9')
audit.command('final_keyboard_login','page',page='login')
audit.adb('shell','input','tap','300','760')
time.sleep(1.2)
audit.adb('shell','input','text','test1234')
audit.command('final_keyboard_open','probe');audit.pull('final_keyboard_open')
opened=json.loads((root/'final_keyboard_open/result.json').read_text(encoding='utf-8'))['final']
assert opened['keyboard_height']>0 and 'Password' in opened['focus'],opened
audit.adb('shell','input','keyevent','4');time.sleep(.8)
audit.command('final_keyboard_closed','probe');audit.pull('final_keyboard_closed')
closed=json.loads((root/'final_keyboard_closed/result.json').read_text(encoding='utf-8'))['final']
assert closed['keyboard_height']==0
print('FINAL_NATIVE_KEYBOARD_OK height',opened['keyboard_height'],'focus',opened['focus'])
