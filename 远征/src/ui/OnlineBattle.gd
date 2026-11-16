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
	_button(_actions, "攻 · 普通攻击", _emit_action.bind("attack"))
	_button(_actions, "技 · 选中技能", _emit_action.bind("skill"))
	_button(_actions, "物 · 使用药品", _emit_action.bind("potion"))
	_button(_actions, "逃 · 退出战斗", _emit_action.bind("flee"))
	_ack = _button(column, "确认结算 · 返回城镇", func() -> void: acknowledge_requested.emit())
	_ack.hide()
	_button(column, "暂离 · 返回在线角色", func() -> void: leave_requested.emit())


func _button(parent: Control, text: String, action: Callable) -> Control:
	var button := G.ghost_button(text, 0, 50, G.FS_MD)
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
	_title.text = {"victory": "试炼告捷", "defeat": "暂且休整", "flee": "平安撤离", "draw": "试炼结束"}.get(String(battle.get("result", "")), "城南试炼")
	_summary.text = "%s · %.1f 秒" % [Online.selected_character.get("nickname", "旅人"), float(state.get("tick", 0)) / 30.0]
	for value_unit in state.get("units", []):
		if not value_unit is Dictionary:
			continue
		var unit := value_unit as Dictionary
		var uid := int(unit.get("uid", -1))
		if not _cards.has(uid):
			var row := HBoxContainer.new()
			row.custom_minimum_size.y = 112
			row.add_theme_constant_override("separation", 12)
			var portrait: Control
			if String(unit.get("kind", "")) == "role":
				portrait = preload("res://src/ui/FieldUI.gd").portrait(String(Online.selected_character.get("role_id", "zs")), Vector2.ZERO, Vector2(100, 112))
			else:
				var picture := TextureRect.new()
				picture.texture = load("res://image/generated_101_200/ready/map/mon_wolf.png")
				picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				portrait = picture
			portrait.custom_minimum_size = Vector2(100, 112)
			row.add_child(portrait)
			var card := VBoxContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.add_theme_constant_override("separation", 10)
			row.add_child(card)
			var caption := G.gold_label("", G.FS_MD)
			card.add_child(caption)
			var health := ProgressBar.new()
			health.custom_minimum_size.y = 26
			health.show_percentage = false
			var track := StyleBoxFlat.new()
			track.bg_color = G.BG_DEEP
			track.border_color = G.GOLD
			track.set_border_width_all(1)
			track.set_corner_radius_all(3)
			var fill := StyleBoxFlat.new()
			fill.bg_color = G.GOLD_BRIGHT
			fill.set_corner_radius_all(3)
			health.add_theme_stylebox_override("background", track)
			health.add_theme_stylebox_override("fill", fill)
			card.add_child(health)
			var note := G.gold_label("", G.FS_SM, false)
			card.add_child(note)
			_units.add_child(row)
			_cards[uid] = {"caption": caption, "health": health, "note": note}
		var card: Dictionary = _cards[uid]
		(card.caption as Label).text = String(Online.selected_character.get("nickname", "旅人")) if String(unit.get("side", "")) == "ally" else String(unit.get("name", "野狼"))
		(card.health as ProgressBar).max_value = maxi(1, int(unit.get("max_hp", 1)))
		(card.health as ProgressBar).value = int(unit.get("hp", 0))
		(card.note as Label).text = "气血 %d/%d · 能量 %d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 0)), int(unit.get("energy", 0))]
		if String(unit.get("kind", "")) == "role":
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
	var last: Dictionary = battle.get("last_input", {})
	if not last.is_empty():
		_feedback.text = {"attacked": "攻击命中", "cast": "技能已施放", "used": "已使用药品", "fled": "已离开战斗", "unavailable": "条件尚未满足，试试其他行动。", "cooldown": "正在准备下一次攻击。", "controlled": "暂时受控，稍候再行动。", "finished": "战斗已经结束。"}.get(String(last.get("reason", "")), "行动已记录")
	if settled:
		var receipt: Dictionary = battle.get("receipt", {})
		_feedback.text = "本次获得：金币 %d · 阅历 %d\n在线金币余额 %d" % [int(receipt.get("gold", 0)), int(receipt.get("experience", 0)), int(receipt.get("wallet_balance", 0))]
