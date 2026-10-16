# RareGearCeremony.gd —— 稀有装备全屏展示仪式系统（商业化品质）
# 适用场景：开箱获得极品、装备锻造/合成成功、升级突破里程碑、神兵启封
# 包含：全屏暗漆沉浸底衬、稀有度色系光芒射线、光粒汇聚、装备悬停、印章加速震落与落地光波震屏反馈
class_name RareGearCeremony
extends Control

signal closed

const NIGHT := Color("0b090e")
const GOLD_EDGE := Color("c29a5b")
const BRONZE := Color("6e5434")
const Haptics := preload("res://src/ui/HapticFeedback.gd")

var _gear_data: Dictionary = {}
var _clock := 0.0
var _shake_timer := 0.0
var _shake_offset := Vector2.ZERO
var _seal_landed := false
var _shockwave_radius := 0.0
var _shockwave_alpha := 0.0

var _scrim: ColorRect
var _pedestal: Control
var _icon_rect: TextureRect
var _seal_node: Control
var _name_label: Label
var _type_label: Label
var _stat_container: VBoxContainer
var _claim_btn: Control
var _rays_rotation := 0.0
var _motes: Array[Dictionary] = []


func _init(gear: Dictionary = {}) -> void:
	_gear_data = gear
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	if size.x <= 0 or size.y <= 0:
		size = Vector2(480, 800)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_init_motes()
	_build_ui()
	_start_ceremony()


func _init_motes() -> void:
	_motes.clear()
	for i in 24:
		var angle := randf() * TAU
		var dist := randf_range(80.0, 240.0)
		_motes.append({
			"pos": Vector2.from_angle(angle) * dist,
			"speed": randf_range(20.0, 50.0),
			"size": randf_range(2.0, 4.0),
			"alpha": randf_range(0.3, 0.9),
			"phase": randf() * TAU
		})


func _build_ui() -> void:
	if size.x <= 0 or size.y <= 0:
		size = Vector2(480, 800)
	# 1. 全屏沉浸遮罩
	_scrim = ColorRect.new()
	_scrim.size = size
	_scrim.color = Color(NIGHT.r, NIGHT.g, NIGHT.b, 0.0)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	# 2. 居中光芒与展台容器
	_pedestal = Control.new()
	_pedestal.size = Vector2(400, 440)
	_pedestal.pivot_offset = _pedestal.size * 0.5
	_pedestal.position = Vector2((size.x - _pedestal.size.x) * 0.5, (size.y - _pedestal.size.y) * 0.5 - 20)
	_pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pedestal)

	# 2.1 展台深黑漆木金框底衬
	var bg_card := Panel.new()
	bg_card.size = _pedestal.size
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("16121c", 0.94)
	card_style.border_color = Color("c29a5b")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(6)
	bg_card.add_theme_stylebox_override("panel", card_style)
	_pedestal.add_child(bg_card)

	# 3. 顶部仪式文案
	var rarity: int = int(_gear_data.get("rarity", 4))
	var rname := G.equip_rarity_name(rarity)
	var ceremony_title := "%s神兵 · 启封" % rname if rarity >= 5 else ("%s宝具 · 现世" % rname if rarity == 4 else "%s神装 · 突破" % rname)
	var title_l := G.gold_label(ceremony_title, G.FS_LG, false, G.GOLD_BRIGHT, true)
	title_l.position = Vector2(0, 16)
	title_l.size = Vector2(_pedestal.size.x, 32)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pedestal.add_child(title_l)

	# 4. 展台中央器物台与装备图标
	var stage_center := Vector2(_pedestal.size.x * 0.5, 125.0)

	var plinth := PlinthGlow.new()
	plinth.size = Vector2(110, 110)
	plinth.position = stage_center - plinth.size * 0.5
	plinth.hue = _rarity_color(rarity)
	_pedestal.add_child(plinth)

	_icon_rect = TextureRect.new()
	_icon_rect.size = Vector2(80, 80)
	_icon_rect.pivot_offset = _icon_rect.size * 0.5
	_icon_rect.position = stage_center - _icon_rect.size * 0.5
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var tpl_id := String(_gear_data.get("tpl", "tpl_sword_relic"))
	var icon_tex: Texture2D = preload("res://src/ui/ReviewFixUI.gd").item(tpl_id)
	if icon_tex == null:
		icon_tex = preload("res://src/ui/ReviewFixUI.gd").item("tpl_" + tpl_id + "_basic")
	if icon_tex == null:
		icon_tex = preload("res://src/ui/ReviewFixUI.gd").item("tpl_sword_relic")
	if icon_tex == null:
		var tpl: Dictionary = G.equip_tpl(tpl_id)
		icon_tex = G.res_tex(String(tpl.get("icon", "")))
	_icon_rect.texture = icon_tex
	_pedestal.add_child(_icon_rect)

	# 5. 装备全称与类型
	var gear_name := String(_gear_data.get("name", G.equip_tpl(tpl_id).get("name", "宝具")))
	var lv := int(_gear_data.get("lv", 0))
	if lv > 0:
		gear_name += " +%d" % lv
	_name_label = G.serif_label(gear_name, 24, _rarity_color(rarity))
	_name_label.position = Vector2(0, 195)
	_name_label.size = Vector2(_pedestal.size.x, 34)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pedestal.add_child(_name_label)

	var type_desc := String(_gear_data.get("type_name", G.equip_slot_name(String(G.equip_tpl(tpl_id).get("slot", "weapon")))))
	_type_label = G.gold_label(type_desc + " · " + G.equip_rarity_name(rarity), G.FS_SM, false, G.TEXT_MUTED, false)
	_type_label.position = Vector2(0, 232)
	_type_label.size = Vector2(_pedestal.size.x, 22)
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pedestal.add_child(_type_label)

	# 6. 属性与词条气泡容器
	_stat_container = VBoxContainer.new()
	_stat_container.position = Vector2(40, 264)
	_stat_container.size = Vector2(_pedestal.size.x - 80, 80)
	_stat_container.add_theme_constant_override("separation", 6)
	_pedestal.add_child(_stat_container)

	var stats: Array = _gear_data.get("stats", ["基础攻击 +36", "暴击率 +5.0%"])
	for st_line in stats:
		var chip := _build_stat_chip(String(st_line))
		_stat_container.add_child(chip)

	# 7. 品质印章（初始在屏幕上方外，待动画震落）
	_seal_node = _build_seal(rarity)
	_seal_node.position = Vector2(stage_center.x + 36, -140)
	_seal_node.pivot_offset = Vector2(26, 26)
	_seal_node.rotation = -0.12
	_pedestal.add_child(_seal_node)

	# 8. 展台内“收下神兵”交互按钮
	_claim_btn = G.gold_button("收入囊中", 160, 42)
	_claim_btn.position = Vector2((_pedestal.size.x - 160) * 0.5, 372)
	_claim_btn.modulate.a = 0.0
	_claim_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_dismiss()
	)
	_pedestal.add_child(_claim_btn)


func _build_stat_chip(text: String) -> Control:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1e1924", 0.85)
	style.border_color = Color("5c4932")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", style)

	var l := Label.new()
	l.text = text
	l.theme_type_variation = "Chest_caption"
	l.add_theme_color_override("font_color", Color("f0e2cc"))
	l.add_theme_font_size_override("font_size", 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box


func _build_seal(rarity: int) -> Control:
	var seal := QualitySeal.new()
	seal.size = Vector2(52, 52)
	seal.words = G.equip_rarity_name(rarity)
	return seal


class QualitySeal extends Control:
	var words := "传说"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(2, 2, w - 4, h - 4), Color("941b16"))
		draw_rect(Rect2(0, 0, w, h), Color("e03d2b"), false, 1.5)
		draw_rect(Rect2(3, 3, w - 6, h - 6), Color("69100c"), false, 1.0)
		var font: Font = G.font_serif
		draw_string(font, Vector2(10, 24), words.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe4cc"))
		draw_string(font, Vector2(28, 24), words.right(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe4cc"))
		draw_string(font, Vector2(10, 42), "印", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8b89e"))
		draw_string(font, Vector2(28, 42), "鉴", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8b89e"))


class PlinthGlow extends Control:
	var hue: Color = Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 46.0, Color(hue.r, hue.g, hue.b, 0.18))
		draw_circle(c, 36.0, Color(hue.r, hue.g, hue.b, 0.32))
		var r := 42.0
		var pts := PackedVector2Array()
		for i in 8:
			var ang := float(i) * TAU / 8.0 + PI / 8.0
			pts.append(c + Vector2.from_angle(ang) * r)
		draw_polygon(pts, PackedColorArray([Color("181420", 0.85)]))
		for i in 8:
			var next_i := (i + 1) % 8
			draw_line(pts[i], pts[next_i], Color("c29a5b", 0.75), 1.5)


func _start_ceremony() -> void:
	var is_review: bool = bool(G.get_meta("ui_review_mode", false)) or DisplayServer.get_name() == "headless" or (get_tree() != null and get_tree().current_scene != null and get_tree().current_scene.name == "ShotRunner")

	if is_review:
		# 测试与出图模式直接跳入高潮落地帧
		_scrim.color = Color(NIGHT.r, NIGHT.g, NIGHT.b, 0.88)
		_icon_rect.scale = Vector2.ONE
		_icon_rect.modulate.a = 1.0
		_seal_node.position = Vector2(_pedestal.size.x * 0.5 + 36, 120.0)
		_seal_node.scale = Vector2.ONE
		_claim_btn.modulate.a = 1.0
		_seal_landed = true
		_shockwave_radius = 52.0
		_shockwave_alpha = 0.75
		queue_redraw()
		return

	# 1. 全屏淡入暗夜底衬
	var tw_bg := create_tween()
	tw_bg.tween_property(_scrim, "color:a", 0.90, 0.24).set_trans(Tween.TRANS_QUAD)

	# 2. 装备图标缩放弹性登场
	_icon_rect.scale = Vector2(0.2, 0.2)
	_icon_rect.modulate.a = 0.0
	var tw_icon := create_tween()
	tw_icon.set_parallel(true)
	tw_icon.tween_property(_icon_rect, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_icon.tween_property(_icon_rect, "modulate:a", 1.0, 0.22)
	tw_icon.chain().tween_property(_icon_rect, "scale", Vector2.ONE, 0.12)

	# 3. 印章加速震落（0.36秒后触发）
	var tw_seal := create_tween()
	tw_seal.tween_interval(0.36)
	var land_pos := Vector2(_pedestal.size.x * 0.5 + 36, 120.0)
	tw_seal.tween_property(_seal_node, "position", land_pos, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_seal.parallel().tween_property(_seal_node, "scale", Vector2(1.6, 1.6), 0.26)
	tw_seal.tween_callback(func():
		_trigger_seal_impact()
	)
	tw_seal.tween_property(_seal_node, "scale", Vector2(0.92, 0.92), 0.08)
	tw_seal.tween_property(_seal_node, "scale", Vector2.ONE, 0.10)

	# 4. 按钮淡入
	var tw_btn := create_tween()
	tw_btn.tween_interval(0.7)
	tw_btn.tween_property(_claim_btn, "modulate:a", 1.0, 0.2)


func _trigger_seal_impact() -> void:
	_seal_landed = true
	_shake_timer = 0.24
	_shockwave_radius = 12.0
	_shockwave_alpha = 1.0

	var tw_wave := create_tween()
	tw_wave.set_parallel(true)
	tw_wave.tween_property(self, "_shockwave_radius", 140.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_wave.tween_property(self, "_shockwave_alpha", 0.0, 0.35)

	# 触觉强震与金铁沉鸣音效
	Haptics.heavy()
	Audio.sfx("level_up", 0.0)


func _process(delta: float) -> void:
	_clock += delta
	_rays_rotation += delta * 0.25

	# 震动阻尼衰减
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		var shake_mag := (_shake_timer / 0.24) * 5.0
		_shake_offset = Vector2(randf_range(-shake_mag, shake_mag), randf_range(-shake_mag, shake_mag))
	else:
		_shake_offset = Vector2.ZERO

	# 展台轻微呼吸悬停
	var bob := sin(_clock * 2.4) * 3.0
	_pedestal.position = Vector2((size.x - _pedestal.size.x) * 0.5, (size.y - _pedestal.size.y) * 0.5 - 20) + _shake_offset + Vector2(0, bob)

	queue_redraw()


func _draw() -> void:
	var stage_center := _pedestal.position + Vector2(_pedestal.size.x * 0.5, 170.0)
	var rarity: int = int(_gear_data.get("rarity", 4))
	var hue: Color = _rarity_color(rarity)

	# 1. 动态旋转光芒射线（14条辐射状柔和光条）
	var num_rays := 14
	var max_ray_len := 220.0
	for i in num_rays:
		var angle := _rays_rotation + float(i) * TAU / float(num_rays)
		var ray_dir := Vector2.from_angle(angle)
		var perp := Vector2(-ray_dir.y, ray_dir.x) * 14.0
		var pts := PackedVector2Array([
			stage_center,
			stage_center + ray_dir * max_ray_len + perp,
			stage_center + ray_dir * max_ray_len - perp
		])
		draw_colored_polygon(pts, Color(hue.r, hue.g, hue.b, 0.08))

	# 2. 汇聚与升腾光粒
	for mote in _motes:
		var pos: Vector2 = mote.pos
		mote.pos += Vector2(0, -mote.speed * 0.016)
		if mote.pos.length() > 240.0 or mote.pos.y < -180.0:
			mote.pos = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 180.0)
		var draw_p: Vector2 = stage_center + (mote.pos as Vector2)
		var mote_alpha := float(mote.alpha) * (0.6 + 0.4 * sin(_clock * 3.0 + float(mote.phase)))
		draw_circle(draw_p, float(mote.size), Color(hue.r, hue.g, hue.b, mote_alpha))

	# 3. 展台中央器物八角光台
	draw_circle(stage_center, 64.0, Color("14111a", 0.95))
	draw_arc(stage_center, 64.0, 0, TAU, 48, BRONZE, 2.0)
	draw_arc(stage_center, 60.0, 0, TAU, 48, Color(hue.r, hue.g, hue.b, 0.55), 1.5)

	# 4. 印章着陆冲击波
	if _shockwave_alpha > 0.01:
		var seal_impact_center := _pedestal.position + _seal_node.position + _seal_node.pivot_offset
		draw_arc(seal_impact_center, _shockwave_radius, 0, TAU, 36, Color(hue.r, hue.g, hue.b, _shockwave_alpha), 2.5)


func _rarity_color(rarity: int) -> Color:
	match rarity:
		3: return Color("a273c9") # 紫色史诗
		4: return Color("f0a030") # 橙色传说
		5: return Color("e5422b") # 传世神兵
		_: return Color("c29a5b")


func _dismiss() -> void:
	Haptics.light()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_pedestal, "scale", Vector2(0.92, 0.92), 0.18)
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free()
	)
