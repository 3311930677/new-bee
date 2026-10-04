"""Nondestructive, reproducible pixel cleanup for scenery and UI illustration.
Leaves character animation, source artwork, and original assets intact.
"""
from pathlib import Path
import json, sys
from PIL import Image, ImageFilter
PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT.parent/'tools/pixel-art-studio/scripts'))
from pixelstudio import Sprite

sources = list((PROJECT/'image/map_proc').glob('*tile*.png'))
sources += list((PROJECT/'image/main_world').glob('*ground*reference*.png'))
sources += list((PROJECT/'image/main_world').glob('lorin_wilds_grass_v2.png'))
sources += list((PROJECT/'image').glob('generated_*/ready/pet/*.png'))
report=[]
for source in sources:
    image=Image.open(source).convert('RGBA')
    terrain='tile' in source.name or 'ground' in source.name or 'grass' in source.name
    if terrain:
        # Preserve atlas dimensions; authored landscapes use a consistent 2px grid.
        if image.width > 1000:
            image=image.resize((image.width//2,image.height//2),Image.Resampling.BOX).filter(ImageFilter.MedianFilter(3)).resize(image.size,Image.Resampling.NEAREST)
        else:
            image=image.filter(ImageFilter.MedianFilter(3))
    rgb=image.convert('RGB').quantize(colors=64 if terrain else 40,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGBA')
    rgb.putalpha(image.getchannel('A'))
    target=source.parent/'refined'/source.name
    target.parent.mkdir(exist_ok=True)
    rgb.save(target)
    sprite=Sprite.from_png(target,scale=1)
    sprite.harden_alpha()
    sprite.dedupe_colors(tol=4)
    sprite.despeckle(min_cluster=2 if terrain else 0)
    sprite.save_png(target)
    report.append({'source':str(source.relative_to(PROJECT)),'output':str(target.relative_to(PROJECT)),'size':image.size,'colors':len(sprite.used_colors()),'terrain':terrain})
(PROJECT/'docs/plans/frontend-refined-art.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Refined',len(report),'UI / terrain assets, original dimensions preserved')
