# VerifyCity.gd —— 主城场景冒烟：实体生成 / 建造闭环 / 活动结算 / 据点码与来客
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_city.json"
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

	# 实体：配置中的建筑全在；常驻 NPC 与来客均有对应实体。
	_check(city._player != null, "玩家未生成")
	_check((city._buildings as Array).size() == G.city_buildings().size(),
		"建筑数量应为 %d，实为 %d" % [G.city_buildings().size(), (city._buildings as Array).size()])
	for building in city._buildings:
		var id := String(building.data.get("id", ""))
		if id == "stable": id = "kennel"
		if id in ["hall", "archive", "barracks", "kennel", "storehouse", "gate", "shrine", "forge"]:
			_check(building.art != null and building.art.resource_path == "res://image/main_world/city_%s_reference_v2.png" % id, "昭元建筑实际读取统一新图")
			var rect := building.get_child(0) as CollisionShape2D
			_check(rect != null and is_equal_approx((rect.shape as RectangleShape2D).size.y, building._h * 0.30), "换图保留建筑脚下碰撞范围")
	var npc_expect: int = G.city_npcs().size() + G.today_guests(2).size()
	_check((city._npcs as Array).size() == npc_expect,
		"NPC 数量应为 %d，实为 %d" % [npc_expect, (city._npcs as Array).size()])
	# P06：行脚商人不能被交易页抢走原有对话；交易另从对话按钮进入。
	city._open_dialog(G.city_npc("npc_warden"), false)
	_check(String(city._dlg.get("id", "")) == "npc_warden" and city._panel != null,
		"行脚商人应先保留原对话/委托入口")
	var dialogue: Label = city._dlg["line"]
	dialogue.text = "北面的驿站已经补齐药箱，码头的盐车也该到了。把这份路书交给门口的守卫，沿着旧碑上的箭头就能找到旅人留下的营火。".repeat(2)
	city._layout_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	var hint: Label = city._dlg["hint"]
	var paper: Control = city._dlg["paper"]
	_check(dialogue.get_global_rect().end.y + 8.0 <= hint.global_position.y,
		"长对话应完整显示在继续提示上方")
	_check(hint.get_global_rect().end.y < paper.get_global_rect().end.y,
		"对话页脚应留在纸页内")
	city._toast("主线完成：北路通行")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(city._toast_lbl.get_global_rect().end.y + 10.0 <= paper.global_position.y,
		"任务提示需避让自适应对话框")
	city._close_panel()
	city._open_shipping_panel()
	await get_tree().process_frame
	await get_tree().process_frame
	var shipping: ScrollContainer = city._panel.find_child("ShippingDetails", true, false)
	_check(shipping != null and shipping.position.y + shipping.size.y < 414.0,
		"船单长文阅读区应与接单按钮留出间距")
	if shipping != null:
		var details := shipping.get_child(0) as Label
		_check(details.text.ends_with("接单锁定报酬；市集歇脚推进游戏日。") and shipping.clip_contents,
			"船单需保留最后一段说明，并在阅读区域内滚动")
	city._close_panel()
	city._open_first_order_preview()
	_check(city._panel is TradePanel and city.has_modal(), "行脚商人应能打开现货交易页")
	(city._panel as TradePanel).close()

	# 像素小人：七常驻 + 旅人都要拿到 idle 四帧条；缺素材退回立绘/色块算 FAIL
	var npc_bad: Array = []
	for n in city._npcs:
		var fr: SpriteFrames = (n as Object).get("frames")
		if fr == null or fr.get_frame_count(&"idle") != 4:
			npc_bad.append(String(((n as Object).get("data") as Dictionary).get("id", "")))
	_check(npc_bad.is_empty(), "NPC 缺 idle 四帧条：%s" % ", ".join(npc_bad))
	# 标定：帧动画子节点在位、0.72 倍、抬 42.5px（脚底踩在节点原点）
	var npc0: Node2D = city._npcs[0]
	var sp := npc0.get_node_or_null("Idle") as AnimatedSprite2D
	_check(sp != null, "NPC 未挂 Idle 帧节点")
	if sp != null:
		_check(is_equal_approx(sp.scale.x, 0.72), "NPC 帧动画缩放应为 0.72，实为 %.3f" % sp.scale.x)
		_check(is_equal_approx(sp.position.y, -42.5), "NPC 脚底标定应为 -42.5，实为 %.2f" % sp.position.y)
		_check(sp.is_playing(), "NPC 呼吸动画应在播放")

	# 基础服务开局可用；工坊与图志不能把主线挡在建造门槛外。
	_check(G.is_built("archive"), "图志阁应开局开放")
	var gold_before := int(G.wallet.get("gold", 0))
	_check(not G.can_build("archive"), "已开放的基础服务不应重复收费建造")
	_check(int(G.wallet.get("gold", 0)) == gold_before, "基础服务开放不应扣金币")
	city._refresh_city()
	await get_tree().process_frame
	var has_scribe := false
	for n in city._npcs:
		if String((n as Object).get("data").get("id", "")) == "npc_scribe":
			has_scribe = true
	_check(has_scribe, "图志阁落成后青姨应上街")
	_check(G.build_state("hall") == "已落成", "议事厅状态应为已落成，实为 %s" % G.build_state("hall"))
	_check(G.build_state("forge") != "尚未开放", "锻造铺应已开放（物资铺），实为 %s" % G.build_state("forge"))
	_check(String(G.city_building("forge").get("action", "")) == "shop", "锻造铺应指向物资铺")

	# 活动：祭坛未建时签到不可领；城中宴会（议事厅）随时可办
	_check(not G.activity_ready("signin"), "祭坛未建，签到应不可领")
	_check(G.activity_state("signin") == "需先建「祭坛」",
		"签到状态文案不符：%s" % G.activity_state("signin"))
	_check(G.activity_ready("feast"), "城中宴会应可领取")
	var exp_before := int(G.prog.get("exp", 0))
	var res := G.do_activity("feast")
	_check(bool(res.get("ok", false)), "宴会应领取成功：%s" % String(res.get("err", "")))
	_check(int(G.wallet.get("gold", 0)) == gold_before - 200, "宴会应花 200 金")
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
