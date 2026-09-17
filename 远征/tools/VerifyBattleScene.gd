# VerifyBattleScene.gd —— 战斗场景冒烟（场景模式：godot --headless --path . res://tools/VerifyBattleScene.tscn）
# 用场景模式而非 -s：BattleScene 依赖 autoload G，-s 模式下编译器不注册 autoload 全局名
# 覆盖：场景构建无脚本错误 / tick 步进 + 事件消费（飘字创建销毁）/ 单位视图同步 /
#       技能条-能量-药剂刷新 / 结算浮层出现与信号 / 全事件类型消费无崩溃（含 BOSS 召唤）
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_battle.json"  # 别污染真实存档
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

	# 4. 打击反馈：顿帧 / 震屏 / 敌方施法可读 / 战报统计 / 低血层不落飘字层
	var r4: Dictionary = await _run_feedback()
	_check(r4.get("hitstop_on", false), "重击应触发顿帧")
	_check(r4.get("hitstop_off", false), "顿帧应在数十毫秒内归零")
	_check(r4.get("shake_moved", false), "重击应推动震屏层")
	_check(r4.get("shake_reset", false), "震屏层最终应回到原点")
	_check(r4.get("enemy_tip", false),
		"敌方施法应给出「敌方/首领技 · 技能名」提示，实为「%s」" % r4.get("tip_text", ""))
	_check(int(r4.get("best_hit", 0)) >= 999, "战报应记下最高单击，实为 %d" % int(r4.get("best_hit", 0)))
	_check(int(r4.get("dmg_in", 0)) >= 7, "战报应累计我方承伤，实为 %d" % int(r4.get("dmg_in", 0)))
	_check(r4.get("danger_ok", false), "低血警示层应存在，且不能挂在飘字层里（飘字层会被清空断言检查）")

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


## 打击反馈专项：造一场战斗，手工喂事件，检查顿帧/震屏/提示/战报/低血层挂点
func _run_feedback() -> Dictionary:
	var out := {"hitstop_on": false, "hitstop_off": false, "shake_moved": false,
		"shake_reset": false, "enemy_tip": false, "tip_text": "", "best_hit": 0,
		"dmg_in": 0, "danger_ok": false}
	BattleScene.pending_cfg = {
		"ally": {"role_id": "zs", "level": 5, "traits": [],
			"active_pet": "pet_rockturtle", "potions": 2},
		"enemy": {"theme": "forest", "node_type": "normal", "layer": 1},
		"seed": 11,
	}
	var scene: BattleScene = _spawn()
	scene.speed = 0.0   # 冻住 sim：本用例只验表现层，免得真实伤害持续插进来干扰断言
	await get_tree().process_frame
	var role := scene.sim.role_unit()
	var enemy_uid := -1
	for u in scene.sim.units:
		if u.side == "enemy":
			enemy_uid = u.uid
			break
	if role == null or enemy_uid < 0:
		scene.queue_free()
		return out

	# 敌方施法必须读得出来
	scene.call("_on_event", {"t": "cast_start", "uid": enemy_uid, "skill": "boss_slam", "name": "震地"})
	var tip: Label = scene.get("_cast_tip")
	out["tip_text"] = tip.text if tip != null else ""
	out["enemy_tip"] = out["tip_text"].contains("敌方") or out["tip_text"].contains("首领技")

	# 一次重击：顿帧 + 震屏 + 计入战报
	scene.call("_on_event", {"t": "dmg", "src": role.uid, "uid": enemy_uid,
		"amount": 999, "crit": true, "dot": false})
	out["hitstop_on"] = float(scene.get("_hitstop")) > 0.0
	out["best_hit"] = int(scene.get("_best_hit"))
	await get_tree().process_frame
	var shake_root: Control = scene.get("_shake_root")
	out["shake_moved"] = shake_root != null and shake_root.position != Vector2.ZERO

	# 我方挨打：计入承伤
	scene.call("_on_event", {"t": "dmg", "src": enemy_uid, "uid": role.uid,
		"amount": 7, "crit": false, "dot": false})
	out["dmg_in"] = int(scene.get("_dmg_in"))

	# 低血层挂点：必须是根节点的直接子级，不能混进飘字层
	var danger: TextureRect = scene.get("_danger")
	var fx: Control = scene.get("_fx_layer")
	out["danger_ok"] = danger != null and fx != null and danger.get_parent() == scene

	for i in 60:
		await get_tree().process_frame
	out["shake_reset"] = shake_root != null and shake_root.position == Vector2.ZERO
	out["hitstop_off"] = float(scene.get("_hitstop")) <= 0.0
	scene.queue_free()
	await get_tree().process_frame
	return out


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
