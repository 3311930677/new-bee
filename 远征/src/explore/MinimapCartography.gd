extends RefCounted
## 只将真实道路抽象成地图线条；不生成装饰性、不可通行的假路线。
const Layout := preload("res://src/explore/FlatGroundLayout.gd")
var routes: Array = []

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
