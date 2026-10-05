extends Node
const Journey := preload("res://src/world/JourneyService.gd")
const Relics := preload("res://src/world/RelicService.gd")
const Pressure := preload("res://src/world/CampaignPressure.gd")
var fails := 0

func check(ok: bool, line: String) -> void:
	if not ok: fails += 1; push_error("FAIL: " + line)

func _ready() -> void:
	call_deferred("_run")

func _unlocked(host: Object) -> void:
	host._init_state_defaults()
	host.save_locked = false
	host.prog.level = 60
	var done: Array = []
	for row in TableCache.story_quests_config().steps: done.append(row.id)
	host.prog.story = {"step":"", "done":done, "goals":{}}
	host.prog.main_world = {"map_id":"lorin_wilds", "visited_maps":["lorin_wilds", "frost_post", "stele_core"]}

func _ticket(host: Object, roll: float) -> Dictionary:
	var start := Relics.begin(host, "relic_core", "zs")
	check(bool(start.ok), "开战记录保存")
	var pending: Dictionary = host.prog.relic_hunts.pending
	pending.roll = int(roll * int(Relics.cfg().roll_range))
	return pending.duplicate(true)

func _run() -> void:
	var host := get_tree().root.get_node("G")
	host.SAVE_PATH = "user://verify_journey_relics.json"
	_unlocked(host)
	check(Journey.status(host,"frost_post").ok, "到访地点可旅行")
	check(not Journey.status(host,"tidal_gate").ok, "未知地点不可跳过首访")
	var old_story: Dictionary = host.prog.story
	host.prog.story = {"done":[]}
	check(not Journey.status(host,"frost_post").ok, "到访标记也不能绕过主线道路条件")
	host.prog.story = old_story
	host.items.trade_salt = 1
	check(not Journey.status(host,"frost_post").ok, "运输货物不能旅行")
	host.items.erase("trade_salt")
	host.prog.economy = {"orders":{"test":{"status":"active"}}}
	check(not Journey.status(host,"frost_post").ok, "未结运单不能旅行")
	host.prog.economy = {}
	host.prog.road_mail = {"status":"active"}
	check(not Journey.status(host,"frost_post").ok, "邮路不能跳过道路")
	host.prog.road_mail = {}
	host.prog.oaths = {"trips":{"test":{"status":"active","oath":"shelter","phase":1}}}
	check(not Journey.status(host,"frost_post").ok, "护送不能旅行")
	host.prog.oaths = {}
	check(Journey.travel(host,"frost_post").ok and host.prog.main_world.map_id == "frost_post", "旅行保存目的地")
	check(host.reload_save() and host.prog.main_world.map_id == "frost_post", "旅行读档保持目的地")
	var level1 := _sim("stele_cavern")
	var final := _sim("stele_core")
	var old := _sim("")
	check(level1.alive_units("enemy")[0].base_atk == old.alive_units("enemy")[0].base_atk, "第一幕保留难度")
	check(final.alive_units("enemy")[0].base_atk > old.alive_units("enemy")[0].base_atk * 2, "后期首领压力明显增加")
	var mine := BattleSim.new()
	mine.setup(10,{"role_id":"zs","level":60},{"theme":"tomb","solo":true,"lead_mon":"mon_redsand_guard","node_type":"boss","display_level":34,"world_map_id":"rift_mine_vault"})
	var boss := mine.alive_units("enemy")[0]
	boss.hp = int(boss.get_max_hp()*.60)
	mine._apply_phases()
	check(boss.once_flags.has("phase_reinforcement"), "第三幕进入援兵阶段")
	var summon: Dictionary = {}
	for skill in boss.skills:
		if String(skill.id) == "boss_reinforcements": summon = skill.def
	SkillSystem._apply_skill(mine,boss,summon,{})
	check(mine.alive_units("enemy").size() == 3, "援兵真实入场")
	var add := mine.alive_units("enemy")[1]
	add.take_damage(100000,mine.role_unit(),mine)
	check(boss.has_buff("break_window"), "击破援兵产生破绽")
	_unlocked(host)
	var ticket := _ticket(host,.8)
	check(Relics.begin(host,"relic_mine","fs").ticket == ticket, "重开不重抽挑战种子与掉落")
	check(host.save_game() and host.reload_save(), "挑战记录存档往返")
	var resumed: Dictionary = Relics.begin(host,"relic_core","zs").ticket
	check(String(resumed.id) == String(ticket.id) and int(resumed.seed) == int(ticket.seed) and is_equal_approx(float(resumed.roll),float(ticket.roll)), "中断读档继续同一抽签")
	check(Relics.finish(host,ticket.id,"defeat").ok and int(Relics.state(host).get("wins",0)) == 0, "失败不增加胜利与保底")
	ticket = _ticket(host,.8)
	check(Relics.finish(host,ticket.id,"victory").ok and int(Relics.state(host).misses.zs) == 1 and host.item_count("pet_food") == 2, "未掉落也发固定材料")
	var before: Dictionary = host.prog.duplicate(true)
	check(not Relics.finish(host,ticket.id,"victory").ok and host.prog == before and host.item_count("pet_food") == 2, "重复结算不增加计数或材料")
	host.prog.relic_hunts.misses.zs = 399
	ticket = _ticket(host,.8)
	check(Relics.finish(host,ticket.id,"victory").drop and int(Relics.state(host).misses.zs) == 0, "第400胜传世保底并清零")
	var found: Dictionary = {}
	for inst in host.inv_instances():
		if String(inst.tpl) == "tpl_sword_relic": found = inst
	check(not found.is_empty() and bool(found.locked) and host.inv_sell_price(int(found.uid)) == 25000, "传世自动锁定且固定高回收价")
	check(host.inv_equip(int(found.uid)).ok, "传世可穿戴")
	var growth: Dictionary = host.growth_bonuses("zs")
	check(is_equal_approx(float(growth.relic_shield_pct),.10) and is_equal_approx(float(growth.relic_break_damage_pct),.15), "传世特性进入战斗快照")
	var relic := BattleSim.new()
	relic.setup(10,{"role_id":"zs","level":60,"growth":growth},{"theme":"forest","solo":true,"lead_mon":"mon_wolf","node_type":"boss"})
	check(relic.role_unit().has_buff("shield"), "传世开场护盾真实生效")
	var target := relic.alive_units("enemy")[0]
	target.base_max_hp = 10000; target.hp = 10000
	target.add_buff("break_window",150,{"pct":0.0})
	check(target.take_damage(100,relic.role_unit(),relic) == 114 or target.hp == 9885, "传世破绽追击真实增伤")
	check(not Relics.buy(host,"zs").ok, "未满20胜不能金币购买")
	host.prog.relic_hunts.wins = 20
	host.wallet.gold = 150000
	check(Relics.buy(host,"zs").ok and host.wallet.gold == 0, "高价购买真实扣金币")
	check(not Relics.buy(host,"zs").ok, "余额不足拒绝购买")
	host.prog.relic_hunts.wins = 120
	check(Relics.claim_pet(host).ok and host.owns_pet("pet_return_deer") and host.pet_level("pet_return_deer") == 25 and host.pet_stat("pet_return_deer").star == 4, "传世宠物一次结缘并设置初始养成")
	check(not Relics.claim_pet(host).ok, "传世宠物不能重复领")
	check(G.res_tex("pet_return_deer") != null and G.RARITY_NAME.relic == "传世", "新品阶与宠物素材可用")
	check(Relics.validate(Relics.state(host)) and not Relics.validate({"wins":-1}) and not Relics.validate({"pending":{"roll":-1}}), "传世坏档字段拒绝")
	host.inv_grant_equip({"tpl":"tpl_armor_basic","n":60},false)
	var pending_count: int = host.inv_pending().size()
	ticket = _ticket(host,0.0)
	check(Relics.finish(host,ticket.id,"victory",["pet_return_deer"]).drop and host.inv_pending().size() == pending_count+1, "满包传世奖励进入待领")
	check(int(CompanionService.state(host.prog,"pet_return_deer").wins) == 1, "传世挑战参战胜利推进宠物训练")
	var pending_weapon: Dictionary = host.inv_pending().back()
	check(bool(pending_weapon.locked) and CampaignGear.source_text(pending_weapon) == "传世挑战", "待领保留自动锁定和获取来源")
	var failed := FailedHost.new()
	_unlocked(failed)
	before = failed.prog.duplicate(true)
	check(not Journey.travel(failed,"frost_post").ok and failed.prog == before, "旅行保存失败还原")
	check(not Relics.begin(failed,"relic_core","zs").ok and failed.prog == before, "开战保存失败还原抽签")
	failed.prog.relic_hunts = {"wins":120,"misses":{"zs":399},"pending":{"id":"failed","role":"zs","roll":900000}}
	before = failed.prog.duplicate(true)
	check(not Relics.finish(failed,"failed","victory").ok and failed.prog == before and failed.item_count("pet_food") == 0, "结算保存失败还原材料、装备与保底")
	failed.prog.relic_hunts.pending = {}
	failed.wallet.gold = 150000
	before = failed.prog.duplicate(true)
	check(not Relics.buy(failed,"zs").ok and failed.wallet.gold == 150000 and failed.prog == before, "购买保存失败还原钱与装备")
	check(not Relics.claim_pet(failed).ok and not failed.owns_pet("pet_return_deer"), "宠物保存失败保留资格")
	failed.free()
	var page := preload("res://src/ui/JourneyPanel.gd").new()
	add_child(page)
	await get_tree().process_frame
	page._tab = "hunt"; page._refresh()
	await get_tree().process_frame
	check(page._paper.size.x <= 440 and page._paper.size.y <= 736, "新入口短屏可关闭且内容滚动")
	# Exercise the real panel -> battle -> settlement path, including retreat.
	host.selected_role = "zs"
	host.prog.relic_hunts.pending = {}
	page._start_hunt("relic_mine")
	await get_tree().process_frame
	check(page._battle != null and page._battle.sim.campaign_profile == Relics.hunt("relic_mine").difficulty, "传世入口创建实际挑战战斗")
	var panel_wins: int = Relics.state(host).wins
	page.close()
	check(not page.is_queued_for_deletion(), "挑战中不能关闭页签绕过结算")
	page._battle._on_flee(); page._battle._on_flee()
	page._battle.confirm_result()
	await get_tree().process_frame
	check(page._battle == null and Relics.state(host).pending.is_empty() and int(Relics.state(host).wins) == panel_wins, "实际撤退回到传世页且不计胜利")
	page._start_hunt("relic_snow")
	await get_tree().process_frame
	page._battle.sim.finished = true
	page._battle.sim.result = "victory"
	page._battle.confirm_result()
	await get_tree().process_frame
	check(page._battle == null and Relics.state(host).pending.is_empty() and int(Relics.state(host).wins) == panel_wins+1, "实际胜利确认回到传世页并结算一次")
	page.close()
	print("JOURNEY_RELICS_OK" if fails == 0 else "JOURNEY_RELICS_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)

func _sim(map_id: String) -> BattleSim:
	var sim := BattleSim.new()
	sim.setup(1,{"role_id":"zs","level":60},{"theme":"abyss","solo":true,"lead_mon":"mon_abyss_avatar","node_type":"boss","display_level":53,"world_map_id":map_id})
	return sim

class FailedHost extends "res://src/autoload/G.gd":
	func save_game() -> bool: return false
