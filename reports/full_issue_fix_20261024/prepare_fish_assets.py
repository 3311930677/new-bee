import json,shutil,hashlib
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parent;project=root.parents[1]/'远征'
assets=project/'assets/full_issue_fix_20261024'
manifest_path=project/'data/resource_manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
rows=[];preview=Image.new('RGB',(512,152),'#25343b')
for index,path in enumerate(sorted(root.glob('fish_fish_*.json'))):
    row=json.loads(path.read_text(encoding='utf-8'))
    im=Image.open(row['path']).convert('RGBA');bbox=im.getchannel('A').getbbox()
    assert bbox and im.getpixel((0,0))[3]==0
    im=im.crop(bbox);im.thumbnail((64,64),Image.Resampling.NEAREST)
    icon=Image.new('RGBA',(72,72));icon.alpha_composite(im,((72-im.width)//2,(72-im.height)//2))
    output=assets/'ready'/('itm_'+row['id']+'.png');icon.save(output,optimize=True)
    shutil.copy2(row['path'],assets/'source'/('itm_'+row['id']+'.png'))
    key='itm_'+row['id'];res='res://'+output.relative_to(project).as_posix()
    manifest[key]=res;manifest[key+'.png']=res
    row.update(texture=res,sha256=hashlib.sha256(output.read_bytes()).hexdigest());rows.append(row)
    preview.paste(icon.resize((112,112),Image.Resampling.NEAREST),(index*128+8,8),icon.resize((112,112),Image.Resampling.NEAREST))
    ImageDraw.Draw(preview).text((index*128+8,128),row['id'],fill='white')
assert len(rows)==4 and len({r['sha256'] for r in rows})==4
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(root/'fish_preparation.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
preview.save(root/'fish_preview.png')
print('Prepared four distinct fish inventory icons')
