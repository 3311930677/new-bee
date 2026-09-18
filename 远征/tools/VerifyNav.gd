# VerifyNav.gd —— 手游返回适配回归（场景模式：godot --headless --path . res://tools/VerifyNav.tscn）
# 背景（轮次 14）：用户反馈「ESC 退出时灵时不灵，且这是手游，每个界面都要有能点的返回键」。
# 本用例把"返回"变成可回归的口径，三件事一起守：
#   A. 每个浮层**实例化后**必须能找到可见的返回类控件（返回/关闭/跳过/取消/撤退/退出），
#      —— 光在代码里有 ESC 分支不算，手机上没手指点得到的东西就是死路。
#   B. 每个浮层脚本必须自己吃 ESC（`ui_cancel`），不能指望父层代为关闭。
#   C. 每个吃 ESC 的脚本必须带 `G.ui_blocked` 守卫——否则开着 GM 控制台按 ESC，
#      会把控制台背后的浮层一起关掉（这正是"时灵时不灵"的根因）。
extends Node

const PANEL_DIR := "res://src/ui"

# 不需要"返回键/ESC"的脚本：autoload / 纯组件 / 无 UI / 过渡页
const SKIP_FILES := [
	"G.gd", "Audio.gd", "DataManager.gd", "GmConsole.gd", "PageDeck.gd", "SlideCard.gd",
	"Main.gd",        # 无 UI
	"LoadScreen.gd",  # 过渡页：加载中途不该能返回（返回了等于卡在半路）
]
# 有 ESC 但不吃 ui_blocked 的合法例外（GM 控制台本身的全屏层）
const BLOCKED_WHITELIST := ["GmConsole.gd"]

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_nav.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _run() -> void:
	await _verify_source_rules()
	await _verify_panel_affordance()
	await _verify_escape_layering()
	if _fails == 0:
		print("NAV_OK all tests passed")
	else:
		print("NAV_FAIL fails=%d" % _fails)


## B + C：源码扫描（不实例化，纯规则）
func _verify_source_rules() -> void:
	var dir := DirAccess.open(PANEL_DIR)
	_check(dir != null, "应能打开 " + PANEL_DIR)
	if dir == null:
		return
	var checked := 0
	for f in dir.get_files():
		if not f.ends_with(".gd") or SKIP_FILES.has(f):
			continue
		var src := _read(PANEL_DIR + "/" + f)
		_check(not src.is_empty(), "应能读到 " + f)
		if src.is_empty():
			continue
		checked += 1
		# B：浮层必须自己处理 ESC（只看动作判定，别把 Audio.sfx("ui_cancel") 的字符串算进来）
		var handles_esc := src.contains("is_action_pressed(\"ui_cancel\")")
		_check(handles_esc, "%s 缺少 ESC（ui_cancel）处理——浮层的返回不能只靠父层" % f)
		# C：吃 ESC 的地方必须有 ui_blocked 守卫
		if handles_esc and not BLOCKED_WHITELIST.has(f):
			_check(src.contains("ui_blocked"),
				"%s 的 ESC 没有 G.ui_blocked 守卫——开着 GM 控制台按 ESC 会关掉背后的浮层" % f)
	_check(checked >= 20, "面板源码扫描数应 ≥20，实为 %d" % checked)


## A：逐个实例化，找"手指点得到"的返回控件
func _verify_panel_affordance() -> void:
	var cases := [
		["WorldPanel", "res://src/ui/WorldPanel.gd"],
		["CodexPanel", "res://src/ui/CodexPanel.gd"],
		["ExchangePanel", "res://src/ui/ExchangePanel.gd"],
		["GachaPanel", "res://src/ui/GachaPanel.gd"],
		["SettingsPanel", "res://src/ui/SettingsPanel.gd"],
		["GrowthPanel", "res://src/ui/GrowthPanel.gd"],
		["TalentPanel", "res://src/ui/TalentPanel.gd"],
		["EquipPanel", "res://src/ui/EquipPanel.gd"],
		["PetRaisePanel", "res://src/ui/PetRaisePanel.gd"],
		["SkillBookPanel", "res://src/ui/SkillBookPanel.gd"],
		["MountPanel", "res://src/ui/MountPanel.gd"],
		["TitlePanel", "res://src/ui/TitlePanel.gd"],
		["QuestPanel", "res://src/ui/QuestPanel.gd"],
		["AvatarPanel", "res://src/ui/AvatarPanel.gd"],
		["ArenaPanel", "res://src/ui/ArenaPanel.gd"],
	]
	for c in cases:
		var name := String(c[0])
		var script: GDScript = load(String(c[1]))
		_check(script != null, "%s 脚本应能加载" % name)
		if script == null:
			continue
		var panel: Control = script.new()
		add_child(panel)
		await get_tree().process_frame   # 等 _ready 里把控件建出来
		var texts := _collect_texts(panel)
		var hit := _has_back_text(texts)
		_check(hit, "%s 实例化后找不到可见的返回类控件，现有文案：%s" % [name, str(texts)])
		panel.queue_free()
		await get_tree().process_frame


## C（运行期）：ESC 关浮层；ui_blocked 时不许关
## 计数用字典而不是局部变量：GDScript 的 lambda 捕获是**值拷贝**（交接文档坑 3），
## 直接 `var n := 0` + `func(): n += 1` 外层永远看不到。
func _verify_escape_layering() -> void:
	var script: GDScript = load("res://src/ui/WorldPanel.gd")
	var panel: Control = script.new()
	var hits := {"n": 0}
	panel.closed.connect(func(): hits["n"] = int(hits["n"]) + 1)
	add_child(panel)
	await get_tree().process_frame

	G.ui_blocked = true
	panel._unhandled_input(_esc())
	_check(int(hits["n"]) == 0, "ui_blocked（GM 控制台开着）时 ESC 不该关闭浮层")
	G.ui_blocked = false
	panel._unhandled_input(_esc())
	_check(int(hits["n"]) == 1, "ui_blocked 复位后 ESC 应关闭浮层，实为 %d 次" % int(hits["n"]))

	# 点可见返回按钮同样要能关（不依赖 ESC）
	hits["n"] = 0
	var btn := _find_back_control(panel)
	_check(btn != null, "WorldPanel 应能找到返回按钮控件")
	if btn != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		btn.gui_input.emit(click)
		_check(int(hits["n"]) == 1, "点返回按钮应发 closed，实为 %d 次" % int(hits["n"]))
	panel.queue_free()
	await get_tree().process_frame


func _esc() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	return e


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t


## 递归收集树里所有 Label 的文案（面板文案都写在 Label 上，够判定"有没有返回入口"）
func _collect_texts(root: Node) -> Array:
	var out: Array = []
	for n in root.get_children():
		var l := n as Label
		if l != null and not l.text.strip_edges().is_empty():
			out.append(l.text)
		out.append_array(_collect_texts(n))
	return out


func _has_back_text(texts: Array) -> bool:
	for t in texts:
		var s := String(t).replace(" ", "")
		if s.contains("返回") or s.contains("关闭") or s.contains("跳过"):
			return true
		if s.contains("取消") or s.contains("撤退") or s.contains("退出"):
			return true
	return false


## 找到那个"点了会关面板"的返回控件：文案命中返回类词的按钮所在的可点击祖先
func _find_back_control(root: Node) -> Control:
	for n in root.get_children():
		var c := n as Control
		if c != null and c.mouse_filter == Control.MOUSE_FILTER_STOP \
				and _has_back_text(_collect_texts(c)) and not c.gui_input.get_connections().is_empty():
			return c
		var deep := _find_back_control(n)
		if deep != null:
			return deep
	return null
