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
	# 动态演武单位也必须有真实素材，不能静默回退为程序圆体。
	_check(G.res_tex("mon_arena_dummy") != null, "演武傀儡素材 mon_arena_dummy 应可解析")
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

	# C2. 连胜（轮次 19）：胜累加 / 败清零 / 每 step 连胜发荣誉 / 平局与撤退不动连胜
	G.arena = {"score": 1000, "wins": 0, "losses": 0, "streak": 0, "best_streak": 0}
	var honor0 := int(G.wallet.get("honor", 0))
	var cfg := G.arena_streak_cfg()
	var step := maxi(1, int(cfg.get("step", 3)))
	var honor_per := maxi(0, int(cfg.get("honor_per_milestone", 0)))
	var last: Dictionary = {}
	for i in range(step):
		last = G.arena_result(true)
	_check(int(G.arena.get("streak", 0)) == step,
		"%d 连胜后 streak 应为 %d，实为 %d" % [step, step, int(G.arena.get("streak", 0))])
	_check(bool(last.get("milestone", false)), "满 %d 连胜应触发里程碑" % step)
	_check(int(last.get("honor", 0)) == honor_per,
		"里程碑荣誉应为 %d，实为 %d" % [honor_per, int(last.get("honor", 0))])
	_check(int(G.wallet.get("honor", 0)) == honor0 + honor_per,
		"里程碑应真的入账荣誉，实为 %d（起点 %d）" % [int(G.wallet.get("honor", 0)), honor0])
	var best_after := int(G.arena.get("best_streak", 0))
	_check(best_after >= step, "最佳连胜应被记录，实为 %d" % best_after)
	G.arena_result(false)
	_check(int(G.arena.get("streak", 0)) == 0, "落败应清零连胜")
	_check(int(G.arena.get("best_streak", 0)) == best_after, "清零不应抹掉最佳连胜")
	# 连胜加成：按连胜长度给下界与封顶（胜利基础分是随机的，只能断言区间不能断言精确值）
	var scfg: Variant = TableCache.arena_config().get("score", {})
	var sc: Dictionary = scfg if scfg is Dictionary else {}
	var wmin := int(sc.get("win_min", 18))
	var wmax := int(sc.get("win_max", 26))
	var per := maxi(0, int(cfg.get("score_bonus_per_streak", 0)))
	var cap := maxi(0, int(cfg.get("score_bonus_cap", 0)))
	G.arena = {"score": 1000, "wins": 0, "losses": 0, "streak": 0, "best_streak": 0}
	var d_first := int(G.arena_result(true).get("delta", 0))
	_check(d_first >= wmin and d_first <= wmax,
		"首胜加分应在 [%d,%d]，实为 %d" % [wmin, wmax, d_first])
	var d_second := int(G.arena_result(true).get("delta", 0))
	_check(d_second >= wmin + per,
		"第二胜应带连胜加成（下界 %d），实为 %d" % [wmin + per, d_second])
	G.arena = {"score": 1000, "wins": 0, "losses": 0, "streak": 50, "best_streak": 50}
	var d_cap := int(G.arena_result(true).get("delta", 0))
	_check(d_cap <= wmax + cap, "连胜加成应封顶 %d，实为 %d" % [wmax + cap, d_cap])
	# 存档往返：连胜与最佳连胜都要留住
	G.arena["streak"] = 7
	G.arena["best_streak"] = 9
	G.save_game()
	G.arena = {"score": 1000, "wins": 0, "losses": 0, "streak": 0, "best_streak": 0}
	G._load_save()
	_check(int(G.arena.get("streak", 0)) == 7, "读档后连胜应保留，实为 %d" % int(G.arena.get("streak", 0)))
	_check(int(G.arena.get("best_streak", 0)) == 9, "读档后最佳连胜应保留")

	# D. 超时平局：不扣段位分（P1-8 / 口径 D3）
	var ap: Control = (load("res://src/ui/ArenaPanel.gd") as GDScript).new()
	add_child(ap)
	await get_tree().process_frame
	G.arena = {"score": 1000, "wins": 0, "losses": 0, "streak": 4, "best_streak": 4}
	ap._on_battle_end("draw", 0)
	_check(int(G.arena.get("score", 0)) == 1000, "平局不应改段位分（实为 %d）" % int(G.arena.get("score", 0)))
	_check(int(G.arena.get("streak", 0)) == 4, "平局不应清连胜（实为 %d）" % int(G.arena.get("streak", 0)))
	ap._on_battle_end("flee", 0)
	_check(int(G.arena.get("streak", 0)) == 4, "撤退不应清连胜（实为 %d）" % int(G.arena.get("streak", 0)))
	ap.queue_free()

	if _fails == 0:
		print("ARENA_OK all tests passed")
	else:
		print("ARENA_FAIL fails=%d" % _fails)
