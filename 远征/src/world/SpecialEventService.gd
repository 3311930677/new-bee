## Three optional anecdotes. Stage, branch, battle ticket and chosen gift commit together.
class_name SpecialEventService
extends RefCounted

const PHASES := ["clue", "choice", "battle", "return", "done"]

static func rows() -> Array:
	return TableCache._load("res://data/special_events.json").get("events", [])

static func row(id: String) -> Dictionary:
	for entry in rows():
		if String(entry.id) == id: return entry
	return {}

static func state(host: Object) -> Dictionary:
	return host.prog.get("special_events", {})

static func record(host: Object, id: String) -> Dictionary:
	return state(host).get("records", {}).get(id, {})

static func unlocked(host: Object, id: String) -> bool:
	var entry := row(id)
	return not entry.is_empty() and host.story_step_done(String(entry.requires_story))

static func objective(host: Object, id: String) -> Dictionary:
	var entry := row(id)
	if entry.is_empty(): return {}
	match String(record(host,id).get("phase", "")):
		"clue": return entry.clue
		"choice", "battle": return entry.encounter
		"return": return entry.board
	return {}

static func tracked(host: Object) -> String:
	var id := String(state(host).get("tracked", ""))
	if not objective(host,id).is_empty(): return id
	for key in state(host).get("records", {}):
		if not objective(host,String(key)).is_empty(): return String(key)
	return ""

static func goal(host: Object, id := "") -> String:
	var key := id if not id.is_empty() else tracked(host)
	var entry := row(key)
	var target := objective(host,key)
	if target.is_empty(): return ""
	var map_name := String(TableCache.main_world_map(String(target.map)).get("name",target.map))
	var phase := String(record(host,key).get("phase",""))
	var action := "回城向%s复命并选谢礼" % String(entry.giver) if phase == "return" else \
		"处理意外遭遇" if phase == "battle" else String(target.name)
	return "%s · %s：%s" % [String(entry.title),map_name,action]

static func entities(host: Object, map_id: String) -> Array:
	var out: Array = []
	for entry in rows():
		var id := String(entry.id)
		if not unlocked(host,id): continue
		var current := record(host,id)
		var phase := String(current.get("phase",""))
		if phase == "done":
			if String(entry.aftermath.map) == map_id:
				out.append({"id":id,"feedback":true,"point":entry.aftermath,"name":entry.aftermath.name})
			continue
		if String(entry.board.map) == map_id:
			out.append({"id":id,"feedback":false,"point":entry.board,"name":"奇遇 · "+String(entry.title)})
		var target := objective(host,id)
		if not target.is_empty() and String(target.map)==map_id and phase != "return":
			out.append({"id":id,"feedback":false,"point":target,"name":"奇遇 · "+String(target.name)})
	return out

static func presentation(host: Object, id: String, map_id: String) -> Dictionary:
	var entry := row(id)
	if entry.is_empty(): return {}
	var saved := record(host,id)
	var phase := String(saved.get("phase",""))
	var text := String(entry.intro)
	var choices: Dictionary = {}
	var target := objective(host,id)
	if phase.is_empty() and map_id == String(entry.board.map):
		choices["accept"] = "接下这件趣事"
	elif phase == "done":
		text = String(entry.branches[String(saved.branch)].outcome)+"\n\n"+String(entry.note)
		var reward: Dictionary = entry.rewards[String(saved.reward)]
		text += "\n已选谢礼："+String(reward.label)+"\n"+String(reward.use)
	elif not target.is_empty() and String(target.map)==map_id:
		match phase:
			"clue":
				text = String(entry.clue.body)
				choices["inspect"] = "核对线索，继续寻找"
			"choice":
				text = String(entry.encounter.body)+"\n战斗路线带两瓶临时药剂，不消耗行旅药剂。"
				for key in entry.branches: choices[key] = String(entry.branches[key].label)
			"battle":
				text = "前方的意外尚未处理。失败或撤退可整备后重试，已查线索和已选路线保留。\n独立遭遇带两瓶临时药剂，不消耗行旅药剂。战斗不会额外掉落材料；谢礼在回城复命时领取。"
				choices["battle"] = "继续这场意外遭遇"
			"return":
				text = String(entry.branches[String(saved.branch)].outcome)+"\n\n"+String(entry.return_line)
				for key in entry.rewards:
					choices[key] = String(entry.rewards[key].label)
	if not target.is_empty() and String(target.map)!=map_id: text += "\n\n下一步："+goal(host,id)
	if phase != "done":
		text += "\n\n复命谢礼：金币 %d，以下二选一。" % int(entry.gold)
		for reward in entry.rewards.values():
			text += "\n"+String(reward.label)
			if phase in ["","return"]: text += " · "+String(reward.use)
	return {"id":id,"name":entry.title,"art":entry.art,"body":text,"choices":choices,
		"phase":phase,"goal":goal(host,id)}

static func _snapshot(host: Object) -> Array:
	return [host.prog.duplicate(true),host.wallet.duplicate(true),host.items.duplicate(true)]

static func _rollback(host: Object, before: Array) -> void:
	host.prog = before[0]
	host.wallet = before[1]
	host.items = before[2]

static func _commit(host: Object, id: String, next: Dictionary, before: Array, line: String) -> Dictionary:
	var next_state := state(host).duplicate(true)
	var records: Dictionary = next_state.get("records",{})
	records[id] = next
	next_state["records"] = records
	next_state["tracked"] = "" if String(next.phase)=="done" else id
	host.prog["special_events"] = next_state
	if not host.save_game():
		_rollback(host,before)
		return {"ok":false,"reason":"save_failed","line":"这一步未保存，进度与谢礼均已恢复，可以重试。"}
	return {"ok":true,"line":line}

static func action(host: Object, id: String, map_id: String, choice: String) -> Dictionary:
	if host.save_locked: return {"ok":false,"reason":"locked","line":"存档暂不可写，请稍后重试。"}
	var entry := row(id)
	if not unlocked(host,id): return {"ok":false,"reason":"locked","line":"这件趣事尚未开放。"}
	var before := _snapshot(host)
	var next := record(host,id).duplicate(true)
	var phase := String(next.get("phase",""))
	if choice == "accept" and phase.is_empty() and map_id == String(entry.board.map):
		next = {"phase":"clue","branch":"","reward":"","seed":int(entry.seed),"battle":{}}
		return _commit(host,id,next,before,"已接下："+String(entry.title)+"。"+goal_for_entry(entry,"clue"))
	if phase == "clue" and choice == "inspect" and map_id == String(entry.clue.map):
		next["phase"] = "choice"
		return _commit(host,id,next,before,"线索已收好。到"+String(entry.encounter.name)+"问清缘由。")
	if phase == "choice" and map_id == String(entry.encounter.map) and entry.branches.has(choice):
		next["branch"] = choice
		var branch: Dictionary = entry.branches[choice]
		next["phase"] = "battle" if branch.has("enemy") else "return"
		return _commit(host,id,next,before,"路线已记下；可以开始意外遭遇。" if branch.has("enemy") else String(branch.outcome))
	if phase == "return" and map_id == String(entry.board.map) and entry.rewards.has(choice):
		var reward: Dictionary = entry.rewards[choice]
		var grants: Dictionary = reward.grants.duplicate(true)
		grants["gold"] = int(entry.gold)
		var tx := RewardLedger.make(RewardLedger.tx_id("special_event",id,"claim"),{},grants)
		var paid := RewardLedger.apply(tx,host.ledger(),host)
		if not bool(paid.get("ok",false)) or not bool(paid.get("applied",false)):
			_rollback(host,before)
			return {"ok":false,"reason":"reward_failed","line":"谢礼未结算，进度已恢复。"}
		next["phase"] = "done"
		next["reward"] = choice
		return _commit(host,id,next,before,"谢礼入袋：金币 %d · %s。%s" % [int(entry.gold),String(reward.label),String(reward.use)])
	return {"ok":false,"reason":"wrong_step","line":"请按已接奇遇的地点和步骤继续。"}

static func goal_for_entry(entry: Dictionary, phase: String) -> String:
	var target: Dictionary = entry[phase]
	return "前往"+String(TableCache.main_world_map(String(target.map)).get("name",target.map))+"查看"+String(target.name)+"。"

## Persist the whole opening setup before showing combat. A restarted process reuses it.
static func prepare_battle(host: Object, id: String, map_id: String, ally: Dictionary) -> Dictionary:
	if host.save_locked: return {"ok":false,"line":"存档暂不可写，尚未开战。"}
	var entry := row(id)
	var next := record(host,id).duplicate(true)
	if entry.is_empty() or String(next.get("phase",""))!="battle" or map_id!=String(entry.encounter.map):
		return {"ok":false,"line":"这不是当前的意外遭遇。"}
	var branch: Dictionary = entry.branches.get(String(next.get("branch","")),{})
	if not branch.has("enemy"): return {"ok":false,"line":"当前路线无需战斗。"}
	if not (next.get("battle",{}) as Dictionary).is_empty():
		return {"ok":true,"battle":next.battle.duplicate(true)}
	if String(ally.get("role_id","")) not in ["zs","ck","fs","fz"]: return {"ok":false,"line":"请先选择职业。"}
	var before := _snapshot(host)
	var battle := {"token":"special|%s|%d" % [id,int(next.seed)],"seed":int(next.seed),
		"special_event_id":id,
		"ally":ally.duplicate(true),"enemy":{"theme":branch.theme,"lead_mon":branch.enemy,
		"node_type":"normal","display_level":int(branch.level),"layer":0,"solo":true},
		"mode":"pve","flee_rule":"free","presentation":"classic_inline","player_name":host.display_name()}
	next["battle"] = battle
	var saved := _commit(host,id,next,before,"遭遇已保存。")
	if bool(saved.ok): saved["battle"] = battle.duplicate(true)
	return saved

static func resolve_battle(host: Object, id: String, map_id: String, token: String, result: String) -> Dictionary:
	if host.save_locked: return {"ok":false,"line":"结果尚未保存，可重新进入本场。"}
	var entry := row(id)
	var next := record(host,id).duplicate(true)
	var pending: Dictionary = next.get("battle",{})
	if entry.is_empty() or String(next.get("phase",""))!="battle" or pending.is_empty() \
		or String(pending.get("token",""))!=token or map_id!=String(entry.encounter.map) \
		or result not in ["victory","flee","defeat","draw"]:
		return {"ok":false,"line":"此结果不属于当前奇遇，未推进任何进度。"}
	var before := _snapshot(host)
	next["battle"] = {}
	if result=="victory": next["phase"]="return"
	var branch: Dictionary = entry.branches[String(next.branch)]
	return _commit(host,id,next,before,String(branch.outcome) if result=="victory" else \
		"已保留线索和路线；整备后可再来，不会重新选择谢礼或战斗种子。")

static func validate(raw: Variant) -> bool:
	if not raw is Dictionary: return false
	if not raw.get("records",{}) is Dictionary or not raw.get("tracked","") is String: return false
	var records: Dictionary = raw.get("records",{})
	if not String(raw.get("tracked","")).is_empty() and not records.has(String(raw.tracked)): return false
	for id in records:
		var entry := row(String(id))
		var value: Variant = records[id]
		if entry.is_empty() or not value is Dictionary: return false
		for field in ["phase","branch","reward"]:
			if not value.get(field,"") is String: return false
		var phase := String(value.get("phase",""))
		if phase not in PHASES or not value.get("battle",{}) is Dictionary: return false
		var seed: Variant=value.get("seed")
		if not (seed is int or seed is float) or float(seed)!=float(entry.seed): return false
		var branch := String(value.get("branch",""))
		if phase in ["battle","return","done"] and not entry.branches.has(branch): return false
		if phase=="battle" and not entry.branches[branch].has("enemy"): return false
		if phase=="done" and not entry.rewards.has(String(value.get("reward",""))): return false
		var pending: Dictionary = value.get("battle",{})
		if not pending.is_empty():
			if phase!="battle" or not pending.get("ally") is Dictionary or not pending.get("enemy") is Dictionary: return false
			if not pending.get("token","") is String or not (pending.get("seed") is int or pending.get("seed") is float): return false
			if String(pending.get("token",""))!="special|%s|%d" % [id,int(entry.seed)] \
				or int(pending.get("seed",0))!=int(entry.seed): return false
			if String(pending.ally.get("role_id","")) not in ["zs","ck","fs","fz"]: return false
			var level: Variant=pending.ally.get("level")
			if not (level is int or level is float) or float(level)<1 or float(level)>60 or float(level)!=floorf(float(level)): return false
			if not pending.ally.get("traits",[]) is Array or not pending.ally.get("growth",{}) is Dictionary: return false
			if String(pending.enemy.get("lead_mon",""))!=String(entry.branches[branch].get("enemy","")): return false
	return true
