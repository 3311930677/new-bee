# Actual input continuation from the verified s01-s28 save. No task/position injection.
extends "res://tools/PlaythroughMainWorld.gd"

const THIRD_SIDE_IDS := ["a3_rel_brazier","a3_rel_nameplate","a3_eco_lichen",
	"a3_eco_vents","a3_trade_parcel","a3_secret_echo"]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role_id = String(args[0]) if args.size() > 0 else "zs"
	phase = String(args[1]) if args.size() > 1 else "a"
	act3 = true
	act3_front = true
	act2 = true
	var source_dir := ""
	G.SAVE_PATH = "res://tools/_logs/save_playthrough_%s_%s.json" % [role_id,phase]
	for arg in args:
		if arg.begins_with("--save-dir="):
			G.SAVE_PATH = arg.trim_prefix("--save-dir=").path_join("save_playthrough_%s_%s.json" % [role_id,phase])
		if arg.begins_with("--source-dir="): source_dir = arg.trim_prefix("--source-dir=")
	await get_tree().process_frame
	get_tree().current_scene = null
	if phase == "b":
		await _run_phase_b()
		return
	var source := source_dir.path_join("save_playthrough_%s_a.json" % role_id)
	var raw := FileAccess.get_file_as_string(source)
	var saved: Variant = JSON.parse_string(raw)
	if not (saved is Dictionary) or (saved as Dictionary).get("selected_role","") != role_id:
		_bad("缺少对应职业的已验收续档")
		return
	if ((saved as Dictionary).get("prog",{}).get("story",{}).get("done",[]) as Array).size() != 28:
		_bad("续档不是完整28步")
		return
	var file := FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
	if file == null:
		_bad("隔离续档不能写入")
		return
	file.store_string(raw)
	file.close()
	print("PLAY_SETUP verified_source=%s sha256=%s role=%s" % [source,FileAccess.get_sha256(source),role_id])
	if not G.reload_save() or not await _enter_world("","","frost_post"):
		_bad("续档不能进霜关")
		return
	if not await _side_talk("npc_frost_guard","a3_rel_brazier",QuestService.SIDE_ACTIVE): return
	if not await _side_visit("a3_wind_lamp","a3_rel_brazier"): return
	if not await _choose_lamp(): return
	if not await _side_talk("npc_frost_miner","a3_rel_nameplate",QuestService.SIDE_ACTIVE): return
	if not await _side_talk("npc_frost_envoy","a3_eco_lichen",QuestService.SIDE_ACTIVE): return
	if not await _side_talk("npc_frost_miner","a3_eco_vents",QuestService.SIDE_ACTIVE): return
	if not await _exit_to("frost_post",Vector2(864,710),"rift_mine_road"): return
	for target in [["a3_dropped_plate","a3_rel_nameplate"],["a3_vent_south","a3_eco_vents"],["a3_vent_north","a3_eco_vents"]]:
		if not await _side_visit(String(target[0]),String(target[1])): return
	if G.item_count("frost_nameplate") != 1:
		_bad("实际拾取名牌没有入栏")
		return
	if not await _exit_to("rift_mine_road",Vector2(90,710),"frost_post"): return
	if not await _side_talk("npc_frost_miner","a3_rel_nameplate",QuestService.SIDE_DONE): return
	if not await _side_talk("npc_frost_guard","a3_secret_echo",QuestService.SIDE_ACTIVE): return
	if not await _side_talk("npc_frost_miner","a3_eco_vents",QuestService.SIDE_DONE): return
	if not await _exit_to("frost_post",Vector2(480,96),"frost_boardwalk"): return
	for eid in ["a3_lichen_south","a3_lichen_north"]:
		if not await _side_visit(eid,"a3_eco_lichen"): return
	if not await _exit_to("frost_boardwalk",Vector2(480,96),"frost_pass"): return
	for eid in ["a3_echo_south","a3_echo_north"]:
		if not await _side_visit(eid,"a3_secret_echo"): return
	if not _map._monsters.is_empty():
		_bad("已清雪幕领主不应因支线重刷")
		return
	if not await _exit_to("frost_pass",Vector2(480,1152),"frost_boardwalk"): return
	if not await _exit_to("frost_boardwalk",Vector2(480,1152),"frost_post"): return
	if not await _side_talk("npc_frost_envoy","a3_eco_lichen",QuestService.SIDE_DONE): return
	if not await _side_talk("npc_frost_guard","a3_secret_echo",QuestService.SIDE_DONE): return
	if not await _side_talk("npc_frost_envoy","a3_trade_parcel",QuestService.SIDE_ACTIVE): return
	if G.item_count("frost_parcel") != 1:
		_bad("实际接药包没有入栏")
		return
	if not await _exit_to("frost_post",Vector2(480,1152),"red_sand_route"): return
	if not await _side_visit("a3_cold_courier","a3_trade_parcel"): return
	if not await _exit_to("red_sand_route",Vector2(480,96),"frost_post"): return
	if not await _close_city_modal() or not G.save_game() or not G.reload_save():
		_bad("最终支线续档未落盘")
		return
	if not _all_done(): return
	_release_all()
	print("PLAY_A_STATE " + JSON.stringify(_state()))
	print("PLAY_A_OK role=%s side_done=6 main_done=28" % role_id)
	get_tree().quit()

func _side_talk(npc_id: String, qid: String, status: String) -> bool:
	if not await _close_city_modal(): return _bad("支线途中不能关面板")
	for attempt in 20:
		if G.side_status_of(qid) == status:
			print("PLAY_EVENT side_npc qid=%s status=%s npc=%s" % [qid,status,npc_id])
			return await _close_city_modal()
		# 关闭上一托付后必须真实走出 NPC 的 90px 重触发距离。
		# 沿主街离开再返回，不修改 cooled，也不绕过受阻导航。
		if _map._player.position.distance_to(_npc_pos(npc_id)) <= 90.0:
			if await _travel(Vector2(480,710),20.0,true) != "ok":
				return _bad("离开上次 NPC 对话范围失败：" + qid)
			print("PLAY_EVENT npc_rearm real_walk=true npc=" + npc_id)
		var result := await _travel(_npc_pos(npc_id),20.0,true,false)
		if result != "ok": return _bad("支线 NPC 导航失败：" + qid + " " + result)
		if not await _close_city_modal(): return false
		await _wait_frames(4)
	return _bad("支线 NPC 未推进：" + qid)

func _side_visit(eid: String, qid: String) -> bool:
	if not await _close_city_modal(): return false
	var seen: Array = QuestService.side_get(G.act1_state(),qid).get("seen",[])
	if seen.has(eid) or G.side_status_of(qid) == QuestService.SIDE_DONE:
		print("PLAY_EVENT side_entity qid=%s eid=%s traversed=true" % [qid,eid])
		return true
	var entity: Node2D = null
	for candidate in _map._quest_entities:
		if not is_instance_valid(candidate): continue
		if candidate.eid == eid: entity = candidate
	if entity == null: return _bad("缺少支线地图实体：" + eid)
	var at := entity.position
	if await _travel(at,20.0,true) != "ok": return _bad("支线地图实体不可达：" + eid)
	for frame in 120:
		var state := QuestService.side_get(G.act1_state(),qid)
		if (state.get("seen",[]) as Array).has(eid) or G.side_status_of(qid) == QuestService.SIDE_DONE:
			print("PLAY_EVENT side_entity qid=%s eid=%s real_input=true" % [qid,eid])
			return true
		await get_tree().physics_frame
	return _bad("实际走近未调查：" + eid)

func _choose_lamp() -> bool:
	for attempt in 20:
		if not _city_modal():
			if await _travel(_npc_pos("npc_frost_guard"),20.0,true,false) != "ok": return _bad("修灯返程不可达")
		if _city_modal():
			var label := _find_label(_map._city_content.get("_panel"),[G._button_text("挡风 · 省炭守灯")])
			if label != null:
				if not await _click_until(label.get_parent() as Control,
					func() -> bool: return G.side_status_of("a3_rel_brazier") == QuestService.SIDE_DONE,40,"lamp_choice"):
					return _bad("实际修灯按钮未交付")
				print("PLAY_EVENT side_choice shield real_click=true")
				return await _close_city_modal()
			if not await _close_city_modal(): return false
	return _bad("未找到实际挡风选项")

func _all_done() -> bool:
	for qid in THIRD_SIDE_IDS:
		if G.side_status_of(qid) != QuestService.SIDE_DONE: return _bad("支线未完成：" + qid)
	if G.item_count("frost_nameplate") != 0 or G.item_count("frost_parcel") != 0:
		return _bad("支线交付物残留")
	if G.prog.flags.get("act3_brazier_choice","") != "shield": return _bad("风灯选择未保存")
	return true

func _run_phase_b() -> void:
	if not G.reload_save() or not _all_done(): return
	var gold := int(G.wallet.gold)
	for qid in THIRD_SIDE_IDS:
		var result := RewardLedger.apply(RewardLedger.make(RewardLedger.tx_id("side",qid,"complete"),{},
			{"gold":9999},{}),G.ledger(),G)
		if not bool(result.get("duplicate",false)) or int(G.wallet.gold) != gold:
			_bad("跨进程支线奖励没有判重：" + qid)
			return
	print("PLAY_EVENT side_idempotent_replay count=6 gold_unchanged=true")
	await super._run_phase_b()

func _state() -> Dictionary:
	var result := super._state()
	result["third_side"] = {}
	for qid in THIRD_SIDE_IDS: result.third_side[qid] = QuestService.side_get(G.act1_state(),qid).duplicate(true)
	result["brazier_choice"] = G.prog.flags.get("act3_brazier_choice","")
	result["frost_nameplate"] = G.item_count("frost_nameplate")
	result["frost_parcel"] = G.item_count("frost_parcel")
	return result
