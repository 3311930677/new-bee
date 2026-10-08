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
	t.position = Vector2(60, 44)
	t.size = Vector2(360, 186)
	add_child(t)

# ---------- 右侧按钮列 ----------

func _build_menu() -> void:
	var board := _MenuBoard.new()
	board.name = "MenuBoard"
	board.position = Vector2(90, 396)
	board.size = Vector2(300, 246)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	var col := VBoxContainer.new()
	col.name = "Menu"
	col.position = Vector2(105, 412)
	col.custom_minimum_size = Vector2(270, 214)
	col.add_theme_constant_override("separation", 8)
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


# ---------- 半透明暗色菜单底板 ----------
class _MenuBoard extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 10: return
		# 1. 深度投影
		draw_rect(Rect2(4, 8, w - 8, h - 6), Color(0.0, 0.0, 0.0, 0.6))
		# 2. 沉稳微暖半透明黑曜/铁木底板 (0.86 alpha，清晰隔绝背景干扰)
		draw_rect(Rect2(0, 0, w, h), Color(0.07, 0.08, 0.11, 0.88))
		# 3. 内部微暗层
		draw_rect(Rect2(3, 3, w - 6, h - 6), Color(0.09, 0.11, 0.14, 0.7))

		# 4. 外圈暗铁色双线框
		draw_rect(Rect2(0, 0, w, h), Color("181e26"), false, 1.0)
		draw_rect(Rect2(2, 2, w - 4, h - 4), Color("283240", 0.7), false, 1.0)

		# 5. 上下古金饰线
		var gold_dim := Color("8a7040", 0.5)
		draw_line(Vector2(16, 6), Vector2(w - 16, 6), gold_dim, 1.0)
		draw_line(Vector2(16, h - 6), Vector2(w - 16, h - 6), gold_dim, 1.0)

		# 6. 精致金色铜角码 (四角 12px L形)
		var gc := Color("c8a252")
		var gc_hi := Color("ffe288")
		var arm := 12.0
		# 左上
		draw_line(Vector2(3, 3), Vector2(3 + arm, 3), gc_hi, 1.0)
		draw_line(Vector2(3, 3), Vector2(3, 3 + arm), gc_hi, 1.0)
		draw_rect(Rect2(4, 4, 2, 2), gc)
		# 右上
		draw_line(Vector2(w - 4, 3), Vector2(w - 4 - arm, 3), gc_hi, 1.0)
		draw_line(Vector2(w - 4, 3), Vector2(w - 4, 3 + arm), gc_hi, 1.0)
		draw_rect(Rect2(w - 6, 4, 2, 2), gc)
		# 左下
		draw_line(Vector2(3, h - 4), Vector2(3 + arm, h - 4), gc, 1.0)
		draw_line(Vector2(3, h - 4), Vector2(3, h - 4 - arm), gc, 1.0)
		draw_rect(Rect2(4, h - 6, 2, 2), gc)
		# 右下
		draw_line(Vector2(w - 4, h - 4), Vector2(w - 4 - arm, h - 4), gc, 1.0)
		draw_line(Vector2(w - 4, h - 4), Vector2(w - 4, h - 4 - arm), gc, 1.0)
		draw_rect(Rect2(w - 6, h - 6, 2, 2), gc)


# ---------- 精致半透明菜单按钮 ----------
class _EntranceButton extends Control:
	var _kind: int
	var _label: Label
	var _pressed := false
	var _light := 0.0:
		set(value):
			_light = value
			queue_redraw()
	var _hover_tween: Tween

	func _init(words: String, kind: int) -> void:
		_kind = kind
		var h := 50.0 if kind == 0 else 44.0
		custom_minimum_size = Vector2(270, h)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_label = G.serif_label(words, 21 if kind == 0 else 18, Color("f3e4c8"), false)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_color_override("font_shadow_color", Color("06080a", 0.95))
		_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(_label)
		resized.connect(_place_label)
		gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				_pressed = event.pressed
				_place_label()
				queue_redraw())
		mouse_exited.connect(func(): _pressed = false; _place_label(); queue_redraw())

	func _place_label() -> void:
		var dy := 1 if _pressed else 0
		_label.position = Vector2(0, dy)
		_label.size = Vector2(size.x, size.y)

	func set_active(active: bool) -> void:
		_label.add_theme_color_override("font_color", Color("fff6d8") if (active or _kind == 0) else Color("c6baa4"))
		if _hover_tween != null and _hover_tween.is_valid(): _hover_tween.kill()
		var target := 1.0 if active else 0.0
		if G.get_meta("ui_review_mode", false) or DisplayServer.get_name() == "headless":
			_light = target
		else:
			_hover_tween = create_tween()
			_hover_tween.tween_property(self, "_light", target, 0.12)

	func _draw() -> void:
		var dy := 1.0 if _pressed else 0.0
		var w := size.x
		var h := size.y
		var is_primary := (_kind == 0)
		var is_active := (_light > 0.05 or is_primary)

		# 1. 投影
		if not _pressed:
			draw_rect(Rect2(1, 2 + dy, w - 2, h - 2), Color(0.0, 0.0, 0.0, 0.35))

		# 2. 背景填充：主按钮与激活项带温暖琥珀沉稳底，未激活项通透微暗
		if is_primary:
			var bg_primary := Color("221a16", 0.85) if _light > 0.5 else Color("1a1618", 0.78)
			draw_rect(Rect2(0, dy, w, h), bg_primary)
			# 微暖渐变条
			draw_rect(Rect2(1, dy + 1, w - 2, h * 0.45), Color(0.4, 0.3, 0.15, 0.14))
		elif _light > 0.05:
			var bg_hover := Color("1c1e26", 0.75)
			draw_rect(Rect2(0, dy, w, h), bg_hover)
		else:
			draw_rect(Rect2(0, dy, w, h), Color("10141c", 0.45))

		# 3. 边框逻辑
		if is_primary:
			# 亮金双重外框
			var gold_main := Color("e2b85a") if _light > 0.5 else Color("c89e46")
			draw_rect(Rect2(0, dy, w, h), gold_main, false, 1.0)
			draw_line(Vector2(2, dy + 1), Vector2(w - 2, dy + 1), Color("fff0a8", 0.7), 1.0)
			draw_line(Vector2(2, dy + h - 2), Vector2(w - 2, dy + h - 2), Color("7a5618", 0.7), 1.0)
			# 四角金色嵌块
			var bcol := Color("ffe490")
			draw_line(Vector2(1, dy + 1), Vector2(5, dy + 1), bcol, 1.0)
			draw_line(Vector2(1, dy + 1), Vector2(1, dy + 5), bcol, 1.0)
			draw_line(Vector2(w - 2, dy + 1), Vector2(w - 6, dy + 1), bcol, 1.0)
			draw_line(Vector2(w - 2, dy + 1), Vector2(w - 2, dy + 5), bcol, 1.0)
			draw_line(Vector2(1, dy + h - 2), Vector2(5, dy + h - 2), bcol, 1.0)
			draw_line(Vector2(1, dy + h - 2), Vector2(1, dy + h - 6), bcol, 1.0)
			draw_line(Vector2(w - 2, dy + h - 2), Vector2(w - 6, dy + h - 2), bcol, 1.0)
			draw_line(Vector2(w - 2, dy + h - 2), Vector2(w - 2, dy + h - 6), bcol, 1.0)
		elif _light > 0.05:
			draw_rect(Rect2(0, dy, w, h), Color("c49e52", _light * 0.8), false, 1.0)
			draw_line(Vector2(1, dy + 1), Vector2(w - 1, dy + 1), Color("ffebaa", _light * 0.4), 1.0)
		else:
			draw_rect(Rect2(0, dy, w, h), Color("2e3848", 0.45), false, 1.0)

		# 4. 激活/选中状态两侧装饰菱形 (左右对称，典雅大方)
		if is_active:
			var icon_alpha := 1.0 if is_primary else (_light * 0.9)
			var cy := h * 0.5 + dy
			# 左侧菱形
			var lx := 22.0
			var l_diamond := PackedVector2Array([
				Vector2(lx, cy - 4), Vector2(lx + 4, cy),
				Vector2(lx, cy + 4), Vector2(lx - 4, cy)
			])
			draw_colored_polygon(l_diamond, Color("eac468", icon_alpha))
			draw_circle(Vector2(lx, cy), 1.0, Color("ffffff", icon_alpha))
			# 右侧菱形
			var rx := w - 22.0
			var r_diamond := PackedVector2Array([
				Vector2(rx, cy - 4), Vector2(rx + 4, cy),
				Vector2(rx, cy + 4), Vector2(rx - 4, cy)
			])
			draw_colored_polygon(r_diamond, Color("eac468", icon_alpha))
			draw_circle(Vector2(rx, cy), 1.0, Color("ffffff", icon_alpha))

