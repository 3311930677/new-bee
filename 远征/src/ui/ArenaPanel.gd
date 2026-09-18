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
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.025, 0.02, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 木匾压在面板上沿（挂牌式），整块弹窗落在屏幕视觉中心，不再悬在半空
	var banner := G.banner_box("演武场", 280, 50)
	banner.position = Vector2((VIEW_W - 280.0) * 0.5, 150)
	banner.z_index = 2
	add_child(banner)

	var subtitle := G.gold_label("擂台试锋 · 不损装备，不耗资源", G.FS_XS, false, Color("c7a46b"), false)
	subtitle.z_index = 3
	subtitle.position = Vector2(0, 126)
	subtitle.custom_minimum_size = Vector2(VIEW_W, 0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	_panel = G.parchment_box(440, 420, 16.0)
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
	rank_icon.position = Vector2(12, 4)
	rank_icon.size = Vector2(52, 52)
	rank_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rank_icon)

	_info = G.gold_label("", G.FS_SM, false, Color("5a4020"), false)
	_info.position = Vector2(74, 8)
	_info.custom_minimum_size = Vector2(CONTENT_W - 74.0, 0)
	content.add_child(_info)

	var rule := G.gold_label("胜利提升段位分，失败小幅扣分", G.FS_XS, false, Color("8a6a34"), false)
	rule.position = Vector2(74, 34)
	rule.custom_minimum_size = Vector2(CONTENT_W - 74.0, 0)
	content.add_child(rule)

	var divider := ColorRect.new()
	divider.color = Color("c9a85a", 0.42)
	divider.position = Vector2(0, 68)
	divider.size = Vector2(CONTENT_W, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)

	# 对手预览卡：图标 + 名称 + 等级，避免整块面板只有文字。
	# 用 Panel（非 PanelContainer）：PanelContainer 会把所有子节点拉伸铺满整卡，手摆的图标/两行字会互相重叠。
	var foe_card := Panel.new()
	foe_card.position = Vector2(0, 86)
	foe_card.size = Vector2(CONTENT_W, 112)
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
	foe_icon.position = Vector2(18, 20)
	foe_icon.size = Vector2(68, 68)
	foe_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_card.add_child(foe_icon)
	_foe_l = G.gold_label("", G.FS_LG, true, Color("6a4a1e"), false)
	_foe_l.position = Vector2(104, 26)
	_foe_l.custom_minimum_size = Vector2(280, 0)
	foe_card.add_child(_foe_l)
	var foe_tip := G.gold_label("演武傀儡 · 练手对局", G.FS_XS, false, Color("8a6a34"), false)
	foe_tip.position = Vector2(104, 62)
	foe_tip.custom_minimum_size = Vector2(280, 0)
	foe_card.add_child(foe_tip)

	var tip := G.gold_label("不掉装备、不耗资源，专注磨练战术", G.FS_XS,
		false, Color("8a6a34"), false)
	tip.position = Vector2(0, 214)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tip)

	# 主次分明（§7 光效预算）：整块面板只有一个金色主按钮，换对手和返回都走描边次级款。
	# 两个按钮左右贴齐 408 内容宽、底边对齐，不再各自留 20px 的随手内缩。
	var reroll := G.ghost_button("换对手", G.BTN_M.x, G.BTN_M.y, G.FS_SM)
	reroll.position = Vector2(0, 260)
	reroll.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_page")
			_foe_lv = clampi(_foe_lv + (1 if randf() < 0.5 else -1), 1, 99)
			_refresh())
	content.add_child(reroll)

	_go_btn = G.gold_button("开始切磋", G.BTN_L.x, G.BTN_L.y)
	_go_btn.position = Vector2(CONTENT_W - G.BTN_L.x, 252)
	_go_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_start_battle())
	content.add_child(_go_btn)

	var back := G.ghost_button("返回", G.BTN_S.x, G.BTN_S.y, G.FS_SM)
	back.position = Vector2((CONTENT_W - G.BTN_S.x) * 0.5, 336)
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
	_foe_l.text = "对手：%s" % String(G.make_arena_foe(_foe_lv).get("name", ""))


func _start_battle() -> void:
	if _busy:
		return
	_busy = true
	var foe := G.make_arena_foe(_foe_lv)
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
	if event.is_action_pressed("ui_cancel") and not _busy:
		Audio.sfx("ui_close")
		closed.emit()
		get_viewport().set_input_as_handled()
