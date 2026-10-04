# SettingsPanel.gd —— 常规 / 旅人 / 存档，三页各处理一类事情。
# 版式沿用全项目口径：440 羊皮纸 - 左右各 16 内边距 = 408，子控件按 408 排。
class_name SettingsPanel
extends Control

signal closed
signal avatar_requested   # 请求父层叠出头像浮层（设置页里放不下头像卡片）

const PageDeckScript := preload("res://src/ui/PageDeck.gd")
const Journal := preload("res://src/ui/JournalUI.gd")

# 同 DeployPanel：440 羊皮纸 - 左右各 16 内边距 = 408，子控件按 408 排版才不右偏
const CONTENT_W := 408.0
const TITLE_PATH := "res://src/ui/Title.tscn"
const PANEL_H := 588.0
const PAGE_H := 384.0
const DECK_Y := 84.0
const BACK_Y := 496.0   # 底部返回（固定，不随页翻走）

var _content: Control = null
var _code: LineEdit = null   # 存档码输入框
var _note1: Label = null     # 导出行右侧说明 / 复制结果反馈
var _hint2: Label = null     # 导入反馈（默认引导 / 红字报错 / 绿字成功）
var _reset_btn: Control = null
var _reset_hint: Label = null
var _reset_armed := false    # 重置二次确认：第一次点只亮「确认重置？」，再点才执行
var _mute_btn: Control = null   # 静音开关（文案随状态切）
var _shake_btn: Control = null  # 震屏开关
var _story_btn: Control = null  # 剧情演出开关
var _speed_btn: Control = null  # 战斗默认倍速
var _name_edit: LineEdit = null # 昵称
var _name_hint: Label = null
var _deck: Control = null
var _vol_rows: Array[Control] = []  # 音量行容器：静音时整行压暗（数值仍保留）
var _mute_hint: Label = null    # 静音键右侧的情境提示（随静音 / 素材状态换话）
var _play_hint: Label = null    # 战斗与演出三项的情境提示（随三个开关状态换话）
## 从标题页直接打开时为 true：隐藏「回标题」（已经在标题），关闭时自行销毁
var standalone := false


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰。
	# 设置页压得更暗（0.88）：它常从标题页打开，0.72 会把背后的标题 logo 透出来，
	# 跟「设置」木牌叠成一团花
	G.veil(self, 0.88)

	var banner := G.banner_box("设 置", 300, 50)
	banner.position = Vector2(90, 26)
	add_child(banner)

	var panel := G.parchment_box(440, PANEL_H, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)

	# PanelContainer 是容器，直接放子控件会被布局系统接管位置，包一层 Control 手动布局
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_content)

	# 右上角关闭钮（手游惯例：显眼、一定能找到出口）；「?」键位说明往左让位
	var close := _close_button()
	close.position = Vector2(CONTENT_W - 34.0, -4.0)
	_content.add_child(close)

	# 键位说明收进「?」：三行常驻太占版面
	var help := G.info_button("键位与说明", [
		"WASD / 方向键 —— 人物移动",
		"A/D 或 ← → —— 切换卡片；W/S 或 ↑ ↓ —— 切换页签",
		"Esc —— 主界面打开设置；浮层内关闭当前浮层",
		"设置分三页：点上方页签或左右滑动切换",
		"设置里的「重新选择角色」不会删除其他存档数据",
		"F10 / ` —— 开发者控制台",
	])
	help.position = Vector2(CONTENT_W - 58.0, -2)
	_content.add_child(help)

	_deck = PageDeckScript.new(CONTENT_W, PAGE_H, 12.0)
	_deck.position = Vector2(0, DECK_Y)
	_deck.key_mode = "lr"   # 上下键不抢（设置页里没有纵向导航）
	_deck.page_gap = 14.0   # 相邻页按钮的阴影不再越过裁切边渗进来
	_deck.arrow_outset = 24.0   # 翻页箭头骑到羊皮纸两缘：原来压在第 2 页「剧情与角色」标题上
	_deck.add_page(_page_common())
	_deck.add_page(_page_profile())
	_deck.add_page(_page_save())
	_content.add_child(_deck)
	var tabs := G.page_tabs(_deck, ["常规", "旅人", "存档"], ["settings", "person", "save"], CONTENT_W)
	tabs.position = Vector2(0, 28)
	_content.add_child(tabs)
	G.reveal_control(panel)

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, BACK_Y)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_back())
	_content.add_child(back)


# ================= 常规 / 旅人 / 存档 =================
func _action(page: Control, words: String, at: Vector2, width: float,
        callback: Callable, icon := "") -> Control:
	var button := G.ghost_button(words, width, 42, G.FS_SM)
	button.position = at
	if not icon.is_empty(): G.button_icon(button, icon)
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			callback.call())
	page.add_child(button)
	return button

func _page_common() -> Control:
	var page := _page_root()
	_section(page, "声音", 0)
	_vol_row(page, "音乐", 36, Audio.bgm_vol(), func(v: float): Audio.set_bgm_vol(v))
	_vol_row(page, "音效", 76, Audio.sfx_vol(), func(v: float): Audio.set_sfx_vol(v))
	_mute_btn = _action(page, "静音：关", Vector2(0, 118), 148, func():
		Audio.set_mute(not Audio.muted())
		_sync_mute(), "sound")
	_mute_hint = G.text_label("", G.FS_XS, G.TEXT_MUTED)
	_mute_hint.position = Vector2(164, 130)
	_mute_hint.size = Vector2(244, 44)
	_mute_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_mute_hint)
	_sync_mute()
	_section(page, "战斗与演出", 198)
	_shake_btn = _action(page, "震屏：开", Vector2(0, 234), 194, func():
		G.setting_set("shake", not bool(G.setting_get("shake", true)))
		_sync_toggles())
	_shake_btn.tooltip_text = "受击时的镜头震动"
	_story_btn = _action(page, "剧情演出：播", Vector2(214, 234), 194, func():
		G.setting_set("skip_story", not bool(G.setting_get("skip_story", false)))
		_sync_toggles())
	_speed_btn = _action(page, "战斗倍速：×1", Vector2(0, 290), 194, func():
		var cur := float(G.setting_get("battle_speed", 1.0))
		G.setting_set("battle_speed", 2.0 if cur < 1.5 else 1.0)
		_sync_toggles())
	_play_hint = G.text_label("", G.FS_XS, G.TEXT_MUTED)
	_play_hint.position = Vector2(0, 348)
	_play_hint.size = Vector2(CONTENT_W, 30)
	page.add_child(_play_hint)
	_sync_toggles()
	return page

func _page_profile() -> Control:
	var page := _page_root()
	var frame := Journal.AvatarMedallion.new()
	frame.position = Vector2(0, 10)
	frame.size = Vector2(72, 72)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(frame)
	var avatar := TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.texture = G.avatar_texture()
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.position = Vector2(8, 8)
	avatar.size = Vector2(56, 56)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(avatar)
	var name_l := G.serif_label(G.display_name(), G.FS_LG, G.TEXT_DARK)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(92, 16)
	page.add_child(name_l)
	var role_l := G.text_label("%s · Lv.%d" % [String(G.get_role(G.selected_role).get("name", "旅人")), int(G.prog.get("level", 1))], G.FS_XS, G.TEXT_MUTED)
	role_l.position = Vector2(92, 52)
	page.add_child(role_l)
	_section(page, "昵称", 112)
	_name_edit = LineEdit.new()
	_name_edit.text = G.player_name if not G.player_name.is_empty() else "旅人"
	_name_edit.max_length = 8
	_name_edit.placeholder_text = "最多 8 个字"
	_name_edit.custom_minimum_size = Vector2(258, 42)
	_name_edit.position = Vector2(0, 146)
	G.style_line_edit(_name_edit, G.FS_SM)
	page.add_child(_name_edit)
	_action(page, "保存昵称", Vector2(274, 146), 134, _save_name, "save")
	_name_hint = G.text_label("", G.FS_XS, G.TEXT_MUTED)
	_name_hint.position = Vector2(0, 196)
	page.add_child(_name_hint)
	var avatar_button := _action(page, "更换头像", Vector2(0, 224), 148, _open_avatar, "person")
	avatar_button.tooltip_text = "选择趣味头像或本机图片"
	_section(page, "旅程", 292)
	_action(page, "重看序章", Vector2(0, 326), 128, func(): G.go("res://src/ui/Prologue.tscn"))
	_action(page, "重选角色", Vector2(140, 326), 128, func(): G.go("res://src/ui/CreateRole.tscn"))
	if not standalone:
		_action(page, "回标题", Vector2(280, 326), 128, _on_title, "back")
	return page

func _page_save() -> Control:
	var page := _page_root()
	_section(page, "备份", 0)
	_action(page, "复制存档码", Vector2(0, 34), 180, _on_export, "save")
	_note1 = G.text_label("复制后可备份保存", G.FS_XS, G.TEXT_MUTED)
	_note1.position = Vector2(196, 46)
	_note1.size = Vector2(212, 26)
	page.add_child(_note1)
	_section(page, "恢复存档", 110)
	_code = LineEdit.new()
	_code.placeholder_text = "粘贴备份存档码"
	_code.custom_minimum_size = Vector2(CONTENT_W, 42)
	_code.position = Vector2(0, 144)
	G.style_line_edit(_code, G.FS_SM)
	page.add_child(_code)
	_action(page, "粘贴码", Vector2(0, 198), 118, _on_paste)
	_action(page, "导入", Vector2(134, 198), 118, _on_import)
	_hint2 = G.text_label("导入成功后返回标题", G.FS_XS, G.TEXT_MUTED)
	_hint2.position = Vector2(0, 250)
	_hint2.size = Vector2(CONTENT_W, 26)
	page.add_child(_hint2)
	if _clip_code().begins_with("{"): _hint2.text = "已检测到存档码，点「粘贴码」读入"
	_reset_btn = _action(page, "重置存档", Vector2(0, 318), 128, _on_reset_click)
	(_reset_btn.get_child(0) as Label).add_theme_color_override("font_color", Color("984c3b"))
	_reset_btn.tooltip_text = "清除本机存档；需要再次确认"
	_reset_hint = G.text_label("再点一次执行重置", G.FS_XS, Color("a04a3a"))
	_reset_hint.position = Vector2(144, 330)
	_reset_hint.size = Vector2(264, 26)
	_reset_hint.visible = false
	page.add_child(_reset_hint)
	return page


## 页容器：PageDeck 的页面是手摆坐标，这里给一页定好尺寸与不拦鼠标的底
func _page_root() -> Control:
	var page := Control.new()
	page.custom_minimum_size = Vector2(CONTENT_W, PAGE_H)
	page.size = Vector2(CONTENT_W, PAGE_H)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return page


## 区块小标题：左侧金色竖条 + 左对齐粗体——原来居中的小字混在正文里看不出层级
func _section(page: Control, text: String, y: float) -> void:
	var bar := ColorRect.new()
	bar.color = Color("b98c3a")
	bar.position = Vector2(0, y + 3)
	bar.size = Vector2(4, 15)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(bar)
	var l := G.gold_label(text, G.FS_SM, true, G.TEXT_MUTED, false)
	l.position = Vector2(12, y)
	l.custom_minimum_size = Vector2(CONTENT_W - 12.0, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(l)


# ================= 开关文案同步 =================
## 静音按钮文案 + 音量行联动：静音时两条滑条整体压暗（数值仍保留），
## 旁边一行说明「为什么不响」——不然玩家会以为滑条坏了
func _sync_mute() -> void:
	if _mute_btn == null:
		return
	var on := Audio.muted()
	_set_btn_text(_mute_btn, "静音：开" if on else "静音：关")
	for row in _vol_rows:
		if is_instance_valid(row):
			row.modulate = Color(1, 1, 1, 0.4) if on else Color(1, 1, 1, 1.0)
	if _mute_hint == null:
		return
	# 两行硬换行：这一块宽 248，一句话顶满会从词中间断成"…仍保 / 留"，很难看
	var lines := ["音乐与音效正常播放"]
	if on:
		lines = ["已静音，音量设置已保留"]
	if Audio.has_no_stream():
		lines = ["当前没有可播放的音频"]
	_mute_hint.text = "\n".join(lines)


## 震屏 / 剧情演出 / 倍速 三个开关的文案跟随存档
func _sync_toggles() -> void:
	_set_btn_text(_shake_btn, "震屏：%s" % ("开" if bool(G.setting_get("shake", true)) else "关"))
	_set_btn_text(_story_btn,
		"剧情演出：%s" % ("省略" if bool(G.setting_get("skip_story", false)) else "播"))
	var sp := float(G.setting_get("battle_speed", 1.0))
	_set_btn_text(_speed_btn, "战斗倍速：×%d" % int(round(sp)))
	_refresh_play_hint()


## 战斗与演出三项的情境提示：每行只描述「当前这一档」会发生什么
func _refresh_play_hint() -> void:
	if _play_hint == null: return
	_play_hint.text = "战斗中也可随时切换倍速"


func _set_btn_text(btn: Control, text: String) -> void:
	if btn == null:
		return
	var l := btn.get_child(0) as Label
	if l != null:
		l.text = text


## 昵称保存：只写 player_name（跨存档的显示名），不碰角色数据
func _save_name() -> void:
	var nm := _name_edit.text.strip_edges()
	if nm.is_empty():
		_name_hint.text = "昵称不能为空"
		_name_hint.add_theme_color_override("font_color", Color("a04a3a"))
		Audio.sfx("ui_locked")
		return
	G.player_name = nm
	G.save_game()
	Audio.sfx("ui_confirm")
	_name_hint.text = "已保存：%s" % nm
	_name_hint.add_theme_color_override("font_color", Color("4a7a44"))


func _open_avatar() -> void:
	# 设置面板本身不持有头像浮层（父层负责叠层），这里发信号让父层打开
	avatar_requested.emit()


## 音量行：名称 + 滑条 + 百分比。整行包一个容器返回，静音时好整行压暗
func _vol_row(page: Control, text: String, y: float, value: float, cb: Callable) -> Control:
	var row := Control.new()   # 容器不拦鼠标，滑条才收得到拖拽
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = Vector2(0, y)
	row.custom_minimum_size = Vector2(CONTENT_W, 26)
	row.size = Vector2(CONTENT_W, 26)
	page.add_child(row)

	var l := G.text_label(text, G.FS_SM, Color("6a5a3a"))
	l.position = Vector2(0, 3)
	l.custom_minimum_size = Vector2(60, 0)
	row.add_child(l)

	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = value
	sl.position = Vector2(62, 0)
	sl.custom_minimum_size = Vector2(234, 26)
	sl.size = Vector2(234, 26)
	_style_slider(sl)
	row.add_child(sl)

	var pct := G.gold_label("%d%%" % roundi(value * 100.0), G.FS_XS, false, G.TEXT_MUTED, false)
	pct.position = Vector2(304, 3)
	pct.custom_minimum_size = Vector2(72, 0)
	row.add_child(pct)
	sl.value_changed.connect(func(v: float):
		pct.text = "%d%%" % roundi(v * 100.0)
		cb.call(v))
	_vol_rows.append(row)
	return row


## 滑条皮肤：做旧槽 + 像素方钮（默认皮肤在羊皮纸上太灰，圆钮渐变也偏"现代"）
func _style_slider(sl: HSlider) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("d7c7a1")
	bg.set_corner_radius_all(3)
	bg.content_margin_top = 3.0
	bg.content_margin_bottom = 3.0
	var fill := bg.duplicate() as StyleBoxFlat
	fill.bg_color = G.GOLD_BTN
	sl.add_theme_stylebox_override("slider", bg)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	sl.add_theme_icon_override("grabber", _pixel_grabber(18, G.GOLD_BRIGHT))
	sl.add_theme_icon_override("grabber_highlight", _pixel_grabber(20, Color("f1dab1")))


## 像素方钮贴图（滑条把手）：斜切角方块 + 顶高光/底压暗 + 暗边——
## 逐像素画，与 PixelButton 的按钮语言同族，替代原先的径向渐变圆钮。
func _pixel_grabber(px: int, fill: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cut := 3
	var m := px - 1
	for y in px:
		for x in px:
			var s := x + y
			var d := x - y
			# 八边形内部判定（切四角）
			if s < cut or s > 2 * m - cut or d > m - cut or -d > m - cut:
				continue
			var c := fill
			if s == cut or s == 2 * m - cut or d == m - cut or -d == m - cut \
					or x == 0 or x == m or y == 0 or y == m:
				c = fill.darkened(0.34)          # 外缘暗描边
			elif y <= cut:
				c = fill.lightened(0.22)         # 顶高光带
			elif y >= m - cut:
				c = fill.darkened(0.2)           # 底压暗带
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 右上角圆形关闭钮：旧金外环 + 木底圆牌「×」（与木匾同族），比底部「返回」更显眼
## （玩家反馈找不到出口）。非容器叠层，跟 info_button 的双线边同一做法。
func _close_button() -> Control:
	var btn := Panel.new()
	btn.custom_minimum_size = Vector2(30, 30)
	btn.size = Vector2(30, 30)
	# 外圈：旧金底圆（兼作 2px 环）
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("b39a68")
	sb.set_corner_radius_all(15)
	btn.add_theme_stylebox_override("panel", sb)
	# 内圈：木底圆
	var inner := Panel.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color("3a2c1c")
	isb.set_corner_radius_all(13)
	inner.add_theme_stylebox_override("panel", isb)
	inner.position = Vector2(2, 2)
	inner.size = Vector2(26, 26)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner)
	var l := G.gold_label("×", G.FS_MD, true, G.GOLD_BRIGHT, false)
	l.position = Vector2(0, 3)
	l.custom_minimum_size = Vector2(30, 0)
	btn.add_child(l)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_close")
			_on_back())
	return btn


# ================= 存档导出 / 导入 =================

## 导出：读出存档文件全文（纯逻辑不碰剪贴板，方便自动化验证直调）
func do_export() -> String:
	var f := FileAccess.open(G.SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


## 导入（带原因版）：版本闸门 → 逐版迁移 → 语义校验 → 备份原档 → 原子替换。
## 任一步不过就整份拒绝，原档一字不动（问题 #39/#24）。
## 返回 { ok, err }；err 是给玩家看的中文原因，直接可以贴进提示行。
func do_import_ex(code: String) -> Dictionary:
	# 走静默解析：乱码存档码是玩家会真实输入的东西，不该往控制台刷引擎错误
	var res := SaveData.import_payload(code.strip_edges(), int(Time.get_unix_time_from_system()))
	if not bool(res.get("ok", false)):
		return {"ok": false, "err": String(res.get("err", "存档码无效"))}
	# 先备份现有档，再原子替换；写失败时原档仍在（备份里也还有一份）
	SaveData.backup_file(G.SAVE_PATH, int(Time.get_unix_time_from_system()))
	var w := SaveData.write_text_atomic(G.SAVE_PATH, String(res.get("text", "")))
	if not bool(w.get("ok", false)):
		return {"ok": false, "err": String(w.get("err", "存档写入失败"))}
	return {"ok": true, "err": ""}


## 导入（旧签名，保留给既有调用方与回归用例）：成功为 true
func do_import(code: String) -> bool:
	return bool(do_import_ex(code).get("ok", false))


## 剪贴板文本（已去首尾空白）；headless 没有剪贴板服务，返回空串走"没读到"分支
func _clip_code() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	return String(DisplayServer.clipboard_get()).strip_edges()


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
	var clip := _clip_code()
	if clip.is_empty():
		_hint2.text = "剪贴板里没有存档码"
		_hint2.add_theme_color_override("font_color", Color("a04a3a"))
		return
	_code.text = clip
	_hint2.text = "已读入 · 点「导 入」校验写入"
	_hint2.add_theme_color_override("font_color", G.TEXT_MUTED)


func _on_import() -> void:
	_disarm_reset()
	var code := _code.text
	if code.strip_edges().is_empty():
		_hint2.text = "请先粘贴或输入存档码"
		_hint2.add_theme_color_override("font_color", Color("a04a3a"))
		return
	var imp := do_import_ex(code)
	if not bool(imp.get("ok", false)):
		# 把具体原因贴出来（版本过高 / 时间水位异常 / 字段非法），别只给一句"无效"
		_hint2.text = String(imp.get("err", "存档码无效"))
		_hint2.add_theme_color_override("font_color", Color("a04a3a"))
		return
	# 先提示成功，停一拍回标题——回标题前必须 G.reload_save() 重读内存态，
	# 只 reload 场景不会重读存档，旧内存会在下一次保存时覆盖导入档（P0-3）
	_hint2.text = "导入成功 · 即将回到标题"
	_hint2.add_theme_color_override("font_color", Color("4a7a44"))
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func():
		G.reload_save()
		G.go(TITLE_PATH))


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
	G.go(TITLE_PATH)


func _disarm_reset() -> void:
	if not _reset_armed:
		return
	_reset_armed = false
	_set_reset_btn("重置存档", G.TEXT_DARK)
	_reset_hint.visible = false


func _set_reset_btn(text: String, color: Color) -> void:
	_set_btn_text(_reset_btn, text)
	if _reset_btn == null:
		return
	var l := _reset_btn.get_child(0) as Label
	if l != null:
		l.add_theme_color_override("font_color", color)


func _on_title() -> void:
	G.go(TITLE_PATH)


func _on_back() -> void:
	closed.emit()


## ESC / 返回手势关闭本浮层（轮次 14 统一口径：主界面按 ESC 打开设置，设置里再按 ESC 关掉它，
## 不再依赖父层 GameHome 代为关闭——父层只做兜底）
func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
