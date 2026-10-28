# SaveData.gd —— 存档版本、结构校验、逐版迁移与安全写盘
#
# 为什么单独一个模块（问题 #39、#24）：
#   原实现的迁移逻辑散落在 G._load_save 的字段赋值中间（比如 items.gacha_pity → prog.gacha.pity），
#   导入路径 SettingsPanel.do_import 又只检查"是不是 JSON 对象"就把整份文本盖到存档上：
#   没有版本闸门、没有结构校验、没有备份、没有原子替换。导入一个未来版本的档会静默丢字段，
#   导入一个 last_ts 在未来水位的档会让所有按天/按时的刷新长期冻结。
#
# 数据流（导入）：解析 → 结构/版本闸门 → 逐版迁移 → 语义校验 → 备份 → 原子落盘 → 重读内存
# 数据流（启动）：解析 → 结构/版本闸门 → 逐版迁移 → 语义校验 → 应用内存
# 纯静态、不引用任何 autoload：这样它既能被 -s 脚本测试，也能被 UI 与启动流程共用。
class_name SaveData

## 当前写盘版本。G.SAVE_VERSION 只是它的别名，避免两处各写一个数字。
## v4（P02）：prog.main_world 加 encounters，prog 加 ledger/flags，story 加 goals。
## v5（P04）：装备升级成实例 —— prog.inventory（instances/pending/next_uid），
##            prog.equip 从内联状态 {lv,gems,affixes} 变成实例 uid（旧强化投入等值搬运）。
## v6（P06）：补 prog.economy 的游戏日、现货余量、价格历史与订单；旧档不改已有金币与物品。
## 读档安全位不落盘（见 docs/plans/2026-09-28-p02-world-session-design.md §3.1）。
## v7：独立奇遇阶段、分支、已保存遭遇与二选一谢礼；旧档从空记录开始。
const CURRENT_VERSION := 7
## 低于这个版本的档连迁移入口都没有，直接判定不可读。
const MIN_READABLE_VERSION := 1
## 允许的时钟偏差（秒）：last_ts 超过"现在 + 这个值"就算未来水位异常档。
## 6 小时覆盖跨时区旅行与手动校时，又挡得住明显伪造的未来档。
## ⚠ 这是产品决策，不是技术推导；若玩法需要更长离线进度，改这里并同步设计文档。
const FUTURE_TS_LIMIT_SEC := 6 * 3600
## 备份保留份数（多的按时间从旧到新删）
const BACKUP_KEEP := 3
const WALLET_KEYS := ["gold", "expedition", "soul", "honor"]
## 存档里"必须是字典"的字段（缺省允许，给了就必须是字典）
const DICT_FIELDS := ["wallet", "items", "prog", "city", "quest", "arena", "audio"]


## 版本字段：只接受非负整数（JSON 浮点但数值上是整数也接受）。非法返回 -1。
static func version_of(data: Dictionary) -> int:
	if not data.has("version"):
		return 1   # 历史档没有 version 字段，按 v1 处理
	var v: Variant = data.get("version")
	if v is int:
		return int(v) if int(v) >= 0 else -1
	if v is float:
		var f := float(v)
		if f >= 0.0 and is_equal_approx(f, roundf(f)):
			return int(f)
	return -1


static func is_future(data: Dictionary) -> bool:
	return version_of(data) > CURRENT_VERSION


## 逐版本迁移。每步都是纯函数，对已是目标版本的档再跑一次不会改动数值（幂等）。
## 返回 { ok, err, data, from, to, steps }
static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var from := version_of(data)
	if from < 0:
		return _mig_fail(data, from, "存档 version 字段非法（应为非负整数）")
	if from > CURRENT_VERSION:
		return _mig_fail(data, from,
			"存档版本 %d 高于本程序支持的 %d，拒绝导入（避免把它没有的字段当垃圾丢掉）"
			% [from, CURRENT_VERSION])
	if from < MIN_READABLE_VERSION:
		return _mig_fail(data, from, "存档版本 %d 过旧，无法迁移" % from)
	var v := from
	var steps: Array = []
	var guard := 0
	while v < CURRENT_VERSION and guard < 32:
		guard += 1
		match v:
			1:
				_migrate_v1_to_v2(data)
				steps.append("v1→v2")
				v = 2
			2:
				_migrate_v2_to_v3(data)
				steps.append("v2→v3")
				v = 3
			3:
				_migrate_v3_to_v4(data)
				steps.append("v3→v4")
				v = 4
			4:
				_migrate_v4_to_v5(data)
				steps.append("v4→v5")
				v = 5
			5:
				_migrate_v5_to_v6(data)
				steps.append("v5→v6")
				v = 6
			6:
				_migrate_v6_to_v7(data)
				steps.append("v6→v7")
				v = 7
			_:
				return _mig_fail(data, from, "缺少 v%d 的迁移步骤（迁移表不完整）" % v)
	data["version"] = CURRENT_VERSION
	# 归一化对**所有**版本都跑（含本来就是当前版的档）：散落过的旧字段不能只靠版本号来清，
	# 因为"已经是 v3 但被旧程序写脏的档"确实存在（例如 items.gacha_pity 残留）。
	_normalize(data)
	return {"ok": true, "err": "", "data": data, "from": from, "to": CURRENT_VERSION, "steps": steps}


## 清理历史遗留字段；幂等。
static func _normalize(data: Dictionary) -> void:
	var items: Variant = data.get("items", {})
	if items is Dictionary and (items as Dictionary).has("gacha_pity"):
		var prog: Variant = data.get("prog", {})
		if prog is Dictionary:
			var gacha: Variant = (prog as Dictionary).get("gacha", {})
			if gacha is Dictionary:
				if int((gacha as Dictionary).get("pity", 0)) == 0:
					(gacha as Dictionary)["pity"] = maxi(0, int((items as Dictionary)["gacha_pity"]))
		(items as Dictionary).erase("gacha_pity")
	# v4 结构对所有版本都补齐：已经是 v4 但被旧程序写脏的档确实存在（缺 ledger.encounters 等）
	var p: Variant = data.get("prog", {})
	if p is Dictionary:
		_ensure_v4(p as Dictionary)
		# v5 结构同样对所有版本都补齐（P04）：装备实例化 + prog.equip 转 uid。
		# 幂等 —— 已是 uid 的槽会被跳过，所以"再迁移一次 uid 不变"。
		_ensure_v5(p as Dictionary)
		_ensure_v6(p as Dictionary)
		_ensure_v7(p as Dictionary)


static func _mig_fail(data: Dictionary, from: int, err: String) -> Dictionary:
	push_warning("存档迁移：%s" % err)
	return {"ok": false, "err": err, "data": data, "from": from, "to": from, "steps": []}


## v1 → v2：把顶层容器补成字典。
## v1 时代 wallet/items/prog 允许缺失或为 null，后续所有读取都假定它们是字典。
static func _migrate_v1_to_v2(data: Dictionary) -> void:
	for k in ["wallet", "items", "prog"]:
		if not (data.get(k) is Dictionary):
			data[k] = {}


## v2 → v3：保底计数从道具背包搬进 prog.gacha，并从 items 里清掉。
## 这一步以前混在 G._load_save 的字段赋值之间，没有版本边界，重复读档会反复执行。
static func _migrate_v2_to_v3(data: Dictionary) -> void:
	var items: Variant = data.get("items", {})
	var prog: Variant = data.get("prog", {})
	if not (items is Dictionary):
		items = {}
		data["items"] = items
	if not (prog is Dictionary):
		prog = {}
		data["prog"] = prog
	var gacha: Variant = (prog as Dictionary).get("gacha")
	if not (gacha is Dictionary):
		gacha = {}
		(prog as Dictionary)["gacha"] = gacha
	var legacy: Variant = (items as Dictionary).get("gacha_pity")
	if legacy != null:
		if int((gacha as Dictionary).get("pity", 0)) == 0:
			(gacha as Dictionary)["pity"] = maxi(0, int(legacy))
		(items as Dictionary).erase("gacha_pity")


## v3 → v4（P02）：主世界会话状态与奖励账本落位。
##
## v3 的 prog.main_world 只有单图 respawn_at、bosses_cleared，以及历史遗留的永久击杀表 killed；
## v4 需要：多图 respawn_by_map（旧单图折进来）、encounters（遭遇去重）、ledger/flags（事务），
## 以及 story.goals（把旧 done[] 映射成新目标状态）。这些都是"补齐结构 + 搬数据"，不改数值。
static func _migrate_v3_to_v4(data: Dictionary) -> void:
	var prog: Variant = data.get("prog", {})
	if not (prog is Dictionary):
		prog = {}
		data["prog"] = prog
	_ensure_v4(prog as Dictionary)


## v4 结构落位；幂等，可对已是 v4 的档重复调用。
static func _ensure_v4(prog: Dictionary) -> void:
	# ---- main_world 形状 ----
	var mw: Variant = prog.get("main_world")
	if not (mw is Dictionary):
		mw = {"map_id": "lorin_wilds"}
		prog["main_world"] = mw
	var mwd := mw as Dictionary
	# 注意：这里一律用 .get(k)（不带缺省值）判断"键是否存在/类型对不对"。
	# 若写成 .get(k, {})，缺键时拿到的是一个临时容器，后面的写入会落进临时对象里丢掉。
	if not (mwd.get("bosses_cleared") is Array):
		mwd["bosses_cleared"] = []
	if not (mwd.get("respawn_by_map") is Dictionary):
		mwd["respawn_by_map"] = {}
	if not (mwd.get("encounters") is Dictionary):
		mwd["encounters"] = {}
	var map_id := String(mwd.get("map_id", ""))
	# 旧单图 respawn_at 折进 respawn_by_map[map_id]；respawn_at 本身保留（旧读法与回归仍看它）
	var legacy: Variant = mwd.get("respawn_at")
	if map_id != "" and legacy is Dictionary and not (legacy as Dictionary).is_empty():
		var per := mwd["respawn_by_map"] as Dictionary
		if not per.has(map_id):
			per[map_id] = (legacy as Dictionary).duplicate()
	# 旧永久击杀表：折算成"下次进图即刷新"，再删除该字段（避免同一只怪被永久屏蔽）
	var killed: Variant = mwd.get("killed")
	if map_id != "" and killed is Array and not (killed as Array).is_empty():
		var per2 := mwd["respawn_by_map"] as Dictionary
		var row: Variant = per2.get(map_id)
		if not (row is Dictionary):
			row = {}
			per2[map_id] = row
		for old_id in (killed as Array):
			if not (row as Dictionary).has(str(old_id)):
				(row as Dictionary)[str(old_id)] = 0.0
	mwd.erase("killed")
	# ---- 主线：done[] → goals（新目标状态）----
	var story: Variant = prog.get("story")
	if not (story is Dictionary):
		story = {"step": "s01", "done": []}
		prog["story"] = story
	var sd := story as Dictionary
	if not (sd.get("done") is Array):
		sd["done"] = []
	if not (sd.get("goals") is Dictionary):
		sd["goals"] = {}
	var sdone := sd["done"] as Array
	var sgoals := sd["goals"] as Dictionary
	for id in sdone:
		sgoals[String(id)] = "done"
	for id2 in sgoals.keys():
		if not sdone.has(id2):
			sdone.append(id2)
	# ---- 账本与旗标 ----
	if not (prog.get("ledger") is Dictionary):
		prog["ledger"] = {"applied": []}
	var lgr := prog["ledger"] as Dictionary
	if not (lgr.get("applied") is Array):
		lgr["applied"] = []
	if not (prog.get("flags") is Dictionary):
		prog["flags"] = {}


## v4 → v5（P04）：装备从"6 个固定槽的内联状态"升级成实例。
static func _migrate_v4_to_v5(data: Dictionary) -> void:
	var prog: Variant = data.get("prog", {})
	if not (prog is Dictionary):
		prog = {}
		data["prog"] = prog
	_ensure_v5(prog as Dictionary)


static func _migrate_v5_to_v6(data: Dictionary) -> void:
	var p: Variant = data.get("prog", {})
	if not (p is Dictionary):
		p = {}
		data["prog"] = p
	_ensure_v6(p as Dictionary)


static func _ensure_v6(prog: Dictionary) -> void:
	# 类型错时保留原值，交给 validate() 拒绝；不能把玩家交易记录默默清空。
	if not prog.has("economy"):
		prog["economy"] = EconomyService.ensure({}, TableCache.economy_config())
	elif prog.get("economy") is Dictionary:
		prog["economy"] = EconomyService.ensure(prog["economy"], TableCache.economy_config())


static func _migrate_v6_to_v7(data: Dictionary) -> void:
	if not data.has("prog"): data["prog"] = {}
	if data.get("prog") is Dictionary: _ensure_v7(data["prog"])


static func _ensure_v7(prog: Dictionary) -> void:
	# Only absent fields are defaulted. Malformed records remain visible to validation.
	if not prog.has("special_events"): prog["special_events"] = {"records":{},"tracked":""}


## v5 结构落位；幂等，可对已是 v5 的档重复调用。
##
## 只搬运、不改数值：旧 {lv, gems, affixes} 原样复制进实例，槽位改记实例 uid；
## 基础属性由模板 tpl_<slot>_basic 提供，而它的 base 与 slots[<slot>].base 逐字段相等，
## 所以 equip_base_stat / equip_slot_bonus / growth_bonuses 的输出迁移前后完全一致。
static func _ensure_v5(prog: Dictionary) -> void:
	# ---- 拥有池 / 待领取箱 / 实例号 ----
	# R-05：容器**存在但类型错**时绝不静默替换成空数组 —— 那等于把玩家的全部装备悄悄删掉。
	# 只补"缺键"，类型错的留给 validate() 判非法（上层备份 + 锁写），错误可见、可恢复。
	if not prog.has("inventory"):
		prog["inventory"] = {"instances": [], "pending": [], "next_uid": 1}
	var inv_v: Variant = prog.get("inventory")
	if not (inv_v is Dictionary):
		return
	var inv := inv_v as Dictionary
	if not inv.has("instances"):
		inv["instances"] = []
	if not inv.has("pending"):
		inv["pending"] = []
	# next_uid 只能向上修（永不复用已发出的号）：取 instances+pending 的最大 uid + 1。
	# 这是"可确定修复"的一种：只升不降，不会让任何实例号被复用，也不会删物。
	var max_uid := 0
	for key in ["instances", "pending"]:
		var arr_v: Variant = inv.get(key)
		if arr_v is Array:
			for it in (arr_v as Array):
				if it is Dictionary:
					max_uid = maxi(max_uid, int((it as Dictionary).get("uid", 0)))
	var nu: Variant = inv.get("next_uid")
	if nu is int or nu is float:
		inv["next_uid"] = maxi(int(nu), max_uid + 1)
	else:
		inv["next_uid"] = maxi(1, max_uid + 1)
	# ---- 槽 → uid ----
	if not prog.has("equip"):
		prog["equip"] = {}
	var eq_v: Variant = prog.get("equip")
	if not (eq_v is Dictionary):
		return
	var eq := eq_v as Dictionary
	# 实例数组类型不对时停在这里（validate 会判非法），不要对非数组做 as Array 取空指针
	if not (inv.get("instances") is Array) or not (inv.get("pending") is Array):
		return
	# 槽表来自 equip.json 的 slots[]（模板命名约定 tpl_<slot>_basic）。表缺失时不猜、直接返回。
	var cfg := TableCache.equip_config()
	if cfg.is_empty():
		return
	var default_sockets := int((cfg.get("gems", {}) as Dictionary).get("sockets", 3))
	var insts := inv["instances"] as Array
	var next_uid := int(inv["next_uid"])
	for s in (cfg.get("slots", []) as Array):
		var sid := String((s as Dictionary).get("id", ""))
		if sid.is_empty():
			continue
		var cur: Variant = eq.get(sid)
		if cur is int or cur is float:
			continue   # 已是 uid（v5 形状）→ 跳过，保证"再迁移一次 uid 不变"
		if not (cur is Dictionary):
			continue   # 缺省 = 未装备；新档由 G.ensure_starter_equip() 补
		var old := cur as Dictionary
		var tpl_id := "tpl_%s_basic" % sid
		var sockets := default_sockets
		for t in (cfg.get("templates", []) as Array):
			var td := t as Dictionary
			if String(td.get("id", "")) == tpl_id:
				sockets = int(td.get("sockets", default_sockets))
				break
		var gems_v: Variant = old.get("gems")
		var aff_v: Variant = old.get("affixes")
		insts.append({
			"uid": next_uid,
			"tpl": tpl_id,
			"slot": sid,
			"rarity": 1,
			"lv": maxi(0, int(old.get("lv", 0))),
			"sockets": sockets,
			"gems": (gems_v as Array).duplicate() if gems_v is Array else [],
			"affixes": (aff_v as Array).duplicate(true) if aff_v is Array else [],
			"locked": false,
		})
		next_uid += 1
		eq[sid] = next_uid - 1
	inv["next_uid"] = next_uid


## 语义校验：类型、取值范围、未来时间水位。
## now_sec 由调用方传入（可测，不依赖真实时钟）。
## 返回 { ok, err }
static func validate(data: Dictionary, now_sec: int) -> Dictionary:
	var err := ""
	for k in DICT_FIELDS:
		if data.has(k) and not (data.get(k) is Dictionary):
			err = "字段 %s 应为对象" % k
			return {"ok": false, "err": err}
	var wallet: Variant = data.get("wallet", {})
	if wallet is Dictionary:
		for k in WALLET_KEYS:
			var v: Variant = (wallet as Dictionary).get(k)
			if v == null:
				continue
			if not (v is int or v is float):
				return {"ok": false, "err": "钱包 %s 应为数值" % k}
			if float(v) < 0.0:
				return {"ok": false, "err": "钱包 %s 不应为负数（%s）" % [k, str(v)]}
	var items: Variant = data.get("items", {})
	if items is Dictionary:
		for k in (items as Dictionary):
			var n: Variant = (items as Dictionary)[k]
			if not (n is int or n is float):
				return {"ok": false, "err": "道具 %s 数量应为数值" % str(k)}
			if float(n) < 0.0:
				return {"ok": false, "err": "道具 %s 数量不应为负（%s）" % [str(k), str(n)]}
	var prog: Variant = data.get("prog", {})
	if prog is Dictionary:
		var pd := prog as Dictionary
		var lv: Variant = pd.get("level")
		if lv != null:
			if not (lv is int or lv is float):
				return {"ok": false, "err": "角色等级应为数值"}
			if int(lv) < 1 or int(lv) > 10000:
				return {"ok": false, "err": "角色等级超出范围（%s）" % str(lv)}
		for k in ["pets", "codex_claimed"]:
			var arr: Variant = pd.get(k)
			if arr != null and not (arr is Array):
				return {"ok": false, "err": "prog.%s 应为数组" % k}
		for k in ["talents", "equip", "skills", "mounts", "titles", "pet_stat",
				"tips_seen", "settings", "gacha", "world_cleared", "lore_beats", "main_world", "story",
				"ledger", "flags", "economy", "fishing", "active_run", "quest_postings", "world_commissions"]:
			var dv: Variant = pd.get(k)
			if dv != null and not (dv is Dictionary):
				return {"ok": false, "err": "prog.%s 应为对象" % k}
		if not preload("res://src/world/RelicService.gd").validate(pd.get("relic_hunts",{})):
			return {"ok":false,"err":"传世挑战记录字段非法"}
		if not preload("res://src/world/SpecialEventService.gd").validate(pd.get("special_events",{})):
			return {"ok":false,"err":"奇遇阶段、分支或遭遇记录字段非法"}
		var active: Dictionary = pd.get("active_run", {})
		if not WorldCommission.validate(pd.get("world_commissions",{})):
			return {"ok":false,"err":"世界事务公布或阶段字段非法"}
		if not pd.get("oaths",{}) is Dictionary or not preload("res://src/world/OathService.gd").validate(pd.get("oaths",{})):
			return {"ok":false,"err":"守碑誓约快照字段非法"}
		if not pd.get("dungeon_trials",{}) is Dictionary or not preload("res://src/world/DungeonTrial.gd").validate(pd.get("dungeon_trials",{})):
			return {"ok":false,"err":"副本附加挑战字段非法"}
		if not pd.get("trade_contracts",{}) is Dictionary or not preload("res://src/world/TradeContracts.gd").validate(pd.get("trade_contracts",{})):
			return {"ok":false,"err":"商路合约字段非法"}
		if not active.is_empty():
			if not (active.get("state") is Dictionary) or not (active.get("current_node", {}) is Dictionary):
				return {"ok": false, "err": "历练续局快照结构错误"}
			var run := RunState.new()
			if not run.restore(active.state): return {"ok": false, "err": "历练续局快照字段错误，保留原档"}
		# v4 嵌套结构（P02）：存在就必须是正确类型，否则事务去重与遭遇锁会静默失效
		var story: Variant = pd.get("story")
		if story is Dictionary:
			var sdd := story as Dictionary
			if sdd.get("done", []) is not Array:
				return {"ok": false, "err": "prog.story.done 应为数组"}
			if sdd.has("goals") and not (sdd.get("goals") is Dictionary):
				return {"ok": false, "err": "prog.story.goals 应为对象"}
		var mw: Variant = pd.get("main_world")
		if mw is Dictionary:
			var mwd := mw as Dictionary
			if mwd.has("bosses_cleared") and not (mwd.get("bosses_cleared") is Array):
				return {"ok": false, "err": "prog.main_world.bosses_cleared 应为数组"}
			if mwd.has("encounters") and not (mwd.get("encounters") is Dictionary):
				return {"ok": false, "err": "prog.main_world.encounters 应为对象"}
		var ledger: Variant = pd.get("ledger")
		if ledger is Dictionary and not ((ledger as Dictionary).get("applied", []) is Array):
			return {"ok": false, "err": "prog.ledger.applied 应为数组"}
		var economy: Variant = pd.get("economy")
		if economy is Dictionary:
			var ec := economy as Dictionary
			for ek in ["seed", "day", "next_tx"]:
				var ev: Variant = ec.get(ek)
				if not (ev is int or ev is float) or float(ev) < 1.0 \
						or not is_equal_approx(float(ev), roundf(float(ev))):
					return {"ok": false, "err": "prog.economy.%s 应为正整数" % ek}
			for ek in ["bought", "sold", "history", "orders", "work"]:
				if not (ec.get(ek) is Dictionary):
					return {"ok": false, "err": "prog.economy.%s 应为对象" % ek}
			for order_id in ["salt_ship", "herb_ship"]:
				if not (ec["orders"] as Dictionary).has(order_id):
					continue
				var order_value: Variant = ec["orders"][order_id]
				if not (order_value is Dictionary):
					return {"ok": false, "err": "船运订单应为对象"}
				var order := order_value as Dictionary
				var status := String(order.get("status", ""))
				if status not in ["active", "transit", "done"]:
					return {"ok": false, "err": "船运订单状态非法"}
				for field in ["attempt", "accepted_day", "deadline_day", "freight_gold", "payout_gold"]:
					var value: Variant = order.get(field)
					var minimum := 0 if field in ["freight_gold", "payout_gold"] else 1
					if not (value is int or value is float) or float(value) < minimum \
							or not is_equal_approx(float(value), roundf(float(value))):
						return {"ok": false, "err": "船运订单数值非法"}
				if int(order["accepted_day"]) > int(ec["day"]) or int(order["deadline_day"]) < int(order["accepted_day"]):
					return {"ok": false, "err": "船运订单备货日期非法"}
				for field in (["arrival_day"] if status == "transit" else (["arrival_day", "completed_day"] if status == "done" else [])):
					var value: Variant = order.get(field)
					if not (value is int or value is float) or float(value) < int(order["accepted_day"]) \
							or not is_equal_approx(float(value), roundf(float(value))):
						return {"ok": false, "err": "船运订单到港日期非法"}
				if status == "done" and (int(order["completed_day"]) > int(ec["day"]) or int(order["completed_day"]) < int(order["arrival_day"])):
					return {"ok": false, "err": "船运订单结算日期非法"}
			if (ec["orders"] as Dictionary).has("frost_herb_supply"):
				var herb_value: Variant = ec["orders"]["frost_herb_supply"]
				if not (herb_value is Dictionary):
					return {"ok": false, "err": "霜关药单应为对象"}
				var herb := herb_value as Dictionary
				if String(herb.get("status", "")) not in ["active", "done", "abandoned", "settled"] or \
						String(herb.get("route", "")) not in ["", "quick", "safe"]:
					return {"ok": false, "err": "霜关药单状态非法"}
				if herb.has("protection") and String(herb["protection"]) not in ["self", "insured"]:
					return {"ok": false, "err": "霜关药单保价方式非法"}
				for field in ["attempt", "accepted_day", "deadline_day", "freight_gold", "payout_gold"]:
					var value: Variant = herb.get(field)
					var minimum := 0 if field in ["freight_gold", "payout_gold"] else 1
					if not (value is int or value is float) or float(value) < minimum \
							or not is_equal_approx(float(value), roundf(float(value))):
						return {"ok": false, "err": "霜关药单数值非法"}
				if int(herb["accepted_day"]) > int(ec["day"]) or int(herb["deadline_day"]) < int(herb["accepted_day"]):
					return {"ok": false, "err": "霜关药单期限非法"}
				var herb_deposit: Variant = herb.get("deposit_gold", 0)
				if not (herb_deposit is int or herb_deposit is float) or float(herb_deposit) < 0.0 \
						or not is_equal_approx(float(herb_deposit), roundf(float(herb_deposit))):
					return {"ok": false, "err": "霜关药单保证金非法"}
				if herb.has("extended") and not (herb["extended"] is bool):
					return {"ok": false, "err": "霜关药单延期标记非法"}
				if String(herb["status"]) == "done":
					var completion: Variant = herb.get("completed_day")
					if String(herb["route"]).is_empty() or not (completion is int or completion is float) \
							or float(completion) < int(herb["accepted_day"]) or float(completion) > int(ec["day"]) \
							or not is_equal_approx(float(completion), roundf(float(completion))):
						return {"ok": false, "err": "霜关药单交付日期非法"}
				if String(herb["status"]) in ["abandoned", "settled"]:
					var closed: Variant = herb.get("closed_day")
					if not (closed is int or closed is float) or float(closed) < int(herb["accepted_day"]) \
							or float(closed) > int(ec["day"]) \
							or not is_equal_approx(float(closed), roundf(float(closed))):
						return {"ok": false, "err": "霜关药单退单日期非法"}
			for ek in ["bought", "sold"]:
				for sk in (ec[ek] as Dictionary):
					var n: Variant = (ec[ek] as Dictionary)[sk]
					if not (n is int or n is float) or float(n) < 0.0 \
							or not is_equal_approx(float(n), roundf(float(n))):
						return {"ok": false, "err": "prog.economy.%s.%s 应为非负整数" % [ek, str(sk)]}
			for wk in (ec["work"] as Dictionary):
				var wd: Variant = (ec["work"] as Dictionary)[wk]
				if not (wd is int or wd is float) or float(wd) < 1.0 \
						or not is_equal_approx(float(wd), roundf(float(wd))) \
						or int(wd) > int(ec["day"]):
					return {"ok": false, "err": "prog.economy.work.%s 应为不晚于当前日的游戏日" % str(wk)}
			for hk in (ec["history"] as Dictionary):
				var entries: Variant = (ec["history"] as Dictionary)[hk]
				if not (entries is Array) or (entries as Array).size() > EconomyService.MAX_HISTORY:
					return {"ok": false, "err": "prog.economy.history.%s 应为近 5 日数组" % str(hk)}
				var previous_day := 0
				for row in (entries as Array):
					if not (row is Dictionary):
						return {"ok": false, "err": "prog.economy.history.%s 含非法行情" % str(hk)}
					var rd := int((row as Dictionary).get("day", 0))
					if rd <= previous_day or rd > int(ec["day"]) \
							or int((row as Dictionary).get("mid_gold", 0)) < 1:
						return {"ok": false, "err": "prog.economy.history.%s 含非法行情" % str(hk)}
					previous_day = rd
		var road_mail: Variant = pd.get("road_mail")
		if road_mail != null:
			if not (road_mail is Dictionary):
				return {"ok": false, "err": "prog.road_mail 应为对象"}
			var rm := road_mail as Dictionary
			if not rm.is_empty():
				var mail_status := String(rm.get("status", "idle"))
				var mail_phase := String(rm.get("phase", ""))
				if mail_status not in ["idle", "active", "delivered", "claimed"] or \
						(mail_status == "active" and mail_phase not in ["travel", "clue", "hazard", "pass"]) or \
						(mail_status != "active" and not mail_phase.is_empty()):
					return {"ok": false, "err": "prog.road_mail 进度非法"}
				if mail_status in ["active", "delivered", "claimed"] and \
						String(rm.get("route", "")) not in ["quick", "safe"]:
					return {"ok": false, "err": "prog.road_mail 路线非法"}
				if not (rm.get("observed_clues", []) is Array) or \
						String(rm.get("solution", "")) not in ["", "observe", "supply"] or \
						String(rm.get("encounter", "")) not in ["", "ambush", "help", "escort"] or \
						not (rm.get("archive", []) is Array) or (rm.get("archive", []) as Array).size() > 8:
					return {"ok": false, "err": "prog.road_mail 记录非法"}
				var mail_penalty: Variant = rm.get("penalty_gold", 0)
				if not (mail_penalty is int or mail_penalty is float) or \
						float(mail_penalty) not in [0.0, 20.0]:
					return {"ok": false, "err": "prog.road_mail 报酬调整非法"}
				for clue in (rm.get("observed_clues", []) as Array):
					if String(clue) not in ["sand", "stone"]:
						return {"ok": false, "err": "prog.road_mail 线索非法"}
		var fishing: Variant = pd.get("fishing")
		if fishing is Dictionary and not (fishing as Dictionary).is_empty():
			var fs := fishing as Dictionary
			var fishing_day: Variant = fs.get("day", 1)
			if not (fishing_day is int or fishing_day is float) or float(fishing_day) < 1.0 \
					or not is_equal_approx(float(fishing_day), roundf(float(fishing_day))) \
					or not (fs.get("counts", {}) is Dictionary) \
					or not (fs.get("discoveries", []) is Array) or not (fs.get("pending", {}) is Dictionary):
				return {"ok": false, "err": "prog.fishing 结构非法"}
			for count in (fs.get("counts", {}) as Dictionary).values():
				if not (count is int or count is float) or float(count) < 0.0 \
						or not is_equal_approx(float(count), roundf(float(count))):
					return {"ok": false, "err": "prog.fishing.counts 应为非负整数"}
			var fp: Dictionary = fs.get("pending", {})
			if not fp.is_empty():
				var center: Variant = fp.get("center")
				if not (fp.get("token") is String) or not (fp.get("spot") is String) \
						or not (center is int or center is float) or float(center) < 0.0 or float(center) > 1.0:
					return {"ok": false, "err": "prog.fishing.pending 非法"}
		# v5 结构（P04）：背包容器形状错了会静默丢物（满包判定失效），必须在闸门处拦住
		var inv_v: Variant = pd.get("inventory")
		if inv_v != null:
			if not (inv_v is Dictionary):
				return {"ok": false, "err": "prog.inventory 应为对象"}
			var iv := inv_v as Dictionary
			if iv.has("instances") and not (iv.get("instances") is Array):
				return {"ok": false, "err": "prog.inventory.instances 应为数组"}
			if iv.has("pending") and not (iv.get("pending") is Array):
				return {"ok": false, "err": "prog.inventory.pending 应为数组"}
			var nu: Variant = iv.get("next_uid")
			if nu != null and not (nu is int or nu is float):
				return {"ok": false, "err": "prog.inventory.next_uid 应为数值"}
		var eq_v: Variant = pd.get("equip")
		if eq_v != null:
			if not (eq_v is Dictionary):
				return {"ok": false, "err": "prog.equip 应为对象"}
			for ek in (eq_v as Dictionary):
				var uv: Variant = (eq_v as Dictionary)[ek]
				if not (uv is int or uv is float):
					return {"ok": false, "err": "prog.equip.%s 应为实例 uid（数值）" % str(ek)}
				if float(uv) < 0.0 or not is_equal_approx(float(uv), roundf(float(uv))):
					return {"ok": false, "err": "prog.equip.%s 应为非负整数 uid（%s）" % [str(ek), str(uv)]}
		# R-05：v5 深校验 —— 实例字段、UID 唯一性、在身指针、next_uid 单调性。
		# 只验容器外形是不够的：形如 {instances:[{uid:7}], next_uid:7, equip:{sword:7}}
		# 能通过外形检查，却会让下一件掉落复用 UID 7，换装/回收/背包计数全部指错实例。
		if inv_v is Dictionary:
			var deep := _validate_inventory(inv_v as Dictionary, pd.get("equip"))
			if not bool(deep["ok"]):
				return deep
		var ts: Variant = pd.get("last_ts")
		if ts != null:
			if not (ts is int or ts is float):
				return {"ok": false, "err": "时间水位 last_ts 应为数值"}
			if float(ts) > float(now_sec) + float(FUTURE_TS_LIMIT_SEC):
				return {"ok": false, "err": "时间水位异常：last_ts 比当前时间超前 %d 小时，会冻结按天/按时的刷新"
					% int((float(ts) - float(now_sec)) / 3600.0)}
	if data.get("prog",{}) is Dictionary and (data.get("prog",{}) as Dictionary).has("companions"):
		if not CompanionService.validate(data.prog.companions,data.prog.get("pets",[])):
			return {"ok":false,"err":"prog.companions 伙伴协战状态无效"}
	if data.get("prog", {}) is Dictionary and (data.get("prog", {}) as Dictionary).has("campaign_growth"):
		if not CampaignGrowth.validate(data.prog.campaign_growth, data.prog.get("story", {})):
			return {"ok": false, "err": "prog.campaign_growth 主线经验版本无效"}
	if data.get("prog", {}) is Dictionary and (data.get("prog", {}) as Dictionary).has("skill_curriculum"):
		if not MentorCurriculum.validate(data.prog.skill_curriculum, data.prog):
			return {"ok": false, "err": "prog.skill_curriculum 招式授业状态无效"}
	return {"ok": true, "err": ""}


## v5 装备容器的深校验（R-05）。
## 检查：实例必需字段与允许的槽/模板/稀有度、UID 跨 instances+pending 唯一且为正整数、
## 在身指针（equip[slot]）确实指向**拥有池里同槽**的实例、next_uid 大于所有实例号。
## 返回 { ok, err }。表（equip.json）缺失时不猜：只跳过枚举校验，仍查 UID 与指针一致性。
static func _validate_inventory(inv: Dictionary, equip_v: Variant) -> Dictionary:
	var cfg := TableCache.equip_config()
	var cfg_ok := not cfg.is_empty()
	var slots := {}
	var templates := {}
	var rarities := {}
	if cfg_ok:
		for s in (cfg.get("slots", []) as Array):
			slots[String((s as Dictionary).get("id", ""))] = true
		for t in (cfg.get("templates", []) as Array):
			templates[String((t as Dictionary).get("id", ""))] = t
		for r in (cfg.get("rarity", []) as Array):
			rarities[int((r as Dictionary).get("id", 0))] = true
	var by_uid := {}
	var max_uid := 0
	for key in ["instances", "pending"]:
		var arr_v: Variant = inv.get(key)
		if arr_v == null:
			continue
		if not (arr_v is Array):
			return {"ok": false, "err": "prog.inventory.%s 应为数组" % key}
		var arr := arr_v as Array
		for i in arr.size():
			var it_v: Variant = arr[i]
			if not (it_v is Dictionary):
				return {"ok": false, "err": "prog.inventory.%s[%d] 应为装备实例对象" % [key, i]}
			var it := it_v as Dictionary
			var uid_v: Variant = it.get("uid")
			if not (uid_v is int or uid_v is float) or int(uid_v) <= 0 \
					or not is_equal_approx(float(uid_v), roundf(float(uid_v))):
				return {"ok": false, "err": "prog.inventory.%s[%d].uid 应为正整数（%s）" % [key, i, str(uid_v)]}
			var uid := int(uid_v)
			if by_uid.has(uid):
				return {"ok": false, "err": "装备实例 uid %d 在 instances/pending 中重复（会导致换装与回收指错实例）" % uid}
			by_uid[uid] = it
			max_uid = maxi(max_uid, uid)
			if it.has("source_id") and not (it.source_id is String):
				return {"ok": false, "err": "装备实例 uid %d 的来源应为文字" % uid}
			var tpl_id := String(it.get("tpl", ""))
			if tpl_id.is_empty():
				return {"ok": false, "err": "装备实例 uid %d 缺少模板 id" % uid}
			var slot := String(it.get("slot", ""))
			if slot.is_empty():
				return {"ok": false, "err": "装备实例 uid %d 缺少槽位" % uid}
			if cfg_ok:
				if not templates.has(tpl_id):
					return {"ok": false, "err": "装备实例 uid %d 的模板 %s 不存在" % [uid, tpl_id]}
				var tpl := templates[tpl_id] as Dictionary
				var tslot := String(tpl.get("slot", ""))
				if not tslot.is_empty() and tslot != slot:
					return {"ok": false, "err": "装备实例 uid %d 的模板槽位 %s 与其 slot %s 不一致" % [uid, tslot, slot]}
				if not slots.has(slot):
					return {"ok": false, "err": "装备实例 uid %d 的槽位 %s 不在槽表里" % [uid, slot]}
				var r_v: Variant = it.get("rarity")
				if not (r_v is int or r_v is float) or not rarities.has(int(r_v)):
					return {"ok": false, "err": "装备实例 uid %d 的稀有度 %s 非法" % [uid, str(r_v)]}
			elif int(it.get("rarity", 0)) < 1:
				return {"ok": false, "err": "装备实例 uid %d 的稀有度应为正整数" % uid}
			var lv_v: Variant = it.get("lv")
			if not (lv_v is int or lv_v is float) or int(lv_v) < 0:
				return {"ok": false, "err": "装备实例 uid %d 的强化等级应为非负数值（%s）" % [uid, str(lv_v)]}
			if it.has("enhance_failures"):
				var failures: Variant = it.enhance_failures
				var ec: Dictionary = cfg.get("enhance", {}) if cfg_ok else {}
				var target := int(lv_v) + 1
				var limit := 0 if target <= int(ec.get("guaranteed_target", 3)) or int(lv_v) >= int(ec.get("max_level", 20)) else ceili(
					(1.0 - pow(float(ec.get("success_base", 0.9)), float(target))) \
					/ maxf(0.001, float(ec.get("failure_rate_bonus", 0.15))))
				if not (failures is int or failures is float) or float(failures) != float(int(failures)) \
						or int(failures) < 0 or int(failures) > limit:
					return {"ok": false, "err": "装备实例 uid %d 的强化积累非法" % uid}
			for gk in ["gems", "affixes"]:
				if it.has(gk) and not (it.get(gk) is Array):
					return {"ok": false, "err": "装备实例 uid %d 的 %s 应为数组" % [uid, gk]}
	# 在身指针：必须指向拥有池（instances）里、且槽位相符的实例
	if equip_v is Dictionary:
		for slot_key in (equip_v as Dictionary):
			var uid2 := int((equip_v as Dictionary)[slot_key])
			if uid2 <= 0:
				continue
			if not by_uid.has(uid2):
				return {"ok": false, "err": "prog.equip.%s 指向的实例 uid %d 不在拥有池/待领取箱中（悬空指针）"
					% [String(slot_key), uid2]}
			var inst2 := by_uid[uid2] as Dictionary
			if String(inst2.get("slot", "")) != String(slot_key):
				return {"ok": false, "err": "prog.equip.%s 指向的实例槽位是 %s（跨槽指针）"
					% [String(slot_key), String(inst2.get("slot", ""))]}
			if not (inv.get("instances") as Array).has(inst2):
				return {"ok": false, "err": "prog.equip.%s 指向的实例 uid %d 还在待领取箱里（未真正到手）"
					% [String(slot_key), uid2]}
	var nu_v: Variant = inv.get("next_uid")
	if not (nu_v is int or nu_v is float):
		return {"ok": false, "err": "prog.inventory.next_uid 缺失或非数值"}
	if int(nu_v) <= max_uid:
		return {"ok": false, "err": "prog.inventory.next_uid（%d）必须大于最大实例 uid（%d），否则新掉落会复用已发出的实例号"
			% [int(nu_v), max_uid]}
	return {"ok": true, "err": ""}


## 启动路径用：宽容一些。未来版本不阻断（玩家还要能玩），但要报告出来让上层备份原档。
## 返回 { ok, mode, err, data, from, to, steps }，mode ∈ current / migrated / future / invalid
static func load_payload(raw: Dictionary, now_sec: int) -> Dictionary:
	var from := version_of(raw)
	if from < 0:
		return {"ok": false, "mode": "invalid", "err": "存档 version 字段非法", "data": raw,
			"from": from, "to": from, "steps": []}
	if from > CURRENT_VERSION:
		# 按兼容方式读（缺省即默认），但绝不把它当"已知版本"改写；上层负责先备份原档
		return {"ok": true, "mode": "future", "err": "存档版本 %d 高于本程序 %d" % [from, CURRENT_VERSION],
			"data": raw.duplicate(true), "from": from, "to": from, "steps": []}
	var mig := migrate(raw)
	if not bool(mig["ok"]):
		return {"ok": false, "mode": "invalid", "err": String(mig["err"]), "data": raw,
			"from": from, "to": from, "steps": []}
	var v := validate(mig["data"], now_sec)
	if not bool(v["ok"]):
		return {"ok": false, "mode": "invalid", "err": String(v["err"]), "data": mig["data"],
			"from": from, "to": int(mig["to"]), "steps": mig["steps"]}
	var mode := "migrated" if from < CURRENT_VERSION else "current"
	return {"ok": true, "mode": mode, "err": String(mig["err"]), "data": mig["data"],
		"from": from, "to": int(mig["to"]), "steps": mig["steps"]}


## 导入路径用：严格。版本闸门 + 迁移 + 校验任一不过就拒绝，调用方保持原档不动。
## 返回 { ok, err, text, from, to, steps }
static func import_payload(text: String, now_sec: int) -> Dictionary:
	var j := JSON.new()
	if j.parse(text) != OK or not (j.data is Dictionary):
		return {"ok": false, "err": "存档码不是合法的 JSON 对象", "text": "", "from": -1, "to": -1, "steps": []}
	var raw := j.data as Dictionary
	if is_future(raw):
		return {"ok": false,
			"err": "存档版本 %d 来自更新的游戏版本（本程序最高 %d），已拒绝导入；你的当前存档未改动"
				% [version_of(raw), CURRENT_VERSION],
			"text": "", "from": version_of(raw), "to": -1, "steps": []}
	var res := load_payload(raw, now_sec)
	if not bool(res["ok"]):
		return {"ok": false, "err": String(res["err"]), "text": "", "from": int(res["from"]),
			"to": -1, "steps": []}
	return {"ok": true, "err": "", "text": JSON.stringify(res["data"], "\t"),
		"from": int(res["from"]), "to": int(res["to"]), "steps": res["steps"]}


# ---------- 落盘：备份 + 临时文件 + 替换 ----------

## 把 path 现有内容复制成带时间戳的备份，并按 BACKUP_KEEP 修剪旧备份。
## 返回新建备份的路径（没有原档则返回空串）。
static func backup_file(path: String, stamp: int, keep := BACKUP_KEEP) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var src := FileAccess.open(path, FileAccess.READ)
	if src == null:
		return ""
	var text := src.get_as_text()
	src.close()
	var dir := path.get_base_dir()
	var base := path.get_file().get_basename()
	var bpath := "%s/%s_backup_%d.json" % [dir, base, stamp]
	var f := FileAccess.open(bpath, FileAccess.WRITE)
	if f == null:
		push_error("备份写入失败：%s" % bpath)
		return ""
	f.store_string(text)
	f.close()
	# 修剪：按文件名里的时间戳排序，保留最新 keep 份
	var names: Array = []
	var d := DirAccess.open(dir)
	if d != null:
		for n in d.get_files():
			if String(n).begins_with("%s_backup_" % base) and String(n).ends_with(".json"):
				names.append(String(n))
	names.sort()
	while names.size() > keep:
		d.remove(names[0])
		names.remove_at(0)
	return bpath


## 安全写盘（R-04）：写临时 → 回读校验 → 备份上一份有效档 → 就地替换 → 失败回滚。
##
## 为什么不能直接 `FileAccess.open(path, WRITE)`：那是先把唯一存档清空再重写，
## 写到一半被杀进程 / 磁盘出错，下次启动就没有可读档。这里保证任何时刻磁盘上
## 至少有一份完整有效的档：
##   1) 先把整份文本写进 <path>.tmp，回读逐字符比对，并要求它是合法 JSON 对象；
##   2) 上一份主档已存在则先做时间戳备份（保留 BACKUP_KEEP 份）——这就是"上一份有效档"；
##   3) 替换用"先把旧档改名成 .prev、再把 .tmp 改名为主档"；任何一步失败都把 .prev 改回来。
##      （旧实现在删除与重命名之间有一个"没有主档"的窗口，正是 R-04 指出的问题。）
## backup=false 时不做时间戳备份（导入路径已自行备份），但回滚机制照旧。
## 返回 { ok, err, backup, path }。
static func save_text(path: String, text: String, stamp: int, backup := true) -> Dictionary:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _wfail("临时文件写入失败：%s" % tmp)
	f.store_string(text)
	f.close()
	var g := FileAccess.open(tmp, FileAccess.READ)
	if g == null:
		_remove_quiet(tmp)
		return _wfail("临时文件回读失败，未替换原档")
	# 比字符串**不能**比字节数：存档里有中文（昵称/性别），UTF-8 字节数 != 字符数
	var echo := g.get_as_text()
	g.close()
	if echo != text:
		_remove_quiet(tmp)
		return _wfail("临时文件校验失败（回读内容不一致），未替换原档")
	var parsed: Variant = _parse_silent(echo)
	if not (parsed is Dictionary) or version_of(parsed as Dictionary) > CURRENT_VERSION:
		_remove_quiet(tmp)
		return _wfail("存档内容校验失败（不是合法 JSON 对象或版本过高），未替换原档")
	var da := DirAccess.open(path.get_base_dir())
	if da == null:
		_remove_quiet(tmp)
		return _wfail("无法打开存档目录")
	var had_main := FileAccess.file_exists(path)
	var bak := ""
	if had_main and backup:
		bak = backup_file(path, stamp)
	var prev := path + ".prev"
	_remove_quiet(prev)
	if had_main:
		var e0 := da.rename(path.get_file(), prev.get_file())
		if e0 != OK:
			_remove_quiet(tmp)
			var r0 := _wfail("无法让出主档位置（rename %d），原档保持不变" % e0)
			r0["backup"] = bak
			return r0
	var e2 := da.rename(tmp.get_file(), path.get_file())
	if e2 != OK:
		# 回滚：把上一份有效档放回主档位置，绝不留"没有主档"的状态
		if had_main:
			da.rename(prev.get_file(), path.get_file())
		_remove_quiet(tmp)
		var r2 := _wfail("替换失败（rename %d），已回滚到上一份存档" % e2)
		r2["backup"] = bak
		return r2
	_remove_quiet(prev)
	return {"ok": true, "err": "", "backup": bak, "path": path}


## 兼容旧名：导入路径先用 backup_file 备份，再调这里替换（不重复备份）。
static func write_text_atomic(path: String, text: String) -> Dictionary:
	return save_text(path, text, int(Time.get_unix_time_from_system()), false)


static func _wfail(err: String) -> Dictionary:
	return {"ok": false, "err": err, "backup": "", "path": ""}


## 静默删除（清理临时/回滚文件用；不存在不算错）
static func _remove_quiet(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 已有备份路径，按时间戳**从新到旧**排序，最多 keep 份（没有返回空数组）。
static func backup_paths(path: String, keep := BACKUP_KEEP) -> Array:
	var dir := path.get_base_dir()
	var prefix := "%s_backup_" % path.get_file().get_basename()
	var d := DirAccess.open(dir)
	if d == null:
		return []
	var rows: Array = []
	for n in d.get_files():
		var nm := String(n)
		if not (nm.begins_with(prefix) and nm.ends_with(".json")):
			continue
		var ts := nm.substr(prefix.length())
		ts = ts.substr(0, ts.length() - ".json".length())
		rows.append({"path": "%s/%s" % [dir, nm], "ts": int(ts)})
	rows.sort_custom(func(a, b): return int((a as Dictionary)["ts"]) > int((b as Dictionary)["ts"]))
	var out: Array = []
	for r in rows:
		if out.size() >= keep:
			break
		out.append(String((r as Dictionary)["path"]))
	return out


## 启动恢复（R-04）：选择要读的档，返回 { path, source, res }，source ∈ main/tmp/prev/backup/none/unreadable。
##
## 规则（关键：**主档缺失不等于新档**）：
##   * 主档存在且是合法 JSON 对象 → 按主档走（语义校验结果由上层决定：future 可读 / invalid 锁写）；
##   * 主档存在但连 JSON 都不是 → 先看 .tmp/.prev（那是我们自己中断替换留下的残档），
##     但不拿长期备份去顶掉内存里的现有进度（保持"坏档不静默改写玩家档"的既有语义）；
##   * 主档缺失 → 依次试 .tmp / .prev / 最近备份，读出可用的那一个；
##   * 全都没有 → none（这才是真正的新档）。
static func pick_readable(path: String, now_sec: int) -> Dictionary:
	if FileAccess.file_exists(path):
		var mt := _read_text(path)
		var mp: Variant = _parse_silent(mt)
		if mp is Dictionary:
			return {"path": path, "source": "main",
				"res": load_payload(mp as Dictionary, now_sec)}
		# 主档不可解析：只认同一次保存留下的中间文件，不碰长期备份
		var recovered := _first_readable([path + ".tmp", path + ".prev"], now_sec)
		if String(recovered.get("source", "")) != "none":
			return recovered
		return {"path": "", "source": "unreadable", "res": {}}
	var cands: Array = []
	for extra in [path + ".tmp", path + ".prev"]:
		cands.append({"path": extra, "source": "tmp" if extra.ends_with(".tmp") else "prev"})
	for b in backup_paths(path):
		cands.append({"path": b, "source": "backup"})
	return _first_readable_paths(cands, now_sec)


static func _first_readable(paths: Array, now_sec: int) -> Dictionary:
	var cands: Array = []
	for p in paths:
		var ps := String(p)
		cands.append({"path": ps, "source": "tmp" if ps.ends_with(".tmp") else "prev"})
	return _first_readable_paths(cands, now_sec)


static func _first_readable_paths(cands: Array, now_sec: int) -> Dictionary:
	for c in cands:
		var cp := String((c as Dictionary)["path"])
		if not FileAccess.file_exists(cp):
			continue
		var parsed: Variant = _parse_silent(_read_text(cp))
		if not (parsed is Dictionary):
			continue
		var res := load_payload(parsed as Dictionary, now_sec)
		if bool(res.get("ok", false)):
			return {"path": cp, "source": String((c as Dictionary)["source"]), "res": res}
	return {"path": "", "source": "none", "res": {}}


static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


## 静默解析（与 G.json_parse_silent 同义）：失败返回 null，**不打印引擎错误**。
## 读到的存档可能是被手改/写坏过的乱码 —— 那是我们的校验该说话，不该由引擎刷红字。
static func _parse_silent(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data
