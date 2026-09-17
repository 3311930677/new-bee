# GameHome.gd —— 养成主城：主角立绘 + 等级/经验 + 四币 + 世界进度 + 功能入口
# 养成主线（玩法文档 §6）：主城为唯一据点，世界按 theme_order 逐个解锁，
#   宠物/资源靠打怪升级与通关世界首领积累；此处是查看成长与决定下一步的枢纽。
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0

# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const GrowthPanelScript := preload("res://src/ui/GrowthPanel.gd")

const SPRITE_SCALE := 1.9
const PED_Y := 500.0            # 金色圆台中心 y
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
	var role: Dictionary = G.get_role(G.selected_role)
	_build_background()
	_build_top(role)
	_build_stage(role)
	_build_info(role)
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


# ---------- 顶部：徽标 + 账号小字 + 重建入口 ----------
func _build_top(role: Dictionary) -> void:
	var b := G.banner_box("远征主城", 240, 54)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.position = Vector2(-120, 34)
	add_child(b)

	if not G.account.is_empty():
		var acc := G.gold_label(G.account, G.FS_XS, false, Color("bfa987", 0.8), false)
		acc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		acc.position = Vector2(16, 22)
		add_child(acc)

	var back := Control.new()
	back.custom_minimum_size = Vector2(120, 22)
	back.position = Vector2(VIEW_W - 136, 18)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(_on_back)
	var back_l := G.gold_label("重新创建角色", G.FS_XS, false, Color("d8c090"), false)
	back_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	back_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(back_l)
	add_child(back)

	# 钱包四币（金/远征币/魂石/荣誉——存档累计，远征结算入账）
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.position = Vector2(VIEW_W / 2.0 - 152.0, 90)
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
			row.add_child(icon)
		else:
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(7, 7)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var dot_sb := StyleBoxFlat.new()
			dot_sb.bg_color = Color(String(meta[1]))
			dot_sb.set_corner_radius_all(4)
			dot.add_theme_stylebox_override("panel", dot_sb)
			row.add_child(dot)
		var name_l := G.gold_label(String(meta[0]), G.FS_XS, false, Color("bfa987"), false)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_l)
		var num_l := G.gold_label(str(int(G.wallet.get(String(meta[2]), 0))),
			G.FS_XS, true, Color(String(meta[1])), false)
		num_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(num_l)

	# 召唤 / 养成 / 兑换：三大系统入口（抽宠 · 六线养成 · 荣誉换补给），压在钱包下、展示台上
	var gacha_btn := G.gold_button("召 唤", 130, 36, G.FS_MD)
	gacha_btn.position = Vector2(38, 118)
	gacha_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_gacha())
	add_child(gacha_btn)
	var growth_btn := G.gold_button("养 成", 130, 36, G.FS_MD)
	growth_btn.position = Vector2(175, 118)
	growth_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_growth())
	add_child(growth_btn)
	var exch_btn := G.gold_button("兑 换", 130, 36, G.FS_MD)
	exch_btn.position = Vector2(312, 118)
	exch_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_exchange())
	add_child(exch_btn)


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


# ---------- 信息面板（羊皮纸：角色名 + 职业/武器 + 等级经验 + 世界进度） ----------
func _build_info(role: Dictionary) -> void:
	var panel := G.parchment_box(432, 152, 20.0)
	panel.position = Vector2(24, 552)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var name_txt: String = G.player_name
	if name_txt.is_empty():
		name_txt = String(role.get("name", "旅人"))

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)

	var rname := G.serif_label(name_txt, G.FS_LG + 2, G.NAME_GREEN)
	title_row.add_child(rname)
	var job := G.gold_label("%s · %s" % [role.get("job", ""), role.get("weapon", "")],
		G.FS_SM, false, Color("7a5a2e"), false)
	job.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_row.add_child(job)

	var detail := "%s · %s" % [G.gender, role.get("tags", "")]
	var tags := G.gold_label(detail, G.FS_SM, false, Color("8a6a34"), false)
	tags.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(tags)

	var sep := ColorRect.new()
	sep.color = Color(G.BANNER.r, G.BANNER.g, G.BANNER.b, 0.4)
	sep.custom_minimum_size = Vector2(0, 2)
	box.add_child(sep)

	# 等级 + 经验条：经验条宽 150，右侧写「当前/所需」
	var lv := int(G.prog.get("level", 1))
	var cur := int(G.prog.get("exp", 0))
	var need := G.exp_to_next(lv)
	var lv_row := HBoxContainer.new()
	lv_row.add_theme_constant_override("separation", 8)
	box.add_child(lv_row)

	var lv_l := G.gold_label("LV %d" % lv, G.FS_MD, true, Color("a06020"), false)
	lv_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_row.add_child(lv_l)

	var bar_bg := Control.new()
	bar_bg.custom_minimum_size = Vector2(150, 12)
	bar_bg.clip_contents = true
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv_row.add_child(bar_bg)
	var bar_sbg := ColorRect.new()
	bar_sbg.color = Color("b8a884")
	bar_sbg.size = Vector2(150, 12)
	bar_sbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar_sbg)
	var bar_fill := ColorRect.new()
	bar_fill.color = Color("d8a838")
	bar_fill.position = Vector2(1, 1)
	bar_fill.size = Vector2(148.0 * clampf(float(cur) / maxf(1.0, float(need)), 0.0, 1.0), 10)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar_fill)

	var exp_l := G.gold_label("满级" if need <= 0 else "经验 %d / %d" % [cur, need],
		G.FS_XS, false, Color("8a6a34"), false)
	exp_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_row.add_child(exp_l)

	# 世界进度：已解锁（能出征）/ 已通关（首领倒下）分开写，两者不是一回事
	var unlocked := int(G.prog.get("worlds_unlocked", 1))
	var total := G.world_count()
	var cleared_n := G.cleared_world_count()
	var cur_theme := ""
	var order := G.theme_order()
	if unlocked >= 1 and unlocked <= order.size():
		cur_theme = G.world_name(String(order[unlocked - 1]))
	var prog_txt := "已解锁 %d / %d · 已通关 %d" % [unlocked, total, cleared_n]
	if not cur_theme.is_empty():
		prog_txt += " · 当前「%s」" % cur_theme
	var world_l := G.gold_label(prog_txt, G.FS_SM, false, Color("6a8a4a"), false)
	world_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(world_l)


# ---------- 底部功能入口（占位） ----------
func _build_entries() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.position = Vector2((VIEW_W - (5 * 86.0 + 4 * 8.0)) / 2.0, 732)
	add_child(row)

	for e in ENTRIES:
		row.add_child(_entry(e[0], e[1]))


func _entry(label: String, active: bool) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(86, 56)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2)
	if active:
		sb.bg_color = G.GOLD_BTN
		sb.border_color = G.GOLD_BTN_EDGE
	else:
		sb.bg_color = Color(0.14, 0.09, 0.05, 0.8)
		sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.45)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	root.add_theme_stylebox_override("panel", sb)
	var l := G.serif_label(label, G.FS_MD, G.TEXT_DARK if active else Color("d9b96e"))
	root.add_child(l)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	match label:
		"主城":
			root.gui_input.connect(_open_city)
		"世界":
			root.gui_input.connect(_open_worlds)
		"图鉴":
			root.gui_input.connect(_open_codex)
		"出征":
			root.gui_input.connect(_on_expedition)
		"设置":
			root.gui_input.connect(_open_settings)
	return root


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
	_worlds = WorldPanel.new()
	_worlds.closed.connect(func():
		_worlds.queue_free()
		_worlds = null)
	add_child(_worlds)


# ---------- 图鉴入口（宠物收集进度 + 解锁条件） ----------
func _open_codex(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _codex != null:
		return
	_codex = CodexPanel.new()
	_codex.closed.connect(func():
		_codex.queue_free()
		_codex = null)
	add_child(_codex)


# ---------- 召唤入口（魂石抽宠物：单抽/十连 + 保底 + 重复炼金） ----------
func _open_gacha() -> void:
	if _gacha != null:
		return
	_gacha = GachaPanel.new()
	_gacha.closed.connect(func():
		_gacha.queue_free()
		_gacha = null)
	add_child(_gacha)


# ---------- 兑换入口（荣誉换金币/远征币/魂石/扫荡券） ----------
func _open_exchange() -> void:
	if _exchange != null:
		return
	_exchange = ExchangePanel.new()
	_exchange.closed.connect(func():
		_exchange.queue_free()
		_exchange = null)
	add_child(_exchange)


# ---------- 养成入口（六线：天赋/装备/宠物/技能书/坐骑/称号） ----------
func _open_growth() -> void:
	if _growth != null:
		return
	_growth = GrowthPanelScript.new()
	_growth.closed.connect(func():
		_growth.queue_free()
		_growth = null)
	add_child(_growth)


# ---------- 设置入口（存档导出导入 / 键位说明 / 回标题 / 重置） ----------
func _open_settings(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _settings != null:
		return
	_settings = SettingsPanel.new()
	_settings.closed.connect(func():
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