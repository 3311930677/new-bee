extends "res://tools/VerifyRound1UI.gd"
## Isolated visual fixture; player saves never participate in this review.
func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	OUT = "res://shots/world_hud_20261015/"
	var prefix := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="): prefix = arg.trim_prefix("--prefix=")
	G.SAVE_PATH = OUT + "isolated_save.json"
	G.set_meta("ui_review_mode", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800, 1067]:
		var map := await make_map("maple_road", height)
		map.set_physics_process(false)
		G.player_name = "沈舟"
		G.prog.level = 60
		G.wallet.gold = 1000000
		G.collect_pet("pet_foxfire")
		map.st.active_pet = "pet_foxfire"
		map._refresh_hud()
		map._player.position = Vector2(480,930)
		map._sync_world_companion()
		await get_tree().process_frame
		await get_tree().process_frame
		check(map._main_hp_fill.size.x > 0 and map._main_exp_fill.size.x > 0,"状态条按实际比例填充")
		var mini_center := map._minimap._map_rect().get_center()
		check(map._minimap._project(map._player.position).is_equal_approx(mini_center),"小地图玩家保持居中")
		check(map._minimap._project(Vector2(-10000,-10000)).distance_to(mini_center) <= 38.1,"图外标记收在圆形舆图内")
		check_hotspots(map, map.get_viewport_rect())
		await shot("%s_%d" % [prefix,height])
		await click(map._sprint_btn)
		check(map._sprint and map._sprint_btn.get_node("Caption").text == "疾行中", "疾行按钮可点击且状态同步")
		await shot("%s_sprint_%d" % [prefix,height])
		await click(map._sprint_btn)
		await click(map._round_fold)
		check(map._round_expanded, "任务展开保持可用")
		await click(map._round_fold)
		check(map._round_collapsed, "任务收起保持可用")
		map._round_collapsed = false
		map._layout_round_tasks()
		var safe := Rect2(8,44,464,height-78)
		map._layout_round1_hud(safe)
		check_hotspots(map, safe)
		await shot("%s_safe_%d" % [prefix,height])
		map._layout_round1_hud()
		map.st.hp = roundi(map.st.max_hp() * 0.2)
		map._refresh_hud()
		await shot("%s_low_hp_%d" % [prefix,height])
		var hp_before := map.st.hp
		await click(map._round_potion)
		check(map.st.hp > hp_before and map.st.potions == 1, "药剂点击仍治疗并扣除数量")
		map.st.potions = 0
		map._refresh_hud()
		await shot("%s_potion_zero_%d" % [prefix,height])
		await click(map._minimap)
		check(map._big_map != null, "地图可展开")
		await shot("%s_map_expanded_%d" % [prefix,height])
		map._close_big_map()
		G.wallet.gold = 999999999
		map._refresh_hud()
		check(map._main_gold_l.text == "9.99亿", "大额货币仍正确缩写")
		preload("res://src/ui/WorldHUD.gd").update_task(map._main_story_l,"主 · 穿过城门与执事闻叔交谈然后继续前往古道驿亭调查")
		map._layout_round_tasks()
		check(map._main_story_l.size.y >= 40,"长任务两行有足够文字高度")
		check(map._main_story_l.get_visible_line_count() >= 2,"长任务两行实际可见")
		check_hotspots(map,map.get_viewport_rect())
		if capture: await get_tree().create_timer(2.2).timeout
		await shot("%s_long_task_%d" % [prefix,height])
		await close_page()
	print("PIXEL_WORLD_HUD cases=%d failures=%d" % [cases,failures])
	get_tree().quit(0 if failures == 0 else 1)
