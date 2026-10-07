class_name WorldHUD
extends RefCounted
## 共用漆木、黄铜、纸签与 4px 网格；书法标题、宋体正文、黑体数字各司其职。

const STATUS_SIZE := Vector2(184, 88)
const GOLD_POS := Vector2(212, 64)
const GOLD_SIZE := Vector2(136, 44)
const CITY_TASK_Y := 164.0
const FIELD_TASK_Y := 112.0
const TASK_GAP := 48.0
const WOOD := Color("20332f", 0.96)
const EDGE := Color("42382b")
const BRASS := Color("ae9567")
const PAPER := Color("e4ddc9", 0.98)

static func hud_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = G.font_serif
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", Color("eee8d5"))
	theme.set_constant("outline_size", "Label", 0)
	return theme

static func surface(bg: Color, edge: Color, radius := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = false
	return style

static func finish(canvas: CanvasItem, dimensions: Vector2, accent: Color, paper := false) -> void:
	canvas.draw_rect(Rect2(Vector2(2, 2), dimensions - Vector2(4, 4)), Color(accent, 0.3), false, 1)
	canvas.draw_line(Vector2(8, 3), Vector2(dimensions.x - 8, 3), Color.WHITE * Color(1, 1, 1, 0.12), 1)
	canvas.draw_line(Vector2(4, dimensions.y - 3), Vector2(dimensions.x - 4, dimensions.y - 3), Color("0d211d", 0.18), 1)
	# 稀疏、固定的木纹/纸纤维；不铺满颗粒，不随重绘抖动。
	var grain := Color("6c5737", 0.055) if paper else Color("d2c69d", 0.035)
	for i in range(3):
		var y := roundf(12 + i * maxf(8, (dimensions.y - 24) / 3))
		canvas.draw_line(Vector2(12 + i * 4, y), Vector2(minf(dimensions.x - 12, 40 + i * 8), y), grain, 1)

static func label(text: String, px: int, color: Color, bold := false) -> Label:
	var node := Label.new()
	node.text = text
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.add_theme_font_override("font", G.font_bold if bold else G.font_serif)
	node.add_theme_font_size_override("font_size", px)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("outline_size", 0)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func status(hp_fill: ColorRect, exp_fill: ColorRect) -> Dictionary:
	var root := MaterialPanel.new()
	root.name = "WorldStatus"
	root.theme = hud_theme()
	root.position = Vector2(16, 16)
	root.size = STATUS_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]: inset.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]: inset.add_theme_constant_override("margin_" + side, 8)
	root.add_child(inset)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(stack)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 24
	header.add_theme_constant_override("separation", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(header)
	var level := label("", 16, Color("e8d1a0"), true)
	level.custom_minimum_size.x = 44
	header.add_child(level)
	var heart := VitalGlyph.new()
	heart.custom_minimum_size = Vector2(12, 12)
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heart)
	var hp := label("", 13, Color("e6f0dc"))
	hp.add_theme_font_override("font", G.font_reg)
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp.clip_text = true
	header.add_child(hp)
	stack.add_child(_track(hp_fill, 8, Color("92cbaa"), Color("10241e")))
	var exp_row := HBoxContainer.new()
	exp_row.custom_minimum_size.y = 20
	exp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(exp_row)
	var exp_caption := label("历练", 12, Color("a6b4a8"))
	exp_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_row.add_child(exp_caption)
	var exp := label("", 12, Color("c6b58e"))
	exp.add_theme_font_override("font", G.font_reg)
	exp_row.add_child(exp)
	exp_fill.set_meta("hud_progress_kind", "exp")
	stack.add_child(_track(exp_fill, 4, Color("bca574"), Color("10232a")))
	return {"root": root, "level": level, "hp": hp, "exp": exp}

static func _track(fill: ColorRect, height: int, color: Color, bg: Color) -> Control:
	var track := Panel.new()
	track.custom_minimum_size.y = height
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track_style := surface(bg, Color("8da49b", 0.24), 1)
	track_style.set_border_width_all(1)
	track.add_theme_stylebox_override("panel", track_style)
	track.clip_contents = true
	fill.position = Vector2.ONE
	fill.color = color
	fill.size = Vector2(0, height - 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_meta("hud_ratio", 0.0)
	track.add_child(fill)
	if String(fill.get_meta("hud_progress_kind", "")) == "exp":
		var sweep := ProgressSweep.new()
		sweep.name = "ProgressSweep"
		sweep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sweep.visible = false
		track.add_child(sweep)
	track.resized.connect(func():
		var width := maxf(0.0, track.size.x - 2.0)
		fill.set_meta("hud_width", width)
		fill.set_meta("fill_target", -1.0)
		G.animate_fill(fill, width * float(fill.get_meta("hud_ratio", 0.0))))
	return track

static func progress(fill: ColorRect, ratio: float) -> void:
	var before := float(fill.get_meta("hud_ratio", 0.0))
	var initialized := bool(fill.get_meta("hud_initialized", false))
	fill.set_meta("hud_ratio", clampf(ratio, 0.0, 1.0))
	fill.set_meta("hud_initialized", true)
	G.animate_fill(fill, float(fill.get_meta("hud_width", 0.0)) * clampf(ratio, 0.0, 1.0))
	if initialized and ratio > before and motion_enabled():
		var sweep := fill.get_parent().get_node_or_null("ProgressSweep") as ProgressSweep
		if sweep != null: sweep.play()

static func currency() -> Dictionary:
	var chip := ActionChip.new()
	chip.name = "WorldGold"
	chip.theme = hud_theme()
	chip.position = GOLD_POS
	chip.size = GOLD_SIZE
	chip.bg = WOOD
	chip.edge = EDGE
	chip.accent = BRASS
	chip.tooltip_text = "查看金币与其他货币"
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]: inset.add_theme_constant_override("margin_" + side, 12)
	chip.add_child(inset)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(row)
	# 工厂先开启 EXPAND_IGNORE_SIZE，再设尺寸，48px 原图不会把 24px 图标撑大。
	var icon := G.ui_icon("coin", Vector2(24, 24))
	icon.name = "GoldIcon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var value := label("", 15, Color("d9cba9"), true)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	value.set_meta("hud_currency_chip", chip)
	row.add_child(value)
	return {"root": chip, "value": value}

static func region_title(text: String) -> Control:
	var root := RegionTitle.new()
	root.theme = hud_theme()
	root.position = Vector2(GOLD_POS.x, 16)
	root.size = Vector2(GOLD_SIZE.x, 44)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := label(text, 28, Color("fff0c9"))
	title.add_theme_font_override("font", G.font_art)
	# 长地图名改用更紧凑的宋体，避免缩放整段文字造成糊字。
	if G.font_art.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x > root.size.x - 12:
		title.add_theme_font_override("font", G.font_serif)
		title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.position = Vector2(6, 0)
	title.size = Vector2(root.size.x - 12, 40)
	root.add_child(title)
	return root

static func task_chip(width: float, kind: String) -> Dictionary:
	var chip := ActionChip.new()
	chip.name = "WorldTask_" + kind
	chip.theme = hud_theme()
	chip.size = Vector2(width, 44)
	chip.bg = PAPER
	chip.edge = EDGE
	chip.accent = Color("956c3d")
	chip.paper = true
	var text_color := Color("433b2d")
	var key := "quest"
	if kind == "daily":
		chip.accent = Color("817050")
		key = "book"
	elif kind == "side":
		chip.accent = Color("54766d")
		key = "world"
	var icon := G.ui_icon(key, Vector2(20, 20), chip.accent)
	icon.position = Vector2(12, 12)
	chip.add_child(icon)
	var badge := label({"story": "主线", "side": "支线", "daily": "委托"}.get(kind, "目标"), 12, chip.accent)
	badge.name = "TaskBadge"
	badge.position = Vector2(36, 8)
	badge.size = Vector2(28, 28)
	chip.add_child(badge)
	var text := label("", 14, text_color)
	text.position = Vector2(76, 8)
	text.size = Vector2(width - 104, 28)
	text.clip_text = true
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip.add_child(text)
	chip.chevron = true
	return {"root": chip, "label": text}

static func motion_enabled() -> bool:
	return DisplayServer.get_name() != "headless" and not G.get_meta("ui_review_mode", false)

static func update_task(text_label: Label, full_text: String) -> void:
	var chip := text_label.get_parent() as ActionChip
	if chip == null:
		text_label.text = full_text
		return
	var previous := String(text_label.get_meta("hud_task_text", ""))
	text_label.set_meta("hud_task_text", full_text)
	var pieces := full_text.split("·", true, 1)
	if pieces.size() == 2 and pieces[0].strip_edges() in ["主线", "支线", "委托", "港务", "驿务"]:
		(chip.get_node("TaskBadge") as Label).text = pieces[0].strip_edges()
		text_label.text = pieces[1].strip_edges()
	else:
		text_label.text = full_text
	if not previous.is_empty() and previous != full_text and motion_enabled():
		chip.pulse()
		var old: Tween = text_label.get_meta("hud_text_motion") if text_label.has_meta("hud_text_motion") else null
		if old != null and old.is_valid(): old.kill()
		text_label.position.y = 4
		text_label.modulate.a = 0.65
		var tween := text_label.create_tween().set_parallel(true)
		text_label.set_meta("hud_text_motion", tween)
		tween.tween_property(text_label, "position:y", 8.0, 0.24).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(text_label, "modulate:a", 1.0, 0.24)

static func update_currency(value: Label, amount: int) -> void:
	if value.has_meta("hud_amount") and int(value.get_meta("hud_amount")) == amount: return
	var previous := int(value.get_meta("hud_amount", amount))
	value.set_meta("hud_amount", amount)
	var old: Tween = value.get_meta("hud_number_motion") if value.has_meta("hud_number_motion") else null
	if old != null and old.is_valid(): old.kill()
	if previous == amount or not motion_enabled():
		value.text = str(amount)
		return
	var displayed := float(value.text.to_int())
	var tween := value.create_tween()
	value.set_meta("hud_number_motion", tween)
	var chip := value.get_meta("hud_currency_chip") as ActionChip
	chip.pulse()
	# 资源数只在发生变化时滚动；最终值与 tooltip 始终来自真实钱包。
	tween.tween_method(func(n: float): value.text = str(roundi(n)), displayed, float(amount), 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

class MaterialPanel extends Panel:
	func _ready() -> void:
		add_theme_stylebox_override("panel", WorldHUD.surface(WorldHUD.WOOD, WorldHUD.EDGE))
	func _draw() -> void:
		WorldHUD.finish(self, size, WorldHUD.BRASS)

class VitalGlyph extends Control:
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(1, 3), Vector2(3, 1), Vector2(6, 3), Vector2(9, 1),
			Vector2(11, 3), Vector2(11, 6), Vector2(6, 11), Vector2(1, 6)]), Color("92cbaa"))
		draw_line(Vector2(3, 3), Vector2(5, 3), Color("d0e4c6"), 1)

class ProgressSweep extends Control:
	var phase := 0.0:
		set(value):
			phase = value
			queue_redraw()
	var motion: Tween
	func play() -> void:
		if motion != null and motion.is_valid(): motion.kill()
		phase = 0.0
		visible = true
		motion = create_tween()
		motion.tween_property(self, "phase", 1.0, 0.48)
		motion.tween_callback(func(): visible = false)
	func _draw() -> void:
		var x := phase * size.x
		draw_rect(Rect2(x - 6, 0, 12, size.y), Color("f4ddb0", sin(phase * PI) * 0.25))
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color("fff1ca", sin(phase * PI) * 0.6), 2)

class ActionChip extends Button:
	var bg := Color("263c41")
	var edge := Color("82928b")
	var accent := Color("e5c487")
	var chevron := false
	var paper := false
	var feedback := 0.0:
		set(value):
			feedback = value
			queue_redraw()
	var _feedback_motion: Tween
	var _surface: StyleBoxFlat
	var _shadow: StyleBoxFlat

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size.y = 44
		_surface = WorldHUD.surface(bg, edge)
		_shadow = WorldHUD.surface(Color("071817", 0.27), Color.TRANSPARENT)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for event in [mouse_entered, mouse_exited, button_down, button_up, focus_entered, focus_exited]:
			event.connect(queue_redraw)

	func _draw() -> void:
		var active := is_hovered() or has_focus()
		var fill := bg.lightened(0.08) if active else bg
		if is_pressed(): fill = bg.darkened(0.06)
		_surface.bg_color = fill
		_surface.border_color = accent if active else edge
		draw_style_box(_shadow, Rect2(Vector2(0, 2), size))
		draw_style_box(_surface, Rect2(Vector2.ZERO, size))
		WorldHUD.finish(self, size, accent, paper)
		if paper:
			draw_rect(Rect2(4, 12, 2, size.y - 24), accent)
			draw_line(Vector2(68, 12), Vector2(68, size.y - 12), Color(accent, 0.24), 1)
		if feedback > 0:
			draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color("f4d7a0", feedback * 0.14))
			draw_line(Vector2(8, 3), Vector2(size.x - 8, 3), Color("ffe5ad", feedback * 0.8), 1)
		if chevron:
			var at := Vector2(size.x - 15, size.y * 0.5)
			draw_polyline(PackedVector2Array([at + Vector2(-2, -4), at + Vector2(2, 0), at + Vector2(-2, 4)]), accent, 1.5, true)
		if has_focus(): draw_line(Vector2(10, size.y - 3), Vector2(size.x - 10, size.y - 3), accent, 2)

	func pulse() -> void:
		if _feedback_motion != null and _feedback_motion.is_valid(): _feedback_motion.kill()
		feedback = 1.0
		_feedback_motion = create_tween()
		_feedback_motion.tween_property(self, "feedback", 0.0, 0.42)

class RegionTitle extends Control:
	var _surface := WorldHUD.surface(Color("172924", 0.82), Color.TRANSPARENT, 2)
	var reveal := 1.0:
		set(value):
			reveal = value
			queue_redraw()
	func _ready() -> void:
		if not WorldHUD.motion_enabled(): return
		reveal = 0.1
		modulate.a = 0.4
		var motion := create_tween().set_parallel(true)
		motion.tween_property(self, "reveal", 1.0, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		motion.tween_property(self, "modulate:a", 1.0, 0.4)
	func _draw() -> void:
		draw_style_box(_surface, Rect2(Vector2.ZERO, size))
		var middle := size.x * 0.5
		draw_line(Vector2(middle - 46 * reveal, size.y - 3), Vector2(middle - 6, size.y - 3), Color("d2ac6d", 0.8), 1)
		draw_line(Vector2(middle + 6, size.y - 3), Vector2(middle + 46 * reveal, size.y - 3), Color("d2ac6d", 0.8), 1)
		var p := Vector2(middle, size.y - 3)
		draw_colored_polygon([p + Vector2(0, -2), p + Vector2(2, 0), p + Vector2(0, 2), p + Vector2(-2, 0)], Color("e8ce98"))
