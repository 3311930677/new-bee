extends SubViewport
const Icons = preload("res://src/ui/UIIcons.gd")
const OUT = "res://shots/icons_20261007/icon_sizes.png"

func _ready() -> void:
	G.set_meta("ui_review_mode",true)
	size = Vector2i(480,840)
	render_target_update_mode = UPDATE_ALWAYS
	for band: int in 2:
		var panel := ColorRect.new()
		panel.color = Color("102833") if band == 0 else Color("e8e0ce")
		panel.size = Vector2(480,420)
		panel.position.y = band*420
		add_child(panel)
		for i: int in Icons.ILLUSTRATED_KEYS.size():
			var key: String = Icons.ILLUSTRATED_KEYS[i]
			var origin := Vector2(16+(i%4)*116,band*420+16+(i/4)*100)
			var label := Label.new()
			label.position = origin
			label.text = key + " · 40 / 24"
			label.add_theme_font_size_override("font_size",11)
			label.add_theme_color_override("font_color",Color("e8e0ce") if band == 0 else Color("102833"))
			add_child(label)
			for extent: int in [40,24]:
				var art := Icons.image(key,Vector2.ONE*extent)
				art.position = origin+Vector2(8 if extent == 40 else 66,26 if extent == 40 else 34)
				add_child(art)
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_texture().get_image().save_png(OUT)
	print("ICON_BOARD_OK")
	get_tree().quit()
