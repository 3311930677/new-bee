extends Node
## 两个真实 Godot 客户端各自完成边城任务和服务器战斗。

var _failures := 0
var _world: Node2D
var _tag := ""
var _barriers := ""
var _local_before := ""
var _save_before := PackedByteArray()


func _check(condition: bool, words: String) -> bool:
	if not condition:
		_failures += 1
		push_error("ONLINE_JOURNEY_FAIL " + words)
	return condition


func _ok(reply: Dictionary, words: String) -> bool:
	return _check(bool(reply.get("ok", false)), "%s [status=%d code=%s]" % [words, int(reply.get("status", 0)), reply.get("code", "")])


func _local_snapshot() -> String:
	return JSON.stringify({"account": G.account, "wallet": G.wallet, "items": G.items,
		"prog": G.prog, "role": G.selected_role, "name": G.player_name})


func _marker(name: String, value: Dictionary = {}) -> void:
	var file := FileAccess.open(_barriers.path_join(name + "-" + _tag), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value))


func _wait_peer(name: String) -> bool:
	var peer := "b" if _tag == "a" else "a"
	var path := _barriers.path_join(name + "-" + peer)
	var deadline := Time.get_ticks_msec() + 65000
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	return _check(FileAccess.file_exists(path), "另一位旅人完成 " + name)


func _capture(name: String) -> void:
	var folder := OS.get_environment("YUANZHENG_JOURNEY_CAPTURE")
	if not folder.is_empty():
		await RenderingServer.frame_post_draw
		_check(get_viewport().get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "480×800截图")


func _find_button(root: Node, words: String) -> Control:
	if root is Control and not root.is_visible_in_tree():
		return null
	if root is Control and not root.gui_input.get_connections().is_empty():
		for child in root.get_children():
			if child is Label and String(child.text).replace(" ", "") == words.replace(" ", ""):
				return root as Control
	for child in root.get_children():
		var result := _find_button(child, words)
		if result != null:
			return result
	return null


func _find_item(root: Node, template: String) -> Node:
	if String(root.get_meta("template_id", "")) == template:
		return root
	for child in root.get_children():
		var result := _find_item(child, template)
		if result != null:
			return result
	return null


func _click(root: Node, words: String) -> bool:
	var button := _find_button(root, words) if is_instance_valid(root) else null
	if not _check(button != null, "实际界面按钮存在：" + words):
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
	var deadline := Time.get_ticks_msec() + 35000
	while _world._busy and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
	await get_tree().process_frame
	return _check(not _world._busy, "页面动作完成：" + words)


func _approach(at: Vector2, distance: float) -> bool:
	for i in 42:
		var current := Vector2(float(_world.lease.x), float(_world.lease.y))
		var remaining := at - current
		if remaining.length() <= distance:
			return true
		await get_tree().create_timer(0.17).timeout
		if not _ok(await _world.move_by(remaining.limit_length(24)), "沿地图逐步移动"):
			return false
	return _check(false, "抵达当前任务坐标")


func _step(id: String) -> bool:
	return _check(String(_world._journey.get("id", "")) == id,
		"当前任务应为 %s（实际 %s）" % [id, _world._journey.get("id", "")])


func _item(reply: Dictionary, template: String) -> Dictionary:
	for value in reply.get("data", {}).get("pack", {}).get("items", []):
		if String(value.get("template_id", "")) == template:
			return value
	return {}


func _role_unit() -> Dictionary:
	for unit in _world.battle.get("state", {}).get("units", []):
		if String(unit.get("kind", "")) == "role":
			return unit
	return {}


func _win() -> bool:
	var deadline := Time.get_ticks_msec() + 50000
	while String(_world.battle.get("status", "")) == "active" and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.19).timeout
		if not _ok(await _world.send_action({"action": "attack"}), "真实攻击指令"):
			return false
	return _check(String(_world.battle.get("result", "")) == "victory", "真实胜利结算")


func _use_medicine() -> bool:
	var deadline := Time.get_ticks_msec() + 14000
	while Time.get_ticks_msec() < deadline:
		var unit := _role_unit()
		if int(unit.get("hp", 0)) < int(unit.get("max_hp", 0)):
			break
		await get_tree().create_timer(0.22).timeout
		if not _ok(await _world.refresh_battle(), "等待权威怪物攻击"):
			return false
	if not _check(int(_role_unit().get("hp", 0)) < int(_role_unit().get("max_hp", 0)), "药品在受伤后使用"):
		return false
	var key := Online.new_request_id()
	var action := {"action": "potion"}
	var applied: Dictionary = await _world.send_action(action, key)
	if not _ok(applied, "权威接受服药"):
		return false
	var duplicate: Dictionary = await _world.send_action(action, key)
	var battle: Dictionary = applied.data.battle
	if not _ok(duplicate, "药品请求原键重放") or not _check(duplicate.data == applied.data
			and bool(battle.last_input.accepted) and int(battle.state.potions) == 2, "只扣除一瓶并返回相同回执"):
		return false
	var pack: Dictionary = await Online.journey_state()
	return _ok(pack, "战斗中读权威行囊") and _check(int(_item(pack, "itm_potion_hp_s").get("quantity", 0)) == 2, "服务端库存同步为两瓶")


func _run() -> bool:
	_tag = OS.get_environment("YUANZHENG_JOURNEY_TAG")
	_barriers = OS.get_environment("YUANZHENG_JOURNEY_BARRIER")
	if not _check(_tag in ["a", "b"] and not _barriers.is_empty(), "真实双端上下文"):
		return false
	for variable in ["YUANZHENG_DATABASE_URL", "YUANZHENG_TEST_DATABASE_URL", "YUANZHENG_ROOM_SECRET", "YUANZHENG_ADMIN_TOKEN", "PGPASSWORD"]:
		if not _check(not OS.has_environment(variable), "客户端环境无服务端凭据"):
			return false
	var user := OS.get_environment("YUANZHENG_TEST_USERNAME")
	var password := OS.get_environment("YUANZHENG_TEST_PASSWORD")
	if not _check(Online.configure(OS.get_environment("YUANZHENG_TEST_URL")) and Online.configure_debug_ca(OS.get_environment("YUANZHENG_TEST_CA")), "验证型 HTTPS 连接"):
		return false
	if not _ok(await Online.authenticate(user, password, true), "真实账号注册"):
		return false
	Online.forget_recovery_code()
	var created: Dictionary = await Online.create_character({"nickname": OS.get_environment("YUANZHENG_TEST_NICKNAME"),
		"role_id": "zs" if _tag == "a" else "fz"})
	if not _ok(created, "创建独立角色"):
		return false
	var id := String(created.data.character.id)
	if not _ok(await Online.select_character(id), "选择在线角色"):
		return false
	_world = preload("res://src/ui/OnlineWorld.tscn").instantiate() as Node2D
	_world.auto_connect = false
	_world.automatic_poll = false
	add_child(_world)
	if not _ok(await _world.enter_world(), "实际进入昭元边城") or not _step("s01"):
		return false
	_marker("joined")
	if not await _wait_peer("joined") or not _ok(await _world.refresh_world(), "刷新同屏"):
		return false
	if not _check(_world.entities.size() == 2, "同屏有两位真实旅人"):
		return false
	var initial: Dictionary = await Online.journey_state()
	if not _ok(initial, "查询新角色行囊") or not _check(initial.data.pack.items.is_empty(), "角色从独立空背包开始"):
		return false
	var far: Dictionary = await Online.interact_journey("s01", "npc_steward")
	if not _check(String(far.get("code", "")) == "too_far", "远处不可与闻叔交谈"):
		return false
	if not await _approach(Vector2(418, 1325), 82) or not await _click(_world, "与闻叔交谈") or not _step("gear_up"):
		return false
	await _capture("journey-supplies")
	var weapon := "tpl_sword_basic" if _tag == "a" else "tpl_hammer_basic"
	for template in [weapon, "tpl_armor_basic"]:
		var row := _find_item(_world._journey_panel, template)
		if not await _click(row, "装备"):
			return false
	var closed_by_panel: Array[bool] = []
	_world._journey_panel.closed.connect(func() -> void: closed_by_panel.append(true))
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	get_viewport().push_input(cancel)
	await get_tree().process_frame
	if not _check(closed_by_panel.size() == 1 and not is_instance_valid(_world._journey_panel)
			and _world._connected and not _world.lease.is_empty(), "Esc 由行囊处理且保留城镇连接") or not _step("south_check"):
		return false
	if not await _approach(Vector2(600, 1588), 72) or not await _click(_world, "查看城南路标") or not _step("wolf_trial"):
		return false
	if not await _click(_world._journey_panel, "返回边城") or not await _approach(Vector2(600, 1740), 70):
		return false
	if not await _click(_world, "城南试炼 · 挑战野狼"):
		return false
	var role := _role_unit()
	var base := TableCache.role_stats("zs" if _tag == "a" else "fz", 1)
	if not _check(int(role.get("max_hp", 0)) == int(base.max_hp) + (50 if _tag == "a" else 80)
			and int(role.get("atk", 0)) == int(base.atk) + (10 if _tag == "a" else 9), "武器和护甲加成实际进入权威战斗"):
		return false
	if not await _use_medicine() or not await _win() or not _ok(await _world.confirm_result(), "确认野狼回执") or not _step("report_back"):
		return false
	if not await _approach(Vector2(418, 1325), 82) or not await _click(_world, "与闻叔交谈") or not _step("choose_companion"):
		return false
	if not await _click(_find_item(_world._journey_panel, "pet_rockturtle"), "出战") or not _step("patrol_trial"):
		return false
	if not await _click(_world._journey_panel, "返回边城") or not _ok(await _world.refresh_world(), "领取自己的巡查目标"):
		return false
	if not await _approach(Vector2(752, 1850), 74) or not await _click(_world, "碑影巡查 · 挑战树妖"):
		return false
	var ally := false
	for unit in _world.battle.get("state", {}).get("units", []):
		if unit.get("template_id") == "pet_rockturtle" and unit.get("side") == "ally":
			ally = true
	if not _check(ally and _world._battle_page._cards.size() == 3, "岩龟进入真实权威战斗并显示在战斗页"):
		return false
	await _capture("journey-companion")
	if not await _win() or not _ok(await _world.confirm_result(), "确认巡查回执") or not _step("old_rubbing"):
		return false
	if not await _approach(Vector2(418, 1740), 82) or not await _click(_world, "与青姨交谈") or not _step("complete"):
		return false
	await _capture("journey-coop-entry")
	await Online.logout()
	if not _check(not Online.is_authenticated(), "离开首次会话") or not _ok(await Online.authenticate(user, password), "真实重新登录"):
		return false
	if not _ok(await Online.select_character(id), "重选原角色"):
		return false
	var final: Dictionary = await Online.journey_state()
	var wallet: Dictionary = await Online.character_detail(id)
	if not _ok(final, "重登查询任务与行囊") or not _ok(wallet, "重登查询金币"):
		return false
	if not _check(final.data.journey.id == "complete" and final.data.journey.coop_entry == "stele_cavern"
			and final.data.pack.items.size() == 4 and _item(final, weapon).get("equipped_slot") == "weapon"
			and _item(final, "pet_rockturtle").get("equipped_slot") == "companion"
			and int(_item(final, "itm_potion_hp_s").get("quantity", 0)) == 2 and int(wallet.data.wallet.gold) == 125,
			"重登保留独立进度、出战、两瓶药品和 125 在线金币"):
		return false
	_marker("finished", {"character_id": id, "role_id": created.data.character.role_id, "step": "complete"})
	return true


func _ready() -> void:
	await get_tree().process_frame
	_local_before = _local_snapshot()
	_save_before = FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	var finished := await _run()
	if Online.is_authenticated():
		await Online.logout()
		_check(not Online.is_authenticated(), "注销最终在线会话")
	if is_instance_valid(_world):
		_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_local_before == _local_snapshot(), "单机内存未变")
	var save_after := FileAccess.get_file_as_bytes(G.SAVE_PATH) if FileAccess.file_exists(G.SAVE_PATH) else PackedByteArray()
	_check(_save_before == save_after, "单机存档未写入")
	var passed := finished and _failures == 0
	print("ONLINE_JOURNEY_OK" if passed else "ONLINE_JOURNEY_FAIL")
	get_tree().quit(0 if passed else 1)
