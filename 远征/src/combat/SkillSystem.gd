# SkillSystem.gd —— 技能施法：校验 → 前摇队列 → 结算（玩法文档 §1.4 §2.1）
class_name SkillSystem
extends RefCounted

const WINDUP_TICKS := 12        # 前摇 0.4s
const WINDUP_TICKS_ULT := 15    # 大招前摇 0.5s（cost≥60）


## 施法校验：存活 / 未被控制 / CD 转好 / 能量足够 / 本单位不在施法中
static func can_cast(sim: BattleSim, caster: Combatant, skill: Dictionary) -> bool:
	if not caster.can_act():
		return false
	if String(skill.get("id", "")).is_empty():
		return false
	# 施法中（前摇队列里已有本单位的招）不可再次入队——历史 bug：AI 每 tick 重复决策入队，
	# 一次施法刷出十几条 cast_start（提示/音效风暴），队列还被无效项塞满
	for q in sim.cast_queue:
		if int((q as Dictionary).get("uid", -1)) == caster.uid:
			return false
	for s in caster.skills:
		if String(s.def.get("id", "")) == String(skill.get("id", "")):
			if int(s.cd_left) > 0:
				return false
			break
	if caster.kind == "role" and int(skill.get("cost", 0)) > caster.energy:
		return false
	return true


## 入队（校验通过后调用）
static func enqueue_cast(sim: BattleSim, caster: Combatant, skill: Dictionary) -> void:
	var windup := WINDUP_TICKS_ULT if int(skill.get("cost", 0)) >= 60 else WINDUP_TICKS
	if caster.traits != null:
		windup = maxi(6, int(float(windup) * (1.0 + caster.traits.passive_cd_pct() * 0.5)))
	sim.cast_queue.append({"uid": caster.uid, "skill": skill, "windup": windup})
	sim.emit({"t": "cast_start", "uid": caster.uid, "skill": String(skill.get("id", "")),
		"name": String(skill.get("name", ""))})


## 前摇到点结算
static func resolve_cast(sim: BattleSim, entry: Dictionary) -> void:
	var caster: Combatant = sim.unit_by_uid(int(entry.uid))
	if caster == null or not caster.alive:
		return
	var skill: Dictionary = entry.skill
	if not can_cast(sim, caster, skill):
		return
	# 全场已无敌人（只剩自方）时，伤害/控制类整招作废：不扣能量、不进 CD（历史 bug：空放照扣）
	var etype_pre := ""
	var effect_pre: Variant = skill.get("effect", {})
	if effect_pre is Dictionary:
		etype_pre = String((effect_pre as Dictionary).get("type", ""))
	if etype_pre != "heal" and etype_pre != "summon" and etype_pre != "cleanse":
		if sim.alive_units("enemy" if caster.side == "ally" else "ally").is_empty():
			return
	# 消耗与 CD
	if caster.kind == "role":
		caster.energy -= int(skill.get("cost", 0))
	var cd_ticks := int(float(skill.get("cd", 5)) * 30.0)
	if caster.traits != null:
		cd_ticks = maxi(15, int(float(cd_ticks) * (1.0 + caster.traits.passive_cd_pct())))
	for s in caster.skills:
		if String(s.def.get("id", "")) == String(skill.get("id", "")):
			s.cd_left = cd_ticks
			break
	# 连携检查（first 后 window 秒内施放 then）
	var combo := _check_combo(sim, caster, skill)
	sim.emit({"t": "cast", "uid": caster.uid, "skill": String(skill.get("id", "")),
		"name": String(skill.get("name", "")), "combo": combo.get("name", "")})
	_apply_skill(sim, caster, skill, combo)


static func _check_combo(sim: BattleSim, caster: Combatant, skill: Dictionary) -> Dictionary:
	var last: Dictionary = sim.last_cast.get(caster.uid, {})
	if last.is_empty():
		return {}
	var sid := String(skill.get("id", ""))
	if sid == String(last.get("skill_id", "")):
		return {}
	var last_id := String(last.get("skill_id", ""))
	var elapsed := sim.tick_count - int(last.get("tick", -99999))
	for c in TableCache.combos():
		if String(c.get("first", "")) == last_id and String(c.get("then", "")) == sid:
			if elapsed <= int(float(c.get("window", 5.0)) * 30.0):
				return c
	return {}


static func _apply_skill(sim: BattleSim, caster: Combatant, skill: Dictionary, combo: Dictionary) -> void:
	# 记录连携窗口起点
	sim.last_cast[caster.uid] = {"skill_id": String(skill.get("id", "")), "tick": sim.tick_count}
	var target_type := String(skill.get("target", "enemy_single"))
	var effect_v: Variant = skill.get("effect", {})
	var effect: Dictionary = effect_v if effect_v is Dictionary else {}
	var k := float(skill.get("k", 0.0))
	var hits: int = maxi(1, int(skill.get("hits", 1)))

	# k 动态调整
	if not effect.is_empty():
		var et := String(effect.get("type", ""))
		if et == "execute_cond":
			var t0 := _primary_target(sim, caster, target_type)
			if t0 != null and float(t0.hp) / float(maxi(t0.get_max_hp(), 1)) < float(effect.get("hp_below", 0.3)):
				k = float(effect.get("k_to", k))
		elif et == "vs_controlled":
			var t0 := _primary_target(sim, caster, target_type)
			if t0 != null and (t0.has_buff("stun") or t0.has_buff("fear") or t0.has_buff("confusion")):
				k = float(effect.get("k_to", k))
	# 连携加成
	if not combo.is_empty():
		var ce: Dictionary = combo.get("effect", {})
		var cet := String(ce.get("type", ""))
		if cet == "k_bonus":
			k += float(ce.get("value", 0.0))
		elif cet == "vs_slowed_bonus":
			var t0 := _primary_target(sim, caster, target_type)
			if t0 != null and t0.has_buff("slow"):
				k *= 1.0 + float(ce.get("pct", 0.3))

	# 目标集合
	var etype := String(effect.get("type", ""))
	var targets := _pick_targets(sim, caster, target_type)
	if targets.is_empty() and etype != "heal" and etype != "summon" and etype != "cleanse":
		# 兜底：目标集合为空（敌方前排全灭 / 双方全远程编成）时改打最低血单体（与普攻同规则），
		# 避免 front_all 类技能空放还照扣能量与 CD
		var enemies := sim.alive_units("enemy" if caster.side == "ally" else "ally")
		if not enemies.is_empty():
			targets = [caster.lowest_hp(enemies)]
	if targets.is_empty() and etype != "heal" and etype != "summon":
		return
	match etype:
		"heal":
			_apply_heal(sim, caster, skill, effect, targets, combo)
		"cleanse":
			for t in targets:
				var n := t.dispel_debuffs()
				sim.emit({"t": "cleanse", "uid": t.uid, "count": n})
		"lurk":
			caster.add_buff("lurk", caster.cc_duration_ticks(float(effect.get("dur", 3.0))), {})
			sim.emit({"t": "buff", "uid": caster.uid, "buff": "lurk"})
		"taunt":
			var t := _primary_target(sim, caster, target_type)
			if t != null and sim.rng.randf() >= t.cc_resist:
				t.add_buff("taunt", t.cc_duration_ticks(float(effect.get("dur", 3.0))),
					{"src_uid": caster.uid})
				sim.emit({"t": "buff", "uid": t.uid, "buff": "taunt"})
		"shield":
			for t in targets:
				var pool := int(float(t.get_max_hp()) * float(effect.get("hp_pct", 0.2)))
				t.add_buff("shield", -1, {"pool": pool})
				sim.emit({"t": "shield_add", "uid": t.uid, "pool": pool})
		"atk_up":
			for t in targets:
				t.add_buff("atk_up", int(float(effect.get("dur", 5.0)) * 30.0),
					{"pct": effect.get("pct", 0.2)})
				sim.emit({"t": "buff", "uid": t.uid, "buff": "atk_up"})
		"invincible_heal":
			for t in targets:
				t.add_buff("invincible", int(float(effect.get("dur", 1.5)) * 30.0), {})
				var amt := DamageCalc.heal_amount(t.get_max_hp(), caster.get_atk(),
					float(effect.get("hp_pct", 0.08)), 0.0)
				var ce: Dictionary = combo.get("effect", {})
				if String(ce.get("type", "")) == "heal_bonus":
					amt = int(float(amt) * (1.0 + float(ce.get("pct", 0.3))))
				t.heal(amt, caster, sim)
				sim.emit({"t": "buff", "uid": t.uid, "buff": "invincible"})
		"fear":
			var t := _primary_target(sim, caster, target_type)
			if t != null and sim.rng.randf() >= t.cc_resist:
				t.add_buff("fear", t.cc_duration_ticks(float(effect.get("dur", 1.5))), {})
				sim.emit({"t": "buff", "uid": t.uid, "buff": "fear"})
		"stun":
			var t := _primary_target(sim, caster, target_type)
			if t != null and sim.rng.randf() >= t.cc_resist:
				t.add_buff("stun", t.cc_duration_ticks(float(effect.get("dur", 1.2))), {})
				sim.emit({"t": "buff", "uid": t.uid, "buff": "stun"})
		"summon":
			var mon_id := String(skill.get("summon", ""))
			var count := int(skill.get("summon_count", 2))
			sim.summon_monsters(caster, mon_id, count, int(skill.get("summon_cap", 6)))
		_:
			_apply_damage(sim, caster, skill, k, hits, targets, effect, combo)


static func _apply_damage(sim: BattleSim, caster: Combatant, skill: Dictionary, k: float,
		hits: int, targets: Array[Combatant], effect: Dictionary, combo: Dictionary) -> void:
	var total := 0
	var is_full_energy := caster.energy >= Combatant.MAX_ENERGY
	for h in hits:
		var hit_targets := targets
		# 随机目标：每段独立随机
		if String(skill.get("target", "")) == "enemy_random":
			var all := sim.alive_units("enemy" if caster.side == "ally" else "ally")
			if all.is_empty():
				break
			hit_targets = [all[sim.rng.randi_range(0, all.size() - 1)]]
		for t in hit_targets:
			if not t.alive:
				continue
			var dmg := DamageCalc.basic_damage(int(float(caster.get_atk()) * k), t.get_def())
			# 无视防御（夺魄）
			if String(effect.get("type", "")) == "def_pierce":
				dmg = DamageCalc.basic_damage(int(float(caster.get_atk()) * k),
					int(float(t.get_def()) * (1.0 - float(effect.get("pct", 0.5)))))
			var is_crit := sim.rng.randf() < caster.get_crit()
			if is_crit:
				dmg = DamageCalc.crit_damage(dmg, caster.crit_dmg)
			# 词条修正（凝神/处决/碎冰/超载）
			if caster.traits != null:
				dmg = caster.traits.modify_skill_dmg(caster, t, dmg, is_full_energy)
			# 狂潮：受伤 +15%（受方词条）
			if t.traits != null:
				dmg = int(float(dmg) * (1.0 + t.traits.passive_dmg_taken_pct()))
			var dealt := t.take_damage(dmg, caster, sim, is_crit)
			total += dealt
			if caster.traits != null:
				caster.traits.on_hit(sim, caster, t, dealt, is_crit, true)
				if is_crit:
					caster.traits.on_crit(sim, caster, t)
			# 汲取（亡灵君王）：造成伤害的 50% 回复自身
			if String(effect.get("type", "")) == "lifesteal":
				caster.heal(maxi(1, int(float(dealt) * float(effect.get("pct", 0.5)))), caster, sim)
			# 技能附加 dot（宠物技能）
			var add_type := String(effect.get("apply", effect.get("type", "")))
			if add_type in ["bleed", "poison"]:
				var cap: int = int(effect.get("stack", 1)) + (caster.traits.bleed_stack_cap_add() if caster.traits != null else 0)
				var pct := float(effect.get("pct", 0.03))
				if caster.traits != null:
					pct *= 1.0 + caster.traits.bleed_dmg_pct()
				t.add_buff(add_type, int(float(effect.get("dur", 4.0)) * 30.0),
					{"pct": pct, "atk": caster.get_atk(), "stacks": 1, "stack_cap": maxi(1, cap)})
			elif add_type == "slow":
				t.add_buff("slow", int(float(effect.get("dur", 3.0)) * 30.0),
					{"pct": effect.get("pct", 0.2)})
			# 击退一排（岩龟冲撞）：目标从前排压到后排
			if String(effect.get("type", "")) == "knockback_row" and t.row == Combatant.ROW_FRONT:
				sim.knock_back(t)
	# 词条：技能施放钩子（能量导管）
	if caster.traits != null and total > 0:
		caster.traits.on_skill_cast(sim, caster, total)


static func _apply_heal(sim: BattleSim, caster: Combatant, skill: Dictionary,
		effect: Dictionary, targets: Array[Combatant], combo: Dictionary) -> void:
	var hp_pct := float(effect.get("hp_pct", 0.1))
	var atk_k := float(effect.get("atk_k", 0.0))
	var ce: Dictionary = combo.get("effect", {})
	if String(ce.get("type", "")) == "heal_bonus":
		hp_pct *= 1.0 + float(ce.get("pct", 0.3))
		atk_k *= 1.0 + float(ce.get("pct", 0.3))
	for t in targets:
		var amt := DamageCalc.heal_amount(t.get_max_hp(), caster.get_atk(), hp_pct, atk_k)
		t.heal(amt, caster, sim)


static func _pick_targets(sim: BattleSim, caster: Combatant, target_type: String) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var enemies := sim.alive_units("enemy" if caster.side == "ally" else "ally")
	var allies := sim.alive_units(caster.side)
	match target_type:
		"enemy_single":
			var t := caster.pick_basic_target(sim)
			if t != null:
				out.append(t)
		"enemy_front_all":
			for e in enemies:
				if e.row == Combatant.ROW_FRONT:
					out.append(e)
		"enemy_back_single":
			var best: Combatant = null
			for e in enemies:
				if e.row == Combatant.ROW_BACK and (best == null or e.hp < best.hp):
					best = e
			if best == null and not enemies.is_empty():
				best = caster.lowest_hp(enemies)
			if best != null:
				out.append(best)
		"enemy_all":
			out = enemies
		"enemy_random":
			var t := caster.pick_basic_target(sim)
			if t != null:
				out.append(t)
		"ally_single":
			out.append(_heal_target(caster, allies))
		"ally_all":
			out = allies
		"self":
			out.append(caster)
	return out


static func _heal_target(caster: Combatant, allies: Array[Combatant]) -> Combatant:
	var best: Combatant = allies[0]
	for a in allies:
		if float(a.hp) / float(maxi(a.get_max_hp(), 1)) < float(best.hp) / float(maxi(best.get_max_hp(), 1)):
			best = a
	return best


static func _primary_target(sim: BattleSim, caster: Combatant, target_type: String) -> Combatant:
	var targets := _pick_targets(sim, caster, target_type)
	if targets.is_empty():
		return null
	return targets[0]
