# SimBalanceReport.gd —— 四职业 × 早中后期 × 普通/精英/首领 720 场数值与成长模拟器
# 运行方式：godot --headless --path . -s res://tools/SimBalanceReport.gd
extends SceneTree

const ROLES := ["zs", "ck", "fs", "fz"]
const ROLE_NAMES := {"zs": "破军(战士)", "ck": "穿杨(枪骑)", "fs": "霜语(法师)", "fz": "晨星(牧师)"}
const STAGES := [
	{
		"id": "early",
		"name": "前期(Lv.6·枫林首章)",
		"level": 6,
		"theme": "forest",
		"layer": 1,
		"pet": "pet_rockturtle",
		"traits": ["tr_atk_up_s", "tr_crit_up"],
		"growth": {"hp_add": 45, "maxhp_pct": 0.10, "atk_add": 8, "atk_pct": 0.12, "def_add": 4, "def_pct": 0.08, "spd_pct": 0.05, "crit_add": 0.03},
		"skill_lv": 2,
	},
	{
		"id": "mid",
		"name": "中期(Lv.12·霜境二章)",
		"level": 12,
		"theme": "snow",
		"layer": 2,
		"pet": "pet_frostwolf",
		"traits": ["tr_atk_up_m", "tr_crit_up", "tr_spd_up"],
		"growth": {"hp_add": 120, "maxhp_pct": 0.22, "atk_add": 20, "atk_pct": 0.25, "def_add": 12, "def_pct": 0.18, "spd_pct": 0.10, "crit_add": 0.06},
		"skill_lv": 5,
	},
	{
		"id": "late",
		"name": "后期(Lv.20·深渊终章)",
		"level": 20,
		"theme": "abyss",
		"layer": 3,
		"pet": "pet_holydeer",
		"traits": ["tr_atk_up_m", "tr_crit_up", "tr_spd_up", "tr_rampage"],
		"growth": {"hp_add": 260, "maxhp_pct": 0.38, "atk_add": 42, "atk_pct": 0.42, "def_add": 26, "def_pct": 0.30, "spd_pct": 0.16, "crit_add": 0.10},
		"skill_lv": 8,
	},
]
const TIERS := ["normal", "elite", "boss"]
const SEEDS_PER_CASE := 20


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var report := {
		"generated_at": Time.get_datetime_string_from_system(),
		"seeds_per_case": SEEDS_PER_CASE,
		"total_battles": ROLES.size() * STAGES.size() * TIERS.size() * SEEDS_PER_CASE,
		"results": [],
		"role_summary": {},
	}
	for role_id in ROLES:
		report["role_summary"][role_id] = {
			"name": ROLE_NAMES[role_id],
			"wins": 0,
			"total": 0,
			"avg_sec_normal": 0.0,
			"avg_sec_elite": 0.0,
			"avg_sec_boss": 0.0,
			"boss_win_rate": 0.0,
		}

	for stg in STAGES:
		for tier in TIERS:
			for role_id in ROLES:
				var stat := _simulate_batch(role_id, stg, tier)
				report["results"].append(stat)
				var rsum: Dictionary = report["role_summary"][role_id]
				rsum["wins"] = int(rsum["wins"]) + int(stat["wins"])
				rsum["total"] = int(rsum["total"]) + int(stat["runs"])
				if tier == "normal":
					rsum["avg_sec_normal"] = float(rsum["avg_sec_normal"]) + float(stat["avg_sec"]) / float(STAGES.size())
				elif tier == "elite":
					rsum["avg_sec_elite"] = float(rsum["avg_sec_elite"]) + float(stat["avg_sec"]) / float(STAGES.size())
				elif tier == "boss":
					rsum["avg_sec_boss"] = float(rsum["avg_sec_boss"]) + float(stat["avg_sec"]) / float(STAGES.size())
					rsum["boss_win_rate"] = float(rsum["boss_win_rate"]) + float(stat["win_rate"]) / float(STAGES.size())

	var out_dir := ProjectSettings.globalize_path("res://docs/agent_iteration/test_results")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out_path := out_dir + "/balance_sim.json"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
		print("SIM_BALANCE_JSON_SAVED ", out_path)
	else:
		push_error("SIM_BALANCE_SAVE_FAILED " + out_path)

	print("=== 远征 4职业×3阶段×3难度 720场战斗数值模拟汇总 ===")
	for role_id in ROLES:
		var rs: Dictionary = report["role_summary"][role_id]
		var total_wr := 100.0 * float(rs["wins"]) / maxf(1.0, float(rs["total"]))
		print("%s | 总胜率: %.1f%% | 首领胜率: %.1f%% | 均耗时(普/精/首): %.1fs / %.1fs / %.1fs" % [
			String(rs["name"]), total_wr, float(rs["boss_win_rate"]) * 100.0,
			float(rs["avg_sec_normal"]), float(rs["avg_sec_elite"]), float(rs["avg_sec_boss"])
		])
	quit(0)


func _simulate_batch(role_id: String, stg: Dictionary, tier: String) -> Dictionary:
	var wins := 0
	var total_ticks := 0
	var total_hp_pct := 0.0
	var total_dmg_out := 0
	var total_dmg_in := 0
	var role_skills: Array = []
	for sk_v in TableCache.skills():
		var sk: Dictionary = sk_v
		if String(sk.get("role", "")) == role_id:
			role_skills.append(String(sk.get("id", "")))
	var skill_lvs := {}
	for sid in role_skills:
		skill_lvs[sid] = int(stg["skill_lv"])

	for i in SEEDS_PER_CASE:
		var seed_val := 10000 + i * 97 + ROLES.find(role_id) * 13
		var sim := BattleSim.new()
		var player_cfg := {
			"role_id": role_id,
			"level": int(stg["level"]),
			"traits": (stg["traits"] as Array).duplicate(),
			"active_pet": String(stg["pet"]),
			"bench_pet": "pet_thunderhawk",
			"potions": 2,
			"growth": (stg["growth"] as Dictionary).duplicate(true),
			"skill_levels": skill_lvs,
		}
		var enemy_cfg := {
			"theme": String(stg["theme"]),
			"node_type": tier,
			"layer": int(stg["layer"]),
		}
		sim.setup(seed_val, player_cfg, enemy_cfg)
		sim.auto_mode = true
		var dmg_out := 0
		var dmg_in := 0
		var max_ticks := 2700
		while not sim.finished and sim.tick_count < max_ticks:
			var ru := sim.role_unit()
			if ru != null and ru.alive:
				if float(ru.hp) / maxf(1.0, float(ru.get_max_hp())) < 0.45 and sim.potions_left > 0 and sim.potion_cd_ticks <= 0:
					sim.use_potion()
			sim.step()
			for ev_v in sim.events:
				var ev: Dictionary = ev_v
				if String(ev.get("t", "")) == "dmg":
					var target_u := sim.unit_by_uid(int(ev.get("uid", -1)))
					var amt := int(ev.get("amount", 0))
					if target_u != null:
						if target_u.side == "enemy":
							dmg_out += amt
						else:
							dmg_in += amt
			sim.events.clear()
		if sim.result == "victory":
			wins += 1
		total_ticks += sim.tick_count
		var ru_end := sim.role_unit()
		if ru_end != null and ru_end.get_max_hp() > 0:
			total_hp_pct += clampf(float(ru_end.hp) / float(ru_end.get_max_hp()), 0.0, 1.0)
		total_dmg_out += dmg_out
		total_dmg_in += dmg_in

	var runs := float(SEEDS_PER_CASE)
	var avg_sec := (float(total_ticks) / runs) / 30.0
	var avg_dmg_out := float(total_dmg_out) / runs
	return {
		"role": role_id,
		"role_name": ROLE_NAMES[role_id],
		"stage": String(stg["id"]),
		"stage_name": String(stg["name"]),
		"level": int(stg["level"]),
		"tier": tier,
		"runs": SEEDS_PER_CASE,
		"wins": wins,
		"win_rate": float(wins) / runs,
		"avg_sec": snappedf(avg_sec, 0.01),
		"avg_hp_pct": snappedf(total_hp_pct / runs, 0.001),
		"avg_dmg_out": roundi(avg_dmg_out),
		"avg_dmg_in": roundi(float(total_dmg_in) / runs),
		"avg_dps": snappedf(avg_dmg_out / maxf(0.1, avg_sec), 0.1),
	}
