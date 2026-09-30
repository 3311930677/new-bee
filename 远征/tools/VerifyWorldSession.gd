# VerifyWorldSession.gd —— P02：世界会话（刷点/遭遇锁/刷新/安全位）、主线事件推进、奖励事务去重。
#
# 覆盖 docs/plans/2026-09-28-p02-world-session-design.md §4 的崩溃点矩阵 7 行 +
#      P03 设计 §6 的状态机 3 行（共 10 行）：
#   1 开战前 / 2 战斗中 / 3 结算前 / 4 结算后未返回地图 / 5 切图写档中 / 6 交付任务物时 / 7 满包发奖时
#   8 状态机顺序与非法转移不落盘 / 9 result_id 确定性与 settle_result 幂等 / 10 fled、failed 为终态
# 合成夹具，不写真实 user://save.json（SAVE_PATH 指到 res://tools/_logs/）。
extends Node

var _fails := 0


## 假宿主：只是满足 RewardLedger 的 host 约定（wallet/items/prog + gain_exp/grant_item/inv_grant_equip），
## 这样事务语义可以在不启动整局的情况下被直接测。P04 起加装备容器（实例 / 背包 / 待领取箱）。
class FakeHost:
	var wallet: Dictionary = {}
	var items: Dictionary = {}
	var prog: Dictionary = {}
	var inv: Dictionary = {"instances": [], "pending": [], "next_uid": 1}
	var equip_persist_requested := false
	var force_equip_failure := false

	func gain_exp(amount: int, _persist := true) -> int:
		prog["exp"] = int(prog.get("exp", 0)) + amount
		return 0

	func grant_item(id: String, n: int, _persist := true) -> void:
		items[id] = int(items.get(id, 0)) + n

	## 装备掉落：与 G.inv_grant_equip 同一契约（满包进待领取箱，绝不丢物）
	func inv_grant_equip(spec: Dictionary, persist := true) -> Dictionary:
		equip_persist_requested = persist
		if force_equip_failure:
			return {"ok": false, "err": "注入的发放失败"}
		var tpl_id := String(spec.get("tpl", ""))
		var tpl := _tpl(tpl_id)
		if tpl.is_empty():
			return {"ok": false, "err": "未知装备模板：%s" % tpl_id}
		var rarity := int(spec.get("rarity", tpl.get("rarity", 1)))
		var n := maxi(1, int(spec.get("n", 1)))
		var cfg := TableCache.equip_config()
		var to_pending := false
		for i in n:
			var r := Inventory.add(inv, cfg, {}, Inventory.new_instance(inv, tpl, rarity))
			if bool(r.get("to_pending", false)):
				to_pending = true
		return {"ok": true, "to_pending": to_pending, "n": n}

	func _tpl(tpl_id: String) -> Dictionary:
		for t in (TableCache.equip_config().get("templates", []) as Array):
			var td := t as Dictionary
			if String(td.get("id", "")) == tpl_id:
				return td
		return {}

	## R-07：RewardLedger 预校验装备奖励用的只读契约（与 G.equip_tpl / G.equip_cfg 同义）
	func equip_tpl(tpl_id: String) -> Dictionary:
		return _tpl(tpl_id)

	func equip_cfg() -> Dictionary:
		return TableCache.equip_config()

	func ledger() -> Dictionary:
		var l: Variant = prog.get("ledger", {})
		if not (l is Dictionary):
			l = {"applied": []}
			prog["ledger"] = l
		return RewardLedger.ensure(l as Dictionary)


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_world_session.json"
	G.save_locked = false
	_run()
	if _fails == 0:
		print("WORLD_SESSION_OK matrix=10")
	else:
		print("WORLD_SESSION_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _host(gold := 0, exp := 0) -> FakeHost:
	var h := FakeHost.new()
	h.wallet = {"gold": gold, "expedition": 0, "soul": 0, "honor": 0}
	h.items = {}
	h.prog = {"exp": exp, "ledger": {"applied": []}}
	return h


## 模拟「读档后重放一次结算」：commit 成功才发奖，与 MapScene._on_battle_end 同一判定。
func _settle_once(state: Dictionary, ctx: Dictionary, host: FakeHost, txid: String, gold: int) -> Dictionary:
	var settled := WorldSession.commit(state, ctx)
	var applied := false
	if settled:
		var tx := RewardLedger.make(txid, {}, {"gold": gold}, {})
		applied = bool(RewardLedger.apply(tx, host.ledger(), host).get("applied", false))
	return {"settled": settled, "applied": applied}


## 模拟 P03 的唯一结算入口：settle_result 返回 true 才发奖（result_id 即去重键）。
func _settle_result_once(state: Dictionary, ctx: Dictionary, host: FakeHost,
		result: String, gold: int) -> Dictionary:
	var settled := WorldSession.settle_result(state, ctx, result)
	var applied := false
	if settled:
		var tx := RewardLedger.make(WorldSession.result_id(ctx, result), {}, {"gold": gold}, {})
		applied = bool(RewardLedger.apply(tx, host.ledger(), host).get("applied", false))
	return {"settled": settled, "applied": applied}


func _run() -> void:
	_test_spawn_ids()
	_test_lifecycle()
	_test_crash_matrix()
	_test_state_machine()
	_test_result_idempotent()
	_test_terminal_states()
	_test_quest_plan()
	_test_ledger()
	_test_normalize()
	_test_g_integration()


# ---------- 唯一刷点与遭遇 ID ----------

func _test_spawn_ids() -> void:
	_check(WorldSession.spawn_id("lorin_wilds", 3) == "lorin_wilds:3", "刷点 ID 形状应稳定")
	_check(WorldSession.spawn_id("lorin_wilds", 0) != WorldSession.spawn_id("maple_road", 0),
		"不同地图的同号刷点必须有不同 ID（旧实现用 str(idx) 会撞键）")
	var a := WorldSession.new_encounter("lorin_wilds", 2, Vector2(82, 970), "mon_zombie", 7,
		Vector2(480, 930), "", 0, 4242)
	var b := WorldSession.new_encounter("lorin_wilds", 2, Vector2(82, 970), "mon_zombie", 7,
		Vector2(480, 930), "", 0, 4242)
	_check(String(a["encounter_id"]) == String(b["encounter_id"]), "同一次接战的 encounter_id 必须确定")
	_check(String(a["spawn_id"]) == "lorin_wilds:2", "遭遇应记录全局唯一刷点")
	_check(String(a["status"]) == WorldSession.ST_LOCKED, "新遭遇应从 locked 开始")
	_check((a["return_position"] as Array) == [480, 930], "遭遇应记住撤退要回到的安全位")


# ---------- 遭遇生命周期 ----------

func _test_lifecycle() -> void:
	var state := {}
	var ctx := WorldSession.new_encounter("lorin_wilds", 0, Vector2(82, 560), "mon_zombie", 7,
		Vector2(480, 930), "", 0, 1)
	var eid := String(ctx["encounter_id"])
	_check(not WorldSession.is_settled(state, eid), "未结算不应算 settled")
	_check(WorldSession.commit(state, ctx), "首次 commit 应结算")
	_check(WorldSession.is_settled(state, eid), "commit 后应标记 committed")
	_check(not WorldSession.commit(state, ctx), "重复 commit 必须返回 false（不得重复发奖）")
	var fled := WorldSession.new_encounter("maple_road", 1, Vector2(750, 470), "mon_wolf", 6,
		Vector2(480, 1040), "", 0, 2)
	WorldSession.record(state, fled, WorldSession.ST_FLED)
	_check(not WorldSession.commit(state, fled), "已撤退的遭遇不应再被 commit 发奖")


# ---------- 崩溃点矩阵 ----------

func _test_crash_matrix() -> void:
	var ctx := WorldSession.new_encounter("lorin_wilds", 0, Vector2(82, 560), "mon_zombie", 7,
		Vector2(480, 930), "", 0, 11)
	var eid := String(ctx["encounter_id"])
	var txid := "enc|" + eid
	var dangers := [Vector2(82, 560), Vector2(878, 970)]
	var extent := Vector2(960, 1248)
	var portal := Vector2(480, 96)

	# --- 行 1：开战前（刚接触，未写档）---
	var s1 := {}
	_check(s1.is_empty(), "开战前不应留下任何遭遇记录")
	var safe := WorldSession.safe_position(Vector2(82, 560), dangers, portal, extent)
	_check(safe.distance_to(Vector2(82, 560)) >= WorldSession.DANGER_RADIUS - 0.01,
		"读档落在怪物身上时必须被推到危险半径外，实为距离 %.1f" % safe.distance_to(Vector2(82, 560)))
	_check(safe.distance_to(portal) >= WorldSession.PORTAL_RADIUS - 0.01, "安全位不该压在传送阵上")
	_check(WorldSession.safe_position(Vector2(82, 560), dangers, portal, extent) == safe,
		"安全位算法必须确定性（同输入同输出）")
	var clamped := WorldSession.safe_position(Vector2(10000, 10000), dangers, Vector2.ZERO, extent)
	_check(clamped == Vector2(912, 1200), "安全位必须被夹回地图边界内，实为 %s" % str(clamped))

	# --- 行 2：战斗中（status=battle，遇敌不写档）---
	var s2 := {}
	WorldSession.record(s2, ctx, WorldSession.ST_BATTLE)
	var h2 := _host(0)
	var r2a := _settle_once(s2, ctx, h2, txid, 28)
	var r2b := _settle_once(s2, ctx, h2, txid, 28)
	_check(bool(r2a["settled"]) and bool(r2a["applied"]), "战斗中崩溃重载后应能补结算一次")
	_check(not bool(r2b["settled"]) and not bool(r2b["applied"]), "同一次遭遇不得二次结算")
	_check(int(h2.wallet["gold"]) == 28, "战斗中崩溃重载不得重复发金，实为 %d" % int(h2.wallet["gold"]))

	# --- 行 3：结算前（胜利动画中，尚未 commit）---
	var s3 := {}
	WorldSession.record(s3, ctx, WorldSession.ST_BATTLE)
	var h3 := _host(0)
	_check(not WorldSession.is_settled(s3, eid), "结算前重载不应出现已结算状态")
	_check((h3.ledger()["applied"] as Array).is_empty(), "结算前不得发放任何奖励")
	var r3 := _settle_once(s3, ctx, h3, txid, 28)
	_check(bool(r3["applied"]) and int(h3.wallet["gold"]) == 28, "补结算应恰好发一次奖")

	# --- 行 4：结算后未返回地图（status=committed，战利与刷新同一次写档）---
	var s4 := {}
	var ctx4 := WorldSession.new_encounter("lorin_wilds", 1, Vector2(878, 565), "mon_zombie", 7,
		Vector2(480, 930), "", 0, 21)
	var eid4 := String(ctx4["encounter_id"])
	var txid4 := "enc|" + eid4
	WorldSession.commit(s4, ctx4)
	WorldSession.mark_spawn_defeated(s4, "lorin_wilds", 1, 1789900000.0)
	var h4 := _host(0)
	var first := RewardLedger.apply(RewardLedger.make(txid4, {}, {"gold": 28}, {}), h4.ledger(), h4)
	_check(bool(first["applied"]) and int(h4.wallet["gold"]) == 28, "首次结算应发金")
	var r4 := _settle_once(s4, ctx4, h4, txid4, 28)
	_check(not bool(r4["settled"]) and not bool(r4["applied"]), "结算后崩溃重载不得再结算")
	_check(int(h4.wallet["gold"]) == 28, "结算后崩溃重载不得重复发金，实为 %d" % int(h4.wallet["gold"]))
	_check(WorldSession.spawn_respawn_at(s4, "lorin_wilds", 1) == 1789900000.0,
		"战利落袋时应同时记下刷新时间")
	_check(float((s4["respawn_at"] as Dictionary).get("1", 0.0)) == 1789900000.0,
		"刷新时间要同时写进本图 respawn_at 快照（旧读法仍看它）")

	# --- 行 5：切图写档中（先 _persist 再写档再切场景）---
	var before := WorldSession.normalize_state({"map_id": "broken_slope", "layout_version": 2,
		"position": [480, 1152]})
	_check(String(before["map_id"]) == "broken_slope" and (before["position"] as Array).size() == 2,
		"切图前崩溃应保留旧图的完整状态")
	var target := (before as Dictionary).duplicate(true)
	target["map_id"] = "stele_cavern"
	target["layout_version"] = 1
	target["position"] = [480, 1050]
	var moved := WorldSession.normalize_state(target)
	_check(String(moved["map_id"]) == "stele_cavern" and (moved["position"] as Array) == [480, 1050],
		"切图后崩溃应落到新图的完整状态（不允许半写档）")

	# --- 行 7：满包发奖（装备掉落进待领取箱；任务物走独立 items 键、不占格，仍照常入账）---
	var h7 := _host(0)
	var cap7 := Inventory.capacity(TableCache.equip_config())
	h7.inv_grant_equip({"tpl": "tpl_armor_basic", "rarity": 1, "n": cap7})
	_check(Inventory.count(h7.inv, {}) == cap7, "前置：背包应已填满（%d 格）" % cap7)
	h7.items["stele_fragment"] = 0
	# 一次事务同时发任务物与装备：装备因满包进待领取箱，任务物照常入账 —— 整单不得失败、不得丢物
	var applied7 := RewardLedger.apply(
		RewardLedger.make("story|s10|mix", {},
			{"item:stele_fragment": 1, "equip:tpl_sword_wolf:2": 1}, {}), h7.ledger(), h7)
	_check(bool(applied7["applied"]), "满包时事务仍应成功应用，不得整单失败（%s）" % String(applied7["err"]))
	_check(int(h7.items["stele_fragment"]) == 1,
		"背包塞满时任务物也必须照常入账，不得静默丢物")
	_check((h7.inv["instances"] as Array).size() == cap7,
		"满包时装备掉落不得挤进背包，实为 %d" % (h7.inv["instances"] as Array).size())
	_check((h7.inv["pending"] as Array).size() == 1,
		"满包时的装备掉落必须进待领取箱，实为 %d" % (h7.inv["pending"] as Array).size())
	_check(String(((h7.inv["pending"] as Array)[0] as Dictionary).get("tpl", "")) == "tpl_sword_wolf",
		"待领取箱里应是刚掉落的那件装备")
	_check(not h7.equip_persist_requested,
		"装备奖励必须等到账本记录事务 ID 后统一写盘，不得在发放回调里提前保存")


# ---------- 行 8：完整状态机顺序 + 非法转移不落盘（P03） ----------

func _test_state_machine() -> void:
	var ctx := WorldSession.new_encounter("lorin_wilds", 0, Vector2(82, 560), "mon_zombie", 7,
		Vector2(480, 930), "", 0, 31)
	var eid := String(ctx["encounter_id"])
	var st := {}
	_check(WorldSession.status_of(st, eid) == "", "全新的世界状态里这场遭遇应还没有记录")

	for step in [WorldSession.ST_APPROACH, WorldSession.ST_LOCKED, WorldSession.ST_BATTLE,
			WorldSession.ST_RESULT_PENDING, WorldSession.ST_COMMITTED, WorldSession.ST_RETURN]:
		var r := WorldSession.advance(st, ctx, String(step))
		_check(bool(r["ok"]), "合法转移 %s → %s 应成功，实为 %s"
			% [String(r["from"]), String(step), String(r["reason"])])
		_check(WorldSession.status_of(st, eid) == String(step),
			"转移 %s 后状态应落盘，实为 %s" % [String(step), WorldSession.status_of(st, eid)])

	# 非法转移：locked → committed（跳过 battle/result_pending）必须被拒且不落盘
	var st2 := {}
	WorldSession.advance(st2, ctx, WorldSession.ST_APPROACH)
	WorldSession.advance(st2, ctx, WorldSession.ST_LOCKED)
	var bad := WorldSession.advance(st2, ctx, WorldSession.ST_COMMITTED)
	_check(not bool(bad["ok"]) and String(bad["reason"]) == "bad_transition",
		"locked → committed 应判 bad_transition，实为 %s" % String(bad["reason"]))
	_check(WorldSession.status_of(st2, eid) == WorldSession.ST_LOCKED,
		"非法转移不得改写状态，实为 %s" % WorldSession.status_of(st2, eid))
	# 空记录只能先进 approach：直接 locked 也是非法
	var st3 := {}
	var bad3 := WorldSession.advance(st3, ctx, WorldSession.ST_LOCKED)
	_check(not bool(bad3["ok"]) and WorldSession.status_of(st3, eid) == "",
		"首次推进只能进 approach，不能直接 locked")


# ---------- 行 9：result_id 确定性与 settle_result 幂等（P03） ----------

func _test_result_idempotent() -> void:
	var ctx := WorldSession.new_encounter("lorin_wilds", 1, Vector2(878, 565), "mon_zombie", 7,
		Vector2(480, 930), "", 0, 32)
	var eid := String(ctx["encounter_id"])
	var rid := WorldSession.result_id(ctx, "victory")
	_check(rid == WorldSession.result_id(ctx, "victory"), "result_id 必须确定性（同输入同输出）")
	_check(rid.contains(eid) and rid.ends_with("victory"), "result_id 应含遭遇 ID 与结果，实为 %s" % rid)

	var st := {}
	var host := _host(0)
	var first := _settle_result_once(st, ctx, host, "victory", 33)
	var second := _settle_result_once(st, ctx, host, "victory", 33)
	_check(bool(first["settled"]) and bool(first["applied"]), "首次 settle_result 应结算并发奖一次")
	_check(not bool(second["settled"]) and not bool(second["applied"]),
		"同一 result_id 二次上报不得再结算")
	_check(int(host.wallet["gold"]) == 33, "重复上报不得重复发金，实为 %d" % int(host.wallet["gold"]))
	_check(WorldSession.result_of(st, eid) == "victory", "结算后应记下 result")
	_check(String((WorldSession.encounters(st)[eid] as Dictionary).get("result_id", "")) == rid,
		"结算后应记下 result_id 供重放去重")

	# 合并写入：committed → return 不能把 result / result_id 抹掉
	var adv := WorldSession.advance(st, ctx, WorldSession.ST_RETURN)
	_check(bool(adv["ok"]) and WorldSession.result_of(st, eid) == "victory",
		"committed → return 后结果必须仍在（record 是合并写入而非整行覆盖）")
	_check(String((WorldSession.encounters(st)[eid] as Dictionary).get("result_id", "")) == rid,
		"committed → return 后 result_id 也必须仍在")


# ---------- 行 10：fled / failed 是终态（P03） ----------

func _test_terminal_states() -> void:
	var fled := WorldSession.new_encounter("maple_road", 1, Vector2(750, 470), "mon_wolf", 6,
		Vector2(480, 1040), "", 0, 33)
	var fid := String(fled["encounter_id"])
	var sf := {}
	WorldSession.record(sf, fled, WorldSession.ST_FLED)
	_check(WorldSession.is_terminal(WorldSession.ST_FLED), "fled 必须是终态")
	_check(not WorldSession.commit(sf, fled), "已撤退不得再 commit 发奖")
	_check(not WorldSession.settle_result(sf, fled, "victory"), "已撤退不得再结算")
	_check(WorldSession.status_of(sf, fid) == WorldSession.ST_FLED, "被拒结算不得改写状态")

	var failed := WorldSession.new_encounter("stele_cavern", 0, Vector2(480, 1050),
		"mon_stele_warden", 12, Vector2(480, 1150), "", 0, 34)
	var aid := String(failed["encounter_id"])
	var sa := {}
	WorldSession.record(sa, failed, WorldSession.ST_FAILED)
	_check(WorldSession.is_terminal(WorldSession.ST_FAILED), "failed 必须是终态")
	_check(not WorldSession.commit(sa, failed) and not WorldSession.settle_result(sa, failed, "victory"),
		"已战败不得再发奖")
	var bad := WorldSession.advance(sa, failed, WorldSession.ST_RETURN)
	_check(not bool(bad["ok"]) and String(bad["reason"]) == "bad_transition",
		"failed 是终态，不应再能推进，实为 %s" % String(bad["reason"]))
	_check(WorldSession.status_of(sa, aid) == WorldSession.ST_FAILED, "被拒推进不得改写状态")
	_check(not WorldSession.is_terminal(WorldSession.ST_BATTLE), "battle 不是终态")


# ---------- 主线推进（纯计划函数） ----------

func _test_quest_plan() -> void:
	var rows: Array = TableCache.story_quests_config().get("steps", [])
	_check(rows.size() >= 12 and String((rows[11] as Dictionary).get("id", "")) == "s12",
		"s01–s12 主线步骤不得被重置或删减，实为 %d" % rows.size())

	var p0 := QuestService.plan({"step": "", "done": [], "goals": {}}, rows,
		QuestService.world_event("talk", "npc_steward", "lorin_wilds"), {})
	_check(String(p0["reason"]) == "no_step", "空 step 应判 no_step")
	var p1 := QuestService.plan({"step": "s01", "done": [], "goals": {}}, rows,
		QuestService.world_event("defeat", "npc_steward", "lorin_wilds"), {})
	_check(String(p1["reason"]) == "no_match", "事件类型不符应判 no_match，实为 %s" % String(p1["reason"]))
	var p2 := QuestService.plan({"step": "s01", "done": [], "goals": {}}, rows,
		QuestService.world_event("talk", "npc_steward", "maple_road"), {})
	_check(String(p2["reason"]) == "no_match", "地图不符应判 no_match")

	var st := {"step": "s01", "done": [], "goals": {}}
	var p3 := QuestService.plan(st, rows, QuestService.world_event("talk", "npc_steward", "lorin_wilds"), {})
	_check(bool(p3["ok"]) and String(p3["step_id"]) == "s01", "s01 与闻叔交谈应推进")
	_check(String((p3["next_state"] as Dictionary)["step"]) == "s02", "s01 完成后应指向 s02")
	_check(not QuestService.is_done(st, "s01") and (st["done"] as Array).is_empty(),
		"plan 是纯函数，不得就地写传入状态")

	# 重复上报有两种落点，都必须不发奖：
	#   ① 当前步已完成、还没推进 → duplicate；② 已推进到下一步 → 旧事件不再匹配 → no_match
	var p4 := QuestService.plan({"step": "s01", "done": ["s01"]}, rows,
		QuestService.world_event("talk", "npc_steward", "lorin_wilds"), {})
	_check(String(p4["reason"]) == "duplicate", "当前步已完成时应判 duplicate，实为 %s" % String(p4["reason"]))
	var p4b := QuestService.plan(p3["next_state"], rows,
		QuestService.world_event("talk", "npc_steward", "lorin_wilds"), {})
	_check(String(p4b["reason"]) == "no_match", "推进到下一步后旧事件应判 no_match，实为 %s" % String(p4b["reason"]))

	var s11 := {"step": "s11", "done": [], "goals": {}}
	var e11 := QuestService.world_event("craft", "npc_smith", "lorin_wilds",
		"player", {"method": "forge"})
	var p5 := QuestService.plan(s11, rows, e11, {})
	_check(String(p5["reason"]) == "missing_item", "缺任务物应判 missing_item，实为 %s" % String(p5["reason"]))
	var p6 := QuestService.plan(s11, rows, e11, {"stele_fragment": 1, "refine_stone": 2})
	_check(bool(p6["ok"]) and String(p6["consume_item"]) == "stele_fragment"
		and int((p6["extra_costs"] as Dictionary).get("item:refine_stone", 0)) == 2,
		"材料齐备时 s11 应声明碑片与锻合材料的同笔消耗")

	_check(QuestService.world_event("talk", "npc_steward", "lorin_wilds")["event_id"] == "talk|lorin_wilds|npc_steward",
		"WorldEvent.event_id 必须是确定性拼装")
	_check(QuestService.done_ids({"step": "s02", "done": ["s01"]}) == ["s01"], "goals 缺失时应回落到旧 done[]")


# ---------- 奖励事务 ----------

func _test_ledger() -> void:
	var host := _host(100)
	var txid := RewardLedger.tx_id("story", "s01", "talk|lorin_wilds|npc_steward")
	var tx := RewardLedger.make(txid, {"gold": 10},
		{"gold": 40, "exp": 15, "item:stele_fragment": 1, "flag:met_steward": true}, {})
	var a := RewardLedger.apply(tx, host.ledger(), host)
	_check(bool(a["applied"]) and not bool(a["duplicate"]), "首次应用应落地")
	_check(int(host.wallet["gold"]) == 130 and int(host.prog["exp"]) == 15,
		"应净扣 10 金、加 40 金、加 15 经验（实为金 %d / 经验 %d）"
		% [int(host.wallet["gold"]), int(host.prog["exp"])])
	_check(int(host.items.get("stele_fragment", 0)) == 1, "物件奖励应入账")
	_check(bool((host.prog["flags"] as Dictionary).get("met_steward", false)), "世界旗标应写入 prog.flags")
	var b := RewardLedger.apply(tx, host.ledger(), host)
	_check(bool(b["duplicate"]) and not bool(b["applied"]), "同一 transaction_id 再应用应判重复")
	_check(int(host.wallet["gold"]) == 130 and int(host.items.get("stele_fragment", 0)) == 1,
		"重复应用不得再改数值")

	var poor := _host(5)
	var tx2 := RewardLedger.make("buy|shield", {"gold": 50}, {"item:stele_fragment": 1}, {})
	var c := RewardLedger.apply(tx2, poor.ledger(), poor)
	_check(not bool(c["ok"]) and not bool(c["applied"]), "付不起时应整体拒绝")
	_check(int(poor.wallet["gold"]) == 5 and int(poor.items.get("stele_fragment", 0)) == 0,
		"拒绝时不得扣款也不得发物（失败零副作用）")
	_check(not RewardLedger.applied(poor.ledger(), "buy|shield"), "被拒的事务不得写进去重表")

	# --- R-07：装备奖励的应用前预校验 ---
	# 1) 未知模板：整单拒绝、零副作用、不登记事务 ID（旧实现会把金币扣掉却一件装备不发）
	var badh := _host(100)
	var badt := RewardLedger.make("loot|unknown", {"gold": 10},
		{"gold": 5, "equip:tpl_not_exist:2": 1}, {})
	var bad := RewardLedger.apply(badt, badh.ledger(), badh)
	_check(not bool(bad["ok"]) and not bool(bad["applied"]),
		"未知装备模板的奖励必须整体拒绝，实为 ok=%s" % String(bad["err"]))
	_check(int(badh.wallet["gold"]) == 100 and (badh.inv["instances"] as Array).is_empty(),
		"被拒的装备奖励不得扣款、不得发放其他奖励（失败零副作用）")
	_check(not RewardLedger.applied(badh.ledger(), "loot|unknown"),
		"被拒的装备事务不得写进去重表（否则这笔奖励永久发不出来）")

	# 2) 稀有度不在表中：同样整体拒绝且不扣款
	var rh := _host(100)
	var rt := RewardLedger.make("loot|badrarity", {"gold": 10}, {"equip:tpl_sword_wolf:99": 1}, {})
	var rr := RewardLedger.apply(rt, rh.ledger(), rh)
	_check(not bool(rr["ok"]) and int(rh.wallet["gold"]) == 100,
		"稀有度非法的装备奖励必须整体拒绝且不扣款，实为 ok=%s" % String(rr["err"]))

	# 3) 合法装备 + 金币混合：照常落地一次；重复上报不复发
	var okh := _host(100)
	var okt := RewardLedger.make("loot|ok", {"gold": 10},
		{"gold": 5, "equip:tpl_sword_wolf:2": 1}, {})
	var ok1 := RewardLedger.apply(okt, okh.ledger(), okh)
	_check(bool(ok1["applied"]) and int(okh.wallet["gold"]) == 95,
		"合法装备奖励应随整单落地（净扣 10 加 5 = 95，实为 %d）" % int(okh.wallet["gold"]))
	_check((okh.inv["instances"] as Array).size() == 1, "合法装备奖励应发出一件实例")
	var ok2 := RewardLedger.apply(okt, okh.ledger(), okh)
	_check(bool(ok2["duplicate"]) and int(okh.wallet["gold"]) == 95
		and (okh.inv["instances"] as Array).size() == 1, "重复上报不得重复发装备/金币")
	# 预检通过后宿主仍可能拒绝发放；此前已发的经验/材料/金币和成本都要回滚。
	var cbh := _host(100)
	cbh.force_equip_failure = true
	var cbtx := RewardLedger.make("loot|callback_failed", {"gold": 10},
		{"gold": 5, "exp": 7, "item:stele_fragment": 1, "equip:tpl_sword_wolf:2": 1}, {})
	var cbr := RewardLedger.apply(cbtx, cbh.ledger(), cbh)
	_check(not bool(cbr["ok"]) and int(cbh.wallet["gold"]) == 100
		and int(cbh.prog["exp"]) == 0 and int(cbh.items.get("stele_fragment", 0)) == 0
		and (cbh.inv["instances"] as Array).is_empty()
		and not RewardLedger.applied(cbh.ledger(), "loot|callback_failed"),
		"发放回调失败后整笔事务必须零副作用")
	# JSON 数组的 2/3 稀有度会解析为 float；必掉首领池须能抽到装备。
	var drop_rng := RandomNumberGenerator.new()
	drop_rng.seed = 12345
	var boss_drop := Inventory.roll_drop(TableCache.equip_config(),
		TableCache.drops_config(), "boss", drop_rng)
	_check(not boss_drop.is_empty() and int(boss_drop.get("rarity", 0)) in [2, 3],
		"首领必掉装备池不得因 JSON 数值类型失配而抽空")


# ---------- 状态归一 ----------

func _test_normalize() -> void:
	var legacy := {"map_id": "broken_slope", "respawn_at": {"2": 1789900000.0}, "killed": [0, 3]}
	var n := WorldSession.normalize_state((legacy as Dictionary).duplicate(true))
	_check(n.get("encounters", null) is Dictionary and n.get("respawn_by_map", null) is Dictionary,
		"归一化应补出 encounters / respawn_by_map")
	_check(WorldSession.spawn_respawn_at(n, "broken_slope", 2) == 1789900000.0,
		"归一化后应仍读得到旧单图刷新时间")
	_check(JSON.stringify(WorldSession.normalize_state(n)) == JSON.stringify(n), "世界状态归一必须幂等")

	var cross := WorldSession.normalize_state({"map_id": "lorin_wilds"})
	WorldSession.mark_spawn_defeated(cross, "lorin_wilds", 0, 111.0)
	_check(not (cross["respawn_by_map"] as Dictionary).has("maple_road"),
		"一张图的刷新时间不得写进另一张图的刷点表")
	(cross["respawn_by_map"] as Dictionary)["maple_road"] = {}
	_check(WorldSession.spawn_respawn_at(cross, "maple_road", 0) == 0.0,
		"另一张图已有独立表时，不得回退读取上一张图的单图快照")

	var story := {"step": "s03", "done": ["s01", "s02"]}
	var sn := QuestService.normalize_state(story)
	_check((sn["goals"] as Dictionary).size() == 2
		and String((sn["goals"] as Dictionary)["s01"]) == "done", "旧 done[] 应映射成 goals 目标状态")
	_check(QuestService.is_done(sn, "s02"), "归一化后 is_done 应认得旧步骤")
	_check(JSON.stringify(QuestService.normalize_state(sn)) == JSON.stringify(sn), "主线状态归一必须幂等")


# ---------- G 层整合（行 6：交付任务物时） ----------

func _test_g_integration() -> void:
	G.save_locked = false
	G.prog["level"] = 5
	G.prog["exp"] = 0
	G.prog["story"] = {"step": "s01", "done": [], "goals": {}}
	G.prog["ledger"] = {"applied": []}
	G.prog["flags"] = {}
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.items = {"stele_fragment": 0}

	var events := [
		["talk", "npc_steward", "lorin_wilds"],
		["visit", "maple_road", "maple_road"],
		["defeat", "mon_wolf", "maple_road"],
		["talk", "npc_smith", "lorin_wilds"],
		["visit", "broken_slope", "broken_slope"],
		["defeat", "mon_skeleton", "broken_slope"],
		["talk", "npc_steward", "lorin_wilds"],
		["talk", "npc_scribe", "lorin_wilds"],
		["visit", "stele_cavern", "stele_cavern"],
		["defeat", "mon_stele_warden", "stele_cavern"],
	]
	for i in events.size():
		var row: Array = events[i]
		var r := G.story_event(String(row[0]), String(row[1]), String(row[2]))
		_check(String(r.get("id", "")) == "s%02d" % [i + 1],
			"第 %d 步应由对应事件推进，实为「%s」" % [i + 1, String(r.get("id", ""))])
		_check(G.story_event(String(row[0]), String(row[1]), String(row[2])).is_empty(),
			"第 %d 步同一事件重复上报不得二次结算" % [i + 1])
	_check(String(G.prog["story"]["step"]) == "s11", "走完 s01–s10 后应停在 s11")
	_check(G.item_count("stele_fragment") == 1, "s10 应发放失声碑文")
	var gold_s10 := int(G.wallet["gold"])

	# 行 6：交付任务物——扣物与推进必须成对，重复上报只结算一次
	G.items["refine_stone"] = 2
	var deliver := G.story_event("craft", "npc_smith", "lorin_wilds", true,
		{"method": "forge"})
	_check(String(deliver.get("id", "")) == "s11", "s11 交付应成功")
	_check(G.item_count("stele_fragment") == 0, "交付应扣掉碑文")
	_check(G.item_count("refine_stone") == 0, "修碑应扣掉两块精炼石")
	_check(String(G.prog["story"]["step"]) == "s12", "交付后应推进到 s12")
	var gold_s11 := int(G.wallet["gold"])
	_check(gold_s11 > gold_s10, "交付任务物应发奖")
	var again := G.story_event("craft", "npc_smith", "lorin_wilds", true,
		{"method": "forge"})
	_check(again.is_empty(), "重按 NPC 不得二次结算")
	_check(int(G.wallet["gold"]) == gold_s11 and String(G.prog["story"]["step"]) == "s12"
		and G.item_count("stele_fragment") == 0, "重复上报不得再发奖、不得再推进、不得再扣物")

	# 缺任务物：不推进、不扣物、不发奖
	G.prog["story"] = {"step": "s11", "done": [], "goals": {}}
	for id in ["s01", "s02", "s03", "s04", "s05", "s06", "s07", "s08", "s09", "s10"]:
		(G.prog["story"]["done"] as Array).append(id)
	G.items["stele_fragment"] = 0
	var gold_before := int(G.wallet["gold"])
	var miss := G.story_event("craft", "npc_smith", "lorin_wilds", true,
		{"method": "forge"})
	_check(miss.is_empty(), "缺任务物时不应推进")
	_check(String(G.prog["story"]["step"]) == "s11" and int(G.wallet["gold"]) == gold_before,
		"缺任务物时不得改动状态与钱包")

	# 账本去重表随存档落盘
	var applied_l: Array = G.prog["ledger"]["applied"]
	_check(applied_l.size() == 11, "每次主线结算都应在 ledger.applied 留去重记录，实为 %d" % applied_l.size())
	G.save_game()
	var f := FileAccess.open(G.SAVE_PATH, FileAccess.READ)
	_check(f != null, "应能写出合成存档")
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		_check(parsed is Dictionary and int((parsed as Dictionary).get("version", -1)) == SaveData.CURRENT_VERSION,
			"合成存档应写成 v%d" % SaveData.CURRENT_VERSION)
