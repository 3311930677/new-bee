class_name MentorCurriculum

static func config() -> Dictionary:
	return TableCache.mentor_curriculum_config()

static func rows(role_id: String) -> Array:
	return config().get("roles", {}).get(role_id, [])

static func row(skill_id: String) -> Dictionary:
	for role_id in config().get("roles", {}):
		for entry in rows(String(role_id)):
			if String(entry.id) == skill_id: return entry
	return {}

static func state(prog: Dictionary) -> Dictionary:
	return prog.get("skill_curriculum", {"unlocked": [], "mastery": {}, "variants": {}, "encounters": {}}).duplicate(true)

static func status(host: Node, sid: String) -> String:
	var entry := row(sid)
	if entry.is_empty() or not entry in rows(host.selected_role): return "invalid"
	var root := state(host.prog)
	if sid in root.unlocked:
		if root.variants.has(sid): return "chosen"
		return "choose" if int(root.mastery.get(sid, 0)) >= int(entry.mastery_target) else "practice"
	if int(host.prog.get("level", 1)) < int(entry.level): return "level"
	if not host.story_step_done(String(entry.after)): return "story"
	var previous := String(entry.previous)
	if previous != host.mentor_second_skill() and not previous in root.unlocked: return "previous"
	if previous == host.mentor_second_skill() and not previous in host.mentor_state().unlocked: return "previous"
	return "ready"

static func unlocked(prog: Dictionary, role_id: String) -> Array:
	var out: Array = []
	var root := state(prog)
	for entry in rows(role_id):
		if String(entry.id) in root.unlocked: out.append(String(entry.id))
	return out

static func variants(prog: Dictionary, role_id: String) -> Dictionary:
	var out := {}
	var root := state(prog)
	for entry in rows(role_id):
		var choice := String(root.variants.get(String(entry.id), ""))
		if entry.variants.has(choice): out[String(entry.id)] = entry.variants[choice].duplicate(true)
	return out

# 所有修改都用同一写盘事务，调用方不自行消费金币。
static func apply(host: Node, sid: String, action: String, choice := "", persist := true) -> Dictionary:
	if host.save_locked: return {"ok": false, "reason": "locked"}
	var entry := row(sid)
	var current := status(host, sid)
	if entry.is_empty(): return {"ok": false, "reason": "invalid"}
	var root := state(host.prog)
	var cost := 0
	match action:
		"learn":
			if current != "ready": return {"ok": false, "reason": current}
			cost = int(entry.gold)
			root.unlocked.append(sid)
		"choose":
			if current != "choose" or not entry.variants.has(choice): return {"ok": false, "reason": "choice"}
			root.variants[sid] = choice
		"reset":
			if current != "chosen": return {"ok": false, "reason": current}
			cost = int(config().get("reset_cost_gold", 120))
			root.variants.erase(sid)
		_:
			return {"ok": false, "reason": "invalid"}
	if int(host.wallet.get("gold", 0)) < cost: return {"ok": false, "reason": "gold"}
	var before_prog: Dictionary = host.prog.duplicate(true)
	var before_wallet: Dictionary = host.wallet.duplicate(true)
	host.prog["skill_curriculum"] = root
	host.wallet["gold"] = int(host.wallet.get("gold", 0)) - cost
	if persist and not host.save_game():
		host.prog = before_prog
		host.wallet = before_wallet
		return {"ok": false, "reason": "save_failed"}
	return {"ok": true, "skill": sid, "cost": cost}

static func report(host: Node, skills: Array, encounter_id: String, persist := true) -> Array:
	if host.save_locked or encounter_id.is_empty() or encounter_id.length() > 256: return []
	var root := state(host.prog)
	var counted: Array = root.encounters.get(encounter_id, []).duplicate()
	var messages: Array = []
	for entry in rows(host.selected_role):
		var sid := String(entry.id)
		if not sid in skills or not sid in root.unlocked or sid in counted: continue
		var old := int(root.mastery.get(sid, 0))
		if old >= int(entry.mastery_target): continue
		root.mastery[sid] = old + 1
		counted.append(sid)
		messages.append("熟练 · %s %d/%d" % [String(TableCache.get_skill(sid).get("name", sid)), old + 1, int(entry.mastery_target)])
	if messages.is_empty(): return []
	root.encounters[encounter_id] = counted
	var before: Dictionary = host.prog.duplicate(true)
	host.prog["skill_curriculum"] = root
	if persist and not host.save_game():
		host.prog = before
		return []
	return messages

static func validate(value: Variant, prog: Dictionary) -> bool:
	if not value is Dictionary: return false
	for key in ["unlocked", "mastery", "variants", "encounters"]:
		if not value.has(key): return false
	if not value.unlocked is Array or not value.mastery is Dictionary or not value.variants is Dictionary or not value.encounters is Dictionary: return false
	if value.unlocked.size() > 12 or value.encounters.size() > 28: return false
	var found: Array = []
	for sid in value.unlocked:
		if not sid is String or sid in found or row(sid).is_empty(): return false
		found.append(sid)
		var previous := String(row(sid).previous)
		if not row(previous).is_empty() and not previous in value.unlocked: return false
		if row(previous).is_empty() and not previous in prog.get("act1", {}).get("mentor", {}).get("unlocked", []): return false
	var counts := {}
	for eid in value.encounters:
		if not eid is String or eid.is_empty() or eid.length() > 256 or not value.encounters[eid] is Array: return false
		var seen: Array = []
		if value.encounters[eid].is_empty(): return false
		for sid in value.encounters[eid]:
			if not sid is String or not sid in found or sid in seen: return false
			seen.append(sid)
			counts[sid] = int(counts.get(sid, 0)) + 1
	for sid in value.mastery:
		if not sid in found: return false
		var n: Variant = value.mastery[sid]
		if not (n is int or n is float) or not is_finite(float(n)) or float(n) != float(int(n)) or int(n) < 0 or int(n) > int(row(sid).mastery_target): return false
		if int(n) != int(counts.get(sid, 0)): return false
	for sid in counts:
		if int(counts[sid]) != int(value.mastery.get(sid, 0)): return false
	for sid in value.variants:
		if not sid in found or not value.variants[sid] is String: return false
		if not row(sid).variants.has(value.variants[sid]) or int(value.mastery.get(sid, 0)) < int(row(sid).mastery_target): return false
	return true
