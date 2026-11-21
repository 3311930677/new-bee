extends Control
## 在线市场、寄售行、交易收件箱与好友面对面交换界面。

signal closed
signal action_requested(kind: String, payload: Dictionary)

var _status: Label
var _tab := "market"
var _tab_btns: Dictionary = {}
var _summary: Dictionary = {}
var _orders: Array = []
var _payouts: Array = []
var _sessions: Array = []
var _friends: Array = []
var _pack_items: Array = []
var _self_char_id := ""
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
	col.add_child(G.gold_label("集市与玩家交易", G.FS_BIG))
	_status = G.gold_label("正在同步在线集市数据……", G.FS_SM, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for entry in [["market", "集市"], ["sell", "寄售"], ["payouts", "收件箱"], ["trade", "面对面"]]:
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
	_btn(footer, "刷新集市", func() -> void: action_requested.emit("refresh", {}))
	_btn(footer, "关闭集市", func() -> void: closed.emit())
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


func apply_state(summary: Dictionary, orders: Array, payouts: Array, sessions: Array, friends: Array, pack_items: Array, self_char_id: String) -> void:
	_summary = summary
	_orders = orders
	_payouts = payouts
	_sessions = sessions
	_friends = friends
	_pack_items = pack_items
	_self_char_id = self_char_id
	_rebuild()


func _rebuild() -> void:
	_refresh_tabs()
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	match _tab:
		"market":
			_build_market_tab()
		"sell":
			_build_sell_tab()
		"payouts":
			_build_payouts_tab()
		"trade":
			_build_trade_tab()


func _cat_name(c: String) -> String:
	return String({"commodity": "商货", "equipment": "装备", "material": "材料", "consumable": "消耗品"}.get(c, c))


func _payout_kind_name(k: String) -> String:
	return String({"sale_proceeds": "售出货款", "cancel_return": "撤单退回", "expired_return": "过期退回"}.get(k, k))


func _payout_status_name(s: String) -> String:
	return String({"pending": "待领取", "claimed": "已领取"}.get(s, s))


func _role_name(id: String) -> String:
	return String({"zs": "破军", "ck": "穿杨", "fs": "霜语", "fz": "晨星"}.get(id, id))


func _props_text(props: Dictionary) -> String:
	var key_names := {"atk": "攻击", "attack": "攻击", "def": "防御", "defense": "防御", "hp": "气血", "health": "气血", "spd": "速度", "speed": "速度", "crit": "暴击", "rarity": "品质"}
	var parts: Array[String] = []
	for k in props:
		var ks := String(k)
		var v: Variant = props[k]
		parts.append("%s %s" % [String(key_names.get(ks, ks)), str(v)])
	return " · ".join(parts)


func _build_market_tab() -> void:
	var header := _card("%s · 金币: %d" % [String(_summary.get("region_label", "昭元集市")), int(_summary.get("gold", 0))])
	var alerts := int(_summary.get("open_alerts", 0))
	var alert_note := " · 异常提示 %d" % alerts if alerts > 0 else ""
	_add_line(header, "集市税率：上架费 %d%% · 成交税 %d%% · 待领 %d%s" % [
		int(_summary.get("listing_fee_bps", 100)) / 100,
		int(_summary.get("tax_bps", 400)) / 100,
		int(_summary.get("pending_payouts", 0)),
		alert_note,
	], G.PARCHMENT)
	var ev := String(_summary.get("region_event", ""))
	if not ev.is_empty():
		_add_line(header, ev, G.PARCHMENT)

	var npc_goods: Variant = _summary.get("npc_goods", [])
	if npc_goods is Array and not (npc_goods as Array).is_empty():
		var npc_card := _card("NPC 保底行商 · 指导价带")
		for gv in npc_goods:
			if not gv is Dictionary:
				continue
			var g := gv as Dictionary
			var tpl := String(g.get("template_id", ""))
			var buy_p := int(g.get("npc_buy_price", 0))
			var sell_p := int(g.get("npc_sell_price", 0))
			var rmin := int(g.get("recent_min", 0))
			var rmax := int(g.get("recent_max", 0))
			var recent_str := "暂无成交" if (rmin == 0 and rmax == 0) else ("%d~%dg" % [rmin, rmax])
			_add_line(npc_card, "%s · 行商价 买 %dg / 收 %dg · 挂单 %d · 近成交 %s" % [
				String(g.get("name", tpl)), buy_p, sell_p, int(g.get("open_qty", 0)), recent_str,
			], G.PARCHMENT)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			npc_card.add_child(row)
			_btn(row, "向行商购 1 个 (%dg)" % buy_p, func() -> void:
				action_requested.emit("npc_buy", {"template_id": tpl, "quantity": 1}))

	var board := _card("玩家寄售挂单 (%d)" % _orders.size())
	if _orders.is_empty():
		_add_line(board, "当前暂无在售寄售挂单。", G.PARCHMENT)
	for ov in _orders:
		if not ov is Dictionary:
			continue
		var o := ov as Dictionary
		var st := String(o.get("status", ""))
		if st != "open" and st != "partial":
			continue
		var oid := String(o.get("order_id", ""))
		var unit_p := int(o.get("unit_price", 0))
		var rem := int(o.get("remaining_qty", 0))
		var mine := bool(o.get("mine", false))
		var line := "%s x%d · 单价 %dg · 卖家: %s [%s]" % [
			String(o.get("name", "")), rem, unit_p, String(o.get("seller_name", "")),
			"我的" if mine else _cat_name(String(o.get("category", ""))),
		]
		var props: Variant = o.get("item_properties", {})
		if props is Dictionary and not (props as Dictionary).is_empty():
			line += " · " + _props_text(props as Dictionary)
		_add_line(board, line, G.GOLD_BRIGHT if mine else G.PARCHMENT)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		board.add_child(btns)
		if mine:
			_btn(btns, "撤回挂单", func() -> void:
				action_requested.emit("cancel_order", {"order_id": oid}))
		else:
			_btn(btns, "购买 1 件 (%dg)" % unit_p, func() -> void:
				action_requested.emit("buy_order", {"order_id": oid, "quantity": 1}))
			if rem > 1:
				_btn(btns, "全买 x%d" % rem, func() -> void:
					action_requested.emit("buy_order", {"order_id": oid, "quantity": rem}))


func _build_sell_tab() -> void:
	var card := _card("可寄售行囊物品 (需未绑定且未装备)")
	var listed_any := false
	for iv in _pack_items:
		if not iv is Dictionary:
			continue
		var it := iv as Dictionary
		if bool(it.get("bound", true)) or not String(it.get("equipped_slot", "")).is_empty():
			continue
		if not bool(it.get("tradeable", false)):
			continue
		listed_any = true
		var uid := String(it.get("item_uid", ""))
		var qty := int(it.get("quantity", 0))
		var base_p := maxi(1, int(it.get("base_price", 15)))
		_add_line(card, "%s x%d · 参考价 %dg · %s" % [
			String(it.get("name", "")), qty, base_p, _cat_name(String(it.get("market_category", ""))),
		], G.PARCHMENT)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		card.add_child(btns)
		_btn(btns, "参考价挂单 1 件 (%dg)" % base_p, func() -> void:
			action_requested.emit("create_order", {"item_uid": uid, "quantity": 1, "unit_price": base_p}))
		if String(it.get("market_category", "")) == "commodity" and qty > 1:
			_btn(btns, "全部挂单 x%d" % qty, func() -> void:
				action_requested.emit("create_order", {"item_uid": uid, "quantity": qty, "unit_price": base_p}))
	if not listed_any:
		_add_line(card, "行囊里暂无未绑定且可寄售的材料或装备。可先在“集市”购买样本货物或挑战副本获得可交易材料。", G.PARCHMENT)


func _build_payouts_tab() -> void:
	var card := _card("交易邮件箱与退回物 (%d)" % _payouts.size())
	if _payouts.is_empty():
		_add_line(card, "当前暂无待领货款或撤单退回物品。", G.PARCHMENT)
		return
	for pv in _payouts:
		if not pv is Dictionary:
			continue
		var p := pv as Dictionary
		var pid := String(p.get("payout_id", ""))
		var st := String(p.get("status", ""))
		var gold := int(p.get("gold_amount", 0))
		var qty := int(p.get("quantity", 0))
		var desc := "%s · " % _payout_kind_name(String(p.get("kind", "")))
		if gold > 0:
			desc += "金币 +%dg " % gold
		if qty > 0:
			desc += "%s x%d " % [String(p.get("name", "")), qty]
		desc += "[%s]" % _payout_status_name(st)
		_add_line(card, desc, G.GOLD_BRIGHT if st == "pending" else G.PARCHMENT)
		if st == "pending":
			_btn(card, "领取附件", func() -> void:
				action_requested.emit("claim_payout", {"payout_id": pid}))


func _build_trade_tab() -> void:
	var active_session: Dictionary = {}
	for sv in _sessions:
		if sv is Dictionary and String((sv as Dictionary).get("status", "")) == "active":
			active_session = sv as Dictionary
			break
	if not active_session.is_empty():
		var tid := String(active_session.get("trade_id", ""))
		var rev := int(active_session.get("revision", 1))
		var init_id := String(active_session.get("initiator_id", ""))
		var is_init := init_id == _self_char_id
		var card := _card("面对面交换 (修订 #%d)" % rev)
		_add_line(card, "%s: 金币 %dg · %s | 放入 %d 项" % [
			String(active_session.get("initiator_name", "甲方")),
			int(active_session.get("initiator_gold", 0)),
			"已确认" if bool(active_session.get("initiator_confirmed", false)) else "未确认",
			(active_session.get("initiator_items", []) as Array).size(),
		], G.GOLD_BRIGHT if is_init else G.PARCHMENT)
		_add_line(card, "%s: 金币 %dg · %s | 放入 %d 项" % [
			String(active_session.get("partner_name", "乙方")),
			int(active_session.get("partner_gold", 0)),
			"已确认" if bool(active_session.get("partner_confirmed", false)) else "未确认",
			(active_session.get("partner_items", []) as Array).size(),
		], G.GOLD_BRIGHT if not is_init else G.PARCHMENT)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		card.add_child(btns)
		_btn(btns, "放 10g", func() -> void:
			action_requested.emit("trade_offer", {"trade_id": tid, "gold": 10}))
		var confirm_btn := _btn(btns, "确认交换", func() -> void:
			action_requested.emit("trade_confirm", {"trade_id": tid, "revision": rev}))
		confirm_btn.set_meta("primary_action", true)
		var confirm_lbl := confirm_btn.get_child(0) as Label
		if confirm_lbl != null:
			confirm_lbl.add_theme_color_override("font_color", G.GOLD_BRIGHT)
		confirm_btn.queue_redraw()
		_btn(btns, "取消交易", func() -> void:
			action_requested.emit("trade_cancel", {"trade_id": tid}))
		return

	var start_card := _card("向好友发起面对面交换")
	if _friends.is_empty():
		_add_line(start_card, "暂无好友，请先在“社交”面板添加好友并在同图发起交易。", G.PARCHMENT)
	for fv in _friends:
		if not fv is Dictionary:
			continue
		var f := fv as Dictionary
		var fid := String(f.get("character_id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		start_card.add_child(row)
		var lbl: Label = G.gold_label("%s（%s Lv.%d）" % [String(f.get("nickname", "")), _role_name(String(f.get("role_id", ""))), int(f.get("level", 1))], G.FS_SM, false)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		_btn(row, "发起交换", func() -> void:
			action_requested.emit("trade_start", {"target_character_id": fid}))


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
	button.custom_minimum_size = Vector2(0, 36)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if _busy:
			return
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or event.is_action_pressed("ui_accept"):
			button.accept_event()
			action.call())
	parent.add_child(button)
	return button
