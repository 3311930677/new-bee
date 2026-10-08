import re

# 1. Update JournalUI.gd
path_j = r"D:\new bee\远征\src\ui\JournalUI.gd"
with open(path_j, "r", encoding="utf-8", errors="ignore") as f:
    cj = f.read()

ledger_pattern = r"class LedgerFrame extends PanelContainer:[\s\S]*?class EmbellishedButton extends Button:"
new_ledger = """class LedgerFrame extends PanelContainer:
\tvar header_height := 92.0

\tfunc _ready() -> void:
\t\tresized.connect(queue_redraw)

\tfunc _draw() -> void:
\t\tvar sz := size
\t\tif sz.x < 20: return
\t\ttexture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

\t\t# 1. 深度柔和投影
\t\tdraw_rect(Rect2(4, 8, sz.x - 8, sz.y - 6), Color(0.0, 0.0, 0.0, 0.55))

\t\t# 2. 外框：暗铁镶边
\t\tdraw_rect(Rect2(0, 0, sz.x, sz.y), Color("12161e"))
\t\tdraw_rect(Rect2(2, 2, sz.x - 4, sz.y - 4), Color("1a222e"))

\t\t# 3. 内侧高光
\t\tdraw_line(Vector2(2, 2), Vector2(sz.x - 3, 2), Color(1.0, 1.0, 1.0, 0.08), 1.0)
\t\tdraw_line(Vector2(2, 2), Vector2(2, sz.y - 3), Color(1.0, 1.0, 1.0, 0.05), 1.0)

\t\t# 4. 精细黄铜角码 (四角 14px L形)
\t\tvar gc := Color("c8a050")
\t\tvar gc_hi := Color("ffe088")
\t\tvar arm := 14.0
\t\t# 左上
\t\tdraw_line(Vector2(3, 3), Vector2(3 + arm, 3), gc_hi, 1.0)
\t\tdraw_line(Vector2(3, 3), Vector2(3, 3 + arm), gc_hi, 1.0)
\t\tdraw_rect(Rect2(4, 4, 2, 2), gc)
\t\t# 右上
\t\tdraw_line(Vector2(sz.x - 4, 3), Vector2(sz.x - 4 - arm, 3), gc_hi, 1.0)
\t\tdraw_line(Vector2(sz.x - 4, 3), Vector2(sz.x - 4, 3 + arm), gc_hi, 1.0)
\t\tdraw_rect(Rect2(sz.x - 6, 4, 2, 2), gc)
\t\t# 左下
\t\tdraw_line(Vector2(3, sz.y - 4), Vector2(3 + arm, sz.y - 4), gc, 1.0)
\t\tdraw_line(Vector2(3, sz.y - 4), Vector2(3, sz.y - 4 - arm), gc, 1.0)
\t\tdraw_rect(Rect2(4, sz.y - 6, 2, 2), gc)
\t\t# 右下
\t\tdraw_line(Vector2(sz.x - 4, sz.y - 4), Vector2(sz.x - 4 - arm, sz.y - 4), gc, 1.0)
\t\tdraw_line(Vector2(sz.x - 4, sz.y - 4), Vector2(sz.x - 4, sz.y - 4 - arm), gc, 1.0)
\t\tdraw_rect(Rect2(sz.x - 6, sz.y - 6, 2, 2), gc)

\t\t# 5. 内部温润羊皮纸 (纯正高级古卷羊皮纸)
\t\tvar inset := 8.0
\t\tvar paper_w := sz.x - inset * 2
\t\tvar paper_h := sz.y - inset * 2
\t\tdraw_rect(Rect2(inset, inset, paper_w, paper_h), Color("f0e6cf"))
\t\t# 纸张边缘微暗做旧
\t\tdraw_line(Vector2(inset, inset), Vector2(inset, inset + paper_h), Color("d8c6a0"), 1.0)
\t\tdraw_line(Vector2(inset + paper_w - 1, inset), Vector2(inset + paper_w - 1, inset + paper_h), Color("d8c6a0"), 1.0)
\t\t# 内框装饰细线
\t\tdraw_rect(Rect2(inset + 4, inset + 4, paper_w - 8, paper_h - 8), Color("c4b088", 0.45), false, 1.0)

class EmbellishedButton extends Button:"""

cj_new = re.sub(ledger_pattern, new_ledger, cj)
with open(path_j, "w", encoding="utf-8") as f:
    f.write(cj_new)
print("JournalUI.gd updated successfully!")
