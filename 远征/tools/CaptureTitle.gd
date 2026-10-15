extends Node
## 标题页截图：800 与 1067 高。godot --path . res://tools/CaptureTitle.tscn -- <phase> → shots/title_20261015/<phase>/
const OUT := "res://shots/title_20261015/"
var phase := "before"

func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		phase = OS.get_cmdline_user_args()[0]
	G.SAVE_PATH = OUT + phase + "_isolated_save.json"
	G.set_meta("ui_review_mode", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + phase))
	for height in [800, 1067]:
		get_window().size = Vector2i(480, height)
		await get_tree().process_frame
		await get_tree().process_frame
		var page: Control = load("res://src/ui/Title.tscn").instantiate()
		add_child(page)
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(OUT + phase + "/title_%d.png" % height) != OK:
			push_error("TITLE_SHOT_FAIL")
		# 键盘 / 手柄操作态：真实按一次向下键，焦点移到下一个可用按钮并显示菱形光标。
		var key := InputEventKey.new()
		key.keycode = KEY_DOWN
		key.pressed = true
		get_viewport().push_input(key, true)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + phase + "/title_nav_%d.png" % height)
		page.queue_free()
		await get_tree().process_frame
	print("TITLE_SHOTS_OK ", phase)
	get_tree().quit()
