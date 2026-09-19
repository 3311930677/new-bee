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
	# A2. 面板对齐（P1-8）：血量按当前职业面板生成，且不带首领狂暴
	G.selected_role = "zs"
	var st1 := TableCache.role_stats("zs", 1)
	_check(int((f1.get("base", {}) as Dictionary).get("hp", 0))
		== maxi(180, int(float(st1.max_hp) * 2.2)), "1 级傀儡血量应取自角色面板 ×2.2")
	_check(String(f1.get("ai", "")) == "basic", "傀儡应去掉 boss 狂暴（ai=basic）")

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

	# B2. 镜影（轮次 18）
	G.selected_role = "zs"
	var m1 := G.make_arena_mirror("zs", 5)
	_check(String(m1.get("name", "")).contains("镜影"), "镜影名应带镜影")
	_check((m1.get("skills", []) as Array).size() >= 2, "镜影应带角色技能组")

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

	# D. 超时平局：不扣段位分（P1-8 / 口径 D3）
	var ap: Control = (load("res://src/ui/ArenaPanel.gd") as GDScript).new()
	add_child(ap)
	await get_tree().process_frame
	G.arena = {"score": 1000, "wins": 0, "losses": 0}
	ap._on_battle_end("draw", 0)
	_check(int(G.arena.get("score", 0)) == 1000, "平局不应改段位分（实为 %d）" % int(G.arena.get("score", 0)))
	ap.queue_free()

	if _fails == 0:
		print("ARENA_OK all tests passed")
	else:
		print("ARENA_FAIL fails=%d" % _fails)
