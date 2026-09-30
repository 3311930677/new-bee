extends Node

var _fails := 0

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_port_growth.json"
	for choice in ["remember", "promise"]:
		G._init_state_defaults()
		G.save_locked = false
		G.selected_role = "zs"
		G.wallet["gold"] = 2000
		_check(not bool(G.port_relation_choice(choice)["ok"]), "关系支线需要第二幕回港")
		G.prog["story"] = {"step": "s21", "done": ["s12", "s13", "s14", "s15", "s16", "s17", "s18", "s19", "s20"], "goals": {}}
		var run := RunState.new()
		run.setup({"theme": "forest", "role_id": "zs", "level": 12, "seed": 733})
		MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "shenyuan_port", "run": run,
			"node": {"type": "normal", "layer": 0, "index": 0}}
		var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
		add_child(map)
		await get_tree().process_frame
		map._city_content._open_port_relation()
		_check(map._city_content._panel != null and map._modal_open(), "关系面板冻结地图接战")
		_check(bool(G.port_relation_choice(choice)["ok"]) and G.item_count("gem_def_1") == 1,
			"两项等值选择应发出首颗港口宝石")
		_check(String(G.prog["flags"]["act2_shenlan_relation_choice"]) == choice,
			"关系选择永久记忆")
		_check(not bool(G.port_relation_choice(choice)["ok"]) and G.item_count("gem_def_1") == 1,
			"谈话重放不能重复发石头")
		_check(G.reload_save() and int(G.prog["flags"]["act2_shenlan_relation_stage"]) == 1,
			"关系与宝石可读档")
		G.ensure_starter_equip(true)
		var before := G.growth_bonuses()
		var gold_before := int(G.wallet["gold"])
		_check(bool(G.equip_socket_gem("armor", "gem_def_1")["ok"]) and G.item_count("gem_def_1") == 0
			and int(G.wallet["gold"]) == gold_before - G.equip_socket_cost(), "首石镶嵌真实护甲并扣公开费用")
		_check(float(G.growth_bonuses().get("def_add", 0)) == float(before.get("def_add", 0)) + 2,
			"镶嵌防御增加2")
		for role in ["zs", "ck", "fs", "fz"]:
			G.selected_role = role
			var without := BattleSim.new()
			without.setup(93, {"role_id": role, "level": 12, "traits": [], "growth": before}, {"theme": "forest", "node_type": "normal", "layer": 1})
			var with_gem := BattleSim.new()
			with_gem.setup(93, {"role_id": role, "level": 12, "traits": [], "growth": G.growth_bonuses()}, {"theme": "forest", "node_type": "normal", "layer": 1})
			_check(with_gem.role_unit().base_def == without.role_unit().base_def + 2, "四职业战斗实际获得宝石防御：" + role)
		G.selected_role = "zs"
		var uid := int(G.equip_state("armor")["uid"])
		_check(G.reload_save() and (G.equip_state("armor")["gems"] as Array).has("gem_def_1"), "镶嵌持久化")
		gold_before = int(G.wallet["gold"])
		_check(bool(G.inv_gem_pop(uid, 0)["ok"]) and G.item_count("gem_def_1") == 1
			and int(G.wallet["gold"]) == gold_before, "低成本拆回且不复制")
		_check(G.reload_save() and (G.equip_state("armor")["gems"] as Array).is_empty()
			and G.item_count("gem_def_1") == 1, "拆回持久化")
		G.items["gem_def_1"] = 3
		var snap_prog := G.prog.duplicate(true)
		var snap_items := G.items.duplicate(true)
		var snap_wallet := G.wallet.duplicate(true)
		G.save_locked = true
		_check(not bool(G.equip_socket_gem("armor", "gem_def_1")["ok"])
			and not bool(G.inv_gem_pop(uid, 0)["ok"])
			and not bool(G.inv_gem_merge("gem_def_1")["ok"])
			and G.prog == snap_prog and G.items == snap_items and G.wallet == snap_wallet, "存档锁定拦截所有宝石操作")
		G.save_locked = false
		map.queue_free()
		await get_tree().process_frame
	print("PORT_GROWTH_OK" if _fails == 0 else "PORT_GROWTH_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
