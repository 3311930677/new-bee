import run_android_audit as audit
import json
from pathlib import Path

diagnosis=Path(__file__).resolve().parent/'diagnose_blocked_origin/result.json'
if diagnosis.exists():result=json.loads(diagnosis.read_text(encoding='utf-8'))
else:
    audit.launch('portrait_16_9', install=True)
    result=audit.command('diagnose_blocked_origin','motion',role='zs',mount='horse',seconds=3,start=[480,700],directions=['move_down'])
    audit.pull('diagnose_blocked_origin')
print('BLOCKED_ORIGIN',json.dumps(result['records'][-1]['samples'][-1]),flush=True)
audit.launch('portrait_20_9')
result=audit.command('final_android_moving','mounts',motion_only=True)
audit.pull('final_android_moving')
assert all(row['ok'] for row in result['checks'])
print('FINAL_ANDROID_MOVING_OK',len(result['checks']),len(result['records']),flush=True)
