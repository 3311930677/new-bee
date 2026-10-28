extends Node
const Points := preload("res://src/world/WorldPoints.gd")
const OUT := "res://shots/experience_rework_20261026/world/"
var checks := 0
var errors: Array[String] = []
var capture := false
var current: MapScene

func check(ok: bool,words: String) -> void:
	checks+=1
	if not ok:errors.append(words);push_error("EXPERIENCE_WORLD_FAIL "+words)

func frames(n := 6) -> void:
	for i in n:await get_tree().process_frame

func shot(id: String) -> void:
	if not capture:return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+id+".png")==OK,"shot "+id)

func enter(id: String) -> void:
	G.prog.main_world={"map_id":id}
	var run := RunState.new()
	run.setup({"role_id":"zs","theme":String(TableCache.main_world_map(id).get("theme","forest")),"level":35,"seed":71})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":id,"run":run,"node":{"type":"normal","layer":1,"index":0}}
	current=preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(current)
	await frames(8)
	current.set_physics_process(false)
	for monster in current._monsters:monster.set_physics_process(false)
	if current._city_content!=null:current._city_content.set_physics_process(false)
	if current._city_content!=null and current._city_content._panel!=null:current._city_content._close_panel()
	await frames()

func clean() -> void:
	current.queue_free()
	current=null
	await frames(5)

func _ready() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	G.SAVE_PATH="res://tools/_logs/experience_world_save.json"
	G._init_state_defaults()
	G.save_locked=false
	G.set_meta("ui_review_mode",true)
	G.selected_role="zs"
	G.player_name="沈舟"
	G.gm_unlocked=true
	G.gm_grant_all()
	G.gm_unlock_all_features()
	G.gm_world_open=true
	G.prog.level=35
	G.wallet.gold=100000
	get_window().unresizable=false
	get_window().size=Vector2i(480,1067)
	get_window().content_scale_size=Vector2i(480,1067)
	if "--narrow-only" in OS.get_cmdline_user_args():
		await narrow_layouts()
		var narrow_file := FileAccess.open(OUT+"narrow_results.json",FileAccess.WRITE)
		narrow_file.store_string(JSON.stringify({"checks":checks,"failures":errors},"\t"))
		narrow_file.close()
		print("EXPERIENCE_NARROW checks=%d failures=%d"%[checks,errors.size()])
		Audio.set_suspended(true)
		await frames()
		get_tree().quit(0 if errors.is_empty() else 1)
		return
	var ids: Array=TableCache.main_world_config().get("maps",{}).keys()
	for id in ids:
		await enter(id)
		check(is_equal_approx(current._player_anim.scale.x,.70),"same character scale "+id)
		check(current._world.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"environment linear sampling "+id)
		var extent := current._map_extent()
		for point in Points.rows(id):
			check(Rect2(Vector2.ZERO,extent).has_point(Points.position(point)),"point in real map "+String(point.id))
			if point.kind=="fishing":
				var found := false
				for entity in current._quest_entities:
					if entity.eid==point.entity:
						found=true
						check(entity.position.distance_to(Points.position(point))<.1,"fishing coordinates match "+String(point.id))
				check(found,"actual fishing entity exists "+String(point.id))
		var point_target := Points.find("old_salt_road:fish_salt_spring")
		if id!="old_salt_road":
			G.prog.map_destination=point_target.id
			var info := current._destination_info()
			check(info.get("poi_id","")==point_target.id,"cross-region next-hop tracking "+id)
			G.prog.map_destination=""
		if id in ["lorin_wilds","shenyuan_port","frost_post","frost_boardwalk"]:await shot(id+"_smooth")
		if id=="frost_post":await return_jobs()
		await clean()
	if capture:
		OS.set_environment("YUANZHENG_BACKGROUND_NEAREST","1")
		for id in ["lorin_wilds","shenyuan_port","frost_post","frost_boardwalk"]:
			await enter(id)
			await shot(id+"_nearest")
			await clean()
		OS.set_environment("YUANZHENG_BACKGROUND_NEAREST","0")
	await narrow_layouts()
	var original_flags: Dictionary=G.prog.flags.duplicate(true)
	G.gm_world_open=false
	G.prog.flags.erase("qa_missing_gate")
	check(not Points.gate_reason({"requires_flags":["qa_missing_gate"]}).is_empty(),"shared route gate checks flags")
	G.prog.flags["qa_missing_gate"]=true
	check(Points.gate_reason({"requires_flags":["qa_missing_gate"]}).is_empty(),"opened flag gate is traversable")
	G.prog.flags=original_flags
	var f := FileAccess.open(OUT+"results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"maps":ids.size(),"checks":checks,"failures":errors},"\t"))
	f.close()
	print("EXPERIENCE_WORLD maps=%d checks=%d failures=%d"%[ids.size(),checks,errors.size()])
	Audio.stop_bgm();Audio.set_suspended(true)
	await frames(8)
	get_tree().quit(0 if errors.is_empty() else 1)

func return_jobs() -> void:
	var city: CityScene=current._city_content
	var row := QuestService.side_row(G.side_quest_rows(),"a4_eco_snowflowers")
	check(not row.is_empty(),"return-job fixture exists")
	if row.is_empty():return
	var npc := G.city_npc(String(row.giver))
	if npc.is_empty():
		for item in TableCache.city_config_for("frost_post").get("npcs",[]):
			if String(item.id)==String(row.giver):npc=item;break
	var all: Dictionary=G.act1_state().get("side_quests",{})
	for state in ["","active","ready","done"]:
		if state.is_empty():all.erase(row.id)
		else:all[row.id]={"status":state,"progress":QuestService.side_need(row)}
		G.act1_state()["side_quests"]=all
		city._open_return_job(npc,"",String(row.id))
		await frames()
		check(city._panel!=null,"return job state "+state)
		if city._panel!=null:
			var controls := city._panel.find_children("*","ScrollContainer",true,false)
			check(not controls.is_empty(),"return job text flows and scrolls "+state)
			await shot("return_job_"+("new" if state.is_empty() else state))
			city._close_panel()
			await frames()

func narrow_layouts() -> void:
	get_window().size=Vector2i(320,640)
	get_window().content_scale_size=Vector2i(320,640)
	G.set_meta("test_safe_rect",Rect2(8,24,304,592))
	await frames()
	var panels := [preload("res://src/ui/HonorMarketPanel.gd").new(),preload("res://src/ui/ActivityPanel.gd").new(),preload("res://src/ui/WorldPointMap.gd").new(),FishingPanel.new()]
	for index in panels.size():
		var p: Control=panels[index]
		add_child(p)
		if p is FishingPanel:p.open_spot("fish_salt_spring")
		await frames(8)
		var frame: Control=p._panel if index==0 else p._page if index==3 else p._frame
		check(G.ui_safe_rect(p).encloses(frame.get_global_rect()),"narrow frame %d rect=%s safe=%s"%[index,frame.get_global_rect(),G.ui_safe_rect(p)])
		await shot("narrow_"+str(index))
		if index==2:
			var markers: Array=p._canvas._markers()
			check(markers.size()<p._canvas.points.size(),"dense city markers cluster instead of overlapping")
			for marker in markers:
				if marker.ids.size()>1:
					p._choose_cluster(marker.ids)
					await frames()
					check(G.ui_safe_rect(p).encloses(p._picker_frame.get_global_rect()),"cluster choices fit narrow safe area")
					await shot("narrow_cluster")
					break
		p.queue_free()
		await frames()
	G.remove_meta("test_safe_rect")
