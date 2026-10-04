extends Node
const Trials:=preload("res://src/world/DungeonTrial.gd")
var _fails:=0

func _check(ok:bool,line:String)->void:
	if not ok:
		_fails+=1
		push_error("FAIL: "+line)

func _button(root:Node,text:String)->Control:
	if root is Button and root.text.replace(" ","")==text.replace(" ",""):return root
	if root is Label and root.text.replace(" ","")==text.replace(" ","") and root.get_parent() is Control:return root.get_parent()
	for child in root.get_children():
		var found:=_button(child,text)
		if found!=null:return found
	return null

func _click(control:Control)->void:
	var e:=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=true
	control.gui_input.emit(e)

func _reset(role:String)->void:
	G._init_state_defaults()
	G.save_locked=false
	G.selected_role=role
	G.prog.level=30
	G.SAVE_PATH="res://tools/_logs/save_verify_dungeon_trials.json"
	var done:Array=[]
	for i in range(1,37):done.append("s%02d"%i)
	G.prog.story=QuestService.normalize_state({"step":"","done":done,"goals":{}})
	G.prog.main_world=WorldSession.normalize_state({})
	for map_id in Trials.rows():WorldSession.mark_boss_cleared(G.prog.main_world,String(map_id))
	G.save_game()

func _map(map_id:String)->MapScene:
	var run:=RunState.new()
	run.setup({"role_id":G.selected_role,"level":30,"seed":12,"potions":2})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":map_id,"run":run,"node":{"type":"boss","layer":0,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	map.set_physics_process(false)
	map._player.position=Vector2(720,1000)
	return map

func _step(map:MapScene)->void:
	var step:=Trials.current(G,map._main_map_id)
	if String(step.kind)=="defeat":
		var monster:Variant=null
		for m in map._monsters:
			if m.trial:monster=m
		_check(monster!=null,"当前挑战生成独立残影")
		if monster!=null:
			var gold:=int(G.wallet.gold)
			var exp:=int(G.prog.exp)
			var potions:=map.st.potions
			map._start_battle(monster)
			_check(map._battle!=null,"残影进入生产战斗场景")
			if Trials.no_potions(G,map._main_map_id):_check(map._battle.sim.potions_left==0,"无药挑战的战斗药剂确实不可用")
			map._on_battle_end("victory",map.st.hp)
			_check(int(G.wallet.gold)==gold and int(G.prog.exp)==exp,"练习不重发首通金币与经验")
			_check(map.st.potions==potions,"禁用药剂不能吞掉原有药剂")
	else:
		var entity:Variant=null
		for e in map._quest_entities:
			if e.kind=="trial" and e.eid==String(step.id):entity=e
		_check(entity!=null,"地图只出现本次当前挑战阶段")
		if entity!=null:
			map.on_quest_entity(entity)
			if not (step.get("choices",{}) as Dictionary).is_empty():
				_check(map._puzzle_panel!=null,"回声选择生产面板真实打开")
				if map._puzzle_panel!=null:
					var correct:=_button(map._puzzle_panel,String(step.choices[step.correct]))
					if correct!=null:_click(correct)
	await get_tree().process_frame
	await get_tree().process_frame

func _ready()->void:
	for role in ["zs","ck","fs","fz"]:
		_reset(role)
		for map_id in Trials.rows():
			var original_story:Dictionary=G.prog.story.duplicate(true)
			var map:=await _map(String(map_id))
			var board:Variant=null
			for e in map._quest_entities:
				if e.kind=="trial_board":board=e
			_check(board!=null,"首通后实际入口有挑战告示")
			if board!=null:
				map.on_quest_entity(board)
				await get_tree().process_frame
				if role=="zs" and OS.get_cmdline_user_args().has("--screens"):
					await get_tree().create_timer(.2).timeout
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("res://shots/body_content_20261004/trial_"+String(map_id)+".png")
				var begin:=_button(map._puzzle_panel,"开始附加挑战")
				_check(begin!=null,"开始挑战需明确输入")
				if begin!=null:_click(begin)
				await get_tree().process_frame
				await get_tree().process_frame
			var stones:=G.item_count("enhance_stone")
			var guard:=0
			while not Trials.current(G,String(map_id)).is_empty() and guard<10:
				var step:=Trials.current(G,String(map_id))
				var before:=G.prog.duplicate(true)
				G.save_locked=true
				_check(not bool(Trials.advance(G,String(map_id),String(step.id),String(step.get("correct","")),true).ok) and G.prog==before,"锁盘线索不推进")
				G.save_locked=false
				if not (step.get("choices",{}) as Dictionary).is_empty():
					_check(not bool(Trials.advance(G,String(map_id),String(step.id),"deep").ok) and G.prog==before,"错误回声给反证且不抹观察")
				if Trials.no_potions(G,String(map_id)):
					var hp:=map.st.hp
					var pots:=map.st.potions
					map._use_potion()
					_check(map.st.hp==hp and map.st.potions==pots,"无药挑战地图药剂入口不可用")
				await _step(map)
				_check(G.reload_save(),"阶段能从磁盘恢复")
				guard+=1
			_check(String(Trials.record(G,String(map_id)).get("status",""))=="done" and G.item_count("enhance_stone")==stones+2,"四职业首次挑战只给表内外观材料")
			_check(G.prog.story==original_story and WorldSession.boss_cleared(G.prog.main_world,String(map_id)),"原主线和首领首通状态完整保留")
			var rewards:=G.items.duplicate(true)
			Trials.choose(G,String(map_id),"begin")
			map._refresh_quest_entities()
			guard=0
			while not Trials.current(G,String(map_id)).is_empty() and guard<10:
				await _step(map)
				guard+=1
			_check(G.items==rewards,"再次实际打完残影不多给外观材料或主线物")
			map.queue_free()
			await get_tree().process_frame
	# Leave a real partially heard echo trial for a second independent process.
	_reset("fz")
	Trials.choose(G,"stele_cavern","begin")
	var resume_map:=await _map("stele_cavern")
	await _step(resume_map)
	await _step(resume_map)
	_check(int(Trials.record(G,"stele_cavern").progress)==2,"第一进程留下两处真实听声进度")
	resume_map.queue_free()
	await get_tree().process_frame
	var fault_before:=G.prog.duplicate(true)
	var original:=G.SAVE_PATH
	G.SAVE_PATH="res://tools/_logs/absent_trial_dir/save.json"
	var print_errors:=Engine.print_error_messages
	Engine.print_error_messages=false
	var failed:=Trials.choose(G,"stele_cavern","abort")
	Engine.print_error_messages=print_errors
	G.SAVE_PATH=original
	_check(not bool(failed.ok) and G.prog==fault_before,"实际写盘失败不抹掉挑战线索")
	print("DUNGEON_TRIALS_OK" if _fails==0 else "DUNGEON_TRIALS_FAIL %d"%_fails)
	get_tree().quit(0 if _fails==0 else 1)
