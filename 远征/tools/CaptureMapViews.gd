extends Node
## 单图美术验收截图 + 碰撞探测：godot --path . res://tools/CaptureMapViews.tscn -- <map_id> <phase>
## 输出 shots/map_views_20261012/<map_id>/<phase>/；探测结果打印为 MAP_VIEWS_PROBE。
const OUT := "res://shots/map_views_20261012/"
const VIEWS := {
	"broken_slope": [["spawn", Vector2(480, 1060)], ["ford", Vector2(260, 1060)], ["camp", Vector2(660, 1110)],
		["slope_mid", Vector2(620, 640)], ["upper", Vector2(420, 300)], ["north_gate", Vector2(480, 250)]],
	# 视角点离任务实体 ≥70px，避免靠近自动弹出交互面板挡住画面。
	"tideflat": [["spawn", Vector2(165, 700)], ["cargo", Vector2(330, 780)], ["pools", Vector2(220, 470)],
		["salt_lair", Vector2(200, 1080)], ["north_gate", Vector2(480, 200)], ["east_sea", Vector2(790, 560)]],
}
## [起点, 位移]：玩家应被挡住、走不到位移终点。
const PROBES := {
	"broken_slope": [["cliff_w", Vector2(250, 220), Vector2(0, -160)], ["gully", Vector2(350, 1060), Vector2(0, -120)],
		["ford_mid", Vector2(480, 1060), Vector2(0, -120)], ["ford_west", Vector2(245, 1060), Vector2(0, -120)],
		["stele_giant", Vector2(850, 700), Vector2(0, -80)], ["gate_open", Vector2(480, 250), Vector2(0, -80)]],
	"tideflat": [["sea", Vector2(780, 665), Vector2(160, 0)], ["embankment_w", Vector2(250, 220), Vector2(0, -160)],
		["embankment_e", Vector2(700, 220), Vector2(0, -160)], ["gate_open", Vector2(480, 220), Vector2(0, -90)],
		["boat", Vector2(742, 480), Vector2(0, -60)], ["main_path_clear", Vector2(480, 640), Vector2(0, -150)]],
}

var map_id := "tideflat"
var phase := "after"

func frames(count := 8) -> void:
	for i in count:
		await get_tree().process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(OUT + map_id + "/" + phase + "/" + name + ".png") != OK:
		push_error("MAP_VIEWS_FAIL " + name)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: map_id = args[0]
	if args.size() > 1: phase = args[1]
	G.SAVE_PATH = OUT + map_id + "_" + phase + "_isolated_save.json"
	G.set_meta("ui_review_mode", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + map_id + "/" + phase))
	get_window().size = Vector2i(480, 800)
	await frames()
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "行旅人"
	G.prog.level = 30
	var run := RunState.new()
	run.setup({"role_id": "zs", "theme": "forest", "level": 30, "potions": 2, "seed": 17})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": map_id, "run": run, "node": {"type": "normal", "layer": 0, "index": 0}}
	var map: MapScene = preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(map)
	await frames(14)
	for view in VIEWS.get(map_id, []):
		map._player.position = view[1]
		await frames(12)
		await shot(String(view[0]) + "_hud")
	for probe in PROBES.get(map_id, []):
		map._player.position = probe[1]
		await get_tree().physics_frame
		await get_tree().physics_frame
		var hit: KinematicCollision2D = map._player.move_and_collide(probe[2])
		print("MAP_VIEWS_PROBE ", probe[0], " from ", probe[1], " moved ", map._player.position - Vector2(probe[1]),
			" blocked=", hit != null)
	map._hud.visible = false
	var cam := map.get_viewport().get_camera_2d()
	cam.limit_top = -10000; cam.limit_bottom = 10000; cam.limit_left = -10000; cam.limit_right = 10000
	cam.offset = Vector2.ZERO
	cam.zoom = Vector2.ONE * 0.64
	map._player.position = Vector2(480, 624)
	await frames(10)
	await shot("overview_nohud")
	print("MAP_VIEWS_OK ", map_id, " ", phase)
	get_tree().quit()
