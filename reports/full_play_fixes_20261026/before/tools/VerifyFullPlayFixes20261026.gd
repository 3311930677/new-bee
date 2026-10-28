extends Node
const GScript = preload("res://src/autoload/G.gd")
const Events = preload("res://src/run/RunEvents.gd")
var failures := 0
var checks := 0

class DiskProbe extends "res://src/autoload/G.gd":
	var reject := false
	var writes := 0
	func save_game() -> bool:
		if save_locked: return false
		if _save_batch_depth > 0: return true
		writes += 1
		return not reject

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("REGRESSION_FAIL: " + message)

func _ready() -> void:
	G.SAVE_PATH = "user://full_play_regression.json"
	await run_checks()
	print("FULL_PLAY_FIXES_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func state(g) -> String:
	return JSON.stringify([g.wallet, g.items, g.prog, g.city, g.quest, g.arena])

func prepare(g) -> void:
	g.save_locked = false
	g.wallet = {"gold": 100000, "expedition": 10000, "soul": 10000, "honor": 10000}
	g.items = {"pet_food": 50, "break_crystal": 50, "aptitude_fruit": 5, "evolve_crystal": 20, "refine_stone": 20, "lock_rune": 20}
	g.prog["level"] = 35
	g.prog["pets"] = ["pet_rockturtle"]
	g.prog["pet_stat"] = {"pet_rockturtle": {"lv": 1, "exp": 0, "star": 3, "brk": 0}}
	g.prog["flags"] = {}

func run_checks() -> void:
	var probe := DiskProbe.new()
	prepare(probe)
	var before := state(probe)
	var failed := probe.saved_mutation(func():
		probe.wallet.gold -= 90
		probe.items.pet_food -= 1
		probe.prog.flags["partial"] = true
		return {"ok": false, "err": "injected"})
	check(not failed.ok and state(probe) == before and probe.writes == 0, "action failure must restore every container without writing")
	var operations := ["pet_feed", "pet_break", "pet_reroll_star", "pet_evolve", "pet_bond_interact"]
	for method in operations:
		prepare(probe)
		probe.reject = true
		before = state(probe)
		var writes := probe.writes
		var response: Dictionary = probe.call(method, "pet_rockturtle")
		check(not bool(response.get("ok", false)) and state(probe) == before, method + " must rollback on write failure")
		check(probe.writes == writes + 1, method + " must attempt exactly one final write")
		probe.reject = false
		response = probe.call(method, "pet_rockturtle")
		check(bool(response.get("ok", false)), method + " normal path must still work")
	prepare(probe)
	probe.reject = true
	before = state(probe)
	var curio := probe.curio_appraise("rare")
	check(not curio.ok and state(probe) == before, "curio fees, reward, history and title rollback together")
	probe.reject = false
	curio = probe.curio_appraise("common")
	check(curio.ok, "first appraisal succeeds")
	before = state(probe)
	check(not probe.curio_appraise("common").ok and state(probe) == before, "appraisal cooldown rejects without charge")
	probe.prog.flags.curio_last_ts = 0
	probe.prog.flags.curio_daily_count = 5
	before = state(probe)
	check(not probe.curio_appraise("rare").ok and state(probe) == before, "appraisal daily cap is shared by both tiers")
	probe.save_locked = true
	before = state(probe)
	for method in operations:
		check(not probe.call(method, "pet_rockturtle").ok, method + " rejects locked saves")
	probe.deposit(100, 100, 100, 100)
	check(not probe.curio_appraise().ok and state(probe) == before, "locked save cannot mutate wallet or appraisal")
	probe.save_locked = false
	probe.deposit(-1000000, -1, -2, -3)
	check(int(probe.wallet.gold) >= 0 and int(probe.wallet.soul) >= 0, "negative rewards never create a negative wallet")
	probe.free()

	var sim := BattleSim.new()
	sim.setup(7, {"role_id": "zs", "level": 1}, {"theme": "forest", "layer": 1})
	var low_scale := sim.enemy_scale
	var low_count := sim.units.size()
	sim.setup(7, {"role_id": "zs", "level": 35}, {"theme": "forest", "layer": 1})
	check(sim.enemy_scale > low_scale * 5 and sim.units.size() == low_count, "run difficulty scales with level and setup clears prior units")
	sim.setup(7, {"role_id": "zs", "level": 35}, {"theme": "forest", "solo": true, "display_level": 5})
	check(is_equal_approx(sim.enemy_scale, 1.64), "main-world solo scaling stays on displayed enemy level")
	sim.setup(7, {"role_id": "zs", "level": 1}, {"theme": "__empty_pool__"})
	sim.step()
	check(not sim.setup_error.is_empty() and sim.finished and sim.result != "victory", "empty enemy setup cannot produce victory")
	check(not sim.events.any(func(e): return String(e.get("t", "")) == "victory"), "empty setup emits no victory event")
	sim.setup(7, {"role_id": "zs", "level": 1}, {"theme": "forest"})
	check(sim.setup_error.is_empty() and not sim.finished and sim.tick_count == 0, "valid setup recovers after a rejected setup")
	check(G.res_tex("sk_boss_slam") != null and G.res_tex("sk_boss_summon") != null, "both boss skills resolve to existing art")

	var run := RunState.new()
	run.setup({"role_id": "zs", "level": 10, "theme": "forest", "seed": 21})
	run.run_id = "regression_run"
	var snapshot := run.snapshot()
	for optional in ["growth_bonus", "ascetic", "map_state", "honor"]: snapshot.erase(optional)
	var resumed := RunState.new()
	check(resumed.restore(snapshot) and resumed.growth_bonus.is_empty() and not resumed.ascetic, "old active runs restore optional extension defaults")
	snapshot.erase("hp")
	check(not resumed.restore(snapshot), "missing core progress is still rejected")
	check(RunState.potion_cap() == 4 and int(TableCache.nodes_config().shop.potion_cap) == 4, "supply and shop use four-potion capacity")
	for theme in TableCache._load("res://data/run_events.json").get("events", {}):
		if int(Events.row(theme).get("potions", 0)) <= 0: continue
		run.theme = theme
		run.hp = -1
		run.potions = 3
		check(bool(Events.apply(run, {}, "work").ok) and run.potions == 4, "event supply can fill the fourth potion")
		run.potions = 4
		var progress := {}
		check(not Events.apply(run, progress, "work").ok and progress.is_empty() and run.potions == 4, "full supply is refused without consuming event")

	var bad_path := "user://corrupt_appraisal_regression.json"
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	G.SAVE_PATH = bad_path
	G._load_save()
	check(G.save_locked and not G.save_backup_path.is_empty(), "unparseable main save is backed up and write-locked")
	G.deposit(99, 99, 99)
	check(FileAccess.get_file_as_string(bad_path) == "{broken json", "automatic reward cannot overwrite corrupt main save")
	G.save_locked = false
	G.SAVE_PATH = "user://full_play_regression.json"

	var panel := GachaPanel.new()
	panel.presentation_enabled = false
	add_child(panel)
	G.items["ticket_ten"] = 1
	G.prog["gacha"] = {"pity": 17, "free_day": G.today_key(), "free_streak": 0, "free_last": ""}
	before = state(G)
	G.SAVE_PATH = "user://directory_that_does_not_exist/save.json"
	panel._do_ten()
	check(state(G) == before and panel._results.is_empty(), "failed ten-draw write restores ticket, pity, pets and wallet")
	G.SAVE_PATH = "user://full_play_regression.json"
	panel._do_ten()
	check(G.item_count("ticket_ten") == 0 and panel._results.size() == 10, "ten-draw success consumes one ticket with all rewards")
	check(panel._pick_pet(RandomNumberGenerator.new(), "__missing_rarity__").is_empty(), "missing rarity never falls back to unrelated quality")
	panel._layout_result()
	check(panel._result_content.custom_minimum_size.y >= 680 and panel._result_scroll != null, "result layout provides a scrollable safe content area")
	panel.queue_free()
	await get_tree().process_frame
