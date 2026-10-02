extends Control
signal closed
const Deck := preload("res://src/ui/PageDeck.gd")
var _deck: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	G.veil(self, 0.9)
	var top := (maxf(800, get_viewport_rect().size.y) - 540) * 0.5
	var heading := G.banner_box("远征手记", 240, 50)
	heading.position = Vector2(120, top - 70)
	add_child(heading)
	var panel := G.parchment_box(440, 540, 16)
	panel.position = Vector2(20, top)
	add_child(panel)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_deck = Deck.new(408, 348)
	_deck.position = Vector2(0, 76)
	_deck.key_mode = "lr"
	_deck.page_gap = 18
	for i in 3: _deck.add_page(_page(i))
	content.add_child(_deck)
	var tabs := G.page_tabs(_deck, ["世界", "旅人", "启程"], ["world", "person", "door"], 408)
	tabs.position = Vector2(0, 8)
	content.add_child(tabs)
	var back := G.ghost_button("返回", 140, 44)
	back.position = Vector2(134, 460)
	back.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(back)
	G.reveal_control(panel)

func _page(index: int) -> Control:
	var page := Control.new()
	page.size = Vector2(408, 348)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if index == 0:
		var art := TextureRect.new()
		art.texture = load("res://image/background/home.png")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.position = Vector2(16, 0)
		art.size = Vector2(376, 154)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(art)
	elif index == 1:
		for i in G.roles.size():
			var role: Dictionary = G.roles[i]
			var art := TextureRect.new()
			art.texture = load(G.role_icon_path(String(role.id)))
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.position = Vector2(27 + i * 96, 20)
			art.size = Vector2(64, 64)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			page.add_child(art)
			var name_l := G.gold_label(String(role.get("name", "")), G.FS_XS, false, G.TEXT_DARK, false)
			name_l.position = Vector2(12 + i * 96, 104)
			name_l.size = Vector2(94, 28)
			page.add_child(name_l)
	else:
		var route := _Route.new()
		route.position = Vector2(24, 28)
		page.add_child(route)
	var captions := ["裂隙之下", "四位旅人", "沿先王的足迹"]
	var bodies := [
		"大陆历947年，北境裂隙撕开。\n亡国皇子与旅人在灰烬中相遇。",
		"剑、弓、冰霜与灯火。\n选择职业，结识伙伴，组成远征队伍。",
		"穿越森林、雪原、火山与墓穴。\n构筑词条，挑战首领，失败后重整旗鼓。",
	]
	var caption := G.serif_label(captions[index], G.FS_LG, G.TEXT_DARK)
	caption.position = Vector2(16, 178)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(caption)
	var body := G.text_label(bodies[index], G.FS_SM, G.TEXT_MUTED)
	body.position = Vector2(16, 228)
	body.size = Vector2(376, 94)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(body)
	return page

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

class _Route extends Node2D:
	func _draw() -> void:
		var points := PackedVector2Array([Vector2(16, 64), Vector2(112, 28), Vector2(208, 76), Vector2(336, 20)])
		draw_polyline(points, Color("a79c7e"), 2.0, true)
		for i in points.size():
			draw_circle(points[i], 15, Color("ece2cb"))
			draw_arc(points[i], 15, 0, TAU, 32, Color("887953"), 1.0, true)
			draw_circle(points[i], 5, Color("506e65") if i < 3 else Color("a17941"))
		var labels := ["森林", "雪原", "火山", "墓穴"]
		for i in labels.size():
			draw_string(G.font_reg, points[i] + Vector2(-17, 42), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_SM, G.TEXT_DARK)

