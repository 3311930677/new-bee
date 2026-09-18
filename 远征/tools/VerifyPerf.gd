# VerifyPerf.gd —— 进场景耗时 + 按钮可点击性回归（场景模式，headless 亦可）
# 用法：godot --headless --path . res://tools/VerifyPerf.tscn
#
# 守两件事：
#  A. 一次性开销必须落在加载页，不能落在"玩家点进某个界面"的那一帧
#     （2016-09 实测过：GameHome 首进 533ms / 二次 31ms，差值全是 GDScript 编译）
#  B. 按钮不能被装饰性控件压住 —— 逐点在按钮上做命中测试，报告实际接收者
extends Node

const BUDGET_HOME_MS := 200      # 主界面（脚本已预热）
const BUDGET_CITY_MS := 250      # 主城（480 格地面 + 8 NPC + 建筑）
const BUDGET_PANEL_MS := 100     # 单个浮层（大卡面板已虚拟化：卡用到才建）
const BUDGET_REOPEN_MS := 70     # 同一浮层第二次打开（纯结构成本）

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_perf.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


# ---------- Godot 命中规则复刻：先递归子树；IGNORE 只是"自己不吃"，不挡子节点 ----------
func _hit(node: Node, pos: Vector2) -> Control:
	var kids := node.get_children()
	for i in range(kids.size() - 1, -1, -1):
		var c := kids[i]
		if c is CanvasLayer:
			# HUD / 浮层层也是 CanvasItem，命中测试必须穿过去（否则主城按钮永远"点不到"）
			var l := c as CanvasLayer
			if l.visible:
				var in_layer := _hit(l, pos)
				if in_layer != null:
					return in_layer
			continue
		if not (c is Control):
			continue
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		var sub := _hit(ctl, pos)
		if sub != null:
			return sub
		if ctl.mouse_filter == Control.MOUSE_FILTER_STOP and ctl.get_global_rect().has_point(pos):
			return ctl
	return null


func _find_btn(root: Node, text: String) -> Control:
	var want := text.replace(" ", "")
	for c in root.get_children():
		if c is PanelContainer:
			for g in (c as PanelContainer).get_children():
				if g is Label and (g as Label).text.replace(" ", "") == want:
					return c
		var r := _find_btn(c, text)
		if r != null:
			return r
	return null


## 五点命中测试：中心 + 四角内缩 3px（角上原本最容易被装饰层咬掉）
func _assert_clickable(root: Node, text: String, tag: String) -> void:
	var btn := _find_btn(root, text)
	if btn == null:
		_check(false, "%s：找不到按钮「%s」" % [tag, text])
		return
	var r := btn.get_global_rect()
	var pts := [r.get_center(), r.position + Vector2(3, 3),
		Vector2(r.end.x - 3.0, r.position.y + 3.0),
		Vector2(r.position.x + 3.0, r.end.y - 3.0), r.end - Vector2(3, 3)]
	for p: Vector2 in pts:
		var hit := _hit(root, p)
		var ok: bool = hit == btn or (hit != null and btn.is_ancestor_of(hit))
		var who := "空白"
		if hit != null:
			who = "%s[%s]" % [hit.name, hit.get_class()]
		_check(ok, "%s：点 %s 未能落到按钮上（实际接收 %s）" % [tag, str(p), who])


func _demo() -> void:
	G.prog = {"level": 12, "exp": 300, "worlds_unlocked": 3,
		"world_cleared": {"forest": true}, "pets": []}
	G.ensure_starter_pets()
	G.wallet = {"gold": 5000, "expedition": 200, "soul": 30, "honor": 600}
	G.selected_role = "zs"
	G.player_name = "试剑"


func _enter(path: String, budget: int, tag: String) -> Control:
	var t := Time.get_ticks_msec()
	var n: Control = load(path).instantiate()
	add_child(n)
	await get_tree().process_frame
	await get_tree().process_frame
	var ms := Time.get_ticks_msec() - t
	print("PERF %-22s %5d ms（预算 %d）" % [tag, ms, budget])
	_check(ms <= budget, "%s 耗时 %d ms 超出预算 %d ms（一次性开销应已在加载页付掉）" % [tag, ms, budget])
	return n


func _run() -> void:
	# ---- 0. 加载页：预热清单要能跑完（含脚本/场景编译） ----
	var t0 := Time.get_ticks_msec()
	var ls: Control = load("res://src/ui/LoadScreen.tscn").instantiate()
	ls.set("auto_advance", false)   # 别让加载页把我们顶掉（它会切场景）
	add_child(ls)
	var guard := 0
	while guard < 600 and not bool(ls.get("_done")):
		await get_tree().process_frame
		guard += 1
	print("PERF 加载页预热完（含编译）    %5d ms" % (Time.get_ticks_msec() - t0))
	_check(bool(ls.get("_done")), "加载页 600 帧内应跑完预热队列")
	_check((ls.get("_code") as Array).is_empty(), "预热清单里的脚本/场景应全部编译完")
	_check(G._res_index.size() > 200, "素材索引应建成（实为 %d 项）" % G._res_index.size())
	ls.queue_free()
	await get_tree().process_frame

	# ---- 1. 主界面 ----
	_demo()
	var home := await _enter("res://src/ui/GameHome.tscn", BUDGET_HOME_MS, "GameHome 进场景")

	# ---- 2. 六个浮层：首次 + 二次打开 ----
	var opens := {
		"_worlds": [func(): home.call("_open_worlds", _down()), "世界"],
		"_codex": [func(): home.call("_open_codex", _down()), "图鉴"],
		"_gacha": [func(): home.call("_open_gacha"), "召唤"],
		"_exchange": [func(): home.call("_open_exchange"), "兑换"],
		"_settings": [func(): home.call("_open_settings", _down()), "设置"],
		"_growth": [func(): home.call("_open_growth"), "养成"],
	}
	for k in opens:
		var name := String(opens[k][1])
		var first := -1
		for round_i in 2:
			var t := Time.get_ticks_msec()
			(opens[k][0] as Callable).call()
			await get_tree().process_frame
			await get_tree().process_frame
			var ms := Time.get_ticks_msec() - t
			var budget := BUDGET_PANEL_MS if round_i == 0 else BUDGET_REOPEN_MS
			print("PERF 开浮层 %-6s 第%d次    %5d ms（预算 %d）" % [name, round_i + 1, ms, budget])
			_check(ms <= budget, "浮层「%s」第 %d 次打开 %d ms 超预算 %d ms" % [name, round_i + 1, ms, budget])
			if round_i == 0:
				first = ms
			var panel: Control = home.get(k)
			if panel != null:
				_assert_clickable(panel, "返回", "浮层「%s」的返回按钮" % name)
				if name == "世界":
					# 虚拟化：世界图志首开只应建首屏相邻卡（8 张大卡全建是这轮优化掉的卡顿源）
					var deck: Control = panel.get("_deck")
					var made := int(deck.call("made_count")) if deck != null else -1
					_check(deck != null and made <= 3,
						"世界图志应只建首屏相邻卡（虚拟化），实为 %d 张" % made)
				panel.closed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
	home.queue_free()
	await get_tree().process_frame

	# ---- 3. 主城 ----
	_demo()
	var city := await _enter("res://src/city/CityScene.tscn", BUDGET_CITY_MS, "CityScene 进场景")
	var hud: CanvasLayer = city.get("_hud")
	_assert_clickable(hud, "回营", "主城：回营")
	_assert_clickable(hud, "出 征", "主城：出征")
	# 建筑浮层（点议事厅）里的返回
	city.call("_open_building", G.city_building("hall"))
	await get_tree().process_frame
	_assert_clickable(city, "返 回", "主城：建筑浮层返回")
	city.call("_close_panel")
	await get_tree().process_frame
	city.queue_free()

	if _fails == 0:
		print("PERF_OK all tests passed")
	else:
		print("PERF_FAIL fails=%d" % _fails)


func _down() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev
