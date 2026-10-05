## Exercise the production bag with viewport mouse/keyboard events and an isolated save.
extends Node
var bag: BagPanel
var failures := 0
var checks := 0

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/bag_ui_review/interaction_save.json"
	G._init_state_defaults()
	G.save_locked = false
	G.set_meta("ui_review_mode",true)
	G.prog.level = 50
	G.wallet.gold = 100000
	G.ensure_starter_equip(true)
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":9},false)
	G.inv_grant_equip({"tpl":"tpl_accessory_moon","rarity":3,"n":1},false)
	G.items = {"enhance_stone":24,"gem_atk_1":3,"gem_atk_2":2,"gem_atk_3":1,
		"gem_atk_4":1,"gem_atk_5":1,"gem_def_1":2,"gem_def_2":1,"gem_def_3":1,
		"gem_def_4":1,"gem_def_5":1,"gem_hp_1":2,"gem_hp_2":1,"gem_hp_3":1,
		"gem_hp_4":1,"gem_hp_5":1}
	var origin := Button.new()
	origin.text = "打开背包"
	add_child(origin)
	origin.grab_focus()
	bag = preload("res://src/ui/BagPanel.gd").new()
	add_child(bag)
	await _frames()
	_check(bag.theme!=null,"inventory inherits a central Theme")
	_check(get_viewport().gui_get_focus_owner()==bag._tab_buttons.equip,"opening selects keyboard focus")
	_layout_check()
	await _click(bag._list.find_child("Pagination",true,false).get_child(2))
	_check(bag._page==1,"next equipment page responds to real input")
	await _click(bag._list.find_child("Pagination",true,false).get_child(1))
	_check(bag._page==0,"previous page responds to real input")
	var rare_uid := int(bag._bag_items()[0].uid)
	await _click(bag._item_buttons[0])
	_check(bag._sel_uid==rare_uid,"equipment card responds to real input")
	await _click(_button("锁定"))
	_check(G.inv_find(rare_uid).locked and _sell_button().disabled,"locking prevents selling")
	await _click(_button("解锁"))
	_check(not G.inv_find(rare_uid).locked and not _sell_button().disabled,"unlock restores selling")
	var gold_before := int(G.wallet.gold)
	var sell_price := G.inv_sell_price(rare_uid)
	await _click(_sell_button())
	_check(not G.inv_find(rare_uid).is_empty() and int(G.wallet.gold)==gold_before,"rare sale requires confirmation")
	await _click(_sell_button())
	_check(G.inv_find(rare_uid).is_empty() and int(G.wallet.gold)==gold_before+sell_price,"confirmed sale credits the correct gold")
	var sword_uid := int(bag._bag_items()[0].uid)
	await _click(bag._item_buttons[0])
	await _click(_button("装备",bag._detail))
	_check(G.inv_worn_uids().has(sword_uid) and not _bag_has(sword_uid),"equip updates worn state and removes the card")
	_check(_sell_button().disabled,"worn equipment cannot be sold")
	await _click(_button("卸下",bag._detail))
	_check(not G.inv_worn_uids().has(sword_uid) and _bag_has(sword_uid),"unequip returns equipment to the bag")
	G.inv_find(sword_uid).gems = ["gem_atk_1"]
	bag._refresh()
	await _frames()
	var gem_before := G.item_count("gem_atk_1")
	var sockets := _buttons_of_kind(bag,"BagSocket")
	await _click(sockets[0])
	_check(G.inv_find(sword_uid).gems.is_empty() and G.item_count("gem_atk_1")==gem_before+1,"clicking an occupied socket returns its gem")
	await _click(bag._tab_buttons.gem)
	_check(bag._tab=="gem" and bag._scroll.get_v_scroll_bar().visible,"long gem list has a visible scrollbar")
	var bottom := int(bag._scroll.get_v_scroll_bar().max_value)
	bag._scroll.scroll_vertical = bottom
	await _frames()
	_check(bag._scroll.scroll_vertical>0,"gem list can scroll to later entries")
	_layout_check()
	await _click(bag._tab_buttons.mat)
	_check(bag._tab=="mat" and _has_icon(bag._scroll),"material view loads its existing artwork")
	# Fill the bag through the public inventory API and exercise disabled/full -> enabled/claim.
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":1,"n":G.inv_capacity()+3},false)
	await _click(bag._tab_buttons.pending)
	_check(not bag._item_buttons.is_empty() and bag._item_buttons[0].disabled,"full bag disables claiming")
	var pending_uid := int(G.inv_pending()[0].uid)
	var disposable_uid := 0
	for item in G.inv_instances():
		if not G.inv_worn_uids().has(int(item.uid)) and int(item.rarity)==1:
			disposable_uid = int(item.uid)
			break
	_check(bool(G.inv_sell(disposable_uid).get("ok",false)),"free a fixture slot through the inventory API")
	bag._refresh()
	await _frames()
	_check(not bag._item_buttons[0].disabled,"claim becomes available after freeing a slot")
	await _click(bag._item_buttons[0])
	_check(not G.inv_find(pending_uid).is_empty() and not _pending_has(pending_uid),"real claim moves equipment into the bag")
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		await _frames()
		for key in ["equip","mat","gem","pending"]:
			await _click(bag._tab_buttons[key])
			_layout_check()
	# Tab advances between actual controls; Escape closes only when the modal guard permits it.
	bag._tab_buttons.equip.grab_focus()
	var tab_key := InputEventKey.new()
	tab_key.keycode = KEY_TAB
	tab_key.pressed = true
	get_viewport().push_input(tab_key,true)
	await _frames()
	_check(get_viewport().gui_get_focus_owner()==bag._tab_buttons.mat,"Tab advances to the next category")
	var closed_count := {"n":0}
	bag.closed.connect(func(): closed_count.n+=1)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	G.ui_blocked = true
	get_viewport().push_input(esc,true)
	await _frames()
	_check(closed_count.n==0,"Escape respects an open modal")
	G.ui_blocked = false
	get_viewport().push_input(esc,true)
	await _frames()
	_check(closed_count.n==1 and get_viewport().gui_get_focus_owner()==origin,"Escape closes and returns focus")
	bag.queue_free()
	origin.queue_free()
	await _frames()
	var home := preload("res://src/ui/GameHome.tscn").instantiate()
	add_child(home)
	await _frames()
	var entry := _home_bag_entry(home)
	_check(entry!=null,"production home has a bag entry")
	if entry!=null:
		entry.grab_focus()
		home._open_bag()
		await _frames()
		_check(home._bag._focus_return==entry,"home preserves the originating focus before hiding its controls")
		home._bag._close()
		await _frames()
		_check(home._bag==null and get_viewport().gui_get_focus_owner()==entry,"closing returns to the production home entry")
	home.queue_free()
	await _frames()
	print("INVENTORY_UI_%s checks=%d failures=%d" % ["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func _frames() -> void:
	for i in 5: await get_tree().process_frame

func _home_bag_entry(root: Node) -> Control:
	for child in root.get_children():
		if child is Label and child.text=="背包": return child.get_parent() as Control
		var found := _home_bag_entry(child)
		if found!=null: return found
	return null

func _check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error("INVENTORY_UI: "+message)

func _click(control: Control) -> void:
	_check(control!=null,"click target exists")
	if control==null: return
	await _frames()
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

func _button(words: String,root: Node = bag) -> Button:
	if root is Button and root.text.replace(" ","")==words: return root
	for child in root.get_children():
		var result := _button(words,child)
		if result!=null: return result
	return null

func _sell_button() -> Button:
	for b in bag._action_buttons:
		if b.text.begins_with("卖出"): return b
	return null

func _buttons_of_kind(root: Node,kind: String) -> Array[Button]:
	var result: Array[Button] = []
	for child in root.get_children():
		if child is Button and child.theme_type_variation==kind: result.append(child)
		result.append_array(_buttons_of_kind(child,kind))
	return result

func _has_icon(root: Node) -> bool:
	for child in root.get_children():
		if child is TextureRect and child.texture!=null: return true
		if _has_icon(child): return true
	return false

func _bag_has(uid: int) -> bool:
	for item in bag._bag_items():
		if int(item.uid)==uid: return true
	return false

func _pending_has(uid: int) -> bool:
	for item in G.inv_pending():
		if int(item.uid)==uid: return true
	return false

func _layout_check() -> void:
	var panel := bag._panel_root.get_global_rect()
	var safe := G.ui_safe_rect(bag)
	_check(safe.grow(1).encloses(panel),"window fits the safe area")
	for b in _all_buttons(bag):
		_check(b.size.x>=44 and b.size.y>=44,"button provides a 44 px touch target")
	var footer := bag._close_btn.get_global_rect()
	_check(panel.encloses(footer),"return button remains inside the panel")

func _all_buttons(root: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in root.get_children():
		if child is Button: result.append(child)
		result.append_array(_all_buttons(child))
	return result
