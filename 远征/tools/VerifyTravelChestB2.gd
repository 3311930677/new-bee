extends Node
const OUT := "res://shots/travel_chest_b2_20261009/"
const Page := preload("res://src/ui/ChestPageUI.gd")
var page: Control
var capture := false
var checks := 0
var failures := 0
func check(ok: bool, words: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("B2_FAIL: "+words)
func frames() -> void:
	for i in 5:await get_tree().process_frame
func click(control: Control) -> void:
	check(control!=null,"真实点击目标存在")
	if control==null:return
	var ancestor:=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await frames()
	var point:=control.get_global_rect().get_center()
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new()
		e.position=point
		e.global_position=point
		e.pressed=pressed
		e.button_index=MOUSE_BUTTON_LEFT
		get_viewport().push_input(e,true)
		await get_tree().process_frame
	await frames()
func shot(words: String) -> void:
	await frames()
	if not capture:return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+words+".png")==OK,"运行截图保存 "+words)
	preload("res://tools/UITextAudit.gd").write(page,OUT+words+".text.json")
func drop() -> void:
	page.queue_free()
	await frames()
func button(root: Node, key: String, value: Variant) -> Button:
	for child in root.get_children():
		if child is Button and child.has_meta(key) and child.get_meta(key)==value:return child
		var found:=button(child,key,value)
		if found!=null:return found
	return null
func words(root: Node,text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text==text:return child
		var found:=words(child,text)
		if found!=null:return found
	return null
func geometry(controls: Array,safe: Rect2) -> void:
	for c in controls:
		check(c.size.x>=44 and c.size.y>=44,"44px触控热区 "+str(c.name))
		check(safe.grow(1).encloses(c.get_global_rect()),"安全区容纳 "+str(c.name))
func fixture() -> void:
	G._init_state_defaults()
	G.save_locked=false
	G.selected_role="zs"
	G.prog.level=12
	G.prog.tips_seen={"pet_raise":true}
	G.player_name="行旅人"
	G.wallet.gold=12800
	G.ensure_starter_equip(true)
	G.items={"enhance_stone":12,"refine_stone":6,"lock_rune":3,"gem_atk_1":6,"gem_hp_1":2,"gem_def_1":2}
	G.equip_state("sword").affixes=[{"stat":"atk_pct","v":.05,"locked":false}]
	G.inv_grant_equip({"tpl":"tpl_accessory_moon","rarity":3,"n":1},false)
	G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":2,"n":19},false)
	G.collect_pet("pet_rockturtle")
func _ready() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	G.SAVE_PATH=OUT+"isolated_save.json"
	G.set_meta("ui_review_mode",true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for height in [800,1067]:
		get_window().size=Vector2i(480,height)
		await frames()
		fixture()
		page=preload("res://src/ui/GrowthPanel.gd").new()
		add_child(page)
		await frames()
		check(page._rows.size()==6,"六条养成入口完整")
		for row in page._rows:
			check(row.action.image.texture!=null,"养成图标 "+row.id)
		await shot("growth_%d"%height)
		if height==800:
			G.prog.level=1
			G.wallet.gold=0
			G.items={}
			page._refresh()
			await shot("growth_no_action_800")
			fixture()
			page._refresh()
		var safe:=Rect2(8,44,464,height-78)
		page._layout(safe)
		geometry([page._back],safe)
		check(safe.encloses(page._row_scroll.get_global_rect()),"状态行滚动区适配安全区")
		await shot("growth_safe_%d"%height)
		await drop()
		page=preload("res://src/ui/EquipPanel.gd").new()
		add_child(page)
		await frames()
		var view:Control=page._view
		var gold:=int(G.wallet.gold)
		var stone:=G.item_count("enhance_stone")
		var cost:=G.equip_enhance_cost("sword")
		await shot("equipment_%d"%height)
		await click(button(view,"work_action","enhance"))
		check(int(G.equip_state("sword").lv)==1,"真实点击强化确定成功")
		check(int(G.wallet.gold)==gold-int(cost.gold) and G.item_count("enhance_stone")==stone-int(cost.item_n),"强化实际扣费与预览同源")
		page._on_enhance()
		check(int(G.equip_state("sword").lv)==1,"操作期间防止重复强化")
		await shot("equipment_success_%d"%height)
		await get_tree().create_timer(.45).timeout
		await frames()
		await click(button(view,"work_tab","gem"))
		var gem_n:=G.item_count("gem_atk_1")
		await click(button(view,"gem_id","gem_atk_1"))
		check(G.equip_state("sword").gems.size()==1 and G.item_count("gem_atk_1")==gem_n-1,"真实镶嵌保留消耗")
		await shot("gems_%d"%height)
		await click(button(view,"socket_index",0))
		check(G.equip_state("sword").gems.is_empty() and G.item_count("gem_atk_1")==gem_n,"拆除返回宝石")
		await click(words(view,"合成"))
		gold=int(G.wallet.gold)
		await click(button(view,"gem_id","gem_atk_1"))
		check(G.item_count("gem_atk_2")==1 and G.item_count("gem_atk_1")==gem_n-page._gem_merge_need(),"合成入口保留三合一")
		check(int(G.wallet.gold)==gold-page._gem_merge_cost(),"合成费用准确")
		await get_tree().create_timer(.45).timeout
		await click(button(view,"work_tab","refine"))
		await click(button(view,"affix_index",0))
		check(G.equip_state("sword").affixes[0].locked,"精炼锁条真实可点")
		await shot("refine_%d"%height)
		view.layout(safe)
		geometry([view._back,view._bag,button(view,"work_action","refine")],safe)
		for cell in view._slots.get_children():
			if cell is Button:geometry([cell],safe)
		await shot("equipment_safe_%d"%height)
		view.layout()
		G.wallet.gold=0
		page._work_tab="enhance"
		page._refresh()
		check(button(view,"work_action","enhance").disabled,"资源不足时禁用确认强化")
		await shot("equipment_shortage_%d"%height)
		await click(view._bag)
		check(page._bag!=null,"装备直达背包")
		await click(page._bag._close_btn)
		check(page._bag==null,"背包返回装备页")
		if height==800:
			G.wallet.gold=12800
			G.items.enhance_stone=20
			G.equip_state("sword").lv=10
			G.equip_state("sword").enhance_failures=0
			var rng:=RandomNumberGenerator.new()
			var chosen:=1
			rng.seed=chosen
			while rng.randf()<G.equip_enhance_rate("sword"):
				chosen+=1
				rng.seed=chosen
			rng.seed=chosen
			var failed:=G.equip_enhance("sword",rng)
			check(failed.ok and not failed.success and int(G.equip_state("sword").lv)==10,"实际失败不掉级")
			page._present_enhance(failed)
			await shot("equipment_failure_800")
		await drop()
		page=preload("res://src/ui/BagPanel.gd").new()
		add_child(page)
		await frames()
		await click(page._item_buttons[0])
		check(page._scroll.get_child(0).columns==5,"五列网格")
		await shot("bag_%d"%height)
		if height==800:
			G.inv_set_locked(page._sel_uid,true)
			page._refresh()
			await shot("bag_locked_800")
			G.prog.level=0
			page._refresh()
			check(button(page,"action","wear").disabled,"等级不足禁用装备")
			await shot("bag_level_locked_800")
			G.prog.level=12
			page._refresh()
		page._resize_frame(safe)
		geometry([page._close_btn],safe)
		for b in page._action_buttons:geometry([b],safe)
		check(page._scroll.get_global_rect().encloses(Rect2(page._item_buttons[4].global_position,page._item_buttons[4].size)),"第五列适配横向安全区")
		await shot("bag_safe_%d"%height)
		page._resize_frame()
		await click(page._tab_buttons.gem)
		await shot("bag_gems_%d"%height)
		if height==800:
			G.items={}
			page._refresh()
			await shot("bag_empty_gems_800")
			G.inv_grant_equip({"tpl":"tpl_sword_wolf","rarity":1,"n":G.inv_capacity()},false)
			await click(page._tab_buttons.pending)
			await shot("bag_full_pending_800")
		await drop()
		fixture()
		G.items.pet_food=2
		G.items.break_crystal=10
		G.items.aptitude_fruit=2
		G.wallet.soul=1000
		for pair in [["talent","TalentPanel"],["pet","PetRaisePanel"],["mount","MountPanel"],["titles","TitlePanel"]]:
			page=load("res://src/ui/"+pair[1]+".gd").new()
			add_child(page)
			await frames()
			var child:Control=page._chest
			await shot("%s_%d"%[pair[0],height])
			if height==800:
				if pair[0]=="talent":
					var left:=G.talent_points_left()
					await click(child._main)
					check(G.talent_points_left()==left-1,"天赋子页真实分配")
				elif pair[0]=="pet":
					var food:=G.item_count("pet_food")
					await click(child._main)
					check(G.item_count("pet_food")==food-1,"灵宠子页真实喂养")
				elif pair[0]=="mount":
					var tier:=G.mount_tier(child.selection)
					await click(child._main)
					check(G.mount_tier(child.selection)==tier+1,"坐骑子页真实购买")
				elif pair[0]=="titles":
					await click(child._main)
					check(G.title_owned(child.selection),"称号子页真实领取")
			child.layout(safe)
			geometry([child._back,child._main],safe)
			await shot("%s_safe_%d"%[pair[0],height])
			await drop()
		fixture()
		var run:=RunState.new()
		run.setup({"theme":"forest","role_id":"zs","level":12,"active_pet":"pet_rockturtle","potions":2,"seed":18})
		MapScene.pending_cfg={"mode":"main_world","main_map_id":"lorin_wilds","run":run,"node":{"type":"normal","layer":0,"index":0}}
		page=preload("res://src/explore/MapScene.tscn").instantiate()
		add_child(page)
		await frames()
		page._player.position=Vector2(480,930)
		await shot("town_%d"%height)
		G.prog.mounts={"owned":{"horse":1},"active":"horse","riding":false}
		page._sync_mount_visual()
		await shot("mount_unlocked_%d"%height)
		await click(page._mount_btn)
		check(G.mount_riding(),"骑乘真实开启")
		await shot("riding_on_%d"%height)
		await click(page._mount_btn)
		check(not G.mount_riding(),"骑乘真实关闭")
		check(page._round_fold.get_parent() in page._round_tasks,"折叠入口并入任务签")
		await click(page._round_fold)
		check(page._round_expanded,"任务折叠按钮实际展开")
		await shot("tasks_expanded_%d"%height)
		await click(page._round_fold)
		check(page._round_collapsed and page._round_fold.is_visible_in_tree(),"收起后入口仍可触达")
		await click(page._sprint_btn)
		check(page._sprint and page._sprint_btn.get_node("Caption").text=="疾行中","疾行状态文字与图形变化")
		await shot("sprint_on_%d"%height)
		page._layout_round1_hud(safe)
		geometry([page._round_fold,page._sprint_btn,page._round_potion,page._pet_btn],safe)
		await shot("town_safe_%d"%height)
		await drop()
	fixture()
	var field_run:=RunState.new()
	field_run.setup({"theme":"tomb","role_id":"zs","level":12,"active_pet":"pet_rockturtle","potions":2,"seed":18})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":"stele_cavern","run":field_run,"node":{"type":"normal","layer":0,"index":0}}
	page=preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(page)
	await frames()
	await shot("field_dark_1067")
	await drop()
	# Deliberate label overlap verifies priority independently of map spawn positions.
	var high:=Label.new()
	var low:=Label.new()
	high.size=Vector2(100,24)
	low.size=Vector2(100,24)
	add_child(high)
	add_child(low)
	preload("res://src/ui/NameTagLayout.gd").resolve([{"label":low,"priority":6},{"label":high,"priority":0}],[])
	check(high.self_modulate.a==1 and low.self_modulate.a<.2,"名称避让保留主角优先级")
	high.queue_free()
	low.queue_free()
	print("B2_%s checks=%d failures=%d"%["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
