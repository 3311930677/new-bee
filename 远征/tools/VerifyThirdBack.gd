extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_third_back.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "双关回讯"
	await _run()
	print("THIRD_BACK_OK" if _fails == 0 else "THIRD_BACK_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)


func _enter(id: String) -> MapScene:
	var run := RunState.new()
	run.setup({"theme": String(TableCache.main_world_map(id).get("theme", "snow")),
		"role_id": "zs", "level": 24, "active_pet": "", "bench_pet": "", "potions": 2, "seed": 317})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": id, "run": run,
		"node": {"type": String(TableCache.main_world_map(id).get("node_type", "normal")), "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	return map


func _run() -> void:
	var done: Array = []
	for i in range(1,25): done.append("s%02d" % i)
	G.prog["story"] = {"step": "", "done": done, "goals": {}}
	G.prog["flags"] = {"act1_repair_method": "forge", "act2_port_choice": "dredge"}
	G.prog["level"] = 24
	G.ensure_starter_equip(true)
	G.items = {"mine_record":1, "salt":3}
	G.wallet["gold"] = 3000
	var original := G.prog.duplicate(true)
	_check(String(G.story_current().get("id", "")) == "s25", "P08-A 空步骤旧档应续 s25")
	for key in original:
		if key != "story": _check(G.prog[key] == original[key], "迁移必须保留 " + String(key))
	_check(G.item_count("mine_record") == 1 and int(G.wallet.gold) == 3000, "迁移不得发奖或扣记录")
	var post := await _enter("frost_post")
	post._player.position = Vector2(480,96)
	post._check_world_exits()
	_check(not post._map_done, "械卫前驿北出口应锁定")
	post.queue_free()
	await get_tree().process_frame
	var vault := await _enter("rift_mine_vault")
	_check(vault._monsters.size() == 1 and vault._monsters[0].mon_id == "mon_redsand_guard"
		and vault._monsters[0]._sprite != null, "矿脉应生成独立械卫与贴图")
	G.items.erase("mine_record")
	vault._monsters[0].chasing_contact = true
	vault.on_monster_contact(vault._monsters[0])
	_check(vault._battle == null and not vault._main_boss_cleared(), "缺记录不得进战或清除首领")
	_check(not vault._monsters[0].chasing_contact and vault._monsters[0].contact_cd > 0,
		"缺物拒绝接触后必须解除冻结并进入冷静期")
	_check(vault._settle_main_world("boss", "mon_redsand_guard") == "quest_missing", "胜利入口也应拒绝缺物")
	G.items["mine_record"] = 1
	vault._contact_mon = vault._monsters[0]
	var snap := G.prog.duplicate(true)
	var wallet := G.wallet.duplicate(true)
	var items := G.items.duplicate(true)
	G.save_locked = true
	_check(vault._settle_main_world("boss", "mon_redsand_guard") == "save_failed"
		and G.prog == snap and G.wallet == wallet and G.items == items, "胜利写盘失败必须完整回滚")
	G.save_locked = false
	_check(vault._settle_main_world("boss", "mon_redsand_guard") == "ok"
		and G.story_step_done("s25") and G.item_count("mine_record") == 0
		and G.item_count("gate_stamp") == 1 and vault._main_boss_cleared(), "械卫胜利应交记录、发铁印、清除首领")
	vault.queue_free()
	await get_tree().process_frame
	var cleared := await _enter("rift_mine_vault")
	_check(cleared._monsters.is_empty(), "重进已胜矿脉不得重发首领")
	cleared.queue_free()
	await get_tree().process_frame
	G.prog["mounts"] = {"active":"horse", "owned":{"horse":1}, "riding":true}
	var boardwalk := await _enter("frost_boardwalk")
	_check(not G.mount_riding(), "旧档骑乘重进窄栈道应自动下马")
	boardwalk._toggle_mount()
	_check(not G.mount_riding(), "窄栈道不能再次上马")
	var signal_entity: Node2D = null
	for ent in boardwalk._quest_entities:
		if ent.eid == "signal_ribbons": signal_entity = ent
	_check(signal_entity != null, "栈道应有真实双关讯号")
	if signal_entity != null: boardwalk.on_quest_entity(signal_entity)
	_check(G.story_step_done("s26") and G.item_count("gate_stamp") == 0
		and G.item_count("frost_reply") == 1, "观察应交铁印并取得回讯")
	await get_tree().physics_frame
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = boardwalk._player_shape.shape
	query.collision_mask = 2
	for y in range(150,1140,24):
		query.transform = Transform2D(0, Vector2(480,y))
		_check(boardwalk._player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "栈道主路无隐形碰撞")
	boardwalk.queue_free()
	await get_tree().process_frame
	var pass_map := await _enter("frost_pass")
	_check(pass_map._monsters.size() == 1 and pass_map._monsters[0].mon_id == "mon_snowveil_lord", "冰隘应生成雪幕领主")
	pass_map._contact_mon = pass_map._monsters[0]
	_check(pass_map._settle_main_world("boss", "mon_snowveil_lord") == "ok"
		and G.story_step_done("s27") and G.item_count("frost_reply") == 0 and G.item_count("veil_seal") == 1,
		"雪幕胜利交回讯并发雪幕印")
	pass_map.queue_free()
	await get_tree().process_frame
	var choice_state := G.prog.duplicate(true)
	var choice_wallet := G.wallet.duplicate(true)
	var choice_items := G.items.duplicate(true)
	var choice_city := G.city.duplicate(true)
	var equal_reward_wallet := {}
	for choice in ["merchant", "wardens"]:
		G.prog = choice_state.duplicate(true)
		G.wallet = choice_wallet.duplicate(true)
		G.items = choice_items.duplicate(true)
		G.city = choice_city.duplicate(true) # Alternative history also restores work cooldowns.
		var return_post := await _enter("frost_post")
		var city: CityScene = return_post._city_content
		city._open_dialog(G.city_npc("npc_frost_envoy"), false)
		_check(city._panel != null and not G.story_step_done("s28"), "宁砚必须等待真实选择")
		var button := _find_button(city._panel, "商货先行" if choice == "merchant" else "守关补给")
		_check(button != null, "两种真实选项必须可点击")
		if button != null:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			button.gui_input.emit(click)
		_check(G.story_step_done("s28") and G.item_count("veil_seal") == 0
			and String(G.prog.flags.get("act3_supply_choice", "")) == choice
			and String(G.economy_state().get("frost_event", "")) == choice, "选择应交印并同步永久旗和行情")
		if equal_reward_wallet.is_empty(): equal_reward_wallet = G.wallet.duplicate(true)
		else: _check(G.wallet == equal_reward_wallet, "两种选择的钱包奖励必须等值")
		await get_tree().process_frame
		var banner_found := false
		await get_tree().process_frame
		for child in return_post.get_children():
			if child.get_script() != null and child.get_script().resource_path == "res://src/explore/ThirdActGround.gd":
				banner_found = String(child.get("_choice")) == choice
		_check(banner_found, "驿站旗幡绘制应读同一永久旗")
		var good := "trade_grain" if choice == "merchant" else "trade_iron"
		_check(int(G.economy_quote("frost_market",good).get("event_pct",0)) == -8, "选择实际报价应变化 -8%")
		for npc in ["npc_frost_envoy", "npc_frost_guard", "npc_frost_miner"]:
			_check((G.city_npc(npc).choice_lines[choice] as Array).has(G.npc_line(npc,0)), "居民必须回应所选供货路线")
		_check(G.reload_save() and G.story_step_done("s28") and G.prog.flags.act3_supply_choice == choice,
			"真实重读应保留章末选择")
		var after_wallet := G.wallet.duplicate(true)
		_check(G.story_event("talk","npc_frost_envoy","frost_post",true,{"method":choice}).is_empty()
			and G.wallet == after_wallet, "重复选择不得发奖")
		city._built_action("trade:frost_market")
		_check(city._panel != null, "物资铺必须打开实际现货界面")
		_check(_find_button(city._panel, "断碑坡运路  ·  未解锁", false) == null,
			"驿站行情不应显示与本地无关的断碑运路入口")
		var trade := city._panel as TradePanel
		var buy_button := _find_button(trade,"买入")
		var grain_before := G.item_count("trade_grain")
		var gold_before := int(G.wallet.get("gold",0))
		var quote := G.economy_quote("frost_market","trade_grain")
		if buy_button != null:
			var buy := InputEventMouseButton.new()
			buy.button_index = MOUSE_BUTTON_LEFT
			buy.pressed = true
			buy_button.gui_input.emit(buy)
		_check(G.item_count("trade_grain") == grain_before + 1
			and int(G.wallet.get("gold",0)) == gold_before - int(quote.get("buy_gold",0)),
			"真实买入按钮应按驿站报价一次扣钱并入货")
		_check(bool(G.economy_work("frost_market","frost").get("ok",false))
			and not bool(G.economy_work("frost_market","frost").get("ok",false)),
			"驿站分货应每日可做一次且不可重复发奖")
		city._close_panel()
		return_post.queue_free()
		await get_tree().process_frame
	var host := FailedSaveHost.new()
	host._init_state_defaults()
	host.prog = choice_state.duplicate(true)
	host.wallet = choice_wallet.duplicate(true)
	host.items = choice_items.duplicate(true)
	_check(host.story_event("talk","npc_frost_envoy","frost_post",true,{"method":"merchant"}).is_empty()
		and host.prog == choice_state and host.items == choice_items and host.wallet == choice_wallet,
		"选择写盘失败不得留下旗、报价或印物消耗")
	host.free()
	_test_bosses()


func _test_bosses() -> void:
	for mid in ["mon_redsand_guard", "mon_snowveil_lord"]:
		var sim := BattleSim.new()
		sim.setup(417, {"role_id":"zs","level":24,"traits":[]},
			{"theme":"tomb" if mid == "mon_redsand_guard" else "snow","node_type":"boss","lead_mon":mid,"solo":true})
		var boss: Combatant = sim.alive_units("enemy")[0]
		var skill: Dictionary = boss.skills[0].def
		SkillSystem.enqueue_cast(sim,boss,skill)
		_check(int(sim.cast_queue[0].windup) == (84 if mid == "mon_redsand_guard" else 78), "首领前摇与预兆倒计时同源")
		sim.cast_queue.clear()
		SkillSystem.resolve_cast(sim,{"uid":boss.uid,"skill":skill})
		if mid == "mon_redsand_guard":
			_check(boss.has_buff("break_window") and int(boss.get_buff("break_window").dur) == 120, "械卫重砸后给四秒过热")
		boss.hp = int(boss.get_max_hp() * .54)
		sim._apply_phases()
		var skills_before := boss.skills.size()
		sim._apply_phases()
		_check(boss.skills.size() == skills_before, "阶段不得重复加技能")
		if mid == "mon_snowveil_lord":
			var summon: Dictionary = boss.skills[1].def
			SkillSystem.resolve_cast(sim,{"uid":boss.uid,"skill":summon})
			_check(sim.alive_units("enemy").size() == 2, "雪幕半血必须召出一只风眼")
			for sk in boss.skills: sk.cd_left = 0
			_check(not SkillSystem.can_cast(sim,boss,summon), "冷却归零仍不得二次召唤")
			var eye: Combatant = sim.alive_units("enemy")[1]
			_check(eye.row == Combatant.ROW_FRONT
				and sim.role_unit().pick_basic_target(sim) == eye, "近战必须能实际攻击低血风眼以取得破绽")
			eye.take_damage(99999,boss,sim)
			_check(boss.has_buff("break_window") and int(boss.get_buff("break_window").dur) == 120,
				"击破风眼应给四秒本体破绽")
		boss.hp = int(boss.get_max_hp() * .19)
		sim._apply_phases()
		_check(boss.has_buff("stun"), "低血阶段必须出现硬直")


func _find_button(node: Node, text: String, interactive := true) -> Control:
	if node is Button and (node as Button).text.replace(" ", "") == text.replace(" ", ""):
		return node as Control
	if node is Label and (node as Label).text == text:
		var parent := node.get_parent() as Control
		if parent != null and (not interactive or not parent.gui_input.get_connections().is_empty()): return parent
	for child in node.get_children():
		var button := _find_button(child,text,interactive)
		if button != null: return button
	return null


class FailedSaveHost extends "res://src/autoload/G.gd":
	func save_game() -> bool:
		return false
