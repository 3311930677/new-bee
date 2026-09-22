"""把九宫格面板贴图的全透明中心填成不透明羊皮纸色。

背景（2026-09-22 界面巡检）：F3 面板提示词要"中央大面积留白"，生成模型把它画成了
**全透明**——九宫格一拉伸，面板中段的底色就靠下层背景透出来：暗页面上的深色文字
全灭，这就是"很多页面看不清字"的根因。木色版中心本就不透明，不用处理。

用法：python tools/fill_panel_center.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / "image" / "generated_362_xajh" / "ready" / "ui" / "f3_panel_parchment.png"
FILL = (224, 208, 168, 255)   # 羊皮纸#d8c8a0 提亮一档：面板上大量深褐文字要衬得住


def main() -> None:
    im = Image.open(PANEL).convert("RGBA")
    bg = Image.new("RGBA", im.size, FILL)
    bg.alpha_composite(im)
    bg.save(PANEL)
    px = bg.load()
    print("PANEL_FILL_OK center=%s" % (px[256, 256],))


if __name__ == "__main__":
    main()
