extends Node
## 18 张主世界地图美术普查：每图出生点视角（无 HUD）+ 全图总览，隔离存档，输出到 shots/map_survey_20261012/。
const OUT := "res://shots/map_survey_20261012/"

func frames(count := 8) -> void:
	for i in count:
		await get_tree().process_frame

func fixture() -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "行旅人"
	G.prog.level = 30

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(OUT + name + ".png") != OK:
		push_error("MAP_SURVEY_FAIL " + name)

var keep_hud := false
var phase := ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "hud":
		keep_hud = true
		phase = args[1]
	G.SAVE_PATH = OUT + "isolated_save.json"
	G.set_meta("ui_review_mode", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + phase))
	get_window().size = Vector2i(480, 800)
	await frames()
	var ids: Array = (TableCache.main_world_config().get("maps", {}) as Dictionary).keys()
	for id in ids:
		fixture()
		var run := RunState.new()
		run.setup({"role_id": "zs", "theme": "forest", "level": 30, "potions": 2, "seed": 17})
		MapScene.pending_cfg = {"mode": "main_world", "main_map_id": id, "run": run, "node": {"type": "normal", "layer": 0, "index": 0}}
		var map: MapScene = preload("res://src/explore/MapScene.tscn").instantiate()
		add_child(map)
		await frames(14)
		if keep_hud:
			# 光效普查：暗角与天气层挂在 HUD 下，只拍出生点（不拍总览）。
			await shot(phase + "/" + String(id) + "_spawn_hud")
			map.queue_free()
			await frames(6)
			continue
		map._hud.visible = false
		await frames(4)
		await shot(String(id) + "_spawn")
		var cam := map.get_viewport().get_camera_2d()
		var size := Vector2(float(map._map_cfg.get("map_cols", 20)) * 48.0, float(map._map_cfg.get("map_rows", 26)) * 48.0)
		cam.limit_top = -10000; cam.limit_bottom = 10000; cam.limit_left = -10000; cam.limit_right = 10000
		cam.offset = Vector2.ZERO
		cam.zoom = Vector2.ONE * minf(480.0 / size.x, 800.0 / size.y)
		map._player.position = size / 2
		await frames(8)
		await shot(String(id) + "_overview")
		print("MAP_SURVEY ", id)
		map.queue_free()
		await frames(6)
	print("MAP_SURVEY_OK ", ids.size())
	get_tree().quit()
