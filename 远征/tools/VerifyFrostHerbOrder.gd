extends Node

var _fails := 0

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_frost_herb.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.wallet["gold"] = 10000
	_check(String(G.frost_herb_order().get("status", "")) == "locked", "s28 前不能接霜关药单")
	G.prog["story"] = {"step": "s29", "done": ["s28"], "goals": {}}
	_check(G.save_game(), "隔离测试档可写")
	await _run()
	print("FROST_HERB_OK" if _fails == 0 else "FROST_HERB_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + message)

func _enter(map_id: String) -> MapScene:
	var run := RunState.new()
	run.setup({"theme": "desert", "role_id": "zs", "level": 35, "seed": 810})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": map_id, "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	if map._city_content != null: map._city_content._close_panel()
	return map

func _entity(map: MapScene, eid: String) -> Node2D:
	for ent in map._quest_entities:
		if is_instance_valid(ent) and ent.eid == eid and not ent.used: return ent
	return null

func _find_button(node: Node, wanted: String) -> Control:
	var needle := wanted.replace(" ", "")
	for child in node.get_children():
		if child is Label and needle in String(child.text).replace(" ", "") and node is Control:
			return node
		var found := _find_button(child, wanted)
		if found != null: return found
	return null

func _click(button: Control) -> void:
	_check(button != null, "合约按钮存在")
	if button == null: return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	button.gui_input.emit(event)

func _run() -> void:
	var port := TradePanel.new()
	add_child(port)
	port.open_site("shenyuan_market")
	_check(String(G.frost_herb_order()["status"]) == "available", "港口开放药单")
	var gold_before_accept := int(G.wallet["gold"])
	port._open_frost_contract()
	_check(port._contract_panel != null and
		_find_button(port._contract_panel, "保证金 40 金") != null,
		"签约前条款页列明保证金与损失")
	_check(_find_button(port._contract_panel, "保价签约 · 押 40") != null,
		"条款页同时提供保价与自担两档")
	_click(_find_button(port._contract_panel, "自担签约 · 押 40"))
	await get_tree().process_frame
	_check(String(G.frost_herb_order()["status"]) == "active" and
		int(G.wallet["gold"]) == gold_before_accept - 40 and
		int(G.frost_herb_order()["deposit_held_gold"]) == 40,
		"市集面板接单支付有上限的保证金")
	var info := G.frost_herb_order()
	var quick_payout := int(info["payout_gold"])
	_check(not bool(G.frost_herb_deliver("frost_market").get("ok", false)), "未过赤砂路口不能隔城交货")
	port.close()
	await get_tree().process_frame
	var road := await _enter("red_sand_route")
	_check(_entity(road, "frost_herb_quick_pass") != null and
		_entity(road, "frost_herb_safe_post") != null, "两条药箱路线在实际地图出现")
	var quick := _entity(road, "frost_herb_quick_pass")
	if quick != null: road.on_quest_entity(quick)
	_check(String(G.frost_herb_order()["route"]) == "", "未备货不能空手记录路口")
	_check(bool(G.economy_trade("shenyuan_market", "trade_herb", "buy", 3).get("ok", false))
		and bool(G.economy_trade("shenyuan_market", "trade_grain", "buy", 1).get("ok", false)),
		"港口实际现货能备齐药箱")
	if quick != null: road.on_quest_entity(quick)
	_check(String(G.frost_herb_order()["route"]) == "quick" and
		int(G.frost_herb_order()["payout_gold"]) == quick_payout, "近路保留锁定报酬")
	_check(not bool(G.frost_herb_route("red_sand_route", "frost_herb_safe_post").get("ok", false)),
		"同批不能两路叠加")
	_check(G.reload_save() and String(G.frost_herb_order()["route"]) == "quick", "路口选择可读档")
	road.queue_free()
	await get_tree().process_frame
	var frost := TradePanel.new()
	add_child(frost)
	frost.open_site("frost_market")
	var gold_before := int(G.wallet["gold"])
	frost._open_frost_contract()
	_click(_find_button(frost._contract_panel, "交货 · 退押金"))
	await get_tree().process_frame
	_check(String(G.frost_herb_order()["status"]) == "done" and
		int(G.wallet["gold"]) == gold_before + quick_payout + 40 and
		G.item_count("trade_herb") == 0 and G.item_count("trade_grain") == 0,
		"霜关实际面板扣实物、支付锁定报酬并退回保证金")
	var after := G.prog.duplicate(true)
	_check(not bool(G.frost_herb_deliver("frost_market").get("ok", false)) and
		not bool(G.frost_herb_accept("shenyuan_market").get("ok", false)) and G.prog == after,
		"同日不能重复领奖或重接")
	_check(G.reload_save() and String(G.frost_herb_order()["status"]) == "done", "交付读档后仍去重")
	frost.close()
	await get_tree().process_frame
	var post := await _enter("frost_post")
	if post._city_content != null:
		post._city_content._open_dialog({"id": "npc_frost_miner"}, false)
		var dialog_line: Label = post._city_content._dlg.get("line", null)
		_check(dialog_line != null and "药架终于有货" in dialog_line.text,
			"霜关矿工对白反馈药箱到达")
	post.queue_free()
	await get_tree().process_frame
	_check(bool(G.economy_rest("frost_market").get("ok", false)), "歇脚推进一游戏日")
	var base_offer := int(G.frost_herb_order()["payout_gold"])
	port = TradePanel.new()
	add_child(port)
	port.open_site("shenyuan_market")
	port._open_frost_contract()
	_click(_find_button(port._contract_panel, "保价签约 · 押 40"))
	await get_tree().process_frame
	_check(String(G.frost_herb_order()["protection"]) == "insured" and
		int(G.frost_herb_order()["payout_gold"]) == base_offer - 12,
		"保价档少 12 金报酬且写入本批合同")
	port.close()
	_check(bool(G.economy_trade("shenyuan_market", "trade_herb", "buy", 3).get("ok", false))
		and bool(G.economy_trade("shenyuan_market", "trade_grain", "buy", 1).get("ok", false)),
		"第二批能再次备货")
	info = G.frost_herb_order()
	_check(bool(G.frost_herb_route("red_sand_route", "frost_herb_safe_post").get("ok", false)) and
		String(G.frost_herb_order()["route"]) == "safe" and
		int(G.frost_herb_order()["payout_gold"]) == int(info["payout_gold"]) - 18,
		"旧驿绕路多付运费且第二批独立入账")
	_check(bool(G.frost_herb_deliver("frost_market").get("ok", false)), "绕路仍能正常交付")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(G.SAVE_PATH))
	var broken := saved.duplicate(true)
	broken["prog"]["economy"]["orders"]["frost_herb_supply"]["route"] = "teleport"
	_check(not bool(SaveData.validate(broken, int(Time.get_unix_time_from_system())).get("ok", true)),
		"非法路线不能从存档导入")
	_check(bool(G.economy_rest("frost_market").get("ok", false)) and
		bool(G.frost_herb_accept("shenyuan_market").get("ok", false)), "第三批可接")
	G.economy_state()["day"] += 5
	_check(String(G.frost_herb_order()["status"]) == "expired" and
		not bool(G.frost_herb_deliver("frost_market").get("ok", false)) and
		not bool(G.frost_herb_accept("shenyuan_market").get("ok", false)),
		"过期药单不能直接结算或抹掉保证金重接")
	var before_extend := int(G.wallet["gold"])
	frost = TradePanel.new()
	add_child(frost)
	frost.open_site("frost_market")
	frost._open_frost_contract()
	_click(_find_button(frost._contract_panel, "延期 · 付 12 金"))
	await get_tree().process_frame
	_check(
		String(G.frost_herb_order()["status"]) == "active" and
		bool(G.frost_herb_order()["extended"]) and
		int(G.wallet["gold"]) == before_extend - 12,
		"过期可付费延期一次")
	_check(G.reload_save() and bool(G.frost_herb_order()["extended"]), "延期写档后仍只能一次")
	G.economy_state()["day"] += 3
	_check(String(G.frost_herb_order()["status"]) == "expired" and
		not bool(G.frost_herb_extend("frost_market").get("ok", false)),
		"第二次过期不得再次延期")
	var before_abandon := int(G.wallet["gold"])
	frost._open_frost_contract()
	_click(_find_button(frost._contract_panel, "退单 · 退 30 金"))
	_check(String(G.frost_herb_order()["status"]) == "expired" and
		int(G.wallet["gold"]) == before_abandon, "退单首次点击只展示确认，不扣账")
	_click(_find_button(frost._contract_panel, "确认退单"))
	await get_tree().process_frame
	_check(
		String(G.frost_herb_order()["status"]) == "abandoned" and
		int(G.wallet["gold"]) == before_abandon + 30,
		"退单返还 75% 保证金，已缴延期费不返")
	var abandoned := G.prog.duplicate(true)
	_check(not bool(G.frost_herb_abandon("frost_market").get("ok", false)) and
		not bool(G.frost_herb_accept("shenyuan_market").get("ok", false)) and
		G.prog == abandoned, "退单不可重复退款或同日重接")
	_check(G.reload_save() and String(G.frost_herb_order()["status"]) == "abandoned",
		"退单读档后仍闭合")
	_check(bool(G.economy_rest("frost_market").get("ok", false)) and
		bool(G.frost_herb_accept("shenyuan_market").get("ok", false)),
		"次日可重新签新合同")
	var locked_prog := G.prog.duplicate(true)
	var locked_wallet := G.wallet.duplicate(true)
	G.save_locked = true
	_check(not bool(G.frost_herb_abandon("frost_market").get("ok", false)) and
		not bool(G.frost_herb_extend("frost_market").get("ok", false)) and
		not bool(G.frost_herb_deliver("frost_market").get("ok", false)) and
		G.prog == locked_prog and G.wallet == locked_wallet,
		"存档锁定时合约动作零副作用")
	G.save_locked = false
	var old_record: Dictionary = (G.economy_state()["orders"] as Dictionary)["frost_herb_supply"]
	old_record.erase("deposit_gold")
	old_record.erase("extended")
	_check(G.save_game() and G.reload_save() and int(G.frost_herb_order()["deposit_held_gold"]) == 0,
		"升级前已接药单缺少保证金字段仍可读档")
	var old_gold := int(G.wallet["gold"])
	_check(bool(G.frost_herb_abandon("frost_market").get("ok", false)) and
		int(G.wallet["gold"]) == old_gold,
		"旧单未缴过保证金时退单不能凭空退款")
	_check(bool(G.economy_rest("frost_market").get("ok", false)), "旧单退毕后可推进游戏日")
	var insured_start := int(G.wallet["gold"])
	_check(bool(G.frost_herb_accept("shenyuan_market", true).get("ok", false)) and
		int(G.wallet["gold"]) == insured_start - 40,
		"保价单同样实付 40 金保证金")
	_check(bool(G.frost_herb_abandon("frost_market").get("ok", false)) and
		int(G.wallet["gold"]) == insured_start,
		"保价单主动退单返还全部保证金，不产生套利")
	_check(bool(G.economy_rest("frost_market").get("ok", false)) and
		bool(G.frost_herb_accept("shenyuan_market", true).get("ok", false)),
		"次日可以再签保价单")
	var auto_start := int(G.wallet["gold"])
	var auto_count := 0
	for i in 7:
		var rest := G.economy_rest("frost_market")
		_check(bool(rest.get("ok", false)), "歇脚推进合约日 %d" % i)
		if bool(rest.get("auto_settled", false)):
			auto_count += 1
			_check(int(rest.get("contract_refund_gold", 0)) == 40,
				"保价单超宽限期自动退还全部保证金")
	_check(auto_count == 1 and String(G.frost_herb_order()["status"]) == "settled" and
		int(G.wallet["gold"]) == auto_start - 7 * 22 + 40,
		"长期逾期只自动结算一次且损失受上限约束")
	_check(G.reload_save() and String(G.frost_herb_order()["status"]) == "settled" and
		not bool(G.frost_herb_abandon("frost_market").get("ok", false)),
		"自动结算读档后不可再退保证金")
	frost.close()
