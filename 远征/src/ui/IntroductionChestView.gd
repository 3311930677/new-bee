extends Control
## 独立的手记皮肤，文字和交互均由原生控件呈现。
const ROOT := "res://assets/ui/introduction_20261015/"
const INK := Color("fff0c8")
const GOLD := Color("d6ad68")
var host: Control
var _canvas: Control
var _header: TextureRect
var _title: Label
var _back: Button
var _tabs: HBoxContainer
var _art: TextureRect
var _stage: Control
var _annotations: Control
var _panel: NinePatchRect
var _scroll: ScrollContainer
var _body: VBoxContainer
var _chapter: Label
var _heading: Label
var _description: Label
var _footer: HBoxContainer
var _previous: Button
var _next: Button
var _counter: Label
var _safe := Rect2()
var _tall := false

class Selection extends Control:
	signal page_changed(index: int)
	var current := 0
	var page_count := 3
	func go(index: int, _instant := false) -> void:
		var target := clampi(index, 0, page_count - 1)
		if target == current: return
		current = target
		page_changed.emit(current)
	func _unhandled_input(event: InputEvent) -> void:
		if G.ui_blocked: return
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			go(current + (-1 if event.is_action_pressed("ui_left") else 1))
			get_viewport().set_input_as_handled()

class Route extends Control:
	var progress := 1.0:
		set(value):
			progress = value
			queue_redraw()
	var motion: Tween
	var points := PackedVector2Array([Vector2(.18,.575), Vector2(.405,.355), Vector2(.66,.60), Vector2(.855,.37)])
	func play() -> void:
		if motion != null and motion.is_valid(): motion.kill()
		progress = 1.0
		if G.get_meta("ui_review_mode", false): return
		progress = 0.0
		motion = create_tween()
		motion.tween_property(self, "progress", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	func _draw() -> void:
		var curve := Curve2D.new()
		for point in points:
			curve.add_point(point * size, Vector2(-size.x*.08, 0), Vector2(size.x*.08, 0))
		var path := curve.get_baked_points()
		var count := clampi(int(progress * (path.size()-1))+1, 1, path.size())
		if count > 1:
			var line := path.slice(0, count)
			draw_polyline(line, Color("ce8528", .3), 10, true)
			draw_polyline(line, Color("62401f"), 4, true)
			draw_polyline(line, Color("fff1c8"), 2, true)
		for i in points.size():
			var point := points[i] * size
			draw_circle(point, 7, Color("b07924"))
			draw_circle(point, 4.2, Color("fff5cf"))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color("080d14")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_header = picture("header")
	_canvas.add_child(_header)
	_title = label("远征手记", 30)
	_canvas.add_child(_title)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "返回"
	_back.tooltip_text = "返回"
	_back.self_modulate.a = 0
	_back.pressed.connect(func():
		if not G.ui_blocked: host.closed.emit())
	_canvas.add_child(_back)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 2)
	_canvas.add_child(_tabs)
	host._deck = Selection.new()
	add_child(host._deck)
	host._deck.page_changed.connect(func(_i: int): refresh())
	for i in 3:
		var index := i
		var tab := button(["世界", "旅人", "启程"][i], false)
		tab.name = ["WorldTab", "TravelersTab", "JourneyTab"][i]
		tab.add_theme_font_size_override("font_size", 21)
		tab.pressed.connect(func():
			if not G.ui_blocked:
				host._deck.go(index)
				Audio.sfx("ui_click"))
		tab.icon = load(ROOT + ["icon_world", "icon_travelers", "icon_route"][i] + ".png")
		tab.expand_icon = true
		tab.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.add_theme_constant_override("icon_max_width", 25)
		tab.add_theme_constant_override("h_separation", 16)
		_tabs.add_child(tab)
	_stage = Control.new()
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_stage)
	_art = picture("world")
	_stage.add_child(_art)
	_annotations = Control.new()
	_annotations.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_annotations)
	_panel = NinePatchRect.new()
	_panel.texture = load(ROOT + "reading_panel.png")
	_panel.patch_margin_left = 48
	_panel.patch_margin_right = 48
	_panel.patch_margin_top = 98
	_panel.patch_margin_bottom = 25
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_canvas.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 3)
	_scroll.add_child(_body)
	_chapter = label("", 13, GOLD)
	_body.add_child(_chapter)
	_heading = label("", 30)
	_body.add_child(_heading)
	var divider := picture("divider")
	divider.custom_minimum_size.y = 6
	_body.add_child(divider)
	_description = label("", 14)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_constant_override("line_spacing", 3)
	_body.add_child(_description)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	_canvas.add_child(_footer)
	_previous = button("‹　上一章", false)
	_previous.name = "PreviousChapter"
	_previous.pressed.connect(func(): navigate(-1))
	_footer.add_child(_previous)
	_counter = label("", 19, GOLD)
	_counter.custom_minimum_size.x = 76
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer.add_child(_counter)
	_next = button("下一章　›", true)
	_next.name = "NextChapter"
	_next.pressed.connect(func(): navigate(1))
	_footer.add_child(_next)
	get_viewport().size_changed.connect(layout)
	refresh()

func label(words: String, font_size: int, color := INK) -> Label:
	var node := Label.new()
	node.text = words
	node.add_theme_font_override("font", G.font_serif)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color("08090d", .9))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func picture(id: String) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(ROOT + id + ".png")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return node

func button(words: String, primary: bool) -> Button:
	var node := Button.new()
	node.text = words
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_override("font", G.font_serif)
	node.add_theme_font_size_override("font_size", 22)
	style_button(node, primary)
	return node

func style_button(node: Button, primary: bool) -> void:
	var is_tab := String(node.name).ends_with("Tab")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		var prefix := "tab_" if is_tab else "button_"
		style.texture = load(ROOT + prefix + ("red" if primary and state != "disabled" else "dark") + ".png")
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_texture_margin(side, 12 if is_tab else 14)
			style.set_content_margin(side, 8)
		if is_tab: style.set_content_margin(SIDE_LEFT, 22)
		if state == "pressed": style.modulate_color = Color(.75, .7, .6)
		if state == "hover": style.modulate_color = Color(1.15, 1.1, 1)
		node.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, INK)
	node.add_theme_color_override("font_disabled_color", Color("766e60"))
	node.add_theme_color_override("icon_normal_color", GOLD if primary else Color("95764d"))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ffe1a0")
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)

func navigate(direction: int) -> void:
	if G.ui_blocked: return
	host._deck.go(host._deck.current + direction)
	Audio.sfx("ui_click")

func refresh() -> void:
	var index: int = host._deck.current
	_counter.text = "%d / 3" % (index + 1)
	_previous.disabled = index == 0
	_next.disabled = index == 2
	for i in 3: style_button(_tabs.get_child(i), i == index)
	var texture: Texture2D = load(ROOT + ["world", "travelers", "route"][index] + ("_tall" if _tall and index > 0 else "") + ".png")
	_art.texture = texture
	_chapter.text = ["世界卷 · 01", "旅人卷 · 02", "启程卷 · 03"][index] + "　◇──"
	_heading.text = ["裂隙之下", "四位旅人", "沿先王的足迹"][index]
	_description.text = [
		"大陆历947年，北境裂隙撕开。\n亡国皇子与旅人在灰烬中相遇。\n从昭元出发，沿行旅册认识这片大陆。",
		"剑、弓、冰霜与灯火。\n选择职业，结识伙伴，组成远征队伍。",
		"穿越森林、雪原、火山与墓穴。\n构筑词条，挑战首领，失败后重整旗鼓。"
	][index]
	for child in _annotations.get_children():
		_annotations.remove_child(child)
		child.queue_free()
	host._route_preview = null
	if index == 1:
		for i in mini(4, G.roles.size()):
			var role: Dictionary = G.roles[i]
			var caption := label(String(role.name) + "\n" + String(role.job), 16)
			caption.name = "Role%d" % i
			_annotations.add_child(caption)
	elif index == 2:
		var route := Route.new()
		route.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_annotations.add_child(route)
		host._route_preview = route
		route.play()
		for i in 4:
			var caption := label(["森林", "雪原", "火山", "墓穴"][i], 15, Color("342818"))
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_constant_override("shadow_offset_y", 0)
			caption.name = "Place%d" % i
			_annotations.add_child(caption)
	_scroll.scroll_vertical = 0
	layout()

func place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size

func layout(safe_override := Rect2()) -> void:
	if not is_instance_valid(_footer): return
	_safe = safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var factor := _safe.size.x / 480.0
	_canvas.position = _safe.position
	_canvas.scale = Vector2.ONE * factor
	var height := _safe.size.y / factor
	var tall := height > 900.0
	if tall != _tall:
		_tall = tall
		var index: int = host._deck.current
		_art.texture = load(ROOT + ["world", "travelers", "route"][index] + ("_tall" if _tall and index > 0 else "") + ".png")
	_canvas.size = Vector2(480, height)
	place(_header, Rect2(0, 0, 480, 64))
	place(_title, Rect2(77, 6, 300, 49))
	place(_back, Rect2(10, 6, 53, 49))
	place(_tabs, Rect2(10, 63, 460, 47))
	var footer_y := height - 80.0
	var panel_h := 196.0 if host._deck.current == 0 else 176.0
	var panel_y := footer_y - 10.0 - panel_h
	place(_panel, Rect2(0, panel_y, 480, panel_h))
	place(_scroll, Rect2(53, panel_y + 25, 383, panel_h - 36))
	place(_footer, Rect2(14, footer_y, 452, 56))
	place(_stage, Rect2(0, 110, 480, maxf(120, panel_y - 94)))
	var dimensions := _art.texture.get_size()
	var ratio := _stage.size.x / dimensions.x
	ratio = maxf(ratio, _stage.size.y / dimensions.y)
	var art_size := dimensions * ratio
	var origin := (_stage.size - art_size) * .5
	place(_art, Rect2(origin, art_size))
	place(_annotations, Rect2(origin, art_size))
	if host._deck.current == 1:
		var locations := [Vector2(.30,.20), Vector2(.87,.21), Vector2(.27,.50), Vector2(.88,.52)]
		if _tall: locations = [Vector2(.31,.32), Vector2(.87,.33), Vector2(.28,.48), Vector2(.88,.50)]
		for i in _annotations.get_child_count():
			place(_annotations.get_child(i), Rect2(locations[i] * art_size, Vector2(58, 60)))
	elif host._deck.current == 2:
		host._route_preview.points = PackedVector2Array([Vector2(.185,.535), Vector2(.416,.39), Vector2(.655,.557), Vector2(.861,.404)]) if _tall else PackedVector2Array([Vector2(.18,.575), Vector2(.405,.355), Vector2(.66,.60), Vector2(.855,.37)])
		place(host._route_preview, Rect2(Vector2.ZERO, art_size))
		host._route_preview.queue_redraw()
		var locations := [Vector2(.18,.581), Vector2(.415,.366), Vector2(.655,.612), Vector2(.856,.384)]
		if _tall: locations = [Vector2(.185,.546), Vector2(.416,.405), Vector2(.655,.569), Vector2(.861,.417)]
		for i in 4:
			place(_annotations.get_node("Place%d" % i), Rect2(locations[i] * art_size + Vector2(-25, 0), Vector2(50, 24)))
