# Synthetic fixtures exercise transaction boundaries; PlaythroughFourthBack uses real s32 saves.
extends "res://tools/VerifyThirdBack.gd"

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_fourth_back.json"
	await get_tree().process_frame
	await _run()
	print("FOURTH_BACK_OK" if _fails == 0 else "FOURTH_BACK_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _reset() -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "归路行者"
	G.ensure_starter_buildings()
	G.ensure_starter_equip(true)
	var done: Array = []
	for n in range(1,33): done.append("s%02d" % n)
	G.prog.story = {"step":"","done":done,"goals":{}}
	for n in range(1,33): CampaignGrowth.mark(G.prog,"s%02d" % n)
	G.prog.level = 49
	G.prog.exp = 90
	G.prog.flags = {"act4_depth_ready":true,"act4_preparation":"listen"}
	G.items.stele_key = 1
	G.wallet.gold = 777
	G.campaign_gear_claim(false)

func _entity(map: MapScene, id: String) -> Node2D:
	for e in map._quest_entities:
		if e.eid == id and not e.used: return e
	return null

func _puzzle(map: MapScene, id: String, flag: String) -> void:
	var e := _entity(map,id)
	_check(e != null,"机关必须可见 " + id)
	if e != null: map.on_quest_entity(e)
	await get_tree().process_frame
	_check(bool(G.prog.flags.get(flag,false)),"机关触发保存 " + id)
	var before := G.prog.duplicate(true)
	G.world_puzzle_interact(map._main_map_id,id)
	_check(before == G.prog,"机关不得二次写奖励 " + id)

func _encounter(map: MapScene, mon: Node2D) -> void:
	map._contact_mon = mon
	map._last_battle_tier = "boss"
	map._last_battle_optional = mon.optional
	map._encounter = WorldSession.new_encounter(map._main_map_id,mon.idx,mon.position,mon.mon_id,
		mon.display_level,map._player.position,"",0,Time.get_ticks_usec())
	WorldSession.advance(map._main_world_state(),map._encounter,WorldSession.ST_BATTLE)

func _run() -> void:
	_reset()
	var before := G.prog.duplicate(true)
	_check(G.story_current().get("id","") == "s33" and G.prog.level == before.level and G.items.stele_key == 1 and G.wallet.gold == 777,"32步旧档只续接，不查询领奖")
	var entry := await _enter("stele_entry")
	await get_tree().process_frame
	_check(G.story_step_done("s33") and G.item_count("stele_key") == 0 and G.prog.level == 50,"首次入门消费归路凭证，达到50级")
	_check(entry._monsters.is_empty() and _entity(entry,"return_anchor") != null,"门厅避战且首次入房即可见锚")
	entry._player.position = Vector2(480,96)
	entry._check_world_exits()
	_check(not entry._map_done,"锚未亮时北门锁住，南门可返")
	var puzzle_before := G.prog.duplicate(true)
	G.save_locked = true
	_check(not bool(G.world_puzzle_interact("stele_entry","return_anchor").get("ok",false)) and G.prog == puzzle_before,"机关保存被锁不留半份状态")
	G.save_locked = false
	await _puzzle(entry,"return_anchor","act4_return_anchor")
	entry.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(),"锚点真实重读")
	entry = await _enter("stele_entry")
	_check(G.item_count("stele_key") == 0 and _entity(entry,"return_anchor") == null,"再次进门不重消费，已亮锚不复现")
	entry.queue_free()
	await get_tree().process_frame
	var hall := await _enter("stele_resonance")
	_check(hall._monsters.is_empty() and _entity(hall,"forest_voice") != null and _entity(hall,"tide_voice") == null,"三声按顺序显现")
	_check(G.story_event("observe","aligned_voices","stele_resonance").is_empty(),"缺少声碑不得跳过汇声")
	await _puzzle(hall,"forest_voice","act4_forest_voice")
	await _puzzle(hall,"tide_voice","act4_tide_voice")
	await _puzzle(hall,"snow_voice","act4_snow_voice")
	var aligned := _entity(hall,"aligned_voices")
	_check(aligned != null,"三声齐后汇声座出现")
	if aligned != null: hall.on_quest_entity(aligned)
	_check(G.story_step_done("s34") and G.item_count("stable_seal") == 1 and G.prog.level == 53,"汇声发封记、三声护甲与53级")
	_check(CampaignGear.claim_plan(G.prog,"zs").is_empty(),"满背包时护甲仍在实例或待领箱")
	var saved := G.prog.duplicate(true)
	_check(G.reload_save() and G.prog.story == saved.story and G.prog.flags == saved.flags and G.item_count("stable_seal") == 1,"机关与封记跨存取保留")
	hall.queue_free()
	await get_tree().process_frame
	var core := await _enter("stele_core")
	_check(core._monsters.size() == 1 and core._monsters[0].mon_id == "mon_abyss_avatar","碑心只有原创剧情首领")
	_check(not core._boss_flee_blocked("boss",false),"新剧情首领允许真实撤退恢复")
	var mon := core._monsters[0]
	_encounter(core,mon)
	var battle_before := G.prog.duplicate(true)
	var wallet_before := G.wallet.duplicate(true)
	var items_before := G.items.duplicate(true)
	G.items.erase("stable_seal")
	_check(core._settle_main_world("boss",mon.mon_id) == "quest_missing" and not core._main_boss_cleared(),"缺封记不得标记首领清除")
	G.items = items_before.duplicate(true)
	G.save_locked = true
	_check(core._settle_main_world("boss",mon.mon_id) == "save_failed" and G.prog == battle_before and G.wallet == wallet_before and G.items == items_before,"被锁结算退回首领/战利/封记/账本")
	G.save_locked = false
	var original_path := G.SAVE_PATH
	var print_errors := Engine.print_error_messages
	# The absent parent makes the actual atomic save fail without touching any player file.
	G.SAVE_PATH = "res://tools/_logs/absent_fourth_back_write_parent/save.json"
	Engine.print_error_messages = false
	var disk_result := core._settle_main_world("boss",mon.mon_id)
	Engine.print_error_messages = print_errors
	G.SAVE_PATH = original_path
	print("FOURTH_DISK_ROLLBACK rejected=%s prog=%s wallet=%s items=%s" % [disk_result=="save_failed",G.prog==battle_before,G.wallet==wallet_before,G.items==items_before])
	_check(disk_result == "save_failed" and G.prog == battle_before and G.wallet == wallet_before and G.items == items_before,"真实写盘失败退回首领/战利/封记/账本")
	print("FOURTH_DISK_ROLLBACK_CHECKED expected_io_rejection=true")
	_check(core._settle_main_world("boss",mon.mon_id) == "ok" and G.story_step_done("s35") and G.item_count("stable_seal") == 0 and G.item_count("stele_record") == 1 and G.prog.level == 57,"首通一步事务消费封记并发记录和职业武器")
	var once := {"prog":G.prog.duplicate(true),"wallet":G.wallet.duplicate(true),"items":G.items.duplicate(true)}
	_check(core._settle_main_world("boss",mon.mon_id) == "dup" and G.prog == once.prog and G.wallet == once.wallet and G.items == once.items,"重复上报不再奖励")
	core.queue_free()
	await get_tree().process_frame
	_check(G.reload_save() and G.item_count("stele_record") == 1,"首通和记录真实存取")
	core = await _enter("stele_core")
	_check(core._monsters.is_empty(),"首通后重进不复活剧情首领")
	core.queue_free()
	await get_tree().process_frame
	var before_ending := {"prog":G.prog.duplicate(true),"wallet":G.wallet.duplicate(true),"items":G.items.duplicate(true)}
	for choice in ["seal","echo"]:
		G.prog = before_ending.prog.duplicate(true)
		G.wallet = before_ending.wallet.duplicate(true)
		G.items = before_ending.items.duplicate(true)
		var town := await _enter("lorin_wilds")
		var city: CityScene = town._city_content
		city._open_dialog({"id":"npc_steward","name":"闻叔"},false)
		_check(not G.story_step_done("s36"),"结局必须等待显式选择")
		var button := _find_button(city._panel,"封渊留路" if choice == "seal" else "留声守望")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		if button != null: button.gui_input.emit(event)
		_check(button != null and G.story_step_done("s36") and G.prog.story.done.size() == 36 and G.prog.level == 60 and G.item_count("stele_record") == 0,"两选项均完成36步60级 " + choice)
		_check(G.prog.flags.get("act4_ending","") == choice and bool(G.prog.flags.get("campaign_complete",false)),"结局世界旗 " + choice)
		for npc in ["npc_steward","npc_harbormaster","npc_frost_envoy"]:
			_check(not city._campaign_response(npc).is_empty(),"三城回应 " + npc)
		city._close_panel()
		city._open_abyss_boss_codex()
		_check(city._panel != null and MonsterArt.texture("mon_abyss_avatar") != null and MonsterArt.texture("mon_nameless_warden") != null,"两首领原创图与图鉴入口")
		town.queue_free()
		await get_tree().process_frame
		_check(G.reload_save() and G.prog.flags.act4_ending == choice and G.story_current().is_empty(),"结局重读后自由探索")
	var ring := await _enter("abyss_ring")
	var optional: Node2D = null
	for m in ring._monsters:
		if m.mon_id == "mon_nameless_warden": optional = m
	_check(optional != null,"结局后巡界者才出现")
	if optional != null:
		_check(optional.display_level == 60 and optional.optional,"巡界者独立60级巢穴")
		_encounter(ring,optional)
		_check(ring._settle_main_world("boss",optional.mon_id) == "ok" and G.prog.flags.act4_nameless_down,"巡界者固定首胜落地")
		var first := G.prog.duplicate(true)
		_check(ring._apply_optional_first_kill(optional.mon_id).is_empty() and G.prog == first,"巡界者首胜只领一次")
		_check((G.act1_state().discoveries as Array).has(optional.mon_id),"巡界者图鉴解锁")
	ring.queue_free()
	await get_tree().process_frame
	# A failed disk write must roll back even after the reward transaction passed.
	var host := FailedSaveHost.new()
	host._init_state_defaults()
	host.selected_role = "zs"
	host.prog = before_ending.prog.duplicate(true)
	host.wallet = before_ending.wallet.duplicate(true)
	host.items = before_ending.items.duplicate(true)
	_check(host.story_event("talk","npc_steward","lorin_wilds",true,{"method":"seal"}).is_empty() and host.prog == before_ending.prog and host.wallet == before_ending.wallet and host.items == before_ending.items,"结局写盘失败完整回滚")
	host.free()
	_test_fourth_bosses()

func _test_fourth_bosses() -> void:
	for id in ["mon_abyss_avatar","mon_nameless_warden"]:
		var sim := BattleSim.new()
		sim.setup(417,{"role_id":"zs","level":53,"traits":[]},{"theme":"abyss","node_type":"boss","lead_mon":id,"solo":true,"display_level":53})
		var boss: Combatant = sim.alive_units("enemy")[0]
		var sk: Dictionary = boss.skills[0].def
		SkillSystem.enqueue_cast(sim,boss,sk)
		_check(int(sim.cast_queue[0].windup) == (90 if id == "mon_abyss_avatar" else 84),"首领预兆和真实前摇同源")
		sim.cast_queue.clear()
		SkillSystem.resolve_cast(sim,{"uid":boss.uid,"skill":sk})
		_check(boss.has_buff("break_window"),"蓄力攻击后出现可利用破绽")
		boss.hp = int(boss.get_max_hp()*.49)
		sim._apply_phases()
		var count := boss.skills.size()
		sim._apply_phases()
		_check(boss.skills.size() == count,"阶段只触发一次")
		if id == "mon_abyss_avatar":
			SkillSystem.resolve_cast(sim,{"uid":boss.uid,"skill":boss.skills[1].def})
			_check(sim.alive_units("enemy").size() == 4,"第二阶段真正召出三只余响")
			var echo: Combatant = sim.alive_units("enemy")[1]
			_check(echo.row == Combatant.ROW_FRONT,"三地余响可被近战击破")
			echo.take_damage(99999,boss,sim)
			_check(boss.get_buff("break_window").dur == 150,"击破余响给五秒本体破绽")
