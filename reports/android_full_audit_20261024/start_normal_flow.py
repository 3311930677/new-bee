from pathlib import Path
import sys,json,zipfile,hashlib,time
sys.path.insert(0,str(Path("reports/android_full_audit_20261024").resolve()))
import run_deep_audit as q
r=q.ROOT
d=r/"normal_flow"; d.mkdir(exist_ok=True)
q.prepare_touch()
for name in ["save.json","save.json.bak"]:
    try: (d/("before_"+name)).write_bytes(q.adb("exec-out","run-as",q.PACKAGE,"cat","files/"+name))
    except Exception: pass
q.adb("shell","am","force-stop",q.PACKAGE)
q.adb("shell","run-as",q.PACKAGE,"cp","files/android_full_audit_save.json","files/save.json")
print(q.text("install","-r",str(r/"Yuanzheng-full-flow.apk")),flush=True)
q.adb("logcat","-c")
start=time.monotonic()
q.adb("shell","am","start","-n",q.COMPONENT)
time.sleep(1)
(d/"loading_native.png").write_bytes(q.adb("exec-out","screencap","-p"))
time.sleep(5)
(d/"title_native.png").write_bytes(q.adb("exec-out","screencap","-p"))
(d/"initial_logcat.txt").write_bytes(q.adb("logcat","-d"))
print("normal entry capture",time.monotonic()-start,flush=True)
print(q.text("shell","pidof",q.PACKAGE))

