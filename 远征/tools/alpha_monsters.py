"""AI 怪物立绘入库（asset-regen B 类补图）。

流程：抠纯黑底 → 切掉右下角水印 → 裁到实体外框 → 缩到 128×128 → 写入批次 ready/monster/。

两个约定：
1. **命名直接用 monsters.json 的 id**（`mon_spider.png`）：`G.art()` 的回落分支就是按原名查
   `res_tex`，所以这一类不需要登记 `XA_ART` 映射表，少一处会走样的对照关系。
2. **必须切水印**：生成模型在所难免会加「AI生成 WORKBUDDY」角标，它是不透明的浅灰像素，
   会混进 `getbbox()`，把裁剪框撑成整张图（怪被缩成一小团）。提示词里写了"无水印"也不保险。

用法：python tools/alpha_monsters.py assets_regen/raw/b_monsters2/_map.json
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

from PIL import Image

from slice_map_atlas import chroma_black, crop_to_content

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "image" / "generated_362_xajh" / "ready" / "monster"
if len(sys.argv) > 3:
    OUT = OUT.parent / sys.argv[3]   # 第三个参数换输出目录（如 pet）
TARGET = 128          # 与既有 10 张 AI 怪物同规格；宠物 D 类是 96×96，用第二个参数覆盖
if len(sys.argv) > 2:
    TARGET = int(sys.argv[2])
WATERMARK_H = 0.09    # 底部 9% 与右下 45%×22% 一律清空（水印的常见落点）
WATERMARK_W = 0.45


def strip_watermark(img: Image.Image) -> Image.Image:
    """把底部条带与右下角块整块清空。清的是"图角"，主体居中占 85%，不会误伤。"""
    img = img.copy()
    w, h = img.size
    img.paste((0, 0, 0, 0), (0, int(h * (1.0 - WATERMARK_H)), w, h))
    img.paste((0, 0, 0, 0), (int(w * (1.0 - WATERMARK_W)), int(h * (1.0 - 0.22)), w, h))
    return img


def main() -> None:
    if len(sys.argv) < 2:
        print("用法：python tools/alpha_monsters.py <map.json> [size] [subdir] [noalpha]")
        return
    noalpha = len(sys.argv) > 4   # 满幅场景图：不抠黑底，只切掉底部水印条带（插画类用）
    mapping = json.loads(io.open(sys.argv[1], encoding="utf-8").read())
    src_dir = Path(sys.argv[1]).parent
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    for fname, mon_id in mapping.items():
        src = src_dir / fname
        if not src.exists():
            print("缺源图 %s" % fname)
            continue
        if noalpha:
            full = Image.open(src).convert("RGB")
            img = full.crop((0, 0, full.width, int(full.height * 0.93)))  # 水印在底部 7%
        else:
            img = crop_to_content(strip_watermark(chroma_black(Image.open(src))))
        s = TARGET / float(max(img.width, img.height))
        img = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))),
                         Image.Resampling.NEAREST)
        if noalpha:
            img.save(OUT / ("%s.png" % mon_id))
            made.append("%s ← %s (%dx%d)" % (mon_id, fname[-22:], img.width, img.height))
            continue
        canvas = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
        canvas.paste(img, ((TARGET - img.width) // 2, (TARGET - img.height) // 2))
        canvas.save(OUT / ("%s.png" % mon_id))
        made.append("%s ← %s (%dx%d)" % (mon_id, fname[-22:], canvas.width, canvas.height))
    print("ALPHA_MONSTER_OK %d 张" % len(made))
    for m in made:
        print("  " + m)


if __name__ == "__main__":
    main()
