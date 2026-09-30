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
	G.prog["inventory"] = {"instances": [], "pending": [], "next_uid": 1}
	G.ensure_starter_equip(true)   # P04：装备是实例；重置 = 重发 6 件基础装（uid 从 1 起，确定性）
	G.prog["skills"] = {}
	G.prog["mounts"] = {"owned": {}, "active": ""}
	G.prog["titles"] = {"owned": [], "active": ""}
	G.prog["pet_stat"] = {}
	G.selected_role = "zs"
	G.save_game()


## 背包里（未在身）的第一件实例 uid；没有返回 0
func _bag_uid() -> int:
	var worn := G.inv_worn_uids()
	for it in G.inv_instances():
		var u := int((it as Dictionary).get("uid", 0))
		if not worn.has(u):
			return u
	return 0


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
	# 座骑/槽位这些是**设计常量**（改了就是设计变更，该红）；
	# 称号是**内容表**（加称号是正常的迭代，不该因为加了内容就红），所以用下界而不是等值
	_check((TableCache.titles_config().get("titles", []) as Array).size() >= 12,
		"称号表应至少有 12 条（加称号不该让这条用例红，实为 %d）"
		% (TableCache.titles_config().get("titles", []) as Array).size())

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
	G.equip_state("sword")["lv"] = 5   # P04：等级写在实例上（旧档的 dict 形状已由 v5 迁移吃掉）
	var c5 := G.equip_enhance_cost("sword")
	_check(int(c5["gold"]) == 900 and int(c5["item_n"]) == 2, "lv5 强化应耗 900 金 + 2 石")
	_check(absf(G.equip_enhance_rate("sword") - pow(0.9, 6.0)) < 0.0001, "成功率应为 0.9^目标级")
	G.equip_state("sword")["lv"] = 0
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
	G.equip_state("sword")["lv"] = 0
	G.wallet["gold"] = 1000
	G.items = {"enhance_stone": 10}
	var r_fl := G.equip_enhance("sword", _rng(seed_ng))
	_check(bool(r_fl["ok"]) and not bool(r_fl["success"]) and int(r_fl["lv"]) == 0, "强化失败不掉级")
	_check(int(G.wallet["gold"]) == 850 and G.item_count("enhance_stone") == 9, "失败仍扣费")
	G.equip_state("sword")["lv"] = 20
	G.wallet["gold"] = 99999
	G.items = {"enhance_stone": 99}
	_check(not bool(G.equip_enhance("sword")["ok"]), "满级应拒绝强化")
	# 强化属性：lv10 大剑 atk = 10×(1+0.1×10)=20；饰品 crit 不吃倍率
	G.equip_state("sword")["lv"] = 10
	G.equip_state("accessory")["lv"] = 10
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
	# 进化（P1-3）：一次、耗晶石、全属性 +25％、重复拒绝
	G.prog["pet_stat"]["pet_rockturtle"] = {"lv": 4, "exp": 0, "star": 5, "brk": 2}
	G.items = {"evolve_crystal": 3}
	var ev1 := G.pet_evolve("pet_rockturtle")
	_check(bool(ev1["ok"]), "满足条件应可进化（实为 %s）" % String(ev1.get("err", "")))
	_check(absf(G.pet_stat_mult("pet_rockturtle") - 1.16 * 1.25) < 0.0001, "进化应叠乘 +25％")
	_check(G.item_count("evolve_crystal") == 0, "进化应扣 3 晶石")
	_check(bool((G.pet_stat("pet_rockturtle") as Dictionary).get("evolved", false)), "进化态应落盘")
	_check(not bool(G.pet_evolve("pet_rockturtle")["ok"]), "重复进化应被拒绝")
	G.prog["pet_stat"]["pet_rockturtle"] = {"lv": 4, "exp": 0, "star": 5, "brk": 2}
	G.items = {}
	_check(not bool(G.pet_evolve("pet_rockturtle")["ok"]), "晶石不足应拒绝进化")
	_check(not bool(G.pet_evolve("pet_frostwolf")["ok"]), "未收集的宠物不能进化")

	# —— 9. 养成聚合（含武器绑人物）——
	_reset(10)
	G.prog["talents"] = {"fury_1": 1}
	G.equip_state("sword")["lv"] = 10
	G.equip_state("sword")["gems"] = ["gem_atk_3"]
	# 甲/饰保持 _reset 发的基础装（护甲 def6+hp50、饰品 hp70+crit0.02），聚合期望值与旧档逐项相同
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

	# —— 9.5 成长口径（轮次 21 · #29）——
	# 暴击以前写死 0.05+0.001*level，把 roles.json 里四职业的 base.crit 与 growth.json 的
	# per_level.crit 全忽略；穿杨（ck）明明是 0.07 的暴击职业，实战里却和破军一样。
	var per_crit := float(TableCache.growth().get("per_level", {}).get("crit", 0.0))
	_check(per_crit > 0.0, "growth.json 应声明 per_level.crit（实为 %f）" % per_crit)
	for rid in ["zs", "ck", "fs", "fz"]:
		var rbase: Dictionary = TableCache.get_role(rid).get("base", {})
		var base_crit := float(rbase.get("crit", 0.0))
		_check(base_crit > 0.0, "roles.json 的 %s 应声明 base.crit" % rid)
		for lv in [1, 30, 60]:
			var st := TableCache.role_stats(rid, lv)
			var want := base_crit + per_crit * float(lv - 1)
			_check(absf(float(st.get("crit", -1.0)) - want) < 0.000001,
				"%s lv%d 暴击应为 base(%f)+per_level×%d = %f，实为 %f"
				% [rid, lv, base_crit, lv - 1, want, float(st.get("crit", -1.0))])
			# hp/atk/def 同样是 base + per_level×(lv-1)：等级 1 必须等于 base
			if lv == 1:
				_check(int(st.get("atk", -1)) == int(rbase.get("atk", 0))
					and int(st.get("max_hp", -1)) == int(rbase.get("hp", 0)),
					"%s 1 级攻击/生命应等于 roles.json base" % rid)
	# 职业差异必须真的体现出来：穿杨比破军高 0.02 暴击（表里一直写着，代码以前没读）
	var crit_zs := float(TableCache.role_stats("zs", 60).get("crit", 0.0))
	var crit_ck := float(TableCache.role_stats("ck", 60).get("crit", 0.0))
	_check(absf((crit_ck - crit_zs) - 0.02) < 0.000001,
		"满级穿杨应比破军高 0.02 暴击（实为 %.4f）" % (crit_ck - crit_zs))

	# 经验曲线：类型显式声明，数值与文档曲线一致，且不执行表里的字符串
	_check(TableCache.exp_formula_kind() == "linear_plus_exp",
		"growth.json 应声明 exp.type=linear_plus_exp（实为「%s」）" % TableCache.exp_formula_kind())
	var exp_ok := true
	var exp_bad := ""
	for lv in [1, 2, 5, 17, 33, 59]:
		var want_exp := int(float(lv) * 100.0 + 2.0 * pow(5.0, 0.1 * float(lv)))
		var got_exp := TableCache.exp_to_next(lv)
		if got_exp != want_exp:
			exp_ok = false
			exp_bad = "lv%d 期望 %d 实为 %d" % [lv, want_exp, got_exp]
	_check(exp_ok, "经验曲线应与既定公式逐级一致（%s）" % exp_bad)
	_check(G.exp_to_next(G.level_cap()) == 0, "满级不应有升级需求")

	# —— 9.6 称号表关系校验（数据关系断言，不是"实现算什么就期望什么"）——
	# 新增称号最常见的错是：cond.type 拼错、world 写成表里没有的 id、bonus 键名不在
	# 加成聚合里（加了等于没加）。这些在界面上只是"永远不解锁"，没人会发现。
	var theme_ids := {}
	for tid in TableCache.maps_config().get("themes", {}):
		theme_ids[String(tid)] = true
	var bonus_keys := ["atk_pct", "def_pct", "maxhp_pct", "crit_add", "spd_pct",
		"atk_add", "def_add", "hp_add"]
	var t_bad: Array = []
	var t_ids := {}
	var t_cost := 0
	for t in G.titles_cfg():
		var td := t as Dictionary
		var tid2 := String(td.get("id", ""))
		if tid2.is_empty() or t_ids.has(tid2):
			t_bad.append("id 缺失或重复：" + tid2)
			continue
		t_ids[tid2] = true
		if String(td.get("name", "")).is_empty():
			t_bad.append("%s 缺 name" % tid2)
		var cond: Dictionary = td.get("cond", {})
		var cost: Dictionary = td.get("cost", {})
		if cond.is_empty() and cost.is_empty():
			t_bad.append("%s 既无 cond 也无 cost（永远拿不到）" % tid2)
		if not cond.is_empty():
			var ct := String(cond.get("type", ""))
			if not ["level", "pets", "gold", "clear_world"].has(ct):
				t_bad.append("%s cond.type 未支持：%s" % [tid2, ct])
			if ct == "clear_world" and not theme_ids.has(String(cond.get("world", ""))):
				t_bad.append("%s 的 world 不存在：%s" % [tid2, String(cond.get("world", ""))])
			if ct != "clear_world" and int(cond.get("n", 0)) < 1:
				t_bad.append("%s 的 cond.n 应为正数" % tid2)
		if not cost.is_empty():
			if int(cost.get("honor", 0)) <= 0:
				t_bad.append("%s 的 honor 价应为正数" % tid2)
			else:
				t_cost += 1
		var bonus: Dictionary = td.get("bonus", {})
		if bonus.is_empty():
			t_bad.append("%s 没有加成（戴着没意义）" % tid2)
		for bk in bonus:
			if not bonus_keys.has(String(bk)):
				t_bad.append("%s 的 bonus 键不会被聚合：%s" % [tid2, String(bk)])
	_check(t_bad.is_empty(), "称号表关系校验失败：%s" % str(t_bad))
	_check(t_ids.size() >= 12, "称号全表应有至少 12 条（实为 %d）" % t_ids.size())
	_check(t_cost >= 1, "荣誉商店至少应有一件可兑换称号")

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

	# —— 10.5 装备实例与背包（P04）——
	# 口径：instances[] 是拥有池（背包里的 + 在身的都在里面），equip[slot] = uid；
	#       背包已用格 = 未被 equip 指向的条数（装备不占格）；满包掉落进待领取箱，绝不丢物。
	_reset(1)
	_check(G.inv_instances().size() == 6, "开局应有 6 件基础装实例，实为 %d" % G.inv_instances().size())
	_check(G.inv_count() == 0, "在身装备不占背包格，实为 %d" % G.inv_count())
	var slot_uids := {}
	for sid2 in ["sword", "spear", "staff", "hammer", "armor", "accessory"]:
		var su := int(G.equip_state(sid2).get("uid", 0))
		_check(su > 0 and not slot_uids.has(su), "槽 %s 应指向一个未被占用的实例 uid（实为 %d）" % [sid2, su])
		slot_uids[su] = true

	# 掉落入包 → 占 1 格；uid 全局唯一
	G.inv_grant_equip({"tpl": "tpl_sword_wolf", "rarity": 2, "n": 1})
	_check(G.inv_count() == 1, "掉落一件装备应占 1 格，实为 %d" % G.inv_count())
	var wolf_uid := 0
	for it in G.inv_instances():
		if String((it as Dictionary).get("tpl", "")) == "tpl_sword_wolf":
			wolf_uid = int((it as Dictionary).get("uid", 0))
	_check(wolf_uid > 0, "应能找到刚掉落的狼牙大剑实例")

	# 回收价 = 模板价×稀有度倍率 + 已投入强化金币的一半（与 equip_enhance_cost 同一条公式）
	var ec: Dictionary = G.equip_cfg().get("enhance", {})
	var g_base := float(ec.get("cost_gold_base", 150))
	var g_step := float(ec.get("cost_gold_step", 150))
	var tpl_px := float(G.equip_tpl("tpl_sword_wolf").get("price", 0)) \
		* float(G.equip_rarity_cfg(2).get("sell_mult", 1.0))
	_check(G.inv_sell_price(wolf_uid) == int(roundf(tpl_px)),
		"0 级稀有回收价应为 %d，实为 %d" % [int(roundf(tpl_px)), G.inv_sell_price(wolf_uid)])
	G.inv_find(wolf_uid)["lv"] = 3
	var refund := 0.0
	for i in 3:
		refund += g_base + g_step * float(i)
	_check(G.inv_sell_price(wolf_uid) == int(roundf(tpl_px + refund * 0.5)),
		"lv3 回收价应含已投入强化的一半（%d），实为 %d"
		% [int(roundf(tpl_px + refund * 0.5)), G.inv_sell_price(wolf_uid)])

	# 强化过/稀有 → 卖出要二次确认；确认后金币入钱包、实例出池；重复卖出幂等
	var s_ask := G.inv_sell(wolf_uid)
	_check(not bool(s_ask.get("ok", false)) and bool(s_ask.get("need_confirm", false)),
		"强化过的装备卖出应先要二次确认")
	var gold0 := int(G.wallet.get("gold", 0))
	var px := G.inv_sell_price(wolf_uid)
	var s_ok := G.inv_sell(wolf_uid, true)
	_check(bool(s_ok.get("ok", false)) and int(s_ok.get("gold", 0)) == px, "确认后应卖出并返回回收价")
	_check(int(G.wallet.get("gold", 0)) == gold0 + px, "回收金币应进钱包")
	_check(not bool(G.inv_sell(wolf_uid, true).get("ok", false)), "重复卖出应被拒绝（幂等）")

	# 在身 / 锁定不可卖
	_check(String(G.inv_sell(int(G.equip_state("sword").get("uid", 0)), true).get("err", ""))
		== "装备中的物品不能卖出", "在身装备不可卖出")
	G.inv_grant_equip({"tpl": "tpl_armor_basic", "rarity": 1, "n": 1})
	# 开局基础装里也有 tpl_armor_basic 且正穿在身上 —— 必须挑**刚掉进背包**的那件（未在身）
	var plain_uid := 0
	var worn_now := G.inv_worn_uids()
	for it in G.inv_instances():
		var d1 := it as Dictionary
		if String(d1.get("tpl", "")) == "tpl_armor_basic" \
			and not worn_now.has(int(d1.get("uid", 0))):
			plain_uid = int(d1.get("uid", 0))
	_check(plain_uid > 0, "应能找到刚掉进背包的皮甲实例")
	_check(bool(G.inv_set_locked(plain_uid, true).get("ok", false)), "锁定应成功")
	_check(String(G.inv_sell(plain_uid, true).get("err", "")) == "已锁定的装备不能卖出",
		"锁定装备不可卖出")
	G.inv_set_locked(plain_uid, false)
	# 0 级普通装备：不需确认，直接可卖
	_check(bool(G.inv_sell(plain_uid).get("ok", false)), "0 级普通装备应无需确认即可卖出")

	# 满包：掉落进待领取箱、领取被拒且保留、卸下被拒；换装不因满包失败
	var cap := G.inv_capacity()
	G.inv_grant_equip({"tpl": "tpl_armor_scale", "rarity": 2, "n": maxi(0, cap - G.inv_count())})
	_check(G.inv_count() == cap, "背包应已填满（%d/%d）" % [G.inv_count(), cap])
	var over := G.inv_grant_equip({"tpl": "tpl_sword_ruin", "rarity": 3, "n": 1})
	_check(bool(over.get("to_pending", false)), "满包时的掉落应进待领取箱")
	_check(G.inv_pending().size() == 1, "待领取箱应有 1 件，实为 %d" % G.inv_pending().size())
	var pend_uid := int((G.inv_pending()[0] as Dictionary).get("uid", 0))
	var cl_full := G.inv_claim(pend_uid)
	_check(not bool(cl_full.get("ok", false)) and String(cl_full.get("err", "")) == "背包已满",
		"满包时领取应被拒绝")
	_check(G.inv_pending().size() == 1, "领取失败必须保留在待领取箱，不得丢物")
	_check(String(G.inv_unequip("sword").get("err", "")) == "背包已满，先腾出空位",
		"满包时卸下应被拒绝（不允许卸下来没处放）")
	var swap_uid := _bag_uid()
	_check(swap_uid > 0, "满包时也应能在背包里找到一件可换的装备")
	var swap := G.inv_equip(swap_uid)
	_check(bool(swap.get("ok", false)), "换装不应因满包失败（旧件回池，占用不变）")
	_check(G.inv_count() == cap, "换装后占用不应变化，实为 %d" % G.inv_count())
	_check(not bool(G.inv_equip(swap_uid).get("ok", false)), "重复换装同一件应被拒绝（幂等）")

	# 腾格 → 领取成功；uid 单调递增、不复用卖出的号
	var max_uid := 0
	for it in G.inv_instances():
		max_uid = maxi(max_uid, int((it as Dictionary).get("uid", 0)))
	var dump := _bag_uid()
	_check(bool(G.inv_sell(dump, true).get("ok", false)), "腾格卖出应成功")
	_check(G.inv_count() == cap - 1, "卖出后应空出 1 格，实为 %d" % G.inv_count())
	var cl_ok := G.inv_claim(pend_uid)
	_check(bool(cl_ok.get("ok", false)), "腾出空位后领取应成功")
	_check(G.inv_pending().is_empty(), "领取成功后待领取箱应清空")
	_check(not bool(G.inv_claim(pend_uid).get("ok", false)), "重复领取应被拒绝（幂等）")
	var dump2 := _bag_uid()
	G.inv_sell(dump2, true)
	G.inv_grant_equip({"tpl": "tpl_spear_iron", "rarity": 2, "n": 1})
	var fresh := 0
	for it in G.inv_instances():
		var u4 := int((it as Dictionary).get("uid", 0))
		if u4 > max_uid:
			fresh = u4
	_check(fresh > max_uid and fresh > dump, "新实例 uid 必须单调递增、不得重用卖出的号（%d）" % fresh)
	var uid_seen := {}
	for it in G.inv_instances():
		var u5 := int((it as Dictionary).get("uid", 0))
		_check(not uid_seen.has(u5), "拥有池里 uid 不得重复（%d）" % u5)
		uid_seen[u5] = true

	# 拆宝石：归还原宝石、不占背包格（满包也能拆）
	var sw := G.equip_state("sword")
	var sw_uid := int(sw.get("uid", 0))
	sw["gems"] = ["gem_atk_3"]
	G.items = {}
	var pop := G.inv_gem_pop(sw_uid, 0)
	_check(bool(pop.get("ok", false)) and String(pop.get("gem", "")) == "gem_atk_3",
		"拆宝石应返还 gem_atk_3")
	_check(G.item_count("gem_atk_3") == 1, "拆下的宝石应进 items")
	_check((sw["gems"] as Array).is_empty(), "拆下后孔位应空出")
	_check(not bool(G.inv_gem_pop(sw_uid, 0).get("ok", false)), "空孔位再拆应被拒绝")

	# 宝石 3 合 1：同级同色 3 颗 → 1 颗高一级，扣金币费；缺钱/不足/满级拒绝且不改动
	var mc: Dictionary = G.equip_cfg().get("merge", {})
	var need_n := maxi(2, int(mc.get("gem_merge_n", 3)))
	var fee_g := maxi(0, int(mc.get("gem_merge_cost_gold", 300)))
	G.items = {"gem_atk_1": 3}
	G.wallet["gold"] = 1000
	var mg := G.inv_gem_merge("gem_atk_1")
	_check(bool(mg.get("ok", false)) and String(mg.get("gem", "")) == "gem_atk_2",
		"%d 颗 1 级应合成 1 颗 2 级" % need_n)
	_check(G.item_count("gem_atk_1") == 0 and G.item_count("gem_atk_2") == 1, "合成应 3 换 1")
	_check(int(G.wallet["gold"]) == 1000 - fee_g, "合成应扣 %d 金币" % fee_g)
	_check(not bool(G.inv_gem_merge("gem_atk_2").get("ok", false)), "不足 3 颗应拒绝合成")
	G.items["gem_atk_2"] = 3
	G.wallet["gold"] = fee_g - 1
	var poor := G.inv_gem_merge("gem_atk_2")
	_check(not bool(poor.get("ok", false)) and String(poor.get("err", "")) == "金币不足",
		"金币不足应拒绝合成")
	_check(int(G.item_count("gem_atk_2")) == 3, "拒绝合成时不得改动宝石数量")
	G.wallet["gold"] = 99999
	G.items["gem_atk_5"] = 3
	_check(String(G.inv_gem_merge("gem_atk_5").get("err", "")) == "已是最高级", "满级宝石应拒绝合成")

	# —— 11. 存档往返 ——
	_reset(12)
	G.prog["talents"] = {"fury_1": 2}
	G.equip_state("sword")["lv"] = 3
	G.equip_state("sword")["gems"] = ["gem_atk_3"]
	G.equip_state("sword")["affixes"] = [{"stat": "atk_pct", "v": 0.05, "locked": true}]
	G.prog["skills"] = {_sid: 4}
	G.prog["mounts"] = {"owned": {"horse": 1}, "active": "horse"}
	G.prog["titles"] = {"owned": ["t_rookie"], "active": "t_rookie"}
	G.prog["pet_stat"] = {"pet_rockturtle": {"lv": 3, "exp": 10, "star": 4, "brk": 1}}
	G.save_game()
	var sword_uid_before := int(G.equip_state("sword").get("uid", 0))
	var inst_n_before := G.inv_instances().size()
	G.prog["talents"] = {}
	G.prog["equip"] = {}
	G.prog["inventory"] = {"instances": [], "pending": [], "next_uid": 1}
	G.prog["skills"] = {}
	G.prog["mounts"] = {"owned": {}, "active": ""}
	G.prog["titles"] = {"owned": [], "active": ""}
	G.prog["pet_stat"] = {}
	G._load_save()
	_check(int((G.prog["talents"] as Dictionary).get("fury_1", 0)) == 2, "天赋应随存档恢复")
	_check(int(G.equip_state("sword").get("lv", 0)) == 3, "装备等级应恢复")
	_check(G.equip_state("sword").get("gems", []) == ["gem_atk_3"], "装备宝石应恢复")
	var aff_rt: Array = G.equip_state("sword").get("affixes", [])
	_check(aff_rt.size() == 1 and bool((aff_rt[0] as Dictionary).get("locked", false)),
		"装备词条与锁应恢复")
	_check(int(G.equip_state("sword").get("uid", 0)) == sword_uid_before,
		"存档往返后在身实例 uid 应一致（%d vs %d）" % [int(G.equip_state("sword").get("uid", 0)), sword_uid_before])
	_check(G.inv_instances().size() == inst_n_before,
		"存档往返后拥有池条数应一致（%d vs %d）" % [G.inv_instances().size(), inst_n_before])
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
