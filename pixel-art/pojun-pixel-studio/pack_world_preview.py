"""Pack renderer screenshots from the real map without altering game pixels."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'远征/image/role_pixel_studio/zs/review'
WORLD=FOLDER/'world'
directions=['down','left','right','up']
labels=['向下','向左','向右','向上']
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
frames=[]
for phase in range(8):
    panel=Image.new('RGB',(944,274),'#263340')
    draw=ImageDraw.Draw(panel)
    for c,d in enumerate(directions):
        im=Image.open(WORLD/f'{d}_{phase:02d}.png').convert('RGB')
        crop=im.crop((128,332,352,548))
        panel.paste(crop,(c*236+6,30))
        draw.text((c*236+10,6),labels[c],font=font,fill='#edf3f7')
    draw.text((10,250),'游戏地图实拍 · 破军四方向行走 · 每方向 8 帧',font=font,fill='#c1d2df')
    frames.append(panel)
frames[0].save(FOLDER/'in_game.gif',save_all=True,append_images=frames[1:],duration=110,loop=0,disposal=2)
frames[0].save(FOLDER/'in_game.png')
print('Game map preview packed: four directions, eight renderer phases.')
