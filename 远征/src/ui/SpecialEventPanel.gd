class_name SpecialEventPanel
extends Control

signal closed
signal action_selected(choice: String)
var _list: VBoxContainer
var _scroll: ScrollContainer

func open_event(display: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	G.center_fixed_page.call_deferred(self)
	G.veil(self,0.78,true)
	var paper := G.parchment_box(432,656,18)
	paper.position = Vector2(24,64)
	add_child(paper)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	paper.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var title := G.serif_label(String(display.get("name","路上奇遇")),24,Color("6a4a1e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 34
	column.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = 374
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation",14)
	_scroll.add_child(_list)
	var art_path := String(display.get("art",""))
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		var image := TextureRect.new()
		image.texture = load(art_path)
		image.custom_minimum_size = Vector2(160,160)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(image)
	var body := G.text_label(String(display.get("body","")),G.FS_SM,Color("594731"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(body)
	var choices: Dictionary = display.get("choices",{})
	for key in choices:
		var button := _button(String(choices[key]),String(key))
		# Decisions remain visible while the longer story scrolls independently.
		column.add_child(button)
	var back := _button("回到路上","")
	column.add_child(back)
	# Focus the persistent footer; focusing a choice would scroll past the story on open.
	back.grab_focus.call_deferred()

func _button(label: String, choice: String) -> Control:
	var button := G.gold_button(label,374,46,G.FS_SM)
	button.custom_minimum_size = Vector2(374,46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.gui_input.connect(func(event: InputEvent):
		var click: bool = event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT
		var key: bool = event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("ui_accept")
		if click or key:
			if not choice.is_empty(): action_selected.emit(choice)
			get_viewport().set_input_as_handled())
	if choice.is_empty():
		button.gui_input.connect(func(event: InputEvent):
			if (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) \
				or (event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("ui_accept")): close())
	return button

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not G.ui_blocked:
		close()
		get_viewport().set_input_as_handled()
