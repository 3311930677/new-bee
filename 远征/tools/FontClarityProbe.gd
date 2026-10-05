extends SubViewport

func _ready() -> void:
	size = Vector2i(1080, 700)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var background := ColorRect.new()
	background.color = Color("eee9da")
	background.size = Vector2(size)
	add_child(background)
	var output := "res://shots/ui_all_polish_20261005/font_probe.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	var columns := ["现有：最近邻 / 2倍采样", "对照：线性 / 2倍采样", "对照：线性 / 自动采样"]
	var lines := ["返回营帐 · 领取解锁 · 游戏设置", "背包 道具 回城 继续旅程", "生命 650/650  EXP 38%", "远征 行旅营帐 旅人登记"]
	var fonts := [G.font_reg, G.font_bold, G.font_serif, G.font_display, G.font_art]
	var sizes := [17, 17, 22, 22, 34]
	for col in 3:
		_add_text(columns[col], G.font_reg, 17, Vector2(16+col*360, 15), CanvasItem.TEXTURE_FILTER_LINEAR)
		for row in fonts.size():
			var font: FontFile = fonts[row].duplicate()
			font.oversampling = 0.0 if col == 2 else 2.0
			var y := 60.0 + row*124
			_add_text(font.resource_path.get_file() + "  %dpx" % sizes[row], G.font_reg, 13, Vector2(16+col*360, y), CanvasItem.TEXTURE_FILTER_LINEAR)
			_add_text(lines[0] if row < 2 else lines[1] if row < 4 else lines[3], font, sizes[row], Vector2(16+col*360, y+30), CanvasItem.TEXTURE_FILTER_NEAREST if col == 0 else CanvasItem.TEXTURE_FILTER_LINEAR)
			_add_text(lines[2], font, sizes[row], Vector2(16+col*360+0.5, y+70.5), CanvasItem.TEXTURE_FILTER_NEAREST if col == 0 else CanvasItem.TEXTURE_FILTER_LINEAR)
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	assert(get_texture().get_image().save_png(output) == OK)
	print("FONT_PROBE_SAVED ", output)
	get_tree().quit()

func _add_text(words: String, font: Font, px: int, at: Vector2, filter: int) -> void:
	var label := Label.new()
	label.text = words
	label.position = at
	label.texture_filter = filter
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", Color("313b3a"))
	add_child(label)
