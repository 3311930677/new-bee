extends Node

const WorldPage := preload("res://src/ui/OnlineWorld.tscn")

var _folder := ""
var _player := ""
var _world: Node2D
var _peer := ""
var _seq := 1


func _ready() -> void:
	await get_tree().process_frame
	_folder = OS.get_environment("YUANZHENG_L2_BARRIER")
	_player = OS.get_environment("YUANZHENG_L2_PLAYER")
	if _folder.is_empty() or _player not in ["a", "b"]:
		_fail("missing native L2 configuration")
		return
	if not Online.configure(OS.get_environment("YUANZHENG_TEST_URL")) or not Online.configure_debug_ca(OS.get_environment("YUANZHENG_TEST_CA")):
		_fail("validating HTTPS configuration unavailable")
		return
	if not _success(await Online.authenticate(OS.get_environment("YUANZHENG_TEST_USERNAME"), OS.get_environment("YUANZHENG_TEST_PASSWORD"), true)):
		_fail("native registration")
		return
	var created: Dictionary = await Online.create_character({
		"nickname": OS.get_environment("YUANZHENG_TEST_NICKNAME"),
		"role_id": "zs" if _player == "a" else "fz",
	})
	if not _success(created) or not _success(await Online.select_character(String(created.data.character.id))):
		_fail("native online roster")
		return
	var char_id := String(created.data.character.id)
	_world = WorldPage.instantiate()
	_world.auto_connect = false
	_world.automatic_poll = false
	add_child(_world)
	if not _success(await _world.enter_world()):
		_fail("entering authority town")
		return
	await _equip_starter_supplies()

	if not _write("joined-" + _player, {"id": char_id}):
		_fail("writing joined barrier")
		return
	var other := "b" if _player == "a" else "a"
	if not await _wait_for(func() -> bool:
		var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("joined-" + other))) if _exists("joined-" + other) else null
		if record is Dictionary:
			_peer = String(record.get("id", ""))
		return not _peer.is_empty() and _exists("promoted"), 40.0):
		_fail("other client did not join or promote")
		return

	if _player == "a":
		await _run_alpha(char_id)
	else:
		await _run_bravo(char_id)


func _equip_starter_supplies() -> void:
	# Walk smoothly toward npc_steward ([418, 1325]) within 24px move steps
	var aim := Vector2(418, 1325)
	for _step in 16:
		var cur := Vector2(float(_world.lease.get("x", 600.0)), float(_world.lease.get("y", 1520.0)))
		if cur.distance_to(aim) <= 48.0:
			break
		await get_tree().create_timer(0.15).timeout
		await _world.move_by(aim - cur)
	var inter: Dictionary = await Online.interact_journey("s01", "npc_steward")
	if not _success(inter):
		push_error("starter interact failed: " + JSON.stringify(inter))
		return
	var j: Dictionary = await Online.journey_state()
	if not _success(j):
		return
	var items: Array = (j.data.get("pack", {}) as Dictionary).get("items", [])
	for iv in items:
		var item := iv as Dictionary
		var k := String(item.get("kind", ""))
		if k in ["weapon", "armor"]:
			await Online.equip_journey_item(String(item.get("item_uid", "")), true)


func _run_alpha(_char_id: String) -> void:
	# Verify stele_cavern is still locked until journey is complete.
	var pre_ov: Dictionary = await Online.coop_dungeons()
	if not _success(pre_ov):
		_fail("fetching coop overview")
		return
	var lock_ok := false
	for dv in pre_ov.data.get("dungeons", []):
		if String((dv as Dictionary).get("id", "")) == "stele_cavern" and not bool((dv as Dictionary).get("unlocked", true)):
			lock_ok = true
	if not lock_ok:
		_fail("stele_cavern should start locked before journey completion")
		return

	# Queue for tidal_gate (always open, 2 players via real queue matchmaking!)
	var q: Dictionary = await Online.join_coop_queue("tidal_gate", "standard", "first_clear", false)
	if not _success(q):
		_fail("alpha join queue failed")
		return
	_write("alpha-queued")
	if not await _wait_for(func() -> bool: return _exists("bravo-matched"), 40.0):
		_fail("bravo did not match")
		return
	var ov: Dictionary = await Online.coop_dungeons()
	var inst_id := String(ov.data.get("active_instance_id", ""))
	if inst_id.is_empty():
		_fail("alpha missing matched instance_id")
		return

	# Ready up -> Wait for bravo ready -> Cooperatively solve tidal_gate stage 0!
	if not _success(await Online.set_coop_ready(inst_id, true)):
		_fail("alpha ready failed")
		return
	var active_ok := false
	for _retry in 80:
		var ir: Dictionary = await Online.get_coop_instance(inst_id)
		if _success(ir) and String(ir.data.get("status", "")) == "active":
			active_ok = true
			break
		await get_tree().create_timer(0.15).timeout
	if not active_ok:
		_fail("instance did not become active")
		return
	_write("stage0-active", {"id": inst_id})

	# Alpha reads tide record & sets upper sluice!
	if not _success(await Online.interact_coop_stage(inst_id, "tide_record")):
		_fail("alpha tide_record interact failed")
		return
	if not _success(await Online.interact_coop_stage(inst_id, "upper_sluice", "old")):
		_fail("alpha upper_sluice interact failed")
		return
	_write("alpha-sluice-done")

	# Wait for Beta to open bridge sluice & advance instance to stage 1!
	if not await _wait_for(func() -> bool: return _exists("bravo-stage1-ready"), 30.0):
		_fail("bravo did not advance stage 1")
		return

	# Start & fight Stage 1 (mon_tidal_guard + add via REAL RoomHost BattleSim) and Stage 2 (mon_tide_priest)!
	var battle_ok := await _fight_stage_to_end(inst_id, 1)
	if not battle_ok:
		_fail("stage 1 coop battle did not finish in victory")
		return
	_write("stage1-cleared")

	# Boss Stage 2: capture screenshot inside OnlineCoopPanel before or right after completion!
	if not _success(await Online.start_coop_battle(inst_id)):
		_fail("boss start failed")
		return
	_write("boss-started")

	await _world.open_coop("instance")
	var cap_dir := OS.get_environment("YUANZHENG_L2_CAPTURE")
	if not cap_dir.is_empty():
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(cap_dir.path_join("coop-instance.png")) != OK:
			_fail("capturing coop-instance screenshot")
			return
	await get_tree().process_frame
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_world._coop_panel):
		_fail("esc did not close OnlineCoopPanel")
		return

	var boss_ok := await _drive_active_battle(inst_id, 2)
	if not boss_ok:
		_fail("boss stage 2 battle did not finish in victory")
		return
	_write("boss-cleared")

	if not await _wait_for(func() -> bool: return _exists("bravo-drops-claimed"), 30.0):
		_fail("bravo did not claim drops")
		return

	# Alpha claims personal drop!
	var drops: Dictionary = await Online.coop_drops()
	var list: Array = drops.data.get("drops", [])
	if not _success(drops) or list.is_empty():
		_fail("alpha missing personal coop drop")
		return
	if not _success(await Online.claim_coop_drop(String((list[0] as Dictionary).get("id", "")))):
		_fail("alpha claim coop drop failed")
		return

	# Public World Boss (maple_road): complete objective, engage via RoomHost BattleSim, screenshot, and claim reward!
	var wb: Dictionary = await Online.world_boss_current()
	if not _success(wb):
		_fail("world_boss_current failed")
		return
	var eid := String(wb.data.get("id", ""))
	if not _success(await Online.world_boss_objective(eid, "inspect_trail")):
		_fail("world_boss_objective failed")
		return
	if not _success(await Online.world_boss_engage(eid, "attack")):
		_fail("world_boss_engage failed")
		return
	await _world.open_coop("boss")
	if not cap_dir.is_empty():
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(cap_dir.path_join("world-boss.png")) != OK:
			_fail("capturing world-boss screenshot")
			return
	Input.parse_input_event(esc)
	await get_tree().process_frame
	if not _success(await Online.world_boss_claim(eid)):
		_fail("world_boss_claim failed")
		return

	await Online.logout()
	_write("alpha-done")
	_finish()


func _run_bravo(_char_id: String) -> void:
	if not await _wait_for(func() -> bool: return _exists("alpha-queued"), 30.0):
		_fail("alpha did not queue")
		return
	var q: Dictionary = await Online.join_coop_queue("tidal_gate", "standard", "first_clear", false)
	if not _success(q) or String(q.data.get("status", "")) != "matched":
		_fail("bravo did not match with alpha")
		return
	var inst_id := String((q.data.get("instance", {}) as Dictionary).get("id", ""))
	_write("bravo-matched", {"id": inst_id})

	if not _success(await Online.set_coop_ready(inst_id, true)):
		_fail("bravo ready failed")
		return
	if not await _wait_for(func() -> bool: return _exists("alpha-sluice-done"), 30.0):
		_fail("alpha did not finish upper sluice")
		return

	# Beta grabs optional cargo + opens bridge sluice to unlock Stage 1!
	if not _success(await Online.interact_coop_stage(inst_id, "cargo_rescue")):
		_fail("bravo cargo_rescue failed")
		return
	var br: Dictionary = await Online.interact_coop_stage(inst_id, "bridge_sluice", "bridge")
	if not _success(br) or int(br.data.get("stage_index", 0)) != 1:
		_fail("bravo bridge_sluice did not advance stage 1")
		return
	_write("bravo-stage1-ready")

	if not await _wait_for(func() -> bool: return _exists("boss-started"), 60.0):
		_fail("stage 1/boss did not progress")
		return
	# Beta tests disconnect -> safe_defend -> reconnect during boss battle!
	if not _success(await Online.disconnect_coop_instance(inst_id)):
		_fail("bravo disconnect_coop_instance failed")
		return
	var rejoined: Dictionary = await Online.get_coop_instance(inst_id)
	if not _success(rejoined):
		_fail("bravo reconnect failed")
		return

	if not await _wait_for(func() -> bool: return _exists("boss-cleared"), 90.0):
		_fail("boss did not finish")
		return

	# Beta claims independent personal drop!
	var drops: Dictionary = await Online.coop_drops()
	var list: Array = drops.data.get("drops", [])
	if not _success(drops) or list.is_empty():
		_fail("bravo missing personal drop")
		return
	if not _success(await Online.claim_coop_drop(String((list[0] as Dictionary).get("id", "")))):
		_fail("bravo claim drop failed")
		return
	_write("bravo-drops-claimed")

	if not await _wait_for(func() -> bool: return _exists("alpha-done"), 45.0):
		_fail("alpha did not finish world boss")
		return
	await Online.logout()
	_finish()


func _fight_stage_to_end(inst_id: String, expected_stage: int) -> bool:
	var start: Dictionary = await Online.start_coop_battle(inst_id)
	if not _success(start):
		return false
	return await _drive_active_battle(inst_id, expected_stage)


func _drive_active_battle(inst_id: String, from_stage := 1) -> bool:
	var cur := await Online.get_coop_instance(inst_id)
	if not _success(cur):
		return false
	var seq := int((cur.data.get("battle_confirmed_seq", 0))) + 1
	if seq <= 0:
		seq = 1
	var stage_done := func(d: Dictionary) -> bool:
		return String(d.get("status", "")) == "completed" or int(d.get("stage_index", 0)) > from_stage or String(d.get("battle_result", "")) == "victory"
	for i in 60:
		var act := "skill" if (i % 3 == 1) else "attack"
		var sk := "s1" if act == "skill" else ""
		var cmd: Dictionary = await Online.coop_battle_command(inst_id, seq, act, sk, 0, 120)
		if not _success(cmd):
			var chk := await Online.get_coop_instance(inst_id)
			if _success(chk) and stage_done.call(chk.data):
				return true
			seq = int(chk.data.get("battle_confirmed_seq", seq)) + 1
			continue
		seq += 1
		if stage_done.call(cmd.data):
			return true
		if String(cmd.data.get("battle_status", "")) != "active":
			return false
		var tk: Dictionary = await Online.tick_coop_battle(inst_id, 90)
		if _success(tk):
			if stage_done.call(tk.data):
				return true
			if String(tk.data.get("battle_status", "")) != "active":
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
	push_error("ONLINE_COOP_FAIL " + message)
	get_tree().quit(1)


func _finish() -> void:
	print("ONLINE_COOP_OK")
	get_tree().quit()
