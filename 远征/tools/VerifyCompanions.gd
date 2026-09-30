extends "res://tools/VerifyThirdBack.gd"

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_companions.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	await _run()
	print("COMPANIONS_OK" if _fails == 0 else "COMPANIONS_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _chapter(n: int) -> void:
	var done: Array = []
	for i in range(1,n+1): done.append("s%02d" % i)
	G.prog["story"] = {"step":"s%02d" % (n+1),"done":done,"goals":{}}

func _press(button: Control) -> void:
	if button == null: return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	button.gui_input.emit(event)

func _pet(sim: BattleSim) -> Combatant:
	for unit in sim.units:
		if unit.kind == "pet": return unit
	return null

func _paragraph(root: Node) -> Label:
	for child in root.get_children():
		if child is Label and child.text.begins_with("每次主世界"): return child
		var result := _paragraph(child)
		if result != null: return result
	return null

func _trait_events(sim: BattleSim, tid: String) -> int:
	var count := 0
	for event in sim.events:
		if event.get("t","") == "companion_trait" and event.get("trait","") == tid: count += 1
	return count

func _sim(role: String, traits: Array, pid := "pet_rockturtle") -> BattleSim:
	var fake := {"companions":{"pets":{pid:{"wins":3,"traits":traits}}}}
	var sim := BattleSim.new()
	sim.setup(371,{"role_id":role,"level":10,"active_pet":pid,
		"pet_stats":{pid:{"level":10,"companion_traits":CompanionService.snapshot(fake,pid)}}},
		{"theme":"forest","custom_mon":{"id":"fixture","name":"试招者","base":{"hp":3000,"atk":25,"def":3,"spd":0.8},"skills":[]}})
	return sim

func _cast(sim: BattleSim, sid: String) -> void:
	var role := sim.role_unit()
	role.energy = 100
	for slot in role.skills: slot.cd_left = 0
	SkillSystem.resolve_cast(sim,{"uid":role.uid,"skill":TableCache.get_skill(sid)})

func _run() -> void:
	var cfg := CompanionService.config()
	_check(cfg.slots.size() == 2 and cfg.traits.size() == 3,"两项特性与三个战术必须完整")
	for pet in TableCache.pets():
		_check(cfg.pet_elements.has(pet.id),"所有现有伙伴必须有元素说明")
		for skill in pet.skills: _check(cfg.skill_elements.has(skill.id),"伙伴自身技能必须有响应元素")
	G.prog["pets"] = ["pet_rockturtle","pet_tide_gull"]
	G.prog["main_world"] = {"map_id":"frost_post"}
	G.prog["pet_stat"] = {"pet_rockturtle":{"lv":7,"exp":18,"star":4,"brk":2,"evolved":true}}
	G.items = {"pet_food":20}
	G.ensure_starter_equip(true)
	_chapter(23)
	_check(G.companion_active() == "pet_rockturtle" and not G.prog.has("companions"),"旧档读查询不能自动发特性或重排拥有顺序")
	_check(not bool(G.companion_train("pet_rockturtle",0,"comp_guard").ok),"s24前拒绝训练")
	_chapter(24)
	_check(not bool(G.companion_select("pet_foxfire").ok),"不可选择未拥有伙伴")
	G.prog.main_world.map_id = "red_sand_route"
	_check(not bool(G.companion_select("pet_tide_gull").ok),"野外不能免费更换长期随行")
	G.prog.main_world.map_id = "frost_post"
	var old_stats := (G.prog.pet_stat as Dictionary).duplicate(true)
	var old_equipment := (G.prog.equip as Dictionary).duplicate(true)
	var post := await _enter("frost_post")
	var lodge: Dictionary = {}
	for building in TableCache._load("res://data/frost_post.json").buildings:
		if building.id == "frost_lodge": lodge = building
	post._city_content._open_building(lodge)
	_check(_find_button(post._city_content._panel,"翻阅世界图志") != null,"驿舍原图志入口保留")
	_press(_find_button(post._city_content._panel,"伙伴协战"))
	var panel := post._city_content._panel as CompanionPanel
	_check(panel != null,"实际建筑按钮打开协战服务")
	if panel != null:
		await get_tree().process_frame
		var paragraph := _paragraph(panel)
		_check(paragraph != null and paragraph.size.x <= 382 and paragraph.get_line_count() >= 2,"中文训练规则必须在面板宽度内换行")
		var guard := _find_button(panel,"护卫")
		_check(guard != null and guard.size.y >= 44,"真实训练按钮可点")
		_press(guard)
		_check(CompanionService.state(G.prog,"pet_rockturtle").traits == ["comp_guard"] and G.item_count("pet_food") == 19,"实际按钮耗粮保存特性")
		_press(_find_button(panel,"护卫"))
		_check(G.item_count("pet_food") == 19,"重复同项不得再次扣粮")
		_press(_find_button(panel,"第2项"))
		_press(_find_button(panel,"追击"))
		_check(CompanionService.state(G.prog,"pet_rockturtle").traits == ["comp_guard"],"第二项必须等待真实协战")
		_press(_find_button(panel,"下一只"))
		_press(_find_button(panel,"设为随行"))
		_check(post.st.active_pet == "pet_tide_gull" and post.st.bench_pet == "pet_rockturtle" and post._pet_follower != null,"选择立即刷新同图随行和替补")
	post._city_content._close_panel()
	post.queue_free()
	await get_tree().process_frame
	_check(G.prog.pet_stat == old_stats and G.prog.equip == old_equipment,"训练不能重置既有进阶与装备")
	# 真正写盘后的失败适配器：扣粮/选择必须回滚。
	var host := FailedSaveHost.new()
	host._init_state_defaults()
	host.prog = G.prog.duplicate(true)
	host.items = G.items.duplicate(true)
	var before := host.prog.duplicate(true)
	var items := host.items.duplicate(true)
	_check(not bool(host.companion_train("pet_rockturtle",0,"comp_pursuit").ok) and host.prog == before and host.items == items,"写盘失败返还宠粮与特性")
	_check(not bool(host.companion_select("pet_rockturtle").ok) and host.prog == before,"选择写盘失败不换随行")
	host.free()
	# 真实世界结算入口与遭遇去重/回滚共用，不能单独发训练进度。
	var mine := await _enter("rift_mine_road")
	_check(mine._foot_hits_patrol(Vector2(697.9573,1073.513),1.0),"已复现的岩石基座不能再占据南侧巡逻接触范围")
	for patrol in mine._main_cfg.monster_positions:
		var query := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 18
		query.shape = circle
		query.collision_mask = 2
		query.transform = Transform2D(0,Vector2(patrol[0],patrol[1]))
		_check(mine.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"矿道明雷出生点必须能实际接近")
	mine._last_battle_pets = ["pet_rockturtle","pet_rockturtle"]
	mine._encounter = WorldSession.new_encounter("rift_mine_road",0,Vector2(90,500),"mon_scorp",5,Vector2(480,710),"",0,902)
	WorldSession.advance(mine._main_world_state(),mine._encounter,WorldSession.ST_BATTLE)
	G.save_locked = true
	_check(mine._settle_main_world("normal","mon_scorp") == "save_failed" and int(CompanionService.state(G.prog,"pet_rockturtle").wins) == 0,"锁盘胜利不计协战")
	G.save_locked = false
	_check(mine._settle_main_world("normal","mon_scorp") == "ok","正常胜利必须保存")
	_check(int(CompanionService.state(G.prog,"pet_rockturtle").wins) == 1,"实际参战同物种只加一次")
	_check(mine._settle_main_world("normal","mon_scorp") == "dup" and int(CompanionService.state(G.prog,"pet_rockturtle").wins) == 1,"重复战果不重复加熟练")
	mine.queue_free()
	await get_tree().process_frame
	G.prog.main_world.map_id = "frost_post"
	_check(G.save_game() and G.reload_save() and G.companion_active() == "pet_tide_gull","随行与特性真实读档保留")
	_check(CompanionService.state(G.prog,"pet_rockturtle").traits == ["comp_guard"],"第一项读档保留")
	# 后续第二项训练边界属于合成夹具，三次实际胜利另由输入回放验证。
	CompanionService.record_win(G.prog,["pet_rockturtle"])
	CompanionService.record_win(G.prog,["pet_rockturtle"])
	_check(bool(G.companion_train("pet_rockturtle",1,"comp_pursuit").ok),"三胜后可训练第二项")
	_check(not bool(G.companion_train("pet_rockturtle",1,"comp_guard").ok),"两槽不可重复特性")
	for corrupt in [{"pets":[]},{"active":"pet_foxfire"},{"pets":{"pet_rockturtle":{"wins":1.5}}},
		{"pets":{"pet_rockturtle":{"wins":-1}}},{"pets":{"pet_rockturtle":{"traits":["comp_guard","comp_guard"]}}},
		{"pets":{"pet_rockturtle":{"traits":["missing"]}}}]:
		_check(not bool(SaveData.validate({"prog":{"pets":G.owned_pets(),"companions":corrupt}},int(Time.get_unix_time_from_system())).ok),"坏伙伴状态必须拒绝，不静默清零")
	_test_mechanics()
	_check(not CompanionService.validate({"pets":{"pet_rockturtle":{"wins":2,"traits":["comp_guard","comp_pursuit"]}}},G.owned_pets()),"读档也必须验证第二槽三胜门槛")
	# Synthetic defeat, through the real MapScene result branch; not claimed as input playthrough.
	var loss := await _enter("rift_mine_road")
	loss.st.active_pet = "pet_rockturtle"
	loss.map_finished.connect(func(_result: String): pass)
	loss._start_battle(loss._monsters[0])
	var wins := int(CompanionService.state(G.prog,"pet_rockturtle").wins)
	loss._battle.sim.finished = true
	loss._battle.sim.result = "defeat"
	loss._on_battle_end("defeat",0)
	_check(int(CompanionService.state(G.prog,"pet_rockturtle").wins) == wins and loss._last_battle_pets == ["pet_rockturtle"],"实际参战败局的结算分支不加协战")
	loss.queue_free()
	await get_tree().process_frame

func _test_mechanics() -> void:
	var sim := _sim("zs",["comp_guard"])
	var role := sim.role_unit()
	var pet := _pet(sim)
	var enemy := sim.alive_units("enemy")[0]
	var rhp := role.hp
	var php := pet.hp
	role.take_damage(100,enemy,sim)
	_check(rhp-role.hp == 65 and php-pet.hp == 35 and _trait_events(sim,"comp_guard") == 1,"护卫真实分担35%而非凭空减伤")
	role.take_damage(60,enemy,sim)
	_check(_trait_events(sim,"comp_guard") == 1,"每物种每战一次")
	var blocked := _sim("zs",["comp_guard"])
	_pet(blocked).add_buff("stun",100,{})
	blocked.role_unit().take_damage(100,blocked.alive_units("enemy")[0],blocked)
	_check(_trait_events(blocked,"comp_guard") == 0,"被控制伙伴不能护卫")
	var dot := _sim("zs",["comp_guard"])
	dot.role_unit()._direct_damage(80,dot.alive_units("enemy")[0],dot,true)
	_check(_trait_events(dot,"comp_guard") == 0,"持续伤害不能刷护卫")
	var pursue := _sim("ck",["comp_pursuit"])
	_cast(pursue,"ck_lianzhu")
	_check(_trait_events(pursue,"comp_pursuit") == 1,"连珠二段只触发一追击")
	_cast(pursue,"ck_guanjia")
	_check(_trait_events(pursue,"comp_pursuit") == 1,"冷却内不追击")
	pursue.tick_count = 360
	_cast(pursue,"ck_lianzhu")
	_check(_trait_events(pursue,"comp_pursuit") == 2,"12秒后恢复追击")
	var heal := _sim("fz",["comp_pursuit"])
	_cast(heal,"fz_shengyu")
	_check(_trait_events(heal,"comp_pursuit") == 0,"满血治疗不触发追击")
	heal.role_unit().hp -= 40
	_cast(heal,"fz_shengyu")
	_check(_trait_events(heal,"comp_pursuit") == 1,"晨星实际治疗能触发追击")
	var immune := _sim("ck",["comp_pursuit"])
	immune.alive_units("enemy")[0].add_buff("invincible",100,{})
	_cast(immune,"ck_lianzhu")
	_check(immune.companion_used.is_empty(),"免疫未造成伤害不耗追击冷却")
	var resonance := _sim("fs",["comp_resonance"],"pet_frostwolf")
	resonance.role_unit().add_buff("slow",100,{"pct":0.1})
	resonance.role_unit().add_buff("atk_down",100,{"pct":0.1})
	_pet(resonance).add_buff("poison",100,{"pct":0.1})
	_cast(resonance,"fs_tianyun")
	_check(_trait_events(resonance,"comp_resonance") == 0,"非对应元素不响应")
	_cast(resonance,"fs_shuangren")
	_check(not resonance.role_unit().has_buff("slow") and resonance.role_unit().has_buff("atk_down") and not _pet(resonance).has_buff("poison"),"响应只净化双方各一项最早负面")
	_cast(resonance,"fs_shuangren")
	_check(_trait_events(resonance,"comp_resonance") == 1,"响应冷却不刷新")
	resonance.tick_count = 360
	_cast(resonance,"fs_shuangren")
	_check(_trait_events(resonance,"comp_resonance") == 2 and not resonance.role_unit().has_buff("atk_down"),"响应到期恢复")
	for pd in TableCache.pets():
		var own := _sim("zs",["comp_resonance"],String(pd.id))
		own.role_unit().add_buff("slow",200,{"pct":0.1})
		own.role_unit().hp -= 20
		var companion := _pet(own)
		SkillSystem.resolve_cast(own,{"uid":companion.uid,"skill":pd.skills[0]})
		_check(_trait_events(own,"comp_resonance") == 1,"每种伙伴可通过自身元素招式响应："+String(pd.id))
	var hidden := _sim("ck",["comp_resonance"],"pet_eyescat")
	hidden.role_unit().add_buff("slow",100,{"pct":0.1})
	_cast(hidden,"ck_dunying")
	_check(_trait_events(hidden,"comp_resonance") == 1,"真实潜行增益可以响应")
	_check(not hidden.events.any(func(e): return e.get("t","") == "skill_effective"),"增益响应不改导师伤害治疗护盾熟练口径")
	var blessing := _sim("fz",["comp_resonance","comp_pursuit"],"pet_holydeer")
	blessing.role_unit().add_buff("slow",100,{"pct":0.1})
	_cast(blessing,"fz_zhudao")
	_check(_trait_events(blessing,"comp_resonance") == 1 and _trait_events(blessing,"comp_pursuit") == 0,"真实祝祷可响应但不能当治疗追击")
	var dead := _sim("ck",["comp_guard","comp_pursuit"])
	_pet(dead).hp = 0
	_pet(dead).alive = false
	_cast(dead,"ck_lianzhu")
	dead.role_unit().take_damage(100,dead.alive_units("enemy")[0],dead)
	_check(dead.companion_used.is_empty(),"倒下的伙伴没有协战能力")
	var legal := _sim("ck",["comp_pursuit"])
	legal.alive_units("enemy")[0].row = Combatant.ROW_BACK
	legal._build_custom_mon({"id":"front_fixture","base":{"hp":3000,"atk":1,"def":1,"spd":1},"skills":[]})
	var front := legal.alive_units("enemy")[1]
	front.row = Combatant.ROW_FRONT
	CompanionService.on_skill(legal,legal.role_unit(),TableCache.get_skill("ck_guanjia"),10)
	var events := legal.events.filter(func(e): return e.get("t","") == "companion_trait")
	_check(events.size() == 1 and int(events[0].uid) == front.uid,"近战伙伴追击不能跳过前排")
	var frozen := _sim("ck",["comp_pursuit"])
	var original := _pet(frozen).companion_traits.duplicate(true)
	G.prog.companions.pets.pet_rockturtle.traits = ["comp_guard"]
	_cast(frozen,"ck_lianzhu")
	_check(_pet(frozen).companion_traits == original and _trait_events(frozen,"comp_pursuit") == 1,"局外重训不能改已入场快照")
	frozen.pet_bench_id = "pet_rockturtle"
	_check(frozen.swap_pet(),"测试换宠动作必须实际执行")
	_cast(frozen,"ck_guanjia")
	_check(_trait_events(frozen,"comp_pursuit") == 1 and frozen.companion_participants == ["pet_rockturtle"],"换宠不能刷新同物种冷却或重复计参战")
	var entry := {"pet_rockturtle":{"level":10,"companion_traits":CompanionService.snapshot({"companions":{"pets":{"pet_rockturtle":{"wins":3,"traits":["comp_guard"]}}}},"pet_rockturtle")}}
	var deferred := BattleSim.new()
	deferred.setup(317,{"role_id":"zs","level":10,"bench_pet":"pet_rockturtle","pet_stats":entry},
		{"theme":"forest","custom_mon":{"id":"fixture","base":{"hp":3000,"atk":1,"def":1,"spd":1},"skills":[]}})
	entry.pet_rockturtle.companion_traits.clear()
	_check(deferred.swap_pet() and _pet(deferred).companion_traits.has("comp_guard"),"替补也使用入场时的深复制快照")
