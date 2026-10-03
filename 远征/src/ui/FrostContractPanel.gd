## 霜关药单条款：把保证金、运费、延期与退单损失放在确认动作之前。
class_name FrostContractPanel
extends Control

signal closed
signal action_applied(message: String)

var site_id := ""
var _message := ""
var _confirm_abandon := false
var _offset := Vector2.ZERO

func open_contract(id: String) -> void:
	site_id = id
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var viewport_size := get_viewport_rect().size
	_offset = Vector2((viewport_size.x - 480.0) * 0.5, (viewport_size.y - 800.0) * 0.5)
	G.veil(self, 0.84, true)
	var paper := G.parchment_box(440, 618, 18.0)
	paper.position = Vector2(20, 86) + _offset
	add_child(paper)
	var title := G.serif_label("霜 关 缺 药 · 运 单", G.FS_LG + 2, Color("6a4a1e"))
	title.position = Vector2(46, 118) + _offset
	title.custom_minimum_size = Vector2(388, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var info := G.frost_herb_order()
	var status := String(info.get("status", "locked"))
	var status_name: String = {"locked": "未开放", "available": "待签", "active": "运送中",
		"expired": "已逾期", "done": "已结清", "abandoned": "已退单",
		"settled": "到期结清"}.get(status, status)
	var today := int(info.get("day", 1))
	var deposit := int(info.get("deposit_held_gold", 0)) if status in ["active", "expired"] \
		else int(info.get("deposit_gold", 0))
	var refund := int(deposit * int(info.get("abandon_refund_pct", 0)) / 100.0)
	var extension_fee := int(info.get("extension_fee_gold", 0))
	var maximum_loss := deposit - refund + extension_fee
	var protected_payout := maxi(0, int(info.get("payout_gold", 0)) -
		int(info.get("protected_payout_discount_gold", 0)))
	var mode_name := "保价" if String(info.get("protection", "self")) == "insured" else "自担"
	var route := String(info.get("route", ""))
	var route_line := "未过路口；近路不加费，旧驿绕路加 18 金。" if route.is_empty() else \
		("已走风沙近路，本批运费固定。" if route == "quick" else "已走旧驿绕路，本批运费增加 18 金。")
	var deadline := "第 %d 日前交货" % int(info.get("deadline_day", 0)) \
		if status in ["active", "expired"] else "签约日起 %d 日内交货" % int(info.get("deadline_days", 4))
	var lines := [
		"第 %d 日 · %s%s" % [today, status_name,
			" · %s" % mode_name if status in ["active", "expired", "done", "abandoned", "settled"] else ""],
		"货物：药草 ×3、谷物 ×1  （现持 %d / %d）" % [G.item_count("trade_herb"), G.item_count("trade_grain")],
		"港口采购参考 %d 金；随当天行情变化。" % int(info.get("purchase_gold", 0)),
		"交货报酬 %d 金 · 运费 %d 金 · 参考净利 %d 金。" % [
			int(info.get("payout_gold", 0)), int(info.get("freight_gold", 0)),
			int(info.get("expected_profit_gold", 0))],
		"保证金 %d 金；交货时原额退回。" % deposit,
		deadline,
		route_line,
		"逾期可付 %d 金延期一次，补 %d 游戏日。" % [extension_fee, int(info.get("extension_days", 0))],
		"退单返 %d 金；最坏损 %d 金（不含货物买卖差价）。" % [refund, maximum_loss],
		"退单不扣未交货物。"
	]
	if status == "available":
		lines[8] = "自担退 %d 金、最多损 %d 金；保价退 %d 金、最多损 %d 金。" % [
			refund, maximum_loss, deposit, extension_fee]
		lines[9] = "保价报酬 %d 金（少 %d 金）；退单不扣货。" % [
			protected_payout, int(info.get("protected_payout_discount_gold", 0))]
	var detail := G.text_label("\n".join(PackedStringArray(lines)), G.FS_SM, Color("493724"))
	detail.position = Vector2(48, 185) + _offset
	detail.custom_minimum_size = Vector2(382, 336)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(detail)
	var message := G.text_label(_message, G.FS_SM, Color("8a4a2a"))
	message.position = Vector2(48, 526) + _offset
	message.custom_minimum_size = Vector2(382, 48)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)
	match status:
		"available":
			if site_id == String(info.get("origin_site", "")):
				_button("自担签约 · 押 %d" % deposit, Vector2(46, 585), 188, "accept_self")
				_button("保价签约 · 押 %d" % deposit, Vector2(250, 585), 184, "accept_insured")
		"active":
			if site_id == String(info.get("destination_site", "")):
				_button("交货 · 退押金", Vector2(46, 585), 188, "deliver")
			_button("确认退单" if _confirm_abandon else "放弃 · 退 %d 金" % refund,
				Vector2(250, 585), 184, "abandon")
		"expired":
			if not bool(info.get("extended", false)):
				_button("延期 · 付 %d 金" % extension_fee, Vector2(46, 585), 188, "extend")
			_button("确认退单" if _confirm_abandon else "退单 · 退 %d 金" % refund,
				Vector2(250, 585), 184, "abandon")
	_button("返回市集", Vector2(146, 646), 188, "close")

func _button(label: String, pos: Vector2, width: int, action: String) -> void:
	var button := G.gold_button(label, width, 42, G.FS_SM)
	button.position = pos + _offset
	button.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_act(action))
	add_child(button)

func _act(action: String) -> void:
	if action == "close":
		close()
		return
	if action == "abandon" and not _confirm_abandon:
		_confirm_abandon = true
		var info := G.frost_herb_order()
		_message = "再次点击才会退单；货物留在行囊，保证金退 %d 金。" % int(info.get("abandon_refund_gold", 0))
		_build()
		return
	_confirm_abandon = false
	var result: Dictionary
	match action:
		"accept_self", "accept_insured": result = G.frost_herb_accept(site_id, action == "accept_insured")
		"deliver": result = G.frost_herb_deliver(site_id)
		"extend": result = G.frost_herb_extend(site_id)
		"abandon": result = G.frost_herb_abandon(site_id)
		_: return
	_message = String(result.get("line", "办理成功")) if bool(result.get("ok", false)) \
		else String(result.get("err", "办理失败"))
	if bool(result.get("ok", false)):
		action_applied.emit(_message)
		close()
		return
	_build()

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
