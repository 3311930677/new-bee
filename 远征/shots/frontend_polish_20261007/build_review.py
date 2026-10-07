from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
FONT = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',20)
SMALL = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',14)


def sheet(entries, name, title, width=240, height=400):
    canvas = Image.new('RGB',(len(entries)*(width+16)+16,height+94),'#172b25')
    draw = ImageDraw.Draw(canvas)
    draw.text((16,12),title,font=FONT,fill='#e5d2a5')
    for i,(path,caption) in enumerate(entries):
        shot = Image.open(path).convert('RGB')
        shot.thumbnail((width,height),Image.Resampling.LANCZOS)
        x = 16+i*(width+16)
        canvas.paste(shot,(x+(width-shot.width)//2,50))
        draw.text((x,height+62),caption,font=SMALL,fill='#e5dfcd')
    canvas.save(OUT/name)


sheet([(OUT/'title_800.png','主菜单 · 漆木与黄铜'),(OUT/'load_71_800.png','加载 · 宽进度条'),
       (OUT/'intro_world_800.png','手记 · 新世界插画'),(OUT/'login_800.png','登记 · 自定义头像')],
      'overview.png','前端精修 · 实际游戏画面')
sheet([(OUT/f'intro_{page}_800.png',name) for page,name in [('world','世界'),('party','旅人'),('journey','启程')]],
      'journal_pages.png','三页行旅手记')
sheet([(OUT/'home_800.png','营帐 · 经验条与默认标记'),(OUT/'avatar_800.png','上传头像 · 即时预览')],
      'profile.png','个人身份与营帐')
sheet([(OUT/f'{page}_1067.png',name) for page,name in [('title','主菜单'),('login','旅人登记'),('intro_party','角色卡片'),('load_71','加载')]],
      'tall_screens.png','长屏检查 · 480 × 1067',height=534)

records=json.loads((OUT/'capture_index.json').read_text(encoding='utf-8'))
assert len(records)==20
audit={'captures':20,'text_nodes':0,'issues':[]}
for row in records:
    path=OUT/Path(row['path']).name
    assert list(Image.open(path).size)==row['size']
    data=json.loads(path.with_suffix('.text.json').read_text(encoding='utf-8'))
    audit['text_nodes']+=len(data['text_nodes'])
    for key in ['nonlinear_text','compact_art','short_text_boxes']:
        audit['issues'].extend({'capture':path.name,'kind':key,**item} for item in data[key])
(OUT/'text_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
assert not audit['issues'],audit['issues']

for key in ['wordmark','journey']:
    files=sorted((OUT/'motion'/key).glob('*.png'))
    assert len(files)==30
    frames=[Image.open(p).convert('RGB') for p in files]
    palette_source=Image.new('RGB',(480*5,800))
    for i in range(5): palette_source.paste(frames[round(i*29/4)],(i*480,0))
    palette=palette_source.quantize(colors=256,dither=Image.Dither.NONE)
    gif=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    gif[0].save(OUT/'motion'/f'{key}.gif',save_all=True,append_images=gif[1:],
                duration=([36]*25+[80]*5 if key=='wordmark' else [42]*25+[80]*5),loop=0,disposal=2,optimize=False)
previews=[]
for i in range(30):
    frame=Image.new('RGB',(480,442),'#172b25')
    draw=ImageDraw.Draw(frame)
    draw.text((16,8),'标题 · 快速笔锋勾写',font=SMALL,fill='#e5d2a5')
    logo=Image.open(OUT/'motion/wordmark'/f'{i:03d}.png').convert('RGB').crop((88,48,392,210))
    frame.paste(logo,(88,32))
    draw.text((16,212),'启程 · 路线逐段画出',font=SMALL,fill='#e5d2a5')
    route=Image.open(OUT/'motion/journey'/f'{i:03d}.png').convert('RGB').crop((32,168,448,360))
    frame.paste(route,(32,244))
    previews.append(frame)
palette=previews[-1].quantize(colors=256,dither=Image.Dither.NONE)
gif=[frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in previews]
gif[0].save(OUT/'motion_preview.gif',save_all=True,append_images=gif[1:],duration=[40]*25+[100]*5,
            loop=0,disposal=2,optimize=False)

html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>远征 · 前端精修审阅</title><style>body{margin:0;background:#152822;color:#e8dfc9;font:16px/1.7 system-ui}main{max-width:1120px;margin:auto;padding:28px 20px}h1{font-size:28px}h2{font-size:20px;margin-top:36px}img{max-width:100%;height:auto}a{color:#dfc289}.motion{max-width:480px}.row{display:flex;gap:16px;flex-wrap:wrap}.row img{width:240px}</style>
<main><h1>远征 · 前端精修</h1><p>主菜单、加载、旅人登记、营帐与三页手记。下列图片来自游戏实际渲染；动画预览会循环，游戏中只在进入时播放。</p>
<img src="overview.png"><h2>快速落笔与行旅路线</h2><img class="motion" src="motion_preview.gif"><h2>三页手记</h2><img src="journal_pages.png"><h2>头像与营帐</h2><img src="profile.png"><h2>长屏检查</h2><img src="tall_screens.png"><p><a href="text_audit.json">文字检查记录</a> · <a href="capture_index.json">原始截图索引</a></p></main></html>'''
(OUT/'index.html').write_text(html,encoding='utf-8')
print(f"FRONTEND_REVIEW_OK captures=20 motion_frames=60 text_nodes={audit['text_nodes']} issues=0")
