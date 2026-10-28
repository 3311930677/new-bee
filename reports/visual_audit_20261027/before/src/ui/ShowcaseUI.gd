extends RefCounted
## Shared semantic type and controls for showcase, activity and life-skill pages.
const TouchScroll := preload("res://src/ui/TouchScroll.gd")
const Art := preload("res://src/ui/InventoryQuestSkin.gd")
const INK := Color("12151c")
const CARD := Color("1b2028")
const TEXT := Color("f3e9d2")
const MUTED := Color("bdb29b")
const GOLD := Color("e6bd77")
const JADE := Color("83c9ac")
const RED := Color("f29c87")
const SIZES := {"title":28,"section":22,"object":20,"body":18,"caption":15,"tag":14,"price":24}

static func text(words: String, role := "body", color := TEXT) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_override("font",G.font_serif if role in ["title","section","object"] else G.font_bold if role=="price" else G.font_reg)
	l.add_theme_font_size_override("font_size",int(SIZES.get(role,18)))
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func surface(_fill := CARD, _border := Color("796344"), padding := 14.0) -> StyleBox:
	var box := Art.box("card",padding)
	return box

static func frame(padding := 14.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel",surface(CARD,Color("667360"),padding))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p

static func column(gap := 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",gap)
	return box

static func button(words: String, primary := false) -> Button:
	var b := Button.new()
	b.text = words
	b.custom_minimum_size = Vector2(56,52)
	b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	b.clip_text=true
	b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_override("font",G.font_bold if primary else G.font_reg)
	b.add_theme_font_size_override("font_size",18)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var box:=Art.box("primary" if primary or state=="pressed" else "secondary",10)
		if box is StyleBoxTexture:
			box.modulate_color=Color(1.12,1.1,1.04) if state=="hover" else Color(.72,.72,.72) if state=="pressed" else Color(.45,.45,.45) if state=="disabled" else Color.WHITE
		if state=="focus":
			var focus:=StyleBoxFlat.new()
			focus.bg_color=Color.TRANSPARENT
			focus.border_color=GOLD
			focus.set_border_width_all(2)
			b.add_theme_stylebox_override(state,focus)
		else:b.add_theme_stylebox_override(state,box)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,TEXT)
	b.add_theme_color_override("font_disabled_color",MUTED.darkened(.2))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

static func picture(texture: Texture2D, px: float) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = texture
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.custom_minimum_size = Vector2(px,px)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic

static func hero(title: String, note: String, texture: Texture2D) -> Control:
	var card := frame(16)
	card.custom_minimum_size.y = 124
	card.add_theme_stylebox_override("panel",surface(Color("243d3c"),GOLD,16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	card.add_child(row)
	var words := column(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(text(title,"section",GOLD))
	words.add_child(text(note,"caption",TEXT))
	row.add_child(picture(texture,88))
	return card

static func scroll() -> TouchScroll:
	var s := preload("res://src/ui/TouchScroll.gd").new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s

static func banner(title: String,note: String,art: Texture2D) -> Control:
	var card := frame(0)
	var canvas := Control.new()
	canvas.custom_minimum_size.y=136
	canvas.clip_contents=true
	card.add_child(canvas)
	var image := picture(art,0)
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(image)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color("17151a",.96),Color("17151a",.20)])
	var tex := GradientTexture2D.new()
	tex.gradient=gradient
	tex.fill_from=Vector2.ZERO
	tex.fill_to=Vector2.RIGHT
	shade.texture=tex
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shade)
	var words := column(6)
	words.position=Vector2(16,14)
	canvas.add_child(words)
	words.add_child(text(title,"section",GOLD))
	words.add_child(text(note,"caption",TEXT))
	canvas.resized.connect(func():words.size=Vector2(maxf(160,canvas.size.x*.58),108))
	return card
