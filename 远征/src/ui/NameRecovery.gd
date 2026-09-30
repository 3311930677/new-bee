# 旧档已有职业却没有创角昵称时，只补昵称，不重建角色或清空养成。
extends Control

var _name: LineEdit
var _hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://image/background/enter.png")
	bg.position = Vector2(0, -26)
	bg.size = Vector2(480, 852)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	G.veil(self, 0.52)
	var banner := G.banner_box("补全旅人姓名", 300, 48, G.FS_LG)
	banner.position = Vector2(90, 198)
	add_child(banner)
	var panel := G.parchment_box(400, 276, 18.0)
	panel.position = Vector2(40, 276)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(content)
	var intro := G.text_label("旧档已保留职业与养成进度。请填写要显示在角色头顶的昵称。",
		G.FS_SM, G.TEXT_DARK)
	intro.position = Vector2(4, 8)
	intro.size = Vector2(356, 50)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	_name = LineEdit.new()
	_name.placeholder_text = "请输入角色昵称"
	_name.max_length = 12
	_name.position = Vector2(4, 77)
	_name.size = Vector2(356, 44)
	G.style_line_edit(_name, G.FS_MD)
	_name.text_submitted.connect(func(_text: String): _confirm())
	content.add_child(_name)
	_hint = G.gold_label("", G.FS_XS, false, G.C_COST, false)
	_hint.position = Vector2(4, 130)
	_hint.size = Vector2(356, 20)
	content.add_child(_hint)
	var back := G.ghost_button("返回登录", 154, 46, G.FS_SM)
	back.position = Vector2(15, 172)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.go("res://src/ui/Login.tscn"))
	content.add_child(back)
	var confirm := G.gold_button("保存并进城", 168, 46, G.FS_SM)
	confirm.position = Vector2(188, 172)
	confirm.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_confirm())
	content.add_child(confirm)
	_name.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		G.go("res://src/ui/Login.tscn")
		get_viewport().set_input_as_handled()


func _confirm() -> void:
	var name := _name.text.strip_edges()
	if name.is_empty():
		_hint.text = "请输入角色昵称"
		return
	if name.length() > 12:
		_hint.text = "昵称最长 12 个字符"
		return
	G.player_name = name
	G.save_game()
	if G.lore_seen():
		G.enter_main_world()
	else:
		G.go("res://src/ui/Prologue.tscn")
