# Title.gd —— 清晰黄昏城院背景、艺术字入场与右侧菜单。
extends Control
const Wordmark := preload("res://src/ui/UIWordmark.gd")
const Art := preload("res://src/ui/IllustratedUI.gd")

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
	G.page_background(self, 0.14, "res://image/background/courtyard_visual_v2.png", false)


func _build_title() -> void:
	var t := Wordmark.new()
	t.name = "ExpeditionWordmark"
	t.position = Vector2(64, 48)
	t.size = Vector2(352, 176)
	add_child(t)

	var sub := G.gold_label("昭元行旅录", G.FS_XS, false, Color("e3d4b8"), false)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 232)
	sub.size = Vector2(VIEW_W, 22)
	add_child(sub)
	G.reveal_control(sub, 0.64)



# ---------- 右侧按钮列 ----------

func _build_menu() -> void:
	var charter := Art.Charter.new()
	charter.position = Vector2(124,272)
	charter.size = Vector2(332,498)
	add_child(charter)
	var col := VBoxContainer.new()
	col.name = "Menu"
	col.position = Vector2(166,414)
	col.custom_minimum_size = Vector2(260,0)
	col.add_theme_constant_override("separation",8)
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
		custom_minimum_size = Vector2(260,84 if kind == 0 else 46)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_label = G.serif_label(words, 26 if kind == 0 else 22, Color("efdfbd"), false)
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
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _place_label() -> void:
		_label.position = Vector2(36, 1 if _pressed else 0)
		_label.size = Vector2(size.x - 36, size.y)

	func set_active(active: bool) -> void:
		_label.add_theme_color_override("font_color",Color("f2dfad") if active or _kind==0 else Color("365046"))
		_label.add_theme_color_override("font_shadow_color",Color("132b21",.55) if active or _kind==0 else Color.TRANSPARENT)
		if _hover_tween != null and _hover_tween.is_valid(): _hover_tween.kill()
		var target := 1.0 if active else 0.0
		if G.get_meta("ui_review_mode", false) or DisplayServer.get_name() == "headless":
			_light = target
		else:
			_hover_tween = create_tween()
			_hover_tween.tween_property(self, "_light", target, 0.14)

	func _draw() -> void:
		var art := preload("res://src/ui/IllustratedUI.gd")
		if _kind==0:
			art.silk(self,Rect2(Vector2(0,1 if _pressed else 0),size),_light>.5)
			return
		if _light>.01:
			var tex := art.texture("silk_action")
			var dims := Vector2(tex.get_size())
			draw_texture_rect_region(tex,Rect2(32,3,size.x-36,size.y-6),Rect2(dims*Vector2(.18,.34),dims*Vector2(.64,.24)),Color(1,1,1,_light))
			draw_line(Vector2(36,size.y-4),Vector2(size.x-8,size.y-4),Color("bba16c",_light),1)
		var icon := G.NavigationIcons.texture(["door","book","settings","back"][_kind])
		if icon != null: draw_texture_rect(icon,Rect2(10,(size.y-22)*.5,22,22),false)
		draw_line(Vector2(40,size.y-1),Vector2(size.x-6,size.y-1),Color("ac9366",.32),1)
