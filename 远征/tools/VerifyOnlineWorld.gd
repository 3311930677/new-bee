extends Node
## 真实双客户端验收；由 verify_world.py 提供独立账号与故障恢复屏障。

var _fails := 0
var _folder := ""
var _tag := ""
var _page: Node2D
var _before := ""
var _save_before := PackedByteArray()


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_fails += 1
		push_error("ONLINE_WORLD_FAIL " + message)
	return ok


func _ok(result: Dictionary, message: String) -> bool:
	return _check(bool(result.get("ok", false)), "%s：%s" % [message, result.get("error", result.get("code", ""))])


func _local_snapshot() -> String:
	return JSON.stringify({"account": G.account, "role": G.selected_role, "name": G.player_name, "wallet": G.wallet, "items": G.items, "prog": G.prog})


func _marker(name: String, value: Dictionary = {}) -> void:
	var file := FileAccess.open(_folder.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value))


func _wait_marker(name: String, seconds := 50.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not FileAccess.file_exists(_folder.path_join(name)) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	return _check(FileAccess.file_exists(_folder.path_join(name)), "等待联测屏障超时：" + name)


func _capture(name: String) -> void:
	var folder := OS.get_environment("YUANZHENG_WORLD_CAPTURE")
	if folder.is_empty():
		return
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "实际页面截图")


func _ready() -> void:
	await get_tree().process_frame
	_folder = OS.get_environment("YUANZHENG_WORLD_BARRIER")
	_tag = OS.get_environment("YUANZHENG_WORLD_TAG")
	if not _check(not _folder.is_empty() and _tag in ["a", "b"], "必须由真实联测工具提供上下文"):
		_finish()
		return
	_before = _local_snapshot()
	_save_before = FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	var username := OS.get_environment("YUANZHENG_TEST_USERNAME")
	var password := OS.get_environment("YUANZHENG_TEST_PASSWORD")
	_check(Online.configure(OS.get_environment("YUANZHENG_TEST_URL")), "本地联测地址")
	if not _ok(await Online.authenticate(username, password, true), "真实注册"):
		_finish()
		return
	var created: Dictionary = await Online.create_character({"nickname": OS.get_environment("YUANZHENG_TEST_NICKNAME"), "role_id": "zs" if _tag == "a" else "fs"})
	if not _ok(created, "在线创建"):
		_finish()
		return
	var id := String(created.data.character.id)
	if not _ok(await Online.select_character(id), "选择角色"):
		_finish()
		return
	_page = preload("res://src/ui/OnlineWorld.tscn").instantiate() as Node2D
	_page.auto_connect = false
	_page.automatic_poll = false
	add_child(_page)
	if not _ok(await _page.enter_world(), "进入真实城镇"):
		_finish()
		return
	_marker("joined-" + _tag, {"character_id": id})
	if not await _wait_marker("joined-" + ("b" if _tag == "a" else "a")):
		_finish()
		return
	_ok(await _page.refresh_world(), "刷新同屏玩家")
	_check(_page.entities.size() == 2, "两个真实客户端在同一个房间")
	var position_before := Vector2(float(_page.lease.x), float(_page.lease.y))
	var teleport: Dictionary = await Online.move_world(_page.lease, position_before + Vector2(10000, 0))
	_check(not bool(teleport.get("ok", false)) and int(teleport.get("status", 0)) == 400, "服务器拒绝伪造位置")
	for i in 8:
		await get_tree().create_timer(0.16).timeout
		if not _ok(await _page.move_by(Vector2(-10 if _tag == "a" else 10, 22)), "服务器批准逐步移动"):
			_finish()
			return
	_marker("moved-" + _tag)
	if not await _wait_marker("moved-" + ("b" if _tag == "a" else "a")):
		_finish()
		return
	_ok(await _page.refresh_world(), "显示另一客户端的新位置")
	_check(float(_page.lease.y) > position_before.y + 100, "合法移动持久化")
	await _capture("world-" + _tag)
	if not _ok(await _page.challenge("training_wolf"), "真实服务器创建战斗"):
		_finish()
		return
	await _capture("battle-" + _tag)
	_marker("battle-" + _tag, {"battle_id": _page.battle.id})
	if not await _wait_marker("combat-start"):
		_finish()
		return
	var fault_seen := false
	var final_action: Dictionary = {}
	var final_key := ""
	var deadline := Time.get_ticks_msec() + 100000
	var index := 0
	while String(_page.battle.get("status", "")) == "active" and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.18).timeout
		var action := {"action": "attack"}
		if index % 2 == 1:
			for unit_value in _page.battle.get("state", {}).get("units", []):
				if unit_value is Dictionary and String(unit_value.get("kind", "")) == "role":
					for skill_value in unit_value.get("skills", []):
						if skill_value is Dictionary and int(skill_value.get("cd_left", 1)) == 0:
							action = {"action": "skill", "skill_id": String(skill_value.get("id", ""))}
							break
		var key := Online.new_request_id()
		var result: Dictionary = await _page.send_action(action, key)
		if int(result.get("status", 0)) == 500 and not fault_seen:
			fault_seen = true
			_marker("fault-" + _tag)
			if not await _wait_marker("repair-complete"):
				_finish()
				return
			result = await _page.send_action(action, key)
		if not _ok(result, "真实战斗指令与故障重试"):
			_finish()
			return
		final_action = action
		final_key = key
		index += 1
	_check(fault_seen, "真实奖励事务已注入并观察到失败")
	_check(String(_page.battle.get("result", "")) == "victory", "真实权威战斗取得胜利")
	var receipt: Dictionary = _page.battle.get("receipt", {})
	_check(int(receipt.get("gold", 0)) == 10 and int(receipt.get("experience", 0)) == 5 and int(receipt.get("wallet_balance", 0)) == 110, "服务器原子发奖")
	var battle_id := String(_page.battle.get("id", ""))
	for i in 3:
		var repeated: Dictionary = await Online.battle_command(battle_id, final_action, final_key)
		_ok(repeated, "结算请求重放")
		_check(String(repeated.get("data", {}).get("battle", {}).get("receipt", {}).get("result_id", "")) == String(receipt.get("result_id", "")), "重放使用同一张结算回执")
	await _capture("result-" + _tag)
	if not _ok(await Online.authenticate(username, password), "断线后重新登录"):
		_finish()
		return
	_ok(await Online.select_character(id), "重新选择原角色")
	_ok(await _page.enter_world(), "重新进入并恢复未确认结算")
	_check(String(_page.battle.get("id", "")) == battle_id and String(_page.battle.get("status", "")) == "settled", "结算响应丢失后仍能恢复")
	_ok(await _page.confirm_result(), "确认回执并回城")
	var active: Dictionary = await Online.active_battle()
	_check(bool(active.get("ok", false)) and active.data.get("battle") == null, "确认后不重复显示已结束战斗")
	var wallet: Dictionary = await Online.character_detail(id)
	_check(int(wallet.get("data", {}).get("wallet", {}).get("gold", 0)) == 110, "多次重试后金币仅增加一次")
	_check(_before == _local_snapshot(), "单机内存未被在线操作修改")
	var after := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	_check(after == _save_before, "单机存档字节未变")
	_marker("finished-" + _tag, {"character_id": id, "battle_id": battle_id, "receipt": receipt, "commands": index})
	_page.queue_free()
	await get_tree().process_frame
	await Online.logout()
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("ONLINE_WORLD_OK")
	else:
		print("ONLINE_WORLD_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
