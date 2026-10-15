extends Node
const OUT := "res://shots/inventory_quest_20261015/"
var failures := 0
var capture := false
var _checks := 0

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	G.SAVE_PATH = OUT + "isolated_save.json"
	G._init_state_defaults()
	G.save_locked = false
	G.set_meta("ui_review_mode",true)
	G.player_name = "沈舟"
	G.selected_role = "zs"
	G.prog.level = 50
	G.wallet.gold = 1000000
	G.ensure_starter_equip(true)
	G.prog.story = {"step":"s08","done":[]}
	G.inv_grant_equip({"tpl":"tpl_accessory_moon","rarity":3,"n":1},false)
	G.inv_grant_equip({"tpl":"tpl_staff_basic","rarity":2,"n":3},false)
	G.inv_grant_equip({"tpl":"tpl_spear_basic","rarity":2,"n":1},false)
	G.items = {"enhance_stone":24,"refine_stone":9,"gem_atk_1":9,"gem_def_1":6,"gem_hp_1":3}
	G.quest = {"day":G.today_key(),"offer":["q_slay_forest","q_slay_abyss"],"active":{},"claimed":[]}
	G.prog.ledger = {}
	G.prog.quest_postings = {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		await _frames()
		var bag := preload("res://src/ui/BagPanel.gd").new()
		add_child(bag)
		await _frames()
		_check(G.ui_safe_rect(bag).grow(1).encloses(bag._panel_root.get_global_rect()),"inventory safe area %d" % height)
		await _shot("inventory_idle_%d" % height)
		bag._select_item(int(bag._bag_items()[0].uid))
		await _frames()
		await _shot("inventory_selected_%d" % height)
		_check(bag._actions.get_global_rect().end.y <= bag._panel_root.get_global_rect().end.y,"inventory actions visible")
		for key in ["mat","gem","pending"]:
			bag._select_tab(key)
			await _frames()
			await _shot("inventory_%s_%d" % [key,height])
		var empty := bag.find_child("PendingEmptyState",true,false) as Control
		_check(empty != null and empty.get_global_rect().get_center().x > 200,"pending empty state is centered")
		bag.queue_free()
		await _frames()
		var journal := preload("res://src/ui/QuestPanel.gd").new()
		add_child(journal)
		await _frames()
		_check(G.ui_safe_rect(journal).grow(1).encloses(journal._panel.get_global_rect()),"journal safe area %d" % height)
		_check(journal._list.get_child_count() == 2,"two commissions rendered")
		_check(journal._back.size.y >= 44 and journal._world_button.size.y >= 44,"journal touch targets")
		await _shot("journal_%d" % height)
		if height == 800:
			var accept := journal._list.get_child(0).find_child("QuestAction",true,false) as Button
			await _click(accept)
			_check(G.quest_active("q_slay_forest"),"commission accepts through real pointer input")
			while not G._modals.is_empty(): G.close_info_popup_by_id(int(G._modals.back().id))
			if is_instance_valid(journal._toast): journal._toast.queue_free()
			await _frames()
			_check((journal._list.get_child(0).find_child("QuestAction",true,false) as Button).disabled,"active commission disables repeat accept")
			await _shot("journal_active_800")
			G.quest_report("slay","forest",3)
			journal._refresh()
			await _frames()
			var btn := journal._list.get_child(0).find_child("QuestAction",true,false) as Button
			_check(not btn.disabled and btn.text == "交付","completed commission offers claim")
			await _shot("journal_claimable_800")
			var before := int(G.wallet.gold)
			await _click(btn)
			await _frames()
			_check(G.quest_claimed("q_slay_forest") and int(G.wallet.gold) == before + 140,"journal claim credits exact reward")
			await _shot("journal_claimed_800")
			G.quest = {"day":G.today_key(),"offer":["q_slay_forest","q_slay_abyss"],"active":{},"claimed":[]}
		journal._resize_frame(Rect2(0,44,480,height-78))
		await _frames()
		_check(Rect2(0,44,480,height-78).grow(1).encloses(journal._panel.get_global_rect()),"journal handles top and bottom safe insets")
		journal.queue_free()
		await _frames()
	var result := {"checks":_checks,"failures":failures,"captured":capture}
	var f := FileAccess.open(OUT + "review.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"))
	f.close()
	print("INVENTORY_QUEST_%s checks=%d failures=%d" % ["OK" if failures == 0 else "FAIL",_checks,failures])
	preload("res://src/ui/InventoryQuestSkin.gd")._textures.clear()
	preload("res://src/ui/InventoryQuestSkin.gd")._theme=null
	preload("res://src/ui/TravelChestUI.gd")._textures.clear()
	preload("res://src/ui/TravelChestUI.gd")._sources.clear()
	preload("res://src/ui/TravelChestUI.gd")._theme=null
	preload("res://src/ui/ChestPageUI.gd")._textures.clear()
	preload("res://src/ui/UiKit.gd")._styles.clear()
	preload("res://src/ui/UIIcons.gd")._cache.clear()
	preload("res://src/ui/ReviewFixUI.gd")._textures.clear()
	G._tex_cache.clear()
	await _frames()
	get_tree().quit(0 if failures == 0 else 1)

func _frames() -> void:
	for i in 8: await get_tree().process_frame

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event,true)
		await get_tree().process_frame
	await _frames()

func _shot(id: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(OUT + id + ".png") == OK,"saved " + id)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition: return
	failures += 1
	push_error("INVENTORY_QUEST: " + message)
