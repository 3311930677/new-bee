import run_android_audit as audit
import time
for attempt in range(90):
    try:
        if audit.text('shell','getprop','sys.boot_completed')=='1' and audit.text('shell','service','check','package')=='Service package: found':break
    except Exception:pass
    time.sleep(1)
else:raise RuntimeError('Owned emulator did not finish booting with package service')
for identifier,case in [('final_phone16','portrait_16_9'),('final_phone20','portrait_20_9'),('final_tablet','tablet_10_16')]:
    audit.launch(case,install=identifier=='final_phone16')
    result=audit.command(identifier,'issue_fix');audit.pull(identifier)
    assert all(row['ok'] for row in result['checks']),identifier
result=audit.command('final_android_maps','maps');audit.pull('final_android_maps')
assert all(row['ok'] for row in result['checks'])
result=audit.command('final_android_mounts','mounts');audit.pull('final_android_mounts')
assert all(row['ok'] for row in result['checks'])
print('FINAL_ANDROID_MATRIX_OK')
