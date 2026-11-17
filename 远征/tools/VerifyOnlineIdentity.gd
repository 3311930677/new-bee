extends Node
## 两个真实客户端的身份页面与同频道名片；由 verify_identity.py 提供隔离上下文。

const Profile := preload("res://src/online/OnlineProfile.gd")
var _fails := 0
var _page: Control
var _world: Node2D
var _tag := ""
var _folder := ""
var _saved: Dictionary = {}
var _initial := ""
var _fixture := ""
var _save_before := PackedByteArray()


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_fails += 1
		push_error("ONLINE_IDENTITY_FAIL " + message)
	return ok


func _snapshot() -> String:
	return JSON.stringify({"account": G.account, "role": G.selected_role, "name": G.player_name, "gender": G.gender, "avatar_id": G.avatar_id, "avatar_custom": G.avatar_custom, "avatar_use_custom": G.avatar_use_custom, "wallet": G.wallet, "items": G.items, "prog": G.prog})


func _ok(result: Dictionary, message: String) -> bool:
	return _check(bool(result.get("ok", false)), "%s [status=%d code=%s]" % [message, int(result.get("status", 0)), result.get("code", "")])


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


func _click(root: Node, words: String) -> bool:
	var button := _find_button(root, words)
	if not _check(button != null, "实际页面按钮存在：" + words):
		return false
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
	await get_tree().process_frame
	await get_tree().process_frame
	return _check(not bool(root.get("_busy")), "页面请求在期限内完成")


func _capture(name: String) -> void:
	var folder := OS.get_environment("YUANZHENG_IDENTITY_CAPTURE")
	if folder.is_empty():
		return
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "实际截图保存")


func _marker(name: String, value: Dictionary = {}) -> void:
	var file := FileAccess.open(_folder.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value))


func _wait_marker(name: String) -> bool:
	var deadline := Time.get_ticks_msec() + 90000
	while not FileAccess.file_exists(_folder.path_join(name)) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	return _check(FileAccess.file_exists(_folder.path_join(name)), "等待另一真实客户端：" + name)


func _find_profile(root: Node, id: String) -> Control:
	if root is Control and String(root.get_meta("character_id", "")) == id:
		return root as Control
	for child in root.get_children():
		var found := _find_profile(child, id)
		if found != null:
			return found
	return null


func _labels(root: Node) -> String:
	var words := String(root.text) if root is Label else ""
	for child in root.get_children():
		words += "\n" + _labels(child)
	return words


func _ready() -> void:
	await get_tree().process_frame
	_tag = OS.get_environment("YUANZHENG_IDENTITY_TAG")
	_folder = OS.get_environment("YUANZHENG_IDENTITY_BARRIER")
	if not _check(_tag in ["a", "b"] and not _folder.is_empty(), "必须提供真实双端上下文"):
		await _finish()
		return
	_initial = _snapshot()
	_save_before = FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	for key in ["player_name", "selected_role", "gender", "avatar_id", "avatar_custom", "avatar_use_custom"]:
		_saved[key] = G.get(key)
	G.player_name = "本机身份样本"
	G.selected_role = "zs" if _tag == "a" else "ck"
	G.gender = "女" if _tag == "a" else "男"
	G.avatar_id = "fox"
	G.avatar_custom = "../../never-open-identity-fixture.png"
	G.avatar_use_custom = true
	_fixture = _snapshot()
	for variable in ["YUANZHENG_DATABASE_URL", "YUANZHENG_TEST_DATABASE_URL", "YUANZHENG_ROOM_SECRET", "YUANZHENG_ADMIN_TOKEN", "YUANZHENG_DBADMIN_URL", "YUANZHENG_MIGRATION_DATABASE_URL", "YUANZHENG_BACKUP_DATABASE_URL", "PGPASSWORD"]:
		_check(not OS.has_environment(variable), "客户端不继承服务凭据：" + variable)
	if not _check(Online.configure(OS.get_environment("YUANZHENG_TEST_URL")), "真实 HTTPS 地址") or not _check(Online.configure_debug_ca(OS.get_environment("YUANZHENG_TEST_CA")), "验证型测试 CA"):
		await _finish()
		return
	if not _ok(await Online.authenticate(OS.get_environment("YUANZHENG_TEST_USERNAME"), OS.get_environment("YUANZHENG_TEST_PASSWORD"), true), "真实注册"):
		await _finish()
		return
	Online.forget_recovery_code()
	_check(Profile.catalogue_matches(Online.manifest), "服务端与本地白名单一致")
	_page = preload("res://src/ui/OnlineGateway.tscn").instantiate() as Control
	add_child(_page)
	await get_tree().process_frame
	await get_tree().process_frame
	if not await _click(_page, "预览单机角色身份"):
		await _finish()
		return
	_check(_page._gender.selected == (2 if _tag == "a" else 1), "实际导入预览复制性别")
	_check(_page._avatar.selected == 0 and String(_page._import_notice.text).contains("仅在本机"), "自选图片明确回退职业小像")
	var nickname := OS.get_environment("YUANZHENG_TEST_NICKNAME")
	_page._nickname.text = nickname
	_page._avatar.select(3 if _tag == "a" else 4)
	_page._avatar.item_selected.emit(_page._avatar.selected)
	_check(String(_page._avatar_preview.get_meta("avatar_role", "")) == ("fs" if _tag == "a" else "fz") and _page._avatar_preview.get("texture") != null, "实际预览绘制所选已批准小像")
	var create_button := _find_button(_page, "确认创建在线角色")
	var scroll := create_button.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll is ScrollContainer:
		scroll.ensure_control_visible(create_button)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_page._gender.get_global_rect().end.y < 744 and _page._avatar.get_global_rect().end.y < 744, "480×800 选择控件完整显示")
	_check(_page._import_notice.is_visible_in_tree() and _page._import_notice.get_global_rect().end.y < create_button.get_global_rect().position.y, "导入与不带入说明显示在确认创建之前")
	await _capture("identity-create")
	if not await _click(_page, "确认创建在线角色") or not _check(Online.characters.size() == 1, "真实创建一个角色"):
		await _finish()
		return
	var character: Dictionary = Online.characters[0]
	var id := String(character.id)
	var gender := "female" if _tag == "a" else "male"
	var avatar := "role_fs" if _tag == "a" else "role_fz"
	_check(character.get("gender_id") == gender and character.get("avatar_id") == avatar, "创建返回服务端身份")
	_page._begin_delete(character)
	_page._delete_confirmation.text = nickname
	if not await _click(_page, "确认删除角色"):
		await _finish()
		return
	_check(Online.deleted_characters.size() == 1 and Online.deleted_characters[0].get("gender_id") == gender and Online.deleted_characters[0].get("avatar_id") == avatar, "恢复列表保留身份")
	if not await _click(_page, "恢复 " + nickname):
		await _finish()
		return
	await _page._select_character(id)
	_check(Online.selected_character.get("gender_id") == gender and Online.selected_character.get("avatar_id") == avatar, "恢复并选择同一身份")
	var detail: Dictionary = await Online.character_detail(id)
	_check(bool(detail.get("ok", false)) and int(detail.get("data", {}).get("wallet", {}).get("gold", 0)) == 100, "原在线资产仍为 100")
	_check(_snapshot() == _fixture, "页面操作不修改单机身份或资产")
	_page.queue_free()
	await get_tree().process_frame
	_world = preload("res://src/ui/OnlineWorld.tscn").instantiate() as Node2D
	_world.auto_connect = false
	_world.automatic_poll = false
	add_child(_world)
	if not _ok(await _world.enter_world(), "进入真实同频道"):
		await _finish()
		return
	_marker("joined-" + _tag, {"character_id": id})
	if not await _wait_marker("joined-" + ("b" if _tag == "a" else "a")):
		await _finish()
		return
	_ok(await _world.refresh_world(), "取得另一真实玩家身份")
	var peer: Dictionary = {}
	for value in _world.entities:
		if value is Dictionary and String(value.get("id", "")) != id:
			peer = value
	_check(_world.entities.size() == 2 and peer.get("gender_id") == ("male" if _tag == "a" else "female") and peer.get("avatar_id") == ("role_fz" if _tag == "a" else "role_fs"), "他人身份来自真实服务端快照")
	if not await _click(_world, "同行名片"):
		await _finish()
		return
	var peer_row := _find_profile(_world._profiles, String(peer.get("id", "")))
	if _check(peer_row != null, "实际名片中存在另一角色"):
		_check(_labels(peer_row).contains(String(peer.get("nickname", ""))) and _labels(peer_row).contains("男" if _tag == "a" else "女"), "实际名片显示另一角色昵称与性别")
		_check(String(peer_row.get_child(0).get_meta("avatar_role", "")) == ("fz" if _tag == "a" else "fs") and peer_row.get_child(0).get("texture") != null, "他人小像使用已批准资源")
	await _capture("identity-profiles")
	await _click(_world, "关闭名片")
	_check(not is_instance_valid(_world._profiles), "关闭名片保留城镇")
	_marker("inspected-" + _tag)
	await _wait_marker("inspected-" + ("b" if _tag == "a" else "a"))
	_marker("finished-" + _tag, {"character_id": id, "gender_id": gender, "avatar_id": avatar})
	await _finish()


func _finish() -> void:
	if Online.is_authenticated():
		await Online.logout()
	if is_instance_valid(_page):
		_page.queue_free()
	if is_instance_valid(_world):
		_world.queue_free()
	for key in _saved:
		G.set(key, _saved[key])
	await get_tree().process_frame
	await get_tree().process_frame
	if not _initial.is_empty():
		_check(_snapshot() == _initial, "测试样本恢复后单机内存保持原样")
		var after := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
		_check(after == _save_before, "单机存档字节未变")
	print("ONLINE_IDENTITY_OK" if _fails == 0 else "ONLINE_IDENTITY_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
