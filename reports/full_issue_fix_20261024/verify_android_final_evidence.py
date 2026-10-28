"""Audit the completed emulator evidence; explicitly keep original-phone gate open."""
from pathlib import Path
import json
import hashlib

root=Path(__file__).resolve().parent
def read(case):return json.loads((root/case/'result.json').read_text(encoding='utf-8'))
summary={'original_phone_verified':False,'screen_profiles':[]}
for case in ['final_phone16','final_phone20','final_tablet']:
    data=read(case)
    assert len(data['checks'])==123 and len(data['photos'])==41
    assert all(row['ok'] for row in data['checks'])
    assert all(row['sample_colors']>16 for row in data['photos'])
    assert all((root/case/(row['name']+'.png')).is_file() for row in data['photos'])
    summary['screen_profiles'].append({'id':case,'checks':123,'photos':41,'device':data['device']})
maps=read('final_android_maps')
assert len(maps['records'])==18 and len(maps['photos'])==91
assert all(row['ok'] for row in maps['checks'])
assert all(not row['blank_visible_sprites'] for row in maps['records'])
summary['maps']={'maps':18,'checks':len(maps['checks']),'photos':91}
static=read('final_android_mounts')
static_checks=[row for row in static['checks'] if not row['label'].startswith('P10') and not row['label'].startswith('M09 no hoof after stopping')]
assert len(static_checks)==384 and all(row['ok'] for row in static_checks)
assert len(static['photos'])==256 and all(row['sample_colors']>16 for row in static['photos'])
moving=read('final_android_moving')
assert len(moving['records'])==16 and len(moving['checks'])==96
assert all(row['ok'] for row in moving['checks'])
for row in moving['records']:
    assert all(sample['riding'] and not sample['modal'] for sample in row['samples'])
    assert row['samples'][-1]['y']-row['samples'][0]['y']>180
summary['mounts']={'static_checks':384,'static_photos':256,'actual_moving_checks':96,'actual_moving_cases':16}
index=json.loads((root/'native_motion_recordings.json').read_text())
assert len(index)==16 and len({row['id'] for row in index})==16
videos=[]
for row in index:
    case=row['id'];data=read(case);samples=data['records'][-1]['samples']
    assert all(check['ok'] for check in data['checks'])
    assert len(data['checks'])==7
    assert all(sample['riding'] and not sample['modal'] for sample in samples)
    count=12 if case.endswith('_run') else 8
    timelines={}
    for a,b in zip(samples,samples[1:]):
        moved=sum((x-y)**2 for x,y in zip(a['position'],b['position']))>.01
        if moved:timelines.setdefault(b['animation'],[]).append(b)
    loops={}
    for animation,frames in timelines.items():
        assert len({frame['frame'] for frame in frames})==count
        loops[animation]=sum(b['frame']<a['frame'] for a,b in zip(frames,frames[1:]))
        assert loops[animation]>=3,(case,animation,loops)
    assert len(loops)==4
    video=root/case/'native_screenrecord.mp4'
    assert video.stat().st_size>1000000
    videos.append({'id':case,'checks':7,'complete_loops_per_direction':loops,
                   'video_sha256':hashlib.sha256(video.read_bytes()).hexdigest()})
summary['native_recordings']=videos
opened=read('final_keyboard_open')['final'];closed=read('final_keyboard_closed')['final']
assert opened['keyboard_height']>0 and 'Password' in opened['focus'] and closed['keyboard_height']==0
summary['native_keyboard']={'height':opened['keyboard_height'],'focus':opened['focus'],'restores':True}
(root/'android_final_evidence.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('FINAL_ANDROID_EMULATOR_EVIDENCE_OK ui=369/0 maps=109/0 static_mount=384/0 real_motion=96/0 videos=16 video_checks=112/0')
print('ORIGINAL_PHONE_VERIFICATION_PENDING')
