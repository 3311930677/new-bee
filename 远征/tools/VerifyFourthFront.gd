# 第四幕前半功能验收；合成28步夹具只用于状态边界，真实旧档由PlaythroughFourthFront验证。
extends "res://tools/VerifyThirdBack.gd"

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_fourth_front.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "渊口行者"
	G.ensure_starter_buildings()
	await get_tree().process_frame
	await _run()
	print("FOURTH_FRONT_OK" if _fails == 0 else "FOURTH_FRONT_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _run() -> void:
	var done: Array = []
	for n in range(1, 29): done.append("s%02d" % n)
	G.prog["story"] = {"step": "", "done": done, "goals": {}}
	G.prog["level"] = 42
	G.wallet.gold = 777
	G.items["pet_food"] = 3
	G.ensure_starter_equip(true)
	var before := G.prog.duplicate(true)
	_check(G.story_current().get("id", "") == "s29", "三幕空步骤旧档应只续接s29")
	for key in before:
		if key != "story": _check(G.prog[key] == before[key], "旧档续接保留 " + String(key))
	_check(G.prog.story.done == done and G.wallet.gold == 777 and G.items.pet_food == 3,
		"旧档查询不重奖、不改任务完成或资源")
	var pass_map := await _enter("frost_pass")
	pass_map._player.position = Vector2(864, 660)
	pass_map._check_world_exits()
	_check(not pass_map._map_done, "s29前不能从冰隘东口进入外环")
	pass_map.queue_free()
	await get_tree().process_frame
	var premature := await _enter("abyss_ring")
	_check(premature._quest_entities.is_empty() and not G.story_step_done("s30"),
		"提前构造外环不能跳过接事或生成调查实体")
	premature.queue_free()
	await get_tree().process_frame
	_check(not G.story_event("talk", "npc_frost_envoy", "frost_post").is_empty(), "宁砚接事推进s29")
	var ring := await _enter("abyss_ring")
	_check(G.story_step_done("s30") and ring._monsters.size() == 4,
		"进入外环推进s30并生成四只游荡明雷")
	for monster in ring._monsters:
		_check(monster.wander_only and int(monster.display_level) == 45,
			"外环明雷固定45级且只游荡")
	_check(ring._quest_entities.size() == 1, "s31生成唯一共鸣碑座")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = ring._player_shape.shape
	query.collision_mask = 2
	await get_tree().physics_frame
	for y in range(180, 1120, 40):
		query.transform = Transform2D(0, Vector2(480, y))
		_check(ring._player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "外环中心道路连通")
	query.transform = Transform2D(0, Vector2(80, 650))
	_check(not ring._player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "外环悬崖边界有实体阻挡")
	if not ring._quest_entities.is_empty():
		var entity = ring._quest_entities[0]
		var gold := int(G.wallet.gold)
		G.save_locked = true
		ring.on_quest_entity(entity)
		_check(not G.story_step_done("s31") and not entity.used and G.wallet.gold == gold, "调查锁写不吞实体或发奖")
		G.save_locked = false
		ring.on_quest_entity(entity)
		_check(G.story_step_done("s31") and G.item_count("rift_echo") == 1 and entity.used, "调查发回响并推进一次")
		gold = int(G.wallet.gold)
		ring.on_quest_entity(entity)
		_check(G.wallet.gold == gold and G.item_count("rift_echo") == 1, "重复触碰不重奖")
	ring.queue_free()
	await get_tree().process_frame
	_check(G.reload_save() and G.story_step_done("s31") and G.item_count("rift_echo") == 1, "调查进度与任务物跨读档保留")
	var revisit := await _enter("abyss_ring")
	_check(revisit._quest_entities.is_empty(), "读档重进外环不再生成已完成调查")
	revisit.queue_free()
	await get_tree().process_frame
	var snapshot := G.prog.duplicate(true)
	var wallet := G.wallet.duplicate(true)
	var items := G.items.duplicate(true)
	for method in ["listen", "brace"]:
		G.prog = snapshot.duplicate(true)
		G.wallet = wallet.duplicate(true)
		G.items = items.duplicate(true)
		var town := await _enter("lorin_wilds")
		var city: CityScene = town._city_content
		city._open_dialog(G.city_npc("npc_scribe"), false)
		_check(city._panel != null and not G.story_step_done("s32"), "青姨等待实际选择")
		var title := "先听回声" if method == "listen" else "先稳碑座"
		var button := _find_button(city._panel, title)
		_check(button != null, "准备方式应有可点击按钮 " + title)
		if button != null:
			var input := InputEventMouseButton.new()
			input.pressed = true
			input.button_index = MOUSE_BUTTON_LEFT
			button.gui_input.emit(input)
		_check(G.story_step_done("s32") and G.item_count("rift_echo") == 0
			and G.item_count("stele_key") == 1 and G.prog.flags.get("act4_preparation", "") == method,
			"两种准备均交回响、发凭证并记录选择")
		var settled_wallet := G.wallet.duplicate(true)
		_check(G.story_event("talk", "npc_scribe", "lorin_wilds", true, {"method": method}).is_empty()
			and G.wallet == settled_wallet, "准备选择完成后不得重奖")
		_check(G.reload_save() and G.prog.flags.get("act4_preparation", "") == method
			and G.item_count("stele_key") == 1, "准备方式与凭证跨读档保留")
		town.queue_free()
		await get_tree().process_frame
	var host := FailedSaveHost.new()
	host.prog = snapshot.duplicate(true)
	host.wallet = wallet.duplicate(true)
	host.items = items.duplicate(true)
	host.selected_role = "zs"
	_check(host.story_event("talk", "npc_scribe", "lorin_wilds", true, {"method": "brace"}).is_empty()
		and host.prog == snapshot and host.wallet == wallet and host.items == items,
		"准备写盘失败完整回滚任务、物品、旗与奖励")
	host.free()
