extends Node

var _fails := 0

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_stele_puzzle.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "碑窟测试"
	G.prog["story"] = {"step": "s10", "done": ["s09"], "goals": {}}
	_check(G.save_game(), "隔离档可写")
	await _run()
	await _run_rooms()
	await _run_shadow_fight()
	print("STELE_PUZZLE_OK" if _fails == 0 else "STELE_PUZZLE_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)

func _entity(map: MapScene, eid: String) -> Node2D:
	for ent in map._quest_entities:
		if is_instance_valid(ent) and ent.eid == eid and not ent.used: return ent
	return null

func _button(node: Node, wanted: String) -> Control:
	var needle := wanted.replace(" ", "")
	for child in node.get_children():
		if child is Label and needle in String(child.text).replace(" ", "") and node is Control:
			return node
		var found := _button(child, wanted)
		if found != null: return found
	return null

func _click(button: Control) -> void:
	_check(button != null, "机关选项按钮可见")
	if button == null: return
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	button.gui_input.emit(e)

func _run() -> void:
	var run := RunState.new()
	run.setup({"theme": "tomb", "role_id": "zs", "level": 12,
		"active_pet": "pet_rockturtle", "bench_pet": "", "potions": 2, "seed": 601})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "stele_cavern", "run": run,
		"node": {"type": "boss", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	_check(_entity(map, "act1_echo_rubbing") != null and
		_entity(map, "act1_echo_west") == null, "先见拓痕，后见可调碑座")
	_check(map._story_battle_ready("mon_stele_warden"), "旧档不被新增机关硬卡")
	var rubbing := _entity(map, "act1_echo_rubbing")
	if rubbing != null: map.on_quest_entity(rubbing)
	await get_tree().process_frame
	_check(bool(G.prog.flags.get("act1_stele_clue", false)) and
		_entity(map, "act1_echo_west") != null, "拓片线索持久并解锁首座")
	_check(not map._story_battle_ready("mon_stele_warden"), "已开始机关时需完成校准")
	var west := _entity(map, "act1_echo_west")
	if west != null: map.on_quest_entity(west)
	_check(map._puzzle_panel != null and map._modal_open(), "实际碑座选择面板打开")
	if map._puzzle_panel != null:
		_click(_button(map._puzzle_panel, "引回拖长尾音"))
	await get_tree().process_frame
	_check(not bool(G.prog.flags.get("act1_stele_seat_1", false)) and
		_entity(map, "act1_echo_west") != null, "错误选择给反证，可重试且不记进度")
	west = _entity(map, "act1_echo_west")
	if west != null: map.on_quest_entity(west)
	if map._puzzle_panel != null:
		_click(_button(map._puzzle_panel, "引回两声轻响"))
	await get_tree().process_frame
	_check(bool(G.prog.flags.get("act1_stele_seat_1", false)) and
		_entity(map, "act1_echo_east") != null, "正解解锁第二碑座")
	_check(G.reload_save() and bool(G.prog.flags.get("act1_stele_seat_1", false)),
		"中途退出后机关状态可重读")
	var east := _entity(map, "act1_echo_east")
	if east != null: map.on_quest_entity(east)
	if map._puzzle_panel != null:
		_click(_button(map._puzzle_panel, "缺口朝碑心"))
	await get_tree().process_frame
	_check(bool(G.prog.flags.get("act1_stele_seat_2", false)) and
		map._story_battle_ready("mon_stele_warden"), "两碑归位后原首领可挑战")
	var already := G.prog.duplicate(true)
	_check(not bool(G.world_puzzle_interact("stele_cavern", "act1_echo_east", "heart").get("ok", false))
		and G.prog == already, "重复碑座事件不得改档")
	map.queue_free()

func _enter_cavern() -> MapScene:
	var run := RunState.new()
	run.setup({"theme": "tomb", "role_id": "zs", "level": 12,
		"active_pet": "pet_rockturtle", "bench_pet": "", "potions": 2, "seed": 613})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "stele_cavern", "run": run,
		"node": {"type": "boss", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	return map

func _run_rooms() -> void:
	await get_tree().process_frame
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "新碑窟测试"
	G.prog["story"] = {"step": "s09", "done": ["s08"], "goals": {}}
	_check(G.save_game(), "新进入 s09 的隔离档可写")
	var map := await _enter_cavern()
	_check(bool(G.prog.flags.get("act1_stele_rooms_v1", false)) and
		G.story_step_done("s09"), "新进入碑窟的存档启用三房规则")
	_check(map._stele_room_gates.has("echo") and map._stele_room_gates.has("heart"),
		"入口房与碑座房由两道实体门隔开")
	_check(not bool(G.world_puzzle_interact("stele_cavern", "act1_echo_west", "old").get("ok", false)),
		"新存档未听三处石缝不能通过直接调用先调碑座")
	_check(not map._story_battle_ready("mon_stele_warden"),
		"新存档不解三房不能隔门直接打首领")
	map._player.position = Vector2(480, 810)
	await get_tree().physics_frame
	var blocked := map._player.move_and_collide(Vector2(0, -100))
	_check(blocked != null and map._player.position.y > 755,
		"第一道石门有真实角色碰撞，不能穿墙")
	for eid in ["act1_echo_crack_left", "act1_echo_crack_middle", "act1_echo_crack_right"]:
		var crack := _entity(map, eid)
		_check(crack != null, "三处石缝可在入口房观察：" + eid)
		if crack != null: map.on_quest_entity(crack)
		await get_tree().process_frame
	var rubbing := _entity(map, "act1_echo_rubbing")
	if rubbing != null: map.on_quest_entity(rubbing)
	await get_tree().process_frame
	_check(map._stele_room_one_ready() and not map._stele_room_gates.has("echo") and
		_entity(map, "act1_echo_west") != null,
		"三处石缝与拓片齐备后第一道门打开")
	map._player.position = Vector2(480, 810)
	await get_tree().physics_frame
	map._player.move_and_collide(Vector2(0, -100))
	_check(map._player.position.y < 755, "第一道门开启后角色确实能进入碑座房")
	map.queue_free()


	await get_tree().process_frame
	_check(G.reload_save(), "退出入口房后可读档")
	map = await _enter_cavern()
	_check(not map._stele_room_gates.has("echo") and map._stele_room_gates.has("heart"),
		"重进碑窟保留第一道门状态，第二道门仍关闭")
	map._player.position = Vector2(480, 595)
	await get_tree().physics_frame
	blocked = map._player.move_and_collide(Vector2(0, -100))
	_check(blocked != null and map._player.position.y > 540,
		"未调两座碑座时第二道门挡住首领房")
	var west := _entity(map, "act1_echo_west")
	if west != null: map.on_quest_entity(west)
	if map._puzzle_panel != null: _click(_button(map._puzzle_panel, "引回两声轻响"))
	await get_tree().process_frame
	_check(_entity(map, "act1_echo_east") == null and
		_entity(map, "act1_echo_shadow") != null,
		"第一座归位后先处理守影选择，不能直接跳到第二座")
	var shadow := _entity(map, "act1_echo_shadow")
	if shadow != null: map.on_quest_entity(shadow)
	if map._puzzle_panel != null: _click(_button(map._puzzle_panel, "循侧壁阴刻绕过"))
	await get_tree().process_frame
	_check(bool(G.prog.flags.get("act1_stele_shadow_avoided", false)),
		"绕行分支写档后不强迫战斗")
	var east := _entity(map, "act1_echo_east")
	_check(east != null, "第一枚碑座开启同房间的第二枚")
	if east != null: map.on_quest_entity(east)
	if map._puzzle_panel != null: _click(_button(map._puzzle_panel, "缺口朝碑心"))
	await get_tree().process_frame
	_check(not map._stele_room_gates.has("heart") and
		map._story_battle_ready("mon_stele_warden"),
		"两座碑座归位后首领房开放")
	map._player.position = Vector2(480, 595)
	await get_tree().physics_frame
	map._player.move_and_collide(Vector2(0, -100))
	_check(map._player.position.y < 540, "第二道门开启后角色确实能进入首领房")
	var boss: Node = null
	for monster in map._monsters:
		if monster.mon_id == "mon_stele_warden": boss = monster
	_check(boss != null, "原失声碑灵仍在第三房")
	if boss != null:
		map.call("_start_battle", boss)
		_check(map._battle != null, "原首领仍触发真实战斗")
		if map._battle != null:
			_check(bool(map._battle._cfg.get("stele_echo_ready", false)) and
				"两声轻响" in map._battle._cast_tip.text,
				"碑座稳定使首领开场预兆在战斗界面可读")
			map._battle.sim.finished = true
			map._battle.sim.result = "victory"
			map._battle.confirm_result()
			await get_tree().process_frame
	_check(G.story_step_done("s10") and G.item_count("stele_fragment") == 1,
		"三房战斗胜利仍只发原 s10 首通碑片")
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "首领战后可读档")
	map = await _enter_cavern()
	_check(map._stele_room_gates.is_empty() and map._main_boss_cleared() and
		G.item_count("stele_fragment") == 1,
		"首通后重进不重置门、首领或剧情物")
	map.queue_free()

func _run_shadow_fight() -> void:
	await get_tree().process_frame
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.prog["story"] = {"step": "s10", "done": ["s09"], "goals": {}}
	G.prog["flags"] = {"act1_stele_rooms_v1": true,
		"act1_echo_crack_left": true, "act1_echo_crack_middle": true,
		"act1_echo_crack_right": true, "act1_stele_clue": true,
		"act1_stele_seat_1": true}
	_check(G.save_game(), "守影战斗分支隔离档可写")
	var map := await _enter_cavern()
	var sign := _entity(map, "act1_echo_shadow")
	_check(sign != null and _entity(map, "act1_echo_east") == null,
		"中廊守影抉择在第二碑座前出现")
	if sign != null: map.on_quest_entity(sign)
	if map._puzzle_panel != null: _click(_button(map._puzzle_panel, "敲响残碑迎战守影"))
	await get_tree().process_frame
	_check(bool(G.prog.flags.get("act1_stele_shadow_challenged", false)) and
		not bool(G.prog.flags.get("act1_stele_shadow_defeated", false)) and
		_entity(map, "act1_echo_east") == null,
		"选择迎战后必须取胜，第二碑座暂不出现")
	var guardian: Node = null
	for monster in map._monsters:
		if monster.idx == 3000: guardian = monster
	_check(guardian != null, "守影选择在中廊生成真实怨灵")
	if guardian != null:
		map.call("_start_battle", guardian)
		if map._battle != null:
			map._battle.sim.finished = true
			map._battle.sim.result = "flee"
			map._battle.confirm_result()
			await get_tree().process_frame
	_check(not bool(G.prog.flags.get("act1_stele_shadow_defeated", false)) and
		_entity(map, "act1_echo_east") == null,
		"守影战撤退不算胜利，碑座仍锁定")
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "撤退后守影选择可读档")
	map = await _enter_cavern()
	guardian = null
	for monster in map._monsters:
		if monster.idx == 3000: guardian = monster
	_check(guardian != null, "撤退重进仍能再挑战守影")
	if guardian != null:
		map.call("_start_battle", guardian)
		if map._battle != null:
			map._battle.sim.finished = true
			map._battle.sim.result = "victory"
			map._battle.confirm_result()
			await get_tree().process_frame
	_check(bool(G.prog.flags.get("act1_stele_shadow_defeated", false)) and
		_entity(map, "act1_echo_east") != null and G.item_count("stele_fragment") == 0,
		"真实胜利才开放第二碑座，守影不提前发首通碑片")
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "守影胜利可读档")
	map = await _enter_cavern()
	var guardian_again := false
	for monster in map._monsters:
		if monster.idx == 3000: guardian_again = true
	_check(not guardian_again and _entity(map, "act1_echo_east") != null,
		"守影胜利重进不再刷出，碑座状态保留")
	map.queue_free()