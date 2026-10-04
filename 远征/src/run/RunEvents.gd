extends RefCounted

static func row(theme: String) -> Dictionary:
	return TableCache._load("res://data/run_events.json").get("events", {}).get(theme, {}).duplicate(true)

static func apply(st: RunState, progress: Dictionary, choice: String) -> Dictionary:
	var entry := row(st.theme)
	if bool(progress.get("interact_done", false)): return {"ok": false, "reason": "done"}
	if not entry.get("choices", {}).has(choice): return {"ok": false, "reason": "choice"}
	var cap := st.max_hp()
	if choice == "rest":
		st.heal(maxi(1, roundi(cap * float(entry.heal_pct))))
	else:
		var potion_count := int(entry.get("potions",0))
		if potion_count>0 and st.potions>=3: return {"ok":false,"reason":"potions","message":"药剂已满，先选择休整；补给袋不会被白白消耗。"}
		var hp := cap if st.hp < 0 else st.hp
		var cost := maxi(1, roundi(cap * float(entry.cost_hp_pct)))
		if hp <= cost: return {"ok": false, "reason": "hp", "message": "体力不足，先选择休整；这项行动不能让角色倒下。"}
		st.hp = hp-cost
		st.gold += int(entry.gold)
		st.expedition += int(entry.get("expedition",0))
		st.soul += int(entry.get("soul",0))
		st.potions = mini(3,st.potions+potion_count)
	progress["event_choice"] = choice
	progress["interact_done"] = true
	return {"ok": true}
