extends Node
## 主页面 UI 前后对比截图：godot --path . res://tools/CaptureMainPages.tscn -- <phase>
## 输出 shots/main_pages_20261013/<phase>/<page>.png（480×800 与 480×1067 两种高度）。
const OUT := "res://shots/main_pages_20261013/"
var phase := "before"

func wait(sec := 0.6) -> void:
	await get_tree().create_timer(sec).timeout
	await RenderingServer.frame_post_draw

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(OUT + phase + "/" + name + ".png") != OK:
		push_error("MAIN_PAGES_FAIL " + name)

func page(path: String) -> Control:
	var node: Control = load(path).instantiate()
	add_child(node)
	return node

func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		phase = OS.get_cmdline_user_args()[0]
	G.SAVE_PATH = OUT + phase + "_isolated_save.json"
	G.set_meta("ui_review_mode", true)
	G._init_state_defaults()
	G.save_locked = false
	G.player_name = "沈舟"
	G.selected_role = "zs"
	G.prog.level = 60
	G.wallet = {"gold": 1000000, "expedition": 999999, "soul": 999999, "honor": 999999}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + phase))
	for height in [800, 1067]:
		get_window().size = Vector2i(480, height)
		await get_tree().process_frame
		var load_page := page("res://src/ui/LoadScreen.tscn")
		await wait(1.2)
		await shot("load_%d" % height)
		load_page.queue_free()
		await get_tree().process_frame
		var title := page("res://src/ui/Title.tscn")
		await wait(1.0)
		await shot("title_%d" % height)
		title._show_intro()
		await wait()
		await shot("intro_%d" % height)
		title._intro_panel.queue_free()
		title._intro_panel = null
		await get_tree().process_frame
		title._open_settings()
		await wait()
		await shot("settings_%d" % height)
		title.queue_free()
		await get_tree().process_frame
		var login := page("res://src/ui/Login.tscn")
		await wait(0.8)
		await shot("login_%d" % height)
		login.queue_free()
		await get_tree().process_frame
		var home := page("res://src/ui/GameHome.tscn")
		await wait(0.8)
		await shot("home_%d" % height)
		home.queue_free()
		await get_tree().process_frame
	print("MAIN_PAGES_OK ", phase)
	get_tree().quit()
