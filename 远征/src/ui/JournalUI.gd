extends RefCounted
## 行旅册：分材质纸面、深色题头、朱印与趣味头像徽章。

const Avatars := preload("res://src/ui/AvatarCatalog.gd")
const Icons := preload("res://src/ui/UIIcons.gd")
const ART_FONT := preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const INK := Color("453d2c")
const MUTED := Color("8b7a57")
const GREEN := Color("234746")
const PAPER := Color("eee1bf")
const EDGE := Color("b39a67")
const GOLD := Color("e2c48c")
const Illustrated := preload("res://src/ui/IllustratedUI.gd")

static func surface(fill: Color, edge := Color.TRANSPARENT, radius := 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1 if edge.a > 0 else 0)
	style.set_corner_radius_all(radius)
	return style

static func paper(w: float, h: float, pad := 24.0) -> PanelContainer:
	var panel := LedgerFrame.new()
	panel.custom_minimum_size = Vector2(w, h)
	var style := StyleBoxEmpty.new()
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func art_label(text: String, font_size := 28, color := INK) -> Label:
	var node := label(text, font_size, color)
	node.add_theme_font_override("font", ART_FONT)
	return node

static func stamp(parent: Control, at: Vector2, text := "昭元") -> void:
	var seal := Panel.new()
	seal.position = at
	seal.size = Vector2(30, 36)
	seal.rotation = -0.055
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := surface(Color("983e2b"), Color("ce9d72"), 1)
	style.set_border_width_all(2)
	seal.add_theme_stylebox_override("panel", style)
	parent.add_child(seal)
	var ink := art_label(text.left(1) + "\n" + text.right(1), 12, Color("f2ddb3"))
	ink.position = Vector2(3, 2)
	ink.size = Vector2(24, 32)
	ink.add_theme_constant_override("line_spacing", -4)
	ink.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.add_child(ink)

class LedgerFrame extends PanelContainer:
	var header_height := 92.0

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var sz := size
		if sz.x < 20: return
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		# 1. 深度柔和投影
		draw_rect(Rect2(4, 8, sz.x - 8, sz.y - 6), Color(0.0, 0.0, 0.0, 0.55))

		# 2. 外框：暗铁镶边
		draw_rect(Rect2(0, 0, sz.x, sz.y), Color("12161e"))
		draw_rect(Rect2(2, 2, sz.x - 4, sz.y - 4), Color("1a222e"))

		# 3. 内侧高光
		draw_line(Vector2(2, 2), Vector2(sz.x - 3, 2), Color(1.0, 1.0, 1.0, 0.08), 1.0)
		draw_line(Vector2(2, 2), Vector2(2, sz.y - 3), Color(1.0, 1.0, 1.0, 0.05), 1.0)

		# 4. 精细黄铜角码 (四角 14px L形)
		var gc := Color("c8a050")
		var gc_hi := Color("ffe088")
		var arm := 14.0
		# 左上
		draw_line(Vector2(3, 3), Vector2(3 + arm, 3), gc_hi, 1.0)
		draw_line(Vector2(3, 3), Vector2(3, 3 + arm), gc_hi, 1.0)
		draw_rect(Rect2(4, 4, 2, 2), gc)
		# 右上
		draw_line(Vector2(sz.x - 4, 3), Vector2(sz.x - 4 - arm, 3), gc_hi, 1.0)
		draw_line(Vector2(sz.x - 4, 3), Vector2(sz.x - 4, 3 + arm), gc_hi, 1.0)
		draw_rect(Rect2(sz.x - 6, 4, 2, 2), gc)
		# 左下
		draw_line(Vector2(3, sz.y - 4), Vector2(3 + arm, sz.y - 4), gc, 1.0)
		draw_line(Vector2(3, sz.y - 4), Vector2(3, sz.y - 4 - arm), gc, 1.0)
		draw_rect(Rect2(4, sz.y - 6, 2, 2), gc)
		# 右下
		draw_line(Vector2(sz.x - 4, sz.y - 4), Vector2(sz.x - 4 - arm, sz.y - 4), gc, 1.0)
		draw_line(Vector2(sz.x - 4, sz.y - 4), Vector2(sz.x - 4, sz.y - 4 - arm), gc, 1.0)
		draw_rect(Rect2(sz.x - 6, sz.y - 6, 2, 2), gc)

		# 5. 内部温润羊皮纸 (纯正高级古卷羊皮纸)
		var inset := 8.0
		var paper_w := sz.x - inset * 2
		var paper_h := sz.y - inset * 2
		draw_rect(Rect2(inset, inset, paper_w, paper_h), Color("f0e6cf"))
		# 纸张边缘微暗做旧
		draw_line(Vector2(inset, inset), Vector2(inset, inset + paper_h), Color("d8c6a0"), 1.0)
		draw_line(Vector2(inset + paper_w - 1, inset), Vector2(inset + paper_w - 1, inset + paper_h), Color("d8c6a0"), 1.0)
		# 内框装饰细线
		draw_rect(Rect2(inset + 4, inset + 4, paper_w - 8, paper_h - 8), Color("c4b088", 0.45), false, 1.0)

class EmbellishedButton extends Button:
	var _shine := 0.0
	var _shine_motion: Tween
	func _ready() -> void:
		var colors: Dictionary = G.Visuals.palette(self)
		var primary := String(get_meta("journal_kind", "primary")) == "primary"
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := get_theme_stylebox(state).duplicate() as StyleBoxFlat
			var fill: Color = colors.dark if primary else colors.paper
			if state == "hover": fill = fill.lightened(0.08) if primary else fill.darkened(0.03)
			if state == "pressed": fill = fill.darkened(0.08)
			style.bg_color = fill
			style.border_color = colors.accent
			style.set_border_width_all(2)
			style.shadow_color = Color("101d18",.25)
			style.shadow_size = 2
			style.shadow_offset = Vector2(0,2)
			add_theme_stylebox_override(state, style)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			add_theme_color_override(state, colors.light if primary else colors.ink)
		if icon != null and icon.resource_path.ends_with(".png"):
			for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				add_theme_color_override(state, Color.WHITE)
		G.reveal_control(self)
		mouse_entered.connect(_accent_motion)
		button_down.connect(_accent_motion)
	func _accent_motion() -> void:
		if _shine_motion != null and _shine_motion.is_valid(): _shine_motion.kill()
		_shine_motion = create_tween()
		_shine_motion.tween_method(func(v: float): _shine=v; queue_redraw(),0.0,1.0,.48)

	func _draw() -> void:
		var colors: Dictionary = G.Visuals.palette(self)
		draw_line(Vector2(12,4),Vector2(size.x-12,4),Color(colors.accent,0.5),1)
		draw_line(Vector2(12,size.y-4),Vector2(size.x-12,size.y-4),Color(colors.accent,0.7),1)
		for x in [6.0,size.x-8]:
			for y in [6.0,size.y-8]: draw_rect(Rect2(x,y,2,2),Color(colors.light,.65))
		for y in [14.0,size.y-14]:
			draw_line(Vector2(6,y),Vector2(16,y),Color(colors.accent,.18),1)
			draw_line(Vector2(size.x-16,y),Vector2(size.x-6,y),Color(colors.accent,.18),1)
		if _shine > 0 and _shine < 1:
			var x := lerpf(12,size.x-32,_shine)
			draw_line(Vector2(x,4),Vector2(x+20,4),Color(colors.light,sin(_shine*PI)),1)

class AvatarMedallion extends Panel:
	var slot_style: StyleBoxFlat

	func _ready() -> void:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		if slot_style != null:
			slot_style.changed.connect(queue_redraw)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 1
		draw_circle(center + Vector2(0, 2), radius, Color("5c4c2f", 0.25))
		draw_circle(center, radius, Color("6c542e"))
		draw_circle(center, radius - 1, Color("cfb681"))
		draw_circle(center, radius - 3, Color("142d2b"))
		draw_circle(center, radius - 5, slot_style.bg_color if slot_style != null else Color("29423d"))
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_circle(center + direction * (radius - 2), 1.0, Color("f1dab1"))

static func label(text: String, font_size := 14, color := INK, serif := false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", G.font_serif if serif else G.font_reg)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func rule(parent: Control, y: float, width: float) -> void:
	var line := ColorRect.new()
	line.position = Vector2(0, y)
	line.size = Vector2(width, 1)
	line.color = Color("c4bea9", 0.65)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

static func button(text: String, width: float, height := 46.0,
		kind := "primary", icon_key := "") -> Button:
	var node: Button = EmbellishedButton.new() if (kind == "primary" or kind == "secondary") else Button.new()
	node.set_meta("journal_kind", kind)
	node.text = text
	node.custom_minimum_size = Vector2(width, height)
	node.size = node.custom_minimum_size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", ART_FONT if kind == "primary" else G.font_serif)
	node.add_theme_font_size_override("font_size", 22 if kind == "primary" else 17)
	var primary := kind == "primary"
	var quiet := kind == "quiet" or kind == "dark_quiet"
	var text_color := GOLD if primary or kind == "dark_quiet" else GREEN
	var normal := surface(GREEN if primary else (Color.TRANSPARENT if quiet else Color("eae7da")),
		Color("b89960") if primary else (Color.TRANSPARENT if quiet else EDGE))
	var hover := surface(Color("365d56") if primary else Color("dedfce", 0.40),
		Color("b89960") if primary else Color.TRANSPARENT)
	var pressed := surface(Color("173b38") if primary else Color("d4d8c5", 0.55))
	var focus := surface(Color.TRANSPARENT, Color("a39162") if kind == "dark_quiet" else GREEN)
	focus.set_border_width_all(2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, hover if state == "hover" else (
			pressed if state == "pressed" else normal))
	node.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, text_color)
	if not icon_key.is_empty():
		node.icon = Icons.texture(icon_key)
		node.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		node.alignment = HORIZONTAL_ALIGNMENT_LEFT
		node.expand_icon = true
		node.add_theme_constant_override("icon_max_width", 18)
		node.add_theme_constant_override("h_separation", 9)
		var text_width := G.font_reg.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		for style in [normal, hover, pressed]:
			style.content_margin_left = maxf(8, (width - text_width - 27) * 0.5)
			style.content_margin_right = 8
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			node.add_theme_color_override(state, text_color)
	node.pressed.connect(func(): Audio.sfx("ui_click"))
	return node

static func field(placeholder: String, secret := false) -> LineEdit:
	var node := LineEdit.new()
	node.placeholder_text = placeholder
	node.secret = secret
	node.max_length = 16
	node.custom_minimum_size = Vector2(0, 44)
	var normal := surface(Color("f8edcf"), Color("bda675"), 1)
	normal.content_margin_left = 13
	normal.border_width_bottom = 2
	normal.shadow_color = Color("796540", 0.12)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 1)
	normal.content_margin_right = 13
	var focused := normal.duplicate() as StyleBoxFlat
	focused.border_color = GREEN
	focused.set_border_width_all(2)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("focus", focused)
	node.add_theme_font_override("font", G.font_reg)
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_placeholder_color", Color("999482"))
	node.add_theme_color_override("caret_color", GREEN)
	node.add_theme_color_override("selection_color", Color("92a38b", 0.35))
	return node

static func avatar_card(id: String, side := 56.0) -> Button:
	var root := Button.new()
	root.custom_minimum_size = Vector2(side, side + 28)
	root.size = root.custom_minimum_size
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.tooltip_text = "选择本机图片" if id == "custom" else String(Avatars.NAMES[id])
	root.set_meta("avatar_id", id)
	for state in ["normal", "hover", "pressed"]:
		root.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	root.add_theme_stylebox_override("focus", surface(Color.TRANSPARENT, GREEN))
	var card := AvatarMedallion.new()
	card.name = "Card"
	card.size = Vector2(side, side)
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := surface(Color("d5c59c") if id == "custom" else Color("29423d"), Color("9f8a5b"))
	card.slot_style = style
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.set_meta("style", style)
	root.add_child(card)
	var texture := G.custom_avatar_texture() if id == "custom" else Avatars.texture(id)
	if texture != null:
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture = texture
		picture.position = Vector2(7, 7)
		picture.size = Vector2(side - 14, side - 14)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if id == "custom" else CanvasItem.TEXTURE_FILTER_NEAREST
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
	else:
		var plus := label("+", 26, MUTED)
		plus.size = Vector2(side, side)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(plus)
	var mark := Label.new()
	mark.name = "SelectedMark"
	mark.text = "✓"
	mark.add_theme_font_override("font", G.font_reg)
	mark.add_theme_font_size_override("font_size", 12)
	mark.add_theme_color_override("font_color", Color("f7f2e6"))
	mark.add_theme_stylebox_override("normal", surface(Color("9b4b31"), Color("e6c68b"), 1))
	mark.position = Vector2(side - 15, 0)
	mark.size = Vector2(15, 16)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.visible = false
	card.add_child(mark)
	var caption := label("自选" if id == "custom" else String(Avatars.NAMES[id]), 15, MUTED)
	caption.add_theme_font_override("font", G.font_serif)
	caption.name = "Caption"
	caption.position.y = side + 7
	caption.size.x = side
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(caption)
	root.mouse_entered.connect(func(): card.modulate = Color(1.04, 1.04, 1.02))
	root.mouse_exited.connect(func(): card.modulate = Color.WHITE)
	return root

static func select_card(card: Control, active: bool) -> void:
	var id := String(card.get_meta("avatar_id"))
	var style := card.get_meta("style") as StyleBoxFlat
	style.bg_color = Color("3b5748") if active else (
		Color("d5c59c") if id == "custom" else Color("29423d"))
	style.border_color = Color("b58036") if active else Color("9f8a5b")
	style.set_border_width_all(2 if active else 1)
	(card.get_node("Card/SelectedMark") as Label).visible = active
	(card.get_node("Caption") as Label).add_theme_color_override("font_color", INK if active else MUTED)
