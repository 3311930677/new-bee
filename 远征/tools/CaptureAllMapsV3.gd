extends Node

const OUT := "res://shots/round3_commercial/"
const ARTIFACT_DIR := "C:/Users/Administrator/.gemini/antigravity/brain/1bb250ae-0949-4d1d-b77a-fb355f60ce33/"

const MAP_LIST := [
	"broken_slope",
	"stele_cavern",
	"maple_road",
	"lorin_wilds",
	"old_salt_road",
	"shenyuan_port",
	"tideflat",
	"tidal_gate",
	"red_sand_route",
	"frost_post",
	"rift_mine_road",
	"rift_mine_vault",
	"frost_boardwalk",
	"frost_pass",
	"abyss_ring",
	"stele_entry",
	"stele_resonance",
	"stele_core"
]

func frames(count := 6) -> void:
	for i in count:
		await get_tree().process_frame

func fixture() -> void:
	G._init_state_defaults()
	G.save_locked = true
	G.selected_role = "zs"
	G.player_name = "行旅人"
	G.prog.level = 15

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_window().size = Vector2i(480, 800)
	fixture()
	await frames(10)

	for mid: String in MAP_LIST:
		var run := RunState.new()
		run.setup({"role_id": "zs", "theme": "forest", "level": 15, "potions": 3, "seed": 42})
		MapScene.pending_cfg = {
			"mode": "main_world",
			"main_map_id": mid,
			"run": run,
			"node": {"type": "normal", "layer": 0, "index": 0}
		}

		var map: MapScene = preload("res://src/explore/MapScene.tscn").instantiate()
		add_child(map)
		await frames(15)
		await RenderingServer.frame_post_draw

		var img := get_viewport().get_texture().get_image()
		var local_path: String = ProjectSettings.globalize_path(OUT + "map_" + String(mid) + "_commercial.png")
		img.save_png(local_path)

		var art_path: String = ARTIFACT_DIR + "map_" + String(mid) + "_commercial.png"
		img.save_png(art_path)

		print("CAPTURED COMMERCIAL V3: ", mid)
		map.queue_free()
		await frames(6)

	print("ALL 18 MAPS CAPTURED SUCCESSFULLY IN COMMERCIAL V3 QUALITY!")
	get_tree().quit()
