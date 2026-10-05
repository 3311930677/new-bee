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
# 稀有度色/名全项目唯一定义在 G.gd（C6），这里只引用，不再各自复制一份
const GScript := preload("res://src/autoload/G.gd")
const Finesse := preload("res://src/ui/UIFinesse.gd")
const Craft := preload("res://src/ui/CraftUI.gd")
const RARITY_NAME := GScript.RARITY_NAME
const RARITY_HUE := GScript.RARITY_HUE
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
var _pity_gem: Panel = null               # 保底进度条末端菱形标记
var _hint: Label = null
var _free_btn: Control = null             # 每日免费召唤条（G.InsetBand，免费时描边外有呼吸金线）
var _free_l: Label = null
var _free_available := false
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
var _ceremony: Finesse.Sigil
var _ceremony_label: Label
var _presentation: Tween
var _arriving := false
var _revealing := false
var _reveal_epoch := 0
## 回归与静态出图可关闭入场，实际交互始终使用完整演出。
var presentation_enabled := true


func _ready() -> void:
	_center_page.call_deferred()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_build_result()
	_refresh_top()


func _center_page() -> void:
	G.center_fixed_page(self)


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


## 当前单池配置（gacha.json v2 的 pools[0]；老结构顶层字段作兼容回退）
func _pool() -> Dictionary:
	var pools: Variant = _cfg().get("pools", [])
	if pools is Array and not (pools as Array).is_empty():
		return (pools as Array)[0]
	return _cfg()


## 四档概率（缺档按 0 补，表被改坏也不崩）
func _rates() -> Dictionary:
	var src: Dictionary = _pool().get("rates", {})
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
	var pity_max := int(_pool().get("pity", 60))
	return [
		"【出率】" + " · ".join(rp),
		"【保底】每召唤 1 次累积 1 点计数，满 %d 点必出史诗或传说；中途出史诗/传说即清零重计。" % pity_max,
		"【十连】十连 9 折，且必得至少一只史诗及以上灵宠；有十连券时优先用券。",
		"【每日免费】每天可免费召唤 1 次（零点刷新）；连续 7 天免费召唤可领灵魂石 ×50。",
		"【重复炼化】已结缘的灵宠再抽到会自动炼化为金币：" + " · ".join(dp) + "。",
		"【结伴】通关各世界首领也能结识特定灵宠，详见图鉴。",
	]


# ================= 主面板 =================

func _build() -> void:
	G.veil(self,.97)
	Craft.heading(self,"灵宠召唤","以魂晶结缘 · 寻找并肩而行的伙伴")
	var info := G.info_button("召唤规则",_rules_lines(),44.0)
	info.position = Vector2(412,24)
	add_child(info)
	var content := Control.new()
	content.position = Vector2(24,102)
	content.size = Vector2(432,638)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var balance := Craft.panel(Vector2.ZERO,Vector2(432,36),.96)
	content.add_child(balance)
	var soul_icon := _tex_rect("cur_soul",20,20,G.C_RARE)
	soul_icon.position = Vector2(22,8)
	balance.add_child(soul_icon)
	_soul_l = Craft.label("",Vector2(50,5),Vector2(148,26),16,Craft.WHITE,true)
	balance.add_child(_soul_l)
	var ticket_icon := _tex_rect("itm_ticket_ten",20,20,G.C_RARE)
	ticket_icon.position = Vector2(238,8)
	balance.add_child(ticket_icon)
	_ticket_l = Craft.label("",Vector2(266,5),Vector2(148,26),16,Craft.WHITE,true)
	balance.add_child(_ticket_l)

	var head := Craft.panel(Vector2(0,44),Vector2(432,166),.88)
	content.add_child(head)
	var feat := _featured_pet()
	var rarity := String(feat.get("rarity","white"))
	var hue: Color = RARITY_HUE.get(rarity,Craft.GOLD)
	head.add_child(Craft.label("本期主打",Vector2(18,10),Vector2(180,24),14,Craft.MUTED))
	head.add_child(Craft.label(String(feat.get("name","")),Vector2(18,38),Vector2(198,44),28,Craft.WHITE,false,true))
	head.add_child(Craft.label(String(RARITY_NAME.get(rarity,"普通"))+" · 灵宠",Vector2(20,86),Vector2(182,24),16,hue.lightened(.22)))
	head.add_child(Craft.label("世界首领亦可结伴",Vector2(20,130),Vector2(192,24),14,Craft.MUTED))
	var halo := Finesse.Sigil.new()
	halo.position = Vector2(207,-17)
	halo.size = Vector2(204,204)
	head.add_child(halo)
	var pic := _tex_rect(String(feat.get("id","")),128,128,hue)
	pic.position = Vector2(245,14)
	head.add_child(pic)
	if not bool(G.get_meta("ui_review_mode",false)):
		var drift := pic.create_tween().set_loops()
		drift.tween_property(pic,"position:y",10.0,2.4).set_trans(Tween.TRANS_SINE)
		drift.tween_property(pic,"position:y",14.0,2.4).set_trans(Tween.TRANS_SINE)

	var pity := Craft.panel(Vector2(0,218),Vector2(432,66),.96)
	content.add_child(pity)
	_pity_l = Craft.label("",Vector2(14,7),Vector2(186,24),15,Craft.WHITE)
	pity.add_child(_pity_l)
	_pity_sub = Craft.label("",Vector2(216,7),Vector2(200,24),14,Craft.MUTED)
	_pity_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pity.add_child(_pity_sub)
	var track := Panel.new()
	track.position = Vector2(14,40)
	track.size = Vector2(172,10)
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color("101a28")
	track.add_theme_stylebox_override("panel",track_style)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pity.add_child(track)
	_pity_bar = Panel.new()
	_pity_bar.position = Vector2(15,41)
	_pity_bar.size = Vector2(0,8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("bca4d6")
	_pity_bar.add_theme_stylebox_override("panel",fill)
	_pity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pity.add_child(_pity_bar)
	_pity_gem = Panel.new()
	_pity_gem.size = Vector2(8,8)
	_pity_gem.pivot_offset = Vector2(4,4)
	_pity_gem.rotation = PI*.25
	var gem := StyleBoxFlat.new()
	gem.bg_color = Color("efe0b8")
	_pity_gem.add_theme_stylebox_override("panel",gem)
	_pity_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pity.add_child(_pity_gem)

	var pool := _pool()
	var b1 := _btn2("单次结缘","%d 魂石" % int(pool.get("cost_soul_single",80)),204,64,true)
	b1.position = Vector2(0,296)
	b1.gui_input.connect(func(e: InputEvent):
		if _is_activate(e): _do_single())
	content.add_child(b1)
	var b2 := _btn2("十连召唤","%d 魂石 / 1 券" % int(pool.get("cost_soul_ten",720)),216,64,false)
	b2.position = Vector2(216,296)
	b2.set_meta("action_material","gilded")
	b2.gui_input.connect(func(e: InputEvent):
		if _is_activate(e): _do_ten())
	content.add_child(b2)
	_hint = Craft.label("",Vector2(0,364),Vector2(432,24),15,Color("ffd7ba"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	content.add_child(_hint)
	_free_btn = _inset_band(Vector2(432,44),Vector2(0,392))
	_free_l = G.gold_label("",16,false,G.TEXT_DARK,false)
	_free_l.position = Vector2(10,9)
	_free_l.size = Vector2(412,26)
	_free_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_free_btn.add_child(_free_l)
	_free_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_free_btn.focus_mode = Control.FOCUS_ALL
	_free_btn.gui_input.connect(func(e: InputEvent):
		if _is_activate(e): _do_free())
	content.add_child(_free_btn)
	content.add_child(Craft.label("本期奖池",Vector2(0,443),Vector2(200,28),18,Craft.GOLD))
	var pets: Array = TableCache.pets()
	for i in mini(pets.size(),8):
		var card := _pool_card(pets[i] as Dictionary)
		card.position = Vector2((i%4)*110,478+floori(float(i)/4)*76)
		content.add_child(card)
	var back := Craft.action("返回",Vector2(24,748),Vector2(432,44))
	back.activated.connect(_close)
	add_child(back)

func _is_activate(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept")

func _pool_card(p: Dictionary) -> Panel:
	var pid := String(p.get("id",""))
	var rarity := String(p.get("rarity","white"))
	var hue: Color = RARITY_HUE.get(rarity,G.C_HINT)
	var root := Panel.new()
	root.size = Vector2(102,72)
	root.custom_minimum_size = root.size
	var tile := StyleBoxFlat.new()
	tile.bg_color = hue.darkened(.82)
	tile.border_color = Color(hue,.52)
	tile.border_width_bottom = 2
	tile.border_width_top = 1
	tile.set_corner_radius_all(3)
	root.add_theme_stylebox_override("panel",tile)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var pic := _tex_rect(pid,44,44,hue)
	pic.position = Vector2(29,3)
	root.add_child(pic)
	var name_l := Craft.label(String(p.get("name",pid)),Vector2(4,48),Vector2(94,22),14,Craft.WHITE)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(name_l)
	root.tooltip_text = "%s · %s" % [String(p.get("name",pid)),String(RARITY_NAME.get(rarity,"普通"))]
	return root


## 金按钮 + 副标小字（价格行）：在 gold_button 的 Label 下再叠一行
func _btn2(title: String, sub: String, w: float, h: float, ghost := false) -> PanelContainer:
	var btn := (G.ghost_button(title, w, h) if ghost else G.gold_button(title, w, h)) as PanelContainer
	if not ghost: btn.set_meta("action_material","gilded")
	btn.focus_mode = Control.FOCUS_ALL
	btn.focus_entered.connect(func(): btn.call("_set_hover",1.0))
	btn.focus_exited.connect(func(): btn.call("_set_hover",0.0))
	# PanelContainer 会把每个直接子控件都铺满内容区——再 add_child 一个副标 Label 会与标题
	# 完全重叠（「十连」盖在「800 魂石」上）。必须用 VBox 把标题与副标竖排
	var title_l := btn.get_child(0) as Label
	title_l.add_theme_font_override("font",G.font_art)
	title_l.add_theme_font_size_override("font_size",26)
	title_l.add_theme_color_override("font_color",G.TEXT_DARK)
	btn.remove_child(title_l)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_l)
	# 副标（价格/说明）压在主按钮的金底上：用比主标略浅但明显深于底色的棕，
	# 保证"主标深棕加粗 / 副标深棕常规"两级都在金底上读得清（§17 数字与价格必须高可读）
	var sub_l := G.gold_label(sub, G.FS_XS, false, G.TEXT_DARK, false)
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
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 木色内凹条带（G.InsetBand：切角 + 顶暗底亮 + 金描边）：把成组信息收进同一块底，
## 别让控件飘在纸面上。子控件仍是手动布局（Panel 语义），换肤走 set_surface。
func _inset_band(sz: Vector2, at: Vector2) -> Panel:
	var p := G.InsetBand.new()
	p.custom_minimum_size = sz
	p.size = sz
	p.position = at
	p.set_surface(Color("d3bd92"), Color("b99a5e"))
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
		var pity := int(G.gacha_state().get("pity", 0))
		var pmax := maxi(1, int(_pool().get("pity", 60)))
		var ratio := clampf(float(pity) / float(pmax), 0.0, 1.0)
		_pity_l.text = "保底 %d / %d" % [pity, pmax]
		if _pity_sub != null:
			_pity_sub.text = "还差 %d 抽必得史诗" % maxi(0, pmax - pity)
		if _pity_bar != null:
			_pity_bar.size = Vector2(roundi(170.0 * ratio), 8)
		if _pity_gem != null:
			# Diamond stays inside the 170 px fill track, including empty/full states.
			var cx := clampf(15.0 + 170.0 * ratio, 17.0, 183.0)
			_pity_gem.position = Vector2(cx - 4.0, 41.0)
	_refresh_free()


## 免费条状态刷新（可用 = 暖金底 + 金边 + 呼吸金线；已领 = 灰底灰字 + 压暗）
## 换肤走 InsetBand.set_surface，不再整块替换 StyleBoxFlat（圆角+软影的旧皮已弃用）
func _refresh_free() -> void:
	if _free_l == null:
		return
	_free_available = G.gacha_free_available()
	var band := _free_btn as G.InsetBand
	if _free_available:
		band.set_surface(Color("e6cd93"), Color("b8892e"))
		_free_l.text = "今日免费 · 灵宠结缘（每日 1 次）"
		_free_l.add_theme_color_override("font_color", Color("7a4a0e"))
		_free_btn.modulate = Color.WHITE
	else:
		band.set_surface(Color("cfc6b0"), Color("a49878"))
		band.glow = 0.0
		_free_l.text = "今日免费已领 · 明日再来"
		_free_l.add_theme_color_override("font_color", Color("8a8a8a"))
		_free_btn.modulate = Color(1, 1, 1, 0.72)


## 呼吸金线（画在 InsetBand 描边外）：仅可用时脉动；已领时不动、省电
func _process(_delta: float) -> void:
	if _free_btn == null or not _free_available:
		return
	var ph := float(Time.get_ticks_msec() % 1500) / 1500.0
	var band := _free_btn as G.InsetBand
	band.glow = 0.35 + 0.5 * absf(sin(ph * PI))
	band.queue_redraw()


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
	var solid := ColorRect.new()
	solid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	solid.color = Color("211d2a")
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_child(solid)

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
	var t_icon := _tex_rect("itm_ticket_ten", 20, 20, G.C_RARE)
	t_icon.position = Vector2(262, 7)
	rbal.add_child(t_icon)
	_r_ticket_l = G.gold_label("× 0", G.FS_SM, false, Color("f5ead0"), false)
	_r_ticket_l.position = Vector2(286, 7)
	_r_ticket_l.size = Vector2(90, 20)
	_r_ticket_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rbal.add_child(_r_ticket_l)

	# 摘要行 + 行内提示：摘要承载"本次结果"这一核心信息，抬到卡片区正下方并加底衬
	_sum_l = G.gold_label("", G.FS_SM, true, Color("ffe9b8"), true)
	_sum_l.add_theme_font_override("font",G.font_reg)
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
	_ceremony = Finesse.Sigil.new()
	_ceremony.position = Vector2(100,120)
	_ceremony.size = Vector2(280,280)
	_ceremony.visible = false
	_result.add_child(_ceremony)
	_ceremony_label = G.serif_label("星阵唤灵",30,Color("efdab5"))
	_ceremony_label.position = Vector2(0,405)
	_ceremony_label.size = Vector2(VIEW_W,44)
	_ceremony_label.visible = false
	_result.add_child(_ceremony_label)
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
	_flip_all_btn.focus_mode = Control.FOCUS_ALL
	_flip_all_btn.gui_input.connect(func(e: InputEvent):
		if _is_activate(e):
			_flip_all(_arriving))
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
		if _is_activate(e):
			if _can_repeat(): _again())
	_result.add_child(_again_btn)

	# 返回是次操作：走描边款，避免和主操作抢视觉（§7 一层只有一个核心操作）
	# 结果层是整屏暗底（VEIL_TAKEOVER_A）：这里必须传浅色字，否则返回键的字会被暗底吃掉
	var back_btn := G.ghost_button("返回", btn_w, 48, G.FS_SM, Color("f0d9a0"))
	back_btn.focus_mode = Control.FOCUS_ALL
	back_btn.position = Vector2(pad * 2.0 + btn_w, 612)
	back_btn.gui_input.connect(func(e: InputEvent):
		if _is_activate(e):
			_close())
	_result.add_child(back_btn)


## 展示一批结果：单抽一张大卡居中，十连 5×2 网格；全部背面朝上、back 缓动入场
func _show_results(mode: String, results: Array) -> void:
	_reveal_epoch += 1
	_revealing = false
	if _presentation != null and _presentation.is_valid(): _presentation.kill()
	_last_mode = mode
	_results = results
	for child in get_children():
		if child is CanvasItem and child!=_result: child.hide()
	for c in _cards_box.get_children():
		c.queue_free()
	for c in _fx_layer.get_children():
		c.queue_free()
	var big := results.size() == 1
	_arriving = presentation_enabled
	Audio.sfx("ui_open",0.0)
	_ceremony.visible = _arriving
	_ceremony_label.visible = _arriving
	_ceremony.modulate.a = 1.0
	_ceremony.charge = 0.0
	_ceremony.bloom = 0.0
	_sum_l.visible = not _arriving
	for i in results.size():
		var card := _make_card(results[i] as Dictionary, big)
		if big:
			card.position = Vector2((480.0 - BIG_W) * 0.5, GRID_Y0)
		else:
			card.position = Vector2(GRID_X0 + (i % 5) * CARD_STEP_X,
				GRID_Y0 + (i / 5) * CARD_STEP_Y)
		_cards_box.add_child(card)
		card.pivot_offset = card.size * 0.5
		card.set_meta("rest_position",card.position)
		card.set_meta("ready",not _arriving)
		if _arriving:
			card.position = Vector2(240,260)-card.size*.5
			card.scale = Vector2(.35,.35)
			card.modulate.a = 0.0
			var tw := card.create_tween()
			card.set_meta("arrival",tw)
			tw.tween_interval(.85+i*.045)
			tw.tween_property(card,"position",card.get_meta("rest_position"),.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card,"scale",Vector2.ONE,.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card,"modulate:a",1.0,.18)
			tw.tween_callback(func(): card.set_meta("ready",true))
	if _arriving:
		_presentation = create_tween()
		_presentation.tween_property(_ceremony,"charge",1.0,.65).set_trans(Tween.TRANS_SINE)
		_presentation.tween_property(_ceremony,"bloom",1.0,.36)
		_presentation.parallel().tween_property(_ceremony,"modulate:a",0.0,.36)
		_presentation.tween_interval(.35+results.size()*.045)
		_presentation.tween_callback(_finish_arrival)
	if not _result.visible:
		_result.visible = true
		_result.modulate = Color(1, 1, 1, 0)
		var ftw := _result.create_tween()
		ftw.tween_property(_result, "modulate:a", 1.0, 0.16)
	_update_result_ui()
	_flip_all_btn.grab_focus.call_deferred()
	_refresh_top()


func _finish_arrival() -> void:
	if _presentation != null and _presentation.is_valid(): _presentation.kill()
	_arriving = false
	_ceremony.visible = false
	_ceremony_label.visible = false
	_sum_l.visible = true
	for card in _cards_box.get_children():
		if card.is_queued_for_deletion(): continue
		var tw := card.get_meta("arrival") as Tween if card.has_meta("arrival") else null
		if tw != null and tw.is_valid(): tw.kill()
		card.position = card.get_meta("rest_position")
		card.scale = Vector2.ONE
		card.modulate.a = 1.0
		card.set_meta("ready",true)
	_update_result_ui()


func _can_repeat() -> bool:
	if _arriving or _revealing: return false
	for card in _cards_box.get_children():
		if not card.is_queued_for_deletion() and not bool(card.get_meta("revealed",false)): return false
	return true


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
	var back_base := Finesse.CardSurface.new()
	back_base.size = Vector2(w,h)
	back.add_child(back_base)
	var glyph := G.serif_label("灵", 54 if big else 30, G.GOLD_BRIGHT, true)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back.add_child(glyph)
	root.add_child(back)

	# ---- 正面（翻开前隐藏）----
	var face := Control.new()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.visible = false
	var face_base := Finesse.CardSurface.new()
	face_base.reverse = false
	face_base.rarity = rar
	face_base.size = Vector2(w,h)
	face.add_child(face_base)
	var pic := _tex_rect(pid, 140 if big else 66, 132 if big else 62,
		RARITY_HUE.get(rar, G.C_HINT))
	pic.position = Vector2(15, 12) if big else Vector2(10, 8)
	face.add_child(pic)

	var name_l := G.gold_label(pname, G.FS_LG if big else G.FS_XS, true, Color("fff3d8"), true)
	if big: name_l.add_theme_font_override("font",G.font_art)
	name_l.position = Vector2(0, 150 if big else 72)
	name_l.custom_minimum_size = Vector2(w, 0)
	# 卡名字有两种压底：卡底素材纹理 + 稀有度边框纹样，白字描边后仍会被花纹理吃掉笔画。
	# 加一条居中的暗色底衬条，让名字有一块稳定的阅读底（§17 数字/文字必须高可读）
	var name_bar := Panel.new()
	name_bar.position = Vector2(4 if big else 3, 148 if big else 70)
	name_bar.size = Vector2(w - (8 if big else 6), 26 if big else 20)
	var nbsb := StyleBoxFlat.new()
	nbsb.bg_color = Color(0.06, 0.04, 0.02, 0.55)
	name_bar.add_theme_stylebox_override("panel", nbsb)
	name_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(name_bar)
	face.add_child(name_l)

	if big:
		var tag := G.gold_label(String(RARITY_NAME.get(rar, "普通")), G.FS_SM, false,
			RARITY_HUE.get(rar, G.C_RARE), true)
		tag.position = Vector2(0, 180)
		tag.custom_minimum_size = Vector2(w, 0)
		face.add_child(tag)

	# 重复卡：显示炼金所得小字
	if int(res.get("dup", 0)) > 0:
		var dup_l := G.gold_label(("炼化 +%d 金币" if big else "+%d 金币") % int(res["dup"]),
			G.FS_SM if big else 11, false, Color("ffd97a"), false)
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
		bsb.set_border_width_all(1)
		bsb.border_color = G.GOLD_BTN_EDGE
		# 像素角标：直角 + 描边 + 底边加重 1px（凸起厚度），弃用"四角各不同"圆角与软影
		bsb.border_width_bottom = 2
		badge.add_theme_stylebox_override("panel", bsb)
		var bl := G.gold_label("新", G.FS_XS, true, G.GOLD_BRIGHT, false)
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
	root.set_meta("revealed",false)
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if not _arriving and not _revealing: _flip_card(root))
	return root


## 翻一张卡：横向压缩 → 换面 → 回弹；紫/金附加爆闪帧与轻度过曝
func _flip_card(card: Control, audible := true) -> void:
	if card == null or not is_instance_valid(card) or bool(card.get_meta("flipped", false)):
		return
	card.set_meta("flipped", true)
	var entry_tw := card.get_meta("arrival") as Tween if card.has_meta("arrival") else null
	if entry_tw != null and entry_tw.is_valid(): entry_tw.kill()
	card.position = card.get_meta("rest_position",card.position)
	card.scale = Vector2.ONE
	card.modulate.a = 1.0
	var back: Control = card.get_meta("back")
	var face: Control = card.get_meta("face")
	var rar := String((card.get_meta("res") as Dictionary).get("rarity", "white"))
	var center := card.position + card.size * 0.5
	var tw := card.create_tween()
	tw.tween_property(card, "scale:x", 0.06, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		back.visible = false
		face.visible = true
		if audible: Audio.sfx("ui_page",0.02)
		if rar == "purple" or rar == "gold":
			Finesse.celebrate(_fx_layer,center,RARITY_HUE[rar],card.size.y*1.2)
			if audible: Audio.sfx("level_up" if rar=="gold" else "reward",0.0)
			face.modulate = Color(1.18,1.14,1.10)
			var ftw := face.create_tween()
			ftw.tween_property(face, "modulate", Color.WHITE, 0.4))
	tw.tween_property(card, "scale:x", 1.0, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): card.set_meta("revealed",true); _update_result_ui())
	_update_result_ui()


## 「全部翻开」：按顺序小步错峰逐张翻
func _flip_all(immediate := false) -> void:
	if _revealing: return
	if _arriving: _finish_arrival()
	_revealing = true
	var epoch := _reveal_epoch
	if immediate: Audio.sfx("reward",0.0)
	var delay := 0.0
	for c in _cards_box.get_children():
		if c.is_queued_for_deletion() or bool(c.get_meta("flipped", false)):
			continue
		var card := c as Control
		var tw := card.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			if epoch==_reveal_epoch: _flip_card(card,not immediate))
		delay += 0.0 if immediate else 0.105
	var finish := create_tween()
	finish.tween_interval(delay+.3)
	finish.tween_callback(func():
		if epoch!=_reveal_epoch: return
		_revealing = false
		_update_result_ui())
	_update_result_ui()


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
	(_flip_all_btn.get_child(0) as Label).text = "跳过演出" if _arriving else "依次揭晓"
	_flip_all_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if _revealing else Control.MOUSE_FILTER_STOP
	_flip_all_btn.modulate.a = .45 if _revealing else 1.0
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
	var pending := 0
	for card in _cards_box.get_children():
		if not card.is_queued_for_deletion() and not bool(card.get_meta("revealed",false)): pending+=1
	_again_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if _arriving or _revealing or pending>0 else Control.MOUSE_FILTER_STOP
	_again_btn.focus_mode = Control.FOCUS_NONE if _arriving or _revealing or pending>0 else Control.FOCUS_ALL
	_flip_all_btn.focus_mode = Control.FOCUS_ALL if _flip_all_btn.visible and not _revealing else Control.FOCUS_NONE
	if pending==0 and not _arriving and not _revealing and get_viewport().gui_get_focus_owner()==null:
		_again_btn.grab_focus.call_deferred()
	_again_btn.modulate.a = .45 if _arriving or _revealing or pending>0 else 1.0
	if pending>0:
		_sum_l.text = "轻点灵契 · 揭晓缘分" if _results.size()==1 else "已揭晓 %d / %d · 轻点灵契" % [_results.size()-pending,_results.size()]
	elif new_n > 0 and gold_n > 0:
		_sum_l.text = "新结缘 %d 只 · 炼金 +%d 金币" % [new_n, gold_n]
	elif new_n > 0:
		_sum_l.text = "新结缘 %d 只灵宠" % new_n
	else:
		_sum_l.text = "皆是旧识 · 炼金 +%d 金币" % gold_n
	# 按钮文案不手打空格：字距交给 G 的 _button_text 统一处理（规范 §30/§31）
	if _last_mode == "single":
		_again_l.text = "再抽一次"
		_again_sub.text = "%d 魂石" % int(_pool().get("cost_soul_single", 80))
	else:
		_again_l.text = "再来十连"
		_again_sub.text = "%d 魂石 / 1 券" % int(_pool().get("cost_soul_ten", 720))
	_r_soul_l.text = "× %d" % int(G.wallet.get("soul", 0))
	_r_ticket_l.text = "× %d" % G.item_count("ticket_ten")


# ================= 行为逻辑 =================

func _do_single() -> void:
	var cost := int(_pool().get("cost_soul_single", 80))
	if int(G.wallet.get("soul", 0)) < cost:
		_warn("魂石不足：单抽需 %d，现有 %d" % [cost, int(G.wallet.get("soul", 0))])
		return
	G.wallet["soul"] = int(G.wallet.get("soul", 0)) - cost
	var results := _roll_batch(1)
	_settle(results)
	G.save_game()
	_show_results("single", results)


func _do_ten() -> void:
	var cost := int(_pool().get("cost_soul_ten", 720))
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


## 每日免费一召：不扣魂石、正常累积保底；连抽满 7 天由 G.gacha_mark_free 发奖
func _do_free() -> void:
	if not G.gacha_free_available():
		_warn("今日免费已领取 · 明日再来")
		return
	var bonus := G.gacha_mark_free()
	var results := _roll_batch(1)
	_settle(results)
	G.save_game()
	_show_results("single", results)
	if bonus > 0:
		_warn("连续七日 · 灵魂石 +%d" % bonus, Color("ffe9b8"))
	_refresh_top()


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


## 行内提示：默认深红警告；传 color 可换色（如奖励的金色）；1.5 秒后淡出（重复触发重置计时）
func _warn(msg: String, color := Color(0, 0, 0, 0)) -> void:
	var target := _hint
	var col := Color("ffb6a3")
	if _result != null and _result.visible and _r_hint != null:
		target = _r_hint
		col = Color("ff9a8a")
	if color.a > 0.0:
		col = color
	if target == null:
		return
	target.text = msg
	target.add_theme_color_override("font_color", col)
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


## 稀有度判定钩子：满保底走紫/金池，否则按权重正常抽。
## 单独一层是为了给测试一个"只换判定、不换引擎"的缝——子类覆写它就能确定性走完每一条保底路径。
func _decide_rarity(rng: RandomNumberGenerator, rates: Dictionary, pity: int, pity_max: int) -> String:
	if pity >= pity_max:
		return _roll_high(rng, rates)
	return _roll_rarity(rng, rates)


## 抽 n 张：随机源在本层创建（局外 RNG 与战斗种子 RNG 严禁互串）。判定逻辑见 roll_batch_with。
func _roll_batch(n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return roll_batch_with(n, rng)


## 抽 n 张的**确定性内核**：逐张结算保底计数（+1，出紫/金清零，满 pity 强制紫/金）；
## 十连另有一条整批保底：至少一张史诗及以上（全下品时把末张换成紫/金，设计 §4.2）。
##
## 单独拆出来是为了测试能注入固定 seed 的 rng —— 靠"连抽几百次总能触发保底"来碰运气
## 验证保底是假绿：随机源一换（引擎版本、平台、抽数）就可能永远不命中那条分支。
func roll_batch_with(n: int, rng: RandomNumberGenerator) -> Array:
	var rates := _rates()
	var pity_max := maxi(1, int(_pool().get("pity", 60)))
	var pity := int(G.gacha_state().get("pity", 0))
	var out: Array = []
	for i in n:
		pity += 1
		var rar := _decide_rarity(rng, rates, pity, pity_max)
		if rar == "purple" or rar == "gold":
			pity = 0
		out.append({"id": _pick_pet(rng, rar), "rarity": rar})
	if n >= 10:
		var has_high := false
		for r in out:
			var rr := String((r as Dictionary).get("rarity", ""))
			if rr == "purple" or rr == "gold":
				has_high = true
				break
		if not has_high:
			var rar_hi := _roll_high(rng, rates)   # 按原始权重在紫/金两档里挑
			out[n - 1] = {"id": _pick_pet(rng, rar_hi), "rarity": rar_hi}
			# 整批补的这张同样是"出了史诗及以上"：和逐张保底一个口径，必须清零计数。
			# 漏掉这行就变成"十连补发后保底仍挂着"，下一次连抽会白送一张高品质（问题 #19）。
			# （已做故障注入验证：去掉这行后 VerifyGacha 报「实为 10」，用例确实抓得住。）
			pity = 0
	G.gacha_state()["pity"] = pity
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
