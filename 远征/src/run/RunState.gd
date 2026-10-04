# RunState.gd —— 一局远征的跨节点状态（玩法文档 §2.6）
# 延续规则：HP 跨节点延续（不回满）/ 能量清空 / buff 全清 / 词条保留整局。
# 能量与 buff 随每场战斗重建自然清空，故本类只需跟踪 HP 与词条。
class_name RunState
extends RefCounted

var theme := "forest"
var run_id := ""

const SAVE_FIELDS := ["run_id", "theme", "role_id", "level", "active_pet", "bench_pet", "potions", "traits", "hp",
	"route", "run_seed", "node_seq", "finished", "result", "gold", "expedition", "soul", "exp", "honor",
	"map_state", "growth_bonus", "ascetic"]

func snapshot() -> Dictionary:
	var out := {"version": 1}
	for field in SAVE_FIELDS:
		var value: Variant = get(field)
		out[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	return out

func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1 or String(data.get("run_id", "")).is_empty(): return false
	if not (data.get("route") is Dictionary) or not (data.route.get("layers") is Array): return false
	if (data.route.layers as Array).size() != 3: return false
	for field in SAVE_FIELDS:
		if not data.has(field): return false
		var expected := typeof(get(field))
		var actual := typeof(data[field])
		if expected == TYPE_INT:
			if actual not in [TYPE_INT, TYPE_FLOAT] or not is_equal_approx(float(data[field]), roundf(float(data[field]))): return false
		elif expected != actual: return false
	for field in SAVE_FIELDS:
		var value: Variant = data[field]
		set(field, value.duplicate(true) if value is Dictionary or value is Array else value)
	return true
var role_id := "zs"
var level := 5
var active_pet := "pet_rockturtle"
var bench_pet := ""
var potions := 2
var traits: Array = []     # 已获词条 id（保留整局）
var hp := -1               # -1 = 首战满血；>0 = 延续值
var route: Dictionary = {}
var run_seed := 0
var node_seq := 0          # 已进入节点计数（推导局内唯一战斗种子）
var finished := false
var result := ""           # "defeat" / "clear"
var gold := 0              # 局内累计金币（#10b 结算入账钱包）
var expedition := 0        # 局内累计远征币（抽奖祭坛货币）
var soul := 0              # 局内累计灵魂石（宠物池货币）
var exp := 0               # 局内累计经验（结算时回写养成等级）
var honor := 0             # 局内累计荣誉（战功，用于高难世界门禁）
## 本局各节点探索进度（会话态，不入存档；键 "layer_index"）：重进同一节点恢复
## 击杀/拾取/兴趣点/探索分，避免「撤离 → 重进」重复结算（P0-1）
var map_state := {}
var growth_bonus := {}     # 局外成长快照（G.growth_bonuses；由 RouteScene 注入，供 max_hp 同口径）
var ascetic := false       # 苦行（轮次 22）：本局敌人更强、收益更高，出征前选定，一旦出发不可改


## 苦行参数（data/nodes.json 的 ascetic 段）
func ascetic_cfg() -> Dictionary:
	var c: Variant = TableCache.nodes_config().get("ascetic", {})
	return c if c is Dictionary else {}


## 本局敌人强度倍率（未开苦行 = 1.0）
func enemy_mult() -> float:
	if not ascetic:
		return 1.0
	return maxf(0.1, float(ascetic_cfg().get("enemy_mult", 1.0)))


## 本局收益倍率（未开苦行 = 1.0）
func reward_mult() -> float:
	if not ascetic:
		return 1.0
	return maxf(0.0, float(ascetic_cfg().get("reward_mult", 1.0)))


## 取某节点的探索进度（不存在则建空档）
func map_progress(layer: int, index: int) -> Dictionary:
	var k := "%d_%d" % [layer, index]
	if not map_state.has(k):
		map_state[k] = {"killed": [], "taken": [], "spots": [], "score": 0,
			"cleared_bonus": false, "boss_down": false, "interact_done": false}
	return map_state[k]


## 按 nodes.json rewards 累加节点奖励（normal/elite/boss/chest；战利与拾取同口径）。
## 苦行局在这里统一乘收益倍率：这是本局收益的唯一入口，不会漏掉某类节点。
func add_reward(kind: String) -> void:
	var row: Dictionary = TableCache.nodes_config().get("rewards", {}).get(kind, {})
	var mult := reward_mult()
	gold += roundi(float(row.get("gold", 0)) * mult)
	expedition += roundi(float(row.get("expedition", 0)) * mult)
	soul += roundi(float(row.get("soul", 0)) * mult)
	exp += roundi(float(row.get("exp", 0)) * mult)
	honor += roundi(float(row.get("honor", 0)) * mult)


func setup(cfg: Dictionary) -> void:
	theme = String(cfg.get("theme", "forest"))
	role_id = String(cfg.get("role_id", "zs"))
	level = int(cfg.get("level", 5))
	active_pet = String(cfg.get("active_pet", ""))
	bench_pet = String(cfg.get("bench_pet", ""))
	potions = int(cfg.get("potions", 0))
	ascetic = bool(cfg.get("ascetic", false))
	run_seed = int(cfg.get("seed", 0))
	if run_seed == 0:
		run_seed = randi()
	route = RouteGenerator.generate(run_seed)


## 当前推进到的层（1~3；每层 3 选 1 走完即进下一层，3 层全走后为 4 = BOSS 层）
func current_layer() -> int:
	var layers: Array = route.get("layers", [])
	for l in layers.size():
		var row: Array = layers[l]
		var any_cleared := false
		for n in row:
			if bool((n as Dictionary).get("cleared", false)):
				any_cleared = true
				break
		if not any_cleared:
			return l + 1
	return layers.size() + 1


## 节点是否可进入（仅当前层的节点；层 4 = BOSS）
func node_reachable(layer: int) -> bool:
	return layer == current_layer()


## 进入节点的战斗种子（局内唯一且可复现）
func next_battle_seed() -> int:
	node_seq += 1
	return run_seed * 1000 + node_seq * 7 + 13


## 人物当前最大生命（唯一口径，含局外成长；与 BattleSim._build_role 完全一致，P1-6）
func max_hp() -> int:
	return TraitSystem.role_max_hp(role_id, level, traits, growth_bonus)


## 战斗胜利三选一候选（玩法文档 §2.4）：槽1=num/mech，槽2=link(85%)/double(15%)，槽3=全池；
## 过滤已获词条；槽池尽回退到剩余池，全池尽返回空数组。
## 槽位规则与流派偏置全部读 nodes.json 的 run.trait_slots / run.school_bias_min（B2）：
## 一局只有 3~4 次选择，随机池几乎凑不出流派，玩家根本摸不到构筑系统。
func roll_trait_choices(rng: RandomNumberGenerator) -> Array:
	var remain: Array = []
	for t in TableCache.traits():
		if not traits.has(String((t as Dictionary).get("id", ""))):
			remain.append(t)
	if remain.is_empty():
		return []
	var slot := _trait_slot_cfg()
	var bias := _school_bias()
	var pool2 := _pool_by_type(remain, _types(slot.get("slot2_types", ["link"])))
	if rng.randf() < float(slot.get("slot2_alt_chance", 0.15)):
		pool2 = _pool_by_type(remain, _types(slot.get("slot2_alt_types", ["double"])))
	var pool3: Array = remain.duplicate()
	if bias != "":
		# 偏置只在**槽内**挑本系：槽位类型（数值/机制/流派/双刃）的结构不变，
		# 但同系候选优先出现，玩家才看得见「再拿一条就成型」
		pool2 = _prefer_school(pool2, bias)
		pool3 = _prefer_school(pool3, bias)
	var choices: Array = []
	var slot_pools: Array = [
		_pool_by_type(remain, _types(slot.get("slot1_types", ["num", "mech"]))),
		pool2,
		pool3,
	]
	for pool in slot_pools:
		if (pool as Array).is_empty() or choices.size() >= 3:
			continue
		var row: Dictionary = (pool as Array)[rng.randi_range(0, (pool as Array).size() - 1)]
		if not choices.has(row):
			choices.append(row)
	for t in remain:  # 槽池空/重复时从剩余池补足
		if choices.size() >= 3:
			break
		if not choices.has(t):
			choices.append(t)
	return choices


## 槽位配置（nodes.json run.trait_slots）
func _trait_slot_cfg() -> Dictionary:
	var run_v: Variant = TableCache.nodes_config().get("run", {})
	if not (run_v is Dictionary):
		return {}
	var s: Variant = (run_v as Dictionary).get("trait_slots", {})
	return s if s is Dictionary else {}


func _types(v: Variant) -> Array:
	return v if v is Array else []


## 目标流派：已获同系达到 school_bias_min（缺省 = 激活阈值-1，即「差一件就成型」）时偏置。
## 返回 "" = 不偏置。
func _school_bias() -> String:
	var ts := TraitSystem.new(traits)
	var run_v: Variant = TableCache.nodes_config().get("run", {})
	var min_n := maxi(1, TraitSystem.school_active_n() - 1)
	if run_v is Dictionary:
		min_n = maxi(1, int((run_v as Dictionary).get("school_bias_min", min_n)))
	for s in TraitSystem.SCHOOLS:
		if int(ts.school_count.get(s, 0)) >= min_n:
			return String(s)
	return ""


func _pool_by_type(remain: Array, types: Array) -> Array:
	var pool: Array = []
	for t in remain:
		if types.has(String((t as Dictionary).get("type", ""))):
			pool.append(t)
	return pool


func _pool_by_school(pool: Array, school: String) -> Array:
	var out: Array = []
	for t in pool:
		if String((t as Dictionary).get("school", "none")) == school:
			out.append(t)
	return out


## 优先本系；本系在该槽里已无可出则原样返回（不强行凑）
func _prefer_school(pool: Array, school: String) -> Array:
	var sub := _pool_by_school(pool, school)
	return sub if not sub.is_empty() else pool


## 篝火治疗量（40% 最大生命，nodes.json bonfire.heal_pct）
func bonfire_heal() -> int:
	var cfg := TableCache.nodes_config()
	return int(float(max_hp()) * float(cfg.get("bonfire", {}).get("heal_pct", 0.4)))


## 标记节点完成（layer 4 = BOSS）
func node_cleared(layer: int, index: int) -> void:
	var layers: Array = route.get("layers", [])
	if layer > layers.size():
		var boss: Dictionary = route.get("boss", {})
		boss["cleared"] = true
		return
	var nd: Dictionary = layers[layer - 1][index]
	nd["cleared"] = true


## 战斗结束跨节点写回：药剂余量 / 换宠后出战位（替补转正，旧宠整局离场）
func apply_battle_result(sim: BattleSim) -> void:
	potions = sim.potions_left
	if sim.pet_swap_used:
		active_pet = String(sim.pet_bench_id)
		bench_pet = ""


## 治疗并夹紧到最大生命（篝火/药剂共用）
func heal(amount: int) -> void:
	var cap := max_hp()
	var cur := cap if hp < 0 else hp
	hp = mini(cap, cur + amount)
