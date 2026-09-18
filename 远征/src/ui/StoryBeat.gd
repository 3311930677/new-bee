# StoryBeat.gd —— 剧情演出层（首领前「对峙」/ 战后「余韵」）
# 与 Prologue 的"卷轴翻页"不同：这是"字幕式"演出——全屏压暗 + 首领剪影 + 台词逐行淡入。
# 交互：点任意处/回车 = 快进（全部显示）；再点 = 结束；右上「跳过」直接结束。
# 文案全部来自 G.boss_beat_lines（data/lore.json 的 themes.<id>.boss_intro / boss_outro），代码不写死句子。
extends Control

signal finished

const VIEW_W := 480.0
const VIEW_H := 800.0

var theme_id := ""
var kind := "intro"            # intro=对峙（暗红压迫）/ outro=余韵（金灰）
var on_done := Callable()      # 演完回调（切战斗 / 回奖励流程）
## 测试接口：置 true 时一次铺满全部台词（VerifyLore 直接推进，不等动画）
var instant := false

var _lines: Array = []
var _rows: Array[Control] = []
var _revealed := 0
var _done := false


func setup(theme: String, beat_kind: String) -> void:
	theme_id = theme
	kind = beat_kind


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Audio.sfx("ui_open")
	_lines = G.boss_beat_lines(theme_id, kind)
	_build()
	_play_reveal()


# ---------- 构建 ----------
func _build() -> void:
	var is_intro := kind == "intro"

	# 压暗底：intro 暗红（压迫感），outro 金灰（余韵）
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.02, 0.02, 0.88) if is_intro else Color(0.05, 0.04, 0.02, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_build_silhouette(is_intro)

	# 地名小字 + 首领名（大字）
	var sub := G.gold_label(
		G.world_name(theme_id) + (" · 碑 前 对 峙" if is_intro else " · 碑 灵 低 语"),
		G.FS_XS, false, Color("cfb98a", 0.85), false)
	sub.position = Vector2(0, 466)
	sub.custom_minimum_size = Vector2(VIEW_W, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)

	var title := G.serif_label(G.theme_boss_name(theme_id), G.FS_LG + 6,
		Color("e8c890") if is_intro else Color("ded0ae"))
	title.position = Vector2(0, 488)
	title.custom_minimum_size = Vector2(VIEW_W, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# 台词区：左对齐逐行淡入（居中排长句会参差不齐，左对齐读起来像字幕）
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.position = Vector2(60, 548)
	box.custom_minimum_size = Vector2(360, 160)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	for ln in _lines:
		var l := G.text_label(String(ln), G.FS_MD, Color("efe3c8"))
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size = Vector2(360, 0)
		l.modulate.a = 0.0
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
		_rows.append(l)

	var hint := G.gold_label("轻触继续 · 右上「跳过」", G.FS_XS, false, Color("cfb98a", 0.7), false)
	hint.position = Vector2(0, 748)
	hint.custom_minimum_size = Vector2(VIEW_W, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	var skip := G.gold_button("跳 过", 96, 34, G.FS_XS)
	skip.position = Vector2(VIEW_W - 108, 26)
	skip.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_skip())
	add_child(skip)

	# 点任意处推进（与序章同一个操作习惯）
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_advance())


## 首领剪影：战斗内同款精灵放大、压成"影子"；缺素材时回退成一团暗影（不留白）
func _build_silhouette(is_intro: bool) -> void:
	var art_h := 400.0
	var boss_id := G.theme_boss_id(theme_id)
	var tex: Texture2D = G.res_tex(boss_id) if boss_id != "" else null
	if tex == null:
		var shade := Panel.new()
		shade.position = Vector2(VIEW_W * 0.5 - 110.0, 110)
		shade.custom_minimum_size = Vector2(220, 220)
		shade.size = Vector2(220, 220)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.06, 0.06, 0.9)
		sb.set_corner_radius_all(110)
		shade.add_theme_stylebox_override("panel", sb)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		return
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(VIEW_W, art_h)
	pic.size = Vector2(VIEW_W, art_h)
	pic.position = Vector2(0, 80)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target := Color(0.46, 0.32, 0.30) if is_intro else Color(0.84, 0.78, 0.60)
	pic.modulate = Color(target.r, target.g, target.b, 0.0)
	add_child(pic)
	# 从暗处缓缓浮现（不闪入）+ 极缓推近（"凝视"感）
	pic.pivot_offset = Vector2(VIEW_W * 0.5, art_h * 0.5)
	pic.scale = Vector2(1.05, 1.05)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pic, "modulate:a", 0.92 if is_intro else 0.62, 0.9)\
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(pic, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)


# ---------- 逐行淡入 ----------
func _play_reveal() -> void:
	if _rows.is_empty():
		_revealed = 0
		return
	if instant:
		for l in _rows:
			l.modulate.a = 1.0
		_revealed = _rows.size()
		return
	for i in _rows.size():
		var tw := create_tween()
		tw.tween_interval(0.55 * float(i))
		tw.tween_property(_rows[i], "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func(): _revealed += 1)


func _advance() -> void:
	if _done:
		return
	if _revealed < _rows.size():
		# 快进：剩下的行全部立刻显示（连点两下就能开打，别让人干等动画）
		for l in _rows:
			if is_instance_valid(l):
				l.modulate.a = 1.0
		_revealed = _rows.size()
		return
	_finish()


func _skip() -> void:
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Audio.sfx("ui_confirm")
	finished.emit()
	if on_done.is_valid():
		on_done.call()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right"):
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()
