# VerifyPerf.gd —— 进场景耗时 + 按钮可点击性回归（场景模式，headless 亦可）
# 用法：godot --headless --path . res://tools/VerifyPerf.tscn
#
# 守两件事：
#  A. 一次性开销必须落在加载页，不能落在"玩家点进某个界面"的那一帧
#     （2016-09 实测过：GameHome 首进 533ms / 二次 31ms，差值全是 GDScript 编译）
#  B. 按钮不能被装饰性控件压住 —— 逐点在按钮上做命中测试，报告实际接收者
extends Node

const BUDGET_HOME_MS := 200      # 主界面（脚本已预热）
# 320 → 700（2026-10-29）。依据：用 git worktree 检出 0566a808（拉取前的旧提交）、全量 --import
# 后连跑 3 次，CityScene 进场 625/604/616ms；HEAD 78600ff6 实测落在 561~781ms
# （冷启动首跑出现过 1147ms 的离群值）。旧代码同样远超 320，说明 320 在这台机器上从未达标
# （10-02 的历史日志是 210~250ms，那台机器更快）。
# 700 下连跑 10 次实测 9 绿 1 红（中位约 620ms，离群值 720ms 超 20ms）。这个场景**无法**用
# 「多次取最小」压噪声（见 _enter 注释），所以尾部仍会偶发超出；要连 720 也绿需 750 左右，
# 要连冷启动 1147ms 也绿需 1200。宁可偶发红也不要预算形同虚设，故维持 700。
const BUDGET_CITY_MS := 700      # 旧独立城务场景；开局开放 7 座建筑，主世界另有同屏地图预算
# 100 → 130（2026-10-29）。首开是「真的第一次」，只能单次测量、吃满机器噪声，实测 10 轮
# 落在 57~126ms（「设置」「图鉴」最高）。旧值 100 余量不足 2%，会随机判红；130 给约 10% 余量。
# 注意别再往上抬：首开持续贴近 130 才是真实退化信号。
const BUDGET_PANEL_MS := 130     # 单个浮层（大卡面板已虚拟化：卡用到才建）
# 70 → 90 → 回退 70（2026-10-29）。曾因「设置」第二次开出现 76/102ms 判红而临时放宽到 90，
# 但那属机器争用噪声；改成「重开取三次最小」后不需要放宽，故回退原值（实测 10 轮全绿）。
const BUDGET_REOPEN_MS := 70     # 同一浮层第二次打开（纯结构成本）

# 计时采样次数。机器争用只会让耗时变长（噪声是单向的），取最小才接近真实成本；
# 系统性退化会让最小值一起抬高，仍会被拦住。
# ⚠️ 只适用于「可重复测量」的地方：浮层重开。场景进场不行——见 _enter 注释。
const MEASURE_TRIALS := 3

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
	if root is Control and not (root as Control).is_visible_in_tree():
		return null
	if root is Button and root.text.replace(" ","") == text.replace(" ",""):
		return root as Control
	if root is Button and text=="返回" and root.tooltip_text.begins_with("返回"):
		return root as Control
	var want := text.replace(" ", "")
	for c in root.get_children():
		# 原生自绘按钮也是 Control；识别实际输入接收者，继续做五点命中验证。
		if c is Control and c.mouse_filter == Control.MOUSE_FILTER_STOP and not c.gui_input.get_connections().is_empty():
			for g in c.get_children():
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
	# 这里**不能**「多次取最小」：load() 走 ResourceLoader 缓存，第二次起是缓存命中，
	# 取最小只会测到缓存路径（实测 CityScene 首次 600ms 级、第三次 16ms），守卫意义就没了。
	# 场景进场的噪声只能靠预算余量吸收，或由外部跑多进程取最小。
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
		var opener: Callable = opens[k][0]
		# 首次打开只量一次：它必须是真的「第一次」（首次构建全部控件）。
		# 重复测会退化成「重开」的结构成本，等于把要守的东西测没了。
		var t := Time.get_ticks_msec()
		opener.call()
		await get_tree().process_frame
		await get_tree().process_frame
		var first_ms := Time.get_ticks_msec() - t
		print("PERF 开浮层 %-6s 第1次    %5d ms（预算 %d）" % [name, first_ms, BUDGET_PANEL_MS])
		_check(first_ms <= BUDGET_PANEL_MS, "浮层「%s」第 1 次打开 %d ms 超预算 %d ms" % [name, first_ms, BUDGET_PANEL_MS])
		var panel: Control = home.get(k)
		if panel != null:
			_assert_clickable(panel, "返回", "浮层「%s」的返回按钮" % name)
			if name == "世界":
				_check(panel is RegionMapPanel,
					"世界入口应打开连通地区图，而非历练世界卡")
			panel.closed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		# 二次打开是同一个结构操作、可以重复，取 MEASURE_TRIALS 次最小滤掉噪声。
		var best := 1 << 30
		for trial in MEASURE_TRIALS:
			var t2 := Time.get_ticks_msec()
			opener.call()
			await get_tree().process_frame
			await get_tree().process_frame
			best = mini(best, Time.get_ticks_msec() - t2)
			var again: Control = home.get(k)
			if again != null:
				again.closed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
		print("PERF 开浮层 %-6s 第2次    %5d ms（预算 %d，%d 次取最小）" % [name, best, BUDGET_REOPEN_MS, MEASURE_TRIALS])
		_check(best <= BUDGET_REOPEN_MS, "浮层「%s」第 2 次打开 %d ms 超预算 %d ms" % [name, best, BUDGET_REOPEN_MS])
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
	_assert_clickable(city, "返回城内", "主城：建筑浮层返回")
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
