extends Node

const WorldPage := preload("res://src/ui/OnlineWorld.tscn")

var _folder := ""
var _player := ""
var _world: Node2D
var _peers: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	_folder = OS.get_environment("YUANZHENG_L5_BARRIER")
	_player = OS.get_environment("YUANZHENG_L5_PLAYER")
	if _folder.is_empty() or _player not in ["a", "b", "c", "d", "e", "f"]:
		_fail("missing native L5 configuration")
		return
	if not Online.configure(OS.get_environment("YUANZHENG_TEST_URL")) or not Online.configure_debug_ca(OS.get_environment("YUANZHENG_TEST_CA")):
		_fail("validating HTTPS configuration unavailable")
		return
	if not _success(await Online.authenticate(OS.get_environment("YUANZHENG_TEST_USERNAME"), OS.get_environment("YUANZHENG_TEST_PASSWORD"), true)):
		_fail("native registration")
		return
	var roles := {"a": "zs", "b": "fs", "c": "ck", "d": "fz", "e": "zs", "f": "fs"}
	var created: Dictionary = await Online.create_character({
		"nickname": OS.get_environment("YUANZHENG_TEST_NICKNAME"),
		"role_id": roles[_player],
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

	if not await _wait_for(func() -> bool:
		for p in ["a", "b", "c", "d", "e", "f"]:
			if not _peers.has(p) and _exists("joined-" + p):
				var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("joined-" + p)))
				if rec is Dictionary and not String(rec.get("id", "")).is_empty():
					_peers[p] = String(rec.get("id", ""))
		return _peers.size() == 6 and _exists("seeded"), 60.0):
		_fail("not all 6 clients joined/seeded")
		return

	match _player:
		"a":
			await _run_alpha(char_id)
		"b":
			await _run_bravo(char_id)
		"c":
			await _run_charlie(char_id)
		"d":
			await _run_delta(char_id)
		"e":
			await _run_echo(char_id)
		"f":
			await _run_foxtrot(char_id)


func _run_alpha(char_id: String) -> void:
	# Phase 1: 1v1 Friend Sparring -> zero rating delta
	var ch := await Online.send_pvp_challenge("1v1", String(_peers["b"]), Online.new_request_id())
	if not _success(ch):
		_fail("1v1 challenge send")
		return
	var mid1 := await _wait_active_match(30.0)
	if mid1.is_empty() or not _success(await Online.ready_pvp_match(mid1, true, Online.new_request_id())):
		_fail("1v1 spar ready")
		return
	if not await _wait_match_status(mid1, "active", 30.0):
		_fail("1v1 spar active")
		return
	await Online.tick_pvp_match(mid1, 70)
	if not _success(await Online.pvp_battle_command(mid1, 1, "attack", "", 0, Online.new_request_id())):
		_fail("1v1 spar attack")
		return
	_write("p1-attacked", {"ok": true})
	if not await _wait_match_status(mid1, "completed", 30.0):
		_fail("1v1 spar complete")
		return
	var ov1 := await Online.pvp_overview("1v1")
	if int(ov1.data.ratings["1v1"].rating) != 1000:
		_fail("1v1 sparring mutated rating")
		return
	_write("p1-done", {"ok": true})

	# Phase 2: 1v1 Ranked
	if not _success(await Online.join_pvp_queue("1v1", false, Online.new_request_id())):
		_fail("1v1 ranked queue")
		return
	var mid2 := await _wait_active_match(30.0)
	if mid2.is_empty() or not _success(await Online.ready_pvp_match(mid2, true, Online.new_request_id())):
		_fail("1v1 ranked ready")
		return
	if not await _wait_match_status(mid2, "active", 30.0):
		_fail("1v1 ranked active")
		return
	_write("p2-active", {"mid": mid2})
	if not await _wait_match_status(mid2, "completed", 30.0):
		_fail("1v1 ranked complete")
		return
	var ov2 := await Online.pvp_overview("1v1")
	if int(ov2.data.ratings["1v1"].rating) <= 1000 or int(ov2.data.ratings["2v2"].rating) != 1000 or int(ov2.data.ratings["3v3"].rating) != 1000:
		_fail("1v1 rating isolation check failed")
		return
	_write("p2-done", {"ok": true})

	# Phase 3: 2v2 Premade (a+b) vs Random Fill (c+d), test timeout_default + reconnect protection
	if not _success(await Online.create_party(Online.new_request_id())):
		_fail("2v2 create party")
		return
	if not _success(await Online.invite_party(String(_peers["b"]), Online.new_request_id())):
		_fail("2v2 invite b")
		return
	if not await _wait_for(func() -> bool: return _exists("p3-party-joined"), 30.0):
		_fail("2v2 b join timeout")
		return
	if not _success(await Online.join_pvp_queue("2v2", false, Online.new_request_id())):
		_fail("2v2 premade queue")
		return
	var mid3 := await _wait_active_match(40.0)
	if mid3.is_empty() or not _success(await Online.ready_pvp_match(mid3, true, Online.new_request_id())):
		_fail("2v2 ready")
		return
	if not await _wait_match_status(mid3, "active", 30.0):
		_fail("2v2 active")
		return
	var tick3 := await Online.tick_pvp_match(mid3, 460)
	if not _success(tick3) or int(tick3.data.get("timeout_defaults_applied", 0)) < 1:
		_fail("2v2 timeout_default trigger failed")
		return
	_write("p3-timeout-done", {"mid": mid3})
	if not await _wait_match_status(mid3, "completed", 40.0):
		_fail("2v2 complete")
		return
	await Online.leave_party(Online.new_request_id())
	_write("p3-done", {"ok": true})

	# Phase 4: 3v3 Ranked Premade (a+b+c) vs (d+e + random fill f) + 6-unit capture + Replay + Season + Honor Shop
	if not await _wait_for(func() -> bool: return _exists("p3-b-left"), 30.0):
		_fail("wait p3-b-left")
		return
	if not _success(await Online.create_party(Online.new_request_id())):
		_fail("3v3 create party a")
		return
	if not _success(await Online.invite_party(String(_peers["b"]), Online.new_request_id())) or not _success(await Online.invite_party(String(_peers["c"]), Online.new_request_id())):
		_fail("3v3 invite bc")
		return
	if not await _wait_for(func() -> bool: return _exists("p4-abc-ready"), 40.0):
		_fail("wait p4-abc-ready")
		return
	if not _success(await Online.join_pvp_queue("3v3", false, Online.new_request_id())):
		_fail("3v3 premade queue")
		return
	var mid4 := await _wait_active_match(45.0)
	if mid4.is_empty() or not _success(await Online.ready_pvp_match(mid4, true, Online.new_request_id())):
		_fail("3v3 ready")
		return
	if not await _wait_match_status(mid4, "active", 40.0):
		_fail("3v3 active")
		return
	var mview := await Online.get_pvp_match(mid4)
	var units: Array = mview.data.get("battle_snapshot", {}).get("units", [])
	var role_cnt := 0
	for uv in units:
		if uv is Dictionary and String((uv as Dictionary).get("kind", "")) == "role":
			role_cnt += 1
	if role_cnt != 6:
		_fail("expected 6 role units in 3v3 RoomHost BattleSim, got %d" % role_cnt)
		return
	await _world.open_pvp("match")
	var cap_dir := OS.get_environment("YUANZHENG_L5_CAPTURE")
	if not cap_dir.is_empty():
		await _capture(cap_dir.path_join("pvp-3v3-match.png"))
	_world._close_pvp()

	await Online.tick_pvp_match(mid4, 70)
	if not _success(await Online.pvp_battle_command(mid4, 1, "attack", "", 0, Online.new_request_id())):
		_fail("3v3 attack")
		return
	_write("p4-attacked", {"mid": mid4})
	if not await _wait_match_status(mid4, "completed", 40.0):
		_fail("3v3 complete")
		return

	var rep := await Online.replay_pvp_match(mid4)
	if not _success(rep) or not bool(rep.data.get("replay_verified", false)):
		_fail("3v3 replay verification failed")
		return
	await _world.open_pvp("replay")
	_world._pvp_panel.apply_state((await Online.pvp_overview("3v3")).data, rep.data)
	_world._pvp_panel.set_tab("replay")
	if not cap_dir.is_empty():
		await _capture(cap_dir.path_join("pvp-replay.png"))
	_world._close_pvp()

	if not _success(await Online.claim_pvp_season_reward(Online.new_request_id())):
		_fail("season claim")
		return
	if not _success(await Online.buy_pvp_honor_item("itm_potion_hp_s", Online.new_request_id())):
		_fail("honor shop buy")
		return
	var ovFinal := await Online.pvp_overview("3v3")
	if int(ovFinal.data.ratings["1v1"].rating) <= 1000 or int(ovFinal.data.ratings["2v2"].rating) <= 1000 or int(ovFinal.data.ratings["3v3"].rating) <= 1000:
		_fail("expected independent positive ratings in all 3 modes")
		return
	_write("p4-done", {"mid4": mid4})
	await _cleanup_ok()


func _run_bravo(_char_id: String) -> void:
	# Phase 1: Accept 1v1 spar & forfeit after Alpha attacks
	var cid := await _wait_incoming_challenge(30.0)
	if cid.is_empty() or not _success(await Online.respond_pvp_challenge(cid, true, Online.new_request_id())):
		_fail("b 1v1 spar accept")
		return
	var mid1 := await _wait_active_match(30.0)
	if mid1.is_empty() or not _success(await Online.ready_pvp_match(mid1, true, Online.new_request_id())):
		_fail("b 1v1 spar ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p1-attacked"), 30.0):
		_fail("b wait p1-attacked")
		return
	await Online.forfeit_pvp_match(mid1, Online.new_request_id())
	if not await _wait_for(func() -> bool: return _exists("p1-done"), 30.0):
		_fail("b wait p1-done")
		return

	# Phase 2: 1v1 Ranked
	if not _success(await Online.join_pvp_queue("1v1", false, Online.new_request_id())):
		_fail("b 1v1 ranked queue")
		return
	var mid2 := await _wait_active_match(30.0)
	if mid2.is_empty() or not _success(await Online.ready_pvp_match(mid2, true, Online.new_request_id())):
		_fail("b 1v1 ranked ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p2-active"), 30.0):
		_fail("b wait p2-active")
		return
	await Online.forfeit_pvp_match(mid2, Online.new_request_id())
	if not await _wait_for(func() -> bool: return _exists("p2-done"), 30.0):
		_fail("b wait p2-done")
		return

	# Phase 3: Join Alpha party for 2v2
	var pid := await _wait_party_invite(30.0)
	if pid.is_empty() or not _success(await Online.respond_party_invite(pid, true, Online.new_request_id())):
		_fail("b join 2v2 party")
		return
	_write("p3-party-joined", {"ok": true})
	var mid3 := await _wait_active_match(40.0)
	if mid3.is_empty() or not _success(await Online.ready_pvp_match(mid3, true, Online.new_request_id())):
		_fail("b 2v2 ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p3-done"), 45.0):
		_fail("b wait p3-done")
		return
	await Online.leave_party(Online.new_request_id())
	_write("p3-b-left", {"ok": true})

	# Phase 4: Join Alpha party for 3v3
	var pid2 := await _wait_party_invite(30.0)
	if pid2.is_empty() or not _success(await Online.respond_party_invite(pid2, true, Online.new_request_id())):
		_fail("b join 3v3 party")
		return
	_write("p4-b-joined", {"ok": true})
	var mid4 := await _wait_active_match(45.0)
	if mid4.is_empty() or not _success(await Online.ready_pvp_match(mid4, true, Online.new_request_id())):
		_fail("b 3v3 ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p4-done"), 45.0):
		_fail("b wait p4-done")
		return
	await _cleanup_ok()


func _run_charlie(_char_id: String) -> void:
	if not await _wait_for(func() -> bool: return _exists("p2-done"), 45.0):
		_fail("c wait p2-done")
		return
	# Phase 3: 2v2 Random Fill + disconnect/reconnect protection test
	if not _success(await Online.join_pvp_queue("2v2", true, Online.new_request_id())):
		_fail("c 2v2 queue")
		return
	var mid3 := await _wait_active_match(40.0)
	if mid3.is_empty() or not _success(await Online.ready_pvp_match(mid3, true, Online.new_request_id())):
		_fail("c 2v2 ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p3-timeout-done"), 40.0):
		_fail("c wait timeout")
		return
	if not _success(await Online.pvp_connection(mid3, "disconnected")) or not _success(await Online.pvp_connection(mid3, "reconnected")):
		_fail("c disconnect/reconnect cycle")
		return
	_write("p3-c-reconnected", {"ok": true})
	if not await _wait_for(func() -> bool: return _exists("p3-done"), 40.0):
		_fail("c wait p3-done")
		return

	# Phase 4: Join Alpha party for 3v3
	var pid := await _wait_party_invite(30.0)
	if pid.is_empty() or not _success(await Online.respond_party_invite(pid, true, Online.new_request_id())):
		_fail("c join 3v3 party")
		return
	_write("p4-c-joined", {"ok": true})
	var mid4 := await _wait_active_match(45.0)
	if mid4.is_empty() or not _success(await Online.ready_pvp_match(mid4, true, Online.new_request_id())):
		_fail("c 3v3 ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p4-done"), 45.0):
		_fail("c wait p4-done")
		return
	await _cleanup_ok()


func _run_delta(_char_id: String) -> void:
	if not await _wait_for(func() -> bool: return _exists("p2-done"), 45.0):
		_fail("d wait p2-done")
		return
	if not _success(await Online.join_pvp_queue("2v2", true, Online.new_request_id())):
		_fail("d 2v2 queue")
		return
	var mid3 := await _wait_active_match(40.0)
	if mid3.is_empty() or not _success(await Online.ready_pvp_match(mid3, true, Online.new_request_id())):
		_fail("d 2v2 ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p3-c-reconnected"), 40.0):
		_fail("d wait p3-c-reconnected")
		return
	await Online.forfeit_pvp_match(mid3, Online.new_request_id())
	if not await _wait_for(func() -> bool: return _exists("p3-done"), 40.0):
		_fail("d wait p3-done")
		return

	# Phase 4: Form 2-player premade (d+e) with allow_random_fill=true -> gets matched with f against a+b+c!
	if not _success(await Online.create_party(Online.new_request_id())):
		_fail("d create 3v3 party")
		return
	if not _success(await Online.invite_party(String(_peers["e"]), Online.new_request_id())):
		_fail("d invite e")
		return
	if not await _wait_for(func() -> bool: return _exists("p4-e-joined"), 30.0):
		_fail("d wait e join")
		return
	if not _success(await Online.join_pvp_queue("3v3", true, Online.new_request_id())):
		_fail("d 3v3 queue")
		return
	var mid4 := await _wait_active_match(45.0)
	if mid4.is_empty() or not _success(await Online.ready_pvp_match(mid4, true, Online.new_request_id())):
		_fail("d 3v3 ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p4-attacked"), 45.0):
		_fail("d wait p4-attacked")
		return
	await Online.forfeit_pvp_match(mid4, Online.new_request_id())
	if not await _wait_for(func() -> bool: return _exists("p4-done"), 45.0):
		_fail("d wait p4-done")
		return
	await _cleanup_ok()


func _run_echo(_char_id: String) -> void:
	if not await _wait_for(func() -> bool: return _exists("p3-done"), 60.0):
		_fail("e wait p3-done")
		return
	var pid := await _wait_party_invite(30.0)
	if pid.is_empty() or not _success(await Online.respond_party_invite(pid, true, Online.new_request_id())):
		_fail("e join d party")
		return
	_write("p4-e-joined", {"ok": true})
	var mid4 := await _wait_active_match(45.0)
	if mid4.is_empty() or not _success(await Online.ready_pvp_match(mid4, true, Online.new_request_id())):
		_fail("e 3v3 ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p4-done"), 45.0):
		_fail("e wait p4-done")
		return
	await _cleanup_ok()


func _run_foxtrot(_char_id: String) -> void:
	if not await _wait_for(func() -> bool: return _exists("p3-done"), 60.0):
		_fail("f wait p3-done")
		return
	if not await _wait_for(func() -> bool: return _exists("p4-e-joined") and _exists("p4-b-joined") and _exists("p4-c-joined"), 40.0):
		_fail("f wait parties")
		return
	_write("p4-abc-ready", {"ok": true})
	if not _success(await Online.join_pvp_queue("3v3", true, Online.new_request_id())):
		_fail("f 3v3 random fill queue")
		return
	var mid4 := await _wait_active_match(45.0)
	if mid4.is_empty() or not _success(await Online.ready_pvp_match(mid4, true, Online.new_request_id())):
		_fail("f 3v3 ready")
		return
	if not await _wait_for(func() -> bool: return _exists("p4-done"), 45.0):
		_fail("f wait p4-done")
		return
	await _cleanup_ok()


func _wait_incoming_challenge(timeout_sec: float) -> String:
	var limit := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < limit:
		var ov := await Online.pvp_overview("1v1")
		if _success(ov):
			for cv in ov.data.get("challenges", []):
				if cv is Dictionary and String((cv as Dictionary).get("direction", "")) == "incoming":
					return String((cv as Dictionary).get("id", ""))
		await get_tree().create_timer(0.15).timeout
	return ""


func _wait_active_match(timeout_sec: float) -> String:
	var limit := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < limit:
		var ov := await Online.pvp_overview("1v1")
		if _success(ov):
			var am: Variant = ov.data.get("active_match")
			if am is Dictionary and not (am as Dictionary).is_empty():
				return String((am as Dictionary).get("id", ""))
		await get_tree().create_timer(0.15).timeout
	return ""


func _wait_match_status(match_id: String, want_status: String, timeout_sec: float) -> bool:
	var limit := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < limit:
		var mr := await Online.get_pvp_match(match_id)
		if _success(mr) and String(mr.data.get("status", "")) == want_status:
			return true
		await get_tree().create_timer(0.15).timeout
	return false


func _wait_party_invite(timeout_sec: float) -> String:
	var limit := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < limit:
		var soc := await Online.social_state()
		if _success(soc):
			var invs: Array = soc.data.get("invitations", [])
			if not invs.is_empty():
				return String((invs[0] as Dictionary).get("id", ""))
		await get_tree().create_timer(0.15).timeout
	return ""


func _cleanup_ok() -> void:
	await Online.logout()
	if is_instance_valid(_world):
		_world.queue_free()
	await get_tree().process_frame
	print("ONLINE_PVP_OK")
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
	push_error("ONLINE_PVP_FAIL: " + reason)
	await Online.logout()
	get_tree().quit(1)
