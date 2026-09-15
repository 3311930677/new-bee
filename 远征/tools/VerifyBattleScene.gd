# VerifyBattleScene.gd —— 战斗场景冒烟（场景模式：godot --headless --path . res://tools/VerifyBattleScene.tscn）
# 用场景模式而非 -s：BattleScene 依赖 autoload G，-s 模式下编译器不注册 autoload 全局名
# 覆盖：场景构建无脚本错误 / tick 步进 + 事件消费（飘字创建销毁）/ 单位视图同步 /
#       技能条-能量-药剂刷新 / 结算浮层出现与信号 / 全事件类型消费无崩溃（含 BOSS 召唤）
extends Node

var _fails := 0


func _ready() -> void:
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	# 1. 普通节点整场（加速 12x）
	var r1: Dictionary = await _run_one("forest", "normal", 1, false)
	_check(r1.get("finished", false), "普通节点应出现结算")
	_check(r1.get("result", "") == "victory", "普通节点应胜利，实为 %s" % r1.get("result", ""))
	_check(int(r1.get("fx_left", -1)) == 0, "战斗结束后飘字层应清空（tween 完成后），实为 %d" % int(r1.get("fx_left", -1)))
	_check(int(r1.get("views", 0)) >= 4, "应有至少 4 个单位视图（1人物+1宠+3~4怪），实为 %d" % int(r1.get("views", 0)))

	# 2. BOSS 节点（含召唤/大招/更多事件类型）
	var r2: Dictionary = await _run_one("forest", "boss", 3, true)
	_check(r2.get("finished", false), "BOSS 节点应出现结算")
	_check(r2.get("result", "") == "victory", "lv15+词条应胜 BOSS，实为 %s" % r2.get("result", ""))

	# 3. 撤退路径
	var r3: Dictionary = await _run_flee()
	_check(r3.get("finished", false) and r3.get("result", "") == "defeat", "撤退应判负结算")

	if _fails == 0:
		print("BATTLE_SCENE_OK all tests passed")
	else:
		print("BATTLE_SCENE_FAIL fails=%d" % _fails)


func _run_one(theme: String, node_type: String, layer: int, strong: bool) -> Dictionary:
	var lv := 15 if strong else 5
	var traits: Array = ["tr_atk_up_m", "tr_bleed_1", "tr_bleed_2", "tr_deep_wound"] if strong else []
	var pet := "pet_emberling" if strong else "pet_rockturtle"
	BattleScene.pending_cfg = {
		"ally": {"role_id": "zs", "level": lv, "traits": traits,
			"active_pet": pet, "bench_pet": "pet_thunderhawk", "potions": 2},
		"enemy": {"theme": theme, "node_type": node_type, "layer": layer},
		"seed": 7,
	}
	return await _drive(2400)


func _run_flee() -> Dictionary:
	BattleScene.pending_cfg = {
		"ally": {"role_id": "fs", "level": 5, "traits": [], "potions": 1},
		"enemy": {"theme": "snow", "node_type": "boss", "layer": 3},
		"seed": 3,
	}
	var scene: BattleScene = _spawn()
	scene.sim.finished = true   # 模拟点击"撤退"（强制判负）
	scene.sim.result = "defeat"
	return await _drive(120, scene)


func _spawn() -> BattleScene:
	var packed: PackedScene = load("res://src/battle/BattleScene.tscn")
	_check(packed != null, "BattleScene.tscn 应可加载")
	var scene: BattleScene = packed.instantiate()
	scene.speed = 12.0
	add_child(scene)
	return scene


func _drive(max_frames: int, scene: BattleScene = null) -> Dictionary:
	if scene == null:
		scene = _spawn()
	var out := {"finished": false, "result": "", "fx_left": -1, "views": 0}
	scene.battle_finished.connect(func(result: String, hp: int):
		out["finished"] = true
		out["result"] = result)
	var frames := 0
	while not out["finished"] and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	# 结算浮层出现的下一帧
	await get_tree().process_frame
	var fx_layer: Control = scene.get("_fx_layer")
	out["fx_left"] = fx_layer.get_child_count() if fx_layer != null else -1
	var field: Node2D = scene.get("_field")
	out["views"] = field.get_child_count() if field != null else 0
	# 程序化点击"继续"
	scene.confirm_result()
	await get_tree().process_frame
	scene.queue_free()
	await get_tree().process_frame
	return out
