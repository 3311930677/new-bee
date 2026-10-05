## 只对显式主世界/传世挑战生效，演武与原历练不套用主线倍率。
extends RefCounted

static func cfg() -> Dictionary:
	return TableCache._load("res://data/campaign_difficulty.json")

static func profile(map_id: String) -> Dictionary:
	return cfg().get("maps", {}).get(map_id, {}).duplicate(true)

static func extra_phases(mon_id: String) -> Array:
	return cfg().get("extra_phases", {}).get(mon_id, []).duplicate(true)
