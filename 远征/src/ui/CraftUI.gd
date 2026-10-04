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
	l.add_theme_color_override("font_shadow_color",Color("081522",.80))
	l.add_theme_constant_override("shadow_offset_x",0)
	l.add_theme_constant_override("shadow_offset_y",2)
	return l

static func action(words: String,at: Vector2,extent: Vector2,skin := "secondary") -> Control:
	var b := Field.action(words,at,extent)
	b.skin = skin
	b.caption.add_theme_color_override("font_color",Color("32291c") if skin=="primary" else WHITE)
	b.caption.add_theme_font_size_override("font_size",18)
	return b

static func panel(at: Vector2,extent: Vector2,opacity := .92) -> Control:
	var p := MaterialPanel.new()
	p.position = at
	p.size = extent
	p.opacity = opacity
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func icon(parent: Control,key: String,at: Vector2,extent := Vector2(40,40)) -> TextureRect:
	var art := G.ui_icon(key,extent)
	var detailed: String = {"world":"f6_icon_quest","bag":"f6_icon_backpack","book":"itm_pet_book",
		"settings":"f6_icon_settings","paw":"f6_icon_pet","mount":"f6_icon_mount",
		"swords":"zs_sword_t2","growth":"itm_aptitude_fruit","summon":"cur_soul",
		"exchange":"f6_icon_shop","crown":"cur_honor"}.get(key,"")
	if not detailed.is_empty():
		var tex := G.res_tex(detailed)
		if tex != null: art.texture = tex
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	parent.add_child(label(words,Vector2(26,24),Vector2(320,46),28,WHITE,true,true))
	parent.add_child(label(note,Vector2(28,70),Vector2(350,24),14,MUTED))
	Field.line(parent,Vector2(28,108),424,Color(GOLD,.35))

class MaterialPanel extends Control:
	var opacity := .92
	func _draw() -> void:
		var outline := G.octagon_path(size,0,5)
		draw_set_transform(Vector2(0,4))
		draw_colored_polygon(outline,Color("07121a",.40))
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(outline,Color("152832",opacity))
		draw_line(Vector2(5,0),Vector2(size.x-5,0),Color("d2b27a",.60))
		draw_line(Vector2(5,size.y-1),Vector2(size.x-5,size.y-1),Color("5e7779",.35))
		for x in [4.0,size.x-6]: draw_rect(Rect2(x,4,2,2),Color("d2b27a",.75))

class Atmosphere extends Control:
	func _draw() -> void:
		# Local edge fades leave the lantern-lit actor landing visible.
		for i in 32:
			var fraction := float(i)/32
			draw_rect(Rect2(0,i*4,size.x,4),Color("081520",.52*(1-fraction)))
			var y := size.y-256+i*8
			draw_rect(Rect2(0,y,size.x,8),Color("07141d",fraction*.85))

class Crest extends Control:
	var hue := Color("8ed8f2")
	func _draw() -> void:
		var c := size*.5
		draw_arc(c, minf(size.x,size.y)*.48,PI*.12,PI*.88,48,Color(GOLD,.20),1)
		draw_arc(c, minf(size.x,size.y)*.48,PI*1.12,PI*1.88,48,Color(GOLD,.20),1)
		for at in [Vector2(c.x,4),Vector2(c.x,size.y-4)]:
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-4),at+Vector2(3,0),at+Vector2(0,4),at+Vector2(-3,0)]),Color(hue,.50))
