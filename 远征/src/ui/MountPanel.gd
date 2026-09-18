# MountPanel.gd —— 坐骑（6 类×2 阶：购入 1 阶 → 升 2 阶；骑乘加成全局生效）
class_name MountPanel
extends Control

signal closed

const CONTENT_W := 408.0
const CARD_W := 198.0
const CARD_H := 148.0

var _grid: Control = null
var _active_l: Label = null
var _toast: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.78)

	var banner := G.banner_box("坐 骑", 240, 50)
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

	_grid = Control.new()
	_grid.position = Vector2(0, 28)
	content.add_child(_grid)

	var close_btn := G.gold_button("返 回", 130, 36, G.FS_MD)
	close_btn.position = Vector2(CONTENT_W / 2.0 - 65, 556)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(close_btn)

	_refresh()


func _refresh() -> void:
	var mid := G.mount_active()
	_active_l.text = "骑乘中：%s" % String(G.mount_cfg(mid).get("name", "")) if not mid.is_empty() \
		else "尚未骑乘任何坐骑（购入后自动骑乘）"
	for c in _grid.get_children():
		c.queue_free()
	var mounts := G.mounts_cfg()
	for i in mounts.size():
		var card := _mount_card(mounts[i] as Dictionary)
		card.position = Vector2((i % 2) * (CARD_W + 8.0), (i / 2) * (CARD_H + 8.0))
		_grid.add_child(card)


func _mount_card(m: Dictionary) -> Control:
	var mid := String(m.get("id", ""))
	var tier := G.mount_tier(mid)
	var tiers: Array = m.get("tiers", [])
	var is_active := G.mount_active() == mid and tier > 0

	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f0e2bc") if tier > 0 else Color("d0c09a")
	sb.corner_radius_top_left = 7
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 4
	sb.set_border_width_all(2)
	sb.border_color = G.GOLD_BRIGHT if is_active else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5)
	G._apply_shadow(sb, 3.0, 2.0, 0.25)
	root.add_theme_stylebox_override("panel", sb)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)

	# 坐骑图（按阶级切换素材）
	var icon := String(m.get("icon2" if tier >= 2 else "icon", ""))
	var tex: Texture2D = G.res_tex(icon)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(56, 56)
		tr.size = Vector2(56, 56)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(6, 6)
		tr.modulate = Color.WHITE if tier > 0 else Color(0.55, 0.55, 0.55)
		inner.add_child(tr)

	var name_l := G.serif_label(String(m.get("name", "")), G.FS_MD,
		G.TEXT_DARK if tier > 0 else Color("8a7a58"))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(68, 8)
	inner.add_child(name_l)

	# 当前/下一阶加成说明
	var show_tier := mini(tier, tiers.size() - 1)
	var tinfo := tiers[show_tier] as Dictionary
	var bonus: Dictionary = tinfo.get("bonus", {})
	var bl := G.text_label("%s：%s" % [String(tinfo.get("name", "")), _bonus_text(bonus)],
		G.FS_XS, Color("7a5a2e"))
	bl.position = Vector2(68, 34)
	bl.custom_minimum_size = Vector2(122, 40)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(bl)

	var tier_l := G.gold_label("未拥有" if tier == 0 else ("二阶" if tier >= 2 else "一阶"),
		G.FS_XS, true, Color("a06020") if tier > 0 else Color("8a7a58"), false)
	tier_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tier_l.position = Vector2(6, 66)
	inner.add_child(tier_l)

	# 按钮：购买 / 升阶 / 骑乘 / 骑乘中
	var btn: Control
	if tier <= 0 or tier < tiers.size():
		var cost: Dictionary = tinfo.get("cost", {})
		btn = G.gold_button("购 买" if tier <= 0 else "升 阶", 84, 30, G.FS_SM)
		var cost_l := G.text_label(_cost_text(cost), G.FS_XS - 1, Color("8a6a34"))
		cost_l.position = Vector2(96, 104)
		inner.add_child(cost_l)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_buy(mid))
	elif is_active:
		btn = G.gold_button("骑乘中", 84, 30, G.FS_SM)
		(btn.get_child(0) as Label).add_theme_color_override("font_color", Color("a03020"))
	else:
		btn = G.gold_button("骑 乘", 84, 30, G.FS_SM)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if G.mount_set_active(mid):
					_toast_msg("已骑乘「%s」" % String(m.get("name", "")))
					_refresh())
	btn.position = Vector2(6, 100)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	inner.add_child(btn)
	return root


func _bonus_text(bonus: Dictionary) -> String:
	var names := {"atk_pct": "攻击", "def_pct": "防御", "maxhp_pct": "生命", "spd_pct": "速度", "crit_add": "暴击"}
	var parts := PackedStringArray()
	for k in bonus.keys():
		parts.append("%s+%d%%" % [String(names.get(String(k), String(k))), roundi(float(bonus[k]) * 100.0)])
	return " ".join(parts)


func _cost_text(cost: Dictionary) -> String:
	var names := {"gold": "金币", "soul": "魂石", "honor": "荣誉", "expedition": "远征币"}
	var parts := PackedStringArray()
	for k in cost.keys():
		parts.append("%s %d" % [String(names.get(String(k), String(k))), int(cost[k])])
	return " ".join(parts)


func _on_buy(mid: String) -> void:
	var r := G.mount_buy(mid)
	if bool(r.get("ok", false)):
		_toast_msg("「%s」%s" % [String(G.mount_cfg(mid).get("name", "")),
			"已入手！" if int(r.get("tier", 0)) == 1 else "升至二阶！"])
	else:
		_toast_msg(String(r.get("err", "")))
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
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
