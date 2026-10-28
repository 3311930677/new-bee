extends RefCounted

# The same sampled centerlines drive the visible floor and decoration clearance.
static func sample_routes(routes: Array) -> Array:
	var result: Array = []
	for route: Dictionary in routes:
		var points: Array = route.get("points", [])
		var samples := PackedVector2Array()
		for i in maxi(0, points.size() - 1):
			var a := point(points[maxi(i - 1, 0)])
			var b := point(points[i])
			var c := point(points[i + 1])
			var d := point(points[mini(i + 2, points.size() - 1)])
			var steps := maxi(1, ceili(b.distance_to(c) / 8.0))
			for j in steps:
				var t := float(j) / float(steps)
				var p := 0.5 * ((2.0 * b) + (-a + c) * t +
					(2.0 * a - 5.0 * b + 4.0 * c - d) * t * t +
					(-a + 3.0 * b - 3.0 * c + d) * t * t * t)
				samples.append(p)
		if not points.is_empty(): samples.append(point(points[-1]))
		result.append({"points": samples, "width": float(route.get("width", 144.0))})
	return result

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func clearance(routes: Array, cols: int, rows: int) -> Dictionary:
	var cells: Dictionary = {}
	for route: Dictionary in sample_routes(routes):
		# Include cell half-diagonal and player clearance, so decoration feet cannot overhang a bend.
		var radius := float(route.width) * 0.5 + 44.0
		for p: Vector2 in route.points:
			for y in range(maxi(0, floori((p.y - radius) / 48.0)), mini(rows, ceili((p.y + radius) / 48.0))):
				for x in range(maxi(0, floori((p.x - radius) / 48.0)), mini(cols, ceili((p.x + radius) / 48.0))):
					if Vector2(x * 48 + 24, y * 48 + 24).distance_to(p) <= radius:
						cells[Vector2i(x, y)] = true
	return cells

static func expedition_routes(cells: Dictionary, cols: int, rows: int) -> Array:
	var points: Array = [[cols * 24, rows * 48 - 100]]
	# Keep the saved route's overall course; interpolate its row groups instead of drawing square tiles.
	for y in range(rows - 3, 1, -3):
		var sum_x := 0.0
		var count := 0
		for cell: Vector2i in cells:
			if cell.y == y:
				sum_x += cell.x * 48 + 24
				count += 1
		if count > 0: points.append([sum_x / count, y * 48 + 24])
	points.append([cols * 24, 96])
	var routes: Array = [{"points": points, "width": 90}]
	# Deterministic side loops reuse the existing centerline without consuming gameplay RNG.
	# Space two forks through the playable length so a normal camera view includes a junction.
	for fraction: float in [.68, .43]:
		var lower_y := rows * 48.0 * fraction + 150.0
		var upper_y := lower_y - 320.0
		var lower := _point_at_y(points, lower_y)
		var upper := _point_at_y(points, upper_y)
		var side := -1.0 if fraction > .5 else 1.0
		var offset := 195.0 * side
		routes.append({"points": [[lower.x, lower.y],
			[clampf(lower.x + offset, 100.0, cols * 48.0 - 100.0), lower.y - 90.0],
			[clampf(upper.x + offset, 100.0, cols * 48.0 - 100.0), upper.y + 85.0],
			[upper.x, upper.y]], "width": 62})
	return routes

static func _point_at_y(points: Array, target_y: float) -> Vector2:
	for i in range(points.size() - 1):
		var a := point(points[i])
		var b := point(points[i + 1])
		if target_y <= maxf(a.y, b.y) and target_y >= minf(a.y, b.y):
			return a.lerp(b, (target_y - a.y) / (b.y - a.y))
	return point(points[-1])
