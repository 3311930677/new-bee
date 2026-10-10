extends RefCounted
## Migrate only the player's world position, retaining all saved progression.
static func migrate(at:Vector2,version:int,cfg:Dictionary)->Vector2:
	if version>=int(cfg.get("layout_version",1)) or at.x<0 or at.y<0:return at
	var record:Dictionary=cfg.get("position_migration",{})
	var spawn:Array=cfg.get("spawn",[480,930])
	var point:=Vector2(spawn[0],spawn[1])
	if String(cfg.get("id",""))=="lorin_wilds" or bool(cfg.get("city",false)):
		if version<=4:return point
		var best:=INF
		var delta:=Vector2.ZERO
		for row:Dictionary in record.get("anchors",[]):
			var old:=Vector2(row.old[0],row.old[1]);var fresh:=Vector2(row.new[0],row.new[1])
			var distance:=at.distance_to(old)
			if distance<best:best=distance;delta=fresh-old
		if best<=180:at+=delta
		else:
			var old_extent:Array=record.get("extent",[960,1920])
			at*=Vector2(float(cfg.map_cols)*48/old_extent[0],float(cfg.map_rows)*48/old_extent[1])
	var river:Dictionary=cfg.get("river",{})
	if not river.is_empty():
		var y:=float(river.get("y",578))
		var points:Array=river.get("points",[])
		if points.size()>=2:y=lerpf(float(points[0][1]),float(points[-1][1]),clampf((at.x-points[0][0])/maxf(1,points[-1][0]-points[0][0]),0,1))
		var span:Array=river.get("crossing",[440,560]);var half:=float(river.get("half",22))
		if absf(at.y-y)<half+24 and (at.x<span[0]+18 or at.x>span[1]-18):at.y=y+(-1 if at.y<y else 1)*(half+40)
	return at.clamp(Vector2(48,48),Vector2(float(cfg.map_cols)*48-48,float(cfg.map_rows)*48-48))
