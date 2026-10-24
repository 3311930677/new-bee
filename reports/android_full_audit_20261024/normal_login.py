import sys,time
from pathlib import Path
sys.path.insert(0,str(Path("reports/android_full_audit_20261024").resolve()))
from normal_actions import *
(D/"keyboard_window.txt").write_bytes(adb("shell","dumpsys","window"))
adb("shell","input","text","qa123")
time.sleep(.5);cap("keyboard_typed")
adb("shell","input","keyevent","4");time.sleep(1);cap("keyboard_restored")
tap(540,1697);time.sleep(3);cap("after_login")
(D/"after_login_logcat.txt").write_bytes(adb("logcat","-d"))

