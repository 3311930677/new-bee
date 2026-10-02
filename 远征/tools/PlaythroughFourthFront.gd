# 完整三幕匿名旧档副本，真实走到外环并回昭元选择准备；不造任务/经验/资源，B用新进程恢复。
extends "res://tools/PlaythroughMainWorld.gd"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role_id = String(args[0]) if args.size() > 0 else "zs"
	phase = String(args[1]) if args.size() > 1 else "a"
	G.SAVE_PATH = "res://tools/_logs/save_fourth_front_%s_%s.json" % [role_id, phase]
	var source_dir := ""
	for arg in args:
		if arg.begins_with("--source-dir="): source_dir = arg.trim_prefix("--source-dir=")
		if arg.begins_with("--save-dir="):
			G.SAVE_PATH = arg.trim_prefix("--save-dir=").path_join("save_playthrough_%s_%s.json" % [role_id, phase])
	await get_tree().process_frame
	get_tree().current_scene = null
	var source := source_dir.path_join("save_playthrough_%s_a.json" % role_id)
	var old: Dictionary = {}
	if phase == "a":
		var raw := FileAccess.get_file_as_string(source)
		var parsed: Variant = JSON.parse_string(raw)
		if not parsed is Dictionary: return _bad("第四幕源档缺失")
		old = parsed as Dictionary
		if old.get("selected_role", "") != role_id or old.prog.story.done.size() != 28:
			return _bad("第四幕需相应职业真实三幕完成档")
		var file := FileAccess.open(G.SAVE_PATH, FileAccess.WRITE)
		if file == null: return _bad("无法写隔离第四幕档")
		file.store_string(raw)
		file.close()
		print("PLAY_SOURCE sha256=%s" % FileAccess.get_sha256(source))
	if not G.reload_save() or G.save_locked or G.selected_role != role_id: return _bad("第四幕旧档无法恢复")
	if phase == "a":
		if not await _walk_front(): return
		for key in ["inventory", "equip", "pets", "pet_stat", "skills", "talents", "mounts", "companions", "skill_curriculum"]:
			if JSON.parse_string(JSON.stringify(G.prog.get(key))) != old.prog.get(key):
				return _bad("第四幕破坏原投入 " + String(key))
		for key in old.prog.get("flags", {}):
			if G.prog.flags.get(key) != old.prog.flags[key]: return _bad("第四幕改掉旧世界旗 " + String(key))
	if G.prog.story.done.size() != 32 or not G.story_step_done("s32") or G.item_count("stele_key") != 1:
		return _bad("第四幕前半状态/凭证不完整")
	# 关闭对话后的输入节流也会推进单调时间水位；打印的完整状态必须已真实落盘。
	if phase == "a" and not G.save_game(): return _bad("第四幕终态未落盘")
	# JSON读回后的数字是float；先统一同一序列化路径，让A/B完整字符串可严格比对。
	var state := {"role": G.selected_role, "prog": G.prog, "wallet": G.wallet, "items": G.items}
	print("PLAY_%s_STATE " % phase.to_upper() + JSON.stringify(JSON.parse_string(JSON.stringify(state))))
	print("PLAY_%s_OK role=%s fourth_front=real_walk_return" % [phase.to_upper(), role_id])
	if phase == "b": print("PLAY_OK fourth_front_restart")
	get_tree().quit(0)

func _walk_front() -> bool:
	if not await _enter_world("", "", "frost_post"): return _bad("第四幕旧档未从霜关恢复")
	if not await _talk_to("npc_frost_envoy", "s29"): return false
	for route in [["frost_post", Vector2(480, 96), "frost_boardwalk"],
		["frost_boardwalk", Vector2(480, 96), "frost_pass"],
		["frost_pass", Vector2(864, 660), "abyss_ring"]]:
		if not await _exit_to(String(route[0]), route[1], String(route[2])): return false
	if not await _need("s30"): return false
	if not await _visit_entity("breach_resonance", "s31"): return false
	if G.item_count("rift_echo") != 1: return _bad("真实调查未得到渊口回响")
	for route in [["abyss_ring", Vector2(480, 1152), "frost_pass"],
		["frost_pass", Vector2(480, 1152), "frost_boardwalk"],
		["frost_boardwalk", Vector2(480, 1152), "frost_post"],
		["frost_post", Vector2(480, 1152), "red_sand_route"],
		["red_sand_route", Vector2(480, 1152), "shenyuan_port"],
		["shenyuan_port", Vector2(90, 660), "old_salt_road"],
		["old_salt_road", Vector2(90, 660), "maple_road"],
		["maple_road", Vector2(480, 1152), "lorin_wilds"]]:
		if String(route[0]) == "maple_road" and not await _move_to(Vector2(480, 660), 24.0): return false
		if not await _exit_to(String(route[0]), route[1], String(route[2])): return false
	if not await _close_city_modal(): return false
	var title := "先听回声" if role_id in ["zs", "fs"] else "先稳碑座"
	for attempt in 20:
		if not _city_modal():
			var reached := await _travel(_npc_pos("npc_scribe"), 24.0, true, false)
			if reached != "ok": return _bad("回访青姨失败 " + reached)
		if _city_modal():
			var label := _find_label(_map._city_content._panel, [title])
			if label != null:
				if not await _click_until(label.get_parent() as Control,
					func() -> bool: return G.story_step_done("s32"), 40, "fourth_preparation"):
					return _bad("真实准备选择未推进")
				print("PLAY_STEP s32 done via " + title)
				return await _close_city_modal()
			if not await _close_city_modal(): return false
		await _wait_frames(4)
	return _bad("青姨未提供第四幕准备选择")
