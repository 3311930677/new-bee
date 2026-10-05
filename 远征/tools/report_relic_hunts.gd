extends "res://tools/report_gameplay_balance.gd"
const Relics := preload("res://src/world/RelicService.gd")

func _run() -> void:
	var out := {"profile":"60级；巡界武器/三声护甲/归路佩均+6；常用技能研习3级；25级4星岩龟；两瓶药低于35%使用；无天赋宝石精炼；托管", "cases":[]}
	for hunt in Relics.cfg().hunts:
		for role in ["zs","ck","fs","fz"]:
			var slot: String = {"zs":"sword","ck":"spear","fs":"staff","fz":"hammer"}[role]
			var gb := {"atk_add":0.0,"def_add":0.0,"hp_add":0.0,"crit_add":0.0}
			var ids := ["tpl_%s_boundary" % slot,"tpl_armor_abyss","tpl_accessory_return"]
			for tpl in TableCache.equip_config().templates:
				if not ids.has(String(tpl.id)): continue
				for key in tpl.base:
					var dest: String = {"atk":"atk_add","def":"def_add","hp":"hp_add","crit":"crit_add"}.get(key,"")
					gb[dest] += float(tpl.base[key]) if key == "crit" else int(round(float(tpl.base[key])*1.6))
			var levels := {}
			for sid in TableCache.get_role(role).skills: levels[String(sid)] = 3
			var wins := 0
			var time: Array = []
			var hp := 0.0
			var bottles := 0
			for i in SEEDS:
				var sim := BattleSim.new()
				sim.auto_mode = true; sim.record_events = false
				sim.setup(20261005+i*7919,{"role_id":role,"level":60,"growth":gb,"skill_levels":levels,"active_pet":"pet_rockturtle",
					"pet_stats":{"pet_rockturtle":{"level":25,"growth_mult":1.4,"stat_mult":1.0}},"potions":2},
					{"theme":hunt.theme,"node_type":"boss","solo":true,"lead_mon":hunt.boss,"display_level":60,"world_map_id":hunt.map,"difficulty_override":hunt.difficulty})
				while not sim.finished:
					if sim.role_unit().alive and float(sim.role_unit().hp)/sim.role_unit().get_max_hp() < .35: sim.use_potion()
					sim.step()
				if sim.result == "victory": wins += 1
				time.append(float(sim.tick_count)/BattleSim.TICK_RATE)
				hp += float(sim.role_unit().hp)/sim.role_unit().get_max_hp()
				bottles += 2-sim.potions_left
			time.sort()
			out.cases.append({"hunt":hunt.id,"role":role,"wins":wins,"n":SEEDS,"median_seconds":(float(time[9])+float(time[10]))*.5,"mean_hp_pct":hp*100/SEEDS,"mean_potions":float(bottles)/SEEDS})
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0],FileAccess.WRITE)
		file.store_string(JSON.stringify(out,"  ")); file.close()
	print("RELIC_REPORT_OK battles=%d" % (out.cases.size()*SEEDS))
	quit(0)
