extends SceneTree
## Export the existing first idle pose as a single image for image-to-video input.

func _initialize() -> void:
	var directory := "res://docs/art_briefs/home_idle_20261005/reference"
	DirAccess.make_dir_recursive_absolute(directory)
	for role in [["zs","pojun"],["ck","chuanyang"],["fs","shuangyu"],["fz","chenxing"]]:
		var texture := load("res://image/role/%s/%s_idle.png" % role) as Texture2D
		if texture == null:
			push_error("HOME_REFERENCE_MISSING " + role[1])
			quit(1)
			return
		var frame := texture.get_image().get_region(Rect2i(0,0,128,128))
		frame.convert(Image.FORMAT_RGBA8)
		var reference := Image.create(160,160,false,Image.FORMAT_RGBA8)
		reference.fill(Color(1,0,1,1))
		reference.blend_rect(frame,Rect2i(0,0,128,128),Vector2i(16,14))
		reference.resize(1280,1280,Image.INTERPOLATE_NEAREST)
		if reference.save_png(directory+"/"+role[1]+"_reference.png") != OK:
			push_error("HOME_REFERENCE_SAVE_FAILED " + role[1])
			quit(1)
			return
		print("HOME_REFERENCE_SAVED ",role[1])
	print("HOME_REFERENCES_OK")
	quit()
