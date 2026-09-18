# GameHome.gd —— 养成主城：主角立绘 + 等级/经验 + 四币 + 世界进度 + 功能入口
# 养成主线（玩法文档 §6）：主城为唯一据点，世界按 theme_order 逐个解锁，
#   宠物/资源靠打怪升级与通关世界首领积累；此处是查看成长与决定下一步的枢纽。
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0

# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const GrowthPanelScript := preload("res://src/ui/GrowthPanel.gd")

const SPRITE_SCALE := 2.2       # 主界面以立绘为视觉中心，比局内放大一档
const PED_Y := 604.0            # 金色圆台中心 y
const BASE_OFFSET := 59.0       # 清理后素材脚底相对帧中心的偏移（基线 y=123）
const ANIM_Y := PED_Y - BASE_OFFSET * SPRITE_SCALE

const ENTRIES := [
	["主城", false],
	["世界", false],
	["图鉴", false],
	["出征", false],
	["设置", false],
]

var _anim: AnimatedSprite2D
var _toast: Label = null
var _deploy: DeployPanel = null
var _worlds: WorldPanel = null
var _codex: CodexPanel = null
var _gacha: GachaPanel = null      # 召唤（魂石抽宠物）
var _exchange: ExchangePanel = null  # 荣誉兑换
var _settings: SettingsPanel = null  # 设置（存档/键位）
var _growth: Control = null      # 养成 6 线（GrowthPanel）


func _ready() -> void:
	Audio.play_bgm("bgm_home")
	var role: Dictionary = G.get_role(G.selected_role)
	_build_background()
	_build_profile(role)
	_build_top(role)
	_build_stage(role)
	_build_entries()


# ---------- 背景（黄昏营地插画 + 轻压暗，保持暖调通透） ----------
func _build_background() -> void:
	var tr := TextureRect.new()
	tr.texture = load("res://image/background/home.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	# 上浅下深的压暗：顶部文字清晰，底部角色台与面板自然融入地面
	var grad := Gradient.new()
	grad.set_color(0, Color(0.10, 0.06, 0.03, 0.35))
	grad.set_color(1, Color(0.08, 0.05, 0.03, 0.62))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	var dim := TextureRect.new()
	dim.texture = grad_tex
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


# ---------- 左上角：个人信息（头像 + 名字 + 等级经验） ----------
func _build_profile(role: Dictionary) -> void:
	# 头像：角色 icon；缺素材时回退成写着角色名首字的金边圆牌
	var tex: Texture2D = load(G.role_dir(String(role.get("id", ""))) \
		+ _role_name(String(role.get("id", ""))) + "_icon.png")
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.position = Vector2(16, 18)
		pic.custom_minimum_size = Vector2(56, 56)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
	else:
		var nm := String(role.get("name", "旅"))
		var d := _disc_panel(56, nm.substr(0, 1))
		d.position = Vector2(16, 18)
		add_child(d)

	var name_txt: String = G.player_name if not G.player_name.is_empty() \
		else String(role.get("name", "旅人"))
	var nl := G.serif_label(name_txt, G.FS_MD + 1, G.NAME_GREEN)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nl.position = Vector2(82, 20)
	nl.custom_minimum_size = Vector2(160, 0)
	add_child(nl)

	var lv := int(G.prog.get("level", 1))
	var cur := int(G.prog.get("exp", 0))
	var need := G.exp_to_next(lv)
	var lv_l := G.gold_label("LV %d" % lv, G.FS_MD, true, Color("f0c060"), false)
	lv_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lv_l.position = Vector2(82, 52)
	lv_l.custom_minimum_size = Vector2(52, 0)
	add_child(lv_l)
	_add_exp_bar(Vector2(136, 58), 118.0, cur, need)


## 顶部经验条（金色圆角，满级时按满格画）
func _add_exp_bar(at: Vector2, w: float, cur: int, need: int) -> void:
	var ratio := 1.0 if need <= 0 else clampf(float(cur) / float(need), 0.0, 1.0)
	var track := Control.new()
	track.position = at
	track.custom_minimum_size = Vector2(w, 12)
	track.size = Vector2(w, 12)
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color("4a3a24")
	ts.set_corner_radius_all(6)
	track.add_theme_stylebox_override("panel", ts)   # 只为了复用圆角画风，实际用 Panel 画
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(w, 12)
	bg.size = Vector2(w, 12)
	bg.add_theme_stylebox_override("panel", ts)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(bg)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("e8b84a")
	fs.set_corner_radius_all(6)
	var fg := Panel.new()
	fg.position = Vector2(1, 1)
	fg.custom_minimum_size = Vector2(maxf(0.0, (w - 2.0) * ratio), 10)
	fg.size = Vector2(maxf(0.0, (w - 2.0) * ratio), 10)
	fg.add_theme_stylebox_override("panel", fs)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fg)


## 金边圆牌（头像缺素材时的回退）
func _disc_panel(px: float, glyph: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.06, 0.86)
	sb.set_corner_radius_all(int(px * 0.5))
	sb.set_border_width_all(2)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.55)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(G.serif_label(glyph, G.FS_LG, Color("f0c060")))
	return p


# ---------- 顶部：徽标 + 账号小字 + 重建入口 ----------
func _build_top(role: Dictionary) -> void:
	# 主页是"游戏主界面"：木匾挂游戏名，别跟主城（点进去才是主城）重名
	var b := G.banner_box("远 征", 240, 54)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.position = Vector2(-120, 84)   # 让出顶部两行：左上个人信息、右上四币与经验
	add_child(b)

	# 主线目标一行：一进主页就知道"现在该干什么"；点开是世界志（题记/正史/首领来历）
	# 宽度收到 304 并居中，避开右侧竖列按钮（x≥392），不跟它抢那一列
	var goal := G.main_goal()
	var gl := G.gold_label("目标 · " + G.main_goal_short(), G.FS_XS, false,
		Color("f0d9a0", 0.94), false)
	gl.position = Vector2(88, 142)
	gl.custom_minimum_size = Vector2(304, 0)
	gl.mouse_filter = Control.MOUSE_FILTER_STOP
	gl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gl.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.show_info_popup(gl, String(goal.get("title", "当前目标")),
				goal.get("lines", [])))
	add_child(gl)

	# 账号小字与「重新创建角色」撤出顶栏：一个和头像/名字挤在一起，一个压住货币条。
	# 账号不再常驻主页（游客没信息量），重建入口挪进「设置」面板。

	# 钱包四币（金/远征币/魂石/荣誉——存档累计，远征结算入账）
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)   # 数字别贴着下一个币的图标
	row.position = Vector2(206.0, 30)   # 顶部横带：四币（图标+数字）靠右一行
	# 点货币条 → 讲清四种币各是什么、从哪来
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.show_info_popup(row, "资源说明", [
				"金：建造与升级的主力货币，远征结算、讨伐首领可得。",
				"远征币：远征途中的通行花费，局结算与路线事件产出。",
				"魂石：召唤灵宠的消耗，远征与重复炼化产出。",
				"荣誉：兑换商店的交易凭证，对战与结算产出（不加深数值差距）。",
			]))
	add_child(row)
	var wallet_meta := [
		["金", "f0c060", "gold", "cur_gold"], ["远征", "7ac0c8", "expedition", "cur_expedition"],
		["魂石", "b08ad0", "soul", "cur_soul"], ["荣誉", "d07a5a", "honor", "cur_honor"],
	]
	for meta in wallet_meta:
		# 货币图标（无素材回退小圆点色标）
		var icon_tex: Texture2D = G.res_tex(String(meta[3]))
		if icon_tex != null:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.custom_minimum_size = Vector2(16, 16)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 别把货币条的点击吃掉
			row.add_child(icon)
		else:
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(7, 7)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var dot_sb := StyleBoxFlat.new()
			dot_sb.bg_color = Color(String(meta[1]))
			dot_sb.set_corner_radius_all(4)
			dot.add_theme_stylebox_override("panel", dot_sb)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(dot)
		var name_l := G.gold_label(String(meta[0]), G.FS_XS, false, Color("bfa987"), false)
		name_l.tooltip_text = String(meta[0])
		name_l.visible = false   # 顶栏只留 图标+数字（参考手游主页的货币条），名字进悬停提示
		row.add_child(name_l)
		var num_l := G.gold_label(str(int(G.wallet.get(String(meta[2]), 0))),
			G.FS_XS, true, Color(String(meta[1])), false)
		num_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(num_l)

	# 召唤 / 养成 / 兑换移到右侧竖列（见 _build_entries），这里只留钱包与玩家条


# ---------- 角色展示台（金色圆台 + 光圈 + 待机动画） ----------
func _build_stage(role: Dictionary) -> void:
	var pad := _Pedestal.new()
	pad.rx = 62.0
	pad.ry = 36.0
	pad.position = Vector2(VIEW_W / 2.0, PED_Y)
	add_child(pad)

	var ring := _RingDrawer.new()
	ring.rx = 76.0
	ring.ry = 40.0
	ring.position = Vector2(VIEW_W / 2.0, PED_Y + 6)
	add_child(ring)

	_anim = AnimatedSprite2D.new()
	_anim.scale = Vector2.ONE * SPRITE_SCALE
	_anim.position = Vector2(VIEW_W / 2.0, ANIM_Y)
	add_child(_anim)

	var role_id: String = String(role.get("id", "zs"))
	_anim.sprite_frames = _frames(role_id)
	_anim.animation = &"idle"
	_anim.play()


func _frames(role_id: String) -> SpriteFrames:
	var tex: Texture2D = load(G.role_dir(role_id) + _role_name(role_id) + "_idle.png")
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 5.0)
	frames.set_animation_loop(&"idle", true)
	for c in 4:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(c * 128, 0, 128, 128)
		frames.add_frame(&"idle", at)
	return frames


func _role_name(id: String) -> String:
	match id:
		"zs": return "pojun"
		"ck": return "chuanyang"
		"fs": return "shuangyu"
		"fz": return "chenxing"
	return id


## 右侧竖列：活动与系统入口（出征已搬进主城）
const RAIL_R := [["世界", "界"], ["图鉴", "图"], ["养成", "养"],
	["兑换", "兑"], ["召唤", "召"], ["设置", "设"]]

func _build_entries() -> void:
	# 右侧竖列：活动与系统入口（出征已搬进主城，主页只留浏览与设置）
	for i in RAIL_R.size():
		var b := _round_entry(String(RAIL_R[i][0]), String(RAIL_R[i][1]))
		b.position = Vector2(VIEW_W - 88.0, 150 + i * 84.0)
		add_child(b)

	# 底部：一行若隐若现的字，点它（或点屏幕下方）就直接进主世界
	var hint := G.serif_label("轻 触 进 入 主 世 界", G.FS_MD, Color("e6d0a4"))
	hint.position = Vector2(0, 730)
	hint.custom_minimum_size = Vector2(VIEW_W, 0)
	hint.modulate.a = 0.45
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(hint, "modulate:a", 0.85, 1.1)
	tw.tween_property(hint, "modulate:a", 0.40, 1.1)

	var zone := Control.new()
	zone.position = Vector2(0, 706)
	zone.custom_minimum_size = Vector2(VIEW_W, 94)
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.gui_input.connect(_open_city)
	add_child(zone)


## 圆形入口：圆底 + 金边 + 单字纹样 + 下方小字（不依赖新素材也能立住）
func _round_entry(label: String, glyph: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(72, 72)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var disc := PanelContainer.new()
	disc.custom_minimum_size = Vector2(60, 60)
	disc.position = Vector2(6, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.86)
	sb.set_corner_radius_all(30)
	sb.set_border_width_all(2)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.55)
	G._apply_shadow(sb, 5.0, 2.0, 0.4)
	disc.add_theme_stylebox_override("panel", sb)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(G.serif_label(glyph, G.FS_LG, Color("f0c060")))
	root.add_child(disc)

	var cap := G.gold_label(label, G.FS_XS, false, Color("e0cfa4"), false)
	cap.position = Vector2(0, 60)
	cap.custom_minimum_size = Vector2(72, 0)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cap)

	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_click")
			_dispatch_entry(label))
	return root


func _dispatch_entry(label: String) -> void:
	match label:
		"主城": get_tree().change_scene_to_file("res://src/city/CityScene.tscn")
		"世界": _open_worlds(_click_ev())
		"图鉴": _open_codex(_click_ev())
		"养成": _open_growth()
		"兑换": _open_exchange()
		"召唤": _open_gacha()
		"设置": _open_settings(_click_ev())


## 几个入口函数按鼠标事件判定，这里补一个"左键按下"事件喂给它们
func _click_ev() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


# ---------- 主城入口（可行走据点：建筑 / NPC / 活动 / 访客） ----------
func _open_city(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		get_tree().change_scene_to_file("res://src/city/CityScene.tscn")


# ---------- 远征入口（阶段 2.7：出征筹备 DEPLOY——选秘境→选人物→选宠物） ----------
func _on_expedition(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _deploy != null:
			return
		_deploy = DeployPanel.new()
		_deploy.confirmed.connect(func(cfg: Dictionary):
			RouteScene.pending_run = cfg
			get_tree().change_scene_to_file("res://src/run/RouteScene.tscn"))
		_deploy.canceled.connect(func():
			_deploy.queue_free()
			_deploy = null)
		add_child(_deploy)


# ---------- 世界入口（8 片大陆的解锁进度） ----------
func _open_worlds(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _worlds != null:
		return
	Audio.sfx("ui_open")
	_worlds = WorldPanel.new()
	_worlds.closed.connect(func():
		Audio.sfx("ui_close")
		_worlds.queue_free()
		_worlds = null)
	add_child(_worlds)


# ---------- 图鉴入口（宠物收集进度 + 解锁条件） ----------
func _open_codex(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _codex != null:
		return
	Audio.sfx("ui_open")
	_codex = CodexPanel.new()
	_codex.closed.connect(func():
		Audio.sfx("ui_close")
		_codex.queue_free()
		_codex = null)
	add_child(_codex)


# ---------- 召唤入口（魂石抽宠物：单抽/十连 + 保底 + 重复炼金） ----------
func _open_gacha() -> void:
	if _gacha != null:
		return
	Audio.sfx("ui_open")
	_gacha = GachaPanel.new()
	_gacha.closed.connect(func():
		Audio.sfx("ui_close")
		_gacha.queue_free()
		_gacha = null)
	add_child(_gacha)


# ---------- 兑换入口（荣誉换金币/远征币/魂石/扫荡券） ----------
func _open_exchange() -> void:
	if _exchange != null:
		return
	Audio.sfx("ui_open")
	_exchange = ExchangePanel.new()
	_exchange.closed.connect(func():
		Audio.sfx("ui_close")
		_exchange.queue_free()
		_exchange = null)
	add_child(_exchange)


# ---------- 养成入口（六线：天赋/装备/宠物/技能书/坐骑/称号） ----------
func _open_growth() -> void:
	if _growth != null:
		return
	Audio.sfx("ui_open")
	_growth = GrowthPanelScript.new()
	_growth.closed.connect(func():
		Audio.sfx("ui_close")
		_growth.queue_free()
		_growth = null)
	add_child(_growth)


# ---------- 设置入口（存档导出导入 / 键位说明 / 回标题 / 重置） ----------
func _open_settings(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _settings != null:
		return
	Audio.sfx("ui_open")
	_settings = SettingsPanel.new()
	_settings.closed.connect(func():
		Audio.sfx("ui_close")
		_settings.queue_free()
		_settings = null)
	add_child(_settings)


# ---------- 交互 ----------
func _on_back(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		get_tree().change_scene_to_file("res://src/ui/CreateRole.tscn")


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_MD, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 672)
	_toast.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _worlds != null:
		_worlds.queue_free()
		_worlds = null
		return
	if _codex != null:
		_codex.queue_free()
		_codex = null
		return
	if _deploy != null:
		_deploy.queue_free()
		_deploy = null
		return
	get_tree().change_scene_to_file("res://src/ui/CreateRole.tscn")


# ---------- 自绘：金色圆台 / 脚下光圈 ----------
class _Pedestal extends Node2D:
	var rx := 64.0
	var ry := 40.0
	func _draw() -> void:
		var s := ry / rx
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, s))
		draw_circle(Vector2(0, 6.0 / s), rx * 1.05, Color(0, 0, 0, 0.35))
		draw_circle(Vector2.ZERO, rx, Color("8a6a28"))
		draw_circle(Vector2(0, -3.0 / s), rx * 0.8, Color("c9a44a"))
		draw_circle(Vector2(0, -5.0 / s), rx * 0.5, Color("e8c668"))


class _RingDrawer extends Node2D:
	var rx := 80.0
	var ry := 48.0
	func _draw() -> void:
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var n := 64
		for i in n + 1:
			var a := TAU * float(i) / float(n)
			outer.append(Vector2(cos(a) * rx, sin(a) * ry))
			inner.append(Vector2(cos(a) * rx * 0.9, sin(a) * ry * 0.9))
		draw_polyline(outer, G.GOLD_BRIGHT, 3.0)
		draw_polyline(inner, Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.5), 2.0)
