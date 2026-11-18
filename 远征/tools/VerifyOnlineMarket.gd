extends Node

const WorldPage := preload("res://src/ui/OnlineWorld.tscn")

var _folder := ""
var _player := ""
var _world: Node2D
var _peer := ""


func _ready() -> void:
	await get_tree().process_frame
	_folder = OS.get_environment("YUANZHENG_L3_BARRIER")
	_player = OS.get_environment("YUANZHENG_L3_PLAYER")
	if _folder.is_empty() or _player not in ["a", "b"]:
		_fail("missing native L3 configuration")
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
	# 1. Establish friendship with peer so M3 face-to-face trade works later.
	var fr: Dictionary = await Online.request_friend(_peer)
	if not _success(fr) or not _write("friend-req", {"ok": true}):
		_fail("sending friend request")
		return
	if not await _wait_for(func() -> bool: return _exists("friend-accepted"), 25.0):
		_fail("friend accept barrier")
		return

	# 2. M1: Buy 2 mat_grain from NPC floor shop and list 2 at 16g.
	var npc_res: Dictionary = await Online.npc_market_trade("buy", "mat_grain", 2)
	if not _success(npc_res):
		_fail("npc buy mat_grain")
		return
	var grain_uid := String(npc_res.data.item_uid)
	var list_grain: Dictionary = await Online.create_market_order(grain_uid, 2, 16)
	if not _success(list_grain):
		_fail("listing mat_grain order")
		return
	var grain_order := String(list_grain.data.order_id)

	# 3. M2: Also list seeded unbound forged sword at 60g; verify self-buy triggers rejection + alert!
	var seed_rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("seeded")))
	var sword_uid := String(seed_rec.get("sword_uid", "")) if seed_rec is Dictionary else ""
	var list_sword: Dictionary = await Online.create_market_order(sword_uid, 1, 60)
	if not _success(list_sword):
		_fail("listing forged sword")
		return
	var sword_order := String(list_sword.data.order_id)
	var self_buy: Dictionary = await Online.buy_market_order(sword_order, 1)
	if bool(self_buy.get("ok", false)) or String(self_buy.get("code", "")) != "self_trade_forbidden":
		_fail("expected self_trade_forbidden")
		return

	if not _write("orders-ready", {"grain_order": grain_order, "sword_order": sword_order}):
		_fail("writing orders-ready")
		return
	if not await _wait_for(func() -> bool: return _exists("bravo-bought"), 30.0):
		_fail("waiting for bravo market buys")
		return

	# 4. Cancel remaining 1 grain + claim all pending payouts (sale proceeds + returned grain).
	if not _success(await Online.cancel_market_order(grain_order)):
		_fail("cancelling partial grain order")
		return
	var payouts_res: Dictionary = await Online.market_payouts()
	if not _success(payouts_res):
		_fail("listing market payouts")
		return
	var claimed_count := 0
	for pv in payouts_res.data.payouts:
		if pv is Dictionary and String(pv.get("status", "")) == "pending":
			var cres: Dictionary = await Online.claim_market_payout(String(pv.get("payout_id", "")))
			if not _success(cres):
				_fail("claiming market payout")
				return
			claimed_count += 1
	if claimed_count < 3:
		_fail("expected 3 pending payouts (2 sales + 1 cancel return), got %d" % claimed_count)
		return

	# Open market panel on alpha + test screenshot 1 (market-board.png)
	await _world.open_market("market")
	var cap_dir := OS.get_environment("YUANZHENG_L3_CAPTURE")
	if not cap_dir.is_empty():
		await _capture(cap_dir.path_join("market-board.png"))

	# 5. M3: Start face-to-face trade session with Bravo, offer 5g -> wait for Bravo armor+confirm -> bump to 8g (resets confirm!) -> both confirm latest rev!
	var started: Dictionary = await Online.start_trade_session(_peer)
	if not _success(started):
		_fail("starting trade session")
		return
	var tid := String(started.data.trade_id)
	# Find current grain returned from payout box to include in offer.
	var jrn: Dictionary = await Online.journey_state()
	var ret_grain_uid := ""
	for iv in jrn.data.get("pack", {}).get("items", []):
		if iv is Dictionary and String(iv.get("template_id", "")) == "mat_grain" and int(iv.get("quantity", 0)) >= 1:
			ret_grain_uid = String(iv.get("item_uid", ""))
			break
	if ret_grain_uid.is_empty():
		_fail("returned grain missing in pack after payout claim")
		return
	var off1: Dictionary = await Online.update_trade_offer(tid, {"gold": 5, "add_item_uid": ret_grain_uid, "add_quantity": 1})
	if not _success(off1) or not _write("trade-started", {"trade_id": tid}):
		_fail("offering in trade session")
		return

	if not await _wait_for(func() -> bool: return _exists("bravo-confirmed-1"), 25.0):
		_fail("waiting for bravo confirm 1")
		return

	# Edit gold from 5 -> 8, clearing Bravo's confirmation!
	var off2: Dictionary = await Online.update_trade_offer(tid, {"gold": 8})
	if not _success(off2) or bool(off2.data.get("partner_confirmed", true)):
		_fail("editing trade offer must clear partner confirmation")
		return
	var rev_final := int(off2.data.get("revision", 0))
	if not _write("alpha-edited", {"trade_id": tid, "revision": rev_final}):
		_fail("writing alpha-edited")
		return

	# Refresh UI to face-trade tab and capture face-trade.png while active!
	await _world._refresh_market()
	_world._market_panel.set_tab("trade")
	if not cap_dir.is_empty():
		await _capture(cap_dir.path_join("face-trade.png"))

	var conf_a: Dictionary = await Online.confirm_trade_session(tid, rev_final)
	if not _success(conf_a) or not _write("alpha-confirmed", {"revision": rev_final}):
		_fail("alpha confirming final revision")
		return
	if not await _wait_for(func() -> bool: return _exists("trade-done"), 25.0):
		_fail("waiting for trade completion")
		return

	# Test Esc / ui_cancel closing market panel cleanly while preserving town lease.
	await get_tree().process_frame
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_world._market_panel):
		_fail("ui_cancel did not close market panel")
		return
	var snap := await Online.world_snapshot()
	if not _success(snap) or String(snap.data.lease.character_id) != char_id:
		_fail("town lease lost after closing market panel")
		return
	await _cleanup_ok()


func _run_bravo(_char_id: String) -> void:
	if not await _wait_for(func() -> bool: return _exists("friend-req"), 25.0):
		_fail("waiting friend request")
		return
	var soc: Dictionary = await Online.social_state()
	if not _success(soc):
		_fail("reading social state")
		return
	var incoming: Array = []
	for rv in soc.data.get("friend_requests", []):
		if rv is Dictionary and String((rv as Dictionary).get("direction", "")) == "incoming":
			incoming.append(rv as Dictionary)
	if incoming.is_empty():
		_fail("missing incoming friend request")
		return
	var req_id := String(incoming[0].get("id", ""))
	if not _success(await Online.respond_friend(req_id, true)) or not _write("friend-accepted", {"ok": true}):
		_fail("accepting friend")
		return

	if not await _wait_for(func() -> bool: return _exists("orders-ready"), 30.0):
		_fail("waiting orders-ready")
		return
	var ord := JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("orders-ready"))) as Dictionary
	var grain_order := String(ord.get("grain_order", ""))
	var sword_order := String(ord.get("sword_order", ""))

	# Partial buy 1 mat_grain + full buy M2 forged sword
	if not _success(await Online.buy_market_order(grain_order, 1)):
		_fail("bravo buying partial grain")
		return
	var buy_sword: Dictionary = await Online.buy_market_order(sword_order, 1)
	if not _success(buy_sword):
		_fail("bravo buying forged sword")
		return
	var bought_sword_uid := String(buy_sword.data.buyer_item_uid)
	if not _write("bravo-bought", {"sword_uid": bought_sword_uid}):
		_fail("writing bravo-bought")
		return

	if not await _wait_for(func() -> bool: return _exists("trade-started"), 30.0):
		_fail("waiting trade-started")
		return
	var trd := JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("trade-started"))) as Dictionary
	var tid := String(trd.get("trade_id", ""))
	# Offer bought forged sword in trade, confirm at that revision.
	var boff: Dictionary = await Online.update_trade_offer(tid, {"add_item_uid": bought_sword_uid, "add_quantity": 1})
	if not _success(boff):
		_fail("bravo adding sword to trade")
		return
	var rev1 := int(boff.data.get("revision", 0))
	if not _success(await Online.confirm_trade_session(tid, rev1)) or not _write("bravo-confirmed-1", {"revision": rev1}):
		_fail("bravo confirm 1")
		return

	if not await _wait_for(func() -> bool: return _exists("alpha-edited"), 25.0):
		_fail("waiting alpha-edited")
		return
	var edit_rec := JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join("alpha-edited"))) as Dictionary
	var rev_final := int(edit_rec.get("revision", 0))
	# Verify stale confirmation is rejected cleanly!
	var stale: Dictionary = await Online.confirm_trade_session(tid, rev1)
	if bool(stale.get("ok", false)) or String(stale.get("code", "")) != "trade_changed_reconfirm_required":
		_fail("expected stale revision rejection")
		return

	if not await _wait_for(func() -> bool: return _exists("alpha-confirmed"), 25.0):
		_fail("waiting alpha-confirmed")
		return
	var final_conf: Dictionary = await Online.confirm_trade_session(tid, rev_final)
	if not _success(final_conf) or String(final_conf.data.get("status", "")) != "completed":
		_fail("bravo final confirm did not complete trade")
		return
	if not _write("trade-done", {"ok": true}):
		_fail("writing trade-done")
		return
	await _cleanup_ok()


func _cleanup_ok() -> void:
	await Online.logout()
	if is_instance_valid(_world):
		_world.queue_free()
	await get_tree().process_frame
	print("ONLINE_MARKET_OK")
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
	push_error("ONLINE_MARKET_FAIL: " + reason)
	await Online.logout()
	get_tree().quit(1)
