# WorldPanel.gd —— 世界图志浮层（8 片大陆逐个解锁；已通关 / 可挑战 / 未解锁三态）
# 从 GameHome 的内部类抽出，营帐与主城两处入口共用
class_name WorldPanel
extends Control

signal closed

# 羊皮纸 440 宽 - 左右各 16 内边距 = 内容可用宽；子控件坐标一律按这个基准算，
# 否则整块内容会整体右偏 16px（子控件是挂在 content 上的，不是挂在面板上）
const CONTENT_W := 408.0

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

	for i in order.size():
		var tid := String(order[i])
		content.add_child(_row(tid, String(order[maxi(0, i - 1)]), i))

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 528)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(back)

func _row(tid: String, prev_tid: String, idx: int) -> Control:
	var unlocked: bool = G.is_world_unlocked(tid)
	var cleared: bool = G.is_world_cleared(tid)
	var hue: Color = THEME_HUE.get(tid, Color("8d8474"))

	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CONTENT_W, 48)
	root.position = Vector2(0, 28 + idx * 58)
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.BOX_BG if unlocked else Color("b0a68e")
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 4
	sb.set_border_width_all(2)
	sb.border_color = G.BOX_EDGE if unlocked else Color("8a7f68")
	G._apply_shadow(sb, 4.0, 2.0, 0.32)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	root.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := ColorRect.new()
	bar.color = hue if unlocked else Color(hue.r, hue.g, hue.b, 0.32)
	bar.custom_minimum_size = Vector2(6, 0)
	row.add_child(bar)

	var idx_l := G.gold_label("%02d" % (idx + 1), G.FS_XS, false, Color("8a6a34"), false)
	idx_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(idx_l)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_l := G.gold_label(G.world_name(tid), G.FS_MD, false,
		G.TEXT_DARK if unlocked else Color("6a6152"), false)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(name_l)

	var sub_txt := ""
	var sub_col := Color("8a6a34")
	if cleared:
		sub_txt = "首领已讨伐 · 可重游刷资源"
		sub_col = Color("4a7a44")
	elif unlocked:
		sub_txt = "首领未讨伐 · 可出征挑战"
		sub_col = Color("a06020")
	else:
		sub_txt = "通关「%s」后解锁" % G.world_name(prev_tid)
		sub_col = Color("8a7f68")
	var sub_l := G.gold_label(sub_txt, G.FS_XS, false, sub_col, false)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(sub_l)

	row.add_child(col)

	var mark := G.gold_label("已通关" if cleared else ("可挑战" if unlocked else "未解锁"),
		G.FS_SM, true, Color("4a7a44") if cleared else (Color("a06020") if unlocked else Color("8a7f68")), false)
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(mark)

	root.add_child(row)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root
