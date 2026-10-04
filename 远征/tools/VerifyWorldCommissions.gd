extends Node
var _fails := 0

func _check(ok:bool,line:String)->void:
	if not ok:
		_fails+=1
		push_error("FAIL: "+line)

func _posting(id:String)->Dictionary:
	var region:=String(WorldCommission.row(id).region)
	for i in range(1,29):
		var date:="2000-01-%02d"%i
		for offer in WorldCommission.offers(G,region,date):
			if String(offer.template)==id and not WorldCommission.state(G).has(String(offer.posting)): return offer
	return {}

func _map(mid:String)->MapScene:
	var run:=RunState.new()
	run.setup({"theme":"forest","role_id":"zs","level":10,"seed":7})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":mid,"run":run,"node":{"type":"normal","layer":1,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	map.set_process(false)
	map.set_physics_process(false)
	map._player.position=Vector2(100,1050)
	return map

func _click(control:Control)->void:
	var e:=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=true
	control.gui_input.emit(e)

func _button(root:Node,text:String)->Control:
	if root is Button and root.text.replace(" ","")==text.replace(" ",""):return root
	if root is Label and root.text.replace(" ","")==text.replace(" ","") and root.get_parent() is Control:return root.get_parent()
	for child in root.get_children():
		var found:=_button(child,text)
		if found!=null:return found
	return null

func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_world_commissions.json"
	G._init_state_defaults()
	G.save_locked=false
	G.selected_role="zs"
	var done:Array=[]
	for i in range(1,37): done.append("s%02d"%i)
	G.prog.story={"step":"","done":done,"goals":{}}
	G.prog.main_world=WorldSession.normalize_state({})
	G.items.enhance_stone=20
	_check(WorldCommission.templates().size()==12,"十二类地图事务有独立模板")
	for row in WorldCommission.templates():
		var offer:=_posting(String(row.id))
		_check(not offer.is_empty(),"每日候选确实可轮到每个模板")
		var posting:=String(offer.posting)
		_check(bool(WorldCommission.accept(G,posting,String(row.region),String(offer.day)).ok),"明确接取")
		var before:=G.prog.duplicate(true)
		_check(not bool(WorldCommission.accept(G,posting,String(row.region),String(offer.day)).ok) and G.prog==before,"不可重复接单")
		_check(WorldCommission.offers(G,String(row.region),"2099-12-31").any(func(v:Dictionary):return String(v.posting)==posting),"跨日未交不消失")
		while String(WorldCommission.state(G)[posting].status)=="active":
			var step:=WorldCommission.current(WorldCommission.state(G)[posting])
			var choice:=String(step.get("correct",""))
			var choices:Dictionary=step.get("choices",{})
			if choice.is_empty() and not choices.is_empty(): choice=String(choices.keys()[0])
			before=G.prog.duplicate(true)
			var inventory:=G.items.duplicate(true)
			_check(not bool(WorldCommission.action(G,posting,"wrong_map",String(step.id),choice,true).ok) and G.prog==before,"不能在错误地点推进")
			if not String(step.get("correct","")).is_empty():
				for bad in choices:
					if String(bad)==choice:continue
					var wrong:=WorldCommission.action(G,posting,String(step.map),String(step.id),String(bad))
					_check(not bool(wrong.ok) and not String(wrong.line).is_empty() and G.prog==before and G.items==inventory,"错误道岔只给反证")
			G.save_locked=true
			_check(not bool(WorldCommission.action(G,posting,String(step.map),String(step.id),choice,true).ok) and G.prog==before and G.items==inventory,"锁盘不扣材料不推进")
			G.save_locked=false
			if String(step.kind)=="defeat":
				_check(not bool(WorldCommission.action(G,posting,String(step.map),String(step.id)).ok),"守夜不能靠触碰空牌完成")
				var map:=await _map(String(step.map))
				var guard:Variant=null
				for m in map._monsters:
					if m.commission_posting==posting:guard=m
				_check(guard!=null,"夜岗实际生成可战斗敌人")
				if guard!=null:
					map._start_battle(guard)
					_check(map._battle!=null,"夜岗进入生产战斗场景")
					map._on_battle_end("victory",map.st.hp)
				map.queue_free()
				await get_tree().process_frame
			else:
				_check(bool(WorldCommission.action(G,posting,String(step.map),String(step.id),choice).ok),"现场动作可保存")
				if not (step.get("costs",{}) as Dictionary).is_empty():
					_check(int(G.items.enhance_stone)==int(inventory.enhance_stone)-2,"材料只现场扣一次")
			before=G.prog.duplicate(true)
			_check(not bool(WorldCommission.action(G,posting,String(step.map),String(step.id),choice,true).ok) and G.prog==before,"重放不重复计数扣物")
			_check(G.reload_save(),"现场进度能独立读档")
		var gold:=int(G.wallet.gold)
		before=G.prog.duplicate(true)
		_check(not bool(WorldCommission.claim(G,posting,"other_city").ok) and G.prog==before,"必须回发布城交付")
		G.save_locked=true
		_check(not bool(WorldCommission.claim(G,posting,"lorin_wilds").ok) and G.prog==before,"锁盘领奖无副作用")
		G.save_locked=false
		var cities:Dictionary={"zhaoyuan":"lorin_wilds","shenyuan":"shenyuan_port","frost":"frost_post"}
		_check(bool(WorldCommission.claim(G,posting,String(cities[row.region])).ok) and int(G.wallet.gold)==gold+int(row.reward.gold),"每单普通报酬一次到账")
		gold=int(G.wallet.gold)
		_check(not bool(WorldCommission.claim(G,posting,String(cities[row.region])).ok) and int(G.wallet.gold)==gold,"不能重复领取")
	# Production map choice input, then a separate process resumes the selected route.
	var trust_script := preload("res://src/world/RegionalTrust.gd")
	for region in WorldCommission.REGIONS:
		_check(int(trust_script.info(G,region).count)==4 and int(trust_script.info(G,region).tier)==1,"四件现场实事使三城同时达到信任")
	for npc in trust_script.REPRESENTATIVES:
		_check(not trust_script.npc_line(G,String(npc)).is_empty(),"三名真实代表有地区后续故事")
	for town in trust_script.CITIES:
		var city_map:=await _map(String(town))
		var scene_found:=false
		for entity in city_map._quest_entities:
			if entity.art=="trust_"+String(trust_script.CITIES[town]) and entity.feedback_tier==1:
				scene_found=true
				city_map._player.position=entity.position
				entity._process(0)
				_check(entity._caption_label.visible,"靠近独立往来物件可读来源标题")
		_check(scene_found,"三城从实际事务重建独立路簿、潮图或轮岗场景")
		city_map.queue_free()
		await get_tree().process_frame
	var readonly := G.prog.duplicate(true)
	trust_script.info(G,"shenyuan")
	_check(G.prog==readonly,"查询旧档往来不重发奖励不写假事件")
	var transactions:Array=G.ledger().applied
	transactions.append("shipping|fixture_ship|arrive|1")
	transactions.append("shipping|fixture_ship|arrive|1")
	transactions.append("shipping|fixture_ship|dispatch|2")
	transactions.append("frost_herb|fixture_medicine|deliver|1")
	transactions.append("frost_herb|fixture_medicine|abandon|2")
	_check(int(trust_script.info(G,"shenyuan").count)==5 and int(trust_script.info(G,"frost").count)==5,"按期交货计一次，取消装船不算信任")
	_check(is_equal_approx(trust_script.shop_mult(G,"shenyuan_port"),.98),"信任提供2%普通材料服务便利")
	G.prog=readonly
	var offer:=_posting("wc_escort")
	var posting:=String(offer.posting)
	WorldCommission.accept(G,posting,"shenyuan",String(offer.day))
	var map:=await _map("shenyuan_port")
	var entity:Variant=null
	for e in map._quest_entities:
		if e.commission_posting==posting:entity=e
	_check(entity!=null,"实际地图出现当前货签")
	if entity!=null:
		map.on_quest_entity(entity)
		_check(map._puzzle_panel!=null,"真实交互打开路线选择")
		if map._puzzle_panel!=null:
			var button:=_button(map._puzzle_panel,"沿浅滩近路")
			_check(button!=null,"生产选择按钮可找到")
			if button!=null:_click(button)
			_check(String(WorldCommission.current(WorldCommission.state(G)[posting]).map)=="tideflat","点击浅滩路线保存真实目的地")
	map.queue_free()
	await get_tree().process_frame
	var original:=G.SAVE_PATH
	var before:=G.prog.duplicate(true)
	var money:=G.wallet.duplicate(true)
	G.SAVE_PATH="res://tools/_logs/absent_world_commission_dir/save.json"
	var print_errors:=Engine.print_error_messages
	Engine.print_error_messages=false
	var failed:=WorldCommission.abandon(G,posting)
	Engine.print_error_messages=print_errors
	G.SAVE_PATH=original
	_check(not bool(failed.ok) and G.prog==before and G.wallet==money,"实际写盘失败整体回滚")
	var broken:=JSON.parse_string(FileAccess.get_file_as_string(G.SAVE_PATH)) as Dictionary
	broken.prog.world_commissions[posting].progress=999
	_check(not bool(SaveData.validate(broken,int(Time.get_unix_time_from_system())).ok),"坏阶段不可导入覆盖旧档")
	var abandon_offer:=_posting("wc_sign")
	var abandoned:=String(abandon_offer.posting)
	WorldCommission.accept(G,abandoned,"zhaoyuan",String(abandon_offer.day))
	_check(bool(WorldCommission.abandon(G,abandoned).ok) and not bool(WorldCommission.accept(G,abandoned,"zhaoyuan",String(abandon_offer.day)).ok),"放弃为明确终态，本日不能重接刷事件")
	_check(G.reload_save() and String(WorldCommission.state(G)[abandoned].status)=="abandoned","放弃读档后仍闭合")
	var file:=FileAccess.open("res://tools/_logs/world_commission_resume_id.txt",FileAccess.WRITE)
	file.store_string(posting)
	file.close()
	var panel:=preload("res://src/ui/WorldCommissionPanel.gd").new()
	add_child(panel)
	await get_tree().process_frame
	for region in WorldCommission.REGIONS:
		panel._region=region
		panel._refresh()
		_check(panel._list.get_child_count()>0,"三城公告栏实际渲染")
	panel._region="shenyuan"
	panel._refresh()
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--screens"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/body_content_20261004/world_commissions.png")
	panel.queue_free()
	await _test_oaths()
	print("WORLD_COMMISSIONS_OK" if _fails==0 else "WORLD_COMMISSIONS_FAIL %d"%_fails)
	get_tree().quit(0 if _fails==0 else 1)

func _test_oaths()->void:
	var oaths:=preload("res://src/world/OathService.gd")
	var lock_before:=G.prog.duplicate(true)
	G.save_locked=true
	_check(not bool(oaths.choose(G,"shelter","lorin_wilds").ok) and G.prog==lock_before,"锁盘立约无副作用")
	G.save_locked=false
	for role in ["zs","ck","fs","fz"]:
		var plain:=BattleSim.new()
		plain.setup(7,{"role_id":role,"level":10,"potions":1},{"theme":"forest","node_type":"normal","solo":true})
		for oath in oaths.rows():
			var sim:=BattleSim.new()
			sim.setup(7,{"role_id":role,"level":10,"potions":1,"growth":oath.bonus,"potion_effect_mult":oath.potion_mult},{"theme":"forest","node_type":"normal","solo":true})
			_check(absf(float(sim.role_unit().base_atk)/float(plain.role_unit().base_atk)-1.0)<=.07,"四职业攻击差异在轻量预算内")
			sim.role_unit().hp=1
			_check(sim.use_potion() and sim.role_unit().hp==1+DamageCalc.heal_amount(sim.role_unit().get_max_hp(),0,BattleSim.POTION_HEAL_PCT*float(oath.potion_mult),0),"四职业药剂按立约公开比例恢复")
	G.prog.main_world.map_id="lorin_wilds"
	var before:=G.prog.duplicate(true)
	_check(not bool(oaths.choose(G,"conquest","maple_road").ok) and G.prog==before,"野外不能换约")
	var maps:Dictionary={"shelter":"maple_road","conquest":"stele_cavern","harvest":"broken_slope"}
	for id in maps:
		_check(bool(oaths.choose(G,String(id),"lorin_wilds").ok),"安全城内可以立三种誓约")
		var key:=String(oaths.enter(G,String(maps[id])))
		_check(not key.is_empty() and String(oaths.objective(G,key).id)==String(id),"出行锁定本图誓约")
		oaths.choose(G,"harvest" if id!="harvest" else "shelter","lorin_wilds")
		_check(oaths.enter(G,String(maps[id]))==key and String(oaths.objective(G,key).id)==String(id),"回城切换不重置本图今日目标")
		var map:=await _map(String(maps[id]))
		if id=="conquest":
			var guard:Variant=null
			for m in map._monsters:
				if not m.oath_trip.is_empty():guard=m
			_check(guard!=null and guard.mon_id!=String(map._main_cfg.get("boss_id","")),"前哨不能冒用主线首领身份")
			if guard!=null:
				map._start_battle(guard)
				_check(map._battle!=null,"前哨进入真实战斗")
				map._on_battle_end("victory",map.st.hp)
		else:
			var entity:Variant=null
			for e in map._quest_entities:
				if e.kind=="oath":entity=e
			_check(entity!=null,"庇护与丰收生成有形地图目标")
			if entity!=null:map.on_quest_entity(entity)
			if id=="shelter":
				_check(String(oaths.trip(G,key).status)=="active" and int(oaths.trip(G,key).phase)==1,"接应旅人不能直接领护送报酬")
				await get_tree().process_frame
				await get_tree().process_frame
				for e in map._quest_entities:
					if e.kind=="oath":
						map._oath_traveler.position=e.position
						map.on_quest_entity(e)
		_check(String(oaths.trip(G,key).get("status",""))=="done","目标完成记纹样及材料")
		before=G.prog.duplicate(true)
		var items:=G.items.duplicate(true)
		_check(not bool(oaths.finish(G,key).ok) and G.prog==before and G.items==items,"重放誓约不重复给材料")
		_check(G.reload_save() and String(oaths.trip(G,key).get("status",""))=="done","誓约纹样从磁盘恢复")
		map.queue_free()
		await get_tree().process_frame
	oaths.choose(G,"harvest","lorin_wilds")
	var unfinished:=String(oaths.enter(G,"rift_mine_road"))
	oaths.choose(G,"conquest","lorin_wilds")
	var original:=G.SAVE_PATH
	var fault_before:=G.prog.duplicate(true)
	var inventory:=G.items.duplicate(true)
	G.SAVE_PATH="res://tools/_logs/absent_oath_dir/save.json"
	var print_errors:=Engine.print_error_messages
	Engine.print_error_messages=false
	var failure:=oaths.finish(G,unfinished)
	Engine.print_error_messages=print_errors
	G.SAVE_PATH=original
	_check(not bool(failure.ok) and G.prog==fault_before and G.items==inventory,"誓约报酬写盘失败还原材料纹样目标")
	var panel:=preload("res://src/ui/OathPanel.gd").new()
	add_child(panel)
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--screens"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/body_content_20261004/oaths.png")
	panel.queue_free()
