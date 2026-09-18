# Login.gd —— 登录界面（参考风：棕木匾 + 羊皮纸面板 + 金按钮）
extends Control

const BG_W := 971.0
const BG_H := 1619.0
const VIEW_W := 480.0
const VIEW_H := 800.0

var _account: LineEdit
var _password: LineEdit
var _avatar_caption: Label = null
var _avatar_buttons: Array[Control] = []
var _avatar_row: HBoxContainer = null
var _avatar_dialog: FileDialog = null
var _toast: Label = null

const AVATAR_IDS := ["zs", "ck", "fs", "fz", "custom"]
const AVATAR_NAMES := {"zs": "破军", "ck": "穿杨", "fs": "霜语", "fz": "晨星", "custom": "自定义"}


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
	var panel := G.parchment_box(372, 430, 22.0)
	panel.position = Vector2(54, 150)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := G.serif_label("账号登录", G.FS_LG, G.BANNER)
	box.add_child(title)
	var account_hint := G.gold_label("账号用于识别存档，本地保存，不联网", G.FS_XS, false, Color("8a7350"), false)
	box.add_child(account_hint)

	var sep := ColorRect.new()
	sep.color = Color(G.BANNER.r, G.BANNER.g, G.BANNER.b, 0.45)
	sep.custom_minimum_size = Vector2(0, 2)
	box.add_child(sep)

	_account = _field(box, "账号", "请输入账号", false)
	_password = _field(box, "密码", "请输入密码", true)
	_build_avatar_picker(box)

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

	var ok := G.gold_button("登录", G.BTN_M.x, G.BTN_M.y)
	var guest := G.ghost_button("游客登录", G.BTN_M.x, G.BTN_M.y)
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

	# 底部弱信息：登录页是操作页，不再靠大标题和背景抢中心。
	var legal := G.gold_label("远征 v0.1 · 本地存档 · 不联网", G.FS_XS, false,
		Color("ead7b0", 0.72), false)
	legal.position = Vector2(0, 760)
	legal.custom_minimum_size = Vector2(VIEW_W, 0)
	legal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(legal)


func _build_avatar_picker(box: VBoxContainer) -> void:
	var title := G.gold_label("选择头像", G.FS_SM, true, G.BANNER, false)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	box.add_child(row)
	_avatar_row = row
	_avatar_buttons.clear()
	for id in AVATAR_IDS:
		var card := _avatar_card(id)
		row.add_child(card)
		_avatar_buttons.append(card)
	var selected := "custom" if G.avatar_use_custom and G.has_custom_avatar() \
		else (G.avatar_id if AVATAR_IDS.has(G.avatar_id) else G.selected_role)
	if not AVATAR_IDS.has(selected):
		selected = "zs"
	_select_avatar(selected)
	_avatar_caption = G.gold_label("当前：%s ·「+」可上传本地图片" % String(AVATAR_NAMES.get(selected, "破军")),
		G.FS_XS, false, Color("8a7350"), false)
	box.add_child(_avatar_caption)


func _avatar_card(id: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(60, 78)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.set_meta("avatar_id", id)
	var card := Panel.new()
	card.name = "Card"
	card.size = Vector2(60, 60)
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("dcc9a0")
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.border_color = G.BOX_EDGE
	card.add_theme_stylebox_override("panel", sb)
	root.set_meta("style", sb)
	root.add_child(card)
	var tex: Texture2D = null
	if id == "custom":
		tex = G.custom_avatar_texture()
	else:
		tex = load(G.role_icon_path(id)) as Texture2D
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.custom_minimum_size = Vector2(48, 48)
		pic.position = Vector2(6, 6)
		pic.size = Vector2(48, 48)
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)
	else:
		var plus := G.serif_label("+", G.FS_LG, G.BANNER, false)
		plus.position = Vector2(0, 8)
		plus.size = Vector2(60, 44)
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(plus)
	var mark := G.gold_label("✓", G.FS_XS, true, G.GOLD, false)
	mark.name = "SelectedMark"
	mark.position = Vector2(45, 2)
	mark.size = Vector2(15, 18)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.visible = false
	card.add_child(mark)
	var nm := G.gold_label(String(AVATAR_NAMES.get(id, id)), G.FS_XS, false, Color("7a5a2e"), false)
	nm.position = Vector2(0, 62)
	nm.size = Vector2(60, 16)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(nm)
	root.tooltip_text = "点击上传图片" if id == "custom" else String(AVATAR_NAMES.get(id, id))
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select_avatar(id))
	return root


func _select_avatar(id: String) -> void:
	if not AVATAR_IDS.has(id):
		return
	if id == "custom":
		if not G.use_custom_avatar():
			_open_avatar_picker()
			return
	else:
		G.use_role_avatar(id)
	for card in _avatar_buttons:
		var sb := card.get_meta("style") as StyleBoxFlat
		var active := String(card.get_meta("avatar_id", "")) == id
		if sb != null:
			sb.bg_color = Color("f4e8c8") if active else Color("dcc9a0")
			sb.border_color = G.GOLD if active else G.BOX_EDGE
			sb.set_border_width_all(3 if active else 2)
		var mark := card.get_node_or_null("Card/SelectedMark") as Label
		if mark != null:
			mark.visible = active
	if _avatar_caption != null:
		_avatar_caption.text = "当前：%s ·「+」可上传本地图片" % String(AVATAR_NAMES.get(id, id))


func _avatar_picker() -> FileDialog:
	if _avatar_dialog != null and is_instance_valid(_avatar_dialog):
		return _avatar_dialog
	_avatar_dialog = FileDialog.new()
	_avatar_dialog.title = "选一张图片做头像"
	_avatar_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_avatar_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_avatar_dialog.use_native_dialog = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG)
	_avatar_dialog.add_filter("*.png,*.jpg,*.jpeg,*.webp,*.bmp ; 图片文件", "图片")
	_avatar_dialog.file_selected.connect(_on_avatar_file_selected)
	add_child(_avatar_dialog)
	return _avatar_dialog


func _open_avatar_picker() -> void:
	_avatar_picker().popup_centered()


func _on_avatar_file_selected(path: String) -> void:
	var err := G.import_avatar(path)
	if not err.is_empty():
		_toast_msg(err)
		return
	# 重新建卡：尺寸和选择态都从统一状态源刷新，避免旧的职业图残留。
	_build_avatar_cards_again()
	_toast_msg("头像已更新")


## 上传成功后重建头像行：贴图与选中态都从统一状态源重取，不会残留旧职业图
func _build_avatar_cards_again() -> void:
	if _avatar_row == null or not is_instance_valid(_avatar_row):
		return
	for card in _avatar_buttons:
		card.queue_free()
	_avatar_buttons.clear()
	for id in AVATAR_IDS:
		var card := _avatar_card(id)
		_avatar_row.add_child(card)
		_avatar_buttons.append(card)
	_select_avatar("custom")


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
