# GameHome.gd —— 游戏主页：角色立绘展示 + 信息面板 + 底部功能入口（占位骨架）
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0

const SPRITE_SCALE := 1.9
const PED_Y := 500.0            # 金色圆台中心 y
const BASE_OFFSET := 59.0       # 清理后素材脚底相对帧中心的偏移（基线 y=123）
const ANIM_Y := PED_Y - BASE_OFFSET * SPRITE_SCALE

const ENTRIES := [
	["主页", false],
	["编队", false],
	["远征", true],
	["设置", false],
]

var _anim: AnimatedSprite2D
var _toast: Label = null
var _deploy: _DeployPanel = null


func _ready() -> void:
	var role: Dictionary = G.get_role(G.selected_role)
	_build_background()
	_build_top(role)
	_build_stage(role)
	_build_info(role)
	_build_entries()


# ---------- 背景（沿用入场插画 + 深色压暗） ----------
func _build_background() -> void:
	var tr := TextureRect.new()
	tr.texture = load("res://image/background/enter.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(VIEW_W, VIEW_W * 1672.0 / 941.0)
	tr.position = Vector2(0, VIEW_H - tr.size.y)
	tr.modulate = Color(0.72, 0.68, 0.66)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


# ---------- 顶部：徽标 + 账号小字 + 重建入口 ----------
func _build_top(role: Dictionary) -> void:
	var b := G.banner_box("远征世界", 240, 54)
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

	# 钱包三币（金/远征币/魂石——存档累计，远征结算入账）
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.position = Vector2(VIEW_W / 2.0 - 150.0, 90)
	add_child(row)
	var wallet_meta := [
		["金", "f0c060", "gold"], ["远征币", "7ac0c8", "expedition"], ["魂石", "b08ad0", "soul"],
	]
	for meta in wallet_meta:
		var name_l := G.gold_label(String(meta[0]), G.FS_XS, false, Color("bfa987"), false)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_l)
		var num_l := G.gold_label(str(int(G.wallet.get(String(meta[2]), 0))),
			G.FS_XS, true, Color(String(meta[1])), false)
		num_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(num_l)


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


# ---------- 信息面板（羊皮纸：角色名 + 职业/武器 + 标签） ----------
func _build_info(role: Dictionary) -> void:
	var panel := G.parchment_box(432, 128, 20.0)
	panel.position = Vector2(24, 568)
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

	var lv := G.gold_label("LV 1", G.FS_SM, false, Color("a08050"), false)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(lv)


# ---------- 底部功能入口（占位） ----------
func _build_entries() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2((VIEW_W - (4 * 88.0 + 3 * 10.0)) / 2.0, 732)
	add_child(row)

	for e in ENTRIES:
		row.add_child(_entry(e[0], e[1]))


func _entry(label: String, active: bool) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(88, 56)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2)
	if active:
		sb.bg_color = G.GOLD_BTN
		sb.border_color = G.GOLD_BTN_EDGE
	else:
		sb.bg_color = Color(0.14, 0.09, 0.05, 0.8)
		sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.45)
	root.add_theme_stylebox_override("panel", sb)
	var l := G.serif_label(label, G.FS_MD, G.TEXT_DARK if active else Color("d9b96e"))
	root.add_child(l)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	if not active:
		root.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_toast_msg("「%s」功能开发中" % label))
	elif label == "远征":
		root.gui_input.connect(_on_expedition)
	return root


# ---------- 远征入口（阶段 2.7：出征筹备 DEPLOY——选秘境→选人物→选宠物） ----------
func _on_expedition(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _deploy != null:
			return
		_deploy = _DeployPanel.new()
		_deploy.confirmed.connect(func(cfg: Dictionary):
			RouteScene.pending_run = cfg
			get_tree().change_scene_to_file("res://src/run/RouteScene.tscn"))
		_deploy.canceled.connect(func():
			_deploy.queue_free()
			_deploy = null)
		add_child(_deploy)


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
	if event.is_action_pressed("ui_cancel"):
		if _deploy != null:
			_deploy.queue_free()
			_deploy = null
			return
		get_tree().change_scene_to_file("res://src/ui/CreateRole.tscn")


# ---------- 出征筹备浮层（选秘境 → 选人物 → 选宠物；预填默认可直接出征） ----------
class _DeployPanel extends Control:
	signal confirmed(cfg: Dictionary)
	signal canceled

	var _theme := "forest"
	var _role := "zs"
	var _active_pet := "pet_rockturtle"
	var _bench_pet := ""
	var _theme_btns := {}    # id -> PanelContainer
	var _role_btns := {}
	var _pet_btns := {}
	var _hint: Label = null

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		if G.selected_role != "":
			_role = G.selected_role
		_build()

	func _build() -> void:
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.72)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim)

		var banner := G.banner_box("出征筹备", 280, 50)
		banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		banner.position = Vector2(-140, 36)
		add_child(banner)

		var panel := G.parchment_box(440, 560, 16.0)
		panel.position = Vector2(20, 108)
		add_child(panel)

		_section(panel, "远征秘境", 18)
		var maps: Dictionary = TableCache.maps_config()
		var order: Array = maps.get("theme_order", [])
		var themes: Dictionary = maps.get("themes", {})
		for i in order.size():
			var tid := String(order[i])
			var btn := _opt_btn(String(themes.get(tid, {}).get("name", tid)), 96, 38)
			btn.position = Vector2(16 + (i % 4) * 104, 46 + (i / 4) * 46)
			btn.gui_input.connect(func(e: InputEvent): _on_opt_click(e, _select_theme, tid))
			_theme_btns[tid] = btn
			panel.add_child(btn)

		_section(panel, "出战人物", 140)
		for i in G.roles.size():
			var r: Dictionary = G.roles[i]
			var rid := String(r.get("id", ""))
			var rbtn := _opt_btn(String(r.get("name", rid)), 96, 46)
			rbtn.position = Vector2(16 + i * 104, 168)
			rbtn.gui_input.connect(func(e: InputEvent): _on_opt_click(e, _select_role, rid))
			_role_btns[rid] = rbtn
			panel.add_child(rbtn)

		_section(panel, "随行宠物（先点出战，再点替补）", 228)
		var pets: Array = TableCache.pets()
		for i in pets.size():
			var p: Dictionary = pets[i]
			var pid := String(p.get("id", ""))
			var pbtn := _opt_btn(String(p.get("name", pid)), 96, 42)
			pbtn.position = Vector2(16 + (i % 4) * 104, 256 + (i / 4) * 48)
			pbtn.gui_input.connect(func(e: InputEvent): _on_opt_click(e, _select_pet, pid))
			_pet_btns[pid] = pbtn
			panel.add_child(pbtn)

		_hint = G.gold_label("▶ 出战 · ◇ 替补 · 再点取消", G.FS_XS, false, Color("8a6a34"), false)
		_hint.position = Vector2(0, 352)
		_hint.custom_minimum_size = Vector2(440, 0)
		panel.add_child(_hint)

		var go := G.gold_button("出 征", 200, 48)
		go.position = Vector2(120, 420)
		go.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_on_confirm())
		panel.add_child(go)

		var back := G.gold_button("返 回", 120, 36)
		back.position = Vector2(160, 484)
		back.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				canceled.emit())
		panel.add_child(back)

		_refresh_sel()

	func _section(panel: Control, text: String, y: float) -> void:
		var l := G.gold_label(text, G.FS_SM, false, Color("7a5a2e"), false)
		l.position = Vector2(0, y)
		l.custom_minimum_size = Vector2(440, 0)
		panel.add_child(l)

	func _opt_btn(text: String, w: float, h: float) -> PanelContainer:
		var root := PanelContainer.new()
		root.custom_minimum_size = Vector2(w, h)
		var sb := StyleBoxFlat.new()
		sb.bg_color = G.BOX_BG
		sb.set_corner_radius_all(3)
		sb.set_border_width_all(2)
		sb.border_color = G.BOX_EDGE
		root.add_theme_stylebox_override("panel", sb)
		root.add_child(G.gold_label(text, G.FS_SM, false, G.TEXT_DARK, false))
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		return root

	func _on_opt_click(e: InputEvent, fn: Callable, id: String) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			fn.call(id)

	func _select_theme(id: String) -> void:
		_theme = id
		_refresh_sel()

	func _select_role(id: String) -> void:
		_role = id
		_refresh_sel()

	func _select_pet(id: String) -> void:
		if id == _active_pet:
			if _bench_pet != "":
				_active_pet = _bench_pet
				_bench_pet = ""
			else:
				_active_pet = ""
		elif id == _bench_pet:
			_bench_pet = ""
		else:
			if _active_pet == "":
				_active_pet = id
			else:
				_bench_pet = id
		_refresh_sel()

	func _refresh_sel() -> void:
		for id in _theme_btns:
			_set_sel(_theme_btns[id], id == _theme)
		for id in _role_btns:
			_set_sel(_role_btns[id], id == _role)
		for id in _pet_btns:
			var btn: PanelContainer = _pet_btns[id]
			_set_sel(btn, id == _active_pet or id == _bench_pet)
			var l := btn.get_child(0) as Label
			var txt := String(TableCache.get_pet(String(id)).get("name", String(id)))
			if id == _active_pet:
				txt = "▶ " + txt
			elif id == _bench_pet:
				txt = "◇ " + txt
			if l != null:
				l.text = txt

	func _set_sel(btn: PanelContainer, on: bool) -> void:
		var sb: StyleBoxFlat = btn.get_theme_stylebox("panel")
		if sb == null:
			return
		sb.bg_color = G.GOLD_BTN if on else G.BOX_BG
		sb.border_color = G.GOLD_BTN_EDGE if on else G.BOX_EDGE

	func _on_confirm() -> void:
		if _active_pet == "":
			if _hint != null:
				_hint.text = "请先点选一只出战宠物"
			return
		confirmed.emit({
			"theme": _theme,
			"role_id": _role,
			"level": 5,
			"active_pet": _active_pet,
			"bench_pet": _bench_pet,
			"potions": 2,
			"seed": 0,
		})


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