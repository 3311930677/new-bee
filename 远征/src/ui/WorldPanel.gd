# WorldPanel.gd —— 世界图志浮层（8 片大陆逐个解锁；已通关 / 可挑战 / 未解锁三态）
# 版式：一屏一片大陆的大卡轮播（大插画位 + 名称 + 状态），←→/AD 或拖拽翻页；
#      插画命名 world_<theme>.png，没有素材就留白占位（卡上会写出该生成的文件名）。
# 从 GameHome 的内部类抽出，营帐与主城两处入口共用
class_name WorldPanel
extends Control

signal closed

const PageDeckScript := preload("res://src/ui/PageDeck.gd")
const SlideCardScript := preload("res://src/ui/SlideCard.gd")

# 羊皮纸 440 宽 - 左右各 16 内边距 = 内容可用宽；子控件坐标一律按这个基准算，
# 否则整块内容会整体右偏 16px（子控件是挂在 content 上的，不是挂在面板上）
const CONTENT_W := 408.0
const DECK_H := 400.0
const DECK_Y := 30.0

# 与 DeployPanel 同口径的辨识色
const THEME_HUE := {
	"forest": Color("5f8a46"), "snow": Color("7fa8cf"), "volcano": Color("b0523a"),
	"tomb": Color("6b5f88"), "desert": Color("c09a55"), "glacier": Color("6fb3ba"),
	"abyss": Color("6d5a9e"), "castle": Color("8d8474"),
}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# 浮层自身 rect 要等一帧才结算，锚点定位会算到 0，坐标一律写死
	var banner := G.banner_box("世 界 图 志", 300, 50)
	banner.position = Vector2(90, 36)
	add_child(banner)

	var panel := G.parchment_box(440, 600, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var order: Array = G.theme_order()
	var unlocked_n: int = int(G.prog.get("worlds_unlocked", 1))
	var tip := G.gold_label("已解锁 %d / %d · 已通关 %d · 通关首领即揭开下一片大陆"
		% [unlocked_n, order.size(), G.cleared_world_count()],
		G.FS_XS, false, Color("7a5a2e"), false)
	tip.position = Vector2(0, 2)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tip)

	# 一屏一片：拖拽、两侧箭头、←→/AD 翻页，圆点在卡下页脚
	var deck := PageDeckScript.new(CONTENT_W, DECK_H, 26.0)
	deck.position = Vector2(0, DECK_Y)
	deck.key_mode = "both"   # 没有二级页签，方向键 / WASD 哪个都用来翻大陆
	for i in order.size():
		var tid := String(order[i])
		var card := _slide(tid, i, order)
		deck.add_page(SlideCardScript.page(card, CONTENT_W, DECK_H), Vector2(CONTENT_W, DECK_H))
	content.add_child(deck)
	# 打开就停在「当前推进到的那片」，省得每次从头翻
	deck.go(clampi(unlocked_n - 1, 0, maxi(0, order.size() - 1)), true)

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 480)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(back)


func _slide(tid: String, idx: int, order: Array) -> Control:
	var unlocked: bool = G.is_world_unlocked(tid)
	var cleared: bool = G.is_world_cleared(tid)
	var hue: Color = THEME_HUE.get(tid, Color("8d8474"))
	var prev_tid := String(order[maxi(0, idx - 1)])

	var badge := "未解锁"
	var badge_col := Color("7a7263")
	var lines: Array = []
	var footer := "← → 或拖动翻页"
	if cleared:
		badge = "已通关"
		badge_col = Color("4a7a44")
		lines.append("首领已讨伐 · 可重游刷资源")
		footer = "← → 翻阅 · 出征里可扫荡收菜"
	elif unlocked:
		badge = "可挑战"
		badge_col = Color("a06020")
		lines.append("首领未讨伐 · 可出征挑战")
	else:
		lines.append("通关「%s」后解锁" % G.world_name(prev_tid))
		footer = "← → 翻阅其余大陆"

	# 志异题记：让每片大陆除了"状态"还能读出点味道（文案在 data/lore.json）
	var epi := String(G.theme_lore(tid).get("epigraph", ""))
	if not epi.is_empty():
		lines.insert(0, "「%s」" % epi)

	return SlideCardScript.new({
		"kicker": "秘 境 %02d / %02d" % [idx + 1, order.size()],
		"title": G.world_name(tid),
		"art_names": ["world_%s_art" % tid, "world_%s" % tid],
		"art_hint": "world_%s.png" % tid,
		"art_tint": hue,
		"art_fit": "cover",
		"art_dim": not unlocked,
		"art_ratio": 0.44,
		"badge": badge,
		"badge_color": badge_col,
		"lines": lines,
		"footer": footer,
	})
