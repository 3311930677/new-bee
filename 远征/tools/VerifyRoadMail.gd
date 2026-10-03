extends Node

const RoadMailServiceScript := preload("res://src/world/RoadMailService.gd")

var _fails := 0

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_road_mail.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "邮路测试"
	G.prog["story"] = {"step": "", "done": ["s36"], "goals": {}}
	G.prog["flags"] = {"act4_reply_route_open": true}
	G.prog["level"] = 60
	_check(G.save_game(), "隔离测试档可写")
	await _run()
	print("ROAD_MAIL_OK" if _fails == 0 else "ROAD_MAIL_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + msg)

func _enter(map_id: String) -> MapScene:
	var run := RunState.new()
	run.setup({"theme": "forest", "role_id": "zs", "level": 60,
		"active_pet": "pet_rockturtle", "bench_pet": "", "potions": 2, "seed": 4401})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": map_id, "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	var map := (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	if map._city_content != null: map._city_content._close_panel()
	return map

func _entity(map: MapScene, eid: String) -> Node2D:
	for entity in map._quest_entities:
		if is_instance_valid(entity) and entity.eid == eid and not entity.used:
			return entity
	return null

func _find_button(node: Node, label: String) -> Control:
	var needle := label.replace(" ", "")
	for child in node.get_children():
		if child is Label and needle in String(child.text).replace(" ", "") and node is Control:
			return node
		var hit := _find_button(child, label)
		if hit != null: return hit
	return null

func _has_text(node: Node, value: String) -> bool:
	if node is Label and value in String((node as Label).text): return true
	for child in node.get_children():
		if _has_text(child, value): return true
	return false

func _click(button: Control) -> void:
	_check(button != null, "按钮存在")
	if button == null: return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	button.gui_input.emit(event)

func _run() -> void:
	var before := G.prog.duplicate(true)
	_check(not bool(G.road_mail_action("deliver", "shenyuan_port").get("ok", false))
		and G.prog == before, "未接邮袋不能跳到交付")
	var frost := await _enter("frost_post")
	var board := _entity(frost, "road_mail_board")
	_check(board != null, "霜关驿有归路邮驿实体")
	if board != null: frost.on_quest_entity(board)
	_check(frost._road_mail_panel != null and frost._modal_open(), "邮驿打开后冻结地图接触")
	if frost._road_mail_panel != null:
		_click(_find_button(frost._road_mail_panel, "快行 · 风沙路标"))
	await get_tree().process_frame
	_check(String(G.road_mail_state().get("phase")) == "travel", "真实按钮接快行邮袋")
	_check("阿澜" in String(G.road_mail_state().get("letter", "")), "首封信有具体收件人")
	_check(G.reload_save() and String(G.road_mail_state().get("phase")) == "travel",
		"接单跨进程式重读仍在")
	frost.queue_free()
	await get_tree().process_frame
	var road := await _enter("red_sand_route")
	_check(_entity(road, "road_mail_sand_signal") != null and
		_entity(road, "road_mail_quick_marker") == null, "先查看路况再显示快行目标")
	var clue := _entity(road, "road_mail_sand_signal")
	if clue != null: road.on_quest_entity(clue)
	await get_tree().process_frame
	_check(String(G.road_mail_state().get("phase")) == "clue" and
		_entity(road, "road_mail_quick_marker") != null and
		_entity(road, "road_mail_stone_trace") != null and
		_entity(road, "road_mail_safe_shelter") == null, "按路线显示唯一目标")
	_check(not bool(G.road_mail_action("pass_observe", "red_sand_route").get("ok", false)),
		"没有第二处刻痕线索不能凭空免费通行")
	var trace := _entity(road, "road_mail_stone_trace")
	if trace != null: road.on_quest_entity(trace)
	await get_tree().process_frame
	_check("stone" in (G.road_mail_state().get("observed_clues", []) as Array),
		"实地观察风蚀石写入本趟线索")
	var quick := _entity(road, "road_mail_quick_marker")
	if quick != null: road.on_quest_entity(quick)
	_check(road._puzzle_panel != null and
		_find_button(road._puzzle_panel, "照旧刻痕辨路 · 免费") != null,
		"路标打开两种处理方法")
	if road._puzzle_panel != null:
		_click(_find_button(road._puzzle_panel, "照旧刻痕辨路 · 免费"))
	await get_tree().process_frame
	_check(String(G.road_mail_state().get("phase")) == "hazard" and
		String(G.road_mail_state().get("solution")) == "observe", "刻痕辨路后遇到快行伏击")
	_check(not bool(G.road_mail_action("pass_observe", "red_sand_route").get("ok", false)),
		"旧路标不能重复推进")
	_check(not bool(G.road_mail_action("hazard_battle", "red_sand_route").get("ok", false)),
		"不能跳过真实战斗直接标记伏击胜利")
	var ambush: Node = null
	for monster in road._monsters:
		if monster.idx == road._road_mail_ambush_idx(): ambush = monster
	_check(ambush != null, "快行阶段在赤砂地图生成本趟伏沙蝎")
	if ambush != null:
		road.call("_start_battle", ambush)
		_check(road._battle != null, "伏沙蝎触发真实对战")
		if road._battle != null:
			road._battle.sim.finished = true
			road._battle.sim.result = "victory"
			road._battle.confirm_result()
			await get_tree().process_frame
	_check(String(G.road_mail_state().get("phase")) == "pass" and
		String(G.road_mail_state().get("encounter")) == "ambush",
		"胜利与邮路进度同次结算")
	_check(G.reload_save() and String(G.road_mail_state().get("phase")) == "pass",
		"路况进度读档保留")
	road.queue_free()
	await get_tree().process_frame
	var cleared_road := await _enter("red_sand_route")
	var ambush_again := false
	for monster in cleared_road._monsters:
		if monster.idx == cleared_road._road_mail_ambush_idx(): ambush_again = true
	_check(not ambush_again, "快行伏击胜利读档后不再生成")
	cleared_road.queue_free()
	await get_tree().process_frame
	var port := await _enter("shenyuan_port")
	var receiver := _entity(port, "road_mail_port_receiver")
	_check(receiver != null, "沉渊港生成归路收信人")
	if receiver != null: port.on_quest_entity(receiver)
	await get_tree().process_frame
	_check(String(G.road_mail_state().get("status")) == "delivered", "收信人签收")
	_check("港口" in String(G.road_mail_state().get("reply", "")), "收信人留下具体回信")
	port.queue_free()
	await get_tree().process_frame
	frost = await _enter("frost_post")
	board = _entity(frost, "road_mail_board")
	if board != null: frost.on_quest_entity(board)
	var gold_before := int(G.wallet.get("gold", 0))
	if frost._road_mail_panel != null:
		_click(_find_button(frost._road_mail_panel, "交回平安 · 领取报酬"))
	await get_tree().process_frame
	_check(int(G.wallet.get("gold", 0)) - gold_before == 160 and
		int(G.road_mail_state().get("deliveries", 0)) == 1, "回驿奖励一次入账")
	board = _entity(frost, "road_mail_board")
	_check(board != null, "当天结清后邮驿仍可查看路簿")
	var claimed := G.prog.duplicate(true)
	_check(not bool(G.road_mail_action("claim", "frost_post").get("ok", false))
		and G.prog == claimed, "领奖不能重复")
	_check(G.reload_save() and int(G.road_mail_state().get("deliveries", 0)) == 1,
		"完成记录读档保留")
	_check((G.road_mail_state().get("archive", []) as Array).size() == 1 and
		"阿澜" in String((G.road_mail_state()["archive"] as Array)[0]["letter"]),
		"首封信与回信可从邮驿记录重读")
	if board != null: frost.on_quest_entity(board)
	_check(frost._road_mail_panel != null and
		_find_button(frost._road_mail_panel, "翻看路簿 · 1 封") != null and
		_find_button(frost._road_mail_panel, "快行 · 风沙路标") == null,
		"同日只能翻路簿，不能重新接单")
	if frost._road_mail_panel != null:
		_click(_find_button(frost._road_mail_panel, "翻看路簿 · 1 封"))
		_check(_has_text(frost._road_mail_panel, "阿澜") and
			_has_text(frost._road_mail_panel, "港口这边也会留一盏") and
			_has_text(frost._road_mail_panel, "照刻痕辨路"),
			"游戏内可翻阅首封信、回信与实际解法")
		_click(_find_button(frost._road_mail_panel, "返回邮驿"))
		_check(_find_button(frost._road_mail_panel, "翻看路簿 · 1 封") != null,
			"路簿返回邮驿不关闭浮层")
		_click(_find_button(frost._road_mail_panel, "返回"))
	await get_tree().process_frame
	var real_mail: Dictionary = G.prog["road_mail"].duplicate(true)
	var demo_mail := real_mail.duplicate(true)
	var demo_archive: Array = demo_mail["archive"]
	for i in 2:
		demo_archive.append({"run_id": "demo%d" % i, "day": i + 2,
			"route": "safe", "solution": "supply",
			"letter": "第 %d 封测试信" % (i + 2), "reply": "第 %d 封测试回信" % (i + 2)})
	G.prog["road_mail"] = demo_mail
	var archive_panel := preload("res://src/ui/RoadMailPanel.gd").new()
	add_child(archive_panel)
	archive_panel.open_board()
	_click(_find_button(archive_panel, "翻看路簿 · 3 封"))
	_check(_has_text(archive_panel, "第 3 封测试回信"), "路簿默认先看最新一封")
	_click(_find_button(archive_panel, "更早一封"))
	_check(_has_text(archive_panel, "第 2 封测试回信"), "路簿可向前翻阅")
	_click(_find_button(archive_panel, "更早一封"))
	_check(_has_text(archive_panel, "阿澜") and
		_find_button(archive_panel, "更早一封") == null,
		"最早一封没有越界翻页按钮")
	_click(_find_button(archive_panel, "更新一封"))
	_check(_has_text(archive_panel, "第 2 封测试回信"), "路簿可向后翻回")
	_click(_find_button(archive_panel, "返回邮驿"))
	_click(_find_button(archive_panel, "返回"))
	G.prog["road_mail"] = real_mail
	var state := G.road_mail_state()
	var tomorrow := int(G.economy_state().get("day", 1)) + 1
	var safe: Dictionary = RoadMailServiceScript.transition(state, "accept_safe", "frost_post", tomorrow)
	_check(bool(safe.get("ok", false)) and String((safe.get("next", {}) as Dictionary).get("route")) == "safe",
		"下一游戏日稳行路线可接")
	_check(not RoadMailServiceScript.visible("road_mail_quick_marker", safe.get("next", {}), tomorrow, true)
		and RoadMailServiceScript.visible("road_mail_sand_signal", safe.get("next", {}), tomorrow, true),
		"新路线目标顺序正确")
	var next_state: Dictionary = safe.get("next", {})
	var inspected: Dictionary = RoadMailServiceScript.transition(next_state, "inspect", "red_sand_route", tomorrow)
	_check(bool(inspected.get("ok", false)), "稳行路也能观察风沙")
	G.prog["road_mail"] = inspected.get("next", {})
	G.economy_state()["day"] = tomorrow
	G.wallet["gold"] = 0
	_check(not bool(G.road_mail_action("pass_supply", "red_sand_route").get("ok", false)) and
		String(G.road_mail_state().get("phase")) == "clue", "金币不足时不能买路图或跳过路况")
	G.wallet["gold"] = 40
	var before_supply := int(G.wallet["gold"])
	_check(bool(G.road_mail_action("pass_supply", "red_sand_route").get("ok", false)) and
		int(G.wallet["gold"]) == before_supply - 18 and
		String(G.road_mail_state().get("solution")) == "supply" and
		String(G.road_mail_state().get("phase")) == "hazard",
		"补给方案只扣 18 金并进入稳行遭遇")
	_check(G.reload_save() and String(G.road_mail_state().get("solution")) == "supply" and
		not bool(G.road_mail_action("pass_supply", "red_sand_route").get("ok", false)),
		"付费方案读档后不可再扣费")
	var safe_road := await _enter("red_sand_route")
	var courier := _entity(safe_road, "road_mail_safe_courier")
	_check(courier != null, "稳行路生成受伤信使而非专属伏沙蝎")
	var safe_ambush := false
	for monster in safe_road._monsters:
		if monster.idx == safe_road._road_mail_ambush_idx(): safe_ambush = true
	_check(not safe_ambush, "稳行路不生成快行伏击")
	if courier != null: safe_road.on_quest_entity(courier)
	_check(safe_road._puzzle_panel != null and
		_find_button(safe_road._puzzle_panel, "付 12 金包扎 · 报酬不减") != null and
		_find_button(safe_road._puzzle_panel, "扶他慢行 · 少 20 金") != null,
		"受伤信使提供明确代价的双方案")
	if safe_road._puzzle_panel != null:
		_click(_find_button(safe_road._puzzle_panel, "扶他慢行 · 少 20 金"))
	await get_tree().process_frame
	_check(String(G.road_mail_state().get("phase")) == "pass" and
		String(G.road_mail_state().get("encounter")) == "escort" and
		int(G.road_mail_state().get("penalty_gold")) == 20 and
		int(G.wallet["gold"]) == before_supply - 18,
		"免费护送不扣金币，报酬减少写入本趟邮路")
	_check(G.reload_save() and String(G.road_mail_state().get("encounter")) == "escort",
		"稳行遭遇读档后保留")
	safe_road.queue_free()
	await get_tree().process_frame
	var safe_port := await _enter("shenyuan_port")
	var safe_receiver := _entity(safe_port, "road_mail_port_receiver")
	if safe_receiver != null: safe_port.on_quest_entity(safe_receiver)
	_check(String(G.road_mail_state().get("status")) == "delivered", "稳行护送后可签收")
	safe_port.queue_free()
	await get_tree().process_frame
	var reward_before := int(G.wallet["gold"])
	_check(bool(G.road_mail_action("claim", "frost_post").get("ok", false)) and
		int(G.wallet["gold"]) == reward_before + 140 and
		String((G.road_mail_state()["archive"] as Array).back().get("encounter", "")) == "escort",
		"护送少 20 金报酬且路簿记录遭遇")
	var help_state := RoadMailServiceScript.ensure(G.road_mail_state())
	help_state["status"] = "active"
	help_state["phase"] = "hazard"
	help_state["route"] = "safe"
	var help: Dictionary = RoadMailServiceScript.transition(help_state, "hazard_help", "red_sand_route", tomorrow + 1)
	_check(bool(help.get("ok", false)) and int(help.get("cost_gold", 0)) == 12 and
		int((help.get("next", {}) as Dictionary).get("penalty_gold", -1)) == 0,
		"付费包扎保留完整报酬，纯状态转换不直接扣款")
	var old_pass: Dictionary = {"status": "active", "phase": "pass", "route": "quick",
		"run_id": "old-mail", "run_seq": 1, "deliveries": 0,
		"letter": "旧版在途信", "reply": "", "archive": []}
	_check(bool(RoadMailServiceScript.transition(old_pass, "deliver", "shenyuan_port", tomorrow).get("ok", false)),
		"升级前已越过路口的邮袋可直接签收")
	G.prog["road_mail"] = help_state
	G.wallet["gold"] = 11
	_check(not bool(G.road_mail_action("hazard_help", "red_sand_route").get("ok", false)) and
		String(G.road_mail_state().get("phase")) == "hazard" and int(G.wallet["gold"]) == 11,
		"包扎费不足时信使状态与金币都不变")
	G.wallet["gold"] = 12
	_check(bool(G.road_mail_action("hazard_help", "red_sand_route").get("ok", false)) and
		int(G.wallet["gold"]) == 0 and
		String(G.road_mail_state().get("encounter")) == "help",
		"付费包扎只扣 12 金并记录分支")
	_check(G.reload_save() and String(G.road_mail_state().get("encounter")) == "help" and
		not bool(G.road_mail_action("hazard_help", "red_sand_route").get("ok", false)),
		"包扎分支读档后不会重复扣款")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(G.SAVE_PATH))
	var broken := saved.duplicate(true)
	broken["prog"]["road_mail"]["observed_clues"] = ["forged"]
	_check(not bool(SaveData.validate(broken, int(Time.get_unix_time_from_system())).get("ok", true)),
		"非法邮路线索不能导入存档")
	var capped := RoadMailServiceScript.ensure({})
	for i in 9:
		capped["status"] = "delivered"
		capped["phase"] = ""
		capped["route"] = "quick"
		capped["run_id"] = "cap%d" % i
		capped["letter"] = "寄出 %d" % i
		capped["reply"] = "收到 %d" % i
		capped["solution"] = "observe"
		var closed: Dictionary = RoadMailServiceScript.transition(capped, "claim", "frost_post", i + 1)
		_check(bool(closed.get("ok", false)), "路簿压力结算 %d" % i)
		capped = closed.get("next", {})
	var last_eight: Array = capped.get("archive", [])
	_check(last_eight.size() == 8 and String((last_eight[0] as Dictionary).get("run_id")) == "cap1" and
		String((last_eight[7] as Dictionary).get("run_id")) == "cap8",
		"路簿仅保留最近八封且顺序稳定")
	frost.queue_free()
