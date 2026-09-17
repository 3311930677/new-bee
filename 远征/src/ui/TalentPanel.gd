# TalentPanel.gd —— 天赋树（三系×10 节点，每 5 级 1 点；节点连线程序绘制）
# 布局：三根竖列（狂战/坚壁/迅捷），tier 1 在底部、tier 10 在顶部；
# 点某 tier 需本系已投点 ≥ tier-1（G.talent_can_add 判定）。
class_name TalentPanel
extends Control

signal closed

const CONTENT_W := 408.0
const COL_W := 132.0
const NODE_D := 40.0
const TIER_STEP := 47.0
const TREE_TOP := 66.0          # tier10 中心 y
const BRANCH_HUES := {"fury": Color("c06040"), "guard": Color("5a8a5a"), "spirit": Color("4a7a9a")}

var _points_l: Label = null
var _info_l: Label = null
var _cols: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var banner := G.banner_box("天 赋 树", 240, 50)
	banner.position = Vector2(120, 30)
	add_child(banner)

	var panel := G.parchment_box(440, 620, 16.0)
	panel.position = Vector2(20, 96)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	# 顶行：剩余点数
	_points_l = G.gold_label("", G.FS_MD, true, Color("a06020"), false)
	_points_l.position = Vector2(0, 0)
	_points_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_child(_points_l)

	# 三系列
	_cols = Control.new()
	_cols.position = Vector2(0, 0)
	_cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_cols)
	var branches: Array = G.talents_cfg().get("branches", [])
	for i in branches.size():
		_build_branch(branches[i], i)

	# 底部信息行（点击节点后显示详情）
	_info_l = G.text_label("点击节点投入天赋点", G.FS_XS, Color("7a5a2e"))
	_info_l.position = Vector2(0, 548)
	_info_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	_info_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_info_l)

	var close_btn := G.gold_button("返 回", 130, 36, G.FS_MD)
	close_btn.position = Vector2(CONTENT_W / 2.0 - 65, 570)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(close_btn)

	_refresh()


func _build_branch(b: Dictionary, idx: int) -> void:
	var col_x := idx * (COL_W + 6.0)
	var bid := String(b.get("id", ""))
	var hue: Color = BRANCH_HUES.get(bid, Color("8a6a34"))

	var name_l := G.serif_label(String(b.get("name", "")), G.FS_MD, hue)
	name_l.custom_minimum_size = Vector2(COL_W, 0)
	name_l.position = Vector2(col_x, 24)
	_cols.add_child(name_l)

	# 连线：tier1→tier10 一条竖线（程序绘制）
	var line := _BranchLine.new()
	var nodes: Array = b.get("nodes", [])
	var top_y := TREE_TOP
	var bot_y := TREE_TOP + (nodes.size() - 1) * TIER_STEP
	line.p_from = Vector2(col_x + COL_W / 2.0, top_y)
	line.p_to = Vector2(col_x + COL_W / 2.0, bot_y)
	line.hue = hue
	_cols.add_child(line)

	# 节点：tier 1 在底部（倒序摆）
	for ni in nodes.size():
		var nd := nodes[ni] as Dictionary
		var tier := int(nd.get("tier", ni + 1))
		var cy := bot_y - (tier - 1) * TIER_STEP
		var btn := _node_button(nd, hue)
		btn.position = Vector2(col_x + COL_W / 2.0 - NODE_D / 2.0, cy - NODE_D / 2.0)
		_cols.add_child(btn)


func _node_button(nd: Dictionary, hue: Color) -> Control:
	var nid := String(nd.get("id", ""))
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(NODE_D, NODE_D)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("nid", nid)
	root.set_meta("hue", hue)
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_node(nid))
	_paint_node(root, nd, hue)
	return root


## 节点外观三态：已点满（亮金边+色系底）/ 可点（金边羊皮纸）/ 未解锁（灰）
func _paint_node(root: PanelContainer, nd: Dictionary, hue: Color) -> void:
	var nid := String(nd.get("id", ""))
	var cur := int((G.prog.get("talents", {}) as Dictionary).get(nid, 0))
	var mx := int(nd.get("max", 1))
	var can := G.talent_can_add(nid)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(NODE_D / 2.0))
	sb.set_border_width_all(2)
	if cur >= mx:
		sb.bg_color = hue
		sb.border_color = G.GOLD_BRIGHT
	elif can:
		sb.bg_color = Color("f0e2bc")
		sb.border_color = G.GOLD
	elif cur > 0:
		sb.bg_color = Color(hue.r, hue.g, hue.b, 0.45)
		sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5)
	else:
		sb.bg_color = Color("b8a884")
		sb.border_color = Color(0.3, 0.25, 0.15, 0.5)
	G._apply_shadow(sb, 2.0, 1.0, 0.25)
	root.add_theme_stylebox_override("panel", sb)
	for c in root.get_children():
		c.queue_free()
	var txt_col := G.TEXT_LIGHT if cur >= mx else G.TEXT_DARK
	var l := G.gold_label("%s\n%d/%d" % [String(nd.get("name", "")), cur, mx],
		G.FS_XS - 1, true, txt_col, cur >= mx)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)


func _on_node(nid: String) -> void:
	var nd := G.talent_node(nid)
	if nd.is_empty():
		return
	if G.talent_add(nid):
		_info_l.text = "%s · %s" % [String(nd.get("name", "")), String(nd.get("desc", ""))]
	else:
		var cur := int((G.prog.get("talents", {}) as Dictionary).get(nid, 0))
		if cur >= int(nd.get("max", 1)):
			_info_l.text = "「%s」已点满" % String(nd.get("name", ""))
		elif G.talent_points_left() <= 0:
			_info_l.text = "天赋点不足（每 5 级获得 1 点）"
		else:
			_info_l.text = "需先在本系投入 %d 点" % (int(nd.get("tier", 1)) - 1)
	_refresh()


func _refresh() -> void:
	_points_l.text = "剩余天赋点 %d / %d（每 5 级 1 点）" % [G.talent_points_left(), G.talent_points_total()]
	# 整列重建重绘（节点少，重建最省心）
	for c in _cols.get_children():
		c.queue_free()
	var branches: Array = G.talents_cfg().get("branches", [])
	for i in branches.size():
		_build_branch(branches[i], i)


# 竖直连线
class _BranchLine extends Control:
	var p_from := Vector2.ZERO
	var p_to := Vector2.ZERO
	var hue := Color.GRAY

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(408, 520)
		size = custom_minimum_size

	func _draw() -> void:
		draw_line(p_from, p_to, Color(hue.r, hue.g, hue.b, 0.4), 3.0)
