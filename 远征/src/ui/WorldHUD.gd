class_name WorldHUD
extends RefCounted
const UI := preload("res://src/ui/LacquerUI.gd")
const STATUS_SIZE := Vector2(176, 68)
const GOLD_POS := Vector2(196, 8)
const GOLD_SIZE := Vector2(104, 44)
const CITY_TASK_Y := 88.0
const FIELD_TASK_Y := 88.0
const TASK_GAP := 54.0
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
	s.set_corner_radius_all(maxi(2, _radius))
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 4
	return s

static func finish(canvas: CanvasItem, dimensions: Vector2, _accent: Color, _paper: bool = false) -> void:
	UI.plate(canvas, Rect2(Vector2.ZERO, dimensions), Color.TRANSPARENT)

static func status(hp_fill: ColorRect, exp_fill: ColorRect) -> Dictionary:
	var root := MaterialPanel.new()
	root.name = "WorldStatus"
	root.kind = "status"
	root.position = Vector2(12, 12)
	root.size = STATUS_SIZE
	var lv_caption := label("Lv", 12, UI.AGED)
	lv_caption.position = Vector2(8, 5)
	lv_caption.size = Vector2(36, 18)
	lv_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(lv_caption)
	var level := label("", 18, UI.GOLD, true)
	level.position = Vector2(8, 25)
	level.size = Vector2(36, 28)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(level)
	var hp := label("", 13, UI.PAPER, true)
	hp.position = Vector2(72, 2)
	hp.size = Vector2(96, 20)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hp)
	var heart := label("♥", 12, UI.JADE)
	heart.position = Vector2(56, 2)
	heart.size = Vector2(14, 20)
	root.add_child(heart)
	var caption := label("历练", 11, UI.AGED)
	caption.position = Vector2(56, 33)
	caption.size = Vector2(44, 20)
	root.add_child(caption)
	var exp := label("", 11, UI.AGED)
	exp.position = Vector2(96, 33)
	exp.size = Vector2(72, 20)
	exp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(exp)
	for item in [[hp_fill, 10, 23, UI.JADE], [exp_fill, 6, 55, UI.FROST]]:
		var fill := item[0] as ColorRect
		var bg := BarTrack.new()
		bg.position = Vector2(56, item[2])
		bg.size = Vector2(112, item[1])
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
		fill.position = Vector2(2, 2)
		fill.size = Vector2(0, int(item[1]) - 4)
		fill.color = item[3]
		fill.set_meta("hud_width", 108.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
		var glint := ColorRect.new()
		glint.color = Color(1, 1, 1, 0.25)
		glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.add_child(glint)
		glint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		glint.offset_bottom = 1
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
	icon.position = Vector2(7, 13)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	root.kind = "region"
	var width := clampf(G.font_serif.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20, 128, 200)
	root.position = Vector2(468 - width, 122)
	root.size = Vector2(width, 28)
	var l := UI.label(text, 15, UI.PAPER, true)
	l.position = Vector2(10, 3)
	l.size = Vector2(width - 20, 22)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(l)
	return root

static func task_chip(width: float, kind: String) -> Dictionary:
	var root := ActionChip.new()
	root.name = "WorldTask_" + kind
	root.size = Vector2(width, 50)
	root.task_kind = kind
	root.accent = {"story":UI.GOLD, "daily":UI.AGED, "side":UI.FROST}.get(kind, UI.AGED)
	var badge := label({"story":"主", "daily":"委", "side":"支"}.get(kind, "事"), 11, root.accent, true)
	badge.name = "TaskBadge"
	badge.position = Vector2(8, 12)
	badge.size = Vector2(22, 24)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(badge)
	var heading := label({"story":"当前主线", "daily":"行旅委托", "side":"追踪目标"}.get(kind,"行旅记事"), 10, root.accent)
	heading.name = "TaskHeading"
	heading.position = Vector2(38, 3)
	heading.size = Vector2(width - 46, 18)
	root.add_child(heading)
	var l := label("", 13, UI.PAPER)
	l.position = Vector2(38, 21)
	l.size = Vector2(width - 46, 25)
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
	var width := G.font_reg.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_XS).x
	chip.size.y = 72 if width > l.size.x else 50
	l.size.y = chip.size.y - 24
	chip.queue_redraw()

static func format_currency(amount: int) -> String:
	var v := absi(amount)
	var sign_prefix := "-" if amount < 0 else ""
	if v >= 100000000: return "%s%d.%02d亿" % [sign_prefix, v / 100000000, (v % 100000000) / 1000000]
	if v >= 1000000: return "%s%d.%02d万" % [sign_prefix, v / 10000, (v % 10000) / 100]
	return str(amount)

static func update_currency(value: Label, amount: int) -> void:
	value.text = format_currency(amount)
	value.set_meta("hud_amount", amount)

static func motion_enabled() -> bool:
	return DisplayServer.get_name() != "headless" and not G.get_meta("ui_review_mode", false)

class MaterialPanel extends Control:
	const L = preload("res://src/ui/LacquerUI.gd")
	const S = preload("res://src/ui/WorldHUDSkin.gd")
	var kind := ""
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		S.plate(self, Rect2(Vector2.ZERO, size))
		if kind == "status":
			S.medallion(self,Rect2(6,6,40,size.y-13))
			draw_line(Vector2(50,6),Vector2(50,size.y-6),Color(S.BRONZE,0.65),1)
		elif kind == "region":
			for x in [5.0,size.x-6]: S.diamond(self,Vector2(x,size.y*0.5),2,S.GOLD)

class BarTrack extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("715337"))
		draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("090e0d"))
		draw_line(Vector2(1,size.y-1),Vector2(size.x-1,size.y-1),Color("b18c58",0.65),1)

class ActionChip extends Button:
	const L = preload("res://src/ui/LacquerUI.gd")
	const S = preload("res://src/ui/WorldHUDSkin.gd")
	var bg := Color("171c1b", 0.95)
	var edge := S.BRONZE
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
		var r := Rect2(0, inset_y, size.x, size.y - inset_y * 2)
		S.plate(self, r, bg, S.GOLD if is_hovered() or has_focus() else edge, true, is_pressed())
		if not task_kind.is_empty():
			draw_rect(Rect2(4, inset_y + 8, 1, r.size.y - 16), accent)
			S.plate(self,Rect2(8,inset_y+11,22,26),Color("463824"),accent,false)
		if has_focus(): L.plate(self, Rect2(Vector2.ONE * -2, size + Vector2.ONE * 4), Color.TRANSPARENT, L.PAPER)
	func pulse() -> void: queue_redraw()
