extends Node
const OUT:="res://shots/next_review_20261009/"
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
const Finesse:=preload("res://src/ui/UIFinesse.gd")
const UI:=preload("res://src/ui/TravelChestUI.gd")
var page:Control
var checks:=0
var failures:=0
var capture:=false
func check(ok:bool,msg:String) -> void:checks+=1;if not ok:failures+=1;push_error("NEXT_REVIEW_FAIL "+msg)
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
	DirAccess.make_dir_recursive_absolute(OUT)
	capture="--capture" in OS.get_cmdline_user_args();G.SAVE_PATH=OUT+"isolated_review_save.json";G.set_meta("ui_review_mode",true)
	for cfg in G.equip_cfg().templates:check(Fix.item(String(cfg.id))!=null and Fix.item(String(cfg.id)).get_meta("pixel_art",false),"真实像素物品资源 "+String(cfg.id))
	for skill in JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json")):check(Fix.skill(String(skill.id)).get_meta("pixel_art",false),"真实像素技能资源 "+String(skill.id))
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
		await get_tree().create_timer(.5).timeout
		G.equip_state("sword").lv=2;G.items.enhance_stone=12;page._refresh();await click(button(page,"work_action","enhance"))
		check(int(G.equip_state("sword").lv)==3,"百分百成功等级真实强化")
		check(not page.get_children().filter(func(n):return n is Finesse.Burst).is_empty(),"成功强化出现短暂结果环")
		await get_tree().create_timer(.45).timeout
		G.items.enhance_stone=0;page._refresh();check(button(page,"work_action","enhance").disabled,"材料不足禁用")
		check(not button(page,"work_action","enhance").subtitle.text.contains("金币"),"金币足够时阻断原因不提金币")
		check(button(page,"work_action","enhance").subtitle.text.contains("差"),"阻断原因给出实际差額")
		await get_tree().create_timer(.8).timeout
		check(page.get_children().filter(func(n):return n is Finesse.Burst).is_empty(),"强化结果动画到期释放")
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
		check(is_equal_approx(page._zoom,.5),"默认全览")
		var visible_nodes:=0
		for id in page._positions:
			if Rect2(Vector2.ZERO,page._map.size).has_point(page._positions[id]*page._zoom+page._graph.position):visible_nodes+=1
		check(visible_nodes>=6,"默认能看到至少六处地点")
		await click(page._zoom_button);check(is_equal_approx(page._zoom,1),"真实点击详图")
		await shot("regions_detail_%d"%height)
		await click(page._zoom_button);check(is_equal_approx(page._zoom,.5),"真实点击返回全览")
		var at:Vector2=page._graph.position
		var anchor:Vector2=page._map.get_global_rect().position+Vector2(30,36)
		var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=anchor;get_viewport().push_input(down,true)
		var motion:=InputEventMouseMotion.new();motion.position=anchor-Vector2(80,60);motion.relative=Vector2(-80,-60);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;get_viewport().push_input(motion,true)
		var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=motion.position;get_viewport().push_input(up,true);await frames()
		check(page._graph.position.distance_to(at)>20,"真实鼠标拖动移动地图")
		page._velocity=Vector2.ZERO
		var touch_start:Vector2=page._graph.position
		var touch:=InputEventScreenTouch.new();touch.index=0;touch.pressed=true;touch.position=anchor;get_viewport().push_input(touch,true)
		var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=anchor-Vector2(30,30);drag.relative=Vector2(-30,-30);get_viewport().push_input(drag,true)
		touch.pressed=false;touch.position=drag.position;get_viewport().push_input(touch,true);await frames()
		check(page._graph.position.distance_to(touch_start)>10,"模拟触摸拖动移动地图")
		page._velocity=Vector2.ZERO
		var dbl:=InputEventMouseButton.new();dbl.button_index=MOUSE_BUTTON_LEFT;dbl.pressed=true;dbl.double_click=true;dbl.position=anchor;get_viewport().push_input(dbl,true);await frames()
		check(is_equal_approx(page._zoom,1),"双击空白切换缩放")
		await click(page._zoom_button)
		page.select("lorin_wilds",false)
		page._show_legend();await shot("regions_legend_%d"%height)
		for child in page.get_children():if child is UI.Modal:child.queue_free()
		await frames()
		check(page._shell.footer.get_child_count()==0,"定位不占通栏行动位")
		page.select("frost_post",false);await shot("regions_deep_%d"%height)
		page.layout(safe);await shot("regions_safe_%d"%height);await drop()
		page=DeployPanel.new();add_child(page);await shot("departure_%d"%height)
		var before_gold:=int(G.wallet.gold)
		await click(button(page,"supply_step",1));check(page._extra_potions==1,"补给加号预选一瓶")
		await click(button(page,"supply_step",-1));check(page._extra_potions==0,"补给减号取消预选")
		check(int(G.wallet.gold)==before_gold,"补给步进不提前扣钱")
		G.wallet.gold=0;page._chest.refresh();await frames()
		check(button(page,"supply_step",1).disabled,"预选合计超过持有金币时加号禁用")
		check(page._sweep_btn.disabled,"零张扫荡券禁用")
		await shot("departure_shortage_%d"%height);G.wallet.gold=before_gold;page._chest.refresh()
		page._chest.layout(safe);await shot("departure_safe_%d"%height);await drop()
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
		check(not text_all(page).contains("集火目标"),"场上无浮动目标文案")
		var previous:=focus;await click(page._chest._buttons.target)
		check(page.sim.role_focus_target_uid!=previous,"换目标实际切换")
		var current:int=page.sim.role_focus_target_uid
		check(page._chest._badges[current].focused and page._views[current]._target_ring.visible,"换目标徽记与脚下环同步")
		await shot("battle_switched_%d"%height)
		var defeated:Combatant=page.sim.unit_by_uid(previous);defeated.hp=0;defeated.alive=false;page._sync_views();page._refresh_hud()
		check(not page._chest._badges[previous].visible,"阵亡敌人徽记消失")
		await shot("battle_dead_%d"%height)
		page.sim.role_unit().energy=30;page._refresh_hud();await click(page._chest._buttons.skill);await shot("battle_energy30_%d"%height)
		for row in page._chest._page_body.get_children():
			var def:Dictionary=page._command_skill_def(page.sim.role_unit(),String(row.get_meta("skill_id")))
			check(row.disabled==(int(def.get("cost",0))>30),"能量门槛状态同源")
		page.sim.role_unit().skills[0].cd_left=96;page._chest.update_page();await shot("battle_cooldown_%d"%height)
		page._close_page();page.sim.role_unit().hp=1;page._refresh_hud();page._chest.layout(safe);await shot("battle_safe_low_%d"%height);await drop()
		page=preload("res://src/ui/LoadScreen.tscn").instantiate();page.auto_advance=false;add_child(page);await shot("loading_%d"%height);await drop()
		fixture()
		page=preload("res://src/ui/Title.tscn").instantiate();add_child(page);await shot("title_%d"%height);await drop()
		page=SettingsPanel.new();add_child(page);await shot("settings_%d"%height)
		await click(page._mute_btn);check(page._chest._sliders[0].editable==not Audio.muted(),"设置静音和滑杆同步")
		await click(page._mute_btn);await drop()
	print("NEXT_REVIEW_%s checks=%d failures=%d"%["OK" if failures==0 else "FAIL",checks,failures]);get_tree().quit(0 if failures==0 else 1)
