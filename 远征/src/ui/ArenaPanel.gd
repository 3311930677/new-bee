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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.sfx("ui_open")
	_foe_lv = maxi(1, int(G.prog.get("level", 1)))
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var banner := G.banner_box("演 武 场", 280, 50)
	banner.position = Vector2((VIEW_W - 280.0) * 0.5, 120)
	add_child(banner)

	_panel = G.parchment_box(440, 430, 16.0)
	_panel.position = Vector2(20, 184)
	add_child(_panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(content)

	# 段位与战绩
	_info = G.gold_label("", G.FS_SM, false, Color("5a4020"), false)
	_info.position = Vector2(0, 4)
	_info.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_child(_info)

	# 对手预览
	_foe_l = G.gold_label("", G.FS_LG, true, Color("6a4a1e"), false)
	_foe_l.position = Vector2(0, 64)
	_foe_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	_foe_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_foe_l)

	var tip := G.gold_label("与演武傀儡切磋：胜加分、败小扣（不掉装备不掉钱）",
		G.FS_XS, false, Color("8a6a34"), false)
	tip.position = Vector2(0, 104)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tip)

	# 换对手 / 开始切磋
	var reroll := G.gold_button("换 对 手", 170, 44, G.FS_SM)
	reroll.position = Vector2(20, 160)
	reroll.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_page")
			_foe_lv = clampi(_foe_lv + (1 if randf() < 0.5 else -1), 1, 99)
			_refresh())
	content.add_child(reroll)

	var go := G.gold_button("开 始 切 磋", 190, 52)
	go.position = Vector2(210, 156)
	go.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_start_battle())
	content.add_child(go)

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 300)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_close")
			closed.emit())
	content.add_child(back)
	_refresh()


func _refresh() -> void:
	_info.text = "%s · %d 分 · %d 胜 %d 负" % [G.arena_rank(),
		int(G.arena.get("score", 0)), int(G.arena.get("wins", 0)), int(G.arena.get("losses", 0))]
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
	_toast("切磋%s · 段位分 %+d（%s · %d 分）" % ["得胜" if win else "落败",
		int(res.get("delta", 0)), String(res.get("rank", "")), int(res.get("score", 0))])
	_refresh()


func _toast(msg: String) -> void:
	var l := G.gold_label(msg, G.FS_SM, false, Color("ffe9b0"))
	l.position = Vector2(0, 120)
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
