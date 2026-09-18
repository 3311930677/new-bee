# VerifyQuests.gd —— 主城委托回归（场景模式：godot --headless --path . res://tools/VerifyQuests.tscn）
# 守：委托表完整性（发布人/种类/目标字段齐）、日刷新与跨日重刷、接取门禁、
#     三种 kind 的推进与交付（slay 靠战斗上报、clear 靠通关钩子、deliver 靠道具）、
#     奖励入账、存档往返、NPC 台词联动。
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_quests.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _baseline() -> void:
	G.prog = {"level": 5, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": []}
	G.ensure_starter_pets()
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.items = {"ticket_sweep": 1}
	G.quest = {"day": "", "offer": [], "active": {}, "claimed": []}
	G.selected_role = "zs"
	G.player_name = "试剑"


## 直接指定今日牌：委托抽取是「日期+等级」随机的，用例要的是确定状态
func _set_offer(ids: Array) -> void:
	G.quest = {"day": G.today_key(), "offer": ids.duplicate(), "active": {}, "claimed": []}


func _run() -> void:
	_baseline()

	# ---- A. 委托表完整性 ----
	var defs := G.quest_defs()
	_check(defs.size() >= 6, "委托表应至少有 6 条，实为 %d" % defs.size())
	var bad: Array = []
	for q in defs:
		var d := q as Dictionary
		var qid := String(d.get("id", ""))
		var kind := String(d.get("kind", ""))
		if qid.is_empty() or String(d.get("title", "")).is_empty() \
				or String(d.get("goal", "")).is_empty() or String(d.get("desc", "")).is_empty():
			bad.append(qid + ":字段缺")
			continue
		if not (kind in ["slay", "clear", "deliver"]):
			bad.append(qid + ":未知 kind=" + kind)
			continue
		if G.city_npc(String(d.get("npc", ""))).is_empty():
			bad.append(qid + ":发布人不在 city.json")
		if int(d.get("n", 0)) <= 0:
			bad.append(qid + ":n 非法")
		if (d.get("reward", {}) as Dictionary).is_empty():
			bad.append(qid + ":无奖励")
		if kind == "deliver":
			if String(d.get("item", "")).is_empty():
				bad.append(qid + ":deliver 缺 item")
		elif not G.theme_order().has(String(d.get("theme", ""))):
			bad.append(qid + ":theme 不在 theme_order")
	_check(bad.is_empty(), "委托表问题：%s" % str(bad))

	# ---- B. 日刷新 ----
	G.quest = {"day": "", "offer": [], "active": {}, "claimed": []}
	var offer := G.quest_offer()
	_check(offer.size() == mini(G.quest_daily_slots(), defs.size()),
		"今日牌应有 %d 条，实为 %d" % [G.quest_daily_slots(), offer.size()])
	var again := G.quest_offer()
	_check(again == offer, "同一天反复读取今日牌不应变化")
	G.quest["day"] = "2000-01-01"   # 假装到了隔天
	var refetched := G.quest_offer()
	_check(String(G.quest.get("day", "")) == G.today_key(), "跨日应重刷今日牌")
	_check(refetched.size() > 0, "重刷后今日牌不应为空")

	# ---- C. slay：接取 → 战斗上报 → 交付 ----
	_set_offer(["q_slay_forest"])
	_check(not G.quest_active("q_slay_forest"), "未接取时不该是进行中")
	_check(G.quest_accept("q_slay_forest"), "今日牌上的委托应能接取")
	_check(not G.quest_accept("q_slay_forest"), "重复接取应被拒绝")
	_check(G.quest_state("q_slay_forest").begins_with("进行中"),
		"接取后状态应为进行中，实为「%s」" % G.quest_state("q_slay_forest"))
	G.quest_report("slay", "snow", 1)   # 别的秘境不算数
	_check(G.quest_progress("q_slay_forest") == 0, "别处击杀不该推进本条委托")
	var fin1 := G.quest_report("slay", "forest", 2)
	_check(G.quest_progress("q_slay_forest") == 2, "击杀 2 只应推进到 2")
	var fin2 := G.quest_report("slay", "forest", 5)
	_check(fin2.size() == 1, "做满时应返回完成的委托标题，实为 %s" % str(fin2))
	_check(G.quest_progress("q_slay_forest") == G.quest_need("q_slay_forest"),
		"进度不该超出需求")
	_check(G.quest_completed("q_slay_forest"), "达标后应可交付")
	var gold_before := int(G.wallet.get("gold", 0))
	var claim := G.quest_claim("q_slay_forest")
	_check(bool(claim.get("ok", false)), "达标后交付应成功，实为 %s" % str(claim.get("err", "")))
	_check(int(G.wallet.get("gold", 0)) == gold_before + 140,
		"交付应发奖（金币 +140），实为 %d" % (int(G.wallet.get("gold", 0)) - gold_before))
	_check(G.quest_claimed("q_slay_forest"), "交付后应记入今日已交付")
	_check(not G.quest_claim("q_slay_forest").get("ok", false), "同一条不该交付两次")

	# ---- D. clear：通关钩子（on_world_cleared）自动上报 ----
	_set_offer(["q_clear_forest"])
	G.quest_accept("q_clear_forest")
	_check(not G.quest_completed("q_clear_forest"), "还没通关时不该可交付")
	G.on_world_cleared("forest")
	_check(G.quest_completed("q_clear_forest"), "通关 forest 应让「讨伐首领」类委托达标")

	# ---- E. deliver：道具不足被拦，备齐后可交付并扣物 ----
	_set_offer(["q_deliver_food"])
	G.quest_accept("q_deliver_food")
	_check(not G.quest_completed("q_deliver_food"), "没道具时不该可交付")
	var notyet := G.quest_claim("q_deliver_food")
	_check(not bool(notyet.get("ok", false)), "道具不足时交付应被拒绝")
	_check(String(notyet.get("err", "")).contains("宠物粮"),
		"拒绝理由应说清缺什么，实为「%s」" % String(notyet.get("err", "")))
	G.grant_item("pet_food", 2)
	_check(G.quest_completed("q_deliver_food"), "备齐道具后应可交付")
	var ok2 := G.quest_claim("q_deliver_food")
	_check(bool(ok2.get("ok", false)), "备齐后交付应成功")
	_check(G.item_count("pet_food") == 0, "交付应扣掉 2 袋宠物粮，实为 %d" % G.item_count("pet_food"))

	# ---- F. 门禁：不在今日牌上的接不了 ----
	_set_offer(["q_slay_forest"])
	_check(not G.quest_accept("q_clear_forest"), "不在今日牌上的委托不该能接")

	# ---- G. NPC 台词随委托状态变化 ----
	_set_offer(["q_slay_forest"])
	var npc := String(G.quest_def("q_slay_forest").get("npc", ""))
	_check(G.npc_quest_line(npc).contains("正好"), "未接取时发布人应该主动提起，实为「%s」"
		% G.npc_quest_line(npc))
	G.quest_accept("q_slay_forest")
	_check(G.npc_quest_line(npc).contains("清出道来"),
		"进行中时台词应提到委托名，实为「%s」" % G.npc_quest_line(npc))
	G.quest_report("slay", "forest", 3)
	_check(G.npc_quest_line(npc).contains("办成了"), "做满后台词应改成催交付，实为「%s」"
		% G.npc_quest_line(npc))
	G.quest_claim("q_slay_forest")
	_check(G.npc_quest_line(npc).contains("谢"), "交付后台词应变致谢，实为「%s」"
		% G.npc_quest_line(npc))
	_check(not G.npc_quest_line("npc_child").is_empty() or true, "无关 NPC 可以没有委托台词")

	# ---- H. 存档往返 ----
	_set_offer(["q_slay_forest", "q_deliver_food"])
	G.quest_accept("q_slay_forest")
	G.quest_report("slay", "forest", 2)
	G.save_game()
	G.quest = {"day": "", "offer": [], "active": {}, "claimed": []}
	G._load_save()
	_check(G.quest_active("q_slay_forest"), "读档后已接委托应还在")
	_check(G.quest_progress("q_slay_forest") == 2, "读档后进度应保留，实为 %d"
		% G.quest_progress("q_slay_forest"))
	_check(G.quest_offer().has("q_deliver_food"), "读档后今日牌应保留")

	# ---- I. HUD 一行 ----
	_check(G.quest_today_text().contains("委托"), "主城委托小签文案应含「委托」，实为「%s」"
		% G.quest_today_text())

	if _fails == 0:
		print("QUESTS_OK all tests passed")
	else:
		print("QUESTS_FAIL fails=%d" % _fails)
