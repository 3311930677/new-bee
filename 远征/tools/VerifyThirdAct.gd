extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_third_act.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "双关行者"
	await _run()
	print("THIRD_ACT_OK" if _fails == 0 else "THIRD_ACT_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)


func _enter(map_id: String) -> MapScene:
	var run := RunState.new()
	run.setup({"theme": "forest", "role_id": "zs", "level": 12,
		"active_pet": "", "bench_pet": "", "potions": 2, "seed": 97})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": map_id,
		"run": run, "node": {"type": "normal", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	return map


func _run() -> void:
	var done: Array = []
	for i in range(1, 21): done.append("s%02d" % i)
	G.prog["story"] = {"step": "", "done": done, "goals": {}}
	G.wallet["gold"] = 777
	G.items = {"salt": 3, "tide_egg": 1}
	G.ensure_starter_equip(true)
	G.economy_state()["port_event"] = "embank"
	G.prog["flags"] = {"act2_port_choice": "embank", "act2_tide_gate_open": true}
	G.act1_state()["side_quests"] = {"a2_rel_rope": {"status": "done", "choice": "replace"}}
	G.prog["main_world"] = {"map_id": "shenyuan_port", "position": [480, 900],
		"positions_by_map": {"lorin_wilds": [480, 930]}}
	var before := G.prog.duplicate(true)
	var wallet := G.wallet.duplicate(true)
	var items := G.items.duplicate(true)
	_check(String(G.story_current().get("id", "")) == "s21", "旧第二幕空 step 应续接 s21")
	_check(G.prog["story"]["done"] == done and G.wallet == wallet and G.items == items,
		"续接不得重发已完成奖励或改物品")
	for key in before:
		if key != "story": _check(G.prog[key] == before[key], "旧档字段必须保留：" + String(key))
	_check(String(G.story_current().get("id", "")) == "s21", "重复归一不倒退")
	_check(TableCache.city_config_for("red_sand_route").is_empty(), "野外不应加载边城配置")
	_check(not G.city_npc("npc_frost_envoy").is_empty(), "驿使配置应可供对话查询")
	# 锁门用实际地图检测，不能通过路牌偷渡。
	G.prog["story"] = {"step": "s20", "done": done.slice(0, 19), "goals": {}}
	var port := await _enter("shenyuan_port")
	port._player.position = Vector2(480, 96)
	port._check_world_exits()
	_check(not port._map_done and port._city_content._panel == null, "未接信前港北出口应拦住")
	G.prog["story"] = {"step": "s21", "done": done, "goals": {}}
	port._city_content._open_dialog(G.city_npc("npc_harbormaster"), false)
	_check(G.story_step_done("s21") and G.item_count("frost_letter") == 1,
		"接信必须走真实 NPC 对话，不能被港务服务截走")
	port._city_content._close_panel()
	port.queue_free()
	await get_tree().process_frame
	var route := await _enter("red_sand_route")
	_check(G.story_step_done("s22") and route._monsters.size() == 4,
		"商路到访应推进，且存在可接战明雷")
	route.queue_free()
	await get_tree().process_frame
	var post := await _enter("frost_post")
	_check(post._monsters.is_empty() and post._city_content != null, "霜关驿应是安全城镇")
	var city: CityScene = post._city_content
	_check(city._npcs.size() == 3 and city._buildings.size() == 3,
		"驿站应有三名居民和三栋已落成建筑")
	_check(city._quest_lbl.text.ends_with("采买物资") and not city._quest_lbl.text.contains("今日委托"), "驿站快捷入口应显示真实本地服务")
	for npc in city._npcs:
		for b in city._buildings:
			_check(b.built(), "驿站建筑须可交互")
			var shape := b.get_child(0) as CollisionShape2D
			var footprint := Rect2(b.position + shape.position - (shape.shape as RectangleShape2D).size * 0.5,
				(shape.shape as RectangleShape2D).size)
			_check(not footprint.grow(4).has_point(npc.position), "居民脚点不得落入建筑碰撞")
	post._player.position = Vector2(864, 710)
	post._check_world_exits()
	_check(not post._map_done, "交信前矿道应锁定")
	G.items.erase("frost_letter")
	city._open_dialog(G.city_npc("npc_frost_envoy"), false)
	_check(not G.story_step_done("s23"), "缺信件不得交付")
	city._close_panel()
	G.items["frost_letter"] = 1
	city._open_dialog(G.city_npc("npc_frost_envoy"), false)
	_check(G.story_step_done("s23") and G.item_count("frost_letter") == 0,
		"驿使对话应交信并开放矿道")
	city._close_panel()
	city._built_action("shop")
	_check(city._overlay != null, "驿站物资铺应打开现有真实商店")
	city._close_overlay()
	post.queue_free()
	await get_tree().process_frame
	var mine := await _enter("rift_mine_road")
	await get_tree().physics_frame
	# 按真实回放的输入路径采样玩家碰撞形状；不以表里的保留区代替碰撞证据。
	var sample := Vector2(480, 550)
	var space := mine._player.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = mine._player_shape.shape
	query.collision_mask = 2
	while sample.x > 110:
		query.transform = Transform2D(0, sample)
		_check(space.intersect_shape(query).is_empty(), "矿车返驿通道应没有实体碰撞：" + str(sample))
		sample.x -= 12
		sample.y = minf(710, sample.y + 12)
	var cart: Node2D = null
	for entity in mine._quest_entities:
		if String(entity.eid) == "overturned_mine_cart": cart = entity
	_check(cart != null and mine._monsters.size() == 4, "矿道必须有真实矿车目标和敌影")
	if cart != null: mine.on_quest_entity(cart)
	_check(G.story_step_done("s24") and G.item_count("mine_record") == 1,
		"矿车记录必须进真实库存，留待后段交付")
	var after := G.wallet.duplicate(true)
	_check(G.story_event("collect", "overturned_mine_cart", "rift_mine_road").is_empty()
		and G.wallet == after, "反复调查不能刷矿车奖励")
	_check(G.reload_save() and G.story_step_done("s24") and G.item_count("mine_record") == 1,
		"真实重读应保留第三幕前段与记录")
	mine.queue_free()
	await get_tree().process_frame
	# 实际奖励已应用后写盘失败，回滚必须覆盖信件、钱包与整个主线状态。
	var host := FailedSaveHost.new()
	host._init_state_defaults()
	host.prog["level"] = 30
	host.prog["story"] = {"step": "s23", "done": done + ["s21", "s22"], "goals": {}}
	host.items["frost_letter"] = 1
	var snap_prog := host.prog.duplicate(true)
	var snap_items := host.items.duplicate(true)
	var snap_wallet := host.wallet.duplicate(true)
	_check(host.story_event("talk", "npc_frost_envoy", "frost_post").is_empty()
		and host.prog == snap_prog and host.items == snap_items and host.wallet == snap_wallet,
		"交信写盘失败应完整回滚")
	host.free()
	# 地区图的完整画布不能继续被固定小视口裁断。
	G.prog["main_world"] = {"map_id": "frost_post"}
	var panel := RegionMapPanel.new()
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := _find_scroll(panel)
	_check(scroll != null and scroll.get_h_scroll_bar().max_value > scroll.size.x,
		"地区图必须可横向查看整张图")
	if scroll != null:
		var graph := scroll.get_child(0) as Control
		var point: Vector2 = graph.current_point
		_check(point.x >= scroll.scroll_horizontal and point.x <= scroll.scroll_horizontal + scroll.size.x
			and point.y >= scroll.scroll_vertical and point.y <= scroll.scroll_vertical + scroll.size.y,
			"打开地区图必须把当前霜关驿定位进视口")
	panel.queue_free()


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer: return node
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null: return found
	return null


class FailedSaveHost extends "res://src/autoload/G.gd":
	func save_game() -> bool:
		return false
