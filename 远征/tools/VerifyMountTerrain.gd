extends Node
const Links=preload("res://src/world/ExplorationLinks.gd")
const OUT="res://shots/full_issue_fix_20261024/terrain/"
var checks=0
var failures=0
var records:Array=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;push_error("MOUNT_TERRAIN_FAIL "+label)
func frames(n=4):
	for i in n:await get_tree().process_frame
func shot(map:MapScene,id:String,at:Vector2):
	map._player.position=at
	for camera in map._player.get_children():
		if camera is Camera2D:camera.reset_smoothing();camera.force_update_scroll()
	await frames()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+id+".png")==OK,"screenshot "+id)
func _ready():
	G.SAVE_PATH="res://tools/_logs/mount_terrain_save.json"
	G._init_state_defaults();G.save_locked=false;G.gm_unlock_all_features()
	G.set_meta("ui_review_mode",true);G.wallet.gold=100000
	G.selected_role="zs";G.player_name="骑乘路带验收"
	G.mount_buy("horse");G.mount_buy("bear")
	get_window().size=Vector2i(480,1067);get_window().content_scale_size=Vector2i(480,1067)
	DirAccess.make_dir_recursive_absolute(OUT)
	for row in [{"map":"maple_road","mount":"horse"},{"map":"frost_post","mount":"bear"}]:
		G.mount_set_active(row.mount);G.mount_set_riding(true,false)
		var terrain=Links.trait_for(row.mount,row.map)
		check(not terrain.is_empty(),"terrain mapping "+row.map)
		var rectangle:Array=terrain.rect
		var area=Rect2(rectangle[0],rectangle[1],rectangle[2],rectangle[3])
		var inside=area.get_center();var outside=Vector2(area.end.x+80,inside.y)
		# Restore serialized progress before building, as on re-entering a saved map.
		G.prog=JSON.parse_string(JSON.stringify(G.prog))
		var run=RunState.new();run.setup({"role_id":"zs","theme":"forest","level":32,"seed":71})
		G.prog.main_world={"map_id":row.map}
		MapScene.pending_cfg={"mode":"main_world","main_map_id":row.map,"run":run,"node":{"type":"normal","layer":1,"index":0}}
		var map=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
		map.process_mode=Node.PROCESS_MODE_DISABLED
		add_child(map);await frames(6)
		check(map._terrain_trace!=null and map._terrain_trace.area==area,"original visual area restored "+row.map)
		check(is_equal_approx(Links.speed_mult(row.mount,row.map,inside,true),1.08),"inside original eight percent bonus "+row.map)
		check(is_equal_approx(Links.speed_mult(row.mount,row.map,outside,true),1.0),"outside no bonus "+row.map)
		check(is_equal_approx(Links.speed_mult(row.mount,row.map,inside,false),1.0),"walking no bonus "+row.map)
		await shot(map,row.map+"_mounted_inside",inside)
		await shot(map,row.map+"_mounted_outside",outside)
		G.mount_set_riding(false,false);map._sync_mount_visual();await frames()
		check(map._terrain_trace==null,"dismount removes visual "+row.map)
		await shot(map,row.map+"_dismounted",inside)
		G.mount_set_riding(true,false);map._sync_mount_visual();await frames()
		check(map._terrain_trace!=null,"remount restores visual "+row.map)
		records.append({"map":row.map,"mount":row.mount,"rect":rectangle,"restored_from_serialized_progress":true})
		remove_child(map);map.queue_free();await frames()
	var file=FileAccess.open("res://tools/_logs/mount_terrain_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"));file.close()
	print("MOUNT_TERRAIN_OK checks=%d failures=%d"%[checks,failures])
	Audio.stop_bgm();Audio.set_suspended(true);await get_tree().create_timer(.2).timeout
	get_tree().quit(0 if failures==0 else 1)
