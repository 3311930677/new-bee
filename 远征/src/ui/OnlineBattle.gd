extends Control
## 只展示服务器快照，不创建 BattleSim，也不在客户端生成掉落。

signal command_requested(action: Dictionary)
signal acknowledge_requested
signal leave_requested

var battle: Dictionary = {}
var _title: Label
var _summary: Label
var _feedback: Label
var _units: VBoxContainer
var _skills: OptionButton
var _actions: GridContainer
var _ack: Control
var _potion_button: Control
var _cards: Dictionary = {}
var _busy := false


func _ready() -> void:
	theme = preload("res://src/ui/LacquerUI.gd").theme()
	var background := ColorRect.new()
	background.color = G.BG_DEEP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var landscape := TextureRect.new()
	landscape.texture = load("res://image/battle/art_v2/forest_clearing.png")
	landscape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	landscape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	landscape.modulate.a = 0.16
	landscape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	landscape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(landscape)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_title = G.gold_label("城南试炼", G.FS_BIG)
	column.add_child(_title)
	_summary = G.gold_label("正在等待战斗……", G.FS_SM, false)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_summary)
	_units = VBoxContainer.new()
	_units.add_theme_constant_override("separation", 10)
	column.add_child(_units)
	_skills = OptionButton.new()
	_skills.custom_minimum_size.y = 44
	_style_option(_skills)
	column.add_child(_skills)
	_feedback = G.gold_label("攻、技、物、逃，由你决定下一步。", G.FS_SM, false)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_feedback)
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	_actions = GridContainer.new()
	_actions.columns = 2
	_actions.add_theme_constant_override("h_separation", 10)
	_actions.add_theme_constant_override("v_separation", 10)
	column.add_child(_actions)
	_button(_actions, "攻 · 普通攻击", _emit_action.bind("attack"), true)
	_button(_actions, "技 · 选中技能", _emit_action.bind("skill"))
	_potion_button = _button(_actions, "物 · 治疗药剂", _emit_action.bind("potion"))
	_button(_actions, "逃 · 退出战斗", _emit_action.bind("flee"))
	_ack = _button(column, "确认结算 · 返回城镇", func() -> void: acknowledge_requested.emit(), true)
	_ack.hide()
	_button(column, "暂离 · 返回在线角色", func() -> void: leave_requested.emit())


func _style_option(opt: OptionButton) -> void:
	opt.add_theme_font_override("font", G.font_reg)
	opt.add_theme_font_size_override("font_size", G.FS_SM)
	opt.add_theme_color_override("font_color", G.PARCHMENT)
	opt.add_theme_color_override("font_hover_color", G.GOLD_BRIGHT)
	opt.add_theme_color_override("font_pressed_color", G.GOLD_BRIGHT)
	opt.add_theme_color_override("font_focus_color", G.PARCHMENT)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color("1b1613", 0.96)
	sb_n.border_color = Color("b8924d", 0.85)
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(4)
	sb_n.content_margin_left = 10
	sb_n.content_margin_top = 6
	sb_n.content_margin_right = 10
	sb_n.content_margin_bottom = 6
	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color("261e19", 0.98)
	sb_h.border_color = G.GOLD_BRIGHT
	opt.add_theme_stylebox_override("normal", sb_n)
	opt.add_theme_stylebox_override("hover", sb_h)
	opt.add_theme_stylebox_override("pressed", sb_h)
	opt.add_theme_stylebox_override("focus", sb_h)


func _button(parent: Control, text: String, action: Callable, primary := false) -> Control:
	var button := G.gold_button(text, 0, 50, G.FS_MD) if primary else G.ghost_button(text, 0, 50, G.FS_MD)
	button.custom_minimum_size.y = 50
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.gui_input.connect(func(event: InputEvent) -> void:
		if G.ui_blocked or _busy:
			return
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept"):
			button.accept_event()
			action.call())
	parent.add_child(button)
	return button


func _emit_action(action: String) -> void:
	var payload := {"action": action}
	if action == "skill":
		if _skills.selected < 0:
			return
		payload["skill_id"] = String(_skills.get_item_metadata(_skills.selected))
	command_requested.emit(payload)


func set_busy(value: bool) -> void:
	_busy = value
	_actions.modulate.a = 0.55 if value else 1.0


func show_error(message: String) -> void:
	_feedback.text = message


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave_requested.emit()


func present(value: Dictionary) -> void:
	battle = value.duplicate(true)
	var state: Dictionary = battle.get("state", {})
	var settled := String(battle.get("status", "")) == "settled"
	_actions.visible = not settled
	_skills.visible = not settled
	_ack.visible = settled
	var title := "碑影巡查" if String(battle.get("encounter_id", "")) == "southern_patrol" else "城南试炼"
	_title.text = {"victory": "试炼告捷", "defeat": "暂且休整", "flee": "平安撤离", "draw": "试炼结束"}.get(String(battle.get("result", "")), title)
	_summary.text = "%s · %.1f 秒" % [Online.selected_character.get("nickname", "旅人"), float(state.get("tick", 0)) / 30.0]
	(_potion_button.get_child(0) as Label).text = "物 · 药剂 %d" % int(state.get("potions", 0))
	_potion_button.modulate.a = 1.0 if int(state.get("potions", 0)) > 0 and int(state.get("potion_cd", 0)) == 0 else 0.65
	var live_cards: Array[int] = []
	for value_unit in state.get("units", []):
		if not value_unit is Dictionary:
			continue
		var unit := value_unit as Dictionary
		var uid := int(unit.get("uid", -1))
		live_cards.append(uid)
		var unit_kind := String(unit.get("kind", ""))
		var template := String(unit.get("template_id", ""))
		if not _cards.has(uid):
			var is_ally := unit_kind == "role" or String(unit.get("side", "")) == "ally"
			var panel := PanelContainer.new()
			var p_sb := StyleBoxFlat.new()
			p_sb.bg_color = Color("16120f", 0.92)
			p_sb.border_color = Color("4bb887", 0.80) if is_ally else Color("cf5648", 0.80)
			p_sb.set_border_width_all(1)
			p_sb.set_corner_radius_all(6)
			p_sb.set_content_margin_all(8)
			panel.add_theme_stylebox_override("panel", p_sb)
			var row := HBoxContainer.new()
			row.custom_minimum_size.y = 88
			row.add_theme_constant_override("separation", 12)
			panel.add_child(row)
			var portrait: Control
			if unit_kind == "role":
				portrait = preload("res://src/ui/FieldUI.gd").portrait(String(Online.selected_character.get("role_id", "zs")), Vector2.ZERO, Vector2(84, 88))
			else:
				var picture := TextureRect.new()
				if template == "pet_rockturtle":
					picture.texture = G.res_tex("pet_rockturtle")
				else:
					var path := "mon_treant" if template == "mon_treant" else "mon_wolf"
					picture.texture = load("res://image/generated_101_200/ready/map/%s.png" % path) as Texture2D
				picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				portrait = picture
			portrait.custom_minimum_size = Vector2(84, 88)
			row.add_child(portrait)
			var card := VBoxContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.add_theme_constant_override("separation", 6)
			row.add_child(card)
			var caption := G.gold_label("", G.FS_MD)
			card.add_child(caption)
			var health := ProgressBar.new()
			health.custom_minimum_size.y = 20
			health.show_percentage = false
			var track := StyleBoxFlat.new()
			track.bg_color = G.BG_DEEP
			track.border_color = Color("8c7040", 0.85)
			track.set_border_width_all(1)
			track.set_corner_radius_all(3)
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color("3fa876") if is_ally else Color("cc4438")
			fill.set_corner_radius_all(3)
			health.add_theme_stylebox_override("background", track)
			health.add_theme_stylebox_override("fill", fill)
			card.add_child(health)
			var energy := ProgressBar.new()
			energy.custom_minimum_size.y = 8
			energy.max_value = 100
			energy.show_percentage = false
			var e_track := track.duplicate() as StyleBoxFlat
			var e_fill := StyleBoxFlat.new()
			e_fill.bg_color = Color("4b8fd4")
			e_fill.set_corner_radius_all(2)
			energy.add_theme_stylebox_override("background", e_track)
			energy.add_theme_stylebox_override("fill", e_fill)
			card.add_child(energy)
			var note := G.gold_label("", G.FS_SM, false)
			card.add_child(note)
			_units.add_child(panel)
			_cards[uid] = {"panel": panel, "row": row, "caption": caption, "health": health, "energy": energy, "note": note}
		var card: Dictionary = _cards[uid]
		(card.caption as Label).text = String(Online.selected_character.get("nickname", "旅人")) if unit_kind == "role" else String(unit.get("name", "对手"))
		(card.health as ProgressBar).max_value = maxi(1, int(unit.get("max_hp", 1)))
		(card.health as ProgressBar).value = int(unit.get("hp", 0))
		(card.energy as ProgressBar).value = clampi(int(unit.get("energy", 0)), 0, 100)
		(card.note as Label).text = "气血 %d/%d · 能量 %d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 0)), int(unit.get("energy", 0))]
		if unit_kind == "role":
			var selected := _skills.selected
			_skills.clear()
			for skill_value in unit.get("skills", []):
				if not skill_value is Dictionary:
					continue
				var skill := skill_value as Dictionary
				var definition: Dictionary = skill.get("def", {})
				_skills.add_item("%s · 冷却 %.1fs" % [definition.get("name", skill.get("id", "")), float(skill.get("cd_left", 0)) / 30.0])
				_skills.set_item_metadata(_skills.item_count - 1, skill.get("id", ""))
			if _skills.item_count > 0:
				_skills.select(clampi(selected, 0, _skills.item_count - 1))
	for uid in _cards.keys():
		if not live_cards.has(uid):
			(_cards[uid].panel as Control).queue_free()
			_cards.erase(uid)
	var last: Dictionary = battle.get("last_input", {})
	if not last.is_empty():
		_feedback.text = {"attacked": "攻击命中", "cast": "技能已施放", "used": "已使用药品", "fled": "已离开战斗", "unavailable": "条件尚未满足，试试其他行动。", "cooldown": "正在准备下一次攻击。", "controlled": "暂时受控，稍候再行动。", "finished": "战斗已经结束。"}.get(String(last.get("reason", "")), "行动已记录")
	if settled:
		var receipt: Dictionary = battle.get("receipt", {})
		_feedback.text = "本次获得：金币 %d · 阅历 %d\n在线金币余额 %d" % [int(receipt.get("gold", 0)), int(receipt.get("experience", 0)), int(receipt.get("wallet_balance", 0))]
