extends Node
## 独立在线状态；令牌只留内存，不读写 G 的单机角色、钱包或 save.json。

signal state_changed
signal refresh_finished(result: Dictionary)

const Profile := preload("res://src/online/OnlineProfile.gd")
const PositionStream := preload("res://src/online/WorldPositionStream.gd")
const REQUEST_TIMEOUT := 20.0
const RESPONSE_LIMIT := 256 * 1024

var base_url := "http://127.0.0.1:18080"
var manifest: Dictionary = {}
var characters: Array = []
var deleted_characters: Array = []
var security_notifications: Array = []
var pending_recovery_code := ""
var account_username := ""
var selected_character: Dictionary = {}
var last_error := ""
var access_token := ""
var _refresh_token := ""
var _generation := 0
var _active_requests: Array[HTTPRequest] = []
var _local_content_version := ""
var _refreshing := false
var _pending_commands: Dictionary = {}
var _debug_tls_options: TLSOptions


func _ready() -> void:
	_local_content_version = Profile.content_version()


func is_authenticated() -> bool:
	return not access_token.is_empty()


func configure(url: String) -> bool:
	url = url.strip_edges().trim_suffix("/")
	var local_http := RegEx.create_from_string("^http://(127\\.0\\.0\\.1|localhost|\\[::1\\])(:[0-9]{1,5})?$")
	var has_forbidden := url.contains("@") or url.contains("?") or url.contains("#") or url.contains(" ")
	if has_forbidden or (not url.begins_with("https://") and not (OS.is_debug_build() and local_http.search(url) != null)):
		last_error = "请输入 HTTPS 服务器地址；本机开发可使用本地地址。"
		return false
	if url != base_url:
		clear_session()
		manifest.clear()
		_debug_tls_options = null
	base_url = url
	return true


func configure_debug_ca(certificate_path: String) -> bool:
	# Local verification may trust its disposable CA without altering system
	# trust. The normal validating client and hostname checks remain enabled.
	if not OS.is_debug_build():
		return false
	var certificate := X509Certificate.new()
	if certificate.load(certificate_path) != OK:
		last_error = "测试证书无法读取。"
		return false
	clear_session()
	manifest.clear()
	_debug_tls_options = TLSOptions.client(certificate)
	return true


func connect_service() -> Dictionary:
	var result: Dictionary = await _request(HTTPClient.METHOD_GET, "/v1/manifest")
	if not bool(result.get("ok", false)):
		return result
	var data: Dictionary = result.get("data", {})
	if int(data.get("protocol_version", 0)) != 1 or String(data.get("ruleset_version", "")) != Profile.RULESET_VERSION or String(data.get("content_version", "")) != _local_content_version:
		return _failure("客户端与服务器版本不一致，请更新游戏。", "content_version_mismatch")
	if Profile.identity_supported(data) and not Profile.catalogue_matches(data):
		return _failure("客户端与服务器的身份小像版本不一致，请更新游戏。", "content_version_mismatch")
	manifest = data.duplicate(true)
	state_changed.emit()
	return result


func authenticate(username: String, password: String, register := false) -> Dictionary:
	if manifest.is_empty():
		var connection: Dictionary = await connect_service()
		if not bool(connection.get("ok", false)):
			return connection
	var path := "/v1/auth/register" if register else "/v1/auth/login"
	var result: Dictionary = await _request(HTTPClient.METHOD_POST, path, {"username": username, "password": password})
	if bool(result.get("ok", false)):
		clear_session()
		account_username = username.strip_edges().to_lower()
		pending_recovery_code = String(result.get("data", {}).get("recovery_code", ""))
		_apply_tokens(result.get("data", {}))
	return result


func recover_account(username: String, code: String, password: String) -> Dictionary:
	var result: Dictionary = await _request(HTTPClient.METHOD_POST, "/v1/auth/recover", {"username": username, "recovery_code": code, "password": password})
	if bool(result.get("ok", false)):
		clear_session()
		pending_recovery_code = String(result.get("data", {}).get("recovery_code", ""))
		state_changed.emit()
	return result


func replace_recovery_code(password: String) -> Dictionary:
	var result: Dictionary = await _request(HTTPClient.METHOD_POST, "/v1/account/recovery-code", {"password": password}, "", true)
	if bool(result.get("ok", false)):
		pending_recovery_code = String(result.get("data", {}).get("recovery_code", ""))
		state_changed.emit()
	return result


func forget_recovery_code() -> void:
	pending_recovery_code = ""
	state_changed.emit()


func refresh_security_notifications() -> Dictionary:
	var result: Dictionary = await _request(HTTPClient.METHOD_GET, "/v1/account/notifications", {}, "", true)
	if bool(result.get("ok", false)):
		var notices: Variant = result.get("data", {}).get("notifications", [])
		security_notifications = notices.duplicate(true) if notices is Array else []
	return result


func acknowledge_security_notification(id: String) -> Dictionary:
	if not _valid_id(id):
		return _failure("找不到这条通知。", "invalid_notification")
	return await _send_command("/v1/account/notifications/%s/acknowledge" % id, {}, "")


func refresh_deleted_characters() -> Dictionary:
	var result: Dictionary = await _request(HTTPClient.METHOD_GET, "/v1/characters/deleted", {}, "", true)
	if bool(result.get("ok", false)):
		var list: Variant = result.get("data", {}).get("characters", [])
		deleted_characters = list.duplicate(true) if list is Array else []
	return result


func nickname_suggestions(nickname: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/v1/nicknames/suggestions?nickname=%s" % nickname.uri_encode(), {}, "", true)


func delete_character(id: String, confirmation: String, request_id := "") -> Dictionary:
	if not _valid_id(id):
		return _failure("找不到该在线角色。", "invalid_character")
	var result: Dictionary = await _send_command("/v1/characters/%s" % id, {"confirm_nickname": confirmation}, request_id, HTTPClient.METHOD_DELETE)
	if bool(result.get("ok", false)) and String(selected_character.get("id", "")) == id:
		selected_character.clear()
		state_changed.emit()
	return result


func restore_character(id: String, request_id := "") -> Dictionary:
	if not _valid_id(id):
		return _failure("找不到该在线角色。", "invalid_character")
	return await _send_command("/v1/characters/%s/restore" % id, {}, request_id)


func refresh_characters() -> Dictionary:
	var result: Dictionary = await _request(HTTPClient.METHOD_GET, "/v1/characters", {}, "", true)
	if bool(result.get("ok", false)):
		var list: Variant = result.get("data", {}).get("characters", [])
		characters = list.duplicate(true) if list is Array else []
		state_changed.emit()
	return result


func create_character(identity: Dictionary, request_id := "") -> Dictionary:
	# Whitelist a second time even when the caller uses an import preview.
	var payload := {"nickname": String(identity.get("nickname", "")), "role_id": String(identity.get("role_id", "")), "appearance_id": String(identity.get("appearance_id", "default"))}
	var gender := String(identity.get("gender_id", "unspecified"))
	var avatar := String(identity.get("avatar_id", "role_default"))
	if not Profile.GENDER_IDS.has(gender):
		return _failure("请选择已开放的性别信息。", "invalid_gender")
	if not Profile.AVATAR_IDS.has(avatar):
		return _failure("请选择已开放的职业小像。", "invalid_avatar")
	if gender != "unspecified" or avatar != "role_default":
		if not Profile.identity_supported(manifest):
			return _failure("当前服务器尚未开放身份小像选择，请使用默认身份或更新服务器。", "identity_not_supported")
		if gender != "unspecified":
			payload.gender_id = gender
		if avatar != "role_default":
			payload.avatar_id = avatar
	return await _send_command("/v1/characters", payload, request_id)


func select_character(id: String, request_id := "") -> Dictionary:
	if not _valid_id(id):
		return _failure("请选择有效的在线角色。", "invalid_character")
	var result: Dictionary = await _send_command("/v1/characters/%s/select" % id, {}, request_id)
	if bool(result.get("ok", false)):
		selected_character = (result.get("data", {}).get("character", {}) as Dictionary).duplicate(true)
		state_changed.emit()
	return result


func character_detail(id: String) -> Dictionary:
	if not _valid_id(id):
		return _failure("找不到该在线角色。", "invalid_character")
	return await _request(HTTPClient.METHOD_GET, "/v1/characters/%s" % id, {}, "", true)


func join_world(request_id := "", channel := 0) -> Dictionary:
	var payload := {}
	if channel > 0:
		payload["channel"] = channel
	return await _send_command("/v1/rooms/join", payload, request_id)


func world_channels() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/v1/rooms/channels", {}, "", true)


func switch_channel(channel: int, request_id := "") -> Dictionary:
	return await _send_command("/v1/rooms/channels/switch", {"channel": channel}, request_id)


func travel_portal(portal_id: String, request_id := "") -> Dictionary:
	return await _send_command("/v1/rooms/travel", {"portal_id": portal_id}, request_id)


func interact_npc(npc_id: String, request_id := "") -> Dictionary:
	return await _send_command("/v1/npcs/%s/interact" % npc_id, {}, request_id)


func world_snapshot() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/v1/rooms/current", {}, "", true)


func open_world_positions() -> PositionStream:
	var features: Variant = manifest.get("features", [])
	if not is_authenticated() or not features is Array or not features.has("town_positions"):
		return null
	var stream := PositionStream.new()
	if not stream.open(base_url, access_token, _local_content_version, _debug_tls_options):
		return null
	return stream


func move_world(lease: Dictionary, target: Vector2, request_id := "") -> Dictionary:
	return await _send_command("/v1/rooms/move", {"lease_token": lease.get("lease_token", ""), "generation": int(lease.get("generation", 0)), "sequence": int(lease.get("move_sequence", 0)) + 1, "x": target.x, "y": target.y}, request_id)


func active_battle() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/v1/battles/active", {}, "", true)


func start_battle(encounter_id: String, request_id := "") -> Dictionary:
	return await _send_command("/v1/battles", {"encounter_id": encounter_id}, request_id)


func battle_snapshot(id: String) -> Dictionary:
	if not _valid_id(id):
		return _failure("找不到这场战斗。", "invalid_battle")
	return await _request(HTTPClient.METHOD_GET, "/v1/battles/%s" % id, {}, "", true)


func battle_command(id: String, action: Dictionary, request_id := "") -> Dictionary:
	if not _valid_id(id):
		return _failure("找不到这场战斗。", "invalid_battle")
	return await _send_command("/v1/battles/%s/commands" % id, action, request_id)


func acknowledge_battle(id: String, request_id := "") -> Dictionary:
	if not _valid_id(id):
		return _failure("找不到这场战斗。", "invalid_battle")
	return await _send_command("/v1/battles/%s/acknowledge" % id, {}, request_id)


func journey_state() -> Dictionary:
	var id := String(selected_character.get("id", ""))
	if id.is_empty():
		return _failure("请先选择在线角色。", "character_required")
	return await _request(HTTPClient.METHOD_GET, "/v1/characters/%s/journey" % id, {}, "", true)


func interact_journey(step: String, target: String, request_id := "") -> Dictionary:
	var id := String(selected_character.get("id", ""))
	if id.is_empty():
		return _failure("请先选择在线角色。", "character_required")
	return await _send_command("/v1/characters/%s/journey/interact" % id,
		{"step_id": step, "target_id": target}, request_id)


func equip_journey_item(item_id: String, equipped: bool, request_id := "") -> Dictionary:
	var id := String(selected_character.get("id", ""))
	if id.is_empty():
		return _failure("请先选择在线角色。", "character_required")
	return await _send_command("/v1/characters/%s/pack/equipment" % id,
		{"item_uid": item_id, "equipped": equipped}, request_id)


func social_state() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/v1/social/state", {}, "", true)


func request_friend(target_id: String, request_id := "") -> Dictionary:
	if not _valid_id(target_id):
		return _failure("找不到目标旅人。", "invalid_target")
	return await _send_command("/v1/social/friends/request", {"target_character_id": target_id}, request_id)


func respond_friend(req_id: String, accept: bool, request_id := "") -> Dictionary:
	if not _valid_id(req_id):
		return _failure("找不到该好友申请。", "invalid_request")
	return await _send_command("/v1/social/friends/%s/respond" % req_id, {"accept": accept}, request_id)


func remove_friend(target_id: String) -> Dictionary:
	if not _valid_id(target_id):
		return _failure("找不到该好友。", "invalid_target")
	return await _request(HTTPClient.METHOD_DELETE, "/v1/social/friends/%s" % target_id, {}, "", true)


func block_player(target_id: String, request_id := "") -> Dictionary:
	if not _valid_id(target_id):
		return _failure("找不到目标旅人。", "invalid_target")
	return await _send_command("/v1/social/blocks", {"target_character_id": target_id}, request_id)


func unblock_player(account_id: String) -> Dictionary:
	if not _valid_id(account_id):
		return _failure("找不到该屏蔽记录。", "invalid_target")
	return await _request(HTTPClient.METHOD_DELETE, "/v1/social/blocks/%s" % account_id, {}, "", true)


func report_player(target_id: String, category: String, reason: String, request_id := "") -> Dictionary:
	if not _valid_id(target_id):
		return _failure("找不到举报对象。", "invalid_target")
	return await _send_command("/v1/social/reports", {"target_character_id": target_id, "category": category, "reason": reason}, request_id)


func chat_messages(after_id := 0) -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/v1/chat/messages?after_id=%d" % maxi(0, after_id), {}, "", true)


func send_chat(channel_kind: String, content: String, recipient_id := "", request_id := "") -> Dictionary:
	var payload := {"channel_kind": channel_kind, "content": content}
	if not recipient_id.is_empty():
		payload["recipient_character_id"] = recipient_id
	return await _send_command("/v1/chat/messages", payload, request_id)


func party_state() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET, "/v1/parties/current", {}, "", true)


func create_party(request_id := "") -> Dictionary:
	return await _send_command("/v1/parties", {}, request_id)


func invite_party(target_id: String, request_id := "") -> Dictionary:
	if not _valid_id(target_id):
		return _failure("找不到目标旅人。", "invalid_target")
	return await _send_command("/v1/parties/invite", {"target_character_id": target_id}, request_id)


func respond_party_invite(invite_id: String, accept: bool, request_id := "") -> Dictionary:
	if not _valid_id(invite_id):
		return _failure("找不到该组队邀请。", "invalid_invite")
	return await _send_command("/v1/parties/invites/%s/respond" % invite_id, {"accept": accept}, request_id)


func set_party_ready(ready: bool, request_id := "") -> Dictionary:
	return await _send_command("/v1/parties/ready", {"ready": ready}, request_id)


func kick_party_member(target_id: String, request_id := "") -> Dictionary:
	if not _valid_id(target_id):
		return _failure("找不到该队友。", "invalid_target")
	return await _send_command("/v1/parties/kick", {"target_character_id": target_id}, request_id)


func promote_party_leader(target_id: String, request_id := "") -> Dictionary:
	if not _valid_id(target_id):
		return _failure("找不到该队友。", "invalid_target")
	return await _send_command("/v1/parties/leader", {"target_character_id": target_id}, request_id)


func leave_party(request_id := "") -> Dictionary:
	return await _send_command("/v1/parties/leave", {}, request_id)


func logout() -> void:
	if is_authenticated():
		await _request(HTTPClient.METHOD_POST, "/v1/auth/logout", {}, "", true)
	clear_session()


func clear_session() -> void:
	_generation += 1
	access_token = ""
	_refresh_token = ""
	characters.clear()
	deleted_characters.clear()
	security_notifications.clear()
	pending_recovery_code = ""
	account_username = ""
	selected_character.clear()
	_pending_commands.clear()
	# Resolve awaiting callers while their scene still exists; a cancelled HTTPRequest
	# does not emit request_completed on its own.
	for http in _active_requests.duplicate():
		if is_instance_valid(http):
			http.cancel_request()
			http.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED, 0, PackedStringArray(), PackedByteArray())
	state_changed.emit()


func new_request_id() -> String:
	return Crypto.new().generate_random_bytes(20).hex_encode()


func _valid_id(id: String) -> bool:
	return RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$").search(id) != null


func _apply_tokens(data: Dictionary) -> void:
	access_token = String(data.get("access_token", ""))
	_refresh_token = String(data.get("refresh_token", ""))
	state_changed.emit()


func _failure(message: String, code: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message, "code": code}


func _request(method: int, path: String, payload: Dictionary = {}, request_id := "", authenticated := false) -> Dictionary:
	var generation := _generation
	if authenticated and not is_authenticated():
		return _failure("请先登录在线账号。", "unauthorized")
	var result: Dictionary = await _raw_request(method, path, payload, request_id, authenticated)
	if generation != _generation:
		return _failure("本次连接已取消。", "cancelled")
	if int(result.get("status", 0)) == 401 and authenticated and not _refresh_token.is_empty():
		var refresh: Dictionary = await _refresh_access()
		if generation != _generation:
			return _failure("本次连接已取消。", "cancelled")
		if not bool(refresh.get("ok", false)):
			clear_session()
			return refresh
		result = await _raw_request(method, path, payload, request_id, true)
		if generation != _generation:
			return _failure("本次连接已取消。", "cancelled")
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "连接失败，请稍后重试。"))
	return result


func _send_command(path: String, payload: Dictionary, explicit_key: String, method := HTTPClient.METHOD_POST) -> Dictionary:
	var intent := str(method) + "|" + path + "|" + JSON.stringify(payload)
	var key := explicit_key
	if key.is_empty():
		if not _pending_commands.has(intent):
			_pending_commands[intent] = new_request_id()
		key = String(_pending_commands[intent])
	var result: Dictionary = await _request(method, path, payload, key, true)
	var status := int(result.get("status", 0))
	if bool(result.get("ok", false)) or status in [400, 404, 409]:
		_pending_commands.erase(intent)
	return result


func _refresh_access() -> Dictionary:
	if _refreshing:
		return await refresh_finished
	_refreshing = true
	var generation := _generation
	var result: Dictionary = await _raw_request(HTTPClient.METHOD_POST, "/v1/auth/refresh", {"refresh_token": _refresh_token}, "", false)
	if generation != _generation:
		result = _failure("本次连接已取消。", "cancelled")
	elif bool(result.get("ok", false)):
		_apply_tokens(result.get("data", {}))
	_refreshing = false
	refresh_finished.emit(result)
	return result


func _raw_request(method: int, path: String, payload: Dictionary, request_id: String, authenticated: bool) -> Dictionary:
	var http := HTTPRequest.new()
	http.use_threads = true
	http.timeout = REQUEST_TIMEOUT
	http.body_size_limit = RESPONSE_LIMIT
	if _debug_tls_options != null:
		http.set_tls_options(_debug_tls_options)
	add_child(http)
	# A startup caller can resume from process_frame before the first full idle
	# iteration. Start the request after the new HTTP node has joined that cycle.
	var generation := _generation
	await get_tree().process_frame
	if generation != _generation:
		http.queue_free()
		return _failure("本次连接已取消。", "cancelled")
	_active_requests.append(http)
	var headers := PackedStringArray(["Content-Type: application/json", "X-Content-Version: %s" % _local_content_version])
	if authenticated:
		headers.append("Authorization: Bearer %s" % access_token)
	if not request_id.is_empty():
		headers.append("Idempotency-Key: %s" % request_id)
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	var started := http.request(base_url + path, headers, method, body)
	if started != OK:
		_active_requests.erase(http)
		http.queue_free()
		return _failure("无法连接服务器，仍可返回继续单机。", "connection_failed")
	var response: Array = await http.request_completed
	_active_requests.erase(http)
	http.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		var failed := _failure("连接中断或超时，仍可返回继续单机。", "connection_failed")
		failed["transport_result"] = int(response[0])
		return failed
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not parsed is Dictionary:
		return _failure("服务器响应异常，请稍后重试。", "invalid_response")
	var status := int(response[1])
	if status >= 200 and status < 300:
		var data: Variant = parsed.get("data", {})
		if not data is Dictionary:
			return _failure("服务器响应异常，请稍后重试。", "invalid_response")
		return {"ok": true, "status": status, "data": data}
	var error: Variant = parsed.get("error", {})
	if not error is Dictionary:
		return _failure("服务器响应异常，请稍后重试。", "invalid_response")
	return {"ok": false, "status": status, "error": String(error.get("message", "连接失败，请稍后重试。")), "code": String(error.get("code", "server_error"))}
