# QuestPanel.gd —— 任务窗口：主线目标 + 今日委托
# 循环：在委托板接取 → 出征办事（击杀 / 讨伐首领 / 备齐道具）→ 回城交付领赏。
# 主线目标原来直接压在营帐首页的背景上，既难读也杂；收进这里统一看。
# 历练委托在 data/quests.json；世界事务另有公告栏，已接进度跨日保留。
extends Control

signal closed

const VIEW_W := 480.0
const VIEW_H := 800.0
const CONTENT_W := 408.0
# 行高 108：奖励从「状态行右半」挪到独立一行（原来伸到按钮底下被压住），多要 12px
const ROW_H := 108.0
const ROW_GAP := 8.0
# 主线卡：标题/状态一行 + 目标 + 前往 + 奖励，四行 92px；主线暂尽时收成一行
const STORY_H := 92.0
const STORY_DONE_H := 44.0
const SECTION_H := 20.0   # 分区标题行高（主线 / 今日委托）
# 卡片内排版（问题 #13）：row 的 content_margin 左右各 12 → 内宽 384。
# 任务名/委托人同占一行各限宽，目标与奖励各自限宽，右列留给操作按钮。
const CARD_PAD := 12.0
const INNER_W := CONTENT_W - CARD_PAD * 2.0
const BTN_W := 92.0
const NAME_W := 236.0
const GOAL_W := INNER_W - BTN_W - 28.0

var _panel: PanelContainer = null
var _content: Control = null
var _list: Control = null
var _toast: Label = null
var _rows := 0
var _story_h := STORY_H
var _world_board: Control = null


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.sfx("ui_open")
	_build()
	_refresh()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.74)

	# 浮层自己的 rect 要等一帧才结算，锚点会算到 0：坐标一律写死
	var banner := G.banner_box("任务", 264, 50)
	banner.position = Vector2(56, 40)
	add_child(banner)
	var board := G.gold_button("世界事务", 108, 42, G.FS_SM)
	board.position = Vector2(352, 44)
	board.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _world_board == null:
			_world_board = preload("res://src/ui/WorldCommissionPanel.gd").new()
			add_child(_world_board)
			_world_board.closed.connect(func():
				_world_board.queue_free()
				_world_board = null))
	add_child(board)

	# 委托条数决定面板高（2 条时 ≈ 470）
	_rows = maxi(1, G.quest_offer().size())
	var story := G.story_current()
	_story_h = STORY_H if not story.is_empty() else STORY_DONE_H
	var list_y := SECTION_H + _story_h + 10.0 + SECTION_H + 2.0
	var h := clampf(28.0 + list_y + float(_rows) * (ROW_H + ROW_GAP) + 66.0, 300.0, 640.0)
	_panel = G.parchment_box(440, h, 16.0)
	_panel.position = Vector2((VIEW_W - 440.0) * 0.5, (VIEW_H - h) * 0.5 + 14.0)
	add_child(_panel)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_content)

	# —— 分区一：主线 ——
	var sl := G.serif_label("主线", G.FS_SM, G.BANNER)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sl.position = Vector2(0, 0)
	sl.custom_minimum_size = Vector2(CONTENT_W, 0)
	_content.add_child(sl)
	_story_card(SECTION_H, story)

	# —— 分区二：今日委托 ——
	var dl_y := SECTION_H + _story_h + 10.0
	var dl := G.serif_label("今日委托", G.FS_SM, G.BANNER)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dl.position = Vector2(0, dl_y)
	dl.custom_minimum_size = Vector2(120, 0)
	_content.add_child(dl)
	var tip := G.gold_label("已接委托跨日保留", G.FS_XS, false, G.TEXT_MUTED, false)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip.position = Vector2(CONTENT_W - 200.0, dl_y + 3)
	tip.size = Vector2(200, 0)
	tip.tooltip_text = "每日更新未接候选；已接事务与进度保留，完成后回城交付"
	_content.add_child(tip)

	var scroll := ScrollContainer.new()
	var visible_h := h - 32.0 - list_y - 66.0
	scroll.position = Vector2(0, list_y)
	scroll.size = Vector2(CONTENT_W, visible_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.custom_minimum_size = Vector2(CONTENT_W, float(_rows) * (ROW_H + ROW_GAP))
	scroll.add_child(_list)

	var back := G.ghost_button("返回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, list_y + visible_h + 12.0)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Audio.sfx("ui_close")
			closed.emit())
	_content.add_child(back)


## 主线卡：标题/状态 + 目标 + 前往 + 奖励。主线暂尽时收成一行自由探索提示。
func _story_card(y: float, story: Dictionary) -> void:
	# 内凹贴片（写字区语义）：比外层纸深一档 + 顶暗底亮，替代纯色圆角卡
	var card := G.InsetPanel.new()
	card.position = Vector2(0, y)
	var h := _story_h
	card.custom_minimum_size = Vector2(CONTENT_W, h)
	card.setup(Color("e5dcc1"), Color("b39a67"))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(card)

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	if story.is_empty():
		var done := G.gold_label(G.story_goal_short(), G.FS_SM, false, Color("6a5330"), false)
		done.position = Vector2(0, (h - 24.0) * 0.5)
		done.custom_minimum_size = Vector2(INNER_W, 0)
		inner.add_child(done)
		return

	var title_l := G.serif_label("主线 · %s" % String(story.get("title", "")),
		G.FS_MD, Color("3a2a14"))
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_l.position = Vector2(0, 0)
	title_l.custom_minimum_size = Vector2(NAME_W, 0)
	title_l.clip_text = true
	inner.add_child(title_l)

	var st_l := G.gold_label("进行中", G.FS_XS, false, Color("a06020"), false)
	st_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st_l.position = Vector2(NAME_W, 3)
	st_l.custom_minimum_size = Vector2(INNER_W - NAME_W, 0)
	inner.add_child(st_l)

	var goal_l := G.gold_label("目标：%s" % String(story.get("goal", "")),
		G.FS_SM, false, Color("5a4020"), false)
	goal_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	goal_l.position = Vector2(0, 26)
	goal_l.custom_minimum_size = Vector2(INNER_W, 0)
	goal_l.clip_text = true
	inner.add_child(goal_l)

	var target_cfg := TableCache.main_world_map(String(story.get("map", "")))
	var to_l := G.gold_label("前往：%s" % String(target_cfg.get("name", "昭元边城")),
		G.FS_XS, false, G.TEXT_MUTED, false)
	to_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	to_l.position = Vector2(0, 50)
	to_l.custom_minimum_size = Vector2(INNER_W, 0)
	to_l.clip_text = true
	inner.add_child(to_l)

	# 奖励可能很长（主线保底会带四五条），窗口里只给一行概览
	var parts: Array = G.reward_lines(story.get("reward", {}))
	if parts.size() > 3:
		parts = parts.slice(0, 3)
		parts.append("…")
	var rw_l := G.gold_label(" · ".join(parts), G.FS_XS, false, Color("8a6a34", 0.9), false)
	rw_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rw_l.position = Vector2(0, 70)
	rw_l.custom_minimum_size = Vector2(INNER_W, 0)
	rw_l.clip_text = true
	inner.add_child(rw_l)


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
	var row := G.InsetPanel.new()
	row.position = Vector2(0, y)
	row.custom_minimum_size = Vector2(CONTENT_W, ROW_H)
	row.setup(Color("e6d8b4"), Color("b99a5e"))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(row)

	# 卡片内容容器（问题 #13）：文字原来直接挂在 _list 上、用绝对坐标摆（y+6 / y+34 …），
	# 于是完全绕过卡片的 content_margin，而且 250/168 两段宽度在 240 处重叠 10px，
	# 任务名一长就压到委托人身上。改成放进 row 的内容矩形里按内宽排版：
	# 内宽 = CONTENT_W - 左右各 12 的边距 = 384，每行文字各自限宽、超长裁切。
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inner)

	# 谁托的（NPC 名字 + 头衔，从 city.json 取，别在委托表里再抄一遍）
	var npc := G.city_npc(String(d.get("npc", "")))
	var who := String(npc.get("name", ""))
	var npc_title := String(npc.get("title", ""))
	if npc_title != "":
		who += " · " + npc_title

	var name_l := G.gold_label(String(d.get("title", qid)), G.FS_MD, false, Color("3a2a14"), false)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(0, 0)
	name_l.custom_minimum_size = Vector2(NAME_W, 0)
	name_l.clip_text = true
	inner.add_child(name_l)

	var who_l := G.gold_label(who, G.FS_XS, false, G.TEXT_MUTED, false)
	who_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	who_l.position = Vector2(NAME_W, 3)
	who_l.custom_minimum_size = Vector2(INNER_W - NAME_W, 0)
	who_l.clip_text = true
	inner.add_child(who_l)

	var goal_l := G.gold_label(String(d.get("goal", "")), G.FS_SM, false, Color("5a4020"), false)
	goal_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	goal_l.position = Vector2(0, 24)
	goal_l.custom_minimum_size = Vector2(GOAL_W, 0)
	goal_l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # 中文无空格，按字符断行
	inner.add_child(goal_l)

	var state := G.quest_state(qid)
	var state_col := G.TEXT_MUTED
	if state == "可交付":
		state_col = Color("3a7a3a")
	elif state == "今日已交付":
		state_col = Color("7a7263")
	elif state.begins_with("进行中"):
		state_col = Color("a06020")
	var st_l := G.gold_label(state, G.FS_XS, false, state_col, false)
	st_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	st_l.position = Vector2(0, 48)
	st_l.custom_minimum_size = Vector2(150, 0)
	st_l.clip_text = true
	inner.add_child(st_l)

	# 奖励独占一行：原来塞在状态行右半（x=154），文字一长就钻到右侧按钮底下被压住
	var reward: Dictionary = d.get("reward", {})
	var parts := PackedStringArray()
	for k in G.REWARD_KEYS:
		if int(reward.get(k, 0)) > 0:
			parts.append("%s+%d" % [String(G.REWARD_NAMES.get(k, k)), int(reward[k])])
	if parts.size() > 0:
		var rw_l := G.gold_label(" · ".join(parts), G.FS_XS, false, Color("8a6a34", 0.9), false)
		rw_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		rw_l.position = Vector2(0, 70)
		rw_l.custom_minimum_size = Vector2(INNER_W, 0)
		rw_l.clip_text = true
		inner.add_child(rw_l)

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
	var btn := G.gold_button(btn_text, BTN_W, 38, G.FS_SM)
	btn.position = Vector2(INNER_W - BTN_W, 24)
	if not enabled:
		btn.modulate = Color(0.72, 0.68, 0.6)
	else:
		btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_act(qid))
	inner.add_child(btn)


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
	if _world_board != null: return
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14：原来这里没有守卫，
		return         # 开着控制台按 ESC 会把背后的委托板一起关掉）
	if event.is_action_pressed("ui_cancel"):
		Audio.sfx("ui_close")
		closed.emit()
		get_viewport().set_input_as_handled()
