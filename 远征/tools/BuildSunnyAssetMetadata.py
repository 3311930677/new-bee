"""Read-only alpha analysis; image processing stays in the native Godot importer."""
from pathlib import Path
from PIL import Image
import numpy as np
from scipy import ndimage
import json
root=Path(__file__).resolve().parents[1]
assets=root/'assets/world/sunny_travel_20261010'
p=assets/'source/vegetation_v2.png'
image=Image.open(p).convert('RGBA')
labels,total=ndimage.label(np.asarray(image)[:,:,3]>=128)
objects=[]
for index,region in enumerate(ndimage.find_objects(labels),1):
    if region is None:continue
    area=int(np.sum(labels[region]==index))
    if area<400:continue
    y,x=region;objects.append({'rect':[x.start,y.start,x.stop-x.start,y.stop-y.start],'area':area})
objects.sort(key=lambda a:a['rect'][1]+a['rect'][3]*.5)
assert len(objects)==12,(len(objects),objects)
ordered=[]
for row in range(4):ordered.extend(sorted(objects[row*3:row*3+3],key=lambda a:a['rect'][0]))
(assets/'source_regions.json').write_text(json.dumps({'vegetation':ordered},indent=2),encoding='utf8')
print('SUNNY_METADATA_OK 12 complete transparent components; no image altered.')
