extends SceneTree
## Mechanical packing of imagegen side-view edits; preserve front/back pixels.
const ROLES = {"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}
const OUT = "res://image/role/walk_4dir_review/qa_v7/"
const HEAD_X = {"zs": [151.0, 173.0], "ck": [156.0, 168.0], "fs": [151.0, 174.0], "fz": [145.0, 172.0]}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var review := Image.create(512, 1024, false, Image.FORMAT_RGBA8)
	var role_index := 0
	for id in ROLES:
		var role_name: String = ROLES[id]
		var base := "res://image/role/%s/" % id
		var output := base + role_name + "_walk_4dir.png"
		var backup := base + "source/" + role_name + "_walk_before_v7.png"
		if not FileAccess.file_exists(backup):
			assert(DirAccess.copy_absolute(output, backup) == OK)
		var original := Image.load_from_file(backup)
		var atlas := original.duplicate() as Image
		var source := Image.load_from_file(base + "source/" + role_name + "_walk_side_v7.png")
		assert(source != null)
		source.convert(Image.FORMAT_RGBA8)
		# Ignore near-invisible export fringe when measuring sprite bounds.
		for y in source.get_height():
			for x in source.get_width():
				var color := source.get_pixel(x, y)
				if color.a < 0.5:
					source.set_pixel(x, y, Color.TRANSPARENT)
		var unit := source.get_width() / 4.0
		var unit_y := source.get_height() / 4.0
		for row in [1, 2]:
			var frames: Array[Image] = []
			var maximum_height := 0
			var target_height := 0
			var half_width := 0.0
			var axis: float = HEAD_X[id][row - 1] / 313.5 * unit
			for col in 4:
				var rect := Rect2i(roundi(col * unit), roundi(row * unit_y), roundi((col + 1) * unit) - roundi(col * unit), roundi((row + 1) * unit_y) - roundi(row * unit_y))
				var frame := source.get_region(rect)
				frames.append(frame)
				var bounds := frame.get_used_rect()
				assert(bounds.has_area())
				maximum_height = maxi(maximum_height, bounds.size.y)
				half_width = maxf(half_width, maxf(axis - bounds.position.x, bounds.end.x - axis))
				target_height = maxi(target_height, original.get_region(Rect2i(col * 128, row * 128, 128, 128)).get_used_rect().size.y)
			var factor := minf(float(target_height) / maximum_height, 60.0 / half_width)
			for col in 4:
				var frame := frames[col]
				frame.resize(roundi(frame.get_width() * factor), roundi(frame.get_height() * factor), Image.INTERPOLATE_NEAREST)
				var bounds := frame.get_used_rect()
				var cell := Image.create(128, 128, false, Image.FORMAT_RGBA8)
				cell.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(64 - roundi(axis * factor), 120 - bounds.end.y))
				var packed := cell.get_used_rect()
				assert(packed.position.x >= 2 and packed.end.x <= 126)
				assert(packed.position.y >= 2 and packed.end.y == 120)
				atlas.blit_rect(cell, Rect2i(0, 0, 128, 128), Vector2i(col * 128, row * 128))
		assert(atlas.get_region(Rect2i(0, 0, 512, 128)).get_data() == original.get_region(Rect2i(0, 0, 512, 128)).get_data())
		assert(atlas.get_region(Rect2i(0, 384, 512, 128)).get_data() == original.get_region(Rect2i(0, 384, 512, 128)).get_data())
		assert(atlas.save_png(output) == OK)
		review.blit_rect(atlas, Rect2i(0, 128, 512, 256), Vector2i(0, role_index * 256))
		role_index += 1
		print("SIDE_V7_OK ", id, ": front/back unchanged; 8 side frames grounded at y=120")
	assert(review.save_png(OUT + "side_review.png") == OK)
	quit(0)
