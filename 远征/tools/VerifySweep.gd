# VerifySweep.gd —— 扫荡事务回归（场景模式：godot --headless --path . res://tools/VerifySweep.tscn）
# 守问题清单 #35（扫荡缺行为测试）与 #37（层数假设写死）。
# 口径：扫荡是一次**事务**——要么只消耗 1 张券并恰好发一份奖，要么整单拒绝且零副作用。
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_sweep.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _snapshot() -> Dictionary:
	return {
		"gold": int(G.wallet.get("gold", 0)),
		"expedition": int(G.wallet.get("expedition", 0)),
		"soul": int(G.wallet.get("soul", 0)),
		"honor": int(G.wallet.get("honor", 0)),
		"level": int(G.prog.get("level", 1)),
		"exp": int(G.prog.get("exp", 0)),
		"items": G.items.duplicate(true),
	}


func _differs(a: Dictionary, b: Dictionary) -> bool:
	return JSON.stringify(a) != JSON.stringify(b)


## 按表推导的期望收益（与实现同口径：逐节点相加再乘 sweep_yield，逐项取整）
func _want_gains() -> Dictionary:
	var cfg: Dictionary = TableCache.nodes_config()
	var rewards: Dictionary = cfg.get("rewards", {})
	var y := float(cfg.get("sweep_yield", 0.7))
	var g := {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	var layers := maxi(1, int(cfg.get("layers", 3)))
	var plan: Array = []
	for i in layers:
		plan.append("normal")
	plan.append("boss")
	for kind in plan:
		var row: Dictionary = rewards.get(kind, {})
		for k in g:
			g[k] += int(row.get(k, 0))
	for k in g:
		g[k] = int(float(g[k]) * y)
	return g


func _run() -> void:
	G.prog["level"] = 1
	G.prog["exp"] = 0
	G.prog["world_cleared"] = {}
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.items = {"ticket_sweep": 5}
	G.save_game()

	# ---- A. 未通关：拒绝且零副作用 ----
	var before := _snapshot()
	_check(G.sweep_world("forest").is_empty(), "未通关秘境不应能扫荡")
	_check(not _differs(before, _snapshot()), "被拒的扫荡不能有任何副作用（券、钱包、进度）")

	# ---- B. 已通关但没券：拒绝且零副作用 ----
	G.prog["world_cleared"] = {"forest": true}
	G.items = {"ticket_sweep": 0}
	before = _snapshot()
	_check(G.sweep_world("forest").is_empty(), "没有扫荡券时应拒绝")
	_check(not _differs(before, _snapshot()), "缺券被拒时不能有任何副作用")

	# ---- C. 成功：只耗 1 张券、只发一份奖 ----
	G.items = {"ticket_sweep": 2}
	before = _snapshot()
	var want := _want_gains()
	var gains := G.sweep_world("forest")
	_check(not gains.is_empty(), "已通关且有券时应能扫荡")
	_check(G.item_count("ticket_sweep") == 1, "扫荡只应消耗 1 张券（实为 %d）"
		% G.item_count("ticket_sweep"))
	for k in ["gold", "expedition", "soul", "honor"]:
		_check(int(gains.get(k, -1)) == int(want[k]),
			"扫荡 %s 应为按表推导的 %d，实为 %d" % [k, int(want[k]), int(gains.get(k, -1))])
		_check(int(G.wallet.get(k, 0)) == int(before[k]) + int(want[k]),
			"钱包 %s 应恰好入账一次（%d）" % [k, int(want[k])])
	_check(G.items.get("ticket_sweep", 0) == 1, "道具表里的券数应同步减少")

	# ---- D. 重复点击：第二次照样各消耗 1 张券、各发一份（不是叠加成两份） ----
	var gold_after_one := int(G.wallet.get("gold", 0))
	var gains2 := G.sweep_world("forest")
	_check(not gains2.is_empty(), "第二张券应能再扫一次")
	_check(int(G.wallet.get("gold", 0)) == gold_after_one + int(want["gold"]),
		"第二次扫荡应再入账一份，而不是叠加")
	_check(G.item_count("ticket_sweep") == 0, "两次扫荡后扫荡券应耗尽")
	_check(G.sweep_world("forest").is_empty(), "券耗尽后应拒绝")

	# ---- E. 升级与上限：经验按表结算 ----
	G.prog["level"] = 1
	G.prog["exp"] = 0
	G.items = {"ticket_sweep": 1}
	var g3 := G.sweep_world("forest")
	_check(int(g3.get("level_ups", -1)) >= 1, "扫荡经验应能升级（实为 %d 级）" % int(g3.get("level_ups", -1)))
	G.prog["level"] = G.level_cap()
	G.prog["exp"] = 0
	G.items = {"ticket_sweep": 1}
	var g4 := G.sweep_world("forest")
	_check(int(g4.get("level_ups", -1)) == 0 and int(G.prog.get("level", 0)) == G.level_cap(),
		"满级后扫荡不应越界升级")

	# ---- F. 存档往返：扫荡结果要能读回来 ----
	var gold_saved := int(G.wallet.get("gold", 0))
	G.save_game()
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G._load_save()
	_check(int(G.wallet.get("gold", 0)) == gold_saved,
		"读档后扫荡收益应保留（期望 %d，实为 %d）" % [gold_saved, int(G.wallet.get("gold", 0))])

	# ---- G. #37：结算构成必须跟着 nodes.json 的层数走 ----
	# 注入"4 层"的配置，期望收益要变成 4 普通 + 1 BOSS；写死"3 普通 + 1 BOSS"的实现会红。
	var real_cfg: Variant = TableCache._cache.get("res://data/nodes.json")
	var patched: Dictionary = (real_cfg as Dictionary).duplicate(true) if real_cfg is Dictionary \
		else TableCache.nodes_config().duplicate(true)
	patched["layers"] = 4
	TableCache._cache["res://data/nodes.json"] = patched
	_check(int(TableCache.nodes_config().get("layers", 0)) == 4, "注入 4 层配置应生效")
	var want4 := _want_gains()
	G.prog["level"] = 1
	G.prog["exp"] = 0
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.items = {"ticket_sweep": 1}
	var g5 := G.sweep_world("forest")
	_check(int(g5.get("gold", -1)) == int(want4["gold"]),
		"4 层配置下扫荡金币应按 4 普通 + 1 BOSS 推导（期望 %d，实为 %d）"
		% [int(want4["gold"]), int(g5.get("gold", -1))])
	if real_cfg != null:
		TableCache._cache["res://data/nodes.json"] = real_cfg
	else:
		TableCache._cache.erase("res://data/nodes.json")

	# ---- H. #37：BOSS 层号必须是"层数 + 1"，不是写死的 4 ----
	var r3 := RouteGenerator.generate(20260920)
	_check(RouteGenerator.boss_layer(r3) == 3 + 1, "3 层路线的 BOSS 层应为 4")
	_check(RouteGenerator.is_boss_layer(r3, 4) and not RouteGenerator.is_boss_layer(r3, 3),
		"BOSS 层判定不应把第 3 层也算进去")
	var fake4 := {"layers": [1, 2, 3, 4]}
	_check(RouteGenerator.boss_layer(fake4) == 5 and RouteGenerator.is_boss_layer(fake4, 5),
		"层数变成 4 时 BOSS 层应跟着变成 5（写死 4 的实现会红）")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(G.SAVE_PATH))
	if _fails == 0:
		print("SWEEP_OK all tests passed")
	else:
		print("SWEEP_FAIL fails=%d" % _fails)
