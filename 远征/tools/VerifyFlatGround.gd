extends Node

const Layout := preload("res://src/explore/FlatGroundLayout.gd")
var fails := 0
var maps_checked := 0
var samples_checked := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		fails += 1
		push_error("FLAT_GROUND_FAIL " + message)

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_flat_ground.json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/main_world_maps.json"))
	for mid: String in data.maps:
		await verify_map(mid, "", 7)
	for theme: String in TableCache.maps_config().theme_order:
		for seed_value in [7, 19, 83]: await verify_map("", theme, seed_value)
	print("FLAT_GROUND_OK maps=%d route_samples=%d" % [maps_checked, samples_checked] if fails == 0 else "FLAT_GROUND_FAIL count=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)

func verify_map(mid: String, theme: String, seed_value: int) -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.prog.main_world = {"map_id": mid}
	G.prog.flags = {"act3_mine_rooms_v1": true, "act3_mine_second_wind": true, "act3_mine_switch": true,
		"act3_mine_clue": true, "act2_tidal_rooms_v1": true, "act2_tide_gate_1": true,
		"act2_tide_gate_2": true, "act2_tide_route_bridge": true}
	var cfg := TableCache.main_world_map(mid) if not mid.is_empty() else {}
	var run := RunState.new()
	run.setup({"theme": cfg.get("theme", theme), "role_id": "fs", "level": 12,
		"active_pet": "pet_rockturtle", "potions": 2, "seed": seed_value})
	MapScene.pending_cfg = {"mode": "main_world" if not mid.is_empty() else "expedition",
		"main_map_id": mid, "run": run, "node": {"type": "normal", "layer": 0, "index": 0}}
	var map: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
	add_child(map)
	map.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().physics_frame
	await get_tree().physics_frame
	var label := mid if not mid.is_empty() else "%s seed=%d" % [theme, seed_value]
	var routes: Array = cfg.get("flat_routes", []) if not mid.is_empty() else map._flat_ground.routes
	check(not routes.is_empty(), label + " needs a visible route")
	if map._flat_ground != null:
		check(map._flat_ground.texture != null, label + " floor texture")
		check(map._flat_ground.z_index < -10, label + " floor below mechanisms")
		check(map._flat_ground.material is ShaderMaterial, label + " generated material bound")
		if map._flat_ground.material is ShaderMaterial:
			check(map._flat_ground.material.get_shader_parameter("surface_scale") == map._flat_ground.extent / Vector2(768, 998.4),
				label + " consistent material pixel scale")
			var atlas: Texture2D = map._flat_ground.material.get_shader_parameter("surface_atlas")
			check(atlas != null, label + " generated atlas loaded")
			if atlas != null:
				var pixels := atlas.get_image()
				var dark_mean := 0.0
				var light_mean := 0.0
				for y in 8:
					for x in 8:
						var px := (x + .5) / 16.0 * pixels.get_width()
						var py := (y + .5) / 8.0 * pixels.get_height()
						dark_mean += pixels.get_pixel(int(px), int(py)).get_luminance()
						light_mean += pixels.get_pixel(int(px) + pixels.get_width() / 2, int(py)).get_luminance()
				check((light_mean - dark_mean) / 64.0 > .06, label + " authored material readability")
		var palette: Array = MapScene.FlatGround.palette_for(run.theme, cfg)
		var dark := Color(palette[0])
		var light := Color(palette[3])
		check(light.get_luminance() > dark.get_luminance() + .1, label + " light path / dark floor separation")
	check(map._ground_path.has(Vector2i(map._player.position / 48)), label + " spawn clearance")
	for exit_cfg: Dictionary in cfg.get("exits", []):
		check(map._ground_path.has(Vector2i(Layout.point(exit_cfg.at) / 48)), label + " exit " + String(exit_cfg.id))
	for arrival: Array in (cfg.get("spawn_points", {}) as Dictionary).values():
		check(map._ground_path.has(Vector2i(Layout.point(arrival) / 48)), label + " saved arrival clearance")
	var decor_count := 0
	for child in map._world.get_children():
		if child is MapScene._Deco:
			decor_count += 1
			var foot_scale := 1.0
			for part in child.get_children():
				if part is CollisionShape2D:
					foot_scale = part.shape.size.x / 40.0
			check(not map._foot_hits_road(child.position, foot_scale), label + " decoration overhang")
	if cfg.has("decos") and (cfg.decos as Array).is_empty():
		check(decor_count == 0, label + " explicit empty decoration list")
	if mid == "rift_mine_vault":
		check(map._mine_ground != null and map._mine_ground.z_index > map._flat_ground.z_index,
			"mine mechanisms visible above floor")
		check(map._mine_ground.ventilated and map._mine_ground.rescued, "mine saved mechanism state")
	# Sweep the actual player shape along the rendered centerlines. Mechanism barriers are intentional;
	# random decoration collisions on a light route are not.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = map._player_shape.shape
	query.collision_mask = 2
	var mask_image: Image = map._flat_ground.texture.get_image() if map._flat_ground != null else null
	var reachable: Dictionary = _connected_floor(mask_image, map._flat_ground.extent,
		Layout.point(routes[0].points[0])) if mask_image != null else {}
	for route: Dictionary in Layout.sample_routes(routes):
		var points: PackedVector2Array = route.points
		for i in range(0, points.size(), 4):
			if map._flat_ground != null:
				var uv: Vector2 = points[i] / map._flat_ground.extent
				var px := clampi(int(uv.x * mask_image.get_width()), 0, mask_image.get_width() - 1)
				var py := clampi(int(uv.y * mask_image.get_height()), 0, mask_image.get_height() - 1)
				check(mask_image.get_pixel(px, py).r > .9, label + " rendered path covers its centerline")
				check(reachable.has(Vector2i(points[i] / 8.0)), label + " disconnected visible side path at " + str(points[i]))
			query.transform = Transform2D(0, points[i] + map._player_shape.position)
			for hit: Dictionary in map.get_world_2d().direct_space_state.intersect_shape(query, 16):
				check(not hit.collider is MapScene._Deco, label + " blocked visible path at " + str(points[i]))
			samples_checked += 1
	maps_checked += 1
	map.queue_free()
	await get_tree().process_frame

func _connected_floor(pixels: Image, extent: Vector2, start: Vector2) -> Dictionary:
	# Flood the rendered light surface, so a pretty branch cannot stop short of its junction.
	var dims := Vector2i(ceili(extent.x / 8.0), ceili(extent.y / 8.0))
	var first := Vector2i(start / 8.0)
	var visited: Dictionary = {first: true}
	var queue: Array[Vector2i] = [first]
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + offset
			if next.x < 0 or next.y < 0 or next.x >= dims.x or next.y >= dims.y or visited.has(next): continue
			var uv := (Vector2(next) * 8.0 + Vector2(4, 4)) / extent
			var px := mini(int(uv.x * pixels.get_width()), pixels.get_width() - 1)
			var py := mini(int(uv.y * pixels.get_height()), pixels.get_height() - 1)
			if pixels.get_pixel(px, py).r < .6: continue
			visited[next] = true
			queue.append(next)
	return visited
