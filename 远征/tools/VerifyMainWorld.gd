# VerifyMainWorld.gd —— 新主城纵切：旧城内容、明雷刷新、同图战斗与安全返回。
extends Node

var _fails := 0
var _last_result := ""


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_main_world.json"
	G.prog["main_world"] = {"map_id": "lorin_wilds"}
	G.prog["level"] = 5
	G.prog["exp"] = 10
	G.account = "登录侠客"
	G.player_name = "测试侠客"
	await _run()
	if _fails == 0:
		print("MAIN_WORLD_OK map=lorin_wilds")
	else:
		print("MAIN_WORLD_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	var cfg := TableCache.main_world_map("lorin_wilds")
	_check(not cfg.is_empty(), "洛林郊野配置应存在")
	_check(ResourceLoader.exists(String(cfg.get("background", ""))), "草地主地图背景应存在")
	_check(ResourceLoader.exists(String(cfg.get("monster_sprite", ""))),
		"主地图怪物像素形象应存在")
	_check(not TableCache.get_monster("mon_zombie").is_empty(), "主地图僵尸战斗数据应存在")
	_check(String(cfg.get("background", "")).ends_with("lorin_wilds_grass_v2.png"),
		"主地图应使用新版细节底图")
	var ground_tex := load(String(cfg.get("background", ""))) as Texture2D
	if ground_tex != null:
		var screen_pixel_scale := float(int(cfg.get("map_cols", 20)) * 48) \
			/ float(ground_tex.get_width()) * float(cfg.get("camera_zoom", 1.0))
		_check(screen_pixel_scale <= 1.1, "主地图底图不能在屏幕上明显放大")
	var run := RunState.new()
	run.setup({"theme": "forest", "role_id": "zs", "level": 5,
		"active_pet": "pet_rockturtle", "bench_pet": "", "potions": 2, "seed": 19})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	map.map_finished.connect(func(result: String): _last_result = result)
	add_child(map)
	await get_tree().process_frame
	_check(map._player.position == Vector2(480, 930), "首次进入应从主路空地出生")
	_check(map._mode == "main_world", "应进入 main_world 模式")
	_check(map._main_map_id == "lorin_wilds", "主地图 id 应保留")
	_check(map._monsters.size() == 6, "洛林郊野应生成 6 个明雷")
	_check(map._city_content != null and map._city_content._buildings.size() == 8,
		"新主城应迁入原主城全部建筑")
	_check(map._city_content._npcs.size() >= G.city_npcs().size(),
		"新主城应迁入常驻 NPC 和今日访客")
	for building in map._city_content._buildings:
		_check(building.position.x <= 330.0 or building.position.x >= 630.0,
			"主城店铺应分列中间道路两侧")
	for citizen in map._city_content._npcs:
		_check(citizen.position.x <= 400.0 or citizen.position.x >= 560.0,
			"主城 NPC 应站在道路左右两侧")
	_check(map._city_content._quest_chip != null,
		"新主城应保留委托快捷入口")
	_check(map._potion_badge != null and map._potion_badge.text == str(run.potions),
		"药瓶图标应显示剩余数量")
	_check(map._pet_btn != null and map._pet_btn.get_child(1) is Sprite2D \
		and map._pet_btn.get_child(1).texture != null,
		"换宠入口应显示宠物图标")
	map._city_content._check_interact()
	_check(not map._city_content._npcs[0].label_near,
		"远处 NPC 名签应隐藏，避免遮住主城视野")
	map._player.position = map._city_content._npcs[0].position + Vector2(70, 0)
	map._city_content._check_interact()
	_check(map._city_content._npcs[0].label_near,
		"走近 NPC 时名签应出现")
	map._player.position = map._city_content._buildings[0].position + Vector2(120, 0)
	map._city_content._check_interact()
	_check(map._city_content.has_modal() and map._modal_open(),
		"从路边走近店铺应打开原面板并暂停接战")
	map._city_content._close_panel()
	map._player.position = Vector2(480, 930)
	_check(map._main_level_l != null and map._main_level_l.text == "Lv5",
		"主地图左上应显示角色等级")
	_check(map._main_exp_l != null and map._main_exp_l.text.begins_with("EXP "),
		"主地图左上应显示真实经验进度")
	_check(map._player_name_l != null and map._player_name_l.text == "登录侠客  Lv5",
		"人物头上应显示本次登录账号和等级")
	G.account = "游客"
	map._refresh_hud()
	_check(map._player_name_l.text == "测试侠客  Lv5", "游客应显示创角昵称")
	G.account = "登录侠客"
	map._refresh_hud()
	var first_mon = map._monsters[0]
	_check(first_mon.wander_only and first_mon.mon_id == "mon_zombie" \
		and first_mon.display_level == 7 \
		and first_mon.level_l != null and first_mon.level_l.text.begins_with("Lv7 "),
		"主世界怪物应显示等级且只游荡")
	_check(first_mon._sprite != null and first_mon._sprite.texture != null,
		"主地图明雷应使用配置的怪物形象")
	first_mon.position = map._player.position + Vector2(90, 0)
	first_mon._physics_process(0.016)
	_check(first_mon._state == "wander", "主世界怪物靠近玩家时不应进入追击")
	_check(map._map_cfg.get("map_cols") == 20 and map._map_cfg.get("map_rows") == 26,
		"主地图行走范围应缩到 20×26 格")
	_check(is_equal_approx(map._player_anim.scale.x, 0.54), "主地图旅人应按参考录屏比例控制占屏")
	var player_camera: Camera2D
	for child in map._player.get_children():
		if child is Camera2D:
			player_camera = child as Camera2D
	_check(player_camera != null and is_equal_approx(player_camera.zoom.x, 1.15),
		"主地图镜头应避免放大底图像素")
	_check(map._pickups.is_empty() and map._spots.is_empty(), "主地图不应混入历练拾取与祭坛")
	var has_background := false
	var tile_layers := 0
	for child in map.get_children():
		if child is TextureRect and (child as TextureRect).texture != null:
			has_background = true
		if child is TileMapLayer:
			tile_layers += 1
	_check(has_background, "主地图应铺设新加入的整图背景")
	_check(tile_layers == 0, "主地图不应继续叠历练随机地砖")

	var before_gold := int(G.wallet.get("gold", 0))
	map._player.position = Vector2(390, 900)
	first_mon.position = map._player.position + Vector2(20, 0)
	first_mon._physics_process(0.016)
	_check(map._battle != null and map._battle._classic_presentation(), "明雷应进入同图经典战斗表现")
	if map._battle != null:
		_check(map._battle.sim.alive_units("enemy").size() == 1,
			"主世界接触一只明雷应只与该怪交战")
		var enemy: Combatant = map._battle.sim.alive_units("enemy")[0]
		_check(enemy.base_max_hp > int((TableCache.get_monster("mon_zombie").get("base", {}) as Dictionary).get("hp", 0)),
			"主世界明雷的实际战斗属性应随显示等级成长")
		_check(String((map._battle._cfg.get("enemy", {}) as Dictionary).get("sprite_path", "")) \
			== String(cfg.get("monster_sprite", "")), "战斗形象应与地图怪物一致")
		map._battle.sim.finished = true
		map._battle.sim.result = "victory"
		map._battle.confirm_result()
		await get_tree().process_frame
		_check(map._battle == null, "战斗结束后覆盖层应卸载")
		_check(map._picker == null, "主世界胜利不应弹历练词条")
		_check(run.gold == 0 and int(G.wallet.get("gold", 0)) > before_gold,
			"主世界战利应立即入钱包")
		_check(map._city_content._stat_lbl.text == str(int(G.wallet.get("gold", 0))),
			"战利入账后主城金币牌应立即刷新")
	var saved: Dictionary = G.prog.get("main_world", {})
	_check(float((saved.get("respawn_at", {}) as Dictionary).get("0", 0.0)) > Time.get_unix_time_from_system(),
		"胜利后应保存明雷的刷新时间")
	_check((saved.get("position", []) as Array) == [390, 900], "战利落袋时应同时保存所在坐标")
	_check(int(saved.get("layout_version", 0)) == 3, "新出生点应标记布局版本")
	map.queue_free()
	await get_tree().process_frame
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	map = (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	map.map_finished.connect(func(result: String): _last_result = result)
	add_child(map)
	await get_tree().process_frame
	_check(map._player.position == Vector2(390, 900), "回到主地图应从离开位置继续")
	_check(map._monsters.size() == 5, "刷新时间前重进主城不应复活")
	map._main_respawn_at["0"] = Time.get_unix_time_from_system() - 1.0
	map._player.position = Vector2(480, 790)
	map._tick_main_respawns(1.1)
	_check(map._monsters.size() == 5, "玩家贴近刷新点时不应突然刷怪")
	map._player.position = Vector2(100, 1150)
	map._tick_main_respawns(1.1)
	_check(map._monsters.size() == 6, "刷新时间到后离开玩家身边应重新出现明雷")

	map._player.position = map._portal.position
	map._check_portal()
	_check(not map._map_done, "主城不应通过历练传送阵退出")
	map._finish_map("exited")
	_check(map._map_done and _last_result == "exited", "回营应安全结束主城地图")
	_check(String((G.prog.get("main_world", {}) as Dictionary).get("map_id", "")) == "lorin_wilds",
		"主地图位置应写入存档进度")
	map.queue_free()
	await get_tree().process_frame
	G.prog["main_world"] = {"map_id": "lorin_wilds", "position": [768, 1700]}
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	map = (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	_check(map._player.position.distance_to(Vector2(480, 1052.38)) < 1.0,
		"旧版主地图坐标应等比例迁移到缩小后的地图")
	map.queue_free()
	await get_tree().process_frame
	G.prog["main_world"] = {"map_id": "lorin_wilds", "layout_version": 2,
		"position": [480, 980]}
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	map = (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	_check(map._player.position == Vector2(480, 930),
		"旧档停在旧出生点时应迁入新主路出生点")
	map.queue_free()
	await get_tree().process_frame
