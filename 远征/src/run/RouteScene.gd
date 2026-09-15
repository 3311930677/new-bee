# RouteScene.gd —— 远征路线图（玩法文档 §2.6；阶段 2.2）
# 职责：路线图选节点（每层 3 选 1 → BOSS）；战斗节点挂载 BattleScene 覆盖层并接管
#       battle_finished；非战斗节点（事件/宝箱/商店/篝火）极简快捷结算（#10 换正式交互）；
#       跨节点延续写回：HP / 药剂余量 / 换宠后出战位 / 词条保留整局。
class_name RouteScene
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0

## 场景切入前由调用方写入（GameHome 远征入口）
static var pending_run: Dictionary = {}

const NODE_META := {  # 类型 → [显示名, 节点色]
	"normal": ["遭遇", Color("5f7186")],
	"elite": ["精英", Color("7a4a9a")],
	"event": ["事件", Color("c9a44a")],
	"chest": ["宝箱", Color("b87830")],
	"shop": ["商店", Color("5a8a4a")],
	"bonfire": ["篝火", Color("a04a3a")],
	"boss": ["首领", Color("8a2f2f")],
}
const NODE_X := [120.0, 240.0, 360.0]
const LAYER_Y := {1: 492.0, 2: 380.0, 3: 268.0}
const BOSS_Y := 168.0
const START_Y := 604.0

var st := RunState.new()
var _rng := RandomNumberGenerator.new()
var _field := Control.new()
var _lines: _RouteLines
var _layer_l := Label.new()
var _hp_fill := ColorRect.new()
var _hp_l := Label.new()
var _pot_l := Label.new()
var _trait_l := Label.new()
var _toast: Label = null
var _map: MapScene = null
var _cur_node: Dictionary = {}
var _end_ui: Control = null


func _ready() -> void:
	var cfg := pending_run
	pending_run = {}
	st.setup(cfg)
	_rng.seed = st.run_seed ^ 0x5e11
	_build()


# ================= 布局 =================
func _build() -> void:
	# 背景：主题 tint 深染
	var tc := TableCache.theme_config(st.theme)
	var tint := Color(String(tc.get("tint", "ffffff")))
	var bg := ColorRect.new()
	bg.color = Color(tint.r * 0.18, tint.g * 0.18, tint.b * 0.22)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	_lines = _RouteLines.new()
	_lines.route_ref = st.route
	_field.add_child(_lines)

	# 起点
	var start := _RouteNode.new()
	start.node_data = {"type": "start", "layer": 0, "index": 1, "cleared": true}
	start.name = "node_0_1"
	start.size = Vector2(72, 40)
	start.position = Vector2(204, START_Y - 20)
	_field.add_child(start)

	# 3 层 × 3 节点
	var layers: Array = st.route.get("layers", [])
	for l in layers.size():
		var row: Array = layers[l]
		for i in row.size():
			_field.add_child(_make_node(row[i]))
	# BOSS
	_field.add_child(_make_node(st.route.get("boss", {})))

	_build_top(tint)
	_build_bottom()
	_refresh()


func _make_node(nd: Dictionary) -> Control:
	var c := _RouteNode.new()
	c.node_data = nd
	c.name = "node_%d_%d" % [int(nd.get("layer", 0)), int(nd.get("index", 0))]
	c.size = Vector2(64, 64)
	var pos := Vector2(240.0, BOSS_Y) if int(nd.get("layer", 0)) == 4 \
		else Vector2(NODE_X[int(nd.get("index", 1))], LAYER_Y[int(nd.get("layer", 1))])
	c.position = pos - Vector2(32, 32)
	c.gui_input.connect(_on_node_input.bind(nd))
	return c


func _build_top(tint: Color) -> void:
	var tc := TableCache.theme_config(st.theme)
	var b := G.banner_box("远征 · %s" % String(tc.get("name", "未知")), 300, 52)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.position = Vector2(-150, 22)
	add_child(b)

	_layer_l = G.gold_label("", G.FS_XS, false, Color("d9b96e"), false)
	_layer_l.position = Vector2(0, 78)
	_layer_l.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(_layer_l)

	var quit := _chip("放弃远征")
	quit.position = Vector2(VIEW_W - 96, 16)
	quit.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _map == null and _end_ui == null:
				get_tree().change_scene_to_file("res://src/ui/GameHome.tscn"))
	add_child(quit)


func _chip(text: String) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(84, 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.10, 0.05, 0.7)
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(1)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.3)
	root.add_theme_stylebox_override("panel", sb)
	root.add_child(G.gold_label(text, G.FS_XS, false, Color("d9b96e"), false))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root


func _build_bottom() -> void:
	# 底部状态条：HP 条 + 药剂 + 词条数（#9 换正式词条面板）
	var panel := G.parchment_box(432, 96, 16.0)
	panel.position = Vector2(24, 672)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	box.add_child(hp_row)
	var hp_title := G.gold_label("生命", G.FS_SM, false, Color("7a5a2e"), false)
	hp_row.add_child(hp_title)
	var hp_bar := PanelContainer.new()
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color("3a2a18")
	bar_sb.set_corner_radius_all(4)
	bar_sb.content_margin_left = 2.0
	bar_sb.content_margin_top = 2.0
	bar_sb.content_margin_right = 2.0
	bar_sb.content_margin_bottom = 2.0
	hp_bar.add_theme_stylebox_override("panel", bar_sb)
	hp_bar.custom_minimum_size = Vector2(190, 18)
	hp_row.add_child(hp_bar)
	_hp_fill.color = Color("c05a3a")
	_hp_fill.custom_minimum_size = Vector2(186, 14)
	hp_bar.add_child(_hp_fill)
	_hp_l = G.gold_label("", G.FS_XS, false, Color("5a3a1e"), false)
	_hp_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_row.add_child(_hp_l)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 24)
	box.add_child(info_row)
	_pot_l = G.gold_label("", G.FS_SM, false, Color("7a5a2e"), false)
	info_row.add_child(_pot_l)
	_trait_l = G.gold_label("", G.FS_SM, false, Color("7a5a2e"), false)
	info_row.add_child(_trait_l)


# ================= 状态刷新 =================
func _refresh() -> void:
	var cur := st.current_layer()
	_layer_l.text = ("第 %d / 4 层 · 点亮节点前进" % cur) if cur <= 3 else "抵达首领 · 决战"
	# 节点状态
	for c in _field.get_children():
		if c is _RouteNode:
			(c as _RouteNode).refresh(cur)
	_lines.queue_redraw()
	# HP
	var m := st.max_hp()
	var hp := m if st.hp < 0 else st.hp
	_hp_fill.custom_minimum_size.x = 186.0 * clampf(float(hp) / float(m), 0.0, 1.0)
	_hp_l.text = "%d / %d" % [hp, m]
	_pot_l.text = "药剂 ×%d" % st.potions
	_trait_l.text = "词条 ×%d" % st.traits.size()


# ================= 节点进入 =================
func _on_node_input(e: InputEvent, nd: Dictionary) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _map != null or _end_ui != null or st.finished:
		return
	if not st.node_reachable(int(nd.get("layer", 0))):
		return
	if bool(nd.get("cleared", false)):
		return
	_enter_node(nd)


func _enter_node(nd: Dictionary) -> void:
	_cur_node = nd
	match String(nd.get("type", "normal")):
		"normal", "elite", "boss":
			_start_explore(nd)
		"chest":
			var gold := int(TableCache.nodes_config().get("rewards", {}).get("chest", {}).get("gold", 200))
			st.gold += gold
			_quick_done("宝箱开启：金币 +%d" % gold)
		"event":
			var gold2 := _rng.randi_range(80, 150)
			st.gold += gold2
			_quick_done("旅人赠礼：金币 +%d" % gold2)
		"shop":
			var cap := int(TableCache.nodes_config().get("shop", {}).get("potion_cap", 3))
			if st.potions < cap:
				st.potions += 1
				_quick_done("商队补给：购得治疗药剂 ×1")
			else:
				_quick_done("商队补给：药剂已达上限，继续赶路")
		"bonfire":
			var heal_amt := st.bonfire_heal()
			st.heal(heal_amt)
			_quick_done("篝火休整：回复 %d 点生命" % heal_amt)


func _quick_done(msg: String) -> void:
	st.node_cleared(int(_cur_node.get("layer", 1)), int(_cur_node.get("index", 0)))
	_toast_msg(msg)
	_refresh()


# ================= 战斗节点（MapScene 探索覆盖层） =================
func _start_explore(nd: Dictionary) -> void:
	MapScene.pending_cfg = {"node": nd, "run": st}
	var packed: PackedScene = load("res://src/explore/MapScene.tscn")
	_map = packed.instantiate()
	_map.map_finished.connect(_on_map_finished)
	add_child(_map)


## 探索层结束：cleared（走传送阵）/ defeat（战斗失利）
func _on_map_finished(map_result: String) -> void:
	var is_boss := int(_cur_node.get("layer", 1)) == 4
	_map.queue_free()
	_map = null
	if map_result == "defeat":
		_show_end(false)
		return
	if is_boss:
		st.finished = true
		st.result = "clear"
		_show_end(true)
		return
	_refresh()


# ================= 局结束浮层 =================
func _show_end(win: bool) -> void:
	_end_ui = Control.new()
	_end_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_end_ui)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_ui.add_child(dim)

	var panel := G.parchment_box(360, 300, 22.0)
	panel.position = Vector2(60, 240)
	_end_ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	box.add_child(G.serif_label("远征完成" if win else "远征失利", G.FS_HERO,
		Color("6a8a4a") if win else Color("8a4a3a")))
	box.add_child(G.gold_label("历经 %d 场战斗" % st.node_seq, G.FS_SM, false, Color("7a5a2e"), false))
	box.add_child(G.gold_label("金币 +%d" % st.gold, G.FS_MD, false, Color("8a6a34"), false))
	box.add_child(G.gold_label("词条 ×%d（随局重置）" % st.traits.size(), G.FS_SM,
		false, Color("8a6a34"), false))

	var btn := G.gold_button("回 到 主 城", 200, 48)
	btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			get_tree().change_scene_to_file("res://src/ui/GameHome.tscn"))
	box.add_child(btn)
	_refresh()


# ================= 提示 =================
func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_MD, false, Color("ffe9b0"))
	_toast.position = Vector2(0, 640)
	_toast.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _map == null and _end_ui == null:
		get_tree().change_scene_to_file("res://src/ui/GameHome.tscn")


# ================= 局部绘制 =================
## 已走路径连线（金色折线）+ 当前层预览虚线
class _RouteLines extends Node2D:
	var route_ref: Dictionary = {}

	func _draw() -> void:
		if route_ref.is_empty():
			return
		var layers: Array = route_ref.get("layers", [])
		var boss: Dictionary = route_ref.get("boss", {})
		# 已走路径：起点 → 各层已选节点 → BOSS
		var prev := Vector2(240.0, 604.0)
		var gold := Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.8)
		for l in layers.size():
			var row: Array = layers[l]
			for n in row:
				var nd: Dictionary = n
				if bool(nd.get("cleared", false)):
					var pos := Vector2(RouteScene.NODE_X[int(nd.get("index", 1))],
						RouteScene.LAYER_Y[int(nd.get("layer", 1))])
					draw_line(prev, pos, gold, 3.0)
					prev = pos
					break
		if bool(boss.get("cleared", false)):
			draw_line(prev, Vector2(240.0, RouteScene.BOSS_Y), gold, 3.0)
			prev = Vector2(240.0, RouteScene.BOSS_Y)
		# 起点标记点
		draw_circle(prev, 5.0, gold)


## 路线节点（程序绘制圆徽；node_* 素材入库后热替换）
class _RouteNode extends Control:
	var node_data := {}
	var state := "future"  # future / current / done

	func refresh(cur_layer: int) -> void:
		var layer := int(node_data.get("layer", 0))
		if layer == 0:
			state = "done"  # 起点
		elif bool(node_data.get("cleared", false)):
			state = "done"
		elif layer == cur_layer:
			state = "current"
		else:
			state = "future"
		queue_redraw()

	func _draw() -> void:
		var t := String(node_data.get("type", "start"))
		var center := size / 2.0
		if t == "start":
			draw_circle(center, 16.0, Color("6a5a3a"))
			draw_circle(center, 12.0, Color("c9a44a"))
			return
		var meta: Array = RouteScene.NODE_META.get(t, ["？", Color.GRAY])
		var col: Color = meta[1]
		var r := 30.0 if t == "boss" else 24.0
		var alpha := 1.0 if state != "future" else 0.42
		# 底圆
		draw_circle(center + Vector2(0, 3), r, Color(0, 0, 0, 0.3 * alpha))
		draw_circle(center, r, Color(col.r, col.g, col.b, 0.35 * alpha))
		draw_circle(center, r - 4.0, Color(col.r, col.g, col.b, 0.55 * alpha))
		# 当前层呼吸金环
		if state == "current":
			var ring := Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.9)
			draw_arc(center, r + 5.0, 0.0, TAU, 40, ring, 2.0)
			draw_arc(center, r + 9.0, 0.0, TAU, 40, Color(ring.r, ring.g, ring.b, 0.35), 1.5)
		# 类型字
		var font := G.font_bold
		var label := String(meta[0])
		var fs := 16 if t == "boss" else 14
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, center - ts / 2.0 + Vector2(0, ts.y * 0.5 + fs * 0.25),
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1, 1, 1, alpha))
		# 已完成标记
		if state == "done" and t != "start":
			draw_string(font, center + Vector2(r - 14, -r + 16), "✓",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.95))
