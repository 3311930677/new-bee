from pathlib import Path
root=Path(__file__).resolve().parent
source=(root.parent/'android_full_audit_20261024/run_deep_audit.py').read_text(encoding='utf-8')
source=source.replace('[str(ADB), "-s", SERIAL','[str(ADB), "-P", "5038", "-s", SERIAL')
source=source.replace('apk_name = "Yuanzheng-deep-audit-final.apk" if "--final" in sys.argv else "Yuanzheng-deep-audit-extended.apk" if "--extended" in sys.argv else "Yuanzheng-deep-audit.apk"','apk_name = "Yuanzheng-fullfix-audit.apk"')
(root/'run_android_audit.py').write_text(source,encoding='utf-8')
print('Prepared driver for owned emulator-5554 on private ADB port 5038')
