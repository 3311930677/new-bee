extends Node

const WorldPage := preload("res://src/ui/OnlineWorld.tscn")

var _folder := ""
var _player := ""
var _world: Node2D
var _peer := ""


func _ready() -> void:
	await get_tree().process_frame
	_folder = OS.get_environment("YUANZHENG_L1C_BARRIER")
	_player = OS.get_environment("YUANZHENG_L1C_PLAYER")
	if _folder.is_empty() or _player not in ["a", "b"]:
		_fail("missing native test configuration")
		return
	if not Online.configure(OS.get_environment("YUANZHENG_TEST_URL")) or not Online.configure_debug_ca(OS.get_environment("YUANZHENG_TEST_CA")):
		_fail("validating HTTPS configuration unavailable")
		return
	if not _success(await Online.authenticate(OS.get_environment("YUANZHENG_TEST_USERNAME"), OS.get_environment("YUANZHENG_TEST_PASSWORD"), true)):
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
	await _world.refresh_world()
	if _player == "a":
		await _run_alpha(char_id)
	else:
		await _run_bravo()


func _run_alpha(_char_id: String) -> void:
	if not _success(await Online.request_friend(_peer)):
		_fail("requesting friend")
		return
	if not _success(await Online.create_party()) or not _success(await Online.invite_party(_peer)):
		_fail("creating party and inviting peer")
		return
	_write("alpha-invited")
	if not await _wait_for(func() -> bool: return _exists("bravo-joined-ready"), 30.0):
		_fail("bravo did not accept invites")
		return
	if not _success(await Online.send_chat("party", "小队出发啦")) or not _success(await Online.send_chat("room", "城门集合")):
		_fail("sending party and room chat")
		return
	await _world.open_social()
	var output := OS.get_environment("YUANZHENG_L1C_CAPTURE")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(output.path_join("social-party.png")) != OK:
			_fail("capturing social-party screenshot")
			return
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	if is_instance_valid(_world._social_panel) or _world.lease.is_empty():
		_fail("esc did not close social panel while keeping town lease")
		return
	_write("alpha-chatted")
	if not await _wait_for(func() -> bool: return _exists("bravo-reported-blocked"), 30.0):
		_fail("bravo did not finish report/block check")
		return
	# Verify A cannot send friend request to B while blocked.
	var blocked_fr: Dictionary = await Online.request_friend(_peer)
	if bool(blocked_fr.get("ok", false)) or int(blocked_fr.get("status", 0)) != 403:
		_fail("friend request succeeded despite block")
		return
	await Online.logout()
	_write("alpha-done")
	_finish()


func _run_bravo() -> void:
	if not await _wait_for(func() -> bool: return _exists("alpha-invited"), 30.0):
		_fail("alpha did not send invites")
		return
	var st: Dictionary = await Online.social_state()
	if not _success(st):
		_fail("reading social state")
		return
	var reqs: Array = st.data.get("friend_requests", [])
	var invs: Array = st.data.get("invitations", [])
	if reqs.is_empty() or invs.is_empty():
		_fail("missing friend request or party invitation")
		return
	if not _success(await Online.respond_friend(String(reqs[0].id), true)):
		_fail("accepting friend request")
		return
	if not _success(await Online.respond_party_invite(String(invs[0].id), true)):
		_fail("accepting party invitation")
		return
	if not _success(await Online.set_party_ready(true)):
		_fail("setting party ready")
		return
	_write("bravo-joined-ready")
	if not await _wait_for(func() -> bool: return _exists("alpha-chatted"), 30.0):
		_fail("alpha did not send chat")
		return
	var msgs: Dictionary = await Online.chat_messages(0)
	if not _success(msgs) or (msgs.data.get("messages", []) as Array).size() != 2:
		_fail("missing party/room chat messages for bravo")
		return
	if not _success(await Online.report_player(_peer, "spam", "联机冒烟举报验证")):
		_fail("reporting peer")
		return
	if not _success(await Online.block_player(_peer)):
		_fail("blocking peer")
		return
	var hidden: Dictionary = await Online.chat_messages(0)
	if not _success(hidden) or not (hidden.data.get("messages", []) as Array).is_empty():
		_fail("blocked player messages remained visible")
		return
	_write("bravo-reported-blocked")
	if not await _wait_for(func() -> bool: return _exists("alpha-done"), 30.0):
		_fail("alpha did not finish block assertion")
		return
	await Online.logout()
	_finish()


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
	push_error("ONLINE_SOCIAL_FAIL " + message)
	get_tree().quit(1)


func _finish() -> void:
	print("ONLINE_SOCIAL_OK")
	get_tree().quit()
