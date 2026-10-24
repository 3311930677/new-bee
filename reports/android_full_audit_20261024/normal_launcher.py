import sys,time,json
from pathlib import Path
sys.path.insert(0,str(Path("reports/android_full_audit_20261024").resolve()))
from normal_actions import *
tap(941,1355);time.sleep(1);cap("mute_restored_off")
tap(80,220);cap("title_returned")
adb("shell","input","keyevent","3");time.sleep(1);cap("launcher_home")
adb("shell","input","swipe","540","2050","540","400","450");time.sleep(1);cap("launcher_apps")
(D/"launcher_ui_dump.txt").write_bytes(adb("shell","uiautomator","dump","/sdcard/qa_launcher.xml"))
(D/"launcher_ui.xml").write_bytes(adb("exec-out","cat","/sdcard/qa_launcher.xml"))
print("launcher captured")

