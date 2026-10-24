# ExchangePanel.gd —— 演武荣誉补给（仅兑换少量辅助材料，条目读 data/exchange.json）
# 结构与 CodexPanel 一致：遮罩 → 木匾 → 羊皮纸 → 内包 content 手动布局；父层负责 closed 后回收
class_name ExchangePanel
extends Control

signal closed

# 同 DeployPanel：440 羊皮纸 - 左右各 16 内边距 = 408，子控件按 408 排版才不右偏
const CONTENT_W := 408.0
const TABLE_PATH := "res://data/exchange.json"
# 行高与步距：6 条单列行，68 高 + 10 间隔，从余额区下方一路排到底部提示
const ROW_STEP := 78.0
# 图标缺素材时的回退色块（按 icon 名取色，拿不到就米灰一块，别让卡片开天窗）
const ICON_FALLBACK := {
	"cur_gold": Color("d8ab48"), "cur_soul": Color("a273c9"),
	"cur_expedition": Color("315d87"), "cur_honor": Color("e8b84a"),
	"itm_ticket_ten": Color("c9a44a"), "itm_ticket_sweep": Color("8d8474"),
}

var _entries: Array = []     # data/exchange.json 的 entries
var _btns := {}              # id -> 兑换按钮（刷新置灰态用）
var _cost_l := {}            # id -> 代价行 Label（买不起时转红）
var _times := {}             # id -> 本次会话已兑换次数（toast 的 ×N）
var _content: Control = null
var _honor_l: Label = null   # 顶部荣誉余额
var _hint: Label = null      # 底部提示（默认引导 / 荣誉不足红字）
var _toast_l: Label = null   # 淡出提示（成功兑换）
var _toast_tw: Tween = null
var _panel: PanelContainer
var _scroll: ScrollContainer
var _back: Button
var _banner: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_entries = _load_entries()
	_build()
	preload("res://src/ui/UiSafeArea.gd").watch(self,_layout_page)
	get_viewport().size_changed.connect(_layout_page)
	_layout_page.call_deferred()

func _layout_page() -> void:
	if _panel == null: return
	var safe := G.ui_safe_rect(self)
	_banner.position=Vector2(safe.get_center().x-150,safe.position.y+12)
	_panel.position=Vector2(safe.get_center().x-220,safe.position.y+80)
	_panel.custom_minimum_size=Vector2(440,0)
	_panel.size=Vector2(440,maxf(400,safe.size.y-92))
	var inner_h := _panel.size.y-32
	_scroll.size=Vector2(CONTENT_W,maxf(120,inner_h-162))
	_hint.position.y=inner_h-94
	_back.position=Vector2((CONTENT_W-220)*.5,inner_h-64)
	_back.size=Vector2(220,60)
	if is_instance_valid(_toast_l): _toast_l.position.y=inner_h-124


func _load_entries() -> Array:
	var f := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if f == null:
		push_error("data/exchange.json 缺失")
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).get("entries", [])
	return []


## 兑换表原文（自动化验证 / 外部查询用）
func entries() -> Array:
	return _entries


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.72)

	var banner := G.banner_box("演 武 补 给", 300, 50)
	_banner=banner
	banner.position = Vector2(90, 36)
	add_child(banner)

	# 统一黑漆墨玉金边主面板 + 九宫格玄铁外框
	var panel := PanelContainer.new()
	_panel=panel
	var box := StyleBoxFlat.new()
	box.bg_color = Color("141118", 0.96)
	box.border_color = Color("b89658")
	box.set_border_width_all(2)
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6
	box.shadow_color = Color(0, 0, 0, 0.58)
	box.shadow_size = 10
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(440, 668)
	panel.position = Vector2(20, 108)
	add_child(panel)

	# PanelContainer 是容器，直接放子控件会被布局系统接管位置，包一层 Control 手动布局
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_content)

	# 顶部像素场景横幅衬底与玄铁边框装饰
	var header_art := TextureRect.new()
	header_art.texture = G.Visuals._kit_tex("exchange_header_banner.png")
	header_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	header_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header_art.position = Vector2(0, 0)
	header_art.size = Vector2(CONTENT_W, 54)
	header_art.modulate = Color(1, 1, 1, 0.72)
	header_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(header_art)

	var header_rim := Panel.new()
	header_rim.position = Vector2(0, 0)
	header_rim.size = Vector2(CONTENT_W, 54)
	header_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rim_sb := StyleBoxFlat.new()
	rim_sb.bg_color = Color(0.08, 0.06, 0.10, 0.35)
	rim_sb.border_color = Color("b89658", 0.65)
	rim_sb.set_border_width_all(1)
	header_rim.add_theme_stylebox_override("panel", rim_sb)
	_content.add_child(header_rim)

	# 顶部荣誉余额：金库图标 + 数字（HBox 居中排，免得手算文字宽度）
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	bar.position = Vector2(0, 4)
	bar.custom_minimum_size = Vector2(CONTENT_W, 0)
	var vault := _icon("cur_honor", 28)
	vault.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(vault)
	_honor_l = G.gold_label("荣誉 0", G.FS_MD, false, Color("ffd875"), false)
	_honor_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_honor_l)
	_content.add_child(bar)

	var tip := G.gold_label("演武场对战可获得荣誉", G.FS_XS, false, Color("e6d5b8"), false)
	tip.position = Vector2(0, 32)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	_content.add_child(tip)

	# 14 条兑换项放不进一屏：装进滚动容器，返回/提示行固定在底部不再被行压住
	var scroll := ScrollContainer.new()
	_scroll=scroll
	scroll.position = Vector2(0, 58)
	scroll.size = Vector2(CONTENT_W, 458)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_child(scroll)
	var rows := Control.new()
	rows.custom_minimum_size = Vector2(CONTENT_W - 10.0, 58.0 + _entries.size() * ROW_STEP)
	rows.size = rows.custom_minimum_size
	scroll.add_child(rows)

	for i in _entries.size():
		var row := _entry_row(_entries[i] as Dictionary)
		row.position = Vector2(0, i * ROW_STEP)
		rows.add_child(row)

	_hint = G.gold_label("点「兑 换」消耗荣誉换取资源", G.FS_XS, false, Color("b5a796"), false)
	_hint.position = Vector2(0, 528)
	_hint.custom_minimum_size = Vector2(CONTENT_W, 0)
	_content.add_child(_hint)

	var back := preload("res://src/ui/ReadingSkin.gd").button("返回")
	_back=back
	back.pressed.connect(_on_back)
	_content.add_child(back)

	_refresh()


## 取图标：G.res_tex 有图用图，缺素材回退一块纯色方
func _icon(icon: String, px: float) -> Control:
	var tex: Texture2D = G.res_tex(icon)
	if tex == null:
		if icon == "cur_honor":
			tex = G.res_tex("honor")
		elif icon.begins_with("itm_"):
			tex = G.res_tex(icon.substr(4))
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.custom_minimum_size = Vector2(px, px)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return pic
	var block := ColorRect.new()
	block.color = ICON_FALLBACK.get(icon, Color("b0a68e"))
	block.custom_minimum_size = Vector2(px, px)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return block


## 单条兑换行：图标 + 名称/代价 + 兑换按钮（卡片底为黑金切角，高品质商业手游质感）
func _entry_row(e: Dictionary) -> Control:
	var eid := String(e.get("id", ""))
	var root := G.InsetPanel.new()
	root.custom_minimum_size = Vector2(CONTENT_W, 68)
	root.setup(Color("1b1622"), Color("6e5434"), 10.0, 10.0, 6.0, 6.0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 物品图标卡槽（带像素金边卡槽）
	var icon_slot := PanelContainer.new()
	var slot_tex := G.Visuals._kit_tex("slot_rare.png")
	if slot_tex != null:
		var sb_tex := StyleBoxTexture.new()
		sb_tex.texture = slot_tex
		sb_tex.texture_margin_left = 6.0
		sb_tex.texture_margin_right = 6.0
		sb_tex.texture_margin_top = 6.0
		sb_tex.texture_margin_bottom = 6.0
		sb_tex.content_margin_left = 4.0
		sb_tex.content_margin_right = 4.0
		sb_tex.content_margin_top = 4.0
		sb_tex.content_margin_bottom = 4.0
		icon_slot.add_theme_stylebox_override("panel", sb_tex)
	else:
		var slot_box := StyleBoxFlat.new()
		slot_box.bg_color = Color("100d14")
		slot_box.border_color = Color("6e5434")
		slot_box.set_border_width_all(1)
		slot_box.set_content_margin_all(2)
		icon_slot.add_theme_stylebox_override("panel", slot_box)
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pic := _icon(String(e.get("icon", "")), 44)
	icon_slot.add_child(pic)
	row.add_child(icon_slot)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := G.gold_label(String(e.get("name", eid)), G.FS_SM, false, Color("f3ece0"), false)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(name_l)
	var cost_l := G.gold_label("%d 荣誉" % int(e.get("cost", 0)), G.FS_XS, false, Color("dcb564"), false)
	cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(cost_l)
	row.add_child(col)

	var btn := G.gold_button("兑 换", 96, 38, G.FS_SM)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.gui_input.connect(func(e2: InputEvent):
		if e2 is InputEventMouseButton and e2.pressed and e2.button_index == MOUSE_BUTTON_LEFT:
			HapticFeedback.light()
			do_exchange(eid))
	row.add_child(btn)

	root.add_child(row)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btns[eid] = btn
	_cost_l[eid] = cost_l
	return root


# ================= 兑换逻辑 =================

func _find(entry_id: String) -> Dictionary:
	for e in _entries:
		if String((e as Dictionary).get("id", "")) == entry_id:
			return e as Dictionary
	return {}


## 兑换：扣荣誉 → 发奖（钱包四币直入 / item_ 前缀走道具库存）→ 落盘 → 刷新。
## 荣誉不足返回 false 并亮红字提示；自动化验证可直接调它绕开点击。
func do_exchange(entry_id: String) -> bool:
	var e := _find(entry_id)
	if e.is_empty():
		return false
	var give: Dictionary = e.get("give", {})
	if give.is_empty():
		return false
	for k in give:
		if not String(k).begins_with("item_") or int(give[k]) <= 0:
			push_error("演武荣誉兑换表只允许正数道具：%s" % entry_id)
			return false
	var cost := int(e.get("cost", 0))
	var honor := int(G.wallet.get("honor", 0))
	if honor < cost:
		Audio.sfx("ui_locked")
		_warn("荣誉不足，还差 %d 点" % (cost - honor))
		return false
	G.wallet["honor"] = honor - cost
	for k in give.keys():
		var key := String(k)
		var n := int(give[k])
		G.grant_item(key.substr(5), n, false)
	_times[entry_id] = int(_times.get(entry_id, 0)) + 1
	G.save_game()
	_refresh()
	if _hint != null:
		_hint.text = "点「兑 换」消耗荣誉换取资源"
		_hint.add_theme_color_override("font_color", G.TEXT_MUTED)
	Audio.sfx("coin")
	_toast("已兑换「%s」×%d" % [String(e.get("name", entry_id)), int(_times[entry_id])])
	return true


## 刷新余额数字与各条按钮态：买不起的整颗钮压灰 + 文案直说「荣誉不足」+ 代价数字转红
## ——玩家不点也知道差多少，而不是要靠点一次弹红字才明白
func _refresh() -> void:
	var honor := int(G.wallet.get("honor", 0))
	if _honor_l != null:
		_honor_l.text = "荣誉 %d" % honor
	for id in _btns.keys():
		var btn: Control = _btns[id]
		if btn == null:
			continue
		var e := _find(String(id))
		var poor := honor < int(e.get("cost", 0))
		btn.modulate = Color(1, 1, 1, 0.5) if poor else Color.WHITE
		var bl := btn.get_child(0) as Label
		if bl != null:
			bl.text = "荣誉不足" if poor else "兑换"
		var cl: Label = _cost_l.get(String(id))
		if cl != null:
			cl.add_theme_color_override("font_color",
				G.C_COST if poor else Color("dcb564"))


func _warn(msg: String) -> void:
	if _hint == null:
		return
	_hint.text = msg
	_hint.add_theme_color_override("font_color", Color("a04a3a"))


## 淡出提示（成功兑换后；沿用 Login 的 toast 手法：停一拍 → 渐隐 → 回收）
func _toast(msg: String) -> void:
	if _toast_l != null:
		_toast_l.queue_free()
		_toast_l = null
	if _toast_tw != null:
		_toast_tw.kill()
		_toast_tw = null
	_toast_l = G.gold_label(msg, G.FS_SM, false, Color("4a7a44"), false)
	_toast_l.position = Vector2(0, _panel.size.y-156)
	_toast_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	if _content != null:
		_content.add_child(_toast_l)
	_toast_tw = create_tween()
	_toast_tw.tween_interval(1.2)
	_toast_tw.tween_property(_toast_l, "modulate:a", 0.0, 0.45)
	_toast_tw.tween_callback(func():
		if _toast_l != null:
			_toast_l.queue_free()
			_toast_l = null)


func _on_back() -> void:
	closed.emit()


## ESC / 返回手势关闭本浮层（轮次 14 统一口径）
func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
