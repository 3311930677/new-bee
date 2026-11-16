extends Node

const Profile := preload("res://src/online/OnlineProfile.gd")
var _fails := 0


func _check(ok: bool, reason: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + reason)


func _local_state() -> String:
	return JSON.stringify({"role": G.selected_role, "name": G.player_name, "wallet": G.wallet, "prog": G.prog, "items": G.items, "account": G.account})


func _ready() -> void:
	var before := _local_state()
	var save_before := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	var preview := Profile.import_preview({"selected_role": "fs", "player_name": "归路旅人", "wallet": {"gold": 999999999}, "prog": {"level": 60}, "gm_unlocked": true})
	_check(preview.identity.size() == 3, "角色导入只包含三个身份白名单字段")
	_check(preview.identity.role_id == "fs" and preview.identity.nickname == "归路旅人", "保留职业和昵称建议")
	_check(not preview.identity.has("wallet") and not preview.identity.has("prog"), "本地物资不进入在线创建请求")
	_check(Profile.import_preview({"selected_role": "gm"}).identity.role_id == "zs", "无效本地职业回退公开职业")
	_check(Profile.content_version().length() == 64, "客户端从实际内容计算 SHA256")
	_check(not Online.configure("http://example.com"), "非本地服务禁止明文 HTTP")
	_check(not Online.configure("https://account:password@example.com"), "地址中不允许嵌入凭据")
	_check(Online.configure("https://example.com"), "正式连接使用 HTTPS")
	_check(Online.configure("http://127.0.0.1:1"), "调试构建可连接回环服务")
	Online.access_token = "boundary-test-not-a-server-session"
	Online.selected_character = {"id": "online-character", "nickname": "在线旅人", "level": 1}
	var gm := get_node_or_null("/root/GmConsole")
	if gm != null:
		gm.open_unlocked()
		_check(not gm.visible, "在线会话不能开启本地 GM 控制台")
	Online.clear_session()
	_check(not Online.is_authenticated() and Online.selected_character.is_empty(), "退出清空独立在线状态")
	var failed: Dictionary = await Online.connect_service()
	_check(not bool(failed.get("ok", false)), "服务不可用给出失败结果而非模拟成功")
	_check(_local_state() == before, "联机失败和导入预览不修改任何单机角色或资产")
	var save_after := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	_check(save_before == save_after, "单机存档字节保持不变")
	Online.configure("http://127.0.0.1:18080")
	var page := preload("res://src/ui/OnlineGateway.tscn").instantiate() as Control
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(page._url != null and page._username != null, "真实联机页面创建地址与账号控件")
	_check(page._url.size.x <= 432 and page._url.size.x > 300, "480像素页面内地址控件完整显示")
	_check(page._password.secret, "密码输入采用掩码")
	if "--capture-online" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://tools/_logs/online_gateway_480x800.png")
	page.queue_free()
	await get_tree().process_frame
	if _fails == 0:
		print("ONLINE_BOUNDARY_OK")
	else:
		print("ONLINE_BOUNDARY_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
