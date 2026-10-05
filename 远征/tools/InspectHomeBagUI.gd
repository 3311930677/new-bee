extends Node
const OUT := "res://shots/bag_ui_20261005/"
var version := "mcp"
var home: Control
var bag: BagPanel
var report: Dictionary = {}

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/bag_ui_review/demo_save.json"
	G._init_state_defaults()
	G.save_locked = false
	G.set_meta("ui_review_mode",true)
	G.player_name = "沈舟"
	G.selected_role = "zs"
	G.prog.level = 12
	G.wallet = {"gold":101376,"expedition":1011,"soul":259,"honor":580}
	G.ensure_starter_equip(true)
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":8},false)
	G.inv_grant_equip({"tpl":"tpl_armor_scale","rarity":2,"n":2},false)
	G.inv_grant_equip({"tpl":"tpl_accessory_moon","rarity":3,"n":2},false)
	G.items = {"enhance_stone":24,"refine_stone":9,"lock_rune":3,"pet_food":16,
		"stele_fragment":12,"gate_clue":1,"frost_letter":1,"mine_record":1,"fish_salt":3,
		"gem_atk_1":9,"gem_atk_2":3,"gem_atk_3":1,"gem_def_1":6,"gem_def_2":3,
		"gem_def_3":1,"gem_hp_1":9,"gem_hp_2":3,"gem_hp_3":1}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version="): version = arg.trim_prefix("--version=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	home = preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	for i in 6: await get_tree().process_frame
	report["home"] = _inspect(home)
	if "--capture-all" in OS.get_cmdline_user_args():
		await _capture("home_800")
		get_window().size = Vector2i(480,1067)
		for i in 8: await get_tree().process_frame
		report["home_resized_1067"] = _inspect(home)
		await _capture("home_resized_1067")
		get_window().size = Vector2i(480,800)
		for i in 8: await get_tree().process_frame
	home._open_bag()
	bag = home._bag
	if not bag._bag_items().is_empty():
		bag._sel_uid = int(bag._bag_items()[0].uid)
	bag._refresh()
	for i in 6: await get_tree().process_frame
	report["bag"] = _inspect(bag)
	_save_report()
	if "--capture-all" in OS.get_cmdline_user_args():
		for height in [800,1067]:
			get_window().size = Vector2i(480,height)
			for tab in ["equip","mat","gem","pending"]:
				bag._tab = tab
				bag._page = 0
				bag._refresh()
				for i in 8: await get_tree().process_frame
				report["bag_%s_%d" % [tab,height]] = _inspect(bag)
				await _capture("%s_%d" % [tab,height])
			# Both capacity states, using public inventory operations in this isolated fixture.
			var saved_prog := G.prog.duplicate(true)
			var saved_wallet := G.wallet.duplicate(true)
			G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":G.inv_capacity()+2},false)
			bag._tab = "pending"
			bag._page = 0
			bag._refresh()
			for i in 8: await get_tree().process_frame
			await _capture("pending_full_%d" % height)
			var free_uid := int(bag._bag_items()[0].uid)
			G.inv_sell(free_uid,true)
			bag._refresh()
			for i in 8: await get_tree().process_frame
			await _capture("pending_ready_%d" % height)
			G.prog = saved_prog
			G.wallet = saved_wallet
		_save_report()
		print("HOME_BAG_UI_CAPTURE_OK "+version)
		home.queue_free()
		for i in 3: await get_tree().process_frame
		get_tree().quit()

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT+version+"_"+name+".png")==OK)

func _inspect(root: Node) -> Dictionary:
	var nodes: Array = []
	_walk(root,root,nodes)
	var result := {"controls":nodes,"control_count":nodes.size(),"containers":0,"explicit_themes":0,"focusable":0,"small_targets":[]}
	for row in nodes:
		if row.container: result.containers += 1
		if row.theme_attached: result.explicit_themes += 1
		if row.focus_mode != 0: result.focusable += 1
		if row.action and (row.rect[2] < 44 or row.rect[3] < 44): result.small_targets.append(row.path)
	return result

func _walk(node: Node,root: Node,rows: Array) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		var overrides := 0
		for property in node.get_property_list():
			if String(property.name).begins_with("theme_override") and node.get(property.name)!=null: overrides += 1
		rows.append({"path":str(root.get_path_to(node)),"type":node.get_class(),
			"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],
			"anchors":[node.anchor_left,node.anchor_top,node.anchor_right,node.anchor_bottom],
			"container":node is Container,"theme":node.theme.resource_path if node.theme != null else "",
			"theme_attached":node.theme!=null,"overrides":overrides,"focus_mode":node.focus_mode,
			"action":node is BaseButton or node.has_signal("activated") or node.has_meta("gear_uid"),
			"text":node.text if node is Label or node is Button else ""})
	for child in node.get_children(): _walk(child,root,rows)

func _save_report() -> void:
	var file := FileAccess.open(OUT+"runtime_"+version+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
