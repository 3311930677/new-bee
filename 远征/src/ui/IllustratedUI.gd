class_name IllustratedUI
extends RefCounted
## Original painted assets remain separate from native text, input and focus handling.
const ROOT := "res://image/ui/designer_20261007/"
static var _textures: Dictionary = {}

static func texture(key: String) -> Texture2D:
	if _textures.has(key): return _textures[key]
	var source := load(ROOT+key+".png") as Texture2D
	if source == null: return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	var visible_bounds := {"charter_menu":Rect2(63,2,893,1521),"folio_window":Rect2(37,48,949,1424),"silk_action":Rect2(40,182,1999,378)}
	atlas.region = visible_bounds.get(key,Rect2(source.get_image().get_used_rect()))
	_textures[key] = atlas
	return atlas

static func draw(canvas: CanvasItem, key: String, bounds: Rect2, tint := Color.WHITE) -> void:
	var tex := texture(key)
	if tex != null: canvas.draw_texture_rect(tex,bounds,false,tint)

static func folio(canvas: CanvasItem, bounds: Rect2) -> void:
	var tex := texture("folio_window")
	if tex == null: return
	# Only the quiet paper body stretches vertically; fittings and header keep their proportions.
	var dims := Vector2(tex.get_size())
	var scale := bounds.size.x/dims.x
	var top := dims.y*.20
	var bottom := dims.y*.065
	var head_h := top*scale
	var foot_h := bottom*scale
	canvas.draw_texture_rect_region(tex,Rect2(bounds.position,Vector2(bounds.size.x,head_h)),Rect2(0,0,dims.x,top))
	canvas.draw_texture_rect_region(tex,Rect2(bounds.position+Vector2(0,head_h),Vector2(bounds.size.x,bounds.size.y-head_h-foot_h)),
		Rect2(0,top,dims.x,dims.y-top-bottom))
	canvas.draw_texture_rect_region(tex,Rect2(bounds.position+Vector2(0,bounds.size.y-foot_h),Vector2(bounds.size.x,foot_h)),
		Rect2(0,dims.y-bottom,dims.x,bottom))

static func silk(canvas: CanvasItem, bounds: Rect2, active := false) -> void:
	var tex := texture("silk_action")
	if tex == null: return
	var dims := Vector2(tex.get_size())
	var edge := dims.x*.16
	var target_edge := minf(bounds.size.x*.25,edge*bounds.size.y/dims.y)
	var tint := Color(1.04,1.04,1.02) if active else Color.WHITE
	canvas.draw_texture_rect_region(tex,Rect2(bounds.position,Vector2(target_edge,bounds.size.y)),Rect2(0,0,edge,dims.y),tint)
	canvas.draw_texture_rect_region(tex,Rect2(bounds.position+Vector2(target_edge,0),Vector2(bounds.size.x-2*target_edge,bounds.size.y)),Rect2(edge,0,dims.x-2*edge,dims.y),tint)
	canvas.draw_texture_rect_region(tex,Rect2(bounds.position+Vector2(bounds.size.x-target_edge,0),Vector2(target_edge,bounds.size.y)),Rect2(dims.x-edge,0,edge,dims.y),tint)

static func tab_row(deck: Control, names: Array, width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(width,40)
	row.add_theme_constant_override("separation",8)
	var buttons: Array[Button] = []
	for i in names.size():
		var index := i
		var button := Button.new()
		button.text = String(names[i])
		button.custom_minimum_size = Vector2((width-16)/3,40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font",G.font_serif)
		button.add_theme_font_size_override("font_size",17)
		for state in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		button.pressed.connect(func(): deck.call("go",index); Audio.sfx("ui_click"))
		row.add_child(button)
		buttons.append(button)
	var refresh := func(selected: int):
		for i in buttons.size():
			var style := StyleBoxFlat.new()
			style.bg_color = Color("2d5148",.94) if i==selected else Color("e6dac0",.3)
			style.border_color = Color("b99762")
			style.border_width_bottom = 3 if i==selected else 1
			for state in ["normal","hover","pressed"]: buttons[i].add_theme_stylebox_override(state,style)
			for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
				buttons[i].add_theme_color_override(state,Color("f3dfad") if i==selected else Color("776644"))
	deck.connect("page_changed",refresh)
	refresh.call(int(deck.get("current")))
	return row

class Folio extends PanelContainer:
	func _draw() -> void:
		IllustratedUI.folio(self,Rect2(Vector2.ZERO,size))
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var style := StyleBoxEmpty.new()
		style.content_margin_left = 56
		style.content_margin_right = 28
		style.content_margin_top = 20
		style.content_margin_bottom = 20
		add_theme_stylebox_override("panel",style)

class Charter extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	func _draw() -> void:
		IllustratedUI.draw(self,"charter_menu",Rect2(Vector2.ZERO,size))

class SilkButton extends Button:
	var caption: Label
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]: add_theme_color_override(state,Color.TRANSPARENT)
		icon = null
		caption = Label.new()
		caption.text = text
		caption.add_theme_font_override("font",G.font_art)
		caption.add_theme_font_size_override("font_size",24)
		caption.add_theme_color_override("font_color",Color("f1dfb5"))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(caption)
		resized.connect(_place)
		for event in [mouse_entered,mouse_exited,button_down,button_up,focus_entered,focus_exited]: event.connect(queue_redraw)
		gui_input.connect(func(_event: InputEvent): queue_redraw())
		_place()
	func _place() -> void:
		if caption != null:
			caption.position = Vector2(32,0)
			caption.size = size-Vector2(64,0)
	func _draw() -> void:
		IllustratedUI.silk(self,Rect2(Vector2(0,2 if is_pressed() else 0),size),is_hovered() or has_focus())
		if caption != null: caption.position.y = 2 if is_pressed() else 0
		if has_focus(): draw_line(Vector2(40,size.y-12),Vector2(size.x-40,size.y-12),Color("e8cf94"),1)
