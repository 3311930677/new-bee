extends "res://tools/VerifyThirdBack.gd"

const PATH := "res://tools/_logs/save_verify_campaign_growth.json"

func _ready() -> void:
	G.SAVE_PATH = PATH
	G.save_locked = false
	G.selected_role = "zs"
	await _run()
	print("CAMPAIGN_GROWTH_OK" if _fails == 0 else "CAMPAIGN_GROWTH_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _reset() -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.SAVE_PATH = PATH
	G.selected_role = "zs"

## 合成旧进度仅供迁移单测；实际四职业续档另由 PlaythroughCampaignGrowth 验证。
func _old(n: int) -> void:
	_reset()
	var done: Array = []
	for i in n:
		var row: Dictionary = TableCache.story_quests_config().steps[i]
		done.append(row.id)
		G.gain_exp(int(row.reward.exp), false)
	G.prog["story"] = {"step": "s%02d" % (n+1) if n < 28 else "", "done": done, "goals": {}}
	G.prog["pets"] = ["pet_rockturtle"]
	G.prog["companions"] = {"active": "pet_rockturtle", "pets": {"pet_rockturtle": {"wins": 3, "traits": ["comp_guard", "comp_pursuit"]}}}
	G.wallet["gold"] = 4321
	G.items["pet_food"] = 8
	G.prog["flags"] = {"investment_fixture": true}
	G.prog["pet_stat"] = {"pet_rockturtle": {"lv": 7, "exp": 18, "star": 4, "brk": 2}}

func _total_exp() -> int:
	var result := int(G.prog.exp)
	for lv in range(1, int(G.prog.level)): result += G.exp_to_next(lv)
	return result

func _simple_map(level: int, mode := "main_world") -> MapScene:
	var run := RunState.new()
	run.setup({"role_id": "zs", "level": level, "potions": 2, "seed": 81})
	MapScene.pending_cfg = {"mode": mode, "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 1, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	return map

func _run() -> void:
	_reset()
	var cfg := CampaignGrowth.config()
	_check(cfg.steps.size() == 32 and cfg.enemy_levels.size() == 15, "主线和地图完整配置")
	var legacy_sum := 0
	var current_sum := 0
	var rows := CampaignGrowth.story_rows()
	for i in rows.size():
		var row: Dictionary = rows[i]
		if i < 28: legacy_sum += int(TableCache.story_quests_config().steps[i].reward.exp)
		current_sum += int(row.reward.exp)
		G.gain_exp(int(row.reward.exp), false)
		_check(int(G.prog.level) == int(cfg.steps[row.id].target_level), "主线单独达到 %s 的目标等级" % row.id)
	_check(legacy_sum == 2525 and current_sum == 148127, "前三幕旧经验预算保留，第四幕前半达到49级并保留第一幕90经验余量")
	_check(G.level_cap() == 60 and int(G.prog.level) == 49, "等级公式与上限保留")
	rows[0].reward.gold = 99999
	_check(int(TableCache.story_quests_config().steps[0].reward.gold) == 40, "覆盖表必须深拷贝")
	_reset()
	var reward := G.story_current().get("reward", {}) as Dictionary
	_check(int(reward.exp) == 102 and int(reward.gold) == 40, "任务预览与实际新版奖励一致")
	var result := G.story_event("talk", "npc_steward", "lorin_wilds", false)
	_check(not result.is_empty() and int(G.prog.level) == 2 and CampaignGrowth.revision(G.prog, "s01") == 2, "新档完成一步立即登记经验版本")
	var fresh_before := G.prog.duplicate(true)
	G.campaign_growth_catchup(false)
	G.story_event("talk", "npc_steward", "lorin_wilds", false)
	_check(G.prog == fresh_before and int(G.wallet.gold) == 40, "新档补领与重复上报不重复发放")
	for n in [12, 20, 28]:
		_old(n)
		var before := G.prog.duplicate(true)
		var wallet := G.wallet.duplicate(true)
		var items := G.items.duplicate(true)
		var catchup := G.campaign_growth_catchup()
		_check(bool(catchup.ok) and int(G.prog.level) == {12:12,20:25,28:42}[n], "旧档完成幕补领达到目标等级")
		_check(G.wallet == wallet and G.items == items and G.prog.story == before.story and G.prog.companions == before.companions and G.prog.pet_stat == before.pet_stat and G.prog.flags == before.flags, "补领只改变角色经验与版本账本")
		var saved := G.prog.duplicate(true)
		_check(G.reload_save() and int(G.prog.level) == int(saved.level) and int(G.prog.exp) == int(saved.exp) and CampaignGrowth.catchup_plan(G.prog).is_empty(), "经验版本实际存取不丢失")
		var loaded := G.prog.duplicate(true)
		_check(int(G.campaign_growth_catchup().exp) == 0 and G.prog == loaded, "重读和重进只能补领一次")
	_old(12)
	var prior := _total_exp()
	CampaignGrowth.mark(G.prog, "s01")
	G.gain_exp(102-15, false)
	G.campaign_growth_catchup(false)
	_check(_total_exp() == prior + 6751 - 710, "混合版本只补未标记步骤")
	_old(1)
	G.ledger().applied.append(RewardLedger.tx_id("campaign_growth", "s01", "2"))
	prior = _total_exp()
	_check(int(G.campaign_growth_catchup(false).exp) == 0 and _total_exp() == prior and CampaignGrowth.revision(G.prog, "s01") == 2, "旧版本标记缺失但账本存在时不得二次发奖")
	_old(28)
	var locked_before := G.prog.duplicate(true)
	G.save_locked = true
	_check(not bool(G.campaign_growth_catchup().ok) and G.prog == locked_before, "锁档拒绝补领且不改进度")
	G.save_locked = false
	var host := FailedGrowthHost.new()
	host.prog = G.prog.duplicate(true)
	_check(not bool(host.campaign_growth_catchup().ok) and host.prog == locked_before and host.level_sounds == 0 and not host._campaign_exp_batch, "写盘失败回滚全部经验版本与账本且不播放成功提示音")
	host.can_save = true
	_check(bool(host.campaign_growth_catchup().ok) and host.level_sounds == 1 and not host._campaign_exp_batch, "旧档多步补领只播放一次升级音")
	host.gain_exp(host.exp_to_next(int(host.prog.level)), false)
	_check(host.level_sounds == 2, "补领后普通升级音必须恢复")
	host.free()
	G.prog.level = 59
	G.prog.exp = G.exp_to_next(59)-1
	_check(bool(G.campaign_growth_catchup(false).ok) and int(G.prog.level) == 60 and int(G.prog.exp) == 0 and CampaignGrowth.catchup_plan(G.prog).is_empty(), "满级补领仍登记且不越界")
	for bad in [[], {"story_revision": []}, {"story_revision": {"s01": 3}}, {"story_revision": {"s01": 1.5}}, {"story_revision": {"s01": "2"}}, {"story_revision": {"s99": 2}}, {"story_revision": {"s01": -1}}]:
		_check(not bool(SaveData.validate({"prog": {"story": {"done": ["s01"]}, "campaign_growth": bad}}, int(Time.get_unix_time_from_system())).ok), "坏版本字段拒绝而非静默清零")
	_check(not CampaignGrowth.validate({"story_revision": {"s01": 2}}, {"done": []}), "未完成步骤不能被提前标记")
	_reset()
	var missing_before := G.prog.duplicate(true)
	_check(CampaignGrowth.catchup_plan(G.prog).is_empty() and bool(G.campaign_growth_catchup().ok) and G.prog == missing_before and not G.prog.has("campaign_growth"), "无已完成主线时查询与补领不得补写默认")
	G.prog.level = 5
	var map := await _simple_map(5)
	for monster in map._monsters: _check(int(monster.display_level) == 2, "边城敌人固定二级")
	var max_before := map.st.max_hp()
	map.st.hp = max_before - 35
	G.prog.level = 8
	map._refresh_hud()
	_check(map.st.level == 8 and map.st.max_hp() - map.st.hp == 35 and map._main_hp_l.text == "生命 %d/%d" % [map.st.hp, map.st.max_hp()], "同图升级立即同步等级与生命且保留已损失生命")
	G.ensure_starter_equip(true)
	map._refresh_hud()
	_check(map.st.growth_bonus == G.growth_bonuses("zs") and map.st.max_hp()-map.st.hp == 35, "装备与天赋生命加成必须纳入地图血条和战斗同口径")
	for monster in map._monsters: _check(int(monster.display_level) == 2, "升级不能改变已经出现的敌人")
	map.st.hp = 0
	G.prog.level = 9
	map._refresh_hud()
	_check(map.st.hp == 0, "等级同步不能复活已死亡玩家")
	map.queue_free()
	await get_tree().process_frame
	_reset()
	G.prog.level = 5
	G.prog.exp = G.exp_to_next(5)-1
	map = await _simple_map(5)
	map.st.hp = map.st.max_hp()-35
	var failed_hp := map.st.hp
	var failed_prog := G.prog.duplicate(true)
	map._encounter = WorldSession.new_encounter("lorin_wilds", 0, Vector2(90,500), "mon_zombie", 5, Vector2(480,710), "", 0, 813)
	WorldSession.advance(map._main_world_state(), map._encounter, WorldSession.ST_BATTLE)
	failed_prog = G.prog.duplicate(true)
	G.save_locked = true
	_check(map._settle_main_world("normal", "mon_zombie") == "save_failed" and map.st.level == 5 and map.st.hp == failed_hp and G.prog == failed_prog, "战利升级写盘失败连同生命和等级整体回滚")
	G.save_locked = false
	_check(map._settle_main_world("normal", "mon_zombie") == "ok" and map.st.level == 6 and map.st.max_hp()-map.st.hp == 35, "战利升级成功立即同步生命上限")
	map.queue_free()
	await get_tree().process_frame

	G.prog.level = 50
	map = await _simple_map(50)
	for monster in map._monsters: _check(int(monster.display_level) == 2, "高等级重返旧地图怪物仍固定二级")
	map.queue_free()
	await get_tree().process_frame
	_check(CampaignGrowth.enemy_level("broken_slope", {"level_offset": 3}, 50) == 10, "可选首领保留独立槽位级差")
	_check(CampaignGrowth.enemy_level("future_map", {}, 17) == 17, "未来未配地图沿用既有等级兜底")
	map = await _simple_map(5, "expedition")
	map.st.hp = 70
	map._sync_campaign_level()
	_check(map.st.level == 5 and map.st.hp == 70, "历练仍持有出发时的等级与生命快照")
	map.queue_free()
	await get_tree().process_frame

class FailedGrowthHost extends "res://src/autoload/G.gd":
	var can_save := false
	var level_sounds := 0
	func save_game() -> bool: return can_save
	func _sfx(name: String, _jitter := 0.03) -> void:
		if name == "level_up": level_sounds += 1
