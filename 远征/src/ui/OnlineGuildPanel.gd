extends Control
## L4 帮派总览、成员权限、只收不可交易建材的仓库与审计日志、共同据点建设与招募。

signal closed
signal action_requested(kind: String, payload: Dictionary)

var _status: Label
var _tab := "overview"
var _tab_btns: Dictionary = {}
var _state: Dictionary = {}
var _pack_items: Array = []
var _friends: Array = []
var _self_char_id := ""
var _name_input: LineEdit
var _list: VBoxContainer
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
	col.add_child(G.gold_label("帮派与共同据点", G.FS_BIG))
	_status = G.gold_label("正在同步帮派与据点信息……", G.FS_SM, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for entry in [["overview", "总览"], ["members", "成员"], ["warehouse", "仓库日志"], ["build", "据点招募"]]:
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

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	col.add_child(footer)
	_btn(footer, "刷新帮派", func() -> void: action_requested.emit("refresh", {}))
	_btn(footer, "关闭帮派", func() -> void: closed.emit())
	_refresh_tabs()


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


func _style_line_edit(field: LineEdit) -> void:
	field.custom_minimum_size.y = 42
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


func _unhandled_input(event: InputEvent) -> void:
	if visible and not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func set_busy(flag: bool) -> void:
	_busy = flag


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func set_tab(tab_id: String) -> void:
	_tab = tab_id
	_rebuild()


func apply_state(state: Dictionary, pack_items: Array, friends: Array, self_char_id: String) -> void:
	_state = state
	_pack_items = pack_items
	_friends = friends
	_self_char_id = self_char_id
	_rebuild()


func _rebuild() -> void:
	_refresh_tabs()
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var guild_val: Variant = _state.get("guild")
	if not guild_val is Dictionary:
		_build_unguilded()
		return
	var g := guild_val as Dictionary
	match _tab:
		"overview":
			_build_overview(g)
		"members":
			_build_members(g)
		"warehouse":
			_build_warehouse(g)
		"build":
			_build_stronghold(g)


func _role_name(id: String) -> String:
	return String({"zs": "破军", "ck": "穿杨", "fs": "霜语", "fz": "晨星"}.get(id, id))


func _rank_name(rk: String) -> String:
	return String({"leader": "会长", "officer": "执事", "member": "成员"}.get(rk, rk))


func _decor_name(d: String) -> String:
	return String({"oak_banner": "橡木战旗", "gold_banner": "金穗战旗", "stele_crest": "界碑徽石"}.get(d, d))


func _audit_action_name(act: String) -> String:
	return String({
		"create": "创立帮派",
		"join": "加入帮派",
		"leave": "退出帮派",
		"permission": "调整权限",
		"decorate": "更新据点装饰",
		"warehouse_deposit": "存入仓库",
		"warehouse_withdraw": "取出仓库",
		"weekly_task": "提交周任务",
		"transfer_leader": "移交会长",
		"claim_leadership": "接任会长",
	}.get(act, act))


func _mat_name(tpl: String) -> String:
	return String({"mat_guild_timber": "帮派筑木", "mat_stele_stone": "界碑石料"}.get(tpl, tpl))


func _build_unguilded() -> void:
	var card := _card("创立或加入帮派（不加帮派仍可正常成长）")
	_add_line(card, "创帮要求：完成第 II 幕（或 Lv.3+）并消耗 %d 金币。初始上限 30 人，协作周任务可扩至 60 人；不提供压倒单人战力的攻防数值加成。" % int(_state.get("create_cost_gold", 50)), G.PARCHMENT)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "输入帮派名称（2-16字）"
	_name_input.text = "星火远征帮"
	_style_line_edit(_name_input)
	card.add_child(_name_input)
	_btn(card, "创立帮派", func() -> void:
		action_requested.emit("create", {"name": _name_input.text.strip_edges(), "motto": "同行远征，共守界碑"}))

	var invs: Array = _state.get("invites", [])
	var inv_card := _card("收到的帮派邀请 (%d)" % invs.size())
	if invs.is_empty():
		_add_line(inv_card, "当前暂无待处理的帮派邀请。", G.PARCHMENT)
	for iv in invs:
		if not iv is Dictionary:
			continue
		var inv := iv as Dictionary
		var iid := String(inv.get("id", ""))
		_add_line(inv_card, "%s（邀请人：%s）" % [String(inv.get("guild_name", "")), String(inv.get("inviter", ""))], G.GOLD_BRIGHT)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		inv_card.add_child(row)
		_btn(row, "接受加入", func() -> void: action_requested.emit("respond_invite", {"id": iid, "accept": true}))
		_btn(row, "婉拒", func() -> void: action_requested.emit("respond_invite", {"id": iid, "accept": false}))


func _build_overview(g: Dictionary) -> void:
	var card := _card("%s · 成员 %d / %d" % [String(g.get("name", "")), int(g.get("member_count", 0)), int(g.get("member_cap", 30))])
	_add_line(card, "公告：%s" % String(g.get("announcement", "")), G.GOLD_BRIGHT)
	_add_line(card, "共同据点 Lv.%d · 战旗：%s · 周协作分：%d" % [
		int(g.get("decor_level", 1)), _decor_name(String(g.get("decor_banner", "oak_banner"))), int(g.get("weekly_coop_points", 0)),
	], G.PARCHMENT)
	if bool(g.get("can_claim_inactive", false)):
		_btn(card, "原会长久未上线 · 接任会长", func() -> void: action_requested.emit("claim_inactive", {}))
	_btn(card, "退出帮派（保留所有个人物品，有短冷却）", func() -> void: action_requested.emit("leave", {}))


func _build_members(g: Dictionary) -> void:
	var is_leader := String(g.get("leader_character_id", "")) == _self_char_id
	var card := _card("帮派名册与权限 (%d)" % (g.get("members", []) as Array).size())
	for mv in g.get("members", []):
		if not mv is Dictionary:
			continue
		var m := mv as Dictionary
		var cid := String(m.get("character_id", ""))
		var rk := _rank_name(String(m.get("rank", "member")))
		_add_line(card, "%s（%s Lv.%d）[%s] 招:%s 仓:%s 宣:%s · 贡献 %d" % [
			String(m.get("nickname", "")), _role_name(String(m.get("role_id", ""))), int(m.get("level", 1)), rk,
			"✓" if bool(m.get("can_invite", false)) else "×",
			"✓" if bool(m.get("can_manage_warehouse", false)) else "×",
			"✓" if bool(m.get("can_edit_announcement", false)) else "×",
			int(m.get("contribution_points", 0)),
		], G.GOLD_BRIGHT if cid == _self_char_id else G.PARCHMENT)
		if is_leader and cid != _self_char_id:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			card.add_child(row)
			_btn(row, "升为执事并授仓库权", func() -> void:
				action_requested.emit("permission", {
					"target_character_id": cid, "rank": "officer",
					"can_invite": true, "can_manage_warehouse": true, "can_edit_announcement": true,
				}))
			_btn(row, "移交会长", func() -> void: action_requested.emit("leader", {"target_character_id": cid}))


func _build_warehouse(g: Dictionary) -> void:
	var wh_card := _card("帮派仓库（仅收不可交易协作建筑材料）")
	var wh: Array = g.get("warehouse", [])
	if wh.is_empty():
		_add_line(wh_card, "仓库暂无建材，可通过赤砂矿脉 / 界碑深处副本获得。", G.PARCHMENT)
	for wv in wh:
		if not wv is Dictionary:
			continue
		var w := wv as Dictionary
		var tpl := String(w.get("template_id", ""))
		var qty := int(w.get("quantity", 0))
		_add_line(wh_card, "%s：%d 件" % [String(w.get("name", tpl)), qty], G.GOLD_BRIGHT)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		wh_card.add_child(row)
		_btn(row, "用于共同据点周任务 (-1)", func() -> void: action_requested.emit("task_contribute", {"template_id": tpl, "quantity": 1}))
		_btn(row, "授权取出 (-1)", func() -> void: action_requested.emit("withdraw", {"template_id": tpl, "quantity": 1}))

	var pack_card := _card("存入个人不可交易建材")
	var any_mat := false
	for iv in _pack_items:
		if not iv is Dictionary:
			continue
		var it := iv as Dictionary
		if not bool(it.get("guild_building", false)) or bool(it.get("tradeable", false)):
			continue
		any_mat = true
		var uid := String(it.get("item_uid", ""))
		_add_line(pack_card, "%s x%d" % [String(it.get("name", "")), int(it.get("quantity", 0))], G.PARCHMENT)
		_btn(pack_card, "存入 1 份进帮派仓库", func() -> void: action_requested.emit("deposit", {"item_uid": uid, "quantity": 1}))
	if not any_mat:
		_add_line(pack_card, "行囊里暂无帮派筑木或界碑石料。", G.PARCHMENT)

	var log_card := _card("不可篡改存取与权限审计 (%d)" % (g.get("audit_logs", []) as Array).size())
	for lv in g.get("audit_logs", []):
		if not lv is Dictionary:
			continue
		var l := lv as Dictionary
		var act_label := _audit_action_name(String(l.get("action", "")))
		var mat := _mat_name(String(l.get("template_id", "")))
		var qty_str := (" ×%d" % int(l.get("quantity", 0))) if int(l.get("quantity", 0)) > 0 else ""
		var detail := (" " + mat + qty_str) if not mat.is_empty() else qty_str
		_add_line(log_card, "[#%d] %s · %s%s" % [
			int(l.get("id", 0)), String(l.get("actor", "")), act_label, detail,
		], G.PARCHMENT)


func _build_stronghold(_g: Dictionary) -> void:
	var deco := _card("共同据点装饰与公告")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	deco.add_child(row)
	_btn(row, "换挂金穗战旗", func() -> void:
		action_requested.emit("announcement", {"announcement": "本周协力冲刺赤砂矿脉与沉渊盐鳞王！", "decor_banner": "gold_banner"}))
	_btn(row, "立界碑徽石", func() -> void:
		action_requested.emit("announcement", {"announcement": "据点碑台新立，欢迎好友并肩入伙！", "decor_monument": "stele_crest"}))

	var rec := _card("招募在线好友入会")
	if _friends.is_empty():
		_add_line(rec, "暂无好友可邀，可先在“社交”面板结识旅伴。", G.PARCHMENT)
	for fv in _friends:
		if not fv is Dictionary:
			continue
		var f := fv as Dictionary
		var fid := String(f.get("character_id", ""))
		_btn(rec, "邀请 %s 加入帮派" % String(f.get("nickname", "")), func() -> void: action_requested.emit("invite", {"target_character_id": fid}))


func _card(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.09, 0.07, 0.92)
	sb.border_color = Color(0.76, 0.62, 0.34, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	_list.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(G.gold_label(title, G.FS_MD))
	return box


func _add_line(parent: Control, text: String, color: Color) -> void:
	var lbl: Label = G.gold_label(text, G.FS_SM, false, color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)


func _btn(parent: Control, text: String, action: Callable) -> Control:
	var button: Control = G.ghost_button(text, 0, 38, G.FS_SM)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 38)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _busy:
			return
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept"):
			button.accept_event()
			action.call())
	parent.add_child(button)
	return button
