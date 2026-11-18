extends Node

const WorldPage := preload("res://src/ui/OnlineWorld.tscn")

var _folder := ""
var _player := ""
var _world: Node2D
var _peer := ""


func _ready() -> void:
	await get_tree().process_frame
	_folder = OS.get_environment("YUANZHENG_L1B_BARRIER")
	_player = OS.get_environment("YUANZHENG_L1B_PLAYER")
	if _folder.is_empty() or _player not in ["a", "b"]:
		_fail("missing native test configuration")
		return
	if not Online.configure(OS.get_environment("YUANZHENG_TEST_URL")) or not Online.configure_debug_ca(OS.get_environment("YUANZHENG_TEST_CA")):
		_fail("validating HTTPS configuration unavailable")
		return
	var username := OS.get_environment("YUANZHENG_TEST_USERNAME")
	var password := OS.get_environment("YUANZHENG_TEST_PASSWORD")
	if not _success(await Online.authenticate(username, password, true)):
		_fail("native registration")
		return
	var created: Dictionary = await Online.create_character({
		"nickname": OS.get_environment("YUANZHENG_TEST_NICKNAME"),
		"role_id": "zs" if _player == "a" else "ck",
	})
	if not _success(created) or not _success(await Online.select_character(String(created.data.character.id))):
		_fail("native online roster")
		return
	var char_id := String(created.data.character.id)
	_world = WorldPage.instantiate()
	_world.auto_connect = false
	_world.automatic_poll = false
	add_child(_world)
	if not _success(await _world.enter_world()) or not _write("joined-" + _player, {"id": char_id}):
		_fail("entering authority town")
		return
	var other := "b" if _player == "a" else "a"
	if not await _wait_for(func() -> bool:
		var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("joined-" + other))) if _exists("joined-" + other) else null
		if record is Dictionary:
			_peer = String(record.get("id", ""))
		return not _peer.is_empty(), 40.0):
		_fail("other client did not join")
		return
	if _player == "a":
		await _run_alpha(username, password, char_id)
	else:
		await _run_bravo()


func _run_alpha(username: String, password: String, char_id: String) -> void:
	# Walk slightly right toward npc_warden ([698, 1580]) and interact.
	if not await _walk_to(Vector2(698, 1580)):
		_fail("walking to npc_warden")
		return
	var warden: Dictionary = await _world.interact_npc("npc_warden")
	if not _success(warden) or int((warden.data.get("npc", {}) as Dictionary).get("interaction_count", 0)) != 1:
		_fail("interacting with npc_warden")
		return
	_write("alpha-talked")
	if not await _wait_for(func() -> bool: return _exists("bravo-checked-npc"), 30.0):
		_fail("bravo did not confirm NPC isolation")
		return

	# Walk back to center road x=600, then straight north to north_gate ([616, 140]).
	if not await _walk_to(Vector2(600, 1520)) or not await _walk_to(Vector2(600, 140)) or not await _walk_to(Vector2(616, 140)):
		_fail("walking to north_gate")
		return
	var traveled: Dictionary = await _world.travel_portal("north_gate")
	if not _success(traveled) or String(_world.lease.get("map_id", "")) != "maple_road":
		_fail("traveling through north_gate to maple_road")
		return
	_write("alpha-on-maple", {"x": float(_world.lease.x), "y": float(_world.lease.y)})
	if not await _wait_for(func() -> bool: return _exists("bravo-confirmed-isolated"), 30.0):
		_fail("bravo did not confirm cross-map entity isolation")
		return

	# Interact with maple_road NPC npc_maple_scout ([480, 1660]) and fight maple_wolf ([200, 1460]).
	if not await _walk_to(Vector2(480, 1660)):
		_fail("walking to npc_maple_scout")
		return
	var scout: Dictionary = await _world.interact_npc("npc_maple_scout")
	if not _success(scout) or int((scout.data.get("npc", {}) as Dictionary).get("interaction_count", 0)) != 1:
		_fail("interacting with npc_maple_scout")
		return
	if not await _walk_to(Vector2(200, 1460)):
		_fail("walking to maple_wolf")
		return
	var output := OS.get_environment("YUANZHENG_L1B_CAPTURE")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(output.path_join("maple-road.png")) != OK:
			_fail("capturing maple-road screenshot")
			return
	if not _success(await _world.challenge("maple_wolf")):
		_fail("starting maple_wolf authority battle")
		return
	var battle_deadline := Time.get_ticks_msec() + 45000
	var bstep := 0
	while String(_world.battle.get("status", "")) == "active" and Time.get_ticks_msec() < battle_deadline:
		await get_tree().create_timer(0.18).timeout
		var act := {"action": "skill", "skill_id": "zs_s1"} if bstep % 2 == 1 else {"action": "attack"}
		bstep += 1
		var sent: Dictionary = await _world.send_action(act)
		if not _success(sent):
			_fail("maple_wolf battle attack command")
			return
	if String(_world.battle.get("status", "")) != "settled" or not _success(await _world.confirm_result()):
		_fail("completing maple_wolf battle")
		return

	# Re-login must resume cleanly on maple_road!
	await Online.logout()
	if not _success(await Online.authenticate(username, password, false)) or not _success(await Online.select_character(char_id)):
		_fail("re-authenticating alpha")
		return
	if not _success(await _world.enter_world()) or String(_world.lease.get("map_id", "")) != "maple_road":
		_fail("relog did not resume on maple_road")
		return

	# Walk to south_gate ([480, 1990]) and return to lorin_wilds ([600, 300]).
	if not await _walk_to(Vector2(480, 1990)):
		_fail("walking to south_gate")
		return
	var returned: Dictionary = await _world.travel_portal("south_gate")
	if not _success(returned) or String(_world.lease.get("map_id", "")) != "lorin_wilds" or Vector2(float(_world.lease.x), float(_world.lease.y)).distance_to(Vector2(600, 300)) > 1.0:
		_fail("returning through south_gate to lorin_wilds")
		return
	_write("alpha-returned")
	await Online.logout()
	_finish()


func _run_bravo() -> void:
	if not await _wait_for(func() -> bool: return _exists("alpha-talked"), 30.0):
		_fail("alpha did not talk to warden")
		return
	if not _success(await _world.refresh_world()):
		_fail("bravo refreshing world")
		return
	for npc in _world._npcs:
		if npc is Dictionary and String(npc.get("id", "")) == "npc_warden":
			if bool(npc.get("interacted", true)) or int(npc.get("interaction_count", -1)) != 0:
				_fail("npc_warden state leaked from alpha to bravo")
				return
	_write("bravo-checked-npc")

	if not await _wait_for(func() -> bool: return _exists("alpha-on-maple"), 60.0):
		_fail("alpha did not travel to maple_road")
		return
	# Verify alpha is completely gone from lorin_wilds entities snapshot.
	if not _success(await _world.refresh_world()):
		_fail("bravo refreshing after alpha traveled")
		return
	for entity in _world.entities:
		if entity is Dictionary and String(entity.get("id", "")) == _peer:
			_fail("alpha remained visible in lorin_wilds after moving to maple_road")
			return
	_write("bravo-confirmed-isolated")

	if not await _wait_for(func() -> bool: return _exists("alpha-returned"), 60.0):
		_fail("alpha did not return from maple_road")
		return
	await Online.logout()
	_finish()


func _walk_to(goal: Vector2) -> bool:
	for _i in range(140):
		var here := Vector2(float(_world.lease.get("x", 0)), float(_world.lease.get("y", 0)))
		var delta := goal - here
		if delta.length() <= 16.0:
			if delta.length() <= 1.0:
				return true
			await get_tree().create_timer(0.16).timeout
			return _success(await _world.move_by(delta))
		await get_tree().create_timer(0.16).timeout
		if not _success(await _world.move_by(delta.normalized() * 24.0)):
			return false
	return false


func _success(result: Dictionary) -> bool:
	return bool(result.get("ok", false))


func _exists(name: String) -> bool:
	return FileAccess.file_exists(_folder.path_join(name))


func _write(name: String, data: Dictionary = {}) -> bool:
	var output := FileAccess.open(_folder.path_join(name), FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(JSON.stringify(data))
	return true


func _wait_for(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	return false


func _fail(message: String) -> void:
	push_error("ONLINE_WORLD_L1_FAIL " + message)
	get_tree().quit(1)


func _finish() -> void:
	print("ONLINE_WORLD_L1_OK")
	get_tree().quit()
