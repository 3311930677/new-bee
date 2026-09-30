## 单机现货：纯规则层。存档读写与 RewardLedger 事务由 G 负责。
## 价格只依赖表、存档 seed/day 与已发生的修碑方式；不用现实日期或随机数。
class_name EconomyService

const MAX_HISTORY := 5


static func ensure(raw: Dictionary, cfg: Dictionary) -> Dictionary:
	var out := raw.duplicate(true)
	if not out.has("seed"):
		out["seed"] = maxi(1, int(cfg.get("day_seed", 7919)))
	if not out.has("day"):
		out["day"] = 1
	if not out.has("next_tx"):
		out["next_tx"] = 1
	for key in ["bought", "sold", "history", "orders", "work"]:
		if not out.has(key):
			out[key] = {}
	return out


static func good(cfg: Dictionary, good_id: String) -> Dictionary:
	for row in (cfg.get("goods", []) as Array):
		if row is Dictionary and String((row as Dictionary).get("id", "")) == good_id:
			return row as Dictionary
	return {}


static func site(cfg: Dictionary, site_id: String) -> Dictionary:
	for row in (cfg.get("sites", []) as Array):
		if row is Dictionary and String((row as Dictionary).get("id", "")) == site_id:
			return row as Dictionary
	return {}


static func _index(rows: Array, id: String) -> int:
	for i in rows.size():
		if rows[i] is Dictionary and String((rows[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


static func key(site_id: String, good_id: String) -> String:
	return "%s|%s" % [site_id, good_id]


static func market_price(cfg: Dictionary, state: Dictionary, site_id: String,
		good_id: String, day: int, repair_method := "") -> Dictionary:
	var g := good(cfg, good_id)
	var s := site(cfg, site_id)
	if g.is_empty() or s.is_empty() or day < 1:
		return {}
	var gi := _index(cfg.get("goods", []) as Array, good_id)
	var si := _index(cfg.get("sites", []) as Array, site_id)
	# 简单的稳定整数散列；不使用 Godot hash()，跨进程和引擎升级仍可重现。
	var phase := posmod(int(state.get("seed", 7919)) + day * 37 + gi * 53 + si * 71, 17) - 8
	var event_pct := 0
	var event_name := ""
	var event: Variant = (cfg.get("events", {}) as Dictionary).get(repair_method, {})
	if event is Dictionary:
		event_pct = int(((event as Dictionary).get(site_id, {}) as Dictionary).get(good_id, 0))
		event_name = String((event as Dictionary).get("name", "")) if event_pct != 0 else ""
	var port_choice := String(state.get("port_event", ""))
	var port_event: Variant = (cfg.get("events", {}) as Dictionary).get(port_choice, {})
	if port_event is Dictionary:
		var port_pct := int(((port_event as Dictionary).get(site_id, {}) as Dictionary).get(good_id, 0))
		if port_pct != 0:
			event_pct += port_pct
			event_name = String((port_event as Dictionary).get("name", ""))
	var site_pct := int((s.get("price_pct", {}) as Dictionary).get(good_id, 100))
	var factor := maxi(1, 100 + phase + event_pct)
	var mid := maxi(1, roundi(float(int(g.get("base_gold", 1)) * site_pct * factor) / 10000.0))
	return {"mid": mid, "day_wave_pct": phase, "event_pct": event_pct,
		"event_name": event_name, "site_pct": site_pct}


static func quote(cfg: Dictionary, state: Dictionary, site_id: String,
		good_id: String, repair_method := "") -> Dictionary:
	var g := good(cfg, good_id)
	var s := site(cfg, site_id)
	if g.is_empty() or s.is_empty():
		return {}
	var day := maxi(1, int(state.get("day", 1)))
	var market := market_price(cfg, state, site_id, good_id, day, repair_method)
	var mid := int(market.get("mid", 1))
	var buy := maxi(1, ceili(float(mid * int(cfg.get("buy_markup_pct", 110))) / 100.0))
	var sell := maxi(1, floori(float(mid * int(cfg.get("sell_bid_pct", 88))) / 100.0)
		- int(g.get("haul_gold", 0)))
	var k := key(site_id, good_id)
	var bought: Dictionary = state.get("bought", {})
	var sold: Dictionary = state.get("sold", {})
	var stock := maxi(0, int((s.get("stock", {}) as Dictionary).get(good_id, 0))
		- int(bought.get(k, 0)))
	var demand := maxi(0, int((s.get("demand", {}) as Dictionary).get(good_id, 0))
		- int(sold.get(k, 0)))
	var history := history_for(cfg, state, site_id, good_id, repair_method)
	return {"good_id": good_id, "site_id": site_id, "day": day, "buy_gold": buy,
		"sell_gold": sell, "mid_gold": mid, "stock_left": stock, "demand_left": demand,
		"weight": int(g.get("weight", 1)), "haul_gold": int(g.get("haul_gold", 0)),
		"history": history, "day_wave_pct": int(market.get("day_wave_pct", 0)),
		"event_pct": int(market.get("event_pct", 0)),
		"event_name": String(market.get("event_name", ""))}


static func history_for(cfg: Dictionary, state: Dictionary, site_id: String,
		good_id: String, repair_method := "") -> Array:
	var k := key(site_id, good_id)
	var saved: Variant = (state.get("history", {}) as Dictionary).get(k, [])
	var out: Array = (saved as Array).duplicate(true) if saved is Array else []
	var day := maxi(1, int(state.get("day", 1)))
	if out.is_empty() or int((out.back() as Dictionary).get("day", 0)) < day:
		out.append({"day": day,
			"mid_gold": int(market_price(cfg, state, site_id, good_id, day, repair_method).get("mid", 0))})
	elif int((out.back() as Dictionary).get("day", 0)) == day:
		(out.back() as Dictionary)["mid_gold"] = int(market_price(cfg, state,
			site_id, good_id, day, repair_method).get("mid", 0))
	while out.size() > MAX_HISTORY:
		out.pop_front()
	return out


static func record_history(cfg: Dictionary, state: Dictionary, repair_method := "") -> void:
	var histories: Dictionary = state.get("history", {})
	for s in (cfg.get("sites", []) as Array):
		var sid := String((s as Dictionary).get("id", ""))
		for g in (cfg.get("goods", []) as Array):
			var gid := String((g as Dictionary).get("id", ""))
			histories[key(sid, gid)] = history_for(cfg, state, sid, gid, repair_method)
	state["history"] = histories


static func advance_day(cfg: Dictionary, state: Dictionary, repair_method := "") -> int:
	state["day"] = maxi(1, int(state.get("day", 1))) + 1
	state["bought"] = {}
	state["sold"] = {}
	record_history(cfg, state, repair_method)
	return int(state["day"])


static func carried_weight(cfg: Dictionary, items: Dictionary) -> int:
	var total := 0
	for g in (cfg.get("goods", []) as Array):
		var row := g as Dictionary
		total += maxi(0, int(items.get(String(row.get("id", "")), 0))) \
			* maxi(1, int(row.get("weight", 1)))
	return total
