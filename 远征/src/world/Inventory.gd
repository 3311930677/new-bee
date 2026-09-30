# Inventory.gd —— 装备实例、背包、待领取箱、卖出与宝石合成（P04）
#
# 为什么单独一个模块：
#   P03 之前"装备"就是 6 个固定槽上的等级（prog.equip[slot] = {lv, gems, affixes}），
#   没有实例、没有背包、没有待领取箱：掉落的装备无处可放，重复点击会重复扣费，
#   "满包"这个状态根本不存在。这里把装备做成**可掉落、可比较、可换装、可流通的实例**。
#
# 容器模型（见 docs/plans/2026-09-28-p04-equipment-inventory-design.md §1.2）：
#   instances[]  拥有池：背包里的 + 正穿在身上的实例都在这（穿在身上的由 equip_map 指向）
#   pending[]    待领取箱：背包满时掉落先进这里，绝不丢物
#   next_uid     全局单调递增、永不重用的实例号
#   equip_map    槽 → 实例 uid（0/缺省 = 未装备）
#   背包已用格 = instances 里**未被 equip_map 指向**的条数（装备不占背包格）
#
# 纯静态、不引用任何 autoload：状态以 inv/equip_map 传参，模板以 tpl 传参，
# 可直接用假容器跑边界矩阵（满包 / 缺钱 / 重复点击）。G.gd 提供同名薄封装。
class_name Inventory

const DEFAULT_CAPACITY := 60


## 补齐 instances / pending / next_uid；幂等。Dictionary 是引用类型，就地改写并返回同一个对象。
static func ensure(inv: Dictionary) -> Dictionary:
	if not (inv.get("instances") is Array):
		inv["instances"] = []
	if not (inv.get("pending") is Array):
		inv["pending"] = []
	var n: Variant = inv.get("next_uid")
	if not (n is int or n is float):
		inv["next_uid"] = 1
	else:
		inv["next_uid"] = maxi(1, int(n))
	return inv


static func capacity(cfg: Dictionary) -> int:
	var bag: Variant = cfg.get("bag")
	var cap := int((bag as Dictionary).get("capacity", DEFAULT_CAPACITY)) if bag is Dictionary else DEFAULT_CAPACITY
	return maxi(1, cap)


## 正被穿在身上的实例 uid 集合
static func worn_uids(equip_map: Dictionary) -> Dictionary:
	var s := {}
	for k in equip_map:
		var u := int(equip_map[k])
		if u > 0:
			s[u] = true
	return s


## 背包已用格（装备不占格 —— 这是"装备不是背包"的落地口径）
static func count(inv: Dictionary, equip_map: Dictionary) -> int:
	ensure(inv)
	var worn := worn_uids(equip_map)
	var n := 0
	for it in (inv["instances"] as Array):
		var d := it as Dictionary
		if not worn.has(int(d.get("uid", 0))):
			n += 1
	return n


static func find_by_uid(list: Array, uid: int) -> Dictionary:
	for it in list:
		var d := it as Dictionary
		if int(d.get("uid", 0)) == uid:
			return d
	return {}


## 构造一个实例（分配 uid）。**不落盘**、也不入包 —— 由 add/调用方决定去处。
static func new_instance(inv: Dictionary, tpl: Dictionary, rarity := 0) -> Dictionary:
	ensure(inv)
	var uid := int(inv["next_uid"])
	inv["next_uid"] = uid + 1
	var r := rarity if rarity > 0 else int(tpl.get("rarity", 1))
	return {
		"uid": uid,
		"tpl": String(tpl.get("id", "")),
		"slot": String(tpl.get("slot", "")),
		"rarity": maxi(1, r),
		"lv": 0,
		"sockets": maxi(0, int(tpl.get("sockets", 3))),
		"gems": [],
		"affixes": [],
		"locked": false,
	}


## 入包；满包则进待领取箱（**不丢物**），返回 {ok, to_pending}。
static func add(inv: Dictionary, cfg: Dictionary, equip_map: Dictionary, inst: Dictionary) -> Dictionary:
	ensure(inv)
	if count(inv, equip_map) >= capacity(cfg):
		(inv["pending"] as Array).append(inst)
		return {"ok": true, "to_pending": true}
	(inv["instances"] as Array).append(inst)
	return {"ok": true, "to_pending": false}


## 待领取箱 → 背包。背包满则拒绝并**保留在待领取箱**。
static func claim(inv: Dictionary, cfg: Dictionary, equip_map: Dictionary, uid: int) -> Dictionary:
	ensure(inv)
	var pend: Array = inv["pending"]
	var idx := -1
	for i in pend.size():
		if int((pend[i] as Dictionary).get("uid", 0)) == uid:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "err": "找不到这件装备"}
	if count(inv, equip_map) >= capacity(cfg):
		return {"ok": false, "err": "背包已满"}
	var inst := pend[idx] as Dictionary
	pend.remove_at(idx)
	(inv["instances"] as Array).append(inst)
	return {"ok": true}


## 回滚：把刚领取（已在 instances 里）的实例放回待领取箱（R-04 领取写盘失败的兜底）。
## 界面不能在写盘失败时还说"已领取"，内存也必须回到领取前的状态 ——
## 否则重开游戏会发现装备不见了（盘上还是旧的）。
static func return_to_pending(inv: Dictionary, uid: int) -> Dictionary:
	ensure(inv)
	var arr: Array = inv["instances"]
	var idx := -1
	for i in arr.size():
		if int((arr[i] as Dictionary).get("uid", 0)) == uid:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "err": "找不到这件装备"}
	var inst := arr[idx] as Dictionary
	arr.remove_at(idx)
	(inv["pending"] as Array).append(inst)
	return {"ok": true}


## 换装：同槽旧实例自动回到背包（它本就在拥有池里，只是不再被 equip_map 指向）。
## 因为"先卸指针再换指针"不增加背包占用，换装永不因满包失败 —— 也就永远不会出现
## "换下来的没处放"而丢物。已在身上再点一次返回 {ok:false, err:"已装备"}（幂等）。
static func equip(inv: Dictionary, equip_map: Dictionary, uid: int) -> Dictionary:
	ensure(inv)
	var arr: Array = inv["instances"]
	var idx := -1
	for i in arr.size():
		if int((arr[i] as Dictionary).get("uid", 0)) == uid:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "err": "找不到这件装备"}
	var inst := arr[idx] as Dictionary
	var slot := String(inst.get("slot", ""))
	if slot.is_empty():
		return {"ok": false, "err": "这件装备没有可穿戴的槽位"}
	var old := int(equip_map.get(slot, 0))
	if old == uid:
		return {"ok": false, "err": "已装备"}
	# 拥有池不动：实例始终留在 instances 里，只改 equip_map 指向 —— 换下来的旧件
	# 因此自动回到背包，占用不增加，换装永不因满包失败。
	equip_map[slot] = uid
	return {"ok": true, "slot": slot, "replaced": old}


## 卸下 → 回背包；背包满则拒绝（不允许卸下来没处放）。
static func unequip(inv: Dictionary, cfg: Dictionary, equip_map: Dictionary, slot: String) -> Dictionary:
	ensure(inv)
	var uid := int(equip_map.get(slot, 0))
	if uid <= 0:
		return {"ok": false, "err": "该槽没有装备"}
	if count(inv, equip_map) >= capacity(cfg):
		return {"ok": false, "err": "背包已满，先腾出空位"}
	equip_map.erase(slot)
	return {"ok": true, "uid": uid}


static func set_locked(inv: Dictionary, uid: int, on: bool) -> Dictionary:
	ensure(inv)
	var inst := find_by_uid(inv["instances"], uid)
	if inst.is_empty():
		return {"ok": false, "err": "找不到这件装备"}
	inst["locked"] = on
	return {"ok": true, "locked": on}


static func rarity_row(cfg: Dictionary, rarity_id: int) -> Dictionary:
	for r in (cfg.get("rarity", []) as Array):
		var rd := r as Dictionary
		if int(rd.get("id", 0)) == rarity_id:
			return rd
	return {}


static func rarity_mult(cfg: Dictionary, rarity_id: int) -> float:
	return float(rarity_row(cfg, rarity_id).get("sell_mult", 1.0))


## 回收价 = 模板价 × 稀有度倍率 + 已投入强化金币的一半。
## 强化返还用**与 equip_enhance_cost 同一条公式**逐级累加：确定性、可被测试重算，
## 强化过的装备不会以"0 级白装价"被卖掉（旧强化投入在经济上被承认）。
static func sell_price(cfg: Dictionary, tpl: Dictionary, inst: Dictionary) -> int:
	var ec: Dictionary = cfg.get("enhance", {})
	var price := float(tpl.get("price", 0)) * rarity_mult(cfg, int(inst.get("rarity", 1)))
	var g_base := float(ec.get("cost_gold_base", 150))
	var g_step := float(ec.get("cost_gold_step", 150))
	var refund := 0.0
	for i in maxi(0, int(inst.get("lv", 0))):
		refund += g_base + g_step * float(i)
	return int(roundf(price + refund * 0.5))


## 卖出。在身 / 锁定 → 拒绝；强化过或稀有 → 需 confirm=true（防误卖），否则回 {need_confirm:true}。
## tpl_of 是 Callable：id -> 模板字典（G 传 equip_tpl，保持本模块不读表）。
static func sell(inv: Dictionary, cfg: Dictionary, equip_map: Dictionary,
		tpl_of: Callable, uid: int, confirm := false) -> Dictionary:
	ensure(inv)
	var arr: Array = inv["instances"]
	var inst := find_by_uid(arr, uid)
	if inst.is_empty():
		return {"ok": false, "err": "找不到这件装备"}
	if worn_uids(equip_map).has(uid):
		return {"ok": false, "err": "装备中的物品不能卖出"}
	if bool(inst.get("locked", false)):
		return {"ok": false, "err": "已锁定的装备不能卖出"}
	if (int(inst.get("lv", 0)) > 0 or int(inst.get("rarity", 1)) >= 2) and not confirm:
		return {"ok": false, "need_confirm": true, "err": "再次点击确认卖出"}
	var tpl: Dictionary = tpl_of.call(String(inst.get("tpl", "")))
	var price := sell_price(cfg, tpl, inst)
	var idx := arr.find(inst)
	if idx >= 0:
		arr.remove_at(idx)
	return {"ok": true, "gold": price}


## 拆下一颗宝石（免金币）。宝石回 items 堆叠，不占背包格，所以**不会因满包失败**。
static func gem_pop(inst: Dictionary, idx: int) -> Dictionary:
	var gems: Array = inst.get("gems", [])
	if idx < 0 or idx >= gems.size():
		return {"ok": false, "err": "该孔位没有宝石"}
	var gid := String(gems[idx])
	gems.remove_at(idx)
	inst["gems"] = gems
	return {"ok": true, "gem": gid}


## 确定性 3 合 1：同级同色 3 颗 → 1 颗 +1 级；扣金币费。满级／不足 3 颗／缺钱 → 拒绝且**不改动**。
static func gem_merge(items: Dictionary, wallet: Dictionary, cfg: Dictionary, gem_id: String) -> Dictionary:
	var mc: Variant = cfg.get("merge")
	var need := maxi(2, int((mc as Dictionary).get("gem_merge_n", 3))) if mc is Dictionary else 3
	var cost := maxi(0, int((mc as Dictionary).get("gem_merge_cost_gold", 300))) if mc is Dictionary else 0
	var color := ""
	var lv := 0
	var max_lv := 0
	for c in ((cfg.get("gems", {}) as Dictionary).get("colors", []) as Array):
		var cd := c as Dictionary
		if gem_id.begins_with("gem_%s_" % String(cd.get("id", ""))):
			color = String(cd.get("id", ""))
			lv = int(gem_id.get_slice("_", 2))
			max_lv = (cd.get("values", []) as Array).size()
			break
	if color.is_empty() or lv < 1:
		return {"ok": false, "err": "无效宝石"}
	if lv >= max_lv:
		return {"ok": false, "err": "已是最高级"}
	if int(items.get(gem_id, 0)) < need:
		return {"ok": false, "err": "需要 %d 颗同级同色宝石" % need}
	if int(wallet.get("gold", 0)) < cost:
		return {"ok": false, "err": "金币不足"}
	var next_id := "gem_%s_%d" % [color, lv + 1]
	items[gem_id] = int(items.get(gem_id, 0)) - need
	items[next_id] = int(items.get(next_id, 0)) + 1
	wallet["gold"] = int(wallet.get("gold", 0)) - cost
	return {"ok": true, "gem": next_id}


## 地图外观钩子：在身武器 → {weapon_tpl, weapon_icon, weapon_name, rarity, color}；未装备 → {}。
static func appearance(tpl_of: Callable, cfg: Dictionary, inst: Dictionary) -> Dictionary:
	if inst.is_empty():
		return {}
	var tpl: Dictionary = tpl_of.call(String(inst.get("tpl", "")))
	var row := rarity_row(cfg, int(inst.get("rarity", 1)))
	return {
		"weapon_tpl": String(inst.get("tpl", "")),
		"weapon_icon": String(tpl.get("icon", "")),
		"weapon_name": String(tpl.get("name", "")),
		"rarity": int(inst.get("rarity", 1)),
		"color": String(row.get("color", "")),
	}


## 掷一次装备掉落：返回 {tpl, rarity} 或 {}。
## 概率取 cfg.drop[tier].chance；稀有度池取 drops_cfg.equip[tier].rarities（缺省=全体），
## 同池内按 cfg.rarity[].drop_weight 加权抽模板。rng 由调用方注入 → 可确定性测试。
static func roll_drop(cfg: Dictionary, drops_cfg: Dictionary, tier: String,
		rng: RandomNumberGenerator) -> Dictionary:
	var drop_v: Variant = cfg.get("drop")
	if not (drop_v is Dictionary):
		return {}
	var row_v: Variant = (drop_v as Dictionary).get(tier)
	if not (row_v is Dictionary):
		return {}
	if rng.randf() > float((row_v as Dictionary).get("chance", 0.0)):
		return {}
	var allowed: Array = []
	var eq_v: Variant = drops_cfg.get("equip")
	if eq_v is Dictionary:
		var tier_v: Variant = (eq_v as Dictionary).get(tier)
		if tier_v is Dictionary:
			var arr_v: Variant = (tier_v as Dictionary).get("rarities")
			if arr_v is Array:
				# JSON 数字读入后可能是 float（2.0）；Array.has(2) 对类型敏感，
				# 不归一会让首领的 [2, 3] 池被误判为空，必掉装备也发不出来。
				for rarity_v in arr_v:
					allowed.append(int(rarity_v))
	var pools: Array = []
	var total := 0.0
	for t in (cfg.get("templates", []) as Array):
		var td := t as Dictionary
		var r := int(td.get("rarity", 1))
		if not allowed.is_empty() and not allowed.has(r):
			continue
		var w := float(rarity_row(cfg, r).get("drop_weight", 0))
		if w <= 0.0:
			continue
		pools.append({"tpl": String(td.get("id", "")), "rarity": r, "w": w})
		total += w
	if pools.is_empty() or total <= 0.0:
		return {}
	var roll := rng.randf() * total
	var acc := 0.0
	for p in pools:
		var pd := p as Dictionary
		acc += float(pd.get("w", 0.0))
		if roll <= acc:
			return {"tpl": String(pd.get("tpl", "")), "rarity": int(pd.get("rarity", 1))}
	var last := pools[pools.size() - 1] as Dictionary
	return {"tpl": String(last.get("tpl", "")), "rarity": int(last.get("rarity", 1))}
