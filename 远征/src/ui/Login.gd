# Login.gd —— 登录界面（参考风：棕木匾 + 羊皮纸面板 + 金按钮）
extends Control

const BG_W := 971.0
const BG_H := 1619.0
const VIEW_W := 480.0
const VIEW_H := 800.0

var _account: LineEdit
var _password: LineEdit
var _toast: Label = null


func _ready() -> void:
	_build_background()
	_build_banner()
	_build_panel()


# ---------- 背景 ----------
func _build_background() -> void:
	var tr := TextureRect.new()
	tr.texture = G.res_tex("bg_main") if G.res_tex("bg_main") != null \
		else load("res://image/background/enter.png")  # 黄昏营地：出征前的整备时刻
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(VIEW_W, VIEW_W * BG_H / BG_W)
	tr.position = Vector2(0, VIEW_H - tr.size.y)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


func _build_banner() -> void:
	var b := G.banner_box("登录", 200, 54)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.position = Vector2(-100, 46)
	add_child(b)


# ---------- 面板 ----------
func _build_panel() -> void:
	var panel := G.parchment_box(372, 306, 22.0)
	panel.position = Vector2(54, 178)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := G.serif_label("账号登录", G.FS_LG, G.BANNER)
	box.add_child(title)

	var sep := ColorRect.new()
	sep.color = Color(G.BANNER.r, G.BANNER.g, G.BANNER.b, 0.45)
	sep.custom_minimum_size = Vector2(0, 2)
	box.add_child(sep)

	_account = _field(box, "账号", "请输入账号", false)
	_password = _field(box, "密码", "请输入密码", true)

	# 老玩家：预填账号，提示语从「创建角色」换成「继续远征」
	var hint_text := "首次登录将直接创建新角色"
	if G.has_profile():
		hint_text = "欢迎回来，登录后继续远征"
		_account.text = G.account
		_account.caret_column = _account.text.length()
	var hint := G.gold_label(hint_text, G.FS_XS, false, Color("8a7350"), false)
	box.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	var ok := G.gold_button("登录", 132, 46)
	var guest := G.gold_button("游客登录", 132, 46)
	row.add_child(ok)
	row.add_child(guest)

	ok.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_do_login(false)
	)
	guest.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_do_login(true)
	)

	_account.grab_focus()


func _field(box: VBoxContainer, label: String, ph: String, secret: bool) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var l := G.gold_label(label, G.FS_MD, true, G.BANNER, false)
	l.custom_minimum_size = Vector2(56, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)

	var le := LineEdit.new()
	le.placeholder_text = ph
	le.secret = secret
	le.max_length = 16
	le.custom_minimum_size = Vector2(248, 42)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	G.style_line_edit(le, G.FS_MD)
	row.add_child(le)
	return le


# ---------- 登录 ----------
func _do_login(guest: bool) -> void:
	if guest:
		G.account = "游客"
	else:
		var acc := _account.text.strip_edges()
		if acc.is_empty():
			_toast_msg("请输入账号")
			return
		if _password.text.is_empty():
			_toast_msg("请输入密码")
			return
		G.account = acc
	# 已有存档（角色已创建）→ 直接回主城；首次登录才进捏人页。
	# 还没看过序章的话先在序章停一站（看过的不再拦，免得打断老玩家）
	if G.has_profile():
		var next := "res://src/ui/GameHome.tscn"
		if not G.lore_seen():
			next = "res://src/ui/Prologue.tscn"
		G.go(next)
	else:
		G.go("res://src/ui/CreateRole.tscn")


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_MD, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 620)
	_toast.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_do_login(false)
	elif event.is_action_pressed("ui_cancel"):
		G.go("res://src/ui/Title.tscn")
