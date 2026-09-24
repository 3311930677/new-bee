extends SceneTree
## Mechanical atlas packing only. All poses are drawn by imagegen.
## Run headless with --script res://tools/pack_walk_v6.gd
const ROLES = {"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}
const DIRECTIONS = ["down", "left", "right", "up"]
const OUT = "res://image/role/walk_4dir_review/qa_v6/"
const HEAD_X = {
	"zs": [160.0, 149.0, 163.0, 154.0],
	"ck": [147.0, 148.0, 162.0, 151.0],
	"fs": [147.0, 155.0, 171.0, 160.0],
	"fz": [145.0, 145.0, 170.0, 153.0],
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var report := {"cell": 128, "columns": 4, "rows": 4, "fps": 8,
		"directions": DIRECTIONS, "baseline": 120, "roles": []}
	for id in ROLES:
		var name: String = ROLES[id]
		var source := "res://image/role/%s/source/%s_walk_v6.png" % [id, name]
		var img := Image.load_from_file(source)
		assert(img != null)
		img.convert(Image.FORMAT_RGBA8)
		# Pixel-art export: discard near-transparent RGB fringe, retain solid art.
		for y in img.get_height():
			for x in img.get_width():
				var color := img.get_pixel(x, y)
				if color.a < 0.5:
					img.set_pixel(x, y, Color.TRANSPARENT)
				else:
					color.a = 1.0
					img.set_pixel(x, y, color)
		var row_cuts := _cuts(img, false)
		var atlas := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		var role_report := {"role": id, "source": source, "rows": []}
		for row in 4:
			var strip := img.get_region(Rect2i(0, row_cuts[row], img.get_width(), row_cuts[row + 1] - row_cuts[row]))
			var col_cuts := _cuts(strip, true)
			var frames: Array[Image] = []
			var boxes: Array[Rect2i] = []
			var max_h := 0
			var max_half_width := 0.0
			var tops: Array[int] = []
			var bottoms: Array[int] = []
			var centers: Array[float] = []
			for col in 4:
				var frame := strip.get_region(Rect2i(col_cuts[col], 0, col_cuts[col+1]-col_cuts[col], strip.get_height()))
				var box := frame.get_used_rect()
				assert(box.has_area())
				frames.append(frame)
				boxes.append(box)
				tops.append(box.position.y)
				bottoms.append(box.end.y)
				# Fixed body-axis landmarks, independent of cape/weapon silhouette.
				var center: float = (HEAD_X[id][row] + col * 313.5) * img.get_width() / 1254.0 - col_cuts[col]
				centers.append(center)
				max_half_width = maxf(max_half_width, maxf(center - box.position.x, box.end.x - center))
				max_h = maxi(max_h, box.size.y)
			tops.sort()
			bottoms.sort()
			# One scale per direction, identical for all gait frames.
			var scale_factor := minf(108.0 / max_h, 60.0 / max_half_width)
			var row_report := {"direction": DIRECTIONS[row], "scale": scale_factor, "frames": []}
			for col in 4:
				var frame: Image = frames[col]
				var scaled := frame.duplicate() as Image
				scaled.resize(roundi(frame.get_width() * scale_factor), roundi(frame.get_height() * scale_factor), Image.INTERPOLATE_NEAREST)
				var anchor := Vector2i(64 - roundi(centers[col] * scale_factor), 120 - roundi(bottoms[2] * scale_factor))
				var cell := Image.create(128, 128, false, Image.FORMAT_RGBA8)
				cell.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), anchor)
				var bounds := cell.get_used_rect()
				assert(bounds.position.x >= 2 and bounds.end.x <= 126)
				assert(bounds.position.y >= 2 and bounds.end.y <= 123)
				assert(bounds.end.y >= 116, "%s %s lacks ground contact" % [id, DIRECTIONS[row]])
				atlas.blit_rect(cell, Rect2i(0, 0, 128, 128), Vector2i(col * 128, row * 128))
				row_report.frames.append({"column": col, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "origin": [anchor.x, anchor.y]})
			role_report.rows.append(row_report)
		var output := "res://image/role/%s/%s_walk_4dir.png" % [id, name]
		# Keep the previously active artwork so this replacement is reversible.
		var backup := "res://image/role/%s/source/%s_walk_before_v6.png" % [id, name]
		if not FileAccess.file_exists(backup):
			DirAccess.copy_absolute(output, backup)
		assert(atlas.save_png(output) == OK)
		assert(atlas.save_png(OUT + name + "_sheet.png") == OK)
		role_report["output"] = output
		report.roles.append(role_report)
		print("PACK_V6 ", id, ": ", output)
	var file := FileAccess.open(OUT + "technical_checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit(0)

func _cuts(img: Image, horizontal: bool) -> Array[int]:
	var length := img.get_width() if horizontal else img.get_height()
	var cross := img.get_height() if horizontal else img.get_width()
	var projection: Array[int] = []
	projection.resize(length)
	projection.fill(0)
	for axis in length:
		for other in cross:
			var color := img.get_pixel(axis, other) if horizontal else img.get_pixel(other, axis)
			if color.a > 0.5:
				projection[axis] += 1
	var result: Array[int] = [0]
	for boundary in range(1, 4):
		var expected := length * boundary / 4.0
		var best := roundi(expected)
		var score := INF
		for candidate in range(maxi(1, roundi(expected - length * 0.06)), mini(length - 1, roundi(expected + length * 0.06))):
			var candidate_score := projection[candidate] * 10000.0 + absf(candidate - expected)
			if candidate_score < score:
				score = candidate_score
				best = candidate
		assert(projection[best] <= 2, "No transparent gutter near %s" % expected)
		result.append(best)
	result.append(length)
	return result
