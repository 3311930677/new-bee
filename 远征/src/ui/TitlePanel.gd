# TitlePanel.gd —— 称号成就（条件达成免费领 / 荣誉购买；佩戴给小幅加成，程序文字渲染）
class_name TitlePanel
extends Control

signal closed

const CONTENT_W := 408.0

var _rows_box: Control = null
var _active_l: Label = null
var _toast: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.78)

	var banner := G.banner_box("称 号", 240, 50)
	banner.position = Vector2(120, 30)
	add_child(banner)

	var panel := G.parchment_box(440, 620, 16.0)
	panel.position = Vector2(20, 96)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	_active_l = G.gold_label("", G.FS_SM, true, Color("a06020"), false)
	_active_l.position = Vector2(0, 0)
	_active_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_child(_active_l)

	_rows_box = Control.new()
	_rows_box.position = Vector2(0, 28)
	content.add_child(_rows_box)

	var close_btn := G.gold_button("返 回", 130, 36, G.FS_MD)
	close_btn.position = Vector2(CONTENT_W / 2.0 - 65, 566)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(close_btn)

	_refresh()


func _refresh() -> void:
	var tid := G.title_active()
	_active_l.text = "佩戴中：%s" % String(G.title_cfg(tid).get("name", "")) if not tid.is_empty() \
		else "尚未佩戴称号（称号加成随身生效）"
	for c in _rows_box.get_children():
		c.queue_free()
	# 已拥有排前，其余按表序
	var titles := G.titles_cfg()
	var owned: Array = []
	var locked: Array = []
	for t in titles:
		if G.title_owned(String((t as Dictionary).get("id", ""))):
			owned.append(t)
		else:
			locked.append(t)
	var y := 0
	for t in owned + locked:
		var row := _title_row(t as Dictionary)
		row.position = Vector2(0, y)
		_rows_box.add_child(row)
		y += 42


func _title_row(t: Dictionary) -> Control:
	var tid := String(t.get("id", ""))
	var owned := G.title_owned(tid)
	var is_active := G.title_active() == tid
	var met := G.title_cond_met(t)

	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CONTENT_W, 38)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f0e2bc") if owned else Color("d0c09a")
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.border_color = G.GOLD_BRIGHT if is_active else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.4)
	G._apply_shadow(sb, 2.0, 1.0, 0.2)
	root.add_theme_stylebox_override("panel", sb)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)

	# 称号本体：宋体大字（程序文字渲染）
	var name_l := G.serif_label(String(t.get("name", "")), G.FS_MD,
		Color("b8860b") if owned else Color("8a7a58"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(10, 2)
	inner.add_child(name_l)

	var desc := G.text_label("%s%s" % [String(t.get("desc", "")), _bonus_text(t.get("bonus", {}))],
		G.FS_XS - 1, Color("7a5a2e"))
	desc.position = Vector2(10, 24)
	inner.add_child(desc)

	# 按钮：佩戴 / 领取 / 荣誉价 / 未达成
	var btn: Control
	if is_active:
		btn = G.gold_button("佩戴中", 88, 30, G.FS_SM)
		(btn.get_child(0) as Label).add_theme_color_override("font_color", Color("a03020"))
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				G.title_set_active("")
				_refresh())
	elif owned:
		btn = G.gold_button("佩 戴", 88, 30, G.FS_SM)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				G.title_set_active(tid)
				_refresh())
	elif met:
		btn = G.gold_button("领 取", 88, 30, G.FS_SM)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_claim(tid))
	else:
		var cost: Dictionary = t.get("cost", {})
		if cost.is_empty():
			btn = G.gold_button("未达成", 88, 30, G.FS_SM)
			(btn.get_child(0) as Label).add_theme_color_override("font_color", Color("8a7a58"))
		else:
			btn = G.gold_button("%d 荣誉" % int(cost.get("honor", 0)), 88, 30, G.FS_SM)
			btn.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_on_claim(tid))
	btn.position = Vector2(CONTENT_W - 98, 4)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	inner.add_child(btn)
	return root


func _bonus_text(bonus: Dictionary) -> String:
	if bonus.is_empty():
		return ""
	var names := {"atk_pct": "攻", "def_pct": "防", "maxhp_pct": "血", "spd_pct": "速",
		"crit_add": "暴", "atk_add": "攻", "def_add": "防", "hp_add": "血"}
	var parts := PackedStringArray()
	for k in bonus.keys():
		var v := float(bonus[k])
		if String(k).ends_with("_pct") or String(k) == "crit_add":
			parts.append("%s+%d%%" % [String(names.get(String(k), String(k))), roundi(v * 100.0)])
		else:
			parts.append("%s+%d" % [String(names.get(String(k), String(k))), int(v)])
	return "（%s）" % " ".join(parts)


func _on_claim(tid: String) -> void:
	var r := G.title_claim(tid)
	_toast_msg("称号「%s」入手！" % String(G.title_cfg(tid).get("name", "")) if bool(r.get("ok", false))
		else String(r.get("err", "")))
	_refresh()


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_SM, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 726)
	_toast.custom_minimum_size = Vector2(480, 0)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
