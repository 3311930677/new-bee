## 固定主线装备与材料，使用既有一次性账本；不强行换装或清理旧物。
class_name CampaignGear

static func config() -> Dictionary:
	return TableCache.campaign_gear_config()

static func reward(step: String, role: String) -> Dictionary:
	for row in config().get("rewards", []):
		if String(row.get("step", "")) != step: continue
		var tpl := String(row.get("role_equips", {}).get(role, row.get("equip", "")))
		if tpl.is_empty(): return {}
		return {"step": step, "tpl": tpl, "materials": row.get("materials", {}).duplicate(true),
			"transaction_id": RewardLedger.tx_id("campaign_gear", step, "first")}
	return {}

static func claim_plan(prog: Dictionary, role: String) -> Array:
	var result: Array = []
	var done: Array = prog.get("story", {}).get("done", [])
	for row in config().get("rewards", []):
		var next := reward(String(row.get("step", "")), role)
		if not next.is_empty() and next.step in done and not RewardLedger.applied(prog.get("ledger", {}), String(next.transaction_id)):
			result.append(next)
	return result

static func source_text(inst: Dictionary) -> String:
	var source := String(inst.get("source_id", ""))
	if source.begins_with("campaign_gear|"):
		var parts := source.split("|")
		if parts.size() > 1:
			var row := QuestService.step_by_id(TableCache.story_quests_config().get("steps", []), String(parts[1]))
			return "主线保底 · %s" % String(row.get("title", "已完成任务"))
	if source.begins_with("relic_hunt|"): return "传世挑战"
	if source.begins_with("relic_buy|"): return "珍品购入"
	if source.begins_with("res|"): return "随机战利"
	if source.begins_with("side|"): return "支线奖励"
	if not source.is_empty(): return "探索奖励"
	return ""
