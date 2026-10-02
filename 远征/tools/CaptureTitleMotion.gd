extends Node
## 记录实际 Godot 标题 Tween 的 15 fps 帧序列，按 --fixed-fps=60 运行。
func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_title_motion.json"
	G.set_meta("ui_review_mode", false)
	var output := "res://shots/aesthetic_refinement_20261002/motion_frames"
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 800)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(load("res://src/ui/Title.tscn").instantiate())
	for i in 26:
		for step in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var err := viewport.get_texture().get_image().save_png("%s/frame_%02d.png" % [output, i])
		if err != OK:
			push_error("TITLE_MOTION_SAVE_FAILED")
			get_tree().quit(1)
			return
	print("TITLE_MOTION_SAVED 26")
	get_tree().quit()
