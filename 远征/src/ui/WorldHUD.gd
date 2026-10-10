class_name WorldHUD
extends RefCounted
const UI := preload("res://src/ui/LacquerUI.gd")
const STATUS_SIZE := Vector2(176, 56)
const GOLD_POS := Vector2(196, 8)
const GOLD_SIZE := Vector2(104, 44)
const CITY_TASK_Y := 76.0
const FIELD_TASK_Y := 76.0
const TASK_GAP := 50.0
const WOOD := Color("17151a", 0.78)
const EDGE := Color("6e5434")
const BRASS := Color("c29a5b")
const PAPER := Color("f3e8d0")

static func hud_theme() -> Theme: return UI.theme()
static func label(text: String, px: int, color: Color, bold: bool = false) -> Label:
	var l := UI.label(text, px, color)
	if not bold: l.add_theme_font_override("font", G.font_reg)
	return l

static func surface(bg: Color, edge: Color, _radius: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	return s

static func finish(canvas: CanvasItem, dimensions: Vector2, _accent: Color, _paper: bool = false) -> void:
	UI.plate(canvas, Rect2(Vector2.ZERO, dimensions), Color.TRANSPARENT)

static func status(hp_fill: ColorRect, exp_fill: ColorRect) -> Dictionary:
	var root := MaterialPanel.new()
	root.name = "WorldStatus"
	root.position = Vector2(12, 12)
	root.size = STATUS_SIZE
	var lv_caption := label("Lv", 12, UI.AGED)
	lv_caption.position = Vector2(8, 3)
	lv_caption.size = Vector2(36, 16)
	root.add_child(lv_caption)
	var level := label("", 20, UI.PAPER, true)
	level.position = Vector2(8, 20)
	level.size = Vector2(36, 26)
	root.add_child(level)
	var hp := label("", 13, UI.PAPER, true)
	hp.position = Vector2(52, 2)
	hp.size = Vector2(120, 18)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hp)
	var heart := label("♥", 12, UI.JADE)
	heart.position = Vector2(52, 2)
	heart.size = Vector2(14, 18)
	root.add_child(heart)
	var caption := label("历练", 12, UI.AGED)
	caption.position = Vector2(52, 31)
	caption.size = Vector2(40, 16)
	root.add_child(caption)
	var exp := label("", 12, UI.AGED)
	exp.position = Vector2(92, 31)
	exp.size = Vector2(80, 16)
	exp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(exp)
	for item in [[hp_fill, 8, 20, UI.JADE], [exp_fill, 4, 48, UI.FROST]]:
		var fill := item[0] as ColorRect
		var bg := ColorRect.new()
		bg.color = UI.RAISED
		bg.position = Vector2(52, item[2])
		bg.size = Vector2(122, item[1])
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
		fill.position = Vector2.ONE
		fill.size = Vector2(0, int(item[1]) - 2)
		fill.color = item[3]
		fill.set_meta("hud_width", 120.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
	return {"root":root, "level":level, "hp":hp, "exp":exp}

static func progress(fill: ColorRect, ratio: float) -> void:
	fill.set_meta("hud_ratio", clampf(ratio, 0, 1))
	G.animate_fill(fill, float(fill.get_meta("hud_width", 120.0)) * clampf(ratio, 0, 1))

static func currency() -> Dictionary:
	var root := ActionChip.new()
	root.name = "WorldGold"
	root.position = GOLD_POS
	root.size = GOLD_SIZE
	root.inset_y = 8
	var icon := G.ui_icon("coin", Vector2(18, 18))
	icon.name = "GoldIcon"
	icon.position = Vector2(6, 13)
	root.add_child(icon)
	var value := label("", 13, UI.GOLD, true)
	value.position = Vector2(28, 8)
	value.size = Vector2(72, 28)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(value)
	return {"root":root, "value":value}

static func region_title(text: String) -> Control:
	var root := MaterialPanel.new()
	root.name = "RegionTitle"
	var width := clampf(G.font_serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20, 128, 200)
	root.position = Vector2(468 - width, 122)
	root.size = Vector2(width, 26)
	var l := UI.label(text, 15, UI.PAPER, true)
	l.position = Vector2(10, 2)
	l.size = Vector2(width - 20, 22)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	return root

static func task_chip(width: float, kind: String) -> Dictionary:
	var root := ActionChip.new()
	root.name = "WorldTask_" + kind
	root.size = Vector2(width, 44)
	root.task_kind = kind
	root.accent = {"story":UI.GOLD, "daily":UI.AGED, "side":UI.FROST}.get(kind, UI.AGED)
	var badge := label({"story":"主", "daily":"委", "side":"支"}.get(kind, "事"), 12, root.accent, true)
	badge.name = "TaskBadge"
	badge.position = Vector2(10, 12)
	badge.size = Vector2(20, 20)
	root.add_child(badge)
	var l := label("", 13, UI.PAPER)
	l.position = Vector2(34, 5)
	l.size = Vector2(width - 42, 34)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	root.add_child(l)
	return {"root":root, "label":l}

static func update_task(l: Label, words: String) -> void:
	var pieces := words.split("·", true, 1)
	l.text = pieces[1].strip_edges() if pieces.size() == 2 else words
	var chip := l.get_parent() as ActionChip
	if chip == null: return
	if pieces.size() == 2:
		var first := pieces[0].strip_edges()
		(chip.get_node("TaskBadge") as Label).text = first.left(1)
	# Reserve an actual 60px row for wrapped text; the owning map packs by height.
	var width := G.font_reg.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	chip.size.y = 60 if width > l.size.x else 44
	l.size.y = chip.size.y - 10
	chip.queue_redraw()

static func format_currency(amount: int) -> String:
	if amount >= 100000000: return "%d.%02d亿" % [amount / 100000000, (amount % 100000000) / 1000000]
	if amount >= 1000000: return "%d.%d万" % [amount / 10000, (amount % 10000) / 1000]
	var raw := str(amount)
	var out := ""
	for i in raw.length():
		if i > 0 and (raw.length() - i) % 3 == 0: out += ","
		out += raw[i]
	return out

static func update_currency(value: Label, amount: int) -> void:
	value.text = format_currency(amount)
	value.set_meta("hud_amount", amount)

static func motion_enabled() -> bool:
	return DisplayServer.get_name() != "headless" and not G.get_meta("ui_review_mode", false)

class MaterialPanel extends Control:
	const L = preload("res://src/ui/LacquerUI.gd")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void: L.plate(self, Rect2(Vector2.ZERO, size))

class ActionChip extends Button:
	const L = preload("res://src/ui/LacquerUI.gd")
	var bg := Color("17151a", 0.78)
	var edge := Color("6e5434")
	var accent := Color("c29a5b")
	var task_kind := ""
	var inset_y := 0.0
	var paper := false
	var chevron := false
	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for event in [mouse_entered, mouse_exited, button_down, button_up, focus_entered, focus_exited, resized]:
			event.connect(queue_redraw)
	func _draw() -> void:
		L.plate(self, Rect2(0, inset_y, size.x, size.y - inset_y * 2), L.RAISED if is_pressed() else bg, L.LIT if is_hovered() else edge)
		if not task_kind.is_empty(): draw_rect(Rect2(2, 3, 4, size.y - 6), accent)
		if has_focus(): L.plate(self, Rect2(Vector2.ONE * -2, size + Vector2.ONE * 4), Color.TRANSPARENT, L.PAPER)
	func pulse() -> void: queue_redraw()
