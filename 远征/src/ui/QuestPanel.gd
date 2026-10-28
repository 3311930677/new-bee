# Quest journal: responsive containers, pixel material plates, existing quest operations.
class_name QuestPanel
extends Control
signal closed
const UI := preload("res://src/ui/TravelChestUI.gd")
const Art := preload("res://src/ui/InventoryQuestSkin.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const INNER_W := 420.0
var _panel: PanelContainer
var _content: VBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _world_board: Control
var _toast: Control
var _back: Button
var _world_button: Button
var _focus_return: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_focus_return = get_viewport().gui_get_focus_owner()
	theme = Art.theme()
	Audio.sfx("ui_open")
	_build()
	_refresh()
	get_viewport().size_changed.connect(_resize_frame)
	preload("res://src/ui/UiSafeArea.gd").watch(self,_resize_frame)
	_content.minimum_size_changed.connect(_resize_frame.call_deferred)
	_resize_frame()
	_world_button.grab_focus.call_deferred()

func _build() -> void:
	var stage := Art.Stage.new()
	stage.name = "PageBackground"
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	_panel = PanelContainer.new()
	_panel.name = "QuestBoard"
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.add_theme_stylebox_override("panel", Art.box("card", 14))
	add_child(_panel)
	_content = VBoxContainer.new()
	_content.name = "JournalContent"
	_content.add_theme_constant_override("separation", 10)
	_panel.add_child(_content)
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 60
	header.add_theme_stylebox_override("panel", Art.box("header", 8))
	_content.add_child(header)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	header.add_child(head_row)
	var top_back := Art.action("‹", "back")
	top_back.name = "HeaderBackButton"
	top_back.custom_minimum_size = Vector2(44, 44)
	top_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_back.tooltip_text = "返回"
	top_back.pressed.connect(_close_self)
	head_row.add_child(top_back)
	var mark := G.ui_icon("quest", Vector2(28,28), Art.GOLD)
	mark.name="HeaderIcon"
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(mark)
	var title := Art.label("任务卷宗", "title", Art.GOLD)
	title.name="JournalTitle"
	title.clip_text=true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(title)
	_world_button = Art.action("世界事务")
	_world_button.name = "WorldAffairsButton"
	_world_button.custom_minimum_size = Vector2(104,44)
	_world_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_world_button.caption.add_theme_font_size_override("font_size", G.FS_XS)
	_world_button.pressed.connect(_open_world_board)
	head_row.add_child(_world_button)
	_content.add_child(_section("主线传书", "quest"))
	_story_card(G.story_current())
	_content.add_child(_section("边城委托", "swords"))
	var tip := Art.label("已接委托跨日保留 · 完成后回城交付", "caption", Art.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(tip)
	_scroll = Page.scroll()
	_scroll.name = "CommissionScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "CommissionCards"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)
	_back = Art.action("返回")
	_back.name = "ReturnButton"
	_back.custom_minimum_size = Vector2(160,48)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(_close_self)
	_content.add_child(_back)

func _resize_frame(safe_override := Rect2()) -> void:
	if _panel == null: return
	var safe: Rect2 = safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var compact:=safe.size.x<400
	_panel.find_child("HeaderIcon",true,false).visible=not compact
	var title:=_panel.find_child("JournalTitle",true,false) as Label
	title.add_theme_font_size_override("font_size",G.FS_SECTION if compact else G.FS_BIG)
	_world_button.custom_minimum_size.x=68 if compact else 104
	_world_button.caption.text="事务" if compact else "世界事务"
	var height := safe.size.y - 24.0
	_panel.position = safe.position + Vector2(16,roundf((safe.size.y-height)*.5))
	_panel.size = Vector2(safe.size.x-32,height)
	# Labels in side columns wrap, so long NPC titles cannot widen the journal.
	for label in _panel.find_children("*","Label",true,false):
		if label.text.begins_with("已接委托"):label.clip_text=true
	var story_icon:=_panel.find_child("StoryIcon",true,false) as Control
	if story_icon!=null:story_icon.visible=not compact
	for card in _list.get_children():
		if not card.has_meta("side_column"):continue
		var side:Control=card.get_meta("side_column")
		var target:Node=card.get_meta("card_body") if compact else card.get_meta("info_row")
		if side.get_parent()!=target:side.reparent(target,false)
		side.custom_minimum_size.x=0 if compact else float(card.get_meta("side_width"))

func _section(words: String, icon: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 30
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Art.box("secondary", 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var mark := G.ui_icon(icon, Vector2(20,20), Art.GOLD)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	row.add_child(Art.label(words,"section",Art.GOLD))
	return panel

const Journey := preload("res://src/world/JourneyService.gd")
var _region_map: Control

func _story_card(story: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "MainStoryCard"
	card.custom_minimum_size.y = 128 if not story.is_empty() else 56
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", Art.box("card", 12))
	_content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var mark := G.ui_icon("quest", Vector2(44,44), Art.GOLD)
	mark.name="StoryIcon"
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	row.add_child(info)
	if story.is_empty():
		info.add_child(_line(G.story_goal_short(),"caption",Art.MUTED))
		return
	var top := HBoxContainer.new()
	info.add_child(top)
	var title := _line(String(story.get("title","")),"object",Art.PAPER)
	title.name = "MainStoryTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(68, 26)
	badge.add_theme_stylebox_override("panel",_badge_box())
	var badge_l := Art.label("进行中","tag",Art.JADE)
	badge_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_l)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(badge)
	info.add_child(_line("目标：" + String(story.get("goal","")),"body"))
	var target_map_id := String(story.get("map","lorin_wilds"))
	var target := TableCache.main_world_map(target_map_id)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	info.add_child(bottom_row)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 3)
	bottom_row.add_child(text_col)
	text_col.add_child(_line("前往：" + String(target.get("name","昭元边城")),"caption",Art.MUTED))
	text_col.add_child(_line("奖励：" + " · ".join(G.reward_lines(story.get("reward",{}))),"tag",Art.GOLD))
	var nav_btn := Art.action("行路图", "secondary")
	nav_btn.name = "StoryMapButton"
	nav_btn.custom_minimum_size = Vector2(88, 40)
	nav_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	nav_btn.pressed.connect(func(): _open_region_map(target_map_id))
	bottom_row.add_child(nav_btn)

func _badge_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("21433e")
	box.border_color = Color("527e66")
	box.set_border_width_all(1)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

func _line(words: String, role := "body", color := Art.PAPER) -> Label:
	var l := Art.label(words,role,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _refresh() -> void:
	var offset := _scroll.scroll_vertical
	var focused_id := ""
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null: focused_id = String(owner.get_meta("quest_id",""))
	Page.clear(_list)
	for id in G.quest_offer(): _row(String(id))
	if _list.get_child_count() == 0:
		_list.add_child(_line("今日暂无委托，请明日再来。","body",Art.MUTED))
	_append_side_quests()
	_scroll.set_deferred("scroll_vertical",offset)
	var controls: Array[Button] = [_world_button]
	for row in _list.get_children():
		var b := row.find_child("QuestAction", true, false) as Button
		if b != null and not b.disabled: controls.append(b)
		if b != null and String(b.get_meta("quest_id","")) == focused_id:
			(b if not b.disabled else _back).grab_focus.call_deferred()
	controls.append(_back)
	for i in controls.size():
		controls[i].focus_next = controls[(i+1)%controls.size()].get_path()
		controls[i].focus_previous = controls[posmod(i-1,controls.size())].get_path()

func _append_side_quests() -> void:
	if not G.has_method("side_status_of"): return
	var active_rows: Array = []
	for row_v in TableCache.side_quests_config().get("quests", []):
		var srow := row_v as Dictionary
		var sid := String(srow.get("id", ""))
		var st: String = String(G.side_status_of(sid))
		if st in ["active", "ready"]:
			active_rows.append(srow)
	if active_rows.is_empty(): return
	_list.add_child(_section("支线轶事 · 寻迹与信使", "quest"))
	var tracked_id: String = String(G.side_tracked_id()) if G.has_method("side_tracked_id") else ""
	for srow_v in active_rows:
		var srow := srow_v as Dictionary
		var sid := String(srow.get("id", ""))
		var st: String = String(G.side_status_of(sid))
		var card := PanelContainer.new()
		card.name = "SideQuest_" + sid
		card.custom_minimum_size.y = 124
		card.add_theme_stylebox_override("panel", Art.box("card", 12))
		_list.add_child(card)
		var body:=VBoxContainer.new()
		body.add_theme_constant_override("separation",8)
		card.add_child(body)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		body.add_child(row)
		var mark := G.ui_icon("quest", Vector2(30, 30), Art.JADE if st == "ready" else Art.GOLD)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		row.add_child(info)
		var map_id := String(srow.get("map", "lorin_wilds")) if st == "active" else String(srow.get("turn_in_map", srow.get("map", "lorin_wilds")))
		var map_name := String(TableCache.main_world_map(map_id).get("name", map_id))
		info.add_child(_line(String(srow.get("title", sid)) + (" [追踪中]" if sid == tracked_id else ""), "object"))
		info.add_child(_line(String(srow.get("clue", "")), "caption"))
		info.add_child(_line(("可交付 · " if st == "ready" else "进行中 · ") + "地点：" + map_name, "tag", Art.JADE if st == "ready" else Art.GOLD))
		var side := VBoxContainer.new()
		side.custom_minimum_size.x = 108
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		side.add_theme_constant_override("separation", 6)
		row.add_child(side)
		card.set_meta("side_column",side)
		card.set_meta("card_body",body)
		card.set_meta("info_row",row)
		card.set_meta("side_width",108)
		var choices: Array = srow.get("choices", [])
		var can_courier := st == "ready" and choices.is_empty()
		var act_label := "信使交付" if can_courier else ("前往抉择" if st == "ready" else ("看地图" if sid == tracked_id else "追踪"))
		var btn := Art.action(act_label, "primary" if st == "ready" or sid != tracked_id else "secondary")
		btn.custom_minimum_size = Vector2(108, 42)
		btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
		btn.pressed.connect(func(): _on_side_action(sid, st, can_courier, map_id))
		side.add_child(btn)

func _on_side_action(sid: String, st: String, can_courier: bool, map_id: String) -> void:
	if can_courier:
		var res: Dictionary = G._side_complete(sid, true, "")
		if bool(res.get("ok", false)):
			Audio.sfx("reward")
			_show_toast("信使已代交「%s」并带回谢礼！" % String(res.get("title", sid)))
		else:
			Audio.sfx("ui_locked")
			_show_toast("该任务需当面交付")
		_refresh()
		return
	if st == "ready":
		_open_region_map(map_id)
		return
	if G.has_method("side_track"):
		var tracked: String = String(G.side_tracked_id())
		if tracked == sid:
			_open_region_map(map_id)
		else:
			G.side_track(sid)
			Audio.sfx("ui_confirm")
			_show_toast("已追踪支线：" + String(G.side_quest_def(sid).get("title", sid)))
			_refresh()

func _open_region_map(focus_map_id: String) -> void:
	if _region_map != null: return
	_region_map = RegionMapPanel.new()
	add_child(_region_map)
	if not focus_map_id.is_empty() and _region_map.has_method("select"):
		_region_map.call_deferred("select", focus_map_id, true)
	_region_map.closed.connect(func():
		if is_instance_valid(_region_map):
			_region_map.queue_free()
		_region_map = null)

func _row(qid: String) -> void:
	var d := G.quest_def(qid)
	if d.is_empty(): return
	var card := PanelContainer.new()
	card.name = "Quest_" + qid
	card.custom_minimum_size.y = 132
	card.add_theme_stylebox_override("panel",Art.box("card",12))
	_list.add_child(card)
	var body:=VBoxContainer.new()
	body.add_theme_constant_override("separation",8)
	card.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	body.add_child(row)
	var mark := G.ui_icon("swords" if String(d.get("kind","")) == "slay" else "quest",Vector2(32,32),Art.GOLD)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",4)
	row.add_child(info)
	info.add_child(_line(String(d.get("title",qid)),"object"))
	info.add_child(_line(String(d.get("goal","")),"caption"))
	var state := G.quest_state(qid)
	info.add_child(_line(state,"tag",Art.JADE if state == "可交付" else Art.GOLD if state.begins_with("进行中") else Art.MUTED))
	var reward_line := _line(" · ".join(G.reward_lines(d.get("reward",{}))),"tag",Art.GOLD)
	reward_line.add_theme_font_size_override("font_size", G.FS_DENSE)
	info.add_child(reward_line)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 114
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation",8)
	row.add_child(side)
	card.set_meta("side_column",side)
	card.set_meta("card_body",body)
	card.set_meta("info_row",row)
	card.set_meta("side_width",114)
	var npc := G.city_npc(String(d.get("npc","")))
	var who := String(npc.get("name",""))
	if not String(npc.get("title","")).is_empty(): who += " · " + String(npc.title)
	var who_label := Art.label(who,"tag",Art.MUTED)
	who_label.clip_text=true
	who_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who_label.custom_minimum_size.x = 114
	who_label.add_theme_font_size_override("font_size", G.FS_DENSE)
	side.add_child(who_label)
	var enabled := not G.quest_claimed(qid) and (not G.quest_active(qid) or G.quest_completed(qid))
	var words := "已交付" if G.quest_claimed(qid) else "接取" if not G.quest_active(qid) else "交付" if G.quest_completed(qid) else "进行中"
	var btn := Art.action(words,"primary" if enabled else "secondary")
	btn.name = "QuestAction"
	btn.set_meta("quest_id",qid)
	btn.custom_minimum_size = Vector2(108,44)
	btn.caption.add_theme_font_size_override("font_size",G.FS_SM)
	btn.disabled = not enabled
	btn.pressed.connect(_act.bind(qid))
	btn.focus_entered.connect(func(): _scroll.ensure_control_visible(btn))
	side.add_child(btn)

func _open_world_board() -> void:
	if _world_board != null: return
	_world_board = preload("res://src/ui/WorldCommissionPanel.gd").new()
	add_child(_world_board)
	_world_board.closed.connect(func():
		_world_board.queue_free()
		_world_board = null
		_world_button.grab_focus.call_deferred())

func _close_self() -> void:
	Audio.sfx("ui_close")
	if is_instance_valid(_focus_return): _focus_return.grab_focus.call_deferred()
	G.close_page(self, func(): closed.emit())

func _act(qid: String) -> void:
	if G.quest_active(qid):
		var res := G.quest_claim(qid)
		if bool(res.get("ok",false)):
			Audio.sfx("reward")
			_show_toast("「%s」交付 · %s" % [String(res.get("title","")), " · ".join(PackedStringArray(res.get("lines",[])))])
		else:
			Audio.sfx("ui_locked")
			_show_toast(String(res.get("err","还不能交付")))
	else:
		if G.quest_accept(qid):
			Audio.sfx("ui_confirm")
			var d := G.quest_def(qid)
			_show_toast("接下委托：" + String(d.get("title","")))
			var desc := String(d.get("desc",""))
			if not desc.is_empty(): G.show_info_popup(self,String(d.get("title","")),[desc,"","目标：" + String(d.get("goal",""))])
		else:
			Audio.sfx("ui_locked")
			_show_toast("该委托无法接取")
	_refresh()

func _show_toast(msg: String, _err: bool = false) -> void:
	if is_instance_valid(_toast): _toast.queue_free()
	_toast = UI.toast(self,msg)

func _unhandled_input(event: InputEvent) -> void:
	if _world_board != null or G.ui_blocked: return
	if event.is_action_pressed("ui_cancel"):
		_close_self()
		get_viewport().set_input_as_handled()
