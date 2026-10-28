"""Capture native screen recordings of four professions, two mounts and both gaits."""
from pathlib import Path
import json
import subprocess
import time
import run_android_audit as audit

root = Path(__file__).resolve().parent
audit.launch('portrait_20_9')
summaries = []
for mount in ['horse','bear']:
    for role in ['zs','ck','fs','fz']:
        for sprint in [False,True]:
            identifier = f'final_motion_{mount}_{role}_{"run" if sprint else "walk"}'
            remote = '/data/local/tmp/' + identifier + '.mp4'
            recorder = subprocess.Popen([str(audit.ADB),'-P','5038','-s',audit.SERIAL,'shell','screenrecord','--time-limit','21','--bit-rate','6000000',remote], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            time.sleep(.5)
            result = audit.command(identifier,'motion',role=role,mount=mount,sprint=sprint,seconds=16,isolated_directions=True)
            audit.pull(identifier)
            recorder.communicate(timeout=30)
            assert recorder.returncode == 0
            audit.adb('pull',remote,str(root / identifier / 'native_screenrecord.mp4'))
            audit.adb('shell','rm','-f',remote)
            assert all(row['ok'] for row in result['checks'])
            samples = result['records'][-1]['samples']
            assert all(sample['riding'] and not sample['modal'] for sample in samples), identifier
            movements = {}
            for a,b in zip(samples,samples[1:]):
                if sum((x-y)**2 for x,y in zip(a['position'],b['position'])) <= .01: continue
                movements.setdefault(b['animation'],set()).add(b['frame'])
            summary = {'id':identifier,'moving_animation_frames':{key:sorted(value) for key,value in movements.items()}}
            expected={('run_' if sprint else 'walk_')+direction for direction in ['down','right','up','left']}
            assert set(movements)==expected,summary
            assert all(len(movements[key])>=(10 if sprint else 6) for key in expected),summary
            summaries.append(summary)
            (root / 'native_motion_recordings.json').write_text(json.dumps(summaries,indent=2))
            print('NATIVE_VIDEO',json.dumps(summary),flush=True)
(root / 'native_motion_recordings.json').write_text(json.dumps(summaries,indent=2))
print('NATIVE_MOTION_RECORDINGS_SAVED',len(summaries))
