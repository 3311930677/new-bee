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
var gold := 0              # 局内累计金币（#10 结算接管）


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


## 人物当前最大生命（词条被动烧入口径与 BattleSim._build_role 一致）
func max_hp() -> int:
	var stats := TableCache.role_stats(role_id, level)
	var ts := TraitSystem.new(traits)
	return maxi(1, int(float(stats.max_hp) * (1.0 + ts.passive_maxhp_pct())))


## 战斗胜利后随机获 1 词条（#9 落地三选一 UI 前的过渡）；池尽返回空串
func roll_trait(rng: RandomNumberGenerator) -> String:
	var pool: Array = []
	for t in TableCache.traits():
		var tid := String((t as Dictionary).get("id", ""))
		if not traits.has(tid):
			pool.append(tid)
	if pool.is_empty():
		return ""
	var pick := String(pool[rng.randi_range(0, pool.size() - 1)])
	traits.append(pick)
	return pick


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


## 治疗并夹紧到最大生命（篝火/药剂共用）
func heal(amount: int) -> void:
	var cap := max_hp()
	var cur := cap if hp < 0 else hp
	hp = mini(cap, cur + amount)
