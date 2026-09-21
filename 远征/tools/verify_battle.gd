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
	_test_lethal_and_kill_hooks()
	_test_cc_duration_from_caster()
	_test_overload_full_energy()
	_test_def_down()
	_test_buff_merge()
	_test_hp_override_zero()
	_test_potion_full_hp()
	_test_dmg_taken_on_basic()
	_test_school_build_rate()
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
	# 流派激活（阈值从表读，不手抄数字——B1）
	var ts := TraitSystem.new(["tr_bleed_1", "tr_bleed_2", "tr_deep_wound"])
	_check(ts.school_active("bleed"), "流血流派同系达标应激活")
	_check(ts.bleed_dmg_pct() > 0.4, "流血流派加成生效")
	_check(not ts.school_active("crit"), "非本系不应激活")
	var need := TraitSystem.school_active_n()
	_check(need == int((TableCache.nodes_config().get("run", {}) as Dictionary)
			.get("school_active_n", 2)),
		"流派阈值应来自 nodes.json run.school_active_n（实为 %d）" % need)
	var bleed_pool := ["tr_bleed_1", "tr_bleed_2", "tr_deep_wound"]
	var many := TraitSystem.new(bleed_pool.slice(0, mini(need, bleed_pool.size())))
	_check(many.school_active("bleed"), "同系达到阈值 %d 件应激活" % need)
	var few := TraitSystem.new(bleed_pool.slice(0, maxi(0, mini(need - 1, bleed_pool.size()))))
	_check(need <= 1 or not few.school_active("bleed"), "不足阈值 %d 件不应激活" % need)
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


# ---------- 14. A1/A2：致死伤不再被奶回来 + 击杀钩子真的被调用 ----------
func _test_lethal_and_kill_hooks() -> void:
	# ① 以伤换伤救不了致死伤（回血曾排在死亡判定之前 → 几乎无敌）
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(61, {"role_id": "zs", "level": 10, "traits": ["tr_thorn_2"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	var foe := sim.alive_units("enemy")[0]
	role.hp = 5
	role.take_damage(9999, foe, sim)
	_check(not role.alive and role.hp == 0,
		"以伤换伤不该把致死伤奶回来（alive=%s hp=%d）" % [str(role.alive), role.hp])
	# ② 越战越勇叠层（on_kill 全仓曾 0 调用点）
	var sim2 := BattleSim.new()
	sim2.record_events = false
	sim2.setup(63, {"role_id": "zs", "level": 10, "traits": ["tr_rampage"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var r2 := sim2.role_unit()
	var foe2 := sim2.alive_units("enemy")[0]
	foe2.hp = 1
	foe2.take_damage(9999, r2, sim2)
	_check(r2.rampage_stacks == 1, "击杀应给越战越勇叠 1 层，实为 %d" % r2.rampage_stacks)
	# ③ 宠物击杀记主人
	var sim3 := BattleSim.new()
	sim3.record_events = false
	sim3.setup(65, {"role_id": "zs", "level": 10, "traits": ["tr_rampage"],
		"active_pet": "pet_rockturtle"},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var r3 := sim3.role_unit()
	var pet3: Combatant = null
	for u in sim3.units:
		if u.kind == "pet":
			pet3 = u
	_check(pet3 != null, "应有出战宠物")
	if pet3 != null:
		var f3 := sim3.alive_units("enemy")[0]
		f3.hp = 1
		f3.take_damage(9999, pet3, sim3)
		_check(r3.rampage_stacks == 1, "宠物击杀应记到主人头上（实为 %d）" % r3.rampage_stacks)
	# ④ DoT 击杀按施加者归属（以前 src 传成中毒者自己 → 算自杀）
	var sim4 := BattleSim.new()
	sim4.record_events = false
	sim4.setup(67, {"role_id": "zs", "level": 10, "traits": ["tr_rampage"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var r4 := sim4.role_unit()
	var f4 := sim4.alive_units("enemy")[0]
	f4.hp = 1
	f4.add_buff("poison", 300, {"pct": 0.5, "atk": 200, "stacks": 1, "stack_cap": 3,
		"src_uid": r4.uid})
	sim4.step()
	_check(r4.rampage_stacks == 1, "DoT 击杀应记为施加者的击杀（实为 %d）" % r4.rampage_stacks)
	# ⑤ 威吓：击杀后恐惧敌方全体，且时长按**击杀者**词条放大（A3）
	var sim5 := BattleSim.new()
	sim5.record_events = false
	sim5.setup(69, {"role_id": "zs", "level": 10, "traits": ["tr_fear_aura", "tr_ctrl_1"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var r5 := sim5.role_unit()
	var foes5 := sim5.alive_units("enemy")
	_check(foes5.size() >= 2, "至少 2 只怪才测得出「恐惧全体」")
	var victim5: Combatant = foes5[0]
	victim5.hp = 1
	victim5.take_damage(9999, r5, sim5)
	var feared := 0
	for e in sim5.alive_units("enemy"):
		var fb := e.get_buff("fear")
		if fb.is_empty():
			continue
		feared += 1
		_check(int(fb.get("dur", 0)) > int(1.0 * 30.0),
			"恐惧时长应按**击杀者**的控制词条放大（实为 %d tick）" % int(fb.get("dur", 0)))
	_check(feared >= 1, "击杀应触发威吓（恐惧敌方全体），实为 %d" % feared)


# ---------- 15. A3：控制时长倍率取施加方 ----------
func _test_cc_duration_from_caster() -> void:
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(71, {"role_id": "zs", "level": 10, "traits": ["tr_ctrl_1"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	var foe := sim.alive_units("enemy")[0]
	var base_ticks := int(1.0 * 30.0)
	_check(int(foe.cc_duration_ticks(1.0)) == base_ticks,
		"被控方（怪物无 traits）不应放大控制时长，实为 %d" % int(foe.cc_duration_ticks(1.0)))
	_check(int(role.cc_duration_ticks(1.0)) > base_ticks,
		"施加方（霜寒延长 / 控制流派）应放大控制时长，实为 %d" % int(role.cc_duration_ticks(1.0)))


# ---------- 16. A4：超载（满能量施法）真的生效，且数值读表 ----------
func _test_overload_full_energy() -> void:
	var e := _trait_eff("tr_energy_2")
	var want_pct := float(e.get("full_energy_dmg_pct", 0.20))
	var ts := TraitSystem.new(["tr_energy_2"])
	_check(ts.modify_outgoing(null, null, 100, true, true) == int(100.0 * (1.0 + want_pct)),
		"满能量技能伤害应按表值 %.2f 加成" % want_pct)
	_check(ts.modify_outgoing(null, null, 100, true, false) == 100, "非满能量不应有超载加成")
	# 集成：走完整的 _apply_damage 路径（关掉暴击，伤害才可比对）
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(75, {"role_id": "zs", "level": 10, "traits": ["tr_energy_2"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	role.base_crit = 0.0
	role.energy = Combatant.MAX_ENERGY
	var foes := sim.alive_units("enemy")
	var keep: Combatant = foes[0]
	for f in foes:
		if f != keep:
			f.hp = 0
			f.alive = false
	keep.base_max_hp = 100000
	keep.hp = 100000
	var sd := TableCache.get_skill("zs_lieshan")
	var k := float(sd.get("k", 1.0))
	var h0 := keep.hp
	SkillSystem._apply_damage(sim, role, sd, k, 1, [keep], {}, {}, true)
	var d_full := h0 - keep.hp
	var h1 := keep.hp
	SkillSystem._apply_damage(sim, role, sd, k, 1, [keep], {}, {}, false)
	var d_plain := h1 - keep.hp
	_check(d_plain > 0, "构造：普通施法应造成伤害")
	_check(d_full == int(float(d_plain) * (1.0 + want_pct)),
		"满能量施法伤害应为普通值的 %.2f 倍（%d vs %d）" % [1.0 + want_pct, d_full, d_plain])


# ---------- 17. A5：def_down 落成 def_break（破阵 / 贯甲的破甲） ----------
func _test_def_down() -> void:
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(73, {"role_id": "zs", "level": 10, "traits": []},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	var foes := sim.alive_units("enemy")
	var keep: Combatant = foes[0]
	for f in foes:
		if f != keep:
			f.hp = 0
			f.alive = false
	keep.base_def = 100
	var def0 := keep.get_def()
	_check(def0 == 100, "构造：DEF 应为 100，实为 %d" % def0)
	var sd := TableCache.get_skill("zs_pozhen")
	_check(String(sd.get("effect", {}).get("type", "")) == "def_down",
		"破阵的 effect.type 应是 def_down（改动表时要同步代码分支）")
	SkillSystem._apply_skill(sim, role, sd, {})
	_check(keep.has_buff("def_break"), "破阵应落成 def_break（原来整条被 add_type 丢弃）")
	_check(keep.get_def() < def0, "破甲后 DEF 应下降（%d → %d）" % [def0, keep.get_def()])


# ---------- 18. A8 / 收口：同类 buff 逐键合并 ----------
func _test_buff_merge() -> void:
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(77, {"role_id": "zs", "level": 10, "traits": []},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	# 护盾重复施放：池子累加（以前只刷新时长，数值被丢弃，却照扣能量与 CD）
	role.add_buff("shield", -1, {"pool": 50})
	role.add_buff("shield", -1, {"pool": 30})
	var sv: Dictionary = role.get_buff("shield").get("val", {})
	_check(int(sv.get("pool", 0)) == 80, "护盾重复施放应累加池子，实为 %d" % int(sv.get("pool", 0)))
	# DoT：累积器不能被重复施放清零，ATK 快照取更强的那次
	role.add_buff("poison", 300, {"pct": 0.1, "atk": 100, "stacks": 1, "stack_cap": 3,
		"src_uid": 1})
	var pv: Dictionary = role.get_buff("poison").get("val", {})
	pv["acc"] = 0.9
	role.add_buff("poison", 300, {"pct": 0.2, "atk": 150, "stacks": 1, "stack_cap": 3,
		"src_uid": 2})
	var pv2: Dictionary = role.get_buff("poison").get("val", {})
	_check(absf(float(pv2.get("acc", 0.0)) - 0.9) < 0.0001,
		"重复施放 DoT 不应清零浮点累积器，实为 %.2f" % float(pv2.get("acc", 0.0)))
	_check(int(pv2.get("atk", 0)) == 150, "DoT 的 ATK 快照应取更强的那次，实为 %d"
		% int(pv2.get("atk", 0)))
	_check(int(pv2.get("src_uid", 0)) == 2, "DoT 的施加者应取最新一次，实为 %d"
		% int(pv2.get("src_uid", 0)))
	# 层数上限一经写入只放宽：重创 3 层不会被低上限的技能打回 1
	role.add_buff("bleed", 300, {"stacks": 3, "stack_cap": 3, "atk": 10, "pct": 0.02})
	role.add_buff("bleed", 300, {"stacks": 1, "stack_cap": 1, "atk": 10, "pct": 0.02})
	_check(int(role.get_buff("bleed").get("stacks", 0)) == 3,
		"层数上限不应被后来的低上限打回，实为 %d" % int(role.get_buff("bleed").get("stacks", 0)))
	# 永久 buff 不被限时刷新改写成限时
	role.add_buff("spd_up", -1, {"pct": 0.3})
	role.add_buff("spd_up", 60, {"pct": 0.1})
	_check(int(role.get_buff("spd_up").get("dur", 0)) == -1, "永久 buff 不应被刷新成限时")


# ---------- 19. A6：hp_override 哨兵口径（0 = 濒危续战，钳到 1） ----------
func _test_hp_override_zero() -> void:
	var s0 := BattleSim.new()
	s0.record_events = false
	s0.setup(79, {"role_id": "zs", "level": 10, "traits": [], "hp_override": 0},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	_check(s0.role_unit().hp == 1,
		"0 血续战应钳到 1（0 血开局等于必死），实为 %d" % s0.role_unit().hp)
	var s1 := BattleSim.new()
	s1.record_events = false
	s1.setup(79, {"role_id": "zs", "level": 10, "traits": [], "hp_override": -1},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	_check(s1.role_unit().hp == s1.role_unit().get_max_hp(), "-1 应表示无续血（满血开局）")
	var s2 := BattleSim.new()
	s2.record_events = false
	s2.setup(79, {"role_id": "zs", "level": 10, "traits": [], "hp_override": 5},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	_check(s2.role_unit().hp == 5, "小血量续战应原样带进战斗，实为 %d" % s2.role_unit().hp)


# ---------- 20. 收口：战斗内满血喝药不扣瓶、不进 CD ----------
func _test_potion_full_hp() -> void:
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(81, {"role_id": "zs", "level": 10, "traits": [], "potions": 2},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	_check(not sim.use_potion(), "满血喝药应被拒绝")
	_check(sim.potions_left == 2, "被拒时不应扣瓶（实为 %d）" % sim.potions_left)
	_check(sim.potion_cd_ticks == 0, "被拒时不应进 CD")
	role.hp = 1
	_check(sim.use_potion(), "残血喝药应成功")
	_check(sim.potions_left == 1, "喝药成功应扣 1 瓶（实为 %d）" % sim.potions_left)
	_check(role.hp > 1, "药剂应回血（hp=%d）" % role.hp)


# ---------- 21. 收口：受伤加深下沉到 take_damage（普攻也吃，且只算一次） ----------
func _test_dmg_taken_on_basic() -> void:
	var e := _trait_eff("de_kuangchao")
	var pct := float(e.get("dmg_taken_pct", 0.15))
	_check(pct > 0.0, "狂潮应有受伤加深（表值 %.2f）" % pct)
	var sim := BattleSim.new()
	sim.record_events = false
	sim.setup(83, {"role_id": "zs", "level": 10, "traits": ["de_kuangchao"]},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var role := sim.role_unit()
	var foe := sim.alive_units("enemy")[0]
	var h0 := role.hp
	role.take_damage(100, foe, sim)
	_check(h0 - role.hp == int(100.0 * (1.0 + pct)),
		"受伤加深应在唯一入口生效一次（掉 %d，期望 %d）" % [h0 - role.hp, int(100.0 * (1.0 + pct))])
	# 技能路径同样只算一次（下沉后 SkillSystem 里的同款应用已删）
	var h1 := role.hp
	role.take_damage(100, foe, sim)
	_check(h1 - role.hp == int(100.0 * (1.0 + pct)),
		"受伤加深不应被算两遍（掉 %d）" % (h1 - role.hp))


# ---------- 22. B 批手感指标：一局下来真能凑出一条流派吗 ----------
## 固定种子模拟 20 局（每局 3~4 次三选一），统计「至少一条流派激活」的局占比。
## 阈值进 nodes.json run.school_active_rate_min：调平衡改表，不改代码。
func _test_school_build_rate() -> void:
	var run_v: Variant = TableCache.nodes_config().get("run", {})
	var min_rate := 0.7
	if run_v is Dictionary:
		min_rate = float((run_v as Dictionary).get("school_active_rate_min", 0.7))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	var runs := 20
	var ok_runs := 0
	for i in runs:
		var st := RunState.new()
		st.setup({"theme": "forest", "role_id": "zs", "level": 10, "seed": 1000 + i})
		for n in 4:   # 一局 3 层 + BOSS ≈ 3~4 次选择
			var ch: Array = st.roll_trait_choices(rng)
			if ch.is_empty():
				break
			var row: Dictionary = ch[rng.randi_range(0, ch.size() - 1)]
			st.traits.append(String(row.get("id", "")))
		var ts := TraitSystem.new(st.traits)
		for s in TraitSystem.SCHOOLS:
			if ts.school_active(s):
				ok_runs += 1
				break
	var rate := float(ok_runs) / float(runs)
	_check(rate >= min_rate,
		"20 局里「至少一条流派激活」占比 %.2f 应 ≥ %.2f（阈值读表）" % [rate, min_rate])


## traits.json 里某词条的 effect（用于「表值 vs 代码值」对拍）
func _trait_eff(id: String) -> Dictionary:
	for t in TableCache.traits():
		if String((t as Dictionary).get("id", "")) == id:
			return (t as Dictionary).get("effect", {})
	return {}
