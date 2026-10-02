extends "res://tools/VerifyThirdBack.gd"

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_third_side.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "霜关托付"
	await _run()
	print("THIRD_SIDE_OK" if _fails == 0 else "THIRD_SIDE_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _chapter(n: int) -> void:
	var done: Array = []
	for i in range(1, n + 1): done.append("s%02d" % i)
	G.prog["story"] = {"step":"" if n == 28 else "s%02d" % (n + 1), "done":done,"goals":{}}
	# 本工具主动回退章节夹具时，也要移除回退之后的经验版本标记。
	# 新主线 s29 会被宁砚的真实对话推进；仅重置 story 会造出不可读的夹具。
	var marks: Dictionary = G.prog.get("campaign_growth", {}).get("story_revision", {})
	for id in marks.keys():
		if not done.has(id): marks.erase(id)

func _entity(map: MapScene, eid: String) -> Node2D:
	for ent in map._quest_entities:
		if ent.eid == eid: return ent
	return null

func _run() -> void:
	G.ensure_starter_equip(true)
	var legacy := {"a1_rel_guard":{"status":"done","progress":2,"seen":[]},
		"a2_rel_rope":{"status":"done","progress":1,"seen":["a2_loose_rope"],"choice":"retie"}}
	G.prog["act1"] = {"side_quests":legacy.duplicate(true),"repair_method":"forge"}
	_check(G.save_game() and G.reload_save(), "旧进度基线必须先真实保存并读取")
	legacy = (G.act1_state().side_quests as Dictionary).duplicate(true)
	var equipment: Dictionary = G.prog.get("equip", {}).duplicate(true)
	var rows: Array = []
	for row in G.side_quest_rows():
		if String(row.id).begins_with("a3_"): rows.append(row)
	_check(rows.size() == 6 and G.side_quest_rows().size() == 24, "霜关六条保留，归路托付扩为24条")
	_chapter(23)
	for row in rows: _check(not bool(G.side_accept(String(row.id)).get("ok",false)), "矿道记录前不可接霜关托付")
	_chapter(24)
	_check(not bool(G.side_accept("a3_secret_echo").get("ok",false)), "雪幕余痕必须等 s28 后开放")
	var npc_ids: Array = []
	for npc in TableCache._load("res://data/frost_post.json").npcs: npc_ids.append(npc.id)
	for row in rows:
		_check(npc_ids.has(row.giver), "霜关发布者必须是实际 NPC")
		var ents: Dictionary = TableCache.main_world_map(String(row.map)).get("entities",{})
		var targets: Array = row.objective.get("target_entities",[row.objective.get("target_entity","")])
		for eid in targets: _check(ents.has(eid) and ents[eid].quest == row.id, "支线目标必须有同任务实体")
	# 同图接取、明确两种风灯按钮、等值奖励和世界回应。
	var first_delta := -1
	for choice in ["coal","shield"]:
		G.prog["act1"] = {"side_quests":legacy.duplicate(true),"repair_method":"forge"}
		G.prog["ledger"] = {}
		G.prog["flags"] = {"act3_supply_choice":"merchant","act2_pier_rope":"retie"}
		G.wallet["gold"] = 1000
		var post := await _enter("frost_post")
		post._city_content._open_dialog(G.city_npc("npc_frost_guard"),false)
		_check(G.side_status_of("a3_rel_brazier") == QuestService.SIDE_ACTIVE, "岑雪真实对话应接风灯托付")
		var lamp := _entity(post,"a3_wind_lamp")
		_check(lamp != null, "同图接取后风灯应即时生成")
		post._city_content._close_panel()
		if lamp != null: post.on_quest_entity(lamp)
		_check(G.side_status_of("a3_rel_brazier") == QuestService.SIDE_READY, "实际风灯调查应可交付")
		post._city_content._open_dialog(G.city_npc("npc_frost_guard"),false)
		var title := "添炭 · 暖灯轮岗" if choice == "coal" else "挡风 · 省炭守灯"
		var button := _find_button(post._city_content._panel,G._button_text(title))
		_check(button != null and button.size.y >= 44, "真实修法按钮必须可点")
		var before_prog := G.prog.duplicate(true)
		var before_wallet := G.wallet.duplicate(true)
		G.save_locked = true
		if button != null: _press(button)
		_check(G.prog == before_prog and G.wallet == before_wallet, "锁盘点击不得保存选择或奖励")
		G.save_locked = false
		if button != null: _press(button)
		var delta := int(G.wallet.gold) - int(before_wallet.gold)
		if first_delta < 0: first_delta = delta
		_check(delta == first_delta and delta == 160, "两种风灯修法奖励必须等值")
		_check(G.side_status_of("a3_rel_brazier") == QuestService.SIDE_DONE
			and G.prog.flags.act3_brazier_choice == choice and G.prog.flags.act3_supply_choice == "merchant",
			"风灯完成旗不得改变主线供货选择")
		await get_tree().process_frame
		await get_tree().process_frame
		var ground_seen := false
		for child in post.get_children():
			if child.get_script() != null and child.get_script().resource_path == "res://src/explore/ThirdActGround.gd":
				ground_seen = String(child.get("_brazier_choice")) == choice
		_check(ground_seen and G.side_npc_line("npc_frost_guard").contains("岑雪"), "风灯和人物读取实际修法")
		_check(G.reload_save() and G.prog.flags.act3_brazier_choice == choice, "风灯读档保留选择")
		_check(G._side_complete("a3_rel_brazier",true,choice).is_empty(), "风灯重复交付不可重奖")
		post.queue_free()
		await get_tree().process_frame
	# 各条从实际发布者接取，再通过真实地图实体推进与 NPC 交付。
	for qid in ["a3_rel_nameplate","a3_eco_lichen","a3_eco_vents","a3_trade_parcel","a3_secret_echo"]:
		var row := QuestService.side_row(rows,qid)
		if qid == "a3_secret_echo": _chapter(28)
		var post := await _enter("frost_post")
		post._city_content._open_dialog(G.city_npc(String(row.giver)),false)
		_check(G.side_status_of(qid) == QuestService.SIDE_ACTIVE, "实际发布者应接取 " + qid)
		post.queue_free()
		await get_tree().process_frame
		var map := await _enter(String(row.map))
		if qid == "a3_trade_parcel":
			G.items.erase("frost_parcel")
			var courier := _entity(map,"a3_cold_courier")
			if courier != null: map.on_quest_entity(courier)
			_check(G.side_status_of(qid) == QuestService.SIDE_ACTIVE and _entity(map,"a3_cold_courier") != null,
				"缺药包不能成交或使接应人消失")
			G.items["frost_parcel"] = 1
		for entity in map._quest_entities.duplicate():
			if entity.quest != qid: continue
			var eid := String(entity.eid)
			map.on_quest_entity(entity)
			_check(not bool(G.side_entity_interact(String(row.objective.kind),eid,String(row.map),qid).get("ok",false)),
				"同一目标不可重复计数或发奖")
		if qid == "a3_rel_nameplate": _check(G.item_count("frost_nameplate") == 1, "名牌应实际入物品栏")
		map.queue_free()
		await get_tree().process_frame
		if qid != "a3_trade_parcel":
			var turn := await _enter("frost_post")
			if qid == "a3_eco_lichen":
				# s28 主线选择不被已经 ready 的宁砚支线夺走。
				G.prog.story.step = "s28"
				G.items["veil_seal"] = 1
				turn._city_content._open_dialog(G.city_npc("npc_frost_envoy"),false)
				var main_button := _find_button(turn._city_content._panel,"守关补给")
				_check(main_button != null and G.side_status_of(qid) == QuestService.SIDE_READY, "主线供货优先且不吞待交支线")
				if main_button != null: _press(main_button)
				turn._city_content._close_panel()
				_check(G.story_step_done("s28") and G.side_status_of(qid) == QuestService.SIDE_READY, "主线完成仍保留待交支线")
			turn._city_content._open_dialog(G.city_npc(String(row.turn_in)),false)
			turn.queue_free()
			await get_tree().process_frame
		_check(G.side_status_of(qid) == QuestService.SIDE_DONE, "地图目标加真实 NPC 应完成 " + qid)
		_check(G._side_complete(qid).is_empty(), "每条交付必须幂等")
	_check(G.item_count("frost_nameplate") == 0 and G.item_count("frost_parcel") == 0, "名牌与药包应真实交付消耗")
	_check(G.reload_save(), "霜关六支线最终档应可读")
	for row in rows: _check(G.side_status_of(String(row.id)) == QuestService.SIDE_DONE, "读档六支线应均完成")
	for qid in legacy: _check(QuestService.side_get(G.act1_state(),qid) == legacy[qid], "不得重置旧支线")
	_check(G.prog.get("equip",{}) == equipment, "支线不能更改已装备 UID")
	# 真正发物/发奖之后的失败存储，不只检查提前锁盘。
	for delivery in [false,true]:
		var host := FailedSaveHost.new()
		host._init_state_defaults()
		host.prog["story"] = {"step":"s25","done":["s24"],"goals":{}}
		var qid := "a3_trade_parcel" if delivery else "a3_rel_nameplate"
		QuestService.side_accept(host.act1_state(),host._side_live_rows(),qid)
		if delivery: host.items["frost_parcel"] = 1
		var prog := host.prog.duplicate(true)
		var wallet := host.wallet.duplicate(true)
		var items := host.items.duplicate(true)
		var result := host.side_entity_interact("deliver" if delivery else "collect",
			"a3_cold_courier" if delivery else "a3_dropped_plate",
			"red_sand_route" if delivery else "rift_mine_road",qid)
		_check(not bool(result.get("ok",false)) and host.prog == prog and host.wallet == wallet and host.items == items,
			"真实写盘失败必须回滚物品、奖励、进度和账本")
		host.free()

func _press(button: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	button.gui_input.emit(event)
