extends Node
## 登录页截图：默认 / 报错 / 软键盘 / 明文密码，800 与 1067 高。
## godot --path . res://tools/CaptureLogin.tscn -- <phase>  → shots/login_20261014/<phase>/
const OUT := "res://shots/login_20261014/"
var phase := "after"

func shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(OUT + phase + "/" + name + ".png") != OK:
		push_error("LOGIN_SHOT_FAIL " + name)

func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		phase = OS.get_cmdline_user_args()[0]
	G.SAVE_PATH = OUT + phase + "_isolated_save.json"
	G.set_meta("ui_review_mode", true)
	G._init_state_defaults()
	G.save_locked = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + phase))
	for height in [800, 1067]:
		get_window().size = Vector2i(480, height)
		await get_tree().process_frame
		await get_tree().process_frame
		var page: Control = load("res://src/ui/Login.tscn").instantiate()
		add_child(page)
		await shot("login_%d" % height)
		page._do_login(false)
		await shot("login_error_%d" % height)
		page._account.text = "shenzhou"
		page._password.text = "abc123"
		page._chest._eye.pressed.emit()
		page._chest.error("")
		await shot("login_filled_%d" % height)
		page._chest._go.grab_focus()
		await shot("login_focus_%d" % height)
		page._account.grab_focus()
		page._chest.layout(Rect2(0, 0, 480, height), 300)
		await shot("login_keyboard_%d" % height)
		page.queue_free()
		await get_tree().process_frame
	print("LOGIN_SHOTS_OK ", phase)
	get_tree().quit()
