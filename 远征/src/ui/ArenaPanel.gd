# ArenaPanel.gd —— 演武场（PVP 首版）：傀儡对手 + 段位分
extends Control

signal closed

const BattleScenePacked := "res://src/battle/BattleScene.tscn"
const VIEW_W := 480.0
const VIEW_H := 800.0
const CONTENT_W := 408.0

var _panel: PanelContainer = null
var _rank_icon: TextureRect = null   # 段位徽章（升档后 _refresh 要换图）
var _info: Label = null
var _streak_l: Label = null      # 连胜行（轮次 19）
var _rank_title: Label = null    # 段位进度标题
var _rank_bar: Panel = null      # 段位进度填充条
var _rank_sub: Label = null      # 下一段位门槛说明
var _season_l: Label = null      # 赛季奖励（连胜荣誉口径）
var _rec_l: Label = null         # 战绩（胜负 / 胜率）
var _foe_l: Label = null
var _foe_lv := 1
var _mirror := false          # 对手模式：false=演武傀儡（默认，好上手）true=镜影（自己的镜像）
var _foe_tip: Label = null
var _battle_layer: CanvasLayer = null
var _busy := false
var _go_btn: Control = null


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.sfx("ui_open")
	_foe_lv = maxi(1, int(G.prog.get("level", 1)))
	_build()


func _build() -> void:
	# 演武场是独立场景，完全压住主页控件，避免标题和圆台透出造成层级混乱。
	# 演武场是独立场景 → 走接管级底衬；统一工厂（深棕 + 暗角 + 斜纹）
	G.veil(self, G.VEIL_TAKEOVER_A)

	# 开放式书法标题与演武卡面分开，横线留在卡面之外。
	var banner := G.banner_box("演武场", 280, 50)
	banner.position = Vector2((VIEW_W - 280.0) * 0.5, 112)
	banner.z_index = 2
	add_child(banner)

	# 副标题：原来压在木匾正上方（y=126）且用 c7a46b 压深底，字号 13px 又暗又小，
	# 实测几乎读不出来。移到木匾与面板之间不成立（木匾 150 起、面板 178 起），
	# 改为降到面板下沿外、用更亮的暖金 + FS_SM，既让开木匾，也保证对比度
	var subtitle := G.gold_label("擂台试锋 · 不损装备，不耗资源", G.FS_SM, false,
		Color("d9b96e"), false)
	subtitle.z_index = 3
	subtitle.position = Vector2(0, 631)
	subtitle.custom_minimum_size = Vector2(VIEW_W, 0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	# 木匾下沿 y=200 会盖住面板内容首行（内容起点 178+11=189）。
	# 整块内容区下移 TOP_PAD，让首行完全落在木匾之下，而不是被压掉半行。
	var top_pad := 26.0

	_panel = G.parchment_box(440, 436, 16.0)
	_panel.position = Vector2(20, 178)
	_panel.z_index = 1
	add_child(_panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(content)

	# ── 区块一：段位徽章 + 段位名/分 + 连胜
	# 徽章单独存成员：切磋后段位可能升档，_refresh() 里要跟着换图
	_rank_icon = TextureRect.new()
	_rank_icon.texture = G.res_tex(_rank_icon_name())
	_rank_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rank_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rank_icon.position = Vector2(12, 4 + top_pad)
	_rank_icon.size = Vector2(48, 48)
	_rank_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_rank_icon)

	# 段位名与分数：段位名用深棕加粗、显著高于辅助行（§7 第二层核心信息）
	_info = G.gold_label("", G.FS_MD, true, Color("4a3010"), false)
	_info.position = Vector2(70, 4 + top_pad)
	_info.custom_minimum_size = Vector2(CONTENT_W - 70.0, 0)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(_info)

	# 连胜行（轮次 19）：演武场此前赢了只有段位分，没有可花的产出。
	# 连胜既是短期目标，也是荣誉来源——放在段位行正下方，一眼能看到进度。
	_streak_l = G.gold_label("", G.FS_SM, true, Color("8a5a1a"), false)
	_streak_l.position = Vector2(70, 28 + top_pad)
	_streak_l.custom_minimum_size = Vector2(CONTENT_W - 70.0, 0)
	_streak_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(_streak_l)

	# 规则/口径属于第三层辅助信息：四条平铺会把下面的区块整块挤没，
	# 收进右上角「?」圆钮，点开才看（口径数值全读 data/arena.json，不写死）
	var rules := G.info_button("演武规则", _rules_lines(), 24.0)
	rules.position = Vector2(CONTENT_W - 26.0, 2.0)
	content.add_child(rules)

	var divider1 := ColorRect.new()
	divider1.color = Color("c9a85a", 0.42)
	divider1.position = Vector2(0, 82)
	divider1.size = Vector2(CONTENT_W, 1)
	divider1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider1)

	# ── 区块二：段位进度（当前分 / 下一段位门槛 / 进度条）
	# 档位门槛由 data/arena.json 的 ranks[].min 现算，升档/降档都跟着走
	_rank_title = G.gold_label("", G.FS_XS, false, Color("6a5230"), false)
	_rank_title.position = Vector2(0, 88)
	_rank_title.custom_minimum_size = Vector2(CONTENT_W, 0)
	_rank_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(_rank_title)

	var bar_bg := Panel.new()
	bar_bg.position = Vector2(0, 110)
	bar_bg.size = Vector2(CONTENT_W, 10)
	var bbg := StyleBoxFlat.new()
	bbg.bg_color = Color(0.35, 0.26, 0.14, 0.35)
	bar_bg.add_theme_stylebox_override("panel", bbg)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bar_bg)

	_rank_bar = Panel.new()
	_rank_bar.position = Vector2(1, 111)
	_rank_bar.size = Vector2(0, 8)
	var pbsb := StyleBoxFlat.new()
	pbsb.bg_color = G.C_RARE
	_rank_bar.add_theme_stylebox_override("panel", pbsb)
	_rank_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_rank_bar)

	_rank_sub = G.gold_label("", G.FS_XS, false, Color("6a5230"), false)
	_rank_sub.position = Vector2(0, 122)
	_rank_sub.custom_minimum_size = Vector2(CONTENT_W, 0)
	_rank_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(_rank_sub)

	var divider2 := ColorRect.new()
	divider2.color = Color("c9a85a", 0.42)
	divider2.position = Vector2(0, 146)
	divider2.size = Vector2(CONTENT_W, 1)
	divider2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider2)

	# ── 区块三：对手预览卡（图标 + 名称 + 模式提示）
	# PixelButton 皮（切角 + 厚度 + 硬影）+ 内层 Control 手动布局：
	# PanelContainer 会把直接子节点拉伸铺满整卡，手摆的图标/两行字要挂在内层上。
	var foe_card := G.PixelButton.new()
	foe_card.position = Vector2(0, 152)
	foe_card.size = Vector2(CONTENT_W, 84)
	foe_card.custom_minimum_size = Vector2(CONTENT_W, 84)
	foe_card.set_content_margin(0.0)
	foe_card.set_surface(Color("dccfa4"), Color("b99a5e"))
	# 点卡片切换对手类型（傀儡/镜影）：原来单独的「对手：傀儡」钮悬在按钮行上方，
	# 和换对手/开始切磋错成三级台阶；收进卡片后下方只剩一组主次分明的按钮
	foe_card.mouse_filter = Control.MOUSE_FILTER_STOP
	foe_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	foe_card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_mirror = not _mirror
			Audio.sfx("ui_confirm")
			_refresh())
	content.add_child(foe_card)
	var foe_inner := Control.new()
	foe_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_card.add_child(foe_inner)
	var foe_icon := TextureRect.new()
	foe_icon.texture = G.res_tex("icon_double_edge")
	foe_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foe_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foe_icon.position = Vector2(18, 16)
	foe_icon.size = Vector2(68, 68)
	foe_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_inner.add_child(foe_icon)
	_foe_l = G.gold_label("", G.FS_LG, true, Color("4a3010"), false)
	_foe_l.position = Vector2(104, 20)
	_foe_l.custom_minimum_size = Vector2(280, 0)
	_foe_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	foe_inner.add_child(_foe_l)
	_foe_tip = G.gold_label("", G.FS_XS, false, Color("6a5230"), false)
	_foe_tip.position = Vector2(104, 58)
	_foe_tip.custom_minimum_size = Vector2(280, 0)
	_foe_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	foe_inner.add_child(_foe_tip)

	# ── 区块四：赛季奖励（连胜荣誉积累）／战绩（胜负与胜率）
	# 演武场此前只显示段位分，看不出"打了这么多场攒下了什么"。
	# foe 卡下沿（236）到按钮行（268）只剩一条窄缝 → 单行左右分栏，左奖励右战绩，不再占第二行高度。
	_season_l = G.gold_label("", G.FS_XS, false, Color("7a5a20"), false)
	_season_l.position = Vector2(0, 244)
	_season_l.custom_minimum_size = Vector2(CONTENT_W * 0.5, 0)
	_season_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(_season_l)

	_rec_l = G.gold_label("", G.FS_XS, false, Color("6a5230"), false)
	_rec_l.position = Vector2(CONTENT_W * 0.5, 244)
	_rec_l.custom_minimum_size = Vector2(CONTENT_W * 0.5, 0)
	_rec_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(_rec_l)

	# 主次分明（§7 光效预算）：整块面板只有一个金色主按钮，换对手和返回都走描边次级款。
	# 对齐（§5 网格）：BTN_L 高 52、BTN_M 高 44，两枚按钮按垂直中心对齐（不是按 top 对齐）
	var btn_cy := 268.0 + top_pad
	var reroll := G.ghost_button("换对手", G.BTN_M.x, G.BTN_M.y, G.FS_SM)
	reroll.position = Vector2(0, btn_cy - G.BTN_M.y * 0.5)
	reroll.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			HapticFeedback.light()
			Audio.sfx("ui_page")
			_foe_lv = clampi(_foe_lv + (1 if randf() < 0.5 else -1), 1, 99)
			_refresh())
	content.add_child(reroll)

	_go_btn = G.gold_button("开始切磋", G.BTN_L.x, G.BTN_L.y)
	_go_btn.position = Vector2(CONTENT_W - G.BTN_L.x, btn_cy - G.BTN_L.y * 0.5)
	_go_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			HapticFeedback.medium()
			_start_battle())
	content.add_child(_go_btn)

	var archery_btn := G.ghost_button("校场射艺", 118, G.BTN_S.y, G.FS_SM)
	archery_btn.name = "OpenArcheryButton"
	archery_btn.position = Vector2(0, 322 + top_pad)
	archery_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_open")
			_open_archery())
	content.add_child(archery_btn)

	var back := G.ghost_button("返回", G.BTN_S.x, G.BTN_S.y, G.FS_SM)
	# 返回按钮与按钮行拉开 16，落在整个面板的底部收尾位
	back.position = Vector2((CONTENT_W - G.BTN_S.x) * 0.5, 322 + top_pad)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_close")
			closed.emit())
	content.add_child(back)

	var curio_btn := G.ghost_button("古碑鉴宝", 118, G.BTN_S.y, G.FS_SM)
	curio_btn.name = "OpenCurioButton"
	curio_btn.position = Vector2(CONTENT_W - 118.0, 322 + top_pad)
	curio_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_open")
			_open_curio_modal())
	content.add_child(curio_btn)
	_refresh()


var _archery_overlay: Control = null
var _curio_overlay: Control = null


func _open_archery() -> void:
	if _archery_overlay != null or _busy:
		return
	var ap: Control = (load("res://src/ui/ArcheryPanel.gd") as GDScript).new()
	_archery_overlay = ap
	ap.z_index = 20
	ap.closed.connect(func():
		if _archery_overlay != null:
			_archery_overlay.queue_free()
			_archery_overlay = null
		_refresh())
	add_child(ap)


func _open_curio_modal() -> void:
	if _curio_overlay != null or _busy:
		return
	var root := Control.new()
	root.name = "CurioLoreOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.z_index = 20
	_curio_overlay = root
	add_child(root)
	G.veil(root, G.VEIL_TAKEOVER_A)
	var box := G.parchment_box(436, 520, 16.0)
	box.position = Vector2(22, 140)
	root.add_child(box)
	var inner := Control.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(inner)

	var title_l := G.gold_label("边城古碑共鸣 · 行商鉴宝", G.FS_LG, true, Color("4a3010"), false)
	title_l.position = Vector2(0, 8)
	title_l.custom_minimum_size = Vector2(404, 0)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(title_l)

	var desc_l := G.gold_label("", G.FS_XS, false, Color("5a3e1b"), false)
	desc_l.name = "CurioStatusLabel"
	desc_l.position = Vector2(8, 44)
	desc_l.custom_minimum_size = Vector2(388, 120)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc_l)

	var log_l := G.gold_label("点选下方「参悟古碑」可激活当前职业先祖铭文与专属称号；点选「鉴宝」可开启蒙尘古匣获取宝石、精炼石与高阶装备。", G.FS_XS, false, Color("6a5230"), false)
	log_l.name = "CurioLogLabel"
	log_l.position = Vector2(8, 176)
	log_l.custom_minimum_size = Vector2(388, 168)
	log_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(log_l)

	var refresh_curio := func() -> void:
		var flags: Dictionary = G.prog.get("flags", {}) if G.prog.get("flags") is Dictionary else {}
		var cnt := int(flags.get("curio_appraised_count", 0))
		var resonated := bool(flags.get("lore_resonated_" + G.selected_role, false))
		var hist: Array = flags.get("curio_history", []) if flags.get("curio_history") is Array else []
		var hist_str := "暂无鉴宝记录" if hist.is_empty() else ("近期鉴宝：" + "；".join(hist.slice(0, 2)))
		desc_l.text = "当前金币：%d ｜ 已鉴宝：%d 次（满3次解锁【慧眼识珍】）\n当前职业古碑共鸣：%s\n%s" % [
			int(G.wallet.get("gold", 0)), cnt,
			"已达成（已领专属称号）" if resonated else "未共鸣（首次免费参悟领奖）",
			hist_str
		]

	var btn_lore := G.gold_button("参悟古碑", 124, 42, G.FS_SM)
	btn_lore.name = "LoreResonateButton"
	btn_lore.position = Vector2(4, 366)
	btn_lore.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var res := G.lore_resonate(G.selected_role)
			var lines: Array = res.get("lines", [])
			var reward_tail := "\n【首次共鸣】金币+180 · 远征币+40 · 魂晶+25 · 荣誉+30，解锁称号【%s】！" % String(res.get("title_name", "")) if bool(res.get("first", false)) else "\n（已参悟过该职业碑文，可随时重温铭文）"
			log_l.text = "【%s】\n%s%s" % [String(res.get("heading", "")), "\n".join(lines), reward_tail]
			refresh_curio.call()
			_refresh())
	inner.add_child(btn_lore)

	var btn_c1 := G.ghost_button("鉴古匣(260金)", 132, 42, G.FS_XS)
	btn_c1.name = "AppraiseCommonButton"
	btn_c1.position = Vector2(134, 366)
	btn_c1.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var res := G.curio_appraise("common")
			if bool(res.get("ok", false)):
				log_l.text = "鉴定成功！开启【%s】获得：%s%s" % [
					String(res.get("curio_name", "")),
					String(res.get("reward_desc", "")),
					"（达成3次鉴宝，额外解锁称号【慧眼识珍】！）" if bool(res.get("unlocked_title", false)) else ""
				]
			else:
				log_l.text = String(res.get("err", "金币不足"))
			refresh_curio.call()
			_refresh())
	inner.add_child(btn_c1)

	var btn_c2 := G.ghost_button("鉴宝匣(680金)", 132, 42, G.FS_XS)
	btn_c2.name = "AppraiseRareButton"
	btn_c2.position = Vector2(272, 366)
	btn_c2.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var res := G.curio_appraise("rare")
			if bool(res.get("ok", false)):
				log_l.text = "秘宝出世！开启【%s】获得：%s%s" % [
					String(res.get("curio_name", "")),
					String(res.get("reward_desc", "")),
					"（达成3次鉴宝，额外解锁称号【慧眼识珍】！）" if bool(res.get("unlocked_title", false)) else ""
				]
			else:
				log_l.text = String(res.get("err", "金币不足"))
			refresh_curio.call()
			_refresh())
	inner.add_child(btn_c2)

	var close_b := G.ghost_button("关闭", G.BTN_S.x, G.BTN_S.y, G.FS_SM)
	close_b.position = Vector2((404.0 - G.BTN_S.x) * 0.5, 432)
	close_b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_close")
			if _curio_overlay != null:
				_curio_overlay.queue_free()
				_curio_overlay = null)
	inner.add_child(close_b)
	refresh_curio.call()


func _rank_icon_name() -> String:
	match G.arena_rank():
		"铜印": return "rank_bronze"
		"银印": return "rank_silver"
		"金印": return "rank_gold"
		"铂印": return "rank_platinum"
		"钻印": return "rank_diamond"
	return "rank_bronze"


## 段位档位表（data/arena.json ranks）：面板内统一从这里取，避免各处重复解析
func _ranks() -> Array:
	var ranks: Variant = TableCache.arena_config().get("ranks", [])
	return ranks if ranks is Array else []


## 演武规则弹层文案：数值全读 data/arena.json，改数值不动代码
func _rules_lines() -> Array:
	var scfg: Variant = TableCache.arena_config().get("score", {})
	var sc: Dictionary = scfg if scfg is Dictionary else {}
	var cfg := G.arena_streak_cfg()
	var step := maxi(1, int(cfg.get("step", 3)))
	var honor_per := maxi(0, int(cfg.get("honor_per_milestone", 0)))
	var per_streak := maxi(0, int(cfg.get("score_bonus_per_streak", 0)))
	var cap := maxi(0, int(cfg.get("score_bonus_cap", 0)))
	var lines: Array = [
		"切磋不损装备、不耗资源；平局或中途退出不判负，段位分不变。",
		"胜利 +%d~%d 分，落败 -%d 分（段位分最低 0，不会跌破）。" % [
			int(sc.get("win_min", 18)), int(sc.get("win_max", 26)), int(sc.get("loss", 12))],
	]
	if per_streak > 0:
		lines.append("连胜每场额外 +%d 分，单场最多 +%d。" % [per_streak, cap])
	lines.append("每累计 %d 连胜额外发放 %d 荣誉，落败则连胜清零。" % [step, honor_per])
	var parts: PackedStringArray = []
	for r in _ranks():
		if r is Dictionary:
			parts.append("%s %d" % [String(r.get("name", "")), int(r.get("min", 0))])
	if not parts.is_empty():
		lines.append("段位按段位分划分：%s。" % " / ".join(parts))
	lines.append("点对手卡可在「镜影」（同套技能加成）与「演武傀儡」之间切换。")
	return lines


func _refresh() -> void:
	var score := int(G.arena.get("score", 0))
	var wins := int(G.arena.get("wins", 0))
	var losses := int(G.arena.get("losses", 0))

	# 段位行只留"段位名 + 段位分"：胜负数字改由区块四的战绩行承担，
	# 同一组数据不在同一屏里出现两次（§2 信息不重复）
	_info.text = "%s · %d 分" % [G.arena_rank(), score]
	_rank_icon.texture = G.res_tex(_rank_icon_name())

	# 段位进度：当前档门槛与下一档门槛都从 ranks[].min 现算，升/降档都跟着走
	var cur_min := 0
	var next_name := ""
	var next_min := -1
	for r in _ranks():
		if not (r is Dictionary):
			continue
		var lo := int((r as Dictionary).get("min", 0))
		if lo <= score and lo >= cur_min:
			cur_min = lo
		if lo > score and (next_min < 0 or lo < next_min):
			next_min = lo
			next_name = String((r as Dictionary).get("name", ""))
	if next_min < 0:
		_rank_title.text = "段位进度 · 已封顶"
		_rank_bar.size = Vector2(CONTENT_W - 2.0, 8)
		_rank_sub.text = "最高段位"
	else:
		var span := maxi(1, next_min - cur_min)
		var ratio := clampf(float(score - cur_min) / float(span), 0.0, 1.0)
		_rank_bar.size = Vector2(roundf((CONTENT_W - 2.0) * ratio), 8)
		_rank_title.text = "段位进度 · %s → %s" % [G.arena_rank(), next_name]
		_rank_sub.text = "还差 %d 分" % (next_min - score)

	var st := G.arena_streak()
	_streak_l.text = "连胜 %d · 最佳 %d" % [st, maxi(st, int(G.arena.get("best_streak", 0)))]
	_streak_l.add_theme_color_override("font_color",
		Color("8a5a1a") if st > 0 else Color("6a5230"))

	# 赛季奖励：口径就是连胜里程碑（arena.json streak），只把"已攒荣誉"和"还差几场"摊开
	var cfg := G.arena_streak_cfg()
	var step := maxi(1, int(cfg.get("step", 3)))
	var honor_per := maxi(0, int(cfg.get("honor_per_milestone", 0)))
	var to_next := step if st <= 0 else step - (st % step)
	_season_l.text = "赛季荣誉 %d · 再胜 %d 场 +%d" % [
		int(G.wallet.get("honor", 0)), to_next, honor_per]

	# 战绩：胜负之外给出胜率，比单纯两个计数器更能说明"打得怎么样"
	var total := wins + losses
	var rate := 0 if total <= 0 else roundi(float(wins) * 100.0 / float(total))
	_rec_l.text = "%d 胜 %d 负 · 胜率 %d%%" % [wins, losses, rate]

	# 傀儡名里已带等级（"演武傀儡 · N 级"），这里不再重复拼 Lv.
	_foe_l.text = "对手：%s" % String(_foe().get("name", ""))
	if _foe_tip != null:
		_foe_tip.text = ("镜像对局 · 同套技能加成 · 点卡片换傀儡" if _mirror \
			else "练手对局 · 数值随等级缩放 · 点卡片换镜影")


func _foe() -> Dictionary:
	if _mirror:
		return G.make_arena_mirror(G.selected_role, _foe_lv)
	return G.make_arena_foe(_foe_lv)


func _start_battle() -> void:
	if _busy:
		return
	_busy = true
	var foe := _foe()
	var pet := ""
	var owned: Array = G.owned_pets()
	if owned.size() > 0:
		pet = String(owned[0])
	BattleScene.pending_cfg = {
		"ally": {"role_id": G.selected_role, "level": int(G.prog.get("level", 1)),
			"traits": [], "active_pet": pet, "bench_pet": "", "potions": 2,
			"growth": G.growth_bonuses(G.selected_role),
			"skill_levels": G.prog.get("skills", {}),
			"pet_stats": G.battle_pet_stats([pet])},
		"enemy": {"theme": "forest", "node_type": "normal", "custom_mon": foe},
		"mode": "arena",   # 超时文案按"未分胜负"显示（口径 D3；问题 #21）
		"seed": 0,
	}
	_set_busy_look(true)   # 切磋进行中：主按钮压灰，避免连点重复开局（§26 禁用态要看得见）
	_battle_layer = CanvasLayer.new()
	_battle_layer.layer = 5
	add_child(_battle_layer)
	var b: Node = (load(BattleScenePacked) as PackedScene).instantiate()
	b.battle_finished.connect(_on_battle_end)
	_battle_layer.add_child(b)


func _on_battle_end(result: String, _hp_left: int) -> void:
	if _battle_layer != null:
		_battle_layer.queue_free()
		_battle_layer = null
	if result == "draw":
		# 超时平局：不判负、不动段位分（口径 D3）
		_busy = false
		_set_busy_look(false)
		_toast("未分胜负 · 段位分不变")
		_refresh()
		return
	if result == "flee":
		# 退出切磋（与远征撤退同义）：不判负、不动段位分
		_busy = false
		_set_busy_look(false)
		_toast("已退出切磋 · 段位分不变")
		_refresh()
		return
	var win := result == "victory"
	var res: Dictionary = G.arena_result(win)
	_busy = false
	_set_busy_look(false)
	_toast("切磋%s · 段位分 %+d（%s · %d 分）" % ["得胜" if win else "落败",
		int(res.get("delta", 0)), String(res.get("rank", "")), int(res.get("score", 0))])
	if bool(res.get("milestone", false)):
		Audio.sfx("reward")
		_toast("%d 连胜！额外荣誉 +%d" % [int(res.get("streak", 0)), int(res.get("honor", 0))])
	_refresh()


## 切磋中的按钮禁用态：压灰 + 不接点击（不是"点了没反应"）
func _set_busy_look(busy: bool) -> void:
	if _go_btn == null:
		return
	_go_btn.modulate = Color(1, 1, 1, 0.55) if busy else Color.WHITE
	_go_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP


func _toast(msg: String) -> void:
	var l := G.gold_label(msg, G.FS_SM, false, Color("ffe9b0"))
	l.position = Vector2(0, 616)
	l.custom_minimum_size = Vector2(VIEW_W, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14：ESC 只在最上层生效）
		return
	if event.is_action_pressed("ui_cancel") and not _busy:
		Audio.sfx("ui_close")
		closed.emit()
		get_viewport().set_input_as_handled()
