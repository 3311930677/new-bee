extends Node

const MountVisual := preload("res://src/world/MountVisual.gd")

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_story.json"
	G._init_state_defaults()
	G.save_locked = false
	G.ensure_starter_buildings()
	G.selected_role = "zs"
	G.player_name = "行路人"
	G.prog["level"] = 1
	G.prog["exp"] = 0
	G.prog["story"] = {"step": "s01", "done": []}
	G.items.erase("stele_fragment")
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	_run()
	print("STORY_OK" if _fails == 0 else "STORY_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	var maps: Dictionary = TableCache.main_world_config().get("maps", {})
	_check(maps.size() >= 4, "首章应有边城、古道、断碑坡和碑窟")
	for mid in maps:
		var cfg: Dictionary = maps[mid]
		for exit_v in cfg.get("exits", []):
			var route: Dictionary = exit_v
			var dest := String(route.get("to", ""))
			_check(maps.has(dest), "%s 的出口不应指向空地图" % mid)
			if maps.has(dest):
				var arrivals: Dictionary = (maps[dest] as Dictionary).get("spawn_points", {})
				_check(arrivals.has(String(route.get("arrival", ""))),
					"%s → %s 应有独立到达点" % [mid, dest])
				var has_return := false
				for back_v in (maps[dest] as Dictionary).get("exits", []):
					if String((back_v as Dictionary).get("to", "")) == mid:
						has_return = true
				_check(has_return, "%s → %s 应有返回道路" % [mid, dest])
	var rows: Array = TableCache.story_quests_config().get("steps", [])
	_check(rows.size() == 32 and String((rows[11] as Dictionary).get("id", "")) == "s12"
		and String((rows[19] as Dictionary).get("id", "")) == "s20",
		"前三幕二十八步保留，第四幕前半四步接续")
	for row_v in rows:
		var step: Dictionary = row_v
		var map_id := String(step.get("map", ""))
		_check(maps.has(map_id), "主线目标必须指向存在的地区：%s" % map_id)
		var kind := String(step.get("event", ""))
		var target := String(step.get("target", ""))
		if kind == "talk" or kind == "craft":
			var npc_exists := false
			for npc_v in TableCache.city_config_for(map_id).get("npcs", []):
				if String((npc_v as Dictionary).get("id", "")) == target:
					npc_exists = true
			_check(npc_exists, "主线对话目标必须是城内常驻 NPC：%s" % target)
		elif kind == "defeat":
			_check(target == "*" or (maps[map_id]["monster_ids"] as Array).has(target),
				"主线讨伐目标必须在对应地区刷新")
	var cavern: Dictionary = maps.get("stele_cavern", {})
	_check(String(cavern.get("node_type", "")) == "boss"
		and String(cavern.get("boss_id", "")) == "mon_stele_warden",
		"碑窟应由独立首领守护")
	var slope: Dictionary = maps.get("broken_slope", {})
	var cavern_gate: Dictionary = {}
	for route_v in slope.get("exits", []):
		var route: Dictionary = route_v
		if String(route.get("to", "")) == "stele_cavern":
			cavern_gate = route
	_check(String(cavern_gate.get("requires_story", "")) == "s08",
		"碑窟入口应在查到旧卷后开放")
	_check(not G.story_step_done("s08"), "新档不能预先开放碑窟")
	_check(G.story_current().get("id", "") == "s01", "新档从第一步开始")
	_check(G.story_event("visit", "maple_road", "maple_road").is_empty(),
		"未接事前不能跳过第一步")
	var events := [
		["talk", "npc_steward", "lorin_wilds"],
		["visit", "maple_road", "maple_road"],
		["defeat", "mon_wolf", "maple_road"],
		["talk", "npc_smith", "lorin_wilds"],
		["visit", "broken_slope", "broken_slope"],
		["defeat", "mon_treant", "broken_slope"],
		["talk", "npc_steward", "lorin_wilds"],
		["talk", "npc_scribe", "lorin_wilds"],
		["visit", "stele_cavern", "stele_cavern"],
		["defeat", "mon_stele_warden", "stele_cavern"],
		["craft", "npc_smith", "lorin_wilds"],
		["talk", "npc_steward", "lorin_wilds"],
	]
	for i in events.size():
		var event: Array = events[i]
		var refine_before_step := G.item_count("refine_stone")
		if i == 10:
			G.grant_item("refine_stone", 2, false)
			_check(G.story_event("talk", "npc_smith", "lorin_wilds").is_empty()
				and G.story_event("craft", "npc_smith", "lorin_wilds").is_empty(),
				"s11 对话与未选方案不能自动完成修碑")
		var before := int(G.wallet.get("gold", 0))
		var payload := {"method": "forge"} if i == 10 else {}
		var result := G.story_event(event[0], event[1], event[2], true, payload)
		_check(String(result.get("id", "")) == "s%02d" % [i + 1],
			"第 %d 步应由对应场景事件推进" % [i + 1])
		_check(int(G.wallet.get("gold", 0)) > before, "主线应发放金币")
		_check(G.story_event(event[0], event[1], event[2], true, payload).is_empty(),
			"同一事件不能重复结算")
		if i == 7:
			_check(G.story_step_done("s08"), "旧卷完成后应开放碑窟")
		if i == 9:
			_check(G.item_count("stele_fragment") == 1, "击败碑灵应取得失声碑文")
		if i == 10:
			_check(G.item_count("stele_fragment") == 0, "铁匠修复碑文应消耗任务物")
			_check(G.item_count("refine_stone") == refine_before_step
				and String((G.prog["story"]["choices"] as Dictionary).get("s11", "")) == "forge"
				and bool((G.prog.get("flags", {}) as Dictionary).get("act1_stele_repaired", false)),
				"修碑锻合应扣两块精炼石、记选择和世界旗")
	_check(String(G.story_current().get("id", "")) == "s13", "第一幕复命后应接第二幕")
	_check((G.prog["story"]["done"] as Array).size() == 12, "完成步骤应写档")
	_check(int(G.wallet.get("expedition", 0)) == 0 and int(G.wallet.get("soul", 0)) == 0
		and int(G.wallet.get("honor", 0)) == 0, "主线不能增发玩法专用货币")
	_check(FileAccess.file_exists(G.SAVE_PATH), "主线进度应落盘")
	_check(G.reload_save(), "主线存档应可重读")
	_check(String(G.story_current().get("id", "")) == "s13" and (G.prog["story"]["done"] as Array).size() == 12,
		"重读后不可重复领奖")
	var s11_state := {"step": "s11", "done": []}
	var s11_rows: Array = TableCache.story_quests_config().get("steps", [])
	var scribe_event := QuestService.world_event("craft", "npc_smith", "lorin_wilds",
		"player", {"method": "scribe"})
	var scribe_plan := QuestService.plan(s11_state, s11_rows, scribe_event,
		{"stele_fragment": 1})
	_check(bool(scribe_plan.get("ok", false))
		and int((scribe_plan.get("extra_costs", {}) as Dictionary).get("gold", 0)) == 120
		and String(scribe_plan.get("choice", "")) == "scribe", "金币拓录方案应可规划且费用为 120")
	var no_frag := QuestService.plan(s11_state, s11_rows, scribe_event, {})
	_check(not bool(no_frag.get("ok", false)) and String(no_frag.get("reason", "")) == "missing_item",
		"缺碑文碎片不能完成任一修碑方案")
	var saved_prog := G.prog.duplicate(true)
	var saved_wallet := G.wallet.duplicate(true)
	var saved_items := G.items.duplicate(true)
	G.prog["story"] = {"step": "s11", "done": [], "goals": {}}
	# 后续为独立合成进度 fixture，不能沿用前一个故事链的经验版本标记。
	G.prog.erase("campaign_growth")
	G.prog["ledger"] = {"applied": []}
	G.wallet["gold"] = 200
	G.items["stele_fragment"] = 1
	var scribe_result := G.story_event("craft", "npc_smith", "lorin_wilds", false,
		{"method": "scribe"})
	_check(String(scribe_result.get("id", "")) == "s11"
		and int(G.wallet.get("gold", 0)) == 180 and G.item_count("stele_fragment") == 0
		and String((G.prog.get("act1", {}) as Dictionary).get("repair_method", "")) == "scribe",
		"拓录方案应实扣 120 金、发 100 金并记录选择")
	G.prog = saved_prog
	G.wallet = saved_wallet
	G.items = saved_items
	var sim := BattleSim.new()
	sim.setup(12, {"role_id": "zs", "level": 9}, {"theme": "tomb", "node_type": "boss",
		"lead_mon": "mon_stele_warden", "solo": true, "display_level": 12})
	_check(sim.alive_units("enemy").size() == 1 and sim.alive_units("enemy")[0].data.get("id", "") == "mon_stele_warden",
		"碑窟首领接触战应只有接触的那只怪")

	# ---------- P05-B：第一幕支线（新增断言并入本用例，不新增用例数） ----------
	var side_rows: Array = []
	for side_row in (TableCache.side_quests_config().get("quests", []) as Array):
		if String((side_row as Dictionary).get("id", "")).begins_with("a1_"):
			side_rows.append(side_row)
	_check(side_rows.size() == 6, "第一幕应配置六条支线")
	var live_count := 0
	for row_v in side_rows:
		var row: Dictionary = row_v
		_check(not String(row.get("title", "")).is_empty()
			and not String(row.get("clue", "")).is_empty()
			and row.get("objective") is Dictionary, "支线应配齐 title／clue／objective")
		if bool(row.get("live", true)):
			live_count += 1
		var giver_ok := false
		for npc_v in G.city_npcs():
			if String((npc_v as Dictionary).get("id", "")) == String(row.get("giver", "")):
				giver_ok = true
		_check(giver_ok, "支线发布者必须是城内常驻 NPC：%s" % row.get("giver", ""))
		var qmap := String(row.get("map", ""))
		_check(maps.has(qmap), "支线目标地图必须存在：%s" % qmap)
		var obj: Dictionary = row.get("objective", {})
		var turn_in := String(row.get("turn_in", ""))
		var turn_ok := false
		for npc_v2 in G.city_npcs():
			if String((npc_v2 as Dictionary).get("id", "")) == turn_in:
				turn_ok = true
		for mid_v in maps:
			var map_ents: Dictionary = (maps[mid_v] as Dictionary).get("entities", {})
			if map_ents.has(turn_in):
				turn_ok = true
		_check(turn_ok, "支线交付人必须是城内 NPC 或已声明的地图实体：%s" % turn_in)
		var targets: Variant = obj.get("target_entities", [])
		if targets is Array and not (targets as Array).is_empty():
			var ents: Dictionary = (maps[qmap] as Dictionary).get("entities", {})
			for eid_v in targets:
				_check(ents.has(String(eid_v)), "支线目标实体必须在该图声明：%s" % eid_v)
			_check(int(obj.get("count", 1)) == (targets as Array).size(),
				"支线计数应与目标实体数一致：%s" % row.get("id", ""))
		var one := String(obj.get("target_entity", ""))
		if not one.is_empty():
			var ents1: Dictionary = (maps[qmap] as Dictionary).get("entities", {})
			_check(ents1.has(one), "支线单体目标必须在该图声明：%s" % one)
	_check(live_count == 6, "P05-C 开首领线后六条支线全部可玩")
	_check(not bool(G.side_entity_interact("collect", "a1_chime", "maple_road", "a1_rel_child").get("ok", false)),
		"接取前的目标事件不得计数")
	_check(G.side_status_of("a1_elite_beast") == "", "未接取的首领支线不应有状态")
	var acc_child := G.side_accept("a1_rel_child")
	_check(bool(acc_child.get("ok", false)) and G.side_tracked() == "a1_rel_child",
		"接取后应自动追踪，且同一时间只追踪一条")
	_check(not bool(G.side_accept("a1_rel_child").get("ok", false)), "同一条支线不能重复接取")
	_check(bool(G.side_accept("a1_eco_roots").get("ok", false))
		and G.side_tracked() == "a1_rel_child", "已有追踪时接第二条不得改追踪")
	_check(G.side_track("a1_eco_roots") and G.side_track("a1_rel_child"),
		"追踪应能在已接支线间切换")
	_check(not bool(G.side_entity_interact("collect", "a1_chime", "broken_slope", "a1_rel_child").get("ok", false)),
		"跨地图的采集事件不得计入古道支线")
	var chime := G.side_entity_interact("collect", "a1_chime", "maple_road", "a1_rel_child")
	_check(bool(chime.get("ok", false)) and G.side_status_of("a1_rel_child") == QuestService.SIDE_READY
		and G.item_count("wind_chime") == 1, "采到风铃应获得任务物并转可交付")
	_check(not bool(G.side_entity_interact("collect", "a1_chime", "maple_road", "a1_rel_child").get("ok", false)),
		"同一实体不得重复计数或重复发物")
	_check(bool(G.side_accept("a1_rel_guard").get("ok", false)), "讨伐支线应可接取")
	var r1 := G.side_report("defeat", "mon_wolf", "maple_road")
	var r2 := G.side_report("defeat", "mon_wolf", "maple_road")
	_check(r1.has("a1_rel_guard") and r2.has("a1_rel_guard")
		and G.side_status_of("a1_rel_guard") == QuestService.SIDE_READY, "击退两只敌影应达成讨伐支线")
	_check(G.side_report("defeat", "mon_wolf", "maple_road").is_empty(), "可交付后继续讨伐不应再计数")
	var gold_before_child := int(G.wallet.get("gold", 0))
	var done_child := G.side_npc_interact("npc_child")
	_check(String(done_child.get("kind", "")) == "turn_in"
		and G.side_status_of("a1_rel_child") == QuestService.SIDE_DONE
		and G.item_count("wind_chime") == 0
		and int(G.wallet.get("gold", 0)) == gold_before_child + 70
		and (G.act1_state()["discoveries"] as Array).has("chime_story")
		and G.side_tracked() == "", "交付风铃应扣物、发奖、记线索并清追踪")
	_check(G.side_npc_interact("npc_child").is_empty(), "已交付的支线不得二次结算")
	_check((G.ledger().get("applied", []) as Array).has(
		RewardLedger.tx_id("side", "a1_rel_child", "complete")),
		"支线完成应走固定交易 ID side|<id>|complete")
	var pure := {}
	QuestService.side_accept(pure, side_rows, "a1_trade_cart")
	var deliver_ev := QuestService.world_event("deliver", "a1_postrider", "maple_road")
	_check(QuestService.side_report(pure, side_rows, deliver_ev, {}).is_empty(),
		"未持盐包不能完成送达")
	_check(QuestService.side_report(pure, side_rows, deliver_ev, {"salt_pack": 1}).has("a1_trade_cart"),
		"持盐包送达应推进目标")
	var prior_repair_method: Variant = G.act1_state().get("repair_method", null)
	G.act1_state().erase("repair_method")
	var route_before := G.first_order_preview()
	_check(not bool(route_before.get("unlocked", true))
		and String(route_before.get("route_state", "")) == "blocked",
		"未完成送盐前不能看见已开通的商路报价")
	var acc_cart := G.side_accept("a1_trade_cart")
	_check(bool(acc_cart.get("ok", false)) and G.item_count("salt_pack") == 1,
		"接取送达支线应随身带盐包")
	var gold_before_cart := int(G.wallet.get("gold", 0))
	var drop := G.side_entity_interact("deliver", "a1_postrider", "maple_road", "a1_trade_cart")
	_check(bool(drop.get("ok", false)) and G.side_status_of("a1_trade_cart") == QuestService.SIDE_DONE
		and G.item_count("salt_pack") == 0
		and int(G.wallet.get("gold", 0)) == gold_before_cart + 140
		and (G.act1_state()["discoveries"] as Array).has("order_preview"),
		"驿亭实体送达应当场成交、扣盐包发奖记线索")
	_check(not bool(G.side_entity_interact("deliver", "a1_postrider", "maple_road", "a1_trade_cart").get("ok", false)),
		"同一送达不得二次成交")
	var route_open := G.first_order_preview()
	_check(bool(route_open.get("unlocked", false))
		and String(route_open.get("route_state", "")) == "open"
		and int(route_open.get("quote_gold", 0)) == 90,
		"送盐后应由驿商开放首条运路的只读报价：%s" % JSON.stringify(route_open))
	G.act1_state()["repair_method"] = "forge"
	var route_forge := G.first_order_preview()
	G.act1_state()["repair_method"] = "scribe"
	var route_scribe := G.first_order_preview()
	if prior_repair_method == null:
		G.act1_state().erase("repair_method")
	else:
		G.act1_state()["repair_method"] = prior_repair_method
	_check(int(route_forge.get("quote_gold", 0)) == 78
		and int(route_scribe.get("quote_gold", 0)) == 84
		and String(route_forge.get("route_state", "")) == "repaired",
		"首订单预览价格须随修碑方式变化，且不写第二份状态")
	var roots_a := G.side_entity_interact("collect", "a1_roots_a", "maple_road", "a1_eco_roots")
	var roots_b := G.side_entity_interact("collect", "a1_roots_b", "maple_road", "a1_eco_roots")
	_check(bool(roots_a.get("ok", false)) and bool(roots_b.get("ok", false))
		and G.side_status_of("a1_eco_roots") == QuestService.SIDE_READY,
		"两丛草根各采一次应达成采集支线")
	var stone_before_roots := G.item_count("enhance_stone")
	var gold_before_roots := int(G.wallet.get("gold", 0))
	var done_roots := G.side_npc_interact("npc_scribe")
	_check(String(done_roots.get("kind", "")) == "turn_in"
		and int(G.wallet.get("gold", 0)) == gold_before_roots + 90
		and G.item_count("enhance_stone") == stone_before_roots + 2,
		"草根交付应发金币与强化石（口径调整：原药草改为现有材料）")
	var stone_before_guard := G.item_count("enhance_stone")
	var gold_before_guard := int(G.wallet.get("gold", 0))
	var done_guard := G.side_npc_interact("npc_guard")
	_check(String(done_guard.get("kind", "")) == "turn_in"
		and int(G.wallet.get("gold", 0)) == gold_before_guard + 100
		and G.item_count("enhance_stone") == stone_before_guard + 1,
		"讨伐交付应发金币与强化石（口径调整：原药剂为局内资源）")
	_check(not G.side_entity_visible("a1_tracks_a", "a1_eco_tracks"), "未接取时足迹实体不应生成")
	var acc_tracks := G.side_accept("a1_eco_tracks")
	_check(bool(acc_tracks.get("ok", false)) and G.side_tracked() == "a1_eco_tracks",
		"接取足迹支线应自动追踪")
	_check(G.side_entity_visible("a1_tracks_a", "a1_eco_tracks")
		and G.side_entity_visible("a1_tracks_b", "a1_eco_tracks"), "接取后两处足迹都应生成")
	var obs := G.side_entity_interact("observe", "a1_tracks_a", "broken_slope", "a1_eco_tracks")
	_check(bool(obs.get("ok", false)) and not G.side_entity_visible("a1_tracks_a", "a1_eco_tracks"),
		"观察过的足迹不应再生成（跨读档一致）")
	_check(G.save_game() and G.reload_save(), "支线状态应可落盘重读")
	_check(G.side_tracked() == "a1_eco_tracks"
		and G.side_status_of("a1_eco_tracks") == QuestService.SIDE_ACTIVE
		and G.side_entity_visible("a1_tracks_b", "a1_eco_tracks")
		and not G.side_entity_visible("a1_tracks_a", "a1_eco_tracks"),
		"重读后追踪、进度与已采实体应保持")
	var ws_state := {}
	_check(not WorldSession.entity_taken(ws_state, "a1_chime"), "未标记实体不应视为已取")
	_check(WorldSession.mark_entity_taken(ws_state, "a1_chime", true)
		and WorldSession.entity_taken(ws_state, "a1_chime"), "once 标记应永久有效")
	_check(not WorldSession.mark_entity_taken(ws_state, "a1_chime", true), "重复标记不应再次变更")
	var ws_day := {}
	WorldSession.mark_entity_taken(ws_day, "a1_roots_a", false, "2026-01-01")
	_check(WorldSession.entity_taken(ws_day, "a1_roots_a", "2026-01-01")
		and not WorldSession.entity_taken(ws_day, "a1_roots_a", "2026-01-02"),
		"日期标记应只在当天有效、次日恢复")
	_check(int(G.wallet.get("expedition", 0)) == 0 and int(G.wallet.get("soul", 0)) == 0
		and int(G.wallet.get("honor", 0)) == 0, "支线奖励不得增发玩法专用货币")

	# ---------- P05-C：可选首领「失路兽」+ 首领支线（断言并入本用例，不新增用例数） ----------
	var slope_cfg: Dictionary = maps.get("broken_slope", {})
	var opt_v: Variant = slope_cfg.get("optional_bosses", [])
	var opt_row: Dictionary = {}
	if opt_v is Array and not (opt_v as Array).is_empty():
		opt_row = (opt_v as Array)[0] as Dictionary
	_check(String(opt_row.get("id", "")) == "lost_beast"
		and String(opt_row.get("mon_id", "")) == "mon_lost_beast"
		and int(opt_row.get("level_offset", 0)) == 3
		and int(opt_row.get("respawn_seconds", 0)) == 600,
		"断碑坡路西应配失路兽：等级 +3、十分钟重刷")
	_check(not (slope_cfg.get("monster_ids", []) as Array).has("mon_lost_beast"),
		"可选首领不得混进普通怪随机池")
	# 素材（P05-C）：本体与召唤影狼的立绘都要真的落盘——sprite / monster_sprite_paths
	# 只是路径字符串，打不到文件时进游戏就是白块，归进本用例一次看住。
	var sprite_paths_v: Variant = slope_cfg.get("monster_sprite_paths", {})
	var sprite_paths: Dictionary = sprite_paths_v if sprite_paths_v is Dictionary else {}
	_check(ResourceLoader.exists(String(opt_row.get("sprite", "")))
		and ResourceLoader.exists(String(sprite_paths.get("mon_shadow_wolf", ""))),
		"失路兽与影狼立绘应存在（image/main_world/mon_lost_beast.png、mon_shadow_wolf.png）")
	var beast: Dictionary = TableCache.get_monster("mon_lost_beast")
	_check(String(beast.get("tier", "")) == "boss"
		and int((beast.get("base", {}) as Dictionary).get("hp", 0)) == 240,
		"失路兽应是 240 血的首领档怪物")
	var sniff: Dictionary = {}
	var roar: Dictionary = {}
	for sk_v in beast.get("skills", []):
		if String((sk_v as Dictionary).get("id", "")) == "boss_sniff":
			sniff = sk_v as Dictionary
	for ph_v in beast.get("phases", []):
		if String((ph_v as Dictionary).get("id", "")) == "roar":
			roar = ph_v as Dictionary
	_check(not sniff.is_empty() and is_equal_approx(float(sniff.get("windup", 0.0)), 2.0),
		"嗅踪应带 2 秒表驱动前摇（表现层画预兆环）")
	_check(not roar.is_empty() and is_equal_approx(float(roar.get("hp_below", 0.0)), 0.5),
		"失路兽半血应进入迷路低吼阶段")
	var od: Dictionary = {}
	if roar.get("on_death") is Dictionary:
		od = roar.get("on_death") as Dictionary
	var od_buff: Dictionary = {}
	if od.get("self_buff") is Dictionary:
		od_buff = od.get("self_buff") as Dictionary
	_check(String(od.get("mon_id", "")) == "mon_shadow_wolf"
		and String(od_buff.get("type", "")) == "break_window"
		and is_equal_approx(float(od_buff.get("dur", 0.0)), 4.0),
		"迷路低吼召出的影狼先死应给失路兽 4 秒破绽")
	var fk_cfg: Dictionary = {}
	if opt_row.get("first_kill") is Dictionary:
		fk_cfg = opt_row.get("first_kill") as Dictionary
	_check(String(fk_cfg.get("flag", "")) == "act1_lost_beast_down"
		and String(fk_cfg.get("discovery", "")) == "mon_lost_beast",
		"首胜应记世界旗 act1_lost_beast_down 与图鉴条目")
	var eq_rows: Dictionary = {}
	if fk_cfg.get("equips") is Dictionary:
		eq_rows = fk_cfg.get("equips") as Dictionary
	var eq_ok := eq_rows.size() == 4
	for rid in ["zs", "ck", "fs", "fz"]:
		var pick: Variant = eq_rows.get(rid, {})
		if not (pick is Dictionary) or int((pick as Dictionary).get("rarity", 0)) != 3 \
			or G.equip_tpl(String((pick as Dictionary).get("tpl", ""))).is_empty():
			eq_ok = false
	_check(eq_ok, "首胜应给四个职业各配一件真实存在的蓝装（rarity 3）")

	# 战斗内核：单挑接触 → 半血阶段 → 召唤影狼 → 影狼先死给破绽（一条阶段钩子只响一次）
	var beast_sim := BattleSim.new()
	beast_sim.setup(23, {"role_id": "zs", "level": 12}, {"theme": "forest", "node_type": "boss",
		"lead_mon": "mon_lost_beast", "solo": true, "display_level": 15})
	_check(beast_sim.alive_units("enemy").size() == 1
		and String(beast_sim.alive_units("enemy")[0].data.get("id", "")) == "mon_lost_beast",
		"断碑坡接触战应只与失路兽本体交战")
	var beast_u: Combatant = beast_sim.alive_units("enemy")[0]
	var probe_sim := BattleSim.new()
	probe_sim.setup(24, {"role_id": "zs", "level": 12}, {"theme": "forest", "node_type": "boss",
		"lead_mon": "mon_lost_beast", "solo": true, "display_level": 15})
	SkillSystem.enqueue_cast(probe_sim, probe_sim.alive_units("enemy")[0], sniff)
	_check(probe_sim.cast_queue.size() == 1
		and int(probe_sim.cast_queue[0].get("windup", 0)) == 60,
		"2 秒前摇应入队 60 tick（预兆环与倒计时同源）")
	beast_u.hp = int(float(beast_u.get_max_hp()) * 0.4)
	beast_sim._apply_phases()
	var summon_def: Dictionary = {}
	for s_v in beast_u.skills:
		if String((s_v as Dictionary).get("id", "")) == "boss_roar_summon":
			summon_def = (s_v as Dictionary).get("def", {})
	_check(beast_u.once_flags.has("phase_roar") and beast_u.skills.size() == 2
		and not summon_def.is_empty(), "半血阶段应解锁迷路低吼（只解锁一次）")
	beast_sim.events.clear()
	SkillSystem.resolve_cast(beast_sim, {"uid": beast_u.uid, "skill": summon_def})
	var wolf: Combatant = null
	for u_v in beast_sim.alive_units("enemy"):
		if String(u_v.data.get("id", "")) == "mon_shadow_wolf":
			wolf = u_v
	_check(beast_sim.alive_units("enemy").size() == 2 and wolf != null,
		"迷路低吼应召出一头表驱动的影狼")
	if wolf != null:
		wolf.take_damage(99999, beast_u, beast_sim)
	var break_buff: Dictionary = beast_u.get_buff("break_window")
	_check(wolf != null and not wolf.alive and not break_buff.is_empty()
		and int(break_buff.get("dur", 0)) == 120
		and is_equal_approx(float((break_buff.get("val", {}) as Dictionary).get("pct", 0.0)), 0.35),
		"影狼先死应给失路兽 4 秒 ×1.35 破绽")
	var break_events := 0
	for e_v in beast_sim.events:
		if String((e_v as Dictionary).get("t", "")) == "phase" \
			and String((e_v as Dictionary).get("id", "")) == "roar_break":
			break_events += 1
	_check(break_events == 1, "破绽应广播一次阶段事件（横幅 + 飘字同源）")
	beast_sim.events.clear()
	beast_sim.summon_monsters(beast_u, "mon_shadow_wolf", 1, 6)
	var wolf2: Combatant = null
	for u_v2 in beast_sim.alive_units("enemy"):
		if String(u_v2.data.get("id", "")) == "mon_shadow_wolf":
			wolf2 = u_v2
	if wolf2 != null:
		wolf2.take_damage(99999, beast_u, beast_sim)
	var repeat_phase := 0
	for e_v2 in beast_sim.events:
		if String((e_v2 as Dictionary).get("t", "")) == "phase":
			repeat_phase += 1
	_check(wolf2 != null and repeat_phase == 0, "同一条阶段破绽钩子不得二次触发")

	# 首胜事务（P05-C §5）：固定 ID 幂等、职业适配蓝装、世界旗与图鉴同批落地
	var ms: MapScene = (load("res://src/explore/MapScene.gd") as GDScript).new() as MapScene
	ms.st = RunState.new()
	ms._main_cfg = slope_cfg
	var gold_before_fk := int(G.wallet.get("gold", 0))
	var fk1 := ms._apply_optional_first_kill("mon_lost_beast")
	_check(not fk1.is_empty()
		and RewardLedger.applied(G.ledger(), RewardLedger.tx_id("act1", "lost_beast", "first"))
		and int(G.wallet.get("gold", 0)) == gold_before_fk,
		"首胜应只发装备与旗标、走固定事务 ID act1|lost_beast|first|")
	_check(bool((G.prog.get("flags", {}) as Dictionary).get("act1_lost_beast_down", false)),
		"首胜应记世界旗（闻叔台词与布告栏依赖）")
	var zs_tpl := String((eq_rows.get("zs", {}) as Dictionary).get("tpl", ""))
	var got_blue := false
	for inst_v in G.inv_instances():
		var inst := inst_v as Dictionary
		if String(inst.get("tpl", "")) == zs_tpl and int(inst.get("rarity", 0)) == 3:
			got_blue = true
	_check(got_blue, "首胜应把职业适配蓝装放进背包")
	var act1_now: Dictionary = G.act1_state()
	_check((act1_now["discoveries"] as Array).has("mon_lost_beast")
		and (act1_now["first_kills"] as Array).has("mon_lost_beast"),
		"首胜应写图鉴条目与首杀记录")
	_check(ms._apply_optional_first_kill("mon_lost_beast").is_empty(), "首胜事务重放不得再发")
	ms.free()

	# 首领支线（P05-C §5）：可察可战、观察即转可交付、回报闻叔
	var acc_beast := G.side_accept("a1_elite_beast")
	_check(bool(acc_beast.get("ok", false)) and G.side_tracked() == "a1_eco_tracks",
		"开线后首领支线可接取且不抢既有追踪")
	_check(G.side_report("observe", "mon_lost_beast", "broken_slope").has("a1_elite_beast")
		and G.side_status_of("a1_elite_beast") == QuestService.SIDE_READY,
		"在断碑坡观察到失路兽应转可交付（不接触也可完成）")
	_check(G.side_report("observe", "mon_lost_beast", "broken_slope").is_empty(),
		"同一目标的观察不得重复计数")
	var gold_before_turn := int(G.wallet.get("gold", 0))
	var done_beast := G.side_npc_interact("npc_steward")
	_check(String(done_beast.get("kind", "")) == "turn_in"
		and G.side_status_of("a1_elite_beast") == QuestService.SIDE_DONE
		and int(G.wallet.get("gold", 0)) == gold_before_turn + 80,
		"回报闻叔应交付首领支线并发放 80 金")

	# ---------- P05-D1：导师第二技能 → 有效熟练 → 分支选择／重置 ----------
	var mentor_cfg := TableCache.act1_growth_config().get("mentor", {}) as Dictionary
	var mentor_roles := mentor_cfg.get("roles", {}) as Dictionary
	_check(mentor_roles.size() == 4 and String(mentor_cfg.get("npc", "")) == "npc_mentor",
		"导师表应覆盖四职业并接到城内岳教头")
	var mentor_npc := false
	for npc_v3 in G.city_npcs():
		if String((npc_v3 as Dictionary).get("id", "")) == "npc_mentor":
			mentor_npc = true
	_check(mentor_npc, "岳教头必须是主城可接触实体")
	G.selected_role = "zs"
	G.prog["story"] = {"step": "s03", "done": ["s01", "s02"],
		"goals": {"s01": "done", "s02": "done"}}
	G.prog["act1"] = {}
	_check(G.mentor_status() == "locked", "s03 完成前导师不得提前发第二技能")
	G.prog["story"] = {"step": "s04", "done": ["s01", "s02", "s03"],
		"goals": {"s01": "done", "s02": "done", "s03": "done"}}
	var unlock := G.mentor_unlock_second(false)
	var second_sid := G.mentor_second_skill("zs")
	_check(bool(unlock.get("ok", false)) and second_sid == "zs_pozhen"
		and G.act1_unlocked_skills("zs") == ["zs_lieshan", "zs_pozhen"]
		and G.mentor_status() == "practice",
		"s03 后应领取本职业第二技能，主世界技能栏由 1 格增至 2 格")
	_check(not bool(G.mentor_unlock_second(false).get("ok", false)), "第二技能不得重复领取")

	var gated_sim := BattleSim.new()
	gated_sim.setup(81, {"role_id": "zs", "level": 6,
		"unlocked_skills": ["zs_lieshan"]},
		{"theme": "forest", "node_type": "normal", "solo": true, "lead_mon": "mon_wolf"})
	_check(gated_sim.role_unit().skills.size() == 1
		and String(gated_sim.role_unit().skills[0].get("id", "")) == "zs_lieshan",
		"主世界显式技能白名单应真的限制 BattleSim，不得继续暗带五技")
	var learn_sim := BattleSim.new()
	learn_sim.setup(82, {"role_id": "zs", "level": 6,
		"unlocked_skills": G.act1_unlocked_skills("zs")},
		{"theme": "forest", "node_type": "normal", "solo": true, "lead_mon": "mon_wolf"})
	var learn_role := learn_sim.role_unit()
	learn_role.energy = 100
	var second_def: Dictionary = learn_role.skills[1].get("def", {})
	SkillSystem.resolve_cast(learn_sim, {"uid": learn_role.uid, "skill": second_def})
	var effective_seen := false
	for ev_v in learn_sim.events:
		var ev := ev_v as Dictionary
		if String(ev.get("t", "")) == "skill_effective" and String(ev.get("skill", "")) == second_sid:
			effective_seen = true
	_check(effective_seen, "第二技能真实命中后应广播 skill_effective，空放不走熟练入口")
	var mastery_lines := G.mentor_report_effective([second_sid], false)
	_check(not mastery_lines.is_empty() and G.mentor_status() == "choose",
		"首次有效使用应显示熟练 1/1，并开放分支选择")
	_check(G.mentor_report_effective([second_sid], false).is_empty(), "同一熟练节点达成后不得继续刷数")

	var chosen := G.mentor_choose_variant("breaker", false)
	_check(bool(chosen.get("ok", false)) and G.mentor_status() == "chosen",
		"熟练达标后应可选择裂阵分支")
	var variant_sim := BattleSim.new()
	variant_sim.setup(83, {"role_id": "zs", "level": 6,
		"unlocked_skills": G.act1_unlocked_skills("zs"),
		"skill_variants": G.act1_skill_variants("zs")},
		{"theme": "forest", "node_type": "normal", "solo": true, "lead_mon": "mon_wolf"})
	var variant_def: Dictionary = variant_sim.role_unit().skills[1].get("def", {})
	_check(float(variant_def.get("k", 0.0)) > float(second_def.get("k", 0.0))
		and int(variant_def.get("cost", 0)) == int(second_def.get("cost", 0)) + 5
		and float(variant_def.get("cd", 0.0)) == float(second_def.get("cd", 0.0)) - 1.0,
		"裂阵应实际改变战斗用技能副本的伤害、消耗和冷却")
	G.wallet["gold"] = 200
	var reset := G.mentor_reset_variant(false)
	_check(bool(reset.get("ok", false)) and int(G.wallet.get("gold", 0)) == 80
		and G.mentor_status() == "choose", "导师重置应实扣 120 金并回到可选状态")

	# ---------- P05-D2：s04 后兽栏结缘 → 主世界跟随 → 接战出阵 ----------
	var turtle_unlock: Dictionary = TableCache.get_pet("pet_rockturtle").get("unlock", {})
	_check(String(turtle_unlock.get("type", "")) == "story"
		and String(turtle_unlock.get("step", "")) == "s04"
		and String(turtle_unlock.get("npc", "")) == "npc_keeper",
		"岩龟应由 s04 后的阿豆兽栏领取，不再是新档自动伙伴")
	_check(G.res_tex("pet_rockturtle") != null,
		"结缘面板与世界跟随使用的岩龟成品图必须进入 G.res_tex 索引")
	G.prog["pets"] = []
	G.prog["flags"] = {}
	G.prog["story"] = {"step": "s04", "done": ["s01", "s02", "s03"],
		"goals": {"s01": "done", "s02": "done", "s03": "done"}}
	G.ensure_starter_pets()
	_check(G.rockturtle_status() == "locked" and not G.owns_pet("pet_rockturtle"),
		"新档与兼容补全不得在 s04 前自动发岩龟")
	_check(not bool(G.claim_rockturtle(false).get("ok", false)), "未完成 s04 的领取必须被拒绝")
	G.prog["story"] = {"step": "s05", "done": ["s01", "s02", "s03", "s04"],
		"goals": {"s01": "done", "s02": "done", "s03": "done", "s04": "done"}}
	_check(G.rockturtle_status() == "ready", "s04 完成后阿豆应出现结缘入口")
	var turtle_claim := G.claim_rockturtle(false)
	_check(bool(turtle_claim.get("ok", false)) and G.owns_pet("pet_rockturtle")
		and bool((G.prog.get("flags", {}) as Dictionary).get("act1_rockturtle_claimed", false)),
		"确认结缘应同批写入伙伴与第一幕领取旗")
	_check(not bool(G.claim_rockturtle(false).get("ok", false))
		and (G.prog.get("pets", []) as Array).count("pet_rockturtle") == 1,
		"重复领取不得复制岩龟")
	# 兼容旧档：即使其主线仍早，已有伙伴也只保留，不回收、不重复改旗。
	G.prog["story"] = {"step": "s01", "done": [], "goals": {}}
	G.prog.erase("campaign_growth")
	_check(G.rockturtle_status() == "owned" and G.owns_pet("pet_rockturtle"),
		"旧档已有岩龟必须原样保留")

	var pet_sim := BattleSim.new()
	pet_sim.setup(91, {"role_id": "zs", "level": 6, "active_pet": "pet_rockturtle"},
		{"theme": "forest", "node_type": "normal", "solo": true, "lead_mon": "mon_wolf"})
	var turtle_in_battle := false
	var turtle_unit: Combatant = null
	for unit_v in pet_sim.units:
		var unit := unit_v as Combatant
		if unit.kind == "pet" and String(unit.data.get("id", "")) == "pet_rockturtle":
			turtle_in_battle = true
			turtle_unit = unit
	_check(turtle_in_battle, "岩龟被设为出战伙伴后必须真正进入同图战斗")
	if turtle_unit != null:
		var guard_def: Dictionary = {}
		for skill_v in turtle_unit.skills:
			var pet_skill := skill_v as Dictionary
			if String(pet_skill.get("id", "")) == "pw_shellguard":
				guard_def = pet_skill.get("def", {})
				break
		_check(not guard_def.is_empty(), "岩龟应有可识别的护主甲技能")
		if not guard_def.is_empty():
			SkillSystem.resolve_cast(pet_sim, {"uid": turtle_unit.uid, "skill": guard_def})
			var role_shield := pet_sim.role_unit().get_buff("shield")
			var shield_seen := false
			for pet_event_v in pet_sim.events:
				var pet_event := pet_event_v as Dictionary
				if String(pet_event.get("t", "")) == "shield_add" \
						and int(pet_event.get("uid", -1)) == pet_sim.role_unit().uid:
					shield_seen = true
			_check(not role_shield.is_empty() and shield_seen,
				"护主甲应为人物加真实护盾，并发出战斗可见的 +盾 事件")
			# 自动施法不能只存在于手动 resolve 的验证里：冲撞进入冷却后，
			# 宠物 AI 应主动排入护主甲，常规接触战才看得到护卫动作。
			pet_sim.cast_queue.clear()
			for skill_v2 in turtle_unit.skills:
				var pet_skill2 := skill_v2 as Dictionary
				if String(pet_skill2.get("id", "")) == "pw_ram":
					pet_skill2["cd_left"] = 30
				elif String(pet_skill2.get("id", "")) == "pw_shellguard":
					pet_skill2["cd_left"] = 0
			MonsterAI.decide(pet_sim, turtle_unit)
			_check(pet_sim.cast_queue.size() == 1
				and String((pet_sim.cast_queue[0].get("skill", {}) as Dictionary).get("id", "")) == "pw_shellguard",
				"冲撞冷却时宠物 AI 应自动选择护主甲")

	var pet_map := (load("res://src/explore/MapScene.gd") as GDScript).new() as MapScene
	pet_map._mode = "main_world"
	pet_map.st = RunState.new()
	pet_map.st.setup({"theme": "forest", "role_id": "zs", "level": 6,
		"active_pet": "pet_rockturtle", "bench_pet": "", "potions": 2, "seed": 91})
	pet_map._player = CharacterBody2D.new()
	pet_map._player.position = Vector2(240, 400)
	pet_map._world.add_child(pet_map._player)
	pet_map._sync_world_companion()
	_check(pet_map._pet_follower != null and pet_map._pet_follower.get_parent() == pet_map._world
		and pet_map._pet_follower_sprite != null,
		"主世界应生成无碰撞岩龟跟随实体，并与世界层一同显隐")
	pet_map.free()
	G.prog["story"] = {"step": "s05", "done": ["s01", "s02", "s03", "s04"],
		"goals": {"s01": "done", "s02": "done", "s03": "done", "s04": "done"}}
	_check(G.save_game(), "岩龟领取状态应写入测试存档")
	G.prog["pets"] = []
	G.prog["flags"] = {}
	G._load_save()
	_check(G.owns_pet("pet_rockturtle")
		and bool((G.prog.get("flags", {}) as Dictionary).get("act1_rockturtle_claimed", false))
		and not bool(G.claim_rockturtle(false).get("ok", false)),
		"重启读档后岩龟和领取旗应同时恢复，且不能重复领取")

	# ---------- P05-D：古道固定奇遇（可见实体、固定事务、跨读档只给一次） ----------
	var road_entities: Dictionary = TableCache.main_world_map("maple_road").get("entities", {})
	var cache_row: Dictionary = road_entities.get(G.WAYSTONE_CACHE_ID, {})
	_check(String(cache_row.get("kind", "")) == "cache"
		and String(cache_row.get("art", "")) == "cache"
		and (cache_row.get("at", []) as Array).size() == 2,
		"旧路石匣应是古道风铃旁可看见、可接触的固定实体")
	G.prog["main_world"] = {"map_id": "maple_road"}
	var cache_gold := int(G.wallet.get("gold", 0))
	var cache_refine := G.item_count("refine_stone")
	_check(G.waystone_cache_available(), "未发现前石匣应可交互")
	var cache_claim := G.claim_waystone_cache(false)
	var cache_world := G.prog.get("main_world", {}) as Dictionary
	_check(bool(cache_claim.get("ok", false))
		and int(G.wallet.get("gold", 0)) == cache_gold + 30
		and G.item_count("refine_stone") == cache_refine + 1
		and WorldSession.entity_taken(cache_world, G.WAYSTONE_CACHE_ID)
		and bool((G.prog.get("flags", {}) as Dictionary).get("act1_waystone_cache_found", false))
		and (G.act1_state()["discoveries"] as Array).has(G.WAYSTONE_CACHE_ID),
		"旧路石匣应同批结算金币、材料、永久实体态、世界旗和线索")
	_check(not G.waystone_cache_available() and not bool(G.claim_waystone_cache(false).get("ok", false))
		and int(G.wallet.get("gold", 0)) == cache_gold + 30,
		"石匣重复接触不得二次发放")
	_check(G.save_game(), "石匣结算应写入测试存档")
	G.prog["main_world"] = {"map_id": "maple_road"}
	G.prog["flags"] = {}
	G._load_save()
	_check(not G.waystone_cache_available()
		and WorldSession.entity_taken(G.prog.get("main_world", {}) as Dictionary, G.WAYSTONE_CACHE_ID)
		and int(G.wallet.get("gold", 0)) == cache_gold + 30,
		"石匣读档后应保持消失、奖励账本不能重放")

	# ---------- P05-D4：马厩剧情首骑、四职业四向骑姿与骑乘存档 ----------
	var prior_mount_prog := G.prog.duplicate(true)
	var stable_seen := false
	for npc_v4 in G.city_npcs():
		if String((npc_v4 as Dictionary).get("id", "")) == "npc_stablemaster":
			stable_seen = true
	_check(stable_seen and G.is_built("stable"), "首骑必须由城内可接触的马厩实体提供")
	var mount_cfg := G.first_mount_cfg()
	_check(String(mount_cfg.get("npc", "")) == "npc_stablemaster"
		and String(mount_cfg.get("unlock_after", "")) == "s06"
		and float(mount_cfg.get("world_speed_mult", 0.0)) > 1.0,
		"首骑应有剧情门槛、马厩入口与可见的世界移动加速")
	for role_id in ["zs", "ck", "fs", "fz"]:
		var mount_frames := MountVisual.frames_for(role_id)
		_check(mount_frames != null, "%s 须有四向骑姿资源" % role_id)
		if mount_frames != null:
			for direction in MountVisual.DIRECTIONS:
				_check(mount_frames.has_animation(StringName(direction))
					and mount_frames.get_frame_count(StringName(direction)) == 1,
					"%s 缺 %s 骑姿" % [role_id, direction])
	G.prog["mounts"] = {"owned": {}, "active": ""}
	G.prog["story"] = {"step": "s06", "done": ["s01", "s02", "s03", "s04", "s05"], "goals": {}}
	_check(G.first_mount_status() == "locked"
		and not bool(G.claim_first_mount(false).get("ok", false)),
		"守住断碑坡前不得提前领取首骑")
	(G.prog["story"]["done"] as Array).append("s06")
	_check(G.first_mount_status() == "ready", "s06 后马厩应开放免费首骑")
	var mount_claim := G.claim_first_mount(false)
	_check(bool(mount_claim.get("ok", false)) and G.mount_tier("horse") == 1
		and G.mount_active() == "horse" and not G.mount_riding()
		and bool((G.prog.get("flags", {}) as Dictionary).get("act1_first_mount_claimed", false)),
		"马厩领取应写拥有、选中与世界旗，初始保持下马")
	_check(not bool(G.claim_first_mount(false).get("ok", false))
		and G.mount_tier("horse") == 1, "首骑不得重复领取或升阶")
	_check(G.mount_set_riding(true, false) and G.mount_riding(), "拥有首骑后应能上马")
	_check(G.save_game(), "骑乘状态应可写入测试存档")
	G.prog["mounts"] = {"owned": {}, "active": ""}
	G._load_save()
	_check(G.mount_tier("horse") == 1 and G.mount_active() == "horse"
		and G.mount_riding() and G.first_mount_status() == "owned",
		"跨进程读档应恢复首骑拥有与骑乘状态")
	_check(G.mount_set_riding(false, false) and not G.mount_riding(), "下马应回到步行状态")
	G.prog["mounts"] = {"owned": {"horse": 1}, "active": "horse"}
	_check(not G.mount_riding(), "旧档只有 active 的坐骑不得无提示自动上马")
	G.prog = prior_mount_prog
