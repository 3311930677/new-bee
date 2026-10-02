# Title.gd —— 原版古城插画、艺术字入场与右侧菜单。
extends Control
const Wordmark := preload("res://src/ui/UIWordmark.gd")

const MENU := ["开始游戏", "游戏介绍", "游戏设置", "退出游戏"]

const BG_W := 971.0             # bg_endless 原始宽
const BG_H := 1619.0            # bg_endless 原始高
const VIEW_W := 480.0
const VIEW_H := 800.0

var _btns: Array[Control] = []
var _focus := 0
var _intro_panel: Control = null
var _settings: SettingsPanel = null


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	Audio.play_bgm("bgm_title")
	_build_background()
	_build_title()
	_build_menu()
	_update_focus(0, false)


# ---------- 背景 ----------
func _build_background() -> void:
	G.page_background(self, 0.14, "res://image/background/enter.png")


func _build_title() -> void:
	var t := Wordmark.new()
	t.name = "ExpeditionWordmark"
	t.position = Vector2(100, 64)
	t.size = Vector2(280, 141)
	add_child(t)

	var sub := G.gold_label("昭元行旅录", G.FS_XS, false, Color("e3d4b8"), false)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 212)
	sub.size = Vector2(VIEW_W, 22)
	add_child(sub)
	G.reveal_control(sub, 0.64)



# ---------- 右侧按钮列 ----------

func _build_menu() -> void:
	var col := VBoxContainer.new()
	col.name = "Menu"
	col.position = Vector2(256, 416)
	col.custom_minimum_size = Vector2(196, 0)
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	for i in MENU.size():
		var idx := i
		var button := _EntranceButton.new(MENU[i], i)
		button.gui_input.connect(_on_menu_input.bind(idx))
		button.mouse_entered.connect(func(): _update_focus(idx, true))
		col.add_child(button)
		_btns.append(button)
		G.reveal_control(button, 0.40 + i * 0.075)


func _on_menu_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_activate(idx)


func _update_focus(idx: int, sfx: bool) -> void:
	if idx < 0 or idx >= _btns.size():
		return
	_focus = idx
	for i in _btns.size():
		(_btns[i] as _EntranceButton).set_active(i == _focus)


func _activate(idx: int) -> void:
	match idx:
		0:  # 开始游戏
			G.go("res://src/ui/Login.tscn")
		1:  # 游戏介绍
			_show_intro()
		2:  # 游戏设置：与主界面同一个设置面板（standalone 模式隐藏「回标题」）
			_open_settings()
		3:  # 退出
			get_tree().quit()


# ---------- 设置（接上真正的设置面板，不再是「开发中」占位） ----------
func _open_settings() -> void:
	if _settings != null:
		return
	Audio.sfx("ui_open")
	_settings = SettingsPanel.new()
	_settings.standalone = true
	_settings.closed.connect(func():
		Audio.sfx("ui_close")
		_settings.queue_free()
		_settings = null)
	add_child(_settings)


# ---------- 键盘操作 ----------
func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if _settings != null:
		return   # 设置打开时键盘交给设置面板（它自己处理 Esc 关闭）
	if _intro_panel != null:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_intro_panel.queue_free()
			_intro_panel = null
		return
	if event.is_action_pressed("ui_down"):
		_update_focus(wrapi(_focus + 1, 0, _btns.size()), true)
	elif event.is_action_pressed("ui_up"):
		_update_focus(wrapi(_focus - 1, 0, _btns.size()), true)
	elif event.is_action_pressed("ui_accept"):
		_activate(_focus)


# ---------- 三页手记 ----------
func _show_intro() -> void:
	if _intro_panel != null: return
	var intro := (load("res://src/ui/IntroductionPanel.gd") as GDScript).new() as Control
	_intro_panel = intro
	intro.connect("closed", func():
		_intro_panel.queue_free()
		_intro_panel = null)
	add_child(intro)


func _show_toast(msg: String) -> void:
	var t := G.gold_label(msg, G.FS_MD, false, Color("f5ead0"))
	t.position = Vector2(0, 580)
	t.custom_minimum_size = Vector2(480, 0)
	add_child(t)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(t, "modulate:a", 0.0, 0.5)
	tw.tween_callback(t.queue_free)


# ---------- 与古城同调的木底、旧金边与像素符号 ----------
class _EntranceButton extends Control:
	const SIGNS := [
		["000010000", "000111000", "001010100", "011010110", "111101111", "011010110", "001010100", "000111000", "000010000"],
		["011101110", "110111011", "100010001", "101010101", "100010001", "101010101", "100010001", "110111011", "011101110"],
		["000111000", "010111010", "011000110", "110010011", "110111011", "110010011", "011000110", "010111010", "000111000"],
		["011111110", "010000010", "010010010", "000001000", "111111100", "000001000", "010010010", "010000010", "011111110"],
	]
	var _kind: int
	var _label: Label
	var _grain: Texture2D
	var _pressed := false
	var _light := 0.0:
		set(value):
			_light = value
			queue_redraw()
	var _hover_tween: Tween

	func _init(words: String, kind: int) -> void:
		_kind = kind
		custom_minimum_size = Vector2(196, 56 if kind == 0 else 50)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_label = G.serif_label(words, 20, Color("efdfbd"), false)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_color_override("font_shadow_color", Color("0e0c09", 0.9))
		_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(_label)
		resized.connect(_place_label)
		gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				_pressed = event.pressed
				_place_label()
				queue_redraw())
		mouse_exited.connect(func(): _pressed = false; _place_label(); queue_redraw())
		_grain = _wood_texture()

	func _place_label() -> void:
		_label.position = Vector2(28, 1 if _pressed else 0)
		_label.size = Vector2(size.x - 28, size.y)

	func set_active(active: bool) -> void:
		if _hover_tween != null and _hover_tween.is_valid(): _hover_tween.kill()
		var target := 1.0 if active else 0.0
		if G.get_meta("ui_review_mode", false) or DisplayServer.get_name() == "headless":
			_light = target
		else:
			_hover_tween = create_tween()
			_hover_tween.tween_property(self, "_light", target, 0.14)

	func _wood_texture() -> Texture2D:
		var canvas := Image.create(188, 48, false, Image.FORMAT_RGBA8)
		var base := Color("403023") if _kind == 0 else Color("292620")
		for y in 48:
			for x in 188:
				var grain := float(posmod(x * 7 + y * 29 + x / 9 * y, 17) - 8) / 1050.0
				var striation := 0.013 if posmod(y + x / 40, 9) == 0 else 0.0
				canvas.set_pixel(x, y, Color(base.r + grain + striation, base.g + grain * 0.75 + striation, base.b + grain * 0.5, 1))
		return ImageTexture.create_from_image(canvas)

	func _outline(inset: float, shift := 0.0) -> PackedVector2Array:
		var width := size.x - inset
		var height := size.y - inset + shift
		return PackedVector2Array([
			Vector2(inset + 4, inset + shift), Vector2(width - 4, inset + shift),
			Vector2(width, inset + 4 + shift), Vector2(width, height - 4),
			Vector2(width - 4, height), Vector2(inset + 4, height),
			Vector2(inset, height - 4), Vector2(inset, inset + 4 + shift),
		])

	func _draw() -> void:
		if size.x < 1: return
		var shift := 1.0 if _pressed else 0.0
		draw_colored_polygon(_outline(1, 3), Color("110e0b", 0.68))
		draw_colored_polygon(_outline(0, shift), Color("251e18"))
		draw_colored_polygon(_outline(2, shift), Color("5c4930").lerp(Color("846742"), _light))
		draw_texture_rect(_grain, Rect2(4, 4 + shift, size.x - 8, size.y - 8), false,
			Color(1.0 + _light * 0.16, 1.0 + _light * 0.13, 1.0 + _light * 0.09))
		var rim := Color("8b704c").lerp(Color("d8b97e"), _light)
		var points := _outline(1, shift)
		points.append(points[0])
		draw_polyline(points, rim, 1.0)
		draw_line(Vector2(8, 4 + shift), Vector2(size.x - 8, 4 + shift), Color("b49a6b", 0.55 + _light * 0.2), 1)
		draw_line(Vector2(8, size.y - 4 + shift), Vector2(size.x - 8, size.y - 4 + shift), Color("130f0c"), 1)
		draw_line(Vector2(4, 8 + shift), Vector2(4, size.y - 8 + shift), Color("a0875b", 0.6), 1)
		draw_line(Vector2(size.x - 4, 8 + shift), Vector2(size.x - 4, size.y - 8 + shift), Color("15120d"), 1)
		for at in [Vector2(8, size.y * 0.5 + shift), Vector2(size.x - 8, size.y * 0.5 + shift)]:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4), at + Vector2(3, 0), at + Vector2(0, 4), at + Vector2(-3, 0)]), rim)
			draw_rect(Rect2(at - Vector2.ONE, Vector2(2, 2)), Color("201a12"))
		# 四角铆钉与短金属护片，沿背景的方形像素边缘落位。
		for at in [Vector2(6, 8 + shift), Vector2(size.x - 8, 8 + shift),
				Vector2(6, size.y - 10 + shift), Vector2(size.x - 8, size.y - 10 + shift)]:
			draw_rect(Rect2(at - Vector2.ONE, Vector2(4, 4)), Color("17130e"))
			draw_rect(Rect2(at, Vector2(2, 2)), Color("b19a70"))
		var text_width := G.font_serif.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var start := Vector2(floorf((size.x - text_width - 28) * 0.5), floorf((size.y - 18) * 0.5) + shift)
		for y in 9:
			for x in 9:
				if SIGNS[_kind][y][x] == "1":
					draw_rect(Rect2(start + Vector2(x * 2, y * 2 + 1), Vector2(2, 2)), Color("100e0a", 0.7))
					draw_rect(Rect2(start + Vector2(x * 2, y * 2), Vector2(2, 2)), Color("beaa80").lerp(Color("f1dba3"), _light))
