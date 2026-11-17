extends Node
## 由真实 TLS/运维工具启动。失败证书场景只发无凭据的清单请求。

var _fails := 0


func _check(value: bool, message: String) -> bool:
	if not value:
		_fails += 1
		push_error("ONLINE_TLS_FAIL " + message)
	return value


func _ok(value: Dictionary, message: String) -> bool:
	return _check(bool(value.get("ok", false)), "%s [code=%s transport=%d]" % [message, value.get("code", ""), int(value.get("transport_result", -1))])


func _snapshot() -> String:
	return JSON.stringify({"account": G.account, "role": G.selected_role, "name": G.player_name, "wallet": G.wallet, "items": G.items, "prog": G.prog})


func _ready() -> void:
	await get_tree().process_frame
	var before := _snapshot()
	var save_before := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	var mode := OS.get_environment("YUANZHENG_TLS_CASE")
	if not _check(mode in ["valid", "default-untrusted", "wrong-ca", "wrong-name", "expired"], "必须明确 TLS 验证场景"):
		_finish()
		return
	for name in ["YUANZHENG_DATABASE_URL", "YUANZHENG_TEST_DATABASE_URL", "YUANZHENG_ROOM_SECRET", "YUANZHENG_ADMIN_TOKEN", "YUANZHENG_TLS_KEY", "PGPASSWORD"]:
		_check(not OS.has_environment(name), "客户端不接收服务端秘密：" + name)
	if not _check(OS.get_environment("YUANZHENG_TEST_URL").begins_with("https://") and Online.configure(OS.get_environment("YUANZHENG_TEST_URL")), "使用 HTTPS 验证地址"):
		_finish()
		return
	var ca := OS.get_environment("YUANZHENG_TEST_CA")
	if not ca.is_empty():
		if not _check(Online.configure_debug_ca(ca), "加载本次测试 CA"):
			_finish()
			return
		_check(not Online._debug_tls_options.is_unsafe_client() and Online._debug_tls_options.get_common_name_override().is_empty(), "仍验证证书与目标主机名")
	var connection: Dictionary = await Online.connect_service()
	if mode == "valid":
		if not _ok(connection, "真实 HTTPS 清单与本地版本一致"):
			_finish()
			return
		if not _ok(await Online.authenticate(OS.get_environment("YUANZHENG_TEST_USERNAME"), OS.get_environment("YUANZHENG_TEST_PASSWORD"), true), "TLS 下真实注册"):
			_finish()
			return
		var created: Dictionary = await Online.create_character({"nickname": OS.get_environment("YUANZHENG_TEST_NICKNAME"), "role_id": "zs"})
		if not _ok(created, "TLS 下创建在线角色"):
			_finish()
			return
		var id := String(created.get("data", {}).get("character", {}).get("id", ""))
		_ok(await Online.select_character(id), "TLS 下选择在线角色")
		var detail: Dictionary = await Online.character_detail(id)
		_check(bool(detail.get("ok", false)) and int(detail.get("data", {}).get("wallet", {}).get("gold", 0)) == 100, "TLS 下资产由服务端建立")
		await Online.logout()
		_check(not Online.is_authenticated(), "TLS 下退出在线会话")
	else:
		_check(not OS.has_environment("YUANZHENG_TEST_USERNAME") and not OS.has_environment("YUANZHENG_TEST_PASSWORD"), "失败证书探针不携带账号或密码")
		_check(not bool(connection.get("ok", false)) and int(connection.get("transport_result", -1)) == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, "证书错误由 TLS 握手拒绝")
		_check(Online.manifest.is_empty() and not Online.is_authenticated(), "拒绝后不建立清单或登录状态")
		print("ONLINE_TLS_REJECTED case=%s transport=%d" % [mode, int(connection.get("transport_result", -1))])
	_check(_snapshot() == before, "TLS 验证不修改单机内存")
	var save_after := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	_check(save_after == save_before, "TLS 验证不改写单机存档")
	_finish()


func _finish() -> void:
	print("ONLINE_TLS_OK" if _fails == 0 else "ONLINE_TLS_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
