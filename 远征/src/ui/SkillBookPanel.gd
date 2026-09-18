# SkillBookPanel.gd —— 技能书（当前角色 5 技能，每级 k+5%，上限 10 级，耗远征币）
class_name SkillBookPanel
extends Control

signal closed

const CONTENT_W := 408.0

var _rows_box: Control = null
var _expedition_l: Label = null
var _toast: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.78)

	var banner := G.banner_box("技 能 书", 240, 50)
	banner.position = Vector2(120, 30)
	add_child(banner)

	var panel := G.parchment_box(440, 600, 16.0)
	panel.position = Vector2(20, 96)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var role := G.get_role(G.selected_role)
	_expedition_l = G.gold_label("", G.FS_SM, true, Color("4a7a8a"), false)
	_expedition_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_expedition_l.position = Vector2(0, 0)
	content.add_child(_expedition_l)
	# 升级规则收进 ⓘ 弹层，主面板不再铺说明文字
	var info := G.info_button("技能书规则", [
		"每个技能最高 %d 级，每升一级伤害/效果系数 +%d％。" % [
			G.skill_max_level(),
			roundi(float(TableCache.skillbook_config().get("k_per_level", 0.05)) * 100.0)],
		"升级消耗远征币，等级越高费用越贵。",
		"远征币由远征战斗结算产出，战败也有份。",
	], 24.0)
	info.position = Vector2(CONTENT_W - 28.0, -2)
	content.add_child(info)

	_rows_box = Control.new()
	_rows_box.position = Vector2(0, 44)
	content.add_child(_rows_box)

	var close_btn := G.gold_button("返 回", 130, 36, G.FS_MD)
	close_btn.position = Vector2(CONTENT_W / 2.0 - 65, 528)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(close_btn)

	_refresh()


func _refresh() -> void:
	_expedition_l.text = "远征币 %d · 「%s」的五技能" % [
		int(G.wallet.get("expedition", 0)),
		String(G.get_role(G.selected_role).get("name", ""))]
	for c in _rows_box.get_children():
		c.queue_free()
	var role := G.get_role(G.selected_role)
	var sids: Array = role.get("skills", [])
	for i in sids.size():
		var row := _skill_row(String(sids[i]))
		row.position = Vector2(0, i * 88.0)
		_rows_box.add_child(row)


func _skill_row(sid: String) -> Control:
	var sd := TableCache.get_skill(sid)
	var lv := G.skill_level(sid)
	var mx := G.skill_max_level()
	var cost := G.skill_upgrade_cost(sid)

	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CONTENT_W, 80)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f0e2bc")
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 4
	sb.set_border_width_all(2)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5)
	G._apply_shadow(sb, 3.0, 2.0, 0.22)
	root.add_theme_stylebox_override("panel", sb)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)

	var name_l := G.serif_label(String(sd.get("name", sid)), G.FS_MD, G.TEXT_DARK)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(10, 6)
	inner.add_child(name_l)

	# 等级珠：10 颗小点
	for i in mx:
		var dot := Panel.new()
		dot.position = Vector2(10 + i * 17.0, 34)
		dot.size = Vector2(12, 12)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dsb := StyleBoxFlat.new()
		dsb.set_corner_radius_all(6)
		dsb.bg_color = Color("4a7a9a") if i < lv else Color("c8b892")
		dot.add_theme_stylebox_override("panel", dsb)
		inner.add_child(dot)

	var k0 := float(sd.get("k", 0.0))
	# 玩家友好表述：「单体猛击 · 强度+25%」，不暴露 k 系数术语；1 级未强化时不显示强度段
	var eff := String(sd.get("desc", ""))
	var mult := G.skill_k_mult(sid)
	if k0 > 0.0 and mult > 1.001:
		eff += " · 强度 +%d％" % roundi((mult - 1.0) * 100.0)
	var k_l := G.text_label(eff, G.FS_XS, Color("7a5a2e"))
	k_l.position = Vector2(10, 52)
	inner.add_child(k_l)

	var btn := G.gold_button("满 级" if cost <= 0 else "升级 %d" % cost, 108, 34, G.FS_SM)
	btn.position = Vector2(CONTENT_W - 118, 23)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_upgrade(sid))
	inner.add_child(btn)
	return root


func _on_upgrade(sid: String) -> void:
	if G.skill_upgrade(sid):
		_toast_msg("「%s」升至 LV%d" % [String(TableCache.get_skill(sid).get("name", sid)), G.skill_level(sid)])
	else:
		_toast_msg("远征币不足或已满级")
	_refresh()


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_SM, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 706)
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
