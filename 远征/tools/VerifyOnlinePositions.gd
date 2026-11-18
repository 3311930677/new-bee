extends Node

const WorldPage := preload("res://src/ui/OnlineWorld.tscn")

var _folder := ""
var _player := ""
var _world: Node2D
var _peer := ""
var _interpolation_seen := false
var _prediction_seen := false


func _ready() -> void:
	await get_tree().process_frame
	_folder = OS.get_environment("YUANZHENG_POSITION_BARRIER")
	_player = OS.get_environment("YUANZHENG_POSITION_PLAYER")
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
	_world = WorldPage.instantiate()
	_world.auto_connect = false
	add_child(_world)
	if not _success(await _world.enter_world()) or not _write("joined-" + _player, {"id": created.data.character.id}):
		_fail("entering authority town")
		return
	var other := "b" if _player == "a" else "a"
	if not await _wait_for(func() -> bool:
		var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("joined-" + other))) if _exists("joined-" + other) else null
		if record is Dictionary:
			_peer = String(record.get("id", ""))
		return not _peer.is_empty(), 40.0):
		_fail("other real client did not join")
		return
	if not await _wait_for(func() -> bool: return _world._position_tick >= 5 and _world._actors.has(_peer), 15.0):
		_fail("nearby traveller did not arrive in the position stream")
		return
	_write("observed-" + _player, {"tick": int(_world._position_tick)})
	if _player == "a":
		await _observe()
	else:
		await _walk()


func _observe() -> void:
	var saw_hidden := await _wait_for(func() -> bool:
		var peer_position := _peer_position()
		if peer_position.is_finite() and _world._actors.has(_peer):
			var actor := _world._actors[_peer] as Node2D
			_interpolation_seen = _interpolation_seen or (actor.position.distance_to(peer_position) > 0.25)
		return _exists("away") and not _world._actors.has(_peer), 35.0)
	if not saw_hidden or not _interpolation_seen or not _write("hidden", {"tween_seen": true}):
		_fail("walking away did not unsubscribe or render interpolated motion")
		return
	if not await _wait_for(func() -> bool: return _exists("returned") and _world._actors.has(_peer), 35.0):
		_fail("returning traveller did not resubscribe")
		return
	var output := OS.get_environment("YUANZHENG_POSITION_CAPTURE")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(output.path_join("position-together.png")) != OK:
			_fail("native positions screenshot")
			return
	_write("visible-again")
	if not await _wait_for(func() -> bool: return _exists("logged-out") and not _world._actors.has(_peer), 15.0):
		_fail("a logged-out traveller remained in the room view")
		return
	await Online.logout()
	_finish()


func _walk() -> void:
	if not await _wait_for(func() -> bool: return _exists("observed-a"), 15.0):
		_fail("observer did not subscribe")
		return
	Input.action_press("ui_down")
	var left := await _wait_for(func() -> bool:
		_prediction_seen = _prediction_seen or float(_world._camera.position.y) > float(_world.lease.get("y", 1520)) + 0.25
		return float(_world.lease.get("y", 0)) >= 2040.0, 27.0)
	Input.action_release("ui_down")
	if not left or not _prediction_seen or not _write("away", {"confirmed_y": float(_world.lease.y), "local_prediction_seen": true}):
		_fail("did not see predicted motion followed by the confirmed distant position")
		return
	if not await _wait_for(func() -> bool: return _exists("hidden"), 15.0):
		_fail("observer kept a traveller outside viewing range")
		return
	Input.action_press("ui_up")
	var returned := await _wait_for(func() -> bool: return float(_world.lease.get("y", 3000)) <= 1595.0, 27.0)
	Input.action_release("ui_up")
	if not returned or not _write("returned", {"confirmed_y": float(_world.lease.y)}):
		_fail("confirmed return to spawn")
		return
	if not await _wait_for(func() -> bool: return _exists("visible-again"), 15.0):
		_fail("observer did not see returning traveller")
		return
	await Online.logout()
	_write("logged-out")
	_finish()


func _peer_position() -> Vector2:
	for person in _world.entities:
		if String(person.get("id", "")) == _peer:
			return Vector2(float(person.get("x", 0)), float(person.get("y", 0)))
	return Vector2.INF


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
	push_error("ONLINE_POSITIONS_FAIL " + message)
	get_tree().quit(1)


func _finish() -> void:
	print("ONLINE_POSITIONS_OK")
	get_tree().quit()
