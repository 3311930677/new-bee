extends Node
## Isolated map art review. Never reads or writes the player's save.
const IDS := ["stele_cavern", "old_salt_road", "shenyuan_port", "tideflat", "tidal_gate", "red_sand_route", "frost_post", "rift_mine_road", "rift_mine_vault", "frost_boardwalk", "frost_pass", "abyss_ring", "stele_entry", "stele_resonance", "stele_core"]
var out := "res://shots/maps_rebuild_20261015/"
var phase := "before"
var failures := 0
var cases := 0
var records: Array = []
var capture := true

func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame

func check(ok: bool, reason: String) -> void:
	cases += 1
	if not ok:
		failures += 1
		push_error("MAP_REBUILD_FAIL " + reason)

func fixture(id: String) -> void:
	G._init_state_defaults()
	G.save_locked = true
	G.selected_role = "zs"
	G.player_name = "行旅人"
	G.prog.level = 30
	G.prog["main_world"] = {"map_id": id, "layout_version": 3}
	G.set_meta("ui_review_mode", true)

func make_map(id: String, setup_flags: Dictionary = {}) -> MapScene:
	fixture(id)
	for key in setup_flags: G.prog.flags[key] = setup_flags[key]
	var run := RunState.new()
	run.setup({"role_id":"zs", "theme":"forest", "level":30, "potions":3, "seed":42})
	MapScene.pending_cfg = {"mode":"main_world", "main_map_id":id, "run":run, "node":{"type":"normal", "layer":0, "index":0}}
	var map := preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	map.set_physics_process(false)
	await frames(12)
	return map

func shot(name_text: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out+phase+"/"+name_text+".png") == OK, "capture " + name_text)

func check_clearance(map: MapScene) -> void:
	var cfg: Dictionary = map._main_cfg
	var space := map.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	query.shape = shape
	query.collision_mask = 2
	query.exclude = [map._player.get_rid()]
	var positions: Array = [cfg.get("spawn", [480,1050])]
	for pt in (cfg.get("spawn_points", {}) as Dictionary).values(): positions.append(pt)
	for pt in positions:
		var at := Vector2(float(pt[0]),float(pt[1]))
		query.transform = Transform2D(0.0, at + Vector2(0,8))
		check(space.intersect_shape(query,1).is_empty(), "%s arrival clear %s" % [map._main_map_id,str(at)])

func check_art(map: MapScene) -> void:
	var cfg: Dictionary = map._main_cfg
	var tex := G.visual_texture(String(cfg.get("background", "")))
	check(tex != null, map._main_map_id + " ground loaded")
	if phase == "after":
		check(bool(cfg.get("painted_ground",false)), map._main_map_id + " uses one painted floor")
		check(map._world.get_node_or_null("SecondaryFloorDepth") == null, map._main_map_id + " legacy floor disabled")
		check(map._world.get_node_or_null("SecondarySceneryLayer") == null, map._main_map_id + " legacy scenery disabled")
		check(cfg.get("decos", []).is_empty(), map._main_map_id + " no random props over new art")
		for child in map.get_children():
			if child is TextureRect and child.texture == tex:
				check(child.size.is_equal_approx(map._map_extent()), map._main_map_id + " exact world extent")
		for exit_row: Dictionary in cfg.get("exits",[]):
			var target: Vector2 = map._world_exit_sign_position(exit_row)
			var at: Vector2 = map._player.position
			for step in 180:
				if at.distance_to(target)<42.0: break
				var next: Vector2 = map._illustrated_navigation.next_point(map,at,target)
				if next.is_equal_approx(at): break
				at = next
			check(at.distance_to(target)<42.0, "%s exit reachable %s" % [map._main_map_id,exit_row.get("id","")])
		var migrated: Vector2 = map._illustrated_navigation.safe_position(cfg,Vector2(12,12))
		check(not map._illustrated_navigation.blocked(cfg,migrated),map._main_map_id+" old position migrates clear")
	check_clearance(map)
	records.append({"map":map._main_map_id,"phase":phase,"ground":cfg.get("background",""),"size":[tex.get_width(),tex.get_height()] if tex != null else [],"extent":str(map._map_extent())})

func overview(map: MapScene, id: String) -> void:
	map._hud.visible = false
	var cam := map.get_viewport().get_camera_2d()
	cam.reparent(map, false)
	cam.position = map._map_extent()/2.0
	cam.offset = Vector2.ZERO
	cam.limit_top = -10000
	cam.limit_bottom = 10000
	cam.limit_left = -10000
	cam.limit_right = 10000
	cam.zoom = Vector2.ONE * minf(480.0/map._map_extent().x,800.0/map._map_extent().y)
	await frames(5)
	await shot(id+"_overview")

func state_review(id: String, flags: Dictionary) -> void:
	var enabled: Dictionary = {}
	if id == "tidal_gate": enabled["act2_tidal_rooms_v1"] = true
	if id == "rift_mine_vault": enabled["act3_mine_rooms_v1"] = true
	if id == "stele_cavern": enabled["act1_stele_rooms_v1"] = true
	var map := await make_map(id,enabled)
	await overview(map,id+"_sealed")
	for key in flags: G.prog.flags[key] = flags[key]
	if id == "tidal_gate":
		map._sync_tidal_room_gates()
		check(not map._tidal_room_gates.has("record") and map._tidal_passages()=="both","tidal states open")
	elif id == "rift_mine_vault":
		map._sync_mine_rooms()
		check(map._mine_room_gates.is_empty(),"mine doors open after completion")
	elif id == "stele_cavern":
		map._sync_stele_room_gates()
		check(map._stele_room_gates.is_empty(),"cavern doors open after alignment")
	await frames(8)
	await overview(map,id+"_activated")
	map.queue_free()
	await frames(3)

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
		if arg == "--no-capture": capture = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out+phase))
	G.SAVE_PATH = out + "isolated_save.json"
	get_window().size = Vector2i(480,800)
	await frames(6)
	for id in IDS:
		var map := await make_map(id)
		await get_tree().physics_frame
		check_art(map)
		await shot(id+"_800")
		await overview(map,id)
		map.queue_free()
		await frames(3)
	if phase == "after":
		get_window().size = Vector2i(480,1067)
		await frames(5)
		for id in IDS:
			var map := await make_map(id)
			await shot(id+"_1067")
			map.queue_free()
			await frames(3)
		get_window().size = Vector2i(480,800)
		await state_review("tidal_gate",{"act2_tide_clue":true,"act2_tide_gate_1":true,"act2_tide_gate_2":true})
		await state_review("rift_mine_vault",{"act3_mine_clue":true,"act3_mine_second_wind":true,"act3_mine_switch":true})
		await state_review("stele_cavern",{"act1_stele_clue":true,"act1_echo_crack_left":true,"act1_echo_crack_middle":true,"act1_echo_crack_right":true,"act1_stele_seat_2":true})
		await state_review("stele_resonance",{"act4_forest_voice":true,"act4_tide_voice":true,"act4_snow_voice":true,"act4_voices_aligned":true})
		await state_review("stele_core",{"act4_avatar_down":true})
	var report := {"phase":phase,"checks":cases,"failures":failures,"maps":records}
	var file := FileAccess.open(out+phase+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("MAP_REBUILD_REVIEW checks=%d failures=%d maps=%d" % [cases,failures,records.size()])
	get_tree().quit(0 if failures == 0 else 1)
