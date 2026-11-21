extends Control
## 在线社交、聊天与组队浮层；所有关系、消息和队伍状态以服务端返回为准。

signal closed
signal action_requested(kind: String, payload: Dictionary)

var _status: Label
var _tab := "party"
var _tab_btns: Dictionary = {}
var _social: Dictionary = {}
var _messages: Array = []
var _entities: Array = []
var _list: VBoxContainer
var _chat_bar: HBoxContainer
var _chat_channel := "room"
var _chat_input: LineEdit
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	G.veil(self, 0.96, true)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.add_child(G.gold_label("同行社交与组队", G.FS_BIG))
	_status = G.gold_label("正在同步……", G.FS_SM, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	for entry in [["party", "队伍"], ["friends", "好友"], ["chat", "聊天"], ["blocks", "屏蔽"]]:
		var key := String(entry[0])
		_tab_btns[key] = _btn(tabs, String(entry[1]), func() -> void:
			_tab = key
			_rebuild())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	_chat_bar = HBoxContainer.new()
	_chat_bar.add_theme_constant_override("separation", 8)
	_chat_bar.visible = (_tab == "chat")
	col.add_child(_chat_bar)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "输入消息……"
	_chat_input.max_length = 120
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.custom_minimum_size.y = 44
	_style_line_edit(_chat_input)
	_chat_bar.add_child(_chat_input)
	var send_btn := _btn(_chat_bar, "发送", func() -> void:
		if _busy or _chat_input.text.strip_edges().is_empty():
			return
		var text := _chat_input.text.strip_edges()
		_chat_input.text = ""
		action_requested.emit("chat_send", {"channel_kind": _chat_channel, "content": text}))
	send_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	send_btn.custom_minimum_size = Vector2(104, 44)
	send_btn.set_meta("primary_action", true)
	send_btn.queue_redraw()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	col.add_child(footer)
	_btn(footer, "刷新", func() -> void: action_requested.emit("refresh", {}))
	_btn(footer, "关闭社交", func() -> void: closed.emit())
	_refresh_tabs()


func _style_line_edit(field: LineEdit) -> void:
	field.add_theme_font_override("font", G.font_reg)
	field.add_theme_font_size_override("font_size", G.FS_SM)
	field.add_theme_color_override("font_color", G.PARCHMENT)
	field.add_theme_color_override("font_placeholder_color", Color("9c8d73"))
	field.add_theme_color_override("caret_color", G.GOLD_BRIGHT)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color("1b1613", 0.96)
	sb_n.border_color = Color("b8924d", 0.85)
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(4)
	sb_n.content_margin_left = 10
	sb_n.content_margin_top = 6
	sb_n.content_margin_right = 10
	sb_n.content_margin_bottom = 6
	var sb_f := sb_n.duplicate() as StyleBoxFlat
	sb_f.border_color = G.GOLD_BRIGHT
	sb_f.set_border_width_all(2)
	field.add_theme_stylebox_override("normal", sb_n)
	field.add_theme_stylebox_override("focus", sb_f)


func _refresh_tabs() -> void:
	for k in _tab_btns:
		var btn := _tab_btns[k] as Control
		if not is_instance_valid(btn):
			continue
		var active := String(k) == _tab
		btn.set_meta("primary_action", active)
		var lbl := btn.get_child(0) as Label
		if lbl != null:
			lbl.add_theme_color_override("font_color", G.GOLD_BRIGHT if active else Color("d8c8a8"))
		btn.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _btn(parent: Control, label_text: String, cb: Callable) -> Control:
	var b := G.ghost_button(label_text, 0, 44, G.FS_SM)
	b.custom_minimum_size.y = 44
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if _busy:
			return
		if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed) or ev.is_action_pressed("ui_accept"):
			b.accept_event()
			cb.call())
	parent.add_child(b)
	return b


func set_busy(busy: bool) -> void:
	_busy = busy


func show_message(msg: String) -> void:
	if _status != null:
		_status.text = msg


func present(social: Dictionary, msgs: Array, nearby: Array) -> void:
	_social = social.duplicate(true)
	_messages = msgs.duplicate(true)
	_entities = nearby.duplicate(true)
	_rebuild()


func _rebuild() -> void:
	_refresh_tabs()
	if _chat_bar != null:
		_chat_bar.visible = (_tab == "chat")
	if _list == null:
		return
	for ch in _list.get_children():
		ch.queue_free()
	var own_id := String(Online.selected_character.get("id", ""))
	match _tab:
		"party":
			var party: Variant = _social.get("party")
			if party is Dictionary:
				var info := party as Dictionary
				var leader_id := String(info.get("leader_id", ""))
				_status.text = "当前队伍（%d/4）" % (info.get("members", []) as Array).size()
				for m in info.get("members", []):
					if not m is Dictionary:
						continue
					var mem := m as Dictionary
					var mid := String(mem.get("id", ""))
					var tag := " [队长]" if mid == leader_id else ""
					var state := "已准备" if bool(mem.get("ready", false)) else ("在线" if bool(mem.get("online", false)) else "离线")
					var row := HBoxContainer.new()
					row.add_theme_constant_override("separation", 6)
					_list.add_child(row)
					var lbl := G.gold_label("%s%s · %s" % [String(mem.get("nickname", "旅人")), tag, state], G.FS_SM)
					lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					row.add_child(lbl)
					if own_id == leader_id and mid != own_id:
						_btn(row, "移交队长", func() -> void: action_requested.emit("party_leader", {"target_id": mid}))
						_btn(row, "请离", func() -> void: action_requested.emit("party_kick", {"target_id": mid}))
				var bar := HBoxContainer.new()
				bar.add_theme_constant_override("separation", 8)
				_list.add_child(bar)
				var is_ready := false
				for m in info.get("members", []):
					if m is Dictionary and String(m.get("id", "")) == own_id:
						is_ready = bool(m.get("ready", false))
				_btn(bar, "取消准备" if is_ready else "准备就绪", func() -> void: action_requested.emit("party_ready", {"ready": not is_ready}))
				_btn(bar, "离开队伍", func() -> void: action_requested.emit("party_leave", {}))
				if own_id == leader_id:
					var member_ids: Dictionary = {}
					for m in info.get("members", []):
						if m is Dictionary:
							member_ids[String(m.get("id", ""))] = true
					var invitable: Array = []
					for e in _entities:
						if e is Dictionary:
							var eid := String(e.get("id", ""))
							if not eid.is_empty() and not member_ids.has(eid):
								invitable.append(e)
					if not invitable.is_empty():
						_list.add_child(G.gold_label("附近可邀请旅人：", G.FS_SM, false))
						for e in invitable:
							var eid := String(e.get("id", ""))
							_btn(_list, "邀请 %s 入队" % String(e.get("nickname", "旅人")), func() -> void: action_requested.emit("party_invite", {"target_id": eid}))
			else:
				_status.text = "尚未加入队伍 · 可创建队伍或接受邀请"
				_btn(_list, "创建队伍", func() -> void: action_requested.emit("party_create", {}))
			for inv in _social.get("invitations", []):
				if not inv is Dictionary:
					continue
				var inv_d := inv as Dictionary
				var inv_id := String(inv_d.get("id", ""))
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				_list.add_child(row)
				var lbl := G.gold_label("来自 %s 的组队邀请" % String(inv_d.get("nickname", "旅人")), G.FS_SM)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(lbl)
				_btn(row, "接受", func() -> void: action_requested.emit("party_respond", {"id": inv_id, "accept": true}))
				_btn(row, "拒绝", func() -> void: action_requested.emit("party_respond", {"id": inv_id, "accept": false}))
		"friends":
			var friends: Array = _social.get("friends", [])
			var reqs: Array = _social.get("friend_requests", [])
			_status.text = "好友 %d 人 · 待处理申请 %d 条" % [friends.size(), reqs.size()]
			for r in reqs:
				if r is Dictionary and String(r.get("direction", "")) == "incoming":
					var rid := String(r.get("id", ""))
					var row := HBoxContainer.new()
					row.add_theme_constant_override("separation", 6)
					_list.add_child(row)
					var lbl := G.gold_label("%s 请求加为好友" % String(r.get("nickname", "旅人")), G.FS_SM)
					lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					row.add_child(lbl)
					_btn(row, "同意", func() -> void: action_requested.emit("friend_respond", {"id": rid, "accept": true}))
					_btn(row, "拒绝", func() -> void: action_requested.emit("friend_respond", {"id": rid, "accept": false}))
			for f in friends:
				if f is Dictionary:
					var fid := String(f.get("id", ""))
					var row := HBoxContainer.new()
					row.add_theme_constant_override("separation", 6)
					_list.add_child(row)
					var lbl := G.gold_label("%s · %s" % [String(f.get("nickname", "旅人")), "在线" if bool(f.get("online", false)) else "离线"], G.FS_SM)
					lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					row.add_child(lbl)
					_btn(row, "删除", func() -> void: action_requested.emit("friend_remove", {"target_id": fid}))
			for e in _entities:
				if e is Dictionary and String(e.get("id", "")) != own_id:
					var eid := String(e.get("id", ""))
					var row := HBoxContainer.new()
					row.add_theme_constant_override("separation", 6)
					_list.add_child(row)
					var lbl := G.gold_label("附近：%s" % String(e.get("nickname", "旅人")), G.FS_SM, false)
					lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					row.add_child(lbl)
					_btn(row, "加好友", func() -> void: action_requested.emit("friend_request", {"target_id": eid}))
					_btn(row, "屏蔽", func() -> void: action_requested.emit("block_add", {"target_id": eid}))
					_btn(row, "举报", func() -> void: action_requested.emit("report_send", {"target_id": eid}))
		"chat":
			var kind_bar := HBoxContainer.new()
			kind_bar.add_theme_constant_override("separation", 6)
			_list.add_child(kind_bar)
			var ch_names := {"room": "频道", "nearby": "附近", "party": "队伍"}
			for ch_k in [["room", "频道"], ["nearby", "附近"], ["party", "队伍"]]:
				var ck := String(ch_k[0])
				var ch_btn := _btn(kind_bar, String(ch_k[1]), func() -> void:
					_chat_channel = ck
					_rebuild())
				var is_cur := _chat_channel == ck
				ch_btn.set_meta("primary_action", is_cur)
				var clbl := ch_btn.get_child(0) as Label
				if clbl != null:
					clbl.add_theme_color_override("font_color", G.GOLD_BRIGHT if is_cur else Color("d8c8a8"))
				ch_btn.queue_redraw()
			_status.text = "当前聊天频道：%s · 共 %d 条可见消息" % [String(ch_names.get(_chat_channel, _chat_channel)), _messages.size()]
			for msg in _messages:
				if msg is Dictionary:
					var m := msg as Dictionary
					var mk := String(m.get("channel_kind", ""))
					var l := G.gold_label("[%s] %s：%s" % [String(ch_names.get(mk, mk)), String(m.get("sender_nickname", "旅人")), String(m.get("content", ""))], G.FS_SM, false)
					l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					_list.add_child(l)
		"blocks":
			var blocks: Array = _social.get("blocks", [])
			_status.text = "屏蔽列表（共 %d 个账号，已过滤其消息与组队邀请）" % blocks.size()
			for blk in blocks:
				if blk is Dictionary:
					var aid := String(blk.get("account_id", ""))
					var row := HBoxContainer.new()
					row.add_theme_constant_override("separation", 6)
					_list.add_child(row)
					var lbl := G.gold_label("已屏蔽：%s" % String(blk.get("nickname", aid.left(8))), G.FS_SM)
					lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					row.add_child(lbl)
					_btn(row, "解除屏蔽", func() -> void: action_requested.emit("block_remove", {"account_id": aid}))
