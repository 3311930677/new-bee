extends Node
const OUT:="res://shots/reference_complete_20261011/"
func frames(count:=10)->void:
	for i in count:await get_tree().process_frame
func shot(id:String)->void:
	for child in get_children():
		if child is MapScene:
			var map:=child as MapScene
			if map._city_content!=null:
				for building in map._city_content._buildings:building.cooled=true
				for npc in map._city_content._npcs:npc.cooled=true
				map._city_content._check_interact()
			map._tick_round_interaction();map._resolve_name_tags()
	await frames(8);await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT+id+".png")==OK)
func fixture()->void:
	G._init_state_defaults();G.save_locked=false;G.selected_role="zs";G.player_name="行旅人";G.prog.level=12
	G.collect_pet("pet_rockturtle");G.prog.tips_seen={"deploy":true}
func map_scene(id:String)->MapScene:
	fixture()
	if id=="lorin_wilds":G.city.built=["hall","gate","stable","barracks","storehouse","forge","archive","kennel","shrine"]
	var run:=RunState.new();run.setup({"role_id":"zs","theme":"forest","level":12,"active_pet":"pet_rockturtle","potions":2,"seed":17})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":id,"run":run,"node":{"type":"normal","layer":0,"index":0}}
	var map:MapScene=preload("res://src/explore/MapScene.tscn").instantiate();add_child(map)
	await frames()
	# Capture views without triggering encounters or dialogue; normal scene data and rendering stay intact.
	map.set_process(false);map.set_physics_process(false)
	if map._city_content!=null:map._city_content.set_process(false)
	for mon in map._monsters:mon.set_process(false);mon.set_physics_process(false)
	for entity in map._quest_entities:entity.set_process(false)
	return map
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	G.SAVE_PATH=OUT+"capture_isolated_save.json";G.set_meta("ui_review_mode",true)
	get_window().size=Vector2i(480,800);await frames()
	for id in ["lorin_wilds","maple_road"]:
		var map:=await map_scene(id)
		if id=="lorin_wilds":
			G.city.built=["hall","gate"]
			for building in map._city_content._buildings:building.queue_redraw()
			await shot("lorin_wilds_default_construction_800")
			G.city.built=["hall","gate","stable","barracks","storehouse","forge","archive","kennel","shrine"]
			for building in map._city_content._buildings:building.queue_redraw()
		await shot(id+"_spawn_800")
		var views:Dictionary={"hall":Vector2(450,1275),"stable":Vector2(430,680),"forge":Vector2(780,985),"south":Vector2(610,1800),"sign_exit":Vector2(610,385)} if id=="lorin_wilds" else {"meadow":Vector2(480,1680),"bridge":Vector2(500,1360),"fork":Vector2(640,1020),"red_maples":Vector2(480,420)}
		for name in views:
			map._player.position=views[name]
			await shot(id+"_"+name+"_800")
		map._hud.visible=false
		map._player.position=Vector2(600,1110) if id=="lorin_wilds" else Vector2(480,1110)
		var camera:=get_viewport().get_camera_2d();camera.zoom=Vector2.ONE*.34;camera.reset_smoothing()
		await shot(id+"_overview")
		map.queue_free();await frames()
	for height in [800,1067]:
		get_window().size=Vector2i(480,height);await frames()
		if height==1067:
			for id in ["lorin_wilds","maple_road"]:
				var map:=await map_scene(id);await shot(id+"_spawn_1067");map.queue_free();await frames()
		var title:=preload("res://src/ui/Title.tscn").instantiate();add_child(title);await shot("title_"+str(height));title.queue_free();await frames()
		var login:=preload("res://src/ui/Login.tscn").instantiate();add_child(login);await shot("login_"+str(height))
		login._chest.error("账号或秘钥不正确，请重新输入");await shot("login_error_"+str(height))
		login._chest.layout(Rect2(0,0,480,height),320);await shot("login_keyboard_"+str(height));login.queue_free();await frames()
		var loading:=preload("res://src/ui/LoadScreen.tscn").instantiate();loading.auto_advance=false;add_child(loading);loading.set_process(false);await frames()
		loading._set_bar_ratio(.45);await shot("loading_"+str(height));loading.queue_free();await frames()
	print("REFERENCE_COMPLETE_CAPTURE_OK")
	get_tree().quit()
