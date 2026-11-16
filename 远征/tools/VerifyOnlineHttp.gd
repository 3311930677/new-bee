extends Node
## 由 server/tools/verify_clients.py 启动：连接真实 API，不提供模拟服务。

const Profile := preload("res://src/online/OnlineProfile.gd")
var _fails := 0


func _check(ok: bool, reason: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + reason)


func _snapshot() -> String:
	return JSON.stringify({"account": G.account, "role": G.selected_role, "name": G.player_name, "wallet": G.wallet, "items": G.items, "prog": G.prog})


func _ready() -> void:
	await get_tree().process_frame
	var before := _snapshot()
	var bytes_before := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	var username := OS.get_environment("YUANZHENG_TEST_USERNAME")
	var password := OS.get_environment("YUANZHENG_TEST_PASSWORD")
	var nickname := OS.get_environment("YUANZHENG_TEST_NICKNAME")
	if username.is_empty() or password.is_empty() or nickname.is_empty():
		_check(false, "缺少真实 HTTP 测试身份，拒绝输出成功")
		_finish()
		return
	_check(Online.configure(OS.get_environment("YUANZHENG_TEST_URL")), "接受测试服务的回环地址")
	var connected: Dictionary = await Online.connect_service()
	_check(bool(connected.get("ok", false)), "真实服务器协议、规则和内容摘要一致：%s（传输结果 %d）" % [String(connected.get("error", "")), int(connected.get("transport_result", 0))])
	var login: Dictionary = await Online.authenticate(username, password, true)
	_check(bool(login.get("ok", false)) and Online.is_authenticated(), "通过真实数据库注册并获取会话：%s（传输结果 %d）" % [String(login.get("error", "")), int(login.get("transport_result", 0))])
	if not Online.is_authenticated():
		_finish()
		return
	var preview := Profile.import_preview({"selected_role": OS.get_environment("YUANZHENG_TEST_ROLE"), "player_name": nickname, "wallet": {"gold": 999999999}, "prog": {"level": 60}})
	var identity: Dictionary = preview.identity.duplicate(true)
	identity["wallet"] = {"gold": 999999999}
	identity["level"] = 60
	var key := Online.new_request_id()
	var created: Dictionary = await Online.create_character(identity, key)
	_check(bool(created.get("ok", false)), "真实创建在线角色")
	var character: Dictionary = created.get("data", {}).get("character", {})
	var id := String(character.get("id", ""))
	_check(not id.is_empty() and int(character.get("level", 0)) == 1, "在线角色使用服务端初始等级")
	var repeated: Dictionary = await Online.create_character(identity, key)
	_check(String(repeated.get("data", {}).get("character", {}).get("id", "")) == id, "回包重试返回同一个角色")
	var listed: Dictionary = await Online.refresh_characters()
	_check(bool(listed.get("ok", false)) and Online.characters.size() == 1, "请求重试未复制在线角色")
	var selected: Dictionary = await Online.select_character(id)
	_check(bool(selected.get("ok", false)) and String(Online.selected_character.get("id", "")) == id, "选择真实在线角色")
	var detail: Dictionary = await Online.character_detail(id)
	_check(int(detail.get("data", {}).get("wallet", {}).get("gold", -1)) == 100, "本地伪造金币没有注入在线钱包")
	# Exercise the real refresh flow, without waiting 30 minutes or mocking an API.
	Online.access_token = "expired-access-probe"
	var refreshed: Dictionary = await Online.character_detail(id)
	_check(bool(refreshed.get("ok", false)) and Online.access_token != "expired-access-probe", "访问令牌失效后自动刷新并重试原请求")
	_check(_snapshot() == before, "真实账号/创建/选择不改变单机内存")
	var bytes_after := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	_check(bytes_after == bytes_before, "真实联机操作不修改本地存档字节")
	var capture := OS.get_environment("YUANZHENG_CAPTURE_PATH")
	if not capture.is_empty():
		var page := preload("res://src/ui/OnlineGateway.tscn").instantiate() as Control
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(page)
		await get_tree().process_frame
		await get_tree().process_frame
		await page._select_character(id)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		_check(image.save_png(capture) == OK, "真实联机页面截图成功")
		page.queue_free()
		await get_tree().process_frame
	await Online.logout()
	_check(not Online.is_authenticated(), "退出撤销服务器会话并清空内存令牌")
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("ONLINE_HTTP_OK")
	else:
		print("ONLINE_HTTP_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
