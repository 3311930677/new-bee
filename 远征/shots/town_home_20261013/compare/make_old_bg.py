"""按旧流程（边城夜景，3:5 居中裁切）重建旧背景，仅用于对比截图。"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
src = Image.open(ROOT / "assets/ui/home/source/home_bg_source.png").convert("RGB")
W, H = src.size
cw = round(H * 240 / 400)
x0 = (W - cw) // 2
art = src.crop((x0, 0, x0 + cw, H)).resize((240, 400), Image.BOX)
art = art.quantize(colors=64, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
a = np.asarray(art)
top = np.repeat(a[:1], 68, axis=0)
tile = a[-42:]
bottom = np.concatenate([tile, tile], 0)[:68]
tall = Image.fromarray(np.concatenate([top, a, bottom], 0))
tall.resize((480, tall.height * 2), Image.NEAREST).save(OUT / "old_bg_tall.png")
print("OLD_BG_OK", tall.size)
