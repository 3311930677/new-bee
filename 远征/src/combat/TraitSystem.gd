# TraitSystem.gd —— 词条系统（玩法文档 §2.4）：44 词条钩子 + 六流派联动
class_name TraitSystem
extends RefCounted

const SCHOOLS := ["bleed", "crit", "thorn", "control", "energy", "summon"]

var rows: Array = []        # 本局已获词条（traits.json 行）
var school_count: Dictionary = {}  # school -> 数量


func _init(trait_ids: Array = []) -> void:
	for tid in trait_ids:
		add(String(tid))


func add(trait_id: String) -> void:
	var row: Dictionary = TableCache.get_trait(trait_id)
	if row.is_empty():
		push_warning("词条不存在：%s" % trait_id)
		return
	rows.append(row)
	var school := String(row.get("school", "none"))
	if school != "none" and school != "double":
		school_count[school] = int(school_count.get(school, 0)) + 1


func has_trait(trait_id: String) -> bool:
	for r in rows:
		if String(r.id) == trait_id:
			return true
	return false


func _effect_of(trait_id: String) -> Dictionary:
	for r in rows:
		if String(r.id) == trait_id:
			return r.get("effect", {})
	return {}


func _sum_stat(stat: String, key: String = "pct") -> float:
	var s := 0.0
	for r in rows:
		if String(r.get("hook", "")) == "passive":
			var e: Dictionary = r.get("effect", {})
			if String(e.get("stat", "")) == stat:
				s += float(e.get(key, 0.0))
	return s


func school_active(school: String) -> bool:
	return int(school_count.get(school, 0)) >= 3


# ---------- 被动数值（构建时由 BattleSim 烧入 base 属性） ----------
# 双刃词条（燃血/薄甲/狂潮/死线）的数值一律从表读，禁止硬编码——
# 历史坑：ATK 加成曾张冠李戴（燃血没加、薄甲多拿），且表值改动不同步。守卫见 verify_trait 第 6 段。
func passive_atk_pct() -> float:
	var s := _sum_stat("atk")
	for tid in ["de_ranxue", "de_baojia"]:
		var e := _effect_of(tid)
		if not e.is_empty():
			s += float(e.get("atk_pct", 0.0))
	return s


func passive_maxhp_pct() -> float:
	return _sum_stat("maxhp")


func passive_def_pct() -> float:
	var s := _sum_stat("def")
	var e := _effect_of("de_baojia")
	if not e.is_empty():
		s += float(e.get("def_pct", 0.0))
	return s


func passive_spd_pct() -> float:
	var s := _sum_stat("spd")
	var e := _effect_of("de_kuangchao")
	if not e.is_empty():
		s += float(e.get("spd_pct", 0.0))
	return s


func passive_crit_add() -> float:
	return _sum_stat("crit", "add")


func crit_dmg_override() -> float:
	var e := _effect_of("tr_crit_dmg")
	if not e.is_empty():
		return float(e.get("set", 1.5))
	return -1.0


func passive_energy_gain_pct() -> float:
	var s := _sum_stat("energy_gain")
	if school_active("energy"):
		s += 0.30
	return s


func passive_cc_resist() -> float:
	return _sum_stat("cc_resist", "add")


func passive_cd_pct() -> float:
	var e := _effect_of("tr_swift_cast")
	if e.is_empty():
		return 0.0
	return float(e.get("cd_pct", 0.0))


func passive_dmg_taken_pct() -> float:
	var e := _effect_of("de_kuangchao")
	if e.is_empty():
		return 0.0
	return float(e.get("dmg_taken_pct", 0.0))


func heal_taken_pct() -> float:
	var e := _effect_of("de_sixian")
	if e.is_empty():
		return 0.0
	return float(e.get("heal_taken_pct", 0.0))


# ---------- 动态数值（getter 每次查询） ----------
func dynamic_atk_pct(unit: Combatant) -> float:
	var pct := 0.0
	# 越战越勇：每击杀 +6%（叠 5 层）
	pct += 0.06 * float(unit.rampage_stacks)
	# 背水一战：HP<30% 时 +30%
	var e := _effect_of("tr_last_stand")
	if not e.is_empty() and float(unit.hp) / float(maxi(unit.get_max_hp(), 1)) < float(e.get("hp_below", 0.3)):
		pct += float(e.get("atk_pct", 0.0))
	# 死线：HP<阈值时伤害 +pct（近似并 ATK；阈值与幅度读表）
	var e_sx := _effect_of("de_sixian")
	if not e_sx.is_empty() \
			and float(unit.hp) / float(maxi(unit.get_max_hp(), 1)) < float(e_sx.get("hp_below", 0.5)):
		pct += float(e_sx.get("dmg_pct", 0.5))
	return pct


func dynamic_spd_pct(unit: Combatant) -> float:
	# 致命韵律：暴击后 3s SPD +15%（用 buff spd_up 承载，此处仅兜底返回 0）
	return 0.0


# ---------- 流派/词条查询 ----------
func cc_dur_pct() -> float:
	var s := 0.30 if school_active("control") else 0.0
	var e := _effect_of("tr_ctrl_1")
	if not e.is_empty():
		s += float(e.get("cc_dur_pct", 0.0))
	return s


func reflect_pct() -> float:
	var s := _sum_stat("reflect")
	var e := _effect_of("tr_thorn_1")
	if not e.is_empty():
		s += float(e.get("reflect_pct", 0.0))
	if school_active("thorn"):
		s *= 2.0
	return s


func has_first_strike() -> bool:
	return has_trait("tr_first_strike")


func bleed_dmg_pct() -> float:
	var s := 0.0
	var e := _effect_of("tr_bleed_1")
	if not e.is_empty():
		s += float(e.get("bleed_dmg_pct", 0.0))
	if school_active("bleed"):
		s += 1.0
	return s


func bleed_stack_cap_add() -> int:
	var e := _effect_of("tr_bleed_2")
	if e.is_empty():
		return 0
	return int(e.get("bleed_stack_add", 0))


func pet_stat_pct() -> float:
	var s := 0.0
	var e := _effect_of("tr_summon_1")
	if not e.is_empty():
		s += float(e.get("pet_stat_pct", 0.0))
	if school_active("summon"):
		s += 0.30
	return s


func energy_on_skill() -> int:
	var e := _effect_of("tr_energy_1")
	if e.is_empty():
		return 0
	return int(e.get("energy_on_skill", 0))


# ---------- 技能伤害修正（多词条叠加） ----------
func modify_skill_dmg(unit: Combatant, target: Combatant, dmg: int, is_full_energy: bool) -> int:
	var pct := 0.0
	# 凝神：技能伤害 +12%
	if has_trait("tr_focus"):
		pct += 0.12
	# 处决者：对 HP<20% 目标 +25%
	var e := _effect_of("tr_execute")
	if not e.is_empty() and not target.is_empty():
		var ratio := float(target.hp) / float(maxi(target.get_max_hp(), 1))
		if ratio < float(e.get("vs_hp_below", 0.2)):
			pct += float(e.get("dmg_pct", 0.25))
	# 碎冰：对受控目标 +20%
	if has_trait("tr_ctrl_2") and (target.has_buff("stun") or target.has_buff("fear") or target.has_buff("confusion")):
		pct += 0.20
	# 超载：满能量时 +20%
	if has_trait("tr_energy_2") and is_full_energy:
		pct += 0.20
	return maxi(1, int(float(dmg) * (1.0 + pct)))


# ---------- 钩子 ----------
func on_battle_start(sim: BattleSim, unit: Combatant) -> void:
	var e := _effect_of("tr_shield_start")
	if not e.is_empty():
		unit.add_buff("shield", -1, {"pool": int(float(unit.get_max_hp()) * float(e.get("shield_hp_pct", 0.15)))})
	var e2 := _effect_of("tr_energy_start")
	if not e2.is_empty():
		unit.gain_energy(int(e2.get("energy_add", 40)))


func on_hit(sim: BattleSim, unit: Combatant, target: Combatant, dmg: int, is_crit: bool, is_skill: bool) -> void:
	# 饮血：普攻吸血 5%
	var e := _effect_of("tr_lifesteal_s")
	if not e.is_empty() and not is_skill:
		unit.heal(maxi(1, int(float(dmg) * float(e.get("lifesteal", 0.05)))), unit, sim)
	# 寒触：15% 概率减速
	var e2 := _effect_of("tr_chill_touch")
	if not e2.is_empty() and target.alive and sim.rng.randf() < float(e2.get("chance", 0.15)):
		target.add_buff("slow", int(float(e2.get("dur", 2.0)) * 30.0), {"pct": e2.get("pct", 0.2)})
	# 重击：8% 概率定身
	var e3 := _effect_of("tr_stun_blow")
	if not e3.is_empty() and target.alive and sim.rng.randf() < float(e3.get("chance", 0.08)):
		if sim.rng.randf() >= target.cc_resist:
			target.add_buff("stun", target.cc_duration_ticks(float(e3.get("dur", 1.0))), {})
	# 燃血：每秒流失 1.5% MaxHP（在 on_tick 处理）
	# 反击架势：受击触发（on_behit）


func on_crit(sim: BattleSim, unit: Combatant, target: Combatant) -> void:
	# 裂创：暴击附加流血
	var e := _effect_of("tr_deep_wound")
	if not e.is_empty() and target.alive:
		var cap := 3 + bleed_stack_cap_add()
		target.add_buff("bleed", int(float(e.get("dur", 4.0)) * 30.0),
			{"pct": e.get("pct", 0.03), "atk": unit.get_atk(), "stacks": 1, "stack_cap": cap})
	# 致命韵律：暴击后 SPD +15%×3s
	var e2 := _effect_of("tr_crit_1")
	if not e2.is_empty():
		unit.add_buff("spd_up", int(float(e2.get("dur", 3.0)) * 30.0), {"pct": e2.get("spd_pct", 0.15)})
	# 弱点洞悉：对满血目标暴击率加成（getter 端处理不了，简化为命中即触发一次小加速）


func on_behit(sim: BattleSim, unit: Combatant, src: Combatant, dmg: int) -> void:
	# 以伤换伤：受击回复 3% 伤害量
	var e := _effect_of("tr_thorn_2")
	if not e.is_empty():
		unit.heal(maxi(1, int(float(dmg) * float(e.get("behit_heal_pct", 0.03)))), unit, sim)
	# 反击架势：20% 概率反击 50% ATK
	var e2 := _effect_of("tr_counter_stance")
	if not e2.is_empty() and src != null and src.alive and sim.rng.randf() < float(e2.get("counter_chance", 0.2)):
		var counter := DamageCalc.basic_damage(int(float(unit.get_atk()) * float(e2.get("counter_k", 0.5))), src.get_def())
		src.take_damage(counter, unit, sim, false)


func on_kill(sim: BattleSim, unit: Combatant, victim: Combatant) -> void:
	# 越战越勇叠层
	if has_trait("tr_rampage"):
		unit.rampage_stacks = mini(unit.rampage_stacks + 1, 5)
	# 威吓：击杀后恐惧敌方全体 1s
	var e := _effect_of("tr_fear_aura")
	if not e.is_empty():
		for u in sim.alive_units("enemy" if unit.side == "ally" else "ally"):
			if sim.rng.randf() >= u.cc_resist:
				u.add_buff("fear", u.cc_duration_ticks(float(e.get("dur", 1.0))), {})
	# 流血流派击杀回血 5%
	if school_active("bleed"):
		unit.heal(maxi(1, int(float(unit.get_max_hp()) * 0.05)), unit, sim)


func on_tick(sim: BattleSim, unit: Combatant) -> void:
	# 生生不息：每秒回 0.5% MaxHP（30 ticks 一次）
	var e := _effect_of("tr_regen")
	if not e.is_empty() and sim.tick_count % 30 == 0:
		unit.heal(maxi(1, int(float(unit.get_max_hp()) * float(e.get("regen_hp_pct", 0.005)))), unit, sim)
	# 燃血：每秒流失 hp_drain_pct×MaxHP（数值读表）
	var e_drain := _effect_of("de_ranxue")
	if not e_drain.is_empty() and sim.tick_count % 30 == 0:
		unit._direct_damage(
			maxi(1, int(float(unit.get_max_hp()) * float(e_drain.get("hp_drain_pct", 0.015)))),
			unit, sim, true)


func on_skill_cast(sim: BattleSim, unit: Combatant, total_dmg: int) -> void:
	# 能量导管：技能命中回 5 能量
	var v := energy_on_skill()
	if v > 0:
		unit.gain_energy(v)


func prevent_death(sim: BattleSim, unit: Combatant) -> bool:
	# 回光返照：免死 1 次并回 20%HP（每场 1 次）
	var e := _effect_of("tr_second_wind")
	if e.is_empty():
		return false
	if unit.once_flags.has("second_wind"):
		return false
	unit.once_flags["second_wind"] = true
	unit.hp = maxi(1, int(float(unit.get_max_hp()) * float(e.get("survive_heal_pct", 0.20))))
	sim.emit({"t": "second_wind", "uid": unit.uid})
	return true


func on_pet_hit(sim: BattleSim, owner: Combatant, pet: Combatant, dmg: int) -> void:
	# 共鸣：宠物攻击 10% 概率回 3 能量
	var e := _effect_of("tr_summon_2")
	if not e.is_empty() and sim.rng.randf() < float(e.get("chance", 0.10)):
		owner.gain_energy(int(e.get("energy_add", 3)))
