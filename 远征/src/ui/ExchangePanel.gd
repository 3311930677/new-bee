# ExchangePanel.gd —— 荣誉兑换浮层（荣誉换金币/魂晶/远征点/召唤券，条目读 data/exchange.json）
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
	"cur_expedition": Color("6f9fd0"), "cur_honor": Color("e8b84a"),
	"itm_ticket_ten": Color("c9a44a"), "itm_ticket_sweep": Color("8d8474"),
}

var _entries: Array = []     # data/exchange.json 的 entries
var _btns := {}              # id -> 兑换按钮（刷新置灰态用）
var _times := {}             # id -> 本次会话已兑换次数（toast 的 ×N）
var _content: Control = null
var _honor_l: Label = null   # 顶部荣誉余额
var _hint: Label = null      # 底部提示（默认引导 / 荣誉不足红字）
var _toast_l: Label = null   # 淡出提示（成功兑换）
var _toast_tw: Tween = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_entries = _load_entries()
	_build()


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
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var banner := G.banner_box("荣 誉 兑 换", 300, 50)
	banner.position = Vector2(90, 36)
	add_child(banner)

	var panel := G.parchment_box(440, 668, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)

	# PanelContainer 是容器，直接放子控件会被布局系统接管位置，包一层 Control 手动布局
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_content)

	# 顶部荣誉余额：金库图标 + 数字（HBox 居中排，免得手算文字宽度）
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	bar.position = Vector2(0, 0)
	bar.custom_minimum_size = Vector2(CONTENT_W, 0)
	var vault := _icon("icon_vault", 26)
	vault.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(vault)
	_honor_l = G.gold_label("荣誉 0", G.FS_MD, false, Color("8a6a34"), false)
	_honor_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_honor_l)
	_content.add_child(bar)

	var tip := G.gold_label("远征结算与讨伐首领可赚得荣誉", G.FS_XS, false, Color("7a5a2e"), false)
	tip.position = Vector2(0, 32)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	_content.add_child(tip)

	# 14 条兑换项放不进一屏：装进滚动容器，返回/提示行固定在底部不再被行压住
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 54)
	scroll.size = Vector2(CONTENT_W, 462)
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

	_hint = G.gold_label("点「兑 换」消耗荣誉换取资源", G.FS_XS, false, Color("8a6a34"), false)
	_hint.position = Vector2(0, 528)
	_hint.custom_minimum_size = Vector2(CONTENT_W, 0)
	_content.add_child(_hint)

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 600)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_back())
	_content.add_child(back)

	_refresh()


## 取图标：G.res_tex 有图用图，缺素材回退一块纯色方
func _icon(icon: String, px: float) -> Control:
	var tex: Texture2D = G.res_tex(icon)
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


## 单条兑换行：图标 + 名称/代价 + 兑换按钮（卡片底沿用 DeployPanel 的四角微差画法）
func _entry_row(e: Dictionary) -> Control:
	var eid := String(e.get("id", ""))
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CONTENT_W, 68)
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.BOX_BG
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 4
	sb.set_border_width_all(2)
	sb.border_color = G.BOX_EDGE
	G._apply_shadow(sb, 4.0, 2.0, 0.30)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	root.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pic := _icon(String(e.get("icon", "")), 44)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := G.gold_label(String(e.get("name", eid)), G.FS_SM, false, G.TEXT_DARK, false)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(name_l)
	var cost_l := G.gold_label("%d 荣誉" % int(e.get("cost", 0)), G.FS_XS, false, Color("8a6a34"), false)
	cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(cost_l)
	row.add_child(col)

	var btn := G.gold_button("兑 换", 84, 38, G.FS_SM)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.gui_input.connect(func(e2: InputEvent):
		if e2 is InputEventMouseButton and e2.pressed and e2.button_index == MOUSE_BUTTON_LEFT:
			do_exchange(eid))
	row.add_child(btn)

	root.add_child(row)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btns[eid] = btn
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
	var cost := int(e.get("cost", 0))
	var honor := int(G.wallet.get("honor", 0))
	if honor < cost:
		_warn("荣誉不足，还差 %d 点" % (cost - honor))
		return false
	G.wallet["honor"] = honor - cost
	var give: Dictionary = e.get("give", {})
	for k in give.keys():
		var key := String(k)
		var n := int(give[k])
		if key.begins_with("item_"):
			G.grant_item(key.substr(5), n)
		elif G.wallet.has(key):
			G.wallet[key] = int(G.wallet[key]) + n
	_times[entry_id] = int(_times.get(entry_id, 0)) + 1
	G.save_game()
	_refresh()
	if _hint != null:
		_hint.text = "点「兑 换」消耗荣誉换取资源"
		_hint.add_theme_color_override("font_color", Color("8a6a34"))
	_toast("已兑换「%s」×%d" % [String(e.get("name", entry_id)), int(_times[entry_id])])
	return true


## 刷新余额数字与各条按钮态（买不起的置灰 modulate 0.5，但仍可点击看红字提示）
func _refresh() -> void:
	var honor := int(G.wallet.get("honor", 0))
	if _honor_l != null:
		_honor_l.text = "荣誉 %d" % honor
	for id in _btns.keys():
		var btn: Control = _btns[id]
		if btn == null:
			continue
		var e := _find(String(id))
		btn.modulate = Color(1, 1, 1, 0.5) if honor < int(e.get("cost", 0)) else Color.WHITE


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
	_toast_l.position = Vector2(0, 556)
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
