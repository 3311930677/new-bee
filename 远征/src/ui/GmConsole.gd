# GmConsole.gd —— GM 开发者控制台（调试用）
# 唤起：F10 或 `（见 G.ACTIONS.gm_console）。平时完全隐藏、不拦输入；
# 唤起后需输入开发者口令，口令通过才展开调试按钮（满级 / 全解锁 / 资源 / 重置）。
# 解锁态只保留在本次运行内（G.gm_unlocked），不落盘——避免误发存档。
extends CanvasLayer

const VIEW_W := 480.0
const PANEL_X := 30.0
const PANEL_Y := 200.0
const PANEL_W := 420.0
const PANEL_H_LOCKED := 224.0
const PANEL_H_OPEN := 364.0
const CLOSE_Y_LOCKED := 150.0
const CLOSE_Y_OPEN := 292.0

var _root: Control = null
var _panel: PanelContainer = null
var _pw: LineEdit = null
var _unlock_btn: Control = null
var _hint: Label = null
var _tools: Control = null
var _locked_info: Control = null
var _close_btn: Control = null


func _ready() -> void:
	layer = 100
	visible = false
	# 常驻最上层：任何界面都能唤起
	process_mode = Node.PROCESS_MODE_ALWAYS


## 用 _input 抢在各界面之前：否则底层场景的 ESC 处理会先把按键吃掉
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("gm_console"):
		toggle()
		var vp := get_viewport()  # 切场景途中可能为 null
		if vp != null:
			vp.set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		var vp2 := get_viewport()
		if vp2 != null:
			vp2.set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if _root == null:
		_build()
	visible = true
	G.ui_blocked = true
	_sync_state()
	if not G.gm_unlocked and _pw != null:
		_pw.grab_focus()


func close() -> void:
	visible = false
	G.ui_blocked = false


# ================= 构建 =================
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# 遮罩：吞掉鼠标事件，避免误点到底下的界面
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	# 别用锚点定位：CanvasLayer 下浮层自己的 rect 要等一帧才结算，写死坐标最稳
	var banner := G.banner_box("开发者控制台", 300, 50)
	banner.position = Vector2(90, 132)
	_root.add_child(banner)

	_panel = G.parchment_box(PANEL_W, PANEL_H_LOCKED, 18.0)
	_panel.position = Vector2(PANEL_X, PANEL_Y)
	_root.add_child(_panel)

	# PanelContainer 是容器，直接放子控件会被布局系统接管位置，包一层 Control 手动排
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(content)

	_pw = LineEdit.new()
	_pw.secret = true
	_pw.placeholder_text = "开发者口令"
	_pw.custom_minimum_size = Vector2(250, 40)
	_pw.position = Vector2(0, 12)
	G.style_line_edit(_pw)
	_pw.text_submitted.connect(func(_t: String): _try_unlock())
	content.add_child(_pw)

	_unlock_btn = G.gold_button("解 锁", 118, 40)
	_unlock_btn.position = Vector2(266, 12)
	_unlock_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_try_unlock())
	content.add_child(_unlock_btn)

	_hint = G.gold_label("", G.FS_XS, false, Color("8a6a34"), false)
	_hint.position = Vector2(0, 58)
	_hint.custom_minimum_size = Vector2(384, 0)
	content.add_child(_hint)

	# 未解锁时用说明文字把面板填满，别让口令下面空一大块
	_locked_info = Control.new()
	_locked_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_locked_info)
	var info_lines := [
		"· 一键满配：满级 · 世界与宠物全解锁 · 四币管够",
		"· 单项：满级 / 解锁世界 / 解锁宠物 / 标记通关 / 重置存档",
		"· 解锁 / 已通关 是两种状态 · F10 或 ` 随时开关",
	]
	for i in info_lines.size():
		var ln := G.text_label(info_lines[i], G.FS_XS, Color("6a5a3a"))
		ln.position = Vector2(0, 88 + i * 20)
		ln.custom_minimum_size = Vector2(384, 0)
		_locked_info.add_child(ln)

	_tools = Control.new()
	_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_tools)

	# 主操作：一键满配（全解锁 + 满级 + 资源）
	var all_btn := G.gold_button("一键满配（全解锁 + 满级 + 资源）", 384, 44, G.FS_MD)
	all_btn.position = Vector2(0, 90)
	all_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.gm_grant_all()
			_flash("已满配：世界/宠物全解锁，等级满级，资源管够"))
	_tools.add_child(all_btn)

	_pair(_tools, "满  级", 142,
		func(): G.gm_max_level(),
		"等级已拉满至上限")
	_pair(_tools, "解锁全部世界", 142,
		func(): G.gm_unlock_all_worlds(),
		"全部世界已解锁", 1)
	_pair(_tools, "解锁全部宠物", 190,
		func(): G.gm_unlock_all_pets(),
		"全部宠物已收集")
	_pair(_tools, "资源 +99999", 190,
		func(): G.gm_add_currency(99999),
		"四币各加 99999", 1)
	_pair(_tools, "重置存档", 238,
		func(): G.gm_reset_save(),
		"养成进度与钱包已重置")
	_pair(_tools, "全部标记已通关", 238,
		func(): G.gm_clear_all_worlds(),
		"全部世界已记为通关（可重游刷资源）", 1)

	# 关闭常驻：未解锁时也能用鼠标退出（否则只能用 ESC / F10）
	_close_btn = G.gold_button("关  闭", 184, 40, G.FS_SM)
	_close_btn.position = Vector2(100, CLOSE_Y_LOCKED)
	_close_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	content.add_child(_close_btn)


## 双列按钮：col 0 → x=0，col 1 → x=200
func _pair(parent: Control, title: String, y: float, fn: Callable,
		msg: String, col := 0) -> void:
	var b := G.gold_button(title, 184, 40, G.FS_SM)
	b.position = Vector2(col * 200.0, y)
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			fn.call()
			if msg != "":
				_flash(msg))
	parent.add_child(b)


# ================= 口令与状态 =================
func _try_unlock() -> void:
	if G.gm_check_password(_pw.text):
		_pw.text = ""
		_sync_state()
		_flash("口令正确 · 开发者权限已开启")
	else:
		_pw.text = ""
		_flash("口令错误")


func _sync_state() -> void:
	var unlocked := G.gm_unlocked
	if _pw != null:
		_pw.visible = not unlocked
	if _unlock_btn != null:
		_unlock_btn.visible = not unlocked
	if _tools != null:
		_tools.visible = unlocked
	if _locked_info != null:
		_locked_info.visible = not unlocked
	if _hint != null:
		_hint.text = "开发者权限已开启 · 点选下方调试项" if unlocked else "输入开发者口令以解锁调试功能"
		_hint.add_theme_color_override("font_color",
			Color("6a8a4a") if unlocked else Color("8a6a34"))
	# 未解锁时收紧面板：不留一大片空白
	if _panel != null:
		_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H_OPEN if unlocked else PANEL_H_LOCKED)
	if _close_btn != null:
		_close_btn.position = Vector2(100, CLOSE_Y_OPEN if unlocked else CLOSE_Y_LOCKED)


var _flash_l: Label = null
var _flash_tw: Tween = null

## 面板内的一次性反馈（不弹窗、不打断操作）
func _flash(msg: String) -> void:
	if _flash_l != null:
		_flash_l.queue_free()
		_flash_l = null
	if _flash_tw != null:
		_flash_tw.kill()
		_flash_tw = null
	_flash_l = G.gold_label(msg, G.FS_XS, false, Color("3a6a3a"), false)
	var panel_h := PANEL_H_OPEN if G.gm_unlocked else PANEL_H_LOCKED
	_flash_l.position = Vector2(PANEL_X, PANEL_Y + panel_h + 14.0)
	_flash_l.custom_minimum_size = Vector2(PANEL_W, 0)
	if _root != null:
		_root.add_child(_flash_l)
	_flash_tw = create_tween()
	_flash_tw.tween_interval(1.6)
	_flash_tw.tween_property(_flash_l, "modulate:a", 0.0, 0.45)
	_flash_tw.tween_callback(func():
		if _flash_l != null:
			_flash_l.queue_free()
			_flash_l = null)
