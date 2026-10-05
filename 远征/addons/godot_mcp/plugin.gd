@tool
extends EditorPlugin

const DEFAULT_PORT := 38900
const PORT_TRIES := 8

# C1: an editor session with no upper bound on connections will grow _peers forever if a client
# opens-and-drops a socket per request (measured: 1 -> 27 -> 53 -> 72 peers, 1.07% -> 13.60% idle
# CPU at 1188 peers). This is a defensive backstop on top of reaping dead peers every frame, not a
# substitute for it — a client behaving normally should never come close to it.
const MAX_PEERS := 64

# M1: requests are reassembled from raw bytes until a newline is seen. Binary-search measured on
# loopback: a request works up to a `code` length of ~127,734 bytes and fails by ~127,929 (a Godot
# socket-buffer limit, not something this file controls). Reject explicitly, with a clear error,
# well below that boundary rather than let a pending buffer grow toward it silently.
const MAX_PENDING_BYTES := 120000

var _server := TCPServer.new()
var _peers: Array = []
# M1: per-peer partial-line buffer, keyed by the StreamPeerTCP itself (compared by identity). A
# request can arrive split across TCP packets mid-JSON exactly like a reply can — the client
# already buffers on its side; the addon did not buffer on this side.
var _peer_buffers: Dictionary = {}
var _token: String = ""
var _port: int = 0

func _enter_tree() -> void:
	_token = Crypto.new().generate_random_bytes(32).hex_encode()
	var last_err: int = FAILED
	for i in range(PORT_TRIES):
		var try_port: int = DEFAULT_PORT + i
		# Loopback only. This port accepts arbitrary GDScript via the eval op.
		last_err = _server.listen(try_port, "127.0.0.1")
		if last_err == OK:
			_port = try_port
			break
		# P39: 22 is ERR_ALREADY_IN_USE — a stale editor, or a socket still in
		# TIME_WAIT from one killed seconds ago. Keep trying, then report clearly.
		printerr("MCP_BRIDGE_PORT_BUSY: ", try_port, " err=", last_err)
	if last_err != OK:
		printerr("MCP_BRIDGE_ERROR: could not bind any port from ", DEFAULT_PORT, " err=", last_err)
		return
	_write_handshake()
	printerr("MCP_BRIDGE_LISTENING: ", _port)
	set_process(true)
	# Lets a caller-supplied `eval` script reach this instance (e.g. `peer_count()`) for live
	# introspection — the only way to verify C1's peer-reaping from outside the process. This adds
	# no new capability: `eval` already runs arbitrary GDScript with the editor's full privileges,
	# so a caller that can reach this could already do anything reachable from GDScript regardless.
	Engine.set_meta("godot_mcp_plugin", self)

# Test/debug hook (see the _enter_tree comment on Engine.set_meta above). Not one of the five ops
# and not intended as public API — just a live-introspection seam for the C1 regression coverage.
func peer_count() -> int:
	return _peers.size()

func _handshake_path() -> String:
	return "res://.godot/mcp_bridge.json"

# C2 helper: reads the `pid` field of whatever handshake file is currently on disk, without
# assuming it belongs to this instance. Returns 0 (never a real pid) if the file is absent,
# unreadable, or not a well-formed handshake object.
func _read_handshake_pid() -> int:
	var f := FileAccess.open(_handshake_path(), FileAccess.READ)
	if f == null:
		return 0
	var text: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		return 0
	var data = json.data
	if not (data is Dictionary):
		return 0
	return int((data as Dictionary).get("pid", 0))

func _write_handshake() -> void:
	# Two editors can be pointed at the same project (two windows, or a headless instance plus an
	# interactive one); each writes this same shared file, so whichever wrote most recently is the
	# one currently discoverable — that is expected, not the C2 defect. C2 was specifically that
	# EXITING an editor deleted this file unconditionally, including one it no longer owns; that is
	# fixed below, in _exit_tree, by checking pid before deleting. Write to a temp file and rename
	# into place here so a reader never observes a half-written file.
	var tmp_path: String = _handshake_path() + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		printerr("MCP_BRIDGE_ERROR: cannot write handshake file")
		return
	f.store_string(JSON.stringify({
		"port": _port,
		"token": _token,
		"pid": OS.get_process_id(),
		"godot": Engine.get_version_info().string,
	}))
	f.close()

	var abs_tmp: String = ProjectSettings.globalize_path(tmp_path)
	var abs_final: String = ProjectSettings.globalize_path(_handshake_path())
	var rename_err: int = DirAccess.rename_absolute(abs_tmp, abs_final)
	if rename_err != OK:
		printerr("MCP_BRIDGE_ERROR: could not publish handshake atomically, err=", rename_err)
		return

	# M5: the token in this file is the only thing standing between a local process and arbitrary
	# GDScript execution as this user. 0600 — owner read/write only, no group, no other.
	FileAccess.set_unix_permissions(_handshake_path(), FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)

func _exit_tree() -> void:
	# C2: only remove a handshake file that THIS process actually wrote. Deleting unconditionally
	# meant editor #1 exiting (even cleanly, via the plugin being disabled) deleted a still-running
	# editor #2's handshake — live-reproduced: editor #2 stayed up and kept answering on its own
	# port, while every tool reported "no editor bridge" with no true remedy.
	if FileAccess.file_exists(_handshake_path()) and _read_handshake_pid() == OS.get_process_id():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_handshake_path()))
	_server.stop()
	_peers.clear()
	_peer_buffers.clear()
	if Engine.has_meta("godot_mcp_plugin") and Engine.get_meta("godot_mcp_plugin") == self:
		Engine.remove_meta("godot_mcp_plugin")

func _reply(peer: StreamPeerTCP, obj: Dictionary) -> void:
	peer.put_data((JSON.stringify(obj) + "\n").to_utf8_buffer())

# One fully-reassembled request line: parse, authenticate, dispatch, reply. Split out of
# _process so the buffering loop below stays focused on framing, not protocol handling.
func _handle_line(peer: StreamPeerTCP, text: String) -> void:
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		# m1: distinct from "valid JSON but not an object" below — this line was not JSON at all.
		_reply(peer, {"ok": false, "code": "bad_request", "error": "line was not valid JSON"})
		return
	var parsed = json.data
	if not (parsed is Dictionary):
		_reply(peer, {"ok": false, "code": "bad_request", "error": "JSON was valid but not an object"})
		return
	var cmd: Dictionary = parsed
	if String(cmd.get("token", "")) != _token:
		# Do not echo the expected token.
		_reply(peer, {"ok": false, "code": "unauthorized", "error": "token mismatch"})
		return
	# One bad command must not take the listener down.
	var result: Dictionary = _dispatch(cmd)
	_reply(peer, result)

func _process(_delta: float) -> void:
	if _server.is_connection_available():
		if _peers.size() < MAX_PEERS:
			var new_peer: StreamPeerTCP = _server.take_connection()
			_peers.append(new_peer)
			_peer_buffers[new_peer] = ""
		else:
			# Defensive cap (C1): refuse rather than grow unbounded if something upstream is
			# opening connections faster than dead ones are being reaped below.
			var overflow: StreamPeerTCP = _server.take_connection()
			overflow.disconnect_from_host()

	# C1: poll every peer's status and drop anything not connected. The previous version never
	# called poll() at all, so a dead peer's status was never updated and it was never even
	# detectable, let alone reaped — measured leaking one dead socket per tool call forever, and
	# 12.7x idle CPU at ~1200 accumulated peers. Rebuilding the array (rather than mutating while
	# iterating it) keeps removal safe.
	var live: Array = []
	for peer in _peers:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peer_buffers.erase(peer)
			continue
		live.append(peer)
	_peers = live

	for peer in _peers:
		var available: int = peer.get_available_bytes()
		if available <= 0:
			continue
		var raw: String = peer.get_utf8_string(available)
		var buf: String = String(_peer_buffers.get(peer, "")) + raw
		while true:
			var nl: int = buf.find("\n")
			if nl < 0:
				break
			var text: String = buf.substr(0, nl).strip_edges()
			buf = buf.substr(nl + 1)
			if text != "":
				_handle_line(peer, text)
		if buf.length() > MAX_PENDING_BYTES:
			_reply(peer, {
				"ok": false, "code": "request_too_large",
				"error": "request exceeded " + str(MAX_PENDING_BYTES) + " bytes without a newline",
			})
			buf = ""
		_peer_buffers[peer] = buf

func _dispatch(cmd: Dictionary) -> Dictionary:
	var ei := get_editor_interface()
	var op: String = String(cmd.get("op", ""))
	match op:
		"editor_state":
			var root = ei.get_edited_scene_root()
			return {"ok": true, "open_scenes": ei.get_open_scenes(),
				"edited": str(root.name) if root != null else null,
				"godot": Engine.get_version_info().string, "pid": OS.get_process_id()}
		"selection":
			# P38: headless selection is ALWAYS empty. That is a real answer,
			# not a failure — the caller must be able to tell it apart from
			# the bridge being unavailable.
			var names: Array = []
			for n in ei.get_selection().get_selected_nodes():
				names.append(str(n.name))
			return {"ok": true, "selected": names}
		"scene_tree":
			var root2 = ei.get_edited_scene_root()
			if root2 == null:
				return {"ok": false, "code": "no_scene_open", "error": "no scene is open in the editor"}
			var out: Array = []
			_walk(root2, 0, out)
			return {"ok": true, "tree": out}
		"open_scene":
			var path: String = String(cmd.get("path", ""))
			if not ResourceLoader.exists(path):
				return {"ok": false, "code": "no_such_scene", "error": "no scene at " + path}
			ei.open_scene_from_path(path)
			return {"ok": true, "opened": path}
		"eval":
			return _eval(String(cmd.get("code", "")))
	return {"ok": false, "code": "unknown_op", "error": "unknown op: " + op}

func _walk(n: Node, depth: int, out: Array) -> void:
	out.append({"name": str(n.name), "class": n.get_class(), "depth": depth})
	for c in n.get_children():
		_walk(c, depth + 1, out)

func _eval(code: String) -> Dictionary:
	# M2: `code` may contain literal newlines — JSON-encoding already prevents an embedded
	# newline from corrupting the request's framing, so concatenation here needs no change; the
	# caller supplies its own continuation-line indentation (e.g. "var a = 1\n\treturn a").
	var script := GDScript.new()
	script.source_code = "@tool\nextends RefCounted\nfunc run():\n\t" + code
	var err: int = script.reload()
	if err != OK:
		# Measured: a syntax error yields 43 here and does NOT crash the editor.
		return {"ok": false, "code": "compile_failed", "error": "compile failed", "godot_error": err}
	var obj = script.new()
	return {"ok": true, "result": str(obj.run())}
