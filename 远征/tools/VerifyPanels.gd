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
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 1000}
	G.items = {"ticket_ten": 0, "ticket_sweep": 0}
	G.save_game()

	var ex := ExchangePanelScript.new()
	add_child(ex)
	await get_tree().process_frame  # 等 _ready 构建完

	# 1. 兑换表加载（6 条货币/券 + 8 条养成材料）
	var entries: Array = ex.entries()
	_check(entries.size() == 14, "兑换表应有 14 条，实为 %d" % entries.size())

	# 2. 货币包兑换：扣荣誉 → 金币入钱包
	_check(ex.do_exchange("gold_pack_s"), "gold_pack_s 应兑换成功")
	_check(int(G.wallet.get("honor", -1)) == 900, "兑换后荣誉应 900，实为 %d" % int(G.wallet.get("honor", -1)))
	_check(int(G.wallet.get("gold", -1)) == 1200, "兑换后金币应 1200，实为 %d" % int(G.wallet.get("gold", -1)))

	# 3. 道具券兑换：走 G.grant_item
	var tk_before := G.item_count("ticket_ten")
	_check(ex.do_exchange("ticket_ten"), "ticket_ten 应兑换成功")
	_check(G.item_count("ticket_ten") == tk_before + 1, "召唤十连券应 +1，实为 %d" % G.item_count("ticket_ten"))

	# 4. 荣誉不足分支：剩余 300 < 400，拒绝且不扣费
	_check(not ex.do_exchange("gold_pack_l"), "荣誉不足应返回 false")
	_check(int(G.wallet.get("honor", -1)) == 300, "失败的兑换不应扣荣誉")
	var hint: Label = ex.get("_hint")
	_check(hint != null and hint.text.contains("荣誉不足"), "荣誉不足应给红字提示")

	# 5. UI 刷新：余额标签 + 按钮置灰态
	var honor_l: Label = ex.get("_honor_l")
	_check(honor_l != null and honor_l.text == "荣誉 300",
		"余额标签应刷成「荣誉 300」，实为 %s" % String(honor_l.text if honor_l != null else ""))
	var btns: Dictionary = ex.get("_btns")
	var poor: Control = btns.get("gold_pack_l")
	var rich: Control = btns.get("gold_pack_s")
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
		_check(sp.do_import(JSON.stringify(d)), "合法存档码应导入成功")
		var back: Variant = JSON.parse_string(sp.do_export())
		_check(back is Dictionary and int((back as Dictionary).get("wallet", {}).get("honor", -1)) == 777,
			"导入后存档应为 honor 777")

		# 2.1 导入后必须重读内存态（P0-3）：只写盘不重读，旧内存会在下次保存覆盖导入档
		(d.get("wallet", {}) as Dictionary)["gold"] = 4321
		_check(sp.do_import(JSON.stringify(d)), "导入成功（gold 4321）")
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

	# 3.5 轮次 15：两页设置 + 开关项真的写进存档
	var deck: Control = sp.get("_deck")
	_check(deck != null and int(deck.get("page_count")) == 2, "设置应分两页（常规 / 存档与系统）")
	_check(bool(G.setting_get("shake", true)), "震屏默认应为开")
	sp.get("_shake_btn").gui_input.emit(_click_ev())
	_check(not bool(G.setting_get("shake", true)), "点震屏开关应写入 shake=false")
	var raw: Variant = JSON.parse_string(sp.do_export())
	_check(raw is Dictionary
		and bool(((raw as Dictionary).get("prog", {}) as Dictionary).get("settings", {}).get("shake", true)) == false,
		"shake 应落进存档 prog.settings")
	sp.get("_shake_btn").gui_input.emit(_click_ev())
	_check(bool(G.setting_get("shake", true)), "再点一次应恢复 shake=true")

	_check(not bool(G.setting_get("skip_story", false)), "剧情演出默认应为播")
	sp.get("_story_btn").gui_input.emit(_click_ev())
	_check(bool(G.setting_get("skip_story", false)), "点剧情开关应写入 skip_story=true")
	sp.get("_story_btn").gui_input.emit(_click_ev())

	_check(is_equal_approx(float(G.setting_get("battle_speed", 1.0)), 1.0), "默认倍速应为 ×1")
	sp.get("_speed_btn").gui_input.emit(_click_ev())
	_check(is_equal_approx(float(G.setting_get("battle_speed", 1.0)), 2.0), "点倍速应切到 ×2")
	sp.get("_speed_btn").gui_input.emit(_click_ev())
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
	_check(rlabel != null and rlabel.text == "确认重置？", "确认态按钮应显示「确认重置？」")
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
	_check((G.city.get("built", []) as Array).size() == 2, "重置后主城应回到初始两建筑")
	_check((G.quest.get("claimed", []) as Array).is_empty(), "重置后委托已交付记录应清空")
	_check(int(G.arena.get("score", -1)) == 1000, "重置后段位分应回 1000，实为 %d" % int(G.arena.get("score", -1)))
	_check(G.player_name == "", "重置后昵称应清空，实为「%s」" % G.player_name)

	# 5.2 非 daily 活动必须有冷却（防「cd:0 = 无限次」歧义再发生，P0-5）
	for a in G.city_activities():
		var ad := a as Dictionary
		if not bool(ad.get("daily", false)):
			_check(int(ad.get("cd", 0)) > 0, "非 daily 活动「%s」应显式给冷却（cd），实为 %d"
				% [String(ad.get("id", "")), int(ad.get("cd", 0))])

	# 6. 返回信号
	var closed_n := {"n": 0}
	sp.closed.connect(func(): closed_n["n"] += 1)
	sp._on_back()
	_check(int(closed_n["n"]) == 1, "返回应发 closed 信号")

	sp.queue_free()
	await get_tree().process_frame
