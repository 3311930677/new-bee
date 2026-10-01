# RewardLedger.gd —— 奖励事务：按 transaction_id 一次扣除与发放（P02）
#
# 为什么单独一个模块：
#   「爆了怪 → 加钱加经验发材料」以前直接改 wallet/items/prog，任何一次重复上报
#   （战斗结果重放、NPC 重按、读档后重进场景）都会再发一遍。加上材料掉落与任务物后，
#   重复发放会真正改变养成数值。这里把「一次结算」做成带 ID 的事务：同一个 ID 只落地一次。
#
# 事务形状（契约见 docs/plans/2026-09-28-p02-world-session-design.md §2.3）：
#   RewardTransaction = {transaction_id, costs, grants, world_flags}
#   costs  键：gold / expedition / soul / honor / "item:<id>"（正数=需要扣除）
#   grants 键：gold / expedition / soul / honor / exp / "item:<id>" / "flag:<name>"
#               / "equip:<tpl_id>:<rarity>"（P04：装备实例，值=件数）
#
# host 是调用方传入的宿主对象（正常游戏里就是 G autoload），约定：
#   属性 wallet: Dictionary、items: Dictionary、prog: Dictionary
#   方法 gain_exp(amount, persist) -> int、grant_item(id, n, persist) -> void
#        inv_grant_equip(spec, persist) -> Dictionary（R-07：返回值必须被检查，失败即整单拒绝）
#        equip_tpl(tpl_id) -> Dictionary（只读，找不到返回 {}）、equip_cfg() -> Dictionary（只读）
# 纯静态、不引用任何 autoload，可用假宿主直接测。
class_name RewardLedger

const ITEM_PREFIX := "item:"
const FLAG_PREFIX := "flag:"
const EQUIP_PREFIX := "equip:"


## 确定性事务 ID。同一事实（同一步骤、同一遭遇）重复调用必须得到同一个 ID。
static func tx_id(kind: String, subject: String, detail := "", nonce := "") -> String:
	return "%s|%s|%s|%s" % [kind, subject, detail, nonce]


static func make(transaction_id: String, costs := {}, grants := {}, world_flags := {}) -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"costs": costs if costs is Dictionary else {},
		"grants": grants if grants is Dictionary else {},
		"world_flags": world_flags if world_flags is Dictionary else {},
	}


static func ensure(ledger: Dictionary) -> Dictionary:
	if not (ledger.get("applied") is Array):
		ledger["applied"] = []
	return ledger


static func applied(ledger: Dictionary, tid: String) -> bool:
	var arr: Variant = ledger.get("applied", [])
	return arr is Array and tid in (arr as Array)


## 应用一次事务。返回 { ok, applied, duplicate, err }。
## 已应用 → ok=true/applied=false/duplicate=true（调用方据此跳过；绝不重复发放）。
## 付不起 → ok=false，且**不做任何改动**。
static func apply(tx: Dictionary, ledger: Dictionary, host: Object) -> Dictionary:
	var tid := String(tx.get("transaction_id", ""))
	if tid.is_empty():
		return {"ok": false, "applied": false, "duplicate": false, "err": "事务缺少 transaction_id"}
	ensure(ledger)
	if applied(ledger, tid):
		return {"ok": true, "applied": false, "duplicate": true, "err": ""}
	var wallet: Dictionary = host.get("wallet")
	var items: Dictionary = host.get("items")
	var costs: Dictionary = tx.get("costs", {})
	var grants: Dictionary = tx.get("grants", {})
	# R-07：装备奖励必须在**任何扣减之前**预校验。
	# 旧实现丢掉了 inv_grant_equip 的返回值：模板未知时装备发不出来，金币/材料却已扣，
	# 事务 ID 还会被写进去重表 —— 玩家既丢了成本又无法重试。失败即整体拒绝、零副作用。
	var pre := _precheck_equips(grants, host)
	if not bool(pre["ok"]):
		return _fail(String(pre["err"]))
	for k in costs:
		var need := int(costs[k])
		if need <= 0:
			continue
		if String(k).begins_with(ITEM_PREFIX):
			var iid := String(k).substr(ITEM_PREFIX.length())
			if int(items.get(iid, 0)) < need:
				return _fail("缺少物品 %s（需 %d，实有 %d）"
					% [iid, need, int(items.get(iid, 0))])
		elif int(wallet.get(String(k), 0)) < need:
			return _fail("货币 %s 不足（需 %d，实有 %d）"
				% [String(k), need, int(wallet.get(String(k), 0))])
	# 预检能拦住表错，但宿主回调仍可能失败。回调期间禁止持久化，
	# 因此在第一笔扣款前保留内存快照；失败时连已发的经验/材料/装备一起退回。
	var prog: Dictionary = host.get("prog")
	var before_wallet := wallet.duplicate(true)
	var before_items := items.duplicate(true)
	var before_prog := prog.duplicate(true)
	var extra_inv := _extra_inventory(host)
	var before_extra_inv := extra_inv.duplicate(true)
	# 扣除
	for k2 in costs:
		var n2 := int(costs[k2])
		if n2 <= 0:
			continue
		if String(k2).begins_with(ITEM_PREFIX):
			var iid2 := String(k2).substr(ITEM_PREFIX.length())
			items[iid2] = int(items.get(iid2, 0)) - n2
		else:
			wallet[String(k2)] = int(wallet.get(String(k2), 0)) - n2
	# 发放
	for g in grants:
		var n3 := int(grants[g])
		if n3 <= 0:
			continue
		if String(g) == "exp":
			host.call("gain_exp", n3, false)
		elif String(g).begins_with(ITEM_PREFIX):
			host.call("grant_item", String(g).substr(ITEM_PREFIX.length()), n3, false)
		elif String(g).begins_with(EQUIP_PREFIX):
			# P04：装备掉落 → 实例（满包时进待领取箱，绝不丢物）。
			# 模板/稀有度已由 _precheck_equips 校验过，这里再兜一层：若仍失败就判整单失败。
			var parts := String(g).substr(EQUIP_PREFIX.length()).split(":")
			var er: Variant = host.call("inv_grant_equip", {
				"tpl": String(parts[0]) if parts.size() > 0 else "",
				"rarity": int(parts[1]) if parts.size() > 1 else 0,
				"n": n3,
				"source_id": tid,
			}, false)
			if not (er is Dictionary) or not bool((er as Dictionary).get("ok", false)):
				_restore_dict(wallet, before_wallet)
				_restore_dict(items, before_items)
				_restore_dict(prog, before_prog)
				if not extra_inv.is_empty() or not before_extra_inv.is_empty():
					_restore_dict(extra_inv, before_extra_inv)
				return _fail("装备奖励发放失败：%s" % String(g))
		elif String(g).begins_with(FLAG_PREFIX):
			_set_flag(host, String(g).substr(FLAG_PREFIX.length()), true)
		else:
			wallet[String(g)] = int(wallet.get(String(g), 0)) + n3
	var world_flags: Dictionary = tx.get("world_flags", {})
	for f in world_flags:
		_set_flag(host, String(f), world_flags[f])
	(ledger["applied"] as Array).append(tid)
	return {"ok": true, "applied": true, "duplicate": false, "err": ""}


## G 把装备容器放在 prog.inventory；轻量测试宿主可能单独持有 inv。
static func _extra_inventory(host: Object) -> Dictionary:
	for prop in host.get_property_list():
		if String(prop.get("name", "")) == "inv":
			var value: Variant = host.get("inv")
			return value as Dictionary if value is Dictionary else {}
	return {}


static func _restore_dict(target: Dictionary, before: Dictionary) -> void:
	target.clear()
	target.merge(before, true)


## R-07：装备奖励的**应用前预校验**（在扣成本/发任何奖励之前调用）。
##
## 为什么必须前置：inv_grant_equip 遇到未知模板会返回 {ok:false}，旧实现把它丢掉了 ——
## 于是「金币与材料照扣、装备一件没发、事务 ID 却已写进去重表」：玩家既丢了成本又无法重试。
## 这里把所有 equip: 奖励的模板、稀有度、数量先验一遍；只要一条不合法就整体拒绝，
## 上层不得扣减、不得发放、不得登记事务 ID（失败零副作用）。
## host 只读契约：equip_tpl(tpl_id) -> Dictionary（找不到返回 {}）、equip_cfg() -> Dictionary。
static func _precheck_equips(grants: Dictionary, host: Object) -> Dictionary:
	for g in grants:
		var key := String(g)
		if not key.begins_with(EQUIP_PREFIX):
			continue
		var n := int(grants[g])
		if n <= 0:
			continue
		var parts := key.substr(EQUIP_PREFIX.length()).split(":")
		var tpl_id := String(parts[0]) if parts.size() > 0 else ""
		if tpl_id.is_empty():
			return {"ok": false, "err": "装备奖励缺少模板 id：%s" % key}
		var tpl_v: Variant = host.call("equip_tpl", tpl_id)
		var tpl: Dictionary = {}
		if tpl_v is Dictionary:
			tpl = tpl_v
		if tpl.is_empty():
			return {"ok": false, "err": "装备奖励引用了未知模板：%s（该奖励发不出来，整单拒绝以免白扣成本）" % tpl_id}
		var rarity := int(parts[1]) if parts.size() > 1 else int(tpl.get("rarity", 1))
		var cfg_v: Variant = host.call("equip_cfg")
		if cfg_v is Dictionary and not (cfg_v as Dictionary).is_empty():
			var found := false
			for r in ((cfg_v as Dictionary).get("rarity", []) as Array):
				if r is Dictionary and int((r as Dictionary).get("id", 0)) == rarity:
					found = true
					break
			if not found:
				return {"ok": false, "err": "装备奖励 %s 的稀有度 %d 不在稀有度表中" % [tpl_id, rarity]}
		elif rarity < 1:
			return {"ok": false, "err": "装备奖励 %s 的稀有度 %d 非法" % [tpl_id, rarity]}
	return {"ok": true, "err": ""}


static func _set_flag(host: Object, name: String, value: Variant) -> void:
	var prog: Dictionary = host.get("prog")
	var flags: Variant = prog.get("flags")
	if not (flags is Dictionary):
		flags = {}
		prog["flags"] = flags
	(flags as Dictionary)[name] = value


static func _fail(err: String) -> Dictionary:
	return {"ok": false, "applied": false, "duplicate": false, "err": err}
