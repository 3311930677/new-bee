extends RefCounted
## Pixel fantasy display components. Input remains in Field.Action.
const Field := preload("res://src/ui/FieldUI.gd")
const BACKGROUND := "res://image/background/art_v2/camp_bluehour.png"
const WHITE := Color("f5ead4")
const GOLD := Color("dfbf82")
const MUTED := Color("a9bec0")
const DARK := Color("152630")
const ROLE_COLORS := {"zs":Color("eeab74"),"ck":Color("8ed3ac"),"fs":Color("8ed8f2"),"fz":Color("d7b7f4")}

static func label(words: String,at: Vector2,extent: Vector2,px := 16,color := WHITE,bold := false,title := false) -> Label:
	var l := Field.label(words,at,extent,px,color,bold,title)
	clean_label(l)
	return l

static func clean_label(l: Label) -> void:
	# Text stays smooth at phone scale; pixel filtering belongs to sprites only.
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	l.add_theme_constant_override("outline_size",0)
	l.add_theme_constant_override("shadow_offset_x",0)
	l.add_theme_constant_override("shadow_offset_y",0)

static func action(words: String,at: Vector2,extent: Vector2,skin := "secondary") -> Control:
	var b := Field.action(words,at,extent)
	b.skin = skin
	b.caption.add_theme_color_override("font_color",Color("f1dfb5") if skin=="primary" else WHITE)
	b.caption.add_theme_font_size_override("font_size",G.FS_MD)
	b.caption.add_theme_font_override("font",G.font_serif)
	if skin=="scroll": b.caption.add_theme_color_override("font_color",Color("3d433b"))
	clean_label(b.caption)
	return b

static func panel(at: Vector2,extent: Vector2,opacity := .92) -> Control:
	var p := MaterialPanel.new()
	p.position = at
	p.size = extent
	p.opacity = opacity
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func icon(parent: Control,key: String,at: Vector2,extent := Vector2(40,40)) -> Control:
	var art := Field.Prop.new()
	art.key = key
	art.size = extent
	art.custom_minimum_size = extent
	art.position = at
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

static func scene(parent: Control,dim := .04) -> void:
	G.page_background(parent,dim,BACKGROUND,false)
	var atmosphere := Atmosphere.new()
	atmosphere.name = "DisplayAtmosphere"
	atmosphere.size = G._veil_viewport_size(parent)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(atmosphere)
	parent.resized.connect(func(): atmosphere.size = G._veil_viewport_size(parent); atmosphere.queue_redraw())

static func heading(parent: Control,words: String,note: String) -> void:
	var plaque := TextureRect.new()
	plaque.texture = G.Visuals._kit_tex("plaque_title.png")
	plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaque.stretch_mode = TextureRect.STRETCH_SCALE
	plaque.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaque.position = Vector2(20, 20)
	plaque.size = Vector2(228, 48)
	plaque.modulate = Color(1, 1, 1, 0.45)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(plaque)
	parent.add_child(label(words,Vector2(28,22),Vector2(320,46),G.FS_BIG,WHITE,true,true))
	parent.add_child(label(note,Vector2(28,70),Vector2(350,24),G.FS_XS,MUTED))
	Field.line(parent,Vector2(28,108),424,Color(GOLD,.45))

class MaterialPanel extends Control:
	var opacity := .92
	func _draw() -> void:
		if size.x < 12 or size.y < 12:
			return
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var outline := G.octagon_path(size,0,5)
		draw_set_transform(Vector2(0,4))
		draw_colored_polygon(outline,Color("07121a",.48))
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(outline,Color("152832",opacity))
		var tex := G.Visuals._kit_tex("panel_iron.png" if (size.x >= 180 and size.y >= 90) else "btn_row.png")
		G.Visuals.nine_slice(self, tex, Rect2(Vector2.ZERO, size), 12.0, 10.0, Color(1, 1, 1, minf(0.82, opacity * 0.78)))
		draw_line(Vector2(5,0),Vector2(size.x-5,0),Color("d2b27a",.68))
		draw_line(Vector2(5,size.y-1),Vector2(size.x-5,size.y-1),Color("5e7779",.42))
		var rim := G.octagon_path(size, 1.5, 4.0)
		rim.append(rim[0])
		draw_polyline(rim, Color("d2b27a", 0.35), 1.0)
		for x in [4.0,size.x-6]:
			draw_rect(Rect2(x,4,2,2),Color("f3dca2",.85))
			draw_rect(Rect2(x,size.y-6,2,2),Color("d2b27a",.72))

class Atmosphere extends Control:
	func _draw() -> void:
		# Color and edge shading preserve every background pixel; there is no blur.
		draw_rect(Rect2(Vector2.ZERO,size),Color("102536",.10))
		for i in 32:
			var fraction := float(i)/32
			draw_rect(Rect2(0,i*4,size.x,4),Color("081520",.52*(1-fraction)))
			var y := size.y-256+i*8
			draw_rect(Rect2(0,y,size.x,8),Color("07141d",fraction*.85))
			draw_rect(Rect2(i*3,132,3,size.y-280),Color("0b1b27",.30*(1-fraction)))
			draw_rect(Rect2(size.x-i*3-3,132,3,size.y-280),Color("0b1b27",.30*(1-fraction)))

class Stage extends Control:
	var hue := Color("e4b777")
	var phase := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(not bool(G.get_meta("ui_review_mode",false)))
	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()
	func _draw() -> void:
		var center := Vector2(size.x*.5,size.y*.45)
		for i in range(7,0,-1):
			draw_circle(center,float(i)*size.x*.062,Color(hue,.008+float(7-i)*.003))
		draw_set_transform(Vector2(size.x*.5,size.y*.89),0,Vector2(1,.23))
		draw_circle(Vector2.ZERO,size.x*.46,Color("07121c",.23))
		draw_arc(Vector2.ZERO,size.x*.46,.12,PI-.12,56,Color(hue,.48),2)
		draw_arc(Vector2.ZERO,size.x*.40,PI+.15,TAU-.15,48,Color(hue,.28),1)
		draw_set_transform(Vector2.ZERO)
		for i in 4:
			var at := Vector2(size.x*(.20+i*.20),size.y*(.38+.17*sin(i*2.3+phase*.35)))
			G.Visuals.diamond(self,at,1.5,Color(hue,.20+.13*sin(phase+i)))

class Crest extends Control:
	var hue := Color("8ed8f2")
	func _draw() -> void:
		var c := size*.5
		draw_arc(c, minf(size.x,size.y)*.48,PI*.12,PI*.88,48,Color(GOLD,.20),1)
		draw_arc(c, minf(size.x,size.y)*.48,PI*1.12,PI*1.88,48,Color(GOLD,.20),1)
		for at in [Vector2(c.x,4),Vector2(c.x,size.y-4)]:
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-4),at+Vector2(3,0),at+Vector2(0,4),at+Vector2(-3,0)]),Color(hue,.50))
