import importlib.util,json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('prepare',root.parents[1]/'远征/tools/prepare_mount_animation.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
jobs=json.loads((root/'mount_sources.json').read_text(encoding='utf-8'))
for role,direction,indices in [('ck','left',[19]),('fs','right',[11,15,19])]:
    job=next(j for j in jobs if j['mount']=='horse' and j['role']==role and j['direction']==direction)
    poses,bounds,clipped=module.extract_poses(Image.open(job['path']).convert('RGBA'))
    for index in indices:
        pose=poses[index]
        square=Image.new('RGBA',(max(pose.size)+100,)*2)
        square.alpha_composite(pose,(50,50))
        square.resize((1024,1024),Image.Resampling.NEAREST).save(root/f'outpaint_ref_horse_{role}_{direction}_{index}.png')
print('Prepared four exact-cell references')
