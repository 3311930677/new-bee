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

	# ---- B3. 导航三件套：小地图 / 目标罗盘 / 疾行（轮次 13）----
	_check(map._minimap != null and map._minimap.size.x > 1.0 and map._minimap.size.y > 1.0,
		"应有已铺开尺寸的小地图")
	_check(map._compass != null and map._compass.size.x > 1.0, "应有目标罗盘小签")
	var nav := map._nav_info()
	_check(String(nav.get("kind", "")) == "portal", "普通区罗盘应指向传送阵，实为 %s" % str(nav))
	_check(nav.get("pos", Vector2.ZERO) == map._portal.position, "罗盘目标应取传送阵坐标")
	_check(String(map._compass._lbl.text).contains("步"),
		"罗盘应显示到目标的步数，实为「%s」" % String(map._compass._lbl.text))
	await map.get_tree().physics_frame   # 让罗盘按实际位置刷新一次
	_check(String(map._compass._lbl.text).contains("传送阵"),
		"罗盘文案应带目标名，实为「%s」" % String(map._compass._lbl.text))

	# 大地图：点小地图打开（含图例与返回按钮），ESC 也能关掉
	_check(map._big_map == null, "起始不应有大地图浮层")
	map._toggle_big_map()
	_check(map._big_map != null, "点小地图应放大为大地图")
	var esc2 := InputEventKey.new()
	esc2.keycode = KEY_ESCAPE
	esc2.physical_keycode = KEY_ESCAPE
	esc2.pressed = true
	map._unhandled_input(esc2)
	_check(map._big_map == null, "ESC 应关闭大地图浮层")

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
	# 剧情演出（首领前对峙/战后余韵）由 VerifyLore 覆盖；这里标记已看，让战斗流程直连
	G.mark_beat_seen(bmap.st.theme, "intro")
	G.mark_beat_seen(bmap.st.theme, "outro")
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

	# ---- J. 导航：疾行提速 + 罗盘自动前往（宝箱区无怪，排除战斗干扰）----
	var nmap := await _spawn_map("chest", 1, "")
	_check(nmap._monsters.is_empty(), "宝箱区应无怪，便于单测导航")
	var nnav := nmap._nav_info()
	_check(String(nnav.get("kind", "")) == "chest", "宝箱区罗盘应指向宝箱，实为 %s" % str(nnav))

	# J1 疾行：同样帧数内位移应显著变大
	var walk_base: float = 0.0
	var sprint_base: float = 0.0
	for pass_idx in 2:
		var y_start: float = nmap._player.position.y
		if pass_idx == 1:
			nmap._toggle_sprint()
		Input.action_press("move_down")
		for i in 10:
			await nmap.get_tree().physics_frame
		Input.action_release("move_down")
		if pass_idx == 0:
			walk_base = absf(nmap._player.position.y - y_start)
		else:
			sprint_base = absf(nmap._player.position.y - y_start)
	if nmap._sprint:
		nmap._toggle_sprint()
	_check(sprint_base > walk_base * 1.3,
		"疾行位移应明显大于步行，实为 疾行%.1f / 步行%.1f" % [sprint_base, walk_base])

	# J2 自动前往：点罗盘应自己缩短与目标的距离
	nmap._player.position = Vector2(nmap._interactable.position.x,
		nmap._interactable.position.y + 420.0)
	var d0: float = nmap._player.position.distance_to(nnav.get("pos", Vector2.ZERO) as Vector2)
	nmap._on_compass_tapped()
	_check(nmap._auto_walk, "点罗盘应开启自动前往")
	for i in 340:
		await nmap.get_tree().physics_frame
		if nmap._interactable == null:   # 已开箱则提前收尾
			break
	var d1: float = nmap._player.position.distance_to(nnav.get("pos", Vector2.ZERO) as Vector2)
	_check(d1 < d0 - 40.0, "自动前往应明显靠近目标 %.1f → %.1f" % [d0, d1])
	_check(nmap._interactable == null, "自动走到宝箱处应触发开箱（%.1f 步外）" % (d1 / 48.0))

	# J3 手动输入随时接手 / 再点罗盘可停下
	var jmap := await _spawn_map("event", 1, "")
	jmap._on_compass_tapped()
	_check(jmap._auto_walk, "奇遇区应能开启自动前往")
	jmap._on_compass_tapped()
	_check(not jmap._auto_walk, "再点罗盘应停止自动前往")
	jmap._on_compass_tapped()
	Input.action_press("move_left")
	for i in 3:
		await jmap.get_tree().physics_frame
	Input.action_release("move_left")
	_check(not jmap._auto_walk, "手动键盘输入应立刻取消自动前往")
	if jmap._auto_walk:   # 再验摇杆这条取消路径（手游主路径）
		jmap._joy.vector = Vector2(0.0, -1.0)
		await jmap.get_tree().physics_frame
		_check(not jmap._auto_walk, "手动摇杆输入应立刻取消自动前往")
		jmap._joy.vector = Vector2.ZERO
	jmap.queue_free()
	await get_tree().process_frame

	# J4 卡死自停（P1-14）：连续卡住应停手交还控制，不再无限对撞
	var zmap := await _spawn_map("chest", 1, "")
	zmap._on_compass_tapped()
	_check(zmap._auto_walk, "应能开启自动前往")
	zmap._auto_fail = 3
	zmap._prev_pos = zmap._player.position   # 伪造"几乎没动"
	zmap._tick_auto_walk(0.3)
	_check(not zmap._auto_walk, "连续卡住应自停交还控制")
	zmap.queue_free()
	await get_tree().process_frame
	nmap.queue_free()
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

	# ---- K. 探索动机：拾取物 / 探索分 / 评价 / 清剿赏（轮次 16）----
	var kmap := await _spawn_map("chest", 1, "")
	var pk_n := kmap._pickups.size()
	_check(pk_n >= 3 and pk_n <= 5, "应撒 3~5 个拾取物，实为 %d" % pk_n)
	var g0: int = kmap.st.gold
	var e0: int = kmap.st.expedition
	if pk_n > 0:
		kmap._player.position = kmap._pickups[0].position
	for i in 8:
		await get_tree().process_frame
	_check(kmap._pickups.size() == pk_n - 1, "走到拾取物上应交接入袋，实剩 %d" % kmap._pickups.size())
	_check(kmap.st.gold > g0 and kmap.st.expedition > e0,
		"拾取应给金币与远征币，实为 %d/%d" % [kmap.st.gold, kmap.st.expedition])
	_check(kmap._score >= 6, "拾取应加探索分，实为 %d" % kmap._score)
	_check(String(kmap._explore_lbl.text).contains("探索分"),
		"无怪节点应显示探索分，实为「%s」" % String(kmap._explore_lbl.text))

	kmap._score = 0
	_check(int(kmap._rank().get("tier", -1)) == 0 and int(kmap._rank().get("bonus", -1)) == 0,
		"低分应无评价加成，实为 %s" % str(kmap._rank()))
	kmap._score = 999
	_check(int(kmap._rank().get("tier", -1)) == 3 and int(kmap._rank().get("bonus", -1)) == 160,
		"满分应为「寸土必争」+160，实为 %s" % str(kmap._rank()))
	var gb: int = kmap.st.gold
	kmap._player.position = kmap._portal.position
	kmap._check_portal()
	_check(kmap.st.gold == gb + 160, "通关时应结算评价附加赏，实为 +%d" % (kmap.st.gold - gb))
	kmap.queue_free()
	await get_tree().process_frame

	var c2map := await _spawn_map("normal", 1, "")
	_check(c2map._total_monsters == c2map._monsters.size(),
		"应记录全图怪物总数，实为 %d / %d" % [c2map._total_monsters, c2map._monsters.size()])
	var g1: int = c2map.st.gold
	c2map._on_area_cleared()
	_check(c2map._cleared_bonus and c2map.st.gold == g1 + 260,
		"清剿应给额外赏 +260，实为 +%d" % (c2map.st.gold - g1))
	c2map._on_area_cleared()
	_check(c2map.st.gold == g1 + 260, "清剿赏只应给一次")
	var score_before: int = c2map._score
	c2map._start_battle(c2map._monsters[0])
	if c2map._battle != null:
		_force_battle_end(c2map._battle, "victory")
		await get_tree().process_frame
		if c2map._picker != null:
			c2map._picker._emit_pick("")
			await get_tree().process_frame
	_check(c2map._kills == 1, "击败 1 只应计 1 杀，实为 %d" % c2map._kills)
	_check(c2map._score > score_before, "击杀应加探索分，实为 %d → %d" % [score_before, c2map._score])
	c2map.queue_free()
	await get_tree().process_frame

	# ---- L. 兴趣点：矿脉（材料）/ 碑灵祭坛（花金重摇祝福）（轮次 17）----
	var lmap := await _spawn_map("normal", 1, "")
	var veins: Array = []
	for s in lmap._spots:
		if s.kind == "vein":
			veins.append(s)
	_check(lmap._spots.size() >= 1 and veins.size() >= 1,
		"每张图应至少 1 个兴趣点（矿脉），实为 %d 个（%d 矿脉）" % [lmap._spots.size(), veins.size()])
	var items_before := 0
	for iid in ["enhance_stone", "refine_stone", "pet_food"]:
		items_before += G.item_count(String(iid))
	var score_before2: int = lmap._score
	lmap._player.position = veins[0].position
	for i in 8:
		await get_tree().process_frame
	var items_after := 0
	for iid2 in ["enhance_stone", "refine_stone", "pet_food"]:
		items_after += G.item_count(String(iid2))
	_check(items_after > items_before, "矿脉应给养成材料，实为 %d → %d" % [items_before, items_after])
	_check(lmap._score > score_before2, "矿脉也应加探索分")
	_check(lmap._spots.size() == 1 and lmap._spots[0].kind != "vein" or lmap._spots.size() == 0,
		"矿脉用掉后应从兴趣点里移除")

	# 祭坛：献金 → 扣费 → 关浮层 → 重摇祝福；金不足则拒绝且不扣费
	lmap.st.gold = 500
	lmap._open_altar(null)
	_check(lmap._altar_ui != null, "祭坛应弹出选择浮层")
	lmap._altar_pay(null, 200)
	_check(lmap.st.gold == 300, "献金应扣 200 金，实为 %d" % lmap.st.gold)
	_check(lmap._altar_ui == null, "献金后祭坛浮层应关闭")
	_check(lmap._picker != null, "献金后应弹出祝福重择")
	if lmap._picker != null:
		lmap._picker._emit_pick(String(lmap._picker.choices[0].get("id", "")))
		await get_tree().process_frame
	lmap.st.gold = 10
	lmap._open_altar(null)
	lmap._altar_pay(null, 200)
	_check(lmap.st.gold == 10 and lmap._altar_ui != null, "金币不足应拒绝且不扣费、浮层不关")
	lmap._close_altar(null, true)
	_check(lmap._altar_ui == null, "离开应关闭祭坛浮层")
	lmap.queue_free()
	await get_tree().process_frame

	# ---- M. 战斗撤退 =「退出本节点」：不判负 / 不结束局 / 保留怪物与 HP；开战即停自动前往 ----
	var mmap := await _spawn_map("normal", 1, "")
	var n_before: int = mmap._monsters.size()
	_check(n_before >= 1, "普通区应有怪")
	if n_before >= 1:
		mmap._auto_walk = true     # 直接置位，验证开战会把它停掉
		mmap._start_battle(mmap._monsters[0])
		_check(not mmap._auto_walk, "开战应停止自动前往")
		_check(mmap._battle != null, "战斗应挂载")
		if mmap._battle != null:
			mmap._battle.sim.role_unit().hp = 42
			_force_battle_end(mmap._battle, "flee")
			await get_tree().process_frame
			_check(mmap._battle == null, "撤退后战斗层应卸载")
			_check(not mmap.st.finished, "撤退不应结束本局")
			_check(mmap.st.hp == 42, "撤退应写回残血，实为 %d" % mmap.st.hp)
			_check(mmap._monsters.size() == n_before, "撤退不应移除怪物，实为 %d/%d" % [mmap._monsters.size(), n_before])
	mmap.queue_free()
	await get_tree().process_frame

	# ---- N. 节点进度持久化：撤离→重进 不复活、不重发（P0-1）----
	var nmap2 := await _spawn_map("normal", 1, "")
	var n_all: int = nmap2._monsters.size()
	var n_st: RunState = nmap2.st
	_check(n_all >= 3, "普通区应有 3~4 怪，实为 %d" % n_all)
	nmap2._start_battle(nmap2._monsters[0])
	_check(nmap2._battle != null, "战斗应挂载")
	if nmap2._battle != null:
		_force_battle_end(nmap2._battle, "victory")
		await get_tree().process_frame
		if nmap2._picker != null:
			nmap2._picker._emit_pick(String(nmap2._picker.choices[0].get("id", "")))
			await get_tree().process_frame
	_check(nmap2._monsters.size() == n_all - 1, "击杀后应少 1 怪，实为 %d/%d" % [nmap2._monsters.size(), n_all])
	var gold_after: int = n_st.gold
	nmap2.queue_free()
	await get_tree().process_frame
	# 重进同节点（同一 RunState、同 layer/index → 同种子同布局）
	MapScene.pending_cfg = {"node": {"type": "normal", "layer": 1, "index": 0}, "run": n_st}
	var rmap: MapScene = (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate()
	rmap.map_finished.connect(func(r: String): _last_result = r)
	add_child(rmap)
	await get_tree().process_frame
	_check(rmap._monsters.size() == n_all - 1,
		"重进后已击杀的怪不应复活（%d vs 期望 %d）" % [rmap._monsters.size(), n_all - 1])
	_check(n_st.gold == gold_after, "重进不应重发奖励（金币 %d vs %d）" % [n_st.gold, gold_after])
	_check(int((rmap._prog as Dictionary).get("killed", []).size()) == 1, "进度表应记 1 个击杀")
	# 再杀一只：只结算新击杀
	if rmap._monsters.size() >= 1:
		rmap._start_battle(rmap._monsters[0])
		if rmap._battle != null:
			_force_battle_end(rmap._battle, "victory")
			await get_tree().process_frame
			if rmap._picker != null:
				rmap._picker._emit_pick(String(rmap._picker.choices[0].get("id", "")))
				await get_tree().process_frame
		_check(n_st.gold > gold_after, "新击杀应正常结算（%d → %d）" % [gold_after, n_st.gold])
		_check(int((rmap._prog as Dictionary).get("killed", []).size()) == 2, "进度表应记 2 个击杀")
	rmap.queue_free()
	await get_tree().process_frame

	# ---- O. 浮层冻结：看大地图期间怪不动、不触发开战（P1-10）----
	var omap := await _spawn_map("normal", 1, "")
	var om = omap._monsters[0]
	om._aggro = 1.0   # 只观察冻结，不让它主动追
	om.position = omap._player.position + Vector2(200.0, 0)
	om.home = om.position
	var om_p0 = om.position
	omap._toggle_big_map()
	_check(omap._big_map != null, "大地图应打开")
	for i in 30:
		await get_tree().physics_frame
	_check(om.position == om_p0, "看大地图时怪物应完全冻结（%.1f,%.1f）" % [om.position.x, om.position.y])
	om.position = omap._player.position + Vector2(10.0, 0)
	for i in 15:
		await get_tree().physics_frame
	_check(omap._battle == null, "看大地图时贴脸也不应开战")
	omap._toggle_big_map()   # 关掉
	var fwait := 0
	while omap._battle == null and fwait < 180:
		await get_tree().process_frame
		fwait += 1
	_check(omap._battle != null, "关掉大地图后接触应恢复开战（%d 帧内）" % fwait)
	omap.queue_free()
	await get_tree().process_frame

	# ---- P. 怪物参与散件碰撞：不再穿树（P1-15）----
	var qmap := await _spawn_map("normal", 1, "")
	var qm = qmap._monsters[0]
	_check(qm is CharacterBody2D, "怪物应为 CharacterBody2D")
	_check(qm.collision_mask == 2, "怪物应只撞散件层（mask 2）")
	var deco: Node2D = null
	for c in qmap._world.get_children():
		if c is StaticBody2D:
			deco = c
			break
	_check(deco != null, "地图上应有散件")
	if deco != null:
		qm._aggro = 1.0
		qm._contact = 0.0
		qm.position = deco.position + Vector2(-46.0, 0)
		qm.velocity = Vector2.ZERO
		qm._target = deco.position + Vector2(60.0, 0)
		qm._state = "wander"
		var min_d := 9999.0
		for i in 70:
			await get_tree().physics_frame
			min_d = minf(min_d, qm.position.distance_to(deco.position))
		_check(min_d > 25.0, "怪物不应压进散件碰撞盒（最近距离 %.1f）" % min_d)
	qmap.queue_free()
	await get_tree().process_frame

	# ---- Q. 血上限同口径：带局外成长时，篝火不会把血削低（P1-6）----
	var fbmap := await _spawn_map("bonfire", 2, "")
	fbmap.st.growth_bonus = {"maxhp_pct": 0.5}   # 模拟天赋/装备的局外加成
	var cap := fbmap.st.max_hp()
	fbmap.st.hp = cap
	fbmap.st.heal(fbmap.st.bonfire_heal())
	_check(fbmap.st.hp == cap, "满血点篝火不应掉血（%d → %d，上限 %d）" % [cap, fbmap.st.hp, cap])
	fbmap.queue_free()
	await get_tree().process_frame

	_print_result()


func _print_result() -> void:
	if _fails == 0:
		print("MAP_SCENE_OK all tests passed")
	else:
		print("MAP_SCENE_FAIL fails=%d" % _fails)
