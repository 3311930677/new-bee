extends RefCounted
## 行旅账册的原生样式工厂；没有独立页面与返回行为。

static func label(words: String, at: Vector2, extent: Vector2, font_size := 16,
		ink := G.FIELD_INK, bold := false, title := false) -> Label:
	var l := G.gold_label(words, font_size, bold, ink, false)
	if title: l.add_theme_font_override("font", G.font_art if font_size >= 26 else G.font_serif)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = at
	l.size = extent
	l.custom_minimum_size = extent
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func surface(at: Vector2, extent: Vector2, paper := false) -> Surface:
	var p := Surface.new()
	p.position = at
	p.size = extent
	p.paper = paper
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func action(words: String, at: Vector2, extent: Vector2, primary := false,
		light := false) -> Action:
	var b := Action.new()
	b.position = at
	b.size = extent
	b.custom_minimum_size = extent
	b.primary = primary
	b.light = light
	b.caption = label(words, Vector2(16, 0), extent - Vector2(32, 0), 18,
		G.FIELD_PAPER_LIGHT if primary or not light else G.FIELD_INK, true)
	b.caption.custom_minimum_size = Vector2.ZERO
	b.caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(b.caption)
	return b

static func line(parent: Control, at: Vector2, width: float, ink := G.FIELD_LINE) -> void:
	var rule := ColorRect.new()
	rule.color = ink
	rule.position = at
	rule.size = Vector2(width, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)

static func heading(parent: Control, title: String, note: String) -> void:
	parent.add_child(label(title, Vector2(32, 28), Vector2(320, 44), 30,
		G.FIELD_PAPER_LIGHT, false, true))
	parent.add_child(label(note, Vector2(34, 76), Vector2(390, 24), 14, G.FIELD_COPPER))
	line(parent, Vector2(32, 108), 416, Color(G.FIELD_COPPER, .55))

static func portrait(role_id: String, at: Vector2, extent: Vector2) -> Control:
	if not G.FIELD_ROLE.has(role_id): role_id = "zs"
	var tr := Portrait.new()
	var nm: String = {"zs":"pojun", "ck":"chuanyang", "fs":"shuangyu", "fz":"chenxing"}.get(role_id,"pojun")
	var tex: Texture2D = load(G.role_dir(role_id) + nm + "_idle.png")
	if tex != null:
		var part := AtlasTexture.new()
		part.atlas = tex
		part.region = Rect2(0, 0, tex.get_width() / 4.0, tex.get_height())
		tr.texture = part
	tr.position = at
	tr.size = extent
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

class Portrait extends Control:
	var texture: Texture2D
	func _draw() -> void:
		if texture == null: return
		var side := minf(size.x,size.y)
		draw_texture_rect(texture,Rect2((size-Vector2.ONE*side)*.5,Vector2.ONE*side),false)

class Surface extends Control:
	var paper := false
	func _draw() -> void:
		var fill := G.FIELD_PAPER if paper else G.FIELD_DARK
		draw_rect(Rect2(0, 4, size.x, size.y), Color(G.FIELD_DEEP, .65))
		draw_rect(Rect2(Vector2.ZERO, size), fill)
		draw_line(Vector2(0, 0), Vector2(size.x, 0), G.FIELD_COPPER, 1)
		if paper:
			# 装订边与穿线孔只服务“账册”结构，内容区保持干净。
			draw_rect(Rect2(0, 1, 12, size.y - 1), G.FIELD_PAPER.darkened(.07))
			draw_line(Vector2(12, 1), Vector2(12, size.y), Color(G.FIELD_LINE,.55))
			for y in [28, int(size.y * .5), int(size.y - 28)]:
				draw_rect(Rect2(4, y, 4, 2), G.FIELD_MUTED)
			draw_colored_polygon(PackedVector2Array([Vector2(size.x-12,size.y),size,Vector2(size.x,size.y-12)]), G.FIELD_PAPER.darkened(.15))

class Action extends Control:
	signal activated
	var caption: Label
	var primary := false
	var light := false
	var quiet := false
	var disabled := false
	var selected := false
	var accent := G.FIELD_COPPER
	# Optional crafted skins preserve the same input and disabled-state behavior.
	var skin := ""
	var _hover := false
	var _down := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
		mouse_entered.connect(func(): _hover = not disabled; queue_redraw())
		mouse_exited.connect(func(): _hover = false; _release())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		gui_input.connect(_input_event)
	func _input_event(event: InputEvent) -> void:
		if disabled: return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_down = event.pressed
			if event.pressed: activated.emit()
			queue_redraw()
			accept_event()
		elif event.is_action_pressed("ui_accept"):
			activated.emit()
			accept_event()
	func _release() -> void:
		_down = false
		queue_redraw()
	func _draw() -> void:
		if not skin.is_empty():
			_draw_crafted()
			return
		var fill := G.FIELD_RED if primary else (G.FIELD_PAPER_LIGHT if light else G.FIELD_DARK)
		if selected: fill = accent.darkened(.72) if not light else G.FIELD_PAPER_LIGHT
		if _hover: fill = fill.lightened(.05)
		if disabled: fill = fill.lerp(G.FIELD_MUTED,.28)
		var dy := 1 if _down else 0
		if not quiet or _hover or selected:
			draw_rect(Rect2(0, dy, size.x, size.y - dy), fill)
			draw_line(Vector2(0, size.y-1), Vector2(size.x,size.y-1), Color(accent,.38),1)
			if primary:
				draw_line(Vector2(0,dy),Vector2(size.x,dy), G.FIELD_COPPER,1)
				draw_rect(Rect2(0,dy,3,size.y-dy),G.FIELD_COPPER)
		if selected: draw_rect(Rect2(12,size.y-3,size.x-24,3),accent)
		if has_focus(): draw_rect(Rect2(2,2,size.x-4,size.y-4),accent,false,1)
		for child in get_children():
			if child is CanvasItem: child.modulate.a = .48 if disabled else 1.0
		if caption != null: caption.position.y = float(caption.get_meta("fixed_y",0)) + dy

	func _draw_crafted() -> void:
		var dy := 2.0 if _down else 0.0
		var extent := size
		if skin == "tool":
			var center := size * .5 + Vector2(0,dy)
			draw_circle(center, minf(size.x,size.y) * .47, Color("172b37",.72))
			if _hover or has_focus():
				draw_arc(center, minf(size.x,size.y) * .47, -PI * .85, PI * .60, 48, Color("e4c58e",.85),1,true)
				if has_focus(): draw_circle(center, minf(size.x,size.y) * .48, Color("f7e6b6"),false,1,true)
			for child in get_children():
				if child is CanvasItem: child.modulate.a = .48 if disabled else 1.0
			return
		if skin == "badge": extent.y = minf(size.y,58)
		var edge := Color("9c8052")
		var fill := Color("223a42",.94)
		if skin == "primary":
			edge = Color("f0d49c")
			fill = Color("bc914e")
		elif skin == "tab" and selected:
			fill = accent.darkened(.60)
			edge = accent.lightened(.20)
		elif skin == "nav":
			fill = Color("1a2c35",.35)
			edge = Color("9c8052",.35)
		elif skin == "scroll":
			fill = Color("d8cfb4")
			edge = Color("a79872")
		elif skin == "ribbon":
			fill = Color("654c47")
			edge = Color("b99574")
		if disabled:
			fill = Color("34434a")
			edge = Color("677374")
		elif _hover or has_focus():
			fill = fill.lightened(.10)
			edge = edge.lightened(.20)
		var cut := 8.0 if skin in ["primary","badge"] else 4.0
		var bounds := Rect2(Vector2(0,dy),extent-Vector2(0,dy))
		if skin == "badge":
			var center := Vector2(extent.x*.5,28+dy)
			var radius := minf(extent.x*.43,27)
			var shape := String(get_meta("badge_shape","circle"))
			var hue: Color = get_meta("badge_hue",edge)
			fill = fill.lerp(hue.darkened(.78),.40)
			if shape == "circle":
				draw_circle(center+Vector2(0,3),radius,Color("080f16",.55))
				draw_circle(center,radius,fill)
				draw_arc(center,radius,-PI*.8,PI*.35,40,hue,1,true)
				draw_arc(center,radius-3,PI*.4,PI*1.2,24,Color(hue,.32),1,true)
			else:
				var rim := PackedVector2Array()
				if shape == "shield":
					rim = PackedVector2Array([center+Vector2(-radius,-radius*.72),center+Vector2(0,-radius),center+Vector2(radius,-radius*.72),center+Vector2(radius*.8,radius*.45),center+Vector2(0,radius),center+Vector2(-radius*.8,radius*.45)])
				elif shape == "diamond":
					rim = PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)])
				else:
					for i in 6: rim.append(center+Vector2.from_angle(-PI*.5+i*TAU/6)*radius)
				draw_set_transform(Vector2(0,3))
				draw_colored_polygon(rim,Color("080f16",.55))
				draw_set_transform(Vector2.ZERO)
				draw_colored_polygon(rim,fill)
				rim.append(rim[0])
				draw_polyline(rim,Color(hue,.8),1,true)
			draw_line(center+Vector2(-10,-radius+5),center+Vector2(10,-radius+5),Color("f7e5bc",.22),1)
			if has_focus(): draw_circle(center,radius+2,Color("f7e6b6"),false,1,true)
			for child in get_children():
				if child is CanvasItem: child.modulate.a = .48 if disabled else 1.0
			return
		if skin != "nav" or _hover or selected:
			draw_colored_polygon(_bevel(Rect2(bounds.position+Vector2(0,4),bounds.size),cut),Color("080f16",.70))
			draw_colored_polygon(_bevel(bounds,cut),edge.darkened(.28))
			var inner := bounds.grow(-2)
			draw_colored_polygon(_bevel(inner,maxf(2,cut-2)),fill)
			draw_colored_polygon(_bevel(Rect2(inner.position,Vector2(inner.size.x,inner.size.y*.46)),maxf(2,cut-2)),fill.lightened(.07))
			draw_line(Vector2(cut,dy+2),Vector2(extent.x-cut,dy+2),edge,1)
			draw_line(Vector2(cut,extent.y-3),Vector2(extent.x-cut,extent.y-3),fill.darkened(.45),2)
			if skin == "primary":
				draw_line(Vector2(14,dy+8),Vector2(extent.x-14,dy+8),Color("f4d99d",.38))
				for x in [10.0,extent.x-12]: draw_rect(Rect2(x,extent.y*.5-1,2,2),Color("fae9c1"))
			elif skin == "badge":
				for x in [6.0,extent.x-8]: draw_rect(Rect2(x,7+dy,2,2),Color("dfc490"))
			elif skin == "scroll":
				draw_line(Vector2(8,8),Vector2(8,extent.y-8),Color("b5a989"),1)
				for y in [12,extent.y-13]: draw_rect(Rect2(4,y,4,2),Color("a89977"))
		if selected and skin == "tab": draw_rect(Rect2(10,extent.y-4,extent.x-20,2),accent.lightened(.28))
		if has_focus(): draw_polyline(_bevel(bounds.grow(-1),cut),Color("f7e6b6"),1)
		for child in get_children():
			if child is CanvasItem: child.modulate.a = .48 if disabled else 1.0
		if caption != null: caption.position.y = float(caption.get_meta("fixed_y",0)) + dy

	func _bevel(r: Rect2,cut: float) -> PackedVector2Array:
		var a := r.position
		var b := r.end
		return PackedVector2Array([a+Vector2(cut,0),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),
			b-Vector2(0,cut),b-Vector2(cut,0),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),a+Vector2(0,cut),a+Vector2(cut,0)])

# 少量器物插画按同一像素网格画，避免导航用图标加任意几何外框。
class Prop extends Control:
	var key := "world"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var s := size.x / 40.0
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * s)
		var ink := G.FIELD_DEEP
		var paper := G.FIELD_PAPER
		var gold := G.FIELD_COPPER
		match key:
			"world":
				draw_rect(Rect2(4,10,32,24),ink)
				draw_rect(Rect2(5,8,10,24),paper.darkened(.16))
				draw_rect(Rect2(15,11,10,24),paper)
				draw_rect(Rect2(25,8,10,24),paper.darkened(.10))
				draw_polyline(PackedVector2Array([Vector2(9,24),Vector2(18,20),Vector2(21,27),Vector2(30,18)]),G.FIELD_RED,2)
				draw_rect(Rect2(8,22,3,3),gold)
				draw_rect(Rect2(29,16,3,3),G.FIELD_RED)
				draw_line(Vector2(15,12),Vector2(15,32),gold)
				draw_line(Vector2(25,10),Vector2(25,32),gold)
				draw_line(Vector2(6,9),Vector2(14,9),G.FIELD_PAPER_LIGHT)
				draw_line(Vector2(26,9),Vector2(34,9),G.FIELD_PAPER_LIGHT)
				for q in [Vector2(8,16),Vector2(28,26),Vector2(17,30)]:
					draw_line(q,q+Vector2(3,-3),G.FIELD_MUTED)
					draw_line(q+Vector2(3,-3),q+Vector2(6,0),G.FIELD_MUTED)
			"bag":
				draw_rect(Rect2(10,4,20,6),ink)
				draw_rect(Rect2(12,5,16,4),gold)
				draw_rect(Rect2(6,13,28,23),ink)
				draw_rect(Rect2(8,13,24,20),G.FIELD_RED)
				draw_rect(Rect2(6,10,28,9),G.FIELD_LEATHER)
				draw_rect(Rect2(18,10,4,23),gold)
				draw_rect(Rect2(15,17,10,7),ink)
				draw_rect(Rect2(17,19,6,3),gold)
				draw_line(Vector2(10,30),Vector2(16,30),paper)
				draw_line(Vector2(7,11),Vector2(33,11),gold)
				draw_rect(Rect2(4,20,3,11),G.FIELD_LEATHER)
				draw_rect(Rect2(33,20,3,11),G.FIELD_LEATHER)
				for x in [10,14,26,30]: draw_rect(Rect2(x,29,1,2),gold)
			"growth":
				draw_rect(Rect2(7,33,26,4),ink)
				draw_rect(Rect2(10,32,20,3),gold)
				draw_line(Vector2(20,33),Vector2(20,12),Color("41664d"),4)
				draw_line(Vector2(19,31),Vector2(19,10),Color("b4d38c"),1)
				draw_colored_polygon(PackedVector2Array([Vector2(19,24),Vector2(8,22),Vector2(4,13),Vector2(13,12),Vector2(19,17)]),ink)
				draw_colored_polygon(PackedVector2Array([Vector2(18,22),Vector2(9,20),Vector2(7,15),Vector2(13,14),Vector2(18,18)]),Color("78b586"))
				draw_colored_polygon(PackedVector2Array([Vector2(20,17),Vector2(24,7),Vector2(35,4),Vector2(33,14),Vector2(26,19)]),ink)
				draw_colored_polygon(PackedVector2Array([Vector2(22,16),Vector2(26,9),Vector2(32,7),Vector2(30,13),Vector2(26,16)]),Color("a4ce83"))
				draw_line(Vector2(22,16),Vector2(30,9),Color("d9e8af"),1)
			"book":
				draw_rect(Rect2(3,11,34,24),ink)
				draw_rect(Rect2(4,8,15,24),paper.darkened(.1))
				draw_rect(Rect2(20,8,16,24),paper)
				for y in [13,18,23]:
					draw_line(Vector2(7,y),Vector2(15,y),G.FIELD_MUTED)
					draw_line(Vector2(24,y),Vector2(32,y),G.FIELD_LINE)
				draw_rect(Rect2(29,8,3,29),G.FIELD_RED)
				draw_line(Vector2(4,7),Vector2(18,7),G.FIELD_PAPER_LIGHT)
				draw_line(Vector2(21,7),Vector2(35,7),G.FIELD_PAPER_LIGHT)
				draw_line(Vector2(4,32),Vector2(18,32),gold)
				draw_line(Vector2(21,32),Vector2(35,32),gold)
			"swords":
				for flip in [false,true]:
					draw_set_transform(Vector2(20,20)*s,PI*.25 if flip else -PI*.25,Vector2.ONE*s)
					draw_colored_polygon(PackedVector2Array([Vector2(-3,4),Vector2(-3,-13),Vector2(0,-18),Vector2(3,-13),Vector2(3,4)]),ink)
					draw_colored_polygon(PackedVector2Array([Vector2(-2,3),Vector2(-2,-12),Vector2(0,-16),Vector2(2,-12),Vector2(2,3)]),Color("99b7c7"))
					draw_line(Vector2(-1,2),Vector2(-1,-12),Color("ecf3e5"),1)
					draw_rect(Rect2(-7,3,14,3),gold)
					draw_rect(Rect2(-2,6,4,9),G.FIELD_RED)
					draw_rect(Rect2(-3,14,6,3),gold)
			"summon":
				draw_circle(Vector2(20,22),15,ink)
				draw_arc(Vector2(20,22),14,.2,TAU-.2,32,Color("8d75b0"),2)
				draw_colored_polygon(PackedVector2Array([Vector2(20,3),Vector2(30,17),Vector2(20,32),Vector2(10,17)]),ink)
				draw_colored_polygon(PackedVector2Array([Vector2(20,5),Vector2(27,17),Vector2(20,29),Vector2(13,17)]),Color("779ed7"))
				draw_colored_polygon(PackedVector2Array([Vector2(20,5),Vector2(20,29),Vector2(13,17)]),Color("b6e1ea"))
				draw_line(Vector2(20,7),Vector2(25,17),Color("f3f3dc"),1)
				draw_rect(Rect2(11,33,18,3),gold)
			"exchange":
				draw_rect(Rect2(7,34,26,3),ink)
				draw_rect(Rect2(10,32,20,3),gold)
				draw_line(Vector2(20,32),Vector2(20,6),gold,3)
				draw_line(Vector2(7,12),Vector2(33,9),gold,3)
				for x in [9,31]:
					var y := 12 if x==9 else 10
					draw_line(Vector2(x,y),Vector2(x-5,24),paper,1)
					draw_line(Vector2(x,y),Vector2(x+5,24),paper,1)
					draw_colored_polygon(PackedVector2Array([Vector2(x-7,24),Vector2(x+7,24),Vector2(x+4,29),Vector2(x-4,29)]),Color("7caaa9"))
					draw_line(Vector2(x-7,24),Vector2(x+7,24),gold,2)
				draw_rect(Rect2(18,4,4,4),Color("f0d19a"))
			"paw":
				for at in [Vector2(7,12),Vector2(15,7),Vector2(25,7),Vector2(33,12)]:
					draw_circle(at+Vector2(0,1),4,ink)
					draw_circle(at,3,Color("c8b087"))
				draw_colored_polygon(PackedVector2Array([Vector2(9,28),Vector2(12,21),Vector2(20,17),Vector2(28,21),Vector2(31,28),Vector2(25,33),Vector2(15,33)]),ink)
				draw_colored_polygon(PackedVector2Array([Vector2(12,27),Vector2(15,22),Vector2(20,19),Vector2(25,22),Vector2(28,27),Vector2(24,30),Vector2(16,30)]),Color("86c3ad"))
			"crown":
				draw_colored_polygon(PackedVector2Array([Vector2(6,11),Vector2(15,18),Vector2(20,5),Vector2(25,18),Vector2(34,11),Vector2(30,31),Vector2(10,31)]),ink)
				draw_colored_polygon(PackedVector2Array([Vector2(9,15),Vector2(16,21),Vector2(20,10),Vector2(24,21),Vector2(31,15),Vector2(28,28),Vector2(12,28)]),gold)
				draw_rect(Rect2(12,29,16,4),Color("b7793e"))
				draw_rect(Rect2(18,22,4,5),Color("82c4de"))
				draw_line(Vector2(12,31),Vector2(28,31),paper,1)
			"mount":
				draw_colored_polygon(PackedVector2Array([Vector2(6,11),Vector2(12,6),Vector2(17,17),Vector2(26,17),Vector2(32,8),Vector2(36,14),Vector2(30,29),Vector2(11,29)]),ink)
				draw_colored_polygon(PackedVector2Array([Vector2(9,12),Vector2(12,10),Vector2(17,20),Vector2(27,20),Vector2(32,12),Vector2(33,15),Vector2(28,26),Vector2(13,26)]),Color("a16e50"))
				draw_rect(Rect2(15,25,4,10),gold)
				draw_rect(Rect2(14,33,7,3),ink)
				draw_line(Vector2(15,23),Vector2(28,23),Color("e2c18a"),1)
			_: draw_texture_rect(G.NavigationIcons.texture(key),Rect2(4,4,32,32),false)
		draw_set_transform(Vector2.ZERO)
