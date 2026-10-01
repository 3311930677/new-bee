## Read a verified old save, enter through the real game path, walk, then reopen in another process.
extends "res://tools/PlaythroughMainWorld.gd"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role_id = String(args[0]) if args.size() > 0 else "zs"
	phase = String(args[1]) if args.size() > 1 else "a"
	var source_dir := ""
	G.SAVE_PATH = "res://tools/_logs/save_playthrough_%s_%s.json" % [role_id,phase]
	for arg in args:
		if arg.begins_with("--save-dir="): G.SAVE_PATH = arg.trim_prefix("--save-dir=").path_join("save_playthrough_%s_%s.json" % [role_id,phase])
		if arg.begins_with("--source-dir="): source_dir = arg.trim_prefix("--source-dir=")
	await get_tree().process_frame
	get_tree().current_scene = null
	if phase == "b":
		if not G.reload_save() or not await _enter_world("", "", "frost_post"):
			_bad("补领档跨进程不能重开")
			return
		if int(G.prog.level) != 42 or not CampaignGrowth.catchup_plan(G.prog).is_empty() or not G.take_campaign_note().is_empty():
			_bad("补领档重开等级或一次提示异常")
			return
		print("PLAY_B_STATE " + JSON.stringify(_state()))
		print("PLAY_B_OK role=%s level=%d" % [role_id, int(G.prog.level)])
		print("PLAY_OK role=%s" % role_id)
		get_tree().quit(0)
		return
	var source := source_dir.path_join("save_playthrough_%s_a.json" % role_id)
	var raw := FileAccess.get_file_as_string(source)
	var saved: Variant = JSON.parse_string(raw)
	if not (saved is Dictionary) or saved.get("selected_role", "") != role_id or saved.get("prog", {}).get("story", {}).get("done", []).size() != 28 or int(saved.get("prog", {}).get("level", 0)) != 10:
		_bad("缺少对应职业旧版28步Lv10验收档")
		return
	var file := FileAccess.open(G.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_bad("隔离续档不能写入")
		return
	file.store_string(raw)
	file.close()
	if not G.reload_save():
		_bad("旧档不能载入")
		return
	var before := _investments()
	var old_exp := _total_exp()
	if not await _enter_world("", "", "frost_post"): return
	if int(G.prog.level) != 42 or _total_exp() != old_exp+93511 or not _legacy_preserved(before) or not CampaignGrowth.catchup_plan(G.prog).is_empty():
		_bad("实际入口补领或旧投入保存不符")
		return
	var once := G.prog.duplicate(true)
	if int(G.campaign_growth_catchup().exp) != 0 or G.prog != once:
		_bad("重进补领不幂等")
		return
	# MapScene has consumed the one-time note and displays it on the actual HUD.
	if not G.take_campaign_note().is_empty():
		_bad("地图未消费一次提示")
		return
	print("PLAY_EVENT campaign_catchup source_sha256=%s exp=93511 level=42 investments_preserved=true" % FileAccess.get_sha256(source))
	if not await _move_to(Vector2(480, 930), 20): return
	_map._persist_main_world_progress()
	if not G.save_game():
		_bad("补领及实际步行不能落盘")
		return
	print("PLAY_A_STATE " + JSON.stringify(_state()))
	print("PLAY_A_OK role=%s level=%d" % [role_id, int(G.prog.level)])
	get_tree().quit(0)

func _total_exp() -> int:
	var result := int(G.prog.exp)
	for level in range(1, int(G.prog.level)): result += G.exp_to_next(level)
	return result

func _investments() -> Dictionary:
	var result := {"wallet": G.wallet.duplicate(true), "items": G.items.duplicate(true)}
	for field in ["story", "act1", "pets", "pet_stat", "companions", "inventory", "equip", "skills", "talents", "mounts", "titles", "flags", "economy", "mentor"]:
		result[field] = G.prog.get(field, {}).duplicate(true) if G.prog.get(field) is Dictionary or G.prog.get(field) is Array else G.prog.get(field)
	return result

func _legacy_preserved(before: Dictionary) -> bool:
	var after := _investments()
	# Entering the world also grants the independently tested P08-E2 gear migration.
	var inventory: Dictionary = after.inventory
	for pool in ["instances", "pending"]:
		inventory[pool] = inventory.get(pool, []).filter(func(item): return not String(item.get("source_id", "")).begins_with("campaign_gear|"))
	inventory["next_uid"] = before.inventory.get("next_uid", inventory.get("next_uid"))
	for id in ["enhance_stone", "pet_food"]:
		var original := int(before.items.get(id, 0))
		if int(after.items.get(id, 0)) != original+(24 if id == "enhance_stone" else 3): return false
		if before.items.has(id): after.items[id] = before.items[id]
		else: after.items.erase(id)
	return after == before

func _state() -> Dictionary:
	var result := super._state()
	result["exp"] = int(G.prog.exp)
	result["experience_revision_n"] = G.prog.get("campaign_growth", {}).get("story_revision", {}).size()
	result["investments"] = JSON.parse_string(JSON.stringify(_investments()))
	return result
