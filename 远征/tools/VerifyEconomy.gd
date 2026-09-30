extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_economy.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "商路测试"
	G.wallet["gold"] = 2000
	_run()
	print("ECONOMY_OK" if _fails == 0 else "ECONOMY_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	var cfg := TableCache.economy_config()
	_check((cfg.get("goods", []) as Array).size() == 4 and
		(cfg.get("sites", []) as Array).size() == 4, "四货品、四交易点须入表")
	var maps: Dictionary = TableCache.main_world_config().get("maps", {})
	for site_v in cfg.get("sites", []):
		var site: Dictionary = site_v
		var map_id := String(site.get("map_id", ""))
		_check(maps.has(map_id), "交易点应在可进入地图：%s" % map_id)
		if site.has("entity_id"):
			_check(((maps[map_id] as Dictionary).get("entities", {}) as Dictionary).has(
				String(site["entity_id"])), "野外交易实体应常驻：%s" % String(site["entity_id"]))
	for site_v in cfg.get("sites", []):
		var site: Dictionary = site_v
		for good_v in cfg.get("goods", []):
			var good: Dictionary = good_v
			var q := G.economy_quote(String(site["id"]), String(good["id"]))
			_check(int(q.get("sell_gold", 0)) < int(q.get("buy_gold", 0)),
				"同点即买即卖不能刷钱：%s/%s" % [site["id"], good["id"]])
	# 120 游戏日 × 3 地点 × 4 货品：行情始终正价且本地往返严格亏损。
	var simulated := EconomyService.ensure({}, cfg)
	for day in range(1, 121):
		simulated["day"] = day
		for site_v in cfg.get("sites", []):
			for good_v in cfg.get("goods", []):
				var sid := String((site_v as Dictionary)["id"])
				var gid := String((good_v as Dictionary)["id"])
				var q := EconomyService.quote(cfg, simulated, sid, gid, "forge")
				_check(int(q.get("buy_gold", 0)) > int(q.get("sell_gold", 0))
					and int(q.get("sell_gold", 0)) >= 1,
					"120 日价格模拟不可出现零价或同城套利：%d/%s/%s" % [day, sid, gid])
	var initial_gold := int(G.wallet["gold"])
	var q0 := G.economy_quote("city_market", "trade_salt")
	var bought := G.economy_trade("city_market", "trade_salt", "buy", 2)
	_check(bool(bought.get("ok", false)) and G.item_count("trade_salt") == 2,
		"现货买入须扣金并入包")
	_check(int(G.wallet["gold"]) == initial_gold - 2 * int(q0["buy_gold"]),
		"买入价应与面板报价一致")
	var same_day := G.economy_quote("city_market", "trade_salt")
	_check(int(same_day["stock_left"]) == int(q0["stock_left"]) - 2,
		"库存应当日递减")
	var sold := G.economy_trade("city_market", "trade_salt", "sell", 1)
	_check(bool(sold.get("ok", false)) and int(G.wallet["gold"]) < initial_gold,
		"同点往返交易须亏损")
	var before_bad := JSON.stringify([G.wallet, G.items, G.prog])
	_check(not bool(G.economy_trade("city_market", "trade_iron", "buy", 20).get("ok", false)),
		"超库存或负重应拒绝")
	_check(not bool(G.economy_trade("city_market", "trade_iron", "sell", 1).get("ok", false)),
		"空包卖货应拒绝")
	_check(before_bad == JSON.stringify([G.wallet, G.items, G.prog]),
		"失败交易不能变更钱包、背包、日内计数")
	var day_one_quote := G.economy_quote("slope_camp", "trade_iron")
	_check(G.save_game(), "交易档须写盘")
	_check(G.reload_save(), "交易档须可重读")
	_check(int(G.economy_quote("slope_camp", "trade_iron")["buy_gold"]) ==
		int(day_one_quote["buy_gold"]), "同日读档报价应可复现")
	var rest := G.economy_rest("maple_post")
	_check(bool(rest.get("ok", false)) and int(G.economy_state()["day"]) == 2,
		"付费歇脚须推进游戏日")
	_check(int(G.economy_quote("city_market", "trade_salt")["stock_left"]) ==
		int(q0["stock_left"]), "跨日刷新库存")
	var capital := int(G.wallet["gold"])
	var city_buy := G.economy_trade("city_market", "trade_salt", "buy", 5)
	var camp_sell := G.economy_trade("slope_camp", "trade_salt", "sell", 5)
	_check(bool(city_buy.get("ok", false)) and bool(camp_sell.get("ok", false))
		and int(G.wallet["gold"]) > capital,
		"跨站点有货额限制的运盐应能产生正利润")
	_check(int(G.economy_quote("slope_camp", "trade_salt")["demand_left"]) == 1,
		"营地收购额度应随跨站点交货递减")
	var capped_wallet := int(G.wallet["gold"])
	_check(not bool(G.economy_trade("slope_camp", "trade_salt", "sell", 2).get("ok", false))
		and int(G.wallet["gold"]) == capped_wallet,
		"零成本切图不得绕过营地当日收购上限")
	for n in 6:
		_check(bool(G.economy_rest("maple_post").get("ok", false)), "歇脚写盘须成功")
	_check((G.economy_quote("city_market", "trade_salt")["history"] as Array).size() == 5,
		"只保存近五日行情")
	var before_work := int(G.wallet["gold"])
	_check(bool(G.economy_work("city_market", "carry").get("ok", false)) and
		int(G.wallet["gold"]) == before_work + 42, "稳定工作应按表发金币")
	_check(not bool(G.economy_work("city_market", "carry").get("ok", false)) and
		int(G.wallet["gold"]) == before_work + 42, "同日同一份工作不得重复领奖")
	_check(G.reload_save() and not bool(G.economy_work("city_market", "carry").get("ok", false)),
		"读档后仍不得重复工作领奖")
	var saved_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(G.SAVE_PATH))
	if saved_raw is Dictionary:
		var rolled: Dictionary = (saved_raw as Dictionary).duplicate(true)
		var ec: Dictionary = (rolled["prog"] as Dictionary)["economy"]
		(ec["work"] as Dictionary)["carry"] = int(ec["day"]) + 1
		_check(not bool(SaveData.validate(rolled, int(Time.get_unix_time_from_system())).get("ok", true)),
			"经济日回退到已做工作之前应被存档闸门拒绝")
	# 已有的送盐支线仍是订单前置，通关后才可接单。
	_check(String(G.economy_first_order().get("status", "")) == "locked",
		"未完成送盐不能接首单")
	var accepted_side := G.side_accept("a1_trade_cart")
	_check(bool(accepted_side.get("ok", false)), "送盐支线应可接取")
	var handed := G.side_entity_interact("deliver", "a1_postrider", "maple_road", "a1_trade_cart")
	_check(bool(handed.get("ok", false)), "原送盐玩法应能交付")
	var offer := G.economy_first_order()
	_check(String(offer.get("status", "")) == "available", "送盐完成后订单应可接")
	var accept := G.economy_first_order_accept()
	_check(bool(accept.get("ok", false)), "首单应可接取")
	var locked_payout := int(G.economy_first_order()["payout_gold"])
	G.act1_state()["repair_method"] = "forge"
	_check(int(G.economy_first_order()["payout_gold"]) == locked_payout,
		"修碑变动不能追溯更改已接单报酬")
	for n in 4:
		_check(bool(G.economy_rest("city_market").get("ok", false)), "过期测试应能推进游戏日")
	_check(String(G.economy_first_order().get("status", "")) == "expired",
		"超过截止日后订单应过期")
	_check(not bool(G.economy_first_order_deliver("slope_camp").get("ok", false)),
		"过期订单不能交付")
	var retry := G.economy_first_order_accept()
	_check(bool(retry.get("ok", false)) and int(retry.get("attempt", 0)) == 2,
		"过期后可重接，尝试次数须递增")
	locked_payout = int(G.economy_first_order()["payout_gold"])
	_check(not bool(G.economy_first_order_deliver("maple_post").get("ok", false)),
		"错误地点不能交货")
	_check(not bool(G.economy_first_order_deliver("slope_camp").get("ok", false)),
		"缺货不能交单")
	G.grant_item("trade_salt", 1, false)
	G.grant_item("trade_iron", 1, false)
	var before_gold := int(G.wallet["gold"])
	var delivery := G.economy_first_order_deliver("slope_camp")
	_check(bool(delivery.get("ok", false)) and int(G.wallet["gold"]) == before_gold + locked_payout,
		"交货应消耗实物并结算锁定报酬")
	_check(not bool(G.economy_first_order_deliver("slope_camp").get("ok", false)) and
		String(G.economy_first_order().get("status", "")) == "done",
		"已完成订单不能重复领奖")
	_check(G.reload_save() and String(G.economy_first_order().get("status", "")) == "done",
		"读档后仍不可重复交单")
