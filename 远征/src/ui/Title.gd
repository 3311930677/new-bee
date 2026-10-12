extends Control
const ChestUI := preload("res://src/ui/TravelChestUI.gd")
const Lacquer := preload("res://src/ui/LacquerUI.gd")
const Kit := preload("res://src/ui/PixelKit.gd")
const MENU := ["开始游戏", "游戏介绍", "游戏设置", "退出游戏"]
var _btns: Array[Control] = []
var _focus := 0
var _intro_panel: Control = null
var _settings: SettingsPanel = null
var _brand: Control
var _street: TextureRect
var _shade: TextureRect
var _sky_extension:TextureRect
var _subtitle: Label
var _subtitle_group: Control
var _separators: Array[ColorRect] = []

func _ready() -> void:
	Audio.play_bgm("bgm_title")
	theme = Lacquer.theme()
	var sky := ColorRect.new()
	sky.color = Color("2a2433")
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	_street = TextureRect.new()
	_street.texture = load("res://image/background/courtyard_visual_v2.png")
	_street.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_street.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_street.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_street.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_street)
	var sky_source:=load("res://assets/ui/review_fixes_20261009/sky_outpaint.png") as Texture2D
	_sky_extension=TextureRect.new()
	_sky_extension.texture=sky_source
	_sky_extension.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_sky_extension.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform sampler2D original : filter_nearest;
uniform float extra_height = 267.0;
uniform float layer_height = 300.0;
uniform float sky_fraction = 0.2885;
void fragment() {
 float y = UV.y * layer_height;
 vec4 sky = texture(TEXTURE, vec2(UV.x,UV.y*sky_fraction));
 vec4 base = texture(original, vec2(UV.x, clamp((y-extra_height)/800.0,0.0,1.0)));
 float merge = smoothstep(extra_height-40.0,extra_height+33.0,y);
 COLOR = mix(sky,base,merge);
}"""
	var sky_material:=ShaderMaterial.new()
	sky_material.shader=shader
	sky_material.set_shader_parameter("original",_street.texture)
	sky_material.set_shader_parameter("sky_fraction",sky_source.get_width()*300.0/480.0/sky_source.get_height())
	_sky_extension.material=sky_material
	_sky_extension.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_sky_extension)
	_shade = Lacquer.scrim(Vector2(480, 280), true)
	add_child(_shade)
	var motes := _AmbientMotes.new()
	motes.name = "AmbientMotes"
	motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(motes)
	_brand = _TravelWordmark.new()
	_brand.name = "ExpeditionWordmark"
	_brand.size = Vector2(280,120)
	add_child(_brand)
	_subtitle_group = Control.new()
	_subtitle_group.size = Vector2(260,28)
	_subtitle_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle_group)
	_subtitle = Lacquer.label("昭元行旅录",18,Color("d9be8a"),true)
	var subtitle_font := FontVariation.new()
	subtitle_font.base_font = G.font_serif
	subtitle_font.spacing_glyph = 6
	_subtitle.add_theme_font_override("font",subtitle_font)
	_subtitle.position = Vector2(56,0)
	_subtitle.size = Vector2(148,28)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_group.add_child(_subtitle)
	for x in [0,212]:
		var line := ColorRect.new()
		line.color = Lacquer.LIT
		line.position = Vector2(x,14)
		line.size = Vector2(48,1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_subtitle_group.add_child(line)
	# 主按钮：朱漆铁框 + 周期扫光 + 点击火星；次级菜单：铁铜像素按钮。全部按 2px 网格绘制。
	for i in MENU.size():
		var idx := i
		var b: Button
		if i == 0:
			var hero := Kit.PixelButton.new(MENU[i], "crimson", 24)
			hero.shine = true
			hero.kit = "hero"
			hero.trim = Color("c9963f")
			b = hero
		else:
			b = Kit.PixelButton.new(MENU[i], "iron", 16)
			(b as Kit.PixelButton).kit = "btn"
			if i == 3: (b as Kit.PixelButton).caption.add_theme_color_override("font_color", Color("a89c88"))
		b.name = ["StartGame", "Introduction", "Settings", "Quit"][i]
		b.pressed.connect(_activate.bind(idx))
		b.focus_entered.connect(func(): _focus = idx)
		add_child(b)
		_btns.append(b)
	get_viewport().size_changed.connect(_layout_page)
	_layout_page()
	_update_focus(0, false)
	# 入场：标识自上落下、副标题随后、按钮自下逐个推入。
	Kit.enter(_brand, 0.0, Vector2(0, -18))
	Kit.enter(_subtitle_group, 0.14, Vector2(0, -10))
	for i in _btns.size(): Kit.enter(_btns[i], 0.28 + i * 0.07)

func _layout_page(safe_override: Rect2 = Rect2()) -> void:
	var view := get_viewport_rect()
	var safe := safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	_street.position=Vector2((view.size.x-480)*.5,view.size.y-800)
	_street.size=Vector2(480,800)
	_sky_extension.visible=view.size.y>800
	_sky_extension.size=Vector2(view.size.x,maxf(1,view.size.y-800+33))
	(_sky_extension.material as ShaderMaterial).set_shader_parameter("extra_height",maxf(0,view.size.y-800))
	(_sky_extension.material as ShaderMaterial).set_shader_parameter("layer_height",_sky_extension.size.y)
	_shade.position = Vector2(0, view.size.y - 280)
	_shade.size.x = view.size.x
	var brand_y := 72 + 0.4 * maxf(0, safe.size.y - 800)
	_brand.position = Vector2(safe.get_center().x - 140, safe.position.y + brand_y)
	_subtitle_group.position = Vector2(safe.get_center().x-130,safe.position.y+brand_y+128)
	# 菜单上提并放大：画面中段不再是一大片空街面，主按钮落在视线自然停留处。
	_btns[0].size = Vector2(304, 72)
	_btns[0].position = Vector2(safe.get_center().x - 152, safe.end.y - 304)
	# 次级按钮宽 112：两端铆钉角块（各 16px）不被挤压。
	for i in range(1, 4):
		_btns[i].size = Vector2(112, 48)
		_btns[i].position = Vector2(safe.get_center().x - 176 + (i - 1) * 120, safe.end.y - 212)
	for i in _btns.size():
		_btns[i].focus_neighbor_top = _btns[0].get_path() if i > 0 else _btns[1].get_path()
		_btns[i].focus_neighbor_bottom = _btns[1].get_path() if i == 0 else _btns[0].get_path()
		if i > 0:
			_btns[i].focus_neighbor_left = _btns[3 if i == 1 else i - 1].get_path()
			_btns[i].focus_neighbor_right = _btns[1 if i == 3 else i + 1].get_path()

func _update_focus(idx: int, _sfx: bool) -> void:
	if idx < 0 or idx >= _btns.size(): return
	_focus = idx
	_btns[idx].grab_focus()

func _activate(idx: int) -> void:
	if G.ui_blocked or _settings != null or _intro_panel != null: return
	match idx:
		0: G.go("res://src/ui/Login.tscn")
		1: _show_intro()
		2: _open_settings()
		3: get_tree().quit()

func _open_settings() -> void:
	if _settings != null: return
	Audio.sfx("ui_open")
	_settings = SettingsPanel.new()
	_settings.standalone = true
	_settings.closed.connect(func():
		_settings.queue_free()
		_settings = null
		_update_focus(2, false))
	add_child(_settings)

func _show_intro() -> void:
	if _intro_panel != null: return
	_intro_panel = (load("res://src/ui/IntroductionPanel.gd") as GDScript).new()
	_intro_panel.connect("closed", func():
		_intro_panel.queue_free()
		_intro_panel = null
		_update_focus(1, false))
	add_child(_intro_panel)

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked or _settings != null: return
	if _intro_panel != null and event.is_action_pressed("ui_cancel"):
		_intro_panel.queue_free()
		_intro_panel = null
		_update_focus(1, false)
		get_viewport().set_input_as_handled()

class _TravelWordmark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var source := load("res://assets/ui/review_fixes_20261009/wordmark_body.png") as Texture2D
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(source.get_image().get_used_rect())
		for shadow in [true,false]:
			var image := TextureRect.new()
			image.texture = atlas
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			image.position = Vector2(2,2) if shadow else Vector2.ZERO
			image.size = Vector2(280,120)
			image.modulate = Color(0.04,0.035,0.043,0.85) if shadow else Color(0.87,0.83,0.80)
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(image)

class _AmbientMotes extends Control:
	var _particles: Array = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 22:
			_particles.append({
				"pos": Vector2(randf_range(20.0, 460.0), randf_range(60.0, 780.0)),
				"vel": Vector2(randf_range(-4.0, 4.0), randf_range(-10.0, -22.0)),
				"r": randf_range(1.2, 2.5),
				"a": randf_range(0.25, 0.75),
				"phase": randf_range(0.0, TAU)
			})
	func _process(delta: float) -> void:
		for p in _particles:
			p.pos += p.vel * delta
			p.phase += delta * 1.8
			if p.pos.y < 30.0:
				p.pos.y = 780.0
				p.pos.x = randf_range(20.0, 460.0)
		queue_redraw()
	func _draw() -> void:
		# 火星按 2px 像素方块绘制，与画面像素颗粒一致（不用平滑圆点）。
		for p in _particles:
			var alpha: float = p.a * (0.6 + 0.4 * sin(p.phase))
			var at: Vector2 = (p.pos / 2.0).floor() * 2.0
			var big: bool = p.r > 1.9
			draw_rect(Rect2(at, Vector2(4, 4) if big else Vector2(2, 2)), Color(0.98, 0.86, 0.56, alpha))
			if big: draw_rect(Rect2(at + Vector2(1, 1), Vector2(2, 2)), Color(1, .97, .86, alpha))

