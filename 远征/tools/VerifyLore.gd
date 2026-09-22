# VerifyLore.gd —— 世界志与序章回归（场景模式：godot --headless --path . res://tools/VerifyLore.tscn）
# 守：data/lore.json 的完整性（八境志异俱全）、主线目标随进度正确推进、
#     序章能逐页看完并落盘 lore_seen、序章文案与配置一一对应。
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_lore.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _baseline() -> void:
	G.prog = {"level": 1, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": []}
	G.ensure_starter_pets()
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.selected_role = "zs"
	G.player_name = "试剑"
	G.save_game()


func _run() -> void:
	_baseline()

	# ---- A. 设定表完整性 ----
	var w := G.world_setting()
	_check(not String(w.get("name", "")).is_empty(), "lore.json 应给出界名 world.name")
	_check(not String(w.get("era", "")).is_empty(), "lore.json 应给出纪年 world.era")
	_check(String(w.get("premise", "")).length() >= 30, "世界局势 premise 不该太短（实为 %d 字）"
		% String(w.get("premise", "")).length())
	_check(not String(w.get("you", "")).is_empty(), "应交代主角身份 world.you")

	var order := G.theme_order()
	_check(order.size() == 8, "maps.json 应有 8 片大陆，实为 %d" % order.size())
	var missing: Array = []
	for t in order:
		var tid := String(t)
		var tl := G.theme_lore(tid)
		if String(tl.get("epigraph", "")).is_empty():
			missing.append(tid + ":epigraph")
		if String(tl.get("lore", "")).length() < 20:
			missing.append(tid + ":lore")
		if String(tl.get("boss_lore", "")).is_empty():
			missing.append(tid + ":boss_lore")
		# 首领名必须从 maps.json → monsters.json 解析出来（不许解析成空/退回 id）
		var boss := String(tl.get("boss", ""))
		_check(not boss.is_empty() and not boss.begins_with("mon_"),
			"「%s」的首领名应从 monsters.json 取到中文名，实为「%s」" % [tid, boss])
	_check(missing.is_empty(), "八境志异缺项：%s" % str(missing))

	# 序章页数（世界志一页 + 正文页）
	var pages := G.prologue_pages()
	_check(pages.size() >= 4, "序章至少 4 页，实为 %d" % pages.size())
	var bad_page := ""
	for p in pages:
		var pd := p as Dictionary
		if String(pd.get("title", "")).is_empty() or (pd.get("lines", []) as Array).is_empty():
			bad_page = str(pd)
	_check(bad_page.is_empty(), "序章每页都要有 title 与 lines，问题页：%s" % bad_page)

	# ---- B. 主线目标随进度推进 ----
	_check(not G.lore_seen(), "新档默认不该是「已看序章」")
	var goal := G.main_goal()
	_check(String(goal.get("theme", "")) == "forest",
		"初始主线目标应指向主世界 forest，实为「%s」" % String(goal.get("theme", "")))
	_check(String(goal.get("title", "")).contains("森林之主"),
		"目标标题应点出首领名「森林之主」，实为「%s」" % String(goal.get("title", "")))
	var joined := " ".join(PackedStringArray(goal.get("lines", [])))
	_check(joined.contains("出征"), "可达成的目标应给出「出征」指引，实为「%s」" % joined)
	_check(G.main_goal_short().contains("苍绿林海"),
		"主页那一行摘要应含大陆名，实为「%s」" % G.main_goal_short())

	G.on_world_cleared("forest")
	_check(String(G.main_goal().get("theme", "")) == "snow",
		"通关 forest 后目标应推进到 snow，实为「%s」" % String(G.main_goal().get("theme", "")))
	# 解锁数落后于通关数的档（改档/老档）：目标仍指向下一片，但指引要说清"碑门推不开"
	G.prog["world_cleared"] = {"forest": true, "snow": true}
	G.prog["worlds_unlocked"] = 1
	var g3 := G.main_goal()
	_check(String(g3.get("theme", "")) == "volcano", "应继续推进到 volcano")
	var j3 := " ".join(PackedStringArray(g3.get("lines", [])))
	_check(j3.contains("推不开"), "未解锁秘境的指引应说明需要先打前一片，实为「%s」" % j3)
	G.prog["worlds_unlocked"] = 3   # 解锁到位后，指引应回到「出征」
	var j4 := " ".join(PackedStringArray(G.main_goal().get("lines", [])))
	_check(j4.contains("出征"), "解锁到位后应给可出征指引，实为「%s」" % j4)

	G.gm_clear_all_worlds()
	var g_end := G.main_goal()
	_check(String(g_end.get("theme", "")).is_empty(), "全通关后不应再指向某片秘境")
	var j_end := " ".join(PackedStringArray(g_end.get("lines", [])))
	_check(j_end.contains("王城"), "全通关目标应收束到王城，实为「%s」" % j_end)

	# ---- C. 序章看完落盘，重新读档仍然记得 ----
	_baseline()
	_check(not G.lore_seen(), "复位后应回到「未看序章」")
	G.mark_lore_seen()
	_check(G.lore_seen(), "mark_lore_seen 后应置位")
	G.prog = {"level": 1, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": []}
	G._load_save()
	_check(G.lore_seen(), "读档后 lore_seen 应保留（老档没这字段则默认 false）")

	# ---- D. 序章场景能逐页走完 ----
	_baseline()
	var packed: PackedScene = load("res://src/ui/Prologue.tscn")
	_check(packed != null, "Prologue.tscn 应能加载")
	var pro: Control = packed.instantiate()
	pro.set("on_finish_scene", "")   # 别让它切场景（测试节点会被顶掉）
	add_child(pro)
	await get_tree().process_frame
	var total: int = int((pro.get("_pages") as Array).size())
	_check(total == pages.size() + 1,
		"序章页数应为「世界志 1 页 + 正文 %d 页」，实为 %d" % [pages.size(), total])
	var lines_box: VBoxContainer = pro.get("_lines_box")
	_check(lines_box != null and lines_box.get_child_count() > 0, "首屏应已排出正文行")
	var guard := 0
	while int(pro.get("_page")) < total - 1 and guard < total + 4:
		pro.call("_advance")
		await get_tree().process_frame
		guard += 1
	_check(int(pro.get("_page")) == total - 1, "连点「继续」应能走到最后一页，实为第 %d 页"
		% (int(pro.get("_page")) + 1))
	var last_box: VBoxContainer = pro.get("_lines_box")
	_check(last_box.get_child_count() > 0, "最后一页也要有正文行")
	pro.call("_advance")   # 最后一页再推进 = 启程
	await get_tree().process_frame
	_check(G.lore_seen(), "走完序章应记为已看")
	pro.queue_free()
	await get_tree().process_frame

	# ---- E. 剧情演出节拍（首领前「对峙」 / 战后「余韵」） ----
	_baseline()
	var beat_missing: Array = []
	for t in order:
		var tid := String(t)
		if G.boss_beat_lines(tid, "intro").size() < 2:
			beat_missing.append(tid + ":intro")
		if G.boss_beat_lines(tid, "outro").size() < 2:
			beat_missing.append(tid + ":outro")
	_check(beat_missing.is_empty(), "八境演出文本缺项（每段至少 2 行）：%s" % str(beat_missing))

	# 只演一次的门禁 + 存档往返
	_check(not G.beat_seen("forest", "intro"), "新档不该看过对峙")
	G.mark_beat_seen("forest", "intro")
	_check(G.beat_seen("forest", "intro"), "标记后应记位")
	_check(not G.beat_seen("forest", "outro"), "标记 intro 不该带出 outro")
	G.prog = {"level": 1, "exp": 0, "worlds_unlocked": 1, "world_cleared": {}, "pets": []}
	G._load_save()
	_check(G.beat_seen("forest", "intro"), "读档后节拍记录应保留（老档无字段默认未看）")
	_check(not G.beat_seen("snow", "intro"), "未标记的秘境应回到未看")

	# 演出层：能建、能铺满、能推进结束并回调
	var sb_packed: PackedScene = load("res://src/ui/StoryBeat.tscn")
	_check(sb_packed != null, "StoryBeat.tscn 应能加载")
	var sb: Control = sb_packed.instantiate()
	sb.set("instant", true)
	sb.call("setup", "forest", "intro")
	var done := {"v": false}
	sb.set("on_done", func(): done["v"] = true)
	add_child(sb)
	await get_tree().process_frame
	_check(int(sb.get("_revealed")) == G.boss_beat_lines("forest", "intro").size(),
		"instant 模式应一次铺满全部台词行")
	sb.call("_advance")
	_check(bool(done["v"]), "推进到末尾应触发 on_done 回调")
	_check(is_instance_valid(sb) and sb.is_queued_for_deletion(), "演出结束后应自回收")
	await get_tree().process_frame

	if _fails == 0:
		print("LORE_OK all tests passed")
	else:
		print("LORE_FAIL fails=%d" % _fails)
