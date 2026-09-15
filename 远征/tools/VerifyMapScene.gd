# VerifyMapScene.gd —— 探索大地图冒烟（场景模式：godot --headless --path . res://tools/VerifyMapScene.tscn）
# 覆盖：构建（TileMap 地面/玩家/传送阵/按节点类型的怪物编成）/ 键盘移动 /
#       警戒追击→接触开战 / 强制胜利写回（接触怪离场+词条+HP）/ 地图换宠 /
#       传送阵通关（cleared 信号+节点标记）/ BOSS 区封印与解封 / 精英区编成 / 战败 defeat
extends Node

var _fails := 0
var _last_result := ""


func _ready() -> void:
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _spawn_map(node_type: String, layer: int, bench: String) -> MapScene:
	_last_result = ""
	var st := RunState.new()
	st.setup({
		"theme": "forest", "role_id": "zs", "level": 5,
		"active_pet": "pet_rockturtle", "bench_pet": bench,
		"potions": 2, "seed": 7,
	})
	MapScene.pending_cfg = {"node": {"type": node_type, "layer": layer, "index": 0}, "run": st}
	var packed: PackedScene = load("res://src/explore/MapScene.tscn")
	var map: MapScene = packed.instantiate()
	map.map_finished.connect(func(r: String): _last_result = r)
	add_child(map)
	await get_tree().process_frame  # 等 _ready 构建
	return map


func _force_battle_end(b: BattleScene, result: String) -> void:
	b.sim.finished = true
	b.sim.result = result
	b.confirm_result()


func _run() -> void:
	# ---- A. 普通区构建 ----
	var map := await _spawn_map("normal", 1, "pet_thunderhawk")
	_check(map.st != null, "应持有 run 状态")
	_check(map._player != null, "应构建玩家")
	_check(map._portal != null and not map._portal.locked, "普通区传送阵应解锁")
	_check(map._monsters.size() >= 3 and map._monsters.size() <= 4,
		"普通区应有 3~4 小怪，实为 %d" % map._monsters.size())
	var tile_cnt := -1
	for c in map.get_children():
		if c is TileMapLayer:
			tile_cnt = (c as TileMapLayer).get_used_cells().size()
	_check(tile_cnt > 1000, "应平铺 TileMap 地面（>1000 格），实为 %d" % tile_cnt)
	_check(map._pet_btn != null and map._pet_btn.visible, "有替补时应显示换宠按钮")

	# ---- B. 键盘移动（ui_up）----
	var y0: float = map._player.position.y
	Input.action_press("ui_up")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release("ui_up")
	_check(map._player.position.y < y0 - 20.0,
		"按上键玩家应上移，Δy=%.1f" % (y0 - map._player.position.y))

	# ---- C. 警戒追击→接触开战 ----
	var m := map._monsters[0]
	m.position = map._player.position + Vector2(50.0, 30.0)
	m.home = m.position
	var frames := 0
	while map._battle == null and frames < 300:
		await get_tree().process_frame
		frames += 1
	_check(map._battle != null, "警戒半径内怪物应追击并触发战斗（%d 帧内）" % frames)
	if map._battle == null:
		_print_result()
		return  # 后续依赖战斗，直接收尾
	var mon_cnt := map._monsters.size()

	# ---- D. 强制胜利写回 + 三选一 ----
	_force_battle_end(map._battle, "victory")
	await get_tree().process_frame
	_check(map._battle == null, "战斗结束覆盖层应卸载")
	_check(map._monsters.size() == mon_cnt - 1,
		"接触怪应离场，实剩 %d / %d" % [map._monsters.size(), mon_cnt])
	_check(map._picker != null, "胜利应弹出词条三选一")
	var picked_id := ""
	if map._picker != null:
		picked_id = String(map._picker.choices[0].get("id", ""))
		map._picker._emit_pick(picked_id)
		await get_tree().process_frame
	_check(map._picker == null, "选卡后浮层应关闭")
	_check(map.st.traits.size() == 1 and map.st.traits.has(picked_id), "选卡应写入词条")
	_check(map.st.hp > 0, "HP 应写回正值，实为 %d" % map.st.hp)

	# ---- 地图上换宠 ----
	var pet0 := map.st.active_pet
	map._swap_pet()
	_check(map.st.active_pet != pet0 and map.st.bench_pet == pet0, "地图上换宠应交换出战位")

	# ---- E. 传送阵通关 ----
	map._player.position = map._portal.position
	map._check_portal()
	_check(map._map_done, "触碰传送阵应结束地图")
	_check(_last_result == "cleared", "应发 cleared 信号，实为 %s" % _last_result)
	_check(bool(map.st.route["layers"][0][0].get("cleared", false)), "节点应标记 cleared")
	map.queue_free()
	await get_tree().process_frame

	# ---- F. BOSS 区：封印→首领战→解封→通关 ----
	var bmap := await _spawn_map("boss", 4, "")
	_check(bmap._monsters.size() == 1 and bmap._monsters[0].tier == "boss", "BOSS 区应 1 首领守阵")
	_check(bmap._portal.locked, "BOSS 区传送阵应封印")
	bmap._player.position = bmap._portal.position
	bmap._check_portal()
	_check(not bmap._map_done and bmap._portal.warned, "封印中触碰应警告而非通关")
	bmap._start_battle(bmap._monsters[0])
	_check(bmap._battle != null, "BOSS 战应挂载")
	if bmap._battle != null:
		var has_boss := bmap._battle.sim.units.any(
			func(u): return u.kind == "monster" and String(u.data.get("tier", "")) == "boss")
		_check(has_boss, "BOSS 战敌方应含首领单位")
		_force_battle_end(bmap._battle, "victory")
		await get_tree().process_frame
		_check(not bmap._portal.locked, "首领战败传送阵应解封")
		if bmap._picker != null:  # 选卡后再通关
			bmap._picker._emit_pick(String(bmap._picker.choices[0].get("id", "")))
			await get_tree().process_frame
		bmap._player.position = bmap._portal.position
		bmap._check_portal()
		_check(bmap._map_done and _last_result == "cleared", "解封后触碰应 cleared")
		_check(bool(bmap.st.route["boss"].get("cleared", false)), "BOSS 节点应标记 cleared")
	bmap.queue_free()
	await get_tree().process_frame

	# ---- G. 精英区编成 + 战败 ----
	var gmap := await _spawn_map("elite", 2, "")
	_check(gmap._monsters.size() == 3, "精英区应 1+2 编成，实为 %d" % gmap._monsters.size())
	var tiers: Array = []
	for mo in gmap._monsters:
		tiers.append(mo.tier)
	_check(tiers.has("elite") and tiers.count("normal") == 2, "编成应为 elite+2normal，实为 %s" % str(tiers))
	_check(gmap._pet_btn == null or not gmap._pet_btn.visible, "无替补时换宠按钮应隐藏")
	gmap._start_battle(gmap._monsters[0])
	_check(gmap._battle != null, "精英战应挂载")
	if gmap._battle != null:
		gmap._battle.sim.potions_left = 1
		gmap._battle.sim.pet_swap_used = true
		_force_battle_end(gmap._battle, "defeat")
		await get_tree().process_frame
		_check(gmap.st.potions == 1, "药剂余量应写回，实为 %d" % gmap.st.potions)
		_check(gmap.st.finished and gmap.st.result == "defeat", "战败应结束局")
		_check(gmap._map_done and _last_result == "defeat", "应发 defeat 信号")
	gmap.queue_free()
	await get_tree().process_frame

	_print_result()


func _print_result() -> void:
	if _fails == 0:
		print("MAP_SCENE_OK all tests passed")
	else:
		print("MAP_SCENE_FAIL fails=%d" % _fails)
