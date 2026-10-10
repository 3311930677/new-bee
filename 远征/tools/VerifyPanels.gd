# VerifyPanels.gd —— 面板冒烟（场景模式：godot --headless --path . res://tools/VerifyPanels.tscn）
# 用场景模式而非 -s：面板依赖 autoload G，-s 模式下编译器不注册 autoload 全局名。
# 新 class_name 尚未进编辑器的全局类缓存，这里一律 preload 路径取脚本，别写类型名。
# 覆盖：兑换表加载 / 兑换扣费+发奖（钱包与道具两条路）/ 荣誉不足分支与按钮置灰 /
#       余额刷新 / closed 信号 / 存档导出读码 / 导入合法与非法存档码 /
#       重置存档二次确认（取消路径不落盘）/ execute_reset 删档重落默认档
extends Node

const ExchangePanelScript := preload("res://src/ui/ExchangePanel.gd")
const SettingsPanelScript := preload("res://src/ui/SettingsPanel.gd")

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_panels.json"  # 别污染真实存档
	_wipe_temp()
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _wipe_temp() -> void:
	if FileAccess.file_exists(G.SAVE_PATH):
		var dir := DirAccess.open(G.SAVE_PATH.get_base_dir())
		if dir != null:
			dir.remove(G.SAVE_PATH.get_file())


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


## 合成一次左键按下事件（开关类按钮都只认这一种输入）
func _click_ev() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _run() -> void:
	await _verify_exchange()
	await _verify_settings()
	if _fails == 0:
		print("PANELS_OK all tests passed")
	else:
		print("PANELS_FAIL fails=%d" % _fails)


func _verify_exchange() -> void:
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 330}
	G.items = {"ticket_ten": 0, "ticket_sweep": 0}
	G.save_game()

	var ex := ExchangePanelScript.new()
	add_child(ex)
	await get_tree().process_frame  # 等 _ready 构建完

	# 1. 荣誉兑换只给辅助材料，不能直接换其他三币。
	var entries: Array = ex.entries()
	_check(entries.size() == 5, "演武补给应有 5 条，实为 %d" % entries.size())
	for row_v in entries:
		var row: Dictionary = row_v
		for key in (row.get("give", {}) as Dictionary):
			_check(String(key).begins_with("item_"), "荣誉不应兑换通用货币")

	# 2. 辅助材料兑换：扣荣誉，道具入包，金币不变化。
	_check(ex.do_exchange("enhance_stone"), "强化石应兑换成功")
	_check(int(G.wallet.get("honor", -1)) == 250, "兑换后荣誉应 250")
	_check(G.item_count("enhance_stone") == 3, "强化石应入包 ×3")
	_check(int(G.wallet.get("gold", -1)) == 0, "荣誉兑换不应印出金币")

	# 3. 第二次兑换写入另一项库存。
	_check(ex.do_exchange("refine_stone"), "精炼石应兑换成功")
	_check(G.item_count("refine_stone") == 2, "精炼石应入包 ×2")

	# 4. 荣誉不足分支：剩余 130 < 160，拒绝且不扣费。
	_check(not ex.do_exchange("lock_rune"), "荣誉不足应返回 false")
	_check(int(G.wallet.get("honor", -1)) == 130, "失败的兑换不应扣荣誉")
	var hint: Label = ex.get("_hint")
	_check(hint != null and hint.text.contains("荣誉不足"), "荣誉不足应给红字提示")

	# 5. UI 刷新：余额标签 + 按钮置灰态
	var honor_l: Label = ex.get("_honor_l")
	_check(honor_l != null and honor_l.text == "荣誉 130",
		"余额标签应刷成「荣誉 130」，实为 %s" % String(honor_l.text if honor_l != null else ""))
	var btns: Dictionary = ex.get("_btns")
	var poor: Control = btns.get("lock_rune")
	var rich: Control = btns.get("enhance_stone")
	_check(poor != null and is_equal_approx(poor.modulate.a, 0.5), "买不起的按钮应置灰 modulate 0.5")
	_check(rich != null and is_equal_approx(rich.modulate.a, 1.0), "买得起的按钮不应置灰")

	# 6. 返回信号
	var closed_n := {"n": 0}
	ex.closed.connect(func(): closed_n["n"] += 1)
	ex._on_back()
	_check(int(closed_n["n"]) == 1, "返回应发 closed 信号")

	await get_tree().process_frame  # 跑一帧让 toast tween 不炸
	ex.queue_free()
	await get_tree().process_frame


func _verify_settings() -> void:
	G.wallet["honor"] = 888
	G.save_game()

	var sp := SettingsPanelScript.new()
	add_child(sp)
	await get_tree().process_frame

	# 1. 导出：能读出合法 JSON 存档码
	var code: String = sp.do_export()
	_check(not code.is_empty(), "导出应得到存档码")
	var parsed: Variant = JSON.parse_string(code)
	_check(parsed is Dictionary, "存档码应为合法 JSON 对象")
	if parsed is Dictionary:
		var d: Dictionary = (parsed as Dictionary).duplicate(true)
		_check(int((d.get("wallet", {}) as Dictionary).get("honor", -1)) == 888,
			"导出码应含 honor 888")

		# 2. 导入合法码：写入后回读一致
		(d.get("wallet", {}) as Dictionary)["honor"] = 777
		var imp1 := sp.do_import_ex(JSON.stringify(d))
		_check(bool(imp1["ok"]), "合法存档码应导入成功（原因：%s）" % String(imp1["err"]))
		var back: Variant = JSON.parse_string(sp.do_export())
		_check(back is Dictionary and int((back as Dictionary).get("wallet", {}).get("honor", -1)) == 777,
			"导入后存档应为 honor 777")

		# 2.1 导入后必须重读内存态（P0-3）：只写盘不重读，旧内存会在下次保存覆盖导入档
		(d.get("wallet", {}) as Dictionary)["gold"] = 4321
		var imp2 := sp.do_import_ex(JSON.stringify(d))
		_check(bool(imp2["ok"]), "导入成功（gold 4321，原因：%s）" % String(imp2["err"]))
		G.reload_save()
		_check(int(G.wallet.get("gold", -1)) == 4321,
			"导入后内存钱包应重读为 4321，实为 %d" % int(G.wallet.get("gold", -1)))
		_check(int(G.wallet.get("honor", -1)) == 777, "导入后内存荣誉应重读为 777")
		G.wallet["gold"] = 999
		G.save_game()
		var back2: Variant = JSON.parse_string(sp.do_export())
		_check(back2 is Dictionary and int((back2 as Dictionary).get("wallet", {}).get("gold", -1)) == 999,
			"重读后正常保存应写回新值，而不是被旧内存覆盖")

	# 3. 导入非法码：乱串与非字典 JSON 都要拒绝
	_check(not sp.do_import("这不是存档码"), "乱码应导入失败")
	_check(not sp.do_import("[1,2,3]"), "数组 JSON 应导入失败")

	# 三页设置仍保留开关落盘、昵称与存档功能。
	var deck: Control = sp.get("_deck")
	_check(deck != null and int(deck.get("page_count")) == 3, "设置应分常规、旅人、存档三页")
	_check(bool(G.setting_get("shake", true)), "震屏默认应为开")
	sp.get("_shake_btn").pressed.emit()
	_check(not bool(G.setting_get("shake", true)), "点震屏开关应写入 shake=false")
	var raw: Variant = JSON.parse_string(sp.do_export())
	_check(raw is Dictionary
		and bool(((raw as Dictionary).get("prog", {}) as Dictionary).get("settings", {}).get("shake", true)) == false,
		"shake 应落进存档 prog.settings")
	sp.get("_shake_btn").pressed.emit()
	_check(bool(G.setting_get("shake", true)), "再点一次应恢复 shake=true")

	_check(not bool(G.setting_get("skip_story", false)), "剧情演出默认应为播")
	sp.get("_story_btn").pressed.emit()
	_check(bool(G.setting_get("skip_story", false)), "点剧情开关应写入 skip_story=true")
	sp.get("_story_btn").pressed.emit()

	_check(is_equal_approx(float(G.setting_get("battle_speed", 1.0)), 1.0), "默认倍速应为 ×1")
	sp.get("_speed_btn").pressed.emit()
	_check(is_equal_approx(float(G.setting_get("battle_speed", 1.0)), 2.0), "点倍速应切到 ×2")
	sp._chest._speed_prev.pressed.emit()
	_check(is_equal_approx(float(G.setting_get("battle_speed", 1.0)), 1.0), "再点应切回 ×1")

	# 3.6 昵称：空值拒绝、正常值写入存档
	var ne: LineEdit = sp.get("_name_edit")
	_check(ne != null, "设置页应有昵称输入框")
	ne.text = "   "
	sp.call("_save_name")
	_check(String(sp.get("_name_hint").text).contains("不能为空"), "空昵称应被拒绝并提示")
	ne.text = "夜行者"
	sp.call("_save_name")
	_check(G.player_name == "夜行者", "昵称应写入 G.player_name，实为 %s" % G.player_name)

	# 4. 重置二次确认：第一次点击只亮确认态，不落盘
	sp._on_reset_click()
	_check(bool(sp.get("_reset_armed")), "第一次点重置应进入确认态")
	var rbtn: Control = sp.get("_reset_btn")
	var rlabel: Label = rbtn.get_child(0) if rbtn != null else null
	_check(is_instance_valid(sp._chest._reset_modal), "重置必须打开独立确认弹窗")
	sp._disarm_reset()
	_check(not bool(sp.get("_reset_armed")), "取消后应退出确认态")
	_check(rlabel != null and rlabel.text == "重置存档", "取消后按钮文案应还原")
	_check(FileAccess.file_exists(G.SAVE_PATH), "取消路径不应动存档文件")

	# 5. 执行重置：删档 + gm_reset_save 重落默认档
	G.wallet["honor"] = 555
	G.save_game()
	sp.execute_reset()
	_check(int(G.wallet.get("honor", -1)) == 0, "重置后荣誉应归零")
	var fresh: Variant = JSON.parse_string(sp.do_export())
	_check(fresh is Dictionary and int((fresh as Dictionary).get("wallet", {}).get("honor", -1)) == 0,
		"重置后应重落默认档（honor 0）")

	# 5.1 重置必须清掉全部进度类字段（P0-4：此前只清 prog/wallet，道具/主城/委托/段位/资料全留存）
	G.items["ticket_ten"] = 7
	G.city["built"] = ["hall", "gate", "archive"]
	G.quest["claimed"] = ["q_fake"]
	G.arena["score"] = 1500
	G.player_name = "测试者"
	G.gm_reset_save()
	_check(int(G.items.get("ticket_ten", -1)) == 0, "重置后道具应清空（ticket_ten 归零）")
	for building_v in G.city_buildings():
		var building: Dictionary = building_v
		_check(G.is_built(String(building.get("id", ""))) == bool(building.get("start", false)),
			"重置后基础服务应按 city.json 开局状态恢复")
	_check((G.quest.get("claimed", []) as Array).is_empty(), "重置后委托已交付记录应清空")
	_check(int(G.arena.get("score", -1)) == 1000, "重置后段位分应回 1000，实为 %d" % int(G.arena.get("score", -1)))
	_check(G.player_name == "", "重置后昵称应清空，实为「%s」" % G.player_name)

	# 5.2 非 daily 活动必须有冷却（防「cd:0 = 无限次」歧义再发生，P0-5）
	for a in G.city_activities():
		var ad := a as Dictionary
		if not bool(ad.get("daily", false)):
			_check(int(ad.get("cd", 0)) > 0, "非 daily 活动「%s」应显式给冷却（cd），实为 %d"
				% [String(ad.get("id", "")), int(ad.get("cd", 0))])

	# 7. 物资铺（P1-2）：价目表合法、购买扣款发货、金币不足拒绝、面板能列出货架
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.items = {}
	var shop: Array = G.shop_items()
	_check(shop.size() >= 4, "物资铺应有至少 4 件货，实为 %d" % shop.size())
	var bad_shop: Array = []
	for r in shop:
		var d := r as Dictionary
		var iid := String(d.get("item", ""))
		if G.item_name(iid) == iid or int(d.get("price", 0)) <= 0:
			bad_shop.append(iid)
	_check(bad_shop.is_empty(), "物资铺条目应登记名称且有正价：%s" % str(bad_shop))
	if not shop.is_empty():
		var item0 := String((shop[0] as Dictionary).get("item", ""))
		var price0 := G.shop_price(item0)
		_check(price0 > 0, "取价应命中货品")
		_check(not bool(G.shop_buy(item0)["ok"]), "金币不足应买不了")
		G.wallet["gold"] = price0
		var buy1 := G.shop_buy(item0)
		_check(bool(buy1["ok"]) and G.item_count(item0) == 1, "购买应发货")
		_check(int(G.wallet["gold"]) == 0, "购买应扣款")
		var sell_price0 := G.shop_sell_price(item0)
		_check(sell_price0 > 0 and sell_price0 < price0,
			"回收价必须公开且低于购价，防止同城套利")
		var sale := G.shop_sell(item0)
		_check(bool(sale["ok"]) and G.item_count(item0) == 0,
			"出售应扣掉一件材料")
		_check(int(G.wallet["gold"]) == sell_price0,
			"出售应只按公开回收价入金")
		_check(not bool(G.shop_sell(item0)["ok"]), "库存为零不能重复出售")
	var shop_p: Control = (load("res://src/ui/ShopPanel.gd") as GDScript).new()
	add_child(shop_p)
	await get_tree().process_frame
	_check(shop_p.get("_rows_box") != null and (shop_p.get("_rows_box") as Control).get_child_count() >= shop.size(),
		"物资铺面板应列出全部货品")
	shop_p.queue_free()

	# 7.1 非法货品必须下架，且购买接口独立拒绝（轮次 20 · #20）
	# 旧实现把异常价格 max(1, ...) 兜底成 1：表里写 0/负/字符串/缺字段，货架照卖 1 金币。
	# 这条用例把"表被写坏"直接注进去，检查的是**下架**而不是"兜底成 1"。
	var bad_path := "user://verify_panels_shop_bad.json"
	var bf := FileAccess.open(bad_path, FileAccess.WRITE)
	bf.store_string(JSON.stringify({"items": [
		{"item": "ticket_ten", "price": 100},        # 合法
		{"item": "ticket_ten", "price": 5},          # 重复 id
		{"item": "enhance_stone"},                   # 缺 price
		{"item": "refine_stone", "price": 0},        # 零价
		{"item": "lock_rune", "price": -50},         # 负价
		{"item": "pet_food", "price": "100"},        # 字符串价
		{"item": "break_crystal", "price": 100.7},   # 非整数价
		{"item": "no_such_item_xyz", "price": 100},  # 未登记 id
		{"item": "", "price": 100},                  # 空 id
	]}))
	bf.close()
	var real_shop_path := G.SHOP_PATH
	G.SHOP_PATH = bad_path
	G.shop_reload()
	var shelf: Array = G.shop_items()
	_check(shelf.size() == 1, "非法货品应全部下架，只剩 1 件（实为 %d）" % shelf.size())
	_check(String((shelf[0] as Dictionary).get("item", "")) == "ticket_ten"
		and int((shelf[0] as Dictionary).get("price", 0)) == 100, "留下的应是唯一合法条目")
	for bogus in ["enhance_stone", "refine_stone", "lock_rune", "pet_food",
			"break_crystal", "no_such_item_xyz", ""]:
		G.wallet["gold"] = 9999
		var items_before := G.items.duplicate()
		var r := G.shop_buy(bogus)
		_check(not bool(r["ok"]), "非法商品「%s」不应允许购买" % bogus)
		_check(int(G.wallet["gold"]) == 9999, "非法购买不应扣款（%s）" % bogus)
		_check(JSON.stringify(G.items) == JSON.stringify(items_before), "非法购买不应发货（%s）" % bogus)
		_check(G.shop_price(bogus) <= 0, "非法商品取价应为 0（%s）" % bogus)
	# 合法条目仍要能正常买：恰好扣一次、发一次
	G.wallet["gold"] = 100
	G.items = {}
	var ok_buy := G.shop_buy("ticket_ten")
	_check(bool(ok_buy["ok"]) and int(G.wallet["gold"]) == 0 and G.item_count("ticket_ten") == 1,
		"合法商品应恰好扣一次发一次")
	G.SHOP_PATH = real_shop_path
	G.shop_reload()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
	_check(G.shop_items().size() >= 4, "恢复真实货架后应回到正常条目数")

	# 6. 返回信号
	var closed_n := {"n": 0}
	sp.closed.connect(func(): closed_n["n"] += 1)
	sp._on_back()
	_check(int(closed_n["n"]) == 1, "返回应发 closed 信号")

	sp.queue_free()
	await get_tree().process_frame
