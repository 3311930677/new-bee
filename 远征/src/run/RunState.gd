# RunState.gd —— 一局远征的跨节点状态（玩法文档 §2.6）
# 延续规则：HP 跨节点延续（不回满）/ 能量清空 / buff 全清 / 词条保留整局。
# 能量与 buff 随每场战斗重建自然清空，故本类只需跟踪 HP 与词条。
class_name RunState
extends RefCounted

var theme := "forest"
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


## 取某节点的探索进度（不存在则建空档）
func map_progress(layer: int, index: int) -> Dictionary:
	var k := "%d_%d" % [layer, index]
	if not map_state.has(k):
		map_state[k] = {"killed": [], "taken": [], "spots": [], "score": 0,
			"cleared_bonus": false, "boss_down": false, "interact_done": false}
	return map_state[k]


## 按 nodes.json rewards 累加节点奖励（normal/elite/boss/chest；战利与拾取同口径）
func add_reward(kind: String) -> void:
	var row: Dictionary = TableCache.nodes_config().get("rewards", {}).get(kind, {})
	gold += int(row.get("gold", 0))
	expedition += int(row.get("expedition", 0))
	soul += int(row.get("soul", 0))
	exp += int(row.get("exp", 0))
	honor += int(row.get("honor", 0))


func setup(cfg: Dictionary) -> void:
	theme = String(cfg.get("theme", "forest"))
	role_id = String(cfg.get("role_id", "zs"))
	level = int(cfg.get("level", 5))
	active_pet = String(cfg.get("active_pet", ""))
	bench_pet = String(cfg.get("bench_pet", ""))
	potions = int(cfg.get("potions", 0))
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
## 过滤已获词条；槽池尽回退到剩余池，全池尽返回空数组
func roll_trait_choices(rng: RandomNumberGenerator) -> Array:
	var remain: Array = []
	for t in TableCache.traits():
		if not traits.has(String((t as Dictionary).get("id", ""))):
			remain.append(t)
	if remain.is_empty():
		return []
	var choices: Array = []
	var slot_pools: Array = [
		_pool_by_type(remain, ["num", "mech"]),
		_pool_by_type(remain, ["link" if rng.randf() < 0.85 else "double"]),
		remain,
	]
	for pool in slot_pools:
		if pool.is_empty() or choices.size() >= 3:
			continue
		var row: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		if not choices.has(row):
			choices.append(row)
	for t in remain:  # 槽池空/重复时从剩余池补足
		if choices.size() >= 3:
			break
		if not choices.has(t):
			choices.append(t)
	return choices


func _pool_by_type(remain: Array, types: Array) -> Array:
	var pool: Array = []
	for t in remain:
		if types.has(String((t as Dictionary).get("type", ""))):
			pool.append(t)
	return pool


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
