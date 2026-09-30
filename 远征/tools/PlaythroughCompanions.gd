# Continue a verified third-act save through actual walking and viewport clicks.
extends "res://tools/PlaythroughThirdSide.gd"

const PID := "pet_rockturtle"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role_id = String(args[0]) if args.size() > 0 else "zs"
	phase = String(args[1]) if args.size() > 1 else "a"
	act3 = true
	act3_front = true
	act2 = true
	var source_dir := ""
	G.SAVE_PATH = "res://tools/_logs/save_playthrough_%s_%s.json" % [role_id,phase]
	for arg in args:
		if arg.begins_with("--save-dir="): G.SAVE_PATH = arg.trim_prefix("--save-dir=").path_join("save_playthrough_%s_%s.json" % [role_id,phase])
		if arg.begins_with("--source-dir="): source_dir = arg.trim_prefix("--source-dir=")
	await get_tree().process_frame
	get_tree().current_scene = null
	if phase == "b":
		await _run_phase_b()
		return
	var source := source_dir.path_join("save_playthrough_%s_a.json" % role_id)
	var raw := FileAccess.get_file_as_string(source)
	var saved: Variant = JSON.parse_string(raw)
	if not (saved is Dictionary) or saved.get("selected_role","") != role_id or saved.get("prog",{}).get("story",{}).get("done",[]).size() != 28:
		_bad("缺少对应职业28步验收档")
		return
	var file := FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
	if file == null:
		_bad("隔离续档不能写入")
		return
	file.store_string(raw)
	file.close()
	print("PLAY_SETUP verified_source=%s sha256=%s role=%s" % [source,FileAccess.get_sha256(source),role_id])
	if not G.reload_save() or not _all_done() or not await _enter_world("","","frost_post"): return
	# Return along the existing world roads; never grant a pet or teleport to its keeper.
	for edge in [["frost_post",480,1152,"red_sand_route"],["red_sand_route",480,1152,"shenyuan_port"],
		["shenyuan_port",90,660,"old_salt_road"],["old_salt_road",90,660,"maple_road"],
		["maple_road",480,1152,"lorin_wilds"]]:
		if edge[0] == "maple_road" and not await _move_to(Vector2(480,660),20): return
		if not await _exit_to(edge[0],Vector2(edge[1],edge[2]),edge[3]): return
	if not await _claim_pet(): return
	for edge in [["lorin_wilds",480,96,"maple_road"],["maple_road",864,660,"old_salt_road"],
		["old_salt_road",864,660,"shenyuan_port"],["shenyuan_port",480,96,"red_sand_route"],
		["red_sand_route",480,96,"frost_post"]]:
		if edge[0] == "old_salt_road" and not await _move_to(Vector2(480,500),20): return
		if not await _exit_to(edge[0],Vector2(edge[1],edge[2]),edge[3]): return
	if not await _buy_food() or not await _open_training(): return
	var food := G.item_count("pet_food")
	if not await _training_click("追击",func() -> bool: return CompanionService.state(G.prog,PID).traits == ["comp_pursuit"]): return
	if G.item_count("pet_food") != food-1:
		_bad("第一项实际扣粮不符")
		return
	if not await _close_city_modal(): return
	var before := int(CompanionService.state(G.prog,PID).wins)
	if not await _exit_to("frost_post",Vector2(864,710),"rift_mine_road"): return
	# Actual retreat must leave the participant's counter unchanged.
	if not await _fight_nearest("flee"): return
	if int(CompanionService.state(G.prog,PID).wins) != before:
		_bad("撤退错误增加协战")
		return
	print("PLAY_EVENT companion_flee wins_unchanged=true")
	# The retreat grace period is part of the actual game; wait it out rather than clearing it.
	for frame in 240: await get_tree().physics_frame
	for i in 3:
		var count := int(CompanionService.state(G.prog,PID).wins)
		if i == 2:
			# Follow the open central aisle to the northern patrol, instead of cutting through side rocks.
			if _map._player.position.y < 1005 and not await _move_to(Vector2(_map._player.position.x,1005),20): return
			if not await _move_to(Vector2(480,1005),20): return
			if not await _move_to(Vector2(480,345),20): return
			if not await _move_to(Vector2(300,345),20): return
		if int(CompanionService.state(G.prog,PID).wins) == count and not await _fight_nearest("win"): return
		if int(CompanionService.state(G.prog,PID).wins) != mini(20,count+1):
			_bad("实际胜利未恰好增加一次协战")
			return
		print("PLAY_EVENT companion_real_win count=%d" % int(CompanionService.state(G.prog,PID).wins))
	if not await _move_to(Vector2(480,345),20) or not await _move_to(Vector2(480,710),20): return
	if not await _exit_to("rift_mine_road",Vector2(90,710),"frost_post") or not await _open_training(): return
	if not await _training_click("第2项",func() -> bool: return (_map._city_content._panel as CompanionPanel)._slot == 1): return
	food = G.item_count("pet_food")
	if not await _training_click("护卫",func() -> bool: return CompanionService.state(G.prog,PID).traits == ["comp_pursuit","comp_guard"]): return
	if G.item_count("pet_food") != food-2:
		_bad("第二项实际扣粮不符")
		return
	if not await _training_click("随行中",func() -> bool: return G.prog.get("companions",{}).get("active","") == PID): return
	if not await _close_city_modal() or not G.save_game() or not G.reload_save():
		_bad("协战最终落盘失败")
		return
	_release_all()
	print("PLAY_A_STATE " + JSON.stringify(_state()))
	print("PLAY_A_OK role=%s companion_real_wins=3 pet_claim=true training_slots=2" % role_id)
	get_tree().quit()

func _claim_pet() -> bool:
	if G.owned_pets().has(PID): return true
	for attempt in 20:
		if not await _close_city_modal(): return false
		if _map._player.position.distance_to(_npc_pos("npc_keeper")) <= 90:
			if await _travel(Vector2(480,660),20,true) != "ok": return _bad("不能离开兽栏重触发范围")
		if await _travel(_npc_pos("npc_keeper"),20,true,false) != "ok": return _bad("兽栏不可达")
		var label := _find_label(_map._city_content._panel,[G._button_text("结缘 · 带它同行")])
		if label != null:
			if not await _click_until(label.get_parent() as Control,func() -> bool: return G.owned_pets().has(PID),40,"claim_pet"): return _bad("结缘点击未领取")
			print("PLAY_EVENT companion_claim real_click=true source=npc_keeper")
			return await _close_city_modal()
	return _bad("未触发兽栏结缘面板")

func _buy_food() -> bool:
	if not await _close_city_modal(): return false
	var city: CityScene = _map._city_content
	if not await _click_until(city._quest_chip,func() -> bool: return city._overlay is ShopPanel,40,"open_shop"): return _bad("物资铺真实按钮不能打开")
	while G.item_count("pet_food") < 3:
		var shop := city._overlay as ShopPanel
		var buy: Label = null
		for band in shop._rows_box.get_children():
			if band.is_queued_for_deletion(): continue
			for child in band.get_children():
				if child is Label and child.text.begins_with(G.item_name("pet_food")):
					buy = _find_label(band,[G._button_text("购入")])
		if buy == null: return _bad("没有宠粮货架")
		var food := G.item_count("pet_food")
		var gold := int(G.wallet.gold)
		if not await _click_until(buy.get_parent() as Control,func() -> bool: return G.item_count("pet_food") == food+1,40,"buy_food"): return _bad("宠粮购买未入栏")
		if int(G.wallet.gold) != gold-90: return _bad("宠粮购价不符")
		print("PLAY_EVENT companion_food real_buy=true gold_cost=90")
		await _wait_frames(3)
	var back := _find_label(city._overlay,["返回"])
	return back != null and await _click_until(back.get_parent() as Control,func() -> bool: return city._overlay == null,40,"shop_back")

func _open_training() -> bool:
	for attempt in 20:
		if not _city_modal():
			var positions: Dictionary = _map._main_cfg.city_building_positions
			var at: Array = positions.frost_lodge
			if await _travel(Vector2(at[0],at[1]),20,true,false) != "ok": return _bad("驿舍不可达")
		var label := _find_label(_map._city_content._panel,[G._button_text("伙伴协战")])
		if label != null:
			return await _click_until(label.get_parent() as Control,func() -> bool: return _map._city_content._panel is CompanionPanel,40,"open_training")
		if not await _close_city_modal(): return false
		if await _travel(Vector2(480,660),20,true) != "ok": return _bad("不能离开驿舍重触发范围")
	return _bad("未找到驿舍协战服务")

func _training_click(words: String, predicate: Callable) -> bool:
	var label := _find_label(_map._city_content._panel,[G._button_text(words)])
	return label != null and await _click_until(label.get_parent() as Control,predicate,40,"training_"+words)

func _run_phase_b() -> void:
	if not G.reload_save(): return _bad("协战续档重启失败")
	var row := CompanionService.state(G.prog,PID)
	if row.get("traits",[]) != ["comp_pursuit","comp_guard"] or int(row.get("wins",0)) < 3 or G.companion_active() != PID:
		_bad("跨进程丢失两项训练、熟练或随行")
		return
	print("PLAY_EVENT companion_restart slots=2 wins=%d active=%s" % [int(row.wins),G.companion_active()])
	await super._run_phase_b()

func _state() -> Dictionary:
	var result := super._state()
	result["companions"] = G.prog.get("companions",{}).duplicate(true)
	result["pet_stats"] = G.prog.get("pet_stat",{}).duplicate(true)
	result["pet_food"] = G.item_count("pet_food")
	return result
