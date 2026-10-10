extends Control
signal closed
const Deck := preload("res://src/ui/PageDeck.gd")
const Style := preload("res://src/ui/LedgerStyle.gd")
const Art := preload("res://src/ui/IllustratedUI.gd")
const WORLD_ART := "res://image/ui/frontend_polish_20261007/journey_world.png"
var _deck: Control
var _route_preview: Control

class _IntroBoard extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# 1. Drop shadow
		draw_rect(Rect2(4, 8, w - 8, h - 6), Color(0.04, 0.06, 0.08, 0.65))
		# 2. Dark Iron & Leather chassis frame
		draw_rect(Rect2(0, 0, w, h), Color("1a242c"))
		draw_rect(Rect2(0, 0, w, h), Color("0d1318"), false, 1.0)
		draw_rect(Rect2(2, 2, w - 4, h - 4), Color("8a6a28"), false, 1.0)
		# 3. Inner warm vellum parchment sheet
		var paper := Rect2(12, 12, w - 24, h - 24)
		draw_rect(paper, Color("f2e6cb"))
		draw_rect(paper, Color("b89d6c"), false, 1.0)
		draw_rect(Rect2(14, 14, w - 28, h - 28), Color("dfcaa0"), false, 1.0)
		# 4. Top dark jade header plaque for title
		var header_rect := Rect2(20, 18, w - 40, 68)
		draw_rect(header_rect, Color("142c26"))
		draw_rect(header_rect, Color("c8a24c"), false, 1.0)
		draw_line(Vector2(24, 84), Vector2(w - 24, 84), Color("ffe894", 0.6), 1.0)
		# 5. Brass corner brackets
		for c in [Vector2(2, 2), Vector2(w - 14, 2), Vector2(2, h - 14), Vector2(w - 14, h - 14)]:
			draw_rect(Rect2(c, Vector2(12, 12)), Color("8a6a28"))
			draw_rect(Rect2(c + Vector2(2, 2), Vector2(8, 8)), Color("ffe894"))
			draw_circle(c + Vector2(6, 6), 2.0, Color("5c3a10"))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view:=preload("res://src/ui/IntroductionChestView.gd").new()
	view.host=self
	add_child(view)
func _build_tab_row(deck: Control, names: Array, width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(width, 38)
	row.add_theme_constant_override("separation", 8)
	var buttons: Array[Button] = []
	for i in names.size():
		var index := i
		var btn := Button.new()
		btn.text = String(names[i])
		btn.custom_minimum_size = Vector2((width - 16) / 3, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_override("font", G.font_serif)
		btn.add_theme_font_size_override("font_size", 16)
		for state in ["normal","hover","pressed","disabled","focus"]:
			btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		btn.pressed.connect(func(): deck.call("go", index); Audio.sfx("ui_click"))
		row.add_child(btn)
		buttons.append(btn)
	var refresh := func(selected: int):
		for i in buttons.size():
			var style := StyleBoxFlat.new()
			var is_sel := (i == selected)
			style.bg_color = Color("18342c") if is_sel else Color("ded0b4")
			style.border_color = Color("d8a846") if is_sel else Color("a89066")
			style.set_border_width_all(1)
			if is_sel: style.border_width_bottom = 3
			style.set_corner_radius_all(2)
			for state in ["normal","hover","pressed"]: buttons[i].add_theme_stylebox_override(state, style)
			for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
				buttons[i].add_theme_color_override(state, Color("ffe894") if is_sel else Color("4a3622"))
	deck.connect("page_changed", refresh)
	refresh.call(int(deck.get("current")))
	return row

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
	page.size = Vector2(380,440)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if index==0:
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture = load(WORLD_ART)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.size = Vector2(380,210)
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(picture)
		var shade := ColorRect.new()
		shade.position = Vector2(0,160)
		shade.size = Vector2(380,50)
		shade.color = Color("142e26",.88)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(shade)
		_label(page,"裂隙之下",Vector2(16,165),Vector2(348,40),24,Color("f8dfad"),true)
		_label(page,"世界卷 · 01",Vector2(4,220),Vector2(364,22),13,Color("8a5e20"))
		_label(page,"大陆历947年，北境裂隙撕开。\n亡国皇子与旅人在灰烬中相遇。",Vector2(4,248),Vector2(364,60),16,Color("2a1c12"))
		_label(page,"从昭元出发，沿行旅册认识这片大陆。",Vector2(4,320),Vector2(364,30),14,Color("5c4930"))
	elif index==1:
		for i in G.roles.size():
			var role: Dictionary = G.roles[i]
			var card := _RoleCard.new()
			card.position = Vector2((i%2)*192,(i/2)*116)
			card.size = Vector2(184,106)
			card.hue = [Color("a26e43"),Color("587a64"),Color("6990a1"),Color("a19155")][i]
			page.add_child(card)
			var portrait := TextureRect.new()
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.texture = load(G.role_icon_path(String(role.id)))
			portrait.position = Vector2(8,8)
			portrait.size = Vector2(72,88)
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(portrait)
			_label(card,String(role.get("name","")),Vector2(88,20),Vector2(86,30),20,Style.JADE,true)
			_label(card,String(role.get("job","")),Vector2(88,54),Vector2(86,24),13,Style.MUTED)
		_label(page,"四位旅人",Vector2(4,246),Vector2(364,36),24,Color("8a5e20"),true)
		_label(page,"剑、弓、冰霜与灯火。\n选择职业，结识伙伴，组成远征队伍。",Vector2(4,286),Vector2(364,60),15,Color("2a1c12"))
	else:
		var route := _Route.new()
		route.size = Vector2(380,240)
		_route_preview = route
		page.add_child(route)
		_label(page,"沿先王的足迹",Vector2(4,256),Vector2(364,36),24,Color("8a5e20"),true)
		_label(page,"穿越森林、雪原、火山与墓穴。\n构筑词条，挑战首领，失败后重整旗鼓。",Vector2(4,296),Vector2(364,60),15,Color("2a1c12"))
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
		draw_rect(Rect2(Vector2.ZERO,size),Color("efe4c7",.6))
		draw_rect(Rect2(0,0,size.x,size.y),Color("c8b894"),false,1.0)
		draw_rect(Rect2(0,12,3,size.y-24),hue)
		draw_line(Vector2(12,size.y-4),Vector2(size.x-8,size.y-4),Color(hue,.4),1)

class _Route extends Control:
	const ATLAS_TEX := preload("res://image/ui/designer_20261007/journey_atlas.png")
	var points := PackedVector2Array([Vector2(48,160),Vector2(140,56),Vector2(250,170),Vector2(335,48)])
	var route: PackedVector2Array
	var milestones: Array[float] = []
	var progress := 1.0:
		set(value):
			progress=value
			queue_redraw()
	var motion: Tween
	func _ready() -> void:
		custom_minimum_size = Vector2(380, 240)
		size = custom_minimum_size
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
		if ATLAS_TEX != null:
			draw_texture_rect(ATLAS_TEX, Rect2(Vector2.ZERO, size), false)
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

