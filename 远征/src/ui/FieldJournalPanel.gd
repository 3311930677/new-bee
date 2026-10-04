extends Control

signal closed

var _list: VBoxContainer
var _volume := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	G.veil(self, 0.8)
	var top := maxf(24, (get_viewport_rect().size.y - 680) * 0.5)
	var panel := G.parchment_box(440, 680, 16)
	panel.position = Vector2(20, top)
	add_child(panel)
	var content := Control.new()
	panel.add_child(content)
	var title := G.serif_label("行旅图志", G.FS_LG, G.TEXT_DARK)
	title.position = Vector2(12, 4)
	content.add_child(title)
	var names := ["地理", "怪物", "伙伴", "人物手记"]
	for i in names.size():
		var tab := G.gold_button(String(names[i]), 96, 44, G.FS_SM)
		tab.position = Vector2(i * 104, 52)
		tab.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_volume = i
				_refresh())
		content.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 112)
	scroll.size = Vector2(408, 454)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 16)
	scroll.add_child(_list)
	var back := G.ghost_button("返回", 160, 44)
	back.position = Vector2(124, 588)
	back.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: closed.emit())
	content.add_child(back)
	_refresh()

func _paragraph(text: String, heading := false) -> void:
	var label := G.text_label(text, G.FS_MD if heading else G.FS_SM, G.TEXT_DARK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 374
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(label)

func _refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var count := 0
	var world: Dictionary = G.prog.get("main_world", {})
	if _volume == 0:
		var visited: Array = (world.get("visited_maps", []) as Array).duplicate()
		var current := String(world.get("map_id", ""))
		if not current.is_empty() and not visited.has(current): visited.append(current)
		# 旧档有地图刷点记录的地点也是确实走过的来源。
		for mid in (world.get("respawn_by_map", {}) as Dictionary):
			if not visited.has(mid): visited.append(mid)
		for mid in visited:
			var cfg := TableCache.main_world_map(String(mid))
			if cfg.is_empty(): continue
			_paragraph(String(cfg.get("name", mid)), true)
			_paragraph("来源：亲历此地。\n%s" % String(cfg.get("goal", "道路与地貌仍待调查。")))
			count += 1
	elif _volume == 1:
		var known: Array = (G.act1_state().first_kills as Array).duplicate()
		for encounter in (world.get("encounters", {}) as Dictionary).values():
			if not (encounter is Dictionary): continue
			var mid := String(encounter.get("enemy_id", ""))
			if not mid.is_empty() and not known.has(mid): known.append(mid)
		for mid in known:
			var monster := TableCache.get_monster(String(mid))
			if monster.is_empty(): continue
			_paragraph(String(monster.get("name", mid)), true)
			var sources: Array = []
			for map_id in TableCache.main_world_config().get("maps", {}):
				var cfg := TableCache.main_world_map(String(map_id))
				if (cfg.get("monster_ids", []) as Array).has(mid): sources.append(String(cfg.get("name", map_id)))
			var moves: Array = []
			for move in monster.get("skills", []):
				if move is Dictionary: moves.append(String(move.get("name", "未知招式")))
			_paragraph("来源：真实遭遇记录。\n可见地貌：%s\n招式：%s" % ["、".join(sources), "、".join(moves)])
			_paragraph("材料按实际遭遇档位抽取，物种不固定档位；每种材料独立判定。剧情首通物和定向装备由主线另行结算。")
			var tiers := {"normal":"普通", "elite":"精英", "boss":"首领"}
			for tier in tiers:
				var chances: Array = []
				for drop in TableCache.drops_config().get("drops",{}).get(tier,[]):
					chances.append("%s %d%%（%d—%d件）"%[G.item_name(String(drop.item)),roundi(float(drop.chance)*100),int(drop.min),int(drop.max)])
				_paragraph("%s材料：%s"%[tiers[tier],"、".join(chances)])
			count += 1
	elif _volume == 2:
		for pid in G.owned_pets():
			var pet: Dictionary = TableCache.get_pet(String(pid))
			_paragraph(String(pet.get("name", pid)), true)
			_paragraph("来源：已经结伴的伙伴。培养与协战可在兽栏、霜关驿舍查看。")
			var hint:Dictionary=preload("res://src/world/ExplorationLinks.gd").config().get("pet_hints",{}).get(String(pid),{})
			if not hint.is_empty(): _paragraph("探索本领："+String(hint.line))
			count += 1
	else:
		for map_id in preload("res://src/world/DungeonTrial.gd").rows():
			if not bool(G.prog.get("flags",{}).get("trial_note_"+String(map_id),false)):continue
			var trial:Dictionary=preload("res://src/world/DungeonTrial.gd").row(String(map_id))
			_paragraph(String(trial.name)+" · 附注",true)
			_paragraph("来源：首通后自愿挑战。\n"+String(trial.note))
			count+=1
		for oath in preload("res://src/world/OathService.gd").rows():
			if not bool(G.prog.get("flags",{}).get("oath_pattern_"+String(oath.id),false)): continue
			var seal:=preload("res://src/ui/OathPattern.gd").new()
			seal.oath_id=String(oath.id)
			seal.earned=true
			_list.add_child(seal)
			_paragraph(String(oath.record),true)
			_paragraph("来源：%s出行目标。\n%s"%[String(oath.name),String(oath.desc)])
			count+=1
		for record in WorldCommission.state(G).values():
			if String(record.status) != "done": continue
			var commission := WorldCommission.row(String(record.template))
			_paragraph("事务 · " + String(commission.title), true)
			_paragraph("来源：%s公布的现场记录。\n%s" % [String(record.day), String(commission.desc)])
			if not String(record.get("choice", "")).is_empty():
				for step in commission.steps:
					if (step.get("choices", {}) as Dictionary).has(String(record.choice)):
						_paragraph("当时选择：" + String(step.choices[record.choice]))
			count += 1
		for row in G.side_quest_rows():
			if G.side_status_of(String(row.id)) != QuestService.SIDE_DONE: continue
			_paragraph(String(row.title), true)
			_paragraph("来源：%s的托付。\n%s" % [G.side_target_name(String(row.giver)), String(row.get("completion_dialogue", ""))])
			var branches: Dictionary = QuestService.side_get(G.act1_state(), String(row.id)).get("branch_flags", {})
			for objective in row.get("steps", []):
				var eid := String(objective.get("target_entity", ""))
				if branches.has(eid):
					_paragraph("当时选择：%s" % String((objective.get("choices", {}) as Dictionary).get(branches[eid], "已记录")))
			count += 1
	if count == 0: _paragraph("这一卷尚无亲历记录。走访地图、遭遇敌影、结伴或完成托付后会留下来源；未见之事仍留作空白。")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not G.ui_blocked:
		closed.emit()
		get_viewport().set_input_as_handled()
