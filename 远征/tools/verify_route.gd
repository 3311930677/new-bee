# verify_route.gd —— 路线生成与局状态单测（headless：godot --headless --path . -s tools/verify_route.gd）
# 覆盖：结构合法 / 同种子复现 / 三条保底（100 局全查）/ 类型分布带宽（100 局 900 节点）/
#       RunState 层推进 / 战斗种子唯一 / 词条抽取不重复至池尽 / 篝火治疗与夹紧
extends SceneTree

const VALID_TYPES := ["normal", "elite", "event", "chest", "shop", "bonfire"]

var _fails := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	# 1. 结构：3 层 × 3 节点 + BOSS，类型合法
	var r := RouteGenerator.generate(42)
	_check(r.get("layers", []).size() == 3, "应有 3 层，实为 %d" % r.get("layers", []).size())
	for l in 3:
		var row: Array = r["layers"][l]
		_check(row.size() == 3, "第 %d 层应有 3 节点，实为 %d" % [l + 1, row.size()])
		for n in row:
			var nd: Dictionary = n
			_check(nd.get("layer", 0) == l + 1, "节点 layer 字段应为 %d" % (l + 1))
			_check(VALID_TYPES.has(String(nd.get("type", ""))), "节点类型非法：%s" % nd.get("type"))
	var boss: Dictionary = r.get("boss", {})
	_check(String(boss.get("type", "")) == "boss" and int(boss.get("layer", 0)) == 4, "BOSS 节点应为第 4 层")

	# 2. 同种子复现
	var r2 := RouteGenerator.generate(42)
	_check(JSON.stringify(r) == JSON.stringify(r2), "同种子应生成相同路线")

	# 3+4. 100 局：保底全查 + 分布带宽
	var counts := {}
	for t in VALID_TYPES:
		counts[t] = 0
	var ok_elite := true
	var ok_event := true
	var ok_shop := true
	for s in 100:
		var g := RouteGenerator.generate(1000 + s)
		var flat: Array = []
		for row in g["layers"]:
			for n in row:
				var nd: Dictionary = n
				flat.append(String(nd["type"]))
				counts[String(nd["type"])] = int(counts[String(nd["type"])]) + 1
		var l2: Array = g["layers"][1]
		if not l2.any(func(n): return String(n["type"]) == "elite"):
			ok_elite = false
		if not flat.has("event"):
			ok_event = false
		if not flat.has("shop"):
			ok_shop = false
	_check(ok_elite, "100 局中存在第 2 层无精英的违例")
	_check(ok_event, "100 局中存在全局无事件的违例")
	_check(ok_shop, "100 局中存在全局无商店的违例")
	# 分布带宽（900 节点，权重 40/15/15/12/8/10；三类保底优先换走 normal：期望 ~0.28，elite 抬至 ~0.22）
	var bands := {
		"normal": [0.22, 0.40], "elite": [0.12, 0.28], "event": [0.11, 0.21],
		"chest": [0.07, 0.18], "shop": [0.05, 0.14], "bonfire": [0.06, 0.16],
	}
	for t in VALID_TYPES:
		var freq := float(counts[t]) / 900.0
		var band: Array = bands[t]
		_check(freq >= band[0] and freq <= band[1],
			"类型 %s 频率 %.3f 超出带宽 [%.2f, %.2f]" % [t, freq, band[0], band[1]])

	# 5. RunState：层推进（3 选 1 走完即进下一层）
	var st := RunState.new()
	st.setup({"role_id": "zs", "level": 5, "theme": "forest",
		"active_pet": "pet_rockturtle", "potions": 2, "seed": 42})
	_check(st.current_layer() == 1, "开局应在第 1 层")
	_check(st.node_reachable(1) and not st.node_reachable(2), "仅第 1 层可达")
	st.node_cleared(1, 1)
	_check(st.current_layer() == 2, "第 1 层走完应到第 2 层")
	_check(st.node_reachable(2) and not st.node_reachable(1), "仅第 2 层可达")
	st.node_cleared(2, 0)
	st.node_cleared(3, 2)
	_check(st.current_layer() == 4, "3 层走完应到 BOSS 层")
	_check(st.node_reachable(4), "BOSS 层应可达")
	st.node_cleared(4, 1)
	_check(bool(st.route["boss"]["cleared"]), "BOSS 完成标记")

	# 6. 战斗种子唯一
	var seeds := {}
	for i in 10:
		seeds[st.next_battle_seed()] = true
	_check(seeds.size() == 10, "10 次战斗种子应互不相同")

	# 7. 词条三选一：候选不含已获、逐次选卡可集满、池尽返回空
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var total := TableCache.traits().size()
	for i in total:
		var ch: Array = st.roll_trait_choices(rng)
		_check(not ch.is_empty(), "第 %d 次选卡应返回候选（池共 %d）" % [i + 1, total])
		if ch.is_empty():
			break
		for cand in ch:
			var cid := String((cand as Dictionary).get("id", ""))
			_check(not st.traits.has(cid), "候选 %s 不应已获" % cid)
		st.traits.append(String(ch[0].get("id", "")))
	_check(st.traits.size() == total, "逐次选卡应集满全部 %d 词条，实为 %d" % [total, st.traits.size()])
	_check(st.roll_trait_choices(rng).is_empty(), "池尽后应返回空数组")

	# 8. 篝火治疗与夹紧（词条含 maxhp 类时口径一致）
	var st2 := RunState.new()
	st2.setup({"role_id": "zs", "level": 10, "theme": "forest", "seed": 1})
	_check(st2.max_hp() > 0, "max_hp 应为正")
	st2.hp = st2.max_hp() - 5
	st2.heal(st2.bonfire_heal())
	_check(st2.hp == st2.max_hp(), "治疗应夹紧到最大生命")
	st2.hp = 10
	st2.heal(5)
	_check(st2.hp == 15, "普通治疗应累加")

	if _fails == 0:
		print("ROUTE_OK all tests passed")
	else:
		print("ROUTE_FAIL fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
