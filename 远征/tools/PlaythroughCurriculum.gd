# 完整三幕旧档副本：真实走回昭元，接近岳教头并点击学会后三式；B 为新进程读档。
extends "res://tools/PlaythroughMainWorld.gd"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role_id = String(args[0]) if args.size() > 0 else "zs"
	phase = String(args[1]) if args.size() > 1 else "a"
	var source_dir := ""
	G.SAVE_PATH = "res://tools/_logs/save_playthrough_%s_%s.json" % [role_id, phase]
	for arg in args:
		if arg.begins_with("--source-dir="): source_dir = arg.trim_prefix("--source-dir=")
		if arg.begins_with("--save-dir="): G.SAVE_PATH = arg.trim_prefix("--save-dir=").path_join("save_playthrough_%s_%s.json" % [role_id, phase])
	await get_tree().process_frame
	get_tree().current_scene = null
	act2 = true
	if phase == "a":
		var source := source_dir.path_join("save_playthrough_%s_a.json" % role_id)
		var raw := FileAccess.get_file_as_string(source)
		if not JSON.parse_string(raw) is Dictionary: return _bad("授业源档缺失")
		var file := FileAccess.open(G.SAVE_PATH, FileAccess.WRITE)
		if file == null: return _bad("隔离授业档无法复制")
		file.store_string(raw)
		file.close()
		print("PLAY_SOURCE sha256=%s" % FileAccess.get_sha256(source))
	if not G.reload_save() or G.save_locked or G.selected_role != role_id: return _bad("授业旧档载入失败")
	if phase == "a":
		if G.prog.has("skill_curriculum"): return _bad("源档已含后三式")
		if not await _learn_three(): return
	if G.act1_unlocked_skills().size() != 5 or not MentorCurriculum.validate(G.prog.get("skill_curriculum"), G.prog): return _bad("后三式或授业账目不完整")
	print("PLAY_%s_STATE " % phase.to_upper() + JSON.stringify({"role": G.selected_role, "skills": G.act1_unlocked_skills(), "curriculum": G.prog.skill_curriculum, "wallet": G.wallet, "items": G.items, "inventory": G.prog.inventory, "worn": G.prog.equip, "old_mentor": G.mentor_state(), "level": G.prog.level, "story": G.prog.story}))
	print("PLAY_%s_OK role=%s curriculum=three_real_learns" % [phase.to_upper(), role_id])
	if phase == "b": print("PLAY_OK curriculum_restart")
	get_tree().quit(0)

func _learn_three() -> bool:
	var start := String(G.prog.get("main_world", {}).get("map_id", ""))
	if start != "frost_post": return _bad("授业路线必须从三幕完成的霜关旧档出发")
	if not await _enter_world("", "", start): return _bad("无法继续霜关旧档")
	for route in [["frost_post", Vector2(480, 1152), "red_sand_route"], ["red_sand_route", Vector2(480, 1152), "shenyuan_port"], ["shenyuan_port", Vector2(90, 660), "old_salt_road"], ["old_salt_road", Vector2(90, 660), "maple_road"], ["maple_road", Vector2(480, 1152), "lorin_wilds"]]:
		# 东侧入口先沿横路走到中轴，再沿主路回城；不斜穿树丛。
		if String(route[0]) == "maple_road" and not await _move_to(Vector2(480, 660), 24.0): return false
		if not await _exit_to(String(route[0]), route[1], String(route[2])): return false
	if not await _close_city_modal(): return false
	var city: CityScene = _map._city_content
	var open: Control = null
	# 路边其他 NPC 也会自动开对话；正常关闭后继续走，不把任意弹窗当作导师。
	for attempt in 20:
		if not _city_modal():
			var reached := await _travel(_npc_pos("npc_mentor"), 20.0, true, false)
			if reached != "ok": return _bad("真实前往导师失败：" + reached)
		if _city_modal():
			open = _action(city._panel, "open")
			if open != null: break
			if not await _close_city_modal(): return false
		await _wait_frames(4)
	if open == null: return _bad("导师缺少后续招式入口")
	await _click(open)
	await _wait_frames(5)
	var baseline: Variant = JSON.parse_string(JSON.stringify([G.prog.inventory, G.prog.equip, G.items, G.prog.skills, G.mentor_state()]))
	var gold := int(G.wallet.gold)
	for entry in MentorCurriculum.rows(role_id):
		var sid := String(entry.id)
		var detail := _action(city._panel, "detail", sid)
		if detail == null: return _bad("招式表缺少 " + sid)
		await _click(detail)
		await _wait_frames(5)
		var learn := _action(city._panel, "learn", sid)
		if learn == null: return _bad("满足三幕等级剧情仍不能学习 " + sid)
		var before := int(G.wallet.gold)
		if not await _click_until(learn, func() -> bool: return sid in G.act1_unlocked_skills(), 30, "curriculum_" + sid): return _bad("真实学习未解锁 " + sid)
		await _wait_frames(5)
		if int(G.wallet.gold) != before - int(entry.gold): return _bad("学费扣除错误 " + sid)
		if _action(city._panel, "learn", sid) != null: return _bad("已学招式仍可重复付费")
		print("PLAY_EVENT curriculum_learn skill=%s cost=%d gold=%d" % [sid, int(entry.gold), int(G.wallet.gold)])
		await _click(_action(city._panel, "back"))
		await _wait_frames(5)
	if int(G.wallet.gold) != gold - 500 or JSON.parse_string(JSON.stringify([G.prog.inventory, G.prog.equip, G.items, G.prog.skills, G.mentor_state()])) != baseline: return _bad("学习后三式破坏旧投入或费用不符")
	if not await _close_city_modal(): return false
	if not G.save_game(): return _bad("五式写档失败")
	return true

func _action(root: Node, action: String, sid := "") -> Control:
	if root == null: return null
	for child in root.get_children():
		if child is Control and child.get_meta("curriculum_action", "") == action and (sid.is_empty() or child.get_meta("curriculum_skill", "") == sid): return child
		var found := _action(child, action, sid)
		if found != null: return found
	return null
