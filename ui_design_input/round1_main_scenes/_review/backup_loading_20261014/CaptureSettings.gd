extends Node
## 设置页三个页签截图：常规 / 旅人 / 存档。
## godot --path . res://tools/CaptureSettings.tscn -- <phase>  → shots/settings_20261014/<phase>/
const OUT := "res://shots/settings_20261014/"
var phase := "before"

func shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(OUT + phase + "/" + name + ".png") != OK:
		push_error("SETTINGS_SHOT_FAIL " + name)

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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + phase))
	get_window().size = Vector2i(480, 800)
	await get_tree().process_frame
	var panel := SettingsPanel.new()
	panel.standalone = true
	add_child(panel)
	await shot("common")
	for i in [1, 2]:
		panel._chest._select(i)
		await shot(["common", "profile", "save"][i])
	print("SETTINGS_SHOTS_OK ", phase)
	get_tree().quit()
