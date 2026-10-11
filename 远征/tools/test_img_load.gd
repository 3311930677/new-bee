extends SceneTree
func _init():
	var p := ProjectSettings.globalize_path("res://image/main_world/broken_slope_ground_v4.png")
	var img := Image.load_from_file(p)
	print("Loaded image: ", img != null, " size: ", img.get_size() if img else "null")
	var tex := ImageTexture.create_from_image(img)
	print("Created ImageTexture: ", tex != null)
	quit()
