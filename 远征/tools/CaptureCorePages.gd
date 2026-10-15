extends Node
## 核心玩法页面截图：主页 / 养成 / 装备 / 出征筹备 / 世界地图。
## godot --path . res://tools/CaptureCorePages.tscn -- <phase>  → shots/core_pages_20261013/<phase>/
const OUT := "res://shots/core_pages_20261013/"
var phase := "before"

func wait(sec := 0.7) -> void:
	await get_tree().create_timer(sec).timeout
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(OUT + phase + "/" + name + ".png") != OK:
		push_error("CORE_PAGES_FAIL " + name)

func fresh_home() -> Control:
	var home: Control = preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	await wait()
	return home

func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		phase = OS.get_cmdline_user_args()[0]
	G.SAVE_PATH = OUT + phase + "_isolated_save.json"
	G.set_meta("ui_review_mode", true)
	G._init_state_defaults()
	G.save_locked = false
	G.player_name = "沈舟"
	G.selected_role = "zs"
	G.prog.level = 30
	G.wallet = {"gold": 128400, "expedition": 2310, "soul": 860, "honor": 1240}
	G.ensure_starter_pets()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + phase))
	get_window().size = Vector2i(480, 800)
	await get_tree().process_frame

	var home := await fresh_home()
	await shot("home")
	home._open_growth()
	await wait()
	await shot("growth")
	home._growth._open("equip")
	await wait()
	await shot("equip")
	home.queue_free()
	await get_tree().process_frame

	home = await fresh_home()
	home._on_expedition(home._click_ev())
	await wait()
	await shot("deploy")
	home.queue_free()
	await get_tree().process_frame

	home = await fresh_home()
	home._open_worlds(home._click_ev())
	await wait()
	await shot("worlds")
	home.queue_free()
	await get_tree().process_frame
	print("CORE_PAGES_OK ", phase)
	get_tree().quit()
