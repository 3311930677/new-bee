extends Control

const Profile := preload("res://src/online/OnlineProfile.gd")
const Lacquer := preload("res://src/ui/LacquerUI.gd")
const ROLE_NAMES := ["破军", "穿杨", "霜语", "晨星"]
const AccountPage := preload("res://src/ui/OnlineAccount.tscn")
const Field := preload("res://src/ui/FieldUI.gd")

var _status: Label
var _url: LineEdit
var _username: LineEdit
var _password: LineEdit
var _nickname: LineEdit
var _role: OptionButton
var _gender: OptionButton
var _avatar: OptionButton
var _avatar_preview: Control
var _identity_hint: Label
var _import_notice: Label
var _form: VBoxContainer
var _roster: VBoxContainer
var _create_form: VBoxContainer
var _logout_action: Control
var _details: Label
var _enter_world: Control
var _security_action: Control
var _save_code_action: Control
var _account_page: Control
var _deleted_roster: VBoxContainer
var _suggestions: VBoxContainer
var _delete_form: VBoxContainer
var _delete_words: Label
var _delete_confirmation: LineEdit
var _delete_target: Dictionary = {}
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
	_button(_form, "忘记密码 · 使用恢复码", _open_account.bind("recovery"))
	_save_code_action = _button(column, "保存账号恢复码", _open_account.bind("code"))
	_roster = VBoxContainer.new()
	_roster.add_theme_constant_override("separation", 10)
	column.add_child(_roster)
	_deleted_roster = VBoxContainer.new()
	_deleted_roster.add_theme_constant_override("separation", 10)
	column.add_child(_deleted_roster)
	_delete_form = VBoxContainer.new()
	_delete_form.add_theme_constant_override("separation", 10)
	column.add_child(_delete_form)
	_delete_words = G.gold_label("", G.FS_SM, false)
	_delete_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_delete_form.add_child(_delete_words)
	_delete_confirmation = _input_field(_delete_form, "完整输入要删除的角色昵称", false)
	_button(_delete_form, "确认删除角色", _delete_character)
	_button(_delete_form, "取消删除", _cancel_delete)
	_delete_form.hide()
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
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 12)
	create.add_child(identity_row)
	_avatar_preview = Field.portrait("zs", Vector2.ZERO, Vector2(80, 88))
	_avatar_preview.custom_minimum_size = Vector2(80, 88)
	_avatar_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity_row.add_child(_avatar_preview)
	var identity_options := VBoxContainer.new()
	identity_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_options.add_theme_constant_override("separation", 8)
	identity_row.add_child(identity_options)
	_gender = OptionButton.new()
	_gender.custom_minimum_size.y = 44
	for words in Profile.GENDER_NAMES:
		_gender.add_item("性别：" + words)
	identity_options.add_child(_gender)
	_avatar = OptionButton.new()
	_avatar.custom_minimum_size.y = 44
	for words in Profile.AVATAR_NAMES:
		_avatar.add_item("头像：" + words)
	identity_options.add_child(_avatar)
	_role.item_selected.connect(func(_index: int) -> void: _update_avatar_preview())
	_avatar.item_selected.connect(func(_index: int) -> void: _update_avatar_preview())
	_identity_hint = G.gold_label("性别与小像会显示在同行名片中；性别可选未指定。", G.FS_SM, false)
	_identity_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create.add_child(_identity_hint)
	_button(create, "预览单机角色身份", _preview_import)
	_import_notice = G.gold_label("", G.FS_SM, false)
	_import_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create.add_child(_import_notice)
	_import_notice.hide()
	_button(create, "确认创建在线角色", _create_character)
	_suggestions = VBoxContainer.new()
	_suggestions.add_theme_constant_override("separation", 8)
	create.add_child(_suggestions)
	_add_text(create, "可沿用职业、昵称和身份建议；等级、金币、装备与宠物战力从线上重新成长。")
	_details = G.gold_label("", G.FS_SM, false)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_details)
	_enter_world = _button(column, "进入昭元边城", _open_world)
	_enter_world.visible = Online.is_authenticated() and not Online.selected_character.is_empty()
	_security_action = _button(column, "账号安全 · 更新恢复码", _open_account.bind("security"))
	_logout_action = _button(column, "退出在线账号", _logout)
	_button(outer, "返回 · 继续单机", _back, false)
	Online.state_changed.connect(_online_state_changed)
	_refresh_roster()
	if Online.is_authenticated():
		call_deferred("_refresh_account_data")


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
	_role.disabled = value
	_gender.disabled = value or not _identity_available()
	_avatar.disabled = value or not _identity_available()
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
		await Online.refresh_deleted_characters()
	_refresh_roster()
	_set_busy(false)
	if bool(result.get("ok", false)) and not Online.pending_recovery_code.is_empty():
		_open_account("code")


func _preview_import() -> void:
	var preview := Profile.import_preview({"player_name": G.player_name, "selected_role": G.selected_role, "gender": G.gender, "avatar_id": G.avatar_id, "avatar_use_custom": G.avatar_use_custom})
	_nickname.text = String(preview.identity.nickname)
	_role.select(Profile.ROLE_IDS.find(String(preview.identity.role_id)))
	_gender.select(Profile.GENDER_IDS.find(String(preview.identity.gender_id)) if _identity_available() else 0)
	_avatar.select(Profile.AVATAR_IDS.find(String(preview.identity.avatar_id)) if _identity_available() else 0)
	_update_avatar_preview()
	var compatibility := "" if _identity_available() else "\n当前服务器仅支持默认身份，本次预览使用未指定性别和职业头像。"
	_import_notice.text = "%s\n%s\n不带入：%s%s" % [preview.notice, preview.avatar_notice, "、".join(preview.not_imported), compatibility]
	_import_notice.show()


func _identity_available() -> bool:
	return Profile.identity_supported(Online.manifest) and Profile.catalogue_matches(Online.manifest)


func _update_avatar_preview() -> void:
	var identity := {"role_id": Profile.ROLE_IDS[_role.selected], "avatar_id": Profile.AVATAR_IDS[_avatar.selected]}
	var avatar_role := Profile.avatar_role(identity)
	var picture := Field.portrait(avatar_role, Vector2.ZERO, Vector2(80, 88))
	_avatar_preview.set("texture", picture.get("texture"))
	_avatar_preview.set_meta("avatar_role", avatar_role)
	_avatar_preview.queue_redraw()
	picture.free()


func _create_character() -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await Online.create_character({"nickname": _nickname.text, "role_id": Profile.ROLE_IDS[_role.selected], "appearance_id": "default", "gender_id": Profile.GENDER_IDS[_gender.selected], "avatar_id": Profile.AVATAR_IDS[_avatar.selected]})
	if _show_result(result, "在线角色创建成功"):
		await Online.refresh_characters()
		_clear_suggestions()
		_import_notice.hide()
	elif String(result.get("code", "")) == "nickname_unavailable":
		_clear_suggestions()
		var alternatives: Dictionary = await Online.nickname_suggestions(_nickname.text)
		if bool(alternatives.get("ok", false)):
			_add_text(_suggestions, "可选昵称（以创建时为准）")
			for value in alternatives.data.get("suggestions", []):
				var candidate := String(value)
				_button(_suggestions, "使用 " + candidate, func() -> void: _nickname.text = candidate)
	_refresh_roster()
	_set_busy(false)


func _refresh_roster() -> void:
	_form.visible = not Online.is_authenticated()
	_create_form.visible = Online.is_authenticated()
	_logout_action.visible = Online.is_authenticated()
	_security_action.visible = Online.is_authenticated()
	_save_code_action.visible = not Online.pending_recovery_code.is_empty()
	_gender.disabled = _busy or not _identity_available()
	_avatar.disabled = _busy or not _identity_available()
	_identity_hint.text = "性别与小像会显示在同行名片中；战斗使用职业形象。" if _identity_available() else "当前服务器仅开放默认身份，性别和小像选择暂不可用。"
	var features: Variant = Online.manifest.get("features", [])
	_enter_world.visible = Online.is_authenticated() and not Online.selected_character.is_empty() and features is Array and features.has("town_rooms")
	for child in _roster.get_children():
		child.queue_free()
	for child in _deleted_roster.get_children():
		child.queue_free()
	_buttons.assign(_buttons.filter(func(button: Variant) -> bool: return is_instance_valid(button) and button is Control and not button.is_queued_for_deletion()))
	if not Online.is_authenticated():
		_cancel_delete()
		return
	_add_text(_roster, "你的在线角色（占用 %d/3 个名额）" % (Online.characters.size() + Online.deleted_characters.size()))
	for value in Online.characters:
		if not value is Dictionary:
			continue
		var character := value as Dictionary
		var role_index := Profile.ROLE_IDS.find(String(character.get("role_id", "zs")))
		var words := "%s\n%s · %s · Lv.%d" % [character.get("nickname", ""), ROLE_NAMES[maxi(0, role_index)], Profile.gender_name(String(character.get("gender_id", "unspecified"))), int(character.get("level", 1))]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_roster.add_child(row)
		var portrait := Field.portrait(Profile.avatar_role(character), Vector2.ZERO, Vector2(56, 62))
		portrait.custom_minimum_size = Vector2(56, 62)
		row.add_child(portrait)
		var choose := _button(row, words, _select_character.bind(String(character.get("id", ""))))
		choose.custom_minimum_size.y = 62
		var manage := _button(row, "管理", _begin_delete.bind(character))
		manage.size_flags_horizontal = Control.SIZE_SHRINK_END
		manage.custom_minimum_size.x = 76
	if not Online.deleted_characters.is_empty():
		_add_text(_deleted_roster, "七天内可恢复的角色")
		for value in Online.deleted_characters:
			if not value is Dictionary:
				continue
			var character := value as Dictionary
			var until := String(character.get("recover_until", "")).replace("T", " ").left(16)
			_add_text(_deleted_roster, "%s · 可恢复至 %s UTC" % [character.get("nickname", ""), until])
			_button(_deleted_roster, "恢复 " + String(character.get("nickname", "")), _restore_character.bind(String(character.get("id", ""))))


func _select_character(id: String) -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await Online.select_character(id)
	if _show_result(result, "已选择在线角色"):
		var detail: Dictionary = await Online.character_detail(id)
		if bool(detail.get("ok", false)):
			var wallet: Dictionary = detail.data.get("wallet", {})
			var world_notice := "进入边城，与同行旅人一起踏上新的旅程。" if _world_available() else "已选择在线角色；当前服务器尚未开放城镇。"
			_details.text = "%s · 在线金币 %d\n%s" % [Online.selected_character.get("nickname", ""), int(wallet.get("gold", 0)), world_notice]
		_refresh_roster()
	_set_busy(false)


func _open_world() -> void:
	if not _busy and not Online.selected_character.is_empty() and _world_available():
		G.go("res://src/ui/OnlineWorld.tscn")


func _world_available() -> bool:
	var features: Variant = Online.manifest.get("features", [])
	return features is Array and features.has("town_rooms")


func _online_state_changed() -> void:
	_refresh_roster.call_deferred()


func _refresh_account_data() -> void:
	await Online.refresh_characters()
	await Online.refresh_deleted_characters()
	_refresh_roster()


func _open_account(mode: String) -> void:
	if _busy or is_instance_valid(_account_page):
		return
	if not Online.configure(_url.text):
		_status.text = Online.last_error
		return
	if mode == "security" and not Online.is_authenticated():
		_status.text = "请先登录这个服务器的在线账号。"
		return
	_account_page = AccountPage.instantiate() as Control
	_account_page.mode = mode
	_account_page.username_hint = _username.text
	_account_page.closed.connect(func() -> void:
		_account_page = null
		_refresh_roster())
	add_child(_account_page)


func _begin_delete(character: Dictionary) -> void:
	if _busy:
		return
	_delete_target = character.duplicate(true)
	_delete_words.text = "删除「%s」后保留七天恢复期，期间仍占角色名额。\n确认删除前，请完整输入这个角色的昵称。" % character.get("nickname", "")
	_delete_confirmation.clear()
	_delete_form.show()


func _cancel_delete() -> void:
	_delete_target.clear()
	_delete_confirmation.clear()
	_delete_form.hide()


func _delete_character() -> void:
	if _busy or _delete_target.is_empty():
		return
	if _delete_confirmation.text != String(_delete_target.get("nickname", "")):
		_status.text = "请完整输入要删除的角色昵称。"
		return
	_set_busy(true)
	var result: Dictionary = await Online.delete_character(String(_delete_target.get("id", "")), _delete_confirmation.text)
	if _show_result(result, "角色已进入七天恢复期"):
		_cancel_delete()
		_details.text = ""
		await _refresh_account_data()
	_set_busy(false)


func _restore_character(id: String) -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await Online.restore_character(id)
	if _show_result(result, "角色已恢复，原有在线物资保留"):
		await _refresh_account_data()
	_set_busy(false)


func _clear_suggestions() -> void:
	for child in _suggestions.get_children():
		child.queue_free()


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
