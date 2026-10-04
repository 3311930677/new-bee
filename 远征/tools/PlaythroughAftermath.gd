# Continue a verified ending save exclusively through actual movement and UI input.
extends "res://tools/PlaythroughReturnJobs.gd"

var aftermath_ids:Array[String]=[]

func _ready()->void:
	print("PLAY_SETUP aftermath_runner_ready")
	var args:=OS.get_cmdline_user_args()
	role_id=String(args[0]) if args.size()>0 else "zs"
	phase=String(args[1]) if args.size()>1 else "a"
	var source_dir:=""
	for arg in args:
		if arg.begins_with("--source-dir="):source_dir=arg.trim_prefix("--source-dir=")
		if arg.begins_with("--save-dir="):G.SAVE_PATH=arg.trim_prefix("--save-dir=").path_join("save_playthrough_%s_%s.json"%[role_id,phase])
	await get_tree().process_frame
	get_tree().current_scene=null
	var old:Dictionary={}
	if phase=="a":
		var source:=source_dir.path_join("save_playthrough_%s_a.json"%role_id)
		var raw:=FileAccess.get_file_as_string(source)
		var parsed:Variant=JSON.parse_string(raw)
		if not parsed is Dictionary:return _bad("缺少真实结局源档")
		old=parsed
		if old.selected_role!=role_id or old.prog.story.done.size()!=36:return _bad("要求对应职业真实36步结局档")
		var file:=FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
		if file==null:return _bad("隔离存档不可写")
		file.store_string(raw)
		file.close()
		print("PLAY_SOURCE done_steps=36 sha256=%s"%FileAccess.get_sha256(source))
	if not G.reload_save() or G.save_locked:return _bad("余波存档不可读")
	for row in G.side_quest_rows():
		if not (row.get("steps",[]) as Array).is_empty():aftermath_ids.append(String(row.id))
	if aftermath_ids.size()!=12:return _bad("余波任务表不是十二条")
	if phase=="a":
		if not await _enter_world("","",String(G.prog.main_world.map_id)):return _bad("真实源档进图失败")
		for qid in aftermath_ids:
			if not await _walk_aftermath(qid):return
		for key in ["story","equip","pets","pet_stat","skills","talents","mounts","companions","skill_curriculum"]:
			if JSON.parse_string(JSON.stringify(G.prog.get(key)))!=old.prog.get(key):return _bad("余波破坏旧投入 "+key)
		for instance in old.prog.inventory.get("instances",[]):
			if JSON.parse_string(JSON.stringify(G.inv_find(int(instance.uid))))!=instance:return _bad("余波破坏旧装备 uid="+str(instance.uid))
		for key in old.prog.flags:
			if G.prog.flags.get(key)!=old.prog.flags[key]:return _bad("余波改变旧世界旗 "+key)
	for qid in aftermath_ids:
		if G.side_status_of(qid)!=QuestService.SIDE_DONE:return _bad("余波未完成 "+qid)
		var before:=G.wallet.duplicate(true)
		var result:=RewardLedger.apply(RewardLedger.make(RewardLedger.tx_id("side",qid,"complete"),{},{"gold":9999},{}),G.ledger(),G)
		if not bool(result.get("duplicate",false)) or G.wallet!=before:return _bad("跨进程余波领奖不幂等 "+qid)
	if phase=="a" and not G.save_game():return _bad("余波终态未落盘")
	var state:Dictionary={"role":G.selected_role,"prog":G.prog,"wallet":G.wallet,"items":G.items}
	print("PLAY_%s_STATE "%phase.to_upper()+JSON.stringify(JSON.parse_string(JSON.stringify(state))))
	print("PLAY_%s_OK role=%s aftermath=12 real_input=true"%[phase.to_upper(),role_id])
	if phase=="b":print("PLAY_OK aftermath_restart")
	get_tree().quit(0)

func _walk_aftermath(qid:String)->bool:
	var row:=QuestService.side_row(G.side_quest_rows(),qid)
	if G.side_status_of(qid)==QuestService.SIDE_DONE:return true
	if not await _go_map(String(row.turn_in_map)):return false
	if not await _select_npc_job(String(row.giver),qid):return false
	if G.side_status_of(qid)==QuestService.SIDE_READY:
		if not await _selected_button("交付 · 领取报酬",func():return G.side_status_of(qid)==QuestService.SIDE_DONE):return false
		print("PLAY_EVENT aftermath_done qid=%s real_input=true resume_ready=true"%qid)
		return await _close_city_modal()
	if G.side_status_of(qid).is_empty():
		if not await _selected_button("接下这份托付",func():return G.side_status_of(qid)==QuestService.SIDE_ACTIVE):return false
	if G.side_status_of(qid)==QuestService.SIDE_ACTIVE:
		if not await _selected_button("追踪这份托付",func():return G.side_tracked()==qid):return false
	if not await _close_city_modal():return false
	while G.side_status_of(qid)==QuestService.SIDE_ACTIVE:
		var progress:=QuestService.side_get(G.act1_state(),qid)
		var objective:=QuestService.side_objective(row,progress)
		if not await _go_map(String(objective.map)):return false
		var target:Node2D=null
		for entity in _map._quest_entities:
			if is_instance_valid(entity) and entity.eid==String(objective.target_entity):target=entity
		if target==null:return _bad("余波实际地图缺目标 "+String(objective.target_entity))
		# Southern city meetings are reached from the public street below the shop fronts.
		if String(_map._main_map_id)=="shenyuan_port" and target.position.y>950:
			if not await _move_to(Vector2(480,1050),12):return false
		var before:=int(progress.progress)
		for attempt in 20:
			if int(QuestService.side_get(G.act1_state(),qid).progress)>before:break
			# Closing a city window rebuilds quest entities; resolve the live node again.
			target=null
			for entity in _map._quest_entities:
				if is_instance_valid(entity) and entity.eid==String(objective.target_entity):target=entity
			if target==null:return _bad("余波重建后缺目标 "+String(objective.target_entity))
			var status:=await _walk_to(target.position,20,3600)
			if status=="battle":
				if await _resolve_battle("win")!="victory":return _bad("余波途中战斗未胜")
			elif status=="modal":
				if _map._puzzle_panel!=null:
					var options:Dictionary=objective.get("choices",{})
					if options.is_empty():return _bad("任务途中出现非本任务机关")
					var choice:=String(objective.get("correct",""))
					if choice.is_empty():choice=String(options.keys()[0 if role_id=="zs" else options.size()-1])
					var label:=_find_label(_map._puzzle_panel,[String(options[choice]),G._button_text(String(options[choice]))])
					if label==null:return _bad("余波选择按钮不可见")
					if not await _click_until(label.get_parent() as Control,func():return int(QuestService.side_get(G.act1_state(),qid).progress)>before,40,"aftermath_choice"):return _bad("余波选择不推进")
				elif _city_modal():
					if not await _close_city_modal():return false
				elif not await _close_travel_modal():return false
			elif status in ["blocked","timeout"]:return _bad("余波目标行走受阻 "+String(objective.target_entity))
			await _wait_frames(6)
		if int(QuestService.side_get(G.act1_state(),qid).progress)<=before:return _bad("余波实体未推进 "+String(objective.target_entity))
		print("PLAY_EVENT aftermath_entity qid=%s eid=%s real_input=true"%[qid,String(objective.target_entity)])
	if not await _go_map(String(row.turn_in_map)):return false
	if not await _select_npc_job(String(row.turn_in),qid):return false
	if not await _selected_button("交付 · 领取报酬",func():return G.side_status_of(qid)==QuestService.SIDE_DONE):return false
	print("PLAY_EVENT aftermath_done qid=%s real_input=true"%qid)
	return await _close_city_modal()

func _selected_button(text:String,condition:Callable)->bool:
	var label:=_find_label(_map._city_content._panel,[text,G._button_text(text)])
	if label==null:return _bad("选定托付缺操作按钮 "+text)
	if not await _click_until(label.get_parent() as Control,condition,40,"aftermath_"+text):return _bad("选定托付按钮未生效 "+text)
	return true

func _select_npc_job(npc:String,qid:String)->bool:
	if not await _close_city_modal():return false
	# Reopen through walking outside the NPC contact ring, just as a player would.
	var npc_at:=_npc_pos(npc)
	if _map._player.position.distance_to(npc_at)<90:
		if not await _move_to(Vector2(480,npc_at.y),6):return false
	if npc in ["npc_port_worker","npc_port_keeper"] and not await _move_to(Vector2(480,1050),20):return false
	for attempt in 30:
		if not _city_modal() and await _travel(_npc_pos(npc),20,true,false)!="ok":return _bad("余波NPC不可达 "+npc)
		if not _city_modal():continue
		var button:=_job_by_id(_map._city_content._panel,qid)
		if button!=null:
			var scroll:=button.get_parent().get_parent() as ScrollContainer
			if scroll!=null:scroll.ensure_control_visible(button)
			await _wait_frames(2)
			return await _click_until(button,func():return _find_label(_map._city_content._panel,[String(QuestService.side_row(G.side_quest_rows(),qid).title)])!=null,40,"aftermath_select")
		var entry:=_find_label(_map._city_content._panel,["其他托付","沿路托付"])
		if entry!=null:
			var old_panel:int=_map._city_content._panel.get_instance_id()
			if not await _click_until(entry.get_parent() as Control,func():return _map._city_content._panel!=null and _map._city_content._panel.get_instance_id()!=old_panel,40,"aftermath_list"):return _bad("实际托付列表未打开")
			if _job_by_id(_map._city_content._panel,qid)==null and not await _close_city_modal():return false
			continue
		if not await _close_city_modal():return false
	return _bad("未能从实际NPC入口选到 "+qid)

func _job_by_id(node:Node,qid:String)->Control:
	if node==null:return null
	if node is Control and String(node.get_meta("side_job_id",""))==qid:return node
	for child in node.get_children():
		var result:=_job_by_id(child,qid)
		if result!=null:return result
	return null

func _go_map(target:String)->bool:
	if not await _close_city_modal():return false
	var current:=String(_map._main_map_id)
	if current==target:return true
	var queue:Array=[current]
	var previous:Dictionary={current:""}
	while not queue.is_empty() and not previous.has(target):
		var mid:=String(queue.pop_front())
		for exit in TableCache.main_world_map(mid).get("exits",[]):
			var next:=String(exit.to)
			if not previous.has(next):
				previous[next]=mid
				queue.append(next)
	if not previous.has(target):return _bad("不存在实际地图出口路径 "+target)
	var route:Array[String]=[target]
	while route[0]!=current:route.push_front(String(previous[route[0]]))
	for i in range(route.size()-1):
		var mid:=route[i]
		var next:=route[i+1]
		var at:=Vector2.ZERO
		for exit in TableCache.main_world_map(mid).exits:
			if String(exit.to)==next:at=Vector2(float(exit.at[0]),float(exit.at[1]))
		if mid in ["maple_road","old_salt_road"]:
			if not await _move_to(Vector2(480,660 if mid=="maple_road" else 500),24):return false
		if not await _exit_to(mid,at,next):return false
	return true
