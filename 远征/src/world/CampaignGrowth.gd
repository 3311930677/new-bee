## 主世界成长校准：配置覆盖首通经验，保留旧表供旧档计算差额。
class_name CampaignGrowth

static func config() -> Dictionary:
	return TableCache.campaign_growth_config()

static func story_rows() -> Array:
	var rows: Array = TableCache.story_quests_config().get("steps", []).duplicate(true)
	var steps: Dictionary = config().get("steps", {})
	for row in rows:
		var id := String(row.get("id", ""))
		if steps.has(id): row["reward"]["exp"] = int(steps[id].get("exp", 0))
	return rows

static func revision(prog: Dictionary, id: String) -> int:
	return int(prog.get("campaign_growth", {}).get("story_revision", {}).get(id, 1))

static func mark(prog: Dictionary, id: String) -> void:
	if not config().get("steps", {}).has(id): return
	var root: Dictionary = prog.get("campaign_growth", {}).duplicate(true)
	var marks: Dictionary = root.get("story_revision", {}).duplicate(true)
	marks[id] = int(config().get("version", 2))
	root["story_revision"] = marks
	prog["campaign_growth"] = root

## 只读计划；调用方以奖励账本与版本标记在同一存档事务中提交。
static func catchup_plan(prog: Dictionary) -> Array:
	var result: Array = []
	var done: Array = prog.get("story", {}).get("done", [])
	var steps: Dictionary = config().get("steps", {})
	var version := int(config().get("version", 2))
	for row in TableCache.story_quests_config().get("steps", []):
		var id := String(row.get("id", ""))
		if id in done and steps.has(id) and revision(prog, id) < version:
			result.append({"id": id, "exp": maxi(0, int(steps[id].get("exp", 0)) - int(row.get("reward", {}).get("exp", 0))),
				"transaction_id": RewardLedger.tx_id("campaign_growth", id, str(version))})
	return result

static func enemy_level(map_id: String, slot: Dictionary, fallback: int) -> int:
	var levels: Dictionary = config().get("enemy_levels", {})
	if not levels.has(map_id): return maxi(1, fallback)
	return maxi(1, int(levels[map_id]) + int(slot.get("level_offset", 0)))

static func validate(value: Variant, story: Variant) -> bool:
	if not (value is Dictionary) or not (story is Dictionary): return false
	var marks: Variant = value.get("story_revision", {})
	if not (marks is Dictionary): return false
	var steps: Dictionary = config().get("steps", {})
	var version := int(config().get("version", 2))
	for id in marks:
		var n: Variant = marks[id]
		if not steps.has(id) or not id in story.get("done", []): return false
		if not (n is int or n is float) or float(n) != float(int(n)) or int(n) < 1 or int(n) > version: return false
	return true
