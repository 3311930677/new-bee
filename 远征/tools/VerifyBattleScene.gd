# VerifyBattleScene.gd —— 战斗场景冒烟（场景模式：godot --headless --path . res://tools/VerifyBattleScene.tscn）
# 用场景模式而非 -s：BattleScene 依赖 autoload G，-s 模式下编译器不注册 autoload 全局名
# 覆盖：场景构建无脚本错误 / tick 步进 + 事件消费（飘字创建销毁）/ 单位视图同步 /
#       技能条-能量-药剂刷新 / 结算浮层出现与信号 / 全事件类型消费无崩溃（含 BOSS 召唤）
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_battle.json"  # 别污染真实存档
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	# 1. 普通节点整场（加速 12x）
	var r1: Dictionary = await _run_one("forest", "normal", 1, false)
	_check(r1.get("finished", false), "普通节点应出现结算")
	_check(r1.get("result", "") == "victory", "普通节点应胜利，实为 %s" % r1.get("result", ""))
	_check(int(r1.get("fx_left", -1)) == 0, "战斗结束后飘字层应清空（tween 完成后），实为 %d" % int(r1.get("fx_left", -1)))
	_check(int(r1.get("views", 0)) >= 4, "应有至少 4 个单位视图（1人物+1宠+3~4怪），实为 %d" % int(r1.get("views", 0)))

	# 2. BOSS 节点（含召唤/大招/更多事件类型）
	var r2: Dictionary = await _run_one("forest", "boss", 3, true)
	_check(r2.get("finished", false), "BOSS 节点应出现结算")
	_check(r2.get("result", "") == "victory", "lv15+词条应胜 BOSS，实为 %s" % r2.get("result", ""))

	# 3. 撤退路径
	var r3: Dictionary = await _run_flee()
	_check(r3.get("finished", false) and r3.get("result", "") == "defeat", "撤退应判负结算")

	# 4. 打击反馈：顿帧 / 震屏 / 敌方施法可读 / 战报统计 / 低血层不落飘字层
	var r4: Dictionary = await _run_feedback()
	_check(r4.get("hitstop_on", false), "重击应触发顿帧")
	_check(r4.get("hitstop_off", false), "顿帧应在数十毫秒内归零")
	_check(r4.get("shake_moved", false), "重击应推动震屏层")
	_check(r4.get("shake_reset", false), "震屏层最终应回到原点")
	_check(r4.get("enemy_tip", false),
		"敌方施法应给出「敌方/首领技 · 技能名」提示，实为「%s」" % r4.get("tip_text", ""))
	_check(int(r4.get("best_hit", 0)) >= 999, "战报应记下最高单击，实为 %d" % int(r4.get("best_hit", 0)))
	_check(int(r4.get("dmg_in", 0)) >= 7, "战报应累计我方承伤，实为 %d" % int(r4.get("dmg_in", 0)))
	_check(r4.get("danger_ok", false), "低血警示层应存在，且不能挂在飘字层里（飘字层会被清空断言检查）")

	# 5. 超时文案按模式分开（问题 #21 / 口径 D3）：
	#    同一个战斗场景被远征与演武复用，但超时在两边的意义不同——
	#    远征按失败结算（要说"远征失利"），演武不判负（要说"未分胜负"）。
	_check(await _draw_text_seen("pve", "远征失利"), "PVE 超时应显示「远征失利」，与按败结算一致")
	_check(await _draw_text_seen("arena", "未分胜负"), "演武平局应显示「未分胜负」，不能写成失利")
	_check(await _run_classic_commands(), "经典战斗的攻/技/物/逃入口应可用且共用原战斗规则")
	_check(await _run_ranged_presentation(), "远程普攻应先飞弹、抵达后再显示伤害反馈且血条同步")
	_check(await _run_contact_presentation(), "两种战斗模式均我方左敌方右，近战到达目标身前命中并回位")
	_check(await _run_omens_and_phase(),
		"P03 敌方施法应出图形预兆（施法者+目标环）与含技能名的蓄力倒数；阶段事件应出居中横幅并把阶段名写进首领血条")
	_check(await _run_boss_flee_blocked(), "P03 剧情首领战「逃」应置灰且点击不产生撤退结算（其余三枚不受影响）")

	if _fails == 0:
		print("BATTLE_SCENE_OK all tests passed")
	else:
		print("BATTLE_SCENE_FAIL fails=%d" % _fails)


## 造一场超时（draw）结算，返回结算层里是否出现了 want 这段文案
func _draw_text_seen(mode: String, want: String) -> bool:
	BattleScene.pending_cfg = {
		"ally": {"role_id": "zs", "level": 5, "traits": [], "potions": 1},
		"enemy": {"theme": "forest", "node_type": "normal", "layer": 1},
		"mode": mode,
		"seed": 5,
	}
	var scene: BattleScene = _spawn()
	scene.sim.finished = true
	scene.sim.result = "draw"
	var found := false
	for i in 90:
		await get_tree().process_frame
		if not found and _texts(scene).any(func(t): return String(t).contains(want)):
			found = true
	scene.queue_free()
	await get_tree().process_frame
	return found


func _run_classic_commands() -> bool:
	BattleScene.pending_cfg = {
		"ally": {"role_id": "zs", "level": 5, "traits": [],
			"active_pet": "pet_rockturtle", "bench_pet": "pet_thunderhawk", "potions": 2},
		"enemy": {"theme": "forest", "node_type": "normal", "layer": 1},
		"presentation": "classic_inline", "seed": 17,
	}
	var scene := _spawn()
	scene.speed = 0.0
	await get_tree().process_frame
	var ok := scene._classic_presentation() and scene._cmd_root != null \
		and scene._cmd_btns.size() == 4 and scene._cmd_root.visible
	# P03：「逃」的后果文案要说在点之前（普通怪=退出本节点、保留战损与进度）
	ok = ok and String(scene._radial_hint("flee")).contains("保留战损")
	if not ok:
		scene.queue_free()
		await get_tree().process_frame
		return false

	var role := scene.sim.role_unit()
	var role_view: BattleScene.UnitView = scene._views[role.uid] if role != null else null
	var enemies := scene.sim.alive_units("enemy")
	if role != null and not enemies.is_empty():
		var enemy := enemies[0]
		ok = ok and scene._grid_pos(enemy.side, enemy.row, enemy.col).x \
			> scene._grid_pos(role.side, role.row, role.col).x
		ok = ok and (scene._views[enemy.uid] as BattleScene.UnitView).position \
			== scene._grid_pos(enemy.side, enemy.row, enemy.col)
		ok = ok and role_view.position == scene._grid_pos(role.side, role.row, role.col)
	if role_view != null:
		# 四枚指令在固定操作带上，不随角色移动，也不压单位与血条。
		var sprite_rect := Rect2(role_view.position + Vector2(-36, -62), Vector2(72, 72))
		var bars_rect := Rect2(role_view.position + Vector2(-22, 12), Vector2(44, 11))
		var tiles: Array[Rect2] = []
		for i in scene._cmd_btns.size():
			var cbd: Dictionary = scene._cmd_btns[i]
			var root := cbd.root as Control
			var want := Vector2(39.0 + i * 101.0, BattleScene.CLASSIC_CMD_Y)
			ok = ok and root.position == want
			var tile := Rect2(root.position, Vector2(BattleScene.CLASSIC_CMD_W,
				BattleScene.CLASSIC_CMD_H))
			ok = ok and not tile.intersects(sprite_rect) and not tile.intersects(bars_rect)
			# Imported icon dimensions must not override the intended touch layout.
			for child in root.get_children():
				if child is TextureRect:
					ok = ok and Rect2(Vector2.ZERO,root.size).encloses(child.get_rect())
					ok = ok and child.texture is AtlasTexture and child.size.x<=50
			for other in tiles:
				ok = ok and not tile.intersects(other)
			tiles.append(tile)
		# 原版风名牌：挂身右、纯文字无底板（name_bg 从不创建）
		ok = ok and role_view.name_l.position.x < 0 \
			and role_view.name_bg == null \
			and String(role_view.name_l.text) == "旅人 5"
		# 身侧宠物（经典模式整体偏移）不压任何一枚指令
		for unit in scene.sim.units:
			if unit.alive and unit.uid != role.uid:
				var uv: BattleScene.UnitView = scene._views[unit.uid]
				var unit_pos: Vector2 = scene._grid_pos(unit.side, unit.row, unit.col) \
					+ uv.body.position
				var unit_bounds := Rect2(unit_pos + Vector2(-36, -76), Vector2(72, 94))
				for tile in tiles:
					ok = ok and not tile.intersects(unit_bounds)
	scene._command_attack()
	var focus_id := scene.sim.role_focus_target_uid
	ok = focus_id >= 0 and role != null \
		and role.pick_basic_target(scene.sim) != null \
		and role.pick_basic_target(scene.sim).uid == focus_id
	ok = ok and (scene._views[focus_id] as BattleScene.UnitView)._target_mark.visible

	scene._show_command_skills()
	await get_tree().process_frame  # 页条按钮 queue_free 后再核对技能页
	var expected_skills := mini(5, role.skills.size()) if role != null else 0
	# 技能页底边固定、按行数向上长；每行至少 44px，触屏易点且不会透出旧指令。
	ok = ok and scene._page_panel.get_child_count() == expected_skills + 1 \
		and BattleScene.PAGE_ROW_H >= 44.0 and not scene._cmd_root.visible \
		and is_equal_approx(scene._page_panel.position.x, BattleScene.PAGE_PANEL_POS.x) \
		and is_equal_approx(scene._page_panel.size.x, BattleScene.PAGE_PANEL_SIZE.x) \
		and is_equal_approx(scene._page_panel.position.y + scene._page_panel.size.y,
			BattleScene.PAGE_PANEL_BOTTOM)
	if scene._page_panel.get_child_count() > 0:
		var row0 := scene._page_panel.get_child(0) as Control
		ok = ok and is_equal_approx(row0.size.x, BattleScene.PAGE_PANEL_SIZE.x) \
			and is_equal_approx(row0.size.y, BattleScene.PAGE_ROW_H)
	if expected_skills > 0:
		# 每行「左名 + 右侧灰色详情」：技能行必须写清 Lv/耗/冷/范围
		var row_text := " ".join(_texts(scene._page_panel.get_child(0)))
		ok = ok and row_text.contains("Lv") and row_text.contains("耗") \
			and row_text.contains("冷") and row_text.contains("单体")
		role.energy = 0
		var sid := String((role.skills[0] as Dictionary).def.get("id",""))
		var queued := scene.sim.cast_queue.size()
		scene._cast_command_skill(sid)
		ok = ok and scene.sim.cast_queue.size()==queued and scene._page_panel.visible
		ok = ok and scene._cast_tip.text.contains("能量不足")
		role.energy = Combatant.MAX_ENERGY
		role.skills[0].cd_left = 60
		scene._refresh_hud()
		var detail: Label = scene._page_panel.get_child(0).get_node("DetailText")
		ok = ok and detail.text.contains("2.0s")
		scene._cast_command_skill(sid)
		ok = ok and scene.sim.cast_queue.size()==queued and scene._page_panel.visible
		ok = ok and scene._cast_tip.text.contains("冷却中")
		role.skills[0].cd_left = 0
		scene._refresh_hud()
		ok = ok and scene._page_energy_l.text.contains(str(Combatant.MAX_ENERGY))
	scene._close_page()
	ok = ok and not scene._page_panel.visible
	scene._show_command_skills()
	await get_tree().process_frame
	if role != null:
		role.energy = Combatant.MAX_ENERGY
		var sid := String((role.skills[0] as Dictionary).def.get("id", ""))
		scene._cast_command_skill(sid)
		ok = ok and scene.sim.cast_queue.size() > 0 and not scene._page_panel.visible

	var potions_before := scene.sim.potions_left
	if role != null:
		role.hp = maxi(1, role.get_max_hp() - 40)
	scene._command_item()
	await get_tree().process_frame
	ok = ok and scene._page_panel.visible and scene._command_page == "items"
	# P03：道具行必须写清「数量 + 效果」（药剂 ×N / 恢复 X% 生命）
	var item_text := _join_texts(scene._page_panel)
	ok = ok and item_text.contains("药剂 ×") and item_text.contains("恢复")
	# P03 常驻信息条：四枚指令之上的一行，把攻/技/物三件事都说出来
	var info: Label = scene.get("_cmd_info_l")
	ok = ok and info != null and String(info.text).contains("攻") \
		and String(info.text).contains("技") and String(info.text).contains("物")
	scene._command_use_potion()
	ok = ok and scene.sim.potions_left == potions_before - 1
	scene._flee_armed = true # 模拟二次确认的第二击，验证仍落到既有撤退结算
	scene._command_flee()
	ok = ok and scene.sim.finished and scene.sim.result == "flee"
	scene.queue_free()
	await get_tree().process_frame
	return ok


## 把一棵子树里的所有 Label 文本拼成一段（弹页断言用）
func _join_texts(root: Node) -> String:
	return " | ".join(_texts(root))


## P03：图形预兆 + 文字倒数 + 阶段横幅 + 首领血条阶段名
func _run_omens_and_phase() -> bool:
	BattleScene.pending_cfg = {
		"ally": {"role_id": "zs", "level": 20, "traits": [], "potions": 2},
		"enemy": {"theme": "forest", "node_type": "boss", "layer": 1},
		"presentation": "classic_inline", "seed": 29,
	}
	var scene := _spawn()
	scene.speed = 0.0   # 冻住 sim：本用例只验表现层，避免真实施法把队列搅乱
	await get_tree().process_frame
	var boss: Combatant = null
	for u in scene.sim.units:
		if u.side == "enemy" and u.ai_type == "boss":
			boss = u
			break
	if boss == null:
		scene.queue_free()
		await get_tree().process_frame
		return false

	# 手工塞一条敌方前摇（首领技 · 碑震 · 全体前排），验预兆环与文字倒数
	scene.sim.cast_queue.append({"uid": boss.uid, "windup": 8,
		"skill": {"id": "boss_slam", "name": "碑震", "target": "enemy_front_all"}})
	scene.call("_on_event", {"t": "cast_start", "uid": boss.uid, "skill": "boss_slam", "name": "碑震"})
	# 预兆环平时是逐帧刷新的；这里直接调一次，免得断言依赖 process_frame 与 _process 的先后
	scene.call("_refresh_omens")
	var omens: Node2D = scene.get("_omens")
	var rings: Array = [] if omens == null else omens.get("rings")
	var caster_ring := false
	var target_ring := false
	for r in rings:
		if bool(r.get("target", false)):
			target_ring = true
		else:
			caster_ring = true
	# 施法者脚下 + 将要挨打者身上，两种环都要有
	var ok := omens != null and omens.visible and rings.size() >= 2 and caster_ring and target_ring
	var tip: Label = scene.get("_cast_tip")
	ok = ok and tip != null and String(tip.text).contains("碑震") and String(tip.text).contains("蓄力")

	# 阶段事件 → 居中横幅 + 首领血条追加阶段名
	scene.call("_on_event", {"t": "phase", "uid": boss.uid, "id": "wail",
		"name": "碑鸣", "announce": "失声碑灵发出低鸣——攻势加快"})
	var banner := false
	for i in 6:
		await get_tree().process_frame
		if not banner and _texts(scene).any(func(t): return String(t).contains("碑鸣")):
			banner = true
	ok = ok and banner
	var boss_l: Label = scene.get("_boss_name_l")
	ok = ok and boss_l != null and String(boss_l.text).contains("碑鸣")
	scene.queue_free()
	await get_tree().process_frame
	return ok


## P03：剧情首领战禁止撤退（flee_rule=blocked）——按钮置灰且点击不出撤退结算
func _run_boss_flee_blocked() -> bool:
	BattleScene.pending_cfg = {
		"ally": {"role_id": "zs", "level": 20, "traits": [], "potions": 1},
		"enemy": {"theme": "forest", "node_type": "boss", "layer": 1},
		"presentation": "classic_inline", "flee_rule": "blocked", "seed": 31,
	}
	var scene := _spawn()
	scene.speed = 0.0
	await get_tree().process_frame
	var ok := bool(scene.get("_flee_blocked")) and scene._radial_disabled("flee")
	# 置灰的同时必须把「为什么不能逃」写在按钮上（否则玩家以为是按键坏了）
	ok = ok and String(scene._radial_hint("flee")) == "首领战不可撤退"
	scene._command_flee()
	await get_tree().process_frame
	ok = ok and not scene.sim.finished and not bool(scene.get("_flee_armed"))
	# 灰化必须只落在「逃」上，其他三枚照常可点
	ok = ok and not scene._radial_disabled("attack") \
		and not scene._radial_disabled("skill") and not scene._radial_disabled("item")
	scene.queue_free()
	await get_tree().process_frame
	return ok


func _run_ranged_presentation() -> bool:
	BattleScene.pending_cfg = {
		"ally": {"role_id": "fs", "level": 5, "traits": [],
			"active_pet": "pet_rockturtle", "potions": 1},
		"enemy": {"theme": "forest", "node_type": "normal", "layer": 1},
		"presentation": "classic_inline", "seed": 19,
	}
	var scene := _spawn()
	scene.speed = 0.0
	await get_tree().process_frame
	var role := scene.sim.role_unit()
	var enemies := scene.sim.alive_units("enemy")
	if role == null or enemies.is_empty():
		scene.queue_free()
		await get_tree().process_frame
		return false
	role.attack_range = "range"  # 固定用例条件，不依赖职业表未来的平衡调整
	var target: Combatant = enemies[0]
	var target_view: BattleScene.UnitView = scene._views[target.uid]
	var before_ratio := target_view._hp_ratio
	var amount := mini(20, maxi(target.hp - 1, 1))
	target.hp -= amount
	scene._on_event({"t": "basic", "src": role.uid, "uid": target.uid})
	scene._on_event({"t": "dmg", "src": role.uid, "uid": target.uid,
		"amount": amount, "crit": false, "dot": false})
	scene._sync_views()
	var key := "%d:%d" % [role.uid, target.uid]
	var launched := scene._ranged_waiting.has(key) and target_view._hp_hold_count > 0 \
		and is_equal_approx(target_view._hp_ratio, before_ratio)
	await get_tree().create_timer(0.5).timeout
	var arrived := target_view._hp_hold_count == 0 \
		and target_view._hp_ratio < before_ratio and scene._ranged_waiting.is_empty()
	scene.queue_free()
	await get_tree().process_frame
	return launched and arrived


func _run_contact_presentation() -> bool:
	var ok := true
	for mode in ["classic_inline", "default"]:
		BattleScene.pending_cfg = {"ally":{"role_id":"zs","level":20,"traits":[]},
			"enemy":{"theme":"forest","node_type":"normal","lead_mon":"mon_wolf","solo":true},
			"presentation":mode,"seed":417}
		var scene := _spawn()
		scene.speed = 0
		await get_tree().process_frame
		var role := scene.sim.role_unit()
		var target: Combatant = scene.sim.alive_units("enemy")[0]
		var actor: BattleScene.UnitView = scene._views[role.uid]
		var enemy: BattleScene.UnitView = scene._views[target.uid]
		ok = ok and actor.position.x < enemy.position.x
		var before := target.hp
		target.hp -= 5
		scene._on_event({"t":"basic","src":role.uid,"uid":target.uid})
		scene._on_event({"t":"dmg","src":role.uid,"uid":target.uid,"amount":5,"crit":false,"dot":false})
		scene._sync_views()
		ok = ok and enemy._hp_hold_count > 0 and is_equal_approx(enemy._hp_ratio,float(before)/target.get_max_hp())
		await get_tree().create_timer(.20).timeout
		var contact := actor.position+actor.body.position
		ok = ok and contact.x > actor.position.x+95 and contact.distance_to(enemy.position+enemy._body_home)<65
		ok = ok and enemy._hp_hold_count == 0 and scene._fx_layer.get_child_count()>0
		await get_tree().create_timer(.42).timeout
		ok = ok and actor.body.position.is_equal_approx(actor._body_home) and scene._ranged_waiting.is_empty()
		# An AOE creates several feedback callbacks, while one motion still returns to its home.
		scene._on_event({"t":"cast","uid":role.uid,"skill":"zs_huifeng"})
		for i in 3:
			scene._on_event({"t":"dmg","src":role.uid,"uid":target.uid,"amount":2,"crit":false,"dot":false})
		await get_tree().create_timer(.65).timeout
		ok = ok and enemy._hp_hold_count == 0 and actor.body.position.is_equal_approx(actor._body_home) and scene._ranged_waiting.is_empty()
		scene.queue_free()
		await get_tree().process_frame
	return ok


func _texts(root: Node, out: Array = []) -> Array:
	for c in root.get_children():
		if c is Label:
			out.append(String((c as Label).text))
		_texts(c, out)
	return out


func _run_one(theme: String, node_type: String, layer: int, strong: bool) -> Dictionary:
	var lv := 15 if strong else 5
	var traits: Array = ["tr_atk_up_m", "tr_bleed_1", "tr_bleed_2", "tr_deep_wound"] if strong else []
	var pet := "pet_emberling" if strong else "pet_rockturtle"
	BattleScene.pending_cfg = {
		"ally": {"role_id": "zs", "level": lv, "traits": traits,
			"active_pet": pet, "bench_pet": "pet_thunderhawk", "potions": 2},
		"enemy": {"theme": theme, "node_type": node_type, "layer": layer},
		"seed": 7,
	}
	return await _drive(2400)


func _run_flee() -> Dictionary:
	BattleScene.pending_cfg = {
		"ally": {"role_id": "fs", "level": 5, "traits": [], "potions": 1},
		"enemy": {"theme": "snow", "node_type": "boss", "layer": 3},
		"seed": 3,
	}
	var scene: BattleScene = _spawn()
	scene.sim.finished = true   # 模拟点击"撤退"（强制判负）
	scene.sim.result = "defeat"
	return await _drive(120, scene)


## 打击反馈专项：造一场战斗，手工喂事件，检查顿帧/震屏/提示/战报/低血层挂点
func _run_feedback() -> Dictionary:
	var out := {"hitstop_on": false, "hitstop_off": false, "shake_moved": false,
		"shake_reset": false, "enemy_tip": false, "tip_text": "", "best_hit": 0,
		"dmg_in": 0, "danger_ok": false}
	BattleScene.pending_cfg = {
		"ally": {"role_id": "zs", "level": 5, "traits": [],
			"active_pet": "pet_rockturtle", "potions": 2},
		"enemy": {"theme": "forest", "node_type": "normal", "layer": 1},
		"seed": 11,
	}
	var scene: BattleScene = _spawn()
	scene.speed = 0.0   # 冻住 sim：本用例只验表现层，免得真实伤害持续插进来干扰断言
	await get_tree().process_frame
	var role := scene.sim.role_unit()
	var enemy_uid := -1
	for u in scene.sim.units:
		if u.side == "enemy":
			enemy_uid = u.uid
			break
	if role == null or enemy_uid < 0:
		scene.queue_free()
		return out

	# 敌方施法必须读得出来
	scene.call("_on_event", {"t": "cast_start", "uid": enemy_uid, "skill": "boss_slam", "name": "震地"})
	var tip: Label = scene.get("_cast_tip")
	out["tip_text"] = tip.text if tip != null else ""
	out["enemy_tip"] = out["tip_text"].contains("敌方") or out["tip_text"].contains("首领技")

	# 一次重击：顿帧 + 震屏 + 计入战报
	scene.call("_on_event", {"t": "dmg", "src": role.uid, "uid": enemy_uid,
		"amount": 999, "crit": true, "dot": false})
	out["hitstop_on"] = float(scene.get("_hitstop")) > 0.0
	out["best_hit"] = int(scene.get("_best_hit"))
	await get_tree().process_frame
	var shake_root: Control = scene.get("_shake_root")
	out["shake_moved"] = shake_root != null and shake_root.position != Vector2.ZERO

	# 我方挨打：计入承伤
	scene.call("_on_event", {"t": "dmg", "src": enemy_uid, "uid": role.uid,
		"amount": 7, "crit": false, "dot": false})
	out["dmg_in"] = int(scene.get("_dmg_in"))

	# 低血层挂点：必须是根节点的直接子级，不能混进飘字层
	var danger: TextureRect = scene.get("_danger")
	var fx: Control = scene.get("_fx_layer")
	out["danger_ok"] = danger != null and fx != null and danger.get_parent() == scene

	for i in 60:
		await get_tree().process_frame
	out["shake_reset"] = shake_root != null and shake_root.position == Vector2.ZERO
	out["hitstop_off"] = float(scene.get("_hitstop")) <= 0.0
	scene.queue_free()
	await get_tree().process_frame
	return out


func _spawn() -> BattleScene:
	var packed: PackedScene = load("res://src/battle/BattleScene.tscn")
	_check(packed != null, "BattleScene.tscn 应可加载")
	var scene: BattleScene = packed.instantiate()
	scene.speed = 12.0
	add_child(scene)
	return scene


func _drive(max_frames: int, scene: BattleScene = null) -> Dictionary:
	if scene == null:
		scene = _spawn()
	var out := {"finished": false, "result": "", "fx_left": -1, "views": 0}
	scene.battle_finished.connect(func(result: String, hp: int):
		out["finished"] = true
		out["result"] = result)
	var frames := 0
	while not out["finished"] and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	# 结算浮层出现的下一帧
	await get_tree().process_frame
	var fx_layer: Control = scene.get("_fx_layer")
	out["fx_left"] = fx_layer.get_child_count() if fx_layer != null else -1
	var field: Node2D = scene.get("_field")
	out["views"] = field.get_child_count() if field != null else 0
	# 程序化点击"继续"
	scene.confirm_result()
	await get_tree().process_frame
	scene.queue_free()
	await get_tree().process_frame
	return out
