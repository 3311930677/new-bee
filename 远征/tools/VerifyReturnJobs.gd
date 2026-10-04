extends "res://tools/VerifyThirdBack.gd"

const IDS := ["a4_rel_waylight","a4_rel_letter","a4_eco_tidebuds","a4_eco_snowflowers","a4_trade_reply","a4_secret_runes"]

func _ready() -> void:
	G.SAVE_PATH="res://tools/_logs/save_verify_return_jobs.json"
	var source:="res://shots/fourth_back_20261002/evidence/final_ck/save_playthrough_ck_a.json"
	var file:=FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(source))
	file.close()
	await get_tree().process_frame
	_check(G.reload_save() and G.story_step_done("s36"),"真实结局档可读")
	var original:=G.prog.duplicate(true)
	var original_items:=G.items.duplicate(true)
	var original_wallet:=G.wallet.duplicate(true)
	var story:Dictionary=G.prog.story.duplicate(true)
	G.prog.story.done.erase("s36")
	G.prog.story.step="s36"
	for qid in IDS: _check(not bool(G.side_accept(qid).get("ok",false)),"结局前不可接 "+qid)
	G.prog.story=story
	_check(G.side_quest_rows().size()==36,"原24条保留，新增十二条余波")
	var sum_gold:=0
	for qid in IDS:
		var row:=QuestService.side_row(G.side_quest_rows(),qid)
		_check(G.return_job_row(String(row.giver)).id==qid,"实际NPC入口 "+qid)
		var town:=await _enter(String(row.turn_in_map) if qid!="a4_trade_reply" else "lorin_wilds")
		var city:CityScene=town._city_content
		city._close_panel()
		city._open_dialog(G.city_npc(String(row.giver)),false)
		_check(G.side_status_of(qid).is_empty(),"明确点击前不自动接取 "+qid)
		var accept:=_find_button(city._panel,"接下这份托付")
		_check(accept!=null and accept.size.y>=44,"接取按钮可见且触控足够")
		_click(accept)
		_check(G.side_status_of(qid)==QuestService.SIDE_ACTIVE,"实际按钮接取 "+qid)
		_click(_find_button(city._panel,"追踪这份托付"))
		_check(G.side_tracked()==qid,"实际按钮将新托付接入现有地图任务追踪 "+qid)
		city._close_panel()
		town.queue_free()
		await get_tree().process_frame
		var map:=await _enter(String(row.map))
		var ids:Array=row.objective.get("target_entities",[row.objective.get("target_entity","")])
		for eid in ids:
			var entity:=_entity(map,String(eid))
			_check(entity!=null,"地图生成任务实体 "+String(eid))
			if entity!=null: map.on_quest_entity(entity)
			await get_tree().process_frame
			var snapshot:=G.prog.duplicate(true)
			G.side_entity_interact(String(row.objective.kind),String(eid),String(row.map),qid)
			_check(G.prog==snapshot,"实体不能重复计数或奖励 "+String(eid))
			_check(G.reload_save(),"每个目标真实重读 "+String(eid))
		map.queue_free()
		await get_tree().process_frame
		var before_gold:=int(G.wallet.gold)
		if qid=="a4_trade_reply":
			_check(G.side_status_of(qid)==QuestService.SIDE_DONE and G.item_count("return_mailbag")==0 and G.prog.flags.act4_reply_route_open,"邮袋送达当场事务完成")
		else:
			_check(G.side_status_of(qid)==QuestService.SIDE_READY,"调查后可交付 "+qid)
			if qid=="a4_rel_letter":
				var snapshot:={"prog":G.prog.duplicate(true),"items":G.items.duplicate(true),"wallet":G.wallet.duplicate(true)}
				var path:=G.SAVE_PATH
				var print_errors:=Engine.print_error_messages
				G.SAVE_PATH="res://tools/_logs/absent_return_job_parent/save.json"
				Engine.print_error_messages=false
				var rejected:=G._side_complete(qid).is_empty()
				Engine.print_error_messages=print_errors
				G.SAVE_PATH=path
				_check(rejected and G.prog==snapshot.prog and G.items==snapshot.items and G.wallet==snapshot.wallet,"真实写盘拒绝保留家书/奖励/完成旗")
				print("RETURN_JOB_DISK_ROLLBACK_CHECKED expected_io_rejection=true")
			town=await _enter(String(row.turn_in_map))
			city=town._city_content
			city._close_panel()
			city._open_dialog(G.city_npc(String(row.giver)),false)
			var choice:="beacon" if qid=="a4_rel_waylight" else ("trace" if qid=="a4_secret_runes" else "")
			var title:=String(row.choices[choice].title) if not choice.is_empty() else "交付 · 领取报酬"
			var button:=_find_button(city._panel,G._button_text(title))
			_click(button)
			_check(button!=null and G.side_status_of(qid)==QuestService.SIDE_DONE,"实际按钮交付 "+qid)
			_check(int(G.wallet.gold)-before_gold==int(row.reward.gold),"一次固定奖励 "+qid)
			city._close_panel()
			town.queue_free()
			await get_tree().process_frame
		var after:=G.prog.duplicate(true)
		_check(G._side_complete(qid).is_empty() and G.prog==after,"交付不能重领 "+qid)
		sum_gold+=int(row.reward.gold)
		map=await _enter(String(row.map))
		for eid in ids: _check(_entity(map,String(eid))==null,"完成后目标不重生 "+String(eid))
		await get_tree().create_timer(.3).timeout
		if qid!="a4_rel_letter":
			var prop_count:=0
			for child in map._world.get_children():
				if child is ReturnJourneyProps: prop_count=child.get_child_count()
			_check(prop_count==ids.size(),"持久场景变化存在 "+qid)
		map.queue_free()
		await get_tree().process_frame
	_check(G.prog.story==original.story and G.prog.level==60,"结局与等级保持")
	for key in ["inventory","equip","pets","pet_stat","skills","talents","mounts","companions","skill_curriculum"]:
		_check(G.prog.get(key)==original.get(key),"保留原投入 "+key)
	for key in original.flags: _check(G.prog.flags[key]==original.flags[key],"保留旧世界旗 "+String(key))
	_check(int(G.wallet.gold)-int(original_wallet.gold)==sum_gold,"六条报酬无重复")
	_check(G.item_count("return_old_letter")==0 and G.item_count("return_mailbag")==0,"两件任务物交付消费")
	var completed:=G.prog.duplicate(true)
	_check(G.reload_save() and G.prog==completed,"全部支线完整重读")
	var port:=await _enter("shenyuan_port")
	var keeper:CityScene=port._city_content
	keeper._close_panel()
	keeper._open_dialog(G.city_npc("npc_port_keeper"),false)
	_click(_find_button(keeper._panel,"原有事务"))
	_check(_has_text(keeper._panel,"潮羽孵化") and G.prog==completed,"新任务保留原有孵化服务入口且不改变进度")
	keeper._close_panel()
	port.queue_free()
	await get_tree().process_frame
	# Alternate choices, equal pay, and failed-write rollback use an isolated save host.
	for row in G.side_quest_rows():
		if String(row.id) not in ["a4_rel_waylight","a4_secret_runes"]: continue
		for key in row.choices:
			var host:=FailedSaveHost.new()
			host._init_state_defaults()
			host.selected_role=G.selected_role
			host.prog=original.duplicate(true)
			host.items=original_items.duplicate(true)
			host.wallet=original_wallet.duplicate(true)
			QuestService.side_accept(host.act1_state(),G.side_quest_rows(),String(row.id))
			var state:=QuestService.side_get(host.act1_state(),String(row.id))
			state.status=QuestService.SIDE_READY
			state.progress=QuestService.side_need(row)
			var snapshot:=host.prog.duplicate(true)
			_check(host._side_complete(String(row.id),true,String(key)).is_empty() and host.prog==snapshot and host.wallet==original_wallet,"分支写盘拒绝完整回滚 "+String(key))
			_check(not host._side_complete(String(row.id),false,String(key)).is_empty() and int(host.wallet.gold)-int(original_wallet.gold)==int(row.reward.gold),"每个分支固定等值报酬 "+String(key))
			host.free()
	print("RETURN_JOBS_OK" if _fails==0 else "RETURN_JOBS_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails==0 else 1)

func _entity(map:MapScene,id:String) -> Node2D:
	for entity in map._quest_entities:
		if is_instance_valid(entity) and entity.eid==id and not entity.used: return entity
	return null

func _click(button:Control) -> void:
	if button==null: return
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	button.gui_input.emit(event)

func _has_text(node:Node, text:String) -> bool:
	if node is Label and text in node.text: return true
	for child in node.get_children():
		if _has_text(child,text): return true
	return false
