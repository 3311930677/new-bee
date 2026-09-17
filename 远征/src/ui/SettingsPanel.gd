# SettingsPanel.gd —— 设置浮层（存档导出/导入剪贴板 · 键位说明 · 回标题 · 重置存档二次确认）
# 结构与 CodexPanel 一致：遮罩 → 木匾 → 羊皮纸 → 内包 content 手动布局；父层负责 closed 后回收
class_name SettingsPanel
extends Control

signal closed

# 同 DeployPanel：440 羊皮纸 - 左右各 16 内边距 = 408，子控件按 408 排版才不右偏
const CONTENT_W := 408.0
const TITLE_PATH := "res://src/ui/Title.tscn"

var _content: Control = null
var _code: LineEdit = null   # 存档码输入框
var _note1: Label = null     # 导出行右侧说明 / 复制结果反馈
var _hint2: Label = null     # 导入反馈（默认引导 / 红字报错 / 绿字成功）
var _reset_btn: Control = null
var _reset_hint: Label = null
var _reset_armed := false    # 重置二次确认：第一次点只亮「确认重置？」，再点才执行


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var banner := G.banner_box("设 置", 300, 50)
	banner.position = Vector2(90, 36)
	add_child(banner)

	var panel := G.parchment_box(440, 524, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)

	# PanelContainer 是容器，直接放子控件会被布局系统接管位置，包一层 Control 手动布局
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_content)

	# 顶部小徽记（ui_notice 有图用图，缺素材回退一枚字符花饰，不强制装饰）
	var notice := _emblem("ui_notice", 30)
	notice.position = Vector2((CONTENT_W - 30.0) * 0.5, 0)
	_content.add_child(notice)

	# ---- 存档备份：导出到剪贴板 ----
	_section("存档备份", 40)
	var exp_btn := G.gold_button("复制存档码", 180, 36, G.FS_SM)
	exp_btn.position = Vector2(0, 68)
	exp_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_export())
	_content.add_child(exp_btn)
	_note1 = G.gold_label("把整份存档复制到剪贴板", G.FS_XS, false, Color("8a6a34"), false)
	_note1.position = Vector2(196, 77)
	_note1.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_note1.custom_minimum_size = Vector2(212, 0)
	_content.add_child(_note1)

	# ---- 存档导入：粘贴码 / 手贴 → 校验写档 ----
	_section("存档导入", 114)
	_code = LineEdit.new()
	_code.placeholder_text = "点「粘贴码」读入剪贴板，或直接粘贴存档码"
	_code.custom_minimum_size = Vector2(CONTENT_W, 42)
	_code.position = Vector2(0, 142)
	G.style_line_edit(_code, G.FS_SM)
	_content.add_child(_code)

	var paste_btn := G.gold_button("粘贴码", 118, 36, G.FS_SM)
	paste_btn.position = Vector2(0, 192)
	paste_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_paste())
	_content.add_child(paste_btn)
	var imp_btn := G.gold_button("导 入", 118, 36, G.FS_SM)
	imp_btn.position = Vector2(134, 192)
	imp_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_import())
	_content.add_child(imp_btn)

	_hint2 = G.gold_label("校验通过后写档并回到标题重新读档", G.FS_XS, false, Color("8a6a34"), false)
	_hint2.position = Vector2(0, 236)
	_hint2.custom_minimum_size = Vector2(CONTENT_W, 0)
	_content.add_child(_hint2)

	# ---- 键位说明：静态文字 ----
	_section("键位说明", 266)
	var keys := [
		"WASD / 方向键 —— 人物移动",
		"Esc —— 关闭当前浮层",
		"F10 / ` —— 开发者控制台",
	]
	for i in keys.size():
		var ln := G.text_label(keys[i], G.FS_SM, Color("6a5a3a"))
		ln.position = Vector2(0, 294 + i * 24.0)
		ln.custom_minimum_size = Vector2(CONTENT_W, 0)
		_content.add_child(ln)

	# ---- 危险区：回标题 / 重置存档（二次确认） ----
	var title_btn := G.gold_button("回到标题", 196, 40, G.FS_SM)
	title_btn.position = Vector2(0, 374)
	title_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_title())
	_content.add_child(title_btn)
	_reset_btn = G.gold_button("重置存档", 196, 40, G.FS_SM)
	_reset_btn.position = Vector2(212, 374)
	_reset_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_reset_click())
	_content.add_child(_reset_btn)

	_reset_hint = G.gold_label("再点一次执行重置 · 其他操作取消", G.FS_XS, false, Color("a04a3a"), false)
	_reset_hint.position = Vector2(0, 424)
	_reset_hint.custom_minimum_size = Vector2(CONTENT_W, 0)
	_reset_hint.visible = false
	_content.add_child(_reset_hint)

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 456)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_back())
	_content.add_child(back)


## 区块小标题（同 DeployPanel._section 的画法）
func _section(text: String, y: float) -> void:
	var l := G.gold_label(text, G.FS_SM, false, Color("7a5a2e"), false)
	l.position = Vector2(0, y)
	l.custom_minimum_size = Vector2(CONTENT_W, 0)
	_content.add_child(l)


## 顶部徽记：有素材用图，缺素材回退一枚字符花饰
func _emblem(res: String, px: float) -> Control:
	var tex: Texture2D = G.res_tex(res)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.custom_minimum_size = Vector2(px, px)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return pic
	var l := G.serif_label("※", G.FS_LG, Color("b98c3a"))
	l.custom_minimum_size = Vector2(px, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ================= 存档导出 / 导入 =================

## 导出：读出存档文件全文（纯逻辑不碰剪贴板，方便自动化验证直调）
func do_export() -> String:
	var f := FileAccess.open(G.SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


## 导入：校验是 JSON 字典后整份写入存档路径（不碰剪贴板/不切场景，方便自动化验证直调）
func do_import(code: String) -> bool:
	var body := code.strip_edges()
	var parsed: Variant = JSON.parse_string(body)
	if not (parsed is Dictionary):
		return false
	var f := FileAccess.open(G.SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("存档写入失败：" + G.SAVE_PATH)
		return false
	f.store_string(body)
	f.close()
	return true


func _on_export() -> void:
	_disarm_reset()
	var code := do_export()
	if code.is_empty():
		_note1.text = "没有找到可导出的存档"
		_note1.add_theme_color_override("font_color", Color("a04a3a"))
		return
	# headless 没有剪贴板服务（DisplayServer 为 headless），跳过即可，验证走 do_export 直取文本
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(code)
	_note1.text = "存档码已复制"
	_note1.add_theme_color_override("font_color", Color("4a7a44"))


func _on_paste() -> void:
	_disarm_reset()
	var clip := ""
	if DisplayServer.get_name() != "headless":
		clip = String(DisplayServer.clipboard_get())
	if clip.strip_edges().is_empty():
		_hint2.text = "剪贴板里没有存档码"
		_hint2.add_theme_color_override("font_color", Color("a04a3a"))
		return
	_code.text = clip
	_hint2.text = "已读入 · 点「导 入」校验写入"
	_hint2.add_theme_color_override("font_color", Color("8a6a34"))


func _on_import() -> void:
	_disarm_reset()
	var code := _code.text
	if code.strip_edges().is_empty():
		_hint2.text = "请先粘贴或输入存档码"
		_hint2.add_theme_color_override("font_color", Color("a04a3a"))
		return
	if not do_import(code):
		_hint2.text = "存档码无效"
		_hint2.add_theme_color_override("font_color", Color("a04a3a"))
		return
	# 先提示成功，停一拍再回标题重读档，玩家能看到反馈
	_hint2.text = "导入成功 · 即将回到标题"
	_hint2.add_theme_color_override("font_color", Color("4a7a44"))
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func(): get_tree().reload_current_scene())


# ================= 重置存档（二次确认） =================

## 执行重置：删档（并确认删干净）→ G 内状态复位落盘；回标题由按钮回调负责，
## 拆开是为了自动化验证能单测删档逻辑而不被切场景打断
func execute_reset() -> void:
	if FileAccess.file_exists(G.SAVE_PATH):
		var dir := DirAccess.open(G.SAVE_PATH.get_base_dir())
		if dir != null:
			dir.remove(G.SAVE_PATH.get_file())
	if FileAccess.file_exists(G.SAVE_PATH):
		push_error("存档删除失败：" + G.SAVE_PATH)
	G.gm_reset_save()


## 第一次点：亮「确认重置？」；再点：执行并回标题。点其他任意操作则解除
func _on_reset_click() -> void:
	if not _reset_armed:
		_reset_armed = true
		_set_reset_btn("确认重置？", Color("a04a3a"))
		_reset_hint.visible = true
		return
	execute_reset()
	get_tree().change_scene_to_file(TITLE_PATH)


func _disarm_reset() -> void:
	if not _reset_armed:
		return
	_reset_armed = false
	_set_reset_btn("重置存档", G.TEXT_DARK)
	_reset_hint.visible = false


func _set_reset_btn(text: String, color: Color) -> void:
	if _reset_btn == null:
		return
	var l := _reset_btn.get_child(0) as Label
	if l != null:
		l.text = text
		l.add_theme_color_override("font_color", color)


func _on_title() -> void:
	get_tree().change_scene_to_file(TITLE_PATH)


func _on_back() -> void:
	closed.emit()
