extends SceneTree
## Packaging transforms only. The selected icon.png remains the art master.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/launcher")
	var original := Image.load_from_file("res://icon.png")
	original.convert(Image.FORMAT_RGBA8)
	var ordinary := original.duplicate() as Image
	ordinary.resize(192,192,Image.INTERPOLATE_LANCZOS)
	ordinary.save_png("res://assets/launcher/main_192.png")
	var foreground := Image.create(432,432,false,Image.FORMAT_RGBA8)
	foreground.fill(Color.TRANSPARENT)
	original.resize(264,264,Image.INTERPOLATE_LANCZOS)
	foreground.blit_rect(original,Rect2i(0,0,264,264),Vector2i(84,84))
	foreground.save_png("res://assets/launcher/foreground_432.png")
	var background := Image.create(432,432,false,Image.FORMAT_RGB8)
	background.fill(Color("17252f"))
	background.save_png("res://assets/launcher/background_432.png")
	print("LAUNCHER_ICONS_OK selected icon.png with adaptive safe padding")
	quit()
