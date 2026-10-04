"""Stabilize video camera drift and inspect real, chronological gait cycles."""
from pathlib import Path
import json
import cv2
import numpy as np
from PIL import Image,ImageDraw
from analyze_side_video_v17 import OUT

CYCLES={'left':(180,209),'right':(250,279)}

def face(image):
    a=np.array(image)
    r,g,b,alpha=[a[:,:,i].astype(float) for i in range(4)]
    mask=((r>140)&(r>g*1.09)&(g>b*1.06)&(alpha>128)).astype('uint8')
    mask[int(image.height*.58):]=0
    n,labels,stats,centers=cv2.connectedComponentsWithStats(mask,8)
    label=1+np.argmax(stats[1:,cv2.CC_STAT_AREA])
    x,y,w,h,_=stats[label]
    return [float(centers[label,0]),float(centers[label,1]),int(w),int(h)]

def main():
    all_metrics={}
    for direction in ('left','right'):
        records=json.loads((OUT/f'{direction}_source.json').read_text())
        # Ignore initial direction transitions and clipped late left poses.
        records=[r for r in records if r['frame']>=153 or direction=='right']
        images=[Image.open(OUT/direction/f"{r['frame']:03d}.png").convert('RGBA') for r in records]
        faces=[face(im) for im in images]
        # The camera's slow zoom is a trend, not a change in face width during
        # each gait pose. Fit the entire shot rather than pumping the body size
        # whenever compression or a facial turn changes a thresholded edge.
        indices=np.array([r['frame'] for r in records],dtype=float)
        widths=np.array([f[2] for f in faces],dtype=float)
        trend=np.polyfit(indices,widths,1)
        smooth_width=np.polyval(trend,indices).tolist()
        cycle_start,cycle_end=CYCLES[direction]
        heights=[]
        for i,(record,image) in enumerate(zip(records,images)):
            if cycle_start<=record['frame']<=cycle_end:
                box=image.getchannel('A').getbbox()
                heights.append((box[3]-box[1])*12.0/smooth_width[i])
        size_factor=110.0/float(np.median(heights))
        # A fixed face size cancels video zoom. No bone or foot is deformed.
        tiles=[]
        metrics=[]
        for i,(record,image) in enumerate(zip(records,images)):
            scale=12.0*size_factor/smooth_width[i]
            x,y,w,h=faces[i]
            origin=(round((53 if direction=='left' else 75)-x*scale),round(53-y*scale))
            reduced=image.resize((round(image.width*scale),round(image.height*scale)),Image.Resampling.NEAREST)
            tile=Image.new('RGBA',(128,128))
            tile.alpha_composite(reduced,origin)
            tile.save(OUT/direction/f"registered_{record['frame']:03d}.png")
            tiles.append(tile)
            metrics.append({'frame':record['frame'],'face':faces[i],'smoothed_face_width':smooth_width[i],
                            'scale':scale,'origin':origin,'bbox':tile.getchannel('A').getbbox()})
        all_metrics[direction]=metrics
        for offset in range(0,len(tiles),32):
            sheet=Image.new('RGB',(8*192,4*140),'#29323d')
            draw=ImageDraw.Draw(sheet)
            for j,tile in enumerate(tiles[offset:offset+32]):
                # Larger leg-only view exposes which foot supports each phase.
                legs=tile.crop((16,82,112,124)).resize((192,84),Image.Resampling.NEAREST)
                x0,y0=(j%8)*192,(j//8)*140
                sheet.paste(legs,(x0,y0),legs)
                draw.text((x0+8,y0+95),f"#{metrics[offset+j]['frame']}",fill='white')
            sheet.save(OUT/f'{direction}_legs_{offset//32}.png')
        # Rank full-cycle return errors using only the leg region after camera registration.
        data=[np.array(t.crop((24,84,104,123))).astype('float32')/255 for t in tiles]
        periods=[]
        for period in range(18,45):
            pairs=[]
            for i in range(len(data)-period):
                distance=float(np.mean(np.abs(data[i]-data[i+period])))
                pairs.append((distance,metrics[i]['frame']))
            if pairs:
                pairs.sort()
                periods.append({'period':period,'mean':float(np.mean([p[0] for p in pairs])),
                                'best_pairs':pairs[:4]})
        periods.sort(key=lambda p:p['mean'])
        print(direction,'best periods',periods[:6])
        (OUT/f'{direction}_period_search.json').write_text(json.dumps(periods,indent=2),encoding='utf-8')
    (OUT/'registration.json').write_text(json.dumps(all_metrics,indent=2),encoding='utf-8')

if __name__=='__main__':main()
