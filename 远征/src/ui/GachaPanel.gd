# GachaPanel.gd —— 灵宠召唤浮层（单抽/十连、60 抽保底、翻卡演出、重复炼金）
# 纯代码构建 UI（无 .tscn）：主面板（余额/按钮/奖池预览）+ 结果层（背面朝上的卡、逐张翻开、出金爆闪）
# 价格、概率、保底、炼金数额全部读 data/gacha.json，代码不硬编码
class_name GachaPanel
extends Control

signal closed

# 羊皮纸 440 宽 - 左右各 16 内边距 = 408（同 DeployPanel/CodexPanel 的手动布局基准）
const CONTENT_W := 408.0
# 视口宽：面板宽 440 是内容基准，视口宽 480 是居中对齐基准，两者不要混用
const VIEW_W := 480.0
# 稀有度固定顺序（权重累加、文案、卡底命名都按它来）
const RARITY_ORDER := ["white", "blue", "purple", "gold"]
const RARITY_NAME := {"white": "普通", "blue": "稀有", "purple": "史诗", "gold": "传说"}
const RARITY_HUE := {
	"white": Color("a89e88"), "blue": Color("6f9fd0"),
	"purple": Color("a273c9"), "gold": Color("d8ab48"),
}
# 十连网格：5 列 × 2 行。卡 86×115、列距 92、行距 131，整排落在 13..467，不出 480
const CARD_W := 86.0
const CARD_H := 115.0
const CARD_STEP_X := 92.0
const CARD_STEP_Y := 131.0
const GRID_X0 := 13.0
const GRID_Y0 := 140.0
# 单抽大卡（约 3:4，与卡底素材同比例）
const BIG_W := 170.0
const BIG_H := 227.0

var _cfg_cache: Dictionary = {}

# ---- 主面板控件引用 ----
var _soul_l: Label = null
var _ticket_l: Label = null
var _pity_l: Label = null
var _pity_sub: Label = null
var _pity_bar: Panel = null
var _hint: Label = null
# ---- 结果层 ----
var _result: Control = null
var _cards_box: Control = null
var _fx_layer: Control = null
var _r_soul_l: Label = null
var _r_ticket_l: Label = null
var _sum_l: Label = null
var _r_hint: Label = null
var _flip_all_btn: Control = null
var _again_btn: PanelContainer = null
var _again_l: Label = null
var _again_sub: Label = null
# 最近一次召唤（模式 + 明细），「再抽一次」按 _last_mode 重放
var _last_mode := ""
var _results: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_build_result()
	_refresh_top()


# ================= 配置表 =================

## 读 data/gacha.json（首次读盘后缓存；测试可整体替换 _cfg_cache 注入假表）
func _cfg() -> Dictionary:
	if _cfg_cache.is_empty():
		var f := FileAccess.open("res://data/gacha.json", FileAccess.READ)
		if f != null:
			var v: Variant = JSON.parse_string(f.get_as_text())
			if v is Dictionary:
				_cfg_cache = v
	return _cfg_cache


## 四档概率（缺档按 0 补，表被改坏也不崩）
func _rates() -> Dictionary:
	var src: Dictionary = _cfg().get("rates", {})
	var out := {}
	for k in RARITY_ORDER:
		out[k] = float(src.get(k, 0.0))
	return out


## 召唤规则长文案（收进 ⓘ 弹层；概率/保底/炼金全部读表，不硬编码）
func _rules_lines() -> Array:
	var rates := _rates()
	var rp := PackedStringArray()
	for k in RARITY_ORDER:
		rp.append("%s %d％" % [String(RARITY_NAME[k]), roundi(float(rates[k]) * 100.0)])
	var dup: Dictionary = _cfg().get("dup_gold", {})
	var dp := PackedStringArray()
	for k in RARITY_ORDER:
		dp.append("%s +%d" % [String(RARITY_NAME[k]), int(dup.get(k, 0))])
	var pity_max := int(_cfg().get("pity", 60))
	return [
		"【出率】" + " · ".join(rp),
		"【保底】每召唤 1 次累积 1 点计数，满 %d 点必出史诗或传说；中途出史诗/传说即清零重计。" % pity_max,
		"【十连】十连必得至少一只稀有及以上灵宠；有十连券时优先用券。",
		"【重复炼化】已结缘的灵宠再抽到会自动炼化为金币：" + " · ".join(dp) + "。",
		"【结伴】通关各世界首领也能结识特定灵宠，详见图鉴。",
	]


# ================= 主面板 =================

func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, G.VEIL_MODAL_A)

	# 同 DeployPanel 的教训：浮层 rect 时机问题，横幅直接写死坐标最稳
	var banner := G.banner_box("灵宠召唤", 300, 50)
	banner.position = Vector2(90, 36)
	add_child(banner)

	var panel := G.parchment_box(440, 600, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)

	# PanelContainer 是容器，直接放子控件会被布局覆盖位置；包一层 Control 手动布局
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	# 顶部信息带：本期主打 + 保底进度
	# （原来是冷色「蓝城堡」横幅素材，压在暖色羊皮纸上像贴错了图；改成同族木色内嵌带）
	var head := _inset_band(Vector2(CONTENT_W, 104), Vector2(0, 0))
	content.add_child(head)
	var feat := _featured_pet()
	var fpic := _tex_rect(String(feat.get("id", "")), 68, 68, Color("a89e88"))
	fpic.position = Vector2(14, 18)
	head.add_child(fpic)
	var fraw := String(feat.get("rarity", "white"))
	var kicker := G.gold_label("本 期 主 打", G.FS_XS, false, Color("7a5a2e"), false)
	kicker.position = Vector2(92, 14)
	kicker.size = Vector2(120, 16)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(kicker)
	var fname_l := G.gold_label(String(feat.get("name", "")), G.FS_MD, true, G.BANNER, false)
	fname_l.position = Vector2(92, 30)
	fname_l.size = Vector2(120, 24)
	fname_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(fname_l)
	var chip := Panel.new()
	chip.position = Vector2(92, 58)
	chip.size = Vector2(64, 20)
	var csb := StyleBoxFlat.new()
	csb.bg_color = RARITY_HUE.get(fraw, Color("a89e88"))
	csb.set_corner_radius_all(4)
	csb.set_border_width_all(1)
	csb.border_color = Color(0.25, 0.16, 0.06, 0.55)
	chip.add_theme_stylebox_override("panel", csb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_l := G.gold_label(String(RARITY_NAME.get(fraw, "普通")), G.FS_XS, true,
		Color("fff6e0"), false)
	chip_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	chip_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(chip_l)
	head.add_child(chip)
	# 右侧：保底数字 + 进度条 + 下一档提示
	_pity_l = G.gold_label("", G.FS_XS, false, Color("6a4a1e"), false)
	_pity_l.position = Vector2(206, 16)
	_pity_l.size = Vector2(172, 16)
	_pity_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_pity_l)
	var bar_bg := Panel.new()
	bar_bg.position = Vector2(206, 38)
	bar_bg.size = Vector2(172, 10)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.35, 0.26, 0.14, 0.35)
	bsb.set_corner_radius_all(5)
	bar_bg.add_theme_stylebox_override("panel", bsb)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(bar_bg)
	_pity_bar = Panel.new()
	_pity_bar.position = Vector2(207, 39)
	_pity_bar.size = Vector2(0, 8)
	var pbsb := StyleBoxFlat.new()
	pbsb.bg_color = Color("d8ab48")
	pbsb.set_corner_radius_all(4)
	_pity_bar.add_theme_stylebox_override("panel", pbsb)
	_pity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_pity_bar)
	# 保底小字 8a6a34 在 d3bd92 内嵌底上约 3.4:1，13px 下偏灰；压深到 6a5230 约 5:1
	_pity_sub = G.gold_label("", G.FS_XS, false, Color("6a5230"), false)
	_pity_sub.position = Vector2(206, 56)
	_pity_sub.size = Vector2(172, 16)
	_pity_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_pity_sub)
	var info := G.info_button("召唤规则", _rules_lines(), 24.0)
	info.position = Vector2(382, 6)
	head.add_child(info)

	# 余额条：灵魂石 + 十连券（同一内嵌底，不再飘在羊皮纸上）
	# 对称（§5 网格）：408 宽对半分，每组"图标+数字"在各自半区居中。
	# 原来写 72/228，两组中心分别在 115 / 258，视觉上左边空、右边挤。
	var bal := _inset_band(Vector2(CONTENT_W, 36), Vector2(0, 116))
	content.add_child(bal)
	var soul_icon := _tex_rect("cur_soul", 20, 20, Color("b08ad0"))
	soul_icon.position = Vector2(60, 8)
	bal.add_child(soul_icon)
	_soul_l = G.gold_label("× 0", G.FS_SM, false, G.TEXT_DARK, false)
	_soul_l.position = Vector2(84, 8)
	_soul_l.size = Vector2(90, 20)
	_soul_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bal.add_child(_soul_l)
	var tk_icon := _tex_rect("itm_ticket_ten", 20, 20, Color("d8ab48"))
	tk_icon.position = Vector2(264, 8)
	bal.add_child(tk_icon)
	_ticket_l = G.gold_label("× 0", G.FS_SM, false, G.TEXT_DARK, false)
	_ticket_l.position = Vector2(288, 8)
	_ticket_l.size = Vector2(90, 20)
	_ticket_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bal.add_child(_ticket_l)

	# 抽卡按钮（主标题 + 副标价格两行）
	var single_cost := int(_cfg().get("cost_soul_single", 80))
	var ten_cost := int(_cfg().get("cost_soul_ten", 800))
	# 主次分明：十连是主操作（金底），单抽降为描边次级，不再并排两个大金块
	var b1 := _btn2("单 抽", "%d 魂石" % single_cost, 196, 56, true)
	b1.position = Vector2(4, 160)
	b1.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_do_single())
	content.add_child(b1)
	var b2 := _btn2("十 连", "%d 魂石 / 1 券" % ten_cost, 196, 56, false)
	b2.position = Vector2(208, 160)
	b2.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_do_ten())
	content.add_child(b2)

	# 行内提示（红字，1.5 秒后淡出）
	_hint = G.gold_label("", G.FS_SM, false, Color("a04a3a"), false)
	_hint.position = Vector2(0, 222)
	_hint.custom_minimum_size = Vector2(CONTENT_W, 0)
	_hint.modulate.a = 0.0
	content.add_child(_hint)

	# 一句书卷气的小字，压一压"功能面板"的模板感
	var flavor := G.serif_label("魂 石 为 引 · 灵 宠 结 缘", G.FS_SM, Color("8a6a34"))
	flavor.position = Vector2(0, 246)
	flavor.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_child(flavor)

	# 本期奖池预览（pets.json 全量，稀有度色条一眼分档）
	var sec := G.gold_label("本期奖池", G.FS_SM, false, Color("7a5a2e"), false)
	sec.position = Vector2(0, 274)
	sec.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_child(sec)
	var pets: Array = TableCache.pets()
	# 两列四行：卡宽 196 能放下「双头蛇·影」这类长名，四列窄卡会把名字顶出面板右边界
	for i in mini(pets.size(), 8):
		var pc := _pool_card(pets[i] as Dictionary)
		pc.position = Vector2((i % 2) * 212, 298 + (i / 2) * 54)
		content.add_child(pc)

	var back_btn := G.gold_button("返 回", 120, 38)
	back_btn.position = Vector2((CONTENT_W - 120.0) * 0.5, 522)
	back_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close())
	content.add_child(back_btn)


## 奖池小卡：立绘 + 名字（悬停看稀有度），样式同 DeployPanel 宠物卡
func _pool_card(p: Dictionary) -> Panel:
	var pid := String(p.get("id", ""))
	var rar := String(p.get("rarity", "white"))
	# 用 Panel + 手动布局：PanelContainer 会按文字最小宽度自己撑大，长名卡片会顶出面板右边界
	var root := Panel.new()
	root.custom_minimum_size = Vector2(196, 50)
	root.size = Vector2(196, 50)
	root.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.BOX_BG
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 4
	sb.set_border_width_all(2)
	sb.border_color = G.BOX_EDGE
	G._apply_shadow(sb, 4.0, 2.0, 0.3)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	root.add_theme_stylebox_override("panel", sb)
	var pic := _tex_rect(pid, 36, 36, RARITY_HUE.get(rar, Color("a89e88")))
	pic.position = Vector2(14, 7)
	root.add_child(pic)
	var l := G.gold_label(String(p.get("name", pid)), G.FS_XS, false, G.TEXT_DARK, false)
	l.position = Vector2(56, 15)
	l.size = Vector2(132, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	# 左沿一条稀有度色带：比"四个角各不一样"的圆角更克制，也更容易一眼分档
	var strip := Panel.new()
	strip.position = Vector2(0, 0)
	strip.size = Vector2(6, 50)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = RARITY_HUE.get(rar, Color("a89e88"))
	ssb.corner_radius_top_left = 5
	ssb.corner_radius_bottom_left = 5
	strip.add_theme_stylebox_override("panel", ssb)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.tooltip_text = "%s · %s" % [String(p.get("name", pid)), String(RARITY_NAME.get(rar, "普通"))]
	return root


## 金按钮 + 副标小字（价格行）：在 gold_button 的 Label 下再叠一行
func _btn2(title: String, sub: String, w: float, h: float, ghost := false) -> PanelContainer:
	var btn := (G.ghost_button(title, w, h) if ghost else G.gold_button(title, w, h)) as PanelContainer
	# PanelContainer 会把每个直接子控件都铺满内容区——再 add_child 一个副标 Label 会与标题
	# 完全重叠（「十连」盖在「800 魂石」上）。必须用 VBox 把标题与副标竖排
	var title_l := btn.get_child(0) as Label
	btn.remove_child(title_l)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_l)
	# 副标（价格/说明）压在主按钮的金底上：用比主标略浅但明显深于底色的棕，
	# 保证"主标深棕加粗 / 副标深棕常规"两级都在金底上读得清（§17 数字与价格必须高可读）
	var sub_l := G.gold_label(sub, G.FS_XS, false, Color("5a3c14"), false)
	box.add_child(sub_l)
	btn.add_child(box)
	return btn


## 贴图矩形；素材缺失时退化为圆角色块，不让 UI 破相
func _tex_rect(res_name: String, w: float, h: float, fallback: Color,
		stretch := TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> Control:
	var tex: Texture2D = G.res_tex(res_name)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		# expand_mode 必须在 size 之前：否则最小尺寸被钳到贴图原尺寸，
		# 之后设 size 只会被顶大、不会缩回（横幅会撑成原图尺寸铺满面板）
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = stretch
		tr.custom_minimum_size = Vector2(w, h)
		tr.size = Vector2(w, h)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var p := Panel.new()
	p.custom_minimum_size = Vector2(w, h)
	p.size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fallback
	sb.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 木色内嵌带（比羊皮纸深一档 + 棕描边）：把成组信息收进同一块底，别让控件飘在纸面上
func _inset_band(sz: Vector2, at: Vector2) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = sz
	p.size = sz
	p.position = at
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("d3bd92")
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(G.BOX_EDGE.r, G.BOX_EDGE.g, G.BOX_EDGE.b, 0.55)
	sb.shadow_color = Color(0.24, 0.16, 0.06, 0.18)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 1)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 本期主打：取奖池里稀有度最高的一只（同档取第一只，稳定不随帧变化）
func _featured_pet() -> Dictionary:
	var best: Dictionary = {}
	var rank := -1
	for p in TableCache.pets():
		var pd := p as Dictionary
		var r := RARITY_ORDER.find(String(pd.get("rarity", "white")))
		if r > rank:
			rank = r
			best = pd
	return best


func _refresh_top() -> void:
	if _soul_l != null:
		_soul_l.text = "× %d" % int(G.wallet.get("soul", 0))
	if _ticket_l != null:
		_ticket_l.text = "× %d" % G.item_count("ticket_ten")
	if _pity_l != null:
		var pity := int(G.items.get("gacha_pity", 0))
		var pmax := maxi(1, int(_cfg().get("pity", 60)))
		_pity_l.text = "保底 %d / %d" % [pity, pmax]
		if _pity_sub != null:
			_pity_sub.text = "还差 %d 抽必得史诗" % maxi(0, pmax - pity)
		if _pity_bar != null:
			_pity_bar.size = Vector2(roundi(170.0 * clampf(float(pity) / float(pmax), 0.0, 1.0)), 8)


# ================= 结果层 =================

func _build_result() -> void:
	_result = Control.new()
	# 用 set_anchors_and_offsets_preset 而不是 set_anchors_preset：
	# 前者同时把 offset 归零，控件立即铺满父级；后者只改 anchors，size 要等下一帧布局
	# 才更新，期间遮罩会是 (0,0) 尺寸——结果层看起来"没盖住"，主面板整个透出来。
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result.mouse_filter = Control.MOUSE_FILTER_STOP   # 盖住主面板的按钮
	_result.visible = false
	add_child(_result)

	# 结果层底衬：整屏接管，底下不该透出任何东西。走统一浮层工厂（深棕+暗角+斜纹），
	# 比原来单色 0.985 的大平底有纵深——顶部木匾、底部按钮各有一块暗角收边。
	var rdim := G.veil(_result, G.VEIL_TAKEOVER_A)

	var title := G.banner_box("召唤结果", 260, 46)
	title.position = Vector2(110, 30)
	_result.add_child(title)

	# 余额条：结果层在深底上，控件的浅色字需要一块暗底衬着才不发飘（§8 光效预算——
	# 只有一块内嵌底，不做发光）。用非交互 Panel 承载，避免和遮罩抢点击。
	var rbal := Panel.new()
	rbal.position = Vector2(0, 86)
	rbal.custom_minimum_size = Vector2(VIEW_W, 34)
	rbal.size = Vector2(VIEW_W, 34)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.16, 0.11, 0.06, 0.85)
	rsb.set_border_width_all(0)
	rbal.add_theme_stylebox_override("panel", rsb)
	rbal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_child(rbal)
	# 两个资源对称排布：中心线左右各占一半，图标+数字成组居中。
	# 坐标一律相对 rbal（高 34），垂直居中 → (34-20)/2 = 7。
	# 原来写 y=93/94（那是屏幕绝对坐标），被 rbal 的 34 高裁掉，余额条看着是空的。
	var s_icon := _tex_rect("cur_soul", 20, 20, Color("b08ad0"))
	s_icon.position = Vector2(118, 7)
	rbal.add_child(s_icon)
	_r_soul_l = G.gold_label("× 0", G.FS_SM, false, Color("f5ead0"), false)
	_r_soul_l.position = Vector2(142, 7)
	_r_soul_l.size = Vector2(90, 20)
	_r_soul_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rbal.add_child(_r_soul_l)
	var t_icon := _tex_rect("itm_ticket_ten", 20, 20, Color("d8ab48"))
	t_icon.position = Vector2(262, 7)
	rbal.add_child(t_icon)
	_r_ticket_l = G.gold_label("× 0", G.FS_SM, false, Color("f5ead0"), false)
	_r_ticket_l.position = Vector2(286, 7)
	_r_ticket_l.size = Vector2(90, 20)
	_r_ticket_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rbal.add_child(_r_ticket_l)

	# 摘要行 + 行内提示：摘要承载"本次结果"这一核心信息，抬到卡片区正下方并加底衬
	_sum_l = G.gold_label("", G.FS_SM, true, Color("ffe9b8"), true)
	_sum_l.position = Vector2(0, 400)
	_sum_l.custom_minimum_size = Vector2(VIEW_W, 0)
	_result.add_child(_sum_l)
	_r_hint = G.gold_label("", G.FS_SM, false, Color("ff9a8a"), true)
	_r_hint.position = Vector2(0, 426)
	_r_hint.custom_minimum_size = Vector2(VIEW_W, 0)
	_r_hint.modulate.a = 0.0
	_result.add_child(_r_hint)

	# 卡片区与特效层同坐标系：特效压在卡上方但不挡点击。
	# 这两层是卡片定位的坐标基准，必须立即铺满（否则卡会按 (0,0) 尺寸的父级算位置）
	var _cb := Control.new()
	_cb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_box = _cb
	_result.add_child(_cards_box)
	var _fx := Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer = _fx
	_result.add_child(_fx_layer)

	# 「全部翻开」：悬浮在摘要行上方居中，只在还有未翻卡时出现
	_flip_all_btn = G.gold_button("全部翻开", 150, 44)
	_flip_all_btn.position = Vector2((VIEW_W - 150.0) * 0.5, 456)
	_flip_all_btn.visible = false
	_flip_all_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_flip_all())
	_result.add_child(_flip_all_btn)

	# 底部操作行：主操作（再抽一次）+ 次操作（返回），同高同基线、左右对称留边 28。
	# y=612 而非 540：卡片/摘要/翻牌按钮占满 400..500，按钮贴太近会挤成一坨，
	# 下移后"操作区"与"结果区"之间留出一段安静空白（§9 留白本身就是设计）。
	var pad := 28.0
	var btn_w := (VIEW_W - pad * 3.0) * 0.5   # 两枚等宽，间距与边距都为 pad
	_again_btn = _btn2("再抽一次", "", btn_w, 48)
	_again_btn.position = Vector2(pad, 612)
	var again_box := _again_btn.get_child(0) as VBoxContainer
	_again_l = again_box.get_child(0) as Label
	_again_sub = again_box.get_child(1) as Label
	_again_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_again())
	_result.add_child(_again_btn)

	# 返回是次操作：走描边款，避免和主操作抢视觉（§7 一层只有一个核心操作）
	# 结果层是整屏暗底（VEIL_TAKEOVER_A）：这里必须传浅色字，否则返回键的字会被暗底吃掉
	var back_btn := G.ghost_button("返回", btn_w, 48, G.FS_SM, Color("f0d9a0"))
	back_btn.position = Vector2(pad * 2.0 + btn_w, 612)
	back_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close())
	_result.add_child(back_btn)


## 展示一批结果：单抽一张大卡居中，十连 5×2 网格；全部背面朝上、back 缓动入场
func _show_results(mode: String, results: Array) -> void:
	_last_mode = mode
	_results = results
	for c in _cards_box.get_children():
		c.queue_free()
	for c in _fx_layer.get_children():
		c.queue_free()
	var big := results.size() == 1
	# 开卡音：出金用更亮的升级音，其余用领赏音（整批只在开头响一次，别叠成十下）
	var has_gold := false
	for r in results:
		if String((r as Dictionary).get("rarity", "")) == "gold":
			has_gold = true
			break
	Audio.sfx("level_up" if has_gold else "reward", 0.0)
	for i in results.size():
		var card := _make_card(results[i] as Dictionary, big)
		if big:
			card.position = Vector2((480.0 - BIG_W) * 0.5, GRID_Y0)
		else:
			card.position = Vector2(GRID_X0 + (i % 5) * CARD_STEP_X,
				GRID_Y0 + (i / 5) * CARD_STEP_Y)
		_cards_box.add_child(card)
		# 入场：scale 0.2→1（同 BattleScene UnitView.pop_in），逐张错峰
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.2, 0.2)
		var tw := card.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(card, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _result.visible:
		_result.visible = true
		_result.modulate = Color(1, 1, 1, 0)
		var ftw := _result.create_tween()
		ftw.tween_property(_result, "modulate:a", 1.0, 0.16)
	_update_result_ui()
	_refresh_top()


## 一张结果卡：背面（压暗白卡底 + 浮雕边 +「灵」字，不露稀有度）+ 正面（卡底/边框/立绘/名字）
func _make_card(res: Dictionary, big: bool) -> Control:
	var pid := String(res.get("id", ""))
	var rar := String(res.get("rarity", "white"))
	var w := BIG_W if big else CARD_W
	var h := BIG_H if big else CARD_H
	var pd := TableCache.get_pet(pid)
	var pname := String(pd.get("name", "未知灵宠"))

	var root := Control.new()
	root.custom_minimum_size = Vector2(w, h)
	root.size = Vector2(w, h)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# ---- 背面 ----
	var back := Control.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_base := _tex_rect("gacha_card_white", w, h, Color("4a3018"), TextureRect.STRETCH_SCALE)
	back_base.modulate = Color(0.52, 0.42, 0.3)
	back.add_child(back_base)
	var back_edge := _tex_rect("frame_white", w, h, Color("4a3018"), TextureRect.STRETCH_SCALE)
	back_edge.modulate = Color(0.55, 0.45, 0.32)
	back.add_child(back_edge)
	var glyph := G.serif_label("灵", G.FS_BIG if big else G.FS_LG, G.GOLD_BRIGHT, true)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back.add_child(glyph)
	root.add_child(back)

	# ---- 正面（翻开前隐藏）----
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.visible = false
	face.add_child(_tex_rect("gacha_card_" + rar, w, h,
		RARITY_HUE.get(rar, Color("a89e88")).darkened(0.35), TextureRect.STRETCH_SCALE))
	face.add_child(_tex_rect("frame_" + rar, w, h, Color("8a6220"), TextureRect.STRETCH_SCALE))
	var pic := _tex_rect(pid, 140 if big else 66, 132 if big else 62,
		RARITY_HUE.get(rar, Color("a89e88")))
	pic.position = Vector2(15, 12) if big else Vector2(10, 8)
	face.add_child(pic)

	var name_l := G.gold_label(pname, G.FS_LG if big else G.FS_XS, true, Color("fff3d8"), true)
	name_l.position = Vector2(0, 150 if big else 72)
	name_l.custom_minimum_size = Vector2(w, 0)
	# 卡名字有两种压底：卡底素材纹理 + 稀有度边框纹样，白字描边后仍会被花纹理吃掉笔画。
	# 加一条居中的暗色底衬条，让名字有一块稳定的阅读底（§17 数字/文字必须高可读）
	var name_bar := Panel.new()
	name_bar.position = Vector2(4 if big else 3, 148 if big else 70)
	name_bar.size = Vector2(w - (8 if big else 6), 26 if big else 20)
	var nbsb := StyleBoxFlat.new()
	nbsb.bg_color = Color(0.06, 0.04, 0.02, 0.55)
	nbsb.set_corner_radius_all(3)
	name_bar.add_theme_stylebox_override("panel", nbsb)
	name_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(name_bar)
	face.add_child(name_l)

	if big:
		var tag := G.gold_label(String(RARITY_NAME.get(rar, "普通")), G.FS_SM, false,
			RARITY_HUE.get(rar, Color("d8ab48")), true)
		tag.position = Vector2(0, 180)
		tag.custom_minimum_size = Vector2(w, 0)
		face.add_child(tag)

	# 重复卡：显示炼金所得小字
	if int(res.get("dup", 0)) > 0:
		var dup_l := G.gold_label("→ 金币 +%d" % int(res["dup"]),
			G.FS_SM if big else G.FS_XS, false, Color("ffd97a"), true)
		dup_l.position = Vector2(0, 202 if big else 91)
		dup_l.custom_minimum_size = Vector2(w, 0)
		face.add_child(dup_l)

	# 新收集：金底「新」角标
	if bool(res.get("is_new", false)):
		var badge := Panel.new()
		badge.position = Vector2(5, 5)
		badge.size = Vector2(30, 22) if big else Vector2(24, 19)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = G.GOLD_BTN
		bsb.corner_radius_top_left = 4
		bsb.corner_radius_top_right = 6
		bsb.corner_radius_bottom_left = 5
		bsb.corner_radius_bottom_right = 4
		bsb.set_border_width_all(1)
		bsb.border_color = G.GOLD_BTN_EDGE
		G._apply_shadow(bsb, 3.0, 1.5, 0.3)
		badge.add_theme_stylebox_override("panel", bsb)
		var bl := G.gold_label("新", G.FS_XS, true, G.TEXT_DARK, false)
		bl.set_anchors_preset(Control.PRESET_FULL_RECT)
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(bl)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(badge)

	root.add_child(face)
	root.set_meta("back", back)
	root.set_meta("face", face)
	root.set_meta("res", res)
	root.set_meta("flipped", false)
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_flip_card(root))
	return root


## 翻一张卡：横向压缩 → 换面 → 回弹；紫/金附加爆闪帧与轻度过曝
func _flip_card(card: Control) -> void:
	if card == null or not is_instance_valid(card) or bool(card.get_meta("flipped", false)):
		return
	card.set_meta("flipped", true)
	var back: Control = card.get_meta("back")
	var face: Control = card.get_meta("face")
	var rar := String((card.get_meta("res") as Dictionary).get("rarity", "white"))
	var center := card.position + card.size * 0.5
	var tw := card.create_tween()
	tw.tween_property(card, "scale:x", 0.06, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		back.visible = false
		face.visible = true
		_play_strip("fx_gacha_flip", center, card.size * 1.45, 0.07, Color(1, 1, 1, 0.92))
		if rar == "purple" or rar == "gold":
			_play_strip("fx_gacha_burst", center, card.size * 1.9, 0.09, Color(1.35, 1.25, 1.0))
			face.modulate = Color(1.7, 1.6, 1.35)
			var ftw := face.create_tween()
			ftw.tween_property(face, "modulate", Color.WHITE, 0.35))
	tw.tween_property(card, "scale:x", 1.0, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_result_ui()


## 「全部翻开」：按顺序小步错峰逐张翻
func _flip_all() -> void:
	var delay := 0.0
	for c in _cards_box.get_children():
		if c.is_queued_for_deletion() or bool(c.get_meta("flipped", false)):
			continue
		var card := c as Control
		var tw := card.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func(): _flip_card(card))
		delay += 0.06


## 播一条 3 帧横排特效（AtlasTexture 切帧，播完即自毁）
func _play_strip(res_name: String, center: Vector2, size_px: Vector2,
		frame_time: float, tint: Color) -> void:
	var strip: Texture2D = G.res_tex(res_name)
	if strip == null or _fx_layer == null:
		return
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = size_px
	tr.position = center - size_px * 0.5
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(tr)
	var fw := strip.get_width() / 3.0
	var fh := strip.get_height()
	var tw := tr.create_tween()
	for i in 3:
		var at := AtlasTexture.new()
		at.atlas = strip
		at.region = Rect2(i * fw, 0.0, fw, fh)
		tw.tween_callback(func(): tr.texture = at)
		tw.tween_interval(frame_time)
	tw.tween_callback(tr.queue_free)


## 结果层的动态文案：摘要 / 翻开按钮 / 再抽按钮 / 余额
func _update_result_ui() -> void:
	if _result == null:
		return
	var unflipped := 0
	for c in _cards_box.get_children():
		if not c.is_queued_for_deletion() and not bool(c.get_meta("flipped", false)):
			unflipped += 1
	_flip_all_btn.visible = unflipped > 0
	var new_n := 0
	var gold_n := 0
	for r in _results:
		if bool((r as Dictionary).get("is_new", false)):
			new_n += 1
		else:
			gold_n += int((r as Dictionary).get("dup", 0))
	# 摘要：结果层最该被看到的一句话（§18 玩家要 3 秒知道"我拿到了什么"）。
	# 原来"皆是旧识 · 炼金 +2280"和"再抽一次/返回"挤在同一视觉带里，且全用同色同号，
	# 现在摘要走 FS_SM 加粗描边、底部按钮独立成行，层级才分得开。
	if new_n > 0 and gold_n > 0:
		_sum_l.text = "新结缘 %d 只 · 炼金 +%d 金币" % [new_n, gold_n]
	elif new_n > 0:
		_sum_l.text = "新结缘 %d 只灵宠" % new_n
	else:
		_sum_l.text = "皆是旧识 · 炼金 +%d 金币" % gold_n
	# 按钮文案不手打空格：字距交给 G 的 _button_text 统一处理（规范 §30/§31）
	if _last_mode == "single":
		_again_l.text = "再抽一次"
		_again_sub.text = "%d 魂石" % int(_cfg().get("cost_soul_single", 80))
	else:
		_again_l.text = "再来十连"
		_again_sub.text = "%d 魂石 / 1 券" % int(_cfg().get("cost_soul_ten", 800))
	_r_soul_l.text = "× %d" % int(G.wallet.get("soul", 0))
	_r_ticket_l.text = "× %d" % G.item_count("ticket_ten")


# ================= 行为逻辑 =================

func _do_single() -> void:
	var cost := int(_cfg().get("cost_soul_single", 80))
	if int(G.wallet.get("soul", 0)) < cost:
		_warn("魂石不足：单抽需 %d，现有 %d" % [cost, int(G.wallet.get("soul", 0))])
		return
	G.wallet["soul"] = int(G.wallet.get("soul", 0)) - cost
	var results := _roll_batch(1)
	_settle(results)
	G.save_game()
	_show_results("single", results)


func _do_ten() -> void:
	var cost := int(_cfg().get("cost_soul_ten", 800))
	# 有券优先用券（consume_item 内部会落盘）
	if G.item_count("ticket_ten") >= 1 and G.consume_item("ticket_ten", 1):
		pass
	elif int(G.wallet.get("soul", 0)) >= cost:
		G.wallet["soul"] = int(G.wallet.get("soul", 0)) - cost
	else:
		_warn("魂石不足且无十连券：十连需 %d 魂石或 1 张券" % cost)
		return
	var results := _roll_batch(10)
	_settle(results)
	G.save_game()
	_show_results("ten", results)


## 再抽一次：按上次模式重放
func _again() -> void:
	if _last_mode == "single":
		_do_single()
	else:
		_do_ten()


func _close() -> void:
	closed.emit()


## ESC / 返回手势关闭本浮层（轮次 14 统一口径）。
## 与结果层「返回」按钮同一条路径：召唤页的结果层是整屏接管页，没有"只收起结果层"
## 的可见操作，ESC 就照按钮的口径走，不额外发明一层。
func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


## 行内提示：主面板用深红，结果层用亮红；1.5 秒后淡出（重复触发时重置计时）
func _warn(msg: String) -> void:
	var target := _hint
	var color := Color("a04a3a")
	if _result != null and _result.visible and _r_hint != null:
		target = _r_hint
		color = Color("ff9a8a")
	if target == null:
		return
	target.text = msg
	target.add_theme_color_override("font_color", color)
	target.modulate.a = 1.0
	var old: Tween = null
	if target.has_meta("fade_tw"):
		old = target.get_meta("fade_tw") as Tween
	if old != null:
		old.kill()
	var tw := target.create_tween()
	target.set_meta("fade_tw", tw)
	tw.tween_interval(1.5)
	tw.tween_property(target, "modulate:a", 0.0, 0.45)


# ================= 抽取内核 =================

## 某稀有度的宠物池（pets.json）
func _pool_of(rarity: String) -> Array:
	var out: Array = []
	for p in TableCache.pets():
		if String((p as Dictionary).get("rarity", "")) == rarity:
			out.append(p)
	return out


func _rand_id(rng: RandomNumberGenerator, pool: Array) -> String:
	if pool.is_empty():
		return ""
	return String((pool[rng.randi_range(0, pool.size() - 1)] as Dictionary).get("id", ""))


## randf 按权重选稀有度 → 再在该稀有度宠物里随机
func _pick_pet(rng: RandomNumberGenerator, rarity: String) -> String:
	var pool := _pool_of(rarity)
	if pool.is_empty():
		pool = TableCache.pets()   # 该档位没宠物时兜底全池，别让抽卡空转
	return _rand_id(rng, pool)


func _roll_rarity(rng: RandomNumberGenerator, rates: Dictionary) -> String:
	var roll := rng.randf()
	var acc := 0.0
	for k in RARITY_ORDER:
		acc += float(rates.get(k, 0.0))
		if roll < acc:
			return String(k)
	return "white"


## 保底档：按紫/金原始权重比例在两档里挑
func _roll_high(rng: RandomNumberGenerator, rates: Dictionary) -> String:
	var p := float(rates.get("purple", 0.0))
	var g := float(rates.get("gold", 0.0))
	if p + g <= 0.0:
		return "purple"
	return "purple" if rng.randf() < p / (p + g) else "gold"


## 抽 n 张：逐张结算保底计数（+1，出紫/金清零，满 60 强制紫/金）；
## 十连另有一条"至少一张蓝及以上"的整批保底（全白时把末张换成随机稀有）
func _roll_batch(n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rates := _rates()
	var pity_max := int(_cfg().get("pity", 60))
	var pity := int(G.items.get("gacha_pity", 0))
	var out: Array = []
	for i in n:
		pity += 1
		var rar := ""
		if pity >= pity_max:
			rar = _roll_high(rng, rates)
		else:
			rar = _roll_rarity(rng, rates)
		if rar == "purple" or rar == "gold":
			pity = 0
		out.append({"id": _pick_pet(rng, rar), "rarity": rar})
	if n >= 10:
		var has_blue := false
		for r in out:
			if String((r as Dictionary).get("rarity", "")) != "white":
				has_blue = true
				break
		if not has_blue:
			for rar in ["blue", "purple", "gold"]:
				var pool := _pool_of(rar)
				if pool.is_empty():
					continue
				out[n - 1] = {"id": _rand_id(rng, pool), "rarity": rar}
				break
	G.items["gacha_pity"] = pity
	return out


## 结算收集与炼金：新宠入册（G.collect_pet），重复按稀有度转金币入钱包
func _settle(results: Array) -> void:
	var dup_cfg: Dictionary = _cfg().get("dup_gold", {})
	var gold_gain := 0
	for r in results:
		var rd := r as Dictionary
		var pid := String(rd.get("id", ""))
		if pid == "":
			rd["is_new"] = false
			rd["dup"] = 0
			continue
		if G.owns_pet(pid):
			var g := int(dup_cfg.get(String(rd.get("rarity", "white")), 0))
			rd["is_new"] = false
			rd["dup"] = g
			gold_gain += g
		else:
			G.collect_pet(pid)
			rd["is_new"] = true
			rd["dup"] = 0
	if gold_gain > 0:
		G.wallet["gold"] = int(G.wallet.get("gold", 0)) + gold_gain
