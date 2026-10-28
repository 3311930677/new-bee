extends Control
## A crisp full-height background; form controls own their layout and hit targets.
const Reading := preload("res://src/ui/ReadingSkin.gd")
const Wordmark := preload("res://src/ui/UIWordmark.gd")
var host: Control
var _backdrop: TextureRect
var _art: TextureRect
var _back: Button
var _go: Button
var _guest: Button
var _eye: Button
var _error: Label
var _note: Label
var _avatar: TextureRect
var _form_scroll: ScrollContainer
var _column: VBoxContainer
var _header: VBoxContainer
var _top: HBoxContainer
var _last_keyboard := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("safe_layout_exempt",true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = TextureRect.new()
	_backdrop.name = "LoginBackdrop"
	_backdrop.texture = load("res://assets/full_issue_fix_20261024/ready/login_background.png")
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_art = _backdrop
	host._paper = Reading.frame(true)
	host._paper.name = "RegistrationPaper"
	add_child(host._paper)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation",12)
	host._paper.add_child(_column)
	var top := HBoxContainer.new()
	_top = top
	_column.add_child(top)
	_back = Reading.button("‹")
	_back.custom_minimum_size = Vector2(44,44)
	_back.tooltip_text = "返回标题"
	_back.pressed.connect(func():G.go("res://src/ui/Title.tscn"))
	top.add_child(_back)
	var caption := Reading.label("旅人登记",24)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(caption)
	_header = VBoxContainer.new()
	_column.add_child(_header)
	host._wordmark = Wordmark.new()
	host._wordmark.custom_minimum_size = Vector2(0,88)
	_header.add_child(host._wordmark)
	host._subtitle = Reading.label("昭元行旅录",20)
	host._subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_child(host._subtitle)
	_form_scroll = ScrollContainer.new()
	_form_scroll.name = "RegistrationFields"
	_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_scroll.follow_focus = true
	_column.add_child(_form_scroll)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation",10)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_scroll.add_child(form)
	form.add_child(Reading.label("通关文牒 · 账号",20))
	host._account = _field("输入账号")
	host._account.name = "Account"
	host._account.text = G.account if G.account!="游客" else ""
	form.add_child(host._account)
	form.add_child(Reading.label("通关秘钥 · 密码",20))
	var secret_row := HBoxContainer.new()
	secret_row.add_theme_constant_override("separation",8)
	form.add_child(secret_row)
	host._password = _field("输入密码")
	host._password.name = "Password"
	host._password.secret = true
	host._password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	secret_row.add_child(host._password)
	_eye = Reading.button("显")
	_eye.custom_minimum_size = Vector2(56,56)
	_eye.tooltip_text = "显示或隐藏密码"
	_eye.pressed.connect(func():host._password.secret=not host._password.secret;_eye.text="显" if host._password.secret else "隐")
	secret_row.add_child(_eye)
	var avatar_row := HBoxContainer.new()
	avatar_row.add_theme_constant_override("separation",10)
	form.add_child(avatar_row)
	_avatar = TextureRect.new()
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar.custom_minimum_size = Vector2(48,48)
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_row.add_child(_avatar)
	host._avatar_medallion = _avatar
	host._avatar_card_btn = Reading.button("自选画像 · 导入图片")
	host._avatar_card_btn.add_theme_font_size_override("font_size",20)
	host._avatar_card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._avatar_card_btn.name = "AvatarCard"
	host._avatar_card_btn.pressed.connect(func():host._select_avatar("custom"))
	avatar_row.add_child(host._avatar_card_btn)
	host._account.text_submitted.connect(func(_text:String):host._password.grab_focus())
	host._password.text_submitted.connect(func(_text:String):host._do_login(false))
	_error = Reading.label("",20,Color("962c21"))
	_error.visible = false
	_column.add_child(_error)
	_go = Reading.button("登录入城",true)
	_go.name = "LoginButton"
	_go.pressed.connect(func():host._do_login(false))
	_column.add_child(_go)
	_guest = Reading.button("游客入城")
	_guest.name = "GuestButton"
	_guest.pressed.connect(func():host._do_login(true))
	_column.add_child(_guest)
	_note = Reading.label("旅途进度自动保存在本机 · 离线可读",16)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_note)
	host._footer = _note
	refresh_avatar()
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	layout()
	layout.call_deferred()

func _field(hint: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.max_length = 16
	field.custom_minimum_size.y = 56
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_override("font",G.font_reg)
	field.add_theme_font_size_override("font_size",22)
	field.add_theme_color_override("font_color",Reading.INK)
	field.add_theme_color_override("font_placeholder_color",Color("78674f"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7edda")
	style.border_color = Color("987b4b")
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	field.add_theme_stylebox_override("normal",style)
	var focus := style.duplicate()
	focus.border_color = Color("c48b27")
	field.add_theme_stylebox_override("focus",focus)
	return field

func refresh_avatar() -> void:
	var custom := G.custom_avatar_texture() if G.avatar_use_custom else null
	_avatar.texture = custom if custom!=null else load("res://assets/ui/home/icons/hero_40.png")

func error(words: String) -> void:
	_error.text = words
	_error.visible = not words.is_empty()
	layout()

func layout(safe_override := Rect2(), keyboard_override := -1.0) -> void:
	if not is_instance_valid(host._paper):return
	var safe := safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var keyboard := DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
	if keyboard>0:keyboard_override=float(keyboard)*get_viewport_rect().size.y/maxf(1,get_window().size.y)
	var typing := keyboard_override>0
	_top.visible = not typing
	_header.visible = not typing and safe.size.y>=700
	_guest.visible = not typing
	_note.visible = not typing and not _error.visible and safe.size.y>=700
	var available := safe
	if typing:available.size.y=maxf(240,safe.size.y-keyboard_override)
	var extent := Vector2(minf(432,available.size.x-24),minf(742 if not typing else 480,available.size.y-24))
	host._paper.position = (available.get_center()-extent*.5).round()
	host._paper.size = extent
	var form := _form_scroll.get_child(0) as Control
	form.custom_minimum_size.x = maxf(120,extent.x-44)
	if typing:
		_reveal_focus.call_deferred()

func _reveal_focus() -> void:
	# The VBox sorts after visibility/size changes; reveal only after that layout.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:_form_scroll.ensure_control_visible(focus)

func _process(_delta: float) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):return
	var height := DisplayServer.virtual_keyboard_get_height()
	if height!=_last_keyboard:
		_last_keyboard=height
		layout()
