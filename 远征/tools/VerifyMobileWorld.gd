extends Node
const OUT := "res://shots/mobile_fixes_20261024/"
var fails := 0
var checks := 0
var records: Array[Dictionary] = []
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("WORLD_VISUAL_FAIL "+words)
func _ready() -> void:
	G.SAVE_PATH="res://tools/_logs/mobile_world_save.json"
	G._init_state_defaults()
	G.save_locked=false
	G.set_meta("ui_review_mode",true)
	G.selected_role="zs"
	G.player_name="场景验收"
	G.gm_unlock_all_features()
	get_window().size=Vector2i(480,1067)
	var capture := "--capture-mobile" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	for id in TableCache.main_world_config().get("maps",{}):
		var row: Dictionary=TableCache.main_world_config().maps[id]
		var run:=RunState.new()
		run.setup({"role_id":"zs","theme":String(row.get("theme","forest")),"level":20,"seed":71})
		G.mount_set_riding(false,false)
		G.prog.main_world={"map_id":id}
		G.prog.flags["act3_supply_choice"]="merchant"
		MapScene.pending_cfg={"mode":"main_world","main_map_id":id,"run":run,"node":{"type":"normal","layer":1,"index":0}}
		var scene:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
		add_child(scene)
		for i in 6: await get_tree().process_frame
		scene.set_physics_process(false)
		check(scene._player!=null and scene._world!=null,"world builds "+String(id))
		check(scene._player_anim.sprite_frames!=null,"player art "+String(id))
		if id=="frost_post":
			scene._player.position=Vector2(480,415)
			for child in scene._player.get_children():
				if child is Camera2D: child.reset_smoothing()
		var missing: Array[String]=[]
		for node in scene.find_children("*","Sprite2D",true,false):
			if node.visible and node.texture==null and node.get_parent()==scene._world:
				missing.append(String(node.name))
		check(missing.is_empty(),"no visible blank world sprites "+String(id))
		records.append({"map_id":id,"art_state":"authored textures with gameplay geometry","blank_world_sprites":missing,"capture":"world_"+String(id)+".png"})
		if capture:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OUT+"world_"+String(id)+".png")
		remove_child(scene)
		scene.queue_free()
		await get_tree().process_frame
	var file:=FileAccess.open("res://tools/_logs/mobile_world_art_inventory.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"maps":records,"checks":checks,"failures":fails},"\t"))
	file.close()
	print("MOBILE_WORLD_OK maps=%d checks=%d fails=%d"%[records.size(),checks,fails])
	get_tree().quit(0 if fails==0 else 1)
