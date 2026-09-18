# TalentPanel.gd —— 天赋树（三系×10 节点，每 5 级 1 点；节点连线程序绘制）
# 布局：三根竖列（狂战/坚壁/迅捷），tier 1 在底部、tier 10 在顶部；
# 点某 tier 需本系已投点 ≥ tier-1（G.talent_can_add 判定）。
class_name TalentPanel
extends Control

signal closed

const CONTENT_W := 408.0
const COL_W := 122.0
const NODE_D := 40.0
const TIER_STEP := 47.0
const TREE_TOP := 66.0          # tier10 中心 y
# 列距 = COL_W + COL_GAP：三列必须整体居中且右列不顶到面板内沿。
# 3*122 + 2*8 = 382，比 408 窄 26，两侧各留 13 的呼吸空间（原来 3*132+2*6=408 顶死内沿，
# 最右列名字直接贴在面板金边上，视觉上"挤出框了"）。
const COL_GAP := 8.0
const BRANCH_HUES := {"fury": Color("c06040"), "guard": Color("5a8a5a"), "spirit": Color("4a7a9a")}
# 系名与节点文字色：直接用色系本色压深一档，保证在羊皮纸上够对比度。
# 原来的亮色系色（c06040/5a8a5a/4a7a9a）当 16px 字色偏灰、在米底上发闷，读起来费劲。
const BRANCH_TEXT := {"fury": Color("8e2f18"), "guard": Color("2f5a2f"), "spirit": Color("23506e")}

var _points_l: Label = null
var _info_l: Label = null
var _cols: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.78)

	# 木匾文案不手打空格：字距由 G.banner_box 内部的 spaced_font 统一处理（规范 §30/§31）
	var banner := G.banner_box("天赋树", 240, 50)
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
	_info_l = G.text_label("点击节点投入天赋点", G.FS_XS, Color("6a4a1e"))
	_info_l.position = Vector2(0, 544)
	_info_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	_info_l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_info_l)

	# 返回按钮走 BTN_S 档（120×38），字号 FS_SM——与全项目次级按钮同一规格，
	# 原来写死 130×36 + FS_MD，既不在档位上，字也比同类按钮大一号
	var close_btn := G.ghost_button("返回", G.BTN_S.x, G.BTN_S.y, G.FS_SM)
	close_btn.position = Vector2((CONTENT_W - G.BTN_S.x) * 0.5, 572)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(close_btn)

	_refresh()


func _build_branch(b: Dictionary, idx: int) -> void:
	# 三列整体在内容区居中：总宽 = 3*COL_W + 2*COL_GAP，起点 = (CONTENT_W - 总宽)/2
	var total_w := COL_W * 3.0 + COL_GAP * 2.0
	var col_x := (CONTENT_W - total_w) * 0.5 + idx * (COL_W + COL_GAP)
	var bid := String(b.get("id", ""))
	var hue: Color = BRANCH_HUES.get(bid, Color("8a6a34"))
	var name_col: Color = BRANCH_TEXT.get(bid, Color("7a5a2e"))

	var name_l := G.serif_label(String(b.get("name", "")), G.FS_MD, name_col)
	name_l.custom_minimum_size = Vector2(COL_W, 0)
	name_l.position = Vector2(col_x, 24)
	_cols.add_child(name_l)

	# 连线：tier1→tier10 一条竖线（程序绘制）
	var line := _BranchLine.new()
	var nodes: Array = b.get("nodes", [])
	var top_y := TREE_TOP
	var bot_y := TREE_TOP + (nodes.size() - 1) * TIER_STEP
	# 竖线贴着圆的左沿走（圆改为靠列左摆），让右侧腾出完整空间放名字
	var node_cx := col_x + NODE_D / 2.0
	line.p_from = Vector2(node_cx, top_y)
	line.p_to = Vector2(node_cx, bot_y)
	line.hue = hue
	_cols.add_child(line)

	# 节点：tier 1 在底部（倒序摆）。圆靠列左，名字在圆右侧单行排布
	for ni in nodes.size():
		var nd := nodes[ni] as Dictionary
		var tier := int(nd.get("tier", ni + 1))
		var cy := bot_y - (tier - 1) * TIER_STEP
		var btn := _node_button(nd, hue)
		btn.position = Vector2(col_x, cy - NODE_D / 2.0)
		_cols.add_child(btn)
		var st := _node_state(nd)
		var nl := _node_name_label(nd, hue, st)
		nl.position = Vector2(col_x + NODE_D + 6.0, cy - 8.0)
		_cols.add_child(nl)


## 节点状态：0 未解锁 / 1 可点 / 2 已投点 / 3 已满（供文字取色与逻辑判断共用）
func _node_state(nd: Dictionary) -> int:
	var nid := String(nd.get("id", ""))
	var cur := int((G.prog.get("talents", {}) as Dictionary).get(nid, 0))
	var mx := int(nd.get("max", 1))
	if cur >= mx:
		return 3
	if cur > 0:
		return 2
	return 1 if G.talent_can_add(nid) else 0


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
## 可读性重构（原版节点圆内塞「名字\n0/3」两行 12px 字）：
##   40px 的圆扣掉边框后可用宽度不足 36px，中文名三字（「破军之势」四字更甚）直接被圆边裁掉，
##   两行字还把圆撑满，既看不清又像糊了一团。改为「圆内只放等级数字（大字、居中）+
##   名字外置到圆右侧（左对齐、独立文字层）」——圆恢复成纯粹的进度指示器，
##   名字有完整横向空间，对比度和字号都能按正文档来。这与去AI感规范 §33「图标不要画太复杂，
##   0.5 秒识别」一致：圆负责状态，文字负责识别。
func _paint_node(root: PanelContainer, nd: Dictionary, hue: Color) -> void:
	var nid := String(nd.get("id", ""))
	var cur := int((G.prog.get("talents", {}) as Dictionary).get(nid, 0))
	var mx := int(nd.get("max", 1))
	var can := G.talent_can_add(nid)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(NODE_D / 2.0))
	sb.set_border_width_all(2)
	var txt_col := G.TEXT_DARK
	if cur >= mx:
		sb.bg_color = hue
		sb.border_color = G.GOLD_BRIGHT
		txt_col = G.TEXT_LIGHT
	elif can:
		sb.bg_color = Color("f7ecd0")
		sb.border_color = G.GOLD
	elif cur > 0:
		sb.bg_color = Color(hue.r, hue.g, hue.b, 0.45)
		sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5)
		txt_col = Color("3a2a14")
	else:
		# 未解锁：灰底 + 灰字是原来的"看不清"重灾区（b8a884 底 + TEXT_DARK 只有约 2.6:1）。
		# 底色提到接近羊皮纸、字色压到深棕，保证"未解锁"依然读得清，只是没颜色
		sb.bg_color = Color("cdbf9c")
		sb.border_color = Color(0.34, 0.28, 0.17, 0.55)
	G._apply_shadow(sb, 2.0, 1.0, 0.25)
	root.add_theme_stylebox_override("panel", sb)
	for c in root.get_children():
		c.queue_free()
	# 圆内只留「当前/上限」：字号提到正文档，加粗，一眼看出进度
	var l := G.gold_label("%d/%d" % [cur, mx], G.FS_SM, true, txt_col, cur >= mx)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)


## 节点名字层（圆右侧外置）：与圆分开摆放，避免"塞进 40px 圆"的裁切问题
func _node_name_label(nd: Dictionary, hue: Color, state: int) -> Label:
	var nm := String(nd.get("name", ""))
	# state: 0 未解锁 / 1 可点 / 2 已投点 / 3 已满
	var col := Color("4a3a20")
	match state:
		2: col = Color("5a3a10")
		3: col = BRANCH_TEXT.get(String(nd.get("branch", "")), Color("6a4a1e"))
	var l := G.gold_label(nm, G.FS_XS, false, col, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 名字可用宽 = COL_W - NODE_D - 6：四字名（「破军之势」）13px 约 52px，余量充足；
	# 给死宽度并裁剪，防止后续加长名把相邻列顶掉（超出省略而非串列）
	l.custom_minimum_size = Vector2(COL_W - NODE_D - 6.0, 0)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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
		# 连线压在节点圆底下（z_index 低于节点），端点各内缩半个圆径，
		# 避免线头从圆的上下沿戳出来（原来 p_from/p_to 正好落在圆心，线会贯穿圆）
		var r := NODE_D * 0.5
		var a := p_from
		var b := p_to
		if b.y < a.y:
			var t := a
			a = b
			b = t
		draw_line(Vector2(a.x, a.y + r), Vector2(b.x, b.y - r),
			Color(hue.r, hue.g, hue.b, 0.4), 3.0)
