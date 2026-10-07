extends SubViewport
const OUT := "res://shots/frontend_polish_20261007/motion"

func _ready() -> void:
	size = Vector2i(480,800)
	render_target_update_mode = UPDATE_ALWAYS
	G.SAVE_PATH = "res://shots/frontend_polish_20261007/motion_save.json"
	G._init_state_defaults()
	G.set_meta("ui_review_mode",false)
	var title := preload("res://src/ui/Title.tscn").instantiate()
	add_child(title)
	for i in 40: await get_tree().process_frame
	title.process_mode = PROCESS_MODE_DISABLED
	var logo := title.get_node("ExpeditionWordmark")
	for i in 30:
		logo.call("set_reveal",clampf(float(i)/24,0,1))
		await frame("wordmark",i)
	title.queue_free()
	for i in 3: await get_tree().process_frame
	var intro := preload("res://src/ui/IntroductionPanel.gd").new()
	add_child(intro)
	intro._deck.call("go",2,true)
	for i in 30: await get_tree().process_frame
	intro.process_mode = PROCESS_MODE_DISABLED
	for i in 30:
		var phase := clampf(float(i)/24,0,1)
		intro._route_preview.set("progress",.5-.5*cos(PI*phase))
		await frame("journey",i)
	intro.queue_free()
	for i in 3: await get_tree().process_frame
	print("FRONTEND_MOTION_OK frames=60")
	get_tree().quit()

func frame(key: String, index: int) -> void:
	var folder := OUT+"/"+key
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await RenderingServer.frame_post_draw
	if get_texture().get_image().save_png(folder+"/%03d.png"%index)!=OK:
		push_error("FRONTEND_MOTION_FAIL")
		get_tree().quit(1)
