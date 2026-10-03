extends Node

var _fails := 0

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_shipping.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.wallet["gold"] = 10000
	_check(G.shipping_order("salt_ship")["status"] == "locked", "交账前船单锁定")
	G.prog["story"] = {"step": "s17", "done": ["s12", "s13", "s14", "s15", "s16"], "goals": {}}
	var run := RunState.new()
	run.setup({"theme": "forest", "role_id": "zs", "level": 12, "seed": 511})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "shenyuan_port", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	map._city_content._built_action("shipping")
	_check(map._city_content._panel != null, "港务厅应打开船运面板")
	map._city_content._close_panel()
	map._city_content._open_dialog({"id": "npc_harbormaster"}, false)
	_check(map._city_content._panel != null, "交账后港务人应打开船运面板")
	map._city_content._close_panel()
	for id in ["salt_ship", "herb_ship"]:
		_check(not bool(G.shipping_accept(id, "city_market")["ok"]), "异地不能接单")
		_check(bool(G.shipping_accept(id, "shenyuan_market")["ok"]), "可以接取两条船单")
		var info := G.shipping_order(id)
		var original_payout := int(info["payout_gold"])
		var original_freight := int(info["freight_gold"])
		var aid_map := String(info["route_aid_map"])
		var aid_entity := String(info["route_aid_entity"])
		_check(G.shipping_aid_visible(id, aid_entity), "接单后地图路障可见")
		_check(not bool(G.shipping_route_aid(id, "shenyuan_port", aid_entity)["ok"]), "异地不能处理路障")
		var aid := G.shipping_route_aid(id, aid_map, aid_entity)
		_check(bool(aid.get("ok", false)), "实地排障可折让运费")
		info = G.shipping_order(id)
		var locked_payout := int(info["payout_gold"])
		_check(bool(info["aid_applied"]) and not G.shipping_aid_visible(id, aid_entity)
			and locked_payout == original_payout + int(info["route_aid_discount_gold"])
			and int(info["freight_gold"]) == original_freight - int(info["route_aid_discount_gold"]),
			"同一批船单的折让正确入账")
		_check(not bool(G.shipping_route_aid(id, aid_map, aid_entity)["ok"]), "路障不能重复领取折让")
		_check(G.reload_save() and bool(G.shipping_order(id)["aid_applied"]), "实地排障应持久化")
		var before_items := G.items.duplicate(true)
		_check(not bool(G.shipping_dispatch(id, "shenyuan_market")["ok"]) and G.items == before_items,
			"缺货装船不应扣物品")
		for gid in (info["cargo"] as Dictionary):
			var purchase := G.economy_trade(String(info["purchase_site"]), String(gid), "buy", int(info["cargo"][gid]))
			_check(bool(purchase.get("ok", false)), "实物现货采购应可备齐：" + String(gid))
		var gold_before := int(G.wallet["gold"])
		_check(bool(G.shipping_dispatch(id, "shenyuan_market")["ok"]), "备齐后装船")
		_check(int(G.wallet["gold"]) == gold_before and G.shipping_order(id)["status"] == "transit", "装船不提前发钱")
		for gid in (info["cargo"] as Dictionary):
			_check(G.item_count(String(gid)) == int(before_items.get(gid, 0)), "装船消耗对应实物")
		_check(not bool(G.shipping_dispatch(id, "shenyuan_market")["ok"]), "不能重复装船")
		_check(G.reload_save() and G.shipping_order(id)["status"] == "transit", "在途船单应持久化")
		G.economy_state()["port_event"] = "dredge"
		_check(int(G.shipping_order(id)["payout_gold"]) == locked_payout, "港口事件不能改已接报酬")
		_check(not bool(G.shipping_claim(id, "shenyuan_market")["ok"]), "未到港不发奖励")
		_check(bool(G.economy_rest("shenyuan_market").get("ok", false)), "歇脚推进到港日")
		_check(G.shipping_order(id)["status"] == "ready", "推进一天后到港")
		gold_before = int(G.wallet["gold"])
		_check(bool(G.shipping_claim(id, "shenyuan_market")["ok"]) and int(G.wallet["gold"]) == gold_before + locked_payout,
			"领取锁定的到手报酬")
		_check(not bool(G.shipping_claim(id, "shenyuan_market")["ok"]) and not bool(G.shipping_accept(id, "shenyuan_market")["ok"]),
			"重复领奖与本日重复接单均拦截")
		_check(G.reload_save() and G.shipping_order(id)["status"] == "done", "已领状态持久化")
		_check(bool(G.economy_rest("shenyuan_market").get("ok", false)), "次日重新开放船单")
		_check(bool(G.shipping_accept(id, "shenyuan_market")["ok"]) and int(G.shipping_order(id)["attempt"]) == 2,
			"新一日新事务可重复经营")
		G.economy_state()["day"] += 4
		_check(G.shipping_order(id)["status"] == "expired" and not bool(G.shipping_dispatch(id, "shenyuan_market")["ok"]),
			"超过备货期限不能装船")
		_check(bool(G.shipping_accept(id, "shenyuan_market")["ok"]) and int(G.shipping_order(id)["attempt"]) == 3, "过期可重接")
	var prog_before := G.prog.duplicate(true)
	var items_before := G.items.duplicate(true)
	var wallet_before := G.wallet.duplicate(true)
	G.save_locked = true
	_check(not bool(G.shipping_accept("salt_ship", "shenyuan_market")["ok"])
		and not bool(G.shipping_dispatch("salt_ship", "shenyuan_market")["ok"])
		and not bool(G.shipping_claim("salt_ship", "shenyuan_market")["ok"])
		and G.prog == prog_before and G.items == items_before and G.wallet == wallet_before, "存档锁定不改变交易")
	G.save_locked = false
	_check(G.save_game(), "可保存船运订单")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(G.SAVE_PATH))
	for field in ["attempt", "arrival_day", "payout_gold"]:
		var broken := saved.duplicate(true)
		broken["prog"]["economy"]["orders"]["salt_ship"][field] = -2
		if field == "arrival_day": broken["prog"]["economy"]["orders"]["salt_ship"]["status"] = "transit"
		_check(not bool(SaveData.validate(broken, int(Time.get_unix_time_from_system())).get("ok", true)), "非法船运数值拒绝导入：" + field)
	map.queue_free()
	await get_tree().process_frame
	print("SHIPPING_OK" if _fails == 0 else "SHIPPING_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
