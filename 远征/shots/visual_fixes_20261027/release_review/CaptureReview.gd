extends Node

const OUT := "res://shots/visual_fixes_20261027/release_review/"
var current: Node
var records: Array = []

func frames(n := 8) -> void:
	for i in n: await get_tree().process_frame

func clean() -> void:
	if is_instance_valid(current):
		current.queue_free()
		await frames(3)
	current = null

func attach(node: Node) -> void:
	await clean()
	current = node
	add_child(node)
	await frames(12)

func shot(id: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(OUT + id + ".png")
	records.append({"id": id, "size": str(get_viewport().get_visible_rect().size), "result": result})
	print("REVIEW_SHOT ", id)

func dimensions(w: int, h: int) -> void:
	await clean()
	get_window().size = Vector2i(w, h)
	get_window().content_scale_size = Vector2i(w, h)
	await frames()

func home(page: String, id: String) -> void:
	await attach(preload("res://src/ui/GameHome.tscn").instantiate())
	if not page.is_empty():
		current.open_gm_feature(page)
		await frames(14)
	await shot(id)

func bag(id: String) -> void:
	var panel := BagPanel.new()
	await attach(panel)
	if not panel._item_buttons.is_empty():
		panel._item_buttons[0].pressed.emit()
		await frames()
	await shot(id)

func map_page(id: String) -> void:
	var panel := preload("res://src/ui/WorldPointMap.gd").new()
	panel.map_id = "lorin_wilds"
	panel.standalone = true
	await attach(panel)
	await shot(id)

func world(id: String) -> void:
	G.prog.main_world = {"map_id": id}
	var run := RunState.new()
	run.setup({"role_id":"zs", "theme":String(TableCache.main_world_map(id).get("theme","forest")), "level":35, "seed":71})
	MapScene.pending_cfg = {"mode":"main_world", "main_map_id":id, "run":run, "node":{"type":"normal", "layer":1, "index":0}}
	await attach(preload("res://src/explore/MapScene.tscn").instantiate())
	await get_tree().create_timer(0.7).timeout
	current.set_physics_process(false)
	for monster in current._monsters: monster.set_physics_process(false)
	if current._city_content != null:
		current._city_content.set_physics_process(false)
		if current._city_content._panel != null: current._city_content._close_panel()
	await frames()
	await shot("world_" + id)
	if id in ["old_salt_road", "red_sand_route", "frost_boardwalk"]:
		current._player.position = Vector2(480,560)
		await frames()
		await shot("world_" + id + "_middle")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	G.SAVE_PATH = ProjectSettings.globalize_path(OUT + "isolated_save.json")
	G._init_state_defaults()
	G.save_locked = false
	G.set_meta("ui_review_mode", true)
	G.gm_unlocked = true
	G.gm_grant_all()
	G.gm_unlock_all_features()
	G.gm_world_open = true
	G.selected_role = "zs"
	G.player_name = "沈舟"
	G.prog.level = 35
	G.wallet = {"gold":128400, "expedition":2310, "soul":860, "honor":1240}
	G.ensure_starter_equip(true)
	G.ensure_starter_pets()
	G.mount_buy("horse")
	G.mount_set_riding(false, false)
	G.items["enhance_stone"] = 23
	G.items["gem_hp_5"] = 1
	G.inv_grant_equip({"tpl":"tpl_sword_wolf", "rarity":2, "n":24}, false)
	get_window().unresizable = false
	get_window().min_size = Vector2i(300,480)
	await dimensions(480,800)
	if "--hud-proof" in OS.get_cmdline_user_args():
		var proof: Array = []
		for id in ["lorin_wilds", "red_sand_route"]:
			await world(id)
			var before: String = current._main_story_l.text
			current._refresh_hud()
			await frames()
			proof.append({"map":id, "before":before, "after":current._main_story_l.text, "expected":G.story_goal_short()})
			await shot("world_" + id + "_hud_refreshed")
		var proof_file := FileAccess.open(OUT + "hud_observation.json", FileAccess.WRITE)
		proof_file.store_string(JSON.stringify(proof, "\t"))
		proof_file.close()
		await clean()
		print("HUD_OBSERVATION_DONE")
		get_tree().quit()
		return
	if "--details" in OS.get_cmdline_user_args():
		if not "--region-only" in OS.get_cmdline_user_args():
			for id in ["lorin_wilds", "maple_road", "broken_slope", "old_salt_road", "shenyuan_port", "tideflat", "tidal_gate", "stele_cavern", "red_sand_route", "frost_post", "rift_mine_road", "rift_mine_vault", "frost_pass", "frost_boardwalk", "abyss_ring", "stele_entry", "stele_resonance", "stele_core"]:
				await world(id)
		G.prog.main_world = {"map_id":"lorin_wilds"}
		await home("worlds", "worlds_800")
		var region: Control = current._worlds
		region._shell.scroll.scroll_vertical = 100000
		await frames()
		await shot("worlds_800_scrolled")
		await clean()
		print("CURRENT_REVIEW_DETAILS_DONE")
		get_tree().quit()
		return
	await attach(preload("res://src/ui/Title.tscn").instantiate())
	await get_tree().create_timer(0.9).timeout
	await shot("title_800")
	await attach(preload("res://src/ui/Login.tscn").instantiate())
	await shot("login_800")
	G.prog.main_world = {"map_id":"lorin_wilds"}
	await home("", "home_800")
	await bag("bag_800")
	for page in ["quests", "activities", "exchange", "growth:pet", "gacha", "worlds", "fishing:salt"]:
		await home(page, page.replace(":", "_") + "_800")
	await map_page("map_800")
	for id in ["lorin_wilds", "maple_road", "broken_slope", "old_salt_road", "shenyuan_port", "tideflat", "tidal_gate", "stele_cavern", "red_sand_route", "frost_post", "rift_mine_road", "rift_mine_vault", "frost_pass", "frost_boardwalk", "abyss_ring", "stele_entry", "stele_resonance", "stele_core"]:
		await world(id)
	await clean()
	BattleScene.pending_cfg = {"ally":{"role_id":"zs", "level":35, "active_pet":"pet_rockturtle"}, "enemy":{"theme":"forest", "node_type":"normal", "layer":1}, "seed":71}
	await attach(preload("res://src/battle/BattleScene.tscn").instantiate())
	current.set_process(false)
	await shot("battle_800")
	await dimensions(480,1067)
	G.prog.main_world = {"map_id":"lorin_wilds"}
	await home("", "home_1067")
	await bag("bag_1067")
	await home("activities", "activities_1067")
	await home("exchange", "exchange_1067")
	await home("fishing:salt", "fishing_1067")
	await map_page("map_1067")
	await dimensions(320,640)
	await bag("bag_320x640")
	await map_page("map_320x640")
	await clean()
	var f := FileAccess.open(OUT + "capture_manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"captured_at":Time.get_datetime_string_from_system(), "records":records}, "\t"))
	f.close()
	Audio.stop_bgm()
	Audio.set_suspended(true)
	print("CURRENT_REVIEW_DONE ", records.size())
	get_tree().quit()
