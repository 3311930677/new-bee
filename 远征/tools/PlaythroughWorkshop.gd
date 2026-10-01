## Actual viewport input, using isolated copies of four completed campaign saves.
extends "res://tools/PlaythroughMainWorld.gd"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role_id = String(args[0]) if args.size() > 0 else "zs"
	phase = String(args[1]) if args.size() > 1 else "a"
	var source_dir := ""
	G.SAVE_PATH = "res://tools/_logs/workshop_input/save_%s.json" % role_id
	for arg in args:
		if arg.begins_with("--source-dir="): source_dir = arg.trim_prefix("--source-dir=")
	DirAccess.make_dir_recursive_absolute(G.SAVE_PATH.get_base_dir())
	await get_tree().process_frame
	get_tree().current_scene = null
	var source := source_dir.path_join("save_playthrough_%s_a.json" % role_id)
	var raw := FileAccess.get_file_as_string(source)
	var original: Variant = JSON.parse_string(raw)
	if not original is Dictionary: return _bad("缺少已验收源档")
	if phase == "a":
		var file := FileAccess.open(G.SAVE_PATH,FileAccess.WRITE)
		if file == null: return _bad("无法复制隔离档")
		file.store_string(raw)
		file.close()
	if not G.reload_save() or G.save_locked: return _bad("工坊档不能载入")
	var slot := G.equip_weapon_slot()
	if phase == "a":
		if int(G.equip_state(slot).lv) != 0: return _bad("源武器不是未强化基线")
		var panel := EquipPanel.new()
		add_child(panel)
		await _wait_frames(6)
		for target in range(1,4):
			var action := _enhance_button(panel)
			if not await _click_until(action,func(): return int(G.equip_state(slot).lv) == target,20,"workshop_%d"%target): return _bad("实际强化按钮没有效果")
			await _wait_frames(6)
		panel.queue_free()
		await _wait_frames(3)
	var expected_inventory: Dictionary = original.prog.inventory.duplicate(true)
	var uid := int(original.prog.equip[slot])
	for inst in expected_inventory.instances:
		if int(inst.uid) == uid:
			inst.lv = 3
			inst["enhance_failures"] = 0
	var expected_wallet: Dictionary = original.wallet.duplicate(true)
	expected_wallet.gold = int(expected_wallet.gold)-900
	var expected_items: Dictionary = original.items.duplicate(true)
	expected_items.enhance_stone = int(expected_items.enhance_stone)-3
	if JSON.parse_string(JSON.stringify([G.prog.inventory,G.wallet,G.items,G.prog.equip])) != JSON.parse_string(JSON.stringify([expected_inventory,expected_wallet,expected_items,original.prog.equip])):
		return _bad("三次真实强化或重启资源不符")
	print("WORKSHOP_INPUT_STATE " + JSON.stringify({"role":role_id,"inventory":G.prog.inventory,"worn":G.prog.equip,"wallet":G.wallet,"items":G.items}))
	print("WORKSHOP_%s_OK role=%s source_sha256=%s" % [phase.to_upper(),role_id,FileAccess.get_sha256(source)])
	get_tree().quit(0)

func _enhance_button(root: Node) -> Control:
	for child in root.get_children():
		if child is Control and child.get_meta("work_action", "") == "enhance": return child
		var found := _enhance_button(child)
		if found != null: return found
	return null
