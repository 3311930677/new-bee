extends RefCounted
const INK := Color("17151a", 0.78)
const RAISED := Color("26222a")
const BRONZE := Color("6e5434")
const LIT := Color("c29a5b")
const GOLD := Color("f0b95a")
const PAPER := Color("f3e8d0")
const AGED := Color("bfb096")
const ASH := Color("77705f")
const RED := Color("cf4a33")
const JADE := Color("63b784")
const FROST := Color("8db3c7")

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = G.font_reg
	t.default_font_size = 13
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_shadow_color", "Label", Color("0a090b", 0.8))
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("outline_size", "Label", 0)
	return t

static func label(words: String, px: int = 13, color: Color = PAPER, serif: bool = false) -> Label:
	var l := Label.new()
	l.text = words
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.theme = theme()
	l.add_theme_font_override("font", G.font_serif if serif else G.font_bold)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func polygon(rect: Rect2, cut: float = 2.0) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.25)
	return PackedVector2Array([p + Vector2(c, 0), Vector2(e.x - c, p.y), Vector2(e.x, p.y + c),
		e - Vector2(0, c), e - Vector2(c, 0), Vector2(p.x + c, e.y), Vector2(p.x, e.y - c), p + Vector2(0, c)])

static func plate(canvas: CanvasItem, rect: Rect2, bg: Color = INK, edge: Color = BRONZE) -> void:
	var poly := polygon(rect)
	canvas.draw_colored_polygon(poly, bg)
	poly.append(poly[0])
	canvas.draw_polyline(poly, edge, 1.0, true)
	canvas.draw_line(rect.position + Vector2(5, 1), rect.position + Vector2(rect.size.x - 5, 1), Color(LIT, 0.3), 1)

static func scrim(dimensions: Vector2, bottom: bool = false) -> TextureRect:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color("0a090b", 0.0 if bottom else 0.38), Color("0a090b", 0.30 if bottom else 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 4
	tex.height = 160
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var node := TextureRect.new()
	node.texture = tex
	node.size = dimensions
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

class Surface extends Control:
	const Lacquer = preload("res://src/ui/LacquerUI.gd")
	var bg := Color("17151a", 0.78)
	var edge := Color("6e5434")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		Lacquer.plate(self, Rect2(Vector2.ZERO, size), bg, edge)

class CutPanel extends Panel:
	const Lacquer = preload("res://src/ui/LacquerUI.gd")
	var surface_style: StyleBoxFlat
	func _ready() -> void:
		surface_style = get_theme_stylebox("panel") as StyleBoxFlat
		add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		if surface_style != null:
			Lacquer.plate(self,Rect2(Vector2.ZERO,size),surface_style.bg_color,surface_style.border_color)

class Action extends Button:
	const Lacquer = preload("res://src/ui/LacquerUI.gd")
	var caption: Label
	var glyph_label: Label
	var disc := false
	var primary := false
	var quiet := false
	var active := false
	var warning := false
	var art: TextureRect
	var icon_size := 28.0
	var count_badge: Control
	var count_label: Label
	var motion_icon: Control
	func _init(words: String = "", glyph: String = "") -> void:
		caption = Lacquer.label(words, 12)
		caption.name = "Caption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(caption)
		glyph_label = Lacquer.label(glyph, 24, Lacquer.AGED)
		glyph_label.name = "Glyph"
		glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(glyph_label)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _ready() -> void:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		resized.connect(_layout)
		for event in [mouse_entered, mouse_exited, button_down, button_up, focus_entered, focus_exited]:
			event.connect(queue_redraw)
		_layout()
	func set_motion_icon() -> void:
		motion_icon = Lacquer.MotionIcon.new()
		motion_icon.name = "MotionIcon"
		motion_icon.position = Vector2((size.x-28)*0.5,5)
		motion_icon.size = Vector2(28,28)
		add_child(motion_icon)
		glyph_label.visible = false
	func set_count(value: int, at: Vector2 = Vector2(44,-4)) -> void:
		if count_badge == null:
			count_badge = Lacquer.Surface.new()
			count_badge.name = "CountBadge"
			count_badge.size = Vector2(24,18)
			count_badge.set("bg",Color("17151a",0.96))
			add_child(count_badge)
			count_label = Lacquer.label("",12)
			count_label.name = "Count"
			count_label.size = count_badge.size
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_badge.add_child(count_label)
		count_badge.position = at
		count_badge.visible = value >= 0
		count_label.text = str(value) if value < 100 else "99+"
		count_badge.set("bg",Lacquer.ASH if value == 0 else Color("17151a",0.96))
		count_badge.queue_redraw()
		if art != null:
			if art.material == null:
				var shader := Shader.new()
				shader.code = "shader_type canvas_item; uniform float gray=0.0; void fragment(){vec4 c=texture(TEXTURE,UV); float v=dot(c.rgb,vec3(0.299,0.587,0.114)); COLOR=vec4(mix(c.rgb,vec3(v)*0.4,gray),c.a);}"
				var material := ShaderMaterial.new()
				material.shader = shader
				art.material = material
			(art.material as ShaderMaterial).set_shader_parameter("gray",1.0 if value==0 else 0.0)
	func set_texture(texture: Texture2D) -> void:
		if art == null:
			art = TextureRect.new()
			art.name = "ActionIcon"
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(art)
		if texture is AtlasTexture: art.texture=texture
		elif texture!=null:
			var crop:=AtlasTexture.new()
			crop.atlas=texture
			crop.region=Rect2(texture.get_image().get_used_rect())
			art.texture=crop
		glyph_label.visible = false
		_layout()
	func _layout() -> void:
		if art != null:
			art.position = Vector2((size.x - icon_size) * 0.5, 2 if size.y <= 44 else size.y * 0.12)
			art.size = Vector2(icon_size,icon_size)
			if caption.text.is_empty(): art.position.y = (size.y-icon_size)*0.5
			caption.position = Vector2(0, size.y - 18)
			caption.size = Vector2(size.x,18)
		elif glyph_label.text.is_empty():
			caption.position = Vector2.ZERO
			caption.size = size
		else:
			glyph_label.position = Vector2(0, 2)
			glyph_label.size = Vector2(size.x, size.y * 0.60)
			caption.position = Vector2(0, size.y * 0.60 - 1)
			caption.size = Vector2(size.x, maxf(16, size.y * 0.30))
	func _draw() -> void:
		var edge := Lacquer.RED if warning else (Lacquer.GOLD if active else Lacquer.BRONZE)
		var bg := Color("6a2b1f") if primary else Lacquer.INK
		if disabled: edge = Color(edge, 0.5)
		if is_pressed(): bg = bg.darkened(0.12)
		if primary: caption.position.y = 1 if is_pressed() else 0
		caption.modulate = Color(Lacquer.ASH) if disabled else Color.WHITE
		if not quiet:
			if disc:
				draw_arc(size * 0.5, size.x * 0.5, 0, TAU, 64, Color("0a090b",0.4), 1, true)
				draw_circle(size * 0.5, size.x * 0.5 - 1, bg)
				draw_arc(size * 0.5, size.x * 0.5 - 1, 0, TAU, 64, edge, 2 if active else 1, true)
				if bool(get_meta("partner_available",false)):draw_circle(Vector2(size.x-7,7),4,Lacquer.RED)
			else:
				Lacquer.plate(self, Rect2(Vector2.ONE, size - Vector2.ONE * 2), bg, edge)
				if primary:
					Lacquer.plate(self, Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4), Color.TRANSPARENT, Lacquer.LIT)
					for x in [14.0, size.x - 14]: draw_circle(Vector2(x, size.y * 0.5), 2, Lacquer.LIT)
		if has_focus():
			if disc: draw_line(Vector2(size.x*.3,size.y+3),Vector2(size.x*.7,size.y+3),Lacquer.BRONZE,1)
			elif primary:
				# Separate keyboard indication from the bronze button outline.
				draw_line(Vector2(20,size.y+5),Vector2(size.x-20,size.y+5),Lacquer.PAPER,2)
				for x in [-5.0,size.x+5]: draw_rect(Rect2(x,size.y*0.5-3,2,6),Lacquer.PAPER)
			else: Lacquer.plate(self, Rect2(Vector2.ONE * -3, size + Vector2.ONE * 6), Color.TRANSPARENT, Lacquer.PAPER)
		elif is_hovered() and disc:
			draw_arc(size * 0.5, size.x * 0.5 - 1, 0, TAU, 64, Lacquer.LIT, 1, true)
		if quiet and (is_pressed() or has_focus()):
			draw_line(Vector2(size.x * 0.5 - 12, size.y - 6), Vector2(size.x * 0.5 + 12, size.y - 6), Lacquer.LIT, 1)

class MotionIcon extends Control:
	func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var on := bool(get_parent().get("active"))
		var color := Color("f0b95a") if on else Color("bfb096")
		var back := PackedVector2Array([Vector2(8,2),Vector2(27,14),Vector2(8,26),Vector2(8,19),Vector2(2,19),Vector2(2,9),Vector2(8,9)])
		draw_colored_polygon(back,Color("0a090b"))
		draw_colored_polygon(PackedVector2Array([Vector2(10,5),Vector2(24,14),Vector2(10,23),Vector2(10,17),Vector2(4,17),Vector2(4,11),Vector2(10,11)]),color)
		if on:
			draw_rect(Rect2(0,4,7,3),color)
			draw_rect(Rect2(0,22,7,3),color)
