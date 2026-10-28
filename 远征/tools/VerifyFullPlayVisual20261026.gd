extends Node
var fails := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		fails += 1
		push_error("VISUAL_FAIL: " + message)
func shot(name: String) -> void:
	var dir := "D:/new-bee/reports/full_play_fixes_20261026/visual"
	DirAccess.make_dir_recursive_absolute(dir)
	var image := get_viewport().get_texture().get_image()
	check(image != null and image.save_png(dir + "/" + name + ".png") == OK, "screenshot " + name)
func _ready() -> void:
	G.SAVE_PATH = "user://verify_full_play_visual.json"
	G.save_locked = false
	BattleScene.pending_cfg = {"ally": {"role_id":"zs", "level":35, "active_pet":"pet_rockturtle"}, "enemy": {"theme":"forest", "node_type":"normal", "layer":1}, "presentation":"classic_inline", "seed":7}
	var battle: BattleScene = load("res://src/battle/BattleScene.tscn").instantiate()
	add_child(battle)
	battle.set_process(false)
	while battle.sim.alive_units("enemy").size()<6:
		battle.sim._spawn_monster("mon_wolf", Combatant.ROW_FRONT, 3)
	battle._sync_views()
	await get_tree().process_frame
	battle._chest.refresh()
	await get_tree().process_frame
	check(battle._chest._enemy_strip.get_child_count() == 6, "six enemies have six real target cards")
	for enemy in battle.sim.alive_units("enemy"):
		var view = battle._views[enemy.uid]
		check(view.hp_bg.visible and view.hp_fg.visible, "crowded enemy retains health bar")
	await RenderingServer.frame_post_draw
	shot("battle_health_six_targets")
	battle._chest._enemy_scroll.scroll_horizontal = 1000
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	shot("battle_last_targets")
	battle.queue_free()
	await get_tree().process_frame
	get_tree().root.content_scale_size = Vector2i(480,640)
	get_tree().root.size = Vector2i(480,640)
	G.set_meta("test_safe_rect",Rect2(0,32,480,584))
	var gacha := GachaPanel.new()
	gacha.presentation_enabled = false
	add_child(gacha)
	G.wallet.soul = 720
	G.items["ticket_ten"] = 0
	gacha._do_ten()
	gacha._flip_all(true)
	await get_tree().create_timer(.6).timeout
	gacha._layout_result()
	gacha._result_scroll.scroll_vertical = 0
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(240, 490)
	touch.pressed = true
	get_viewport().push_input(touch)
	await get_tree().process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(240, 350)
	drag.relative = Vector2(0, -140)
	get_viewport().push_input(drag)
	await get_tree().process_frame
	touch.pressed = false
	touch.position = drag.position
	get_viewport().push_input(touch)
	await get_tree().process_frame
	check(gacha._result_scroll.scroll_vertical > 0, "short result screen responds to a real touch drag")
	gacha._result_scroll.scroll_vertical = 1000
	await get_tree().process_frame
	await get_tree().process_frame
	check(gacha._result_scroll.position.y >= 32 and gacha._result_scroll.get_rect().end.y <= 616, "result scroll stays inside short-screen safe area")
	check(gacha._again_btn.get_global_rect().end.y <= 616 and gacha._again_btn.get_global_rect().size.y >= 44, "repeat button is visible with full touch height after scrolling")
	await RenderingServer.frame_post_draw
	shot("gacha_short_safe_area")
	gacha.queue_free()
	G.remove_meta("test_safe_rect")
	await get_tree().process_frame
	get_tree().root.content_scale_size = Vector2i(480,800)
	get_tree().root.size = Vector2i(480,800)
	G.prog.level = 35
	G.prog.talents = {"fury_1":1}
	var talent := TalentPanel.new()
	add_child(talent)
	await get_tree().process_frame
	check(talent._chest._secondary.visible and not talent._chest._secondary.disabled, "talent reset is reachable")
	await RenderingServer.frame_post_draw
	shot("talent_reset")
	talent.queue_free()
	await get_tree().process_frame
	print("FULL_PLAY_VISUAL_%s failures=%d" % ["OK" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)
