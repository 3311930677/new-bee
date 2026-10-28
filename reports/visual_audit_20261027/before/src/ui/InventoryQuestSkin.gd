extends RefCounted
## Scoped skin for the inventory and quest journal. Game operations stay in their panels.
const Base := preload("res://src/ui/TravelChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const ROOT := "res://assets/ui/inventory_quest_20261015/"
const NIGHT := Color("12151c")
const FACE := Color("1b2028")
const GOLD := Color("e5bb70")
const BRASS := Color("796344")
const PAPER := Color("f2e4c5")
const MUTED := Color("aea58e")
const INK := Color("35291e")
const JADE := Color("78b9a5")
static var _theme: Theme
static var _textures: Dictionary = {}
static var _regions: Dictionary = {}

static func theme() -> Theme:
	if _theme != null: return _theme
	_theme = Base.theme().duplicate()
	for role in Base.FONT_SIZES:
		var variant := "Chest_" + String(role)
		_theme.set_font("font", variant, G.font_serif if role in ["title", "section", "object"] else G.font_bold if role in ["number", "tag"] else G.font_reg)
		_theme.set_font_size("font_size", variant, 28 if role == "title" else 24 if role == "object" else 22 if role == "section" else 18 if role == "body" else 20 if role in ["secondary", "primary","number"] else 16)
	_theme.default_font = G.font_reg
	return _theme

static func label(words: String, role := "body", color := PAPER) -> Label:
	var l := Base.label(words, role, color)
	l.theme = theme()
	return l

static func texture(id: String) -> Texture2D:
	if _textures.has(id): return _textures[id]
	if id == "chest":
		var chest := load(ROOT + "pending_chest.png") as Texture2D
		var pixels := chest.get_image()
		pixels.resize(300,200,Image.INTERPOLATE_NEAREST)
		var tex := ImageTexture.create_from_image(pixels)
		tex.set_meta("pixel_art",true)
		_textures[id] = tex
		return tex
	if _regions.is_empty() and FileAccess.file_exists(ROOT + "regions.json"):
		_regions = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "regions.json"))
	if not _regions.has(id): return null
	var d: Dictionary = _regions[id]
	var source := load(ROOT + "atlas.png") as Texture2D
	var region := Rect2i(d.rect[0], d.rect[1], d.rect[2], d.rect[3])
	var pixels := source.get_image().get_region(region)
	var factor := 44.0 / float(region.size.y) if id in ["primary","secondary"] else 0.5
	pixels.resize(roundi(region.size.x * factor),roundi(region.size.y * factor),Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(pixels)
	tex.set_meta("pixel_art", true)
	_textures[id] = tex
	return tex

static func box(kind := "card", padding := 12.0) -> StyleBox:
	var tex := texture(kind)
	if tex != null:
		var b := StyleBoxTexture.new()
		b.texture = tex
		var margin := 20.0 if kind in ["header", "paper", "card"] else 14.0
		b.texture_margin_left = margin
		b.texture_margin_right = margin
		b.texture_margin_top = margin
		b.texture_margin_bottom = margin
		b.set_content_margin_all(padding)
		return b
	var b := StyleBoxFlat.new()
	b.bg_color = Color("c5a772") if kind == "paper" else Color("215951") if kind == "primary" else Color("302921") if kind == "header" else FACE
	b.border_color = GOLD if kind in ["paper", "primary"] else BRASS
	b.set_border_width_all(2)
	b.set_corner_radius_all(0)
	b.set_content_margin_all(padding)
	return b

static func plate(kind := "card") -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_theme_stylebox_override("panel", box(kind, 0))
	return p

static func action(words: String, family := "secondary") -> Button:
	return PixelButton.new(words, family)

static func paper_ink(root: Node) -> void:
	if root is Label:
		root.theme = theme()
		var c: Color = root.get_theme_color("font_color")
		root.add_theme_color_override("font_color", Color("366b58") if c == Base.JADE else Color("a13b2c") if c == Base.RED else INK)
		root.add_theme_constant_override("shadow_offset_y", 0)
	for child in root.get_children(): paper_ink(child)

class Stage extends Control:
	const Art = preload("res://src/ui/InventoryQuestSkin.gd")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Art.NIGHT)
		for y in range(0, int(size.y), 16):
			draw_rect(Rect2(10, y, maxf(0, size.x - 20), 1), Color("1c2027"))
			for x in range(16, int(size.x)-16, 24):
				if (int(x / 8) + int(y / 8)) % 7 == 0: draw_rect(Rect2(x, y+5, 6, 2), Color("20242b"))
		for x in [4.0, size.x-8.0]:
			draw_rect(Rect2(x, 4, 4, size.y-8), Color("342b23"))
			draw_rect(Rect2(x, 4, 1, size.y-8), Art.BRASS)
		for at in [Vector2(6,6), Vector2(size.x-12,6), Vector2(6,size.y-12), Vector2(size.x-12,size.y-12)]:
			draw_rect(Rect2(at, Vector2(6,6)), Art.GOLD)
			draw_rect(Rect2(at+Vector2(2,2), Vector2(2,2)), Art.NIGHT)

class PixelButton extends Button:
	const Art = preload("res://src/ui/InventoryQuestSkin.gd")
	var caption: Label
	var selected := false
	var skin := "secondary"
	func _init(words := "", family := "secondary") -> void:
		text = words
		skin = family
		theme = Art.theme()
		custom_minimum_size = Vector2(44,44)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		caption = Art.label(words, "secondary")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(caption)
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for state in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for property in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]: add_theme_color_override(property, Color.TRANSPARENT)
		for event in [resized,mouse_entered,mouse_exited,button_down,button_up,focus_entered,focus_exited]: event.connect(queue_redraw)
	func _draw() -> void:
		var kind := "paper" if skin == "tab" and selected else "primary" if skin == "primary" else "secondary"
		draw_style_box(Art.box(kind, 0), Rect2(Vector2.ZERO,size))
		if is_pressed() or disabled: draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color(0,0,0,.30 if disabled else .18))
		caption.position.y = 1.0 if is_pressed() else 0.0
		caption.add_theme_color_override("font_color", Art.MUTED if disabled else Art.INK if kind == "paper" else Art.PAPER)
		if has_focus(): draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Art.GOLD,false,1)

class ItemCell extends Page.ItemCell:
	const Art = preload("res://src/ui/InventoryQuestSkin.gd")
	func _init() -> void:
		super()
		custom_minimum_size = Vector2(72,80)
		image_px = 64
	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Empty capacity slots must not look like occupied items with missing art.
		if disabled and item_image.texture == null:
			draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color("15191e"))
			draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color("484237"),false,1)
			heading.hide()
			amount.hide()
			return
		draw_style_box(Art.box("secondary",0),Rect2(Vector2.ZERO,size))
		if item_image.texture == null:
			var c := (size *.5).floor()
			draw_rect(Rect2(c-Vector2(4,0),Vector2(9,1)),Color("3c3934"))
			draw_rect(Rect2(c-Vector2(0,4),Vector2(1,9)),Color("3c3934"))
		else:
			if rarity_rank > 1:
				draw_rect(Rect2(4,size.y-5,size.x-8,2),rarity.darkened(.2))
			if selected or has_focus(): draw_rect(Rect2(1,1,size.x-2,size.y-2),Art.GOLD,false,2)
		var px := minf(image_px,minf(size.x,size.y)-14)
		item_image.size = Vector2(px,px)
		item_image.custom_minimum_size = Vector2(px,px)
		item_image.position = ((size-Vector2(px,px))*.5).floor()
		item_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heading.visible = show_name or (item_image.texture == null and not disabled)
		heading.position = Vector2(4,size.y-24)
		heading.size = Vector2(size.x-8,20)
		amount.position = Vector2(4,4)
		amount.size = Vector2(size.x-12,20)
		flag.text = "装" if worn else ""
		flag.position = Vector2(6,size.y-22)
		flag.size = Vector2(24,18)
		if locked:
			draw_rect(Rect2(size.x-14,size.y-14,8,7),Art.GOLD)
			draw_rect(Rect2(size.x-12,size.y-18,4,5),Art.GOLD,false,1)
