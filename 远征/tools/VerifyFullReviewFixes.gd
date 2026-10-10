extends Node
const OUT:="res://shots/full_review_fixes_20261009/"
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
var page:Control
var checks:=0
var failures:=0
var capture:=false
func check(ok:bool,msg:String) -> void:checks+=1;if not ok:failures+=1;push_error("FULL_FIX_FAIL "+msg)
func frames() -> void:for i in 5:await get_tree().process_frame
func shot(name:String) -> void:
	await frames()
	if page is BattleScene:page._sync_views();page._refresh_hud()
	if not capture:return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(OUT+name+".png")==OK,"截图 "+name)
	preload("res://tools/UITextAudit.gd").write(page,OUT+name+".text.json")
func click(node:Control) -> void:
	check(node!=null,"点击目标存在");if node==null:return
	var ancestor:=node.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(node)
		ancestor=ancestor.get_parent()
	await frames()
	var point:=node.get_global_rect().get_center()
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		get_viewport().push_input(e,true);await get_tree().process_frame
	await frames()
func button(root:Node,key:String,value:Variant) -> Button:
	for child in root.get_children():
		if child is Button and child.has_meta(key) and child.get_meta(key)==value:return child
		var b:=button(child,key,value);if b!=null:return b
	return null
func text_all(root:Node) -> String:
	var words:=""
	for child in root.get_children():
		if child is Label:words+=child.text+" "
		words+=text_all(child)
	return words
func check_cost_visible(root:Node,scroll:ScrollContainer) -> void:
	for node in root.get_children():
		if node.has_meta("cost_need"):check(scroll.get_global_rect().grow(1).encloses(node.get_global_rect()),"投入数量与持有量默认完整可见")
		check_cost_visible(node,scroll)
func drop() -> void:page.queue_free();await frames()
func fixture() -> void:
	G._init_state_defaults();G.save_locked=false;G.selected_role="zs";G.player_name="行旅人";G.prog.level=12
	G.prog.tips_seen={"pet_raise":true,"deploy":true};G.prog.worlds_unlocked=3
	G.wallet={"gold":12800,"expedition":500,"soul":100,"honor":900}
	G.items={"enhance_stone":12,"refine_stone":6,"lock_rune":3,"evolve_crystal":6,"gem_atk_1":3,"gem_hp_1":2}
	G.ensure_starter_equip(true);G.equip_state("sword").lv=3;G.equip_state("armor").lv=2;G.equip_state("accessory").lv=1
	G.collect_pet("pet_rockturtle");G.collect_pet("pet_thunderhawk")
func _ready() -> void:
	capture="--capture" in OS.get_cmdline_user_args();G.SAVE_PATH=OUT+"isolated_review_save.json";G.set_meta("ui_review_mode",true)
	for cfg in G.equip_cfg().templates:check(Fix.item(String(cfg.id))!=null,"物品资源 "+String(cfg.id))
	for cfg in TableCache.pets():check(Fix.pet(String(cfg.id)).get_size()==Vector2(64,64),"展示精灵64像素 "+String(cfg.id))
	for height in [800,1067]:
		get_window().size=Vector2i(480,height);await frames();fixture()
		var safe:=Rect2(8,44,464,height-78)
		page=GrowthPanel.new();add_child(page);await shot("growth_%d"%height)
		check(page._stats.get_child_count()==6,"五项真实属性")
		check(page._next_id=="talent" and not page._recommend.disabled,"天赋优先推荐可操作")
		await click(page._recommend);check(page._sub!=null,"推荐行真实进入子页")
		page._sub.closed.emit();await frames()
		page._layout(safe);await shot("growth_safe_%d"%height)
		G.prog.level=1;G.wallet.gold=0;G.items={};page._refresh();await shot("growth_no_action_%d"%height)
		check(page._recommend.disabled,"无可行动推荐退为摘要")
		await drop();fixture()
		page=EquipPanel.new();add_child(page);await shot("equipment_%d"%height)
		check(not text_all(page).contains("需要 / 持有"),"投入芯片不用分母说明")
		var cost:=G.equip_enhance_cost("sword");var gold:=int(G.wallet.gold)
		await click(button(page,"work_action","enhance"));check(int(G.wallet.gold)==gold-int(cost.gold),"强化扣费保留")
		await shot("equipment_result_%d"%height)
		await get_tree().create_timer(.45).timeout
		G.items.enhance_stone=0;page._refresh();check(button(page,"work_action","enhance").disabled,"材料不足禁用")
		await shot("equipment_shortage_%d"%height)
		await click(button(page,"work_tab","gem"));await shot("equipment_gems_%d"%height)
		page._view.layout(safe);await shot("equipment_safe_%d"%height)
		await drop();fixture()
		for row in G.equip_cfg().templates.slice(6,20):G.inv_grant_equip({"tpl":row.id,"rarity":1+int(row.id.hash()%5+5)%5,"n":1},false)
		page=BagPanel.new();add_child(page);await frames();await click(page._item_buttons[0]);await shot("bag_%d"%height)
		for cell in page._item_buttons:check(not cell.heading.visible,"格内没有重复名字")
		var uid:int=page._sel_uid;await click(button(page,"action","lock"));check(G.inv_find(uid).locked,"锁定保持实际效果")
		await shot("bag_locked_%d"%height)
		page._resize_frame(safe);await shot("bag_safe_%d"%height)
		await click(page._tab_buttons.mat);await shot("bag_material_%d"%height)
		await drop()
		page=CodexPanel.new();add_child(page);await shot("codex_unknown_%d"%height)
		check(not page._chest._go.visible,"未知页没有禁用大主键")
		var owned_i:=0
		for i in page._pets.size():if G.owns_pet(String(page._pets[i].id)):owned_i=i;break
		page._deck.go(owned_i,true);await shot("codex_owned_%d"%height)
		check_cost_visible(page._chest.shell.body,page._chest.shell.scroll)
		var crystal:=G.item_count("evolve_crystal");await click(page._chest._go);check(G.item_count("evolve_crystal")<crystal,"进化消耗同源")
		await shot("codex_evolved_%d"%height);page._chest.layout(safe);await shot("codex_safe_%d"%height);await drop()
		page=SkillBookPanel.new();add_child(page);await shot("skill_study_%d"%height)
		check_cost_visible(page._chest.shell.body,page._chest.shell.scroll)
		check(not text_all(page).contains("需要 / 持有"),"研习消耗使用共享芯片")
		page._chest.layout(safe);await shot("skill_study_safe_%d"%height);await drop()
		page=RegionMapPanel.new();add_child(page);await shot("regions_%d"%height)
		check(page._nodes.size()==18,"全部地点保留")
		check(page._shell.footer.get_child_count()==0,"定位不占通栏行动位")
		page.select("frost_post",false);await shot("regions_deep_%d"%height)
		page.layout(safe);await shot("regions_safe_%d"%height);await drop()
		page=DeployPanel.new();add_child(page);await shot("departure_%d"%height);page._chest.layout(safe);await shot("departure_safe_%d"%height);await drop()
		page=preload("res://src/ui/Login.tscn").instantiate();add_child(page);await shot("login_%d"%height)
		check(page._paper.size.y<=341,"纸签340高且无旧刻度")
		page._chest.layout(safe,300);await shot("login_keyboard_%d"%height);await drop()
		page=preload("res://src/ui/IntroductionPanel.gd").new();add_child(page);await shot("introduction_%d"%height);page._deck.go(2);await shot("introduction_last_%d"%height);await drop()
		BattleScene.pending_cfg={"presentation":"classic_inline","player_name":"行旅人","seed":17,"ally":{"role_id":"zs","level":12,"active_pet":"pet_rockturtle","bench_pet":"pet_thunderhawk","potions":2},"enemy":{"theme":"forest","node_type":"normal","layer":1,"display_level":2}}
		page=preload("res://src/battle/BattleScene.tscn").instantiate();add_child(page);page.set_process(false);await shot("battle_%d"%height)
		await click(page._chest._buttons.attack);await click(page._chest._buttons.attack);await shot("battle_focus_%d"%height)
		var focus:int=page.sim.role_focus_target_uid;var found:=false
		for chip in page._chest._enemy_strip.get_children():if chip.unit.uid==focus and chip.focused:found=true
		check(found,"集火头像条即时同步")
		page.sim.role_unit().energy=30;page._refresh_hud();await click(page._chest._buttons.skill);await shot("battle_energy30_%d"%height)
		for row in page._chest._page_body.get_children():
			var def:Dictionary=page._command_skill_def(page.sim.role_unit(),String(row.get_meta("skill_id")))
			check(row.disabled==(int(def.get("cost",0))>30),"能量门槛状态同源")
		page.sim.role_unit().skills[0].cd_left=96;page._chest.update_page();await shot("battle_cooldown_%d"%height)
		page._close_page();page.sim.role_unit().hp=1;page._refresh_hud();page._chest.layout(safe);await shot("battle_safe_low_%d"%height);await drop()
		page=preload("res://src/ui/LoadScreen.tscn").instantiate();page.auto_advance=false;add_child(page);await shot("loading_%d"%height);await drop()
	print("FULL_FIX_%s checks=%d failures=%d"%["OK" if failures==0 else "FAIL",checks,failures]);get_tree().quit(0 if failures==0 else 1)
