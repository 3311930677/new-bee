# CharSelect.gd —— 选人界面（模仿参考游戏：角色站金色圆台 + 选中光圈 + 信息面板）
extends Control

const FRAME := 128          # spritesheet 每帧 128×128
const IDLE_FRAMES := 4      # 第 0 行前 4 帧为待机
const SPRITE_SCALE := 1.05  # 帧 128 宽，卡片 120 宽，人物略大于卡片更饱满

const CARD_W := 120
const CARD_H := 400
const ROW_Y := 80
const PAD_Y := 306          # 圆台中心（卡片内 y）
const PAD_RX := 44.0        # 椭圆圆台横半径
const PAD_RY := 28.0        # 椭圆圆台纵半径
const ANIM_Y := PAD_Y - 6.0 - 63.0 * SPRITE_SCALE   # 人物帧中心（脚底落在台面上）

# 背景裁切区（与 480:800 同比例，避开下方抢眼的法师立绘）
const BG_CROP := Rect2(40, 13, 400, 667)
const BG_DIM := 110.0 / 255.0   # 顶部压暗叠加透明度

var _cards: Array[Control] = []
var _info: Dictionary = {}   # 信息面板节点引用
var _focus := 0
var _confirm_panel: Control = null


func _ready() -> void:
	_build_background()
	_build_header()
	_build_cards()
	_build_info_panel()
	_update_focus(0, false)


# ---------- 背景与标题 ----------
func _build_background() -> void:
	# 从入场背景裁出与 480:800 同比例的一块（去掉下方法师，避免与角色抢视线）
	var at := AtlasTexture.new()
	at.atlas = load("res://image/background/enter.png")
	at.region = BG_CROP
	var tr := TextureRect.new()
	tr.texture = at
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(480, 800)
	tr.modulate = Color(0.7, 0.7, 0.7)   # 压暗 30%
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	var dim := ColorRect.new()
	dim.color = Color(G.BG_DEEP.r, G.BG_DEEP.g, G.BG_DEEP.b, BG_DIM)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


func _build_header() -> void:
	# 棕色横幅标题（模仿参考：棕底 + 金字）
	var banner := PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-130, 26)   # 相对顶部中心锚点的偏移
	banner.custom_minimum_size = Vector2(260, 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.BANNER
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = G.GOLD
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	banner.add_theme_stylebox_override("panel", sb)
	add_child(banner)
	var title := G.gold_label("选择角色", 28, true, G.GOLD_BRIGHT)
	title.add_theme_font_override("font", G.spaced_font(10))
	banner.add_child(title)


# ---------- 角色卡（像素小人站金色圆台） ----------
func _build_cards() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(0, ROW_Y)
	row.custom_minimum_size = Vector2(480, CARD_H)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	for i in G.roles.size():
		var idx := i
		var role: Dictionary = G.roles[i]
		var card := Control.new()
		card.custom_minimum_size = Vector2(CARD_W, CARD_H)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(idx))
		card.mouse_entered.connect(func(): _update_focus(idx, true))
		row.add_child(card)

		# 1) 金色椭圆圆台（最底层，垫在人物脚下）
		var pad := _Pedestal.new()
		pad.position = Vector2(CARD_W / 2.0, PAD_Y)
		pad.rx = PAD_RX
		pad.ry = PAD_RY
		card.add_child(pad)

		# 2) 待机动画：帧以中心为原点，脚底落在台面上
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = _build_frames(role["id"])
		anim.animation = &"idle"
		anim.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		anim.position = Vector2(CARD_W / 2.0, ANIM_Y)
		anim.play(&"idle")
		card.add_child(anim)
		card.set_meta("anim", anim)

		# 3) 选中光圈（脚下椭圆魔法阵，外扩出圆台）
		var ring := _RingDrawer.new()
		ring.position = Vector2(CARD_W / 2.0, PAD_Y + 8)
		ring.rx = 58.0
		ring.ry = 34.0
		ring.visible = false
		card.add_child(ring)
		card.set_meta("ring", ring)

		# 4) 名字（绿）+ LV.1（橙）落在台面下方
		var n := G.gold_label(role["name"], 20, true, G.NAME_GREEN)
		n.add_theme_color_override("font_outline_color", Color("0a1f0a"))
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.position = Vector2(0, PAD_Y + PAD_RY + 16 - 15)
		n.size = Vector2(CARD_W, 30)
		card.add_child(n)

		var lv := G.gold_label("LV.1", 13, true, G.LV_ORANGE)
		lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lv.position = Vector2(0, PAD_Y + PAD_RY + 37 - 12)
		lv.size = Vector2(CARD_W, 24)
		card.add_child(lv)

		_cards.append(card)


## 从 spritesheet 重建 idle SpriteFrames（只取第 0 行 4 帧，其余行是攻击/受击等动作）
func _build_frames(role_id: String) -> SpriteFrames:
	var tex: Texture2D = load(G.role_dir(role_id) + role_id_map(role_id) + "_spritesheet.png")
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 5.0)
	frames.set_animation_loop(&"idle", true)
	for c in IDLE_FRAMES:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(c * FRAME, 0, FRAME, FRAME)
		frames.add_frame(&"idle", at)
	return frames


func role_id_map(id: String) -> String:
	match id:
		"zs": return "pojun"
		"ck": return "chuanyang"
		"fs": return "shuangyu"
		"fz": return "chenxing"
	return id


func _on_card_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _focus == idx:
			_open_confirm()
		else:
			_update_focus(idx, true)


# ---------- 信息面板（羊皮纸风，模仿参考） ----------
func _build_info_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-215, -200)   # 相对底部中心锚点的偏移
	panel.custom_minimum_size = Vector2(430, 190)
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.PARCHMENT
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(3)
	sb.border_color = G.GOLD
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)
	var rname := G.gold_label("破军", 23, true, G.BANNER)
	rname.add_theme_color_override("font_color", G.BANNER)
	rname.add_theme_color_override("font_outline_color", G.PARCHMENT)
	title_row.add_child(rname)
	var job := G.gold_label("战士 · 大剑", 15, false, Color("7a5a2e"))
	job.add_theme_color_override("font_color", Color("7a5a2e"))
	job.add_theme_color_override("font_outline_color", G.PARCHMENT)
	title_row.add_child(job)

	var desc := Label.new()
	desc.add_theme_font_override("font", G.font_reg)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", G.TEXT_DARK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(388, 0)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)

	var hint := G.gold_label("← → 切换 · 再点一次确认", 13, false, Color("7a6640"))
	hint.add_theme_color_override("font_outline_color", G.PARCHMENT)
	box.add_child(hint)

	_info = {"title": rname, "job": job, "desc": desc}


func _refresh_info() -> void:
	var role: Dictionary = G.get_role(G.roles[_focus]["id"])
	if role.is_empty():
		return
	_info["title"].text = role["name"]
	_info["job"].text = "%s · %s" % [role["job"], role["weapon"]]
	_info["desc"].text = role["desc"]


# ---------- 焦点与选中 ----------
func _update_focus(idx: int, sfx: bool) -> void:
	_focus = wrapi(idx, 0, _cards.size())
	for i in _cards.size():
		var card: Control = _cards[i]
		var ring: Node2D = card.get_meta("ring")
		var active := i == _focus
		ring.visible = active
		# 选中角色放大 + 提亮，未选中落回原尺寸并压暗
		var anim := card.get_meta("anim") as AnimatedSprite2D
		var target := Vector2(SPRITE_SCALE, SPRITE_SCALE) * (1.08 if active else 1.0)
		var target_mod := Color(1, 1, 1) if active else Color(0.62, 0.6, 0.66)
		var tw := card.create_tween()
		tw.set_parallel(true)
		tw.tween_property(anim, "scale", target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(anim, "modulate", target_mod, 0.12)
	_refresh_info()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm_panel != null:
		return
	if event.is_action_pressed("ui_right"):
		_update_focus(_focus + 1, true)
	elif event.is_action_pressed("ui_left"):
		_update_focus(_focus - 1, true)
	elif event.is_action_pressed("ui_accept"):
		_open_confirm()


# ---------- 起名确认弹窗 ----------
func _open_confirm() -> void:
	if _confirm_panel != null:
		return
	var role: Dictionary = G.get_role(G.roles[_focus]["id"])

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_confirm_panel = dim

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-180, -115)
	panel.custom_minimum_size = Vector2(360, 230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.PARCHMENT
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(3)
	sb.border_color = G.GOLD
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", sb)
	dim.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var t := G.gold_label("以 %s 之名出发" % role["name"], 22, true, G.BANNER)
	t.add_theme_color_override("font_color", G.BANNER)
	t.add_theme_color_override("font_outline_color", G.PARCHMENT)
	box.add_child(t)

	var le := LineEdit.new()
	le.text = String(role["name"])
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.max_length = 7
	le.custom_minimum_size = Vector2(300, 42)
	le.add_theme_font_override("font", G.font_reg)
	le.add_theme_font_size_override("font_size", 20)
	le.add_theme_color_override("font_color", G.TEXT_DARK)
	le.add_theme_color_override("caret_color", G.BANNER)
	box.add_child(le)
	le.grab_focus()

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	box.add_child(btn_row)

	var ok := G.menu_button("开始远征")
	var cancel := G.menu_button("返回")
	btn_row.add_child(ok)
	btn_row.add_child(cancel)

	ok.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			G.selected_role = role["id"]
			G.player_name = le.text.strip_edges()
			if G.player_name.is_empty():
				G.player_name = role["name"]
			get_tree().change_scene_to_file("res://src/ui/GameHome.tscn")
	)
	cancel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			dim.queue_free()
			_confirm_panel = null
	)


# ---------- 自绘节点 ----------
## 金色装饰圆台（模仿参考：像素小人脚下的金色椭圆台）
class _Pedestal extends Node2D:
	var rx := 44.0
	var ry := 28.0
	func _draw() -> void:
		# 纵向压扁成椭圆，只需画同心圆
		var s := ry / rx
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, s))
		# 台面投影（暗）
		draw_circle(Vector2(0, 6.0 / s), rx * 1.05, Color(0, 0, 0, 0.35))
		# 外圈暗金
		draw_circle(Vector2.ZERO, rx, Color("8a6a28"))
		# 内圈亮金
		draw_circle(Vector2(0, -3.0 / s), rx * 0.8, Color("c9a44a"))
		# 台芯
		draw_circle(Vector2(0, -5.0 / s), rx * 0.5, Color("e8c668"))


## 选中光圈（脚下椭圆魔法阵）
class _RingDrawer extends Node2D:
	var rx := 58.0
	var ry := 34.0
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
