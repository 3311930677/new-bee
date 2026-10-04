extends Node

var _fails := 0

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_boss_puzzles.json"
	await _run_case("tidal_gate", "s19", "s18", "gate_clue", "mon_tide_priest",
		["act2_tide_record", "act2_tide_upper", "act2_tide_bridge"], ["old", "bridge"], "main")
	await _run_case("rift_mine_vault", "s25", "s24", "mine_record", "mon_redsand_guard",
		["act3_mine_record", "act3_mine_wheel", "act3_mine_switch"], ["west", "north"], "east")
	await _run_tidal_rooms()
	await _run_tidal_cargo_route()
	await _run_tidal_prior_save()
	for role in ["zs", "ck", "fs", "fz"]:
		await _run_mine_rooms(role)
	print("BOSS_PUZZLES_OK" if _fails == 0 else "BOSS_PUZZLES_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + message)


func _enter_mine(role: String) -> MapScene:
	var run := RunState.new()
	run.setup({"theme": "tomb", "role_id": role, "level": 32, "seed": 921})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "rift_mine_vault", "run": run,
		"node": {"type": "boss", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	map.map_finished.connect(_ignore_map_finish)
	add_child(map)
	await get_tree().process_frame
	await get_tree().physics_frame
	return map


func _mine_choose(map: MapScene, eid: String, label: String) -> void:
	var entity := _entity(map, eid)
	_check(entity != null, "矿脉机关实体存在：" + eid)
	if entity == null: return
	map.on_quest_entity(entity)
	if map._puzzle_panel != null: _click(_button(map._puzzle_panel, label))
	await get_tree().process_frame
	await get_tree().process_frame


func _run_mine_rooms(role: String) -> void:
	G._init_state_defaults()
	G.prog["main_world"] = WorldSession.normalize_state({})
	G.save_locked = false
	G.selected_role = role
	G.items["mine_record"] = 1
	G.prog["story"] = {"step": "s25", "done": ["s24"], "goals": {}}
	G.prog["flags"] = {"act3_mine_rooms_v1": true}
	_check(G.save_game(), role + " 矿脉隔离档可写")
	var map := await _enter_mine(role)
	_check(map._mine_room_gates.size() == 2 and not map._story_battle_ready("mon_redsand_guard"),
		role + " 两道实体门与机关首领门禁")
	map._player.position = Vector2(550, 850)
	await get_tree().physics_frame
	_check(map._player.move_and_collide(Vector2(0, -110)) != null and map._player.position.y > 785,
		"未读记录不能穿过第一房")
	var record := _entity(map, "act3_mine_record")
	if record != null: map.on_quest_entity(record)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(map._mine_room_gates.size() == 1, "记录写盘后第一门移除")
	await _mine_choose(map, "act3_mine_wheel", "向东送风")
	_check(not bool(G.prog.flags.get("act3_mine_wind", false)), "错风向给反证且可重试")
	await _mine_choose(map, "act3_mine_wheel", "向西排烟")
	_check(not bool(G.world_puzzle_interact("rift_mine_vault", "act3_mine_switch", "north").get("ok", false)),
		"不能绕过第二风轮直接发车")
	await _mine_choose(map, "act3_mine_second_wheel", "从北井引入清风")
	_check(not map._mine_ground.get("ventilated"), "回风错误保留烟区")
	await _mine_choose(map, "act3_mine_second_wheel", "从南井引入清风")
	_check(bool(map._mine_ground.get("ventilated")), "双轮通风后烟区可见退去")
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "矿脉中段进度可从磁盘读回")
	map = await _enter_mine(role)
	_check(map._mine_room_gates.size() == 1 and bool(map._mine_ground.get("ventilated")), "重进恢复烟区与第二门")
	await _mine_choose(map, "act3_mine_switch", "拨向北侧避烟线")
	await get_tree().physics_frame
	_check(map._mine_room_gates.is_empty() and bool(map._mine_ground.get("rescued")) and
		map._story_battle_ready("mon_redsand_guard"), "矿车撤离与首领房同次开放")
	map._player.position = Vector2(480, 530)
	await get_tree().physics_frame
	map._player.move_and_collide(Vector2(0, -95))
	_check(map._player.position.y < 475, "救援后确实可步行进入炉房")
	var boss: Node = null
	for monster in map._monsters:
		if monster.mon_id == "mon_redsand_guard": boss = monster
	_check(boss != null, "原械卫保留")
	if boss != null:
		map.call("_start_battle", boss)
		if map._battle != null:
			map._battle.sim.finished = true
			map._battle.sim.result = "defeat"
			map._battle.confirm_result()
			await get_tree().process_frame
	_check(not G.story_step_done("s25") and G.item_count("gate_stamp") == 0, "战败不完成主线或发首通物")
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "战败后矿脉救援可重读")
	map = await _enter_mine(role)
	_check(map._mine_room_gates.is_empty() and bool(map._mine_ground.get("rescued")), "战败不重置矿工与机关")
	var before := G.prog.duplicate(true)
	_check(not bool(G.world_puzzle_interact("rift_mine_vault", "act3_mine_switch", "north").get("ok", false))
		and G.prog == before, "重复发车无奖励和状态变化")
	boss = null
	for monster in map._monsters:
		if monster.mon_id == "mon_redsand_guard": boss = monster
	if boss != null:
		map.call("_start_battle", boss)
		if map._battle != null:
			map._battle.sim.finished = true
			map._battle.sim.result = "victory"
			map._battle.confirm_result()
			await get_tree().process_frame
	_check(G.story_step_done("s25") and G.item_count("gate_stamp") == 1, role + " 三房首胜只发原通关印")
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "首胜进度可读回")
	map = await _enter_mine(role)
	_check(map._main_boss_cleared() and G.item_count("gate_stamp") == 1, "重进不复活首领或重发通关印")
	map.queue_free()
	await get_tree().process_frame

func _ignore_map_finish(_result: String) -> void:
	pass

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
	_check(button != null, "闸柄选项按钮可见")
	if button == null: return
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	button.gui_input.emit(e)

func _enter_tidal() -> MapScene:
	var run := RunState.new()
	run.setup({"theme": "tomb", "role_id": "zs", "level": 20, "seed": 829})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "tidal_gate", "run": run,
		"node": {"type": "boss", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	map.map_finished.connect(_ignore_map_finish)
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	return map

func _run_tidal_rooms() -> void:
	G._init_state_defaults()
	G.prog["main_world"] = WorldSession.normalize_state({})
	G.save_locked = false
	G.selected_role = "zs"
	G.items["gate_clue"] = 1
	G.prog["story"] = {"step": "s19", "done": ["s18"], "goals": {}}
	G.prog["flags"] = {"act2_tidal_rooms_v1": true}
	_check(G.save_game(), "新水闸三段档可写")
	var map := await _enter_tidal()
	_check(map._tidal_room_gates.has("record") and map._tidal_room_gates.has("priest")
		and map._tidal_water_bounds.size() == 2
		and not map._story_battle_ready("mon_tide_priest"), "新档的入口、首领房与两侧深水都有实体边界")
	map._player.position = Vector2(480, 825)
	await get_tree().physics_frame
	var side_collision := map._player.move_and_collide(Vector2(-250, 0))
	_check(side_collision != null and map._player.position.x > 330,
		"角色不能钻进左侧深水绕过隔水堰")
	_check(String(map._nav_info().get("name", "")) == "港务水痕记录", "罗盘先引向入口房线索")
	map._player.position = Vector2(480, 825)
	await get_tree().physics_frame
	var collision := map._player.move_and_collide(Vector2(0, -100))
	_check(collision != null and map._player.position.y > 770, "未读记录不能穿过第一道隔水门")
	var record := _entity(map, "act2_tide_record")
	if record != null: map.on_quest_entity(record)
	await get_tree().process_frame
	_check(not map._tidal_room_gates.has("record") and map._tidal_room_gates.has("priest")
		and _entity(map, "act2_tide_upper") != null, "记录写盘后入口隔水门打开")
	map._player.position = Vector2(480, 825)
	await get_tree().physics_frame
	map._player.move_and_collide(Vector2(0, -100))
	_check(map._player.position.y < 770, "第一道门开启后角色确实可进调闸房")
	map._player.position = Vector2(480, 530)
	await get_tree().physics_frame
	collision = map._player.move_and_collide(Vector2(0, -95))
	_check(collision != null and map._player.position.y > 475, "排水前第二道门挡住首领房")
	var upper := _entity(map, "act2_tide_upper")
	if upper != null: map.on_quest_entity(upper)
	if map._puzzle_panel != null: _click(_button(map._puzzle_panel, "直接打开主渠"))
	await get_tree().process_frame
	_check(not bool(G.prog.flags.get("act2_tide_gate_1", false)) and
		_entity(map, "act2_tide_upper") != null, "错开主渠给反证，闸柄可以重调")
	upper = _entity(map, "act2_tide_upper")
	if upper != null: map.on_quest_entity(upper)
	if map._puzzle_panel != null: _click(_button(map._puzzle_panel, "先向旧渠泄水"))
	await get_tree().process_frame
	_check(map._tidal_ground.upper_released and not map._tidal_ground.bridge_drained
		and map._tidal_room_gates.has("priest"), "上闸泄水改变可见水线，但侧闸仍封路")
	var bridge := _entity(map, "act2_tide_bridge")
	_check(bridge != null, "第二道闸在地图上出现")
	if bridge != null: map.on_quest_entity(bridge)
	if map._puzzle_panel != null: _click(_button(map._puzzle_panel, "先通栈桥步道"))
	await get_tree().process_frame
	_check(map._tidal_room_gates.has("priest") and
		map._tidal_room_gates["priest"].route == "bridge" and
		map._tidal_ground.bridge_drained and map._tidal_ground.passages == "bridge"
		and map._story_battle_ready("mon_tide_priest"), "两道闸稳定后水退、首领房可进入")
	var herb_before := G.item_count("trade_herb")
	var bridge_supply := _entity(map, "act2_tide_bridge_supply")
	_check(bridge_supply != null, "栈桥退水后有可取的干燥补给")
	if bridge_supply != null: map.on_quest_entity(bridge_supply)
	await get_tree().process_frame
	_check(G.item_count("trade_herb") == herb_before + 1 and
		bool(G.prog.flags.get("act2_tide_bridge_supply_claimed", false)),
		"栈桥补给发一份药草并写入领取旗")
	_check(not bool(G.world_puzzle_interact("tidal_gate", "act2_tide_bridge_supply").get("ok", false))
		and G.item_count("trade_herb") == herb_before + 1, "重复触摸栈桥补给不重发")
	map._player.position = Vector2(540, 530)
	await get_tree().physics_frame
	collision = map._player.move_and_collide(Vector2(0, -95))
	_check(collision != null and map._player.position.y > 475,
		"先通栈桥时货箱暗渠仍有实体拦水堰")
	map._player.position = Vector2(420, 530)
	await get_tree().physics_frame
	map._player.move_and_collide(Vector2(0, -95))
	_check(map._player.position.y < 475, "栈桥左侧实地通向首领房")
	var rescue := _entity(map, "act2_tide_rescue_cargo")
	_check(rescue != null, "先通栈桥后货箱补救点出现")
	if rescue != null: map.on_quest_entity(rescue)
	await get_tree().process_frame
	_check(bool(G.prog.flags.get("act2_tide_cargo_saved", false)) and
		map._tidal_room_gates["priest"].route == "both", "沿堤救回货箱后两边都可走")
	var cargo_supply := _entity(map, "act2_tide_cargo_supply")
	_check(cargo_supply != null, "货箱救回后另一处药包可见")
	if cargo_supply != null: map.on_quest_entity(cargo_supply)
	await get_tree().process_frame
	_check(G.item_count("trade_herb") == herb_before + 2 and
		bool(G.prog.flags.get("act2_tide_cargo_supply_claimed", false)),
		"两处货物各仅领取一份，战斗补给另按一次计算")
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "两道水线可从磁盘重读")
	map = await _enter_tidal()
	_check(map._tidal_room_gates["priest"].route == "both" and map._tidal_ground.upper_released
		and map._tidal_ground.bridge_drained and map._tidal_ground.passages == "both"
		and map._story_battle_ready("mon_tide_priest"),
		"重进后门与水位都沿用已保存的状态")
	_check(G.item_count("trade_herb") == herb_before + 2 and
		_entity(map, "act2_tide_bridge_supply") == null and
		_entity(map, "act2_tide_cargo_supply") == null,
		"补给领取跨磁盘重进，实体不复生")
	var boss: Node = null
	for monster in map._monsters:
		if monster.mon_id == "mon_tide_priest": boss = monster
	_check(boss != null, "原潮蚀司祭仍在末房")
	if boss != null:
		map.call("_start_battle", boss)
		if map._battle != null:
			var sim := map._battle.sim
			var priest: Combatant = null
			for unit in sim.units:
				if String(unit.data.get("id", "")) == "mon_tide_priest": priest = unit
			_check(bool(map._battle._cfg.get("tide_supply_bonus", false)) and
				sim.potions_left == mini(G.run_potions_max(), map.st.potions + 1) and
				String(map._battle._cfg.get("tide_route", "")) == "both",
				"两处补给仅给司祭战一瓶额外药剂，双路闸态入战")
			_check(priest != null and priest.has_buff("def_break") and
				priest.get_def() < priest.base_def and
				int(priest.get_buff("def_break").get("dur", 0)) == 180,
				"双闸同开让司祭开场六秒露出真实护甲破绽")
			map._battle.sim.finished = true
			map._battle.sim.result = "defeat"
			map._battle.confirm_result()
			await get_tree().process_frame
	_check(not G.story_step_done("s19") and G.item_count("tide_core") == 0
		and bool(G.prog.flags.get("act2_tide_gate_2", false)) and
		G.item_count("trade_herb") == herb_before + 2,
		"首领战败不清除已排好的水线，也不发首通闸芯")
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "战败退出后水闸状态可重读")
	map = await _enter_tidal()
	_check(map._tidal_room_gates["priest"].route == "both" and map._tidal_ground.bridge_drained,
		"战败重进仍可直达首领房")
	boss = null
	for monster in map._monsters:
		if monster.mon_id == "mon_tide_priest": boss = monster
	_check(boss != null, "战败后原首领仍可重试")
	if boss != null:
		map.call("_start_battle", boss)
		if map._battle != null:
			map._battle.sim.finished = true
			map._battle.sim.result = "victory"
			map._battle.confirm_result()
			await get_tree().process_frame
	_check(G.story_step_done("s19") and G.item_count("tide_core") == 1,
		"三段水闸首胜仍只给原主线闸芯")
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "首胜后水闸存档可重读")
	map = await _enter_tidal()
	_check(map._main_boss_cleared() and map._tidal_room_gates["priest"].route == "both"
		and G.item_count("tide_core") == 1 and G.item_count("trade_herb") == herb_before + 2,
		"重进不会重置水线、补给或重复首通闸芯")
	map.queue_free()

func _run_tidal_cargo_route() -> void:
	await get_tree().process_frame
	G._init_state_defaults()
	G.prog["main_world"] = WorldSession.normalize_state({})
	G.save_locked = false
	G.selected_role = "zs"
	G.items["gate_clue"] = 1
	G.prog["story"] = {"step": "s19", "done": ["s18"], "goals": {}}
	G.prog["flags"] = {"act2_tidal_rooms_v1": true}
	_check(G.save_game(), "护货箱路线隔离档可写")
	_check(bool(G.world_puzzle_interact("tidal_gate", "act2_tide_record").get("ok", false))
		and bool(G.world_puzzle_interact("tidal_gate", "act2_tide_upper", "old").get("ok", false)),
		"货箱路线仍须先读记录、泄向旧渠")
	var map := await _enter_tidal()
	var bridge := _entity(map, "act2_tide_bridge")
	_check(bridge != null, "货箱路线的第二道闸可见")
	if bridge != null: map.on_quest_entity(bridge)
	if map._puzzle_panel != null: _click(_button(map._puzzle_panel, "先护货箱暗渠"))
	await get_tree().process_frame
	_check(bool(G.prog.flags.get("act2_tide_route_cargo", false)) and
		bool(G.prog.flags.get("act2_tide_cargo_saved", false)) and
		not bool(G.prog.flags.get("act2_tide_bridge_open", false)) and
		map._tidal_room_gates["priest"].route == "cargo" and
		map._tidal_ground.passages == "cargo" and map._story_battle_ready("mon_tide_priest"),
		"先护货箱只打开右侧干路，仍能挑战司祭")
	var herb_before := G.item_count("trade_herb")
	var cargo_supply := _entity(map, "act2_tide_cargo_supply")
	_check(cargo_supply != null, "先护货箱时右侧药包可领取")
	if cargo_supply != null: map.on_quest_entity(cargo_supply)
	await get_tree().process_frame
	_check(G.item_count("trade_herb") == herb_before + 1 and
		bool(G.prog.flags.get("act2_tide_cargo_supply_claimed", false)),
		"先护货箱同样能取得一份补给")
	map._player.position = Vector2(420, 530)
	await get_tree().physics_frame
	var collision := map._player.move_and_collide(Vector2(0, -95))
	_check(collision != null and map._player.position.y > 475,
		"护货箱路线未修桥时左侧仍被水堰拦住")
	map._player.position = Vector2(540, 530)
	await get_tree().physics_frame
	map._player.move_and_collide(Vector2(0, -95))
	_check(map._player.position.y < 475, "货箱暗渠右侧实地通向首领房")
	var boss: Node = null
	for monster in map._monsters:
		if monster.mon_id == "mon_tide_priest": boss = monster
	if boss != null:
		map.call("_start_battle", boss)
		if map._battle != null:
			var priest: Combatant = null
			for unit in map._battle.sim.units:
				if String(unit.data.get("id", "")) == "mon_tide_priest": priest = unit
			_check(String(map._battle._cfg.get("tide_route", "")) == "cargo" and
				map._battle.sim.potions_left == mini(G.run_potions_max(), map.st.potions + 1),
				"只开货箱暗渠仍可挑战，单处补给给一瓶药剂")
			_check(priest != null and not priest.has_buff("def_break"),
				"只开一侧没有双闸破绽，不影响正常战斗")
			map._battle.sim.finished = true
			map._battle.sim.result = "defeat"
			map._battle.confirm_result()
			await get_tree().process_frame
	map.queue_free()
	await get_tree().process_frame
	_check(G.reload_save(), "护货箱路线跨地图退出可重读")
	map = await _enter_tidal()
	_check(map._tidal_room_gates["priest"].route == "cargo" and
		_entity(map, "act2_tide_repair_bridge") != null,
		"重进后右路保留，栈桥补救点仍可用")
	var before := G.prog.duplicate(true)
	_check(not bool(G.world_puzzle_interact("tidal_gate", "act2_tide_bridge", "cargo").get("ok", false))
		and G.prog == before, "重复选择护货箱不会改档")
	var repair := _entity(map, "act2_tide_repair_bridge")
	if repair != null: map.on_quest_entity(repair)
	await get_tree().process_frame
	_check(bool(G.prog.flags.get("act2_tide_bridge_open", false)) and
		map._tidal_room_gates["priest"].route == "both", "堤边修回栈桥后两路均通")
	before = G.prog.duplicate(true)
	_check(not bool(G.world_puzzle_interact("tidal_gate", "act2_tide_repair_bridge").get("ok", false))
		and G.prog == before, "栈桥补救重复触发不能改档")
	var port := CityScene.new()
	_check("栈桥与货箱都保住" in String(port.call("_tide_route_reply")),
		"港务人能回应两边均已保住的闸态")
	port.free()
	map.queue_free()

func _run_tidal_prior_save() -> void:
	await get_tree().process_frame
	G._init_state_defaults()
	G.prog["main_world"] = WorldSession.normalize_state({})
	G.save_locked = false
	G.selected_role = "zs"
	G.items["gate_clue"] = 1
	G.prog["story"] = {"step": "s19", "done": ["s18"], "goals": {}}
	G.prog["flags"] = {"act2_tidal_rooms_v1": true, "act2_tide_clue": true,
		"act2_tide_gate_1": true, "act2_tide_gate_2": true}
	_check(G.save_game(), "既有三段水闸进度可写")
	var map := await _enter_tidal()
	_check(map._tidal_room_gates["priest"].route == "both" and
		map._tidal_ground.passages == "both" and map._story_battle_ready("mon_tide_priest"),
		"新版路线旗缺席的旧进度仍有两条干路，不被迁移卡住")
	var boss: Node = null
	for monster in map._monsters:
		if monster.mon_id == "mon_tide_priest": boss = monster
	if boss != null:
		map.call("_start_battle", boss)
		if map._battle != null:
			_check(String(map._battle._cfg.get("tide_route", "")) == "legacy" and
				not bool(map._battle._cfg.get("tide_supply_bonus", false)) and
				(map._battle._cfg.get("enemy", {}) as Dictionary).get("opening_def_break", {}).is_empty(),
				"旧档双通路仅保留可达性，不凭空获得新补给或开场破绽")
			map._battle.sim.finished = true
			map._battle.sim.result = "defeat"
			map._battle.confirm_result()
			await get_tree().process_frame
	map.queue_free()

func _run_case(map_id: String, step: String, done: String, item: String, boss: String,
		entity_ids: Array, choices: Array, wrong: String) -> void:
	G._init_state_defaults()
	G.prog["main_world"] = WorldSession.normalize_state({})
	G.prog["flags"] = {}
	G.save_locked = false
	G.selected_role = "zs"
	G.items[item] = 1
	G.prog["story"] = {"step": step, "done": [done], "goals": {}}
	_check(G.save_game(), map_id + " 隔离档可写")
	var run := RunState.new()
	run.setup({"theme": "tomb", "role_id": "zs", "level": 30, "seed": 807})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": map_id, "run": run,
		"node": {"type": "boss", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	_check(_entity(map, String(entity_ids[0])) != null and _entity(map, String(entity_ids[1])) == null,
		map_id + " 先读线索再开机关")
	if map_id == "tidal_gate":
		_check(map._tidal_room_gates.is_empty() and not map._tidal_ground.dynamic_water,
			"旧水闸存档沿用原地图与首领路线")
	_check(map._story_battle_ready(boss), map_id + " 旧档不被新机关卡住")
	var first := _entity(map, String(entity_ids[0]))
	if first != null: map.on_quest_entity(first)
	await get_tree().process_frame
	_check(not map._story_battle_ready(boss) and _entity(map, String(entity_ids[1])) != null,
		map_id + " 开始机关后需要完成校准")
	var before := G.prog.duplicate(true)
	_check(not bool(G.world_puzzle_interact(map_id, String(entity_ids[1]), wrong).get("ok", false))
		and G.prog == before, map_id + " 错线可重试且不改档")
	_check(bool(G.world_puzzle_interact(map_id, String(entity_ids[1]), String(choices[0])).get("ok", false)),
		map_id + " 第一处正确")
	_check(G.reload_save() and _entity(map, String(entity_ids[2])) == null,
		map_id + " 中途存档可重读")
	map._refresh_quest_entities()
	_check(_entity(map, String(entity_ids[2])) != null, map_id + " 第二处出现在地图上")
	_check(bool(G.world_puzzle_interact(map_id, String(entity_ids[2]), String(choices[1])).get("ok", false))
		and map._story_battle_ready(boss), map_id + " 完成机关后原首领开放")
	before = G.prog.duplicate(true)
	_check(not bool(G.world_puzzle_interact(map_id, String(entity_ids[2]), String(choices[1])).get("ok", false))
		and G.prog == before, map_id + " 重复机关无收益")
	map.queue_free()
	await get_tree().process_frame
