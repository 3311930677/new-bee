extends RefCounted
## One round, one save: scores, first clear, title, side quest and materials move together.

static func state(host: Object) -> Dictionary:
	if not host.prog.get("flags") is Dictionary: host.prog["flags"] = {}
	var flags: Dictionary = host.prog.flags
	if not flags.get("archery_state") is Dictionary: flags["archery_state"] = {}
	var value: Dictionary = flags.archery_state
	for key in ["best_scores", "cleared", "first_claimed"]:
		if not value.get(key) is Dictionary: value[key] = {}
	return value

static func unlocked(host: Object, mode: Dictionary) -> bool:
	var required := String(mode.get("requires_clear", ""))
	var value: Dictionary = host.prog.get("flags", {}).get("archery_state", {})
	return required.is_empty() or bool(value.get("cleared", {}).get(required, false))

static func settle(host: Object, mode: Dictionary, token: String, score: int, bullseyes: int, lit_hits := 0) -> Dictionary:
	if host.save_locked: return {"ok": false, "line": "存档暂不可写，本局成绩已保留。请恢复保存后重试。"}
	if token.is_empty() or not unlocked(host, mode): return {"ok": false, "line": "请先完成初试百步，再参加巡灯守夜。"}
	var arrows := int(mode.get("arrows", 5))
	if score < 0 or score > arrows * 10 or bullseyes < 0 or bullseyes > arrows or lit_hits < 0 or lit_hits > arrows:
		return {"ok": false, "line": "本局成绩无效，未发放奖励。"}
	if RewardLedger.applied(host.ledger(), token): return {"ok": true, "duplicate": true, "line": "本局已保存，奖励已入袋。"}
	var before := {"prog": host.prog.duplicate(true), "wallet": host.wallet.duplicate(true), "items": host.items.duplicate(true)}
	var value := state(host)
	var id := String(mode.id)
	value.total_plays = int(value.get("total_plays", 0)) + 1
	value.total_bullseyes = int(value.get("total_bullseyes", 0)) + bullseyes
	value.best_scores[id] = maxi(int(value.best_scores.get(id, 0)), score)
	var passed := score >= int(mode.get("pass_score", 28)) and lit_hits >= int(mode.get("required_lit_hits", 0))
	var mastered := passed and score >= int(mode.get("master_score", 42))
	var grants := {}
	var parts: Array[String] = []
	var first := passed and not bool(value.first_claimed.get(id, false))
	if passed:
		value.cleared[id] = true
		value.first_claimed[id] = true
		var reward: Dictionary = mode.get("first_reward" if first else "repeat_reward", {})
		for currency in ["gold", "expedition", "soul", "honor"]:
			var count := maxi(0, int(reward.get(currency, 0)))
			if count > 0:
				grants[currency] = count
				parts.append("%s+%d" % [String({"gold": "金币", "expedition": "远征币", "soul": "魂晶", "honor": "荣誉"}[currency]), count])
		for item in reward.get("items", {}):
			var count := maxi(0, int(reward.items[item]))
			if count > 0:
				grants["item:" + String(item)] = count
				parts.append("%s×%d" % [host.item_name(String(item)), count])
		# Mastery is independent of the first-clear reward, including older saves.
		var title := String(mode.get("first_reward", {}).get("title", ""))
		if mastered and not title.is_empty():
			if not host.prog.get("titles") is Dictionary: host.prog["titles"] = {"owned": [], "active": ""}
			var titles: Dictionary = host.prog.titles
			if not titles.get("owned", []) is Array: titles["owned"] = []
			if not titles.get("owned", []).has(title):
				var owned: Array = titles.get("owned", [])
				owned.append(title)
				titles["owned"] = owned
				parts.append("解锁称号【百步穿杨】")
		if host.has_method("side_report"): host.side_report("archery", id, "lorin_wilds", false)
	var applied := RewardLedger.apply(RewardLedger.make(token, {}, grants), host.ledger(), host)
	if not bool(applied.get("ok", false)) or not host.save_game():
		host.prog = before.prog
		host.wallet = before.wallet
		host.items = before.items
		return {"ok": false, "line": "本局尚未保存，奖励未入账；点击「重试保存」即可重试。"}
	var line := "【%s】%d环 · %s：%s" % ["神射魁首" if mastered else "演武达标", score, "首通" if first else "再战", " · ".join(parts)] if passed else \
		"本局%d环，达标需%d环。%s再调整风偏与蓄力试试。" % [score, int(mode.get("pass_score", 28)), "需亮灯命中%d箭；" % int(mode.required_lit_hits) if mode.has("required_lit_hits") else ""]
	return {"ok": true, "passed": passed, "mastered": mastered, "first": first, "line": line}
