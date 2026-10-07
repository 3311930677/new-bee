extends SubViewport

# Review-only capture. All saves go into this audit folder; gameplay sources stay unchanged.
const OUT := "res://shots/flat_ground_20261006"
var records: Array = []

func _ready() -> void:
	G.SAVE_PATH = OUT + "/review_save.json"
	G.set_meta("ui_review_mode", true)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var states_only := OS.get_cmdline_user_args().has("--states")
	var layer_probe := OS.get_cmdline_user_args().has("--layer-probe")
	var expected := 4 if layer_probe else (24 if states_only else 96)
	if layer_probe:
		await capture_map("rift_mine_vault", "", 7, {"act3_mine_rooms_v1": true}, "_layer_probe")
	elif states_only:
		var variants := [
			["rift_mine_vault", "_rooms", {"act3_mine_rooms_v1": true}],
			["rift_mine_vault", "_rescued", {"act3_mine_rooms_v1": true, "act3_mine_second_wind": true, "act3_mine_switch": true}],
			["tidal_gate", "_sealed", {"act2_tidal_rooms_v1": true}],
			["tidal_gate", "_bridge", {"act2_tidal_rooms_v1": true, "act2_tide_clue": true, "act2_tide_gate_1": true, "act2_tide_gate_2": true, "act2_tide_route_bridge": true, "act2_tide_bridge_open": true}],
			["tidal_gate", "_cargo", {"act2_tidal_rooms_v1": true, "act2_tide_clue": true, "act2_tide_gate_1": true, "act2_tide_gate_2": true, "act2_tide_route_cargo": true, "act2_tide_cargo_saved": true}],
			["stele_core", "_lit", {"act4_avatar_down": true, "act4_forest_voice": true, "act4_tide_voice": true, "act4_snow_voice": true}]
		]
		for variant in variants:
			await capture_map(variant[0], "", 7, variant[2], variant[1])
	else:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/main_world_maps.json"))
		for mid: String in data.maps:
			await capture_map(mid, "", 7)
		for theme: String in TableCache.maps_config().theme_order:
			await capture_map("", theme, 7)
	if records.size() != expected:
		push_error("AUDIT_INCOMPLETE images=%d expected=%d" % [records.size(), expected])
		get_tree().quit(1)
		return
	var index_name := "/layer_probe_index.json" if layer_probe else ("/state_capture_index.json" if states_only else "/capture_index.json")
	var output := FileAccess.open(OUT + index_name, FileAccess.WRITE)
	output.store_string(JSON.stringify(records, "\t"))
	print("MAP_BACKGROUND_AUDIT_OK images=%d" % records.size())
	get_tree().quit()

func capture_map(mid: String, theme: String, seed_value: int, flags: Dictionary = {}, suffix := "") -> void:
	size = Vector2i(480, 800)
	canvas_transform = Transform2D.IDENTITY
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "fs"
	G.player_name = "场景检查"
	G.prog.level = 12
	G.prog.exp = 100
	G.prog["flags"] = flags.duplicate(true)
	G.wallet = {"gold": 101576, "expedition": 240, "soul": 36, "honor": 900}
	G.collect_pet("pet_rockturtle")
	var cfg := TableCache.main_world_map(mid) if not mid.is_empty() else {}
	var world_theme := String(cfg.get("theme", theme))
	var run := RunState.new()
	run.setup({"theme": world_theme, "role_id": "fs", "level": 12,
		"active_pet": "pet_rockturtle", "bench_pet": "", "potions": 2, "seed": seed_value})
	if not mid.is_empty(): G.prog.main_world = {"map_id": mid}
	MapScene.pending_cfg = {"mode": "main_world" if not mid.is_empty() else "expedition",
		"main_map_id": mid, "run": run,
		"node": {"type": String(cfg.get("node_type", "normal")), "layer": 0, "index": 0}}
	var map: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
	add_child(map)
	for i in 6: await get_tree().process_frame
	if map._city_content != null: map._city_content.call("_close_panel")
	if suffix == "_layer_probe" and map._mine_ground != null: map._mine_ground.z_index = 0
	map.process_mode = Node.PROCESS_MODE_DISABLED
	var key := (mid if not mid.is_empty() else "exp_" + theme) + suffix
	var cam: Camera2D = get_camera_2d()
	var dims := Vector2i(int(map._map_cfg.map_cols) * 48, int(map._map_cfg.map_rows) * 48)
	var spawn := map._player.position
	await shot(map, key, "spawn_800", world_theme, spawn)
	map._player.position = Vector2(dims) * 0.5
	cam.reset_physics_interpolation()
	cam.force_update_scroll()
	await shot(map, key, "center_800", world_theme, map._player.position)
	map._hud.visible = false
	cam.enabled = false
	size = dims
	canvas_transform = Transform2D.IDENTITY
	await shot(map, key, "overview", world_theme, map._player.position)
	map.queue_free()
	for i in 3: await get_tree().process_frame
	if not mid.is_empty():
		# HUD placement is calculated at construction, so capture a fresh long-screen scene.
		size = Vector2i(480, 1067)
		canvas_transform = Transform2D.IDENTITY
		G.prog.main_world = {"map_id": mid}
		MapScene.pending_cfg = {"mode": "main_world", "main_map_id": mid, "run": run,
			"node": {"type": String(cfg.get("node_type", "normal")), "layer": 0, "index": 0}}
		var long_map: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
		add_child(long_map)
		for i in 6: await get_tree().process_frame
		if long_map._city_content != null: long_map._city_content.call("_close_panel")
		if suffix == "_layer_probe" and long_map._mine_ground != null: long_map._mine_ground.z_index = 0
		long_map.process_mode = Node.PROCESS_MODE_DISABLED
		long_map._player.position = Vector2(dims) * 0.5
		var long_cam: Camera2D = get_camera_2d()
		long_cam.force_update_scroll()
		await shot(long_map, key, "center_1067", world_theme, long_map._player.position)
		long_map.queue_free()
		for i in 3: await get_tree().process_frame
	print("CAPTURED " + key)

func shot(map: MapScene, key: String, view: String, theme: String, focus: Vector2) -> void:
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := OUT + "/" + view
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := folder + "/" + key + ".png"
	var result := get_texture().get_image().save_png(path)
	if result != OK:
		push_error("AUDIT_CAPTURE_FAILED " + path)
		get_tree().quit(1)
		return
	records.append({"id": key, "name": String(map._main_cfg.get("name", theme)),
		"theme": theme, "view": view, "size": [size.x, size.y],
		"focus": [focus.x, focus.y], "path": path, "seed": 7,
		"flags": G.prog.get("flags", {}).duplicate(true),
		"mine_ground_present": map._mine_ground != null,
		"mine_ground_z": map._mine_ground.z_index if map._mine_ground != null else null,
		"state": "isolated demo; stationary capture"})

