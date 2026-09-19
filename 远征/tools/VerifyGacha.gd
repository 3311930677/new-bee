# VerifyGacha.gd —— 召唤面板冒烟（场景模式：godot --headless --path . res://tools/VerifyGacha.tscn）
# 用场景模式而非 -s：GachaPanel 依赖 autoload G，-s 模式下编译器不注册 autoload 全局名
# 覆盖：配置表读取（v2 池结构）/ 余额不足行内提示 / 单抽扣费与新收集 / 重复炼金入账 /
#       十连用券优先与至少一张紫 / 无券扣魂石 / 60 抽保底强制史诗 / 全下品十连强制补紫 /
#       每日免费抽与七日连抽奖 / 旧档保底迁移 / 翻卡与全部翻开 / closed 信号 / 200 抽概率与保底不变量
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_gacha.json"  # 别污染真实存档
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


## 重置到确定状态（钱包 / 道具 / 抽奖状态 / 宠物只留初始岩龟）。
## 免费抽默认记为「今天已领」，避免干扰付费路径；免费用例自行改写 free_day。
func _reset(soul := 0, ticket := 0, pity := 0) -> void:
	G.wallet = {"gold": 0, "expedition": 0, "soul": soul, "honor": 0}
	G.items = {"ticket_ten": ticket, "ticket_sweep": 0}
	G.prog["pets"] = ["pet_rockturtle"]
	G.prog["gacha"] = {"pity": pity, "free_day": G.today_key(), "free_streak": 0, "free_last": ""}
	G.save_game()


## 结果层里"活着"的卡数（旧一批被 queue_free 的不算）
func _live_cards(p: GachaPanel) -> int:
	var n := 0
	for c in p._cards_box.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


func _run() -> void:
	var holder := Control.new()
	holder.size = Vector2(480, 800)
	add_child(holder)
	var p := GachaPanel.new()
	holder.add_child(p)

	# —— 0. 配置表（v2 池结构） ——
	var cfg := p._cfg()
	_check(not cfg.is_empty(), "gacha.json 应能读取")
	var pool: Dictionary = p._pool()
	_check(not pool.is_empty(), "gacha.json 应有 pools[0]（v2 结构）")
	_check(int(pool.get("cost_soul_single", 0)) == 80, "单抽价格应为 80")
	_check(int(pool.get("cost_soul_ten", 0)) == 720, "十连应为 9 折 720")
	_check(int(pool.get("pity", 0)) == 60, "保底抽数应为 60")
	_check(int(pool.get("daily_free", 0)) == 1, "应有每日免费 1 抽")
	_check(String(pool.get("ten_guarantee", "")) == "purple", "十连保底应为史诗及以上")
	var rates: Dictionary = pool.get("rates", {})
	var rates_sum := float(rates.get("white", 0.0)) + float(rates.get("blue", 0.0)) \
		+ float(rates.get("purple", 0.0)) + float(rates.get("gold", 0.0))
	_check(is_equal_approx(rates_sum, 1.0), "四档概率之和应为 1（实为 %f）" % rates_sum)
	var dup: Dictionary = cfg.get("dup_gold", {})
	_check(int(dup.get("white", 0)) == 200 and int(dup.get("blue", 0)) == 600
		and int(dup.get("purple", 0)) == 1500 and int(dup.get("gold", 0)) == 4000,
		"重复炼金数额应与规格一致（白200/蓝600/紫1500/金4000）")

	# —— 1. 余额不足：不扣费、不出结果层、给行内提示 ——
	_reset(10, 0, 0)
	p._do_single()
	_check(int(G.wallet["soul"]) == 10, "余额不足时魂石不应被扣")
	_check(not p._result.visible, "余额不足不应出结果层")
	_check(p._hint.text != "" and p._hint.modulate.a > 0.9, "应给出行内红字提示")
	p._do_ten()
	_check(int(G.wallet["soul"]) == 10 and not p._result.visible, "十连余额不足同理不应扣费")

	# —— 2. 单抽：扣费 + 新收集（清空宠物册，抽谁都是新）——
	_reset(80, 0, 0)
	G.prog["pets"] = []
	p._do_single()
	_check(int(G.wallet["soul"]) == 0, "单抽应扣 80 魂石")
	_check(p._result.visible, "单抽后应展示结果层")
	_check(_live_cards(p) == 1, "单抽应展示一张卡（实为 %d）" % _live_cards(p))
	_check(p._results.size() == 1, "结果数应为 1")
	var r0: Dictionary = p._results[0]
	_check(not TableCache.get_pet(String(r0["id"])).is_empty(), "抽中应为有效宠物")
	_check(G.owns_pet(String(r0["id"])), "新抽中宠物应已入册")
	_check(bool(r0["is_new"]) and int(r0["dup"]) == 0, "首次抽中应标记为新、无炼金")

	# —— 3. 重复炼金（先全拥有，抽谁都是重复）——
	var all_pets: Array = []
	for pd in TableCache.pets():
		all_pets.append(String((pd as Dictionary).get("id", "")))
	_reset(80, 0, 0)
	G.prog["pets"] = all_pets
	p._do_single()
	var r1: Dictionary = p._results[0]
	var want := int(dup.get(String(r1["rarity"]), 0))
	_check(not bool(r1["is_new"]) and int(r1["dup"]) == want,
		"重复宠应按稀有度炼金（%s 应 +%d）" % [String(r1["rarity"]), want])
	_check(int(G.wallet["gold"]) == want, "炼金金币应入账（应 +%d）" % want)

	# —— 4. 十连：有券优先用券 + 至少一张蓝及以上 ——
	_reset(50, 2, 0)
	p._do_ten()
	_check(G.item_count("ticket_ten") == 1, "有券时应优先消耗十连券")
	_check(int(G.wallet["soul"]) == 50, "用券时不应扣魂石")
	_check(_live_cards(p) == 10 and p._results.size() == 10, "十连应有十张卡")
	var has_high := false
	for r in p._results:
		var rr4 := String((r as Dictionary)["rarity"])
		if rr4 == "purple" or rr4 == "gold":
			has_high = true
	_check(has_high, "十连至少一张史诗及以上")
	var pity_now := int(G.gacha_state().get("pity", -1))
	_check(pity_now >= 0 and pity_now < 60, "保底计数应在 0..59（实为 %d）" % pity_now)

	# —— 5. 十连：无券扣魂石（9 折 720） ——
	_reset(800, 0, 0)
	p._do_ten()
	_check(int(G.wallet["soul"]) == 80 and G.item_count("ticket_ten") == 0, "无券十连应扣 720 魂石")

	# —— 6. 60 抽保底：强制史诗及以上并清零 ——
	_reset(80, 0, 59)
	p._do_single()
	var rar6 := String(p._results[0]["rarity"])
	_check(rar6 == "purple" or rar6 == "gold", "第 60 抽必出史诗及以上（实为 %s）" % rar6)
	_check(int(G.gacha_state().get("pity", -1)) == 0, "出紫/金后保底应清零")

	# —— 7. 全下品十连强制补一张史诗（临时注入全白概率表）——
	_reset(800, 0, 0)
	p._cfg_cache = {
		"version": 2,
		"pools": [{"id": "pet", "name": "灵宠召唤", "currency": "soul",
			"cost_soul_single": 80, "cost_soul_ten": 720, "pity": 60, "daily_free": 1,
			"ten_guarantee": "purple",
			"rates": {"white": 1.0, "blue": 0.0, "purple": 0.0, "gold": 0.0}}],
		"dup_gold": {"white": 200, "blue": 600, "purple": 1500, "gold": 4000},
	}
	p._do_ten()
	var highs := 0
	for r in p._results:
		var rr7 := String((r as Dictionary)["rarity"])
		if rr7 == "purple" or rr7 == "gold":
			highs += 1
	_check(highs == 1, "全下品十连应强制补一张史诗（实为 %d 张紫/金）" % highs)
	p._cfg_cache = {}   # 恢复读表

	# —— 8. 翻卡：初始背面 → 点击翻开 → 全部翻开 ——
	var card: Control = null
	for c in p._cards_box.get_children():
		if not c.is_queued_for_deletion():
			card = c
			break
	_check(card != null, "应能找到结果卡")
	var back: Control = card.get_meta("back")
	var face: Control = card.get_meta("face")
	_check(back.visible and not face.visible, "初始应背面朝上")
	p._flip_card(card)
	_check(bool(card.get_meta("flipped", false)), "点击后应标记已翻开")
	await get_tree().create_timer(0.5).timeout   # 等翻面 tween 真实走完
	_check(not back.visible and face.visible, "翻开后应显示正面")
	p._flip_all()
	await get_tree().create_timer(0.8).timeout
	var all_flipped := true
	for c in p._cards_box.get_children():
		if not c.is_queued_for_deletion() and not bool(c.get_meta("flipped", false)):
			all_flipped = false
	_check(all_flipped, "全部翻开后不应有未翻的卡")
	_check(not p._flip_all_btn.visible, "全部翻开后「全部翻开」应隐藏")

	# —— 9. 再抽一次（保留上次模式）+ closed 信号 ——
	_reset(80, 0, 0)
	p._again()   # 上次是十连：80 魂石无券，应走行内提示不扣费
	_check(p._r_hint.text != "" and _live_cards(p) == 10, "再抽失败应给行内提示且卡片不变")
	_reset(800, 0, 1)
	p._again()
	_check(p._results.size() == 10 and int(G.wallet["soul"]) == 80, "再抽一次应按十连重放并扣费")
	var closed_flag := {"hit": false}   # lambda 按值捕获，得用引用类型带出状态
	p.closed.connect(func(): closed_flag["hit"] = true)
	p._close()
	_check(bool(closed_flag["hit"]), "返回应发出 closed 信号")

	# —— 10. 200 次单抽：概率落点 + 保底不变量 ——
	_reset(80 * 200, 0, 0)
	var gold_n := 0
	var purple_n := 0
	for i in 200:
		var pre := int(G.gacha_state().get("pity", 0))
		p._do_single()
		var rr: Dictionary = p._results[0]
		var rar := String(rr["rarity"])
		if rar == "gold":
			gold_n += 1
		elif rar == "purple":
			purple_n += 1
		if pre >= 59:
			_check(rar == "purple" or rar == "gold", "保底触发必出史诗及以上（实为 %s）" % rar)
		var post := int(G.gacha_state().get("pity", -1))
		_check(post >= 0 and post < 60, "保底计数应始终在 0..59（实为 %d）" % post)
		_check(not TableCache.get_pet(String(rr["id"])).is_empty(), "抽中 id 应为有效宠物")
		if i % 20 == 0:
			await get_tree().process_frame   # 让旧卡 queue_free 落地
	_check(purple_n >= 4 and purple_n <= 32, "200 抽紫卡应在 4..32（实为 %d）" % purple_n)
	_check(gold_n <= 13, "200 抽金卡不应超过 13（实为 %d）" % gold_n)
	_check(p._soul_l.text == "× 0", "抽完后主面板魂石余额应刷新（实为 %s）" % p._soul_l.text)

	# —— 11. 每日免费抽：同日一次、不扣魂石 ——
	_reset(0, 0, 0)
	G.prog["gacha"]["free_day"] = ""   # 模拟"今天还没领"
	_check(G.gacha_free_available(), "未领取时免费抽应可用")
	p._do_free()
	_check(p._results.size() >= 1, "免费抽应出结果")
	_check(int(G.wallet["soul"]) == 0, "免费抽不扣魂石")
	_check(String(G.gacha_state().get("free_day", "")) == G.today_key(), "免费次数应记为今天")
	_check(not G.gacha_free_available(), "同一天第二次应不可用")
	var n_free := p._results.size()
	p._do_free()
	_check(p._results.size() == n_free, "重复点免费不应再抽")

	# —— 12. 连续 7 天免费：第 7 天送灵魂石 ×50 并重新计数 ——
	_reset(0, 0, 0)
	G.prog["gacha"]["free_day"] = ""
	G.prog["gacha"]["free_streak"] = 6
	G.prog["gacha"]["free_last"] = G._day_key(G.now_ts() - 86400)
	p._do_free()
	_check(int(G.wallet["soul"]) == 50, "连续第 7 天免费应送灵魂石 50（实为 %d）" % int(G.wallet["soul"]))
	_check(int(G.gacha_state().get("free_streak", -1)) == 0, "满 7 天后连抽计数应重置")

	# —— 13. 旧档迁移：items.gacha_pity → prog.gacha.pity（P2-5） ——
	_reset(0, 0, 0)
	G.items["gacha_pity"] = 42
	G.prog["gacha"]["pity"] = 0
	G.save_game()
	G.reload_save()
	_check(int(G.gacha_state().get("pity", -1)) == 42,
		"旧档保底应迁移为 42（实为 %d）" % int(G.gacha_state().get("pity", -1)))
	_check(not G.items.has("gacha_pity"), "迁移后 items 里不应再留 gacha_pity")

	if _fails == 0:
		print("GACHA_OK all tests passed")
	else:
		print("GACHA_FAIL fails=%d" % _fails)
