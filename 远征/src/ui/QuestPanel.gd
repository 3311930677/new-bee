# Quest journal: responsive containers, pixel material plates, existing quest operations.
class_name QuestPanel
extends Control
signal closed
const UI := preload("res://src/ui/TravelChestUI.gd")
const Art := preload("res://src/ui/InventoryQuestSkin.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
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
	head_row.add_theme_constant_override("separation", 12)
	header.add_child(head_row)
	var mark := G.ui_icon("quest", Vector2(28,28), Art.GOLD)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(mark)
	var title := Art.label("任务卷宗", "title", Art.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(title)
	_world_button = Art.action("世界事务")
	_world_button.name = "WorldAffairsButton"
	_world_button.custom_minimum_size = Vector2(104,44)
	_world_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_world_button.caption.add_theme_font_size_override("font_size", 13)
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
	var height := minf(800,safe.size.y-32)
	_panel.position = safe.position + Vector2(16,roundf((safe.size.y-height)*.5))
	_panel.size = Vector2(safe.size.x-32,height)

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

func _story_card(story: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "MainStoryCard"
	card.custom_minimum_size.y = 128 if not story.is_empty() else 56
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", Art.box("card", 12))
	_content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var mark := G.ui_icon("quest", Vector2(44,44), Art.GOLD)
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
	badge.add_theme_stylebox_override("panel",_badge_box())
	badge.add_child(Art.label("进行中","tag",Art.JADE))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(badge)
	info.add_child(_line("目标：" + String(story.get("goal","")),"body"))
	var target := TableCache.main_world_map(String(story.get("map","")))
	info.add_child(_line("前往：" + String(target.get("name","昭元边城")),"caption",Art.MUTED))
	info.add_child(_line("奖励：" + " · ".join(G.reward_lines(story.get("reward",{}))),"tag",Art.GOLD))

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

func _row(qid: String) -> void:
	var d := G.quest_def(qid)
	if d.is_empty(): return
	var card := PanelContainer.new()
	card.name = "Quest_" + qid
	card.custom_minimum_size.y = 132
	card.add_theme_stylebox_override("panel",Art.box("card",12))
	_list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	card.add_child(row)
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
	info.add_child(_line(" · ".join(G.reward_lines(d.get("reward",{}))),"tag",Art.GOLD))
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 108
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation",8)
	row.add_child(side)
	var npc := G.city_npc(String(d.get("npc","")))
	var who := String(npc.get("name",""))
	if not String(npc.get("title","")).is_empty(): who += " · " + String(npc.title)
	var who_label := _line(who,"tag",Art.MUTED)
	who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who_label.custom_minimum_size.x = 108
	who_label.add_theme_font_size_override("font_size",11)
	side.add_child(who_label)
	var enabled := not G.quest_claimed(qid) and (not G.quest_active(qid) or G.quest_completed(qid))
	var words := "已交付" if G.quest_claimed(qid) else "接取" if not G.quest_active(qid) else "交付" if G.quest_completed(qid) else "进行中"
	var btn := Art.action(words,"primary" if enabled else "secondary")
	btn.name = "QuestAction"
	btn.set_meta("quest_id",qid)
	btn.custom_minimum_size = Vector2(108,44)
	btn.caption.add_theme_font_size_override("font_size",16)
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

func _show_toast(msg: String) -> void:
	if is_instance_valid(_toast): _toast.queue_free()
	_toast = UI.toast(self,msg)

func _unhandled_input(event: InputEvent) -> void:
	if _world_board != null or G.ui_blocked: return
	if event.is_action_pressed("ui_cancel"):
		_close_self()
		get_viewport().set_input_as_handled()
