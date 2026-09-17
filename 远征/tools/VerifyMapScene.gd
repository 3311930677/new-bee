# VerifyMapScene.gd —— 探索大地图冒烟（场景模式：godot --headless --path . res://tools/VerifyMapScene.tscn）
# 覆盖：构建（TileMap 地面/玩家/传送阵/按节点类型的怪物编成）/ 键盘移动 /
#       警戒追击→接触开战 / 强制胜利写回（接触怪离场+词条+HP）/ 地图换宠 /
#       传送阵通关（cleared 信号+节点标记）/ BOSS 区封印与解封 / 精英区编成 / 战败 defeat
extends Node

var _fails := 0
var _last_result := ""


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_map.json"  # 别污染真实存档
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


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
	var tile_cnt := 0
	var layer_sizes: Array[int] = []
	for c in map.get_children():
		if c is TileMapLayer:
			var n: int = (c as TileMapLayer).get_used_cells().size()
			layer_sizes.append(n)
			tile_cnt += n
	_check(tile_cnt > 1000, "应平铺 TileMap 地面（>1000 格），实为 %d" % tile_cnt)
	# 地面细节层：森林主题带 path_sheet，应多出一层蜿蜒土路（地面 + 土路 = 2 层）
	_check(layer_sizes.size() == 2 and layer_sizes.min() >= 20,
		"森林主题应含土路层（地面+土路），实为 %s" % str(layer_sizes))
	_check(map._pet_btn != null and map._pet_btn.visible, "有替补时应显示换宠按钮")

	# ---- B. 键盘移动（move_up / WASD 与方向键同映射）----
	var y0: float = map._player.position.y
	var x0: float = map._player.position.x
	Input.action_press("move_up")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release("move_up")
	_check(map._player.position.y < y0 - 20.0,
		"按上键（W）玩家应上移，Δy=%.1f" % (y0 - map._player.position.y))
	Input.action_press("move_right")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release("move_right")
	_check(map._player.position.x > x0 + 20.0,
		"按右键（D）玩家应右移，Δx=%.1f" % (map._player.position.x - x0))

	# ---- B2. 退出：HUD 撤离按钮 + ESC ----
	_check(map._exit_ui == null, "起始不应有撤离确认浮层")
	map._ask_exit()
	_check(map._exit_ui != null, "点「撤离」应弹出二次确认")
	map._cancel_exit()
	_check(map._exit_ui == null, "「继续探索」应关闭确认浮层")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	map._unhandled_input(esc)
	_check(map._exit_ui != null, "ESC 应能呼出撤离确认（不再卡死在地图里）")
	map._unhandled_input(esc)
	_check(map._exit_ui == null, "再按 ESC 应关闭确认浮层")

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

	# ---- H. 非战斗节点物件化（宝箱/事件/商店/篝火，§2.7） ----
	# H1 宝箱：无怪有物件，靠近自动开启并入账
	var cmap := await _spawn_map("chest", 1, "")
	_check(cmap._monsters.size() == 0, "宝箱区应无怪")
	_check(cmap._interactable != null and cmap._interactable.kind == "chest", "宝箱区应放宝箱物件")
	_check(not cmap._portal.locked, "宝箱区传送阵应解锁")
	cmap._player.position = cmap._interactable.position
	for i in 6:
		await get_tree().process_frame
	_check(cmap._interactable == null, "开启后宝箱物件应消失")
	_check(cmap.st.gold == 200 and cmap.st.expedition == 30,
		"宝箱应入账金币 200/远征币 30，实为 %d/%d" % [cmap.st.gold, cmap.st.expedition])
	cmap._player.position = cmap._portal.position
	cmap._check_portal()
	_check(cmap._map_done and _last_result == "cleared", "宝箱区应可走传送阵通关")
	cmap.queue_free()
	await get_tree().process_frame

	# H2 篝火：回血 + 词条删除浮层（选一行舍弃）
	var fmap := await _spawn_map("bonfire", 2, "")
	var tlist: Array = TableCache.traits()
	fmap.st.traits = [String(tlist[0].get("id", "")), String(tlist[1].get("id", ""))]
	fmap.st.hp = 10
	fmap._player.position = fmap._interactable.position
	for i in 6:
		await get_tree().process_frame
	_check(fmap._remover != null, "篝火应弹出词条删除浮层")
	_check(fmap.st.hp > 10, "篝火应回血，实为 %d" % fmap.st.hp)
	var drop_id := String(tlist[0].get("id", ""))
	if fmap._remover != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		fmap._on_remove_row(click, drop_id)
		await get_tree().process_frame
	_check(fmap._remover == null, "选行后浮层应关闭")
	_check(fmap.st.traits.size() == 1 and not fmap.st.traits.has(drop_id),
		"应舍弃所选词条，实为 %s" % str(fmap.st.traits))
	fmap.queue_free()
	await get_tree().process_frame

	# H3 商店：金不足免费赠药
	var smap := await _spawn_map("shop", 1, "")
	smap.st.gold = 0
	smap.st.potions = 1
	smap._player.position = smap._interactable.position
	for i in 6:
		await get_tree().process_frame
	_check(smap._interactable == null and smap.st.potions == 2,
		"金不足应免费赠药 ×1，实为药剂 %d" % smap.st.potions)
	smap.queue_free()
	await get_tree().process_frame

	# H4 事件：金币 80~150 随机
	var emap := await _spawn_map("event", 1, "")
	emap.st.gold = 0
	emap._player.position = emap._interactable.position
	for i in 6:
		await get_tree().process_frame
	_check(emap._interactable == null and emap.st.gold >= 80 and emap.st.gold <= 150,
		"事件应得金币 80~150，实为 %d" % emap.st.gold)
	emap.queue_free()
	await get_tree().process_frame

	# ---- I. 撤离确认里点「撤 离」→ 真正离场 ----
	var xmap := await _spawn_map("normal", 1, "")
	xmap._ask_exit()
	_check(xmap._exit_ui != null, "点撤离应弹出二次确认")
	var leave_btn: Control = null
	if xmap._exit_ui != null and xmap._exit_ui.get_child_count() >= 3:
		var ex_panel: Node = xmap._exit_ui.get_child(2)
		if ex_panel.get_child_count() >= 1:
			var ex_content: Node = ex_panel.get_child(0)
			if ex_content.get_child_count() >= 3:
				leave_btn = ex_content.get_child(2) as Control
	_check(leave_btn != null, "撤离确认内应有「撤 离」按钮")
	if leave_btn != null:
		leave_btn.gui_input.emit(_click())
		await get_tree().process_frame
	_check(xmap._exit_ui == null, "点撤离后确认浮层应卸载")
	_check(xmap._map_done and _last_result == "exited",
		"点撤离应发 exited 信号并结束地图，实为 %s（done=%s）" % [_last_result, str(xmap._map_done)])
	xmap.queue_free()
	await get_tree().process_frame

	_print_result()


func _print_result() -> void:
	if _fails == 0:
		print("MAP_SCENE_OK all tests passed")
	else:
		print("MAP_SCENE_FAIL fails=%d" % _fails)
