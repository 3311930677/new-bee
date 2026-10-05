## 已到访地点的驿路旅行。纯状态预检与提交，场景切换交给调用方。
extends RefCounted

static func cfg() -> Dictionary:
	return TableCache._load("res://data/journey.json")

static func point(map_id: String) -> Dictionary:
	for row in cfg().get("points", []):
		if String(row.get("map", "")) == map_id: return row
	return {}

static func blocked(host: Object) -> String:
	if host.save_locked: return "存档暂不可写"
	for good in TableCache.economy_config().get("goods", []):
		if int(host.items.get(String(good.id), 0)) > 0:
			return "携带商货时请沿道路运输，卖出或交货后可乘驿车"
	var economy: Dictionary = host.prog.get("economy", {})
	for record in economy.get("orders", {}).values():
		if String(record.get("status", "")) in ["active", "accepted", "carrying", "expired"]:
			return "请先交付或退掉运输订单"
	for record in host.prog.get("trade_contracts", {}).values():
		if String(record.get("status", "")) == "active": return "请先交付或退掉运输合约"
	if String(host.prog.get("road_mail", {}).get("status", "")) == "active":
		return "邮路运送途中需亲自走完道路"
	for trip in host.prog.get("oaths", {}).get("trips", {}).values():
		if String(trip.get("oath", "")) == "shelter" and String(trip.get("status", "")) == "active" and int(trip.get("phase", 0)) > 0:
			return "正在护送旅人，抵达后再乘驿车"
	return ""

static func status(host: Object, map_id: String) -> Dictionary:
	var row := point(map_id)
	if row.is_empty(): return {"ok":false, "line":"这里没有驿路落点"}
	var world: Dictionary = host.prog.get("main_world", {})
	var visited: Array = world.get("visited_maps", [])
	if not visited.has(map_id) and String(world.get("map_id", "")) != map_id:
		return {"ok":false, "line":"首次到访后解锁"}
	var required := String(row.get("requires_story", ""))
	if not required.is_empty() and not host.story_step_done(required):
		return {"ok":false, "line":"先完成这段道路的主线"}
	for flag in row.get("requires_flags", []):
		if not bool(host.prog.get("flags", {}).get(String(flag), false)):
			return {"ok":false, "line":"先完成入口机关"}
	var reason := blocked(host)
	return {"ok":reason.is_empty(), "line":"免费前往" if reason.is_empty() else reason}

static func travel(host: Object, map_id: String) -> Dictionary:
	var check := status(host, map_id)
	if not bool(check.ok): return check
	var map := TableCache.main_world_map(map_id)
	if map.is_empty(): return {"ok":false, "line":"目的地暂不可用"}
	var before: Dictionary = host.prog.duplicate(true)
	var state: Dictionary = host.prog.get("main_world", {}).duplicate(true)
	state["map_id"] = map_id
	state["layout_version"] = int(map.get("layout_version", 1))
	state["position"] = point(map_id).get("at", map.get("spawn", [480, 1030])).duplicate()
	state["respawn_at"] = state.get("respawn_by_map", {}).get(map_id, {}).duplicate(true)
	host.prog["main_world"] = WorldSession.normalize_state(state)
	if not host.save_game():
		host.prog = before
		return {"ok":false, "line":"旅行未保存，仍留在原地"}
	return {"ok":true, "line":"前往" + String(map.get("name", map_id))}
