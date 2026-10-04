class_name WorldCommission
extends RefCounted

const REGIONS := ["zhaoyuan", "shenyuan", "frost"]
const NAMES := ["昭元", "沉渊港", "霜关驿"]
const GATES := ["s04", "s13", "s21"]

static func templates() -> Array:
	var data: Variant = TableCache._load("res://data/world_commissions.json")
	return data.get("templates", []) if data is Dictionary else []

static func row(id: String) -> Dictionary:
	for r in templates():
		if String(r.id) == id: return r
	return {}

static func available(host: Object, region: String) -> bool:
	var i := REGIONS.find(region)
	return i >= 0 and host.story_step_done(GATES[i])

static func day() -> String:
	return Time.get_date_string_from_system()

static func state(host: Object) -> Dictionary:
	return host.prog.get("world_commissions", {})

static func offers(host: Object, region: String, board_day := "") -> Array:
	if not available(host, region): return []
	if board_day.is_empty(): board_day = day()
	var pool: Array = []
	for r in templates():
		if String(r.region) == region: pool.append(r)
	var out: Array = []
	var offset := absi(board_day.hash()) % pool.size()
	for slot in 2:
		var r: Dictionary = pool[(offset + slot) % pool.size()]
		out.append({"posting": "%s|%s|%d" % [r.id, board_day, slot], "template": r.id,
			"day": board_day, "slot": slot})
	for pid in state(host):
		var saved: Dictionary = state(host)[pid]
		if String(saved.status) not in ["active", "ready"] or String(row(String(saved.template)).get("region", "")) != region: continue
		if not out.any(func(r: Dictionary): return String(r.posting) == String(pid)):
			out.append(saved.duplicate(true))
	return out

static func current(record: Dictionary) -> Dictionary:
	var steps: Array = row(String(record.get("template", ""))).get("steps", [])
	var progress := int(record.get("progress", 0))
	if String(record.get("status", "")) != "active" or progress >= steps.size(): return {}
	var step: Dictionary = steps[progress].duplicate(true)
	var route: Dictionary = step.get("routes", {}).get(String(record.get("choice", "")), {})
	step.merge(route, true)
	return step

static func _snapshot(host: Object) -> Dictionary:
	return {"prog": host.prog.duplicate(true), "wallet": host.wallet.duplicate(true), "items": host.items.duplicate(true)}

static func _rollback(host: Object, before: Dictionary) -> void:
	host.prog = before.prog
	host.wallet = before.wallet
	host.items = before.items

static func _commit(host: Object, before: Dictionary, line: String, persist := true) -> Dictionary:
	if persist and not host.save_game():
		_rollback(host, before)
		return {"ok":false, "line":"存档写入失败，事务与物资已恢复；可重试"}
	return {"ok":true, "line":line}

static func accept(host: Object, posting: String, region: String, board_day := "") -> Dictionary:
	if host.save_locked: return {"ok":false, "line":"存档暂不可写"}
	if state(host).has(posting): return {"ok":false, "line":"这一公布已经接过；次日可接新单"}
	for offer in offers(host, region, board_day):
		if String(offer.posting) != posting: continue
		for old in state(host).values():
			if String(old.template) == String(offer.template) and String(old.status) in ["active", "ready"]:
				return {"ok":false,"line":"同类事务尚未交付，请先办完旧单"}
		var before := _snapshot(host)
		var record: Dictionary = offer.duplicate(true)
		record.merge({"status":"active", "progress":0, "choice":""})
		var records := state(host).duplicate(true)
		records[posting] = record
		host.prog["world_commissions"] = records
		return _commit(host, before, "已接「%s」，目标跨日保留" % String(row(String(record.template)).title))
	return {"ok":false, "line":"这条公布已更换，请刷新公告栏"}

static func action(host: Object, posting: String, map_id: String, step_id: String,
		choice := "", battle := false, persist := true) -> Dictionary:
	if host.save_locked: return {"ok":false, "line":"存档暂不可写"}
	var record: Dictionary = state(host).get(posting, {})
	var step := current(record)
	if step.is_empty() or String(step.map) != map_id or String(step.id) != step_id:
		return {"ok":false, "line":"这不是当前委托目标"}
	if String(step.kind) == "defeat" and not battle: return {"ok":false, "line":"需要守住岗火并击退来敌"}
	var choices: Dictionary = step.get("choices", {})
	if not choices.is_empty():
		if not choices.has(choice): return {"ok":false, "line":"请按线索选择"}
		if not String(step.get("correct", "")).is_empty() and choice != String(step.correct):
			return {"ok":false, "line":String(step.get("wrong", "线索尚未对上，可再试"))}
	var before := _snapshot(host)
	var tx := RewardLedger.make(RewardLedger.tx_id("world_commission", posting, step_id), step.get("costs", {}))
	var applied := RewardLedger.apply(tx, host.ledger(), host)
	if not bool(applied.ok) or bool(applied.duplicate):
		_rollback(host, before)
		return {"ok":false, "line":String(applied.get("err", "这一步已经记入委托"))}
	record["progress"] = int(record.progress) + 1
	if not choice.is_empty(): record["choice"] = choice
	if int(record.progress) >= (row(String(record.template)).steps as Array).size(): record["status"] = "ready"
	return _commit(host, before, "已记录：%s%s" % [String(step.name), " · 回本城公告栏交付" if record.status == "ready" else ""], persist)

static func abandon(host: Object, posting: String) -> Dictionary:
	if host.save_locked: return {"ok":false,"line":"存档暂不可写"}
	var record: Dictionary = state(host).get(posting, {})
	if String(record.get("status", "")) not in ["active", "ready"]: return {"ok":false,"line":"没有进行中的委托"}
	var before := _snapshot(host)
	record.status = "abandoned"
	return _commit(host, before, "委托已放弃；已用于修补的材料不返还，次日可接新单")

static func claim(host: Object, posting: String, city_map: String) -> Dictionary:
	if host.save_locked: return {"ok":false,"line":"存档暂不可写"}
	var record: Dictionary = state(host).get(posting, {})
	if String(record.get("status", "")) != "ready": return {"ok":false,"line":"请先完成现场目标"}
	var r := row(String(record.template))
	var cities := {"zhaoyuan":"lorin_wilds", "shenyuan":"shenyuan_port", "frost":"frost_post"}
	if city_map != String(cities.get(String(r.region), "")): return {"ok":false,"line":"请回发布委托的城镇交付"}
	var before := _snapshot(host)
	var tx := RewardLedger.make(RewardLedger.tx_id("world_commission", posting, "claim"), {}, r.reward)
	var applied := RewardLedger.apply(tx, host.ledger(), host)
	if not bool(applied.ok) or bool(applied.duplicate):
		_rollback(host, before)
		return {"ok":false,"line":"报酬未通过结算，请核对公告栏"}
	record.status = "done"
	return _commit(host, before, "交付「%s」 · %s" % [String(r.title), " · ".join(host.reward_lines(r.reward))])

static func entities(host: Object, map_id: String) -> Array:
	var out: Array = []
	for posting in state(host):
		var step := current(state(host)[posting])
		if step.is_empty() or String(step.map) != map_id: continue
		step["posting"] = posting
		out.append(step)
	return out

static func validate(records: Dictionary) -> bool:
	for posting in records:
		var value:Variant=records[posting]
		if not value is Dictionary:return false
		var r:Dictionary=value
		var definition:=row(String(r.get("template","")))
		if definition.is_empty():return false
		if not r.get("slot") is float and not r.get("slot") is int:return false
		var slot:=int(r.slot)
		if slot<0 or slot>1 or float(r.slot)!=float(slot):return false
		if not r.get("day") is String or not r.get("posting") is String:return false
		if String(posting)!="%s|%s|%d"%[definition.id,r.day,slot] or String(r.posting)!=String(posting):return false
		if String(r.get("status","")) not in ["active","ready","done","abandoned"]:return false
		if not r.get("progress") is float and not r.get("progress") is int:return false
		var progress:=int(r.progress)
		var steps:Array=definition.steps
		if progress<0 or progress>steps.size() or float(r.progress)!=float(progress):return false
		if String(r.status)=="active" and progress==steps.size():return false
		if String(r.status) in ["ready","done"] and progress!=steps.size():return false
		if not r.get("choice","") is String:return false
		var choice:=String(r.get("choice",""))
		if not choice.is_empty():
			var known:=false
			for i in progress:
				if (steps[i].get("choices",{}) as Dictionary).has(choice):known=true
			if not known:return false
	return true
