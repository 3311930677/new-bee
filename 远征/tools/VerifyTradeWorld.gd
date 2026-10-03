## P06 world integration: persistent trade entities, proximity UI, order delivery and reload.
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_trade_world.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "商路行者"
	G.wallet["gold"] = 3000
	G.prog["level"] = 12
	G.act1_state()["side_quests"] = {"a1_trade_cart": {"status": "done"}}
	await _run()
	print("TRADE_WORLD_OK" if _fails == 0 else "TRADE_WORLD_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)


func _make_run() -> RunState:
	var run := RunState.new()
	run.setup({"theme": "forest", "role_id": "zs", "level": 12,
		"active_pet": "pet_rockturtle", "bench_pet": "", "potions": 2, "seed": 53})
	return run


func _enter_map(map_id: String) -> MapScene:
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": map_id, "run": _make_run(),
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	return map


func _entity(map: MapScene, eid: String) -> Node2D:
	for ent in map._quest_entities:
		if is_instance_valid(ent) and String(ent.eid) == eid:
			return ent
	return null


func _run() -> void:
	_check(bool(G.economy_first_order_accept().get("ok", false)), "送盐后应能接首单")
	_check(bool(G.economy_trade("city_market", "trade_salt", "buy", 2).get("ok", false)),
		"市集应卖出订单用盐")
	_check(bool(G.economy_trade("city_market", "trade_iron", "buy", 1).get("ok", false)),
		"市集应卖出订单用铁")
	var expected_reward := int(G.economy_first_order()["payout_gold"])
	var before_gold := int(G.wallet["gold"])
	var slope := await _enter_map("broken_slope")
	var walk_bridge := _entity(slope, "first_order_walk_bridge")
	_check(walk_bridge != null and _entity(slope, "first_order_ride_bridge") != null,
		"铁料运单在坡口提供步行与骑乘两种桥面处理")
	if walk_bridge != null: slope.on_quest_entity(walk_bridge)
	_check(bool(G.economy_first_order()["bridge_aided"]) and
		String(G.economy_first_order()["bridge_mode"]) == "walk" and
		int(G.economy_first_order()["payout_gold"]) == expected_reward + 8,
		"步行系绳可为本批运单减免运费")
	expected_reward = int(G.economy_first_order()["payout_gold"])
	_check(not bool(G.first_order_bridge("broken_slope", "first_order_ride_bridge").get("ok", false))
		and G.reload_save() and bool(G.economy_first_order()["bridge_aided"]),
		"不能重复桥面折让，读档仍保留")
	await get_tree().process_frame
	var camp := _entity(slope, "trade_slope_camp")
	_check(camp != null, "断碑营地应有常驻可交互交易实体")
	if camp != null:
		slope._player.position = camp.position + Vector2(0, 30)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(slope._trade_panel != null and slope._modal_open(),
			"靠近营地应打开交易页并冻结接战")
		if slope._trade_panel != null:
			_check(slope._trade_panel.site_id == "slope_camp", "面板应显示营地行情")
			slope._trade_panel._order_deliver()
			_check(String(G.economy_first_order().get("status", "")) == "done"
				and int(G.wallet["gold"]) == before_gold + expected_reward,
				"营地面板交单应扣实物并发锁定净报酬")
			_check(G.item_count("trade_salt") == 0 and G.item_count("trade_iron") == 0,
				"交单后所需货品应从背包扣除")
			slope._trade_panel.close()
			await get_tree().process_frame
			_check(slope._trade_panel == null, "关闭交易页应解锁地图")
			slope._player.position = camp.position + Vector2(0, 100)
			await get_tree().process_frame
			slope._player.position = camp.position + Vector2(0, 30)
			await get_tree().process_frame
			_check(slope._trade_panel != null, "离开再靠近仍应能重开常驻交易点")
			if slope._trade_panel != null:
				slope._trade_panel.close()
	slope.queue_free()
	await get_tree().process_frame
	_check(G.reload_save() and String(G.economy_first_order().get("status", "")) == "done",
		"跨进程式重读档不能重领首单")
	var maple := await _enter_map("maple_road")
	var post := _entity(maple, "trade_maple_post")
	_check(post != null, "送盐支线完成后古道驿亭仍应保留独立交易实体")
	if post != null:
		maple._player.position = post.position + Vector2(0, 30)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(maple._trade_panel != null and maple._trade_panel.site_id == "maple_post",
			"古道驿亭靠近后应显示当地行情")
		if maple._trade_panel != null:
			maple._trade_panel.close()
	maple.queue_free()
	await get_tree().process_frame
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.act1_state()["side_quests"] = {"a1_trade_cart": {"status": "done"}}
	G.prog["mounts"] = {"owned": {"horse": 1}, "active": "horse", "riding": true}
	G.items["trade_salt"] = 2
	G.items["trade_iron"] = 1
	_check(G.mount_riding() and bool(G.economy_first_order_accept().get("ok", false)),
		"骑乘测试可接新运单")
	var base_payout := int(G.economy_first_order()["payout_gold"])
	slope = await _enter_map("broken_slope")
	var ride_bridge := _entity(slope, "first_order_ride_bridge")
	if ride_bridge != null: slope.on_quest_entity(ride_bridge)
	_check(bool(G.economy_first_order()["bridge_aided"]) and
		String(G.economy_first_order()["bridge_mode"]) == "ride" and
		int(G.economy_first_order()["payout_gold"]) == base_payout + 14,
		"骑乘牵引给另一种折让，步行始终可替代")
	slope.queue_free()
	await get_tree().process_frame
