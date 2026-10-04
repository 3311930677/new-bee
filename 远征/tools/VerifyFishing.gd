extends Node

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_fishing.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "钓客"
	G.prog["story"] = {"step": "s17", "done": ["s12", "s13", "s14", "s15", "s16"], "goals": {}}
	await _run()
	print("FISHING_OK" if _fails == 0 else "FISHING_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	_check(G.res_tex("itm_fish_common") != null, "鲜鱼图标应接入运行时")
	_check((TableCache.fishing_config().get("spots", []) as Array).size() == 4,
		"应有四个独立地图钓点，包含霜关冷水")
	for row in (TableCache.fishing_config()["spots"] as Array):
		var id := String(row["id"])
		var iid := String(row["item"])
		_check(not String(row.get("environment_hint","")).is_empty(),"每个钓点有地区水情线索")
		var run := RunState.new()
		run.setup({"theme": "forest", "role_id": "zs", "level": 12, "seed": 413})
		MapScene.pending_cfg = {"mode": "main_world", "main_map_id": String(row["map"]),
			"run": run, "node": {"type": "normal", "layer": 0, "index": 0}}
		var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
		add_child(map)
		await get_tree().process_frame
		var ent: Node2D = null
		for candidate in map._quest_entities:
			if String(candidate.eid) == id:
				ent = candidate
		_check(ent != null, "地图应生成钓点：" + id)
		if ent == null:
			map.queue_free()
			continue
		map.on_quest_entity(ent)
		var panel := map._fishing_panel
		_check(panel != null and map._modal_open(), "钓鱼面板期间应冻结接战")
		if panel != null:
			panel._act()
			var token := String(panel._cast.get("token", ""))
			_check(panel._casting and not token.is_empty() and G.fishing_remaining(id) == 2,
				"抛竿应先预留一次并保存凭据")
			_check(G.reload_save(), "未收竿时存档应可重读")
			var resumed := G.fishing_begin(id)
			_check(bool(resumed.get("resumed", false))
				and String((resumed.get("cast", {}) as Dictionary).get("token", "")) == token
				and G.fishing_remaining(id) == 2, "重启同点接回一竿不能二次扣次数")
			panel._phase = float(panel._cast["center"])
			panel._act()
			_check(not panel._casting and G.item_count(iid) == 1,
				"绿色区域收竿应结算普通鱼")
			_check(not bool(G.fishing_finish(token, true).get("ok", false))
				and G.item_count(iid) == 1, "重放收竿凭据不能复制鲜鱼")
			var food := G.item_count("pet_food")
			panel._cook()
			_check(G.item_count(iid) == 0 and G.item_count("pet_food") == food + 1,
				"钓获应有制成伙伴粮的材料出口")
			panel.close()
			_check(map._fishing_panel == null and bool(ent.trade_cooled),
				"关闭面板后应保持离开再触发的冷静状态")
		for attempt in 2:
			var cast_res := G.fishing_begin(id)
			_check(bool(cast_res.get("ok", false)), "余下次数应可抛竿")
			var miss_token := String((cast_res.get("cast", {}) as Dictionary).get("token", ""))
			_check(bool(G.fishing_finish(miss_token, false).get("ok", false)), "脱钩应可结算")
		_check(G.fishing_remaining(id) == 0
			and not bool(G.fishing_begin(id).get("ok", false)) and G.item_count(iid) == 0,
			"三竿上限、失败无鱼、重开不可绕过次数")
		if id=="fish_frost_pool":
			# Fixture start on the public street; actual movement must open the new spot.
			map._player.position=Vector2(480,1080)
			for frame in 4:await get_tree().physics_frame
			Input.action_press("move_left")
			for frame in 240:
				if map._fishing_panel!=null:break
				await get_tree().physics_frame
			Input.action_release("move_left")
			_check(map._fishing_panel!=null,"霜关钓点可从公共街道用实际移动触发")
			if map._fishing_panel!=null:map._fishing_panel.close()
		map.queue_free()
		await get_tree().process_frame
	_check((G.fishing_state()["discoveries"] as Array).size() == 4,
		"四类普通鱼应记录永久图鉴")
	G.economy_state()["day"] = int(G.economy_state()["day"]) + 1
	_check(G.fishing_remaining("fish_port_pier") == 3
		and (G.fishing_state()["discoveries"] as Array).size() == 4,
		"翻日重置次数但保留鱼类图鉴")
	var locked_prog := G.prog.duplicate(true)
	var locked_items := G.items.duplicate(true)
	G.save_locked = true
	_check(not bool(G.fishing_begin("fish_port_pier").get("ok", false))
		and not bool(G.fishing_cook("fish_port").get("ok", false))
		and G.prog == locked_prog and G.items == locked_items,
		"存档锁定期间禁止预留和材料消耗")
	G.save_locked = false
	_check(G.save_game() and G.reload_save()
		and (G.fishing_state()["discoveries"] as Array).size() == 4,
		"钓鱼图鉴与重置状态应可持久化")

	var escape_panel := FishingPanel.new()
	for row in TableCache.fishing_config().spots:
		var id:=String(row.id)
		var flag:="fish_king_"+id
		G.prog.flags.erase(flag)
		G.economy_state().day=6+int(row.king_phase)
		_check(G.fishing_king_available(id),"每个鱼王由冻结的地区水情出现")
		var king_panel:=FishingPanel.new()
		add_child(king_panel)
		king_panel.open_spot(id)
		king_panel._act()
		_check(bool(king_panel._cast.king) and is_equal_approx(king_panel._band.size.x,57.6),"鱼王实际浮标区间收窄至16%")
		king_panel._phase=float(king_panel._cast.center)+.10
		king_panel._act()
		_check(not bool(G.prog.flags.get(flag,false)),"旧普通区间内但鱼王区间外收竿仍算脱钩")
		king_panel._act()
		var token:=String(king_panel._cast.token)
		var old_count:=G.item_count(String(row.item))
		_check(G.reload_save() and bool(G.fishing_begin(id).cast.king),"鱼王未收竿凭据可重读且不改变水情")
		king_panel._phase=float(king_panel._cast.center)
		king_panel._act()
		_check(bool(G.prog.flags.get(flag,false)) and G.item_count(String(row.item))==old_count+1,"鱼王只给一条鱼并永久记录")
		_check(not bool(G.fishing_finish(token,true).ok) and G.item_count(String(row.item))==old_count+1,"重放鱼王凭据不能重复奖励")
		king_panel.close()
		await get_tree().process_frame
	_check(G.save_game() and G.reload_save() and bool(G.prog.flags.get("fish_king_fish_frost_pool",false)),"鱼王图志跨读档保持")
	add_child(escape_panel)
	escape_panel.open_spot("fish_port_pier")
	var hits := {"closed": 0}
	escape_panel.closed.connect(func(): hits["closed"] += 1)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	G.ui_blocked = true
	escape_panel._unhandled_input(escape)
	_check(int(hits["closed"]) == 0, "控制台开启时不能关闭背后的钓鱼面板")
	G.ui_blocked = false
	escape_panel._unhandled_input(escape)
	_check(int(hits["closed"]) == 1, "钓鱼面板应自己处理ESC且只关闭一次")
