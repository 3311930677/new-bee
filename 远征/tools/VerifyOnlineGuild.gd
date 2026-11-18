extends Node

const WorldPage := preload("res://src/ui/OnlineWorld.tscn")

var _folder := ""
var _player := ""
var _world: Node2D
var _peer := ""


func _ready() -> void:
	await get_tree().process_frame
	_folder = OS.get_environment("YUANZHENG_L4_BARRIER")
	_player = OS.get_environment("YUANZHENG_L4_PLAYER")
	if _folder.is_empty() or _player not in ["a", "b"]:
		_fail("missing native L4 configuration")
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

	if not _write("joined-" + _player, {"id": char_id}):
		_fail("writing joined barrier")
		return
	var other := "b" if _player == "a" else "a"
	if not await _wait_for(func() -> bool:
		var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("joined-" + other))) if _exists("joined-" + other) else null
		if record is Dictionary:
			_peer = String(record.get("id", ""))
		return not _peer.is_empty() and _exists("seeded"), 40.0):
		_fail("other client did not join or seed")
		return

	if _player == "a":
		await _run_alpha(char_id)
	else:
		await _run_bravo(char_id)


func _run_alpha(char_id: String) -> void:
	# 1. Second World Boss in shenyuan_port (沉渊盐鳞王).
	var wb: Dictionary = await Online.world_boss_current("shenyuan_port")
	if not _success(wb) or String(wb.data.get("boss_id", "")) != "mon_salt_scale":
		_fail("expected shenyuan_port world boss")
		return
	var wb_id := String(wb.data.get("id", ""))
	if not _success(await Online.world_boss_objective(wb_id, "anchor_barricade")):
		_fail("shenyuan boss objective")
		return
	if not _success(await Online.world_boss_engage(wb_id, "attack")):
		_fail("shenyuan boss engage")
		return
	if not _success(await Online.world_boss_claim(wb_id)):
		_fail("shenyuan boss claim")
		return

	await _world.open_coop("boss")
	var cap_dir := OS.get_environment("YUANZHENG_L4_CAPTURE")
	if not cap_dir.is_empty():
		await _capture(cap_dir.path_join("shenyuan-boss.png"))
	_world._close_coop()

	# 2. L4 Dungeon ore_vein puzzle via solo/seeded co-op or 2p queue.
	var inst: Dictionary = await Online.create_coop_instance("ore_vein", "standard", "first_clear", true)
	if not _success(inst):
		_fail("create ore_vein instance")
		return
	var iid := String(inst.data.get("id", ""))
	if not _success(await Online.set_coop_ready(iid, true)):
		_fail("ready ore_vein")
		return
	if not _success(await Online.interact_coop_stage(iid, "rail_map")) or not _success(await Online.interact_coop_stage(iid, "north_lever")):
		_fail("ore_vein rail clue")
		return
	var solved := await Online.interact_coop_stage(iid, "south_switch")
	if not _success(solved) or int(solved.data.get("stage_index", 0)) < 1:
		_fail("ore_vein puzzle advance")
		return
	await Online.leave_coop_instance(iid)

	# 3. Guild creation (50g, Act-II unlocked by seed), recruit Bravo, deposit non-tradeable building material, reject tradeable item.
	var cg: Dictionary = await Online.create_guild("远征星火盟", "护碑拓路")
	if not _success(cg):
		_fail("create guild: " + String(cg.get("error", "")))
		return
	var seed_rec := JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("seeded"))) as Dictionary
	var grain_uid := String(seed_rec.get("grain_uid", ""))
	var timber_uid := String(seed_rec.get("timber_uid", ""))

	var bad_dep := await Online.deposit_guild_warehouse(grain_uid, 1)
	if bool(bad_dep.get("ok", false)) or String(bad_dep.get("code", "")) != "tradeable_item_forbidden":
		_fail("guild warehouse must reject tradeable items")
		return
	if not _success(await Online.deposit_guild_warehouse(timber_uid, 3)):
		_fail("deposit non-tradeable guild timber")
		return
	if not _success(await Online.invite_guild(_peer)) or not _write("guild-invited", {"ok": true}):
		_fail("invite bravo to guild")
		return
	if not await _wait_for(func() -> bool: return _exists("guild-joined"), 25.0):
		_fail("waiting bravo join guild")
		return

	# Grant permissions, update announcement/decor, contribute task expanding member_cap > 30!
	if not _success(await Online.update_guild_permissions(_peer, "officer", true, true, true)):
		_fail("grant bravo permissions")
		return
	if not _success(await Online.update_guild_banner("同赴赤砂矿脉与沉渊港", "gold_banner", "stele_crest")):
		_fail("update guild banner")
		return
	var task_res := await Online.contribute_guild_task("mat_guild_timber", 3)
	if not _success(task_res) or int(task_res.data.guild.get("member_cap", 30)) <= 30:
		_fail("weekly guild task should expand cap > 30")
		return

	await _world.open_guild("warehouse")
	if not cap_dir.is_empty():
		await _capture(cap_dir.path_join("guild-hall.png"))

	# Test Esc closing guild panel cleanly while keeping town lease.
	await get_tree().process_frame
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_world._guild_panel):
		_fail("ui_cancel did not close guild panel")
		return

	if not _write("alpha-done", {"ok": true}):
		_fail("writing alpha-done")
		return
	if not await _wait_for(func() -> bool: return _exists("bravo-done"), 25.0):
		_fail("waiting bravo-done")
		return
	var snap := await Online.world_snapshot()
	if not _success(snap) or String(snap.data.lease.character_id) != char_id:
		_fail("town lease check failed")
		return
	await _cleanup_ok()


func _run_bravo(_char_id: String) -> void:
	if not await _wait_for(func() -> bool: return _exists("guild-invited"), 40.0):
		_fail("waiting guild invite")
		return
	var st := await Online.guild_state()
	var invs: Array = st.data.get("invites", [])
	if not _success(st) or invs.is_empty():
		_fail("missing guild invite")
		return
	if not _success(await Online.respond_guild_invite(String((invs[0] as Dictionary).get("id", "")), true)) or not _write("guild-joined", {"ok": true}):
		_fail("accept guild invite")
		return
	if not await _wait_for(func() -> bool: return _exists("alpha-done"), 30.0):
		_fail("waiting alpha-done")
		return
	# Bravo leaves guild cleanly -> triggers cooldown.
	if not _success(await Online.leave_guild()):
		_fail("bravo leave guild")
		return
	if not _write("bravo-done", {"ok": true}):
		_fail("writing bravo-done")
		return
	await _cleanup_ok()


func _cleanup_ok() -> void:
	await Online.logout()
	if is_instance_valid(_world):
		_world.queue_free()
	await get_tree().process_frame
	print("ONLINE_GUILD_OK")
	get_tree().quit(0)


func _capture(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _wait_for(check: Callable, timeout_sec: float) -> bool:
	var limit := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < limit:
		if check.call():
			return true
		await get_tree().create_timer(0.1).timeout
	return false


func _exists(name: String) -> bool:
	return FileAccess.file_exists(_folder.path_join(name))


func _write(name: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(_folder.path_join(name), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


func _success(result: Dictionary) -> bool:
	return bool(result.get("ok", false))


func _fail(reason: String) -> void:
	push_error("ONLINE_GUILD_FAIL: " + reason)
	await Online.logout()
	get_tree().quit(1)
