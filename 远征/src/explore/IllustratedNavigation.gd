extends RefCounted
## Navigation and saved-position migration use the same authored footprints.
const STEP := 24.0
var grid: AStarGrid2D
var signature := ""

static func blocked(cfg: Dictionary, at: Vector2) -> bool:
	var extent := Vector2(float(cfg.get("map_cols",20))*48,float(cfg.get("map_rows",26))*48)
	if not Rect2(Vector2(24,60),extent-Vector2(48,84)).has_point(at): return true
	var feet := Rect2(at+Vector2(-16,-6),Vector2(32,28))
	for row in cfg.get("block_rects",[]):
		if feet.intersects(Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))): return true
	for row: Dictionary in cfg.get("illustrated_scenery",[]):
		if not row.has("footprint"): continue
		var p := Vector2(float(row.at[0]),float(row.at[1]))
		var size := Vector2(float(row.footprint[0]),float(row.footprint[1]))
		if feet.intersects(Rect2(p-Vector2(size.x*0.5,size.y),size)): return true
	return false

static func safe_position(cfg: Dictionary, at: Vector2) -> Vector2:
	if not blocked(cfg,at): return at
	var fallback: Array = cfg.get("spawn",[480,1050])
	var best := Vector2(float(fallback[0]),float(fallback[1]))
	var distance := INF
	var extent := Vector2(float(cfg.get("map_cols",20))*48,float(cfg.get("map_rows",26))*48)
	for y in range(72,int(extent.y)-24,24):
		for x in range(36,int(extent.x)-24,24):
			var point := Vector2(x,y)
			if point.distance_squared_to(at) < distance and not blocked(cfg,point):
				best = point
				distance = point.distance_squared_to(at)
	return best

func next_point(map: CanvasItem, from: Vector2, target: Vector2) -> Vector2:
	var cfg: Dictionary = map.get("_main_cfg") if map.get("_main_cfg") is Dictionary else {}
	if cfg.is_empty() and map.get("_map_cfg") is Dictionary:
		cfg = map.get("_map_cfg")
	var cols := maxi(2, int(cfg.get("map_cols", 20)) * 2)
	var rows := maxi(2, int(cfg.get("map_rows", 26)) * 2)
	var map_id := String(map.get("_main_map_id") if map.get("_main_map_id") != null else "")
	var current := "%s|%dx%d|%s|%s" % [map_id, cols, rows, JSON.stringify(G.prog.get("flags", {})), str(G.mount_riding())]
	if grid == null or signature != current:
		signature = current
		grid = AStarGrid2D.new()
		grid.region = Rect2i(0,0,cols,rows)
		grid.cell_size = Vector2.ONE*STEP
		grid.offset = Vector2.ONE*(STEP*0.5)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		grid.update()
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 22.0 if G.mount_riding() else 16.0
		query.shape = shape
		query.collision_mask = 2
		var player := map.get("_player") as CollisionObject2D
		if player != null:
			query.exclude = [player.get_rid()]
		for y in rows:
			for x in cols:
				var at := Vector2(x,y)*STEP+Vector2.ONE*(STEP*0.5)
				query.transform = Transform2D(0.0,at+Vector2(0,8))
				var solid := blocked(cfg,at) or not map.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
				grid.set_point_solid(Vector2i(x,y),solid)
	var start := _nearest(from)
	var goal := _nearest(target)
	var path := grid.get_point_path(start,goal,true)
	for point in path:
		if from.distance_to(point)>18.0: return point
	if not path.is_empty() and from.distance_to(path[path.size() - 1]) > 8.0:
		return path[path.size() - 1]
	return target

func _nearest(at: Vector2) -> Vector2i:
	var direct := Vector2i(floori(at.x/STEP),floori(at.y/STEP))
	if grid.is_in_boundsv(direct) and not grid.is_point_solid(direct): return direct
	var best := Vector2i.ZERO
	var distance := INF
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x,y)
			if grid.is_point_solid(cell): continue
			var d := grid.get_point_position(cell).distance_squared_to(at)
			if d < distance:
				distance = d
				best = cell
	return best
