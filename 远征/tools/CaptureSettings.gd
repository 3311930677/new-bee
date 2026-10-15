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
	# 按下 / 禁用状态：toggle_mode 让按钮停在按下态，便于截图核对（只在截图里改，不影响游戏）
	var chest = panel._chest
	chest.back.button_down.emit()
	chest._select(2)
	var save_page: Control = chest._pages[2]
	var buttons: Array = []
	_collect_buttons(save_page, buttons)
	for i in buttons.size():
		var b: Button = buttons[i]
		if i % 2 == 0:
			b.toggle_mode = true
			b.button_pressed = true
		else:
			b.disabled = true
		b.queue_redraw()
	await shot("states_save")
	chest._select(1)
	buttons.clear()
	_collect_buttons(chest._pages[1], buttons)
	for i in buttons.size():
		var b: Button = buttons[i]
		if i % 2 == 0:
			b.toggle_mode = true
			b.button_pressed = true
		else:
			b.disabled = true
		b.queue_redraw()
	await shot("states_profile")
	chest._select(0)
	for t in chest.shell.tabs.get_children():
		(t as Button).toggle_mode = true
		(t as Button).button_pressed = true
	chest._speed_prev.disabled = false
	chest._speed_prev.toggle_mode = true
	chest._speed_prev.button_pressed = true
	chest.host._speed_btn.disabled = true
	Audio.set_mute(true)
	chest.sync()
	await shot("states_common")
	Audio.set_mute(false)
	print("SETTINGS_SHOTS_OK ", phase)
	get_tree().quit()


func _collect_buttons(root: Node, out: Array) -> void:
	for c in root.get_children():
		if c is Button and not (c is CheckButton): out.append(c)
		_collect_buttons(c, out)
