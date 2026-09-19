# TitlePanel.gd —— 称号成就（条件达成免费领 / 荣誉购买；佩戴给小幅加成，程序文字渲染）
# 分组分页（皇室战争式）：成就达成 / 荣誉兑换 两组，用 PageDeck 一屏一组翻页，
# 不再把 12 条全平铺在一屏。组内仍按「已拥有 → 可领取 → 未达成」排序。
class_name TitlePanel
extends Control

signal closed

const CONTENT_W := 408.0
const DECK_H := 470.0
const PageDeckScript := preload("res://src/ui/PageDeck.gd")

var _deck: Control = null
var _active_l: Label = null
var _toast: Label = null
var _content: Control = null
# 三组：修行（等级/宠物/金币养成）/ 征服（通关秘境）/ 荣誉（荣誉兑换），一屏 ≤5 张大卡片
var _groups: Array = []
var _group_names := ["修行之路", "秘境征服", "荣誉兑换"]


func _ready() -> void:
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

	# 分组分页由 _refresh 统一建（首次 + 交互后重建共用一条路径）

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


func _refresh() -> void:
	var tid := G.title_active()
	_active_l.text = "佩戴：%s" % String(G.title_cfg(tid).get("name", "")) if not tid.is_empty() \
		else "尚未佩戴称号"
	# 重新分组 + 整块重建 PageDeck：领取/佩戴会改变状态色与归属，组少重建开销可忽略
	_split_groups()
	if _deck != null:
		_deck.queue_free()
	_deck = PageDeckScript.new(CONTENT_W, DECK_H, 30.0)
	_deck.position = Vector2(0, 30)
	_deck.key_mode = "both"
	_deck.set_factory(_groups.size(), func(gi: int) -> Control:
		return _group_page(gi), Vector2(CONTENT_W, DECK_H))
	_content.add_child(_deck)
	_deck.go(_default_group(), true)


## 一组一个分页：组名头 + 该组称号大卡片纵向排
func _group_page(gi: int) -> Control:
	var page := Control.new()
	page.custom_minimum_size = Vector2(CONTENT_W, DECK_H)
	page.size = Vector2(CONTENT_W, DECK_H)

	# 组名头：宋体深棕 + 底部一条金细分隔线（顶部留 8px 与「佩戴」行分开）
	var head := G.serif_label(_group_names[gi], G.FS_MD, Color("7a5a2e"))
	head.position = Vector2(4, 8)
	head.custom_minimum_size = Vector2(CONTENT_W - 8, 0)
	page.add_child(head)
	var rule := Panel.new()
	rule.position = Vector2(4, 36)
	rule.size = Vector2(CONTENT_W - 8, 2)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.4)
	rule.add_theme_stylebox_override("panel", rsb)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(rule)

	# 该组称号卡片：大卡片纵向排，行距 10
	var list := _sorted_group(gi)
	var y := 50.0
	for t in list:
		var card := _title_card(t as Dictionary)
		card.position = Vector2(0, y)
		page.add_child(card)
		y += 104.0
	return page


func _title_card(t: Dictionary) -> Control:
	var tid := String(t.get("id", ""))
	var owned := G.title_owned(tid)
	var is_active := G.title_active() == tid
	var met := G.title_cond_met(t)

	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CONTENT_W, 94)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f0e2bc") if owned else Color("e2d2a8")
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = G.GOLD_BRIGHT if is_active else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.45)
	G._apply_shadow(sb, 3.0, 2.0, 0.22)
	root.add_theme_stylebox_override("panel", sb)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)

	# 左缘色条：已拥有亮金 / 可领取橙 / 未达成灰，一眼区分状态
	var bar := ColorRect.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(5, 94)
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
		btn = G.gold_button("卸 下", G.BTN_S.x - 24, 34, G.FS_SM)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				G.title_set_active("")
				_refresh())
	elif owned:
		btn = G.gold_button("佩 戴", G.BTN_S.x - 24, 34, G.FS_SM)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				G.title_set_active(tid)
				_refresh())
	elif met:
		btn = G.gold_button("领 取", G.BTN_S.x - 24, 34, G.FS_SM)
		(btn.get_child(0) as Label).add_theme_color_override("font_color", Color("a03020"))
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_claim(tid))
	else:
		var cost: Dictionary = t.get("cost", {})
		if cost.is_empty():
			btn = G.gold_button("未达成", G.BTN_S.x - 24, 34, G.FS_SM)
			(btn.get_child(0) as Label).add_theme_color_override("font_color", Color("8a7a58"))
		else:
			btn = G.gold_button("%d 荣誉" % int(cost.get("honor", 0)), G.BTN_S.x - 24, 34, G.FS_SM)
			btn.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_on_claim(tid))
	btn.position = Vector2(CONTENT_W - G.BTN_S.x + 20, 30)
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
	_refresh()


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
