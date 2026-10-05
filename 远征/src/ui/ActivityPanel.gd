extends Control
## Configured announcements only. Opening this page never changes player progress.
signal closed
const Craft := preload("res://src/ui/CraftUI.gd")
const CONFIG := "res://data/activities.json"
var events_override: Variant = null
var _events: Array[Dictionary] = []
var _content: Control
var _detail_id := ""
var _back: Control

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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Craft.scene(self,.65)
	Craft.heading(self,"活动","行旅告示 · 活动与新消息")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var rows: Variant = data.get("events",[]) if data is Dictionary else []
	_events = valid_events(rows if events_override==null else events_override)
	_content = Control.new()
	_content.position = Vector2(24,132)
	_content.size = Vector2(432,544)
	add_child(_content)
	_back = Craft.action("返回营帐",Vector2(130,716),Vector2(220,48))
	_back.activated.connect(go_back)
	add_child(_back)
	_show_list()
	G.center_fixed_page.call_deferred(self)
	G.fit_mobile_page.call_deferred(self)

func _clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

func _scroll() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size = _content.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 412
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",16)
	scroll.add_child(list)
	return list

func _show_list() -> void:
	_clear_content()
	_detail_id = ""
	_back.caption.text = "返回营帐"
	if _events.is_empty():
		_content.add_child(Craft.panel(Vector2.ZERO,Vector2(432,312),.96))
		Craft.icon(_content,"world",Vector2(190,42),Vector2(52,52))
		var heading := Craft.label("暂无正在进行的活动",Vector2(24,128),Vector2(384,32),22,Craft.WHITE,true)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(heading)
		var note := Craft.label("新活动开启后，将在这里显示\n时间、玩法与参与说明。",Vector2(40,180),Vector2(352,80),17,Craft.MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(note)
		return
	var list := _scroll()
	var now := int(Time.get_unix_time_from_system())
	for event in _events:
		var card := Craft.action("",Vector2.ZERO,Vector2(412,122))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.name = "Event_"+String(event.id)
		var title := Craft.label(String(event.title),Vector2(16,8),Vector2(294,32),20,Craft.WHITE,true)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_child(title)
		card.add_child(Craft.label(event_status(event,now),Vector2(318,10),Vector2(86,28),16,Craft.GOLD))
		var note := Craft.label(String(event.get("summary","点击查看活动详情")),Vector2(16,48),Vector2(370,52),16,Craft.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_child(note)
		var id := String(event.id)
		card.activated.connect(func(): show_event(id))
		list.add_child(card)

func show_event(id: String) -> void:
	var event: Dictionary = {}
	for row in _events:
		if String(row.id)==id: event = row; break
	if event.is_empty(): return
	_clear_content()
	_detail_id = id
	_back.caption.text = "返回活动"
	_content.add_child(Craft.panel(Vector2.ZERO,_content.size,.97))
	var list := _scroll()
	list.custom_minimum_size.x = 392
	list.add_theme_constant_override("separation",20)
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left",20)
	inset.add_theme_constant_override("margin_right",20)
	inset.add_theme_constant_override("margin_top",20)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation",20)
	inset.add_child(inner)
	list.add_child(inset)
	_add_paragraph(inner,String(event.title),24,Craft.WHITE,true)
	_add_paragraph(inner,event_status(event,int(Time.get_unix_time_from_system())),17,Craft.GOLD)
	var start := _timestamp(event,"starts_at")
	var finish := _timestamp(event,"ends_at")
	if start>0 or finish>0:
		_add_paragraph(inner,"开始：%s\n结束：%s" % [_date(start),_date(finish)],16,Craft.MUTED)
	var body: Variant = event.get("body",event.get("summary","活动说明将在开启时公布。"))
	if body is Array:
		for paragraph in body: _add_paragraph(inner,String(paragraph),18,Craft.WHITE)
	else: _add_paragraph(inner,String(body),18,Craft.WHITE)

func _add_paragraph(parent: Control,words: String,px: int,ink: Color,bold := false) -> void:
	var l := Craft.label(words,Vector2.ZERO,Vector2(360,32),px,ink,bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)

func _date(stamp: int) -> String:
	if stamp<=0: return "待公布"
	var local_stamp := stamp + int(Time.get_time_zone_from_system().get("bias",0))*60
	return Time.get_datetime_string_from_unix_time(local_stamp).replace("T"," ").left(16)

func _timestamp(event: Dictionary,key: String) -> int:
	var value: Variant = event.get(key,0)
	return int(value) if (value is int or value is float) else 0

func go_back() -> void:
	if not _detail_id.is_empty(): _show_list()
	else: closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()
