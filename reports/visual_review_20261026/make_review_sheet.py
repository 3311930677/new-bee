from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"D:\new-bee")
SOURCE = ROOT / "远征/shots/visual_review_current_20261026"
OUT = ROOT / "reports/visual_review_20261026"
OUT.mkdir(parents=True, exist_ok=True)
FONT = ImageFont.truetype(r"C:\Windows\Fonts\msyhbd.ttc", 23)
SMALL = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 18)
tiles = [
    ("bag_320x640.png", "① 窄屏：金币数字越界", "320×640；右上角金额显示不全", [(206,88,319,124)]),
    ("world_red_sand_route_middle.png", "② 野外：大片地面缺少地标与层次", "赤砂商路中段；主角周围大面积只有沙地", [(24,160,454,620)]),
    ("world_frost_post.png", "③ 霜关：比例不齐，装饰挤在一处", "人类 NPC 比主角高；右侧物件相互叠压", [(104,258,188,371),(198,486,285,578),(280,389,397,533)]),
    ("map_800.png", "④ 详图：数字聚合，地点辨认费力", "同色圆点多；缺少建筑轮廓、地点名称", [(177,246,316,490)]),
    ("battle_800.png", "⑤ 战斗：敌群叠压，目标信息拥挤", "树妖、蜘蛛与编号集中在右侧", [(297,196,437,374),(12,588,468,640)]),
    ("activities_800.png", "⑥ 页面风格：绿底卡片与旧金框脱节", "对照左上背包；边框、色彩、按钮材质不一", []),
]
margin, gap, tw, hh, ih = 16, 16, 480, 76, 800
sheet = Image.new("RGB", (margin*2+tw*3+gap*2, margin*2+(hh+ih)*2+gap), "#10151d")
for index, (filename, title, caption, boxes) in enumerate(tiles):
    im = Image.open(SOURCE / filename).convert("RGB")
    d = ImageDraw.Draw(im)
    for box in boxes:
        d.rectangle(box, outline="#ff655f", width=3)
    scale = min(tw/im.width, ih/im.height)
    im = im.resize((round(im.width*scale), round(im.height*scale)), Image.Resampling.LANCZOS)
    x = margin+(index%3)*(tw+gap)
    y = margin+(index//3)*(hh+ih+gap)
    draw = ImageDraw.Draw(sheet)
    draw.rectangle((x,y,x+tw,y+hh+ih), fill="#1c2631")
    draw.text((x+10,y+8), title, font=FONT, fill="#f5d291")
    draw.text((x+10,y+43), caption, font=SMALL, fill="#d0d9e3")
    sheet.paste(im,(x+(tw-im.width)//2,y+hh))
sheet.save(OUT / "issues_contact_sheet.jpg", quality=94)
print(OUT / "issues_contact_sheet.jpg")
