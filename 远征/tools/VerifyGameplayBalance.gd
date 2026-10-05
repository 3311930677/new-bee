## 真实结算边界：研习收益、条件倍率、超杀收益、退款幂等及写盘失败。
extends Node

var fails := 0

func _ready() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if not value:
		fails += 1
		push_error("FAIL: " + label)

func battle(role := "zs", levels: Dictionary = {}) -> BattleSim:
	var sim := BattleSim.new()
	sim.setup(20261005, {"role_id": role, "level": 30, "skill_levels": levels},
		{"theme": "forest", "node_type": "normal", "layer": 1, "solo": true, "lead_mon": "mon_wolf"})
	return sim

func _run() -> void:
	var host := get_tree().root.get_node("G")
	host.SAVE_PATH = "user://save_verify_gameplay_balance.json"
	host.save_locked = false
	host._init_state_defaults()
	for sid in ["fz_shengyu", "fz_puzhao", "fs_midun", "fz_zhudao", "fz_poxiao"]:
		var original := TableCache.get_skill(sid)
		var copy := original.duplicate(true)
		var scaled := SkillSystem.study_skill(original, 10)
		check(SkillSystem.can_study(original), "辅助强度必须可研习 " + sid)
		check(original == copy, "研习不能污染缓存 " + sid)
		var fields: Array = TableCache.skillbook_config().effect_scale_fields[original.effect.type]
		for field in fields:
			check(is_equal_approx(float(scaled.effect[field]), snappedf(float(original.effect[field]) * 1.45, 0.001)), "辅助强度获得45%增幅 " + sid)
		check(scaled.cd == original.cd and scaled.cost == original.cost, "研习不改变冷却与能耗")
		if original.effect.has("dur"): check(scaled.effect.dur == original.effect.dur, "研习不能延长无敌或增益")
	var heal_sim := battle("fz", {"fz_shengyu": 10})
	var healer := heal_sim.role_unit()
	healer.hp = 1
	var heal_skill: Dictionary = healer.skills[0].def
	var expected := DamageCalc.heal_amount(healer.get_max_hp(), healer.get_atk(), heal_skill.effect.hp_pct, heal_skill.effect.atk_k)
	SkillSystem._apply_skill(heal_sim, healer, heal_skill, {})
	check(healer.hp == 1 + expected, "升级治疗必须进入真实生命结算")
	var priest_sim := battle("fz")
	var priest := priest_sim.role_unit()
	priest.base_crit = 0.0
	var training := priest.pick_basic_target(priest_sim)
	training.hp = 10000
	var hp_before := training.hp
	priest.do_basic_attack(priest_sim)
	check(hp_before - training.hp == DamageCalc.basic_damage(int(priest.get_atk()*1.35),training.get_def()), "晨星普攻按独立1.35系数结算")
	check(priest.energy == 20, "晨星普攻加强不提高回能")
	check(is_equal_approx(float(host.make_arena_mirror("fz",30).basic_attack_k),1.35), "镜影同样保留晨星普攻系数")
	for sid in ["zs_duanzui", "fs_yanmie"]:
		var sim := battle("zs" if sid == "zs_duanzui" else "fs", {sid: 10})
		var actor := sim.role_unit()
		actor.base_atk = 100
		actor.base_crit = 0.0
		var target := actor.pick_basic_target(sim)
		target.base_max_hp = 100000
		target.hp = 20000
		target.base_def = 0
		if sid == "fs_yanmie": target.add_buff("stun", 100, {})
		var sd: Dictionary = {}
		for skill in actor.skills:
			if skill.id == sid: sd = skill.def
		var before := target.hp
		SkillSystem._apply_skill(sim, actor, sd, {})
		check(before - target.hp == int(100.0 * float(sd.effect.k_to)), "条件伤害不能覆盖研习倍率 " + sid)
	var overkill := battle()
	var attacker := overkill.role_unit()
	var victim := attacker.pick_basic_target(overkill)
	attacker.hp = 20
	attacker.add_buff("lifesteal", 100, {"pct": 0.5})
	victim.hp = 2
	victim.add_buff("thorns", 100, {"pct": 0.5})
	check(victim.take_damage(10000, attacker, overkill) == 2, "超杀只计真实扣血")
	check(attacker.hp == 20 and attacker.alive, "超杀反伤1与吸血1，不能放大或反杀")
	var dot_sim := battle()
	var second := dot_sim.alive_units("enemy")[0]
	second.hp = 2
	check(second._direct_damage(999, dot_sim.role_unit(), dot_sim, true) == 2, "持续伤害也只计真实扣血")
	for sid in ["zs_zhanhou", "ck_dunying", "fz_jinghua", "missing"]:
		check(host.skill_upgrade_cost(sid) == 0 and not host.skill_upgrade(sid), "无收益或未知技能禁止收费 " + sid)
	host.prog.skills = {"zs_zhanhou": 3, "ck_dunying": 10, "fz_jinghua": 2, "fz_shengyu": 4}
	host.wallet.expedition = 17
	check(host.save_game(), "旧技能存档写入")
	check(host.reload_save(), "读取旧技能并退款")
	check(int(host.wallet.expedition) == 17 + 150 + 2460 + 60 and host.skill_level("fz_shengyu") == 4, "仅无效技能全额退款并保留辅助投入")
	var snapshot: Dictionary = host.prog.duplicate(true)
	var wallet: Dictionary = host.wallet.duplicate(true)
	check(host.reload_save() and host.prog.skills == snapshot.skills and host.wallet == wallet and int(host.skill_study_refund().amount) == 0, "退款存档往返不能重复领取")
	var failed := FailedHost.new()
	failed.wallet.expedition = 3000
	failed.prog.skills = {"zs_zhanhou": 3}
	var before_prog := failed.prog.duplicate(true)
	check(not failed.skill_study_refund().ok and failed.wallet.expedition == 3000 and failed.prog == before_prog, "退款写盘失败回滚")
	check(not failed.skill_upgrade("zs_lieshan") and failed.wallet.expedition == 3000 and failed.prog == before_prog, "升级写盘失败回滚")
	failed.save_locked = true
	check(not failed.skill_study_refund().ok and not failed.skill_upgrade("zs_lieshan"), "锁档拒绝退款及升级")
	failed.free()
	print("GAMEPLAY_BALANCE_OK" if fails == 0 else "GAMEPLAY_BALANCE_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)

class FailedHost extends "res://src/autoload/G.gd":
	func save_game() -> bool: return false
