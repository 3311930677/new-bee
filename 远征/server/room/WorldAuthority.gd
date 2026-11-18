extends RefCounted
## Go 提供已持久化的起点与会话；客户端不能为起点、时间或速度背书。

static var _allowed_maps_cache: Dictionary = {}


static func _allowed_map(map_id: String) -> bool:
	if _allowed_maps_cache.is_empty():
		var file := FileAccess.open("res://data/online_rules.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				var rules := parsed as Dictionary
				var town_id := String((rules.get("town", {}) as Dictionary).get("map_id", ""))
				if not town_id.is_empty():
					_allowed_maps_cache[town_id] = true
				for key in (rules.get("maps", {}) as Dictionary).keys():
					_allowed_maps_cache[String(key)] = true
	return _allowed_maps_cache.has(map_id)


static func validate_move(args: Dictionary) -> Dictionary:
	var map_id := String(args.get("map_id", ""))
	var cfg: Dictionary = TableCache.main_world_map(map_id)
	if cfg.is_empty() or (not bool(cfg.get("city", false)) and not _allowed_map(map_id)):
		return {"ok": false, "error": "map_unavailable"}
	var start := Vector2(float(args.get("from_x", -1)), float(args.get("from_y", -1)))
	var target := Vector2(float(args.get("x", -1)), float(args.get("y", -1)))
	if not start.is_finite() or not target.is_finite():
		return {"ok": false, "error": "invalid_position"}
	var speed := clampf(float(args.get("speed", 0)), 1, 400)
	var elapsed := clampf(float(args.get("elapsed", 0)), 0, 0.5)
	if start.distance_to(target) > speed * elapsed + 5.0:
		return {"ok": false, "error": "invalid_speed"}
	var bounds := Rect2(16, 16, int(cfg.get("map_cols", 0)) * 48 - 32, int(cfg.get("map_rows", 0)) * 48 - 32)
	if not bounds.has_point(start) or not bounds.has_point(target):
		return {"ok": false, "error": "outside_map"}
	var steps := maxi(1, ceili(start.distance_to(target) / 8.0))
	for step in range(1, steps + 1):
		var point := start.lerp(target, float(step) / steps)
		for id in cfg.get("city_building_positions", {}):
			if id in cfg.get("city_passable", []):
				continue
			var position: Array = cfg.city_building_positions[id]
			var dimensions: Array = cfg.get("city_building_sizes", {}).get(id, [280, 200])
			var block := Rect2(Vector2(float(position[0]) - float(dimensions[0]) * 0.45, float(position[1]) - 48), Vector2(float(dimensions[0]) * 0.9, 40)).grow(16)
			if block.has_point(point):
				return {"ok": false, "error": "blocked"}
	return {"ok": true, "x": target.x, "y": target.y}
