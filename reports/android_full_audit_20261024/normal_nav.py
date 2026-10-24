import sys,time,json,hashlib
from pathlib import Path
sys.path.insert(0,str(Path("reports/android_full_audit_20261024").resolve()))
from normal_actions import *
tap(540,1185);time.sleep(1);cap("reopened_from_launcher")
tap(540,1828);cap("second_login")
tap(540,1870);time.sleep(1);cap("second_map")
tap(751,207);cap("second_camp_confirmation")
tap(733,1355);time.sleep(1);cap("second_home")
adb("shell","input","swipe","540","2398","540","2230","260")
cap("home_threebutton_native")
(D/"home_threebutton_window.txt").write_bytes(adb("shell","dumpsys","window"))
(D/"normal_final_logcat.txt").write_bytes(adb("logcat","-d"))
print("normal navigation captured")

