# verify_battle.gd —— 战斗内核验证（headless：godot --headless --path . -s tools/verify_battle.gd）
# 覆盖：DamageCalc 手算断言 / 编成规则 / 四人物自动战斗 / 确定性对拍 / 换宠 / 词条 / 精英与BOSS
extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	_test_damage_calc()
	_test_formation()
	_test_four_roles_auto()
	_test_determinism()
	_test_traits()
	_test_elite_boss()
	_test_energy_economy()
	_test_lifesteal()
	_test_summon_skill()
	_test_empty_target_fallback()
	_test_cast_dedup()
	_test_max_hp_parity()
	_test_timeout_draw()
	if _fails == 0:
		print("BATTLE_OK all tests passed")
	else:
		print("BATTLE_FAIL fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)


# ---------- 1. DamageCalc 手算（3 组） ----------
func _test_damage_calc() -> void:
	_check(DamageCalc.basic_damage(20, 10) == 4, "手算1: 20²/(8×10+20)=400/100=4")
	_check(DamageCalc.basic_damage(22, 4) == 8, "手算2: 22²/(32+22)=484/54=8")
	_check(DamageCalc.basic_damage(100, 50) == 20, "手算3: 10000/500=20")
	_check(DamageCalc.basic_damage(5, 999) == 1, "下限 1")
	_check(DamageCalc.crit_damage(20, 1.5) == 30, "暴击 20×1.5=30")
	_check(DamageCalc.heal_amount(200, 20, 0.15, 0.5) == 40, "治疗 200×0.15+20×0.5=40")


# ---------- 2. 敌方编成（§2.5） ----------
func _test_formation() -> void:
	for nt in ["normal", "elite", "boss"]:
		var sim := BattleSim.new()
		sim.record_events = false
		sim.setup(42, {"role_id": "zs", "level": 5, "traits": []},
			{"theme": "forest", "node_type": String(nt), "layer": 1})
		var enemies := sim.alive_units("enemy")
		if String(nt) == "normal":
			_check(enemies.size() >= 3 and enemies.size() <= 4, "普通节点 3~4 怪，实为 %d" % enemies.size())
		elif String(nt) == "elite":
			_check(enemies.size() == 3, "精英节点 1+2=3，实为 %d" % enemies.size())
		else:
			_check(enemies.size() == 3, "BOSS 节点 1+2=3，实为 %d" % enemies.size())
			_check(sim.has_boss(), "BOSS 节点应含 BOSS")
		# 精英必前排
		if String(nt) == "elite":
			var has_front := false
			for e in enemies:
				if e.row == Combatant.ROW_FRONT and e.base_max_hp > 100:
					has_front = true
			_check(has_front, "精英应在前排且血量强化")
	# 我方站位：近战前排 / 远程后排
	var sim2 := BattleSim.new()
	sim2.record_events = false
	sim2.setup(1, {"role_id": "fs", "level": 1, "traits": []},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var fs := sim2.role_unit()
	_check(fs != null and fs.row == Combatant.ROW_BACK, "霜语(远程)应在后排")
	_check(fs != null and fs.col == 2, "人物固定 col2")


# ---------- 3. 四人物自动战斗均能正常结束 ----------
func _test_four_roles_auto() -> void:
	for role_id in ["zs", "ck", "fs", "fz"]:
		for layer in [1, 3]:
			var sim := BattleSim.new()
			sim.record_events = false
			sim.auto_mode = true
			sim.setup(7, {"role_id": String(role_id), "level": 10, "traits": []},
				{"theme": "forest", "node_type": "normal", "layer": layer})
			var r := sim.run_to_end()
			_check(r == "victory", "%s lv10 第%d层普通节点应胜（无养成下限验证）" % [role_id, layer])


# ---------- 4. 确定性对拍（同 seed 同指令 → 逐段哈希一致） ----------
func _test_determinism() -> void:
	var a := BattleSim.new()
	var b := BattleSim.new()
	a.record_events = false
	b.record_events = false
	a.setup(999, {"role_id": "zs", "level": 8, "traits": ["tr_atk_up_s", "tr_crit_up"]},
		{"theme": "volcano", "node_type": "normal", "layer": 2})
	b.setup(999, {"role_id": "zs", "level": 8, "traits": ["tr_atk_up_s", "tr_crit_up"]},
		{"theme": "volcano", "node_type": "normal", "layer": 2})
	a.auto_mode = true
	b.auto_mode = true
	for i in 900:
		a.step()
		b.step()
		if i % 90 == 0:
			_check(a.hash_state() == b.hash_state(), "确定性：第 %d tick 哈希漂移" % i)
		if a.finished or b.finished:
			break
	_check(a.result == b.result, "同 seed 结果一致")
	_check(a.result != "", "战斗应结束")


# ---------- 5. 词条被动与流派 ----------
func _test_traits() -> void:
	# 数值系被动生效
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(3, {"role_id": "zs", "level": 10,
		"traits": ["tr_atk_up_m", "tr_hp_up_s", "tr_def_up_s", "tr_spd_up", "tr_crit_up"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	var plain := TableCache.role_stats("zs", 10)
	_check(role.get_max_hp() == int(float(plain.max_hp) * 1.10), "词条 MaxHP +10% 生效")
	_check(role.get_atk() == int(float(plain.atk) * 1.15), "词条 ATK +15% 生效")
	_check(absf(role.get_spd() / plain.spd - 1.12) < 0.001, "词条 SPD +12% 生效")
	_check(absf(role.get_crit() - (plain.crit + 0.08)) < 0.0001, "词条 CRIT +8% 生效")
	# 流派 3 件触发（bleed = tr_bleed_1 + tr_bleed_2 + tr_deep_wound，见 traits.json school 归属）
	var ts := TraitSystem.new(["tr_bleed_1", "tr_bleed_2", "tr_deep_wound"])
	_check(ts.school_active("bleed"), "流血流派 3 件应激活")
	_check(ts.bleed_dmg_pct() > 0.4, "流血流派加成生效")
	_check(not ts.school_active("crit"), "不足 3 件不激活")
	# 换宠免死
	var sim2 := BattleSim.new()
	sim2.record_events = false
	sim2.setup(5, {"role_id": "zs", "level": 1, "traits": [],
		"active_pet": "pet_rockturtle", "bench_pet": "pet_thunderhawk"},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	_check(sim2.swap_pet(), "换宠应成功")
	var pets := 0
	for u in sim2.units:
		if u.kind == "pet":
			pets += 1
			_check(u.deathproof_buff, "换上宠物应获免死")
	_check(pets == 1, "换宠后仅 1 只宠物在场")
	_check(not sim2.swap_pet(), "本局第二次换宠应失败")


# ---------- 6. 精英与 BOSS 可战 ----------
func _test_elite_boss() -> void:
	for nt in ["elite", "boss"]:
		var sim := BattleSim.new()
		sim.record_events = false
		sim.auto_mode = true
		sim.setup(11, {"role_id": "ck", "level": 12, "traits": ["tr_atk_up_m"],
			"active_pet": "pet_foxfire"},
			{"theme": "snow", "node_type": String(nt), "layer": 2})
		var r := sim.run_to_end()
		_check(r == "victory", "%s 节点 lv12+紫宠应胜" % nt)
	# BOSS 召唤：上限 6
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(13, {"role_id": "zs", "level": 15, "traits": []},
		{"theme": "forest", "node_type": "boss", "layer": 1})
	var boss: Combatant = null
	for u in sim.units:
		if u.ai_type == "boss":
			boss = u
	_check(boss != null, "BOSS 在场")
	if boss != null:
		sim.summon_monsters(boss, "mon_wolf", 5, 6)
		_check(sim.alive_units("enemy").size() <= 6, "召唤上限 6")


# ---------- 7. 分人物能量经济（无 deadlock：关键技能都能出手） ----------
func _test_energy_economy() -> void:
	for role_id in ["zs", "ck", "fs", "fz"]:
		var sim := BattleSim.new()
		sim.record_events = true
		sim.auto_mode = true
		sim.setup(21, {"role_id": String(role_id), "level": 10, "traits": []},
			{"theme": "tomb", "node_type": "elite", "layer": 3})
		sim.run_to_end()
		var cast_count := 0
		for e in sim.events:
			if String(e.t) == "cast":
				cast_count += 1
		_check(cast_count >= 2, "%s 托管整局技能施放 ≥2 次（能量无死锁），实为 %d" % [role_id, cast_count])


# ---------- 8. 吸血取向：攻击方的 lifesteal 回攻击方；受击方的 lifesteal 不生效 ----------
func _test_lifesteal() -> void:
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(31, {"role_id": "zs", "level": 10, "traits": []},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	var foe := sim.alive_units("enemy")[0]
	# ① 攻击方带吸血：受击方挨打 → 攻击方按 50% 回血
	role.hp = 100
	role.add_buff("lifesteal", -1, {"pct": 0.5})
	foe.take_damage(40, role, sim)
	_check(role.hp == mini(role.get_max_hp(), 120), "吸血：攻击方应按伤害 50％ 回血（hp=%d）" % role.hp)
	# ② 受击方带吸血：攻击方血量不受影响（历史 bug：该场景曾错给攻击方回血）
	role.remove_buff("lifesteal")
	foe.add_buff("lifesteal", -1, {"pct": 0.5})
	role.hp = 50
	foe.take_damage(5, role, sim)
	_check(role.hp == 50, "吸血：受击方的 lifesteal 不应治疗攻击方（hp=%d）" % role.hp)


# ---------- 9. BOSS 召唤技可达（历史 bug：target="summon" 数据与 effect 分支对不上，整招空放） ----------
func _test_summon_skill() -> void:
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(17, {"role_id": "zs", "level": 15, "traits": []},
		{"theme": "forest", "node_type": "boss", "layer": 1})
	var boss: Combatant = null
	for u in sim.units:
		if u.ai_type == "boss":
			boss = u
	_check(boss != null, "BOSS 在场")
	if boss == null:
		return
	var sd: Dictionary = {}
	for s in boss.skills:
		if String((s as Dictionary).get("def", {}).get("id", "")) == "boss_summon":
			sd = (s as Dictionary).def
	_check(not sd.is_empty(), "BOSS 应带 boss_summon 技能")
	if sd.is_empty():
		return
	var n0 := sim.alive_units("enemy").size()
	SkillSystem.enqueue_cast(sim, boss, sd)
	if not sim.cast_queue.is_empty():
		sim.cast_queue[sim.cast_queue.size() - 1]["windup"] = 1
	sim.step()
	_check(sim.alive_units("enemy").size() == n0 + 2,
		"召唤狼群应 +2 狼（%d → %d）" % [n0, sim.alive_units("enemy").size()])


# ---------- 10. 空目标兜底：前排全灭时 front_all 改打最低血单体；无敌人时整招作废不扣能量 ----------
func _test_empty_target_fallback() -> void:
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(29, {"role_id": "zs", "level": 15, "traits": []},
		{"theme": "forest", "node_type": "elite", "layer": 1})
	var role := sim.role_unit()
	# 构造「敌方无前排」：全部摆到后排，只留一只顶着
	var keep: Combatant = null
	for e in sim.alive_units("enemy"):
		e.row = Combatant.ROW_BACK
		if keep == null:
			keep = e
	for e in sim.alive_units("enemy"):
		if e != keep:
			e.hp = 0
			e.alive = false
	_check(keep != null, "应留一名敌人")
	if keep != null:
		var sd: Dictionary = TableCache.get_skill("zs_huifeng")
		role.energy = 100
		_check(SkillSystem.can_cast(sim, role, sd), "回风斩应可施放")
		var hp0 := keep.hp
		SkillSystem.enqueue_cast(sim, role, sd)
		if not sim.cast_queue.is_empty():
			sim.cast_queue[sim.cast_queue.size() - 1]["windup"] = 1
		sim.step()
		_check(keep.hp < hp0, "前排全灭时回风斩应兜底命中最低血敌人（%d → %d）" % [hp0, keep.hp])
	# 无敌人：整招作废，能量不减
	var sim2 := BattleSim.new()
	sim2.record_events = false
	sim2.setup(37, {"role_id": "zs", "level": 10, "traits": []},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var r2 := sim2.role_unit()
	for e2 in sim2.alive_units("enemy"):
		e2.hp = 0
		e2.alive = false
	r2.energy = 80
	var sd2: Dictionary = TableCache.get_skill("zs_huifeng")
	SkillSystem.enqueue_cast(sim2, r2, sd2)
	if not sim2.cast_queue.is_empty():
		sim2.cast_queue[sim2.cast_queue.size() - 1]["windup"] = 1
	sim2.step()
	_check(r2.energy == 80, "无敌人时技能作废不应扣能量（实为 %d）" % r2.energy)


# ---------- 11. 入队去重：前摇期间 AI 重复决策只产生一条 cast_start ----------
func _test_cast_dedup() -> void:
	var sim := BattleSim.new()
	sim.record_events = true
	sim.setup(19, {"role_id": "zs", "level": 15, "traits": []},
		{"theme": "forest", "node_type": "boss", "layer": 1})
	var boss: Combatant = null
	for u in sim.units:
		if u.ai_type == "boss":
			boss = u
	_check(boss != null, "BOSS 在场")
	if boss == null:
		return
	var n0 := 0
	for e in sim.events:
		if String(e.t) == "cast_start":
			n0 += 1
	# 模拟决策循环：前摇期间连续决策不应重复入队
	for i in 6:
		MonsterAI.decide(sim, boss)
	var n1 := 0
	for e in sim.events:
		if String(e.t) == "cast_start":
			n1 += 1
	_check(n1 == n0 + 1, "前摇期间只应入队一次（cast_start %d → %d）" % [n0, n1])


# ---------- 12. 血上限同口径：BattleSim 与共享公式一致（P1-6） ----------
func _test_max_hp_parity() -> void:
	var growth := {"maxhp_pct": 0.35, "hp_add": 40, "atk_pct": 0.1, "def_pct": 0.0,
		"spd_pct": 0.0, "crit_add": 0.0, "atk_add": 0.0, "def_add": 0.0, "energy_pct": 0.0}
	var traits := ["tr_hp_up_m"]
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(41, {"role_id": "zs", "level": 10, "traits": traits, "growth": growth},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	var want := TraitSystem.role_max_hp("zs", 10, traits, growth)
	_check(role.get_max_hp() == want, "战斗血上限应等于共享公式（%d vs %d）" % [role.get_max_hp(), want])
	var sim0 := BattleSim.new()
	sim0.record_events = false
	sim0.setup(41, {"role_id": "zs", "level": 10, "traits": traits},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	_check(role.get_max_hp() > sim0.role_unit().get_max_hp(), "带成长的血上限应更大")


# ---------- 13. 超时判平局（P1-8）：result="draw"，不再一律判负 ----------
func _test_timeout_draw() -> void:
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(43, {"role_id": "zs", "level": 3, "traits": []},
		{"theme": "forest", "node_type": "elite", "layer": 1})
	sim.tick_count = BattleSim.MAX_TICKS - 1
	sim.step()
	_check(sim.finished and sim.result == "draw", "到硬上限应判平局（实为 %s）" % sim.result)
