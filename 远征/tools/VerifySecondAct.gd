# P07-A/B: old-save continuation, salt-road ledger, port runtime and trade entry.
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_second_act.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "盐路行者"
	G.wallet["gold"] = 1000
	G.prog["level"] = 12
	G.prog["story"] = {"step": "", "done": ["s12"], "goals": {}}
	await _run()
	await _run_port_side_quests()
	print("SECOND_ACT_OK" if _fails == 0 else "SECOND_ACT_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)


func _make_run() -> RunState:
	var run := RunState.new()
	run.setup({"theme": "forest", "role_id": "zs", "level": 12,
		"active_pet": "pet_rockturtle", "bench_pet": "", "potions": 2, "seed": 97})
	return run


func _enter(map_id: String) -> MapScene:
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": map_id,
		"run": _make_run(), "node": {"type": "normal", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	return map


func _run() -> void:
	var before_gold := int(G.wallet["gold"])
	_check(String(G.story_current().get("id", "")) == "s13",
		"旧档 s12 完成且 step 为空时应接入 s13")
	_check(String(G.story_current().get("id", "")) == "s13"
		and int(G.wallet["gold"]) == before_gold, "重复归一不能重发 s12 奖励")
	var maple := TableCache.main_world_map("maple_road")
	var salt := TableCache.main_world_map("old_salt_road")
	var port := TableCache.main_world_map("shenyuan_port")
	_check(not salt.is_empty() and not port.is_empty(), "旧盐道与沉渊港地图应存在")
	_check(String((maple["exits"] as Array)[2].get("requires_story", "")) == "s12",
		"古道东口应由第一幕复命开放")
	_check((salt["spawn_points"] as Dictionary).has("from_shenyuan_port")
		and (port["spawn_points"] as Dictionary).has("from_old_salt_road"),
		"两图返回路各有独立安全落点")
	_check(String(G.story_event("talk", "npc_warden", "lorin_wilds").get("id", "")) == "s13",
		"行脚商人对话应开启盐账调查")
	var salt_scene := await _enter("old_salt_road")
	_check(G.story_step_done("s14"), "实际进入旧盐道应完成到访目标")
	_check(salt_scene._monsters.size() == 4 and salt_scene._city_content == null,
		"盐道应有游荡敌影且不是城务场景")
	var cart: Node2D = null
	for ent in salt_scene._quest_entities:
		if is_instance_valid(ent) and String(ent.eid) == "salt_cart_ledger":
			cart = ent
	_check(cart != null, "断桥盐车账页应作为地图实体出现")
	if cart != null:
		salt_scene.on_quest_entity(cart)
	_check(G.story_step_done("s15") and G.item_count("salt_ledger") == 1,
		"拾取账页应只发一次任务物并推进主线")
	var gold_after_cart := int(G.wallet["gold"])
	_check(G.story_event("collect", "salt_cart_ledger", "old_salt_road").is_empty()
		and int(G.wallet["gold"]) == gold_after_cart, "重复拾取不能刷奖励")
	salt_scene.queue_free()
	await get_tree().process_frame
	var port_scene := await _enter("shenyuan_port")
	_check(port_scene._city_content != null and port_scene._monsters.is_empty(),
		"港口应作为安全城镇实例化，不在主街刷怪")
	if port_scene._city_content != null:
		var city: CityScene = port_scene._city_content
		_check(city._city_id == "shenyuan_port" and city._buildings.size() == 4
			and city._npcs.size() == 4, "港口应加载独立的四栋建筑和四名常驻人物")
		_check(city._quest_lbl != null and city._quest_lbl.text == "港务 · 查看行情",
			"港口快捷入口不应误显示昭元的今日委托")
		for b in city._buildings:
			_check(b.built(), "港口建筑应已落成并可交互")
		city._open_first_order_preview("shenyuan_market")
		_check(city._panel is TradePanel and city._panel.site_id == "shenyuan_market",
			"港口市集入口应打开本地行情")
		if city._panel is TradePanel:
			city._panel.close()
		await get_tree().process_frame
		for npc in city._npcs:
			_check(city._npc_portrait_tex(String(npc.data["id"]), false) != null, "港口对话必须复用相同人物的头肩图")
			_check(npc.frames != null and npc.has_node("Idle"), "港口NPC必须使用四帧待机：" + String(npc.data["id"]))
			for building in city._buildings:
				_check(building.art != null, "港口建筑必须接入贴图：" + String(building.data["id"]))
				var shape: CollisionShape2D = building.get_child(0) as CollisionShape2D
				var footprint := Rect2(building.position + shape.position - (shape.shape as RectangleShape2D).size * 0.5, (shape.shape as RectangleShape2D).size)
				_check(not footprint.grow(4).has_point(npc.position), "港口NPC脚点不能落入建筑基座：" + String(npc.data["id"]))
		var master: Dictionary = G.city_npc("npc_harbormaster")
		_check(G.res_tex("city_port_hall") != null, "港务厅应接入新的建筑图")
		_check(city._npc_idle_frames("npc_harbormaster", false) != null, "港务人必须接入四帧待机")
		_check(not master.is_empty(), "港务人对话应可从港口配置读取")
		city._open_dialog(master, false)
		_check(G.story_step_done("s16") and G.item_count("salt_ledger") == 0,
			"港务对话应收回账页、完成前段主线")
		city._close_panel()
		city._built_action("hatch")
		_check(city._panel != null and G.res_tex("itm_tide_egg") != null
			and G.res_tex("pet_tide_gull") != null,
			"港口兽栏应打开孵化面板并接入蛋与伙伴图")
		city._close_panel()
		_check(bool(G.port_egg_claim().get("ok", false)) and G.item_count("tide_egg") == 1,
			"交账后兽栏可领取一枚潮纹蛋")
		_check(not bool(G.port_egg_claim().get("ok", false)), "赠蛋只可领取一次")
		var hatch := G.port_egg_hatch()
		_check(bool(hatch.get("ok", false)) and not bool(hatch.get("duplicate", true))
			and G.item_count("tide_egg") == 0 and G.owns_pet("pet_tide_gull")
			and G.battle_pet_stats(["pet_tide_gull"]).has("pet_tide_gull"),
			"首次孵化应消耗蛋、获得可协战伙伴")
		var gull_sim := BattleSim.new()
		gull_sim.setup(505, {"role_id": "zs", "level": 12, "traits": [],
			"active_pet": "pet_tide_gull", "pet_stats": G.battle_pet_stats(["pet_tide_gull"])},
			{"theme": "desert", "node_type": "normal", "layer": 1})
		var gull_ready := false
		for unit in gull_sim.units:
			if unit.kind == "pet" and String(unit.data.get("id", "")) == "pet_tide_gull":
				gull_ready = not unit.skills.is_empty()
		_check(gull_ready, "潮羽雏鸥必须进入战斗单位编成并带技能")
	port_scene.queue_free()
	await get_tree().process_frame
	_check(G.reload_save() and G.story_step_done("s16") and G.item_count("salt_ledger") == 0
		and G.owns_pet("pet_tide_gull"), "港口交付与孵化后重读档不能退回或复制")
	var actual_story: Dictionary = G.prog["story"]
	G.prog["story"] = {"step": "", "done": ["s12", "s13", "s14", "s15", "s16"]}
	_check(String(G.story_current().get("id", "")) == "s17",
		"P07-A/B 版本在 s16 停止的旧档应接入潮痕滩")
	G.prog["story"] = actual_story
	var flat := await _enter("tideflat")
	_check(flat._monsters.size() == 5 and flat._city_content == null,
		"潮痕滩应生成四只游荡怪和独立可选盐鳞王")
	var guards := 0
	var cargo: Node2D = null
	for mon in flat._monsters:
		if mon.mon_id == "mon_tidal_guard":
			guards += 1
		if mon.mon_id == "mon_salt_crab":
			_check(mon._sprite != null and mon.sprite_path == "res://image/main_world/mon_salt_crab.png", "盐甲蟹必须使用新贴图")
	for ent in flat._quest_entities:
		if is_instance_valid(ent) and String(ent.eid) == "tide_cargo":
			cargo = ent
	_check(guards == 2 and cargo != null, "闸门守卫槽和潮印货堆应稳定出现")
	if cargo != null:
		flat.on_quest_entity(cargo)
	_check(G.story_step_done("s17"), "实际调查潮印货堆应推进主线")
	var first := flat._apply_optional_first_kill("mon_salt_scale")
	_check(not first.is_empty() and bool((G.prog.get("flags", {}) as Dictionary).get(
		"act2_salt_scale_down", false)), "盐鳞王首胜应发独立一次性战利")
	_check(flat._apply_optional_first_kill("mon_salt_scale").is_empty(),
		"盐鳞王首胜事务不可重复发放")
	_check(String(G.story_event("defeat", "mon_tidal_guard", "tideflat").get("id", "")) == "s18"
		and G.item_count("gate_clue") == 1, "守卫胜利应给闸门线索并开放水闸")
	flat.queue_free()
	await get_tree().process_frame
	var gate := await _enter("tidal_gate")
	_check(gate._monsters.size() == 1 and gate._monsters[0].mon_id == "mon_tide_priest",
		"水闸应有独立的潮蚀司祭首领")
	var priest := TableCache.get_monster("mon_tide_priest")
	_check((priest.get("phases", []) as Array).size() == 2
		and float(((priest.get("skills", []) as Array)[0] as Dictionary).get("windup", 0)) >= 2.0,
		"司祭应有可预告的蓄力技和两个阶段")
	var sim := BattleSim.new()
	sim.setup(309, {"role_id": "zs", "level": 20, "traits": []},
		{"theme": "tomb", "node_type": "boss", "layer": 1,
			"lead_mon": "mon_tide_priest", "solo": true})
	var boss: Combatant = null
	for unit in sim.units:
		if unit.side == "enemy" and unit.ai_type == "boss":
			boss = unit
			break
	_check(boss != null and String(boss.data.get("id", "")) == "mon_tide_priest",
		"同图接战应组出正确司祭而非主题默认首领")
	if boss != null:
		boss.hp = int(float(boss.get_max_hp()) * 0.54)
		sim.events.clear()
		sim.step()
		var phase_one := false
		for event in sim.events:
			if String(event.get("t", "")) == "phase" and String(event.get("id", "")) == "high_tide":
				phase_one = true
		_check(phase_one and boss.has_buff("spd_up"), "半血涨潮应广播且加速")
		boss.hp = int(float(boss.get_max_hp()) * 0.21)
		sim.events.clear()
		sim.step()
		var phase_two := false
		for event in sim.events:
			if String(event.get("t", "")) == "phase" and String(event.get("id", "")) == "ebb":
				phase_two = true
		_check(phase_two and boss.has_buff("stun") and boss.has_buff("def_break"),
			"低血退潮应给可利用的硬直与破防窗口")
	_check(String(G.story_event("defeat", "mon_tide_priest", "tidal_gate").get("id", "")) == "s19"
		and G.item_count("gate_clue") == 0 and G.item_count("tide_core") == 1,
		"水闸首胜应消耗线索、给闸芯并推进回港目标")
	gate.queue_free()
	await get_tree().process_frame
	var price_before := G.economy_quote("shenyuan_market", "trade_salt")
	var return_port := await _enter("shenyuan_port")
	var port_city: CityScene = return_port._city_content
	port_city._open_dialog(G.city_npc("npc_harbormaster"), false)
	_check(port_city._panel != null and not G.story_step_done("s20"),
		"回港应先显示等值供货选择，不自动替玩家决定")
	port_city._commit_tide_choice("dredge")
	var price_after := G.economy_quote("shenyuan_market", "trade_salt")
	_check(G.story_step_done("s20") and G.item_count("tide_core") == 0
		and String(G.economy_state().get("port_event", "")) == "dredge",
		"疏浚选择应消耗闸芯并写入港口行情状态")
	var wallet_before_egg := int(G.wallet.get("gold", 0))
	var pet_food_before := G.item_count("pet_food")
	var owned_before := G.owned_pets().size()
	_check(bool(G.port_egg_buy().get("ok", false)) and G.item_count("tide_egg") == 1
		and int(G.wallet.get("gold", 0)) == wallet_before_egg - 500,
		"港口再购蛋应扣铜钱并入背包")
	var duplicate_hatch := G.port_egg_hatch()
	_check(bool(duplicate_hatch.get("ok", false)) and bool(duplicate_hatch.get("duplicate", false))
		and G.item_count("tide_egg") == 0 and G.item_count("pet_food") == pet_food_before + 2
		and G.owned_pets().size() == owned_before,
		"重复孵化应转成宠物粮，不复制伙伴")
	_check(int(price_after.get("event_pct", 0)) == int(price_before.get("event_pct", 0)) - 8,
		"疏浚后盐价事件应按选项变化")
	_check(G.story_event("talk", "npc_harbormaster", "shenyuan_port", true,
		{"method": "dredge"}).is_empty(), "回港选择不得重复领奖")
	return_port.queue_free()
	await get_tree().process_frame
	_check(G.reload_save() and G.story_step_done("s20")
		and String(G.economy_state().get("port_event", "")) == "dredge",
		"跨重读档应保留供货选择与主线完成状态")
	# 存档被锁时，胜利结算不能把金币、物品、刷点或等级留在内存里。
	var rollback_map := await _enter("tideflat")
	var rollback_mon = rollback_map._monsters[0]
	rollback_map._contact_mon = rollback_mon
	rollback_map._last_battle_tier = "normal"
	rollback_map._last_battle_optional = false
	rollback_map.st.gold = 7
	rollback_map.st.exp = 9
	var snap_prog := G.prog.duplicate(true)
	var snap_wallet := G.wallet.duplicate(true)
	var snap_items := G.items.duplicate(true)
	var snap_respawn := rollback_map._main_respawn_at.duplicate(true)
	var snap_level := rollback_map.st.level
	G.save_locked = true
	var failed := rollback_map._settle_main_world("normal", String(rollback_mon.mon_id))
	G.save_locked = false
	_check(failed == "save_failed" and G.prog == snap_prog and G.wallet == snap_wallet
		and G.items == snap_items and rollback_map._main_respawn_at == snap_respawn
		and rollback_map.st.gold == 7 and rollback_map.st.exp == 9
		and rollback_map.st.level == snap_level,
		"写盘失败必须完整回滚胜利战利、刷点和临时状态")
	rollback_map.queue_free()


class FailedSaveHost extends "res://src/autoload/G.gd":
	func save_game() -> bool:
		return false


func _run_port_side_quests() -> void:
	G._init_state_defaults()
	G.selected_role = "zs"
	G.player_name = "港口支线"
	G.prog["level"] = 12
	G.prog["story"] = {"step": "s16", "done": ["s12"], "goals": {}}
	var port_rows: Array = []
	for row in G.side_quest_rows():
		if String((row as Dictionary).get("id", "")).begins_with("a2_"): port_rows.append(row)
	_check(port_rows.size() == 6, "港口地区必须交付六条支线")
	for row in port_rows:
		_check(not bool(G.side_accept(String(row.id)).get("ok", false)), "交账前不开放港口支线")
	G.prog["story"] = {"step": "s17", "done": ["s12", "s16"], "goals": {}}
	var npc_ids: Array = []
	for npc in (TableCache._load("res://data/shenyuan_port.json").get("npcs", []) as Array):
		npc_ids.append(String(npc.id))
	for row in port_rows:
		_check(npc_ids.has(String(row.giver)), "港口发布者必须实际存在")
		var map_cfg := TableCache.main_world_map(String(row.map))
		var entities: Dictionary = map_cfg.get("entities", {})
		var targets: Array = (row.objective as Dictionary).get("target_entities", [])
		var single := String((row.objective as Dictionary).get("target_entity", ""))
		if not single.is_empty(): targets = [single]
		for eid in targets:
			_check(entities.has(eid) and String(entities[eid].quest) == String(row.id), "支线目标必须有同任务地图实体")
	# 两种修法必须显式选择，奖励等值；实体在同图接任务后即时出现。
	var choice_gold := -1
	for choice in ["retie", "replace"]:
		G.prog["act1"] = {}
		G.prog["ledger"] = {}
		G.wallet["gold"] = 1000
		var port := await _enter("shenyuan_port")
		port._city_content._open_dialog(G.city_npc("npc_port_worker"), false)
		_check(G.side_status_of("a2_rel_rope") == QuestService.SIDE_ACTIVE, "老鹭真实对话应接取松缆托付")
		var rope: Node2D = null
		for entity in port._quest_entities:
			if entity.eid == "a2_loose_rope": rope = entity
		_check(rope != null, "同地图接任务后松缆必须即时出现")
		port._city_content._close_panel()
		if rope != null: port.on_quest_entity(rope)
		_check(G.side_status_of("a2_rel_rope") == QuestService.SIDE_READY, "调查松缆应转可交付")
		_check(G._side_complete("a2_rel_rope").is_empty(), "普通对话不可代选修缆方法")
		port._city_content._open_dialog(G.city_npc("npc_port_worker"), false)
		_check(port._city_content._panel != null and G.side_status_of("a2_rel_rope") == QuestService.SIDE_READY, "实际回报必须显示选择并等待输入")
		await get_tree().process_frame
		var gold_before := int(G.wallet.gold)
		G.save_locked = true
		_check(G._side_complete("a2_rel_rope", true, choice).is_empty() and int(G.wallet.gold) == gold_before, "锁盘不能保存选择或发奖励")
		G.save_locked = false
		var option_title := "留旧缆 · 重新系紧" if choice == "retie" else "换新缆 · 收起旧绳"
		var button := _choice_button(port._city_content._panel, option_title)
		_check(button != null and button.size.y >= 44, "修缆选项必须有完整触控区域")
		if button != null:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			button.gui_input.emit(event)
		var delta := int(G.wallet.gold) - gold_before
		_check(G.side_status_of("a2_rel_rope") == QuestService.SIDE_DONE and String((G.prog.get("flags", {}) as Dictionary).get("act2_pier_rope", "")) == choice, "选择、奖励和绳色旗必须同时保存")
		_check(G.side_status_of("a2_eco_salt").is_empty(), "提交选择不能自动接取下一条托付")
		if choice_gold < 0: choice_gold = delta
		_check(delta == choice_gold and delta == 120, "两种修法奖励等值")
		_check(G.reload_save() and String(QuestService.side_get(G.act1_state(), "a2_rel_rope").get("choice", "")) == choice, "读档保留所选修法")
		_check(G._side_complete("a2_rel_rope", true, choice).is_empty(), "重复交付不可重发")
		port.queue_free()
		await get_tree().process_frame
	# 其它五条各自走地图实体；同一采样不重复计数。
	G.prog["act1"] = {}
	for row in port_rows:
		var qid := String(row.id)
		if qid == "a2_rel_rope": continue
		_check(bool(G.side_accept(qid).get("ok", false)), "交账后支线应可接")
		var map := await _enter(String(row.map))
		if String(row.objective.kind) == "boss":
			var scale: Node2D = null
			for monster in map._monsters:
				if monster.mon_id == "mon_salt_scale": scale = monster
			_check(scale != null, "盐鳞王观察支线必须有真实首领")
			if scale != null:
				map._player.position = scale.position + Vector2(150, 0)
				await get_tree().process_frame
				await get_tree().process_frame
			_check(map._battle == null and G.side_status_of(qid) == QuestService.SIDE_READY, "在接触前应完成盐鳞王观察，不强迫战斗")
		else:
			for entity in map._quest_entities.duplicate():
				if entity.quest != qid: continue
				var eid := String(entity.eid)
				map.on_quest_entity(entity)
				_check(not bool(G.side_entity_interact(String(row.objective.kind), eid, String(row.map), qid).get("ok", false)), "同实体重报不得重复领奖或计数")
		if String(row.objective.kind) != "deliver":
			_check(G.side_status_of(qid) == QuestService.SIDE_READY and bool(G._side_complete(qid).get("ok", false)), "每条目标应可交付")
		_check(G.side_status_of(qid) == QuestService.SIDE_DONE, "每条港口支线都必须可完成")
		map.queue_free()
		await get_tree().process_frame
	_check(G.reload_save() and G.side_status_of("a2_trade_message") == QuestService.SIDE_DONE, "实体当场结算在读档后保持")
	# 实际写盘失败发生在奖励之后：用同脚本的失败存储适配器验证钱包也回滚。
	var host := FailedSaveHost.new()
	host._init_state_defaults()
	host.selected_role = "zs"
	host.prog["story"] = {"step": "s17", "done": ["s16"], "goals": {}}
	QuestService.side_accept(host.act1_state(), host._side_live_rows(), "a2_trade_message")
	var before_prog := host.prog.duplicate(true)
	var before_wallet := host.wallet.duplicate(true)
	var before_items := host.items.duplicate(true)
	var failed := host.side_entity_interact("deliver", "a2_salt_courier", "old_salt_road", "a2_trade_message")
	_check(not bool(failed.get("ok", false)) and host.prog == before_prog and host.wallet == before_wallet and host.items == before_items, "送口信发奖后的写盘失败必须整体回滚，包含钱包")
	host.free()


func _choice_button(node: Node, title: String) -> Control:
	if node == null: return null
	if node is Label and node.text == G._button_text(title): return node.get_parent() as Control
	for child in node.get_children():
		var found := _choice_button(child, title)
		if found != null: return found
	return null
