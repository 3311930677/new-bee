# VerifyRouteScene.gd —— 远征循环冒烟（场景模式：godot --headless --path . res://tools/VerifyRouteScene.tscn）
# seed=1 布局：层1 bonfire/event/shop（全快捷）→ 层2 elite/shop/normal → 层3 normal/normal/elite
# 覆盖：路线图构建 / 快捷节点流转 / 战斗节点挂载 BattleScene 覆盖层 + 胜利写回（HP 延续/词条/层推进）/
#       BOSS 通关结算 / 战败结算 / 药剂与换宠跨节点写回
extends Node

var _fails := 0


func _ready() -> void:
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _spawn(seed: int, bench: String) -> RouteScene:
	RouteScene.pending_run = {
		"theme": "forest", "role_id": "zs", "level": 5,
		"active_pet": "pet_rockturtle", "bench_pet": bench,
		"potions": 2, "seed": seed,
	}
	var packed: PackedScene = load("res://src/run/RouteScene.tscn")
	var scene: RouteScene = packed.instantiate()
	add_child(scene)
	return scene


func _find_node(row: Array, types: Array) -> Dictionary:
	for n in row:
		if types.has(String((n as Dictionary).get("type", ""))):
			return n
	return {}


func _run() -> void:
	# 1. 路线图构建
	var scene := _spawn(1, "pet_thunderhawk")
	_check(scene.st.route.get("layers", []).size() == 3, "路线应有 3 层")
	var node_cnt := 0
	for c in scene._field.get_children():
		if String(c.name).begins_with("node_"):
			node_cnt += 1
	_check(node_cnt == 11, "路线图应有 11 个节点视图（起点+9+BOSS），实为 %d" % node_cnt)
	_check(scene.st.current_layer() == 1, "开局应在第 1 层")

	# 2. 层 1 快捷节点流转（seed=1 层 1 全为非战斗）
	var quick := _find_node(scene.st.route["layers"][0], ["event", "chest", "shop", "bonfire"])
	_check(not quick.is_empty(), "seed=1 层 1 应有快捷节点")
	if not quick.is_empty():
		var qtype := String(quick.get("type", ""))
		var gold_b := scene.st.gold
		var pot_b := scene.st.potions
		scene._enter_node(quick)
		_check(scene._battle == null, "快捷节点不应挂载战斗")
		_check(bool(quick.get("cleared", false)), "快捷节点应标记完成")
		_check(scene.st.current_layer() == 2, "快捷节点走完应推进到第 2 层")
		match qtype:
			"event", "chest":
				_check(scene.st.gold > gold_b, "%s 应产出金币" % qtype)
			"shop":
				_check(scene.st.potions == pot_b + 1, "商店应购得 1 药剂")
			"bonfire":
				_check(scene.st.hp == scene.st.max_hp(), "篝火满血治疗应夹紧")

	# 3. 层 2 战斗节点真打一场（加速 8x）：挂载/卸载 + 胜利写回
	var nd := _find_node(scene.st.route["layers"][1], ["normal", "elite"])
	_check(not nd.is_empty(), "seed=1 层 2 应有战斗节点")
	if not nd.is_empty():
		scene._enter_node(nd)
		_check(scene._battle != null, "战斗节点应挂载 BattleScene")
		scene._battle.speed = 8.0
		var frames := 0
		while scene._battle != null and not scene._battle.sim.finished and frames < 3000:
			await get_tree().process_frame
			frames += 1
		_check(scene._battle != null and scene._battle.sim.finished, "战斗应在帧预算内结束")
		if scene._battle != null:
			scene._battle.confirm_result()
			await get_tree().process_frame
			_check(scene._battle == null, "结算后战斗覆盖层应卸载")
			_check(bool(nd.get("cleared", false)), "节点应标记完成")
			_check(scene.st.traits.size() == 1, "胜利应获 1 词条，实为 %d" % scene.st.traits.size())
			_check(scene.st.hp > 0, "HP 应延续为正值，实为 %d" % scene.st.hp)
			_check(scene.st.current_layer() == 3, "应推进到第 3 层，实为 %d" % scene.st.current_layer())

	# 4. 层 3 战斗节点强制胜利（写回路径已由真打覆盖）
	var nd3 := _find_node(scene.st.route["layers"][2], ["normal", "elite"])
	_check(not nd3.is_empty(), "seed=1 层 3 应有战斗节点")
	if not nd3.is_empty():
		scene._enter_node(nd3)
		_check(scene._battle != null, "层 3 战斗应挂载")
		if scene._battle != null:
			scene._battle.sim.finished = true
			scene._battle.sim.result = "victory"
			scene._battle.confirm_result()
			await get_tree().process_frame
			_check(scene.st.current_layer() == 4, "3 层走完应到 BOSS 层，实为 %d" % scene.st.current_layer())

	# 5. BOSS 通关：强制胜利 → 结算浮层
	var boss: Dictionary = scene.st.route["boss"]
	scene._enter_node(boss)
	_check(scene._battle != null, "BOSS 节点应挂载战斗")
	if scene._battle != null:
		var has_boss := scene._battle.sim.units.any(
			func(u): return u.kind == "monster" and String(u.data.get("tier", "")) == "boss")
		_check(has_boss, "BOSS 战敌方应含首领单位")
		scene._battle.sim.finished = true
		scene._battle.sim.result = "victory"
		scene._battle.confirm_result()
		await get_tree().process_frame
		_check(scene._end_ui != null, "通关应显示结算浮层")
		_check(scene.st.finished and scene.st.result == "clear", "局状态应为通关")
	scene.queue_free()
	await get_tree().process_frame

	# 6. 战败 + 药剂/换宠写回（seed=2：层 1 = elite/shop/normal）
	var scene2 := _spawn(2, "pet_thunderhawk")
	var nd2 := _find_node(scene2.st.route["layers"][0], ["normal", "elite"])
	_check(not nd2.is_empty(), "seed=2 层 1 应有战斗节点")
	if not nd2.is_empty():
		scene2._enter_node(nd2)
		_check(scene2._battle != null, "战斗应挂载")
		scene2._battle.sim.potions_left = 1      # 模拟战斗中消耗 1 瓶
		scene2._battle.sim.pet_swap_used = true  # 模拟已换宠（替补上场，旧宠整局离场）
		scene2._battle.sim.finished = true
		scene2._battle.sim.result = "defeat"
		scene2._battle.confirm_result()
		await get_tree().process_frame
		_check(scene2.st.potions == 1, "药剂余量应写回 1，实为 %d" % scene2.st.potions)
		_check(scene2.st.active_pet == "pet_thunderhawk", "换宠后出战位应写回替补")
		_check(scene2.st.bench_pet == "", "换宠后替补位应清空")
		_check(scene2.st.finished and scene2.st.result == "defeat", "战败应结束局")
		_check(scene2._end_ui != null, "战败应显示结算浮层")

	if _fails == 0:
		print("ROUTE_SCENE_OK all tests passed")
	else:
		print("ROUTE_SCENE_FAIL fails=%d" % _fails)
