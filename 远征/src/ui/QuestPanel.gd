# QuestPanel.gd —— 主城委托板：今日委托的接取 / 交付
# 循环：在委托板接取 → 出征办事（击杀 / 讨伐首领 / 备齐道具）→ 回城交付领赏。
# 数据全在 data/quests.json；状态在 G.quest（跨日重刷，跨日未交付作废）。
extends Control

signal closed

const VIEW_W := 480.0
const VIEW_H := 800.0
const CONTENT_W := 408.0
const ROW_H := 96.0
const ROW_GAP := 8.0
const TOP := 46.0

var _panel: PanelContainer = null
var _content: Control = null
var _list: Control = null
var _toast: Label = null
var _rows := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.sfx("ui_open")
	_build()
	_refresh()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.74)

	# 浮层自己的 rect 要等一帧才结算，锚点会算到 0：坐标一律写死
	var banner := G.banner_box("委 托 板", 280, 50)
	banner.position = Vector2((VIEW_W - 280.0) * 0.5, 40)
	add_child(banner)

	# 委托条数决定面板高（2 条时 ≈ 420）
	_rows = maxi(1, G.quest_offer().size())
	var h := clampf(TOP + 26.0 + float(_rows) * (ROW_H + ROW_GAP) + 66.0, 260.0, 620.0)
	_panel = G.parchment_box(440, h, 16.0)
	_panel.position = Vector2((VIEW_W - 440.0) * 0.5, (VIEW_H - h) * 0.5 + 14.0)
	add_child(_panel)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_content)

	var tip := G.gold_label("今日的活计就这些。接下、办完、回来交付——跨日作废。",
		G.FS_XS, false, Color("7a5a2e"), false)
	tip.position = Vector2(0, 0)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	_content.add_child(tip)

	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.position = Vector2(0, 26.0)
	_content.add_child(_list)

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 26.0 + float(_rows) * (ROW_H + ROW_GAP) + 12.0)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_close")
			closed.emit())
	_content.add_child(back)


# ---------- 列表 ----------
func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var offer := G.quest_offer()
	if offer.is_empty():
		var none := G.gold_label("今日没有委托，明日再来。", G.FS_SM, false, Color("6a5330"), false)
		none.position = Vector2(0, 16)
		none.custom_minimum_size = Vector2(CONTENT_W, 0)
		_list.add_child(none)
		return
	for i in offer.size():
		var qid := String(offer[i])
		_row(qid, float(i) * (ROW_H + ROW_GAP))


func _row(qid: String, y: float) -> void:
	var d := G.quest_def(qid)
	if d.is_empty():
		return
	var row := PanelContainer.new()
	row.position = Vector2(0, y)
	row.custom_minimum_size = Vector2(CONTENT_W, ROW_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e6d8b4")
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(1)
	sb.border_color = Color("b99a5e")
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	row.add_theme_stylebox_override("panel", sb)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(row)

	# 谁托的（NPC 名字 + 头衔，从 city.json 取，别在委托表里再抄一遍）
	var npc := G.city_npc(String(d.get("npc", "")))
	var who := String(npc.get("name", ""))
	var title := String(npc.get("title", ""))
	if title != "":
		who += " · " + title

	var name_l := G.gold_label(String(d.get("title", qid)), G.FS_MD, false, Color("3a2a14"), false)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(0, y + 6)
	name_l.custom_minimum_size = Vector2(250, 0)
	_list.add_child(name_l)

	var who_l := G.gold_label(who, G.FS_XS, false, Color("8a6a34"), false)
	who_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	who_l.position = Vector2(240, y + 10)
	who_l.custom_minimum_size = Vector2(168, 0)
	_list.add_child(who_l)

	var goal_l := G.gold_label(String(d.get("goal", "")), G.FS_SM, false, Color("5a4020"), false)
	goal_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	goal_l.position = Vector2(0, y + 34)
	goal_l.custom_minimum_size = Vector2(250, 0)
	_list.add_child(goal_l)

	var state := G.quest_state(qid)
	var state_col := Color("8a6a34")
	if state == "可交付":
		state_col = Color("3a7a3a")
	elif state == "今日已交付":
		state_col = Color("7a7263")
	elif state.begins_with("进行中"):
		state_col = Color("a06020")
	var st_l := G.gold_label(state, G.FS_XS, false, state_col, false)
	st_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	st_l.position = Vector2(0, y + 58)
	st_l.custom_minimum_size = Vector2(250, 0)
	_list.add_child(st_l)

	# 奖励一行小字：让玩家知道值不值得做
	var reward: Dictionary = d.get("reward", {})
	var parts := PackedStringArray()
	for k in G.REWARD_KEYS:
		if int(reward.get(k, 0)) > 0:
			parts.append("%s+%d" % [String(G.REWARD_NAMES.get(k, k)), int(reward[k])])
	if parts.size() > 0:
		var rw_l := G.gold_label(" · ".join(parts), G.FS_XS, false, Color("8a6a34", 0.9), false)
		rw_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		rw_l.position = Vector2(0, y + 76)
		rw_l.custom_minimum_size = Vector2(260, 0)
		_list.add_child(rw_l)

	# 操作按钮：未接取→接取；可交付→交付；其余是灰字状态
	var btn_text := ""
	var enabled := true
	if G.quest_claimed(qid):
		btn_text = "已交付"
		enabled = false
	elif not G.quest_active(qid):
		btn_text = "接 取"
	elif G.quest_completed(qid):
		btn_text = "交 付"
	else:
		btn_text = "进行中"
		enabled = false
	var btn := G.gold_button(btn_text, 92, 38, G.FS_SM)
	btn.position = Vector2(276, y + 28)
	if not enabled:
		btn.modulate = Color(0.72, 0.68, 0.6)
	else:
		btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_act(qid))
	_list.add_child(btn)


func _act(qid: String) -> void:
	if G.quest_active(qid):
		var res := G.quest_claim(qid)
		if bool(res.get("ok", false)):
			Audio.sfx("reward")   # 领赏音：交付是"这一圈闭环"的高光，值得一个热闹点的音
			_show_toast("「%s」交付 · %s" % [String(res.get("title", "")),
				" · ".join(PackedStringArray(res.get("lines", [])))])
		else:
			Audio.sfx("ui_locked")
			_show_toast(String(res.get("err", "还不能交付")))
	else:
		if G.quest_accept(qid):
			Audio.sfx("ui_confirm")
			var d := G.quest_def(qid)
			_show_toast("接下委托：%s" % String(d.get("title", "")))
			# 发布人的原话，接了才知道这事的分量
			var desc := String(d.get("desc", ""))
			if desc != "":
				G.show_info_popup(self, String(d.get("title", "")), [desc, "", "目标：" + String(d.get("goal", ""))])
		else:
			Audio.sfx("ui_locked")
			_show_toast("这条接不了")
	_refresh()


func _show_toast(msg: String) -> void:
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_SM, false, Color("ffe9b0"))
	_toast.position = Vector2(0, 96)
	_toast.custom_minimum_size = Vector2(VIEW_W, 0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Audio.sfx("ui_close")
		closed.emit()
		get_viewport().set_input_as_handled()
