extends RefCounted
## B1 shared visual system. Factories do not change game rules or global popup behavior.
const ROOT := "res://assets/ui/travel_chest_b1/"
const NIGHT := Color("120e0c")
const FACE := Color("1a1412")
const SELECTED := Color("2a201a")
const BRONZE := Color("8a6d38")
const COPPER := Color("c9a45c")
const PAPER := Color("f3e3c0")
const AGED := Color("8f8376")
const GOLD := Color("f2c76a")
const RED := Color("e2402c")
const JADE := Color("55d8a8")
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
const FONT_SIZES := {"title":22,"section":17,"object":20,"body":15,"caption":15,"tag":15,"number":15,"primary":22,"hero":26,"secondary":17}
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
	for kit_id in ["hero_normal", "hero_pressed", "hero_disabled", "btn_normal", "btn_pressed", "btn_disabled", "tab_active", "tab_idle", "back_diamond", "panel_iron", "card_paper", "nav_base", "top_bar", "bottom_bar", "drawer_sheet", "slot_rare", "slot_legend", "slot_common", "slot_empty", "slot_selected", "btn_row", "plaque_title", "bar_frame", "bar_fill_exp", "bar_fill_hp", "currency_capsule", "sortie_medal", "quest_slip", "button_red", "button_dark", "card_frame_parchment", "building_tag", "rail_socket", "rail_socket_selected", "nav_socket", "nav_socket_selected", "plaque_small"]:
		preload("res://src/ui/UiKit.gd").style(kit_id)
		G.Visuals._kit_tex(kit_id + ".png")
	for role_idle in ["res://image/role/zs/pojun_idle.png", "res://image/role/ck/chuanyang_idle.png", "res://image/role/fs/shuangyu_idle.png", "res://image/role/fz/chenxing_idle.png", "res://assets/ui/home/home_bg_tall.png", "res://assets/ui/home/fire_s.png", "res://assets/ui/home/fire_xs.png", "res://assets/ui/home/avatar_frame.png", "res://assets/ui/home/level_badge.png", "res://assets/ui/illustrated_icons_20261007/swords.png"]:
		if ResourceLoader.exists(role_idle):
			G.visual_texture(role_idle)
	_theme.default_font = G.font_reg
	_theme.default_font_size = G.FS_XS
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
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var points := cut(rect,amount)
	canvas.draw_colored_polygon(points,color)
	if rect.size.x >= 36.0 and rect.size.y >= 24.0:
		var is_large := rect.size.x >= 200.0 and rect.size.y >= 90.0
		var tex := G.Visuals._kit_tex("panel_iron.png" if is_large else "btn_row.png")
		G.Visuals.nine_slice(canvas, tex, rect, 12.0 if is_large else 8.0, 10.0 if is_large else 6.0, Color(1, 1, 1, 0.42 if is_large else 0.30))
	points.append(points[0])
	canvas.draw_polyline(points,border,1,true)
	if rect.size.x >= 44.0 and rect.size.y >= 26.0:
		var p := rect.position
		var e := rect.end
		canvas.draw_line(Vector2(p.x + amount + 2, p.y + 1), Vector2(e.x - amount - 2, p.y + 1), Color(border.lightened(0.25), 0.32), 1.0)
		for corner in [p + Vector2(3, 3), Vector2(e.x - 5, p.y + 3), Vector2(p.x + 3, e.y - 5), e - Vector2(5, 5)]:
			canvas.draw_rect(Rect2(corner, Vector2(2, 2)), Color(border.lightened(0.18), 0.72))

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

static func format_number(amount: int, compact: bool = true) -> String:
	if not compact:
		return str(amount)
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
	## 换皮用：有值时用这块九宫格替换默认底板（设置页的像素素材），为空时画法不变
	var plate: StyleBox
	var plate_selected: StyleBox
	## 换皮用：文字区左缩进（左侧放图标时用），默认 0 时文字铺满按钮居中
	var caption_inset := 0.0
	var _state_material: ShaderMaterial
	var _fit_text := ""
	var _fit_font: Font
	var _fit_base_size := 0
	var _fit_measured := 0.0
	func _init(words: String = "", family: String = "secondary", icon: String = "") -> void:
		text = words
		clip_text = true
		skin = family
		icon_id = icon
		caption = UI.label(words,"hero" if family=="hero" else ("primary" if family=="primary" else ("caption" if family=="nav" else ("tag" if family=="rail" else "secondary"))))
		caption.name = "Caption"
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(caption)
		subtitle = UI.label("","body" if family=="hero" else "caption",UI.AGED)
		subtitle.name = "Subtitle"
		subtitle.clip_text = true
		subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
		if not G.get_meta("ui_review_mode", false) and DisplayServer.get_name() != "headless":
			button_down.connect(func():
				pivot_offset = size * 0.5
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(0.96, 0.96), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				preload("res://src/ui/HapticFeedback.gd").light()
			)
			button_up.connect(func():
				pivot_offset = size * 0.5
				var tw := create_tween()
				tw.tween_property(self, "scale", Vector2(1.03, 1.03), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(self, "scale", Vector2.ONE, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			)
		resized.connect(_layout)
		_layout()
	func _layout() -> void:
		var offset := 1.0 if is_pressed() else 0.0
		# Labels paint the button; the hidden native caption must not impose a width.
		if not caption.has_meta("fit_font_size"):
			caption.set_meta("fit_font_size",caption.get_theme_font_size("font_size"))
		var base_size := int(caption.get_meta("fit_font_size"))
		var available := maxf(16,size.x-caption_inset-(88 if skin=="hero" else 12))
		var font := caption.get_theme_font("font")
		if _fit_font!=font or _fit_text!=caption.text or _fit_base_size!=base_size:
			_fit_font=font
			_fit_text=caption.text
			_fit_base_size=base_size
			_fit_measured=font.get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,base_size).x
		var fitted_size:=maxi(12,mini(base_size,floori(base_size*available/maxf(1,_fit_measured))))
		if caption.get_theme_font_size("font_size")!=fitted_size:
			caption.add_theme_font_size_override("font_size",fitted_size)
		if skin == "hero":
			caption.position = Vector2(64,4+offset)
			caption.size = Vector2(size.x-88,40)
			caption.add_theme_color_override("font_color",UI.ASH if disabled else Color("f6d9a0"))
			subtitle.position = Vector2(64,44+offset)
			subtitle.size = Vector2(size.x-88,22)
		elif skin == "nav":
			# 图标 + 文字作为一组在按钮内垂直居中（图标 40、间距 4、文字 22）。
			caption.position = Vector2(0,(size.y-66)*0.5+44+offset)
			caption.size = Vector2(size.x,22)
		elif skin == "rail":
			caption.position = Vector2(0,size.y-24+offset)
			caption.size = Vector2(size.x,22)
		elif not subtitle.text.is_empty():
			caption.position=Vector2(0,offset)
			caption.size=Vector2(size.x,32)
			subtitle.position=Vector2(8,32+offset)
			subtitle.size=Vector2(size.x-16,22)
		else:
			caption.position = Vector2(caption_inset,offset)
			caption.size = Vector2(size.x-caption_inset,size.y)
	func _draw() -> void:
		_layout()
		if _state_material != null: _state_material.set_shader_parameter("gray",1.0 if disabled else 0.0)
		var primary := skin in ["primary","hero"]
		var bg := UI.SELECTED if selected else UI.FACE
		if plate != null:
			draw_style_box(plate_selected if selected and plate_selected != null else plate,Rect2(Vector2.ZERO,size))
			if is_pressed() or disabled: draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,.22 if is_pressed() else .38))
		elif primary:
			var state := "disabled" if disabled else ("pressed" if is_pressed() else "normal")
			var kit_sb := preload("res://src/ui/UiKit.gd").style("hero_" + state, 0)
			if kit_sb != null:
				draw_style_box(kit_sb, Rect2(Vector2.ZERO, size))
			else:
				UI.surface(self, Rect2(Vector2.ZERO, size), Color("6e1a12") if is_pressed() else Color("9e2b25"), UI.COPPER, 4)
		elif skin == "tab":
			var tab_sb := preload("res://src/ui/UiKit.gd").style("tab_active" if selected else "tab_idle", 0)
			if tab_sb != null:
				draw_style_box(tab_sb, Rect2(Vector2.ZERO, size))
			else:
				draw_line(Vector2(8,size.y-1),Vector2(size.x-8,size.y-1),UI.BRONZE,1)
				if selected:
					draw_rect(Rect2(Vector2.ZERO,size),Color("2a201a",.82))
					G.Visuals.nine_slice(self, G.Visuals._kit_tex("button_dark.png"), Rect2(Vector2.ZERO, size), 8.0, 6.0, Color(1, 1, 1, 0.35))
		elif skin not in ["quiet","back","nav","currency"]:
			var sec_state := "disabled" if disabled else ("pressed" if is_pressed() else "normal")
			var sec_sb := preload("res://src/ui/UiKit.gd").style("btn_" + sec_state, 0) if skin == "secondary" else null
			if sec_sb != null:
				draw_style_box(sec_sb, Rect2(Vector2.ZERO, size))
			else:
				UI.surface(self,Rect2(Vector2.ZERO,size),UI.NIGHT if skin=="rail" else bg,UI.COPPER if (is_hovered() or selected) else UI.BRONZE)
		elif is_pressed(): UI.surface(self,Rect2(Vector2.ZERO,size),UI.FACE)
		if skin == "tab" and selected and plate == null:
			draw_rect(Rect2(8,size.y-2,size.x-16,2),UI.COPPER)
			G.Visuals.diamond(self, Vector2(size.x * 0.5, size.y - 2.0), 2.5, UI.GOLD)
		if skin == "back":
			caption.visible = false
			var back_sb := preload("res://src/ui/UiKit.gd").style("back_diamond", 0)
			if back_sb != null:
				draw_style_box(back_sb, Rect2(Vector2.ZERO, size))
			else:
				UI.surface(self,Rect2(Vector2.ZERO,size),Color("120e0c",0.92),UI.COPPER if (is_hovered() or has_focus()) else UI.BRONZE,4.0)
				var p := size*.5
				draw_polyline(PackedVector2Array([p+Vector2(4,-7),p+Vector2(-4,0),p+Vector2(4,7)]),UI.PAPER,2.0,true)
		if skin == "currency": draw_line(Vector2(4,size.y-1),Vector2(size.x-4,size.y-1),Color("3a2c1c"),1)
		if not icon_id.is_empty():
			var icon := UI.texture(icon_id)
			if icon != null:
				var px := 40.0 if skin in ["hero","nav"] else (28.0 if skin=="rail" else icon_px)
				var icon_y := (size.y-66)*0.5 if skin=="nav" else (6.0 if skin=="rail" else (size.y-px)*0.5)
				var p := Vector2(12,16) if skin=="hero" else Vector2((size.x-px)*0.5,icon_y)
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
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_rect(Rect2(Vector2.ZERO,size),Color("120e0c",0.96))
		if size.x >= 80 and size.y >= 60:
			var iron_tex := G.Visuals._kit_tex("panel_iron.png")
			G.Visuals.nine_slice(self, iron_tex, Rect2(Vector2.ZERO, size), 16.0, 16.0, Color(1, 1, 1, 0.58))
			draw_rect(Rect2(4, 4, size.x - 8, size.y - 8), Color(UI.COPPER, 0.25), false, 1.0)
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
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT  # 数字紧跟图标，四枚货币间距一致
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
		goal = UI.label("","caption",Color("ede4d4"))
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goal.max_lines_visible = 2
		goal.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		goal.clip_text = true
		add_child(goal)
	func _layout() -> void:
		caption.text = "委托可交付" if claimable else "主线目标"
		caption.theme_type_variation = "Chest_tag"
		caption.add_theme_color_override("font_color",UI.JADE if claimable else Color("e5c07b"))
		caption.position = Vector2(16,4)
		caption.size = Vector2(size.x-36,22)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		goal.position = Vector2(16,28)
		goal.size = Vector2(size.x-36,36)
	func _draw() -> void:
		var bg_color := Color("2a201a", 0.94) if is_pressed() else (Color("221a16", 0.92) if is_hovered() else Color("1a1412", 0.90))
		var border_color := UI.GOLD if is_hovered() else (UI.JADE if claimable else Color("c9a45c"))
		UI.surface(self, Rect2(Vector2.ZERO, size), bg_color, border_color, 2.0)
		# 左侧立柱铜纹与状态彩条
		draw_rect(Rect2(0, 3, 4, size.y - 6), UI.JADE if claimable else Color("c29a5b"))
		# 右侧轻质展开箭头
		var arrow_x := size.x - 14.0
		var arrow_y := size.y * 0.5
		var chevron_color := UI.GOLD if is_hovered() else Color("7a664e")
		draw_polyline(PackedVector2Array([Vector2(arrow_x - 3, arrow_y - 5), Vector2(arrow_x + 2, arrow_y), Vector2(arrow_x - 3, arrow_y + 5)]), chevron_color, 1.5, true)
		_layout()
		if has_focus(): draw_rect(Rect2(Vector2.ONE*-2,size+Vector2.ONE*4),UI.GOLD,false,2)

class Toast extends Control:
	const UI = preload("res://src/ui/TravelChestUI.gd")
	var words := ""
	var kind := "info"
	func _ready() -> void:
		z_index = UI.Z_FEEDBACK
		var safe:=G.ui_safe_rect(self)
		size = Vector2(minf(360,safe.size.x-24),44)
		position = Vector2(safe.get_center().x-size.x*.5,safe.position.y+safe.size.y/3)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var l := UI.label(words,"body")
		l.position = Vector2(12,4)
		l.size = Vector2(size.x-24,36)
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
	const Reading = preload("res://src/ui/ReadingSkin.gd")
	var heading := ""
	var lines: Array = []
	var choices: Array = []
	var _buttons: Array[Button] = []
	var _frame: PanelContainer
	var _column: VBoxContainer
	var _scroll: ScrollContainer
	var _reading: VBoxContainer
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		set_meta("safe_layout_exempt",true)
		mouse_filter = Control.MOUSE_FILTER_STOP
		z_index = 60
		var veil := ColorRect.new()
		veil.color = Color("0e0d10",.72)
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(veil)
		_frame = Reading.frame(false,G.Visuals.title_family(heading))
		_frame.name = "ReadingDialog"
		add_child(_frame)
		_column = VBoxContainer.new()
		_column.add_theme_constant_override("separation",14)
		_frame.add_child(_column)
		var title := Reading.label(heading,24,Reading.TEXT)
		_column.add_child(title)
		_scroll = ScrollContainer.new()
		_scroll.name = "BodyScroll"
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.follow_focus = true
		_column.add_child(_scroll)
		_reading = VBoxContainer.new()
		_reading.add_theme_constant_override("separation",14)
		_reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.add_child(_reading)
		for words in lines: _reading.add_child(Reading.label(String(words),22,Reading.TEXT))
		for i in choices.size():
			var button := Reading.button(String(choices[i]))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(func(): Audio.sfx("ui_confirm"); selected.emit(i))
			_reading.add_child(button)
			_buttons.append(button)
		var close := Reading.button("关闭",true)
		close.pressed.connect(func(): Audio.sfx("ui_close"); closed.emit())
		_column.add_child(close)
		_buttons.append(close)
		for i in _buttons.size():
			_buttons[i].focus_next = _buttons[(i+1)%_buttons.size()].get_path()
			_buttons[i].focus_previous = _buttons[posmod(i-1,_buttons.size())].get_path()
			_buttons[i].focus_neighbor_bottom = _buttons[i].focus_next
			_buttons[i].focus_neighbor_top = _buttons[i].focus_previous
		get_viewport().size_changed.connect(layout)
		preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
		layout()
		close.grab_focus.call_deferred()
	func layout() -> void:
		if _frame == null: return
		var safe := G.ui_safe_rect(self)
		var width := minf(440,safe.size.x-24)
		var body_height := 0.0
		for words in lines:
			var pixels := G.font_reg.get_string_size(String(words),HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
			body_height += maxf(34,ceili(pixels/maxf(120,width-60))*34)+14
		var height := minf(safe.size.y-24,maxf(260,180+body_height+choices.size()*74))
		_frame.size = Vector2(width,height)
		_frame.position = (safe.get_center()-_frame.size*.5).round()
		_reading.custom_minimum_size.x = width-58
	func _unhandled_input(event: InputEvent) -> void:
		if not G.ui_blocked and event.is_action_pressed("ui_cancel"):
			closed.emit()
			get_viewport().set_input_as_handled()
