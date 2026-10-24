import sys,time,json
from pathlib import Path
sys.path.insert(0,str(Path("reports/android_full_audit_20261024").resolve()))
from normal_actions import *
tap(941,1355);time.sleep(1);cap("mute_on")
(D/"saved_mute_on.json").write_bytes(adb("exec-out","run-as",PACKAGE,"cat","files/save.json"))
apk=text("shell","pm","path",PACKAGE).removeprefix("package:")
(D/"installed_package.json").write_text(json.dumps({"package":PACKAGE,"apk":apk,"device_sha256":text("shell","sha256sum",apk),"package_dump":text("shell","dumpsys","package",PACKAGE)},ensure_ascii=False,indent=2),encoding="utf-8")
adb("shell","am","force-stop",PACKAGE);adb("shell","am","start","-n",COMPONENT)
time.sleep(15);cap("title_after_mute_restart")
tap(540,2117);cap("mute_after_restart")
(D/"saved_after_restart.json").write_bytes(adb("exec-out","run-as",PACKAGE,"cat","files/save.json"))
(D/"normal_logcat.txt").write_bytes(adb("logcat","-d"))

