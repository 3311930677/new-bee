extends Node

const Rewards := preload("res://src/world/ArcheryRewards.gd")
var checks := 0
var fails := 0

class FailedHost extends RefCounted:
	var prog: Dictionary
	var wallet: Dictionary
	var items: Dictionary
	var save_locked := false
	func _init() -> void:
		prog = G.prog.duplicate(true)
		wallet = G.wallet.duplicate(true)
		items = G.items.duplicate(true)
	func ledger() -> Dictionary:
		if not prog.has("ledger"): prog.ledger = {"applied": []}
		return prog.ledger
	func grant_item(id: String, n: int, _persist := true) -> void: items[id] = int(items.get(id, 0)) + n
	func item_name(id: String) -> String: return G.item_name(id)
	func save_game() -> bool: return false

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		push_error("FAIL: " + message)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func fixture() -> void:
	G.SAVE_PATH = "res://tools/_logs/play_journey_save.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "ck"
	G.player_name = "巡路旅人"
	G.ensure_starter_buildings()
	G.set_meta("ui_review_mode", true)
	G.gm_world_open = false

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/play_iteration_20261026/" + name + ".png"))

func _ready() -> void:
	fixture()
	var modes: Array = TableCache._load("res://data/archery.json").modes
	check(modes.size() == 4, "射艺包含真实第四档试炼")
	var novice: Dictionary = modes[0]
	var master: Dictionary = modes[2]
	var lantern: Dictionary = modes[3]
	check(not Rewards.unlocked(G, lantern), "新手不能跳过初试参加守夜")
	var before := G.prog.duplicate(true)
	check(not bool(Rewards.settle(G, lantern, "locked_mode", 60, 6, 6).ok) and G.prog == before, "未解锁不发奖也不改成绩")
	var fail_host := FailedHost.new()
	var fault_before := [fail_host.prog.duplicate(true), fail_host.wallet.duplicate(true), fail_host.items.duplicate(true)]
	check(not bool(Rewards.settle(fail_host, novice, "fault", 40, 4, 4).ok), "写盘失败明确拒绝")
	check(fail_host.prog == fault_before[0] and fail_host.wallet == fault_before[1] and fail_host.items == fault_before[2], "整局成绩、材料、钱包和凭据回滚")
	G.save_locked = true
	check(not bool(Rewards.settle(G, novice, "lock", 40, 4, 4).ok) and G.prog == before, "锁档无内存发奖")
	G.save_locked = false
	check(bool(Rewards.settle(G, novice, "round1", 40, 4, 4).passed), "初试真实过关")
	check(int(G.wallet.gold) == 250 and G.item_count("enhance_stone") == 3, "首通货币和材料入袋")
	check(Rewards.unlocked(G, lantern), "初试解锁守夜")
	var wallet := G.wallet.duplicate(true)
	check(bool(Rewards.settle(G, novice, "round1", 40, 4, 4).duplicate) and G.wallet == wallet, "相同回调不重复发奖")
	check(bool(Rewards.settle(G, novice, "round2", 30, 0, 5).ok) and int(G.wallet.gold) == 330, "重玩使用重玩奖")
	check(bool(Rewards.settle(G, master, "master_pass", 40, 0, 6).passed) and not G.title_owned("t_archery_master"), "首次仅达标不假报魁首")
	check(bool(Rewards.settle(G, master, "master_later", 60, 6, 6).mastered) and G.title_owned("t_archery_master"), "重玩达到魁首仍自动授称号")
	wallet = G.wallet.duplicate(true)
	check(not bool(Rewards.settle(G, lantern, "unlit_round", 40, 3, 3).passed) and G.wallet == wallet, "环数够但亮灯命中不足仍失败")
	check(bool(Rewards.settle(G, lantern, "lit_round", 48, 0, 6).passed), "亮灯挑战过关")
	check(G.item_count("refine_stone") == 3 and G.item_count("pet_food") == 2, "挑战产出接入精炼与伙伴材料")
	check(G.reload_save() and Rewards.unlocked(G, lantern) and G.title_owned("t_archery_master"), "解锁成绩与称号可读回")
	var panel := preload("res://src/ui/ArcheryPanel.gd").new()
	add_child(panel)
	await frames()
	panel.set_process(false)
	panel._select_mode(3)
	panel._time = 2.0
	panel._wind = 0
	panel._target_pos = Vector2(240, 134)
	var arrows: int = panel._arrows_left
	var miss: Dictionary = panel.shoot_with_params(panel._target_pos, 0.8)
	check(int(miss.rings) == 0 and panel._arrows_left == arrows - 1 and panel._bullseyes_this_round == 0, "暗灯正中靶心也不计分或虚增红心")
	panel._time = 0.5
	panel._wind = 0
	var hit: Dictionary = panel.shoot_with_params(panel._target_pos, 0.8)
	check(int(hit.rings) == 10 and panel._lit_hits == 1, "亮灯命中真实记环")
	panel._range.floaters.clear()
	panel._range.sparks.clear()
	panel._last_banner_t = 0.0
	await shot("after_archery_lantern")
	for height in [640, 800, 1067]:
		get_window().content_scale_size = Vector2i(480, height)
		get_window().size = Vector2i(480, height)
		await frames()
		panel._relayout()
		check(panel._fire_btn.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y + 1, "射箭按钮在%d高可见" % height)
		check(absf(get_viewport().get_visible_rect().size.x - 480) < 1 and absf(get_viewport().get_visible_rect().size.y - height) < 1, "使用真实480×%d逻辑比例" % height)
		check(panel.shell.stage.size.y <= panel.MAX_STAGE_HEIGHT + 1, "长屏优先给规则留空间而不拉伸靶场")
		check(panel._mode_tabs.get_child_count() == 4 and panel._mode_tabs.columns == 2, "四档模式使用两列布局")
		await shot("after_archery_%d" % height)
	var arrows_before_input: int = panel._arrows_left
	var fire_at: Vector2 = panel._fire_btn.get_global_rect().get_center()
	var mouse := InputEventMouseButton.new()
	mouse.position = fire_at
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	mouse.pressed = true
	get_viewport().push_input(mouse, true)
	await frames()
	check(panel._charging, "视口鼠标按下真实射箭按钮进入蓄力")
	panel._process(0.565)
	mouse = mouse.duplicate()
	mouse.button_mask = 0
	mouse.pressed = false
	get_viewport().push_input(mouse, true)
	await frames()
	check(panel._flying and not panel._charging, "视口鼠标松开真实发箭")
	panel._process(0.3)
	check(panel._arrows_left == arrows_before_input - 1, "飞行落靶只扣一箭，无双发")
	panel._arrows_left = 0
	panel._score = 40
	panel._lit_hits = 4
	G.save_locked = true
	panel._finish_round()
	check(panel._save_pending and panel._reset_btn.caption.text == "重试保存", "失败结算保留本局并可重试")
	G.save_locked = false
	panel._finish_round()
	check(not panel._save_pending, "恢复可写后本局能结算")
	check(not bool(panel.shoot_with_params(panel._target_pos, 0.8).get("ok", true)), "结算后不再消耗或重复结算")
	panel.queue_free()
	await frames()
	fixture()
	G.prog.story = {"step": "s02", "done": ["s01"], "goals": {"s01": "done"}}
	G.side_accept("a1_elite_beast")
	var run := RunState.new()
	run.setup({"role_id": "ck", "theme": "forest", "level": 2, "seed": 71})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run, "node": {"type": "normal", "layer": 1, "index": 0}}
	var map := preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(map)
	await frames(8)
	map._select_walk_focus("story")
	var target: Dictionary = map._hud_target_info()
	check(String(target.get("name", "")) == "前往枫林古道", "已追踪精英支线时主线仍指向古道")
	check(map._walk_focus == "story" and map._auto_walk, "显式寻路来源生效")
	map._select_walk_focus("story")
	check(not map._auto_walk, "重复点主线可停止寻路")
	map._select_walk_focus("side")
	check(map._walk_focus == "side", "玩家仍可主动切换支线")
	map._stop_auto_walk("")
	G.prog.story = {"step": "s04", "done": ["s01", "s02", "s03"], "goals": {"s01": "done", "s02": "done", "s03": "done"}}
	check(not map._story_navigation_info().is_empty(), "真实起始建筑使回城铁匠可导航")
	G.prog.story = {"step": "s11", "done": [], "goals": {}}
	var craft_target: Dictionary = map._story_navigation_info()
	check(String(craft_target.get("kind", "")) == "quest" and String(craft_target.get("name", "")).contains("修碑"), "修碑任务使用NPC实体ID而非立绘素材别名")
	map._toggle_big_map()
	var point_id := "lorin_wilds:npc_keeper"
	check(bool(preload("res://src/world/WorldPoints.gd").track(point_id).ok), "真实地图目的地可追踪")
	map._big_map.destination_selected.emit(point_id)
	check(map._walk_focus == "destination" and String(map._hud_target_info().get("poi_id", "")) == point_id, "选地图地点后切换导航来源")
	map._select_walk_focus("story")
	check(not map._hud_target_info().has("poi_id"), "有地图目的地时仍可明确选择主线")
	map._select_walk_focus("destination")
	check(String(map._hud_target_info().get("poi_id", "")) == point_id, "玩家可切回原目的地")
	map._stop_auto_walk("")
	var story_done: Array = []
	var story_goals := {}
	for i in range(1, 10):
		story_done.append("s%02d" % i)
		story_goals["s%02d" % i] = "done"
	G.prog.story = {"step": "s10", "done": story_done, "goals": story_goals}
	map._main_map_id = "stele_cavern"
	map._walk_focus = "story"
	var waiting: Dictionary = map._hud_target_info()
	check(bool(waiting.get("waiting", false)) and String(waiting.get("kind", "")) == "", "目标缺席不引向其他敌人：" + JSON.stringify(waiting))
	map.queue_free()
	await frames(4)
	for script in ["CurioLorePanel", "HonorMarketPanel", "WorldPointMap", "CurrencyPanel"]:
		var page := load("res://src/ui/%s.gd" % script).new() as Control
		var closes := [0]
		page.closed.connect(func(): closes[0] += 1)
		add_child(page)
		await frames()
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = true
		var handler := "_input" if script in ["CurioLorePanel", "HonorMarketPanel"] else "_unhandled_input"
		G.ui_blocked = true
		page.call(handler, event)
		check(closes[0] == 0, script + "上层浮层打开时不误关背后页面")
		G.ui_blocked = false
		page.call(handler, event)
		check(closes[0] == 1, script + "正常返回可关闭")
		page.queue_free()
		await frames()
	var output := FileAccess.open("res://../reports/play_iteration_20261026/acceptance_result.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"checks": checks, "fails": fails, "display": DisplayServer.get_name()}, "\t"))
		output.close()
	if fails == 0: print("PLAY_JOURNEY_OK checks=%d" % checks)
	else: print("PLAY_JOURNEY_FAIL checks=%d fails=%d" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)
