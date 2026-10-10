extends RefCounted
## B1 shared visual system. Factories do not change game rules or global popup behavior.
const ROOT := "res://assets/ui/travel_chest_b1/"
const NIGHT := Color("17141a")
const FACE := Color("221e26")
const SELECTED := Color("2f2832")
const BRONZE := Color("6e5434")
const COPPER := Color("c29a5b")
const PAPER := Color("f3e8d0")
const AGED := Color("bfb096")
const GOLD := Color("f0b95a")
const RED := Color("cf4a33")
const JADE := Color("63b784")
const BLUE := Color("8db3c7")
const ASH := Color("77705f")
const SLIP := Color("e8dcc0")
const GRID := 4
const TOUCH := 44
const PAGE_MARGIN := 12
const Z_CONTENT := 30
const Z_TRAY := 40
const Z_FEEDBACK := 50
const Z_MODAL := 60
const FONT_SIZES := {"title":22,"section":17,"object":20,"body":14,"caption":13,"tag":12,"number":14,"primary":22,"hero":26,"secondary":17}
static var _theme: Theme
static var _regions: Dictionary = {}
static var _sources: Dictionary = {}
static var _textures: Dictionary = {}
static var _disabled_shader: Shader

static func disabled_shader() -> Shader:
	if _disabled_shader == null:
		_disabled_shader = Shader.new()
		_disabled_shader.code = "shader_type canvas_item; varying vec4 item_tint; uniform float gray=0.0; void vertex(){item_tint=COLOR;} void fragment(){vec4 c=texture(TEXTURE,UV)*item_tint; float v=dot(c.rgb,vec3(0.299,0.587,0.114)); c.rgb=mix(c.rgb,vec3(v)*0.65,gray); COLOR=c;}"
	return _disabled_shader

static func theme() -> Theme:
	if _theme != null: return _theme
	_theme = Theme.new()
	_theme.default_font = G.font_reg
	_theme.default_font_size = 14
	for role in FONT_SIZES:
		var variant: String = "Chest_"+str(role)
		_theme.set_type_variation(variant,"Label")
		var font: Font = G.font_serif if role in ["title","section","object","primary","hero","secondary"] else (G.font_bold if role in ["number","tag"] else G.font_reg)
		if role in ["title","primary","hero"]:
			var spaced := FontVariation.new()
			spaced.base_font = font
			spaced.spacing_glyph = 4
			font = spaced
		_theme.set_font("font",variant,font)
		_theme.set_font_size("font_size",variant,FONT_SIZES[role])
		_theme.set_color("font_color",variant,PAPER)
		_theme.set_color("font_shadow_color",variant,Color("0e0d10",0.8))
		_theme.set_constant("shadow_offset_y",variant,1)
		_theme.set_constant("outline_size",variant,0)
	return _theme

static func label(words: String, role: String = "body", color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = words
	l.theme = theme()
	l.theme_type_variation = "Chest_"+role
	l.add_theme_color_override("font_color",color)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func texture(id: String) -> Texture2D:
	if _textures.has(id): return _textures[id]
	if _regions.is_empty() and FileAccess.file_exists(ROOT+"regions.json"):
		_regions = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"regions.json"))
	if not _regions.has(id): return null
	var info: Dictionary = _regions[id]
	var file := String(info.file)
	if not _sources.has(file): _sources[file] = load(ROOT+file)
	var source := _sources[file] as Texture2D
	var scale := source.get_size()/Vector2(info.source_size[0],info.source_size[1])
	var rect: Array = info.rect
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(Vector2(rect[0],rect[1])*scale,Vector2(rect[2],rect[3])*scale)
	_textures[id] = atlas
	return atlas

static func cut(rect: Rect2, amount: float = 2.0) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([p+Vector2(amount,0),Vector2(e.x-amount,p.y),Vector2(e.x,p.y+amount),e-Vector2(0,amount),e-Vector2(amount,0),Vector2(p.x+amount,e.y),Vector2(p.x,e.y-amount),p+Vector2(0,amount)])

static func surface(canvas: CanvasItem, rect: Rect2, color: Color, border: Color = BRONZE, amount: float = 2.0) -> void:
	var points := cut(rect,amount)
	canvas.draw_colored_polygon(points,color)
	points.append(points[0])
	canvas.draw_polyline(points,border,1,true)

static func nine(canvas: CanvasItem, tex: Texture2D, dimensions: Vector2, hero: bool = false) -> void:
	if tex == null: return
	var src := tex.get_size()
	var dl := 60.0 if hero else 16.0
	var dr := 24.0 if hero else 16.0
	var dt := 4.0
	var sl := src.x*(0.16 if hero else 0.18)
	var sr := src.x*(0.05 if hero else 0.18)
	var st := src.y*0.13
	var xs := [0.0,sl,src.x-sr,src.x]
	var ys := [0.0,st,src.y-st,src.y]
	var xd := [0.0,dl,dimensions.x-dr,dimensions.x]
	var yd := [0.0,dt,dimensions.y-dt,dimensions.y]
	for y in 3:
		for x in 3:
			canvas.draw_texture_rect_region(tex,Rect2(xd[x],yd[y],xd[x+1]-xd[x],yd[y+1]-yd[y]),Rect2(xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y]))

static func action(words: String, skin: String = "secondary", icon: String = "") -> Button:
	return ChestButton.new(words,skin,icon)

static func format_number(amount: int) -> String:
	return preload("res://src/ui/WorldHUD.gd").format_currency(amount)

static func toast(parent: Node, words: String, kind: String = "info") -> Control:
	var t := Toast.new()
	t.words = words
	t.kind = kind
	parent.add_child(t)
	return t

class ChestButton extends Button:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	var caption: Label
	var subtitle: Label
	var skin := "secondary"
	var icon_id := ""
	var selected := false
	var locked := false
	var hint_dot := false
	var icon_px := 24.0
	var pressed_content := false
	var _state_material: ShaderMaterial
	func _init(words: String = "", family: String = "secondary", icon: String = "") -> void:
		text = words
		skin = family
		icon_id = icon
		caption = UI.label(words,"hero" if family=="hero" else ("primary" if family=="primary" else ("caption" if family=="nav" else ("tag" if family=="rail" else "secondary"))))
		caption.name = "Caption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(caption)
		subtitle = UI.label("","body" if family=="hero" else "caption",UI.AGED)
		subtitle.name = "Subtitle"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(subtitle)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _ready() -> void:
		if skin in ["primary","hero"]:
			_state_material = ShaderMaterial.new()
			_state_material.shader = UI.disabled_shader()
			material = _state_material
		for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for property in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]: add_theme_color_override(property,Color.TRANSPARENT)
		for event in [mouse_entered,mouse_exited,button_down,button_up,focus_entered,focus_exited,resized]: event.connect(queue_redraw)
		resized.connect(_layout)
		_layout()
	func _layout() -> void:
		var offset := 1.0 if is_pressed() else 0.0
		if skin == "hero":
			caption.position = Vector2(64,4+offset)
			caption.size = Vector2(size.x-88,40)
			caption.add_theme_color_override("font_color",UI.ASH if disabled else Color("f6d9a0"))
			subtitle.position = Vector2(64,45+offset)
			subtitle.size = Vector2(size.x-88,20)
		elif skin in ["nav","rail"]:
			caption.position = Vector2(0,size.y-24+offset)
			caption.size = Vector2(size.x,22)
		elif not subtitle.text.is_empty():
			caption.position=Vector2(0,offset)
			caption.size=Vector2(size.x,34)
			subtitle.position=Vector2(8,34+offset)
			subtitle.size=Vector2(size.x-16,20)
		else:
			caption.position = Vector2(0,offset)
			caption.size = size
	func _draw() -> void:
		_layout()
		if _state_material != null: _state_material.set_shader_parameter("gray",1.0 if disabled else 0.0)
		var primary := skin in ["primary","hero"]
		var bg := UI.SELECTED if selected else UI.FACE
		if primary:
			var state := "disabled" if disabled else ("pressed" if is_pressed() else "normal")
			var tex := UI.texture(skin+"_"+state)
			if tex != null: UI.nine(self,tex,size,skin=="hero")
			else: UI.surface(self,Rect2(Vector2.ZERO,size),Color("6a2b1f"),UI.COPPER,4)
		elif skin == "tab":
			draw_line(Vector2(8,size.y-1),Vector2(size.x-8,size.y-1),UI.BRONZE,1)
			if selected: draw_rect(Rect2(Vector2.ZERO,size),Color("2f2832",.5))
		elif skin not in ["quiet","back","nav","currency"]:
			UI.surface(self,Rect2(Vector2.ZERO,size),UI.NIGHT if skin=="rail" else bg,UI.COPPER if is_hovered() else UI.BRONZE)
		elif is_pressed(): UI.surface(self,Rect2(Vector2.ZERO,size),UI.FACE)
		if skin == "tab" and selected: draw_rect(Rect2(8,size.y-2,size.x-16,2),UI.COPPER)
		if skin == "back":
			caption.visible = false
			var p := size*.5
			draw_polyline(PackedVector2Array([p+Vector2(5,-8),p+Vector2(-4,0),p+Vector2(5,8)]),UI.PAPER,2,true)
		if skin == "currency": draw_line(Vector2(4,size.y-1),Vector2(size.x-4,size.y-1),Color("3a2c1c"),1)
		if not icon_id.is_empty():
			var icon := UI.texture(icon_id)
			if icon != null:
				var px := 40.0 if skin=="hero" else (32.0 if skin=="nav" else (28.0 if skin=="rail" else icon_px))
				var p := Vector2(12,16) if skin=="hero" else Vector2((size.x-px)*0.5,6 if skin in ["nav","rail"] else (size.y-px)*0.5)
				var dimensions := icon.get_size()*minf(px/icon.get_width(),px/icon.get_height())
				draw_texture_rect(icon,Rect2(p+(Vector2.ONE*px-dimensions)*0.5,dimensions),false,Color(0.5,0.5,0.5) if locked or disabled else Color.WHITE)
		if locked:
			draw_rect(Rect2(size.x-12,6,7,6),UI.ASH)
			draw_arc(Vector2(size.x-8.5,6),2.5,PI,TAU,8,UI.ASH,1)
		if hint_dot: draw_circle(Vector2(size.x-8,8),4,UI.RED)
		if has_focus():
			var points := UI.cut(Rect2(Vector2.ONE*-3,size+Vector2.ONE*6),4 if primary else 2)
			points.append(points[0])
			draw_polyline(points,Color("0e0d10"),4,true)
			draw_polyline(points,UI.GOLD,2,true)
		caption.modulate = Color(0.6,0.6,0.6) if locked or disabled else Color.WHITE

class Tray extends Control:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("17141a",0.96))
		var rim := UI.texture("tray_rim")
		if rim != null:
			var src := rim.get_size()
			var cap := src.y
			draw_texture_rect_region(rim,Rect2(0,0,12,12),Rect2(0,0,cap,src.y))
			draw_texture_rect_region(rim,Rect2(12,0,size.x-24,12),Rect2(cap,0,src.x-cap*2,src.y))
			draw_texture_rect_region(rim,Rect2(size.x-12,0,12,12),Rect2(src.x-cap,0,cap,src.y))
		else: draw_rect(Rect2(0,0,size.x,2),UI.COPPER)

class CurrencyChip extends ChestButton:
	var amount: Label
	var currency_image: TextureRect
	func _init() -> void:
		super("","currency")
		custom_minimum_size = Vector2(72,44)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amount = UI.label("","number")
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(amount)
		currency_image = TextureRect.new()
		currency_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		currency_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		currency_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		currency_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(currency_image)
	func _layout() -> void:
		amount.position = Vector2(28,8)
		amount.size = Vector2(maxf(44,size.x-32),28)
		currency_image.position = Vector2(4,12)
		currency_image.size = Vector2(20,20)

class QuestSlip extends ChestButton:
	var goal: Label
	var claimable := false
	func _init() -> void:
		super("任务","slip")
		goal = UI.label("","caption",Color("2b2420"))
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goal.max_lines_visible = 2
		goal.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		goal.clip_text = true
		add_child(goal)
	func _layout() -> void:
		caption.text = "可交付" if claimable else "主线 · 今日委托"
		caption.theme_type_variation = "Chest_tag"
		caption.add_theme_color_override("font_color",UI.JADE if claimable else Color("6e5434"))
		caption.position = Vector2(12,4)
		caption.size = Vector2(size.x-24,18)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		goal.position = Vector2(12,26)
		goal.size = Vector2(size.x-24,38)
	func _draw() -> void:
		UI.surface(self,Rect2(Vector2.ZERO,size),UI.SLIP.darkened(0.06) if is_pressed() else UI.SLIP,Color("b9a27a"))
		draw_rect(Rect2(0,4,4,size.y-8),UI.JADE if claimable else UI.GOLD)
		_layout()
		if has_focus(): draw_rect(Rect2(Vector2.ONE*-2,size+Vector2.ONE*4),UI.GOLD,false,2)

class Toast extends Control:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	var words := ""
	var kind := "info"
	func _ready() -> void:
		z_index = UI.Z_FEEDBACK
		size = Vector2(360,44)
		position = Vector2((get_viewport_rect().size.x-360)*0.5,get_viewport_rect().size.y/3)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var l := UI.label(words,"body")
		l.position = Vector2(12,4)
		l.size = Vector2(336,36)
		l.clip_text = true
		add_child(l)
		gui_input.connect(func(e:InputEvent):
			if e is InputEventMouseButton and e.pressed: queue_free())
		var timer := create_tween()
		timer.tween_interval(1.6)
		timer.tween_property(self,"modulate:a",0.0,0.16)
		timer.tween_callback(queue_free)
	func _draw() -> void:
		UI.surface(self,Rect2(Vector2.ZERO,size),UI.NIGHT)
		draw_rect(Rect2(0,2,4,size.y-4),UI.JADE if kind=="success" else (UI.RED if kind=="failure" else UI.BLUE))

class Modal extends Control:
	signal closed
	signal selected(index: int)
	const UI = preload("res://src/ui/TravelChestUI.gd")
	var heading := ""
	var lines: Array = []
	var choices: Array = []
	var _buttons: Array[Button] = []
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		z_index = UI.Z_MODAL
		var veil := ColorRect.new()
		veil.color = Color("0e0d10",0.55)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(veil)
		var safe := G.ui_safe_rect(self)
		var width := minf(432,safe.size.x-32)
		var inner := width-40
		var body_height := 0.0
		for words in lines:
			var pixels := G.font_reg.get_string_size(String(words),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
			body_height += maxf(26,ceili(pixels/inner)*22)+6
		var height := minf(560,112+body_height+choices.size()*52)
		var tray := UI.Tray.new()
		tray.position = Vector2(safe.get_center().x-width*0.5,safe.get_center().y-height*0.5)
		tray.size = Vector2(width,height)
		add_child(tray)
		var title := UI.label(heading,"section")
		title.position = Vector2(20,16)
		title.size = Vector2(inner,28)
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tray.add_child(title)
		var scroll := ScrollContainer.new()
		scroll.name = "BodyScroll"
		scroll.position = Vector2(20,52)
		var available := height-112-choices.size()*52
		scroll.size = Vector2(inner,available)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		tray.add_child(scroll)
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = inner
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation",6)
		scroll.add_child(column)
		for words in lines:
			var l := UI.label(String(words),"body")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_child(l)
		var y := 60+available
		for i in choices.size():
			var b := UI.action(String(choices[i]),"secondary")
			b.position = Vector2(20,y)
			b.size = Vector2(inner,44)
			b.pressed.connect(func(): selected.emit(i))
			tray.add_child(b)
			_buttons.append(b)
			y += 52
		var close := UI.action("关闭","quiet")
		close.position = Vector2(20,height-48)
		close.size = Vector2(inner,44)
		close.pressed.connect(func(): closed.emit())
		tray.add_child(close)
		_buttons.append(close)
		for i in _buttons.size():
			_buttons[i].focus_next = _buttons[(i+1)%_buttons.size()].get_path()
			_buttons[i].focus_previous = _buttons[posmod(i-1,_buttons.size())].get_path()
			_buttons[i].focus_neighbor_bottom = _buttons[(i+1)%_buttons.size()].get_path()
			_buttons[i].focus_neighbor_top = _buttons[posmod(i-1,_buttons.size())].get_path()
			_buttons[i].focus_neighbor_left = _buttons[i].get_path()
			_buttons[i].focus_neighbor_right = _buttons[i].get_path()
		close.grab_focus()
	func _unhandled_input(e: InputEvent) -> void:
		if not G.ui_blocked and e.is_action_pressed("ui_cancel"):
			closed.emit()
			get_viewport().set_input_as_handled()
