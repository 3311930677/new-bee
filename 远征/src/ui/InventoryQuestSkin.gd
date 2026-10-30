extends RefCounted
## Scoped skin for the inventory and quest journal. Game operations stay in their panels.
const Base := preload("res://src/ui/TravelChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const Kit := preload("res://src/ui/UiKit.gd")
const ROOT := "res://assets/ui/inventory_quest_20261015/"
const NIGHT := Color("120e0c")
const FACE := Color("1a1412")
const GOLD := Color("f2c76a")
const BRASS := Color("c9a45c")
const PAPER := Color("f3e3c0")
const MUTED := Color("8f8376")
const INK := Color("35291e")
const JADE := Color("55d8a8")
static var _theme: Theme
static var _textures: Dictionary = {}
static var _regions: Dictionary = {}

static func theme() -> Theme:
	if _theme != null: return _theme
	_theme = Base.theme().duplicate()
	for role in Base.FONT_SIZES:
		var variant := "Chest_" + String(role)
		_theme.set_font("font", variant, G.font_serif if role in ["title", "section", "object"] else G.font_bold if role in ["number", "tag"] else G.font_reg)
		_theme.set_font_size("font_size", variant, 26 if role == "title" else 22 if role == "object" else 20 if role == "section" else 16 if role == "body" else 18 if role in ["secondary", "primary","number"] else 16)
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
	var kit_map := {
		"primary": "hero_normal",
		"secondary": "btn_normal",
		"back": "back_diamond",
		"tab_active": "tab_active",
		"tab_idle": "tab_idle",
		"header": "nav_base",
		"card": "panel_iron",
		"paper": "card_paper",
	}
	if kit_map.has(kind):
		var sb := Kit.style(String(kit_map[kind]), padding)
		if sb != null:
			return sb
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
	b.bg_color = Color("e8dcc0") if kind == "paper" else Color("8e251d") if kind == "primary" else Color("2a201a") if kind in ["header", "tab_active"] else FACE
	b.border_color = GOLD if kind in ["paper", "primary", "tab_active"] else BRASS
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
			draw_rect(Rect2(10, y, maxf(0, size.x - 20), 1), Color("1a1412"))
			for x in range(16, int(size.x)-16, 24):
				if (int(x / 8) + int(y / 8)) % 7 == 0: draw_rect(Rect2(x, y+5, 6, 2), Color("221a16"))
		for x in [4.0, size.x-8.0]:
			draw_rect(Rect2(x, 4, 4, size.y-8), Color("2a201a"))
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
		clip_text = true
		skin = family
		theme = Art.theme()
		custom_minimum_size = Vector2(44,44)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		caption = Art.label(words, "secondary")
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(caption)
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for state in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for property in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]: add_theme_color_override(property, Color.TRANSPARENT)
		for event in [resized,mouse_entered,mouse_exited,button_down,button_up,focus_entered,focus_exited]: event.connect(queue_redraw)
	func _draw() -> void:
		var kind := ("tab_active" if selected else "tab_idle") if skin == "tab" else ("primary" if skin == "primary" else ("back" if skin == "back" else "secondary"))
		draw_style_box(Art.box(kind, 0), Rect2(Vector2.ZERO,size))
		if is_pressed() or disabled: draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color(0,0,0,.30 if disabled else .18))
		caption.position.y = 1.0 if is_pressed() else 0.0
		var col := Art.MUTED if disabled else (Art.GOLD if (skin == "tab" and selected) or skin == "back" else (Art.MUTED if skin == "tab" else Art.PAPER))
		caption.add_theme_color_override("font_color", col)
		if has_focus(): draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Art.GOLD,false,1)

class ItemCell extends Page.ItemCell:
	const Art = preload("res://src/ui/InventoryQuestSkin.gd")
	func _init() -> void:
		super()
		custom_minimum_size = Vector2(72,76)
		image_px = 58
	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Empty capacity slots use A-08 slot_empty
		if disabled and item_image.texture == null:
			var empty_tex := KitV4.commercial_tex("slot_empty")
			if empty_tex != null:
				G.Visuals.nine_slice(self, empty_tex, Rect2(Vector2.ZERO, size), 10.0, 10.0)
			else:
				draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color("15191e"))
				draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color("484237"),false,1)
			heading.hide()
			amount.hide()
			return
		var slot_tex := KitV4.commercial_tex(KitV4.slot_key(rarity_rank))
		if slot_tex != null:
			G.Visuals.nine_slice(self, slot_tex, Rect2(Vector2.ZERO, size), 10.0, 10.0)
		else:
			draw_style_box(Art.box("secondary",0),Rect2(Vector2.ZERO,size))
		if item_image.texture == null:
			var c := (size *.5).floor()
			draw_rect(Rect2(c-Vector2(4,0),Vector2(9,1)),Color("3c3934"))
			draw_rect(Rect2(c-Vector2(0,4),Vector2(1,9)),Color("3c3934"))
		else:
			if selected:
				# 选中只提亮格内底色并加一枚小勾，保留物品自身的稀有度边框。
				draw_rect(Rect2(Vector2(7,7), size-Vector2(14,14)), Color(Art.GOLD, 0.13))
				draw_circle(Vector2(size.x-13,13), 8.0, Color("241a12"))
				draw_circle(Vector2(size.x-13,13), 7.0, Art.GOLD)
				draw_polyline(PackedVector2Array([Vector2(size.x-17,13),Vector2(size.x-14,16),Vector2(size.x-9,10)]), Color("241a12"), 2.0, true)
			elif has_focus():
				# 键盘焦点只用短下划线提示，不再覆盖整圈选中框。
				draw_line(Vector2(18,size.y-5), Vector2(size.x-18,size.y-5), Art.GOLD, 2.0, true)
		var px := minf(image_px,minf(size.x,size.y)-14)
		item_image.size = Vector2(px,px)
		item_image.custom_minimum_size = Vector2(px,px)
		item_image.position = ((size-Vector2(px,px))*.5).floor()
		item_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heading.visible = show_name or (item_image.texture == null and not disabled)
		heading.position = Vector2(4,size.y-24)
		heading.size = Vector2(size.x-8,20)
		amount.visible = true
		amount.position = Vector2(4, size.y - 22 if amount.text.begins_with("×") else 4)
		amount.size = Vector2(size.x-10,20)
		flag.text = "装" if worn else ""
		flag.position = Vector2(6,size.y-22)
		flag.size = Vector2(24,18)
		if locked:
			draw_rect(Rect2(size.x-14,size.y-14,8,7),Art.GOLD)
			draw_rect(Rect2(size.x-12,size.y-18,4,5),Art.GOLD,false,1)
