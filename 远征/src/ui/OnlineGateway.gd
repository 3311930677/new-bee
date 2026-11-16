extends Control

const Profile := preload("res://src/online/OnlineProfile.gd")
const Lacquer := preload("res://src/ui/LacquerUI.gd")
const ROLE_NAMES := ["破军", "穿杨", "霜语", "晨星"]

var _status: Label
var _url: LineEdit
var _username: LineEdit
var _password: LineEdit
var _nickname: LineEdit
var _role: OptionButton
var _form: VBoxContainer
var _roster: VBoxContainer
var _create_form: VBoxContainer
var _logout_action: Control
var _details: Label
var _enter_world: Control
var _busy := false
var _buttons: Array[Control] = []


func _ready() -> void:
	theme = Lacquer.theme()
	var background := ColorRect.new()
	background.color = G.BG_DEEP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	column.add_child(G.gold_label("结伴远征", G.FS_BIG))
	_add_text(column, "与旅人相遇，从一段新的线上旅程开始。")
	_url = _input_field(column, "服务器地址", false)
	_url.text = Online.base_url
	_button(column, "连接服务器", _connect_service)
	_status = G.gold_label("尚未连接 · 原单机进度保留", G.FS_SM, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	if Online.is_authenticated():
		_status.text = "在线账号已登录"
	elif not Online.manifest.is_empty():
		_status.text = "已连接 · 可登录在线账号"
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 10)
	column.add_child(_form)
	_username = _input_field(_form, "在线账号：字母、数字或下划线", false)
	_username.max_length = 32
	_password = _input_field(_form, "密码：至少 10 位", true)
	_password.max_length = 72
	_button(_form, "登录在线账号", _authenticate.bind(false))
	_button(_form, "注册在线账号", _authenticate.bind(true))
	_roster = VBoxContainer.new()
	_roster.add_theme_constant_override("separation", 10)
	column.add_child(_roster)
	var create := VBoxContainer.new()
	_create_form = create
	create.name = "CreateCharacter"
	create.add_theme_constant_override("separation", 10)
	column.add_child(create)
	_add_text(create, "创建在线角色")
	_nickname = _input_field(create, "在线昵称（2–12 字）", false)
	_nickname.max_length = 12
	_role = OptionButton.new()
	_role.custom_minimum_size.y = 44
	for role_name in ROLE_NAMES:
		_role.add_item(role_name)
	create.add_child(_role)
	_button(create, "预览单机角色身份", _preview_import)
	_button(create, "确认创建在线角色", _create_character)
	_add_text(create, "可沿用职业和昵称；等级、金币、装备与宠物战力从线上重新成长。")
	_details = G.gold_label("", G.FS_SM, false)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_details)
	_enter_world = _button(column, "进入昭元边城", _open_world)
	_enter_world.visible = Online.is_authenticated() and not Online.selected_character.is_empty()
	_logout_action = _button(column, "退出在线账号", _logout)
	_button(outer, "返回 · 继续单机", _back, false)
	_refresh_roster()


func _input_field(parent: Control, placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.custom_minimum_size.y = 44
	field.add_theme_font_override("font", G.font_reg)
	field.add_theme_font_size_override("font_size", G.FS_SM)
	parent.add_child(field)
	return field


func _button(parent: Control, words: String, action: Callable, tracked := true) -> Control:
	var primary := words in ["登录在线账号", "确认创建在线角色"]
	var button := G.gold_button(words, 0, 46, G.FS_MD) if primary else G.ghost_button(words, 0, 46, G.FS_MD)
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.gui_input.connect(func(event: InputEvent):
		if G.ui_blocked:
			return
		if _busy and tracked:
			return
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept"):
			button.accept_event()
			action.call())
	parent.add_child(button)
	if tracked:
		_buttons.append(button)
	return button


func _add_text(parent: Control, words: String) -> void:
	var label := G.gold_label(words, G.FS_SM, false)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _set_busy(value: bool) -> void:
	_busy = value
	for button in _buttons:
		if is_instance_valid(button):
			button.modulate.a = 0.5 if value else 1.0
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP


func _show_result(result: Dictionary, success: String) -> bool:
	var ok := bool(result.get("ok", false))
	_status.text = success if ok else String(result.get("error", "连接失败，请稍后重试。"))
	return ok


func _connect_service() -> void:
	if _busy:
		return
	if not Online.configure(_url.text):
		_status.text = Online.last_error
		return
	_set_busy(true)
	_status.text = "正在连接……"
	var result: Dictionary = await Online.connect_service()
	_show_result(result, "已连接 · 可登录在线账号")
	_refresh_roster()
	_set_busy(false)


func _authenticate(register: bool) -> void:
	if _busy:
		return
	if not Online.configure(_url.text):
		_status.text = Online.last_error
		return
	_set_busy(true)
	_status.text = "正在注册……" if register else "正在登录……"
	var result: Dictionary = await Online.authenticate(_username.text, _password.text, register)
	_password.clear()
	if _show_result(result, "在线账号已登录"):
		await Online.refresh_characters()
	_refresh_roster()
	_set_busy(false)


func _preview_import() -> void:
	var preview := Profile.import_preview({"player_name": G.player_name, "selected_role": G.selected_role})
	_nickname.text = String(preview.identity.nickname)
	_role.select(Profile.ROLE_IDS.find(String(preview.identity.role_id)))
	_details.text = "%s\n不带入：%s" % [preview.notice, "、".join(preview.not_imported)]


func _create_character() -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await Online.create_character({"nickname": _nickname.text, "role_id": Profile.ROLE_IDS[_role.selected], "appearance_id": "default"})
	if _show_result(result, "在线角色创建成功"):
		await Online.refresh_characters()
	_refresh_roster()
	_set_busy(false)


func _refresh_roster() -> void:
	_form.visible = not Online.is_authenticated()
	_create_form.visible = Online.is_authenticated()
	_logout_action.visible = Online.is_authenticated()
	_enter_world.visible = Online.is_authenticated() and not Online.selected_character.is_empty()
	for child in _roster.get_children():
		child.queue_free()
	_buttons = _buttons.filter(func(button: Control) -> bool: return is_instance_valid(button) and not button.is_queued_for_deletion())
	if not Online.is_authenticated():
		return
	_add_text(_roster, "你的在线角色（%d/3）" % Online.characters.size())
	for value in Online.characters:
		if not value is Dictionary:
			continue
		var character := value as Dictionary
		var role_index := Profile.ROLE_IDS.find(String(character.get("role_id", "zs")))
		var words := "%s · %s Lv.%d" % [character.get("nickname", ""), ROLE_NAMES[maxi(0, role_index)], int(character.get("level", 1))]
		_button(_roster, words, _select_character.bind(String(character.get("id", ""))))


func _select_character(id: String) -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await Online.select_character(id)
	if _show_result(result, "已选择在线角色"):
		var detail: Dictionary = await Online.character_detail(id)
		if bool(detail.get("ok", false)):
			var wallet: Dictionary = detail.data.get("wallet", {})
			_details.text = "%s · 在线金币 %d\n进入边城，与同行旅人一起踏上新的旅程。" % [Online.selected_character.get("nickname", ""), int(wallet.get("gold", 0))]
		_enter_world.show()
	_set_busy(false)


func _open_world() -> void:
	if not _busy and not Online.selected_character.is_empty():
		G.go("res://src/ui/OnlineWorld.tscn")


func _logout() -> void:
	if _busy:
		return
	_set_busy(true)
	await Online.logout()
	_details.text = ""
	_status.text = "已退出在线账号"
	_refresh_roster()
	_set_busy(false)


func _back() -> void:
	Online.clear_session()
	G.go("res://src/ui/Title.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
