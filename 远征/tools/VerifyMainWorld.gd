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
	_check(String(cfg.get("background", "")).ends_with("lorin_wilds_reference_v4.png"),
		"主地图应实际接入参考画风地表")
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
	_check(map._monsters.size() == 4, "昭元边城道路两侧应生成 4 个明雷")
	_check(map._city_content != null and map._city_content._buildings.size() == G.city_buildings().size(),
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
	_check(map._sprint_btn != null and map._sprint_btn.size.x >= 44.0
		and map._sprint_btn.size.y >= 44.0 and map._sprint_btn.position.y > 650.0,
		"疾行入口应收在屏幕下方且保留触控热区")
	_check(map._main_story_l != null and map._main_story_l.get_parent().position.y >= 136.0,
		"主城主线签应避开城务委托签")
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
	_check(map._player_name_l != null and map._player_name_l.text == "测试侠客  Lv5",
		"人物头上应显示创角昵称和等级")
	G.account = "游客"
	map._refresh_hud()
	_check(map._player_name_l.text == "测试侠客  Lv5", "游客应显示创角昵称")
	G.account = "登录侠客"
	map._refresh_hud()
	var first_mon = map._monsters[0]
	_check(first_mon.wander_only and first_mon.mon_id == "mon_zombie" \
		and first_mon.display_level == 2 \
		and first_mon.level_l != null and first_mon.level_l.text.begins_with("Lv2 "),
		"边城怪物应显示固定二级且只游荡")
	_check(first_mon._sprite != null and first_mon._sprite.texture != null,
		"主地图明雷应使用配置的怪物形象")
	var edge_mon = map._monsters[3]
	var edge_x: float = edge_mon.get_global_transform_with_canvas().origin.x
	_check(edge_x < 0.0 or edge_x > map.get_viewport_rect().size.x,
		"道路外侧明雷在当前镜头下应处于屏外")
	edge_mon._clamp_label()
	_check(not edge_mon.level_l.visible,
		"怪物本体离屏后等级名签不能孤立钳在屏缘")
	first_mon.position = map._player.position + Vector2(90, 0)
	first_mon._physics_process(0.016)
	_check(first_mon._state == "wander", "主世界怪物靠近玩家时不应进入追击")
	_check(map._map_cfg.get("map_cols") == 20 and map._map_cfg.get("map_rows") == 26,
		"主地图行走范围应缩到 20×26 格")
	_check(is_equal_approx(map._player_anim.scale.x, 0.66), "主地图旅人应采用当前同屏样板比例")
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
		_check(map._main_gold_l.text == str(int(G.wallet.get("gold", 0))),
			"战利入账后主世界金币牌应立即刷新")
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
	_check(map._monsters.size() == 3, "刷新时间前重进主城不应复活")
	map._main_respawn_at["0"] = Time.get_unix_time_from_system() - 1.0
	map._player.position = map._main_spawn_slots[0]["position"]
	map._tick_main_respawns(1.1)
	_check(map._monsters.size() == 3, "玩家贴近刷新点时不应突然刷怪")
	map._player.position = Vector2(100, 1150)
	map._tick_main_respawns(1.1)
	_check(map._monsters.size() == 4, "刷新时间到后离开玩家身边应重新出现明雷")

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

	# P05-C 回放曾在这一条真实入口报错：观察上报有进度后，地图提示调用了
	# 不存在的 G.side_row。必须起一张断碑坡图、已接支线并实际调用观察回调。
	G.prog["act1"] = {}
	G.prog["main_world"] = {"map_id": "broken_slope"}
	var beast_accept := G.side_accept("a1_elite_beast")
	_check(bool(beast_accept.get("ok", false)), "可选首领观察测试应先接取路西兽影")
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "broken_slope", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var slope := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(slope)
	await get_tree().process_frame
	slope.on_optional_boss_seen("mon_lost_beast")
	_check(G.side_status_of("a1_elite_beast") == QuestService.SIDE_READY
		and slope._toast_lbl != null and slope._toast_lbl.text.contains("路西兽影"),
		"靠近失路兽观察后应推进已接支线并显示标题提示，不得脚本报错")
	slope.queue_free()
	await get_tree().process_frame

	# P05-E：主城同屏 NPC 名牌若与玩家名牌碰撞，应临时收起；
	# 玩家走开后立即恢复，实体与交互仍在。
	G.prog["main_world"] = {"map_id": "lorin_wilds", "layout_version": 3,
		"position": [480, 930]}
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var label_map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(label_map)
	await get_tree().process_frame
	var label_city := label_map._city_content as CityScene
	var stable_npc: Node2D = null
	for npc_v in label_city._npcs:
		if String((npc_v as Node2D).get("data").get("id", "")) == "npc_stablemaster":
			stable_npc = npc_v as Node2D
			break
	_check(stable_npc != null, "主城应有马厩 NPC 可供名牌避让检查")
	if stable_npc != null:
		label_map._player.position = Vector2(480, 930)
		label_city._check_interact()
		_check(not bool(stable_npc.get("label_near")),
			"玩家与马伯名牌相撞时，应优先保留玩家名牌")
		label_map._player.position = Vector2(480, 980)
		label_city._check_interact()
		_check(bool(stable_npc.get("label_near")),
			"名牌分开后，马伯名牌应恢复")
	label_map.queue_free()
	await get_tree().process_frame

	# P05-D4：真实主世界实例上马后改四向图与碰撞脚点；接战自动下马。
	G.prog["mounts"] = {"owned": {"horse": 1}, "active": "horse", "riding": true}
	G.prog["main_world"] = {"map_id": "lorin_wilds", "layout_version": 3,
		"position": [480, 930]}
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var mounted := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(mounted)
	await get_tree().process_frame
	_check(mounted._mount_anim != null and mounted._mount_anim.visible
		and not mounted._player_anim.visible
		and mounted._mount_btn != null and mounted._mount_btn.visible
		and (mounted._player_shape.shape as RectangleShape2D).size == Vector2(42, 28),
		"主世界骑乘须显示四向马、隐藏步行人物并扩大窄路碰撞盒")
	_check(mounted._mount_clearance(), "主街空地应允许上马")
	var toggle_slot := Audio.sfx_slot()
	mounted._toggle_mount()
	_check(not G.mount_riding() and not mounted._mount_anim.visible,
		"骑乘按钮应能下马并立即更新外观")
	_check(Audio.sfx_slot() == (toggle_slot + 1) % Audio.sfx_player_count(),
		"下马应播放专属音效")
	mounted._toggle_mount()
	_check(G.mount_riding() and mounted._mount_anim.visible,
		"骑乘按钮应能再次上马并立即更新外观")
	var hoof_slot := Audio.sfx_slot()
	mounted._tick_mount_hoof(0.016, Vector2(100, 0))
	_check(Audio.sfx_slot() == (hoof_slot + 1) % Audio.sfx_player_count(),
		"骑行产生实际位移时应有低音量落蹄反馈")
	hoof_slot = Audio.sfx_slot()
	mounted._tick_mount_hoof(0.016, Vector2.ZERO)
	_check(Audio.sfx_slot() == hoof_slot,
		"骑乘静止时不应循环播放落蹄")
	if not mounted._monsters.is_empty():
		mounted._start_battle(mounted._monsters[0])
		_check(not G.mount_riding() and not mounted._mount_anim.visible
			and mounted._player_anim.visible
			and (mounted._player_shape.shape as RectangleShape2D).size == Vector2(30, 26),
			"接触明雷后应先下马，战斗前恢复步行脚点与碰撞盒")
	mounted.queue_free()
	await get_tree().process_frame

	# 修碑前后同一北口路牌的文字与色态必须随存档世界旗重建。
	G.prog["flags"] = {"act1_stele_repaired": false}
	G.prog["main_world"] = {"map_id": "broken_slope"}
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "broken_slope", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var gate_before := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(gate_before)
	await get_tree().process_frame
	var sealed_gate := false
	for child in gate_before._world.get_children():
		var style_v: Variant = child.get("gate_style")
		if style_v is String and style_v == "sealed":
			sealed_gate = true
			_check(child.position.y >= 200.0, "北口路牌要站在手机状态栏下方")
	_check(sealed_gate, "修碑前北口路牌应是灰石色态")
	gate_before.queue_free()
	await get_tree().process_frame
	G.prog["flags"] = {"act1_stele_repaired": true}
	G.prog["act1"] = {"repair_method": "forge"}
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "broken_slope", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var gate_after := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(gate_after)
	await get_tree().process_frame
	var restored_gate := false
	for child in gate_after._world.get_children():
		var style_v2: Variant = child.get("gate_style")
		if style_v2 is String and style_v2 == "restored":
			restored_gate = String(child.get("caption")).contains(G.restored_stele_name())
	_check(restored_gate, "修碑后北口应转暖金并显示图志中相同的碑名")
	gate_after.queue_free()
	await get_tree().process_frame

	# P05-E：在离屏逻辑视口复现 720×1600 的宽度归一化比例（480×1067）。
	# 直接量运行时 HUD 与同图战斗，不以桌面窗口截图高度冒充手机长屏。
	var tall_view := SubViewport.new()
	tall_view.size = Vector2i(480, 1067)
	tall_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(tall_view)
	G.prog["main_world"] = {"map_id": "lorin_wilds", "layout_version": 3,
		"position": [480, 930]}
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var tall_map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	tall_view.add_child(tall_map)
	await get_tree().process_frame
	_check(absf(tall_map._joy.position.y - 891.0) < 1.0
		and absf(tall_map._pet_btn.position.y - 941.0) < 1.0
		and absf(tall_map._sprint_btn.position.y - 999.0) < 1.0,
		"长屏主世界摇杆与拇指按钮应留在视口底缘")
	if not tall_map._monsters.is_empty():
		tall_map._start_battle(tall_map._monsters[0])
		await get_tree().process_frame
		_check(tall_map._battle != null
			and absf(tall_map._battle._field.position.y - 267.0) < 1.0
			and absf(tall_map._battle._cmd_info_l.position.y - 830.0) < 1.0,
			"长屏同图战斗人物与指令条应跟随视口下移")
	tall_view.queue_free()
	await get_tree().process_frame
