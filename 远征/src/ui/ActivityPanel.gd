extends Control
## Presentation reads configured activities; opening a page never grants rewards.
signal closed
signal action_requested(action_id: String)
const View := preload("res://src/ui/ShowcaseUI.gd")
const KitV4 := preload("res://src/ui/KitV4.gd")
const TouchScroll := preload("res://src/ui/TouchScroll.gd")
const CONFIG := "res://data/activities.json"
var events_override: Variant = null
var _events: Array[Dictionary] = []
var _content: TouchScroll
var _detail_id := ""
var _back: Button
var _frame: PanelContainer
var _filter := "all"
var _filters: Dictionary = {}
var _clock := 0.0
var _status_signature := ""

static func event_status(event: Dictionary,now: int) -> String:
	for key in ["starts_at","ends_at"]:
		var value: Variant = event.get(key,0)
		if not (value is int or value is float): return "未开放"
	var start := int(event.get("starts_at",0))
	var finish := int(event.get("ends_at",0))
	if not bool(event.get("enabled",true)) or start<0 or finish<0 or (finish>0 and start>finish): return "未开放"
	if finish>0 and now>=finish: return "已结束"
	if start>0 and now<start: return "即将开启"
	return "进行中"

static func valid_events(rows: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Dictionary = {}
	if not rows is Array: return result
	for value in rows:
		if not value is Dictionary: continue
		var event: Dictionary = value
		var id := String(event.get("id","")).strip_edges()
		var title := String(event.get("title","")).strip_edges()
		if id.is_empty() or title.is_empty() or ids.has(id) or not bool(event.get("visible",true)): continue
		ids[id] = true
		result.append(event.duplicate(true))
	return result

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("safe_layout_exempt",true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = View.INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var rows: Variant = data.get("events",[]) if data is Dictionary else []
	_events = valid_events(rows if events_override==null else events_override)
	_frame = View.frame(18)
	add_child(_frame)
	var column := View.column(12)
	_frame.add_child(column)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	column.add_child(top_row)
	_back = G.top_back_button(top_row, go_back, Vector2.ZERO, "返回营帐")
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title_col := View.column(2)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_col)
	title_col.add_child(View.text("行旅活动","title",View.GOLD))
	title_col.add_child(View.text("演武磨砺 · 重访山河","caption",View.MUTED))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",8)
	column.add_child(tabs)
	for pair in [["all","全部"],["permanent","常驻玩法"],["timed","限时活动"]]:
		var key: String = pair[0]
		var b := View.button(pair[1])
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():_filter=key;_show_list())
		tabs.add_child(b)
		_filters[key] = b
	_content = View.scroll()
	column.add_child(_content)
	_show_list()
	get_viewport().size_changed.connect(_layout_page)
	preload("res://src/ui/UiSafeArea.gd").watch(self,_layout_page)
	_layout_page()

func _layout_page() -> void:
	if _frame==null:return
	var safe := G.ui_safe_rect(self)
	_frame.size = Vector2(minf(620,safe.size.x-20),safe.size.y-20)
	_frame.position = safe.get_center()-_frame.size*.5

func _clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_content.scroll_vertical = 0

func _scroll() -> VBoxContainer:
	var list := View.column(14)
	_content.add_child(list)
	return list

func _show_list() -> void:
	_clear_content()
	_detail_id = ""
	_back.text = "‹"
	_back.tooltip_text = "返回营帐"
	for key in _filters:_filters[key].set_pressed_no_signal(key==_filter)
	var list := _scroll()
	var count := 0
	var now := int(Time.get_unix_time_from_system())
	for event in _events:
		var timed := _timestamp(event,"starts_at")>0 or _timestamp(event,"ends_at")>0
		if (_filter=="timed" and not timed) or (_filter=="permanent" and timed):continue
		count+=1
		list.add_child(_event_card(event,now))
	if count==0:
		list.add_child(View.hero("暂无限时活动" if _filter=="timed" else "暂无活动","常驻玩法可在分类中浏览。\n新活动开放后会在这里显示。",G.NavigationIcons.texture("world")))

func _event_card(event: Dictionary, now: int) -> Control:
	var card := View.frame(14)
	card.name = "Event_"+String(event.id)
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var id := String(event.id)
	card.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and not e.pressed and not _content.gesture_active()) or e.is_action_pressed("ui_accept"):
			show_event(id))
	var column := View.column(10)
	card.add_child(column)
	var art_path := String(event.get("art","res://assets/ui/arena_v2/arena_duel_stage.png"))
	if ResourceLoader.exists(art_path):
		var image := View.picture(load(art_path),100)
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.custom_minimum_size = Vector2(0,104)
		image.clip_contents = true
		column.add_child(image)
		var q_btn := Button.new()
		q_btn.text = "?"
		q_btn.custom_minimum_size = Vector2(32, 32)
		q_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		q_btn.offset_left = -40; q_btn.offset_top = 8; q_btn.offset_right = -8; q_btn.offset_bottom = 40
		var q_sb := KitV4.style("btn_round", 0)
		for st in ["normal", "hover", "pressed"]:
			q_btn.add_theme_stylebox_override(st, q_sb)
		q_btn.add_theme_font_override("font", G.font_bold)
		q_btn.add_theme_font_size_override("font_size", G.FS_SM)
		q_btn.add_theme_color_override("font_color", KitV4.GOLD)
		q_btn.pressed.connect(show_event.bind(id))
		image.add_child(q_btn)
	var status := event_status(event,now)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	column.add_child(head_row)
	var t_lbl := View.text(String(event.title),"section",View.GOLD)
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(t_lbl)
	var st_lbl := View.text(("常驻" if _timestamp(event,"starts_at")==0 and _timestamp(event,"ends_at")==0 else "限时")+" · "+status,"tag",View.JADE if status=="进行中" else View.MUTED)
	st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head_row.add_child(st_lbl)
	column.add_child(View.text(String(event.get("summary","查看活动详情")),"body"))
	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 8)
	column.add_child(bot_row)
	var reward := String(event.get("reward_summary",""))
	var r_lbl := View.text("收获 · "+reward if not reward.is_empty() else "参与可得历练奖励","caption",View.JADE)
	r_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_row.add_child(r_lbl)
	var b := View.button("前往",status=="进行中")
	b.custom_minimum_size = Vector2(108, 44)
	b.pressed.connect(show_event.bind(id))
	bot_row.add_child(b)
	return card

func show_event(id: String) -> void:
	var event: Dictionary = {}
	for row in _events:
		if String(row.id)==id:event=row;break
	if event.is_empty():return
	_clear_content()
	_detail_id = id
	_back.text = "‹"
	_back.tooltip_text = "返回活动"
	var list := _scroll()
	list.add_child(View.text(String(event.title),"title",View.GOLD))
	var status := event_status(event,int(Time.get_unix_time_from_system()))
	list.add_child(View.text(status,"object",View.JADE))
	if _timestamp(event,"starts_at")>0 or _timestamp(event,"ends_at")>0:
		list.add_child(View.text("开始 "+_date(_timestamp(event,"starts_at"))+"\n结束 "+_date(_timestamp(event,"ends_at")),"caption",View.MUTED))
	else:list.add_child(View.text("常驻玩法 · 无结束时间","caption",View.MUTED))
	var body: Variant = event.get("body",event.get("summary","活动说明将在开启时公布。"))
	if body is Array:
		for paragraph in body:list.add_child(View.text(String(paragraph)))
	else:list.add_child(View.text(String(body)))
	var reward := String(event.get("reward_summary",""))
	if not reward.is_empty():list.add_child(View.hero("玩法收获",reward,G.NavigationIcons.texture("honor")))
	var action_id := String(event.get("action",""))
	if not action_id.is_empty():
		var b := View.button(String(event.get("action_text","前往挑战")),true)
		b.disabled = status!="进行中"
		b.pressed.connect(func():
			if event_status(event,int(Time.get_unix_time_from_system()))=="进行中":action_requested.emit(action_id)
			else:show_event(id))
		list.add_child(b)

func _process(delta: float) -> void:
	_clock+=delta
	if _clock<1.0:return
	_clock=0
	var states: Array[String] = []
	for row in _events:states.append(event_status(row,int(Time.get_unix_time_from_system())))
	var signature := "|".join(states)
	if not _status_signature.is_empty() and signature!=_status_signature:
		if _detail_id.is_empty():_show_list()
		else:show_event(_detail_id)
	_status_signature=signature

func _date(stamp: int) -> String:
	if stamp<=0:return "未设置"
	var local_stamp := stamp+int(Time.get_time_zone_from_system().get("bias",0))*60
	return Time.get_datetime_string_from_unix_time(local_stamp).replace("T"," ").left(16)

func _timestamp(event: Dictionary,key: String) -> int:
	var value: Variant = event.get(key,0)
	return int(value) if value is int or value is float else 0

func go_back() -> void:
	if not _detail_id.is_empty():_show_list()
	else:closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()
