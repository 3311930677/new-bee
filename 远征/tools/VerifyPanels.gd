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

	# 3. 导入非法码：乱串与非字典 JSON 都要拒绝
	_check(not sp.do_import("这不是存档码"), "乱码应导入失败")
	_check(not sp.do_import("[1,2,3]"), "数组 JSON 应导入失败")

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

	# 6. 返回信号
	var closed_n := {"n": 0}
	sp.closed.connect(func(): closed_n["n"] += 1)
	sp._on_back()
	_check(int(closed_n["n"]) == 1, "返回应发 closed 信号")

	sp.queue_free()
	await get_tree().process_frame
