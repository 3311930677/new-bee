## 地图内的驿路与终局挑战，容器布局适配短屏；战斗时禁止旅行。
extends Control
signal closed
signal travel_requested(map_id: String)
const Journey := preload("res://src/world/JourneyService.gd")
const Relics := preload("res://src/world/RelicService.gd")
var recommended := ""
var _tab := "travel"
var _list: VBoxContainer
var _message: Label
var _paper: PanelContainer
var _battle: Control = null
var _layer: CanvasLayer
var _ticket: Dictionary = {}
var _settle_result := ""
var _participants: Array = []
var _confirm := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	G.veil(self, .90)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_paper = G.parchment_box(420, 680, 16)
	center.add_child(_paper)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	_paper.add_child(body)
	var title := G.serif_label("驿路与传世", G.FS_LG, G.TEXT_DARK)
	body.add_child(title)
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	_button(tabs, "已探索地点", func(): _tab = "travel"; _refresh())
	_button(tabs, "传世挑战", func(): _tab = "hunt"; _refresh())
	_message = G.text_label("", G.FS_SM, G.TEXT_DARK)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(380, 70)
	body.add_child(_message)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	_button(body, "继续探索", close)
	resized.connect(_resize)
	_resize()
	_refresh()

func _resize() -> void:
	_paper.custom_minimum_size = Vector2(minf(420, size.x - 40), minf(680, size.y - 64))

func _text(parent: Node, words: String, big := false) -> Label:
	var label := G.text_label(words, G.FS_MD if big else G.FS_SM, G.TEXT_DARK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent: Node, words: String, callback: Callable, disabled := false) -> Control:
	var button := G.gold_button(words, 0, 44, G.FS_SM)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	button.modulate.a = .45 if disabled else 1.0
	button.gui_input.connect(func(e: InputEvent):
		if disabled: return
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or e.is_action_pressed("ui_accept"):
			callback.call()
			button.accept_event())
	parent.add_child(button)
	return button

func show_message(words: String) -> void:
	_message.text = words

func _refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _tab == "travel":
		_message.text = "首次到访解锁驿路 · 免费直达旧地点。运输与护送途中需亲自走路。"
		if not recommended.is_empty(): _message.text = "首领已击败，可以返回城镇交付任务，也可继续探索。"
		for row in Journey.cfg().get("points", []):
			var id := String(row.map)
			var status := Journey.status(G, id)
			var caption := String(row.name) + (" · 返回交任务" if id == recommended else "")
			_button(_list, caption, func(): travel_requested.emit(id), not bool(status.ok))
			_text(_list, String(status.line))
	else:
		var config := Relics.cfg()
		var state := Relics.state(G)
		var role := G.selected_role if not G.selected_role.is_empty() else "zs"
		var pending: Dictionary = state.get("pending", {})
		if not pending.is_empty(): role = String(pending.role)
		var miss := int(state.get("misses", {}).get(role, 0))
		_message.text = "通关且60级开放 · 传世武器掉率%.1f%%\n本职业保底%d/%d · 成功挑战%d次" % [float(config.drop_chance)*100, miss, int(config.pity_wins), int(state.get("wins", 0))]
		_text(_list, "每次胜利给精炼石×1、宠物粮×2。失败不计保底；传世挑战可立即再打。")
		for row in config.hunts:
			var id := String(row.id)
			_text(_list, String(row.name), true)
			_text(_list, String(row.hint))
			var resume := not pending.is_empty() and String(pending.hunt) == id
			_button(_list, "继续未结挑战" if resume else "挑战首领", _start_hunt.bind(id), not Relics.ready(G) or (not pending.is_empty() and not resume))
		var tpl := G.equip_tpl(Relics.template(role))
		_text(_list, String(tpl.get("name", "传世武器")) + " · 回收25,000金币", true)
		_text(_list, String(tpl.get("special_desc", "")))
		_button(_list, "购买武器 · %d金币" % int(config.buy_gold), _buy.bind(role), not Relics.ready(G) or int(state.get("wins", 0)) < int(config.buy_requires_wins) or not pending.is_empty())
		_text(_list, "成功挑战20次后可购买；传世武器自动锁定，可解锁后回收。")
		_text(_list, "宠物品阶：普通 → 稀有 → 史诗 → 传说 → 传世", true)
		_text(_list, "品阶代表种类与能力稀有程度；资质星级决定成长。同样等级也要看定位、技能和培养。")
		_button(_list, "传世·归路圣鹿 · 挑战120胜领取", _claim_pet, not Relics.ready(G) or int(state.get("wins", 0)) < int(config.pet_requires_wins) or G.owns_pet(String(config.pet_id)) or not pending.is_empty())
		_text(_list, "初始25级、4星资质，群体治疗与护盾；领取后可在伙伴页培养和派出。")
		if not _settle_result.is_empty(): _button(_list, "重试本场结算", _settle)

func _start_hunt(id: String) -> void:
	if _battle != null or not _settle_result.is_empty(): return
	var role := G.selected_role if not G.selected_role.is_empty() else "zs"
	var begin := Relics.begin(G, id, role)
	if not bool(begin.ok): show_message(String(begin.line)); return
	_ticket = begin.ticket
	role = String(_ticket.role)
	var hunt := Relics.hunt(String(_ticket.hunt))
	var pets := G.owned_pets()
	var active := G.companion_active()
	var bench := ""
	for pid in pets:
		if String(pid) != active: bench = String(pid); break
	BattleScene.pending_cfg = {"ally":{"role_id":role,"level":int(G.prog.level),"growth":G.growth_bonuses(role),
		"skill_levels":G.prog.get("skills",{}),"unlocked_skills":G.act1_unlocked_skills(role),"skill_variants":G.act1_skill_variants(role),
		"active_pet":active,"bench_pet":bench,"pet_stats":G.battle_pet_stats([active,bench]),"potions":G.run_potions_base()},
		"enemy":{"theme":String(hunt.theme),"node_type":"boss","solo":true,"lead_mon":String(hunt.boss),
			"display_level":int(hunt.level),"world_map_id":String(hunt.map),"difficulty_override":hunt.difficulty},
		"mode":"pve","flee_rule":"free","seed":int(_ticket.seed),"player_name":G.display_name()}
	_layer = CanvasLayer.new()
	_layer.layer = 7
	add_child(_layer)
	_battle = (load("res://src/battle/BattleScene.tscn") as PackedScene).instantiate()
	_battle.battle_finished.connect(_battle_finished)
	_layer.add_child(_battle)

func _battle_finished(result: String, _hp: int) -> void:
	if _battle == null or not _battle.sim.finished: return
	# Use the simulator's final outcome; its timeout is a failed PVE hunt.
	if result != "flee": result = "victory" if _battle.sim.result == "victory" else "defeat"
	_participants = _battle.sim.companion_participants.duplicate()
	_layer.queue_free()
	_battle = null
	_settle_result = result
	_settle()

func _settle() -> void:
	var result := Relics.finish(G, String(_ticket.get("id", "")), _settle_result, _participants)
	if bool(result.ok): _settle_result = ""; _ticket = {}
	_refresh()
	show_message(String(result.line))

func _buy(role: String) -> void:
	if _confirm != "buy":
		_confirm = "buy"
		show_message("再次点购买确认花费%d金币购买本职业传世武器。" % int(Relics.cfg().buy_gold))
		return
	_confirm = ""
	var result := Relics.buy(G, role)
	_refresh()
	show_message(String(result.line))

func _claim_pet() -> void:
	var result := Relics.claim_pet(G)
	_refresh()
	show_message(String(result.line))

func close() -> void:
	if _battle != null: return
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if event.is_action_pressed("ui_cancel") and _battle == null:
		get_viewport().set_input_as_handled()
		close()
