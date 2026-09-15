# sim_ttk.gd —— TTK 数值模拟报告（玩法文档 §1.8，headless：godot --headless --path . -s tools/sim_ttk.gd）
# 覆盖：① 四人物×4等级×3节点 TTK 表（目标 普通8~15s/精英40~70s/BOSS 60~120s）
#       ② 分人物能量经济（霜语双重惩罚验证）③ 晨星治疗曲线 vs 主题强度递进
#       ④ 深渊 25 层终层（×4）vs lv60 满养成（流派词条+金宠+药剂）可行性
extends SceneTree

const SEEDS := 10
const THEMES := ["forest", "snow", "volcano", "tomb", "desert", "glacier", "abyss", "castle"]
const ROLES := ["zs", "ck", "fs", "fz"]
# lv60 满养成 Build：各人物一套流派 4 词条 + 金宠 + 药剂×3
const BUILD := {
	"zs": {"traits": ["tr_atk_up_m", "tr_bleed_1", "tr_bleed_2", "tr_deep_wound"],
		"pet": "pet_shadowviper", "bench": "pet_rockturtle"},
	"ck": {"traits": ["tr_crit_1", "tr_crit_2", "tr_crit_up", "tr_crit_dmg"],
		"pet": "pet_emberling", "bench": "pet_foxfire"},
	"fs": {"traits": ["tr_ctrl_1", "tr_ctrl_2", "tr_chill_touch", "tr_stun_blow"],
		"pet": "pet_eyescat", "bench": "pet_frostwolf"},
	"fz": {"traits": ["tr_summon_1", "tr_summon_2", "tr_regen", "tr_hp_up_m"],
		"pet": "pet_holydeer", "bench": "pet_thunderhawk"},
}


func _initialize() -> void:
	call_deferred("_run")


## 跑一组：返回 {win, ticks, casts, ult_casts, heal, dmg_taken}
func _sim_batch(role_id: String, level: int, node_type: String, layer: int,
		theme := "forest", traits: Array = [], pet := "", bench := "", potions := 0) -> Dictionary:
	var wins := 0
	var ticks_sum := 0
	var casts := 0
	var ults := 0
	var heal_sum := 0
	var taken_sum := 0
	var role_uid := 0
	for i in SEEDS:
		var sim := BattleSim.new()
		sim.record_events = true
		sim.auto_mode = true
		sim.setup(1000 + i * 7919, {"role_id": role_id, "level": level, "traits": traits,
			"active_pet": pet, "bench_pet": bench, "potions": potions},
			{"theme": theme, "node_type": node_type, "layer": layer})
		role_uid = sim.role_uid
		sim.run_to_end()
		if sim.result == "victory":
			wins += 1
		ticks_sum += sim.tick_count
		for e in sim.events:
			match String(e.t):
				"cast":
					casts += 1
				"heal":
					heal_sum += int(e.amount)
				"dmg":
					if int(e.uid) == role_uid:
						taken_sum += int(e.amount)
		# 大招数：cost≥55 的技能 cast 事件无法区分，这里用能量峰值近似——改为统计整局 cast 已够
		ults += 0
	var out := {"win": float(wins) / float(SEEDS), "sec": float(ticks_sum) / float(SEEDS) / 30.0,
		"casts": casts, "heal": heal_sum / SEEDS, "taken": taken_sum / SEEDS}
	return out


func _run() -> void:
	print("== ① TTK 表（forest，%d seeds 均值；目标 普通8~15s/精英40~70s/BOSS 60~120s）==" % SEEDS)
	print("role lv |  normal 胜率  TTK |   elite 胜率  TTK |    boss 胜率  TTK")
	for role_id in ROLES:
		for lv in [1, 10, 30, 50]:
			var line := "%s lv%-2d |" % [role_id, lv]
			for nt in ["normal", "elite", "boss"]:
				var layer := 3 if nt == "boss" else 2
				var r := _sim_batch(role_id, lv, nt, layer)
				line += "  %4.0f%% %5.1fs |" % [r.win * 100.0, r.sec]
			print(line)

	print("")
	print("== ② 分人物能量经济（lv10 forest elite 匹配难度，%d seeds；cast=整局技能施放总数/局）==" % SEEDS)
	for role_id in ROLES:
		var r := _sim_batch(role_id, 10, "elite", 2)
		print("%s：胜率 %3.0f%% | 场均技能 %4.1f 次 | 场均承伤 %6.0f" % [role_id, r.win * 100.0,
			float(r.casts) / float(SEEDS), r.taken])

	print("")
	print("== ③ 晨星治疗曲线（fz layer3 normal，各主题胜率/场均治疗/场均承伤）==")
	for lv in [10, 30, 50]:
		var line := "fz lv%-2d |" % lv
		for theme in THEMES:
			var r := _sim_batch("fz", lv, "normal", 3, theme)
			line += " %s %3.0f%%(治%4.0f/伤%4.0f) |" % [theme.substr(0, 3), r.win * 100.0, r.heal, r.taken]
		print(line)

	print("")
	print("== ④ 深渊 25 层终层（abyss boss ×4 难度 vs lv60 满养成：流派4词条+金宠+药剂3）==")
	for role_id in ROLES:
		var b: Dictionary = BUILD[role_id]
		var r := _sim_batch(role_id, 60, "boss", 25, "abyss", b.traits, b.pet, b.bench, 3)
		print("%s：胜率 %3.0f%% | TTK %5.1fs | 场均治疗 %6.0f | 场均承伤 %6.0f" % [role_id,
			r.win * 100.0, r.sec, r.heal, r.taken])

	print("TTK_REPORT_OK")
	quit(0)
