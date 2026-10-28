class_name LedgerStyle
extends RefCounted
## Shared travel panels: lacquered wood, brass fittings, paper and semantic status seals.
const WOOD := Color("20332f")
const EDGE := Color("42382b")
const BRASS := Color("ae9567")
const PAPER := Color("e4ddc9")
const LIGHT := Color("f3ecd9")
const INK := Color("35443b")
const MUTED := Color("82765e")
const JADE := Color("356653")
const BLUE := Color("345a69")
const RUST := Color("985b42")

static func text(words: String, px := G.FS_SM, ink := INK, numeric := false) -> Label:
	var node := Label.new()
	node.text = words
	node.add_theme_font_override("font", G.font_bold if numeric else G.font_serif)
	node.add_theme_font_size_override("font_size", maxi(px, G.FS_XS))
	node.add_theme_color_override("font_color", ink)
	node.add_theme_constant_override("outline_size", 0)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func panel(at: Vector2, extent: Vector2, paper := true, padding := 16) -> PanelContainer:
	var node := Frame.new()
	node.position = at
	node.size = extent
	node.paper = paper
	node.padding = padding
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func badge(words: String, status: String) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = "StatusBadge"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var colors: Array = {"available": ["c2d6ae", "2b5331"], "open": ["c2d6ae", "2b5331"],
		"active": ["bed8dc", "26515c"], "ready": ["e6d698", "684f18"],
		"done": ["d7d6bc", "50593c"], "expired": ["e8b8a6", "7e3f2b"],
		"abandoned": ["d3c2bb", "6a5045"], "settled": ["d7d6bc", "50593c"]}.get(status, ["d0cab9", "685e49"])
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colors[0])
	style.border_color = Color(colors[1])
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	node.add_theme_stylebox_override("panel", style)
	var lbl := text("◆ " + words, G.FS_XS, Color(colors[1]))
	node.add_child(lbl)
	return node

static func apply_button(button: Control, kind := "primary") -> void:
	var fill: Color = {"primary": JADE, "rules": BLUE, "danger": RUST, "quiet": WOOD}.get(kind, LIGHT)
	if button.has_method("set_surface"): button.call("set_surface", fill, BRASS)
	button.set_meta("primary_action", kind == "primary")
	button.set_meta("tab_selected", false)
	button.set_meta("ledger_kind", kind)
	for child in button.get_children():
		if child is Label:
			child.add_theme_font_override("font", G.font_serif)
			child.add_theme_color_override("font_color", INK if kind == "secondary" else LIGHT)

static func header_plaque(words: String, at: Vector2, width := 360.0) -> Control:
	var h := G.Visuals.header_plaque(words, width, 38.0)
	h.position = at
	return h

static func list_card(parent: VBoxContainer) -> VBoxContainer:
	var frame := panel(Vector2.ZERO, Vector2(384,0), true,14)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	frame.add_child(stack)
	return stack

static func paint(item: CanvasItem, extent: Vector2, fill: Color, accent := BRASS, paper := false) -> void:
	if extent.x < 12 or extent.y < 12:
		return
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bounds := Rect2(Vector2.ZERO, extent)
	item.draw_rect(Rect2(Vector2(2, 5), extent - Vector2(2, 2)), Color("0d1612", .52))
	item.draw_colored_polygon(_cut(bounds, 4), EDGE)
	item.draw_colored_polygon(_cut(bounds.grow(-2), 2), fill)

	# 叠加像素九宫格材质：子卡片用茶宣嵌铜框，大账本用古卷宣纸，木框/主按钮用玄铁木纹或暗铜底板
	if extent.x >= 44 and extent.y >= 28:
		if paper:
			var is_subcard := extent.y < 520
			var slip_tex := G.Visuals._kit_tex("card_frame_parchment.png" if is_subcard else "quest_slip.png")
			G.Visuals.nine_slice(item, slip_tex, bounds.grow(-1), 14.0, 12.0, Color(1, 1, 1, 0.90 if is_subcard else 0.72))
			if not is_subcard:
				# 保持大账本内芯宣纸纯净，防止外框暗边侵入 x=16 文本区
				item.draw_rect(bounds.grow(-6), Color(fill, 0.92))
			if extent.x >= 180 and extent.y >= 56 and not is_subcard:
				# 左侧古籍细装订线（收窄至 5px，绝不压内文）
				item.draw_rect(Rect2(2, 4, 3, extent.y - 8), fill.darkened(0.08))
				item.draw_line(Vector2(5, 4), Vector2(5, extent.y - 4), Color(accent, 0.42), 1.0)
			if extent.x >= 260 and extent.y >= 90:
				var seal_tex := G.Visuals._kit_tex("seal_stamps.png")
				if seal_tex != null:
					var seal_idx := posmod(int(extent.x + extent.y), 3)
					item.draw_texture_rect_region(seal_tex, Rect2(extent.x - 36, extent.y - 36, 24, 24),
						Rect2(float(seal_idx * 32), 0, 32, 32), Color(1, 1, 1, 0.22))
		else:
			var is_large := extent.x >= 240 and extent.y >= 120
			var frame_tex := G.Visuals._kit_tex("panel_iron.png" if is_large else "button_dark.png")
			G.Visuals.nine_slice(item, frame_tex, bounds, 14.0 if is_large else 10.0, 14.0 if is_large else 8.0, Color(1, 1, 1, 0.68 if is_large else 0.42))
			if is_large:
				# 顶部商行匾额横幅衬底
				var banner_tex := G.Visuals._kit_tex("trade_header_banner.png")
				if banner_tex != null and extent.y >= 260:
					item.draw_texture_rect(banner_tex, Rect2(6, 6, extent.x - 12, 64), false, Color(1, 1, 1, 0.32))
					item.draw_line(Vector2(8, 70), Vector2(extent.x - 8, 70), Color(accent, 0.55), 1.0)

	item.draw_rect(bounds.grow(-4), Color(accent, .68), false, 1)
	if extent.x >= 80 and extent.y >= 40:
		item.draw_rect(bounds.grow(-6), Color("983e2b" if paper else "e4c77a", 0.22), false, 1)
	item.draw_line(Vector2(8, 4), Vector2(extent.x - 8, 4), Color("fff1cf", .28), 1)
	item.draw_line(Vector2(4, extent.y - 4), Vector2(extent.x - 4, extent.y - 4), Color("101d17", .30), 1)
	# Restrained deterministic fibers/grain at the margins keep content areas clean.
	for i in range(4):
		var y := 12.0 + i * maxf(8, (extent.y - 24) / 4)
		item.draw_line(Vector2(8, roundf(y)), Vector2(12 + i, roundf(y)),
			Color("765d39", .06) if paper else Color("e1d4ad", .05), 1)
	for p in [Vector2(6, 6), Vector2(extent.x - 8, 6), Vector2(6, extent.y - 8), extent - Vector2(8, 8)]:
		item.draw_rect(Rect2(p, Vector2(2, 2)), accent.lightened(0.15))

static func _cut(r: Rect2, cut: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([a + Vector2(cut, 0), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut),
		b - Vector2(0, cut), b - Vector2(cut, 0), Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut), a + Vector2(0, cut)])

class Frame extends PanelContainer:
	var paper := true
	var padding := 16
	var fill := Color.TRANSPARENT
	func _ready() -> void:
		var style := StyleBoxEmpty.new()
		for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, padding)
		add_theme_stylebox_override("panel", style)
	func _draw() -> void:
		var color := fill if fill.a > 0 else (LedgerStyle.PAPER if paper else LedgerStyle.WOOD)
		LedgerStyle.paint(self, size, color, LedgerStyle.BRASS, paper)

class RouteRibbon extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var a := Vector2(16, 12)
		var b := Vector2(size.x - 16, 12)
		draw_line(a, b, Color("ae9567", 0.25), 1.0)
		for x in range(32, int(size.x - 24), 10): draw_line(Vector2(x, 12), Vector2(x + 5, 12), Color("8a6d3b", .75), 1.5)
		draw_circle(a, 5, LedgerStyle.JADE)
		draw_circle(a, 2.5, LedgerStyle.LIGHT)
		draw_colored_polygon(PackedVector2Array([b + Vector2(0, -6), b + Vector2(6, 0), b + Vector2(0, 6), b + Vector2(-6, 0)]), LedgerStyle.BLUE)
		draw_circle(b, 2.0, LedgerStyle.LIGHT)
