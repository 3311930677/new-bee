# Title.gd —— 入场界面（模仿参考游戏登录页布局）
# 满屏背景插画（底部对齐，保证法师完整入画） + 顶部金色标题 + 右侧竖排按钮列
extends Control

const MENU := ["开始游戏", "游戏介绍", "游戏设置", "退出游戏"]

const BG_W := 971.0             # bg_endless 原始宽
const BG_H := 1619.0            # bg_endless 原始高
const VIEW_W := 480.0
const VIEW_H := 800.0

var _btns: Array[Control] = []
var _focus := 0
var _intro_panel: Control = null


func _ready() -> void:
	Audio.play_bgm("bgm_title")
	_build_background()
	_build_title()
	_build_menu()
	_update_focus(0, false)


# ---------- 背景 ----------
func _build_background() -> void:
	# 原图 941×1672，按宽度缩放到 480 → 高 853，比屏幕高 53。
	# 顶部对齐（裁掉最上方天空），底部贴屏 ⇒ 左下角法师完整可见。
	var tr := TextureRect.new()
	tr.name = "BG"
	tr.texture = G.res_tex("bg_endless") if G.res_tex("bg_endless") != null \
		else load("res://image/background/enter.png")  # 星空秘境：中央留白正好承载标题
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(VIEW_W, VIEW_W * BG_H / BG_W)
	tr.position = Vector2(0, VIEW_H - tr.size.y)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	# 底部渐隐，让按钮列可读
	var grad := TextureRect.new()
	grad.name = "Vignette"
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.05, 0.02, 0.0, 0.5)])
	g.offsets = PackedFloat32Array([0.55, 1.0])
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	grad.texture = tex
	add_child(grad)

	# 顶部渐隐，压住城堡亮部，让标题可读
	var top_grad := TextureRect.new()
	top_grad.name = "VignetteTop"
	top_grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ttex := GradientTexture2D.new()
	var tg := Gradient.new()
	tg.colors = PackedColorArray([Color(0.04, 0.02, 0.0, 0.55), Color(0, 0, 0, 0.0)])
	tg.offsets = PackedFloat32Array([0.0, 0.42])
	ttex.gradient = tg
	ttex.fill = GradientTexture2D.FILL_LINEAR
	ttex.fill_from = Vector2(0, 0)
	ttex.fill_to = Vector2(0, 1)
	top_grad.texture = ttex
	add_child(top_grad)


# ---------- 标题（宋体大标 + 收敛描边 + 轻字距） ----------
func _build_title() -> void:
	var t := G.serif_label("远征", G.FS_HERO + 8, G.GOLD_BRIGHT, true)
	t.add_theme_font_override("font", G.spaced_font(10, true, true))
	t.add_theme_constant_override("outline_size", 3)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 52)
	t.size = Vector2(VIEW_W, 118)
	add_child(t)

	var sub := G.gold_label("EXPEDITION", G.FS_SM, false, Color("d8bd8a", 0.8))
	sub.add_theme_font_override("font", G.spaced_font(9, false))
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 166)
	sub.size = Vector2(VIEW_W, 22)
	add_child(sub)

	var rule := _Rule.new()
	rule.position = Vector2(0, 201)
	add_child(rule)


# ---------- 右侧按钮列（轻微错落，避免模板式等宽对齐） ----------
const STAGGER := [0, 14, 6, 18]

func _build_menu() -> void:
	var col := VBoxContainer.new()
	col.name = "Menu"
	col.position = Vector2(286, 316)
	col.custom_minimum_size = Vector2(194, 0)
	col.add_theme_constant_override("separation", 15)
	add_child(col)

	for i in MENU.size():
		var idx := i
		var wrap := MarginContainer.new()
		wrap.add_theme_constant_override("margin_left", STAGGER[i % STAGGER.size()])
		wrap.add_theme_constant_override("margin_right", STAGGER[(i + 2) % STAGGER.size()] / 2)
		var b := G.menu_button(MENU[i])
		b.gui_input.connect(_on_menu_input.bind(idx))
		b.mouse_entered.connect(func(): _update_focus(idx, true))
		wrap.add_child(b)
		col.add_child(wrap)
		_btns.append(b)


func _on_menu_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_activate(idx)


func _update_focus(idx: int, sfx: bool) -> void:
	if idx < 0 or idx >= _btns.size():
		return
	_focus = idx
	for i in _btns.size():
		G.set_button_active(_btns[i], i == _focus)


func _activate(idx: int) -> void:
	match idx:
		0:  # 开始游戏
			G.go("res://src/ui/Login.tscn")
		1:  # 游戏介绍
			_show_intro()
		2:  # 游戏设置（占位提示）
			_show_toast("设置功能开发中")
		3:  # 退出
			get_tree().quit()


# ---------- 键盘操作 ----------
func _unhandled_input(event: InputEvent) -> void:
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


# ---------- 羊皮纸介绍面板 ----------
func _show_intro() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_intro_panel = dim

	var panel := PanelContainer.new()
	panel.position = Vector2(40, 120)
	panel.custom_minimum_size = Vector2(400, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.PARCHMENT
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(3)
	sb.border_color = G.GOLD
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", sb)
	dim.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := G.serif_label("游戏介绍", G.FS_BIG, G.BANNER)
	box.add_child(title)

	var sep := ColorRect.new()
	sep.color = Color(G.BANNER.r, G.BANNER.g, G.BANNER.b, 0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	box.add_child(sep)

	var body := Label.new()
	body.text = """大陆历 947 年，深渊裂隙自北境撕开。

亡国皇子与三名旅人在灰烬中相遇：
持剑的战士、穿杨的猎手、
聆听冰霜低语的法师、执灯的牧师。

他们沿先王的远征路线向北，
穿越森林、雪原、火山与墓穴，
在无尽层叠的深渊中步步登塔——
词条构筑即命运，
每一次抉择都在改写队伍的走向。

失败者不死，只是重整旗鼓。
远征，永不停歇。"""
	body.add_theme_font_override("font", G.font_serif)
	body.add_theme_font_size_override("font_size", G.FS_SM)
	body.add_theme_color_override("font_color", G.TEXT_DARK)
	body.add_theme_constant_override("line_spacing", 7)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(350, 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	var hint := G.gold_label("点击任意处 / 按 确认键 返回", G.FS_XS, false, Color("8a7350", 0.9), false)
	box.add_child(hint)

	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			dim.queue_free()
			_intro_panel = null
	)


func _show_toast(msg: String) -> void:
	var t := G.gold_label(msg, G.FS_MD, false, Color("f5ead0"))
	t.position = Vector2(0, 580)
	t.custom_minimum_size = Vector2(480, 0)
	add_child(t)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(t, "modulate:a", 0.0, 0.5)
	tw.tween_callback(t.queue_free)


# ---------- 标题下的金色分隔线 ----------
class _Rule extends Node2D:
	const CX := 240.0
	const Y := 0.0
	func _draw() -> void:
		var col := Color("c69c4a")
		var seg := 138.0
		# 左右两段细线（中间留空给菱形）
		draw_line(Vector2(CX - seg, Y), Vector2(CX - 10, Y), col, 2.0)
		draw_line(Vector2(CX + 10, Y), Vector2(CX + seg, Y), col, 2.0)
		# 两端小点
		draw_circle(Vector2(CX - seg, Y), 1.5, col)
		draw_circle(Vector2(CX + seg, Y), 1.5, col)
		# 中央菱形
		draw_colored_polygon(PackedVector2Array([
			Vector2(CX, Y - 5), Vector2(CX + 5, Y),
			Vector2(CX, Y + 5), Vector2(CX - 5, Y)]), G.GOLD_BRIGHT)
