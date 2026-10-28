extends Control
## Black iron frame and a native, measurable pixel-art progress instrument.
const ART := preload("res://image/ui/pixel_20261008/loading_gauge_pixel.png")

const ART_REGION := Rect2(0, 0, 416, 66)
const TRACK_ORIGIN := Vector2(46, 42)
const TRACK_WIDTH := 300.0
var ratio := 0.0
var lit_blade: Control
var _clock := 0.0
var _tablet: AtlasTexture
var _review := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tablet = AtlasTexture.new()
	_tablet.atlas = ART
	_tablet.region = ART_REGION
	lit_blade = LitBlade.new()
	lit_blade.name = "LitBlade"
	lit_blade.position = TRACK_ORIGIN-Vector2(0,4)
	lit_blade.size = Vector2(0,8)
	lit_blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lit_blade)
	_review = bool(G.get_meta("ui_review_mode",false))
	set_process(not _review)

func set_ratio(value: float) -> void:
	ratio = clampf(value,0.0,1.0)
	if lit_blade != null:
		lit_blade.size = Vector2(TRACK_WIDTH*ratio,6)
		lit_blade.set("ratio",ratio)
		lit_blade.queue_redraw()

func fill_width() -> float:
	return lit_blade.size.x if lit_blade != null else 0.0

func _process(delta: float) -> void:
	if ratio <= 0.0 or ratio >= 1.0:
		return
	_clock += delta
	lit_blade.set("breath",.5+.5*sin(_clock*2.2))
	lit_blade.queue_redraw()

func _draw() -> void:
	if _tablet != null:
		draw_texture_rect(_tablet, Rect2(Vector2.ZERO, size), false)

class LitBlade extends Control:
	var ratio := 0.0
	var breath := .5
	func _draw() -> void:
		var w := size.x
		if w <= 0.0:
			return
		var body_width := minf(w, 296.0)
		# Deep cyan base fill
		draw_rect(Rect2(0, 1, body_width, 10), Color("1e768e"))
		# Specular top highlight
		draw_line(Vector2(0, 1), Vector2(body_width, 1), Color("d8f9ff"), 1.0)
		draw_line(Vector2(0, 2), Vector2(body_width, 2), Color("76e5f6"), 1.0)
		# Mid-body crystal core
		draw_line(Vector2(0, 5), Vector2(body_width, 5), Color("3ad2e9"), 2.0)
		# Deep shadow
		draw_line(Vector2(0, 10), Vector2(body_width, 10), Color("0c3442"), 1.0)
		
		# Energy sparks / hash marks
		for x in range(12, int(body_width), 24):
			draw_line(Vector2(x, 2), Vector2(x + 2, 5), Color("eafcff", 0.7), 1.0)

		# Glowing runner diamond at the tip
		if ratio < 1.0:
			var at := Vector2(roundf(w), 6)
			# Outer glow
			draw_circle(at, 7.0, Color("5ce1f2", 0.15 + 0.12 * breath))
			# Diamond gem
			var gem := PackedVector2Array([
				at + Vector2(0, -6), at + Vector2(5, 0),
				at + Vector2(0, 6), at + Vector2(-5, 0)
			])
			draw_colored_polygon(gem, Color("1a6d84"))
			draw_polyline(gem, Color("f2dc87"), 1.0)
			draw_line(at + Vector2(0, -4), at + Vector2(0, 4), Color("e0faff"), 1.0)

class BrandSeal extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var center := size*.5
		var radius := minf(size.x,size.y)*.42
		for ring in [radius,radius-5]:
			var pts := PackedVector2Array()
			for i in range(25):
				var angle := TAU*float(i)/24.0
				pts.append((center+Vector2(cos(angle),sin(angle))*ring).round())
			draw_polyline(pts,Color("9c8050",.23),1.0,false)
		for i in 8:
			var angle := TAU*float(i)/8.0
			var outward := Vector2(cos(angle),sin(angle))
			draw_line((center+outward*(radius-8)).round(),
				(center+outward*(radius+3)).round(),Color("ac905a",.22),1.0)
		draw_line(Vector2(0,size.y-10),Vector2(42,size.y-10),Color("b2935c",.5),1.0)
		draw_line(Vector2(size.x-42,size.y-10),Vector2(size.x,size.y-10),Color("b2935c",.5),1.0)
