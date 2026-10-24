extends SceneTree
## This script runs outside the game against resources reassembled from the APK.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game: Node = root.get_node("G")
	game.set("SAVE_PATH","user://package_reinspection.json")
	game.set("save_locked",true)
	game.call("_init_state_defaults")
	game.set("selected_role","zs")
	game.set("player_name","安装包复核")
	print("INSTALLED_GM_VISIBLE ",root.get_node("GmConsole").get("_bar_layer") != null)
	print("INSTALLED_AUDIO_EFFECTS ",root.get_node("Audio").get("SFX_NAMES").size())
	var items: Dictionary = game.get("items")
	for stat in ["atk","def","hp"]:
		for tier in range(1,6): items["gem_%s_%d" % [stat,tier]] = 9
	var bag: Control = load("res://src/ui/BagPanel.gd").new()
	root.add_child(bag)
	bag.call("_select_tab","gem")
	for i in 8: await process_frame
	var present := 0
	for cell in bag.get("_item_buttons"):
		if cell.get("item_image").texture != null: present += 1
	print("INSTALLED_BAG_GEM_TEXTURES ",present,"/",bag.get("_item_buttons").size())
	print("INSTALLED_VIEWPORT ",root.get_visible_rect()," WINDOW ",root.size," TRANSFORM ",root.get_screen_transform())
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/new-bee/reports/mobile_rework_20261024/installed_bag.png")
	bag.queue_free()
	for i in 3: await process_frame
	quit()
