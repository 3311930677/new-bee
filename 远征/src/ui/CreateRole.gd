# CreateRole.gd —— 创建角色（参考"创建角色"风：昵称输入 + 随机取名 + 性别/职业切换 + 单角色展示 + 羊皮纸说明）
extends Control

const BG_W := 971.0
const BG_H := 1619.0
const VIEW_W := 480.0
const VIEW_H := 800.0

const SPRITE_SCALE := 1.9      # 单角色放大展示
const PED_Y := 530.0           # 金色圆台中心 y
const BASE_OFFSET := 59.0      # 清理后素材脚底相对帧中心的偏移（基线 y=123）
const ANIM_Y := PED_Y - BASE_OFFSET * SPRITE_SCALE

const GENDERS := ["男", "女"]

var _name_edit: LineEdit
var _sel_gender: _Selector
var _sel_class: _Selector
var _anim: AnimatedSprite2D
var _info: Dictionary = {}
var _role_idx := 0
var _gender_idx := 0
var _toast: Label = null
var _role_art_frame: PanelContainer = null   # 职业插画位（有图才显形）
var _role_art: TextureRect = null


func _ready() -> void:
	_build_background()
	_build_header()
	_build_name_row()
	_build_selectors()
	_build_stage_art()
	_build_stage()
	_build_swipe()
	_build_info_panel()
	_build_buttons()
	_sel_gender.set_text(GENDERS[_gender_idx])
	_name_edit.text = G.random_name()
	var start := 0
	for i in G.roles.size():
		if G.roles[i]["id"] == G.selected_role:
			start = i
	_switch_role(start, false)


# ---------- 背景 ----------
func _build_background() -> void:
	var tr := TextureRect.new()
	tr.texture = G.res_tex("bg_abyss") if G.res_tex("bg_abyss") != null \
		else load("res://image/background/enter.png")  # 深渊暗调：托底四职业立绘
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(VIEW_W, VIEW_W * BG_H / BG_W)
	tr.position = Vector2(0, VIEW_H - tr.size.y)
	tr.modulate = Color(0.72, 0.68, 0.66)   # 压暗去色，避免背景立绘与展示角色抢视线
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.03, 0.70)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


func _build_header() -> void:
	var b := G.banner_box("创建角色", 240, 54)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.position = Vector2(-120, 22)
	add_child(b)


# ---------- 昵称 ----------
func _build_name_row() -> void:
	var lbl := G.serif_label("角色昵称", G.FS_MD, Color("ecdcb2"))
	lbl.position = Vector2(0, 88)
	lbl.size = Vector2(VIEW_W, 26)
	add_child(lbl)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "请输入昵称"
	_name_edit.max_length = 12
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.position = Vector2(62, 118)
	_name_edit.custom_minimum_size = Vector2(232, 42)
	G.style_line_edit(_name_edit, G.FS_MD)
	_name_edit.text_submitted.connect(func(_t: String): _confirm())
	add_child(_name_edit)

	var rnd := G.gold_button("随机取名", 112, 42)
	rnd.position = Vector2(306, 118)
	rnd.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_name_edit.text = G.random_name()
			_name_edit.grab_focus()
	)
	add_child(rnd)

	var hint := G.gold_label("2~12 个字符，汉字 2~6 个", G.FS_XS, false, Color("cdb088", 0.85), false)
	hint.position = Vector2(0, 168)
	hint.size = Vector2(VIEW_W, 22)
	add_child(hint)


# ---------- 性别 / 职业 选择框 ----------
func _build_selectors() -> void:
	_sel_gender = _Selector.new(132, 42, G.FS_MD)
	_sel_gender.position = Vector2(92, 200)
	_sel_gender.prev_pressed.connect(func(): _cycle_gender(-1))
	_sel_gender.next_pressed.connect(func(): _cycle_gender(1))
	add_child(_sel_gender)

	_sel_class = _Selector.new(132, 42, G.FS_MD)
	_sel_class.position = Vector2(256, 200)
	_sel_class.prev_pressed.connect(func(): _switch_role(_role_idx - 1, true))
	_sel_class.next_pressed.connect(func(): _switch_role(_role_idx + 1, true))
	add_child(_sel_class)


func _cycle_gender(delta: int) -> void:
	_gender_idx = wrapi(_gender_idx + delta, 0, GENDERS.size())
	_sel_gender.set_text(GENDERS[_gender_idx])
	_sel_gender.set_active(true)
	_sel_class.set_active(false)


# ---------- 角色展示台 ----------
## 职业插画位：role_<id>_art.png（或 role_<id>.png）存在时才显形，缺图整块不占地方
## —— 生成好立绘丢进 image/generated_*/ready/ 即可自动铺在角色身后
func _build_stage_art() -> void:
	_role_art_frame = PanelContainer.new()
	_role_art_frame.position = Vector2(72, 298)
	_role_art_frame.custom_minimum_size = Vector2(336, 246)
	_role_art_frame.clip_contents = true
	_role_art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.03, 0.35)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.16)
	_role_art_frame.add_theme_stylebox_override("panel", sb)
	add_child(_role_art_frame)

	_role_art = TextureRect.new()
	_role_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_role_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# 压成氛围层：这张立绘和台上的像素小人画的是同一个角色，太实会"两个破军"打架
	_role_art.modulate = Color(0.82, 0.78, 0.76, 0.34)
	_role_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role_art_frame.add_child(_role_art)
	_refresh_role_art()


func _refresh_role_art() -> void:
	if _role_art == null:
		return
	var rid := String((G.roles[_role_idx] as Dictionary).get("id", ""))
	var tex: Texture2D = G.res_tex("role_%s_art" % rid)
	if tex == null:
		tex = G.res_tex("role_%s" % rid)
	_role_art.texture = tex
	_role_art_frame.visible = tex != null


func _build_stage() -> void:
	var pad := _Pedestal.new()
	pad.position = Vector2(VIEW_W / 2.0, PED_Y)
	pad.rx = 62.0
	pad.ry = 36.0
	add_child(pad)

	var ring := _RingDrawer.new()
	ring.position = Vector2(VIEW_W / 2.0, PED_Y + 6)
	ring.rx = 76.0
	ring.ry = 40.0
	add_child(ring)

	_anim = AnimatedSprite2D.new()
	_anim.scale = Vector2.ONE * SPRITE_SCALE
	_anim.position = Vector2(VIEW_W / 2.0, ANIM_Y)
	add_child(_anim)


## 滑动切职业：舞台上横向拖 40px 就换人（与 ←→ 键同口径），手机拖拽 / 电脑鼠标都能用
func _build_swipe() -> void:
	var hint := G.gold_label("← → 或左右拖动切换职业", G.FS_XS, false, Color("cdb088", 0.8), false)
	hint.position = Vector2(0, 272)
	hint.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(hint)

	var zone := Control.new()
	zone.position = Vector2(20, 296)
	zone.custom_minimum_size = Vector2(440, 268)
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var drag := {"on": false, "x": 0.0}
	zone.gui_input.connect(func(e: InputEvent):
		if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
			return
		if e.pressed:
			drag["on"] = true
			drag["x"] = (e as InputEventMouseButton).global_position.x
		elif drag["on"]:
			drag["on"] = false
			var dx: float = (e as InputEventMouseButton).global_position.x - float(drag["x"])
			if dx < -40.0:
				_switch_role(_role_idx + 1, true)
			elif dx > 40.0:
				_switch_role(_role_idx - 1, true))
	add_child(zone)


func _switch_role(idx: int, animate: bool) -> void:
	_role_idx = wrapi(idx, 0, G.roles.size())
	var role: Dictionary = G.roles[_role_idx]
	_anim.sprite_frames = _build_frames(role["id"])
	_anim.animation = &"idle"
	_anim.play(&"idle")
	_sel_class.set_text(role["name"])
	_sel_class.set_active(true)
	_sel_gender.set_active(false)
	_refresh_role_art()
	_refresh_info()
	if animate:
		_anim.modulate.a = 0.0
		_anim.scale = Vector2.ONE * (SPRITE_SCALE * 0.78)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_anim, "modulate:a", 1.0, 0.16)
		tw.tween_property(_anim, "scale", Vector2.ONE * SPRITE_SCALE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_frames(role_id: String) -> SpriteFrames:
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


# ---------- 羊皮纸说明面板 ----------
func _build_info_panel() -> void:
	var panel := G.parchment_box(432, 156, 20.0)
	panel.position = Vector2(24, 580)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)

	var rname := G.serif_label("破军", G.FS_LG, G.BANNER)
	title_row.add_child(rname)
	var job := G.gold_label("战士 · 大剑", G.FS_SM, false, Color("7a5a2e"), false)
	job.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_row.add_child(job)

	var tags := G.gold_label("近战物理 · 能抗能打", G.FS_SM, false, Color("8a6a34"), false)
	tags.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(tags)

	var desc := Label.new()
	desc.add_theme_font_override("font", G.font_serif)
	desc.add_theme_font_size_override("font_size", G.FS_SM)
	desc.add_theme_color_override("font_color", G.TEXT_DARK)
	desc.add_theme_constant_override("line_spacing", 5)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(392, 0)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)

	_info = {"title": rname, "job": job, "tags": tags, "desc": desc}


func _refresh_info() -> void:
	var role: Dictionary = G.roles[_role_idx]
	_info["title"].text = role["name"]
	_info["job"].text = "%s · %s" % [role["job"], role["weapon"]]
	_info["tags"].text = role.get("tags", "")
	_info["desc"].text = role.get("desc", "")


# ---------- 底部按钮 ----------
func _build_buttons() -> void:
	var ok := G.gold_button("确定", 150, 46)
	ok.position = Vector2(78, 744)
	ok.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_confirm()
	)
	add_child(ok)

	var cancel := G.gold_button("取消", 150, 46)
	cancel.position = Vector2(252, 744)
	cancel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			get_tree().change_scene_to_file("res://src/ui/Login.tscn")
	)
	add_child(cancel)


# ---------- 确认 ----------
func _confirm() -> void:
	var nm := _name_edit.text.strip_edges()
	if nm.is_empty():
		Audio.sfx("ui_locked")
		_toast_msg("请输入角色昵称")
		return
	if nm.length() > 12:
		Audio.sfx("ui_locked")
		_toast_msg("昵称最长 12 个字符")
		return
	Audio.sfx("ui_confirm")
	G.gender = GENDERS[_gender_idx]
	G.selected_role = G.roles[_role_idx]["id"]
	G.player_name = nm
	# 捏完人先看序章：交代"你在哪、为什么出征、第一站去哪"，再进主城
	if G.lore_seen():
		get_tree().change_scene_to_file("res://src/ui/GameHome.tscn")
	else:
		get_tree().change_scene_to_file("res://src/ui/Prologue.tscn")


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_MD, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 470)
	_toast.size = Vector2(VIEW_W, 24)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://src/ui/Login.tscn")
	elif event.is_action_pressed("ui_left"):
		_switch_role(_role_idx - 1, true)
	elif event.is_action_pressed("ui_right"):
		_switch_role(_role_idx + 1, true)


# ---------- 参考风选择框：◀ 值 ▶ ----------
class _Selector extends PanelContainer:
	signal prev_pressed
	signal next_pressed

	var value: Label
	var _sb: StyleBoxFlat

	func _init(w: float, h: float, fs: int) -> void:
		custom_minimum_size = Vector2(w, h)
		_sb = StyleBoxFlat.new()
		_sb.bg_color = G.BOX_BG
		_sb.set_corner_radius_all(3)
		_sb.set_border_width_all(2)
		_sb.border_color = G.BOX_EDGE
		add_theme_stylebox_override("panel", _sb)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		add_child(row)
		row.add_child(_arrow("◀", fs, true))
		value = G.gold_label("-", fs, true, G.TEXT_DARK, false)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(value)
		row.add_child(_arrow("▶", fs, false))

	func _arrow(glyph: String, fs: int, is_prev: bool) -> Control:
		var b := Control.new()
		b.custom_minimum_size = Vector2(32, 0)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var l := G.gold_label(glyph, fs, true, G.TEXT_DARK, false)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				if is_prev:
					prev_pressed.emit()
				else:
					next_pressed.emit()
		)
		return b

	func set_text(t: String) -> void:
		value.text = t

	func set_active(a: bool) -> void:
		_sb.bg_color = G.GOLD_BTN if a else Color("b5aa90")
		_sb.border_color = G.GOLD_BTN_EDGE if a else G.BOX_EDGE
		value.add_theme_color_override("font_color", G.TEXT_DARK)


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
