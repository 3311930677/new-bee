extends Node

var _fails := 0

func _check(ok: bool, line: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + line)

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_aftermath.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	var done: Array = []
	for i in range(1, 37): done.append("s%02d" % i)
	G.prog["story"] = {"step": "", "done": done, "goals": {}}
	G.prog["main_world"] = WorldSession.normalize_state({})
	_check(G.side_quest_rows().size() == 36, "原24条和新12条均保留")
	var tested := 0
	for row in G.side_quest_rows():
		if (row.get("steps", []) as Array).is_empty(): continue
		var qid := String(row.id)
		_check(bool(G.side_accept(qid).get("ok", false)), qid + "可明确接取")
		var steps: Array = row.steps
		var last: Dictionary = steps.back()
		_check(not bool(G.side_entity_interact(String(last.kind), String(last.target_entity), String(last.map), qid).get("ok", false)),
			qid + "不允许跳过前段")
		for objective in steps:
			var eid := String(objective.target_entity)
			var mid := String(objective.map)
			var kind := String(objective.kind)
			_check(G.side_entity_visible(eid, qid), eid + "按当前阶段出现")
			var entity: Dictionary = TableCache.main_world_map(mid).get("entities", {}).get(eid, {})
			_check(String(entity.get("quest", "")) == qid and String(entity.get("kind", "")) == kind, eid + "生产地图确有实体")
			var before := G.prog.duplicate(true)
			var old_items := G.items.duplicate(true)
			var good := String(objective.get("correct", ""))
			var options: Dictionary = objective.get("choices", {})
			if not options.is_empty():
				if good.is_empty(): good = String(options.keys()[0])
				_check(not bool(G.side_entity_interact(kind, eid, mid, qid, "unknown").get("ok", false)) and G.prog == before, "非法选择无副作用")
				if not String(objective.get("correct", "")).is_empty():
					for bad in options:
						if String(bad) == good: continue
						var wrong := G.side_entity_interact(kind, eid, mid, qid, String(bad))
						_check(not bool(wrong.get("ok", false)) and not String(wrong.get("line", "")).is_empty() and G.prog == before,
							"错误组合给反证，拓片与进度不损坏")
			G.save_locked = true
			_check(not bool(G.side_entity_interact(kind, eid, mid, qid, good).get("ok", false)) and G.prog == before and G.items == old_items,
				"锁盘事件不推进")
			G.save_locked = false
			_check(bool(G.side_entity_interact(kind, eid, mid, qid, good).get("ok", false)), eid + "能推进")
			before = G.prog.duplicate(true)
			_check(not bool(G.side_entity_interact(kind, eid, mid, qid, good).get("ok", false)) and G.prog == before, "重复实体不重复计数")
			_check(G.reload_save() and not G.side_entity_visible(eid, qid), "阶段与实体去重可从磁盘恢复")
		_check(G.side_status_of(qid) == QuestService.SIDE_READY, qid + "完整目标后可交付")
		var gold := int(G.wallet.gold)
		var before := G.prog.duplicate(true)
		G.save_locked = true
		_check(G._side_complete(qid).is_empty() and G.prog == before and int(G.wallet.gold) == gold, "交付锁盘不发奖")
		G.save_locked = false
		_check(bool(G._side_complete(qid).get("ok", false)) and int(G.wallet.gold) == gold + int(row.reward.gold), "交付只发数据表中的等值奖励")
		gold = int(G.wallet.gold)
		_check(G._side_complete(qid).is_empty() and int(G.wallet.gold) == gold, "重复领奖不给第二次")
		_check((G.act1_state().discoveries as Array).has(qid), "交付写入图志来源")
		tested += 1
	_check(tested == 12, "十二条完整接取至交付")
	var journal := preload("res://src/ui/FieldJournalPanel.gd").new()
	add_child(journal)
	await get_tree().process_frame
	for volume in range(4):
		journal._volume = volume
		journal._refresh()
		_check(journal._list.get_child_count() > 0, "行旅图志四卷都有真实记录或空白提示")
		await get_tree().process_frame
	journal._volume = 3
	journal._refresh()
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--screens"):
		DirAccess.make_dir_recursive_absolute("res://shots/body_content_20261004")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/body_content_20261004/journal.png")
	journal.queue_free()
	await get_tree().process_frame
	await _test_npc_selection()
	await _test_map_input("zs")
	await _test_map_input("fs")
	# 留一个进行中阶段给独立的下一进程重读，而非同进程缓存。
	G.SAVE_PATH = "res://tools/_logs/save_verify_aftermath_resume.json"
	G._init_state_defaults()
	G.prog["story"] = {"step": "", "done": done, "goals": {}}
	G.prog["main_world"] = WorldSession.normalize_state({})
	G.selected_role = "zs"
	G.save_locked = false
	_check(bool(G.side_accept("a1_secret_rubbing").get("ok", false)), "恢复夹具可接取")
	_check(bool(G.side_entity_interact("inspect", "a1_secret_rubbing_step_1", "stele_cavern", "a1_secret_rubbing").get("ok", false)), "跨进程夹具中途保存")
	print("AFTERMATH_OK quests=12" if _fails == 0 else "AFTERMATH_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _button(root: Node, text: String) -> Control:
	if root is Button and root.text.replace(" ", "") == text.replace(" ", ""): return root
	if root is Label and root.text.replace(" ", "") == text.replace(" ", "") and root.get_parent() is Control: return root.get_parent()
	for child in root.get_children():
		var result := _button(child, text)
		if result != null: return result
	return null

func _test_npc_selection()->void:
	G.act1_state().side_quests.erase("a1_trade_bridge")
	var run:=RunState.new()
	run.setup({"role_id":"zs","theme":"forest","level":20,"seed":751})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":"lorin_wilds","run":run,"node":{"type":"normal","layer":0,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	var city:CityScene=map._city_content
	city._close_panel()
	city._open_npc_jobs(G.city_npc("npc_smith"))
	var button:=_button(city._panel,"楔住归桥 · 未接取")
	_check(button!=null,"结局后能从NPC列表选择前幕新增托付")
	if button!=null:
		var input:=InputEventMouseButton.new()
		input.button_index=MOUSE_BUTTON_LEFT
		input.pressed=true
		button.gui_input.emit(input)
		var accept:=_button(city._panel,"接下这份托付")
		_check(accept!=null,"选择前幕托付后保持明确接取")
		if accept!=null:accept.gui_input.emit(input)
		_check(G.side_status_of("a1_trade_bridge")==QuestService.SIDE_ACTIVE,"明确按钮接取前幕余波")
		var track:=_button(city._panel,"追踪这份托付")
		_check(track!=null,"选定托付刷新时不被第四幕默认任务覆盖")
		if track!=null:track.gui_input.emit(input)
		_check(G.side_tracked()=="a1_trade_bridge","选定前幕托付可以继续追踪")
	city._close_panel()
	map._player.position=Vector2(580,730)
	var visible_count:=0
	for entity in map._quest_entities:
		if entity.kind=="feedback":
			entity._process(0)
			if entity._caption_label.visible:visible_count+=1
	_check(visible_count==1,"多个已完成反馈附近仅最近一处显示标题")
	map.queue_free()
	await get_tree().process_frame

func _test_map_input(role: String) -> void:
	G.selected_role = role
	# Reuse completed quest data as a fresh fixture; ledger also reset for this scene check.
	G.act1_state().side_quests.erase("a1_secret_rubbing")
	_check(bool(G.side_accept("a1_secret_rubbing").get("ok", false)), "真实地图输入夹具接取")
	var run := RunState.new()
	run.setup({"role_id": role, "theme": "tomb", "level": 20, "seed": 751})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "stele_cavern", "run": run, "node": {"type": "boss", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	for i in range(1, 5):
		var eid := "a1_secret_rubbing_step_%d" % i
		var entity: Node = null
		for ent in map._quest_entities:
			if ent.eid == eid: entity = ent
		_check(entity != null, role + "地图依阶段生成目标")
		if entity == null: continue
		map.on_quest_entity(entity)
		if i == 4:
			_check(map._puzzle_panel != null, "拓片选择面板实际打开")
			if map._puzzle_panel != null:
				var button := _button(map._puzzle_panel, "岩纹 → 刀痕 → 缺口")
				_check(button != null, "选择按钮实际存在")
				if button != null:
					var input := InputEventMouseButton.new()
					input.button_index = MOUSE_BUTTON_LEFT
					input.pressed = true
					button.gui_input.emit(input)
		await get_tree().process_frame
		await get_tree().process_frame
	_check(G.side_status_of("a1_secret_rubbing") == QuestService.SIDE_READY, "两职业真实面板输入可到交付态")
	map.queue_free()
	await get_tree().process_frame
