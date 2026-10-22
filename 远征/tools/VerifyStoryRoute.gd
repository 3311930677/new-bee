extends Node
## 验证跨图主线指引：主线目标在别的地图时，罗盘/自动前往指向下一步出口，而不是隐藏的传送阵。
## 用例：s08 目标在昭元边城，玩家站在失声碑窟 → 应指向碑窟南出口，名称「前往昭元边城」。
var fails := 0

func frames(count := 8) -> void:
	for i in count:
		await get_tree().process_frame

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)

func open_map(id: String) -> MapScene:
	var run := RunState.new()
	run.setup({"role_id": "zs", "theme": "forest", "level": 30, "potions": 2, "seed": 17})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": id, "run": run, "node": {"type": "normal", "layer": 0, "index": 0}}
	var map: MapScene = preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(map)
	await frames(12)
	return map

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/verify_story_route_save.json"
	G.set_meta("ui_review_mode", true)
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.prog.level = 30
	var done: Array = []
	for i in range(1, 8): done.append("s%02d" % i)
	G.prog["story"] = {"step": "s08", "done": done}
	check(String(G.story_current().get("map", "")) == "lorin_wilds", "s08 目标应在昭元边城")

	var cavern := await open_map("stele_cavern")
	var info: Dictionary = cavern._nav_info()
	print("ROUTE stele_cavern -> ", info)
	check(String(info.get("name", "")) == "前往昭元边城", "碑窟应提示前往昭元边城")
	check((info.get("pos", Vector2.ZERO) as Vector2).distance_to(Vector2(480, 1152)) < 4.0, "碑窟应指向南出口牌")
	check(String(info.get("kind", "")) != "portal", "主世界不应再指向隐藏传送阵")
	cavern.queue_free()
	await frames(6)

	var slope := await open_map("broken_slope")
	info = slope._nav_info()
	print("ROUTE broken_slope -> ", info)
	check(String(info.get("name", "")) == "前往昭元边城", "断碑坡应提示前往昭元边城")
	check((info.get("pos", Vector2.ZERO) as Vector2).y > 1000.0, "断碑坡应指向南出口（往枫林古道）")
	slope.queue_free()
	await frames(6)

	G.prog["story"] = {"step": "s01", "done": [], "goals": {}}
	var town := await open_map("lorin_wilds")
	var info_s01: Dictionary = town._nav_info()
	check(String(info_s01.get("kind", "")) == "quest", "同图主线 s01 应指向城内任务目标")
	check((info_s01.get("pos", Vector2.ZERO) as Vector2).distance_to(Vector2(480, 120)) > 100.0, "同图主线不应再退回隐藏传送阵")
	var goal_pt: Vector2 = info_s01.get("pos", Vector2(480, 720))
	var near_pt := goal_pt + Vector2(0, 20)
	check(town._illustrated_navigation.next_point(town, near_pt, goal_pt).distance_to(near_pt) > 1.0, "接近目标 20px 时寻路不应原地返回")
	town.queue_free()
	await frames(6)

	BattleScene.pending_cfg = {
		"presentation": "classic_inline",
		"player_name": "行旅人",
		"seed": 17,
		"ally": {"role_id": "zs", "level": 12, "active_pet": "", "bench_pet": "", "potions": 2},
		"enemy": {"theme": "forest", "node_type": "normal", "layer": 1, "display_level": 2}
	}
	var battle: BattleScene = preload("res://src/battle/BattleScene.tscn").instantiate()
	add_child(battle)
	await frames(4)
	battle.set_process(false)
	var enemies := battle._attackable_enemies()
	var hp0 := enemies[0].hp
	for i in 45:
		battle.sim.step()
	check(enemies[0].hp == hp0, "手动模式下未点击攻击不自动普攻")
	battle._command_switch_target()
	var f1 := battle.sim.role_focus_target_uid
	battle._command_switch_target()
	var f2 := battle.sim.role_focus_target_uid
	check(f1 >= 0 and f2 >= 0 and f1 != f2, "换目标按钮在敌人间循环切换")
	battle._select_enemy_target(enemies[0].uid, false)
	check(battle.sim.role_focus_target_uid == enemies[0].uid, "可直接点选锁定指定敌方目标")
	battle.set_process(true)
	battle.speed = 1.0
	battle._command_attack()
	check(battle.sim.role_focus_target_uid == enemies[0].uid and enemies[0].hp < hp0, "点击攻击对当前选定目标立即发动普攻且不乱跳目标")
	battle.queue_free()
	await frames(4)

	print("STORY_ROUTE_OK" if fails == 0 else "STORY_ROUTE_FAIL fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
