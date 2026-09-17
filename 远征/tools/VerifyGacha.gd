# VerifyGacha.gd —— 召唤面板冒烟（场景模式：godot --headless --path . res://tools/VerifyGacha.tscn）
# 用场景模式而非 -s：GachaPanel 依赖 autoload G，-s 模式下编译器不注册 autoload 全局名
# 覆盖：配置表读取 / 余额不足行内提示 / 单抽扣费与新收集 / 重复炼金入账 /
#       十连用券优先与至少一张蓝 / 无券扣魂石 / 60 抽保底强制史诗 / 全白十连强制补蓝 /
#       翻卡与全部翻开 / closed 信号 / 200 抽概率与保底不变量
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


## 重置到确定状态（钱包 / 道具含保底计数 / 宠物只留初始岩龟）
func _reset(soul := 0, ticket := 0, pity := 0) -> void:
	G.wallet = {"gold": 0, "expedition": 0, "soul": soul, "honor": 0}
	G.items = {"ticket_ten": ticket, "ticket_sweep": 0, "gacha_pity": pity}
	G.prog["pets"] = ["pet_rockturtle"]
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

	# —— 0. 配置表 ——
	var cfg := p._cfg()
	_check(not cfg.is_empty(), "gacha.json 应能读取")
	_check(int(cfg.get("cost_soul_single", 0)) == 80, "单抽价格应为 80")
	_check(int(cfg.get("cost_soul_ten", 0)) == 800, "十连价格应为 800")
	_check(int(cfg.get("pity", 0)) == 60, "保底抽数应为 60")
	var rates: Dictionary = cfg.get("rates", {})
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
	var has_blue := false
	for r in p._results:
		if String((r as Dictionary)["rarity"]) != "white":
			has_blue = true
	_check(has_blue, "十连至少一张稀有及以上")
	var pity_now := int(G.items.get("gacha_pity", -1))
	_check(pity_now >= 0 and pity_now < 60, "保底计数应在 0..59（实为 %d）" % pity_now)

	# —— 5. 十连：无券扣魂石 ——
	_reset(800, 0, 0)
	p._do_ten()
	_check(int(G.wallet["soul"]) == 0 and G.item_count("ticket_ten") == 0, "无券十连应扣 800 魂石")

	# —— 6. 60 抽保底：强制史诗及以上并清零 ——
	_reset(80, 0, 59)
	p._do_single()
	var rar6 := String(p._results[0]["rarity"])
	_check(rar6 == "purple" or rar6 == "gold", "第 60 抽必出史诗及以上（实为 %s）" % rar6)
	_check(int(G.items.get("gacha_pity", -1)) == 0, "出紫/金后保底应清零")

	# —— 7. 全白十连强制补一张稀有（临时注入全白概率表）——
	_reset(800, 0, 0)
	p._cfg_cache = {
		"cost_soul_single": 80, "cost_soul_ten": 800, "pity": 60,
		"rates": {"white": 1.0, "blue": 0.0, "purple": 0.0, "gold": 0.0},
		"dup_gold": {"white": 200, "blue": 600, "purple": 1500, "gold": 4000},
	}
	p._do_ten()
	var blues := 0
	for r in p._results:
		if String((r as Dictionary)["rarity"]) == "blue":
			blues += 1
	_check(blues == 1, "全白十连应强制补一张稀有（实为 %d 张蓝）" % blues)
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
	_check(p._results.size() == 10 and int(G.wallet["soul"]) == 0, "再抽一次应按十连重放并扣费")
	var closed_flag := {"hit": false}   # lambda 按值捕获，得用引用类型带出状态
	p.closed.connect(func(): closed_flag["hit"] = true)
	p._close()
	_check(bool(closed_flag["hit"]), "返回应发出 closed 信号")

	# —— 10. 200 次单抽：概率落点 + 保底不变量 ——
	_reset(80 * 200, 0, 0)
	var gold_n := 0
	var purple_n := 0
	for i in 200:
		var pre := int(G.items.get("gacha_pity", 0))
		p._do_single()
		var rr: Dictionary = p._results[0]
		var rar := String(rr["rarity"])
		if rar == "gold":
			gold_n += 1
		elif rar == "purple":
			purple_n += 1
		if pre >= 59:
			_check(rar == "purple" or rar == "gold", "保底触发必出史诗及以上（实为 %s）" % rar)
		var post := int(G.items.get("gacha_pity", -1))
		_check(post >= 0 and post < 60, "保底计数应始终在 0..59（实为 %d）" % post)
		_check(not TableCache.get_pet(String(rr["id"])).is_empty(), "抽中 id 应为有效宠物")
		if i % 20 == 0:
			await get_tree().process_frame   # 让旧卡 queue_free 落地
	_check(purple_n >= 4 and purple_n <= 32, "200 抽紫卡应在 4..32（实为 %d）" % purple_n)
	_check(gold_n <= 13, "200 抽金卡不应超过 13（实为 %d）" % gold_n)
	_check(p._soul_l.text == "× 0", "抽完后主面板魂石余额应刷新（实为 %s）" % p._soul_l.text)

	if _fails == 0:
		print("GACHA_OK all tests passed")
	else:
		print("GACHA_FAIL fails=%d" % _fails)
