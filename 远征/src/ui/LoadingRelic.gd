extends Control
## Black iron frame and a native, measurable pixel-art progress instrument.
const ART := preload("res://image/ui/loading_relic_20261007/iron_tablet.png")
# Exclude the almost-transparent padding around the generated fittings.
const ART_REGION := Rect2(51,224,1905,327)
const TRACK_ORIGIN := Vector2(46,46)
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
	lit_blade.position = TRACK_ORIGIN-Vector2(0,3)
	lit_blade.size = Vector2(0,6)
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
		draw_texture_rect(_tablet,Rect2(Vector2.ZERO,size),false)
	var y := TRACK_ORIGIN.y
	var blade := PackedVector2Array([Vector2(44,y-6),Vector2(340,y-6),
		Vector2(350,y),Vector2(340,y+6),Vector2(44,y+6)])
	draw_colored_polygon(blade,Color("0e1011"))
	var inset := PackedVector2Array([Vector2(46,y-4),Vector2(338,y-4),
		Vector2(346,y),Vector2(338,y+4),Vector2(46,y+4),Vector2(46,y-4)])
	draw_colored_polygon(inset,Color("30373a"))
	draw_polyline(inset,Color("68716c",.65),1.0,false)
	draw_line(Vector2(46,y),Vector2(338,y),Color("7c8075",.28),1.0)
	for x in range(64,330,28):
		draw_line(Vector2(x,y-2),Vector2(x+4,y),Color("9b967f",.23),1.0)
		draw_line(Vector2(x+4,y),Vector2(x+8,y-2),Color("9b967f",.23),1.0)
	# Wrapped grip and a small bronze crossguard.
	draw_rect(Rect2(23,y-2,18,4),Color("1b1714"))
	draw_line(Vector2(23,y-2),Vector2(40,y-2),Color("b09666"),1.0)
	draw_line(Vector2(23,y+2),Vector2(40,y+2),Color("55422c"),1.0)
	for x in range(25,40,4):
		draw_line(Vector2(x,y-1),Vector2(x+2,y+1),Color("80704d"),1.0)
	_diamond(Vector2(19,y),Vector2(4,4),Color("a68b55"),Color("ead09b"))
	draw_rect(Rect2(40,y-8,3,16),Color("715432"))
	draw_rect(Rect2(40,y-8,1,16),Color("e1c28b"))
	draw_rect(Rect2(38,y-8,7,2),Color("b6955c"))
	draw_rect(Rect2(38,y+6,7,2),Color("80603d"))
	_diamond(Vector2(41,y),Vector2(3,4),Color("294a5c"),Color("97d7e9"))

func _diamond(center: Vector2, radius: Vector2, dark: Color, light: Color) -> void:
	var pts := PackedVector2Array([center+Vector2(0,-radius.y),center+Vector2(radius.x,0),
		center+Vector2(0,radius.y),center+Vector2(-radius.x,0),center+Vector2(0,-radius.y)])
	draw_colored_polygon(pts,dark)
	draw_polyline(pts,Color("bb9e67"),1.0,false)
	draw_line(center+Vector2(0,-radius.y+1),center+Vector2(0,radius.y-1),light,1.0)
	draw_line(center+Vector2(-1,-1),center+Vector2(1,-1),light,1.0)

class LitBlade extends Control:
	var ratio := 0.0
	var breath := .5
	func _draw() -> void:
		var w := size.x
		if w <= 0.0:
			return
		var body_width := minf(w,292.0)
		draw_rect(Rect2(0,0,body_width,6),Color("c7a362"))
		draw_rect(Rect2(0,0,body_width,1),Color("f3deb0"))
		draw_rect(Rect2(0,2,body_width,2),Color("dcc18a"))
		draw_rect(Rect2(0,5,body_width,1),Color("856538"))
		if w > 292.0:
			var tip_end := minf(300.0,w)
			var half_height := 3.0*(300.0-tip_end)/8.0
			var tip := PackedVector2Array([Vector2(292,0),Vector2(tip_end,3-half_height),
				Vector2(tip_end,3+half_height),Vector2(292,6)])
			draw_colored_polygon(tip,Color("d7ba7c"))
		if ratio < 1.0:
			var at := Vector2(roundf(w),3)
			draw_rect(Rect2(at-Vector2(5,6),Vector2(10,12)),Color("77c9e5",.045+.025*breath))
			var gem := PackedVector2Array([at+Vector2(0,-5),at+Vector2(3,0),
				at+Vector2(0,5),at+Vector2(-3,0),at+Vector2(0,-5)])
			draw_colored_polygon(gem,Color("2b697f"))
			draw_polyline(gem,Color("bb9e67"),1.0,false)
			draw_line(at+Vector2(0,-4),at+Vector2(0,4),Color("c1f0f8"),1.0)

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
