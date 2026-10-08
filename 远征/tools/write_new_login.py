NEW_LOGIN_GD = '''# Login.gd —— 旅人登记卡，工业级古典奇幻通关文牒风格。
extends Control

const UI := preload("res://src/ui/JournalUI.gd")
const Wordmark := preload("res://src/ui/UIWordmark.gd")
const ART_FONT := preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const VIEW_W := 480.0
const AVATAR_IDS := ["custom"]

var _account: LineEdit
var _password: LineEdit
var _paper: PanelContainer
var _footer: Label
var _wordmark: Control
var _subtitle: Label
var _avatar_card_btn: Button
var _avatar_medallion: Control
var _avatar_dialog: FileDialog
var _toast: Label


func _ready() -> void:
	G.page_background(self, 0.18, "res://image/background/courtyard_visual_v2.png", false)
	_build_banner()
	_build_panel()
	resized.connect(_layout_page)
	_layout_page.call_deferred()


func _build_banner() -> void:
	var back := UI.button("返回", 80, 44, "dark_quiet", "back")
	back.position = Vector2(26, 38)
	back.pressed.connect(func(): G.go("res://src/ui/Title.tscn"))
	add_child(back)
	_wordmark = Wordmark.new()
	_wordmark.size = Vector2(248, 122)
	add_child(_wordmark)
	_subtitle = UI.label("昭元行旅录", 15, Color("ead6ad"), true)
	_subtitle.size.x = 480
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_shadow_color", Color("152a29"))
	_subtitle.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_subtitle)


func _build_panel() -> void:
	# 408 x 512 羊皮纸装牒卡片，内边距对称设置为 16
	_paper = UI.paper(408, 512, 16)
	_paper.name = "RegistrationCard"
	add_child(_paper)

	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(content)

	# 1. 顶部黑曜/玄玉题名匾额（独立封装，不再切穿纸面）
	var plaque := _TitlePlaque.new()
	plaque.position = Vector2(0, 0)
	plaque.size = Vector2(376, 52)
	content.add_child(plaque)

	# 2. 迎宾致辞（位于温润羊皮纸上，深墨书法体）
	var returning := G.has_profile() or not G.selected_role.is_empty()
	var greeting_text := "欢迎回来，继续上次旅程。" if returning else "欢迎来到昭元，旅人。"
	var greeting := G.serif_label(greeting_text, 13, Color("3c2c1a"), false)
	greeting.position = Vector2(0, 60)
	greeting.size = Vector2(376, 20)
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(greeting)

	# 3. 装饰金线
	var div1 := _FleuronDivider.new()
	div1.position = Vector2(16, 84)
	div1.size = Vector2(344, 8)
	content.add_child(div1)

	# 4. 账号输入栏
	var acc_lbl := G.serif_label("通关文牒", 14, Color("362818"), false)
	acc_lbl.position = Vector2(6, 104)
	acc_lbl.size = Vector2(68, 38)
	acc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(acc_lbl)

	_account = _create_input_field("你的文牒账号")
	_account.name = "Account"
	_account.position = Vector2(78, 102)
	_account.size = Vector2(290, 40)
	content.add_child(_account)

	# 5. 密码输入栏
	var pwd_lbl := G.serif_label("通关秘钥", 14, Color("362818"), false)
	pwd_lbl.position = Vector2(6, 152)
	pwd_lbl.size = Vector2(68, 38)
	pwd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(pwd_lbl)

	_password = _create_input_field("输入通关密码", true)
	_password.name = "Password"
	_password.position = Vector2(78, 150)
	_password.size = Vector2(290, 40)
	content.add_child(_password)

	if returning:
		_account.text = G.account
	_account.text_submitted.connect(func(_text: String): _password.grab_focus())
	_password.text_submitted.connect(func(_text: String): _do_login(false))

	# 6. 旅人小像（圆形勋章 + 自定义图片引导卡片）
	var ava_lbl := G.serif_label("旅人画相", 14, Color("362818"), false)
	ava_lbl.position = Vector2(6, 212)
	ava_lbl.size = Vector2(68, 24)
	content.add_child(ava_lbl)

	_avatar_medallion = _AvatarMedallion.new()
	_avatar_medallion.position = Vector2(78, 200)
	_avatar_medallion.size = Vector2(50, 50)
	_avatar_medallion.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_avatar("custom"))
	content.add_child(_avatar_medallion)

	_avatar_card_btn = _AvatarTagButton.new()
	_avatar_card_btn.position = Vector2(136, 200)
	_avatar_card_btn.size = Vector2(232, 50)
	_avatar_card_btn.pressed.connect(func(): _select_avatar("custom"))
	content.add_child(_avatar_card_btn)

	# 7. 装饰金线
	var div2 := _FleuronDivider.new()
	div2.position = Vector2(16, 264)
	div2.size = Vector2(344, 8)
	content.add_child(div2)

	# 8. 主按钮：登录入城（富丽堂皇的朱红金边大主纽）
	var login := _LoginCTAButton.new("登 录 入 城", true)
	login.name = "LoginButton"
	login.position = Vector2(6, 280)
	login.size = Vector2(364, 48)
	login.pressed.connect(func(): _do_login(false))
	content.add_child(login)

	# 9. 次按钮：游客入城（沉稳典雅的玄铁岩青纽）
	var guest := _LoginCTAButton.new("游 客 入 城", false)
	guest.name = "GuestButton"
	guest.position = Vector2(6, 336)
	guest.size = Vector2(364, 42)
	guest.pressed.connect(func(): _do_login(true))
	content.add_child(guest)

	# 10. 底部通关文牒方印与验籍批注
	var stamp := _CinnabarSeal.new()
	stamp.position = Vector2(322, 388)
	stamp.size = Vector2(40, 40)
	content.add_child(stamp)

	var doc_note := G.serif_label("昭元都护府·验籍通关", 11, Color("7c6850"), false)
	doc_note.position = Vector2(8, 396)
	doc_note.size = Vector2(300, 24)
	content.add_child(doc_note)

	# 页面底部提示
	_footer = UI.label("旅途进度自动保存在本机", 14, Color("d5c19a"))
	_footer.size.x = VIEW_W
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_footer)

	_refresh_avatar_selection()


func _create_input_field(placeholder: String, secret := false) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.secret = secret
	edit.max_length = 16
	edit.custom_minimum_size = Vector2(0, 40)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("faf4e8")
	normal.border_color = Color("c0ae8a")
	normal.set_border_width_all(1)
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.shadow_color = Color("000000", 0.06)
	normal.shadow_size = 1

	var focused := normal.duplicate() as StyleBoxFlat
	focused.bg_color = Color("fffef9")
	focused.border_color = Color("c89848")
	focused.set_border_width_all(2)

	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focused)
	edit.add_theme_font_override("font", G.font_reg)
	edit.add_theme_font_size_override("font_size", 16)
	edit.add_theme_color_override("font_color", Color("281e14"))
	edit.add_theme_color_override("font_placeholder_color", Color("a89884"))
	edit.add_theme_color_override("caret_color", Color("8a4820"))
	edit.add_theme_color_override("selection_color", Color("c89848", 0.35))
	return edit


func _layout_page() -> void:
	preload("res://src/ui/UiSafeArea.gd").restore_page(self)
	var height := maxf(800, get_viewport_rect().size.y)
	_paper.position = Vector2(36, maxf(214, (height - 512) * 0.5 + 50))
	_wordmark.position = Vector2(116, _paper.position.y - 164)
	_subtitle.position.y = _paper.position.y - 38
	_footer.position = Vector2(0, height - 48)
	G.fit_mobile_page(self)


func _refresh_avatar_selection() -> void:
	if _avatar_medallion != null and is_instance_valid(_avatar_medallion):
		_avatar_medallion.queue_redraw()
	if _avatar_card_btn != null and is_instance_valid(_avatar_card_btn):
		_avatar_card_btn.queue_redraw()


func _select_avatar(id: String) -> void:
	if not AVATAR_IDS.has(id):
		return
	if id == "custom":
		if not G.use_custom_avatar():
			_open_avatar_picker()
			return
	else:
		G.use_preset_avatar(id)
	Audio.sfx("ui_click")
	_refresh_avatar_selection()


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
	_build_avatar_cards_again()
	_toast_msg("头像已更新")


func _build_avatar_cards_again() -> void:
	_refresh_avatar_selection()


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
	if G.has_profile():
		if not G.lore_seen():
			G.go("res://src/ui/Prologue.tscn")
		else:
			G.enter_main_world()
	elif not G.selected_role.is_empty():
		G.go("res://src/ui/NameRecovery.tscn")
	else:
		G.go("res://src/ui/CreateRole.tscn")


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = UI.label(msg, 14, Color("e5b4a2"))
	_toast.position = Vector2(0, _paper.position.y + 524)
	_toast.custom_minimum_size = Vector2(VIEW_W, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	var toast := _toast
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_accept"):
		_do_login(false)
	elif event.is_action_pressed("ui_cancel"):
		G.go("res://src/ui/Title.tscn")


# ==============================================================================
# 自定义高品质界面组件 (Custom Premium Components)
# ==============================================================================

# 1. 顶部黑曜玄玉题名匾额
class _TitlePlaque extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# 底色：沉稳玄玉深蓝黑
		draw_rect(Rect2(0, 0, w, h), Color("141e24", 0.98))
		# 描边：古金单线与内侧微光
		draw_rect(Rect2(0, 0, w, h), Color("8a7040"), false, 1.0)
		draw_line(Vector2(2, 2), Vector2(w - 2, 2), Color("c8a252", 0.8), 1.0)
		draw_line(Vector2(2, h - 3), Vector2(w - 2, h - 3), Color("c8a252", 0.8), 1.0)

		# 四角精致金码
		var gc := Color("ffe288")
		var arm := 8.0
		draw_line(Vector2(2, 2), Vector2(2 + arm, 2), gc, 1.0)
		draw_line(Vector2(2, 2), Vector2(2, 2 + arm), gc, 1.0)
		draw_line(Vector2(w - 3, 2), Vector2(w - 3 - arm, 2), gc, 1.0)
		draw_line(Vector2(w - 3, 2), Vector2(w - 3, 2 + arm), gc, 1.0)
		draw_line(Vector2(2, h - 3), Vector2(2 + arm, h - 3), gc, 1.0)
		draw_line(Vector2(2, h - 3), Vector2(2, h - 3 - arm), gc, 1.0)
		draw_line(Vector2(w - 3, h - 3), Vector2(w - 3 - arm, h - 3), gc, 1.0)
		draw_line(Vector2(w - 3, h - 3), Vector2(w - 3, h - 3 - arm), gc, 1.0)

		# 标题书法字：居中金字
		var art_font := preload("res://assets/fonts/MaShanZheng-Regular.ttf")
		var title_text := "旅 人 登 记"
		var t_size := art_font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)
		var tx := (w - t_size.x) * 0.5
		# 阴影
		draw_string(art_font, Vector2(tx + 1, 27), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("080c10"))
		draw_string(art_font, Vector2(tx, 26), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("fff2c0"))

		# 副标
		var sub_text := "— 昭 元 行 旅 通 关 文 牒 —"
		var sub_font := G.font_reg
		var s_size := sub_font.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
		var sx := (w - s_size.x) * 0.5
		draw_string(sub_font, Vector2(sx, 44), sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c8a870"))

		# 左右装饰菱形
		var lx := tx - 16.0
		var rx := tx + t_size.x + 16.0
		var dy := 20.0
		_draw_diamond(Vector2(lx, dy), Color("d8a850"))
		_draw_diamond(Vector2(rx, dy), Color("d8a850"))

	func _draw_diamond(p: Vector2, col: Color) -> void:
		var d := PackedVector2Array([
			p + Vector2(0, -3), p + Vector2(3, 0),
			p + Vector2(0, 3), p + Vector2(-3, 0)
		])
		draw_colored_polygon(d, col)


# 2. 古风卷轴分隔细线
class _FleuronDivider extends Control:
	func _draw() -> void:
		var w := size.x
		var mid := w * 0.5
		var col := Color("baa678", 0.5)
		draw_line(Vector2(0, 4), Vector2(mid - 12, 4), col, 1.0)
		draw_line(Vector2(mid + 12, 4), Vector2(w, 4), col, 1.0)
		# 中央菱形
		var d := PackedVector2Array([
			Vector2(mid, 1), Vector2(mid + 4, 4),
			Vector2(mid, 7), Vector2(mid - 4, 4)
		])
		draw_colored_polygon(d, Color("bfa268"))


# 3. 圆形肖像勋章 (Avatar Medallion)
class _AvatarMedallion extends Control:
	var _hovered := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hovered = true; queue_redraw())
		mouse_exited.connect(func(): _hovered = false; queue_redraw())
		resized.connect(queue_redraw)

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0

		# 阴影
		draw_circle(center + Vector2(0, 2), radius, Color(0, 0, 0, 0.25))
		# 铜环外缘
		draw_circle(center, radius, Color("5c4c2f"))
		draw_circle(center, radius - 1.0, Color("c4a66a") if _hovered else Color("a68a52"))
		draw_circle(center, radius - 2.5, Color("1a242c"))
		draw_circle(center, radius - 4.5, Color("e8dcc4"))

		# 显示头像贴图或默认剪影
		var tex := G.custom_avatar_texture() if G.avatar_use_custom else null
		if tex != null:
			var tw := (radius - 5.0) * 2.0
			draw_texture_rect(tex, Rect2(center.x - tw * 0.5, center.y - tw * 0.5, tw, tw), false)
		else:
			# 绘制雅致加号/默认图标
			draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), Color("8a6a42"), 2.0)
			draw_line(center + Vector2(0, -6), center + Vector2(0, 6), Color("8a6a42"), 2.0)


# 4. 头像信息卡片按钮
class _AvatarTagButton extends Button:
	func _ready() -> void:
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var is_hi := is_hovered()
		# 羊皮纸凹槽底色
		var bg := Color("f5eee0") if is_hi else Color("ece0ca")
		draw_rect(Rect2(0, 0, w, h), bg)
		draw_rect(Rect2(0, 0, w, h), Color("c89848") if is_hi else Color("c0ae88"), false, 1.0)

		# 文字说明
		var font_bold := G.font_serif
		var font_reg := G.font_reg
		draw_string(font_bold, Vector2(12, 22), "自选旅人画像", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("2e2216"))
		var tip_text := "已导入自定义头像" if (G.avatar_use_custom and G.has_custom_avatar()) else "点击导入本机图片 (PNG/JPG)"
		draw_string(font_reg, Vector2(12, 40), tip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("7a6448"))

		# 右侧箭头提示
		draw_string(font_bold, Vector2(w - 20, 30), "›", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("a68858"))


# 5. 主次登录CTA按钮 (Primary / Secondary CTA)
class _LoginCTAButton extends Button:
	var _primary := true

	func _init(btn_text: String, primary: bool) -> void:
		text = ""
		_primary = primary
		set_meta("custom_text", btn_text)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_NONE
		flat = true
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var dy := 1.0 if is_pressed() else 0.0
		var words := String(get_meta("custom_text", ""))
		var art_font := preload("res://assets/fonts/MaShanZheng-Regular.ttf")

		if _primary:
			# ---- 主按钮：深红帝王朱漆金边大主纽 ----
			# 投影
			if not is_pressed():
				draw_rect(Rect2(2, 3 + dy, w - 4, h - 2), Color(0.0, 0.0, 0.0, 0.35))

			# 底色
			var fill := Color("a22a1e") if is_hovered() else Color("882016")
			if is_pressed(): fill = Color("6e160e")
			draw_rect(Rect2(0, dy, w, h), fill)
			# 顶部高光微梯
			draw_line(Vector2(2, dy + 1), Vector2(w - 2, dy + 1), Color("ffe698", 0.65), 1.0)
			draw_line(Vector2(2, dy + h - 2), Vector2(w - 2, dy + h - 2), Color("50100a", 0.7), 1.0)

			# 边框与金角
			var bcolor := Color("ffe288") if is_hovered() else Color("e2b44c")
			draw_rect(Rect2(0, dy, w, h), bcolor, false, 1.0)
			# 四角金色饰码
			var gc := Color("fff2b0")
			draw_line(Vector2(1, dy + 1), Vector2(6, dy + 1), gc, 1.0)
			draw_line(Vector2(1, dy + 1), Vector2(1, dy + 6), gc, 1.0)
			draw_line(Vector2(w - 2, dy + 1), Vector2(w - 7, dy + 1), gc, 1.0)
			draw_line(Vector2(w - 2, dy + 1), Vector2(w - 2, dy + 6), gc, 1.0)
			draw_line(Vector2(1, dy + h - 2), Vector2(6, dy + h - 2), gc, 1.0)
			draw_line(Vector2(1, dy + h - 2), Vector2(1, dy + h - 7), gc, 1.0)
			draw_line(Vector2(w - 2, dy + h - 2), Vector2(w - 7, dy + h - 2), gc, 1.0)
			draw_line(Vector2(w - 2, dy + h - 2), Vector2(w - 2, dy + h - 7), gc, 1.0)

			# 书法字
			var t_size := art_font.get_string_size(words, HORIZONTAL_ALIGNMENT_CENTER, -1, 23)
			var tx := (w - t_size.x) * 0.5
			var ty := (h + t_size.y * 0.7) * 0.5 + dy
			draw_string(art_font, Vector2(tx + 1, ty + 1), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("140402"))
			draw_string(art_font, Vector2(tx, ty), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("fff8dc"))
		else:
			# ---- 次按钮：暗铁岩青典雅沉稳纽 ----
			if not is_pressed():
				draw_rect(Rect2(2, 2 + dy, w - 4, h - 2), Color(0.0, 0.0, 0.0, 0.25))

			var fill := Color("2a3646", 0.9) if is_hovered() else Color("1e2632", 0.85)
			if is_pressed(): fill = Color("161c24", 0.95)
			draw_rect(Rect2(0, dy, w, h), fill)

			var bcol := Color("6a829c") if is_hovered() else Color("425264")
			draw_rect(Rect2(0, dy, w, h), bcol, false, 1.0)
			draw_line(Vector2(1, dy + 1), Vector2(w - 1, dy + 1), Color("8aa6c4", 0.35), 1.0)

			var serif_font := G.font_serif
			var t_size := serif_font.get_string_size(words, HORIZONTAL_ALIGNMENT_CENTER, -1, 17)
			var tx := (w - t_size.x) * 0.5
			var ty := (h + t_size.y * 0.65) * 0.5 + dy
			draw_string(serif_font, Vector2(tx + 1, ty + 1), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("0a0e14"))
			draw_string(serif_font, Vector2(tx, ty), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("fff2da") if is_hovered() else Color("ded2be"))


# 6. 古代朱砂方印 (Cinnabar Seal)
class _CinnabarSeal extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# 略带倾斜感与朱砂质感
		draw_rect(Rect2(1, 1, w - 2, h - 2), Color("8f2014"))
		draw_rect(Rect2(0, 0, w, h), Color("cf3a28"), false, 1.0)
		draw_rect(Rect2(2, 2, w - 4, h - 4), Color("6c160e"), false, 1.0)

		# 印文“昭元”
		var font := G.font_serif
		draw_string(font, Vector2(7, 18), "昭", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fce0c8"))
		draw_string(font, Vector2(21, 18), "元", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fce0c8"))
		draw_string(font, Vector2(7, 33), "行", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fce0c8"))
		draw_string(font, Vector2(21, 33), "牒", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fce0c8"))
'''

with open(r"D:\new bee\远征\src\ui\Login.gd", "w", encoding="utf-8") as f:
    f.write(NEW_LOGIN_GD)
print("Login.gd written successfully!")
