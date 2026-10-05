extends SubViewport
## Captures actual page tweens at fixed intervals, using a disposable demo save.

var folder := "res://shots/frontend_overhaul_20261004/motion"
var mode := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): folder = arg.trim_prefix("--out=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	DirAccess.make_dir_recursive_absolute(folder)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	G.SAVE_PATH = "res://tools/_logs/save_motion_preview.json"
	G.set_meta("ui_review_mode",false)
	G.selected_role = "fs"
	G.player_name = "东方舟影"
	G.prog["level"] = 12
	G.prog["exp"] = 360
	G.prog["tips_seen"] = {"deploy":true,"pet_raise":true}
	G.wallet = {"gold":12800,"expedition":240,"soul":36,"honor":900}
	G.ensure_starter_pets()
	if mode=="readability":
		await _readability()
		return
	if mode=="finesse":
		await _finesse()
		return
	if mode=="icons":
		await _icons()
		return
	var home := (load("res://src/ui/GameHome.tscn") as PackedScene).instantiate()
	add_child(home)
	await capture("home",30)
	# The public input handler requires a pressed left-button event.
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	home.call("_open_codex",click)
	await get_tree().process_frame
	var codex: Control = home.get("_codex")
	if codex != null:
		await get_tree().create_timer(0.4).timeout
		(codex.get("_deck") as Control).call("next_page")
		await capture("pages",18)
	home.queue_free()
	await get_tree().process_frame
	var run := RunState.new()
	run.setup({"theme":"forest","role_id":"fs","pet_id":"pet_rockturtle"})
	G.prog["main_world"] = {"map_id":"lorin_wilds","layout_version":3,"position":[480,930]}
	MapScene.pending_cfg = {"mode":"main_world","main_map_id":"lorin_wilds","run":run,"node":{"type":"normal","layer":0,"index":0}}
	var world := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(world)
	await get_tree().create_timer(0.2).timeout
	world._city_content.call("_open_dialog",G.city_npc("npc_warden"),false)
	await capture("dialogue",30)
	world.queue_free()
	await get_tree().process_frame
	print("MOTION_PREVIEW_OK")
	get_tree().quit()

func capture(key: String, count: int, on_frame := Callable()) -> void:
	var directory := folder+"/"+key
	DirAccess.make_dir_recursive_absolute(directory)
	for i in count:
		if on_frame.is_valid(): on_frame.call(i)
		await RenderingServer.frame_post_draw
		var error := get_texture().get_image().save_png(directory+"/%03d.png" % i)
		if error != OK:
			push_error("Motion frame could not be saved")
			get_tree().quit(1)
			return
		await get_tree().create_timer(0.05).timeout


func _icons() -> void:
	var home := (load("res://src/ui/GameHome.tscn") as PackedScene).instantiate()
	add_child(home)
	await get_tree().create_timer(.45).timeout
	var gear: Control = null
	for child in home.get_children():
		if child is Control and child.get("skin") == "tool": gear = child
	if gear == null:
		push_error("ICON_PREVIEW_MISSING_GEAR")
		get_tree().quit(1)
		return
	await capture("gear",20,func(i: int):
		if i == 3: gear.mouse_entered.emit()
		if i == 12: gear.mouse_exited.emit())
	print("MOTION_PREVIEW_OK icons")
	get_tree().quit()

func _finesse() -> void:
	G.wallet["soul"] = 2400
	var home := (load("res://src/ui/GameHome.tscn") as PackedScene).instantiate()
	add_child(home)
	await capture("home",24,func(i: int):
		if i==14:
			for c in home.get_children():
				if c is Control and c.has_meta("visual_family") and c.get_meta("visual_family")=="atlas": c.mouse_entered.emit())
	home.call("_open_gacha")
	await get_tree().process_frame
	var panel: GachaPanel = home.get("_gacha")
	await capture("altar",20)
	# 只在隔离预览里让单抽确定出金，录到稀有度专属演出；扣费与结算仍走正式入口。
	var config := panel._cfg().duplicate(true)
	config.pools[0].rates = {"white":0.0,"blue":0.0,"purple":0.0,"gold":1.0}
	panel._cfg_cache = config
	panel._do_single()
	await capture("single",56,func(i: int):
		if i==27: panel._flip_all())
	panel._cfg_cache = {}
	panel._do_ten()
	await capture("ten",70,func(i: int):
		if i==28: panel._flip_all())
	home.queue_free()
	await get_tree().process_frame
	G.items["pet_food"] = 10
	var training := (load("res://src/ui/PetRaisePanel.gd") as GDScript).new() as Control
	add_child(training)
	await get_tree().process_frame
	await capture("training",34,func(i: int):
		if i==7 or i==22: training.call("_on_feed"))
	training.queue_free()
	await get_tree().process_frame
	print("MOTION_PREVIEW_OK finesse")
	get_tree().quit()


func _readability() -> void:
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "沈舟"
	G.prog.level = 12
	G.wallet = {"gold":12800,"expedition":240,"soul":36,"honor":900}
	G.ensure_starter_equip(true)
	var home := preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	await capture("home",24)
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":G.inv_capacity()+1},false)
	for item in G.inv_instances():
		if not G.inv_worn_uids().has(int(item.uid)):
			G.inv_sell(int(item.uid),true)
			break
	home._open_bag()
	await get_tree().process_frame
	var bag: BagPanel = home._bag
	bag._select_tab("pending")
	await capture("ready",24)
	var pending_uid := int(G.inv_pending()[0].uid)
	assert(bool(G.inv_claim(pending_uid).get("ok",false)))
	bag._refresh()
	await capture("claim",50)
	bag._close()
	await get_tree().process_frame
	G.prog.story.done = ["s01","s02",String(G.mentor_cfg().get("unlock_after","s03"))]
	assert(bool(G.mentor_unlock_second().get("ok",false)))
	await capture("unlock",50)
	home.queue_free()
	await get_tree().process_frame
	var loading := preload("res://src/ui/LoadScreen.tscn").instantiate()
	loading.auto_advance = false
	add_child(loading)
	await capture("loading",50)
	loading.queue_free()
	await get_tree().process_frame
	print("MOTION_PREVIEW_OK readability")
	get_tree().quit()
