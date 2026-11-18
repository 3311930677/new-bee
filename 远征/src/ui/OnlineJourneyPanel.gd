extends Control
## 只呈现选中在线角色的服务器行囊与当前任务。

signal closed
signal equipment_requested(item_id: String, equipped: bool)

var _body: VBoxContainer
var _scroll: ScrollContainer
var _message: Label
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	G.veil(self, 0.94, true)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(G.gold_label("边城手记", G.FS_BIG))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	_scroll.add_child(_body)
	_message = _wrapped("正在查看行囊……", G.FS_SM)
	column.add_child(_message)
	var close := G.ghost_button("返回边城", 0, 48, G.FS_MD)
	_on_press(close, func() -> void: closed.emit())
	column.add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _wrapped(words: String, size: int, highlight := false) -> Label:
	var label := G.gold_label(words, size, highlight)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func set_busy(value: bool) -> void:
	_busy = value
	_body.modulate.a = 0.62 if value else 1.0


func show_message(words: String) -> void:
	_message.text = words
	_message.visible = not words.is_empty()


func _on_press(button: Control, action: Callable) -> void:
	button.gui_input.connect(func(event: InputEvent) -> void:
		if G.ui_blocked:
			return
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept"):
			button.accept_event()
			action.call())


func present(data: Dictionary, preserve_scroll := false) -> void:
	var top := _scroll.scroll_vertical if preserve_scroll else 0
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var quest: Dictionary = data.get("journey", {})
	var items: Dictionary = data.get("pack", {})
	_body.add_child(_wrapped(String(quest.get("title", "当前任务")), G.FS_LG, true))
	var dialogue := String(data.get("dialogue", ""))
	if not dialogue.is_empty():
		_body.add_child(_wrapped("%s · %s" % [data.get("speaker", "来信"), dialogue], G.FS_SM))
	_body.add_child(_wrapped(String(quest.get("goal", "")), G.FS_SM))
	var inventory: Array = items.get("items", [])
	_body.add_child(_wrapped("行囊   %d / %d" % [inventory.size(), int(items.get("capacity", 0))], G.FS_MD, true))
	if inventory.is_empty():
		_body.add_child(_wrapped("行囊还是空的。到闻叔处领取出行装备。", G.FS_SM))
	for kind in ["weapon", "armor", "companion", "potion", ""]:
		for value in inventory:
			if value is Dictionary and String(value.get("kind", "")) == kind:
				_add_item(value)
	_scroll.set_deferred("scroll_vertical", top)
	show_message("")


func _add_item(item: Dictionary) -> void:
	var kind := String(item.get("kind", ""))
	var equipped := not String(item.get("equipped_slot", "")).is_empty()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size.y = 60
	row.set_meta("template_id", String(item.get("template_id", "")))
	_body.add_child(row)
	var icon := TextureRect.new()
	icon.texture = G.res_tex(String(item.get("icon", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(48, 52)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	words.add_child(_wrapped(String(item.get("name", "物品")), G.FS_MD, true))
	var notes: Array[String] = []
	if kind == "potion":
		notes.append("剩余 %d 瓶 · 战斗中使用" % int(item.get("quantity", 0)))
	elif kind == "companion":
		notes.append("已出战" if equipped else "随行伙伴")
	else:
		for stat in [["attack", "攻击"], ["defense", "防御"], ["health", "气血"]]:
			var amount := int(item.get(stat[0], 0))
			if amount > 0:
				notes.append("%s +%d" % [stat[1], amount])
		if equipped:
			notes.append("已装备")
	if not notes.is_empty():
		words.add_child(_wrapped(" · ".join(notes), G.FS_SM))
	if kind in ["weapon", "armor", "companion"]:
		var action := "卸下" if equipped else "装备"
		if kind == "companion":
			action = "休息" if equipped else "出战"
		var button := G.ghost_button(action, 72, 46, G.FS_SM)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_on_press(button, func() -> void:
			if not _busy:
				equipment_requested.emit(String(item.get("item_uid", "")), not equipped))
		row.add_child(button)
