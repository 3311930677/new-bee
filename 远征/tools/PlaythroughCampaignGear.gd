## Real mouse input: camp, bag pagination, sell ordinary fixture items, claim, wear, return.
extends "res://tools/PlaythroughMainWorld.gd"

var _protected: Array = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role_id = String(args[0]) if args.size() > 0 else "zs"
	phase = String(args[1]) if args.size() > 1 else "a"
	act3 = true
	act3_front = true
	act2 = true
	var source_dir := ""
	G.SAVE_PATH = "res://tools/_logs/save_playthrough_%s_%s.json" % [role_id, phase]
	for arg in args:
		if arg.begins_with("--save-dir="): G.SAVE_PATH = arg.trim_prefix("--save-dir=").path_join("save_playthrough_%s_%s.json" % [role_id, phase])
		if arg.begins_with("--source-dir="): source_dir = arg.trim_prefix("--source-dir=")
	await get_tree().process_frame
	get_tree().current_scene = null
	if phase == "b":
		if not G.reload_save() or not _check_final(): return _bad("保底装备重载不符")
		await _run_phase_b()
	elif source_dir.is_empty():
		await _run_phase_a()
	else:
		var source := source_dir.path_join("save_playthrough_%s_a.json" % role_id)
		var raw := FileAccess.get_file_as_string(source)
		var saved: Variant = JSON.parse_string(raw)
		if not (saved is Dictionary) or saved.get("selected_role", "") != role_id or saved.get("prog", {}).get("story", {}).get("done", []).size() != 28:
			return _bad("缺少对应职业28步验收档")
		var file := FileAccess.open(G.SAVE_PATH, FileAccess.WRITE)
		if file == null: return _bad("隔离档不能写入")
		file.store_string(raw)
		file.close()
		if not G.reload_save(): return _bad("旧档不能载入")
		_protected = G.inv_worn_uids().keys()
		if not await _enter_world("", "", "frost_post"): return _bad(_reason)
		if not await _campaign_gear_checkpoint("old"): return
		if not _check_final(): return _bad("旧档七件保底未齐")
		print("PLAY_EVENT gear_old_source sha256=%s protected=%s" % [FileAccess.get_sha256(source), str(_protected)])
		print("PLAY_A_STATE " + JSON.stringify(_state()))
		print("PLAY_A_OK role=%s level=%d" % [role_id, int(G.prog.level)])
		get_tree().quit(0)

func _prep_new_save() -> void:
	super._prep_new_save()
	_protected = G.inv_worn_uids().keys()

func _check_final() -> bool:
	var gear := _gear_records()
	if gear.size() != 7 or not CampaignGear.claim_plan(G.prog, role_id).is_empty(): return false
	for step in ["s25", "s27", "s28"]:
		var wanted := CampaignGear.reward(step, role_id)
		var tpl := G.equip_tpl(String(wanted.tpl))
		if String(G.equip_state(String(tpl.slot)).get("tpl", "")) != wanted.tpl: return false
	return true

func _gear_records() -> Array:
	var result: Array = []
	for item in G.inv_instances()+G.inv_pending():
		if String(item.get("source_id", "")).begins_with("campaign_gear|"): result.append(item.duplicate(true))
	result.sort_custom(func(a, b): return int(a.uid) < int(b.uid))
	return result

func _state() -> Dictionary:
	var result := super._state()
	# Godot JSON decodes numbers as floats; canonicalize both process snapshots.
	result["gear"] = JSON.parse_string(JSON.stringify(_gear_records()))
	result["worn"] = JSON.parse_string(JSON.stringify(G._equip_map()))
	return result

func _button(root: Node, text: String) -> Control:
	var label := _find_label(root, [text.replace(" ", "")])
	return label.get_parent() as Control if label != null else null

func _uid_control(root: Node, uid: int) -> Control:
	for child in root.get_children():
		if child is Control and int(child.get_meta("gear_uid", 0)) == uid: return child
		var found := _uid_control(child, uid)
		if found != null: return found
	return null

func _tab(bag: BagPanel, id: String, text: String) -> bool:
	if not await _click_until(_button(bag._tabs, text), func(): return bag._tab == id, 30, "bag_tab_"+id): return false
	await _wait_frames(4)
	return true

func _page_to(bag: BagPanel, uid: int) -> Control:
	for page in 20:
		var found := _uid_control(bag._list, uid)
		if found != null: return found
		var arrow := _button(bag._list, "▶")
		if arrow == null: return null
		var previous := bag._page
		if not await _click_until(arrow, func(): return bag._page != previous, 10, "bag_next_page"): return null
		await _wait_frames(4)
	return null

func _free_slot(bag: BagPanel) -> bool:
	if G.inv_count() < G.inv_capacity(): return true
	if not await _tab(bag, "equip", "装备"): return false
	var sell_uid := 0
	for item in bag._bag_items():
		if int(item.get("rarity", 1)) == 1 and int(item.get("lv", 0)) == 0 and not item.get("locked", false) and not _protected.has(int(item.uid)) and String(item.get("source_id", "")).is_empty():
			sell_uid = int(item.uid)
			break
	if sell_uid == 0: return _bad("无可卖普通占格测试装备")
	var row := await _page_to(bag, sell_uid)
	if row == null or not await _click_until(row, func(): return bag._sel_uid == sell_uid, 30, "select_sale"): return _bad("选中卖出失败")
	await _wait_frames(4)
	var sell := _button(bag._detail, "卖出 %d 金" % G.inv_sell_price(sell_uid))
	var gold := int(G.wallet.gold)
	if not await _click_until(sell, func(): return G.inv_find(sell_uid).is_empty(), 30, "sell_plain_fixture"): return _bad("实际卖出失败")
	await _wait_frames(4)
	print("PLAY_EVENT gear_fixture_sale uid=%d gold=%d" % [sell_uid, int(G.wallet.gold)-gold])
	return true

func _labels(root: Node) -> Array:
	var result: Array = []
	for child in root.get_children():
		if child is Label: result.append(child)
		result.append_array(_labels(child))
	return result

func _pending_has(uid: int) -> bool:
	for item in G.inv_pending():
		if int(item.uid) == uid: return true
	return false

func _campaign_gear_checkpoint(chapter: String) -> bool:
	var map_id := String(_map._main_map_id)
	var previous := _map.get_instance_id()
	if not await _click_until(_button(_map._hud, "营帐"), func(): return _map._exit_ui != null, 30, "camp"): return _bad("营帐入口失败")
	await _wait_frames(4)
	if not await _click_until(_button(_map._exit_ui, "撤 离"), func(): return G.transit_busy(), 30, "leave_to_camp"): return _bad("撤离失败")
	await _wait_idle()
	await _wait_frames(8)
	var home := get_tree().current_scene as Control
	if home == null or not home.has_method("_open_bag"): return _bad("未进入营帐")
	if not await _click_until(_button(home, "背包"), func(): return home._bag != null, 30, "open_bag"): return _bad("背包入口失败")
	await _wait_frames(6)
	var bag := home._bag as BagPanel
	if chapter == "old" and G.inv_pending().size() > 8:
		if not await _tab(bag, "pending", "待领取"): return _bad("旧待领分页入口失败")
		if not await _click_until(_button(bag._list, "▶"), func(): return bag._page == 1, 30, "pending_second_page"): return _bad("待领第二页失败")
		await _wait_frames(4)
		print("PLAY_EVENT pending_second_page count=%d" % G.inv_pending().size())
		if not await _click_until(_button(bag._list, "◀"), func(): return bag._page == 0, 30, "pending_first_page"): return _bad("待领首页失败")
		await _wait_frames(4)
	for row in CampaignGear.config().get("rewards", []):
		var step := String(row.step)
		if not G.prog.story.done.has(step): continue
		if chapter == "act2" and step in ["s10", "s12"]: continue
		if chapter == "act3" and step in ["s10", "s12", "s19", "s20"]: continue
		var expected := CampaignGear.reward(step, role_id)
		var uid := 0
		for item in _gear_records():
			if String(item.source_id) == expected.transaction_id: uid = int(item.uid)
		if uid == 0: return _bad("缺少保底实例 "+step)
		if _pending_has(uid):
			if not await _free_slot(bag) or not await _tab(bag, "pending", "待领取"): return _bad("无法准备待领取")
			var claim := await _page_to(bag, uid)
			if claim == null or not await _click_until(claim, func(): return not _pending_has(uid), 30, "claim_"+step): return _bad("实际领取失败 "+step)
			await _wait_frames(4)
		if not await _tab(bag, "equip", "装备"): return _bad("装备页失败")
		var select := await _page_to(bag, uid)
		if select == null or not await _click_until(select, func(): return bag._sel_uid == uid, 30, "select_"+step): return _bad("选中保底失败 "+step)
		await _wait_frames(4)
		var slot := String(G.equip_tpl(String(expected.tpl)).slot)
		if not await _click_until(_button(bag._detail, "装 备"), func(): return int(G._equip_map().get(slot, 0)) == uid, 30, "wear_"+step): return _bad("实际装备失败 "+step)
		await _wait_frames(4)
		print("PLAY_EVENT gear_worn chapter=%s step=%s uid=%d tpl=%s level=%d" % [chapter, step, uid, expected.tpl, int(G.prog.level)])
	if not await _click_until(bag._close_btn, func(): return home._bag == null, 30, "close_bag"): return _bad("关闭背包失败")
	await _wait_frames(4)
	var back := home.find_child("ReturnToWorld", true, false) as Control
	if not await _click_until(back, func(): return G.transit_busy(), 30, "return_world"): return _bad("返世界失败")
	_map = await _wait_new_map(previous, map_id)
	if _map == null: return _bad("返世界地图不符")
	return true
