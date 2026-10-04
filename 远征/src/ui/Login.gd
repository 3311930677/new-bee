# Login.gd —— 旅人登记卡，个人头像与职业分开。
extends Control

const UI := preload("res://src/ui/JournalUI.gd")
const Wordmark := preload("res://src/ui/UIWordmark.gd")
const VIEW_W := 480.0
const AVATAR_IDS := ["fox", "cat", "turtle", "snow", "custom"]

var _account: LineEdit
var _password: LineEdit
var _paper: PanelContainer
var _footer: Label
var _wordmark: Control
var _subtitle: Label
var _avatar_buttons: Array[Control] = []
var _avatar_row: HBoxContainer
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
	_paper = UI.paper(408, 512, 26)
	_paper.name = "RegistrationCard"
	add_child(_paper)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.add_child(content)
	var title := UI.art_label("旅人登记", 30, UI.GOLD)
	title.position = Vector2(0, -1)
	content.add_child(title)
	var returning := G.has_profile() or not G.selected_role.is_empty()
	_put_label(content, "欢迎回来，继续上次旅程。" if returning else "欢迎来到昭元，旅人。",
		Vector2(0, 43), 14, Color("c4b994"), true)
	UI.stamp(content, Vector2(318, -2))
	_put_label(content, "账号", Vector2(0, 106), 16, UI.INK, true)
	_account = UI.field("你的账号")
	_account.name = "Account"
	_account.position = Vector2(66, 96)
	_account.size = Vector2(290, 44)
	content.add_child(_account)
	_put_label(content, "密码", Vector2(0, 162), 16, UI.INK, true)
	_password = UI.field("输入密码", true)
	_password.name = "Password"
	_password.position = Vector2(66, 152)
	_password.size = Vector2(290, 44)
	content.add_child(_password)
	if returning:
		_account.text = G.account
	_account.text_submitted.connect(func(_text: String): _password.grab_focus())
	_password.text_submitted.connect(func(_text: String): _do_login(false))
	_build_avatar_picker(content)
	var login := UI.button("登录入城", 356, 48, "primary")
	login.name = "LoginButton"
	login.position = Vector2(0, 350)
	login.pressed.connect(func(): _do_login(false))
	content.add_child(login)
	var guest := UI.button("游客入城", 356, 44, "quiet")
	guest.name = "GuestButton"
	guest.position = Vector2(0, 406)
	guest.pressed.connect(func(): _do_login(true))
	content.add_child(guest)
	_footer = UI.label("旅途进度自动保存在本机", 14, Color("d5c19a"))
	_footer.size.x = VIEW_W
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_footer)


func _layout_page() -> void:
	preload("res://src/ui/UiSafeArea.gd").restore_page(self)
	var height := maxf(800, get_viewport_rect().size.y)
	_paper.position = Vector2(36, maxf(214, (height - 512) * 0.5 + 50))
	_wordmark.position = Vector2(116, _paper.position.y - 164)
	_subtitle.position.y = _paper.position.y - 38
	_footer.position = Vector2(0, height - 48)
	G.fit_mobile_page(self)


func _put_label(parent: Control, text: String, at: Vector2,
		font_size := 14, color := UI.INK, serif := false) -> Label:
	var node := UI.label(text, font_size, color, serif)
	node.position = at
	parent.add_child(node)
	return node


func _build_avatar_picker(content: Control) -> void:
	_put_label(content, "旅人小像", Vector2(0, 216), 17, UI.INK, true)
	var note := _put_label(content, "随时可以换", Vector2(240, 219), 14, UI.MUTED)
	note.size.x = 116
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_avatar_row = HBoxContainer.new()
	_avatar_row.position = Vector2(0, 246)
	_avatar_row.size = Vector2(356, 84)
	_avatar_row.add_theme_constant_override("separation", 19)
	content.add_child(_avatar_row)
	for id in AVATAR_IDS:
		var card := _avatar_card(id)
		_avatar_row.add_child(card)
		_avatar_buttons.append(card)
	_refresh_avatar_selection()


func _avatar_card(id: String) -> Button:
	var card := UI.avatar_card(id)
	card.pressed.connect(func(): _select_avatar(id))
	return card


func _refresh_avatar_selection() -> void:
	var selected := "custom" if G.avatar_use_custom and G.has_custom_avatar() else G.current_avatar_id()
	for card in _avatar_buttons:
		UI.select_card(card, String(card.get_meta("avatar_id")) == selected)


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
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_accept"):
		_do_login(false)
	elif event.is_action_pressed("ui_cancel"):
		G.go("res://src/ui/Title.tscn")
