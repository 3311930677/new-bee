# Budget model from real s32 saves; production rewards/equipment APIs, no fabricated resources.
# This simulation does not replace real-input PlaythroughFourthBack evidence.
extends Node

var fails := 0

func _ready() -> void:
	await get_tree().process_frame
	for role in ["zs","fs","ck","fz"]:
		var group := "zs_fs" if role in ["zs","fs"] else "ck_fz"
		var source := "res://tools/_logs/fourth_front_verified_%s_20261002/save_playthrough_%s_a.json" % [group,role]
		G.SAVE_PATH = "res://tools/_logs/save_fourth_budget_%s.json" % role
		var file := FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
		file.store_string(FileAccess.get_file_as_string(source))
		file.close()
		if not G.reload_save() or G.prog.story.done.size()!=32:
			_bad("源档必须为32步真实完成档 "+role)
			continue
		print("FOURTH_BUDGET_SOURCE role=%s sha256=%s" % [role,FileAccess.get_sha256(source)])
		G.story_event("visit","stele_entry","stele_entry")
		G.world_puzzle_interact("stele_entry","return_anchor")
		for id in ["forest_voice","tide_voice","snow_voice"]: G.world_puzzle_interact("stele_resonance",id)
		G.story_event("observe","aligned_voices","stele_resonance")
		if G.prog.level!=53 or not _wear("tpl_armor_abyss"): _bad("53级普通护甲预算 "+role)
		_budget(role,"mon_abyss_avatar",53)
		G.story_event("defeat","mon_abyss_avatar","stele_core")
		G.story_event("talk","npc_steward","lorin_wilds",true,{"method":"seal"})
		var slot: String = {"zs":"sword","fs":"staff","ck":"spear","fz":"hammer"}.get(role,"")
		if G.prog.level!=60 or not _wear("tpl_%s_abyss" % slot) or not _wear("tpl_accessory_return"):
			_bad("60级普通结局装备预算 "+role)
		_budget(role,"mon_nameless_warden",60)
	print("FOURTH_BUDGET_OK seeds=80 roles=4 bosses=2" if fails==0 else "FOURTH_BUDGET_FAIL fails=%d" % fails)
	get_tree().quit(0 if fails==0 else 1)

func _wear(tpl: String) -> bool:
	for inst in G.inv_instances():
		if inst.get("tpl","")==tpl: return bool(G.inv_equip(int(inst.uid)).get("ok",false))
	return false

func _budget(role: String, boss: String, level: int) -> void:
	var durations: Array = []
	var max_potions := 0
	var minimum_hp := 1.0
	var wins := 0
	for seed in range(10):
		var sim := BattleSim.new()
		# No pet or traits: retain the source's actual skills, talents and equipment only.
		sim.setup(seed+417,{"role_id":role,"level":level,"traits":[],"active_pet":"","bench_pet":"","potions":2,
			"growth":G.growth_bonuses(role),"skill_levels":G.prog.get("skills",{}),
			"unlocked_skills":G.act1_unlocked_skills(role),"skill_variants":G.act1_skill_variants(role)},
			{"theme":"abyss","node_type":"boss","lead_mon":boss,"solo":true,"display_level":level})
		sim.auto_mode=true
		sim.record_events=false
		for tick in BattleSim.MAX_TICKS+1:
			var unit := sim.role_unit()
			if unit!=null and unit.alive and unit.hp<float(unit.get_max_hp())*.4: sim.use_potion()
			sim.step()
			if sim.finished: break
		if sim.result!="victory": _bad("普通预算未胜 role=%s boss=%s seed=%d result=%s" % [role,boss,seed+417,sim.result])
		else: wins+=1
		durations.append(float(sim.tick_count)/30.0)
		max_potions=maxi(max_potions,2-sim.potions_left)
		minimum_hp=minf(minimum_hp,float(sim.role_unit().hp)/sim.role_unit().get_max_hp())
	print("FOURTH_BUDGET role=%s boss=%s level=%d wins=%d/10 seconds_min=%.2f seconds_max=%.2f potions_max=%d finish_hp_min=%.3f" % [role,boss,level,wins,durations.min(),durations.max(),max_potions,minimum_hp])

func _bad(message: String) -> void:
	fails+=1
	push_error("FAIL: "+message)
