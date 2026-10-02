# Real ending-save continuation, walking and clicking every new job. No progression injection.
extends "res://tools/PlaythroughFourthBack.gd"

const JOB_IDS:=["a4_rel_waylight","a4_rel_letter","a4_eco_tidebuds","a4_eco_snowflowers","a4_trade_reply","a4_secret_runes"]

func _ready() -> void:
	var args:=OS.get_cmdline_user_args()
	role_id=String(args[0]) if args.size()>0 else "zs"
	phase=String(args[1]) if args.size()>1 else "a"
	var source_dir:=""
	G.SAVE_PATH="res://tools/_logs/save_return_jobs_%s_%s.json" % [role_id,phase]
	for arg in args:
		if arg.begins_with("--source-dir="): source_dir=arg.trim_prefix("--source-dir=")
		if arg.begins_with("--save-dir="): G.SAVE_PATH=arg.trim_prefix("--save-dir=").path_join("save_playthrough_%s_%s.json" % [role_id,phase])
	await get_tree().process_frame
	get_tree().current_scene=null
	var old:Dictionary={}
	if phase=="a":
		var source:=source_dir.path_join("save_playthrough_%s_a.json" % role_id)
		var raw:=FileAccess.get_file_as_string(source)
		var parsed:Variant=JSON.parse_string(raw)
		if not parsed is Dictionary: return _bad("缺少真实结局源档")
		old=parsed
		if old.selected_role!=role_id or old.prog.story.done.size()!=36: return _bad("源档必须为对应职业真实36步结局档")
		var file:=FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
		file.store_string(raw)
		file.close()
		print("PLAY_SOURCE done_steps=36 sha256=%s" % FileAccess.get_sha256(source))
	if not G.reload_save() or G.save_locked: return _bad("归路托付隔离档不可读")
	if phase=="a":
		if not await _walk_jobs(): return
		for key in ["story","inventory","equip","pets","pet_stat","skills","talents","mounts","companions","skill_curriculum"]:
			if JSON.parse_string(JSON.stringify(G.prog.get(key)))!=old.prog.get(key): return _bad("破坏旧进度/投入 "+key)
		for key in old.prog.flags:
			if G.prog.flags.get(key)!=old.prog.flags[key]: return _bad("破坏旧世界旗 "+key)
	for qid in JOB_IDS:
		if G.side_status_of(qid)!=QuestService.SIDE_DONE: return _bad("托付未完成 "+qid)
		var before:=G.wallet.duplicate(true)
		var res:=RewardLedger.apply(RewardLedger.make(RewardLedger.tx_id("side",qid,"complete"),{},{"gold":9999},{}),G.ledger(),G)
		if not bool(res.get("duplicate",false)) or G.wallet!=before: return _bad("跨进程托付奖励不幂等 "+qid)
	if G.item_count("return_mailbag")!=0 or G.item_count("return_old_letter")!=0: return _bad("任务物交付未消费")
	if phase=="a" and not G.save_game(): return _bad("归路托付终态未写盘")
	var state:Dictionary={"role":G.selected_role,"prog":G.prog,"wallet":G.wallet,"items":G.items}
	print("PLAY_%s_STATE " % phase.to_upper()+JSON.stringify(JSON.parse_string(JSON.stringify(state))))
	print("PLAY_%s_OK role=%s return_jobs=6 real_input=true" % [phase.to_upper(),role_id])
	if phase=="b": print("PLAY_OK return_jobs_restart")
	get_tree().quit(0)

func _walk_jobs() -> bool:
	if G.side_status_of("a4_rel_waylight")==QuestService.SIDE_DONE and G.side_status_of("a4_rel_letter")==QuestService.SIDE_READY:
		print("PLAY_EVENT continuation_from_real_letter_checkpoint")
		return await _finish_jobs_from_letter()
	if not await _enter_world("","","stele_core"): return _bad("结局源档不在碑心返访处")
	if not await _back_to_ring() or not await _homeward(): return false
	if not await _job_click("npc_guard","a4_rel_waylight","接下这份托付",QuestService.SIDE_ACTIVE): return false
	if not await _job_click("npc_scribe","a4_trade_reply","接下这份托付",QuestService.SIDE_ACTIVE): return false
	if not await _exit_to("lorin_wilds",Vector2(480,96),"maple_road"): return false
	if not await _job_visit("a4_waylight","a4_rel_waylight"): return false
	if not await _move_to(Vector2(480,660),24): return false
	if not await _exit_to("maple_road",Vector2(864,660),"old_salt_road"): return false
	if not await _move_to(Vector2(480,500),24): return false
	if not await _exit_to("old_salt_road",Vector2(864,660),"shenyuan_port"): return false
	if not await _job_click("npc_port_worker","a4_rel_letter","接下这份托付",QuestService.SIDE_ACTIVE): return false
	if not await _job_click("npc_port_keeper","a4_eco_tidebuds","接下这份托付",QuestService.SIDE_ACTIVE): return false
	# Return west along the public route, then pick up the salt-cart letter on the eastbound leg.
	if not await _exit_to("shenyuan_port",Vector2(90,660),"old_salt_road"): return false
	if not await _exit_to("old_salt_road",Vector2(90,660),"maple_road"): return false
	if not await _move_to(Vector2(480,660),24): return false
	if not await _exit_to("maple_road",Vector2(480,1152),"lorin_wilds"): return false
	var light:="点灯 · 照夜归人" if role_id=="zs" else "刻石 · 留清楚路标"
	if not await _job_click("npc_guard","a4_rel_waylight",light,QuestService.SIDE_DONE): return false
	if not await _exit_to("lorin_wilds",Vector2(480,96),"maple_road"): return false
	if not await _move_to(Vector2(480,660),24): return false
	if not await _exit_to("maple_road",Vector2(864,660),"old_salt_road"): return false
	if not await _move_to(Vector2(480,500),24): return false
	if not await _job_visit("a4_old_letter","a4_rel_letter"): return false
	return await _finish_jobs_from_letter()

func _finish_jobs_from_letter() -> bool:
	if not G.reload_save(): return _bad("家书拾取后读档失败")
	if not await _enter_world("","","old_salt_road"): return false
	print("PLAY_EVENT job_letter_reloaded item=%d" % G.item_count("return_old_letter"))
	if not await _move_to(Vector2(480,500),24): return false
	if not await _exit_to("old_salt_road",Vector2(864,660),"shenyuan_port"): return false
	if not await _job_click("npc_port_worker","a4_rel_letter","交付 · 领取报酬",QuestService.SIDE_DONE): return false
	if not await _exit_to("shenyuan_port",Vector2(864,700),"tideflat"): return false
	for eid in ["a4_tidebud_south","a4_tidebud_north"]:
		if not await _job_visit(eid,"a4_eco_tidebuds"): return false
	if not await _exit_to("tideflat",Vector2(90,700),"shenyuan_port"): return false
	if not await _job_click("npc_port_keeper","a4_eco_tidebuds","交付 · 领取报酬",QuestService.SIDE_DONE): return false
	if not await _exit_to("shenyuan_port",Vector2(480,96),"red_sand_route"): return false
	if not await _exit_to("red_sand_route",Vector2(480,96),"frost_post"): return false
	if not await _job_visit("a4_reply_courier","a4_trade_reply"): return false
	if not await _job_click("npc_frost_guard","a4_eco_snowflowers","接下这份托付",QuestService.SIDE_ACTIVE): return false
	if not await _job_click("npc_frost_miner","a4_secret_runes","接下这份托付",QuestService.SIDE_ACTIVE): return false
	if not await _exit_to("frost_post",Vector2(480,96),"frost_boardwalk"): return false
	for eid in ["a4_snowflower_south","a4_snowflower_north"]:
		if not await _job_visit(eid,"a4_eco_snowflowers"): return false
	for route in [["frost_boardwalk",Vector2(480,96),"frost_pass"],["frost_pass",Vector2(864,660),"abyss_ring"],["abyss_ring",Vector2(480,96),"stele_entry"],["stele_entry",Vector2(480,96),"stele_resonance"],["stele_resonance",Vector2(480,96),"stele_core"]]:
		if not await _exit_to(route[0],route[1],route[2]): return false
	for eid in ["a4_rune_forest","a4_rune_tide","a4_rune_snow"]:
		if not await _job_visit(eid,"a4_secret_runes"): return false
	if not await _back_to_ring(): return false
	for route in [["abyss_ring",Vector2(480,1152),"frost_pass"],["frost_pass",Vector2(480,1152),"frost_boardwalk"],["frost_boardwalk",Vector2(480,1152),"frost_post"]]:
		if not await _exit_to(route[0],route[1],route[2]): return false
	if not await _job_click("npc_frost_guard","a4_eco_snowflowers","交付 · 领取报酬",QuestService.SIDE_DONE): return false
	var runes:="拓纹 · 留给后来人" if role_id=="zs" else "告别 · 让碑心歇息"
	if not await _job_click("npc_frost_miner","a4_secret_runes",runes,QuestService.SIDE_DONE): return false
	print("PLAY_EVENT return_jobs_all_done choices=%s/%s" % [G.prog.flags.act4_waylight,G.prog.flags.act4_rune_memory])
	return true

func _back_to_ring() -> bool:
	for route in [["stele_core",Vector2(480,1152),"stele_resonance"],["stele_resonance",Vector2(480,1152),"stele_entry"],["stele_entry",Vector2(480,1152),"abyss_ring"]]:
		if not await _exit_to(route[0],route[1],route[2]): return false
	return true

func _job_click(npc:String,qid:String,title:String,want:String) -> bool:
	if not await _close_city_modal(): return false
	# Port service NPCs stand south of their buildings; approach along the public street.
	if npc in ["npc_port_worker","npc_port_keeper"]:
		if not await _move_to(Vector2(480,1050),20): return false
	for attempt in 20:
		if not _city_modal() and await _travel(_npc_pos(npc),20,true,false)!="ok": return _bad("归路NPC不可达 "+npc)
		if _city_modal():
			var label:=_find_label(_map._city_content._panel,[title,G._button_text(title)])
			if label!=null:
				if not await _click_until(label.get_parent() as Control,func(): return G.side_status_of(qid)==want,40,"return_job_"+qid): return _bad("归路按钮未生效 "+qid)
				print("PLAY_EVENT job_click qid=%s title=%s real_input=true" % [qid,title])
				if want==QuestService.SIDE_ACTIVE:
					var tracking:=_find_label(_map._city_content._panel,["追踪这份托付"])
					if tracking==null or not await _click_until(tracking.get_parent() as Control,func(): return G.side_tracked()==qid,40,"return_job_track_"+qid): return _bad("托付追踪按钮未生效 "+qid)
					print("PLAY_EVENT job_track qid=%s real_input=true" % qid)
				return await _close_city_modal()
			if not await _close_city_modal(): return false
	return _bad("找不到托付按钮 "+qid)

func _job_visit(eid:String,qid:String) -> bool:
	if not await _close_city_modal(): return false
	var initial:=QuestService.side_get(G.act1_state(),qid)
	if (initial.get("seen",[]) as Array).has(eid) or G.side_status_of(qid)==QuestService.SIDE_DONE:
		print("PLAY_EVENT job_entity qid=%s eid=%s real_input=true reached_on_route=true" % [qid,eid])
		return true
	var target:Node2D=null
	for entity in _map._quest_entities:
		if is_instance_valid(entity) and entity.eid==eid: target=entity
	if target==null: return _bad("缺少托付实体 "+eid)
	if await _travel(target.position,20,true)!="ok": return _bad("托付实体不可达 "+eid)
	for frame in 120:
		var state:=QuestService.side_get(G.act1_state(),qid)
		if (state.get("seen",[]) as Array).has(eid) or G.side_status_of(qid)==QuestService.SIDE_DONE:
			print("PLAY_EVENT job_entity qid=%s eid=%s real_input=true" % [qid,eid])
			return true
		await get_tree().physics_frame
	return _bad("走近托付实体没有触发 "+eid)
