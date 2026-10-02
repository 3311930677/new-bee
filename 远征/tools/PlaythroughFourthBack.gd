# Real s32 continuation; no invented experience, money, gear, pets or story flags.
extends "res://tools/PlaythroughCampaignGear.gd"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role_id = String(args[0]) if args.size()>0 else "zs"
	phase = String(args[1]) if args.size()>1 else "a"
	act2 = true
	fullbag_fixture = false
	var source_dir := ""
	G.SAVE_PATH = "res://tools/_logs/save_fourth_back_%s_%s.json" % [role_id,phase]
	for arg in args:
		if arg.begins_with("--source-dir="): source_dir=arg.trim_prefix("--source-dir=")
		if arg.begins_with("--save-dir="):
			G.SAVE_PATH=arg.trim_prefix("--save-dir=").path_join("save_playthrough_%s_%s.json" % [role_id,phase])
	await get_tree().process_frame
	get_tree().current_scene=null
	var source := source_dir.path_join("save_playthrough_%s_a.json" % role_id)
	var old: Dictionary = {}
	if phase=="a":
		var raw:=FileAccess.get_file_as_string(source)
		var parsed: Variant=JSON.parse_string(raw)
		if not parsed is Dictionary: return _bad("第四幕后半源档缺失")
		old=parsed
		if old.get("selected_role","")!=role_id or old.prog.story.done.size() not in [32,36]:
			return _bad("必须使用本职业真实32步完成档或36步返访检查点")
		print("PLAY_SOURCE done_steps=%d" % old.prog.story.done.size())
		var file:=FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
		if file==null: return _bad("隔离存档写入失败")
		file.store_string(raw)
		file.close()
		print("PLAY_SOURCE sha256=%s" % FileAccess.get_sha256(source))
	if not G.reload_save() or G.save_locked: return _bad("第四幕后半读档失败")
	_protected=G.inv_worn_uids().keys()
	if phase=="a":
		if not await _walk_back(): return
		for key in ["pets","pet_stat","skills","talents","mounts","companions","skill_curriculum"]:
			if JSON.parse_string(JSON.stringify(G.prog.get(key))) != old.prog.get(key): return _bad("破坏旧投入 "+key)
		for key in old.prog.get("flags",{}):
			if G.prog.flags.get(key)!=old.prog.flags[key]: return _bad("破坏旧世界旗 "+key)
		for inst in old.prog.inventory.get("instances",[]):
			var found := G.inv_find(int(inst.uid))
			if found.is_empty(): return _bad("旧装备丢失 uid="+str(inst.uid))
	if G.prog.story.done.size()!=36 or not G.story_current().is_empty() or G.prog.level!=60 \
		or G.item_count("stele_key")!=0 or G.item_count("stable_seal")!=0 or G.item_count("stele_record")!=0 \
		or not bool(G.prog.flags.get("act4_nameless_down",false)):
		return _bad("第四幕终态不完整")
	# B is read-only: a fresh process verifies all puzzle flags, bosses, sources and ending.
	for flag in ["act4_return_anchor","act4_forest_voice","act4_tide_voice","act4_snow_voice","act4_voices_aligned","act4_avatar_down","campaign_complete"]:
		if not bool(G.prog.flags.get(flag,false)): return _bad("终态缺世界旗 "+flag)
	if phase=="a" and not G.save_game(): return _bad("终态未落盘")
	var state: Dictionary={"role":G.selected_role,"prog":G.prog,"wallet":G.wallet,"items":G.items}
	print("PLAY_%s_STATE " % phase.to_upper()+JSON.stringify(JSON.parse_string(JSON.stringify(state))))
	print("PLAY_%s_OK role=%s fourth_back=real_rooms_bosses_ending" % [phase.to_upper(),role_id])
	if phase=="b": print("PLAY_OK fourth_back_restart")
	get_tree().quit(0)

func _walk_back() -> bool:
	if G.story_step_done("s36"):
		if not await _enter_world("","","abyss_ring"): return _bad("返访检查点不在外环")
		print("PLAY_EVENT resume_verified_ending_checkpoint=true")
		return await _finish_optional()
	if not await _enter_world("","","lorin_wilds"): return _bad("旧档不在昭元")
	if not await _outward(): return false
	if not await _exit_to("abyss_ring",Vector2(480,96),"stele_entry"): return false
	if not await _need("s33"): return false
	if not await _touch_puzzle("return_anchor","act4_return_anchor"): return false
	if not await _exit_to("stele_entry",Vector2(480,96),"stele_resonance"): return false
	for row in [["forest_voice","act4_forest_voice"],["tide_voice","act4_tide_voice"],["snow_voice","act4_snow_voice"]]:
		if not await _touch_puzzle(row[0],row[1]): return false
	if not await _visit_entity("aligned_voices","s34"): return false
	if not await _campaign_gear_checkpoint("fourth_back"): return false
	if not await _exit_to("stele_resonance",Vector2(480,96),"stele_core"): return false
	# Controlled damage boundary; resources and progression remain the real old-save budget.
	_map.st.hp=1
	print("PLAY_SETUP injured_boundary hp=1 no_resource_grants=true")
	if not await _fight_nearest("lose","mon_abyss_avatar"): return false
	if G.story_step_done("s35") or G.item_count("stable_seal")!=1: return _bad("败北误推进或吞封记")
	if not G.reload_save() or not await _enter_world("","","stele_core"): return _bad("败后读档恢复失败")
	print("PLAY_EVENT fourth_defeat_reenter seal=1")
	if not await _fight_nearest("flee","mon_abyss_avatar"): return false
	if G.story_step_done("s35") or G.item_count("stable_seal")!=1: return _bad("撤退误推进或吞封记")
	print("PLAY_EVENT fourth_flee_recovery seal=1")
	if not G.reload_save() or not await _enter_world("","","stele_core"): return _bad("撤退后读档失败")
	if not await _fight_nearest("win","mon_abyss_avatar"): return false
	if not await _need("s35"): return false
	if not await _campaign_gear_checkpoint("fourth_back"): return false
	for route in [["stele_core",Vector2(480,1152),"stele_resonance"],["stele_resonance",Vector2(480,1152),"stele_entry"],["stele_entry",Vector2(480,1152),"abyss_ring"]]:
		if not await _exit_to(route[0],route[1],route[2]): return false
	if not await _homeward(): return false
	if not await _choose_ending(): return false
	if not await _campaign_gear_checkpoint("fourth_back"): return false
	if not await _outward(): return false
	return await _finish_optional()

func _finish_optional() -> bool:
	# Use the public central lane before approaching the northern optional arena.
	if not await _move_to(Vector2(480,350),24): return false
	if not await _fight_nearest("flee","mon_nameless_warden"): return false
	if bool(G.prog.flags.get("act4_nameless_down",false)): return _bad("巡界者撤退被误奖")
	# Let the real retreat grace period expire before walking into the same foe again.
	await _wait_frames(ceili(MapScene.FLEE_CONTACT_CD*60.0)+12)
	if not await _fight_nearest("win","mon_nameless_warden"): return false
	if not G.reload_save() or not await _enter_world("","","abyss_ring"): return _bad("巡界者首胜重读失败")
	for mon in _map._monsters:
		if mon.mon_id=="mon_nameless_warden": return _bad("首胜后立刻重读刷回可选首领")
	print("PLAY_EVENT fourth_optional_restart no_duplicate_spawn=true")
	if not await _exit_to("abyss_ring",Vector2(480,96),"stele_entry"): return false
	if not await _exit_to("stele_entry",Vector2(480,96),"stele_resonance"): return false
	if not await _exit_to("stele_resonance",Vector2(480,96),"stele_core"): return false
	if not _map._monsters.is_empty() or not _map._quest_entities.is_empty(): return _bad("结局重进副本复活首领或机关")
	print("PLAY_EVENT fourth_finished_revisit no_duplicate_boss=true")
	return true

func _touch_puzzle(id: String, flag: String) -> bool:
	var entity: Node2D=null
	for e in _map._quest_entities:
		if e.eid==id: entity=e
	if entity==null: return _bad("缺少声碑 "+id)
	var target:=entity.position
	if await _travel(target,26,true)!="ok": return _bad("声碑导航失败 "+id)
	for frame in 120:
		if bool(G.prog.flags.get(flag,false)):
			print("PLAY_EVENT puzzle_real_input id="+id)
			return true
		await get_tree().physics_frame
	return _bad("声碑未触发 "+id)

func _choose_ending() -> bool:
	if not await _close_city_modal(): return false
	var title:="封渊留路" if role_id in ["zs","fs"] else "留声守望"
	for attempt in 20:
		if not _city_modal():
			if await _travel(_npc_pos("npc_steward"),24,true,false)!="ok": return _bad("返城对话导航失败")
		if _city_modal():
			var label:=_find_label(_map._city_content._panel,[title])
			if label!=null:
				if not await _click_until(label.get_parent() as Control,func(): return G.story_step_done("s36"),40,"campaign_ending"): return _bad("结局选择未推进")
				print("PLAY_STEP s36 done via "+title)
				return await _close_city_modal()
			if not await _close_city_modal(): return false
		await _wait_frames(4)
	return _bad("未找到结局选择")

func _outward() -> bool:
	for route in [["lorin_wilds",Vector2(480,96),"maple_road"],["maple_road",Vector2(864,660),"old_salt_road"],["old_salt_road",Vector2(864,660),"shenyuan_port"],["shenyuan_port",Vector2(480,96),"red_sand_route"],["red_sand_route",Vector2(480,96),"frost_post"],["frost_post",Vector2(480,96),"frost_boardwalk"],["frost_boardwalk",Vector2(480,96),"frost_pass"],["frost_pass",Vector2(864,660),"abyss_ring"]]:
		# The salt-cart landmark is the same public route used by the second-act replay.
		if route[0]=="old_salt_road" and not await _move_to(Vector2(480,500),24): return false
		if not await _exit_to(route[0],route[1],route[2]): return false
	return true

func _homeward() -> bool:
	for route in [["abyss_ring",Vector2(480,1152),"frost_pass"],["frost_pass",Vector2(480,1152),"frost_boardwalk"],["frost_boardwalk",Vector2(480,1152),"frost_post"],["frost_post",Vector2(480,1152),"red_sand_route"],["red_sand_route",Vector2(480,1152),"shenyuan_port"],["shenyuan_port",Vector2(90,660),"old_salt_road"],["old_salt_road",Vector2(90,660),"maple_road"],["maple_road",Vector2(480,1152),"lorin_wilds"]]:
		if route[0]=="maple_road" and not await _move_to(Vector2(480,660),24): return false
		if not await _exit_to(route[0],route[1],route[2]): return false
	return true
