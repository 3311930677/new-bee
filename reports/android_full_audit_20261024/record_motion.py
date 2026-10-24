from pathlib import Path
import json
import subprocess
import time
from run_deep_audit import adb, ADB, SERIAL, ROOT, command, pull

for sprint in [False,True]:
    identifier='motion_sprint_15s' if sprint else 'motion_normal_15s'
    remote='/sdcard/yuanzheng_'+identifier+'.mp4'
    with (ROOT/(identifier+'_recorder.log')).open('wb') as log:
        recorder=subprocess.Popen([str(ADB),'-s',SERIAL,'shell','screenrecord','--size','540x1200',
            '--bit-rate','2000000','--time-limit','23',remote],stdout=log,stderr=subprocess.STDOUT)
        time.sleep(.5)
        result=command(identifier,'motion',map='lorin_wilds',role='zs',mount='horse',seconds=15,sprint=sprint)
        pull(identifier)
        recorder.wait(timeout=30)
    adb('pull',remote,str(ROOT/identifier/'android_screenrecord.mp4'))
    samples=result['records'][-1]['samples']
    moved=sum(1 for a,b in zip(samples,samples[1:]) if a['position']!=b['position'])
    print(identifier,'samples',len(samples),'moving samples',moved,'max speed',max(s['velocity'] for s in samples),
          'events',len(result['records'][-1]['audio_events']),flush=True)
