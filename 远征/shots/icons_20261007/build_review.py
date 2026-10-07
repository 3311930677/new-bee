from pathlib import Path
from PIL import Image
import json

root=Path(__file__).resolve().parent
before=Image.open(root/'before.png').convert('RGB')
after=Image.open(root/'home_800.png').convert('RGB')
out=Image.new('RGB',(960,800))
out.paste(before,(0,0));out.paste(after,(480,0))
out.save(root/'before_after.png')
audits=[]
for file in root.glob('*.text.json'):
    data=json.loads(file.read_text(encoding='utf-8'))
    issues={key:data.get(key,[]) for key in ['compact_art','nonlinear_text','short_text_boxes']}
    assert not any(issues.values()),(file.name,issues)
    audits.append({'file':file.name,'text_nodes':len(data['text_nodes']),'issues':issues})
(root/'visual_checks.json').write_text(json.dumps(audits,indent=2),encoding='utf-8')
print('SCREENSHOT_AUDIT_OK',len(audits),'screens')
