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
		var empty_panel := Craft.panel(Vector2.ZERO,Vector2(432,332),.96)
		_content.add_child(empty_panel)
		var banner := TextureRect.new()
		banner.texture = G.Visuals._kit_tex("activity_header_banner.png")
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		banner.position = Vector2(6, 6)
		banner.size = Vector2(420, 84)
		banner.modulate = Color(1, 1, 1, 0.72)
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(banner)
		var slot_bg := TextureRect.new()
		slot_bg.texture = G.Visuals._kit_tex("slot_legend.png")
		slot_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_bg.stretch_mode = TextureRect.STRETCH_SCALE
		slot_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot_bg.position = Vector2(182, 58)
		slot_bg.size = Vector2(68, 68)
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(slot_bg)
		Craft.icon(_content,"world",Vector2(190,66),Vector2(52,52))
		var heading := Craft.label("暂无正在进行的活动",Vector2(24,142),Vector2(384,32),G.FS_LG,Craft.WHITE,true)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(heading)
		var note := Craft.label("新活动开启后，将在这里显示\n时间、玩法与参与说明。",Vector2(40,192),Vector2(352,80),G.FS_SM,Craft.MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(note)
		return
	var top_banner := TextureRect.new()
	top_banner.texture = G.Visuals._kit_tex("activity_header_banner.png")
	top_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	top_banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top_banner.custom_minimum_size = Vector2(412, 68)
	top_banner.modulate = Color(1, 1, 1, 0.82)
	top_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list := _scroll()
	list.add_child(top_banner)
	var now := int(Time.get_unix_time_from_system())
	for event in _events:
		var card := Craft.action("",Vector2.ZERO,Vector2(412,122))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.name = "Event_"+String(event.id)
		var title := Craft.label("◆ " + String(event.title),Vector2(16,8),Vector2(294,32),G.FS_MD,Craft.WHITE,true)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_child(title)
		var st_txt := event_status(event,now)
		var st_col := Color("84d498") if st_txt == "进行中" else Craft.GOLD
		card.add_child(Craft.label("【" + st_txt + "】",Vector2(304,10),Vector2(100,28),G.FS_XS,st_col))
		var div := ColorRect.new()
		div.color = Color(Craft.GOLD, 0.28)
		div.position = Vector2(16, 42)
		div.size = Vector2(380, 1)
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(div)
		var note := Craft.label(String(event.get("summary","点击查看活动详情")),Vector2(16,48),Vector2(370,52),G.FS_XS,Craft.MUTED)
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
	var detail_banner := TextureRect.new()
	detail_banner.texture = G.Visuals._kit_tex("activity_header_banner.png")
	detail_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	detail_banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_banner.position = Vector2(6, 6)
	detail_banner.size = Vector2(_content.size.x - 12, 72)
	detail_banner.modulate = Color(1, 1, 1, 0.52)
	detail_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(detail_banner)
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
	_add_paragraph(inner,String(event.title),G.FS_LG,Craft.WHITE,true)
	_add_paragraph(inner,"◆ " + event_status(event,int(Time.get_unix_time_from_system())),G.FS_SM,Craft.GOLD)
	var start := _timestamp(event,"starts_at")
	var finish := _timestamp(event,"ends_at")
	if start>0 or finish>0:
		_add_paragraph(inner,"开始：%s\n结束：%s" % [_date(start),_date(finish)],G.FS_XS,Craft.MUTED)
	var body: Variant = event.get("body",event.get("summary","活动说明将在开启时公布。"))
	if body is Array:
		for paragraph in body: _add_paragraph(inner,String(paragraph),G.FS_MD,Craft.WHITE)
	else: _add_paragraph(inner,String(body),G.FS_MD,Craft.WHITE)

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
