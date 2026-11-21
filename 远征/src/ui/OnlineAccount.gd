extends Control
## 恢复码和密码仅存在内存；复制由玩家明确点击，不写本地存档。

signal closed

var mode := "security"
var username_hint := ""
var _status: Label
var _form: VBoxContainer
var _username: LineEdit
var _password: LineEdit
var _password_confirm: LineEdit
var _recovery_input: LineEdit
var _code_box: VBoxContainer
var _code_text: LineEdit
var _notices: VBoxContainer
var _busy := false
var _buttons: Array[Control] = []


func _ready() -> void:
	theme = preload("res://src/ui/LacquerUI.gd").theme()
	var background := ColorRect.new()
	background.color = G.BG_DEEP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
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
	_text(column, "找回在线账号" if mode == "recovery" else "保存恢复码" if mode == "code" else "账号安全", G.FS_BIG)
	_status = _text(column, "忘记密码时，使用自己保存的恢复码找回。" if mode == "recovery" else "恢复码可在忘记密码时保护这段线上旅程。")
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 10)
	column.add_child(_form)
	_username = _field(_form, "在线账号", false)
	_username.text = username_hint
	_username.max_length = 32
	_username.visible = mode == "recovery"
	_recovery_input = _field(_form, "已保存的恢复码（YZR- 开头）", true)
	_recovery_input.visible = mode == "recovery"
	_password = _field(_form, "新密码" if mode == "recovery" else "当前密码，用于确认是你本人", true)
	_password.max_length = 72
	_password_confirm = _field(_form, "再次输入新密码", true)
	_password_confirm.max_length = 72
	_password_confirm.visible = mode == "recovery"
	if mode == "recovery":
		_text(_form, "找回成功会退出其他设备，并生成新的恢复码；原角色与物资保留。")
		_button(_form, "确认找回 · 更新密码", _recover)
	else:
		_text(_form, "更新后，旧恢复码立即失效。请把新码存放在安全的地方。")
		_button(_form, "生成新的恢复码", _replace_code)
	_form.visible = mode != "code"
	_code_box = VBoxContainer.new()
	_code_box.add_theme_constant_override("separation", 10)
	column.add_child(_code_box)
	_text(_code_box, "请保存这份恢复码", G.FS_MD)
	_text(_code_box, "恢复码等同于找回凭证，不要发给其他人。游戏不会把它写入单机存档；本次关闭后，可登录账号重新生成。")
	_code_text = _field(_code_box, "", true)
	_code_text.editable = false
	_button(_code_box, "显示 / 隐藏恢复码", _toggle_code)
	_button(_code_box, "复制恢复码", _copy_code)
	_button(_code_box, "已保存 · 返回", _ack_code)
	_notices = VBoxContainer.new()
	_notices.add_theme_constant_override("separation", 10)
	column.add_child(_notices)
	_button(outer, "返回", _close, true)
	_show_code()
	if mode == "security" and Online.is_authenticated():
		call_deferred("_refresh_notices")


func _text(parent: Control, words: String, font_size := G.FS_SM) -> Label:
	var label := G.gold_label(words, font_size, font_size > G.FS_SM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _field(parent: Control, placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.custom_minimum_size.y = 44
	field.add_theme_font_override("font", G.font_reg)
	field.add_theme_font_size_override("font_size", G.FS_SM)
	field.add_theme_color_override("font_color", G.PARCHMENT)
	field.add_theme_color_override("font_placeholder_color", Color("9c8d73"))
	field.add_theme_color_override("caret_color", G.GOLD_BRIGHT)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color("1b1613", 0.96)
	sb_n.border_color = Color("b8924d", 0.85)
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(4)
	sb_n.content_margin_left = 10
	sb_n.content_margin_top = 6
	sb_n.content_margin_right = 10
	sb_n.content_margin_bottom = 6
	var sb_f := sb_n.duplicate() as StyleBoxFlat
	sb_f.border_color = G.GOLD_BRIGHT
	sb_f.set_border_width_all(2)
	field.add_theme_stylebox_override("normal", sb_n)
	field.add_theme_stylebox_override("focus", sb_f)
	field.add_theme_stylebox_override("read_only", sb_n)
	parent.add_child(field)
	return field


func _button(parent: Control, words: String, action: Callable, while_busy := false) -> Control:
	var button := G.ghost_button(words, 0, 46, G.FS_MD)
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.gui_input.connect(func(event: InputEvent) -> void:
		if G.ui_blocked or (_busy and not while_busy):
			return
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept"):
			button.accept_event()
			action.call())
	parent.add_child(button)
	if not while_busy:
		_buttons.append(button)
	return button


func _set_busy(value: bool) -> void:
	_busy = value
	for button in _buttons:
		if is_instance_valid(button):
			button.modulate.a = 0.5 if value else 1.0


func _show_code() -> void:
	_code_text.text = Online.pending_recovery_code
	_code_text.secret = true
	_code_box.visible = not Online.pending_recovery_code.is_empty()
	if mode == "code":
		_form.hide()


func _toggle_code() -> void:
	_code_text.secret = not _code_text.secret


func _copy_code() -> void:
	if Online.pending_recovery_code.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		_status.text = "当前模式没有剪贴板，可显示恢复码后自行记录。"
		return
	DisplayServer.clipboard_set(Online.pending_recovery_code)
	_status.text = "恢复码已复制，请保存在安全的地方。"


func _ack_code() -> void:
	Online.forget_recovery_code()
	_code_text.clear()
	_close()


func _recover() -> void:
	if _busy:
		return
	if _password.text != _password_confirm.text or _password.text.is_empty():
		_status.text = "请两次输入相同的新密码。"
		return
	_set_busy(true)
	_status.text = "正在找回账号……"
	if Online.manifest.is_empty():
		var connected: Dictionary = await Online.connect_service()
		if not bool(connected.get("ok", false)):
			_status.text = String(connected.get("error", "连接失败"))
			_set_busy(false)
			return
	var result: Dictionary = await Online.recover_account(_username.text, _recovery_input.text, _password.text)
	_password.clear()
	_password_confirm.clear()
	_recovery_input.clear()
	if bool(result.get("ok", false)):
		_status.text = "密码已更新。请保存新的恢复码，再使用新密码登录。"
		_form.hide()
		_show_code()
	else:
		_status.text = String(result.get("error", "找回失败，请稍后重试。"))
	_set_busy(false)


func _replace_code() -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await Online.replace_recovery_code(_password.text)
	_password.clear()
	if bool(result.get("ok", false)):
		_status.text = "已生成新的恢复码，旧码已失效。"
		_show_code()
		await _refresh_notices()
	else:
		_status.text = String(result.get("error", "更新失败，请稍后重试。"))
	_set_busy(false)


func _refresh_notices() -> void:
	var result: Dictionary = await Online.refresh_security_notifications()
	if not bool(result.get("ok", false)):
		_status.text = String(result.get("error", "读取安全记录失败。"))
		return
	for child in _notices.get_children():
		child.queue_free()
	_buttons.assign(_buttons.filter(func(button: Variant) -> bool: return is_instance_valid(button) and button is Control and not button.is_queued_for_deletion()))
	if Online.security_notifications.is_empty():
		return
	_text(_notices, "近期安全记录", G.FS_MD)
	for value in Online.security_notifications:
		if not value is Dictionary:
			continue
		var notice := value as Dictionary
		var action := "账号密码已找回并更新" if String(notice.get("kind", "")) == "password_reset" else "账号恢复码已更新"
		_text(_notices, "%s\n%s UTC" % [action, String(notice.get("created_at", "")).replace("T", " ").left(16)])
		_button(_notices, "已知晓", _ack_notice.bind(String(notice.get("id", ""))))


func _ack_notice(id: String) -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await Online.acknowledge_security_notification(id)
	if bool(result.get("ok", false)):
		await _refresh_notices()
	else:
		_status.text = String(result.get("error", "操作失败。"))
	_set_busy(false)


func _close() -> void:
	_password.clear()
	_password_confirm.clear()
	_recovery_input.clear()
	_code_text.clear()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
