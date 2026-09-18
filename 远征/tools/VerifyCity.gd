# VerifyCity.gd —— 主城场景冒烟：实体生成 / 建造闭环 / 活动结算 / 据点码与来客
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_city.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	# 固定一份够花的存档：Lv.5 + 各币充足
	G.account = "验证"
	G.player_name = "验证"
	G.selected_role = "zs"
	# 基线完整重置 prog：autoload 启动时已读入真实存档，只改 level 会留下残留 exp——
	# 领宴会经验时恰好跨过升级线就被清零，「宴会应加经验」假红（VerifyGameHome 同款先例）
	G.prog = {"level": 5, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": []}
	G.ensure_starter_pets()
	G.wallet = {"gold": 1000, "expedition": 100, "soul": 50, "honor": 10}
	G.city = {"built": ["hall", "gate"], "code": "", "visits": [], "acts": {}, "day": "", "streak": 0}
	G.ensure_starter_buildings()

	var city := (load("res://src/city/CityScene.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame

	# 实体：8 座建筑全在（落成 2 + 工地 6）；常驻 NPC（need 为空的 3 位）+ 城门卫 + 来客 2
	_check(city._player != null, "玩家未生成")
	_check((city._buildings as Array).size() == 8, "建筑数量应为 8，实为 %d" % (city._buildings as Array).size())
	var npc_expect: int = G.city_npcs().size() + G.today_guests(2).size()
	_check((city._npcs as Array).size() == npc_expect,
		"NPC 数量应为 %d，实为 %d" % [npc_expect, (city._npcs as Array).size()])

	# 建造闭环：图志阁可建 → 落成 → 青姨上街
	_check(G.can_build("archive"), "图志阁应可建造（Lv.5 + 1000 金）")
	var gold_before := int(G.wallet.get("gold", 0))
	_check(G.build("archive"), "图志阁建造应成功")
	_check(int(G.wallet.get("gold", 0)) == gold_before - 150, "建造应扣 150 金")
	_check(G.is_built("archive"), "图志阁应已落成")
	city._refresh_city()
	await get_tree().process_frame
	var has_scribe := false
	for n in city._npcs:
		if String((n as Object).get("data").get("id", "")) == "npc_scribe":
			has_scribe = true
	_check(has_scribe, "图志阁落成后青姨应上街")
	_check(G.build_state("hall") == "已落成", "议事厅状态应为已落成，实为 %s" % G.build_state("hall"))
	_check(G.build_state("forge") == "尚未开放", "锻造铺状态应为尚未开放")

	# 活动：祭坛未建时签到不可领；城中宴会（议事厅）随时可办
	_check(not G.activity_ready("signin"), "祭坛未建，签到应不可领")
	_check(G.activity_state("signin") == "需先建「祭坛」",
		"签到状态文案不符：%s" % G.activity_state("signin"))
	_check(G.activity_ready("feast"), "城中宴会应可领取")
	var exp_before := int(G.prog.get("exp", 0))
	var res := G.do_activity("feast")
	_check(bool(res.get("ok", false)), "宴会应领取成功：%s" % String(res.get("err", "")))
	_check(int(G.wallet.get("gold", 0)) == gold_before - 150 - 200, "宴会应花 200 金")
	_check(int(G.prog.get("exp", 0)) > exp_before, "宴会应加经验")

	# 祭坛落成 → 签到可领 → 连签记 1
	_check(G.build("shrine"), "祭坛建造应成功（260 金 + 20 魂晶）")
	var sr := G.do_activity("signin")
	_check(bool(sr.get("ok", false)), "签到应成功")
	_check(int(G.city.get("streak", 0)) == 1, "首次签到连签应为 1")
	_check(not G.do_activity("signin").get("ok", false), "当天二次签到应被拒")

	# 据点码稳定 + 来客确定
	var c1 := G.city_code()
	_check(c1.length() == 6, "据点码应为 6 位，实为 %s" % c1)
	_check(G.city_code() == c1, "据点码应稳定不变")
	_check(G.today_guests(3) == G.today_guests(3), "今日来客应确定性一致")

	# 访客登记去重
	_check(G.add_visitor("青石堡"), "首次登记青石堡应成功")
	_check(not G.add_visitor("青石堡"), "重复登记青石堡应被拒")

	# 落盘复核
	G.save_game()
	_check(FileAccess.file_exists(G.SAVE_PATH), "存档应已写入")

	city.queue_free()
	await get_tree().process_frame
	if _fails == 0:
		print("CITY_OK all tests passed")
	else:
		print("CITY_FAIL %d test(s) failed" % _fails)
