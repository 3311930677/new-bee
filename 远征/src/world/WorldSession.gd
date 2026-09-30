# WorldSession.gd —— 主世界会话状态（刷点、遭遇锁、首领首胜、刷新计时、安全位）
#
# 为什么单独一个模块（P02）：
#   以前这些状态散在 MapScene.gd 里，用「"0" / "1" 这样的下标字符串」当刷点键，
#   跨地图共用一个 respawn_at，且没有「这场战斗结算过没有」的记录。
#   崩在战斗中途/结算途中，重载后只能靠玩家自己发现异常。
#
# 本模块是**纯静态、无 autoload 依赖**的状态读写器：状态就是存档里
# prog.main_world 那个字典，调用方（MapScene / G）负责把它落盘。
# 单独一个模块的好处是能对「同一份状态」直接跑中断矩阵测试，不用起整张地图。
class_name WorldSession

## 遭遇状态（EncounterContext.status 的取值）
## P03 起是一条显式状态机：approach → locked → battle → result_pending → committed → return
## （撤退/战败从 result_pending 分支出去，见 ALLOWED）。
const ST_APPROACH := "approach"       # 已经接触（遭遇已建，尚未锁定战斗）
const ST_LOCKED := "locked"           # 已接触、尚未确认进战斗
const ST_BATTLE := "battle"           # 战斗中（战斗层已建）
const ST_RESULT_PENDING := "result_pending"  # 战斗已结束、结算尚未落地
const ST_COMMITTED := "committed"     # 已结算（唯一会发战利的状态）
const ST_FLED := "fled"               # 已撤退
const ST_FAILED := "failed"           # 战败
const ST_RETURN := "return"           # 已回到地图（位置与怪物状态已落盘）

## 合法转移表。键是 from，值是允许到达的 to 列表。
## "" 表示这场遭遇还没有任何记录（首次 advance 只能是 approach）。
const ALLOWED := {
	"": [ST_APPROACH],
	ST_APPROACH: [ST_LOCKED, ST_FLED],
	ST_LOCKED: [ST_BATTLE, ST_FLED],
	ST_BATTLE: [ST_RESULT_PENDING, ST_FAILED],
	ST_RESULT_PENDING: [ST_COMMITTED, ST_FLED, ST_FAILED],
	ST_COMMITTED: [ST_RETURN],
	ST_FLED: [ST_RETURN],
	ST_FAILED: [],
}

## 安全位判定半径（px）：读档落在怪物这个范围内就认为会被立刻拖进战斗
const DANGER_RADIUS := 96.0
## 实体永久取走标记（P05-B）：值为 "once" 表示不再恢复；值为日期键表示当天已取、次日恢复。
const ENTITY_ONCE := "once"
## 传送阵避让半径（px）与避让后的朝向偏移
const PORTAL_RADIUS := 80.0
const PORTAL_OFFSET := Vector2(0, 110)
## 地图边界内的最小留白
const EDGE_MARGIN := 48.0


# ---------- 唯一刷点 ----------

## 全局唯一刷点 ID。跨地图不会撞：老实现用 str(idx)，边城 0 号与古道 0 号是同一个键。
static func spawn_id(map_id: String, idx: int) -> String:
	return "%s:%d" % [map_id, idx]


## 遭遇 ID：一次接战一个，写进 encounters 表用于重放去重。
static func encounter_id(map_id: String, spawn: String, game_tick: int) -> String:
	return "%s#%s#%d" % [map_id, spawn, game_tick]


# ---------- 遭遇（EncounterContext） ----------

## 构造 EncounterContext。位置与返回位都写成 [x, y] 数组，和存档里其它坐标一致。
static func new_encounter(map_id: String, idx: int, position: Vector2, enemy_id: String,
		enemy_level: int, return_position: Vector2, story_source: String, rng_seed: int,
		game_tick: int) -> Dictionary:
	var spawn := spawn_id(map_id, idx)
	return {
		"encounter_id": encounter_id(map_id, spawn, game_tick),
		"spawn_id": spawn,
		"map_id": map_id,
		"position": [roundi(position.x), roundi(position.y)],
		"enemy_id": enemy_id,
		"enemy_level": enemy_level,
		"return_position": [roundi(return_position.x), roundi(return_position.y)],
		"story_source": story_source,
		"rng_seed": rng_seed,
		"status": ST_LOCKED,
	}


static func encounters(state: Dictionary) -> Dictionary:
	# 用 .get("encounters")（不带缺省值）：缺键时若拿临时 {}，后面写进遭遇表的记录会丢
	var enc: Variant = state.get("encounters")
	if not (enc is Dictionary):
		enc = {}
		state["encounters"] = enc
	return enc


static func status_of(state: Dictionary, eid: String) -> String:
	var row: Variant = encounters(state).get(eid, {})
	return String((row as Dictionary).get("status", "")) if row is Dictionary else ""


static func is_settled(state: Dictionary, eid: String) -> bool:
	return status_of(state, eid) == ST_COMMITTED


## 写入/更新遭遇记录。返回是否发生变更（重复写同一状态返回 false）。
static func record(state: Dictionary, ctx: Dictionary, status: String) -> bool:
	var eid := String(ctx.get("encounter_id", ""))
	if eid.is_empty():
		return false
	var enc := encounters(state)
	var prev: Variant = enc.get(eid)
	if prev is Dictionary and String((prev as Dictionary).get("status", "")) == status:
		return false
	# 合并写入（不是整行覆盖）：P03 起这一行还带着 result/result_id，
	# 覆盖会把「这场已经结算过」的事实抹掉，committed → return 之后就无法再解释。
	var row: Dictionary = (prev as Dictionary).duplicate() if prev is Dictionary else {}
	row["status"] = status
	row["spawn_id"] = String(ctx.get("spawn_id", ""))
	row["enemy_id"] = String(ctx.get("enemy_id", ""))
	row["tick"] = int(str(eid).get_slice("#", 2)) if str(eid).contains("#") else 0
	enc[eid] = row
	return true


## 结算一次遭遇。只有从非终态进入 committed 才算「新结算」；重复上报返回 false。
static func commit(state: Dictionary, ctx: Dictionary) -> bool:
	var eid := String(ctx.get("encounter_id", ""))
	if eid.is_empty():
		return false
	var st := status_of(state, eid)
	if is_terminal(st):
		return false
	record(state, ctx, ST_COMMITTED)
	return true


## 终态：到达后这场遭遇不能再被结算（重复上报走这里挡掉）。
static func is_terminal(status: String) -> bool:
	return status == ST_COMMITTED or status == ST_FLED or status == ST_FAILED


## 按转移表推进一步（P03）。非法转移返回 {ok:false, reason:"bad_transition"} 且不落盘。
## 返回 {ok, from, to, reason}；同一状态重复推进返回 reason="same" 且 ok=false（幂等）。
static func advance(state: Dictionary, ctx: Dictionary, to: String) -> Dictionary:
	var eid := String(ctx.get("encounter_id", ""))
	if eid.is_empty():
		return {"ok": false, "from": "", "to": to, "reason": "no_encounter"}
	var from := status_of(state, eid)
	if from == to:
		return {"ok": false, "from": from, "to": to, "reason": "same"}
	var allowed: Variant = ALLOWED.get(from, [])
	if not (allowed is Array) or not (to in (allowed as Array)):
		return {"ok": false, "from": from, "to": to, "reason": "bad_transition"}
	record(state, ctx, to)
	return {"ok": true, "from": from, "to": to, "reason": "ok"}


## 一次战斗结果的确定性 ID。同一次接战 + 同一种结果恒定，用作结算去重键。
static func result_id(ctx: Dictionary, result: String) -> String:
	return "res|%s|%s" % [String(ctx.get("encounter_id", "")), result]


## 该遭遇已记录的结果（"" 表示还没有结果）。
static func result_of(state: Dictionary, eid: String) -> String:
	var row: Variant = encounters(state).get(eid, {})
	if not (row is Dictionary):
		return ""
	return String((row as Dictionary).get("result", ""))


## 结算一次战斗结果（P03 唯一发奖入口）：先按 encounter_id 去重，再记下 result_id。
## 返回 true 表示「这是本场第一次结算」——调用方据此才发奖、才推进主线。
## 重复上报（同结果两次 / 已 committed / 已 fled / 已 failed）一律 false。
static func settle_result(state: Dictionary, ctx: Dictionary, result: String) -> bool:
	var eid := String(ctx.get("encounter_id", ""))
	if eid.is_empty():
		return false
	if not commit(state, ctx):
		return false
	_set_result(state, eid, result)
	return true


static func _set_result(state: Dictionary, eid: String, result: String) -> void:
	var enc := encounters(state)
	var row: Variant = enc.get(eid, {})
	if row is Dictionary:
		(row as Dictionary)["result"] = result
		(row as Dictionary)["result_id"] = result_id({"encounter_id": eid}, result)
		enc[eid] = row


# ---------- 首领首胜 ----------

static func boss_cleared(state: Dictionary, map_id: String) -> bool:
	var arr: Variant = state.get("bosses_cleared", [])
	return arr is Array and map_id in (arr as Array)


## 记首领首胜。返回是否首次（重复记返回 false）。
static func mark_boss_cleared(state: Dictionary, map_id: String) -> bool:
	var arr: Variant = state.get("bosses_cleared")
	if not (arr is Array):
		arr = []
		state["bosses_cleared"] = arr
	if map_id in (arr as Array):
		return false
	(arr as Array).append(map_id)
	return true


# ---------- 刷新计时 ----------

## 某刷点下次刷新时间（0 表示当前应存活）。兼容旧单图 respawn_at（不带地图前缀）。
static func spawn_respawn_at(state: Dictionary, map_id: String, idx: int) -> float:
	var per: Variant = state.get("respawn_by_map", {})
	if per is Dictionary and (per as Dictionary).has(map_id):
		var row: Variant = (per as Dictionary)[map_id]
		if row is Dictionary:
			# 本图已有独立刷新表时不能回退到旧的单图快照：旧表可能属于刚离开的地图。
			return float((row as Dictionary).get(str(idx), 0.0))
	var legacy: Variant = state.get("respawn_at", {})
	if legacy is Dictionary and (legacy as Dictionary).has(str(idx)):
		return float((legacy as Dictionary)[str(idx)])
	return 0.0


static func mark_spawn_defeated(state: Dictionary, map_id: String, idx: int, until_ts: float) -> void:
	var per: Variant = state.get("respawn_by_map")
	if not (per is Dictionary):
		per = {}
		state["respawn_by_map"] = per
	var row: Variant = (per as Dictionary).get(map_id)
	if not (row is Dictionary):
		row = {}
		(per as Dictionary)[map_id] = row
	(row as Dictionary)[str(idx)] = until_ts
	# 本图快照同步一份：VerifyMainWorld 与旧读法都看 respawn_at
	var legacy: Variant = state.get("respawn_at")
	if not (legacy is Dictionary):
		legacy = {}
		state["respawn_at"] = legacy
	(legacy as Dictionary)[str(idx)] = until_ts


# ---------- 地图实体（P05-B：采集／观察／奇遇实体的已取状态） ----------

## 实体已取表（prog.main_world.entities）。不带缺省值取，避免写入落进临时容器。
static func entities(state: Dictionary) -> Dictionary:
	var e: Variant = state.get("entities")
	if not (e is Dictionary):
		e = {}
		state["entities"] = e
	return e


## 实体是否已被取走。today 传 G.today_key()：值 "once" 永久有效，日期值只在当天有效。
static func entity_taken(state: Dictionary, eid: String, today := "") -> bool:
	var v: Variant = entities(state).get(eid)
	var s := String(v) if v != null else ""
	if s.is_empty():
		return false
	if s == ENTITY_ONCE:
		return true
	return not today.is_empty() and s == today


## 标记实体已取。once=true 永久（风铃／足迹），否则只记当天（草根点次日恢复普通采集）。
## 返回是否发生变更（重复标记返回 false）。
static func mark_entity_taken(state: Dictionary, eid: String, once: bool, today := "") -> bool:
	var val := ENTITY_ONCE if once else today
	if val.is_empty():
		return false
	var e := entities(state)
	if String(e.get(eid, "")) == val:
		return false
	e[eid] = val
	return true


# ---------- 安全位 ----------

## 读档位置纠偏：不落在传送阵上、不落在任一怪物旁、不越界。
## dangers 传当前**存活**怪物坐标；返回的坐标是确定性的（同样的输入得到同样的输出）。
static func safe_position(saved: Vector2, dangers: Array, portal: Vector2,
		extent: Vector2) -> Vector2:
	var pos := saved
	var lo := Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var hi := Vector2(maxf(EDGE_MARGIN, extent.x - EDGE_MARGIN),
		maxf(EDGE_MARGIN, extent.y - EDGE_MARGIN))
	for d in dangers:
		if not (d is Vector2):
			continue
		if pos.distance_to(d as Vector2) >= DANGER_RADIUS:
			continue
		var away := pos - (d as Vector2)
		if away.length() < 0.001:
			away = Vector2(0, 1)
		pos = (d as Vector2) + away.normalized() * DANGER_RADIUS
	if portal != Vector2.ZERO and pos.distance_to(portal) < PORTAL_RADIUS:
		pos = portal + PORTAL_OFFSET
	return pos.clamp(lo, hi)


# ---------- 状态归一化 ----------

## 保证 v4 形状存在（幂等）。MapScene 落盘前调用，避免因某张图缺键而丢结构。
static func normalize_state(state: Dictionary) -> Dictionary:
	if not (state.get("bosses_cleared") is Array):
		state["bosses_cleared"] = []
	if not (state.get("respawn_by_map") is Dictionary):
		state["respawn_by_map"] = {}
	if not (state.get("encounters") is Dictionary):
		state["encounters"] = {}
	if not (state.get("respawn_at") is Dictionary):
		state["respawn_at"] = {}
	if not (state.get("entities") is Dictionary):
		state["entities"] = {}
	return state
