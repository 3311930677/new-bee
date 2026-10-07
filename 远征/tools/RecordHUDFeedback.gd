extends SubViewport
## 在实际野外 HUD 中检查动效的连续更新与最终状态，并录制供视觉复核的帧。
const HUD := preload("res://src/ui/WorldHUD.gd")
var fails := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		fails += 1
		push_error("HUD_FEEDBACK_FAIL " + message)

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_hud_feedback.json"
	G.set_meta("ui_review_mode", false)
	check(HUD.motion_enabled(), "must run with graphical renderer and motion enabled")
	var output := "res://shots/hud_hierarchy_20261006/motion_frames"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	var fixture: Node = (load("res://tools/ShotRunner.gd") as GDScript).new()
	fixture._demo_prog()
	var run: RunState = fixture._make_run()
	fixture.free()
	G.account = "动效检查"
	G.player_name = "行旅者"
	G.prog.level = 13
	G.prog.exp = roundi(G.exp_to_next(13) * 0.11)
	G.prog.story = {"step": "s04", "done": ["s01", "s02", "s03"]}
	G.wallet.gold = 101780
	G.side_accept("a1_rel_child")
	run.level = 13
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "maple_road", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	map.set_process(false)
	for index in range(56):
		if index == 12:
			G.wallet.gold += 240
			G.prog.exp += roundi(G.exp_to_next(13) * 0.15)
			map._refresh_hud()
			check(map._main_gold_chip.feedback > 0, "gold change must pulse")
			check(map._main_exp_fill.get_parent().get_node("ProgressSweep").visible, "experience gain must sweep")
		if index == 14:
			G.wallet.gold += 10
			map._refresh_hud()
			var number_motion: Tween = map._main_gold_l.get_meta("hud_number_motion")
			for repeat in range(5): map._refresh_hud()
			check(map._main_gold_l.get_meta("hud_number_motion") == number_motion, "unchanged refresh must not restart count")
			check(map._main_gold_chip.tooltip_text.contains(str(G.wallet.gold)), "tooltip must report wallet during tween")
		if index == 24:
			HUD.update_task(map._main_story_l, "主线 · 沿北门继续前行")
			check(map._main_story_l.get_parent().feedback > 0, "task change must pulse")
			check(map._main_story_l.position.y == 4, "changed task should begin subtle entrance")
		if index == 28:
			HUD.update_currency(map._main_gold_l, int(G.wallet.gold) - 50)
			G.wallet.gold -= 50
		await get_tree().create_timer(0.05).timeout
		await RenderingServer.frame_post_draw
		var picture := get_texture().get_image().get_region(Rect2i(0, 0, 480, 212))
		var error := picture.save_png(output.path_join("%03d.png" % index))
		check(error == OK, "frame must save")
	check(map._main_gold_l.text == str(G.wallet.gold), "rapid gain/spend must settle at actual wallet")
	check(is_zero_approx(map._main_gold_chip.feedback), "currency glow must settle")
	check(map._main_story_l.text == "沿北门继续前行", "task badge must not duplicate prefix")
	check(is_equal_approx(map._main_story_l.position.y, 8), "task must return to grid after entrance")
	check(not map._main_exp_fill.get_parent().get_node("ProgressSweep").visible, "experience sweep must stop")
	print("HUD_FEEDBACK_OK frames=56" if fails == 0 else "HUD_FEEDBACK_FAIL fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
