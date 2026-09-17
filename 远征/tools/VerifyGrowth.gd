# VerifyGrowth.gd —— 养成 6 线冒烟（场景模式：godot --headless --path . res://tools/VerifyGrowth.tscn）
# 覆盖：5 张新表读取 / 天赋点数与 tier 门槛 / 装备强化（消耗·成功率·失败不掉级·满级）与强化属性 /
#       宝石数值与镶嵌孔位 / 精炼洗词条与锁定耗符 / 技能书升级与 k 加成 / 坐骑购买升阶骑乘 /
#       称号条件领取与荣誉购买佩戴 / 宠物喂养·突破·资质·战斗快照 / growth_bonuses 聚合（含武器绑人物） /
#       BattleSim 养成接入（角色属性·技能 k·宠物快照与回退）/ 存档往返 / 养成主页与 6 子面板实例化
extends Node

# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const GrowthPanelScript := preload("res://src/ui/GrowthPanel.gd")

var _fails := 0
var _sid := ""   # 当前角色首个 k>0 技能（第 5 节测出，第 10/11 节复用）


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_growth.json"  # 别污染真实存档
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


## 重置到确定状态（钱包/道具清空，养成 6 线字段归零）
func _reset(level := 1) -> void:
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.items = {}
	G.prog["level"] = level
	G.prog["exp"] = 0
	G.prog["pets"] = ["pet_rockturtle"]
	G.prog["world_cleared"] = {}
	G.prog["talents"] = {}
	G.prog["equip"] = {}
	G.prog["skills"] = {}
	G.prog["mounts"] = {"owned": {}, "active": ""}
	G.prog["titles"] = {"owned": [], "active": ""}
	G.prog["pet_stat"] = {}
	G.selected_role = "zs"
	G.save_game()


func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


## 找首个 randf() 落在阈值下（invert=true 时取不低于）的种子：先探后放，强化掷点确定化
func _first_seed_with_roll_below(threshold: float, invert := false) -> int:
	for s in range(1, 5000):
		var r := RandomNumberGenerator.new()
		r.seed = s
		if (r.randf() < threshold) != invert:
			return s
	return 1


## 角色首个 k>0 的伤害技能（测技能书加成用；buff 技能 k=0 测不出差异）
func _first_damage_skill(role_id: String) -> String:
	var skills: Array = TableCache.get_role(role_id).get("skills", [])
	for s in skills:
		if float(TableCache.get_skill(String(s)).get("k", 0.0)) > 0.0:
			return String(s)
	return String(skills[0]) if not skills.is_empty() else ""


func _run() -> void:
	# —— 0. 五张新表 ——
	var tc_cfg := TableCache.talents_config()
	_check(int(tc_cfg.get("points_per_levels", 0)) == 5, "天赋应每 5 级 1 点")
	_check((tc_cfg.get("branches", []) as Array).size() == 3, "天赋应三系")
	var node_n := 0
	for b in tc_cfg.get("branches", []):
		node_n += ((b as Dictionary).get("nodes", []) as Array).size()
	_check(node_n == 30, "三系应共 30 节点，实为 %d" % node_n)
	_check((TableCache.equip_config().get("slots", []) as Array).size() == 6, "装备应 6 槽")
	_check(int(TableCache.skillbook_config().get("max_level", 0)) == 10, "技能书上限应 10 级")
	_check((TableCache.mounts_config().get("mounts", []) as Array).size() == 6, "坐骑应 6 类")
	_check((TableCache.titles_config().get("titles", []) as Array).size() == 12, "称号应 12 个")

	# —— 1. 天赋树 ——
	_reset(10)
	_check(G.talent_points_total() == 2, "10 级应有 2 点天赋，实为 %d" % G.talent_points_total())
	_check(G.talent_points_left() == 2, "未加点时应剩 2 点")
	_check(G.talent_add("fury_1"), "fury_1 首点应成功")
	_check(G.talent_points_spent() == 1 and G.talent_points_left() == 1, "加点后 已投1/剩1")
	_check(G.talent_can_add("fury_2"), "本系已投 1 点应解锁 tier2")
	_check(not G.talent_can_add("fury_3"), "tier3 需本系已投 2 点")
	_check(G.talent_add("fury_2"), "fury_2 应可点")
	_check(G.talent_points_left() == 0, "点数应耗尽")
	_check(not G.talent_add("fury_1"), "无点数时应拒绝加点")
	var n5 := G.talent_node("fury_5")
	_check(String(n5.get("branch", "")) == "fury"
		and absf(float((n5.get("effect", {}) as Dictionary).get("energy_pct", 0.0)) - 0.10) < 0.0001,
		"节点查询应回写 branch 且带 effect")
	_check(G.talent_node("nope").is_empty(), "未知节点应返回空")
	_reset(60)
	_check(G.talent_points_total() == 12, "60 级应有 12 点")
	G.talent_add("fury_1")
	G.talent_add("fury_1")
	G.talent_add("fury_1")
	_check(not G.talent_can_add("fury_1"), "fury_1 点满 3 后不可再点")
	_check(not G.talent_can_add("fury_10"), "tier10 需本系已投 9 点（仅 3）")
	var gb0 := G.growth_bonuses("zs")
	_check(absf(float(gb0["atk_pct"]) - 0.06) < 0.0001, "fury_1×3 应给攻击+6％，实为 %.3f" % float(gb0["atk_pct"]))
	_reset(4)
	_check(G.talent_points_total() == 0, "4 级应 0 点")

	# —— 2. 装备强化 ——
	_reset(1)
	_check(G.equip_weapon_slot("zs") == "sword" and G.equip_weapon_slot("ck") == "spear"
		and G.equip_weapon_slot("fs") == "staff" and G.equip_weapon_slot("fz") == "hammer",
		"四系武器应绑定对应人物")
	var c0 := G.equip_enhance_cost("sword")
	_check(int(c0["gold"]) == 150 and int(c0["item_n"]) == 1, "lv0 强化应耗 150 金 + 1 石")
	G.prog["equip"] = {"sword": {"lv": 5, "gems": [], "affixes": []}}
	var c5 := G.equip_enhance_cost("sword")
	_check(int(c5["gold"]) == 900 and int(c5["item_n"]) == 2, "lv5 强化应耗 900 金 + 2 石")
	_check(absf(G.equip_enhance_rate("sword") - pow(0.9, 6.0)) < 0.0001, "成功率应为 0.9^目标级")
	G.prog["equip"] = {}
	_check(absf(G.equip_enhance_rate("sword") - 0.9) < 0.0001, "lv0→1 成功率应 0.9")
	var r_ng: Dictionary = G.equip_enhance("sword")
	_check(not bool(r_ng["ok"]) and String(r_ng["err"]) == "金币不足", "无金币应拒绝强化")
	G.wallet["gold"] = 1000
	r_ng = G.equip_enhance("sword")
	_check(not bool(r_ng["ok"]) and String(r_ng["err"]) == "强化石不足", "无强化石应拒绝")
	var seed_ok := _first_seed_with_roll_below(0.9)
	var seed_ng := _first_seed_with_roll_below(0.9, true)
	G.items = {"enhance_stone": 10}
	var r_ok := G.equip_enhance("sword", _rng(seed_ok))
	_check(bool(r_ok["ok"]) and bool(r_ok["success"]) and int(r_ok["lv"]) == 1, "强化成功应升 1 级")
	_check(int(G.wallet["gold"]) == 850 and G.item_count("enhance_stone") == 9, "成功应扣 150 金 1 石")
	G.prog["equip"] = {}
	G.wallet["gold"] = 1000
	G.items = {"enhance_stone": 10}
	var r_fl := G.equip_enhance("sword", _rng(seed_ng))
	_check(bool(r_fl["ok"]) and not bool(r_fl["success"]) and int(r_fl["lv"]) == 0, "强化失败不掉级")
	_check(int(G.wallet["gold"]) == 850 and G.item_count("enhance_stone") == 9, "失败仍扣费")
	G.prog["equip"] = {"sword": {"lv": 20, "gems": [], "affixes": []}}
	G.wallet["gold"] = 99999
	G.items = {"enhance_stone": 99}
	_check(not bool(G.equip_enhance("sword")["ok"]), "满级应拒绝强化")
	# 强化属性：lv10 大剑 atk = 10×(1+0.1×10)=20；饰品 crit 不吃倍率
	G.prog["equip"] = {"sword": {"lv": 10, "gems": [], "affixes": []},
		"accessory": {"lv": 10, "gems": [], "affixes": []}}
	var bs := G.equip_base_stat("sword")
	_check(int(bs.get("atk", 0)) == 20, "大剑 lv10 攻击应 20，实为 %d" % int(bs.get("atk", 0)))
	var ba := G.equip_base_stat("accessory")
	_check(int(ba.get("hp", 0)) == 140 and absf(float(ba.get("crit", 0.0)) - 0.02) < 0.0001,
		"饰品 lv10 生命应 140 且暴击不加倍")

	# —— 3. 宝石 ——
	_reset(1)
	_check(G.equip_gem_value("gem_atk_3") == 10 and G.equip_gem_value("gem_hp_5") == 190
		and G.equip_gem_value("gem_def_1") == 2, "宝石数值应按色×级读取")
	_check(G.equip_gem_value("gem_atk_9") == 0, "超范围宝石应无效")
	var s0: Dictionary = G.equip_socket_gem("sword", "gem_atk_3")
	_check(not bool(s0["ok"]) and String(s0["err"]) == "没有这颗宝石", "没有宝石不能镶嵌")
	G.items = {"gem_atk_3": 1}
	s0 = G.equip_socket_gem("sword", "gem_atk_3")
	_check(not bool(s0["ok"]) and String(s0["err"]) == "金币不足", "开孔费不足应拒绝")
	G.wallet["gold"] = 1000
	s0 = G.equip_socket_gem("sword", "gem_atk_3")
	_check(bool(s0["ok"]), "镶嵌应成功")
	_check(int(G.wallet["gold"]) == 800 and G.item_count("gem_atk_3") == 0, "镶嵌应扣 200 金 1 宝石")
	_check(int(G.equip_slot_bonus("sword").get("atk", 0)) == 20, "大剑 atk 应 10+宝石10=20")
	G.items = {"gem_atk_1": 1, "gem_def_2": 1, "gem_hp_1": 1}
	G.equip_socket_gem("sword", "gem_atk_1")
	G.equip_socket_gem("sword", "gem_def_2")
	_check(int(G.wallet["gold"]) == 400, "三次开孔应各扣 200")
	var s_full: Dictionary = G.equip_socket_gem("sword", "gem_hp_1")
	_check(not bool(s_full["ok"]) and String(s_full["err"]) == "孔位已满", "3 孔满后应拒绝")
	_check(int(G.wallet["gold"]) == 400 and G.item_count("gem_hp_1") == 1, "孔满拒绝不应扣费")

	# —— 4. 精炼 ——
	_reset(1)
	G.items = {"refine_stone": 10, "lock_rune": 5}
	var rr := G.equip_refine("sword", _rng(42))
	_check(bool(rr["ok"]), "精炼应成功")
	var aff: Array = rr["affixes"]
	_check(aff.size() == 4, "应洗出 4 条词条，实为 %d" % aff.size())
	var pool_stats := ["atk_pct", "def_pct", "maxhp_pct", "crit_add", "spd_pct"]
	var all_valid := true
	for a in aff:
		var ad := a as Dictionary
		if not pool_stats.has(String(ad.get("stat", ""))) or float(ad.get("v", 0.0)) <= 0.0:
			all_valid = false
	_check(all_valid, "词条应全部来自池且数值为正")
	_check(G.item_count("refine_stone") == 8, "精炼应耗 2 精炼石")
	var a0 := (aff[0] as Dictionary).duplicate()
	G.equip_toggle_lock("sword", 0)
	var rr2 := G.equip_refine("sword", _rng(43))
	_check(bool(rr2["ok"]), "锁定后精炼应成功")
	var a0n := (rr2["affixes"] as Array)[0] as Dictionary
	_check(String(a0n["stat"]) == String(a0["stat"]) and is_equal_approx(float(a0n["v"]), float(a0["v"])),
		"锁定词条应保持不变")
	_check(G.item_count("lock_rune") == 4 and G.item_count("refine_stone") == 6, "锁定应额外耗 1 锁符")
	for i in range(1, 4):
		G.equip_toggle_lock("sword", i)
	G.items["lock_rune"] = 2
	var rr3 := G.equip_refine("sword", _rng(44))
	_check(not bool(rr3["ok"]) and G.item_count("refine_stone") == 6, "锁符不足应拒绝且不扣精炼石")

	# —— 5. 技能书 ——
	_reset(1)
	_sid = _first_damage_skill("zs")
	_check(_sid != "", "应能取到角色技能")
	_check(G.skill_level(_sid) == 1, "技能默认 1 级")
	_check(G.skill_upgrade_cost(_sid) == 60, "升 2 级应耗 60 远征币")
	_check(not G.skill_upgrade(_sid), "无远征币应升级失败")
	G.wallet["expedition"] = 60
	_check(G.skill_upgrade(_sid), "升级应成功")
	_check(G.skill_level(_sid) == 2 and int(G.wallet["expedition"]) == 0, "升级后应 2 级且扣费")
	_check(absf(G.skill_k_mult(_sid) - 1.05) < 0.0001, "2 级 k 应 +5%")
	_check(G.skill_upgrade_cost(_sid) == 90, "升 3 级应耗 90 远征币")
	G.prog["skills"] = {_sid: 10}
	_check(G.skill_upgrade_cost(_sid) == 0 and not G.skill_upgrade(_sid), "满级不可再升")
	_check(absf(G.skill_k_mult(_sid) - 1.45) < 0.0001, "10 级 k 应 +45%")

	# —— 6. 坐骑 ——
	_reset(1)
	_check(not bool(G.mount_buy("horse")["ok"]), "无金币应买不了坐骑")
	G.wallet["gold"] = 2000
	var mb := G.mount_buy("horse")
	_check(bool(mb["ok"]) and int(mb["tier"]) == 1, "购入应得 1 阶")
	_check(int(G.wallet["gold"]) == 0, "购入应扣 2000 金")
	_check(G.mount_active() == "horse", "首购应自动骑乘")
	var gb1 := G.growth_bonuses("zs")
	_check(absf(float(gb1["spd_pct"]) - 0.05) < 0.0001, "烈焰马 1 阶应 +5% 速度")
	G.wallet["gold"] = 8000
	G.wallet["honor"] = 200
	mb = G.mount_buy("horse")
	_check(bool(mb["ok"]) and int(mb["tier"]) == 2, "升阶应得 2 阶")
	var gb2 := G.growth_bonuses("zs")
	_check(absf(float(gb2["spd_pct"]) - 0.10) < 0.0001 and absf(float(gb2["atk_pct"]) - 0.03) < 0.0001,
		"烈焰马 2 阶应 +10% 速度 +3% 攻击")
	_check(not bool(G.mount_buy("horse")["ok"]), "已满阶应拒绝")
	_check(not G.mount_set_active("bear"), "未拥有不能骑乘")
	G.wallet["gold"] = 2000
	_check(bool(G.mount_buy("bear")["ok"]), "铁背熊购入应成功")
	_check(G.mount_set_active("bear"), "已拥有应可骑乘")
	var gb3 := G.growth_bonuses("zs")
	_check(absf(float(gb3["def_pct"]) - 0.05) < 0.0001 and absf(float(gb3["spd_pct"])) < 0.0001,
		"换骑铁背熊后应只生效熊加成")

	# —— 7. 称号 ——
	_reset(10)
	_check(G.title_cond_met(G.title_cfg("t_rookie")), "10 级应达成「初出茅庐」")
	_check(not G.title_cond_met(G.title_cfg("t_legend")), "10 级不应达成「远征传说」")
	var hp_before := int(G.growth_bonuses("zs")["hp_add"])
	_check(bool(G.title_claim("t_rookie")["ok"]), "条件达成应免费领")
	_check(G.title_owned("t_rookie") and G.title_active() == "t_rookie", "领取后应拥有并自动佩戴")
	_check(not bool(G.title_claim("t_rookie")["ok"]), "重复领取应拒绝")
	_check(int(G.growth_bonuses("zs")["hp_add"]) == hp_before + 50, "「初出茅庐」应 +50 生命")
	_check(not bool(G.title_claim("t_legend")["ok"]), "条件未达成且无售价应拒绝")
	G.wallet["honor"] = 499
	_check(not bool(G.title_claim("t_honor1")["ok"]), "荣誉不足应拒绝")
	G.wallet["honor"] = 500
	_check(bool(G.title_claim("t_honor1")["ok"]), "荣誉购买应成功")
	_check(int(G.wallet["honor"]) == 0, "应扣 500 荣誉")
	_check(G.title_set_active("t_honor1"), "已拥有应可佩戴")
	_check(not G.title_set_active("t_snow"), "未拥有不可佩戴")
	_check(G.title_set_active("") and G.title_active() == "", "应可卸下称号")

	# —— 8. 宠物养成 ——
	_reset(5)
	var st0 := G.pet_stat("pet_rockturtle")
	_check(int(st0.get("star", 0)) >= 1 and int(st0.get("star", 0)) <= 5, "首访应随机 1~5 星")
	_check((G.prog.get("pet_stat", {}) as Dictionary).has("pet_rockturtle"), "资质应落盘")
	G.prog["pet_stat"]["pet_rockturtle"] = {"lv": 1, "exp": 0, "star": 3, "brk": 0}
	_check(absf(G.pet_growth_mult("pet_rockturtle") - 1.2) < 0.0001, "3 星成长应 ×1.2")
	G.items = {"pet_food": 3}
	var f1 := G.pet_feed("pet_rockturtle")
	_check(bool(f1["ok"]) and int(f1["ups"]) == 1 and int(f1["lv"]) == 2, "喂 100 经验应升 1 级（80 经验线）")
	var f2 := G.pet_feed("pet_rockturtle")
	_check(bool(f2["ok"]) and int(f2["ups"]) == 0 and int(f2["lv"]) == 2, "经验不足应不升级")
	var f3 := G.pet_feed("pet_rockturtle")
	_check(bool(f3["ok"]) and int(f3["lv"]) == 3, "累计经验应再升 1 级")
	_check(G.item_count("pet_food") == 0, "应耗 3 份宠物粮")
	_check(not bool(G.pet_feed("pet_rockturtle")["ok"]), "无粮应喂不了")
	G.prog["pet_stat"]["pet_rockturtle"] = {"lv": 5, "exp": 0, "star": 3, "brk": 0}
	G.items = {"pet_food": 1}
	_check(not bool(G.pet_feed("pet_rockturtle")["ok"]), "宠物等级不应超过人物")
	# 突破
	G.prog["pet_stat"]["pet_rockturtle"] = {"lv": 5, "exp": 0, "star": 3, "brk": 0}
	var bc := G.pet_break_cost("pet_rockturtle")
	_check(int(bc.get("crystal", 0)) == 10 and int(bc.get("soul", 0)) == 100, "1 层突破应耗 10 晶 + 100 魂")
	G.items = {"break_crystal": 10}
	G.wallet["soul"] = 100
	var br := G.pet_break("pet_rockturtle")
	_check(bool(br["ok"]) and int(br["brk"]) == 1, "突破应成功")
	_check(absf(G.pet_stat_mult("pet_rockturtle") - 1.08) < 0.0001, "1 层突破应 +8%")
	_check(G.item_count("break_crystal") == 0 and int(G.wallet["soul"]) == 0, "突破应扣材料")
	G.prog["pet_stat"]["pet_rockturtle"] = {"lv": 5, "exp": 0, "star": 3, "brk": 5}
	_check(G.pet_break_cost("pet_rockturtle").is_empty(), "满层应无消耗表")
	_check(not bool(G.pet_break("pet_rockturtle")["ok"]), "满层应拒绝突破")
	# 资质
	G.items = {"aptitude_fruit": 1}
	var rs2 := G.pet_reroll_star("pet_rockturtle")
	_check(bool(rs2["ok"]) and int(rs2["star"]) >= 1 and int(rs2["star"]) <= 5, "洗资质应重随 1~5 星")
	_check(G.item_count("aptitude_fruit") == 0, "应耗 1 资质果")
	_check(not bool(G.pet_reroll_star("pet_rockturtle")["ok"]), "无果应拒绝")
	_check(not bool(G.pet_feed("pet_frostwolf")["ok"]), "未收集的宠物不能养成")
	# 战斗快照
	G.prog["pet_stat"]["pet_rockturtle"] = {"lv": 4, "exp": 0, "star": 5, "brk": 2}
	var snap := G.battle_pet_stats(["pet_rockturtle", "pet_frostwolf", ""])
	_check(snap.has("pet_rockturtle") and not snap.has("pet_frostwolf"), "快照应只含已收集宠")
	var sp := snap["pet_rockturtle"] as Dictionary
	_check(int(sp["level"]) == 4 and absf(float(sp["stat_mult"]) - 1.16) < 0.0001
		and absf(float(sp["growth_mult"]) - 1.6) < 0.0001, "快照数值应与养成一致")

	# —— 9. 养成聚合（含武器绑人物）——
	_reset(10)
	G.prog["talents"] = {"fury_1": 1}
	G.prog["equip"] = {
		"sword": {"lv": 10, "gems": ["gem_atk_3"], "affixes": []},
		"armor": {"lv": 0, "gems": [], "affixes": []},
		"accessory": {"lv": 0, "gems": [], "affixes": []},
	}
	G.prog["mounts"] = {"owned": {"horse": 1}, "active": "horse"}
	G.prog["titles"] = {"owned": ["t_rookie"], "active": "t_rookie"}
	var agg := G.growth_bonuses("zs")
	_check(absf(float(agg["atk_pct"]) - 0.02) < 0.0001, "聚合：天赋攻击+2%")
	_check(int(agg["atk_add"]) == 30, "聚合：大剑 lv10(20)+攻击宝石(10)=30，实为 %d" % int(agg["atk_add"]))
	_check(int(agg["def_add"]) == 6, "聚合：护甲防御+6")
	_check(int(agg["hp_add"]) == 170, "聚合：甲50+饰70+称号50=170，实为 %d" % int(agg["hp_add"]))
	_check(absf(float(agg["spd_pct"]) - 0.05) < 0.0001, "聚合：烈焰马速度+5%")
	_check(absf(float(agg["crit_add"]) - 0.02) < 0.0001, "聚合：饰品暴击+2%")
	var agg_ck := G.growth_bonuses("ck")
	_check(int(agg_ck["atk_add"]) == 10, "换穿杨应取长枪(lv0 攻10)而非大剑，实为 %d" % int(agg_ck["atk_add"]))

	# —— 10. BattleSim 接入 ——
	_reset(5)
	var rs5 := TableCache.role_stats("zs", 5)
	var sim := BattleSim.new()
	sim.setup(7, {
		"role_id": "zs", "level": 5, "traits": [],
		"growth": {"atk_pct": 0.1, "atk_add": 5.0, "maxhp_pct": 0.1, "hp_add": 40, "energy_pct": 0.10},
		"skill_levels": {_sid: 5},
		"active_pet": "pet_rockturtle",
		"pet_stats": {"pet_rockturtle": {"level": 5, "stat_mult": 1.08, "growth_mult": 0.8}},
	}, {"theme": "forest", "node_type": "normal", "layer": 1})
	var ru := sim.role_unit()
	_check(ru != null, "应能取到角色单位")
	_check(ru.base_atk == maxi(1, int(float(rs5.atk) * 1.1 + 5.0)),
		"养成后攻击应 ×1.1+5，实为 %d" % ru.base_atk)
	_check(ru.base_max_hp == maxi(1, int(float(rs5.max_hp) * 1.1 + 40.0)),
		"养成后生命应 ×1.1+40，实为 %d" % ru.base_max_hp)
	_check(absf(ru.energy_gain_pct - 0.10) < 0.001, "能量获取应 +10%")
	var k0 := float(TableCache.get_skill(_sid).get("k", 0.0))
	var k_in := -1.0
	for s in ru.skills:
		if String((s as Dictionary)["id"]) == _sid:
			k_in = float((s as Dictionary)["def"].get("k", -1.0))
	_check(k_in >= 0.0 and is_equal_approx(k_in, snappedf(k0 * 1.2, 0.001)),
		"5 级技能 k 应 ×1.2（原 %.3f 实 %.3f）" % [k0, k_in])
	var pet_u: Combatant = null
	for u in sim.units:
		if u.kind == "pet" and u.side == "ally":
			pet_u = u
	_check(pet_u != null, "应能取到宠物单位")
	# 快照：lv5→gl=4、成长×0.8、突破×1.08；岩龟 base hp80/atk9/def10 growth hp11/atk1.5/def1.8
	if pet_u != null:
		_check(pet_u.base_max_hp == 124, "快照生命应 (80+11×4×0.8)×1.08=124，实为 %d" % pet_u.base_max_hp)
		_check(pet_u.base_atk == 14, "快照攻击应 (9+1.5×4×0.8)×1.08=14，实为 %d" % pet_u.base_atk)
		_check(pet_u.base_def == 17, "快照防御应 (10+1.8×4×0.8)×1.08=17，实为 %d" % pet_u.base_def)
	# 无快照回退：宠物等级随人物
	var sim2 := BattleSim.new()
	sim2.setup(7, {"role_id": "zs", "level": 5, "traits": [], "active_pet": "pet_rockturtle"},
		{"theme": "forest", "node_type": "normal", "layer": 1})
	var pet2: Combatant = null
	for u in sim2.units:
		if u.kind == "pet" and u.side == "ally":
			pet2 = u
	_check(pet2 != null and pet2.base_atk == 15,
		"无快照应随人物等级：攻 9+1.5×4=15，实为 %d" % (pet2.base_atk if pet2 != null else -1))

	# —— 11. 存档往返 ——
	_reset(12)
	G.prog["talents"] = {"fury_1": 2}
	G.prog["equip"] = {"sword": {"lv": 3, "gems": ["gem_atk_3"],
		"affixes": [{"stat": "atk_pct", "v": 0.05, "locked": true}]}}
	G.prog["skills"] = {_sid: 4}
	G.prog["mounts"] = {"owned": {"horse": 1}, "active": "horse"}
	G.prog["titles"] = {"owned": ["t_rookie"], "active": "t_rookie"}
	G.prog["pet_stat"] = {"pet_rockturtle": {"lv": 3, "exp": 10, "star": 4, "brk": 1}}
	G.save_game()
	G.prog["talents"] = {}
	G.prog["equip"] = {}
	G.prog["skills"] = {}
	G.prog["mounts"] = {"owned": {}, "active": ""}
	G.prog["titles"] = {"owned": [], "active": ""}
	G.prog["pet_stat"] = {}
	G._load_save()
	_check(int((G.prog["talents"] as Dictionary).get("fury_1", 0)) == 2, "天赋应随存档恢复")
	_check(int(((G.prog["equip"] as Dictionary).get("sword", {}) as Dictionary).get("lv", 0)) == 3,
		"装备等级应恢复")
	_check(G.skill_level(_sid) == 4, "技能等级应恢复")
	_check(G.mount_active() == "horse" and G.mount_tier("horse") == 1, "坐骑应恢复")
	_check(G.title_owned("t_rookie") and G.title_active() == "t_rookie", "称号应恢复")
	_check(int(G.pet_stat("pet_rockturtle").get("star", 0)) == 4, "宠物资质应恢复")

	# —— 12. 面板实例化（养成主页 + 6 子面板打开/关闭）——
	_reset(20)
	G.wallet = {"gold": 99999, "expedition": 9999, "soul": 9999, "honor": 9999}
	G.items = {"enhance_stone": 99, "refine_stone": 10, "lock_rune": 5,
		"pet_food": 5, "break_crystal": 30, "aptitude_fruit": 2, "gem_atk_3": 1, "gem_hp_2": 1}
	G.prog["pets"] = ["pet_rockturtle", "pet_thunderhawk"]
	var holder := Control.new()
	holder.size = Vector2(480, 800)
	add_child(holder)
	var gp: Control = GrowthPanelScript.new()
	holder.add_child(gp)
	await get_tree().process_frame
	for id in ["talent", "equip", "pet", "skill", "mount", "title"]:
		gp.call("_open", id)
		var sub: Control = gp.get("_sub")
		_check(sub != null, "子面板 %s 应打开" % id)
		if sub != null:
			_check(sub.has_signal("closed"), "子面板 %s 应有 closed 信号" % id)
			await get_tree().process_frame
			sub.emit_signal("closed")
			await get_tree().process_frame
			_check(gp.get("_sub") == null, "子面板 %s 关闭后应复位" % id)
	var closed_hit := {"n": 0}
	gp.connect("closed", func(): closed_hit["n"] += 1)
	gp.call("_close")
	_check(int(closed_hit["n"]) == 1, "养成主页返回应发 closed 信号")
	gp.queue_free()
	await get_tree().process_frame

	if _fails == 0:
		print("GROWTH_OK all tests passed")
	else:
		print("GROWTH_FAIL fails=%d" % _fails)
