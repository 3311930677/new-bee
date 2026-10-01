extends SubViewport

# 原生渲染当前地貌，供画风重绘对齐栈桥和出口。没有角色、建筑、HUD，也不写玩家档。
class GroundOnly extends MapScene:
	func _ready() -> void:
		_main_cfg = TableCache.main_world_map(_main_map_id).duplicate(true)
		_main_cfg["background"] = ""
		_map_cfg = TableCache.maps_config().duplicate(true)
		_map_cfg["map_cols"] = int(_main_cfg.get("map_cols", 20))
		_map_cfg["map_rows"] = int(_main_cfg.get("map_rows", 26))
		_theme_cfg = TableCache.theme_config(String(_main_cfg.get("theme", "snow")))
		_map_asset_dir = String(_map_cfg.get("asset_dir", FALLBACK_ASSET_DIR))
		_rng.seed = hash("main_world_%s" % _main_map_id)
		_build_ground()
		if _main_map_id == "frost_post":
			var detail := ThirdActGroundScript.new()
			detail.map_id = _main_map_id
			add_child(detail)
	func _process(_delta: float) -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_terrain_snapshot.json"
	G.prog = {"flags": {}}
	var mid := "shenyuan_port"
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): mid = arg.trim_prefix("--map=")
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	if mid not in ["shenyuan_port", "frost_post"] or output.is_empty():
		push_error("TERRAIN_SNAPSHOT_INVALID_ARGUMENTS")
		get_tree().quit(1)
		return
	size = Vector2i(960, 1248)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var ground := GroundOnly.new()
	ground._mode = "main_world"
	ground._main_map_id = mid
	add_child(ground)
	for i in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var err := get_texture().get_image().save_png(output)
	if err != OK:
		push_error("TERRAIN_SNAPSHOT_WRITE_FAILED")
		get_tree().quit(1)
		return
	print("TERRAIN_SNAPSHOT_OK %s" % mid)
	ground.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)
