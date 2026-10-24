from pathlib import Path
from zipfile import ZipFile
from lxml import etree
from PIL import Image
import json, hashlib

out = Path(__file__).parent
src = Path(r'C:\Users\tsz\Downloads\上下模糊的地方依旧没解决.docx')
ns = {'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
      'a':'http://schemas.openxmlformats.org/drawingml/2006/main',
      'v':'urn:schemas-microsoft-com:vml',
      'r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
records=[]
with ZipFile(src) as z:
    xml=etree.fromstring(z.read('word/document.xml'))
    rels=etree.fromstring(z.read('word/_rels/document.xml.rels'))
    rm={e.get('Id'):e.get('Target') for e in rels}
    for i,e in enumerate(xml.find('w:body',ns)):
        ids=e.xpath('.//a:blip/@r:embed | .//v:imagedata/@r:id',namespaces=ns)
        rec={'block':i,'text':''.join(e.xpath('.//w:t/text()',namespaces=ns)),
             'images':[rm.get(x) for x in ids]}
        records.append(rec)
    for name in z.namelist():
        if name.startswith('word/media/'):
            dst=out/'source_media'/Path(name).name
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(z.read(name))
            with Image.open(dst) as im:
                print(name,im.size)
    (out/'source_document.xml').write_bytes(z.read('word/document.xml'))
(out/'source_extract.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(records,ensure_ascii=False,indent=2))
print('SOURCE_SHA256',hashlib.sha256(src.read_bytes()).hexdigest())

root=Path(r'D:\new-bee\远征')
extensions={'.gd','.tscn','.tres','.godot','.cfg','.json','.gdshader'}
baseline={}
for f in root.rglob('*'):
    if f.is_file() and f.suffix in extensions and not any(p in {'.godot','build','exports'} for p in f.relative_to(root).parts):
        baseline[str(f.relative_to(root))]=hashlib.sha256(f.read_bytes()).hexdigest()
(out/'game_source_baseline.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2),encoding='utf-8')
print('BASELINE_FILES',len(baseline))
