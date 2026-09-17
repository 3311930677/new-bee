# LoadScreen.gd —— 启动加载页：旧星空秘境背景回归 + 预热资源 + 最短 1s
# 流程：Main → 本页（预热 image 素材索引与常用纹理，分帧加载不卡帧）
#       → 完成（且距进场 ≥1s）→ Title。加载文案轮换一点行军趣味话。
extends Control

const TITLE_SCENE := "res://src/ui/Title.tscn"
const MIN_SECONDS := 1.0
const PER_FRAME := 9   # 每帧预热的纹理数（59 项实际引用 + 行走帧 ≈ 数十张，分帧绰绰有余）

var _queue: Array[String] = []
var _total := 0
var _done := false
var _t0 := 0.0
var _bar_fill := PanelContainer.new()
var _bar_l := Label.new()

# 行军小话：随进度轮换（0/25/50/75% 各一句）
const STAGES := [
	"整备行囊……",
	"点起篝火……",
	"擦拭兵器……",
	"查看星图……",
	"启程。",
]


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	_build()
	_collect_queue()


func _build() -> void:
	# 背景：enter.png 星空秘境（941×1672 → 480×853 底对齐，同 Title 的铺法）
	var tr := TextureRect.new()
	tr.texture = load("res://image/background/enter.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = Vector2(480, 480.0 * 1672.0 / 941.0)
	tr.position = Vector2(0, 800.0 - tr.size.y)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	# 上下渐隐，星空中央自然留白承载标题与进度
	for which in ["top", "bottom"]:
		var grad := TextureRect.new()
		grad.set_anchors_preset(Control.PRESET_FULL_RECT)
		grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := GradientTexture2D.new()
		var g := Gradient.new()
		if which == "top":
			g.colors = PackedColorArray([Color(0.02, 0.02, 0.05, 0.6), Color(0, 0, 0, 0.0)])
			g.offsets = PackedFloat32Array([0.0, 0.35])
		else:
			g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.02, 0.02, 0.05, 0.55)])
			g.offsets = PackedFloat32Array([0.6, 1.0])
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_LINEAR
		tex.fill_from = Vector2(0, 0 if which == "top" else 1)
		tex.fill_to = Vector2(0, 1 if which == "top" else 0)
		grad.texture = tex
		add_child(grad)

	# 标题（轻量版：大字 + 副题，不做菜单）
	var t := G.serif_label("远征", G.FS_HERO, Color("e8d5a8"), true)
	t.add_theme_font_override("font", G.spaced_font(10, true, true))
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 96)
	t.size = Vector2(480, 100)
	add_child(t)
	var sub := G.gold_label("EXPEDITION", G.FS_XS, false, Color("d8bd8a", 0.7))
	sub.add_theme_font_override("font", G.spaced_font(9, false))
	sub.position = Vector2(0, 196)
	sub.custom_minimum_size = Vector2(480, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	# 底部进度条：三段式贴图（与路线图 HP 条同款）
	var back := PanelContainer.new()
	var back_tex: Texture2D = G.res_tex("ui_kenney_hp_back")
	var fill_tex: Texture2D = G.res_tex("ui_kenney_hp_fill")
	if back_tex != null and fill_tex != null:
		var bsb := StyleBoxTexture.new()
		bsb.texture = back_tex
		bsb.texture_margin_left = 10.0
		bsb.texture_margin_right = 10.0
		bsb.texture_margin_top = 4.0
		bsb.texture_margin_bottom = 4.0
		bsb.content_margin_left = 3.0
		bsb.content_margin_top = 3.0
		bsb.content_margin_right = 3.0
		bsb.content_margin_bottom = 3.0
		back.add_theme_stylebox_override("panel", bsb)
		var fsb := StyleBoxTexture.new()
		fsb.texture = fill_tex
		fsb.texture_margin_left = 10.0
		fsb.texture_margin_right = 10.0
		fsb.texture_margin_top = 4.0
		fsb.texture_margin_bottom = 4.0
		_bar_fill.add_theme_stylebox_override("panel", fsb)
	else:
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color("2a2216")
		bsb.set_corner_radius_all(4)
		back.add_theme_stylebox_override("panel", bsb)
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Color("c69c4a")
		fsb.set_corner_radius_all(3)
		_bar_fill.add_theme_stylebox_override("panel", fsb)
	back.position = Vector2(96, 690)
	back.custom_minimum_size = Vector2(288, 18)
	_bar_fill.custom_minimum_size = Vector2(6.0, 12.0)
	back.add_child(_bar_fill)
	add_child(back)

	_bar_l = G.gold_label("", G.FS_XS, false, Color("d8c8a8"), false)
	_bar_l.position = Vector2(0, 664)
	_bar_l.custom_minimum_size = Vector2(480, 0)
	_bar_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_bar_l)


## 预热清单：素材索引全量（首扫建索引）+ 四人行走帧 + 主背景三张
func _collect_queue() -> void:
	G._build_res_index()
	for key in G._res_index:
		var p := String(G._res_index[key])
		if p.find("/ready/") != -1 or p.find("/source/") == -1:
			_queue.append(p)
	_queue.append("res://image/role/zs/pojun_walk_4dir.png")
	_queue.append("res://image/role/ck/chuanyang_walk_4dir.png")
	_queue.append("res://image/role/fs/shuangyu_walk_4dir.png")
	_queue.append("res://image/role/fz/chenxing_walk_4dir.png")
	_total = _queue.size()


func _process(_d: float) -> void:
	if _done:
		return
	for i in PER_FRAME:
		if _queue.is_empty():
			break
		load(_queue.pop_front() as String)
	var ratio := 0.0 if _total == 0 else clampf(float(_total - _queue.size()) / float(_total), 0.0, 1.0)
	_bar_fill.custom_minimum_size.x = maxf(6.0, 282.0 * ratio)
	var stage_i := mini(STAGES.size() - 1, int(ratio * float(STAGES.size())))
	_bar_l.text = "%s %d％" % [String(STAGES[stage_i]), roundi(ratio * 100.0)]
	if _queue.is_empty():
		_done = true   # 停轮询；等计时器补足 1s 再切
		var elapsed := float(Time.get_ticks_msec() - _t0) / 1000.0
		if elapsed >= MIN_SECONDS:
			get_tree().change_scene_to_file(TITLE_SCENE)
		else:
			var tw := create_tween()
			tw.tween_interval(MIN_SECONDS - elapsed)
			tw.tween_callback(func(): get_tree().change_scene_to_file(TITLE_SCENE))
