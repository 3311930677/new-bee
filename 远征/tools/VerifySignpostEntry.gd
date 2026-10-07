extends Node
var failures := 0
func check(ok: bool, words: String) -> void:
	if not ok: failures+=1; push_error("SIGNPOST_ENTRY_FAIL " + words)

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_signposts.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "fs"
	G.prog.level = 13
	var tested := 0
	for mid: String in ["lorin_wilds","maple_road","broken_slope","frost_boardwalk"]:
		var cfg := TableCache.main_world_map(mid)
		var run := RunState.new()
		run.setup({"theme":cfg.theme,"role_id":"fs","level":13,"seed":7})
		G.prog.main_world = {"map_id":mid,"layout_version":3,"position":[480,192]}
		MapScene.pending_cfg = {"mode":"main_world","main_map_id":mid,"run":run,"node":{"type":"normal","layer":0,"index":0}}
		var map: MapScene = preload("res://src/explore/MapScene.tscn").instantiate()
		add_child(map)
		map.process_mode = PROCESS_MODE_DISABLED
		for row: Dictionary in cfg.exits:
			var sign := map._world_exit_sign_position(row)
			var found := false
			for child in map._world.get_children():
				if child is MapScene._WorldExit and child.position.is_equal_approx(sign): found=true
			check(found,mid + " real visual sign must match contact area")
			check(map._world_exit_touch_rect(row).has_point(sign+Vector2(0,-48)),mid + " contact at middle of 96px sign")
			check(not map._world_exit_touch_rect(row).has_point(sign+Vector2(110,0)),mid + " unrelated nearby path must not enter")
			tested+=1
		var north: Dictionary = cfg.exits[0]
		for row: Dictionary in cfg.exits:
			if float(row.at[1])<180: north=row; break
		var id := String(north.id)
		check(map._arrival_exit_blocks.has(id),mid + " resume inside sign guarded against return loop")
		map._world_exit_cd = 0
		map._check_world_exits()
		check(map._world_exit_cd == 0,mid + " resume guard does not initiate transition")
		map._player.position = map._world_exit_sign_position(north)+Vector2(0,160)
		map._check_world_exits()
		check(not map._arrival_exit_blocks.has(id),mid + " walking away rearms sign")
		var locked := north.duplicate(true)
		locked.requires_story = "__signpost_test_locked__"
		map._main_cfg = cfg.duplicate(true)
		map._main_cfg.exits = [locked]
		map._player.position = map._world_exit_sign_position(locked)+Vector2(0,-48)
		map._world_exit_cd = 0
		var before := JSON.stringify(G.prog)
		map._check_world_exits()
		check(map._world_exit_cd == 2 and JSON.stringify(G.prog)==before,mid + " story lock remains effective at visible sign")
		map.queue_free()
		await get_tree().process_frame
	print("SIGNPOST_ENTRY_OK signs=%d" % tested if failures==0 else "SIGNPOST_ENTRY_FAIL count=%d" % failures)
	get_tree().quit(0 if failures==0 else 1)
