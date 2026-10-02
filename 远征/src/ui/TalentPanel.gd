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
# 节点圈内的流派图标：项目没有专门的天赋图标，按语义就近复用已有 school_* 素材
# （fury 进攻系=暴击 / guard 防御系=荆棘反伤 / spirit 辅助系=能量），避免凭空塞文字
const BRANCH_ART := {"fury": "school_crit", "guard": "school_thorns", "spirit": "school_energy"}

var _points_l: Label = null
var _info_l: Label = null
var _cols: Control = null
# 可点节点（有待分配天赋点时的未满节点）：_process 里做金色呼吸，其余节点保持静态
var _pulse_nodes: Array = []


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
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


## ESC / 返回手势关闭本浮层（轮次 14 统一口径；本面板是「养成」的子面板，先关自己）
func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _build_branch(b: Dictionary, idx: int) -> void:
	# 三列整体在内容区居中：总宽 = 3*COL_W + 2*COL_GAP，起点 = (CONTENT_W - 总宽)/2
	var total_w := COL_W * 3.0 + COL_GAP * 2.0
	var col_x := (CONTENT_W - total_w) * 0.5 + idx * (COL_W + COL_GAP)
	var bid := String(b.get("id", ""))
	var hue: Color = BRANCH_HUES.get(bid, G.TEXT_MUTED)
	var name_col: Color = BRANCH_TEXT.get(bid, G.TEXT_MUTED)

	var name_l := G.serif_label(String(b.get("name", "")), G.FS_MD, name_col)
	name_l.custom_minimum_size = Vector2(COL_W, 0)
	name_l.position = Vector2(col_x, 24)
	_cols.add_child(name_l)

	# 连线：tier1→tier10 一条竖线（程序绘制）
	var line := _BranchLine.new()
	var nodes: Array = b.get("nodes", [])
	var top_y := TREE_TOP
	var bot_y := TREE_TOP + (nodes.size() - 1) * TIER_STEP
	# 已投点的最高档位：其中心 y 以上是"未激活"（灰细线），以下是"已激活"（金粗线）。
	# 无任何投点时 act_y = bot_y，金色段长度为 0，整条都是灰线。
	var act_y := bot_y
	for nj in nodes.size():
		var ndj := nodes[nj] as Dictionary
		var curj := int((G.prog.get("talents", {}) as Dictionary).get(String(ndj.get("id", "")), 0))
		if curj > 0:
			var tj := int(ndj.get("tier", nj + 1))
			act_y = minf(act_y, bot_y - (tj - 1) * TIER_STEP)
	# 竖线贴着圆的左沿走（圆改为靠列左摆），让右侧腾出完整空间放名字
	var node_cx := col_x + NODE_D / 2.0
	line.p_from = Vector2(node_cx, top_y)
	line.p_to = Vector2(node_cx, bot_y)
	line.act_y = act_y
	_cols.add_child(line)

	# 节点：tier 1 在底部（倒序摆）。圆靠列左，名字在圆右侧单行排布
	for ni in nodes.size():
		var nd := nodes[ni] as Dictionary
		var tier := int(nd.get("tier", ni + 1))
		var cy := bot_y - (tier - 1) * TIER_STEP
		var btn := _node_button(nd, hue, bid)
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


func _node_button(nd: Dictionary, hue: Color, bid: String) -> Control:
	var nid := String(nd.get("id", ""))
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(NODE_D, NODE_D)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("nid", nid)
	root.set_meta("hue", hue)
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_node(nid))
	_paint_node(root, nd, hue, bid)
	return root


## 节点外观三态：已点满（亮金边+色系底）/ 可点（金边羊皮纸）/ 未解锁（灰）
## 可读性重构（原版节点圆内塞「名字\n0/3」两行 12px 字）：
##   40px 的圆扣掉边框后可用宽度不足 36px，中文名三字（「破军之势」四字更甚）直接被圆边裁掉，
##   两行字还把圆撑满，既看不清又像糊了一团。改为「圆内中央放流派图标 + 右下角小字显示等级 +
##   名字外置到圆右侧（左对齐、独立文字层）」——圆恢复成纯粹的进度指示器，
##   名字有完整横向空间，对比度和字号都能按正文档来。这与去AI感规范 §33「图标不要画太复杂，
##   0.5 秒识别」一致：圆负责状态与识别，文字负责命名。
func _paint_node(root: PanelContainer, nd: Dictionary, hue: Color, bid: String) -> void:
	var nid := String(nd.get("id", ""))
	var cur := int((G.prog.get("talents", {}) as Dictionary).get(nid, 0))
	var mx := int(nd.get("max", 1))
	var can := G.talent_can_add(nid)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(NODE_D / 2.0))
	sb.set_border_width_all(2)
	# 内容边距归零：否则 PanelContainer 会按边框宽内缩内容区，
	# 圆内的图标/等级就跟着偏移，位置算不准
	sb.set_content_margin_all(0.0)
	var txt_col := G.TEXT_DARK
	var art_a := 1.0
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
		art_a = 0.85
	else:
		# 未解锁：灰底 + 灰字是原来的"看不清"重灾区（b8a884 底 + TEXT_DARK 只有约 2.6:1）。
		# 底色提到接近羊皮纸、字色压到深棕，保证"未解锁"依然读得清，只是没颜色
		sb.bg_color = Color("cdbf9c")
		sb.border_color = Color(0.34, 0.28, 0.17, 0.55)
		art_a = 0.42
	G._apply_shadow(sb, 2.0, 1.0, 0.25)
	root.add_theme_stylebox_override("panel", sb)
	for c in root.get_children():
		c.queue_free()
	# 包一层 Control 手动布局：PanelContainer 会把每个直接子控件都铺满内容区，
	# 图标与等级会完全重叠。内容边距已归零，这层就是精确的 NODE_D×NODE_D 坐标系
	var lay := Control.new()
	lay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lay)
	# 圆中央：本系图标（20px 内切于 40px 圆，四角不会戳出圆边）
	var tex := G.res_tex(String(BRANCH_ART.get(bid, "")))
	if tex != null:
		var art := TextureRect.new()
		art.texture = tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size = Vector2(20, 20)
		art.position = Vector2((NODE_D - 20.0) * 0.5, 5.0)
		art.modulate = Color(1, 1, 1, art_a)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lay.add_child(art)
	# 右下角：等级小字（11px，右对齐内缩 4px，落在圆下部仍完整在圆内）
	var l := G.gold_label("%d/%d" % [cur, mx], 11, true, txt_col, false)
	l.position = Vector2(0, 25)
	l.size = Vector2(NODE_D - 4.0, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lay.add_child(l)
	# 有剩余点时的可点节点登记进呼吸队列；点用完则整棵静态（不空转 _process）
	if can and G.talent_points_left() > 0:
		_pulse_nodes.append({"sb": sb})


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
	# 整列重建重绘（节点少，重建最省心）；呼吸队列随重建一并清空重登记
	_pulse_nodes.clear()
	for c in _cols.get_children():
		c.queue_free()
	var branches: Array = G.talents_cfg().get("branches", [])
	for i in branches.size():
		_build_branch(branches[i], i)


## 可点节点的金色呼吸（仅存在待分配天赋点时才有队列，否则直接返回，不空转）
func _process(_delta: float) -> void:
	if _pulse_nodes.is_empty():
		return
	var ph := float(Time.get_ticks_msec() % 1300) / 1300.0
	var a := 0.4 + 0.6 * absf(sin(ph * PI))
	for e in _pulse_nodes:
		var sb: StyleBoxFlat = e.get("sb")
		if sb != null:
			sb.border_color = Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, a)
			sb.set_border_width_all(2 + int(a > 0.8))


# 竖直连线
class _BranchLine extends Control:
	var p_from := Vector2.ZERO
	var p_to := Vector2.ZERO
	# 已激活段与未激活段的分界 y（已投点最高档位的圆心）；= p_to.y 时整条未激活
	var act_y := 0.0

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
		var top := Vector2(a.x, a.y + r)
		var bot := Vector2(b.x, b.y - r)
		var split := clampf(act_y, top.y, bot.y)
		# 未激活段（上方）：灰细线，弱化"还没走到"
		if split > top.y:
			draw_line(top, Vector2(top.x, split), Color(0.42, 0.34, 0.22, 0.5), 1.0)
		# 已激活段（下方）：金粗线，强化"已经点亮"
		if bot.y > split:
			draw_line(Vector2(bot.x, split), bot, G.C_RARE, 2.0)
