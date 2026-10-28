extends Node
## Real MapScene entities, including original quest/commission gates and disk reload.
const Art=preload("res://src/world/AssetCompletion.gd")
const OUT="res://shots/full_issue_fix_20261024/prop_states/"
var checks=0
var failures=0
var base_progress:Dictionary
var records:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error("MAP_PROP_STATES_FAIL "+label)
func frames(n=3):
	for i in n:await get_tree().process_frame
func _ready():
	G.SAVE_PATH="res://tools/_logs/map_prop_states_save.json"
	G._init_state_defaults();G.save_locked=false;G.gm_unlock_all_features()
	G.selected_role="zs";G.player_name="物件状态验收"
	G.set_meta("ui_review_mode",true)
	G.act1_state().side_quests.clear()
	G.prog.world_commissions={}
	G.economy_state().orders={}
	G.mount_set_riding(false,false)
	base_progress=G.prog.duplicate(true)
	get_window().size=Vector2i(480,800);get_window().content_scale_size=Vector2i(480,800)
	DirAccess.make_dir_recursive_absolute(OUT)
	var entries:Array=[]
	for mid in TableCache.main_world_config().maps:
		for eid in TableCache.main_world_map(mid).get("entities",{}):
			var definition:Dictionary=TableCache.main_world_map(mid).entities[eid]
			if String(definition.get("art","")) in ["salt_marks","tracks"]:
				entries.append({"id":String(eid),"map":String(mid),"row":definition,"commission":false})
	for template in WorldCommission.templates():
		for index in template.steps.size():
			var step:Dictionary=template.steps[index]
			if String(step.get("art",""))=="tracks" and String(step.kind)!="defeat":
				entries.append({"id":String(step.id),"map":String(step.map),"row":step,"commission":true,"template":String(template.id),"index":index})
	check(entries.size()==34,"all 21 salt objects and 13 noncombat clues enumerated")
	for entry in entries:
		for phase in ["unaccepted","current","completed","reloaded"]:
			await verify_state(entry,phase)
	var file=FileAccess.open("res://tools/_logs/map_prop_states_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"objects":entries.size(),"records":records},"\t"));file.close()
	print("MAP_PROP_STATES_OK checks=%d failures=%d objects=%d states=%d"%[checks,failures,entries.size(),records.size()])
	Audio.stop_bgm();Audio.set_suspended(true);await get_tree().create_timer(.2).timeout
	get_tree().quit(0 if failures==0 else 1)

func prepare(entry:Dictionary,phase:String)->bool:
	G.prog=base_progress.duplicate(true);G.save_locked=false
	var active=phase in ["current","reloaded"]
	var complete=phase=="completed"
	var row:Dictionary=entry.row
	if entry.commission:
		if phase=="unaccepted":return false
		var posting=String(entry.template)+"|2026-10-25|0"
		var definition=WorldCommission.row(entry.template)
		G.prog.world_commissions[posting]={"posting":posting,"template":entry.template,"day":"2026-10-25","slot":0,"status":"done" if complete else "active","progress":definition.steps.size() if complete else entry.index,"choice":""}
		return active
	var qid=String(row.get("quest",""))
	if not qid.is_empty():
		var quest=QuestService.side_row(G.side_quest_rows(),qid)
		var steps:Array=quest.get("steps",[])
		var progress=0
		for index in steps.size():
			if String(steps[index].get("target_entity",""))==String(entry.id):progress=index
		if phase!="unaccepted":
			G.act1_state().side_quests[qid]={"status":"done" if complete else "active","progress":QuestService.side_need(quest) if complete else progress,"seen":[]}
		if String(row.kind)=="feedback":return complete
		if complete:return false
		if active:return true
		# First collect/observe/deliver clues remain discoverable before accepting,
		# as required by the existing G.side_entity_visible rule.
		var first:Dictionary=steps[0] if not steps.is_empty() else quest.get("objective",{})
		return String(first.get("kind","")) in ["collect","observe","deliver"] and (String(first.get("target_entity",""))==String(entry.id) or (first.get("target_entities",[]) as Array).has(entry.id))
	if String(row.kind)=="shipping_aid":
		if phase=="unaccepted":return false
		var info=G.shipping_order(row.shipping_id)
		var accepted=G.shipping_accept(row.shipping_id,String(info.dispatch_site))
		check(bool(accepted.get("ok",false)),"accept real shipping order "+String(entry.id))
		if complete:
			var result=G.shipping_route_aid(row.shipping_id,entry.map,entry.id)
			check(bool(result.get("ok",false)),"complete real shipping aid "+String(entry.id))
		return active
	if String(row.kind)=="puzzle":
		var required=String(row.get("requires_story",""))
		if phase=="unaccepted":
			G.prog.story.done.erase(required);G.prog.story.goals.erase(required)
		for flag in row.get("requires_flags",[]):G.prog.flags[flag]=true
		G.prog.flags[String(row.flag)]=complete
		return active
	check(false,"unknown mechanism "+String(entry.id))
	return false

func verify_state(entry:Dictionary,phase:String):
	var expected=prepare(entry,phase)
	# Feedback objects persist only after turning in, so reload the completed state.
	if phase=="reloaded" and String(entry.row.get("kind",""))=="feedback":
		expected=prepare(entry,"completed")
	if phase=="reloaded":
		check(G.save_game(),"write isolated save "+String(entry.id))
		check(G.reload_save() and not G.save_locked and bool(G.last_load_report.get("ok",false)),"reload validated save "+String(entry.id))
		G.set_meta("ui_review_mode",true)
	var mid=String(entry.map)
	G.prog.main_world={"map_id":mid}
	var run=RunState.new();run.setup({"role_id":"zs","theme":String(TableCache.main_world_map(mid).get("theme","forest")),"level":32,"seed":71})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":mid,"run":run,"node":{"type":"normal","layer":1,"index":0}}
	var map=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	map.process_mode=Node.PROCESS_MODE_DISABLED
	add_child(map);await frames(4)
	var found:Node2D
	for entity in map._quest_entities:
		if entity.eid==String(entry.id):found=entity;break
	check((found!=null)==expected,"visibility "+String(entry.id)+" "+phase+" expected="+str(expected))
	var at=Vector2(entry.row.at[0],entry.row.at[1])
	if found!=null:
		check(found.position.distance_to(at)<.1,"original coordinate "+String(entry.id))
		check(String(found.art)==String(entry.row.art),"original entity semantics "+String(entry.id))
		var key=Art.track_key(entry.id) if String(found.art)=="tracks" else Art.salt_key(entry.id)
		check(Art.texture(key)!=null,"formal semantic texture "+String(entry.id))
	for camera in map._player.get_children():
		if camera is Camera2D:camera.top_level=true;camera.global_position=at;camera.reset_smoothing();camera.force_update_scroll()
	await frames(3)
	var before=JSON.stringify([G.prog,G.wallet,G.items])
	for entity in map._quest_entities:entity.queue_redraw()
	await frames(2);await RenderingServer.frame_post_draw
	var name=String(entry.id)+"_"+phase
	check(get_viewport().get_texture().get_image().save_png(OUT+name+".png")==OK,"capture "+name)
	check(before==JSON.stringify([G.prog,G.wallet,G.items]),"render is read-only "+name)
	var anchor=map._world.get_global_transform_with_canvas()*at
	records.append({"id":entry.id,"map":mid,"phase":phase,"expected_visible":expected,"visible":found!=null,"screen_anchor":[anchor.x,anchor.y],"image":name+".png","disk_reload":phase=="reloaded"})
	remove_child(map);map.queue_free();await frames(2)
