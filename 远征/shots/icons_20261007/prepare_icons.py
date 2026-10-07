from pathlib import Path
from PIL import Image
import json

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets/ui/illustrated_icons_20261007'
records = []
for file in ASSETS.glob('*.png'):
    im = Image.open(file)
    alpha = im.getchannel('A')
    box = alpha.point(lambda a: 255 if a > 64 else 0).getbbox()
    assert box and alpha.getextrema()[0] == 0, file
    x0,y0,x1,y1 = box
    side = min(max(x1-x0,y1-y0) * 1.08, min(im.size))
    x = max(0,min(im.width-side,(x0+x1-side)/2))
    y = max(0,min(im.height-side,(y0+y1-side)/2))
    scale = min(1.0, 256 / max(im.size))
    region = [round(v*scale,3) for v in (x,y,side,side)]
    settings = file.with_suffix('.png.import')
    if settings.exists():
        text = settings.read_text(encoding='utf-8')
        text = text.replace('mipmaps/generate=false','mipmaps/generate=true')
        text = text.replace('process/size_limit=0','process/size_limit=256')
        settings.write_text(text,encoding='utf-8')
    file.with_suffix('.tres').write_text(
        '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n'
        f'[ext_resource type="Texture2D" path="res://assets/ui/illustrated_icons_20261007/{file.name}" id="1"]\n'
        '[resource]\natlas = ExtResource("1")\n'
        f'region = Rect2({", ".join(map(str,region))})\nfilter_clip = true\n',encoding='utf-8')
    records.append({'key':file.stem,'size':im.size,'opaque_bounds':box,'region':region})
(ASSETS/'regions.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print('Prepared',len(records),'transparent assets with native AtlasTexture regions')
