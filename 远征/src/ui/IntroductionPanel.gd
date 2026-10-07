extends Control
signal closed
const Deck := preload("res://src/ui/PageDeck.gd")
const Style := preload("res://src/ui/LedgerStyle.gd")
const Art := preload("res://src/ui/IllustratedUI.gd")
const WORLD_ART := "res://image/ui/frontend_polish_20261007/journey_world.png"
var _deck: Control
var _route_preview: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	G.veil(self,.86)
	var top := roundf((maxf(800,get_viewport_rect().size.y)-688)/2)
	var panel := Art.Folio.new()
	panel.position = Vector2(20,top)
	panel.size = Vector2(440,688)
	add_child(panel)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_label(content,"远征手记",Vector2(12,8),Vector2(280,44),30,Color("e9ce95"),true)
	_label(content,"昭元行旅录  /  旅途档案",Vector2(12,56),Vector2(280,24),13,Color("c8bd9a"))
	_deck = Deck.new(356,420)
	_deck.position = Vector2(0,172)
	_deck.key_mode = "lr"
	_deck.page_gap = 20
	_deck.navigation_visible = false
	for i in 3: _deck.add_page(_page(i),Vector2(356,420))
	content.add_child(_deck)
	_deck.page_changed.connect(func(i: int):
		if i==2 and is_instance_valid(_route_preview): _route_preview.call("play"))
	var tabs := Art.tab_row(_deck,["世界","旅人","启程"],356)
	tabs.position = Vector2(0,120)
	content.add_child(tabs)
	var back := G.ghost_button("返回",144,40)
	Style.apply_button(back,"quiet")
	back.position = Vector2(106,604)
	back.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: closed.emit())
	content.add_child(back)
	G.reveal_control(panel)

func _label(parent: Control, words: String, at: Vector2, extent: Vector2, px: int, color: Color, title := false) -> Label:
	var label := Style.text(words,px,color)
	if title: label.add_theme_font_override("font",G.font_art)
	label.position = at
	label.size = extent
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _page(index: int) -> Control:
	var page := Control.new()
	page.size = Vector2(356,420)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if index==0:
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture = load(WORLD_ART)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.size = Vector2(356,228)
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(picture)
		var shade := ColorRect.new()
		shade.position = Vector2(0,166)
		shade.size = Vector2(356,62)
		shade.color = Color("142e26",.78)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(shade)
		_label(page,"裂隙之下",Vector2(16,170),Vector2(280,44),28,Color("f3dfad"),true)
		_label(page,"世界卷 · 01",Vector2(4,244),Vector2(348,24),13,Style.MUTED)
		_label(page,"大陆历947年，北境裂隙撕开。\n亡国皇子与旅人在灰烬中相遇。",Vector2(12,278),Vector2(336,72),17,Style.INK)
		_label(page,"从昭元出发，沿行旅册认识这片大陆。",Vector2(12,370),Vector2(336,32),14,Style.MUTED)
	elif index==1:
		for i in G.roles.size():
			var role: Dictionary = G.roles[i]
			var card := _RoleCard.new()
			card.position = Vector2((i%2)*186,(i/2)*136)
			card.size = Vector2(170,124)
			card.hue = [Color("a26e43"),Color("587a64"),Color("6990a1"),Color("a19155")][i]
			page.add_child(card)
			var portrait := TextureRect.new()
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.texture = load(G.role_icon_path(String(role.id)))
			portrait.position = Vector2(8,8)
			portrait.size = Vector2(78,94)
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(portrait)
			_label(card,String(role.get("name","")),Vector2(94,24),Vector2(76,32),21,Style.JADE,true)
			_label(card,String(role.get("job","")),Vector2(94,64),Vector2(76,28),14,Style.MUTED)
		_label(page,"四位旅人",Vector2(4,276),Vector2(348,40),26,Style.INK,true)
		_label(page,"剑、弓、冰霜与灯火。\n选择职业，结识伙伴，组成远征队伍。",Vector2(4,324),Vector2(348,76),16,Style.INK)
	else:
		var route := _Route.new()
		route.size = Vector2(356,256)
		_route_preview = route
		page.add_child(route)
		_label(page,"沿先王的足迹",Vector2(4,276),Vector2(348,40),26,Style.INK,true)
		_label(page,"穿越森林、雪原、火山与墓穴。\n构筑词条，挑战首领，失败后重整旗鼓。",Vector2(4,324),Vector2(348,76),16,Style.INK)
	return page

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()

class _RoleCard extends Control:
	var hue := Color("557367")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("efe4c7",.5))
		draw_rect(Rect2(0,12,2,size.y-24),hue)
		draw_line(Vector2(12,size.y-4),Vector2(size.x-8,size.y-4),Color(hue,.4),1)

class _Route extends Control:
	var points := PackedVector2Array([Vector2(48,166),Vector2(134,62),Vector2(236,175),Vector2(315,52)])
	var route: PackedVector2Array
	var milestones: Array[float] = []
	var progress := 1.0:
		set(value):
			progress=value
			queue_redraw()
	var motion: Tween
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var curve := Curve2D.new()
		curve.bake_interval=2
		for p in points: curve.add_point(p,Vector2(-24,0),Vector2(24,0))
		route=curve.get_baked_points()
		for p: Vector2 in points:
			var closest:=0
			for i in route.size():
				if route[i].distance_squared_to(p)<route[closest].distance_squared_to(p): closest=i
			milestones.append(float(closest)/maxi(1,route.size()-1))
	func play() -> void:
		if motion!=null and motion.is_valid(): motion.kill()
		if G.get_meta("ui_review_mode",false): progress=1.0; return
		progress=0.0
		motion=create_tween()
		motion.tween_property(self,"progress",1.0,1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	func _draw() -> void:
		Art.draw(self,"journey_atlas",Rect2(Vector2.ZERO,size))
		if route.size()<2:return
		var count:=clampi(int(progress*(route.size()-1))+1,1,route.size())
		var written:=route.slice(0,count)
		if written.size()>1:
			draw_polyline(written,Color("eee4c4",.88),5,true)
			draw_polyline(written,Color("8b6246"),2,true)
		for i in points.size():
			var lit:=progress>=milestones[i]
			draw_circle(points[i],6,Color("816643") if lit else Color("aaa18a"))
			draw_circle(points[i],3,Color("f3dfab"))
			var at:=points[i]+Vector2(-23,12)
			draw_rect(Rect2(at,Vector2(46,23)),Color("f0e4c4",.92))
			draw_string(G.font_serif,at+Vector2(8,17),["森林","雪原","火山","墓穴"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("3d503e"))
		if progress>0 and progress<1: draw_circle(route[count-1],3,Color("a9563c"))

