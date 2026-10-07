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

static func text(words: String, px := 16, ink := INK, numeric := false) -> Label:
	var node := Label.new()
	node.text = words
	node.add_theme_font_override("font", G.font_bold if numeric else G.font_serif)
	node.add_theme_font_size_override("font_size", px)
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
	var colors: Array = {"available": ["c2d6ae", "365b3b"], "open": ["c2d6ae", "365b3b"],
		"active": ["bed8dc", "305d69"], "ready": ["dcd19c", "695421"],
		"done": ["d7d6bc", "596244"], "expired": ["e3b6a5", "834936"],
		"abandoned": ["d3c2bb", "745b50"], "settled": ["d7d6bc", "596244"]}.get(status, ["d0cab9", "786e58"])
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colors[0])
	style.border_color = Color(colors[1])
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	node.add_theme_stylebox_override("panel", style)
	node.add_child(text(words, 14, Color(colors[1])))
	return node

static func apply_button(button: Control, kind := "primary") -> void:
	var fill: Color = {"primary": JADE, "rules": BLUE, "danger": RUST, "quiet": WOOD}.get(kind, LIGHT)
	if button.has_method("set_surface"): button.call("set_surface", fill, BRASS)
	button.set_meta("primary_action", false)
	button.set_meta("tab_selected", false)
	button.set_meta("ledger_kind", kind)
	for child in button.get_children():
		if child is Label:
			child.add_theme_font_override("font", G.font_serif)
			child.add_theme_color_override("font_color", INK if kind == "secondary" else LIGHT)

static func list_card(parent: VBoxContainer) -> VBoxContainer:
	var frame := panel(Vector2.ZERO, Vector2(384,0), true,12)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	frame.add_child(stack)
	return stack

static func paint(item: CanvasItem, extent: Vector2, fill: Color, accent := BRASS, paper := false) -> void:
	var bounds := Rect2(Vector2.ZERO, extent)
	item.draw_rect(Rect2(Vector2(0, 4), extent), Color("101c17", .45))
	item.draw_colored_polygon(_cut(bounds, 4), EDGE)
	item.draw_colored_polygon(_cut(bounds.grow(-2), 2), fill)
	item.draw_rect(bounds.grow(-3), Color(accent, .55), false, 1)
	item.draw_line(Vector2(8, 4), Vector2(extent.x - 8, 4), Color("fff1cf", .25), 1)
	item.draw_line(Vector2(4, extent.y - 4), Vector2(extent.x - 4, extent.y - 4), Color("101d17", .25), 1)
	# Restrained deterministic fibers/grain at the margins keep content areas clean.
	for i in range(4):
		var y := 12.0 + i * maxf(8, (extent.y - 24) / 4)
		item.draw_line(Vector2(8, roundf(y)), Vector2(16 + i * 2, roundf(y)),
			Color("765d39", .09) if paper else Color("e1d4ad", .06), 1)
	for p in [Vector2(6, 6), Vector2(extent.x - 8, 6), Vector2(6, extent.y - 8), extent - Vector2(8, 8)]:
		item.draw_rect(Rect2(p, Vector2(2, 2)), accent)

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
		for x in range(32, int(size.x - 24), 12): draw_line(Vector2(x, 12), Vector2(x + 5, 12), Color("ae9567", .65), 1)
		draw_circle(a, 4, LedgerStyle.JADE)
		draw_circle(a, 2, LedgerStyle.LIGHT)
		draw_colored_polygon(PackedVector2Array([b + Vector2(0, -5), b + Vector2(5, 0), b + Vector2(0, 5), b + Vector2(-5, 0)]), LedgerStyle.BLUE)
