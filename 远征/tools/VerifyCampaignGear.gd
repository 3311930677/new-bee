extends "res://tools/VerifyThirdBack.gd"

const SAVE := "res://tools/_logs/save_verify_campaign_gear.json"

func _ready() -> void:
	G.SAVE_PATH = SAVE
	await _run()
	print("CAMPAIGN_GEAR_OK" if _fails == 0 else "CAMPAIGN_GEAR_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _reset(n := 28, role := "zs") -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.SAVE_PATH = SAVE
	G.selected_role = role
	G.prog.level = 42
	var done: Array = []
	for i in range(1,n+1): done.append("s%02d" % i)
	G.prog["story"] = {"step": "s%02d" % (n+1) if n < 28 else "", "done": done, "goals": {}}
	G.wallet.gold = 4321
	G.ensure_starter_equip(true)

func _gear() -> Array:
	var result: Array = []
	for item in G.inv_instances()+G.inv_pending():
		if String(item.get("source_id", "")).begins_with("campaign_gear|"): result.append(item)
	return result

func _run() -> void:
	var cfg := CampaignGear.config()
	_check(cfg.rewards.size() == 10 and G.equip_templates().size() >= 40, "四幕十个保底节点与既有装备模板完整保留")
	for role in ["zs", "ck", "fs", "fz"]:
		_reset(28, role)
		var worn: Dictionary = G.prog.equip.duplicate(true)
		var before_exp := [G.prog.level, G.prog.exp]
		var story: Dictionary = G.prog.story.duplicate(true)
		var result := G.campaign_gear_claim()
		_check(bool(result.ok) and int(result.count) == 7 and _gear().size() == 7, "每职业旧完整主线补领七件")
		_check(G.wallet.gold == 4321 and [G.prog.level,G.prog.exp] == before_exp and G.prog.story == story and G.prog.equip == worn, "补领不得改钱/经验/任务或强制换装")
		_check(G.item_count("enhance_stone") == 24 and G.item_count("pet_food") == 3, "明确保底材料24石与3粮")
		for inst in _gear():
			var step := String(inst.source_id).split("|")[1]
			_check(inst.tpl == CampaignGear.reward(step,role).tpl and not bool(G.equip_tpl(inst.tpl).get("random_drop", true)), "每件必须适配角色且不入随机池")
		var all := G.prog.duplicate(true)
		var items := G.items.duplicate(true)
		_check(int(G.campaign_gear_claim().count) == 0 and G.prog == all and G.items == items, "补领奖励与材料只发一次")
		_check(G.reload_save() and CampaignGear.claim_plan(G.prog,role).is_empty() and _gear().size() == 7, "实际写盘重读保存来源及领取账本")
	_reset(12)
	_check(int(G.campaign_gear_claim(false).count) == 2, "旧第一幕档只领前两节点")
	var first := G.prog.duplicate(true)
	G.prog.story.done.append("s19")
	_check(int(G.campaign_gear_claim(false).count) == 1 and _gear().size() == 3, "混合进度只领新满足步骤")
	_reset(0)
	var empty := G.prog.duplicate(true)
	_check(int(G.campaign_gear_claim(false).count) == 0 and G.prog == empty, "未完成主线不得生成任何保底")
	_reset()
	G.inv_grant_equip({"tpl":"tpl_armor_basic","n":60}, false)
	var pending_before := G.inv_pending().size()
	_check(int(G.campaign_gear_claim().count) == 7 and G.inv_count() == 60 and G.inv_pending().size() == pending_before+7, "满包七件完整保存在待领取")
	_check(G.reload_save() and G.inv_pending().size() == pending_before+7, "待领与去重实际读档不丢失")
	# Old full bags can have random pending drops before the seven guaranteed pieces.
	G.inv_grant_equip({"tpl":"tpl_armor_basic","n":6}, false)
	var pending_bag := BagPanel.new()
	add_child(pending_bag)
	pending_bag._tab = "pending"
	pending_bag._refresh()
	await get_tree().process_frame
	var pending_buttons := 0
	for child in pending_bag._item_buttons:
		if child.has_meta("gear_uid"):
			pending_buttons += 1
	_check(pending_bag._scroll.get_global_rect().end.y <= pending_bag._detail.get_global_rect().position.y, "待领取滚动区不得盖住详情")
	_check(pending_buttons == 13, "十三件待领取完整保留在纵向列表")
	pending_bag._scroll.ensure_control_visible(pending_bag._item_buttons[-1])
	await get_tree().process_frame
	pending_buttons = 0
	for child in pending_bag._item_buttons:
		if child.has_meta("gear_uid"): pending_buttons += 1
	_check(pending_buttons == 13 and pending_bag._scroll.get_global_rect().grow(1).encloses(pending_bag._item_buttons[-1].get_global_rect()), "滚动可达最后一件，详情不遮挡领取")
	pending_bag.queue_free()
	await get_tree().process_frame
	_reset()
	var host := FailedGearHost.new()
	host.prog = G.prog.duplicate(true)
	host.items = G.items.duplicate(true)
	host.wallet = G.wallet.duplicate(true)
	host.selected_role = "zs"
	var before := host.prog.duplicate(true)
	var host_items := host.items.duplicate(true)
	_check(not bool(host.campaign_gear_claim().ok) and host.prog == before and host.items == host_items, "补领保存失败返还全部实例材料与账本")
	host.can_save = true
	host.bad_tpl = "tpl_sword_frostgate"
	_check(not bool(host.campaign_gear_claim().ok) and host.prog == before and host.items == host_items, "后续模板未知时整批回滚不留下前几件")
	host.bad_tpl = ""
	host.save_locked = true
	_check(not bool(host.campaign_gear_claim().ok) and host.prog == before, "锁档不得发保底")
	host.save_locked = false
	host.can_save = false
	_check(not bool(host.inv_grant_equip({"tpl":"tpl_armor_stele"}).ok) and host.prog == before, "直接发放保存失败也不吞UID或留下实例")
	host.can_save = true
	host.campaign_gear_claim(false)
	var sword := 0
	for inst in host.inv_instances():
		if inst.tpl == "tpl_sword_frostgate": sword = int(inst.uid)
	host.prog.level = 34
	before = host.prog.duplicate(true)
	_check(not bool(host.inv_equip(sword).ok) and host.prog == before, "低于明确需求等级不得穿装")
	host.prog.level = 35
	host.can_save = false
	before = host.prog.duplicate(true)
	_check(not bool(host.inv_equip(sword).ok) and host.prog == before, "换装保存失败保留原在身与实例投入")
	host.can_save = true
	_check(bool(host.inv_equip(sword).ok) and int(host.prog.equip.sword) == sword, "达到需求即可手动穿装备")
	host.can_save = false
	before = host.prog.duplicate(true)
	_check(not bool(host.inv_unequip("sword").ok) and host.prog == before, "卸装保存失败也恢复原在身")
	host.free()
	_reset(9)
	G.prog.level = 10
	for id in G.prog.story.done: CampaignGrowth.mark(G.prog,id)
	var done := G.story_event("defeat","mon_stele_warden","stele_cavern")
	_check(not done.is_empty() and _gear().size() == 1 and int(done.gear.count) == 1 and G.prog.level == 11, "新首领主线完成与经验/保底同一次落盘")
	var saved := G.prog.duplicate(true)
	_check(G.reload_save() and G.story_step_done("s10") and _gear().size() == 1, "首胜任务和保底实际重读一致")
	var lines := G.reward_lines({"campaign_gear":CampaignGear.reward("s25","zs")})
	_check("主线保底：霜关大剑（Lv35）" in lines and "保底材料：强化石 ×5" in lines, "预览必须显示装备/需求/保底材料")
	var rng := RandomNumberGenerator.new()
	rng.seed = 317
	for i in 1000:
		var drop := Inventory.roll_drop(G.equip_cfg(),TableCache.drops_config(),"boss",rng)
		_check(not drop.is_empty() and bool(G.equip_tpl(drop.tpl).get("random_drop",true)), "随机首领战利不得漏出高阶主线保底")
	_reset()
	G.campaign_gear_claim(false)
	var inst: Dictionary = _gear().back()
	var malformed := G.prog.duplicate(true)
	malformed.inventory.instances.back()["source_id"] = []
	_check(not bool(SaveData.validate({"prog":malformed},int(Time.get_unix_time_from_system())).ok), "坏来源字段拒绝，旧缺来源实例仍接受")
	var bag := BagPanel.new()
	add_child(bag)
	bag._sel_uid = int(inst.uid)
	bag._refresh()
	await get_tree().process_frame
	var found := false
	for child in bag._detail.find_children("*","Label",true,false):
		if child is Label and child.text.begins_with("需求 Lv"):
			found = true
			_check(bag._detail_scroll.size.x >= child.size.x and child.text == "需求 Lv.42 · 主线保底 · 双关定路", "来源与需求中文详情不截断")
	_check(found, "背包必须显示实际装备来源")
	bag.queue_free()
	await get_tree().process_frame

class FailedGearHost extends "res://src/autoload/G.gd":
	var can_save := false
	var bad_tpl := ""
	func save_game() -> bool: return can_save
	func equip_tpl(id: String) -> Dictionary:
		return {} if id == bad_tpl else super.equip_tpl(id)
