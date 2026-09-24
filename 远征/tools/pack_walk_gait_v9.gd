extends SceneTree
## Pack imagegen poses only. Preview candidates before installing the atlas.
const ROLES = {"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}
const OUT = "res://image/role/walk_4dir_review/qa_v9/"
const CHARACTER_HEIGHT := 96

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var review := Image.create(512, 1024, false, Image.FORMAT_RGBA8)
	var role_index := 0
	for id in ROLES:
		var role_name: String = ROLES[id]
		var base := "res://image/role/%s/" % id
		var output := base + role_name + "_walk_4dir.png"
		var backup := base + "source/" + role_name + "_walk_before_v8.png"
		if not FileAccess.file_exists(backup):
			assert(DirAccess.copy_absolute(output, backup) == OK)
		var original := Image.load_from_file(backup)
		var atlas := original.duplicate() as Image
		var version := "v9" if id in ["zs", "ck"] else "v8"
		var source := Image.load_from_file(base + "source/" + role_name + "_walk_side_" + version + ".png")
		assert(source != null)
		source.convert(Image.FORMAT_RGBA8)
		for y in source.get_height():
			for x in source.get_width():
				if source.get_pixel(x, y).a < 0.5:
					source.set_pixel(x, y, Color.TRANSPARENT)
		var unit := source.get_width() / 4.0
		var unit_y := source.get_height() / 2.0
		for row in 2:
			var frames: Array[Image] = []
			var centers: Array[float] = []
			var tops: Array[int] = []
			var bottoms: Array[int] = []
			var maximum_height := 0
			var half_width := 0.0
			for col in 4:
				var frame := source.get_region(Rect2i(roundi(col * unit), roundi(row * unit_y), roundi((col + 1) * unit) - roundi(col * unit), roundi((row + 1) * unit_y) - roundi(row * unit_y)))
				frames.append(frame)
				var bounds := frame.get_used_rect()
				assert(bounds.has_area())
				# Upper silhouette landmarks register the torso independently of swinging feet.
				var head := frame.get_region(Rect2i(0, bounds.position.y, frame.get_width(), roundi(bounds.size.y * 0.38))).get_used_rect()
				# Register to the fixed cell body axis, not the ponytail/weapon silhouette.
				var center := frame.get_width() / 2.0
				centers.append(center)
				tops.append(bounds.position.y)
				bottoms.append(bounds.end.y)
				maximum_height = maxi(maximum_height, bounds.size.y)
				half_width = maxf(half_width, maxf(center - bounds.position.x, bounds.end.x - center))
			var factor := float(CHARACTER_HEIGHT) / maximum_height
			assert(half_width * factor <= 63.0, "Uniform height would clip a weapon")
			var target_top := 120 - roundi(maximum_height * factor)
			for col in 4:
				var frame := frames[col]
				frame.resize(roundi(frame.get_width() * factor), roundi(frame.get_height() * factor), Image.INTERPOLATE_NEAREST)
				var cell := Image.create(128, 128, false, Image.FORMAT_RGBA8)
				cell.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(64 - roundi(centers[col] * factor), target_top - roundi(tops[col] * factor)))
				var packed := cell.get_used_rect()
				assert(packed.position.x >= 1 and packed.end.x <= 127)
				assert(packed.position.y >= 2 and packed.end.y <= 122 and packed.end.y >= 115)
				atlas.blit_rect(cell, Rect2i(0, 0, 128, 128), Vector2i(col * 128, (row + 1) * 128))
		# Same display height for front/back as side poses; one fixed scale per row.
		for row in [0, 3]:
			var max_height := 0
			for col in 4:
				max_height = maxi(max_height, original.get_region(Rect2i(col * 128, row * 128, 128, 128)).get_used_rect().size.y)
			var factor := float(CHARACTER_HEIGHT) / max_height
			for col in 4:
				var frame := original.get_region(Rect2i(col * 128, row * 128, 128, 128))
				frame.resize(roundi(128 * factor), roundi(128 * factor), Image.INTERPOLATE_NEAREST)
				var bounds := frame.get_used_rect()
				var cell := Image.create(128, 128, false, Image.FORMAT_RGBA8)
				cell.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(64 - roundi(64 * factor), 120 - bounds.end.y))
				atlas.blit_rect(cell, Rect2i(0, 0, 128, 128), Vector2i(col * 128, row * 128))
		for row in 4:
			var heights: Array[int] = []
			for col in 4:
				var bounds := atlas.get_region(Rect2i(col * 128, row * 128, 128, 128)).get_used_rect()
				assert(bounds.position.x >= 1 and bounds.end.x <= 127)
				heights.append(bounds.size.y)
			print("HEIGHT ", id, " row ", row, ": ", heights)
		assert(atlas.save_png(OUT + role_name + "_candidate.png") == OK)
		review.blit_rect(atlas, Rect2i(0, 128, 512, 256), Vector2i(0, role_index * 256))
		role_index += 1
		print("GAIT_V8_CANDIDATE_OK ", id)
	assert(review.save_png(OUT + "side_review.png") == OK)
	quit(0)
