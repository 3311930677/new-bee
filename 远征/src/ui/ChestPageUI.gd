extends RefCounted
## Shared B2 page furniture. The owning panel retains every game operation.
const UI := preload("res://src/ui/TravelChestUI.gd")
const ROOT := "res://assets/ui/travel_chest_b2/"
static var _textures: Dictionary = {}
static var _regions: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if _textures.has(id): return _textures[id]
	if _regions.is_empty(): _regions = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"regions.json"))
	if not _regions.has(id): return null
	var data: Dictionary = _regions[id]
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ROOT+String(data.file))
	var scaling := atlas.atlas.get_size()/Vector2(data.source_size[0],data.source_size[1])
	atlas.region = Rect2(Vector2(data.rect[0],data.rect[1])*scaling,Vector2(data.rect[2],data.rect[3])*scaling)
	_textures[id] = atlas
	return atlas

static func place(node: Control, pos: Vector2, extent: Vector2) -> void:
	node.position = pos
	node.size = extent

static func picture(tex: Texture2D, extent: Vector2) -> TextureRect:
	var p := TextureRect.new()
	p.texture = tex
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.custom_minimum_size = extent
	p.size = extent
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if tex!=null and tex.get_meta("pixel_art",false) else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return p

static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	s.follow_focus = true
	return s

static func line(words: String, role: String = "body", color: Color = UI.PAPER) -> Label:
	var l := UI.label(words,role,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func affix_label(a: Dictionary) -> String:
	var id:=String(a.get("stat",""))
	var names: Dictionary={"atk_pct":"攻击","def_pct":"防御","maxhp_pct":"生命","crit_add":"暴击","spd_pct":"速度"}
	return "%s +%.1f%%" % [String(names.get(id,id)),float(a.get("v",0))*100] if not id.is_empty() else "空词条"

static func confirm(parent: Node, title: String, words: String, callback: Callable) -> Control:
	var d := UI.Modal.new()
	d.heading = title
	d.lines = [words]
	d.choices = ["取消","确认"]
	d.z_index = UI.Z_MODAL
	d.closed.connect(d.queue_free)
	d.selected.connect(func(index: int):
		d.queue_free()
		if index==1: callback.call())
	parent.add_child(d)
	if not d._buttons.is_empty():d._buttons[0].grab_focus()
	return d

class Stage extends Control:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	var background: TextureRect
	var sky: TextureRect
	var shade: ColorRect
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		background = TextureRect.new()
		background.texture = load("res://image/background/art_v2/camp_bluehour.png")
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(background)
		sky = TextureRect.new()
		sky.texture = load(UI.ROOT+"camp_sky.png")
		sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; uniform sampler2D original:filter_nearest; uniform float extra=0.0; uniform float height=307.0; void fragment(){float y=UV.y*height; vec4 s=texture(TEXTURE,vec2(UV.x,UV.y*0.30)); vec4 b=texture(original,vec2(UV.x,clamp((y-extra)/800.0,0.0,1.0))); COLOR=mix(s,b,smoothstep(extra-40.0,extra+40.0,y));}"
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("original",background.texture)
		sky.material = mat
		add_child(sky)
		shade = ColorRect.new()
		shade.color = Color("17141a",.42)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		resized.connect(layout)
		layout()
	func layout() -> void:
		if background==null: return
		var extra := maxf(0,size.y-800)
		background.position = Vector2(0,extra)
		background.size = Vector2(size.x,800)
		sky.visible = extra>0
		sky.size = Vector2(size.x,extra+40)
		(sky.material as ShaderMaterial).set_shader_parameter("extra",extra)
		(sky.material as ShaderMaterial).set_shader_parameter("height",sky.size.y)
		shade.size = size

class ItemCell extends Button:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	const Page = preload("res://src/ui/ChestPageUI.gd")
	var selected := false
	var rarity := Color("77705f")
	var item_image: TextureRect
	var heading: Label
	var amount: Label
	var flag: Label
	var rarity_rank:=1
	var show_name:=false
	var image_px:=60.0
	var locked:=false
	var worn:=false
	var fresh:=false
	func _init() -> void:
		custom_minimum_size = Vector2(84,84)
		item_image = Page.picture(null,Vector2(40,40))
		add_child(item_image)
		heading = UI.label("","tag")
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.clip_text = true
		add_child(heading)
		amount = UI.label("","tag",UI.AGED)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(amount)
		flag = UI.label("","tag",UI.COPPER)
		add_child(flag)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _ready() -> void:
		for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for event in [resized,mouse_entered,mouse_exited,focus_entered,focus_exited]: event.connect(queue_redraw)
	func _draw() -> void:
		UI.surface(self,Rect2(Vector2.ZERO,size),UI.SELECTED if selected else Color("17141a",.92),UI.GOLD if selected or has_focus() else UI.BRONZE)
		if rarity_rank>1:
			for radius in [34,28,20]:draw_circle(size*.5,radius,Color(rarity,.045))
			draw_colored_polygon(PackedVector2Array([Vector2(2,2),Vector2(14,2),Vector2(2,14)]),rarity)
			if rarity_rank==5:draw_rect(Rect2(5,5,2,2),UI.PAPER)
		if selected:draw_rect(Rect2(1,1,size.x-2,size.y-2),UI.GOLD,false,2)
		if fresh:draw_circle(Vector2(size.x-7,7),3,UI.GOLD)
		var px:=minf(image_px,minf(size.x,size.y)-16)
		item_image.size=Vector2(px,px)
		item_image.custom_minimum_size=Vector2(px,px)
		item_image.position=(size-Vector2(px,px))*.5
		if item_image.texture!=null and item_image.texture.get_meta("pixel_art",false):item_image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		heading.visible=show_name
		heading.position = Vector2(4,size.y-30)
		heading.size = Vector2(size.x-8,22)
		amount.position = Vector2(4,0)
		amount.size = Vector2(size.x-10,20)
		flag.position = Vector2(6,0)
		flag.size = Vector2(30,20)
		flag.text="装" if worn else ""
		flag.position=Vector2(5,size.y-24)
		if locked:
			var p:=Vector2(size.x-17,size.y-15)
			draw_rect(Rect2(p,Vector2(10,8)),UI.AGED)
			draw_arc(p+Vector2(5,0),3,PI,TAU,12,UI.AGED,2)

class GemSocket extends Button:
	const UI=preload("res://src/ui/TravelChestUI.gd")
	var item_image:TextureRect
	func _init(tex:Texture2D=null) -> void:
		custom_minimum_size=Vector2(44,44)
		item_image=preload("res://src/ui/ChestPageUI.gd").picture(tex,Vector2(24,24))
		item_image.position=Vector2(10,10);add_child(item_image)
	func _ready() -> void:
		for s in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(s,StyleBoxEmpty.new())
		for e in [resized,focus_entered,focus_exited,mouse_entered,mouse_exited]:e.connect(queue_redraw)
	func _draw() -> void:
		draw_circle(size*.5,14,UI.NIGHT)
		draw_arc(size*.5,14,0,TAU,40,UI.COPPER if has_focus() else UI.BRONZE,2,true)

class GrowthRow extends Button:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	const Page = preload("res://src/ui/ChestPageUI.gd")
	var image: TextureRect
	var heading: Label
	var status: Label
	var next_action: Label
	var actionable := false
	func _init(words: String, id: String) -> void:
		text = words
		custom_minimum_size = Vector2(0,52)
		image = Page.picture(Page.texture(id),Vector2(40,40))
		add_child(image)
		heading = UI.label(words,"section")
		add_child(heading)
		status = UI.label("","caption",UI.AGED)
		add_child(status)
		next_action = UI.label("","tag",UI.GOLD)
		next_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(next_action)
	func _ready() -> void:
		for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		for property in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]: add_theme_color_override(property,Color.TRANSPARENT)
		for event in [resized,mouse_entered,mouse_exited,focus_entered,focus_exited]: event.connect(queue_redraw)
	func _draw() -> void:
		UI.surface(self,Rect2(Vector2.ZERO,size),UI.SELECTED if is_hovered() else UI.FACE,UI.COPPER if has_focus() else Color("3a3037"))
		if actionable: draw_rect(Rect2(0,5,2,size.y-10),UI.GOLD)
		image.position = Vector2(12,6)
		heading.position = Vector2(64,0)
		heading.size = Vector2(210,27)
		if get_meta("recommendation",false):heading.size=Vector2(size.x-88,44)
		status.position = Vector2(64,27)
		status.size = Vector2(210,22)
		next_action.position = Vector2(size.x-154,8)
		next_action.size = Vector2(120,36)
		if actionable and not next_action.text.is_empty():
			UI.surface(self,Rect2(size.x-138,14,112,24),UI.NIGHT,UI.BRONZE)
		next_action.add_theme_color_override("font_color",UI.GOLD if actionable else UI.AGED)
		draw_polyline(PackedVector2Array([Vector2(size.x-20,21),Vector2(size.x-15,26),Vector2(size.x-20,31)]),UI.COPPER if actionable else UI.AGED,2)
