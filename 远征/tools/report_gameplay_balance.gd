## 可复现的单场主线压力样本；不代替真实输入全流程验证，不读写玩家存档。
extends SceneTree

const SEEDS := 20
const CASES := [
	{"step":"s03","map":"maple_road","level":3,"skills":1,"gear":"basic"},
	{"step":"s06","map":"broken_slope","level":6,"skills":2,"gear":"basic"},
	{"step":"s10","map":"stele_cavern","level":10,"skills":2,"gear":"basic"},
	{"step":"s18","map":"tideflat","level":19,"skills":3,"gear":"stele","enemy":"mon_tidal_guard"},
	{"step":"s19","map":"tidal_gate","level":21,"skills":3,"gear":"stele"},
	{"step":"s25","map":"rift_mine_vault","level":32,"skills":4,"gear":"tidegate"},
	{"step":"s27","map":"frost_pass","level":37,"skills":5,"gear":"frost_mix"},
	{"step":"s35","map":"stele_core","level":53,"skills":5,"gear":"final"}
]

func _initialize() -> void:
	call_deferred("_run")

func growth(role: String, stage: String) -> Dictionary:
	var slot: String = {"zs":"sword","ck":"spear","fs":"staff","fz":"hammer"}[role]
	var weapon := "basic"
	var armor := "basic"
	var accessory := "basic"
	var levels := [0,0,0]
	match stage:
		"stele": weapon = "stele"; armor = "stele"; levels = [2,1,0]
		"tidegate": weapon = "tidegate"; armor = "tidegate"; levels = [3,2,0]
		"frost_mix": weapon = "frostgate"; armor = "tidegate"; levels = [3,2,0]
		"final": weapon = "frostgate"; armor = "abyss"; accessory = "twinpass"; levels = [3,3,2]
	var templates: Array = TableCache.equip_config().get("templates", [])
	var ids := ["tpl_%s_%s" % [slot,weapon],"tpl_armor_"+armor,"tpl_accessory_"+accessory]
	var out := {"atk_add":0.0,"def_add":0.0,"hp_add":0,"crit_add":0.0}
	for i in ids.size():
		for row in templates:
			if String(row.id) != ids[i]: continue
			var mult := 1.0 + float(TableCache.equip_config().enhance.pct_per_level) * int(levels[i])
			for key in row.base:
				var target: String = {"atk":"atk_add","def":"def_add","hp":"hp_add","crit":"crit_add"}.get(key, "")
				if not target.is_empty():
					out[target] += int(float(row.base[key])*mult) if key != "crit" else float(row.base[key])*mult
	return out

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var before_pacing := args.has("before-pacing")
	var report := {"seeds":SEEDS,"before_priest_pacing":before_pacing,"priest_basic_attack_k":1.0 if before_pacing else float(TableCache.get_role("fz").get("basic_attack_k",1.0)),
		"profile":"full HP, two potions used below 35% HP when ready, skillbook level 1, no talents/gems/refine/mount/title/variants/puzzle assists; optional level-1 3-star rockturtle after s04; fixed milestone gear, previous-step story-only level","cases":[]}
	var maps: Dictionary = TableCache.main_world_config().maps
	for row in CASES:
		for role in ["zs","ck","fs","fz"]:
			var map: Dictionary = maps[row.map]
			var enemy := String(row.get("enemy", map.get("boss_id", (map.monster_ids as Array)[0])))
			var enemy_level := CampaignGrowth.enemy_level(String(row.map), {}, 1)
			var skills: Array = TableCache.get_role(role).skills.slice(0,int(row.skills))
			var pet := "pet_rockturtle" if int(row.level) >= 6 else ""
			var wins := 0
			var draws := 0
			var seconds: Array = []
			var hp_sum := 0.0
			var potion_sum := 0
			for index in SEEDS:
				var sim := BattleSim.new()
				sim.record_events = false
				sim.auto_mode = true
				sim.setup(20261005 + 7919 * index, {"role_id":role,"level":int(row.level),"traits":[],"potions":2,"active_pet":pet,
					"pet_stats":{"pet_rockturtle":{"level":1,"stat_mult":1.0,"growth_mult":1.2}},
					"unlocked_skills":skills,"growth":growth(role,String(row.gear))},
					{"theme":String(map.theme),"node_type":"boss" if map.has("boss_id") else "normal","solo":true,"lead_mon":enemy,"display_level":enemy_level,"world_map_id":String(row.map)})
				if before_pacing and role == "fz":
					sim.role_unit().data = sim.role_unit().data.duplicate(true)
					sim.role_unit().data["basic_attack_k"] = 1.0
				while not sim.finished:
					var actor := sim.role_unit()
					if actor.alive and float(actor.hp)/actor.get_max_hp() < .35: sim.use_potion()
					sim.step()
				potion_sum += 2 - sim.potions_left
				if sim.result == "victory": wins += 1
				if sim.result == "draw": draws += 1
				seconds.append(float(sim.tick_count)/BattleSim.TICK_RATE)
				hp_sum += float(sim.role_unit().hp)/sim.role_unit().get_max_hp()
			seconds.sort()
			var result := {"step":row.step,"role":role,"level":row.level,"enemy":enemy,"enemy_level":enemy_level,"gear":row.gear,"wins":wins,"draws":draws,
				"median_seconds":(float(seconds[(SEEDS-1)/2])+float(seconds[SEEDS/2]))/2.0,"p90_seconds":seconds[int(SEEDS*.9)-1],"mean_hp_pct":snappedf(100.0*hp_sum/SEEDS,.1),"mean_potions_used":float(potion_sum)/SEEDS,"seconds_samples":seconds}
			(report.cases as Array).append(result)
			print(JSON.stringify(result))
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		if file == null: quit(1); return
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	print("GAMEPLAY_REPORT_OK cases=%d battles=%d" % [(report.cases as Array).size(),SEEDS*(report.cases as Array).size()])
	quit(0)
