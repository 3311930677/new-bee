extends SceneTree
## 私有回环 RPC。公开客户端不直连这里；持久化服务验证会话与角色后转发。

const Battle := preload("res://AuthorityBattle.gd")
const Profile := preload("res://src/online/OnlineProfile.gd")
const World := preload("res://WorldAuthority.gd")
const MAX_FRAME := 2 * 1024 * 1024
const PEER_TIMEOUT_MSEC := 10000

var _server := TCPServer.new()
var _secret := PackedByteArray()
var _peers: Array[Dictionary] = []
var _nonces: Dictionary = {}
var _battles: Dictionary = {}
var _content_version := ""
var _epoch := ""
var _touched: Dictionary = {}


func _initialize() -> void:
	Engine.max_fps = 60
	for variable in ["YUANZHENG_DATABASE_URL", "YUANZHENG_TEST_DATABASE_URL", "YUANZHENG_ADMIN_TOKEN", "YUANZHENG_TLS_KEY", "PGPASSWORD"]:
		if OS.has_environment(variable):
			printerr("ROOM_START_FAILED forbidden persistence or management credentials")
			quit(1)
			return
	_epoch = Crypto.new().generate_random_bytes(16).hex_encode()
	_secret = OS.get_environment("YUANZHENG_ROOM_SECRET").to_utf8_buffer()
	if _secret.size() < 32:
		printerr("ROOM_START_FAILED missing private service key")
		quit(1)
		return
	_content_version = Profile.content_version()
	var port := 19081
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
	if port < 1024 or port > 65535 or _server.listen(port, "127.0.0.1") != OK:
		printerr("ROOM_START_FAILED private listener unavailable")
		quit(1)
		return
	print("AUTHORITY_ROOM_READY port=%d content=%s" % [port, _content_version])


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	for id in _battles.keys():
		if now - int(_touched.get(id, now)) > 300000:
			_battles.erase(id)
			_touched.erase(id)
		else:
			_battles[id].advance(now)
	while _server.is_connection_available():
		var socket := _server.take_connection()
		if _peers.size() >= 128:
			socket.disconnect_from_host()
			continue
		_peers.append({"socket": socket, "in": PackedByteArray(), "out": PackedByteArray(), "sent": 0, "opened": now})
	for index in range(_peers.size() - 1, -1, -1):
		var peer: Dictionary = _peers[index]
		var socket := peer.socket as StreamPeerTCP
		socket.poll()
		var status := socket.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTING and now - int(peer.opened) <= PEER_TIMEOUT_MSEC:
			continue
		if status != StreamPeerTCP.STATUS_CONNECTED or now - int(peer.opened) > PEER_TIMEOUT_MSEC:
			_close(index)
			continue
		if (peer.out as PackedByteArray).is_empty():
			var size := socket.get_available_bytes()
			if size > 0:
				if (peer["in"] as PackedByteArray).size() + size > MAX_FRAME:
					_close(index)
					continue
				var read := socket.get_data(size)
				if int(read[0]) != OK:
					_close(index)
					continue
				var buffer := peer["in"] as PackedByteArray
				buffer.append_array(read[1])
				peer["in"] = buffer
				var newline := buffer.find(10)
				if newline >= 0:
					var reply := _handle(buffer.slice(0, newline).get_string_from_utf8())
					if reply.is_empty():
						_close(index)
						continue
					peer.out = (JSON.stringify(reply) + "\n").to_utf8_buffer()
		if not (peer.out as PackedByteArray).is_empty():
			var output := peer.out as PackedByteArray
			var write := socket.put_partial_data(output.slice(int(peer.sent)))
			if int(write[0]) != OK:
				_close(index)
				continue
			peer.sent = int(peer.sent) + int(write[1])
			if int(peer.sent) >= output.size():
				_close(index)
	return false


func _close(index: int) -> void:
	(_peers[index].socket as StreamPeerTCP).disconnect_from_host()
	_peers.remove_at(index)


func _mac(message: String) -> PackedByteArray:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _secret, message.to_utf8_buffer())


func _handle(line: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(line)
	if not parsed is Dictionary:
		return {}
	var request := parsed as Dictionary
	var body := String(request.get("body", ""))
	var nonce := String(request.get("nonce", ""))
	var timestamp := int(request.get("issued_at", 0))
	var signature := String(request.get("signature", ""))
	var now := int(Time.get_unix_time_from_system())
	if nonce.length() != 36 or signature.length() != 64 or absi(now - timestamp) > 30 or _nonces.has(nonce):
		return {}
	var signed := "%d|%s|%s" % [timestamp, nonce, body]
	if not Crypto.new().constant_time_compare(_mac(signed), signature.hex_decode()):
		return {}
	for old in _nonces.keys():
		if now - int(_nonces[old]) > 60:
			_nonces.erase(old)
	if _nonces.size() >= 10000:
		return {}
	_nonces[nonce] = now
	var payload: Variant = JSON.parse_string(body)
	var result := {"ok": false, "error": "invalid_request"}
	if payload is Dictionary:
		result = _dispatch(payload as Dictionary)
	var reply_body := JSON.stringify(result, "", true, true)
	return {"nonce": nonce, "body": reply_body, "signature": _mac(nonce + "|" + reply_body).hex_encode()}


func _dispatch(payload: Dictionary) -> Dictionary:
	if String(payload.get("content_version", "")) != _content_version or String(payload.get("ruleset_version", "")) != Profile.RULESET_VERSION:
		return {"ok": false, "error": "content_version_mismatch"}
	var method := String(payload.get("method", ""))
	var args_value: Variant = payload.get("args", {})
	if not args_value is Dictionary:
		return {"ok": false, "error": "invalid_request"}
	var args := args_value as Dictionary
	if method == "ping":
		return {"ok": true, "content_version": _content_version, "ruleset_version": Profile.RULESET_VERSION,
			"engine": Engine.get_version_info().string, "battles": _battles.size(), "epoch": _epoch}
	if method == "world.validate_move":
		return World.validate_move(args)
	var id := String(args.get("battle_id", ""))
	if id.length() != 36:
		return {"ok": false, "error": "invalid_battle_id"}
	if _battles.has(id):
		_touched[id] = Time.get_ticks_msec()
	if method == "battle.sync":
		if not args.get("inputs") is Array:
			return {"ok": false, "error": "invalid_journal"}
		var synchronized_battle: RefCounted
		if not _battles.has(id):
			if _battles.size() >= 100:
				return {"ok": false, "error": "capacity"}
			synchronized_battle = Battle.new()
		else:
			synchronized_battle = _battles[id]
		var synchronized: Dictionary = synchronized_battle.synchronize(args, args.inputs, int(args.get("target_tick", -1)))
		if bool(synchronized.get("ok", false)):
			_battles[id] = synchronized_battle
			_touched[id] = Time.get_ticks_msec()
		synchronized["epoch"] = _epoch
		return synchronized
	if method == "battle.start":
		if _battles.has(id):
			var existing: RefCounted = _battles[id]
			var config := Battle.battle_config(args)
			if JSON.stringify(existing.initial, "", true) != JSON.stringify(config, "", true):
				return {"ok": false, "error": "battle_id_conflict"}
			return {"ok": true, "state": existing.snapshot()}
		if _battles.size() >= 100:
			return {"ok": false, "error": "capacity"}
		var battle := Battle.new()
		if not battle.setup(args):
			return {"ok": false, "error": "setup_failed"}
		_battles[id] = battle
		_touched[id] = Time.get_ticks_msec()
		return {"ok": true, "state": battle.snapshot()}
	if method == "battle.replay":
		if not args.get("inputs") is Array:
			return {"ok": false, "error": "invalid_replay"}
		if _battles.has(id):
			return (_battles[id] as RefCounted).replay(args.inputs, int(args.get("target_tick", -1)))
		var cold_battle := Battle.new()
		if not cold_battle.setup(args):
			return {"ok": false, "error": "battle_not_found"}
		return cold_battle.replay(args.inputs, int(args.get("target_tick", -1)))
	if not _battles.has(id):
		return {"ok": false, "error": "battle_not_found"}
	var battle: RefCounted = _battles[id]
	match method:
		"battle.release":
			if not battle.sim.finished:
				return {"ok": false, "error": "battle_in_progress"}
			_battles.erase(id)
			_touched.erase(id)
			return {"ok": true, "released": true}
		"battle.snapshot":
			return {"ok": true, "state": battle.snapshot(), "inputs": battle.inputs.duplicate(true)}
		"battle.command":
			if not args.get("action") is Dictionary:
				return {"ok": false, "error": "invalid_action"}
			return battle.command(int(args.get("sequence", 0)), args.action)
	return {"ok": false, "error": "unknown_method"}
