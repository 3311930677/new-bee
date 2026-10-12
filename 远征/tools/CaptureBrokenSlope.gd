extends Node
## 断碑坡美术重构前后对比截图：同一隔离存档、同一组视角，输出到 shots/broken_slope_v2_20261012/<phase>/。
const OUT := "res://shots/broken_slope_v2_20261012/"
const VIEWS := [
	["spawn", Vector2(480, 1040)],
	["gully", Vector2(480, 990)],
	["camp", Vector2(560, 880)],
	["stele", Vector2(560, 760)],
	["terrace", Vector2(415, 600)],
	["north_gate", Vector2(480, 230)],
]

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

func shot(name: String) -> void:
	shot_count += 1
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(OUT + phase + "/" + name + ".png") != OK:
		push_error("BROKEN_SLOPE_CAPTURE_FAIL " + name)
		get_tree().quit(1)

func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		phase = OS.get_cmdline_user_args()[0]
	G.SAVE_PATH = OUT + phase + "_isolated_save.json"
	G.set_meta("ui_review_mode", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + phase))
	get_window().size = Vector2i(480, 800)
	await frames()
	fixture()
	var run := RunState.new()
	run.setup({"role_id": "zs", "theme": "forest", "level": 12, "active_pet": "pet_rockturtle", "potions": 2, "seed": 17})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "broken_slope", "run": run, "node": {"type": "normal", "layer": 0, "index": 0}}
	var map: MapScene = preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(map)
	await frames(12)
	for view in VIEWS:
		map._player.position = view[1]
		await frames(12)
		await shot(String(view[0]) + "_hud")
	map._hud.visible = false
	map._player.position = Vector2(480, 624)
	map.get_viewport().get_camera_2d().limit_top = -10000
	map.get_viewport().get_camera_2d().limit_bottom = 10000
	map.get_viewport().get_camera_2d().zoom = Vector2.ONE * 0.64
	await frames(12)
	await shot("overview_nohud")
	print("BROKEN_SLOPE_CAPTURE_OK ", phase, " views=", shot_count)
	get_tree().quit()
