# MonsterAI.gd —— 怪物/宠物自动施法决策（玩法文档 §2.5）
# 目标选择基础规则在 Combatant.pick_basic_target；本类只管"何时放技能"。
class_name MonsterAI
extends RefCounted


## BOSS/怪物技能循环：CD 转好即放（按表顺序）
static func decide(sim: BattleSim, unit: Combatant) -> void:
	if not unit.can_act():
		return
	for s in unit.skills:
		if int(s.cd_left) <= 0:
			var skill: Dictionary = s.def
			if SkillSystem.can_cast(sim, unit, skill):
				SkillSystem.enqueue_cast(sim, unit, skill)
				return


## 托管：玩家角色技能自动释放（优先级从大招到小技能；治疗/护盾按血线条件）
static func decide_auto(sim: BattleSim, unit: Combatant) -> void:
	if not unit.can_act() or unit.kind != "role":
		return
	var allies := sim.alive_units("ally")
	var enemies := sim.alive_units("enemy")
	if enemies.is_empty():
		return
	# 从后往前（5技 → 1技）
	for i in range(unit.skills.size() - 1, -1, -1):
		var s: Dictionary = unit.skills[i]
		var skill: Dictionary = s.def
		# 统一走 can_cast：CD / 能量 / 「本单位施法中不重复入队」三关都在这里把关
		# （历史 bug：托管绕过校验重复入队，前摇期每 tick 刷一条 cast_start）
		if not SkillSystem.can_cast(sim, unit, skill):
			continue
		var sid := String(skill.get("id", ""))
		if not _auto_condition(sim, unit, sid, skill, allies, enemies):
			continue
		SkillSystem.enqueue_cast(sim, unit, skill)
		return


static func _auto_condition(sim: BattleSim, unit: Combatant, sid: String,
		skill: Dictionary, allies: Array[Combatant], enemies: Array[Combatant]) -> bool:
	match sid:
		"fz_shengyu", "fz_puzhao":
			var threshold := 0.55 if sid == "fz_shengyu" else 0.70
			var need := 1 if sid == "fz_shengyu" else 2
			var low := 0
			for a in allies:
				if float(a.hp) / float(maxi(a.get_max_hp(), 1)) < threshold:
					low += 1
			return low >= need
		"fz_jinghua":
			for a in allies:
				if a.has_buff("bleed") or a.has_buff("poison") or a.has_buff("slow") \
						or a.has_buff("def_break") or a.has_buff("fear") or a.has_buff("stun"):
					return true
			return false
		"fz_zhudao":
			return enemies.size() >= 3 or sim.has_boss()
		"fs_midun":
			for a in allies:
				if float(a.hp) / float(maxi(a.get_max_hp(), 1)) < 0.50:
					return true
			return false
		"zs_zhanhou":
			return sim.has_boss() or enemies.size() >= 3
		"ck_dunying":
			return float(unit.hp) / float(maxi(unit.get_max_hp(), 1)) < 0.40
	# 通用：大招满能量即放；中费技能留 20 缓冲；小技能能量够就放
	var cost := int(skill.get("cost", 0))
	if cost >= 55:
		return unit.energy >= cost
	if cost >= 30:
		return unit.energy >= cost + 20
	return true
