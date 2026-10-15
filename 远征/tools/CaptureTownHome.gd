extends Node
## 主城首页预览截图：godot --path . res://tools/CaptureTownHome.tscn
## 输出 shots/town_home_20261013/town_home_<高度>.png（480×800 与 480×1067）。
const OUT := "res://shots/town_home_20261013/"


func _ready() -> void:
	G.SAVE_PATH = OUT + "isolated_save.json"   # 不碰玩家存档
	G.set_meta("ui_review_mode", true)
	G._init_state_defaults()
	G.save_locked = false
	G.player_name = "沈舟"
	G.prog.level = 32
	G.prog.exp = int(G.exp_to_next(32) * 0.62)
	G.wallet = {"gold": 125480, "expedition": 120, "soul": 3860, "honor": 900}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800, 1067]:
		get_window().size = Vector2i(480, height)
		await get_tree().process_frame
		var home: Control = load("res://src/ui/home/TownHome.tscn").instantiate()
		add_child(home)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		var path := OUT + "town_home_%d.png" % height
		if get_viewport().get_texture().get_image().save_png(path) != OK:
			push_error("TOWN_HOME_FAIL " + path)
		home.queue_free()
		await get_tree().process_frame
	print("TOWN_HOME_OK")
	get_tree().quit()
