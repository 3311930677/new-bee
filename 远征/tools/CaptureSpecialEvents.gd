extends Node
const Events := preload("res://src/world/SpecialEventService.gd")
var height := 800
var destination := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--height="): height=int(arg.get_slice("=",1))
	get_window().size=Vector2i(480,height)
	destination="res://shots/special_events_20261006/480x%d" % height
	DirAccess.make_dir_recursive_absolute(destination)
	G.SAVE_PATH="res://tools/_logs/capture_special_events_%d.json" % height
	var index:=0
	for entry in Events.rows():
		index+=1
		G._init_state_defaults()
		G.save_locked=false
		G.selected_role="zs"
		G.prog.level=60
		var done:Array=[]
		for i in range(1,37): done.append("s%02d" % i)
		G.prog.story={"step":"","done":done,"goals":{}}
		G.ensure_starter_equip()
		var id:=String(entry.id)
		Events.action(G,id,String(entry.board.map),"accept")
		Events.action(G,id,String(entry.clue.map),"inspect")
		var map:MapScene=await open_map(String(entry.encounter.map))
		var entity:Node=null
		for candidate in map._quest_entities:
			if candidate.special_event_id==id and not candidate.used: entity=candidate
		if entity==null:
			push_error("No special event entity: "+id)
			get_tree().quit(1)
			return
		map._player.position=entity.position+Vector2(0,100)
		map.on_quest_entity(entity)
		await capture("%02d_%s_choice_top" % [index,id])
		map._special_panel._scroll.scroll_vertical=int(map._special_panel._scroll.get_v_scroll_bar().max_value)
		await capture("%02d_%s_choice_bottom" % [index,id])
		map.queue_free()
		await get_tree().process_frame
		var peaceful:=String(entry.branches.keys()[0])
		Events.action(G,id,String(entry.encounter.map),peaceful)
		map=await open_map(String(entry.board.map))
		for candidate in map._quest_entities:
			if candidate.special_event_id==id and not candidate.used: entity=candidate
		map.on_quest_entity(entity)
		await capture("%02d_%s_reward_top" % [index,id])
		map._special_panel._scroll.scroll_vertical=int(map._special_panel._scroll.get_v_scroll_bar().max_value)
		await capture("%02d_%s_reward_bottom" % [index,id])
		map._special_panel.close()
		Events.action(G,id,String(entry.board.map),"gear")
		map._refresh_quest_entities()
		map._refresh_hud()
		await get_tree().process_frame
		await get_tree().process_frame
		var feedback:Node=null
		for candidate in map._quest_entities:
			if candidate.special_event_id==id and candidate.used: feedback=candidate
		if feedback!=null: map._player.position=feedback.position+Vector2(0,60)
		await capture("%02d_%s_world_after" % [index,id])
		map.queue_free()
		await get_tree().process_frame
	print("SPECIAL_EVENT_CAPTURE_OK height=%d" % height)
	get_tree().quit()

func open_map(mid:String) -> MapScene:
	var run:=RunState.new()
	run.setup({"role_id":"zs","theme":"forest","level":60,"seed":99})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":mid,"run":run,"node":{"type":"normal","layer":0,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	for i in range(8): await get_tree().process_frame
	map.set_process(false)
	map.set_physics_process(false)
	map._player.set_physics_process(false)
	for monster in map._monsters: monster.process_mode=Node.PROCESS_MODE_DISABLED
	if map._city_content!=null: map._city_content._close_panel()
	return map

func capture(filename:String) -> void:
	var camera:=get_viewport().get_camera_2d()
	if camera!=null:
		camera.reset_smoothing()
		camera.force_update_scroll()
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(destination+"/"+filename+".png")
