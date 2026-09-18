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

const NODE_META := {  # 类型 → [显示名, 节点色, 图标名]
	"normal": ["遭遇", Color("5f7186"), "node_normal"],
	"elite": ["精英", Color("7a4a9a"), "node_elite"],
	"event": ["事件", Color("c9a44a"), "node_event"],
	"chest": ["宝箱", Color("b87830"), "node_chest"],
	"shop": ["商店", Color("5a8a4a"), "node_shop"],
	"bonfire": ["篝火", Color("a04a3a"), "node_campfire"],
	"boss": ["首领", Color("8a2f2f"), "node_boss"],
}
const NODE_X := [120.0, 240.0, 360.0]
const LAYER_Y := {1: 492.0, 2: 380.0, 3: 268.0}
const BOSS_Y := 168.0
const START_Y := 604.0

var st := RunState.new()
var _field := Control.new()
var _lines: _RouteLines
var _layer_l := Label.new()
var _hp_fill := PanelContainer.new()   # 三段式木质血条填充（Kenney CC0），宽度即血量
var _hp_l := Label.new()
var _pot_l := Label.new()
var _trait_l := Label.new()
var _toast: Label = null
var _map: MapScene = null
var _cur_node: Dictionary = {}
var _end_ui: Control = null
var _settled := false     # 局结算入账只做一次
var _level_ups := 0       # 本次结算提升的等级数
var _new_world := ""      # 本次通关新解锁的世界名（无则空串）
var _bonus_gold := 0      # 表现加成金币（毫发无损 +10%）


func _ready() -> void:
	Audio.play_bgm("bgm_route")
	var cfg := pending_run
	pending_run = {}
	st.setup(cfg)
	_build()


# ================= 布局 =================
func _build() -> void:
	# 底：暗石台（卷轴压在上面，边缘露出的就是这层）
	var tc := TableCache.theme_config(st.theme)
	var tint := Color(String(tc.get("tint", "ffffff")))
	var bg := ColorRect.new()
	bg.color = Color(tint.r * 0.12, tint.g * 0.10, tint.b * 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 羊皮纸卷轴：素材 971×1619 与本屏 480×800 同为 3:5，铺满不变形
	var scroll: Texture2D = load("res://image/generated_001_100/source/067_bg_route.png")
	if scroll != null:
		var tr := TextureRect.new()
		tr.texture = scroll
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		# 主题染色：羊皮纸被该秘境的色调轻轻浸过，一局一个"气味"
		var wash := ColorRect.new()
		wash.color = Color(tint.r, tint.g, tint.b, 0.15)
		wash.set_anchors_preset(Control.PRESET_FULL_RECT)
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wash)

	# 暗角：把视线收在中间的路线带，同时让卷轴边缘融进石台
	var gtex := GradientTexture2D.new()
	var gg := Gradient.new()
	gg.colors = PackedColorArray([Color(0.10, 0.06, 0.03, 0.0), Color(0.10, 0.06, 0.03, 0.30)])
	gg.offsets = PackedFloat32Array([0.0, 1.0])
	gtex.gradient = gg
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.46)
	gtex.fill_to = Vector2(0.5, 1.02)
	var glow := TextureRect.new()
	glow.texture = gtex
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

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

	_layer_l = G.gold_label("", G.FS_XS, false, Color("5a4020"), false)  # 卷轴上是浅底，金字看不见，改用墨褐
	_layer_l.position = Vector2(0, 78)
	_layer_l.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(_layer_l)

	var quit := _chip("放弃远征")
	quit.position = Vector2(VIEW_W - 96, 16)
	quit.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _map == null and _end_ui == null:
				G.go("res://src/ui/GameHome.tscn"))
	add_child(quit)


func _chip(text: String) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(84, 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.10, 0.05, 0.78)
	# 手绘感：四角半径刻意不一致（6/4/7/3），不要做成一个规整的圆角矩形
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 7
	sb.corner_radius_bottom_right = 3
	sb.set_border_width_all(1)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.36)
	G._apply_shadow(sb, 4.0, 2.0, 0.34)
	root.add_theme_stylebox_override("panel", sb)
	root.add_child(G.gold_label(text, G.FS_XS, false, Color("e6c684"), false))
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
	# 三段式血条（Kenney CC0）：银边轨道 + 陶红填充，两端帽不拉伸、中段平铺
	var back_tex: Texture2D = G.res_tex("ui_kenney_hp_back")
	var fill_tex: Texture2D = G.res_tex("ui_kenney_hp_fill")
	if back_tex != null and fill_tex != null:
		var back_sb := StyleBoxTexture.new()
		back_sb.texture = back_tex
		back_sb.texture_margin_left = 10.0
		back_sb.texture_margin_right = 10.0
		back_sb.texture_margin_top = 4.0
		back_sb.texture_margin_bottom = 4.0
		back_sb.content_margin_left = 3.0
		back_sb.content_margin_top = 3.0
		back_sb.content_margin_right = 3.0
		back_sb.content_margin_bottom = 3.0
		hp_bar.add_theme_stylebox_override("panel", back_sb)
		hp_bar.custom_minimum_size = Vector2(192, 18)
		hp_row.add_child(hp_bar)
		var fill_sb := StyleBoxTexture.new()
		fill_sb.texture = fill_tex
		fill_sb.texture_margin_left = 10.0
		fill_sb.texture_margin_right = 10.0
		fill_sb.texture_margin_top = 4.0
		fill_sb.texture_margin_bottom = 4.0
		_hp_fill.add_theme_stylebox_override("panel", fill_sb)
		_hp_fill.custom_minimum_size = Vector2(186, 12)
	else:
		# 素材缺失回退：深色轨道 + 陶红平色
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
		var fill_flat := StyleBoxFlat.new()
		fill_flat.bg_color = Color("c05a3a")
		fill_flat.set_corner_radius_all(3)
		_hp_fill.add_theme_stylebox_override("panel", fill_flat)
		_hp_fill.custom_minimum_size = Vector2(186, 14)
	hp_bar.add_child(_hp_fill)
	_hp_l = G.gold_label("", G.FS_XS, false, Color("5a3a1e"), false)
	_hp_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_row.add_child(_hp_l)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	box.add_child(info_row)
	# 药剂小瓶图标 + 余量；词条用双刃图标（本局构筑的记号）
	var pot_icon := TextureRect.new()
	var pot_tex: Texture2D = G.res_tex("itm_potion_hp_m")
	if pot_tex != null:
		pot_icon.texture = pot_tex
		pot_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pot_icon.custom_minimum_size = Vector2(22, 22)
		pot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pot_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_row.add_child(pot_icon)
	_pot_l = G.gold_label("", G.FS_SM, false, Color("7a5a2e"), false)
	info_row.add_child(_pot_l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	info_row.add_child(gap)
	var tr_icon := TextureRect.new()
	var tr_tex: Texture2D = G.res_tex("icon_double_edge")
	if tr_tex != null:
		tr_icon.texture = tr_tex
		tr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_icon.custom_minimum_size = Vector2(22, 22)
		tr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_row.add_child(tr_icon)
	_trait_l = G.gold_label("", G.FS_SM, false, Color("7a5a2e"), false)
	info_row.add_child(_trait_l)


# ================= 状态刷新 =================
func _refresh() -> void:
	var cur := st.current_layer()
	_layer_l.text = ("第 %d 层 · 点亮节点前进" % cur) if cur <= 3 else "抵达首领 · 决战"
	# 节点状态
	for c in _field.get_children():
		if c is _RouteNode:
			(c as _RouteNode).refresh(cur)
	# 虚线预览的目标层＝当前可点的这一层，不传的话永远只画最底层的支路
	_lines.cur_layer = cur
	_lines.queue_redraw()
	# HP
	var m := st.max_hp()
	var hp := m if st.hp < 0 else st.hp
	_hp_fill.custom_minimum_size.x = maxf(8.0, 186.0 * clampf(float(hp) / float(m), 0.0, 1.0))
	_hp_l.text = "%d / %d" % [hp, m]
	_pot_l.text = "×%d" % st.potions
	_trait_l.text = "×%d" % st.traits.size()


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
	# 全类型统一落地探索大地图（§2.7）：战斗节点有怪，非战斗节点有交互物件
	_cur_node = nd
	_start_explore(nd)


# ================= 战斗节点（MapScene 探索覆盖层） =================
func _start_explore(nd: Dictionary) -> void:
	MapScene.pending_cfg = {"node": nd, "run": st}
	var packed: PackedScene = load("res://src/explore/MapScene.tscn")
	_map = packed.instantiate()
	_map.map_finished.connect(_on_map_finished)
	add_child(_map)


## 探索层结束：cleared（走传送阵）/ defeat（战斗失利）/ exited（中途撤离，节点进度保留）
func _on_map_finished(map_result: String) -> void:
	var is_boss := int(_cur_node.get("layer", 1)) == 4
	_map.queue_free()
	_map = null
	if map_result == "exited":
		# 撤离：不判定通关、不结算、不结束本局——回到路线图，节点可再次进入
		_toast_msg("已撤离本节点")
		_refresh()
		return
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
	# 结算入账钱包并落盘（战败亦保留——失败无惩罚；_settled 防重复）
	if not _settled:
		_settled = true
		# 表现加成：通关且结算时满血（整局毫发无损）→ 金币 +10%
		_bonus_gold = int(float(st.gold) * 0.10) \
			if win and (st.hp < 0 or st.hp >= st.max_hp()) else 0
		G.deposit(st.gold + _bonus_gold, st.expedition, st.soul, st.honor)
		_level_ups = G.gain_exp(st.exp)
		if win:
			_new_world = G.on_world_cleared(st.theme)
	_end_ui = Control.new()
	_end_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_end_ui)

	# 通关结算底衬：整屏接管，走统一工厂（深棕 + 暗角 + 斜纹）
	G.veil(_end_ui, G.VEIL_TAKEOVER_A)

	var panel := G.parchment_box(360, 372, 22.0)
	panel.position = Vector2(60, 196)
	_end_ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	box.add_child(G.serif_label("远征完成" if win else "远征失利", G.FS_HERO,
		Color("6a8a4a") if win else Color("8a4a3a")))
	box.add_child(G.gold_label("历经 %d 场战斗" % st.node_seq, G.FS_SM, false, Color("7a5a2e"), false))
	box.add_child(G.gold_label("金币 +%d" % st.gold, G.FS_MD, false, Color("8a6a34"), false))
	if _bonus_gold > 0:
		box.add_child(G.gold_label("毫发无损 · 加成 +%d" % _bonus_gold, G.FS_SM, true, Color("a06020")))
	box.add_child(G.gold_label("远征币 +%d" % st.expedition, G.FS_MD, false, Color("8a6a34"), false))
	box.add_child(G.gold_label("灵魂石 +%d" % st.soul, G.FS_MD, false, Color("8a6a34"), false))
	box.add_child(G.gold_label("荣　誉 +%d" % st.honor, G.FS_MD, false, Color("8a6a34"), false))
	box.add_child(G.gold_label("经验 +%d" % st.exp, G.FS_MD, false, Color("8a6a34"), false))
	if _level_ups > 0:
		box.add_child(G.gold_label("等级提升 ×%d → LV %d" % [_level_ups, int(G.prog.get("level", 1))],
			G.FS_MD, true, Color("a06020")))
	if _new_world != "":
		box.add_child(G.gold_label("新世界解锁：%s" % _new_world, G.FS_MD, true, Color("6a8a4a")))
	box.add_child(G.gold_label("词条 ×%d（随局重置）" % st.traits.size(), G.FS_SM,
		false, Color("8a6a34"), false))

	var btn := G.gold_button("回 到 主 城", 200, 48)
	btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.go("res://src/ui/GameHome.tscn"))
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
		G.go("res://src/ui/GameHome.tscn")


# ================= 局部绘制 =================
## 已走路径连线（墨底 + 金线折线）+ 下一层三条支路的虚线预览
class _RouteLines extends Node2D:
	var route_ref: Dictionary = {}
	var cur_layer := 1

	## 虚线：手动切段，draw_line 没有 dash 参数
	func _dashed(a: Vector2, b: Vector2, col: Color, w: float, dash: float, gap: float) -> void:
		var total := a.distance_to(b)
		if total <= 0.01:
			return
		var dir := (b - a) / total
		var t := 0.0
		while t < total:
			var e: float = minf(t + dash, total)
			draw_line(a + dir * t, a + dir * e, col, w)
			t = e + gap

	func _draw() -> void:
		if route_ref.is_empty():
			return
		var layers: Array = route_ref.get("layers", [])
		var boss: Dictionary = route_ref.get("boss", {})
		var start := Vector2(240.0, RouteScene.START_Y)
		var ink := Color(0.22, 0.14, 0.07, 0.55)   # 墨色底：金线直接压在浅羊皮纸上会发飘
		var gold := Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.95)

		# 已走路径：起点 → 各层已清节点 → BOSS
		var pts: Array = [start]
		for l in layers.size():
			for n in layers[l]:
				var nd: Dictionary = n
				if bool(nd.get("cleared", false)):
					pts.append(Vector2(RouteScene.NODE_X[int(nd.get("index", 1))],
						RouteScene.LAYER_Y[int(nd.get("layer", 1))]))
					break
		if bool(boss.get("cleared", false)):
			pts.append(Vector2(240.0, RouteScene.BOSS_Y))

		var prev: Vector2 = pts[0]
		for i in range(1, pts.size()):
			draw_line(prev, pts[i], ink, 7.0)
			draw_line(prev, pts[i], gold, 3.0)
			prev = pts[i]

		# 下一层的三条支路：虚线，把"每层 3 选 1"讲明白，也让画面不至于只有一条孤线
		var targets: Array = []
		if cur_layer >= 4:
			targets = [boss]
		elif cur_layer - 1 >= 0 and cur_layer - 1 < layers.size():
			targets = layers[cur_layer - 1]
		var from: Vector2 = pts[pts.size() - 1]
		for n in targets:
			var nd: Dictionary = n
			if bool(nd.get("cleared", false)):
				continue
			var pos := Vector2(240.0, RouteScene.BOSS_Y) if int(nd.get("layer", 0)) == 4 \
				else Vector2(RouteScene.NODE_X[int(nd.get("index", 1))],
					RouteScene.LAYER_Y[int(nd.get("layer", 1))])
			_dashed(from, pos, Color(0.24, 0.16, 0.08, 0.34), 2.0, 7.0, 6.0)


## 路线节点：徽章图（node_* 素材）+ 状态环（当前层金环 / 未达压灰 / 已清盖 ✓ 牌）
class _RouteNode extends Control:
	var node_data := {}
	var state := "future"  # future / current / done
	var _icon: Texture2D = null

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
			_draw_start(center)
			return
		var meta: Array = RouteScene.NODE_META.get(t, ["？", Color.GRAY, ""])
		var is_boss := t == "boss"
		var r := 30.0 if is_boss else 25.0   # 图标半宽
		var alpha := 1.0 if state != "future" else 0.42

		# 落地投影：贴纸压在羊皮纸上的厚度
		draw_set_transform(center + Vector2(0, 4.0), 0.0, Vector2(1.0, 0.86))
		draw_circle(Vector2.ZERO, r + 2.0, Color(0.0, 0.0, 0.0, 0.32 * alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# 徽章图标（node_*；无素材回退蜡封色圆）
		if _icon == null:
			_icon = G.res_tex(String(meta[2]))
		if _icon != null:
			var rect := Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
			if state == "future":
				draw_texture_rect(_icon, rect, false, Color(0.52, 0.52, 0.52, 0.6))
			else:
				draw_texture_rect(_icon, rect, false, Color(1, 1, 1, alpha))
		else:
			var col: Color = meta[1]
			draw_circle(center, r, Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, alpha))
			draw_circle(center - Vector2(r * 0.16, r * 0.2), r * 0.82, Color(
				minf(col.r * 1.15, 1.0), minf(col.g * 1.15, 1.0), minf(col.b * 1.15, 1.0), alpha))

		# 当前层：金环 + 四方位短刻线（罗盘感，不是 PPT 高亮圈）
		if state == "current":
			var ring := Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.8)
			draw_arc(center, r + 5.0, 0.0, TAU, 44, Color(0.0, 0.0, 0.0, 0.22), 4.2)
			draw_arc(center, r + 5.0, 0.0, TAU, 44, ring, 2.4)
			for i in 4:
				var a := PI * 0.5 * float(i) + PI * 0.25
				var d := Vector2(cos(a), sin(a))
				draw_line(center + d * (r + 5.0), center + d * (r + 10.0), ring, 2.0)

		# 类型小字：图标下方，先影后字
		var font := G.font_bold
		var label := String(meta[0])
		var fs := 13
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var tp := Vector2(center.x - ts.x / 2.0, center.y + r + fs + 2.0)
		draw_string(font, tp + Vector2(0, 1.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs,
			Color(0.0, 0.0, 0.0, 0.4 * alpha))
		draw_string(font, tp, label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs,
			Color(0.99, 0.95, 0.86, alpha))

		# 已清：右上一枚小金牌 ✓
		if state == "done":
			var bp := center + Vector2(r * 0.72, -r * 0.72)
			var ts2 := font.get_string_size("✓", HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
			draw_circle(bp + Vector2(0, 1.0), 9.0, Color(0.0, 0.0, 0.0, 0.35))
			draw_circle(bp, 9.0, Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.96))
			draw_arc(bp, 9.0, PI * 1.0, PI * 1.7, 12, Color(1.0, 0.95, 0.78, 0.7), 1.4)
			draw_string(font, bp - ts2 / 2.0 + Vector2(0, ts2.y * 0.5), "✓",
				HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color("3a2a14"))

	## 起点：node_start 徽章 + 「起点」小字（明确"这里不动"）
	func _draw_start(center: Vector2) -> void:
		draw_set_transform(center + Vector2(0, 4.0), 0.0, Vector2(1.0, 0.8))
		draw_circle(Vector2.ZERO, 19.0, Color(0.0, 0.0, 0.0, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _icon == null:
			_icon = G.res_tex("node_start")
		if _icon != null:
			draw_texture_rect(_icon, Rect2(center - Vector2(17, 17), Vector2(34, 34)), false)
		else:
			draw_circle(center, 16.0, Color(0.42, 0.32, 0.20))
			draw_circle(center - Vector2(2.4, 3.0), 12.5, Color(0.50, 0.39, 0.24))
		var font := G.font_bold
		var ts := font.get_string_size("起点", HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		var tp := Vector2(center.x - ts.x / 2.0, center.y + 30.0)
		draw_string(font, tp + Vector2(0, 1.0), "起点", HORIZONTAL_ALIGNMENT_CENTER, -1, 13,
			Color(0.0, 0.0, 0.0, 0.40))
		draw_string(font, tp, "起点", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color("f2e3c0"))
