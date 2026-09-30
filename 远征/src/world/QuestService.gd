# QuestService.gd —— 主线任务推进（只从事件推进目标，不改任何全局状态）
#
# 为什么单独一个模块（P02）：
#   以前推进逻辑与奖励发放、写档揉在 G.story_event() 里，判定条件（地图/目标/前置物品/是否已完成）
#   和副作用（扣物、加钱、加经验、写 done[]）在同一段代码里穿插。要测「重复上报只结算一次」
#   或「缺前置物品不能推进」，就得跑整局。
#
# 本模块只做一件事：给一份任务状态 + 一张事件，算出**下一步状态与要发的奖励**（plan），
# 由调用方（G 的适配层）原子落地。纯静态、无 autoload 依赖，可直接在 -s/场景测试里跑。
class_name QuestService

const STATUS_DONE := "done"


## 构造 WorldEvent（契约见 docs/plans/2026-09-28-p02-world-session-design.md §2.1）。
## event_id 是确定性的：同一事实重复上报得到同一 id，用于审计与去重。
static func world_event(type: String, source_id: String, map_id: String,
		actor_id := "player", payload := {}, game_tick := 0) -> Dictionary:
	return {
		"event_id": "%s|%s|%s" % [type, map_id, source_id],
		"type": type,
		"source_id": source_id,
		"map_id": map_id,
		"actor_id": actor_id,
		"payload": payload,
		"game_tick": game_tick,
	}


# ---------- 任务状态 ----------

## 已完成目标集合（v4）。goal 表缺失时用旧 done[] 兜底，保证旧档与新档读法一致。
static func done_ids(state: Dictionary) -> Array:
	var goals: Variant = state.get("goals", {})
	if goals is Dictionary and not (goals as Dictionary).is_empty():
		return (goals as Dictionary).keys()
	var done: Variant = state.get("done", [])
	return (done as Array).duplicate() if done is Array else []


static func is_done(state: Dictionary, step_id: String) -> bool:
	return step_id in done_ids(state)


## 旧档兼容：把 done[] 映射成 goals（新目标状态），并让 done[] 与 goals 同步。
## 幂等：对已是 v4 形状的状态再跑不改动内容。
static func normalize_state(state: Dictionary) -> Dictionary:
	# 不带缺省值地取：缺键时若拿临时容器，写入会落进临时对象里丢掉
	var goals: Variant = state.get("goals")
	if not (goals is Dictionary):
		goals = {}
		state["goals"] = goals
	var done: Variant = state.get("done")
	if not (done is Array):
		done = []
		state["done"] = done
	var gd := goals as Dictionary
	var dn := done as Array
	for id in dn:
		gd[String(id)] = STATUS_DONE
	for id2 in gd.keys():
		if not dn.has(id2):
			dn.append(id2)
	return state


static func step_by_id(rows: Array, step_id: String) -> Dictionary:
	for row_v in rows:
		if row_v is Dictionary and String((row_v as Dictionary).get("id", "")) == step_id:
			return (row_v as Dictionary)
	return {}


static func current_step(state: Dictionary, rows: Array) -> Dictionary:
	return step_by_id(rows, String(state.get("step", "")))


# ---------- 事件 → 计划 ----------

## 纯函数：不改 state，返回 { ok, reason, step_id, step, next_state, consume_item, reward, event_id }。
## reason ∈ no_step / no_match / duplicate / missing_item / ok。
static func plan(state: Dictionary, rows: Array, event: Dictionary, inventory: Dictionary) -> Dictionary:
	var out := {
		"ok": false, "reason": "", "step_id": "", "step": {}, "next_state": {},
		"consume_item": "", "extra_costs": {}, "choice": "",
		"reward": {}, "event_id": String(event.get("event_id", "")),
	}
	var row := current_step(state, rows)
	if row.is_empty():
		out["reason"] = "no_step"
		return out
	var step_id := String(row.get("id", ""))
	out["step_id"] = step_id
	out["step"] = row
	if is_done(state, step_id):
		out["reason"] = "duplicate"
		return out
	if String(row.get("event", "")) != String(event.get("type", "")):
		out["reason"] = "no_match"
		return out
	var need_map := String(row.get("map", ""))
	if not need_map.is_empty() and need_map != String(event.get("map_id", "")):
		out["reason"] = "no_match"
		return out
	var need_target := String(row.get("target", ""))
	if need_target != "*" and need_target != String(event.get("source_id", "")):
		out["reason"] = "no_match"
		return out
	var required_item := String(row.get("requires_item", ""))
	if not required_item.is_empty() and int(inventory.get(required_item, 0)) < 1:
		out["reason"] = "missing_item"
		return out
	var craft_options: Variant = row.get("craft_options", {})
	var payload: Variant = event.get("payload", {})
	var method := String((payload as Dictionary).get("method", "")) if payload is Dictionary else ""
	# 同一 NPC 可能跨章节发任务；旧选择重报不能被普通交谈步骤接收。
	if not method.is_empty() and (not (craft_options is Dictionary) or (craft_options as Dictionary).is_empty()):
		out["reason"] = "invalid_choice"
		return out
	if craft_options is Dictionary and not (craft_options as Dictionary).is_empty():
		var option: Variant = (craft_options as Dictionary).get(method, {})
		if not (option is Dictionary) or (option as Dictionary).is_empty():
			out["reason"] = "invalid_choice"
			return out
		var option_costs: Variant = (option as Dictionary).get("costs", {})
		if not (option_costs is Dictionary):
			out["reason"] = "invalid_choice"
			return out
		for key in (option_costs as Dictionary):
			if String(key).begins_with("item:") and int(inventory.get(String(key).substr(5), 0)) < int(option_costs[key]):
				out["reason"] = "missing_item"
				return out
		out["extra_costs"] = (option_costs as Dictionary).duplicate(true)
		out["choice"] = method
	var next := normalize_state((state as Dictionary).duplicate(true))
	(next["goals"] as Dictionary)[step_id] = STATUS_DONE
	if not (next["done"] as Array).has(step_id):
		(next["done"] as Array).append(step_id)
	next["step"] = String(row.get("next", ""))
	if not String(out["choice"]).is_empty():
		var choices: Variant = next.get("choices")
		if not (choices is Dictionary):
			choices = {}
			next["choices"] = choices
		(choices as Dictionary)[step_id] = String(out["choice"])
	var reward: Variant = row.get("reward", {})
	out["ok"] = true
	out["reason"] = "ok"
	out["next_state"] = next
	out["consume_item"] = required_item
	out["reward"] = reward if reward is Dictionary else {}
	return out


# ---------- 第一幕支线（P05-B）：并行小状态机 ----------
#
# 与主线的区别：主线是「当前步骤」一条线；支线可并行接取，同一时间只追踪其中一条，
# 其余已接任务保留进度。状态存在 prog.act1.side_quests：
#   { "<qid>": {"status": "active"|"ready"|"done", "progress": n, "seen": [实体ID]} }
# 本模块只改这份状态（act1 由调用方持有），不碰钱包／物品／存档。
# 规则：目标发生在接取前不计数；ready 后不再计数；collect/observe 按实体 ID 去重。

const SIDE_ACTIVE := "active"
const SIDE_READY := "ready"
const SIDE_DONE := "done"


static func side_row(rows: Array, qid: String) -> Dictionary:
	for row_v in rows:
		if row_v is Dictionary and String((row_v as Dictionary).get("id", "")) == qid:
			return (row_v as Dictionary)
	return {}


static func side_get(act1: Dictionary, qid: String) -> Dictionary:
	var all: Variant = act1.get("side_quests")
	if not (all is Dictionary):
		return {}
	var row: Variant = (all as Dictionary).get(qid)
	return (row as Dictionary) if row is Dictionary else {}


static func side_status(act1: Dictionary, qid: String) -> String:
	return String(side_get(act1, qid).get("status", ""))


static func side_need(row: Dictionary) -> int:
	var obj: Variant = row.get("objective", {})
	return maxi(1, int((obj as Dictionary).get("count", 1))) if obj is Dictionary else 1


## 接取支线。任务不存在或已接过一律失败；当前没有追踪中的支线时自动追踪本条。
static func side_accept(act1: Dictionary, rows: Array, qid: String) -> Dictionary:
	var row := side_row(rows, qid)
	if row.is_empty():
		return {"ok": false, "reason": "unknown"}
	if side_status(act1, qid) != "":
		return {"ok": false, "reason": "duplicate"}
	var all: Variant = act1.get("side_quests")
	if not (all is Dictionary):
		all = {}
		act1["side_quests"] = all
	(all as Dictionary)[qid] = {"status": SIDE_ACTIVE, "progress": 0, "seen": []}
	if String(act1.get("tracked", "")).is_empty():
		act1["tracked"] = qid
	return {"ok": true, "reason": "ok"}


## 切换追踪（只能追踪已接且未完成的任务）。同一时间只追踪一条。
static func side_track(act1: Dictionary, qid: String) -> bool:
	var st := side_status(act1, qid)
	if st == "" or st == SIDE_DONE:
		return false
	act1["tracked"] = qid
	return true


## 事件推进（只推进已接且 active 的支线）。返回发生变化（进度增长或转 ready）的 qid 列表。
## deliver 目标需要身上有 objective.item；inventory 传 G.items 同形状字典。
static func side_report(act1: Dictionary, rows: Array, event: Dictionary,
		inventory: Dictionary) -> Array:
	var touched: Array = []
	var all: Variant = act1.get("side_quests")
	if not (all is Dictionary):
		return touched
	for row_v in rows:
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		var qid := String(row.get("id", ""))
		var state: Variant = (all as Dictionary).get(qid)
		if not (state is Dictionary):
			continue
		var qs := state as Dictionary
		if String(qs.get("status", "")) != SIDE_ACTIVE:
			continue
		var obj: Variant = row.get("objective", {})
		if not (obj is Dictionary):
			continue
		var o := obj as Dictionary
		if not _side_match(o, event):
			continue
		var need_item := String(o.get("item", ""))
		if not need_item.is_empty() and int(inventory.get(need_item, 0)) < 1:
			continue
		var kind := String(o.get("kind", ""))
		if kind == "collect" or kind == "observe":
			var seen: Variant = qs.get("seen")
			if not (seen is Array):
				seen = []
				qs["seen"] = seen
			var sid := String(event.get("source_id", ""))
			if (seen as Array).has(sid):
				continue
			(seen as Array).append(sid)
		var need := side_need(row)
		var progress := mini(need, int(qs.get("progress", 0)) + 1)
		qs["progress"] = progress
		if progress >= need:
			qs["status"] = SIDE_READY
		touched.append(qid)
	return touched


static func _side_match(o: Dictionary, event: Dictionary) -> bool:
	var kind := String(o.get("kind", ""))
	var etype := String(event.get("type", ""))
	var need_map := String(o.get("map", ""))
	if not need_map.is_empty() and need_map != String(event.get("map_id", "")):
		return false
	match kind:
		"defeat":
			return etype == "defeat"
		"collect":
			return etype == "collect" and _side_entity_match(o, event)
		"observe":
			return etype == "observe" and _side_entity_match(o, event)
		"deliver":
			return etype == "deliver" and _side_entity_match(o, event)
		"boss":
			return (etype == "defeat" or etype == "observe") \
				and String(event.get("source_id", "")) == String(o.get("target", ""))
	return false


## 实体匹配：target_entity（单个）或 target_entities（列表）声明允许的实体 ID；
## 两者都不写时按「本图同类实体皆可」（如两丛草根用列表显式声明，避免与风铃互串）。
static func _side_entity_match(o: Dictionary, event: Dictionary) -> bool:
	var sid := String(event.get("source_id", ""))
	var one := String(o.get("target_entity", ""))
	if not one.is_empty():
		return one == sid
	var many: Variant = o.get("target_entities", [])
	if many is Array and not (many as Array).is_empty():
		return (many as Array).has(sid)
	return true


## 交付领取：只有 ready 才成功。奖励与消耗由调用方走 RewardLedger 落地；
## 同一任务重复交付返回 duplicate（账本还会按 tx=side|<id>|complete 再挡一层）。
static func side_turn_in(act1: Dictionary, rows: Array, qid: String) -> Dictionary:
	var row := side_row(rows, qid)
	if row.is_empty():
		return {"ok": false, "reason": "unknown"}
	var qs := side_get(act1, qid)
	if qs.is_empty():
		return {"ok": false, "reason": "unknown"}
	var st := String(qs.get("status", ""))
	if st == SIDE_DONE:
		return {"ok": false, "reason": "duplicate"}
	if st != SIDE_READY:
		return {"ok": false, "reason": "not_ready"}
	qs["status"] = SIDE_DONE
	if String(act1.get("tracked", "")) == qid:
		act1["tracked"] = ""
	var reward: Variant = row.get("reward", {})
	return {"ok": true, "reason": "ok",
		"reward": reward if reward is Dictionary else {},
		"consume_item": String(row.get("turn_in_item", "")),
		"discovery": String(row.get("discovery", ""))}


## 任务日志信息（纯数据，交给 UI 组文案）：
## {status, progress, need, objective_text, turn_in, turn_in_map, title, category}
static func side_progress_info(act1: Dictionary, rows: Array, qid: String) -> Dictionary:
	var row := side_row(rows, qid)
	var qs := side_get(act1, qid)
	if row.is_empty() or qs.is_empty():
		return {}
	return {
		"status": String(qs.get("status", "")),
		"progress": int(qs.get("progress", 0)),
		"need": side_need(row),
		"objective_text": String(row.get("objective_text", "")),
		"turn_in": String(row.get("turn_in", "")),
		"turn_in_map": String(row.get("turn_in_map", "")),
		"title": String(row.get("title", "")),
		"category": String(row.get("category", "")),
	}


## 本处可做的支线交互：ready 且交付人是本处 → turn_in（先交后接）；
## 否则 giver 是本处且未接过 → accept。返回 {kind:"turn_in"/"accept", qid} 或 {}。
static func side_npc_action(act1: Dictionary, rows: Array, npc_id: String) -> Dictionary:
	for row_v in rows:
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		var qid := String(row.get("id", ""))
		if side_status(act1, qid) == SIDE_READY and String(row.get("turn_in", "")) == npc_id:
			return {"kind": "turn_in", "qid": qid}
	for row_v2 in rows:
		if not (row_v2 is Dictionary):
			continue
		var row2 := row_v2 as Dictionary
		var qid2 := String(row2.get("id", ""))
		if String(row2.get("giver", "")) == npc_id and side_status(act1, qid2) == "":
			return {"kind": "accept", "qid": qid2}
	return {}
