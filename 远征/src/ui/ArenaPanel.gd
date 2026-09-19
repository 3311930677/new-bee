# ArenaPanel.gd —— 演武场（PVP 首版）：傀儡对手 + 段位分
extends Control

signal closed

const BattleScenePacked := "res://src/battle/BattleScene.tscn"
const VIEW_W := 480.0
const VIEW_H := 800.0
const CONTENT_W := 408.0

var _panel: PanelContainer = null
var _info: Label = null
var _foe_l: Label = null
var _foe_lv := 1
var _mirror := false          # 对手模式：false=演武傀儡（默认，好上手）true=镜影（自己的镜像）
var _mode_btn: Control = null
var _foe_tip: Label = null
var _battle_layer: CanvasLayer = null
var _busy := false
var _go_btn: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.sfx("ui_open")
	_foe_lv = maxi(1, int(G.prog.get("level", 1)))
	_build()


func _build() -> void:
	# 演武场是独立场景，完全压住主页控件，避免标题和圆台透出造成层级混乱。
	# 演武场是独立场景 → 走接管级底衬；统一工厂（深棕 + 暗角 + 斜纹）
	G.veil(self, G.VEIL_TAKEOVER_A)

	# 木匾压在面板上沿（挂牌式），整块弹窗落在屏幕视觉中心，不再悬在半空
	var banner := G.banner_box("演武场", 280, 50)
	banner.position = Vector2((VIEW_W - 280.0) * 0.5, 150)
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

	# 段位徽章与战绩
	var rank_icon := TextureRect.new()
	rank_icon.texture = G.res_tex(_rank_icon_name())
	rank_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rank_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rank_icon.position = Vector2(12, 4 + top_pad)
	rank_icon.size = Vector2(52, 52)
	rank_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rank_icon)

	# 段位名与战绩：段位名用深棕加粗、显著高于辅助行（§7 第二层核心信息）
	_info = G.gold_label("", G.FS_MD, true, Color("4a3010"), false)
	_info.position = Vector2(74, 6 + top_pad)
	_info.custom_minimum_size = Vector2(CONTENT_W - 74.0, 0)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(_info)

	# 规则说明属于第三层辅助信息：字号小一档、颜色降饱和但要保住对比度
	# （原 8a6a34 在羊皮纸上只有约 3.1:1，13px 下偏灰；提到 6a5230 后约 4.6:1）
	var rule := G.gold_label("胜利提升段位分，失败小幅扣分", G.FS_XS, false, Color("6a5230"), false)
	rule.position = Vector2(74, 34 + top_pad)
	rule.custom_minimum_size = Vector2(CONTENT_W - 74.0, 0)
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(rule)

	var divider := ColorRect.new()
	divider.color = Color("c9a85a", 0.42)
	divider.position = Vector2(0, 68 + top_pad)
	divider.size = Vector2(CONTENT_W, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)

	# 对手预览卡：图标 + 名称 + 等级，避免整块面板只有文字。
	# 用 Panel（非 PanelContainer）：PanelContainer 会把所有子节点拉伸铺满整卡，手摆的图标/两行字会互相重叠。
	var foe_card := Panel.new()
	foe_card.position = Vector2(0, 86 + top_pad)
	foe_card.size = Vector2(CONTENT_W, 100)
	var foe_sb := StyleBoxFlat.new()
	foe_sb.bg_color = Color(0.32, 0.23, 0.13, 0.16)
	foe_sb.set_corner_radius_all(10)
	foe_sb.set_border_width_all(1)
	foe_sb.border_color = Color("a07a3a", 0.48)
	foe_card.add_theme_stylebox_override("panel", foe_sb)
	foe_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(foe_card)
	var foe_icon := TextureRect.new()
	foe_icon.texture = G.res_tex("icon_double_edge")
	foe_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foe_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foe_icon.position = Vector2(18, 16)
	foe_icon.size = Vector2(68, 68)
	foe_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_card.add_child(foe_icon)
	_foe_l = G.gold_label("", G.FS_LG, true, Color("4a3010"), false)
	_foe_l.position = Vector2(104, 20)
	_foe_l.custom_minimum_size = Vector2(280, 0)
	_foe_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	foe_card.add_child(_foe_l)
	_foe_tip = G.gold_label("", G.FS_XS, false, Color("6a5230"), false)
	_foe_tip.position = Vector2(104, 58)
	_foe_tip.custom_minimum_size = Vector2(280, 0)
	_foe_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	foe_card.add_child(_foe_tip)

	# 对手模式切换（轮次 18）：傀儡好上手，镜影是"你自己"——同套技能与养成，打的每一手都认得
	_mode_btn = G.ghost_button("对手：傀儡", G.BTN_S.x, G.BTN_S.y, G.FS_SM)
	_mode_btn.position = Vector2(0, 226 + top_pad)
	_mode_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_mirror = not _mirror
			Audio.sfx("ui_confirm")
			_refresh())
	content.add_child(_mode_btn)

	# 提示行：与模式按钮同一行右侧，不与按钮行抢竖排空间
	var tip := G.gold_label("不耗资源 · 只磨战术", G.FS_XS,
		false, Color("6a5230"), false)
	tip.position = Vector2(G.BTN_S.x + 12.0, 238 + top_pad)
	tip.custom_minimum_size = Vector2(CONTENT_W - G.BTN_S.x - 12.0, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(tip)

	# 主次分明（§7 光效预算）：整块面板只有一个金色主按钮，换对手和返回都走描边次级款。
	# 对齐（§5 网格）：BTN_L 高 52、BTN_M 高 44，两枚按钮按垂直中心对齐（不是按 top 对齐）
	var btn_cy := 282.0 + top_pad
	var reroll := G.ghost_button("换对手", G.BTN_M.x, G.BTN_M.y, G.FS_SM)
	reroll.position = Vector2(0, btn_cy - G.BTN_M.y * 0.5)
	reroll.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_page")
			_foe_lv = clampi(_foe_lv + (1 if randf() < 0.5 else -1), 1, 99)
			_refresh())
	content.add_child(reroll)

	_go_btn = G.gold_button("开始切磋", G.BTN_L.x, G.BTN_L.y)
	_go_btn.position = Vector2(CONTENT_W - G.BTN_L.x, btn_cy - G.BTN_L.y * 0.5)
	_go_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_start_battle())
	content.add_child(_go_btn)

	var back := G.ghost_button("返回", G.BTN_S.x, G.BTN_S.y, G.FS_SM)
	# 返回按钮与按钮行拉开 16，落在整个面板的底部收尾位
	back.position = Vector2((CONTENT_W - G.BTN_S.x) * 0.5, 324 + top_pad)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_close")
			closed.emit())
	content.add_child(back)
	_refresh()


func _rank_icon_name() -> String:
	match G.arena_rank():
		"铜印": return "rank_bronze"
		"银印": return "rank_silver"
		"金印": return "rank_gold"
		"铂印": return "rank_platinum"
		"钻印": return "rank_diamond"
	return "rank_bronze"


func _refresh() -> void:
	_info.text = "%s · %d 分 · %d 胜 %d 负" % [G.arena_rank(),
		int(G.arena.get("score", 0)), int(G.arena.get("wins", 0)), int(G.arena.get("losses", 0))]
	# 傀儡名里已带等级（"演武傀儡 · N 级"），这里不再重复拼 Lv.
	_foe_l.text = "对手：%s" % String(_foe().get("name", ""))
	if _foe_tip != null:
		_foe_tip.text = "镜像对局 · 同套技能与养成加成" if _mirror else "练手对局 · 数值随等级缩放"
	if _mode_btn != null:
		var ml := _mode_btn.get_child(0) as Label
		if ml != null:
			ml.text = "对手：镜影" if _mirror else "对手：傀儡"


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
	var win := result == "victory"
	var res: Dictionary = G.arena_result(win)
	_busy = false
	_set_busy_look(false)
	_toast("切磋%s · 段位分 %+d（%s · %d 分）" % ["得胜" if win else "落败",
		int(res.get("delta", 0)), String(res.get("rank", "")), int(res.get("score", 0))])
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
