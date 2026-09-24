extends SceneTree
## Pack the approved six-column imagegen atlases into Godot's 128px cells.
const ROLES := {"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}
const DIRECTIONS := ["down", "left", "right", "up"]
const COLS := 6
const CELL := 128
const FPS := 8.0
const QA := "res://image/role/walk_4dir_review/qa_v13/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(QA)
	var report := {"cell": CELL, "columns": COLS, "rows": 4,
		"directions": DIRECTIONS, "fps": FPS, "atlas_size": [COLS * CELL, 4 * CELL], "roles": []}
	for id in ROLES:
		var name: String = ROLES[id]
		var source_path := "res://image/role/%s/source/%s_walk_v13.png" % [id, name]
		var source := Image.load_from_file(source_path)
		assert(source != null and source.get_size() == Vector2i(1536, 1024),
			"%s must be a 6x4 sheet of 256px cells" % source_path)
		source.convert(Image.FORMAT_RGBA8)
		var atlas := Image.create(COLS * CELL, 4 * CELL, false, Image.FORMAT_RGBA8)
		var entries: Array = []
		for row in 4:
			for col in COLS:
				var frame := source.get_region(Rect2i(col * 256, row * 256, 256, 256))
				# Cut almost transparent fringe while preserving every opaque pixel.
				for y in 256:
					for x in 256:
						var pixel := frame.get_pixel(x, y)
						pixel.a = 1.0 if pixel.a >= 0.5 else 0.0
						frame.set_pixel(x, y, pixel)
				# Native-resolution point sampling; no interpolated filtering.
				var reduced := frame.duplicate() as Image
				reduced.resize(CELL, CELL, Image.INTERPOLATE_NEAREST)
				# Imagegen can leave detached boot/edge fragments inside a cell.
				# Keep the connected character silhouette before finding its ground line.
				reduced = _keep_largest_component(reduced)
				# Find the lowest solid pixel after downsampling. Feet can sit off-center
				# in a strict side pose, so inspect the entire frame width.
				var body_ground := 0
				for y in range(CELL - 1, 79, -1):
					for x in CELL:
						if reduced.get_pixel(x, y).a > 0.5:
							body_ground = y
							break
					if body_ground > 0:
						break
				if body_ground == 0:
					var used := reduced.get_used_rect()
					body_ground = used.end.y - 1
				assert(body_ground >= 80, "%s row %d frame %d has no grounded pixel" % [id, row, col])
				var offset_y := 120 - body_ground
				var cell_image := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
				var src_y := maxi(0, -offset_y)
				var dst_y := maxi(0, offset_y)
				var copy_height := mini(CELL - src_y, CELL - dst_y)
				cell_image.blit_rect(reduced, Rect2i(0, src_y, CELL, copy_height), Vector2i(0, dst_y))
				var bounds := cell_image.get_used_rect()
				assert(bounds.has_area() and bounds.position.y >= 0 and bounds.end.y <= 128)
				atlas.blit_rect(cell_image, Rect2i(0, 0, CELL, CELL), Vector2i(col * CELL, row * CELL))
				entries.append({"row": DIRECTIONS[row], "frame": col, "body_ground": body_ground,
					"packed_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]})
		var atlas_path := "res://image/role/%s/%s_walk_4dir.png" % [id, name]
		assert(atlas.save_png(atlas_path) == OK)
		assert(atlas.save_png(QA + name + "_sheet.png") == OK)
		_write_frames("res://image/role/%s/%s_walk_frames.tres" % [id, name], atlas_path, name)
		report.roles.append({"id": id, "source": source_path, "atlas": atlas_path, "frames": entries})
		print("WALK_GAIT_V13_PACKED ", id, ": six frames x four directions, detached fragments removed")
	var file := FileAccess.open(QA + "technical_checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit(0)

func _write_frames(path: String, atlas: String, _name: String) -> void:
	var lines := PackedStringArray(["[gd_resource type=\"SpriteFrames\" load_steps=26 format=3]", "",
		"[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1\"]" % atlas, ""])
	for row in 4:
		for col in COLS:
			var index := row * COLS + col
			lines.append_array([
				"[sub_resource type=\"AtlasTexture\" id=\"Atlas_%d\"]" % index,
				"atlas = ExtResource(\"1\")",
				"region = Rect2(%d, %d, 128, 128)" % [col * 128, row * 128],
				"filter_clip = true", ""
			])
	lines.append("[resource]")
	lines.append("animations = [")
	for row in 4:
		var frame_strings := PackedStringArray()
		for col in COLS:
			frame_strings.append("{\"duration\": 1.0, \"texture\": SubResource(\"Atlas_%d\")}" % (row * COLS + col))
		lines.append("{")
		lines.append("\"frames\": [%s]," % ", ".join(frame_strings))
		lines.append("\"loop\": true,")
		lines.append("\"name\": &\"walk_%s\"," % DIRECTIONS[row])
		lines.append("\"speed\": %.1f" % FPS)
		lines.append("}" if row == 3 else "},")
	lines.append("]")
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string("\n".join(lines) + "\n")


func _keep_largest_component(image: Image) -> Image:
	var visited := PackedByteArray()
	visited.resize(CELL * CELL)
	visited.fill(0)
	var largest := PackedInt32Array()
	for y in CELL:
		for x in CELL:
			var start := y * CELL + x
			if visited[start] != 0 or image.get_pixel(x, y).a <= 0.5:
				continue
			var component := PackedInt32Array([start])
			visited[start] = 1
			var head := 0
			while head < component.size():
				var current := component[head]
				head += 1
				var cy := int(current / CELL)
				var cx := current % CELL
				for ny in range(maxi(0, cy - 1), mini(CELL - 1, cy + 1) + 1):
					for nx in range(maxi(0, cx - 1), mini(CELL - 1, cx + 1) + 1):
						var next := ny * CELL + nx
						if visited[next] == 0 and image.get_pixel(nx, ny).a > 0.5:
							visited[next] = 1
							component.append(next)
			if component.size() > largest.size():
				largest = component
	var cleaned := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	for index in largest:
		var point := Vector2i(index % CELL, int(index / CELL))
		cleaned.set_pixel(point.x, point.y, image.get_pixelv(point))
	return cleaned
