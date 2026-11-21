extends Control
## 登录页：全屏高清远景底图（assets/full_issue_fix_20261024/ready/login_background.png）+ 真实高精矢量/组件 UI。
## 彻底移除整图截图贴图方案，消除上下空边与模糊贴图文字。
const UI := preload("res://src/ui/TravelChestUI.gd")
const Flow := preload("res://src/ui/FlowChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const KitV4 := preload("res://src/ui/KitV4.gd")
const UIWordmark := preload("res://src/ui/UIWordmark.gd")
const BG_TEX := "res://assets/full_issue_fix_20261024/ready/login_background.png"
const KIT := "res://assets/ui/login_20261014/"

var host: Control
var _kit: Dictionary = {}
var _sky_fill: ColorRect
var _ground_fill: ColorRect
var _backdrop: TextureRect
var _art: TextureRect
var _shade_top: TextureRect
var _shade_bot: TextureRect
var _back: Button
var _go: Button
var _guest: Button
var _eye: Button
var _error: Label
var _note: Label
var _avatar: TextureRect
var _form_scroll: ScrollContainer
var _form_body: Control
var _paper_bg: Control
var _paper_header: Control
var _acc_title: Label
var _acc_box: Panel
var _pwd_title: Label
var _pwd_box: Panel
var _ava_title: Label
var _ava_title_line: Label
var _ava_hint_line: Label
var _ava_compass: Control
var _subtitle_bg: Panel
var _last_keyboard := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("safe_layout_exempt", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	if FileAccess.file_exists(KIT + "login_kit.json"):
		_kit = JSON.parse_string(FileAccess.get_file_as_string(KIT + "login_kit.json"))
	_sky_fill = ColorRect.new()
	_sky_fill.name = "SkyFill"
	_sky_fill.color = Color("1a110b")
	_sky_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sky_fill)
	_ground_fill = ColorRect.new()
	_ground_fill.name = "GroundFill"
	_ground_fill.color = Color(0, 0, 0, 0)
	_ground_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground_fill)

	var hd_tex: Texture2D = load(BG_TEX) if ResourceLoader.exists(BG_TEX) else load(KIT + "login_bg.png")
	_backdrop = TextureRect.new()
	_backdrop.name = "LoginBackdrop"
	_backdrop.texture = hd_tex
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_art = TextureRect.new()
	_art.name = "LoginArt"
	_art.texture = hd_tex
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_art)

	_shade_top = _make_gradient(Color(0.06, 0.04, 0.02, 0.48), Color(0.06, 0.04, 0.02, 0.0))
	add_child(_shade_top)
	_shade_bot = _make_gradient(Color(0.05, 0.03, 0.02, 0.0), Color(0.05, 0.03, 0.02, 0.72))
	add_child(_shade_bot)

	# 顶部真实书法字标与副标牌匾
	var wm := UIWordmark.new()
	wm.name = "Wordmark"
	wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wm)
	host._wordmark = wm

	_subtitle_bg = Panel.new()
	_subtitle_bg.name = "SubtitlePlaque"
	_subtitle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub_sb := StyleBoxFlat.new()
	sub_sb.bg_color = Color("241710", 0.88)
	sub_sb.border_color = Color("d4a85c", 0.85)
	sub_sb.set_border_width_all(1)
	sub_sb.set_corner_radius_all(4)
	_subtitle_bg.add_theme_stylebox_override("panel", sub_sb)
	add_child(_subtitle_bg)

	host._subtitle = Label.new()
	host._subtitle.name = "Subtitle"
	host._subtitle.text = "◆  昭 元 行 旅 录  ◆"
	host._subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	host._subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._subtitle.add_theme_font_override("font", G.font_serif)
	host._subtitle.add_theme_font_size_override("font_size", G.FS_XS)
	host._subtitle.add_theme_color_override("font_color", Color("f4dfb4"))
	host._subtitle.add_theme_color_override("font_outline_color", Color("180e08"))
	host._subtitle.add_theme_constant_override("outline_size", 2)
	add_child(host._subtitle)

	_back = Flow.button("‹", func(): G.go("res://src/ui/Title.tscn"))
	_back.skin = "back"
	_back.tooltip_text = "返回标题"
	add_child(_back)

	# 登记纸签容器（支持软键盘弹起时滚动）
	_form_scroll = ScrollContainer.new()
	_form_scroll.name = "RegistrationPaper"
	_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_form_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_form_scroll)
	host._paper = _form_scroll

	_form_body = Control.new()
	_form_body.name = "FormBody"
	_form_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_form_scroll.add_child(_form_body)

	_paper_bg = _PaperCard.new()
	_paper_bg.name = "PaperBg"
	_paper_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_form_body.add_child(_paper_bg)

	_paper_header = _HeaderPlaque.new()
	_paper_header.name = "PaperHeader"
	_paper_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_form_body.add_child(_paper_header)

	_acc_title = _section_label("◆ 通关文牒", "A C C O U N T")
	_form_body.add_child(_acc_title)
	_acc_box = _input_frame()
	_form_body.add_child(_acc_box)

	host._account = _field("输入账号")
	host._account.name = "Account"
	host._account.text = G.account if G.account != "游客" else ""
	_form_body.add_child(host._account)

	_pwd_title = _section_label("◆ 通关秘钥", "P A S S W O R D")
	_form_body.add_child(_pwd_title)
	_pwd_box = _input_frame()
	_form_body.add_child(_pwd_box)

	host._password = _field("输入密码")
	host._password.name = "Password"
	host._password.secret = true
	host._password.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_form_body.add_child(host._password)

	_eye = _EyeButton.new(host)
	_eye.name = "EyeToggle"
	_eye.focus_mode = Control.FOCUS_NONE
	_eye.pressed.connect(func():
		host._password.secret = not host._password.secret
		_eye.queue_redraw())
	_form_body.add_child(_eye)

	host._account.text_submitted.connect(func(_words: String): host._password.grab_focus())
	host._password.text_submitted.connect(func(_words: String): host._do_login(false))

	_ava_title = _section_label("◆ 旅人画相", "P O R T R A I T")
	_form_body.add_child(_ava_title)

	host._avatar_card_btn = _AvatarCardButton.new()
	host._avatar_card_btn.name = "AvatarCard"
	host._avatar_card_btn.pressed.connect(func(): host._select_avatar("custom"))
	_form_body.add_child(host._avatar_card_btn)

	_ava_compass = _CompassMedallion.new()
	_ava_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._avatar_card_btn.add_child(_ava_compass)

	_avatar = TextureRect.new()
	_avatar.name = "AvatarDisc"
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var round_mask := Shader.new()
	round_mask.code = "shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV); c.a*=1.0-smoothstep(0.46,0.5,distance(UV,vec2(0.5))); COLOR=c; }"
	var round_mat := ShaderMaterial.new()
	round_mat.shader = round_mask
	_avatar.material = round_mat
	host._avatar_card_btn.add_child(_avatar)
	host._avatar_medallion = _avatar

	_ava_title_line = Label.new()
	_ava_title_line.text = "自选旅人画像 · 导入图片"
	_ava_title_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ava_title_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ava_title_line.add_theme_font_override("font", G.font_bold)
	_ava_title_line.add_theme_font_size_override("font_size", G.FS_CAPTION)
	_ava_title_line.add_theme_color_override("font_color", Color("3a2414"))
	host._avatar_card_btn.add_child(_ava_title_line)

	_ava_hint_line = Label.new()
	_ava_hint_line.text = "支持 PNG / JPG · 创角与主城通用"
	_ava_hint_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ava_hint_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ava_hint_line.add_theme_font_override("font", G.font_reg)
	_ava_hint_line.add_theme_font_size_override("font_size", G.FS_DENSE)
	_ava_hint_line.add_theme_color_override("font_color", Color("6e5438"))
	host._avatar_card_btn.add_child(_ava_hint_line)

	_go = UI.action("登录入城", "primary")
	_go.name = "LoginButton"
	_go.pressed.connect(func(): host._do_login(false))
	add_child(_go)

	_guest = UI.action("游客入城", "secondary")
	_guest.name = "GuestButton"
	_guest.pressed.connect(func(): host._do_login(true))
	add_child(_guest)

	_note = _caption("◆ 旅途进度自动保存在本机 · 离线可读 ◆", Color("e8d7b2"))
	host._footer = _note
	_error = _caption("", Color("ffb59a"))
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("1a0f0a", 0.90)
	plate.border_color = Color("d07a4e")
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(4)
	plate.content_margin_left = 10
	plate.content_margin_right = 10
	plate.content_margin_top = 2
	plate.content_margin_bottom = 2
	_error.add_theme_stylebox_override("normal", plate)
	_error.visible = false
	refresh_avatar()
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self, layout)
	layout()
	Flow.wire_focus(self)
	layout.call_deferred()

func _make_gradient(top_c: Color, bot_c: Color) -> TextureRect:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([top_c, bot_c])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _section_label(cn: String, _en: String) -> Label:
	var l := Label.new()
	l.text = cn
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", G.font_bold)
	l.add_theme_font_size_override("font_size", G.FS_XS)
	l.add_theme_color_override("font_color", Color("4a2e18"))
	return l

func _input_frame() -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f6ecda", 0.96)
	sb.border_color = Color("9e7744", 0.92)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _field(hint: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = hint
	edit.max_length = 16
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 10
	clear.content_margin_right = 10
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(1, 0.96, 0.84, 0.28)
	focus.border_color = Color("c2842b")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	focus.content_margin_left = 10
	focus.content_margin_right = 10
	for state in ["normal", "read_only"]:
		edit.add_theme_stylebox_override(state, clear)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_font_override("font", G.font_reg)
	edit.add_theme_font_size_override("font_size", G.FS_SM)
	edit.add_theme_color_override("font_color", Color("2b1d10"))
	edit.add_theme_color_override("font_placeholder_color", Color("8a7254"))
	edit.add_theme_color_override("caret_color", Color("8a3a1c"))
	edit.add_theme_color_override("selection_color", Color("c89848", 0.35))
	return edit

func _caption(words: String, color: Color) -> Label:
	var l := Label.new()
	l.text = words
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", G.font_serif)
	l.add_theme_font_size_override("font_size", G.FS_XS)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("140a05"))
	l.add_theme_constant_override("outline_size", 2)
	add_child(l)
	return l

func refresh_avatar() -> void:
	var tex := G.custom_avatar_texture() if G.avatar_use_custom else null
	_avatar.texture = tex
	_avatar.visible = tex != null

func error(words: String) -> void:
	_error.text = words
	_error.visible = not words.is_empty()
	layout()

func layout(safe_override: Rect2 = Rect2(), keyboard_override: float = -1.0) -> void:
	if not is_instance_valid(_form_scroll):
		return
	var vp_size := get_viewport_rect().size
	# Full-rect backgrounds inherit this view; anchors alone own their geometry.
	_shade_top.position = Vector2.ZERO
	_shade_top.size = Vector2(vp_size.x, 180.0)
	_shade_bot.position = Vector2(0, maxf(0.0, vp_size.y - 260.0))
	_shade_bot.size = Vector2(vp_size.x, 260.0)

	var safe := safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var keyboard := DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
	if keyboard > 0 and keyboard_override < 0.0:
		keyboard_override = float(keyboard) * vp_size.y / maxf(1.0, float(get_window().size.y))
	var typing := keyboard_override > 0.0

	_back.position = Vector2(safe.position.x + 10.0, safe.position.y + 8.0).round()
	_back.size = Vector2(44, 44)

	var card_w := clampf(safe.size.x - 40.0, 320.0, 404.0)
	var card_x := roundf(safe.position.x + (safe.size.x - card_w) * 0.5)
	var inner_w := card_w - 44.0
	var body_h := 356.0

	# 内部表单排版（固定 356px 内容高，软键盘弹起时外框缩小并可滚动）
	_form_body.custom_minimum_size = Vector2(card_w, body_h)
	_form_body.size = Vector2(card_w, body_h)
	_paper_bg.position = Vector2.ZERO
	_paper_bg.size = Vector2(card_w, body_h)
	_paper_header.position = Vector2(18, 10)
	_paper_header.size = Vector2(card_w - 36.0, 44)

	_acc_title.position = Vector2(22, 62)
	_acc_title.size = Vector2(inner_w, 24)
	_acc_box.position = Vector2(22, 88)
	_acc_box.size = Vector2(inner_w, 46)
	host._account.position = Vector2(24, 90)
	host._account.size = Vector2(inner_w - 4.0, 42)

	_pwd_title.position = Vector2(22, 144)
	_pwd_title.size = Vector2(inner_w, 24)
	_pwd_box.position = Vector2(22, 170)
	_pwd_box.size = Vector2(inner_w, 46)
	host._password.position = Vector2(24, 172)
	host._password.size = Vector2(inner_w - 50.0, 42)
	_eye.position = Vector2(22 + inner_w - 44.0, 171)
	_eye.size = Vector2(44, 44)

	_ava_title.position = Vector2(22, 224)
	_ava_title.size = Vector2(inner_w, 24)
	host._avatar_card_btn.position = Vector2(22, 250)
	host._avatar_card_btn.size = Vector2(inner_w, 86)
	_ava_compass.position = Vector2(14, 11)
	_ava_compass.size = Vector2(64, 64)
	_avatar.position = Vector2(20, 17)
	_avatar.size = Vector2(52, 52)
	_ava_title_line.position = Vector2(88, 16)
	_ava_title_line.size = Vector2(inner_w - 102.0, 26)
	_ava_hint_line.position = Vector2(88, 44)
	_ava_hint_line.size = Vector2(inner_w - 102.0, 24)

	var btn_w := clampf(card_w - 12.0, 300.0, 384.0)
	var btn_x := roundf(safe.position.x + (safe.size.x - btn_w) * 0.5)
	var go_h := 56.0
	var guest_h := 50.0

	if typing:
		var avail_bottom := safe.end.y - keyboard_override
		var go_y := roundf(avail_bottom - go_h - 6.0)
		var scroll_top := roundf(safe.position.y + 56.0)
		var scroll_h := maxf(120.0, minf(body_h, go_y - scroll_top - 10.0))
		_form_scroll.position = Vector2(card_x, scroll_top)
		_form_scroll.size = Vector2(card_w, scroll_h)
		_go.position = Vector2(btn_x, go_y)
		_go.size = Vector2(btn_w, go_h)
		_guest.visible = false
		host._wordmark.visible = false
		_subtitle_bg.visible = false
		host._subtitle.visible = false
		_note.visible = false
		_error.position = Vector2(card_x, maxf(safe.position.y + 8.0, scroll_top - 30.0)).round()
		_error.size = Vector2(card_w, 26)
		_reveal_focus.call_deferred()
	else:
		host._wordmark.visible = true
		_subtitle_bg.visible = true
		host._subtitle.visible = true
		_guest.visible = true
		_note.visible = not _error.visible

		var total_h := 132.0 + body_h + 14.0 + go_h + 10.0 + guest_h + 34.0
		var start_y := roundf(safe.position.y + maxf(8.0, (safe.size.y - total_h) * 0.42))
		var wm_w := 252.0
		var wm_h := 82.0
		host._wordmark.position = Vector2(roundf(safe.position.x + (safe.size.x - wm_w) * 0.5), start_y)
		host._wordmark.size = Vector2(wm_w, wm_h)

		var sub_w := 216.0
		var sub_h := 28.0
		var sub_pos := Vector2(roundf(safe.position.x + (safe.size.x - sub_w) * 0.5), start_y + 84.0)
		_subtitle_bg.position = sub_pos
		_subtitle_bg.size = Vector2(sub_w, sub_h)
		host._subtitle.position = sub_pos
		host._subtitle.size = Vector2(sub_w, sub_h)

		var paper_y := start_y + 124.0
		var max_paper_bottom := safe.end.y - (go_h + guest_h + 56.0)
		var paper_h := minf(body_h, maxf(220.0, max_paper_bottom - paper_y))
		_form_scroll.position = Vector2(card_x, roundf(paper_y))
		_form_scroll.size = Vector2(card_w, roundf(paper_h))

		var go_y := roundf(_form_scroll.position.y + _form_scroll.size.y + 12.0)
		_go.position = Vector2(btn_x, go_y)
		_go.size = Vector2(btn_w, go_h)

		var guest_y := roundf(go_y + go_h + 8.0)
		_guest.position = Vector2(btn_x, guest_y)
		_guest.size = Vector2(btn_w, guest_h)

		var note_y := minf(safe.end.y - 26.0, guest_y + guest_h + 6.0)
		var note_pos := Vector2(roundf(safe.position.x + 12.0), roundf(note_y))
		var note_sz := Vector2(roundf(safe.size.x - 24.0), 24.0)
		_note.position = note_pos
		_note.size = note_sz
		_error.position = note_pos
		_error.size = note_sz

func _reveal_focus() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit and _form_scroll != null:
		_form_scroll.ensure_control_visible(focus)

func _process(_delta: float) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var height := DisplayServer.virtual_keyboard_get_height()
	if height != _last_keyboard:
		_last_keyboard = height
		layout()


class _PaperCard extends Control:
	const UI := preload("res://src/ui/TravelChestUI.gd")
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.38))
		var ptex: Texture2D = UI.texture("paper")
		if ptex != null:
			UI.nine(self, ptex, size, 24)
		else:
			draw_rect(r, Color("efe1c6", 0.96))
		draw_rect(r.grow(-3), Color("8c6538", 0.85), false, 2.0)
		draw_rect(r.grow(-7), Color("b8925a", 0.45), false, 1.0)


class _HeaderPlaque extends Control:
	var title_l: Label
	var sub_l: Label
	func _init() -> void:
		title_l = Label.new()
		title_l.text = "旅 人 登 记"
		title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_l.add_theme_font_override("font", G.font_bold)
		title_l.add_theme_font_size_override("font_size", G.FS_MD)
		title_l.add_theme_color_override("font_color", Color("ffe7b6"))
		title_l.add_theme_color_override("font_outline_color", Color("1a0e06"))
		title_l.add_theme_constant_override("outline_size", 2)
		add_child(title_l)
		sub_l = Label.new()
		sub_l.text = "— 昭元行旅通关文牒 —"
		sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_l.add_theme_font_override("font", G.font_serif)
		sub_l.add_theme_font_size_override("font_size", G.FS_DENSE)
		sub_l.add_theme_color_override("font_color", Color("d7ba86"))
		add_child(sub_l)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and title_l != null and sub_l != null:
			title_l.position = Vector2(0, 2)
			title_l.size = Vector2(size.x, 24)
			sub_l.position = Vector2(0, 23)
			sub_l.size = Vector2(size.x, 18)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("2b1b12", 0.95))
		draw_rect(r, Color("c89b52", 0.90), false, 2.0)
		draw_rect(r.grow(-3), Color("7a582c", 0.55), false, 1.0)


class _EyeButton extends Button:
	var _host: Control
	func _init(h: Control) -> void:
		_host = h
		text = ""
		flat = true
		tooltip_text = "显示或隐藏密码"
		set("accessibility_name", "显示或隐藏密码")
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
	func _draw() -> void:
		var c := size * 0.5
		var col := Color("5a3e24") if not is_hovered() else Color("8a5a28")
		draw_arc(c + Vector2(0, 3), 10.0, PI * 1.15, PI * 1.85, 16, col, 2.0)
		draw_arc(c + Vector2(0, -3), 10.0, PI * 0.15, PI * 0.85, 16, col, 2.0)
		draw_circle(c, 3.2, col)
		if _host != null and _host._password != null and not _host._password.secret:
			draw_line(c + Vector2(-10, 7), c + Vector2(10, -7), Color("8a2e1b"), 2.2)


class _AvatarCardButton extends Button:
	func _init() -> void:
		text = ""
		flat = true
		tooltip_text = "自选旅人画像 · 导入图片"
		set("accessibility_name", "自选旅人画像 · 导入图片")
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for s in [mouse_entered, mouse_exited, button_down, button_up, focus_entered, focus_exited]:
			s.connect(queue_redraw)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := Color("f3e5cb", 0.96)
		if is_pressed():
			bg = Color("e4d0ad", 0.98)
		elif is_hovered():
			bg = Color("f9efdc", 0.98)
		draw_rect(r, bg)
		draw_rect(r, Color("c89844") if (is_hovered() or has_focus()) else Color("9e7744", 0.92), false, 2.0)
		draw_rect(r.grow(-4), Color("b8945c", 0.40), false, 1.0)


class _CompassMedallion extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.46
		draw_circle(c, rad, Color("2a1d14"))
		draw_arc(c, rad, 0.0, TAU, 32, Color("c89b52"), 2.2)
		draw_arc(c, rad - 4.0, 0.0, TAU, 32, Color("7d5c32"), 1.2)
		for i in 8:
			var a := float(i) * TAU / 8.0
			var r0 := rad - (10.0 if i % 2 == 0 else 6.0)
			draw_line(c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * (rad - 2.0), Color("d8b26e"), 1.5)
		draw_circle(c, 5.0, Color("d8b26e"))
