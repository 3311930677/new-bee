# TitlePanel.gd —— 称号成就（条件达成免费领 / 荣誉购买；佩戴给小幅加成，程序文字渲染）
# 单一纵向滚动列表（原来 PageDeck 翻页 + 组内滚动 + 圆点三套导航并存，找称号像走迷宫）：
# 三组（修行/征服/荣誉）按组名头分段排进一个 ScrollContainer，上下滚到底；
# 组内按「已拥有 → 可领取 → 未达成」排序。滚动条隐藏，卡片吃满内宽。
class_name TitlePanel
extends Control

signal closed

const CONTENT_W := 408.0
const LIST_Y := 30.0
const LIST_H := 524.0       # 佩戴行之下、返回钮之上的整条滚动区
const CARD_W := CONTENT_W   # 滚动条隐藏后卡片吃满内宽
const CARD_H := 94.0
const HEAD_H := 40.0        # 组名头（标题 + 金细分隔线）
const GAP := 10.0           # 列表间距（VBox separation）

var _scroll: ScrollContainer = null
var _active_l: Label = null
var _toast: Label = null
var _content: Control = null
# 三组：修行（等级/宠物/金币养成）/ 征服（通关秘境）/ 荣誉（荣誉兑换）
var _groups: Array = []
var _group_names := ["修行之路", "秘境征服", "荣誉兑换"]


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.78)

	var banner := G.banner_box("称 号", 240, 50)
	banner.position = Vector2(120, 30)
	add_child(banner)

	var panel := G.parchment_box(440, 620, 16.0)
	panel.position = Vector2(20, 96)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_content = content

	_active_l = G.gold_label("", G.FS_SM, true, Color("a06020"), false)
	_active_l.position = Vector2(0, 0)
	_active_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_child(_active_l)

	# 滚动列表由 _refresh 统一建（首次 + 交互后重建共用一条路径）

	var close_btn := G.gold_button("返 回", G.BTN_S.x, G.BTN_S.y, G.FS_SM)
	close_btn.position = Vector2((CONTENT_W - G.BTN_S.x) * 0.5, 566)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(close_btn)

	_refresh()


## 按 cond 类型把称号拆成三组：修行(level/pets/gold) / 征服(clear_world) / 荣誉(有 cost)
func _split_groups() -> void:
	_groups = [[], [], []]
	for t in G.titles_cfg():
		var td := t as Dictionary
		var cost: Dictionary = td.get("cost", {})
		var cond: Dictionary = td.get("cond", {})
		if not cost.is_empty():
			_groups[2].append(t)
		elif String(cond.get("type", "")) == "clear_world":
			_groups[1].append(t)
		else:
			_groups[0].append(t)


## 打开时默认落在哪组：有未领取的组优先（修行 → 征服 → 荣誉）
func _default_group() -> int:
	for gi in _groups.size():
		for t in _groups[gi]:
			if not G.title_owned(String((t as Dictionary).get("id", ""))) \
					and G.title_cond_met(t as Dictionary):
				return gi
	return 0


## 组内排序：已拥有 → 可领取（条件达成）→ 未达成，同档按表序
func _sorted_group(gi: int) -> Array:
	var owned: Array = []
	var claimable: Array = []
	var locked: Array = []
	for t in _groups[gi]:
		var tid := String((t as Dictionary).get("id", ""))
		if G.title_owned(tid):
			owned.append(t)
		elif G.title_cond_met(t as Dictionary):
			claimable.append(t)
		else:
			locked.append(t)
	return owned + claimable + locked


## preserve=true 时留在当前滚动位置（佩戴/领取后不该被弹回顶部——问题 #10）；
## preserve=false（首次打开）滚到「有未领取的那组」的组名头。
func _refresh(preserve := false) -> void:
	var tid := G.title_active()
	_active_l.text = "佩戴：%s" % String(G.title_cfg(tid).get("name", "")) if not tid.is_empty() \
		else "尚未佩戴称号"
	_split_groups()
	var prev_scroll := int(_scroll.scroll_vertical) if (preserve and _scroll != null) else -1
	if _scroll != null:
		_scroll.queue_free()
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, LIST_Y)
	_scroll.size = Vector2(CONTENT_W, LIST_H)
	_scroll.custom_minimum_size = Vector2(CONTENT_W, LIST_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER   # 藏滚动条，卡片吃满 408
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.add_child(_scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(box)
	for gi in _groups.size():
		if _groups[gi].is_empty():
			continue
		box.add_child(_group_head(gi))
		for t in _sorted_group(gi):
			box.add_child(_title_card(t as Dictionary))

	var want_y := prev_scroll if prev_scroll >= 0 else _group_offset(_default_group())
	# 布局还没结算，直接设会被钳回 0；延迟一帧再设
	_scroll.set_deferred("scroll_vertical", want_y)


## 第 gi 组组名头在列表里的 y：组块 = 组名头(40) + 每张卡(10 间距 + 94)
func _group_offset(gi: int) -> int:
	var y := 0.0
	for j in mini(gi, _groups.size()):
		if _groups[j].is_empty():
			continue
		y += HEAD_H + float(_groups[j].size()) * (GAP + CARD_H) + GAP
	return int(y)


## 组名头：宋体深棕 + 底部一条金细分隔线
func _group_head(gi: int) -> Control:
	var head := Control.new()
	head.custom_minimum_size = Vector2(CARD_W, HEAD_H)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := G.serif_label(_group_names[gi], G.FS_MD, G.TEXT_MUTED)
	l.position = Vector2(4, 4)
	l.custom_minimum_size = Vector2(CARD_W - 8, 0)
	head.add_child(l)
	var rule := Panel.new()
	rule.position = Vector2(4, 32)
	rule.size = Vector2(CARD_W - 8, 2)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.4)
	rule.add_theme_stylebox_override("panel", rsb)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(rule)
	return head


## 状态按钮皮（B6）：与 gold_button 同尺寸档位，只换皮——「已佩戴」深绿底白字、
## 「未达成」灰描边棕字。这样"能点的"（金）和"状态"（绿/灰）在列表里一眼分得开。
func _state_button(text: String, active: bool) -> Control:
	var btn := G.gold_button(text, G.BTN_S.x - 24, 34, G.FS_SM)
	if active:
		(btn as G.PixelButton).set_surface(Color("1f5a2e"), Color("3e7a44"))
		(btn.get_child(0) as Label).add_theme_color_override("font_color", Color("eef6e8"))
	else:
		(btn as G.PixelButton).set_surface(Color("9a8a6a4d"), Color("8a7a5a"))
		(btn.get_child(0) as Label).add_theme_color_override("font_color", Color("8a7a5a"))
	return btn


func _title_card(t: Dictionary) -> Control:
	var tid := String(t.get("id", ""))
	var owned := G.title_owned(tid)
	var is_active := G.title_active() == tid
	var met := G.title_cond_met(t)

	# 内凹贴片语言（G.InsetPanel）：切角 + 顶暗底亮 + 1px 描边，替代圆角8+软影的"模板脸"
	var root := G.InsetPanel.new()
	# 坐标一律以 CARD_W 为右边界（滚动条隐藏后 CARD_W = CONTENT_W，卡片吃满内宽）
	root.custom_minimum_size = Vector2(CARD_W, CARD_H)
	root.setup(Color("f0e2bc") if owned else Color("e2d2a8"),
		G.GOLD_BRIGHT if is_active else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.45),
		0.0, 0.0, 0.0, 0.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)

	# 左缘色条：已拥有亮金 / 可领取橙 / 未达成灰，一眼区分状态
	# （从 (2,2) 起、避开切角，色块完整落在八边形内）
	var bar := ColorRect.new()
	bar.position = Vector2(2, 2)
	bar.size = Vector2(5, CARD_H - 4.0)
	if is_active:
		bar.color = G.GOLD_BRIGHT
	elif owned:
		bar.color = Color("c8a040")
	elif met:
		bar.color = Color("d08040")
	else:
		bar.color = Color("a89878")
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bar)

	# 称号名：宋体大字（佩戴中额外高亮）；名字宽度限制，避免顶到右侧按钮
	var name_col := Color("b8860b") if owned else Color("8a7a58")
	if is_active:
		name_col = Color("a06020")
	var name_l := G.serif_label(String(t.get("name", "")), G.FS_LG, name_col)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(16, 10)
	name_l.custom_minimum_size = Vector2(270, 0)
	name_l.clip_text = true
	inner.add_child(name_l)

	# 描述 + 加成：一行，FS_SM 深棕，不放两行
	var desc := G.text_label("%s%s" % [String(t.get("desc", "")), _bonus_text(t.get("bonus", {}))],
		G.FS_XS, Color("5a3a1e"))
	desc.position = Vector2(16, 46)
	desc.custom_minimum_size = Vector2(264, 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc)

	# 右侧操作按钮：垂直居中
	var btn: Control
	if is_active:
		# 已佩戴：深绿底白字——与"可操作的金钮"拉开反差，一眼看出当前生效的是哪个
		btn = _state_button("卸 下", true)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				G.title_set_active("")
				_refresh(true))
	elif owned:
		btn = G.gold_button("佩 戴", G.BTN_S.x - 24, 34, G.FS_SM)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				G.title_set_active(tid)
				_refresh(true))
	elif met:
		btn = G.gold_button("领 取", G.BTN_S.x - 24, 34, G.FS_SM)
		(btn.get_child(0) as Label).add_theme_color_override("font_color", Color("f1dab1"))
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_claim(tid))
	else:
		var cost: Dictionary = t.get("cost", {})
		if cost.is_empty():
			# 未达成：灰描边钮（不是"灰字金钮"）——状态钮不该长得像能点的金钮
			btn = _state_button("未达成", false)
		else:
			btn = G.gold_button("%d 荣誉" % int(cost.get("honor", 0)), G.BTN_S.x - 24, 34, G.FS_SM)
			btn.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_on_claim(tid))
	var btn_w := G.BTN_S.x - 24.0
	btn.position = Vector2(CARD_W - btn_w - 10.0, 30)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	inner.add_child(btn)
	return root


func _bonus_text(bonus: Dictionary) -> String:
	if bonus.is_empty():
		return ""
	var names := {"atk_pct": "攻", "def_pct": "防", "maxhp_pct": "血", "spd_pct": "速",
		"crit_add": "暴", "atk_add": "攻", "def_add": "防", "hp_add": "血"}
	var parts := PackedStringArray()
	for k in bonus.keys():
		var v := float(bonus[k])
		if String(k).ends_with("_pct") or String(k) == "crit_add":
			parts.append("%s+%d%%" % [String(names.get(String(k), String(k))), roundi(v * 100.0)])
		else:
			parts.append("%s+%d" % [String(names.get(String(k), String(k))), int(v)])
	return "（%s）" % " ".join(parts)


func _on_claim(tid: String) -> void:
	var r := G.title_claim(tid)
	_toast_msg("称号「%s」入手！" % String(G.title_cfg(tid).get("name", "")) if bool(r.get("ok", false))
		else String(r.get("err", "")))
	_refresh(true)   # 领取后留在同一组（问题 #10）


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_SM, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 726)
	_toast.custom_minimum_size = Vector2(480, 0)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
	elif _scroll != null and event.is_action_pressed("ui_down"):
		_scroll.scroll_vertical += int(CARD_H + GAP)
		get_viewport().set_input_as_handled()
	elif _scroll != null and event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical -= int(CARD_H + GAP)
		get_viewport().set_input_as_handled()
