## P06 单机商路共用面板：城内市集与野外驿点使用同一套报价和结算。
class_name TradePanel
extends Control

const FrostContractPanelScript := preload("res://src/ui/FrostContractPanel.gd")

signal closed

var site_id := ""
var selected_good := "trade_grain"
var quantity := 1
var _body: Control
var _message := ""
var _contract_panel: Control = null


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked or _contract_panel != null:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_site(id: String) -> void:
	site_id = id
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rebuild()


func _button(parent: Control, label: String, at: Vector2, width: int,
		action: Callable) -> Control:
	var btn := G.gold_button(label, width, 44, G.FS_XS)
	btn.position = at
	btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			action.call())
	parent.add_child(btn)
	return btn


func _label(parent: Control, value: String, at: Vector2, width: float,
		color := Color("3a2a14"), font_size := G.FS_XS) -> void:
	var lab := G.text_label(value, font_size, color)
	lab.position = at
	lab.custom_minimum_size = Vector2(width, 0)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lab)


func _rebuild() -> void:
	if _body != null:
		_body.queue_free()
	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_body)
	G.veil(_body, 0.72, true)
	var height := maxf(800.0, get_viewport_rect().size.y)
	var top := (height - 680.0) * 0.5
	var cfg := TableCache.economy_config()
	var site := EconomyService.site(cfg, site_id)
	var banner := G.banner_box("商路 · %s" % String(site.get("name", "交易点")), 260, 48)
	banner.position = Vector2(110, top - 51)
	_body.add_child(banner)
	var paper := G.parchment_box(440, 680, 16.0)
	paper.position = Vector2(20, top)
	_body.add_child(paper)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(content)
	var state := G.economy_state()
	_label(content, "第 %d 日  ·  金 %d  ·  行囊 %d/%d" % [int(state.get("day", 1)),
		int(G.wallet.get("gold", 0)), EconomyService.carried_weight(cfg, G.items),
		int(cfg.get("carry_limit", 28))], Vector2(8, 4), 390, Color("6b4925"), G.FS_SM)
	_label(content, "货品", Vector2(8, 35), 76)
	_label(content, "买入", Vector2(153, 35), 65)
	_label(content, "卖出", Vector2(222, 35), 65)
	_label(content, "库存/收购", Vector2(286, 35), 100)
	var goods: Array = cfg.get("goods", [])
	for i in goods.size():
		var good: Dictionary = goods[i]
		var gid := String(good.get("id", ""))
		var q := G.economy_quote(site_id, gid)
		var y := 62.0 + i * 47.0
		var name := "%s%s" % ["◆" if gid == selected_good else "", String(good.get("name", gid))]
		var select_btn := _button(content, name, Vector2(8, y), 137, func():
			selected_good = gid
			_rebuild())
		var name_label := select_btn.get_child(0) as Label
		if name_label != null:
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var icon_tex := G.res_tex(String(good.get("icon", "")))
		if icon_tex != null:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.position = Vector2(8, 7)
			icon.size = Vector2(30, 30)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			select_btn.add_child(icon)
		_label(content, str(int(q.get("buy_gold", 0))), Vector2(155, y + 9), 58)
		_label(content, str(int(q.get("sell_gold", 0))), Vector2(225, y + 9), 58)
		_label(content, "%d / %d" % [int(q.get("stock_left", 0)),
			int(q.get("demand_left", 0))], Vector2(291, y + 9), 105)
	var quote := G.economy_quote(site_id, selected_good)
	var history: Array = quote.get("history", [])
	var points := []
	for day_row in history:
		points.append("%d日:%d" % [int((day_row as Dictionary).get("day", 0)),
			int((day_row as Dictionary).get("mid_gold", 0))])
	_label(content, "近五日中价  %s" % "  ".join(points), Vector2(8, 256), 394)
	_label(content, "持有 %d  ·  每件负担 %d  ·  运损 %d" % [int(quote.get("held", 0)),
		int(quote.get("weight", 1)), int(quote.get("haul_gold", 0))],
		Vector2(8, 281), 390, Color("6b4925"))
	_label(content, "数量", Vector2(8, 319), 48)
	for j in 3:
		var amount: int = [1, 2, 5][j]
		_button(content, "%d%s" % [amount, " ✓" if quantity == amount else ""],
			Vector2(52 + j * 68, 308), 62, func():
				quantity = amount
				_rebuild())
	_button(content, "买入", Vector2(260, 308), 74, func(): _trade("buy"))
	_button(content, "卖出", Vector2(338, 308), 74, func(): _trade("sell"))
	var factor := "日波动 %+d%%" % int(quote.get("day_wave_pct", 0))
	if int(quote.get("event_pct", 0)) != 0:
		factor += "  ·  %s %+d%%" % [String(quote.get("event_name", "")),
			int(quote.get("event_pct", 0))]
	_label(content, factor, Vector2(8, 358), 280, Color("6b4925"))
	if site_id in ["city_market","shenyuan_market","frost_market"]:
		_button(content,"三城合约",Vector2(300,356),112,func():_open_trade_contracts())
	_build_order_section(content)
	_button(content, "歇脚换日 · %d 金" % int(cfg.get("rest_gold", 22)),
		Vector2(218, 478), 194, func(): _rest())
	var job_x := 8.0
	for job_v in (cfg.get("jobs", []) as Array):
		var job := job_v as Dictionary
		if String(job.get("site_id", "")) != site_id:
			continue
		var jid := String(job.get("id", ""))
		var done := int((state.get("work", {}) as Dictionary).get(jid, 0)) >= int(state.get("day", 1))
		_button(content, "%s · %s" % [String(job.get("name", "")),
			"已做" if done else "+%d金" % int(job.get("gold", 0))],
			Vector2(job_x, 528), 196, func(): _work(jid))
		job_x += 204.0
	_label(content, _message, Vector2(8, 575), 395, Color("8a4a2a"))
	_button(content, "返回", Vector2(150, 612), 120, func(): close())


func _build_order_section(content: Control) -> void:
	if site_id in ["shenyuan_market", "frost_market"]:
		_build_frost_herb_order(content)
		return
	var order := G.economy_first_order()
	var status := String(order.get("status", "locked"))
	var status_name: String = {"locked": "未解锁", "available": "可接", "active": "运送中",
		"expired": "已过期", "done": "已完成"}.get(status, status)
	_label(content, "断碑坡运路  ·  %s" % status_name,
		Vector2(8, 391), 395, Color("8a4a2a"), G.FS_SM)
	if status == "locked":
		_label(content, "交付盐包后，可查看货单与运费", Vector2(8, 423), 395)
	else:
		_label(content, "需盐×2、铁料×1  ·  净报酬 %d 金 + %d 经验  ·  参考购货 %d 金" % [
			int(order.get("payout_gold", 0)), int(order.get("reward_exp", 0)),
			int(order.get("purchase_gold", 0))], Vector2(8, 423), 395)
	if status == "active":
		var bridge_note := "桥绳已稳，折让计入本批" if bool(order.get("bridge_aided", false)) \
			else "可在坡口步行系绳或骑乘牵引"
		_label(content, "第 %d 日前送达 · %s" % [int(order.get("deadline_day", 0)), bridge_note],
			Vector2(8, 451), 390, Color("6b4925"))
	elif status == "locked":
		_label(content, "替驿商送完盐包后可接取", Vector2(8, 451), 390, Color("6b4925"))
	else:
		_label(content, "路况决定运费；在接单时锁定净报酬", Vector2(8, 451), 390,
			Color("6b4925"))
	if status in ["available", "expired"] and site_id == String(order.get("origin_site", "")):
		_button(content, "接取运单", Vector2(8, 478), 130, func(): _order_accept())
	if status == "active" and site_id == String(order.get("destination_site", "")):
		_button(content, "交付货物", Vector2(8, 478), 130, func(): _order_deliver())


func _build_frost_herb_order(content: Control) -> void:
	var order := G.frost_herb_order()
	var status := String(order.get("status", "locked"))
	var status_name: String = {"locked": "未解锁", "available": "可接", "active": "运送中",
		"expired": "已过期", "done": "已交付", "abandoned": "已退单",
		"settled": "到期结清"}.get(status, status)
	_label(content, "霜关缺药 · %s" % status_name, Vector2(8, 391), 395,
		Color("8a4a2a"), G.FS_SM)
	if status == "locked":
		_label(content, "完成霜关双关定路后，港口开放这张药单。", Vector2(8, 423), 395)
		_label(content, "药草与谷物仍可照常在两地市集买卖。", Vector2(8, 451), 395)
		return
	_label(content, "药草 %d/3 · 谷物 %d/1 · 到手 %d 金 · 参考采购 %d 金" % [
		G.item_count("trade_herb"), G.item_count("trade_grain"),
		int(order.get("payout_gold", 0)), int(order.get("purchase_gold", 0))],
		Vector2(8, 423), 395)
	var route := String(order.get("route", ""))
	var route_line := "赤砂近路原价；旧驿绕路多付 18 金。"
	if status == "active":
		route_line = "第 %d 日前交付 · %s" % [int(order.get("deadline_day", 0)),
			"尚未过路口" if route.is_empty() else ("风沙近路" if route == "quick" else "旧驿绕路")]
	elif status == "expired":
		route_line = "已逾期；查看条款可延期一次或退单。"
	elif status == "done":
		route_line = "药箱已入霜关药架；下一游戏日可接新一批。"
	elif status == "abandoned":
		route_line = "本批保证金已结清；下一游戏日可重新签约。"
	elif status == "settled":
		route_line = "逾期自动结清；货物仍在行囊，明日可签新单。"
	_label(content, route_line, Vector2(8, 451), 395, Color("6b4925"))
	_button(content, "查看药单条款", Vector2(8, 478), 160, func(): _open_frost_contract())


func _open_trade_contracts() -> void:
	if _contract_panel != null: return
	_contract_panel = preload("res://src/ui/TradeContractsPanel.gd").new()
	add_child(_contract_panel)
	_contract_panel.open_contracts(site_id)
	_contract_panel.action_applied.connect(func(line:String):
		_message=line
		_rebuild())
	_contract_panel.closed.connect(func():_contract_panel=null)


func _open_frost_contract() -> void:
	if _contract_panel != null: return
	_contract_panel = FrostContractPanelScript.new()
	add_child(_contract_panel)
	_contract_panel.open_contract(site_id)
	_contract_panel.action_applied.connect(func(message: String):
		_message = message
		_rebuild())
	_contract_panel.closed.connect(func(): _contract_panel = null)


func _trade(action: String) -> void:
	var result := G.economy_trade(site_id, selected_good, action, quantity)
	_message = "%s %d 件，%d 金" % ["买入" if action == "buy" else "卖出", quantity,
		int(result.get("total_gold", 0))] if bool(result.get("ok", false)) else String(result.get("err", "交易失败"))
	_rebuild()


func _rest() -> void:
	var result := G.economy_rest(site_id)
	_message = "已到第 %d 日" % int(result.get("day", 0)) if bool(result.get("ok", false)) \
		else String(result.get("err", "歇脚失败"))
	_rebuild()


func _order_accept() -> void:
	var result := G.economy_first_order_accept()
	_message = "运单已接，第 %d 日截止" % int(result.get("deadline_day", 0)) \
		if bool(result.get("ok", false)) else String(result.get("err", "接单失败"))
	_rebuild()


func _order_deliver() -> void:
	var result := G.economy_first_order_deliver(site_id)
	_message = "运单完成：%d 金、%d 经验" % [int(result.get("gold", 0)),
		int(result.get("exp", 0))] if bool(result.get("ok", false)) \
		else String(result.get("err", "交单失败"))
	_rebuild()


func _work(job_id: String) -> void:
	var result := G.economy_work(site_id, job_id)
	_message = "工作完成：%d 金、%d 经验" % [int(result.get("gold", 0)),
		int(result.get("exp", 0))] if bool(result.get("ok", false)) \
		else String(result.get("err", "工作失败"))
	_rebuild()


func close() -> void:
	closed.emit()
	queue_free()
