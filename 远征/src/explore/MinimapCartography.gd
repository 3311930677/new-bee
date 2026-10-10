extends RefCounted
## 只将真实道路抽象成地图线条；不生成装饰性、不可通行的假路线。
const Layout := preload("res://src/explore/FlatGroundLayout.gd")
var routes: Array = []

func terrain_thumbnail(map: Node) -> Texture2D:
	var cfg: Dictionary = map.get("_main_cfg")
	var extent: Vector2 = map.call("_map_extent")
	var city: Node = map.get("_city_content")
	var show_roads:=bool(cfg.get("minimap_show_roads",true))
	var signature := str(cfg.get("background","")) + str(extent)+str(show_roads)
	if city != null:
		for b in city.get("_buildings"): signature += str(b.position) + str(b.built())
	if map.get_meta("terrain_signature","") == signature:
		return map.get_meta("terrain_thumbnail") as Texture2D
	var dimensions := Vector2i((extent / maxf(extent.x,extent.y) * 256).round())
	var image := Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8)
	var grass := Color("5e7a45").darkened(0.25)
	var road := Color("c9b88a")
	var building := Color("3a3238")
	image.fill(grass)
	var path := String(cfg.get("background",""))
	if not show_roads:
		# User requested a location map without road diagrams; retain water and landmark silhouettes.
		var river:Dictionary=cfg.get("river",{})
		if not river.is_empty():
			var points:Array=river.get("points",[])
			for x in dimensions.x:
				var wx:=(float(x)+.5)/dimensions.x*extent.x
				var center:=float(river.get("y",0))
				if points.size()>=2:center=lerpf(float(points[0][1]),float(points[-1][1]),clampf((wx-points[0][0])/maxf(1,points[-1][0]-points[0][0]),0,1))
				var y:=roundi(center/extent.y*dimensions.y)
				var height:=maxi(1,roundi(float(river.get("half",20))*2/extent.y*dimensions.y))
				image.fill_rect(Rect2i(x,clampi(y-height/2,0,dimensions.y-height),1,height),Color("405c60"))
	elif not path.is_empty():
		var source := G.visual_texture(path)
		if source != null:
			var pixels := source.get_image()
			if pixels.is_compressed(): pixels.decompress()
			# Match the actual background's aspect-cover crop; keep road forks from the art.
			var source_size := Vector2(pixels.get_size())
			var factor := maxf(extent.x/source_size.x,extent.y/source_size.y)
			var visible := extent/factor
			var origin := (source_size-visible)*0.5
			for y in dimensions.y:
				for x in dimensions.x:
					var pos := origin + Vector2((x+0.5)/dimensions.x,(y+0.5)/dimensions.y)*visible
					var c := pixels.get_pixel(clampi(int(pos.x),0,pixels.get_width()-1),clampi(int(pos.y),0,pixels.get_height()-1))
					var palette := building
					if c.g > c.r*1.05 and c.g > c.b*1.1: palette = grass
					elif c.r > 0.35 and c.r > c.b*1.25 and c.g > c.b*1.2: palette = road
					image.set_pixel(x,y,palette)
	else:
		# Worlds without a ground illustration use their visible sampled road geometry.
		for route: Dictionary in routes:
			var radius := maxf(1.0,float(route.width)*0.5/extent.x*dimensions.x)
			for point: Vector2 in route.points:
				var center := point/extent*Vector2(dimensions)
				for y in range(maxi(0,int(center.y-radius)),mini(dimensions.y,ceili(center.y+radius))):
					for x in range(maxi(0,int(center.x-radius)),mini(dimensions.x,ceili(center.x+radius))):
						if Vector2(x,y).distance_squared_to(center)<=radius*radius: image.set_pixel(x,y,road)
	if city != null:
		for b in city.get("_buildings"):
			if not b.built(): continue
			var p: Vector2 = b.position/extent*Vector2(dimensions)
			var w := maxi(3,roundi(float(b.get("_w"))/extent.x*dimensions.x))
			var h := maxi(3,roundi(float(b.get("_h"))/extent.y*dimensions.y))
			var rect := Rect2i(roundi(p.x-w*0.5),roundi(p.y-h),w,h).intersection(Rect2i(Vector2i.ZERO,dimensions))
			image.fill_rect(rect,building)
			if rect.has_area(): image.fill_rect(Rect2i(rect.position,Vector2i(rect.size.x,1)),Color("6e5434"))
	var texture := ImageTexture.create_from_image(image)
	map.set_meta("terrain_signature",signature)
	map.set_meta("terrain_thumbnail",texture)
	return texture

static func marker(canvas: CanvasItem, point: Vector2, kind: String, facing: Vector2 = Vector2.DOWN) -> void:
	var p := point.round()
	var shadow := Color("0a090b")
	if kind == "npc":
		canvas.draw_rect(Rect2(p-Vector2(3,3),Vector2(6,6)),shadow)
		canvas.draw_rect(Rect2(p-Vector2(2,2),Vector2(5,5)),Color("bfb096"))
	elif kind == "target":
		var poly := PackedVector2Array([p+Vector2(0,-5),p+Vector2(5,0),p+Vector2(0,5),p+Vector2(-5,0),p+Vector2(0,-5)])
		canvas.draw_polyline(poly,shadow,3)
		canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-4),p+Vector2(4,0),p+Vector2(0,4),p+Vector2(-4,0)]),Color("f0b95a"))
	else:
		var side := Vector2(-facing.y,facing.x)
		canvas.draw_colored_polygon(PackedVector2Array([p+facing*5,p-facing*4+side*4,p-facing*4-side*4]),shadow)
		canvas.draw_colored_polygon(PackedVector2Array([p+facing*4,p-facing*3+side*3,p-facing*3-side*3]),Color("f3e8d0"))

func setup(source: Array) -> void:
	routes.clear()
	for route: Dictionary in Layout.sample_routes(source):
		var source_points: PackedVector2Array = route.points
		var points := PackedVector2Array()
		var step := maxi(1, ceili(float(source_points.size()) / 80.0))
		for i in range(0, source_points.size(), step): points.append(source_points[i])
		if not source_points.is_empty() and (points.is_empty() or points[-1] != source_points[-1]):
			points.append(source_points[-1])
		routes.append({"points": points, "width": float(route.width)})

static func plot_rect(dimensions: Vector2, large: bool) -> Rect2:
	var top := 32.0 if large else 22.0
	return Rect2(Vector2(9, top), dimensions - Vector2(18, top + 24))

static func fitted_rect(dimensions: Vector2, extent: Vector2, large: bool) -> Rect2:
	var plot := plot_rect(dimensions, large)
	var factor := minf(plot.size.x / extent.x, plot.size.y / extent.y)
	var size := extent * factor
	return Rect2(plot.position + (plot.size - size) * 0.5, size)

static func project(point: Vector2, extent: Vector2, rect: Rect2) -> Vector2:
	return rect.position + Vector2(clampf(point.x / extent.x, 0, 1), clampf(point.y / extent.y, 0, 1)) * rect.size

static func ground_color(theme: String) -> Color:
	return Color({"forest": "394e40", "snow": "405965", "glacier": "365562",
		"desert": "574e3d", "tomb": "40474c", "volcano": "51413c",
		"abyss": "424252", "castle": "4a5147"}.get(theme, "394e40"))

func draw_roads(canvas: CanvasItem, rect: Rect2, extent: Vector2, large: bool) -> void:
	var factor := rect.size.x / extent.x
	for route: Dictionary in routes:
		var points := PackedVector2Array()
		for point: Vector2 in route.points: points.append(project(point, extent, rect))
		if points.size() < 2: continue
		if not large:
			canvas.draw_polyline(points, Color("b9b795", 0.48), 1.4, true)
			continue
		var width := clampf(float(route.width) * factor * 0.6, 2.5, 16.0)
		canvas.draw_polyline(points, Color("192d2b", 0.7), width + 2, true)
		canvas.draw_polyline(points, Color("aca77a", 0.88), width, true)
		canvas.draw_polyline(points, Color("dad0a0", 0.45), maxf(1, width * 0.2), true)

static func draw_house(canvas: CanvasItem, point: Vector2, large: bool, built: bool) -> void:
	if not large:
		canvas.draw_rect(Rect2(point.round() - Vector2(2, 2), Vector2(4, 4)),
			Color("c2b28c", 0.7) if built else Color("84938a", 0.5))
		return
	var scale := 1.5 if large else 1.0
	var p := point.round()
	var ink := Color("14292d")
	var wall := Color("d8c495") if built else Color("7d8c7e")
	var roof := Color("967447") if built else Color("536961")
	canvas.draw_rect(Rect2(p + Vector2(-4, -2) * scale, Vector2(8, 6) * scale), ink)
	canvas.draw_rect(Rect2(p + Vector2(-3, -2) * scale, Vector2(6, 5) * scale), wall)
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -2) * scale,
		p + Vector2(0, -6) * scale, p + Vector2(5, -2) * scale]), ink)
	canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -2) * scale,
		p + Vector2(0, -4) * scale, p + Vector2(3, -2) * scale]), roof)
	canvas.draw_rect(Rect2(p + Vector2(-1, 0) * scale, Vector2(2, 3) * scale), ink)

static func draw_player(canvas: CanvasItem, point: Vector2, facing: Vector2, large: bool) -> void:
	var scale := 1.25 if large else 1.0
	if large:
		var breath := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.0022)
		canvas.draw_circle(point, (7.5 + breath * 0.6) * scale, Color("ffe2a0", 0.09 + breath * 0.04))
		canvas.draw_arc(point, 6.5 * scale, 0, TAU, 24, Color("ffe2a0", 0.37 + breath * 0.12), 1, true)
	var side := Vector2(-facing.y, facing.x)
	canvas.draw_colored_polygon(PackedVector2Array([point + facing * 6 * scale,
		point - facing * 4 * scale + side * 4.5 * scale,
		point - facing * 4 * scale - side * 4.5 * scale]), Color("13282c"))
	canvas.draw_colored_polygon(PackedVector2Array([point + facing * 4.5 * scale,
		point - facing * 2.5 * scale + side * 3 * scale,
		point - facing * 2.5 * scale - side * 3 * scale]), Color("ffe2a0"))
	canvas.draw_circle(point, 1.2 * scale, Color("fff9db"))
