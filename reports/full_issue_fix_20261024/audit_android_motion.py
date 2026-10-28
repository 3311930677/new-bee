import json
from pathlib import Path
root=Path(__file__).resolve().parent
case='final_android_moving' if (root/'final_android_moving/result.json').exists() else 'final_android_mounts' if (root/'final_android_mounts/result.json').exists() else 'android_mounts'
result=json.loads((root/case/'result.json').read_text(encoding='utf-8'))
assert not [c for c in result['checks'] if not c['ok']]
rows=[]
for row in result['records']:
    samples=row['samples']
    assert all(s.get('riding',False) for s in samples),row
    displacement=float(samples[-1]['y'])-float(samples[0]['y'])
    assert displacement>180,row
    expected='run_' if row['sprint'] else 'walk_'
    moving=[s for index,s in enumerate(samples) if index>0 and float(s['y'])>float(samples[index-1]['y']) and s['velocity']>1 and s.get('playing',False) and s.get('animation','').startswith(expected)]
    frames={s['frame'] for s in moving}
    mean=sum(s['velocity'] for s in moving)/max(1,len(moving))
    rows.append({'mount':row['mount'],'role':row['role'],'sprint':row['sprint'],'displacement':displacement,'moving_samples':len(moving),'total_samples':len(samples),'frames':sorted(frames),'mean_velocity':mean,'hoof_events':len([e for e in row['events'] if e['category']=='Movement'])})
assert len(rows)==16
(root/'android_motion_metrics.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print([(r['mount'],r['role'],r['sprint'],r['frames'],round(r['mean_velocity']),r['hoof_events']) for r in rows])
for row in rows:
    assert row['moving_samples']>=40,row
    assert len(row['frames'])>=6 if not row['sprint'] else len(row['frames'])>=10,row
    assert row['hoof_events']>0,row
for mount in ['horse','bear']:
    for role in ['zs','ck','fs','fz']:
        pair=[r for r in rows if r['mount']==mount and r['role']==role]
        walk=next(r for r in pair if not r['sprint']);run=next(r for r in pair if r['sprint'])
        assert abs(run['mean_velocity']/walk['mean_velocity']-1.25)<.03,pair
(root/'android_motion_metrics.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print('ANDROID_REAL_MOTION_OK',len(rows),'moving walk/run cases; speed ratio1.25')
