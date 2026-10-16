# TownHome.gd —— 主城首页（月下山城）
# 场景层：背景 + 火盆动画 + 主角待机，随屏高整体下移（多出高度 3/4 给夜空）。
# 交互层 content：建筑名牌、顶栏（头像/四币/背包/小聚）、任务条、导航、出征徽章。
# 正式版由 GameHome 挂载（host = GameHome），入口直接调用 GameHome 原有的 _open_* 面板；
# 不设 host 时为独立预览，只发 entry_pressed 并提示“预览版”。
# 与 CampChestView 保持同一组对外成员：host / content / _hero / refresh() / layout()。
extends Control

signal entry_pressed(id: String)

const UI := preload("res://src/ui/TravelChestUI.gd")
const DIR := "res://assets/ui/home/"
const KIT := "res://assets/ui/kit_20261013/"
const UiKitLib := preload("res://src/ui/UiKit.gd")
const PIX := "res://assets/ui/pixel_icons/"
const FONT_SERIF := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")
const FONT_BOLD := preload("res://assets/fonts/NotoSansSC-Bold.otf")
const FONT_ART := preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const MAP_SCENE := "res://src/explore/MapScene.tscn"

const VIEW_W := 480.0
const HD := 2.0               # assets/ui/home 贴图是游戏尺寸的 2 倍（高清插画，线性过滤显示）
const SMOOTH := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
const CORE_H := 720.0          # home_bg.png（月下山城 2:3 原图等比缩到 480 宽）的核心画面高度
const BG_TOP_EXT := 200.0      # home_bg_tall.png 顶部补出的夜空（底部同高的广场）
const CORE_Y_800 := 40.0       # 480×800 时核心画面下移量：城门广场正好落在任务条上方

const CREAM := Color("f3e3c0")
const GOLD := Color("f2c76a")
const OUTLINE := Color("1b110b")
const INK := Color("3b2a1a")
const INK_MUTED := Color("6e5638")
const SKY := Color("03266c")          # home_bg_tall 顶行的夜空色（见 manifest.background_source.sky_color）
const HOLE_DARK := Color(0.09, 0.06, 0.08, 0.88)
const PLATE_DARK := Color("2a1410")
const BRONZE := Color("c9973f")
const LOCKED_TINT := Color(0.55, 0.55, 0.6)

# id、名牌文字、图标、名牌中心（核心画面坐标，游戏像素）
# 酒馆 = 召唤（魂石抽伙伴），铁匠铺 = 养成·装备，集市 = 荣誉兑换，世界 = 世界图志
const PLAQUES := [
	["gacha", "酒馆", "tavern", Vector2(130, 150)],
	["arena", "竞技场", "arena", Vector2(352, 150)],
	["craft", "铁匠铺", "anvil", Vector2(108, 268)],
	["exchange", "集市", "market", Vector2(372, 284)],
	["world", "世界", "gate", Vector2(240, 350)],   # 阶梯中段，不压城楼屋顶
]
# 火焰尺寸、火焰底部中心（核心画面坐标），与背景里画好的火盆对位
const FIRES := [
	["s", Vector2(152, 530)], ["s", Vector2(328, 530)],
	["xs", Vector2(198, 528)], ["xs", Vector2(282, 528)],
	["xs", Vector2(167, 444)], ["xs", Vector2(314, 444)],
]
const HERO_FEET := Vector2(240, 556)
# id、文字、图标（伙伴 = 伙伴图鉴）
const NAV_LEFT := [["growth", "养成", "hero"], ["party", "伙伴", "party"]]
const NAV_RIGHT := [["activity", "活动", "banner"], ["settings", "设置", "settings"]]
# 顶栏右侧小入口：id、文字、像素图标
const RAIL := [["bag", "背包", "bag"], ["gathering", "小聚", "food"]]
# 钱包：键、名称、图标
const CURRENCIES := [
	["gold", "金币", "coin"], ["expedition", "远征币", "expedition"],
	["soul", "魂晶", "soul"], ["honor", "荣誉", "honor"],
]
const CAP_W := 86.0

var host: Control = null
var content: Control              # 所有可点内容；打开面板时 GameHome 只隐藏它，背景保留
var _hero: TextureButton          # 出征徽章 = 返回主世界（节点名 ReturnToWorld）
var _scene: Control
var _bg: TextureRect
var _hero_sprite: AnimatedSprite2D
var _top: Control
var _hud_bottom: Control
var _toast: Label
var _name: Label
var _level: Label
var _exp_fill: TextureRect
var _avatar: Button
var _avatar_pic: TextureRect
var _quest: Button
var _quest_title: Label
var _quest_goal: Label
var _quest_dot: Control
var _plaques := {}                # id -> Button
var _plaque_dots := {}            # id -> 红点
var _rail := {}                   # id -> TextureButton
var _gathering_unlocked := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_scene()
	content = Control.new()
	content.name = "TownContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	_build_plaques()
	_build_top_bar()
	_build_bottom()
	_toast = _label("", FONT_SERIF, 16, CREAM, 4)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(VIEW_W, 28)
	_toast.modulate.a = 0.0
	add_child(_toast)
	get_viewport().size_changed.connect(layout)
	layout()


# ---------- 布局 ----------
func layout(safe_override: Rect2 = Rect2()) -> void:
	var vh := get_viewport_rect().size.y
	var safe := safe_override if safe_override.has_area() else _safe_rect()
	# 高屏多出的高度约 3/4 给上方夜空、1/4 给下方广场，城门不至于离任务条太远
	# （取偶数，保持 2 倍像素对齐；超出 home_bg_tall 顶部的部分由 SKY 色块补齐）
	var extra: float = max(vh - 800.0, 0.0)
	var core_y: float = CORE_Y_800 + floor(extra * 0.75 / 2.0) * 2.0
	_scene.position = Vector2(0, core_y)
	for id in _plaques:
		var b: Button = _plaques[id]
		b.position = (Vector2(b.get_meta("center")) + Vector2(0, core_y) - b.size * 0.5).round()
	_top.position = Vector2(0, safe.position.y)
	_hud_bottom.position = Vector2(0, safe.end.y - 200.0)
	_toast.position = Vector2(0, vh * 0.42)
	refresh()


func _safe_rect() -> Rect2:
	if host != null:
		return G.ui_safe_rect(self)
	return get_viewport_rect()


# ---------- 数据刷新（GameHome 关闭面板后会调用） ----------
func refresh() -> void:
	if _name == null:
		return
	var full := _player_name()
	_name.text = full.left(8) + "…" if full.length() > 8 else full
	_name.tooltip_text = full
	var level := _level_value()
	_level.text = str(level)
	_exp_fill.size.x = floor((144 - 16) * _exp_ratio() / 2.0) * 2.0
	if host != null:
		_avatar_pic.texture = G.avatar_texture()
		for entry in host._wallet_labels:
			var value := int(G.wallet.get(entry.key, 0))
			entry.label.text = UI.format_number(value)
			entry.button.tooltip_text = "%s：%d" % [entry.name, value]
		var row: Dictionary = G.story_current()
		_quest_title.text = "主线 · " + String(row.get("title", "归路")) if not row.is_empty() else "主线"
		_quest_goal.text = String(row.get("goal", G.story_goal_short()))
		_quest_dot.visible = host._quest_claimable()
		_plaque_dots["gacha"].visible = host._entry_has_badge("召唤")
		_plaque_dots["exchange"].visible = host._entry_has_badge("兑换")
		_gathering_unlocked = G.side_status_of("a4_rel_nighttable") == QuestService.SIDE_DONE
	var gather: TextureButton = _rail["gathering"]
	gather.modulate = Color.WHITE if _gathering_unlocked or host == null else LOCKED_TINT
	gather.tooltip_text = "归路小聚" if _gathering_unlocked else "完成归路小聚支线后开放"
	var gather_tag := gather.get_node_or_null("GatheringUnlockTag") as Label
	if gather_tag != null:
		gather_tag.text = "归路小聚" if _gathering_unlocked else ""
	_hero.tooltip_text = "出征 · 返回主世界"


# ---------- 场景层 ----------
func _build_scene() -> void:
	_scene = Control.new()
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene)
	# 夜空延伸：home_bg_tall 顶部是均匀的深蓝，超高屏时用同色块接上
	var sky := ColorRect.new()
	sky.color = SKY
	sky.position = Vector2(0, -BG_TOP_EXT - 400.0)
	sky.size = Vector2(VIEW_W, 402.0)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(sky)
	_bg = TextureRect.new()
	_bg.texture = load(DIR + "home_bg_tall.png")
	_bg.texture_filter = SMOOTH
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.size = _bg.texture.get_size() / HD
	_bg.position = Vector2(0, -BG_TOP_EXT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_bg)

	for f in FIRES:
		var fire := _strip_sprite(DIR + "fire_%s.png" % f[0], 6, 9.0)
		fire.frame = randi() % 6
		var fh: float = fire.sprite_frames.get_frame_texture(&"loop", 0).get_height() / HD
		fire.position = Vector2(f[1].x, f[1].y - fh * 0.5)
		_scene.add_child(fire)

	_hero_sprite = _strip_sprite(DIR + "hero_town_idle.png", 4, 5.0)
	_hero_sprite.position = Vector2(HERO_FEET.x, HERO_FEET.y - 32.0)
	_scene.add_child(_hero_sprite)
	if host != null:
		host._anim = _hero_sprite


func _build_plaques() -> void:
	for p in PLAQUES:
		var b := _plaque(p[0], p[1], p[2])
		b.set_meta("center", p[3])
		content.add_child(b)
		# 进树后图标才按 icon_max_width 缩到 32，这里按最终最小宽度重新定尺寸
		b.size = Vector2(b.get_combined_minimum_size().x, 44)
		_plaques[p[0]] = b
		var dot := _red_dot(Vector2(b.size.x - 10, -2))
		dot.visible = false
		b.add_child(dot)
		_plaque_dots[p[0]] = dot


func _strip_sprite(path: String, count: int, fps: float) -> AnimatedSprite2D:
	var tex: Texture2D = load(path)
	var fw := tex.get_width() / count
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"loop")
	frames.set_animation_speed(&"loop", fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, tex.get_height())
		frames.add_frame(&"loop", at)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.scale = Vector2.ONE / HD
	spr.texture_filter = SMOOTH
	spr.play(&"loop")
	return spr


func _plaque(id: String, text: String, icon: String) -> Button:
	var b := Button.new()
	b.name = "Plaque_" + id
	b.text = text
	b.icon = load(DIR + "icons/%s_32.png" % icon)
	b.texture_filter = SMOOTH
	b.add_theme_constant_override("icon_max_width", 32)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT_SERIF)
	b.add_theme_font_size_override("font_size", G.FS_XS)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_constant_override("h_separation", 8)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, CREAM)
	b.add_theme_color_override("font_outline_color", OUTLINE)
	# v3 建筑名牌：图标落在左端圆章里，文字排在圆章右侧；牌子 40 高，热区仍是 44。
	for st in [["normal", Color(1, 1, 1)], ["hover", Color(1.18, 1.12, 1.05)], ["pressed", Color(0.78, 0.74, 0.7)]]:
		var sb := _kit_slice("building_tag", st[1])
		sb.content_margin_left = 4
		sb.content_margin_right = 18
		sb.expand_margin_top = -2
		sb.expand_margin_bottom = -2
		b.add_theme_stylebox_override(st[0], sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.size = Vector2(0, 44)
	b.reset_size()
	b.size.y = 44
	b.pressed.connect(_on_entry.bind(id, text))
	return b


## 素材包九宫格：边距读 ui_kit_spec.json，换素材版本时不用改这里。
func _kit_slice(id: String, tint: Color) -> StyleBoxTexture:
	var sl: Array = UiKitLib.spec(id).get("slice", [0, 0, 0, 0])
	var sb := _slice(KIT + id + ".png", int(sl[0]), int(sl[1]), tint)
	sb.texture_margin_right = int(sl[2])
	sb.texture_margin_bottom = int(sl[3])
	return sb


func _slice(path: String, h: int, v: int, tint: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = h
	sb.texture_margin_right = h
	sb.texture_margin_top = v
	sb.texture_margin_bottom = v
	sb.content_margin_left = 12
	sb.content_margin_right = 18
	sb.modulate_color = tint
	return sb


# ---------- 顶栏 ----------
func _build_top_bar() -> void:
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.03, 0.08, 0.72))
	grad.set_color(1, Color(0.03, 0.03, 0.08, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(VIEW_W, 128)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(shade)

	_top = Control.new()
	_top.name = "TopBar"
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_top)

	# 头像：深底 + 当前头像（AvatarPanel 可换）+ 金框 + 等级徽章
	_avatar = Button.new()
	_avatar.name = "AvatarEntry"
	_avatar.flat = true
	_avatar.focus_mode = Control.FOCUS_NONE
	_avatar.tooltip_text = "更换头像"
	_avatar.position = Vector2(8, 8)
	_avatar.size = Vector2(80, 80)
	_avatar.pressed.connect(_on_entry.bind("avatar", "头像"))
	_top.add_child(_avatar)
	var under := ColorRect.new()
	under.color = Color("2a2036")
	under.position = Vector2(12, 12)
	under.size = Vector2(56, 56)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar.add_child(under)
	_avatar_pic = _tex(DIR + "avatar_portrait.png", Vector2(12, 12))
	_avatar_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar_pic.size = Vector2(56, 56)
	_avatar_pic.clip_contents = true
	_avatar.add_child(_avatar_pic)
	_avatar.add_child(_tex(DIR + "avatar_frame.png", Vector2.ZERO))
	var badge := _tex(DIR + "level_badge.png", Vector2(24, 64))
	_avatar.add_child(badge)
	_level = _label("", FONT_BOLD, G.FS_XS, CREAM, 3)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.position = Vector2(0, -2)
	_level.size = Vector2(32, 22)
	badge.add_child(_level)
	if host != null:
		host._avatar_frame = _avatar
		host._avatar_pic = _avatar_pic

	# 名字 + 经验条
	_name = _label("", FONT_SERIF, G.FS_SM, CREAM, 4)
	_name.position = Vector2(96, 50)
	_name.size = Vector2(150, 24)
	_name.clip_text = true
	_top.add_child(_name)
	var bar := NinePatchRect.new()
	bar.texture = load(KIT + "bar_frame.png")
	bar.patch_margin_left = 10
	bar.patch_margin_right = 10
	bar.position = Vector2(96, 76)
	bar.size = Vector2(144, 20)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(bar)
	_exp_fill = TextureRect.new()
	_exp_fill.texture = load(KIT + "bar_fill_exp.png")
	_exp_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_exp_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_exp_fill.position = Vector2(8, 6)
	_exp_fill.size = Vector2(0, 8)
	_exp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_exp_fill)

	# 四币胶囊：点开“行囊与货币”说明
	var row := HBoxContainer.new()
	row.name = "CurrencyRow"
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(VIEW_W - 12.0 - 4 * CAP_W - 3 * 4.0, 6)
	row.size = Vector2(4 * CAP_W + 12, 44)
	_top.add_child(row)
	if host != null:
		host._wallet_row = row
	for c in CURRENCIES:
		# 热区 44 高（触控下限），胶囊图仍按原尺寸 36 高画在中间
		var cap := Button.new()
		cap.name = "Currency_" + c[0]
		cap.focus_mode = Control.FOCUS_NONE
		cap.custom_minimum_size = Vector2(CAP_W, 44)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			cap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		cap.pressed.connect(_on_entry.bind("wallet", "行囊与货币"))
		row.add_child(cap)
		var skin := NinePatchRect.new()
		skin.texture = load(KIT + "currency_capsule.png")
		var cap_sl: Array = UiKitLib.spec("currency_capsule").get("slice", [10, 0, 10, 0])
		skin.patch_margin_left = int(cap_sl[0])
		skin.patch_margin_right = int(cap_sl[2])
		skin.position = Vector2(0, 4)
		skin.size = Vector2(CAP_W, 36)
		skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_child(skin)
		cap.mouse_entered.connect(func(): skin.modulate = Color(1.15, 1.1, 1.05))
		cap.mouse_exited.connect(func(): skin.modulate = Color.WHITE)
		skin.add_child(_tex(PIX + "%s.png" % c[2], Vector2(1, 2)))
		var num := _label(_fmt(int(_wallet().get(c[0], 0))), FONT_BOLD, G.FS_XS, CREAM, 3)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.position = Vector2(30, 6)
		num.size = Vector2(CAP_W - 38, 22)
		num.clip_text = true
		skin.add_child(num)
		if host != null:
			host._wallet_labels.append({"label": num, "key": c[0], "name": c[1], "button": cap})

	# 小入口：背包、小聚（未解锁时压灰）
	var rx := VIEW_W - 8.0 - RAIL.size() * 56.0 - (RAIL.size() - 1) * 4.0
	for r in RAIL:
		var rid := String(r[0])
		var rtitle := String(r[1])
		var btn := TextureButton.new()
		btn.name = "Rail_" + rid
		btn.texture_normal = load(KIT + "rail_socket.png")
		btn.texture_hover = load(KIT + "rail_socket_selected.png")
		btn.texture_pressed = load(KIT + "rail_socket_selected.png")
		btn.focus_mode = Control.FOCUS_NONE
		btn.position = Vector2(rx, 52)
		btn.pressed.connect(_on_entry.bind(rid, rtitle))
		btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_on_entry(rid, rtitle))
		_top.add_child(btn)
		btn.add_child(_disc(Vector2(10, 10), 36, HOLE_DARK))
		btn.add_child(_tex(PIX + "%s.png" % r[2], Vector2(12, 12)))
		var plate := _plate(Vector2(8, 42), Vector2(40, 22))
		btn.add_child(plate)
		var t := _label(rtitle, FONT_SERIF, G.FS_XS, CREAM, 3)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.position = Vector2(0, -1)
		t.size = plate.size
		plate.add_child(t)
		if rid == "gathering":
			var unlock_tag := Label.new()
			unlock_tag.name = "GatheringUnlockTag"
			unlock_tag.visible = false
			unlock_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(unlock_tag)
		_rail[rid] = btn
		rx += 60.0


# ---------- 底部：任务条 + 导航 + 出征 ----------
func _build_bottom() -> void:
	_hud_bottom = Control.new()
	_hud_bottom.name = "BottomHud"
	_hud_bottom.size = Vector2(VIEW_W, 200)
	_hud_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_hud_bottom)

	# 主线任务条：压暗羊皮纸，不抢出征按钮
	_quest = Button.new()
	_quest.name = "QuestSummary"
	_quest.focus_mode = Control.FOCUS_NONE
	var qs := _kit_slice("quest_slip", Color(0.8, 0.74, 0.66))
	qs.content_margin_left = 0
	qs.content_margin_right = 0
	_quest.add_theme_stylebox_override("normal", qs)
	var qh := qs.duplicate()
	qh.modulate_color = Color(0.9, 0.84, 0.75)
	_quest.add_theme_stylebox_override("hover", qh)
	_quest.add_theme_stylebox_override("pressed", qs)
	_quest.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_quest.position = Vector2(84, 16)
	_quest.size = Vector2(312, 56)
	_quest.pressed.connect(_on_entry.bind("quest", "主线任务"))
	_hud_bottom.add_child(_quest)
	_quest.add_child(_tex(DIR + "icons/quest_32.png", Vector2(14, 12)))
	_quest_title = _label("主线 · 夜叩边城", FONT_SERIF, G.FS_XS, INK, 0)
	_quest_title.position = Vector2(52, 6)
	_quest_title.size = Vector2(226, 22)
	_quest_title.clip_text = true
	_quest.add_child(_quest_title)
	_quest_goal = _label("与城门守将交谈  1/3", FONT_BOLD, G.FS_XS, INK_MUTED, 0)
	_quest_goal.position = Vector2(52, 27)
	_quest_goal.size = Vector2(226, 22)
	_quest_goal.clip_text = true
	_quest_goal.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_quest.add_child(_quest_goal)
	var arrow := _label("›", FONT_BOLD, 26, INK, 0)
	arrow.position = Vector2(282, 6)
	_quest.add_child(arrow)
	_quest_dot = _red_dot(Vector2(300, -2))
	_quest_dot.visible = false
	_quest.add_child(_quest_dot)

	# 导航底座与四个页签
	var base := TextureRect.new()
	base.texture = load(KIT + "nav_base.png")
	base.position = Vector2(0, 112)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_bottom.add_child(base)
	var xs := [12.0, 92.0]
	for i in 2:
		_hud_bottom.add_child(_nav_button(NAV_LEFT[i], Vector2(xs[i], 116)))
		_hud_bottom.add_child(_nav_button(NAV_RIGHT[i], Vector2(308.0 + i * 80.0, 116)))

	# 出征光晕：圆章背后缓慢呼吸的暖光，标明这是主城的主操作。
	var glow := TextureRect.new()
	glow.name = "SortieGlow"
	var gg := Gradient.new()
	gg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gg.colors = PackedColorArray([Color(1.0, 0.62, 0.26, 0.55), Color(1.0, 0.46, 0.18, 0.2), Color(1.0, 0.4, 0.15, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gg
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.texture_filter = SMOOTH
	glow.texture = gt
	glow.size = Vector2(160, 160)
	glow.position = Vector2(240 - 80, 137 - 80)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	_hud_bottom.add_child(glow)
	if not G.get_meta("ui_review_mode", false):
		var tw := glow.create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.45, 1.4).set_trans(Tween.TRANS_SINE)
		tw.tween_property(glow, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)

	# 出征徽章：压在底座上沿；点击返回主世界（原“继续旅程”）
	_hero = TextureButton.new()
	_hero.name = "ReturnToWorld"
	# v3 出征圆章（112×112）：按下、禁用两态由同一张圆章压暗、去色得到，外轮廓完全一致。
	var medal: Texture2D = load(KIT + "sortie_medal.png")
	_hero.texture_normal = medal
	_hero.texture_pressed = _medal_variant(medal, false)
	_hero.texture_disabled = _medal_variant(medal, true)
	_hero.focus_mode = Control.FOCUS_NONE
	_hero.position = Vector2(184, 81)   # 中心 (240, 137)，与旧徽章一致
	# 双剑用手绘插画（原来是 32px 像素图标放大两倍，边缘发糊、颜色发灰）。
	var swords := TextureRect.new()
	swords.name = "SortieSwords"
	swords.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swords.texture_filter = SMOOTH
	swords.texture = load("res://assets/ui/illustrated_icons_20261007/swords.png")
	swords.size = Vector2(68, 68)
	swords.position = Vector2(22, 12)
	swords.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(swords)
	_hero.button_down.connect(func(): swords.modulate = Color(0.75, 0.72, 0.7))
	_hero.button_up.connect(func(): swords.modulate = Color.WHITE)
	_hero.pressed.connect(_on_entry.bind("expedition", "出征"))
	_hud_bottom.add_child(_hero)
	# 字样放在徽章下沿的素材包牌匾上（乌木底 + 红宝石铆钉），代替代码画的纯色方块
	var ep := Panel.new()
	ep.name = "SortiePlate"
	ep.add_theme_stylebox_override("panel", _kit_slice("plaque_small", Color.WHITE))
	ep.position = Vector2(0, 78)
	ep.size = Vector2(112, 40)
	ep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.add_child(ep)
	var et := _label("出征", FONT_ART, 24, GOLD, 4)
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	et.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	et.position = Vector2(0, -2)
	et.size = ep.size
	ep.add_child(et)


## 图标按亮度改成暗铜到奶油金，与圆章的金红色板一致（原图是蓝钢色）。
func _gilded(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	var dark := Color("4a2c16")
	var lit := Color("f6e2b4")
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0: continue
			var t := clampf(c.get_luminance() * 1.25, 0.0, 1.0)
			var g := dark.lerp(lit, t)
			img.set_pixel(x, y, Color(g.r, g.g, g.b, c.a))
	return ImageTexture.create_from_image(img)


## 圆章按下态（压暗）/ 禁用态（去色）。
func _medal_variant(tex: Texture2D, grey: bool) -> Texture2D:
	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0: continue
			if grey:
				var l := c.get_luminance() * 0.75
				c = Color(l, l * 0.96, l * 0.9, c.a)
			else:
				c = Color(c.r * 0.72, c.g * 0.68, c.b * 0.66, c.a)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _nav_button(def: Array, pos: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.name = "Navigation_" + def[1]
	btn.texture_normal = load(KIT + "nav_socket.png")
	btn.texture_hover = load(KIT + "nav_socket_selected.png")
	btn.texture_pressed = load(KIT + "nav_socket_selected.png")
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = pos
	btn.pressed.connect(_on_entry.bind(def[0], def[1]))
	# 内孔垫深色圆底，图标居中在孔里；文字放在下方的小牌子上，压住下沿金属环但不碰图标
	btn.add_child(_disc(Vector2(20, 20), 40, HOLE_DARK))
	btn.add_child(_tex(DIR + "icons/%s_32.png" % def[2], Vector2(24, 20)))
	var plate := _plate(Vector2(18, 54), Vector2(44, 22))
	btn.add_child(plate)
	var t := _label(def[1], FONT_SERIF, G.FS_XS, CREAM, 3)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.position = Vector2(0, -1)
	t.size = plate.size
	plate.add_child(t)
	return btn


# ---------- 入口路由 ----------
func _on_entry(id: String, title: String) -> void:
	entry_pressed.emit(id)
	if host == null:
		_preview_toast("%s（预览版尚未接入）" % title)
		return
	if G.ui_blocked:
		return
	match id:
		"gacha": host._open_gacha()
		"arena": host._open_arena()
		"craft":
			# 没有独立锻造面板：铁匠铺直达养成里的装备页
			host._open_growth()
			if host._growth != null and host._growth.has_method("_open"):
				host._growth._open("equip")
		"exchange": host._open_exchange()
		"world": host._open_worlds(host._click_ev())
		"avatar": host._open_avatar_panel()
		"wallet": host._show_chest_dialog("行囊与货币", G.wallet_info_lines())
		"bag": host._open_bag()
		"gathering":
			if _gathering_unlocked:
				host._open_gathering()
			else:
				UI.toast(host, "完成归路小聚支线后开放")
		"quest": host._open_quests()
		"growth": host._open_growth()
		"party": host._open_codex(host._click_ev())
		"activity": host._open_activities()
		"settings": host._open_settings(host._click_ev())
		"expedition": _continue_journey()


## 出征 = 原“继续旅程”：淡出后回到可行走的主世界
func _continue_journey() -> void:
	if G.ui_blocked or not G.can_go(MAP_SCENE):
		return
	_hero.disabled = true
	refresh()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.24)
	tw.tween_callback(func(): host._open_city(host._click_ev()))


func _preview_toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(0.9)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ---------- 小工具 ----------
func _tex(path: String, pos: Vector2) -> TextureRect:
	var t := TextureRect.new()
	if path.begins_with(DIR):
		# 高清插画素材：按 1/HD 显示，线性过滤（先关掉按贴图撑大的最小尺寸，再赋贴图）
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.texture_filter = SMOOTH
	t.texture = load(path)
	t.position = pos
	if path.begins_with(DIR):
		t.size = t.texture.get_size() / HD
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _label(text: String, font: Font, size_px: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", maxi(size_px, G.FS_XS))
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", OUTLINE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _red_dot(pos: Vector2) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("d8342a")
	sb.border_color = OUTLINE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = Vector2(12, 12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _disc(pos: Vector2, d: int, color: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(d / 2)
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# 深色小牌：铜边 + 黑描边，用于导航文字和出征字样
func _plate(pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PLATE_DARK
	sb.border_color = BRONZE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.shadow_color = OUTLINE
	sb.shadow_size = 2
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _fmt(n: int) -> String:
	return UI.format_number(n)


func _wallet() -> Dictionary:
	return G.wallet


func _level_value() -> int:
	return int(G.prog.get("level", 1))


func _player_name() -> String:
	var n := G.display_name()
	return n if n != "" else "旅人"


func _exp_ratio() -> float:
	var need := G.exp_to_next(_level_value())
	if need <= 0:
		return 1.0   # 满级显示满条
	return clamp(float(G.prog.get("exp", 0)) / float(need), 0.0, 1.0)
