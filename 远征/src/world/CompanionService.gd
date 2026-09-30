class_name CompanionService
extends RefCounted

static func config() -> Dictionary:
	var value: Variant = TableCache._load("res://data/companion_growth.json")
	return value if value is Dictionary else {}

static func state(prog: Dictionary, pid: String) -> Dictionary:
	var root: Dictionary = prog.get("companions", {})
	var pets: Dictionary = root.get("pets", {})
	return (pets.get(pid, {"wins":0,"traits":[]}) as Dictionary).duplicate(true)

static func snapshot(prog: Dictionary, pid: String) -> Dictionary:
	var out := {}
	var cfg := config()
	for tid in state(prog,pid).get("traits",[]):
		if String(tid).is_empty(): continue
		var row: Dictionary = (cfg.get("traits",{}) as Dictionary).get(tid,{})
		if row.is_empty(): continue
		out[tid] = row.duplicate(true)
		if tid == "comp_resonance":
			out[tid]["elements"] = (cfg.get("pet_elements",{}) as Dictionary).get(pid,[]).duplicate()
			out[tid]["skill_elements"] = (cfg.get("skill_elements",{}) as Dictionary).duplicate(true)
	return out

static func record_win(prog: Dictionary, participants: Array) -> void:
	var root: Dictionary = prog.get("companions",{}).duplicate(true)
	var pets: Dictionary = root.get("pets",{})
	var counted: Array = []
	for pid in participants:
		if counted.has(pid) or not (prog.get("pets",[]) as Array).has(pid): continue
		counted.append(pid)
		var row := state(prog,String(pid))
		row["wins"] = mini(int(config().get("wins_cap",20)),int(row.get("wins",0)) + 1)
		pets[pid] = row
	if counted.is_empty(): return
	root["pets"] = pets
	prog["companions"] = root

## 分担是盾后直伤；经 _direct_damage 扣伙伴血，避免受击钩子递归。
static func guard(sim: BattleSim, victim: Combatant, amount: int, source: Combatant) -> int:
	if victim.kind != "role" or victim.side != "ally" or amount <= 0: return amount
	for pet in sim.alive_units("ally"):
		if pet.kind != "pet" or not pet.can_act(): continue
		var row: Dictionary = pet.companion_traits.get("comp_guard",{})
		var key := String(pet.data.get("id","")) + "|guard"
		if row.is_empty() or sim.companion_used.has(key) or pet.has_buff("invincible"): continue
		if amount < int(ceil(float(victim.get_max_hp()) * float(row.get("heavy_pct",0.15)))): continue
		var share := mini(pet.hp,int(float(amount) * float(row.get("share_pct",0.35))))
		if share <= 0: continue
		sim.companion_used[key] = sim.tick_count
		pet._direct_damage(share,source,sim)
		sim.emit({"t":"companion_trait","trait":"comp_guard","src":pet.uid,"uid":victim.uid,"amount":share})
		return amount - share
	return amount

static func _remove_one(unit: Combatant) -> int:
	for i in unit.buffs.size():
		if String(unit.buffs[i].type) in ["bleed","poison","stun","fear","confusion","slow","def_break","atk_down"]:
			unit.buffs.remove_at(i)
			return 1
	return 0

static func on_skill(sim: BattleSim, caster: Combatant, skill: Dictionary, effective: int, attack_effective := -1) -> void:
	if effective <= 0 or caster.side != "ally" or caster.kind not in ["role","pet"]: return
	var owner := sim.role_unit()
	if owner == null or not owner.alive: return
	for pet in sim.alive_units("ally"):
		if pet.kind != "pet" or not pet.can_act(): continue
		var pid := String(pet.data.get("id",""))
		var response: Dictionary = pet.companion_traits.get("comp_resonance",{})
		var rkey := pid + "|resonance"
		if not response.is_empty() and (caster.kind == "role" or caster == pet) \
				and sim.tick_count >= int(sim.companion_used.get(rkey,-1)):
			var element := String((response.get("skill_elements",{}) as Dictionary).get(String(skill.get("id","")),""))
			if (response.get("elements",[]) as Array).has(element):
				var cleansed := _remove_one(owner) + _remove_one(pet)
				if cleansed > 0:
					sim.companion_used[rkey] = sim.tick_count + int(float(response.get("cooldown",12)) * BattleSim.TICK_RATE)
					sim.emit({"t":"companion_trait","trait":"comp_resonance","src":pet.uid,"uid":owner.uid,"amount":cleansed})
		var pursuit: Dictionary = pet.companion_traits.get("comp_pursuit",{})
		if (effective if attack_effective < 0 else attack_effective) <= 0: continue
		var pkey := pid + "|pursuit"
		var effect: Dictionary = skill.get("effect",{}) if skill.get("effect") is Dictionary else {}
		var triggers_attack := float(skill.get("k",0)) > 0 or String(effect.get("type","")) in ["heal","invincible_heal"]
		if caster.kind != "role" or not triggers_attack or pursuit.is_empty() \
				or sim.tick_count < int(sim.companion_used.get(pkey,-1)): continue
		var target := pet.pick_basic_target(sim)
		if target == null: continue
		sim.companion_used[pkey] = sim.tick_count + int(float(pursuit.get("cooldown",12)) * BattleSim.TICK_RATE)
		var attack := int(float(pet.get_atk()) * float(pursuit.get("atk_mult",0.8)))
		var dealt := target.take_damage(DamageCalc.basic_damage(attack,target.get_def()),pet,sim)
		sim.emit({"t":"companion_trait","trait":"comp_pursuit","src":pet.uid,"uid":target.uid,"amount":dealt})

static func validate(value: Variant, owned: Variant) -> bool:
	if not (value is Dictionary) or not (owned is Array): return false
	var root := value as Dictionary
	if not (root.get("active","") is String) or not (root.get("pets",{}) is Dictionary): return false
	if not String(root.get("active","")).is_empty() and not owned.has(root.active): return false
	for pid in root.get("pets",{}):
		if not owned.has(pid) or TableCache.get_pet(String(pid)).is_empty(): return false
		var row: Variant = root.pets[pid]
		if not (row is Dictionary): return false
		var wins: Variant = row.get("wins",0)
		if not (wins is int or wins is float) or float(wins) < 0 or float(wins) > float(config().get("wins_cap",20)) \
				or not is_equal_approx(float(wins),roundf(float(wins))): return false
		if not (row.get("traits",[]) is Array) or row.get("traits",[]).size() > 2: return false
		var seen: Array = []
		var slot := 0
		for tid in row.get("traits",[]):
			if not (tid is String) or seen.has(tid) or (not String(tid).is_empty() and not (config().get("traits",{}) as Dictionary).has(tid)): return false
			if not String(tid).is_empty():
				if int(wins) < int(config().slots[slot].wins): return false
				seen.append(tid)
			slot += 1
	return true
