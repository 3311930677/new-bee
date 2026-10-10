extends Node
## 昭元边城 / 枫林古道重建前后对比截图：同一隔离存档、同一组视角，输出到 shots/map_rebuild_20261010/<phase>/。
const OUT := "res://shots/map_rebuild_20261010/"

var phase := "before"
var shot_count := 0

func frames(count := 8) -> void:
	for i in count:
		await get_tree().process_frame

func fixture() -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "行旅人"
	G.prog.level = 12
	G.collect_pet("pet_rockturtle")
	G.collect_pet("pet_thunderhawk")

func open_map(id: String) -> MapScene:
	fixture()
	var run := RunState.new()
	run.setup({"role_id": "zs", "theme": "forest", "level": 12, "active_pet": "pet_rockturtle", "potions": 2, "seed": 17})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": id, "run": run, "node": {"type": "normal", "layer": 0, "index": 0}}
	var map: MapScene = preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(map)
	await frames()
	return map

func shot(name: String) -> void:
	shot_count += 1
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(OUT + phase + "/" + name + ".png")
	if result != OK:
		push_error("MAP_REBUILD_CAPTURE_FAIL " + name)
		get_tree().quit(1)

func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		phase = OS.get_cmdline_user_args()[0]
	G.SAVE_PATH = OUT + phase + "_isolated_save.json"
	G.set_meta("ui_review_mode", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + phase))
	get_window().size = Vector2i(480, 800)
	await frames()

	# 城镇：出生点（默认旅程入口）、广场中心、议事厅前、隐藏HUD的美术比例视图。
	var town := await open_map("lorin_wilds")
	await frames(12)
	await shot("lorin_spawn_hud")
	town._player.position = Vector2(480, 640)
	await frames(12)
	await shot("lorin_plaza_hud")
	town._player.position = Vector2(480, 960)
	await frames(12)
	await shot("lorin_hall_hud")
	town._player.position = Vector2(330, 370)
	town._hud.visible = false
	await frames(12)
	await shot("lorin_npc_debug_nohud")
	town._player.position = Vector2(480, 624)
	town.get_viewport().get_camera_2d().zoom = Vector2.ONE * 0.5
	await frames(12)
	await shot("lorin_overview_nohud")
	town.queue_free()
	await frames()

	# 野外：出生点、交汇口、东侧盐道入口方向、北坡、隐藏HUD全图。
	var field := await open_map("maple_road")
	await frames(12)
	await shot("maple_spawn_hud")
	field._player.position = Vector2(480, 700)
	await frames(12)
	await shot("maple_junction_hud")
	field._player.position = Vector2(640, 660)
	await frames(12)
	await shot("maple_east_hud")
	field._player.position = Vector2(480, 300)
	await frames(12)
	await shot("maple_north_hud")
	field._player.position = Vector2(480, 624)
	field._hud.visible = false
	field.get_viewport().get_camera_2d().zoom = Vector2.ONE * 0.5
	await frames(12)
	await shot("maple_overview_nohud")

	print("MAP_REBUILD_CAPTURE_OK ", phase, " views=", shot_count)
	get_tree().quit()
