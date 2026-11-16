extends Node
## 真实账号页面按钮 + HTTP + PostgreSQL；恢复码只在测试进程内存中断言。

var _fails := 0
var _page: Control


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
		push_error("ONLINE_ACCOUNTS_FAIL " + message)


func _snapshot() -> String:
	return JSON.stringify({"account": G.account, "role": G.selected_role, "name": G.player_name, "wallet": G.wallet, "items": G.items, "prog": G.prog})


func _find_button(root: Node, words: String) -> Control:
	if root is Control and not root.is_visible_in_tree():
		return null
	if root is Control and not root.gui_input.get_connections().is_empty():
		for child in root.get_children():
			if child is Label and String(child.text).replace(" ", "") == words.replace(" ", ""):
				return root as Control
	for child in root.get_children():
		var found := _find_button(child, words)
		if found != null:
			return found
	return null


func _click(root: Node, words: String) -> void:
	if root == _page and is_instance_valid(_page._account_page):
		root = _page._account_page
	var button := _find_button(root, words)
	_check(button != null, "实际页面按钮存在：" + words)
	if button == null:
		_finish()
		return
	var ancestor := button.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	if ancestor is ScrollContainer:
		ancestor.ensure_control_visible(button)
		await get_tree().process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	button.gui_input.emit(event)
	await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 45000
	while is_instance_valid(root) and bool(root.get("_busy")) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
	_check(not is_instance_valid(root) or not bool(root.get("_busy")), "页面请求在时限内完成")
	await get_tree().process_frame
	await get_tree().process_frame


func _capture(name: String) -> void:
	var directory := OS.get_environment("YUANZHENG_ACCOUNTS_CAPTURE")
	if directory.is_empty():
		return
	if is_instance_valid(_page._account_page) and not Online.pending_recovery_code.is_empty():
		_check(_page._account_page._code_text.secret, "截图前恢复码保持遮挡")
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "实际页面截图成功")


func _ready() -> void:
	await get_tree().process_frame
	for variable in ["YUANZHENG_DATABASE_URL", "YUANZHENG_TEST_DATABASE_URL", "YUANZHENG_ROOM_SECRET", "PGPASSWORD"]:
		_check(not OS.has_environment(variable), "客户端没有服务端环境：" + variable)
	var before := _snapshot()
	var save_before := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	var username := OS.get_environment("YUANZHENG_TEST_USERNAME")
	var password := OS.get_environment("YUANZHENG_TEST_PASSWORD")
	var next_password := OS.get_environment("YUANZHENG_TEST_NEXT_PASSWORD")
	if username.is_empty() or password.is_empty() or next_password.is_empty():
		_check(false, "必须提供真实测试账号上下文")
		_finish()
		return
	_page = preload("res://src/ui/OnlineGateway.tscn").instantiate() as Control
	add_child(_page)
	_page._url.text = OS.get_environment("YUANZHENG_TEST_URL")
	_page._username.text = username
	_page._password.text = password
	await _click(_page, "注册在线账号")
	_check(Online.is_authenticated() and Online.pending_recovery_code.length() == 47, "注册真实账号并提供恢复码")
	if not Online.is_authenticated() or not is_instance_valid(_page._account_page):
		_finish()
		return
	var initial_code := Online.pending_recovery_code
	_check(_page._account_page._code_text.secret, "恢复码默认遮挡")
	await _capture("recovery-code-masked")
	await _click(_page._account_page, "已保存 · 返回")
	_check(Online.pending_recovery_code.is_empty(), "确认保存后清空恢复码内存")
	var nickname := "归途旅人甲乙丙丁戊己庚辛"
	_page._nickname.text = nickname
	await _click(_page, "确认创建在线角色")
	_check(Online.characters.size() == 1, "真实页面创建角色")
	if Online.characters.size() != 1:
		_finish()
		return
	var character: Dictionary = Online.characters[0]
	var id := String(character.id)
	await _click(_page, "确认创建在线角色")
	var choices := 0
	for child in _page._suggestions.get_children():
		if child is Control and not child.gui_input.get_connections().is_empty():
			choices += 1
	_check(choices == 3 and Online.characters.size() == 1, "重名后给出三项可选昵称，没有误建角色")
	await _click(_page, nickname + "\n破军 · Lv.1")
	_check(String(Online.selected_character.get("id", "")) == id, "实际按钮选中在线角色")
	_check(not _page._enter_world.visible, "仅账号服务不展示未启用的城镇入口")
	await _capture("character-management")
	await _click(_page, "管理")
	_check(_page._delete_form.visible, "删除前呈现昵称确认")
	_page._delete_confirmation.text = "错误昵称"
	await _click(_page, "确认删除角色")
	_check(Online.characters.size() == 1 and _page._delete_form.visible, "错误确认不删除角色")
	_page._delete_confirmation.text = nickname
	await _click(_page, "取消删除")
	_check(Online.characters.size() == 1 and not _page._delete_form.visible, "取消不改变角色")
	await _click(_page, "管理")
	_page._delete_confirmation.text = nickname
	await _click(_page, "确认删除角色")
	_check(Online.characters.is_empty() and Online.deleted_characters.size() == 1 and Online.selected_character.is_empty(), "删除后进入恢复期并撤销角色选择")
	await _capture("character-recovery")
	await _click(_page, "恢复 " + nickname)
	_check(Online.characters.size() == 1 and Online.deleted_characters.is_empty(), "页面恢复同一角色")
	var detail: Dictionary = await Online.character_detail(id)
	_check(int(detail.get("data", {}).get("wallet", {}).get("gold", -1)) == 100, "恢复保留原有在线资产")
	await _click(_page, "账号安全 · 更新恢复码")
	_page._account_page._password.text = password
	await _click(_page._account_page, "生成新的恢复码")
	var current_code := Online.pending_recovery_code
	_check(current_code.length() == 47 and current_code != initial_code, "重新验证密码后轮换恢复码")
	await _click(_page._account_page, "已保存 · 返回")
	await _click(_page, "退出在线账号")
	_check(not Online.is_authenticated() and Online.pending_recovery_code.is_empty(), "退出清理令牌与恢复码")
	await _click(_page, "忘记密码 · 使用恢复码")
	var recovery: Control = _page._account_page
	recovery._username.text = username
	recovery._recovery_input.text = initial_code
	recovery._password.text = next_password
	recovery._password_confirm.text = next_password
	await _click(recovery, "确认找回 · 更新密码")
	_check(not Online.is_authenticated() and Online.pending_recovery_code.is_empty(), "旧恢复码无法找回账号")
	recovery._recovery_input.text = current_code
	recovery._password.text = next_password
	recovery._password_confirm.text = next_password
	await _click(recovery, "确认找回 · 更新密码")
	_check(not Online.is_authenticated() and Online.pending_recovery_code.length() == 47 and Online.pending_recovery_code != current_code, "正确恢复码找回后生成新码，并要求重新登录")
	await _capture("password-recovered-masked")
	await _click(recovery, "已保存 · 返回")
	_page._password.text = next_password
	await _click(_page, "登录在线账号")
	_check(Online.is_authenticated() and Online.characters.size() == 1, "使用新密码登录后原角色仍在")
	await _click(_page, "账号安全 · 更新恢复码")
	var deadline := Time.get_ticks_msec() + 15000
	while Online.security_notifications.size() < 2 and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	_check(Online.security_notifications.size() == 2, "找回与恢复码更新有站内安全记录")
	for notice in Online.security_notifications.duplicate(true):
		await _page._account_page._ack_notice(String(notice.id))
	_check(Online.security_notifications.is_empty(), "安全通知确认后不重复显示")
	await _click(_page._account_page, "返回")
	await _click(_page, "退出在线账号")
	_check(_snapshot() == before, "账号管理与找回不修改单机内存")
	var save_after := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	_check(save_after == save_before, "账号管理与找回不改写单机存档")
	_check(Online.pending_recovery_code.is_empty() and Online.security_notifications.is_empty() and Online.deleted_characters.is_empty(), "退出清理独立账号数据")
	_page.queue_free()
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	print("ONLINE_ACCOUNTS_OK" if _fails == 0 else "ONLINE_ACCOUNTS_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
