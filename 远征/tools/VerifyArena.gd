# VerifyArena.gd —— 演武场回归（godot --headless --path . res://tools/VerifyArena.tscn）
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_arena.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	# A. 傀儡生成：数值随等级递增
	var f1 := G.make_arena_foe(1)
	var f5 := G.make_arena_foe(5)
	_check(String(f1.get("name", "")).contains("1 级"), "傀儡名应带等级")
	_check(int((f5.get("base", {}) as Dictionary).get("hp", 0)) >
		int((f1.get("base", {}) as Dictionary).get("hp", 0)), "高等级傀儡应更强")
	_check(int((f1.get("base", {}) as Dictionary).get("hp", 0)) > 0, "傀儡 HP 应为正")

	# B. BattleSim custom_mon：敌方只 1 只、名字/HP 按数据
	var sim := BattleSim.new()
	sim.setup(7,
		{"role_id": "zs", "level": 3, "traits": [], "active_pet": "", "potions": 1},
		{"theme": "forest", "node_type": "normal", "custom_mon": f5})
	var foes := sim.units.filter(func(u): return u.side == "enemy")
	_check(foes.size() == 1, "演武局敌方应只有 1 个单位，实为 %d" % foes.size())
	if foes.size() == 1:
		_check(String(foes[0].data.get("name", "")) == String(f5.get("name", "")),
			"傀儡名字应写入单位数据")
		_check(foes[0].base_max_hp == int((f5.get("base", {}) as Dictionary).get("hp", 0)),
			"傀儡 HP 应按数据来")

	# C. 段位分：胜加分、负扣分且保底 0；存档往返
	G.arena = {"score": 1000, "wins": 0, "losses": 0}
	var w := G.arena_result(true)
	_check(int(w.get("delta", 0)) > 0 and int(w.get("score", 0)) > 1000, "胜利应加分")
	var l := G.arena_result(false)
	_check(int(l.get("score", 0)) < int(w.get("score", 0)), "失败应扣分")
	G.arena["score"] = 3
	var l2 := G.arena_result(false)
	_check(int(l2.get("score", 0)) == 0, "扣分应保底 0，实为 %d" % int(l2.get("score", 0)))
	G.arena["score"] = 1500
	_check(G.arena_rank() == "金印", "1500 分应为金印，实为 %s" % G.arena_rank())
	G.save_game()
	G.arena = {"score": 1000, "wins": 0, "losses": 0}
	G._load_save()
	_check(int(G.arena.get("score", 0)) == 1500, "读档后段位分应保留")

	if _fails == 0:
		print("ARENA_OK all tests passed")
	else:
		print("ARENA_FAIL fails=%d" % _fails)
