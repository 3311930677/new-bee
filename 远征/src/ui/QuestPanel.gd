# QuestPanel.gd —— 任务窗口：主线目标 + 今日委托
# 商业级手游排版：官驿委任板质感 + 漆器木框 + 明晰印戳状态 + 精致奖励标示
class_name QuestPanel
extends Control

signal closed

const UI := preload("res://src/ui/TravelChestUI.gd")
const VIEW_W := 480.0
const VIEW_H := 800.0
const PANEL_W := 440.0
const CONTENT_W := 408.0

const ROW_H := 104.0
const ROW_GAP := 8.0
const STORY_H := 108.0
const STORY_DONE_H := 44.0
const SECTION_H := 26.0

const CARD_PAD := 12.0
const INNER_W := CONTENT_W - CARD_PAD * 2.0
const BTN_W := 84.0
const NAME_W := 236.0
const GOAL_W := INNER_W - BTN_W - 24.0

var _panel: Panel = null
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
	G.veil(self, 0.76)

	_rows = maxi(1, G.quest_offer().size())
	var story := G.story_current()
	_story_h = STORY_H if not story.is_empty() else STORY_DONE_H
	var rel_list_y := SECTION_H + _story_h + 10.0 + SECTION_H + 4.0
	var list_content_h := float(_rows) * (ROW_H + ROW_GAP)
	var h := clampf(60.0 + rel_list_y + list_content_h + 58.0, 380.0, 720.0)

	_panel = Panel.new()
	_panel.name = "QuestBoard"
	_panel.size = Vector2(PANEL_W, h)
	_panel.position = Vector2((VIEW_W - PANEL_W) * 0.5, (VIEW_H - h) * 0.5)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17141b", 0.96)
	style.border_color = Color("8c6f47", 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# 顶部标题栏
	var header := Panel.new()
	header.size = Vector2(PANEL_W, 52)
	header.position = Vector2(0, 0)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color("231c26", 0.95)
	h_style.border_color = Color("6a5338", 0.6)
	h_style.border_width_bottom = 1
	h_style.corner_radius_top_left = 4
	h_style.corner_radius_top_right = 4
	header.add_theme_stylebox_override("panel", h_style)
	_panel.add_child(header)

	var title_l := UI.label("任 务 卷 宗", "title", UI.GOLD)
	title_l.position = Vector2(16, 12)
	title_l.size = Vector2(140, 28)
	header.add_child(title_l)

	var board_btn := Button.new()
	board_btn.text = "世界事务"
	board_btn.size = Vector2(96, 32)
	board_btn.position = Vector2(PANEL_W - 112, 10)
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color("1e1724", 0.9)
	b_style.border_color = Color("6e5434", 0.8)
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(2)
	board_btn.add_theme_stylebox_override("normal", b_style)
	board_btn.add_theme_stylebox_override("hover", b_style)
	board_btn.add_theme_stylebox_override("pressed", b_style)
	board_btn.add_theme_color_override("font_color", UI.PAPER)
	board_btn.add_theme_font_override("font", G.font_reg)
	board_btn.add_theme_font_size_override("font_size", 12)
	board_btn.pressed.connect(func():
		if _world_board == null:
			_world_board = preload("res://src/ui/WorldCommissionPanel.gd").new()
			add_child(_world_board)
			_world_board.closed.connect(func():
				_world_board.queue_free()
				_world_board = null))
	header.add_child(board_btn)

	_content = Control.new()
	_content.position = Vector2(16, 60)
	_content.size = Vector2(CONTENT_W, h - 70)
	_panel.add_child(_content)

	# —— 分区一：主线 ——
	var sl := UI.label("◆ 主线传书", "section", UI.GOLD)
	sl.position = Vector2(0, 0)
	sl.size = Vector2(CONTENT_W, 22)
	_content.add_child(sl)
	_story_card(SECTION_H, story)

	# —— 分区二：今日委托 ——
	var dl_y := SECTION_H + _story_h + 10.0
	var dl := UI.label("◆ 边城委托", "section", UI.COPPER)
	dl.position = Vector2(0, dl_y)
	dl.size = Vector2(140, 22)
	_content.add_child(dl)

	var tip := UI.label("已接委托跨日保留 · 完成后回城交付", "tag", UI.AGED)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip.position = Vector2(CONTENT_W - 240.0, dl_y + 2)
	tip.size = Vector2(240, 20)
	_content.add_child(tip)

	var scroll := ScrollContainer.new()
	var visible_h := minf(list_content_h, h - 60.0 - rel_list_y - 56.0)
	scroll.position = Vector2(0, rel_list_y)
	scroll.size = Vector2(CONTENT_W, visible_h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)

	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.custom_minimum_size = Vector2(CONTENT_W, list_content_h)
	scroll.add_child(_list)

	# 底部返回按钮
	var back := Button.new()
	back.text = "返 回"
	back.size = Vector2(140, 36)
	back.position = Vector2((CONTENT_W - 140.0) * 0.5, rel_list_y + visible_h + 10.0)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color("231d27", 0.9)
	back_style.border_color = Color("6e5434", 0.8)
	back_style.set_border_width_all(1)
	back_style.set_corner_radius_all(3)
	back.add_theme_stylebox_override("normal", back_style)
	back.add_theme_stylebox_override("hover", back_style)
	back.add_theme_stylebox_override("pressed", back_style)
	back.add_theme_color_override("font_color", UI.PAPER)
	back.add_theme_font_override("font", G.font_reg)
	back.add_theme_font_size_override("font_size", 14)
	back.pressed.connect(_close_self)
	_content.add_child(back)


func _close_self() -> void:
	Audio.sfx("ui_close")
	G.close_page(self, func(): closed.emit())


func _story_card(y: float, story: Dictionary) -> void:
	var card := Panel.new()
	card.position = Vector2(0, y)
	card.size = Vector2(CONTENT_W, _story_h)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("221a28", 0.92)
	card_style.border_color = Color("c29a5b", 0.75)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(3)
	card.add_theme_stylebox_override("panel", card_style)
	_content.add_child(card)

	var inner := Control.new()
	inner.position = Vector2(12, 10)
	inner.size = Vector2(INNER_W, _story_h - 20)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	if story.is_empty():
		var done := UI.label(G.story_goal_short(), "caption", UI.AGED)
		done.position = Vector2(0, 10)
		done.size = Vector2(INNER_W, 20)
		inner.add_child(done)
		return

	var title_l := UI.label("主线 · %s" % String(story.get("title", "")), "object", UI.GOLD)
	title_l.position = Vector2(0, 0)
	title_l.size = Vector2(NAME_W, 22)
	title_l.clip_text = true
	inner.add_child(title_l)

	var st_l := UI.label("进行中", "tag", UI.COPPER)
	st_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st_l.position = Vector2(NAME_W, 2)
	st_l.size = Vector2(INNER_W - NAME_W, 18)
	inner.add_child(st_l)

	var goal_l := UI.label("目标: %s" % String(story.get("goal", "")), "body", UI.PAPER)
	goal_l.position = Vector2(0, 24)
	goal_l.size = Vector2(INNER_W, 20)
	goal_l.clip_text = true
	inner.add_child(goal_l)

	var target_cfg := TableCache.main_world_map(String(story.get("map", "")))
	var to_l := UI.label("前往: %s" % String(target_cfg.get("name", "昭元边城")), "caption", UI.AGED)
	to_l.position = Vector2(0, 46)
	to_l.size = Vector2(INNER_W, 18)
	inner.add_child(to_l)

	var parts: Array = G.reward_lines(story.get("reward", {}))
	if parts.size() > 3:
		parts = parts.slice(0, 3)
		parts.append("…")
	var rw_l := UI.label("奖励: " + " · ".join(parts), "tag", UI.GOLD)
	rw_l.position = Vector2(0, 66)
	rw_l.size = Vector2(INNER_W, 18)
	rw_l.clip_text = true
	inner.add_child(rw_l)


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var offer := G.quest_offer()
	if offer.is_empty():
		var none := UI.label("今日暂无委托，请明日再来。", "body", UI.AGED)
		none.position = Vector2(0, 16)
		none.size = Vector2(CONTENT_W, 24)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(none)
		return
	for i in offer.size():
		var qid := String(offer[i])
		_row(qid, float(i) * (ROW_H + ROW_GAP))


func _row(qid: String, y: float) -> void:
	var d := G.quest_def(qid)
	if d.is_empty():
		return

	var row := Panel.new()
	row.position = Vector2(0, y)
	row.size = Vector2(CONTENT_W, ROW_H)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color("201a24", 0.92)
	row_style.border_color = Color("5c4834", 0.75)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(3)
	row.add_theme_stylebox_override("panel", row_style)
	_list.add_child(row)

	var inner := Control.new()
	inner.position = Vector2(12, 8)
	inner.size = Vector2(INNER_W, ROW_H - 16)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inner)

	var npc := G.city_npc(String(d.get("npc", "")))
	var who := String(npc.get("name", ""))
	var npc_title := String(npc.get("title", ""))
	if npc_title != "":
		who += " · " + npc_title

	var name_l := UI.label(String(d.get("title", qid)), "object", UI.PAPER)
	name_l.position = Vector2(0, 0)
	name_l.size = Vector2(NAME_W, 22)
	name_l.clip_text = true
	inner.add_child(name_l)

	var who_l := UI.label(who, "tag", UI.AGED)
	who_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	who_l.position = Vector2(NAME_W, 2)
	who_l.size = Vector2(INNER_W - NAME_W, 18)
	who_l.clip_text = true
	inner.add_child(who_l)

	var goal_l := UI.label(String(d.get("goal", "")), "caption", UI.PAPER)
	goal_l.position = Vector2(0, 24)
	goal_l.size = Vector2(GOAL_W, 20)
	goal_l.clip_text = true
	inner.add_child(goal_l)

	var state := G.quest_state(qid)
	var state_col := UI.AGED
	if state == "可交付":
		state_col = UI.JADE
	elif state.begins_with("进行中"):
		state_col = UI.GOLD
	var st_l := UI.label(state, "tag", state_col)
	st_l.position = Vector2(0, 46)
	st_l.size = Vector2(150, 18)
	st_l.clip_text = true
	inner.add_child(st_l)

	var reward: Dictionary = d.get("reward", {})
	var parts := PackedStringArray()
	for k in G.REWARD_KEYS:
		if int(reward.get(k, 0)) > 0:
			parts.append("%s+%d" % [String(G.REWARD_NAMES.get(k, k)), int(reward[k])])
	if parts.size() > 0:
		var rw_l := UI.label("奖励: " + " · ".join(parts), "tag", UI.GOLD)
		rw_l.position = Vector2(0, 66)
		rw_l.size = Vector2(INNER_W, 18)
		rw_l.clip_text = true
		inner.add_child(rw_l)

	var btn_text := ""
	var enabled := true
	var is_claim := false
	if G.quest_claimed(qid):
		btn_text = "已交付"
		enabled = false
	elif not G.quest_active(qid):
		btn_text = "接 取"
	elif G.quest_completed(qid):
		btn_text = "交 付"
		is_claim = true
	else:
		btn_text = "进行中"
		enabled = false

	var btn := Button.new()
	btn.text = btn_text
	btn.size = Vector2(BTN_W, 34)
	btn.position = Vector2(INNER_W - BTN_W, 26)
	var btn_style := StyleBoxFlat.new()
	if is_claim:
		btn_style.bg_color = Color("7a2e20", 0.95)
		btn_style.border_color = UI.GOLD
	else:
		btn_style.bg_color = Color("231e28", 0.9)
		btn_style.border_color = Color("5e4b38", 0.8)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	btn.add_theme_color_override("font_color", UI.GOLD if is_claim else (UI.PAPER if enabled else UI.AGED))
	btn.add_theme_font_override("font", G.font_reg)
	btn.add_theme_font_size_override("font_size", 13)
	btn.disabled = not enabled
	if enabled:
		btn.pressed.connect(func(): _act(qid))
	inner.add_child(btn)


func _act(qid: String) -> void:
	if G.quest_active(qid):
		var res := G.quest_claim(qid)
		if bool(res.get("ok", false)):
			Audio.sfx("reward")
			_show_toast("「%s」交付 · %s" % [String(res.get("title", "")),
				" · ".join(PackedStringArray(res.get("lines", [])))])
		else:
			Audio.sfx("ui_locked")
			_show_toast(String(res.get("err", "还不能交付")))
	else:
		if G.quest_accept(qid):
			Audio.sfx("ui_confirm")
			var d := G.quest_def(qid)
			_show_toast("接下委托: %s" % String(d.get("title", "")))
			var desc := String(d.get("desc", ""))
			if desc != "":
				G.show_info_popup(self, String(d.get("title", "")), [desc, "", "目标：" + String(d.get("goal", ""))])
		else:
			Audio.sfx("ui_locked")
			_show_toast("该委托无法接取")
	_refresh()


func _show_toast(msg: String) -> void:
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
	_toast = UI.label(msg, "caption", UI.GOLD)
	_toast.position = Vector2(0, 96)
	_toast.size = Vector2(VIEW_W, 24)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if _world_board != null: return
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_self()
		get_viewport().set_input_as_handled()
