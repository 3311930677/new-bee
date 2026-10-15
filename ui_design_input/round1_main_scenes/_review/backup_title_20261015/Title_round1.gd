extends Control
const ChestUI := preload("res://src/ui/TravelChestUI.gd")
const Lacquer := preload("res://src/ui/LacquerUI.gd")
const Kit := preload("res://src/ui/PixelKit.gd")
const MENU := ["开始游戏", "继续冒险", "设置"]
const MENU_ICONS := ["expedition", "book", "settings"]
const LINKS := ["公告", "制作组", "版本信息"]
const LINK_ICONS := ["spark", "person", "help"]
const BG_SIZE := Vector2(841, 1870)  # title_bg.png 原图尺寸
const BRAND_SIZE := Vector2(320, 138)  # title_logo.png 1654×713 等比
var _btns: Array[Control] = []
var _links: Array[Control] = []
var _focus := 0
var _intro_panel: Control = null
var _settings: SettingsPanel = null
var _brand: Control
var _street: TextureRect
var _shade: TextureRect
var _subtitle: Label
var _subtitle_group: Control
var _footer: Control
var _separators: Array[ColorRect] = []

func _ready() -> void:
	Audio.play_bgm("bgm_title")
	theme = Lacquer.theme()
	var sky := ColorRect.new()
	sky.color = Color("2a2433")
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	# 2026-10-14 标题背景：黄昏边城远眺（细颗粒插画，线性过滤）。整张按 480 宽显示，
	# 长屏显示全图，480×800 从第 140px 起取，Logo 始终落在晚霞天空里。
	_street = TextureRect.new()
	_street.texture = load("res://assets/ui/title_20261014/title_bg.png")
	_street.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_street.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_street.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_street.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_street)
	# 底部压暗：盖住中路水洼高光，保证按钮和次级入口文字清楚。
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color("0a090b", 0.0), Color("0a090b", 0.42), Color("0a090b", 0.78)])
	var shade_tex := GradientTexture2D.new()
	shade_tex.gradient = grad
	shade_tex.width = 4
	shade_tex.height = 256
	shade_tex.fill_to = Vector2(0, 1)
	_shade = TextureRect.new()
	_shade.texture = shade_tex
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var motes := _AmbientMotes.new()
	motes.name = "AmbientMotes"
	motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(motes)
	_brand = _TravelWordmark.new()
	_brand.name = "ExpeditionWordmark"
	_brand.size = BRAND_SIZE
	add_child(_brand)
	_subtitle_group = Control.new()
	_subtitle_group.size = Vector2(260,28)
	_subtitle_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle_group)
	_subtitle = Lacquer.label("点击开始旅程",16,Color("e6cf9c"),true)
	var subtitle_font := FontVariation.new()
	subtitle_font.base_font = G.font_serif
	subtitle_font.spacing_glyph = 4
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
	# 2026-10-15 按参考稿：三个竖排主按钮（左侧图标），首个朱漆，其余铁铜。
	for i in MENU.size():
		var idx := i
		var b := Kit.PixelButton.new(MENU[i], "crimson" if i == 0 else "iron", 20 if i == 0 else 18)
		b.kit = "hero" if i == 0 else "btn"
		if i == 0:
			b.shine = true
			b.trim = Color("c9963f")
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = load("res://assets/ui/pixel_icons/%s.png" % MENU_ICONS[i])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.caption.add_child(icon)  # 挂在文字上：跟随按钮的悬停上浮 / 按下下沉
		b.name = ["StartGame", "ContinueGame", "Settings"][i]
		b.pressed.connect(_activate.bind(idx))
		b.focus_entered.connect(func(): _focus = idx)
		add_child(b)
		_btns.append(b)
	# 继续冒险：本机存档里已有角色才可用。
	_btns[1].disabled = not G.has_profile()
	if _btns[1].disabled: _btns[1].focus_mode = Control.FOCUS_NONE
	_footer = _FooterRule.new()
	_footer.name = "FooterRule"
	add_child(_footer)
	for i in LINKS.size():
		var link := _FooterLink.new(LINKS[i], LINK_ICONS[i])
		link.name = ["Notice", "Credits", "Version"][i]
		link.pressed.connect(_open_link.bind(i))
		add_child(link)
		_links.append(link)
	get_viewport().size_changed.connect(_layout_page)
	_layout_page()
	_update_focus(0, false)
	# 入场：标识自上落下、副标题随后、按钮自下逐个推入。
	Kit.enter(_brand, 0.0, Vector2(0, -18))
	Kit.enter(_subtitle_group, 0.14, Vector2(0, -10))
	for i in _btns.size(): Kit.enter(_btns[i], 0.28 + i * 0.07)
	for link in _links: Kit.enter(link, 0.5, Vector2(0, 10))
	_pulse_hint()

func _layout_page(safe_override: Rect2 = Rect2()) -> void:
	var view := get_viewport_rect()
	var safe := safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var bg_h := maxf(480.0 * BG_SIZE.y / BG_SIZE.x, view.size.y)
	var bg_w := bg_h * BG_SIZE.x / BG_SIZE.y
	# 800 高时上移 140，长屏逐步回到 0；更高的屏幕等比放大铺满。
	var top := -clampf((1067.0 - view.size.y) * 140.0 / 267.0, 0.0, 140.0)
	_street.position = Vector2((view.size.x - bg_w) * .5, top)
	_street.size = Vector2(bg_w, bg_h)
	_shade.position = Vector2(0, view.size.y - 380)
	_shade.size = Vector2(view.size.x, 380)
	var brand_y := 24 + 0.17 * maxf(0, safe.size.y - 800)
	_brand.position = Vector2(safe.get_center().x - BRAND_SIZE.x * .5, safe.position.y + brand_y)
	_subtitle_group.position = Vector2(safe.get_center().x-130,safe.position.y+brand_y+BRAND_SIZE.y+2)
	# 菜单落在底部石阶暗区：主角和路牌在按钮上方完整露出（参考稿三键约在 73% / 79% / 86% 高度）。
	var cx := safe.get_center().x
	var sizes := [Vector2(280, 60), Vector2(256, 52), Vector2(256, 52)]
	var tops := [safe.end.y - 266, safe.end.y - 198, safe.end.y - 138]
	for i in _btns.size():
		_btns[i].size = sizes[i]
		_btns[i].position = Vector2(cx - sizes[i].x * .5, tops[i])
		var icon := _btns[i].caption.get_node("Icon") as TextureRect
		icon.size = Vector2(32, 32)
		icon.position = Vector2(sizes[i].x * .5 - 84, (sizes[i].y - 32) * .5)
	# 底部：左侧公告，右侧制作组 / 版本信息，最底一条罗盘细线。
	var link_y := safe.end.y - 80
	_links[0].position = Vector2(safe.position.x + 14, link_y)
	_links[1].position = Vector2(safe.end.x - 14 - 2 * _FooterLink.W - 10, link_y)
	_links[2].position = Vector2(safe.end.x - 14 - _FooterLink.W, link_y)
	_footer.position = Vector2(safe.position.x, safe.end.y - 14)
	_footer.size = Vector2(safe.size.x, 12)
	# 焦点：主按钮上下循环（跳过不可用的继续冒险），最后一个向下进入底部入口。
	var live: Array[Control] = []
	for b in _btns:
		if b.focus_mode != Control.FOCUS_NONE: live.append(b)
	for i in live.size():
		live[i].focus_neighbor_top = live[i - 1].get_path() if i > 0 else _links[0].get_path()
		live[i].focus_neighbor_bottom = live[i + 1].get_path() if i < live.size() - 1 else _links[0].get_path()
		live[i].focus_neighbor_left = live[i].get_path()
		live[i].focus_neighbor_right = live[i].get_path()
	for i in _links.size():
		_links[i].focus_neighbor_top = live.back().get_path()
		_links[i].focus_neighbor_bottom = live[0].get_path()
		_links[i].focus_neighbor_left = _links[(i + 2) % 3].get_path()
		_links[i].focus_neighbor_right = _links[(i + 1) % 3].get_path()

## 引导语呼吸闪烁。
func _pulse_hint() -> void:
	if G.get_meta("ui_review_mode", false) or DisplayServer.get_name() == "headless": return
	var tw := _subtitle.create_tween().set_loops()
	tw.tween_property(_subtitle, "modulate:a", 0.45, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_subtitle, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)

func _update_focus(idx: int, _sfx: bool) -> void:
	if idx < 0 or idx >= _btns.size(): return
	_focus = idx
	_btns[idx].grab_focus()

func _busy() -> bool:
	return G.ui_blocked or _settings != null or _intro_panel != null or G.modal_count() > 0

func _activate(idx: int) -> void:
	if _busy(): return
	match idx:
		0: G.go("res://src/ui/Login.tscn")
		1: _continue_game()
		2: _open_settings()

## 继续冒险：沿用登录后的分流（序章没看完先看序章），跳过账号输入。
func _continue_game() -> void:
	if not G.has_profile(): return
	if not G.lore_seen():
		G.go("res://src/ui/Prologue.tscn")
	else:
		G.enter_main_world()

func _open_link(idx: int) -> void:
	if _busy(): return
	Audio.sfx("ui_open")
	match idx:
		0: G.show_choice_popup(_links[0], "旅途公告", [
				"欢迎来到昭元大陆。当前为测试版本，存档保存在本机。",
				"首次游玩建议先看「游戏介绍」，了解远征、市集与养成的基本玩法。"],
				[{"text": "游戏介绍", "cb": _show_intro}, {"text": "知道了", "cb": func(): pass}], self)
		1: G.show_info_popup(_links[1], "制作组", [
				"远征 · 昭元行旅录",
				"引擎：Godot Engine（MIT 许可）",
				"字体：Noto Serif CJK、马善政楷书、站酷小薇、站酷庆科黄油体（SIL OFL 1.1）"], self)
		2: G.show_info_popup(_links[2], "版本信息", [
				"版本：%s" % String(ProjectSettings.get_setting("application/config/version", "0.2.0")),
				"引擎：Godot %s" % String(Engine.get_version_info().get("string", ""))], self)

## 退出：参考稿没有退出键，改为返回键 / Esc 弹确认。
func _confirm_quit() -> void:
	G.show_choice_popup(self, "退出游戏", ["确定要离开远征吗？进度已保存在本机。"],
		[{"text": "退出", "cb": func(): get_tree().quit()}, {"text": "再看看", "cb": func(): pass}], self)

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
		_update_focus(0, false))
	add_child(_intro_panel)

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked or _settings != null: return
	if not event.is_action_pressed("ui_cancel"): return
	if _intro_panel != null:
		_intro_panel.queue_free()
		_intro_panel = null
		_update_focus(0, false)
		get_viewport().set_input_as_handled()
	elif G.modal_count() == 0:
		_confirm_quit()
		get_viewport().set_input_as_handled()

class _TravelWordmark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var image := TextureRect.new()
		image.texture = load("res://assets/ui/title_20261014/title_logo.png")
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)

## 底部小入口：暗色圆座 + 像素图标 + 下方小字。
class _FooterLink extends Button:
	const W := 52.0
	var _icon_tex: Texture2D
	var _hover := false
	func _init(words: String, icon_id: String) -> void:
		_icon_tex = load("res://assets/ui/pixel_icons/%s.png" % icon_id)
		size = Vector2(W, 60)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var l := preload("res://src/ui/PixelKit.gd").label(words, 12, Color("d9c69c"), 1)
		l.position = Vector2(-12, 44)
		l.size = Vector2(W + 24, 16)
		add_child(l)
	func _ready() -> void:
		for s in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())
		for e in [button_down, button_up, focus_entered, focus_exited]: e.connect(queue_redraw)
	func _draw() -> void:
		var c := Vector2(W * .5, 21)
		draw_circle(c, 20, Color("0d0b0a", .82))
		var ring := Color("ffe08a") if _hover or has_focus() else Color("a8834a")
		draw_arc(c, 19, 0, TAU, 40, ring, 1.5, true)
		var sink := 1.0 if is_pressed() else 0.0
		draw_texture(_icon_tex, (c - Vector2(16, 16) + Vector2(0, sink)).floor())

## 底部装饰线：两段向外渐隐的金线，中间一枚菱形罗盘点。
class _FooterRule extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var y := 6.0
		var mid := size.x * .5
		var gold := Color("c9a25e")
		var steps := 24
		for side in [-1.0, 1.0]:
			for k in steps:
				var a := 0.55 * (1.0 - float(k) / steps)
				var x0: float = mid + side * (10 + k * (mid - 24) / steps)
				var x1: float = mid + side * (10 + (k + 1) * (mid - 24) / steps)
				draw_line(Vector2(x0, y), Vector2(x1, y), Color(gold, a), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(mid, y - 6), Vector2(mid + 4, y), Vector2(mid, y + 6), Vector2(mid - 4, y)]), gold)
		draw_colored_polygon(PackedVector2Array([Vector2(mid, y - 3), Vector2(mid + 2, y), Vector2(mid, y + 3), Vector2(mid - 2, y)]), Color("fff1c8"))

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

