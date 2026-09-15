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
	return root


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