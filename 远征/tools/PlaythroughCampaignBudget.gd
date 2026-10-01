## Natural-resource route; no filled-bag items, sales, or additional resource grants.
extends "res://tools/PlaythroughCampaignGear.gd"

var _budgets: Array = []

func _ready() -> void:
	fullbag_fixture = false
	await super._ready()

func _free_slot(_bag: BagPanel) -> bool:
	# Any unexpectedly full bag must fail this audit instead of injecting sale revenue.
	return G.inv_count() < G.inv_capacity() or _bad("自然预算路线意外满包，停止以免引入销售收益")

func _after_gear_worn(home: Control, chapter: String) -> bool:
	var before := {"wallet":G.wallet.duplicate(true),"items":G.items.duplicate(true),"bag":G.inv_count()}
	var targets: Dictionary = {G.equip_weapon_slot():2,"armor":1} if chapter == "act1" else \
		{G.equip_weapon_slot():3,"armor":2} if chapter == "act2" else \
		{G.equip_weapon_slot():3,"armor":3,"accessory":2}
	var expected_gold := 600 if chapter == "act1" else 1350 if chapter == "act2" else 2250
	var expected_stones := 3 if chapter == "act1" else 5 if chapter == "act2" else 8
	if int(G.wallet.gold) < expected_gold or G.item_count("enhance_stone") < expected_stones:
		return _bad("正常收入不足以支撑公开路线：%s 现有%d金/%d石，需要%d金/%d石" % [chapter,G.wallet.gold,G.item_count("enhance_stone"),expected_gold,expected_stones])
	if not await _click_until(_button(home,"养成"),func(): return home._growth != null,30,"budget_growth"): return _bad("养成入口失败")
	await _wait_frames(5)
	var growth := home._growth as GrowthPanel
	var label := _find_label(growth,["装备"])
	var card := label.get_parent().get_parent() as Control if label != null else null
	if not await _click_until(card,func(): return growth._sub is EquipPanel,30,"budget_workshop"): return _bad("装备养成入口失败")
	await _wait_frames(5)
	var panel := growth._sub as EquipPanel
	for slot in targets:
		var slot_button: Control = null
		for child in panel._slots_row.get_children():
			if String(child.get_meta("sid", "")) == slot: slot_button = child
		if not await _click_until(slot_button,func(): return panel._sel == slot,30,"budget_slot_"+slot): return _bad("强化槽位点击失败")
		await _wait_frames(4)
		if int(G.equip_state(slot).lv) != 0: return _bad("当前幕新装备不应继承前幕强化")
		for target in range(1,int(targets[slot])+1):
			if not await _click_until(_action(panel),func(): return int(G.equip_state(slot).lv) == target,30,"budget_enhance_%s_%d"%[slot,target]): return _bad("自然资源强化失败")
			await _wait_frames(4)
	if int(before.wallet.gold)-int(G.wallet.gold) != expected_gold or int(before.items.get("enhance_stone",0))-G.item_count("enhance_stone") != expected_stones:
		return _bad("实际加工扣费与公开预算不一致")
	if not await _click_until(_button(panel,"返 回"),func(): return growth._sub == null,30,"budget_close_workshop"): return _bad("不能退出工坊")
	await _wait_frames(4)
	if not await _click_until(_button(growth,"返 回"),func(): return home._growth == null,30,"budget_close_growth"): return _bad("不能返回营帐")
	await _wait_frames(4)
	var row := {"chapter":chapter,"before":before,"after":{"wallet":G.wallet.duplicate(true),"items":G.items.duplicate(true),"bag":G.inv_count()},"targets":targets,"gold_cost":expected_gold,"stone_cost":expected_stones}
	_budgets.append(JSON.parse_string(JSON.stringify(row)))
	print("BUDGET_CHECKPOINT "+JSON.stringify(row))
	var file := FileAccess.open(_budget_file(),FileAccess.WRITE)
	if file == null: return _bad("不能保存预算证据")
	file.store_string(JSON.stringify(_budgets))
	file.close()
	return true

func _budget_file() -> String:
	return G.SAVE_PATH.get_base_dir().path_join("budget_%s.json"%role_id)

func _action(root: Node) -> Control:
	for child in root.get_children():
		if child is Control and child.get_meta("work_action", "") == "enhance": return child
		var found := _action(child)
		if found != null: return found
	return null

func _check_final() -> bool:
	return super._check_final() and int(G.equip_state(G.equip_weapon_slot()).lv) == 3 \
		and int(G.equip_state("armor").lv) == 3 and int(G.equip_state("accessory").lv) == 2

func _state() -> Dictionary:
	var result := super._state()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_budget_file()))
	result["budgets"] = data if data is Array else []
	result["inventory"] = JSON.parse_string(JSON.stringify(G.prog.inventory))
	result["wallet"] = JSON.parse_string(JSON.stringify(G.wallet))
	result["items"] = JSON.parse_string(JSON.stringify(G.items))
	return result
