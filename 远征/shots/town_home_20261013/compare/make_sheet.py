"""旧 / 新首页并排对比图（每张 ≤2000px，方便在对话里查看）。"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
SHOTS = HERE.parent
FONT = ImageFont.truetype(str(HERE.parents[2] / "assets/fonts/NotoSansSC-Bold.otf"), 22)

for h in (800, 1067):
    old = Image.open(HERE / f"old_{h}.png").convert("RGB")
    new = Image.open(SHOTS / f"town_home_{h}.png").convert("RGB")
    gap, head = 16, 40
    sheet = Image.new("RGB", (480 * 2 + gap, h + head), (24, 22, 28))
    sheet.paste(old, (0, head))
    sheet.paste(new, (480 + gap, head))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), f"之前：边城夜景  480×{h}", font=FONT, fill=(230, 220, 200))
    d.text((480 + gap + 12, 8), f"现在：月下山城阶梯要塞  480×{h}", font=FONT, fill=(242, 199, 106))
    out = HERE / f"compare_{h}.png"
    sheet.save(out)
    print(sheet.size, out.name)
