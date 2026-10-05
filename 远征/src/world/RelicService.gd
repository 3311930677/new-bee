## 传世挑战的持久化抽签与奖励事务，和主线首通/野外刷新分开。
extends RefCounted

static func cfg() -> Dictionary:
	return TableCache._load("res://data/relic_hunts.json")

static func state(host: Object) -> Dictionary:
	return host.prog.get("relic_hunts", {})

static func validate(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	var state: Dictionary = raw
	for key in ["seq", "wins", "purchases"]:
		var n: Variant = state.get(key, 0)
		if not (n is int or n is float) or float(n) < 0 or float(n) != floorf(float(n)): return false
	if not state.get("misses", {}) is Dictionary or not state.get("pending", {}) is Dictionary: return false
	for role in state.get("misses", {}):
		var n: Variant = state.misses[role]
		if template(String(role)).is_empty() or not (n is int or n is float) or float(n) < 0 or float(n) >= int(cfg().pity_wins) or float(n) != floorf(float(n)): return false
	if state.has("rng_state") and (not state.rng_state is String or not String(state.rng_state).is_valid_int()): return false
	var pending: Dictionary = state.get("pending", {})
	if not pending.is_empty():
		if String(pending.get("id", "")).is_empty() or hunt(String(pending.get("hunt", ""))).is_empty() or template(String(pending.get("role", ""))).is_empty(): return false
		for key in ["seed", "roll"]:
			var n: Variant = pending.get(key)
			if not (n is int or n is float) or float(n) != floorf(float(n)): return false
		if int(pending.seed) < 1 or int(pending.roll) < 0 or int(pending.roll) >= int(cfg().roll_range): return false
	return true

static func hunt(id: String) -> Dictionary:
	for row in cfg().get("hunts", []):
		if String(row.id) == id: return row
	return {}

static func template(role: String) -> String:
	return String(cfg().get("weapons", {}).get(role, ""))

static func ready(host: Object) -> bool:
	return not host.save_locked and host.story_step_done(String(cfg().get("unlock_story", "s36"))) and int(host.prog.get("level", 1)) >= int(cfg().get("unlock_level", 60))

static func begin(host: Object, id: String, role: String) -> Dictionary:
	if not ready(host) or hunt(id).is_empty() or template(role).is_empty():
		return {"ok":false, "line":"主线通关且60级后开放传世挑战"}
	var next := state(host).duplicate(true)
	var pending: Dictionary = next.get("pending", {})
	if not pending.is_empty(): return {"ok":true, "ticket":pending.duplicate(true), "line":"继续未结的传世挑战"}
	var rng := RandomNumberGenerator.new()
	if next.has("rng_state"): rng.state = int(String(next.rng_state))
	else: rng.randomize()
	var seq := int(next.get("seq", 0)) + 1
	pending = {"id":"hunt_%d" % seq, "hunt":id, "role":role,
		"seed":rng.randi_range(1, 2147483647), "roll":rng.randi_range(0, int(cfg().roll_range)-1)}
	next["seq"] = seq
	next["rng_state"] = str(rng.state)
	next["pending"] = pending
	var before: Dictionary = host.prog.duplicate(true)
	host.prog["relic_hunts"] = next
	if not host.save_game():
		host.prog = before
		return {"ok":false, "line":"开战记录未保存，请重试"}
	return {"ok":true, "ticket":pending.duplicate(true), "line":"挑战开始"}

static func finish(host: Object, ticket_id: String, result: String, participants: Array = []) -> Dictionary:
	if host.save_locked: return {"ok":false, "line":"存档暂不可写"}
	var next := state(host).duplicate(true)
	var pending: Dictionary = next.get("pending", {})
	if pending.is_empty() or String(pending.get("id", "")) != ticket_id:
		return {"ok":false, "line":"这场挑战已结束，不重复领奖"}
	if result not in ["victory", "defeat", "flee", "draw"]: return {"ok":false, "line":"挑战结果尚未确认"}
	var before := {"prog":host.prog.duplicate(true), "wallet":host.wallet.duplicate(true), "items":host.items.duplicate(true)}
	var role := String(pending.role)
	var counters: Dictionary = next.get("misses", {}).duplicate(true)
	var miss := int(counters.get(role, 0))
	var drop := result == "victory" and (int(pending.roll) < int(round(float(cfg().drop_chance)*int(cfg().roll_range))) or miss + 1 >= int(cfg().pity_wins))
	var rewards: Dictionary = {}
	if result == "victory":
		CompanionService.record_win(host.prog, participants)
		next["wins"] = int(next.get("wins", 0)) + 1
		counters[role] = 0 if drop else miss + 1
		next["misses"] = counters
		rewards = cfg().get("rewards", {}).duplicate(true)
		if drop: rewards["equip:%s:5" % template(role)] = 1
	var tx := RewardLedger.make(RewardLedger.tx_id("relic_hunt", ticket_id, result), {}, rewards)
	var applied := RewardLedger.apply(tx, host.ledger(), host)
	if not bool(applied.get("ok", false)) or bool(applied.get("duplicate", false)):
		host.prog = before.prog; host.wallet = before.wallet; host.items = before.items
		return {"ok":false, "line":"奖励未落袋，请重试结算"}
	next["pending"] = {}
	host.prog["relic_hunts"] = next
	if not host.save_game():
		host.prog = before.prog; host.wallet = before.wallet; host.items = before.items
		return {"ok":false, "line":"结算未保存，奖励与保底已还原；可重试结算"}
	var line := "传世武器入袋！已自动锁定；满包时请到待领区领取。" if drop else \
		"挑战胜利：精炼石与宠物粮入袋 · 本职业保底 %d/%d" % [int(counters.get(role, 0)), int(cfg().pity_wins)]
	if result != "victory": line = "挑战未通关，保底不增加；整备后可再挑战。"
	return {"ok":true, "drop":drop, "line":line}

static func buy(host: Object, role: String) -> Dictionary:
	if not ready(host) or template(role).is_empty(): return {"ok":false, "line":"主线通关且60级后开放"}
	if not state(host).get("pending", {}).is_empty(): return {"ok":false, "line":"请先结束当前挑战"}
	if int(state(host).get("wins", 0)) < int(cfg().buy_requires_wins): return {"ok":false, "line":"成功挑战20次后可购买"}
	var before := {"prog":host.prog.duplicate(true), "wallet":host.wallet.duplicate(true), "items":host.items.duplicate(true)}
	var next := state(host).duplicate(true)
	var seq := int(next.get("purchases", 0)) + 1
	var applied := RewardLedger.apply(RewardLedger.make(RewardLedger.tx_id("relic_buy", str(seq), role),
		{"gold":int(cfg().buy_gold)}, {"equip:%s:5" % template(role):1}), host.ledger(), host)
	if not bool(applied.get("ok", false)) or bool(applied.get("duplicate", false)):
		host.prog = before.prog; host.wallet = before.wallet; host.items = before.items
		return {"ok":false, "line":"金币不足或装备未能入袋"}
	next["purchases"] = seq
	host.prog["relic_hunts"] = next
	if not host.save_game():
		host.prog = before.prog; host.wallet = before.wallet; host.items = before.items
		return {"ok":false, "line":"购买未保存，金币已退回"}
	return {"ok":true, "line":"传世武器已购入并锁定，请查看背包／待领区"}

static func claim_pet(host: Object) -> Dictionary:
	var config := cfg()
	var pid := String(config.pet_id)
	if not ready(host) or int(state(host).get("wins", 0)) < int(config.pet_requires_wins):
		return {"ok":false, "line":"通关后成功挑战120次可结缘归路圣鹿"}
	if host.owns_pet(pid): return {"ok":false, "line":"已经结缘，无需重复领取"}
	if not state(host).get("pending", {}).is_empty(): return {"ok":false, "line":"请先结束当前挑战"}
	var before: Dictionary = host.prog.duplicate(true)
	var pets: Array = host.prog.get("pets", []).duplicate()
	pets.append(pid)
	host.prog["pets"] = pets
	var stats: Dictionary = host.prog.get("pet_stat", {}).duplicate(true)
	stats[pid] = {"lv":int(config.pet_start_level), "exp":0, "star":int(config.pet_start_star), "brk":0}
	host.prog["pet_stat"] = stats
	if not host.save_game():
		host.prog = before
		return {"ok":false, "line":"结缘未保存，领取资格保留"}
	return {"ok":true, "line":"传世·归路圣鹿已结缘，初始25级、4星；在伙伴页派出"}
