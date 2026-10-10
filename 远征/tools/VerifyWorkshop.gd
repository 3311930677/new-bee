extends "res://tools/VerifyThirdBack.gd"

const SAVE := "res://tools/_logs/save_verify_workshop.json"

func _ready() -> void:
	G.SAVE_PATH = SAVE
	await _run()
	print("WORKSHOP_OK" if _fails == 0 else "WORKSHOP_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _reset(role := "zs") -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = role
	G.wallet.gold = 50000
	G.items = {"enhance_stone":100}
	G.ensure_starter_equip(true)
	_check(G.save_game() and G.reload_save(), "测试档先经过正常旧字段归一")

func _roll_above(rate: float) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for seed_value in 100000:
		rng.seed = seed_value
		if rng.randf() >= rate:
			rng.seed = seed_value
			return rng
	return rng

func _run() -> void:
	for role in ["zs", "ck", "fs", "fz"]:
		_reset(role)
		var slot := G.equip_weapon_slot()
		var before := G.prog.duplicate(true)
		_check(G.equip_enhance_rate(slot) == 1.0 and G.prog == before, "旧实例预览不增字段或改变投入")
		var rng := _roll_above(0.99)
		var rng_state := rng.state
		for target in range(1,4):
			var result := G.equip_enhance(slot,rng)
			_check(bool(result.ok) and bool(result.success) and int(result.lv) == target, "四职业低阶不依赖随机点数")
		_check(G.wallet.gold == 49100 and G.item_count("enhance_stone") == 97 and rng.state == rng_state, "低阶总900金3石，确定成功不取随机数")
		# JSON numbers decode as float; compare canonical data, not transient int types.
		var expected: Dictionary = JSON.parse_string(JSON.stringify(G.prog))
		var loaded := G.reload_save()
		_check(loaded and JSON.parse_string(JSON.stringify(G.prog)) == expected, "低阶实际落盘重读一致")
	_reset()
	G.equip_state("sword").lv = 3
	_check(is_equal_approx(G.equip_enhance_rate("sword"), 0.6561), "+4初始公开65.61%")
	for failures in range(1,4):
		var rate := G.equip_enhance_rate("sword")
		var result := G.equip_enhance("sword",_roll_above(rate))
		_check(bool(result.ok) and not bool(result.success) and int(result.lv) == 3 and int(result.failures) == failures, "失败扣费留等级并逐次积累")
		_check(is_equal_approx(float(result.next_rate),minf(1.0,0.6561+0.15*failures)), "积累每次增加15个百分点且不越100%")
	_check(G.wallet.gold == 48200 and G.item_count("enhance_stone") == 97 and G.reload_save() and int(G.equip_state("sword").enhance_failures) == 3, "失败费用与积累同档重载")
	var uid := int(G.equip_state("sword").uid)
	G.inv_unequip("sword")
	G.inv_equip(uid)
	_check(G.equip_enhance_rate("sword") == 1.0, "卸下穿回保留本件积累")
	var rng := _roll_above(0.99)
	var rng_state := rng.state
	var result := G.equip_enhance("sword",rng)
	_check(bool(result.success) and int(result.lv) == 4 and int(result.failures) == 0 and rng.state == rng_state, "积累到满率确定成功并清零")
	_check(is_equal_approx(G.equip_enhance_rate("sword"),pow(0.9,5.0)), "成功后下一阶回到基础率")
	# Every reachable high tier has a finite worst-case bound, including the +20 edge.
	for lv in range(3,20):
		_reset()
		G.equip_state("sword").lv = lv
		var limit := G.equip_enhance_failure_limit("sword")
		for count in limit:
			result = G.equip_enhance("sword",_roll_above(G.equip_enhance_rate("sword")))
			_check(bool(result.ok) and not bool(result.success) and int(result.failures) == count+1, "各阶最坏失败序列可达到公开上界")
		_check(G.equip_enhance_rate("sword") == 1.0, "所有中高阶均有限次保证成功")
		result = G.equip_enhance("sword",_roll_above(0.99))
		_check(bool(result.success) and int(result.lv) == lv+1 and int(result.failures) == 0, "到达保证后升阶且清零，包括最终+20")
		_check(G.reload_save() and int(G.equip_state("sword").lv) == lv+1, "每阶最坏序列的终态可读")
	_reset()
	G.equip_state("sword").lv = 4
	G.equip_state("sword")["enhance_failures"] = 0
	for bad in [-1,0.5,"2",[],7]:
		var malformed := G.prog.duplicate(true)
		malformed.inventory.instances[0]["enhance_failures"] = bad
		_check(not bool(SaveData.validate({"prog":malformed},int(Time.get_unix_time_from_system())).ok), "坏积累拒绝而不静默修正")
	var valid := G.prog.duplicate(true)
	valid.inventory.instances[0].erase("enhance_failures")
	_check(bool(SaveData.validate({"prog":valid},int(Time.get_unix_time_from_system())).ok), "旧档缺字段依旧合法")
	for lv in [0,20]:
		var malformed := valid.duplicate(true)
		malformed.inventory.instances[0].lv = lv
		malformed.inventory.instances[0]["enhance_failures"] = 1
		_check(not bool(SaveData.validate({"prog":malformed},int(Time.get_unix_time_from_system())).ok), "低阶或满阶非法积累拒绝")
	var host := FailingHost.new()
	host.prog = G.prog.duplicate(true)
	host.wallet = G.wallet.duplicate(true)
	host.items = G.items.duplicate(true)
	var before := [host.prog.duplicate(true),host.wallet.duplicate(true),host.items.duplicate(true)]
	rng = _roll_above(0.99)
	rng_state = rng.state
	_check(not bool(host.equip_enhance("sword",rng).ok) and [host.prog,host.wallet,host.items] == before and rng.state == rng_state and host.writes == 1, "写失败完整回滚所有资源和随机状态，只有一次存档")
	host.save_locked = true
	_check(not bool(host.equip_enhance("sword",rng).ok) and [host.prog,host.wallet,host.items] == before and host.writes == 1, "锁档连写请求也不发起")
	host.free()
	G.inv_unequip("sword")
	before = [G.prog.duplicate(true),G.wallet.duplicate(true),G.items.duplicate(true)]
	_check(not bool(G.equip_enhance("sword").ok) and [G.prog,G.wallet,G.items] == before, "空槽不能凭空生成基础装或扣费")
	_reset()
	G.equip_state("sword").lv = 3
	G.equip_state("sword")["enhance_failures"] = 2
	var panel := EquipPanel.new()
	add_child(panel)
	await get_tree().process_frame
	var rate_label: Label = null
	var action: Control = null
	var words:=PackedStringArray()
	var pending:Array[Node]=[panel._view._body]
	var rule_button:Button
	while not pending.is_empty():
		var child:Node=pending.pop_back()
		pending.append_array(child.get_children())
		if child is Label:
			words.append(child.text)
			if child.text.begins_with("成功率"):rate_label=child
		if child is Button and child.text=="说明":rule_button=child
	_check(rule_button!=null,"详细费用后果有可点击说明入口")
	if rule_button!=null:
		rule_button.pressed.emit()
		await get_tree().process_frame
		for dialog in panel._view._body.find_children("*","Control",true,false):
			if dialog is Label:words.append(dialog.text)
	for child in panel._view._actions.get_children():
		if child.get_meta("work_action","")=="enhance":action=child
	var joined:=" ".join(words).replace(" ","")
	_check(rate_label!=null and joined.contains("95.6%") and joined.contains("积累2/3") and joined.contains("失败扣费"),"概率和积累常驻，点击说明后公开失败费用后果")
	_check(rate_label!=null and action!=null and rate_label.get_global_rect().end.y<=action.get_global_rect().position.y and panel._view._scroll.get_global_rect().end.y<action.get_global_rect().position.y,"概率与费用说明不会覆盖底部确认操作")
	panel.queue_free()
	await get_tree().process_frame

class FailingHost extends "res://src/autoload/G.gd":
	var writes := 0
	func save_game() -> bool:
		writes += 1
		return false
