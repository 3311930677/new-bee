"""Inspect actual video side poses and extract their original RGB foreground."""
from pathlib import Path
import json
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'shots'/'walk_video_v17_20261004'
VIDEO = Path(r'C:\Users\tsz\Downloads\video_20261003_204732.mp4')

def extract(rgb):
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    colored = ((hsv[:,:,1]>65)&(hsv[:,:,2]>50)).astype('uint8')
    colored[:400] = 0
    colored[1550:] = 0
    yy,xx = np.where(colored)
    crop = (max(0,int(xx.min())-40),max(0,int(yy.min())-70),
            min(1080,int(xx.max())+41),min(1600,int(yy.max())+81))
    a = rgb[crop[1]:crop[3],crop[0]:crop[2]].copy()
    spread = np.ptp(a.astype('int16'),axis=2)
    dark = np.min(a,axis=2)
    # Only neutral border-connected pixels are background. The outlined light
    # hair/collar remain enclosed. Include the dark neutral cast shadow.
    possible_bg = ((spread <= 8)&(dark >= 150)&(dark <= 220)).astype('uint8')
    ground_band = np.arange(a.shape[0])[:,None] >= int(yy.max())-crop[1]-40
    possible_bg |= ((spread <= 24)&(dark >= 80)&(dark <= 165)&ground_band).astype('uint8')
    count,labels,_,_ = cv2.connectedComponentsWithStats(possible_bg,4)
    exterior = np.unique(np.concatenate((labels[0],labels[-1],labels[:,0],labels[:,-1])))
    exterior = exterior[exterior!=0]
    alpha = (~np.isin(labels,exterior)).astype('uint8')
    # Gray islands between boots/staff belong to the same matte, even if
    # visually enclosed by the silhouette; fill light hair first via outlines.
    foreground = alpha.copy()
    n,components,stats,_ = cv2.connectedComponentsWithStats(foreground,8)
    largest = 1+np.argmax(stats[1:,cv2.CC_STAT_AREA])
    alpha = (components==largest).astype('uint8')*255
    rgba = np.dstack((a,alpha))
    rgba[alpha==0]=0
    return Image.fromarray(rgba),crop

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    for direction,start,end in [('left',148,229),('right',237,300)]:
        cap = cv2.VideoCapture(str(VIDEO))
        cap.set(cv2.CAP_PROP_POS_FRAMES,start)
        frames=[]
        records=[]
        for index in range(start,end+1):
            ok,bgr=cap.read()
            if not ok:break
            rgb=cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB)
            image,crop=extract(rgb)
            (OUT/direction).mkdir(exist_ok=True)
            image.save(OUT/direction/f'{index:03d}.png')
            records.append({'frame':index,'time':index/30,'crop':crop,'bbox':image.getchannel('A').getbbox()})
            box=image.getchannel('A').getbbox()
            tile=image.crop(box)
            ratio=min(176/tile.width,176/tile.height)
            tile=tile.resize((round(tile.width*ratio),round(tile.height*ratio)),Image.Resampling.NEAREST)
            cell=Image.new('RGB',(200,206),'#303946')
            cell.paste(tile,((200-tile.width)//2,178-tile.height),tile)
            ImageDraw.Draw(cell).text((8,184),f'#{index} {index/30:.3f}s',fill='white')
            frames.append(cell)
        cap.release()
        for offset in range(0,len(frames),24):
            sheet=Image.new('RGB',(6*200,4*206),'#303946')
            for i,cell in enumerate(frames[offset:offset+24]):
                sheet.paste(cell,((i%6)*200,(i//6)*206))
            sheet.save(OUT/f'{direction}_all_{offset//24}.png')
        (OUT/f'{direction}_source.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
    print('Extracted every source frame: left 148..229, right 237..300')

if __name__=='__main__':main()
