class_name TradePanel
extends Control
## Three leaves of the merchant ledger: prices, cargo orders, and the wayside inn.
signal closed
const Field := preload("res://src/ui/FieldUI.gd")
const Craft := preload("res://src/ui/CraftUI.gd")
const FrostContractPanelScript := preload("res://src/ui/FrostContractPanel.gd")
const INK := Color("3d4135")
const MUTED := Color("7c715a")
const JADE := Color("31594f")
const RUST := Color("965739")
var site_id := ""
var selected_good := "trade_grain"
var quantity := 1
var _body: Control
var _message := ""
var _contract_panel: Control = null
var _page := 0
var _help := false

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked or _contract_panel != null: return
	if event.is_action_pressed("ui_cancel"):
		if _help: _help = false; _rebuild()
		else: close()
		get_viewport().set_input_as_handled()

func open_site(id: String) -> void:
	site_id = id
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rebuild()

func _text(parent: Control, words: String, at: Vector2, extent: Vector2,
		px := 16, ink := INK, bold := false) -> Label:
	var lab := Craft.label(words, at, extent, px, ink, bold)
	lab.custom_minimum_size = Vector2.ZERO
	parent.add_child(lab)
	return lab

func _button(parent: Control, words: String, at: Vector2, extent: Vector2,
		callback: Callable, primary := false, disabled := false) -> Field.Action:
	var btn := Field.action(words, at, extent, primary, not primary)
	btn.disabled = disabled
	btn.accent = JADE
	btn.caption.add_theme_font_size_override("font_size", 17)
	btn.caption.add_theme_color_override("font_color", Color("f5ead4") if primary else JADE)
	Craft.clean_label(btn.caption)
	btn.activated.connect(callback)
	parent.add_child(btn)
	return btn

func _card(parent: Control, at: Vector2, extent: Vector2) -> Control:
	var card := Panel.new()
	card.position = at
	card.size = extent
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d9d6bb",.42)
	style.border_color = Color("ac9c76",.5)
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel",style)
	parent.add_child(card)
	return card

func _icon(parent: Control, key: String, at: Vector2, extent := Vector2(36,36)) -> void:
	var tex := G.res_tex(key)
	if tex == null: return
	var icon := TextureRect.new()
	icon.texture = tex
	icon.position = at
	icon.size = extent
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)

func _rebuild() -> void:
	if is_instance_valid(_body):
		remove_child(_body)
		_body.queue_free()
	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	G.veil(_body,.72,true)
	var layout := Control.new()
	layout.name = "LedgerLayout"
	layout.size = Vector2(480,800)
	_body.add_child(layout)
	var cfg := TableCache.economy_config()
	var site := EconomyService.site(cfg,site_id)
	var title := _text(layout,"商路",Vector2(26,20),Vector2(350,42),32,Color("f1dfb6"),true)
	title.add_theme_font_override("font",G.font_art)
	_text(layout,String(site.get("name","交易点")),Vector2(28,64),Vector2(370,24),17,Color("d6c199"))
	_button(layout,"？",Vector2(410,30),Vector2(42,42),func(): _help = not _help; _rebuild())
	var paper := G.parchment_box(440,636,16.0)
	paper.position = Vector2(20,98)
	layout.add_child(paper)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	paper.add_child(stack)
	var state := G.economy_state()
	var summary := Control.new()
	summary.custom_minimum_size = Vector2(408,54)
	stack.add_child(summary)
	_text(summary,"第 %d 日" % int(state.get("day",1)),Vector2(0,0),Vector2(86,48),20,JADE,true)
	_text(summary,"钱囊",Vector2(122,0),Vector2(116,20),14,MUTED)
	_text(summary,"%d 金" % int(G.wallet.get("gold",0)),Vector2(122,20),Vector2(150,30),21,INK,true)
	_text(summary,"行囊",Vector2(308,0),Vector2(96,20),14,MUTED)
	_text(summary,"%d / %d" % [EconomyService.carried_weight(cfg,G.items),int(cfg.get("carry_limit",28))],Vector2(308,20),Vector2(96,30),21,INK,true)
	Field.line(summary,Vector2(0,53),408,Color("b9a57a",.45))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",8)
	stack.add_child(tabs)
	for i in 3:
		var index := i
		var btn := _button(tabs,["货市","运单","驿站"][i],Vector2.ZERO,Vector2(130,40),func():
			_page = index; _help = false; _message = ""; _rebuild(),i == _page)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var leaf := Control.new()
	leaf.name = "LedgerLeaf"
	leaf.custom_minimum_size = Vector2(408,438)
	stack.add_child(leaf)
	if _help: _build_help(leaf,cfg)
	else:
		match _page:
			0: _build_market(leaf,cfg)
			1: _build_orders(leaf)
			2: _build_inn(leaf,cfg,state)
	var notice := Label.new()
	notice.text = _message
	notice.custom_minimum_size = Vector2(408,40)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_override("font",G.font_reg)
	notice.add_theme_font_size_override("font_size",15)
	notice.add_theme_color_override("font_color",RUST)
	Craft.clean_label(notice)
	stack.add_child(notice)
	_button(layout,"返回",Vector2(160,748),Vector2(160,40),close)
	preload("res://src/ui/UiSafeArea.gd").fit_page(_body,G.ui_safe_rect(self))

func _build_market(parent: Control, cfg: Dictionary) -> void:
	for column in [["货品",8,136],["买入",156,64],["卖出",230,64],["库存 / 收购",300,108]]:
		_text(parent,column[0],Vector2(column[1],0),Vector2(column[2],24),14,MUTED)
	var goods: Array = cfg.get("goods",[])
	for i in goods.size():
		var good: Dictionary = goods[i]
		var gid := String(good.get("id",""))
		var quote := G.economy_quote(site_id,gid)
		var row := _button(parent,"",Vector2(0,28+i*54),Vector2(408,50),func(): selected_good = gid; _rebuild())
		row.selected = gid == selected_good
		row.caption.hide()
		_icon(row,String(good.get("icon","")),Vector2(10,7))
		_text(row,String(good.get("name","货品")),Vector2(56,0),Vector2(86,50),18,JADE if row.selected else INK,true)
		_text(row,str(int(quote.get("buy_gold",0))),Vector2(156,0),Vector2(64,50),20,INK)
		_text(row,str(int(quote.get("sell_gold",0))),Vector2(230,0),Vector2(64,50),20,INK)
		_text(row,"%d / %d" % [int(quote.get("stock_left",0)),int(quote.get("demand_left",0))],Vector2(312,0),Vector2(96,50),17,MUTED)
	var quote := G.economy_quote(site_id,selected_good)
	var detail := _card(parent,Vector2(0,252),Vector2(408,180))
	_text(detail,"%s · 持有 %d" % [G.item_name(selected_good),int(quote.get("held",0))],Vector2(14,8),Vector2(250,28),17,JADE,true)
	_text(detail,"行情 %+d%%" % int(quote.get("day_wave_pct",0)),Vector2(278,8),Vector2(118,28),14,MUTED)
	var chart := PriceHistory.new()
	chart.position = Vector2(16,42)
	chart.size = Vector2(376,62)
	chart.history = quote.get("history",[])
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(chart)
	_text(detail,"数量",Vector2(14,120),Vector2(46,44),14,MUTED)
	for i in 3:
		var amount: int = [1,2,5][i]
		var btn := _button(detail,str(amount),Vector2(62+i*42,120),Vector2(36,44),func(): quantity = amount; _rebuild())
		btn.selected = quantity == amount
		btn.caption.position.x = 0
		btn.caption.size.x = 36
	_button(detail,"买入",Vector2(202,120),Vector2(90,44),func(): _trade("buy"),true)
	_button(detail,"卖出",Vector2(300,120),Vector2(94,44),func(): _trade("sell"))

func _status(order: Dictionary) -> String:
	return String({"locked":"未解锁","available":"可接取","active":"运送中","expired":"已逾期","done":"已完成","abandoned":"已退单","settled":"已结清"}.get(String(order.get("status","locked")),"待查看"))

func _build_orders(parent: Control) -> void:
	var frost := site_id in ["shenyuan_market","frost_market"]
	var order := G.frost_herb_order() if frost else G.economy_first_order()
	var status := String(order.get("status","locked"))
	var card := _card(parent,Vector2(0,6),Vector2(408,326))
	_text(card,"霜关缺药" if frost else "断碑坡运路",Vector2(18,16),Vector2(270,32),23,INK,true)
	_text(card,_status(order),Vector2(304,20),Vector2(86,26),16,RUST)
	_text(card,"沉渊港  →  霜关" if frost else "昭元市集  →  断碑营地",Vector2(18,56),Vector2(370,28),16,MUTED)
	Field.line(card,Vector2(18,96),372,Color("b9a57a",.5))
	if status == "locked":
		_text(card,"完成双关定路后开放" if frost else "送完驿商盐包后开放",Vector2(18,122),Vector2(370,42),19,JADE)
		_text(card,"可先在货市备货",Vector2(18,176),Vector2(370,32),16,MUTED)
	else:
		var cargo: Dictionary = TableCache.economy_config().get("frost_herb_order" if frost else "first_order",{}).get("cargo",{})
		var x := 18.0
		for gid in cargo:
			_text(card,"%s  %d / %d" % [G.item_name(String(gid)),G.item_count(String(gid)),int(cargo[gid])],Vector2(x,112),Vector2(182,32),18,JADE)
			x += 188
		_text(card,"净报酬",Vector2(18,168),Vector2(130,24),14,MUTED)
		_text(card,"%d 金" % int(order.get("payout_gold",0)),Vector2(18,198),Vector2(204,40),30,RUST,true)
		_text(card,"经验 +%d" % int(order.get("reward_exp",42 if frost else 35)),Vector2(260,204),Vector2(130,32),17,MUTED)
		var note := "采购约 %d 金" % int(order.get("purchase_gold",0))
		if status == "active": note = "第 %d 日前送达" % int(order.get("deadline_day",0))
		if status == "expired": note = "运单逾期，可查看条款处理" if frost else "运单逾期，可在昭元市集重接"
		_text(card,note,Vector2(18,252),Vector2(360,26),16,MUTED)
	var button_line := "查看药单条款" if frost else "查看运路规则"
	var callback: Callable = _open_frost_contract if frost else func(): _help = true; _rebuild()
	var primary := frost
	if not frost:
		if status in ["available","expired"] and site_id == String(order.get("origin_site","")):
			button_line = "接取运单"; callback = _order_accept; primary = true
		elif status == "active" and site_id == String(order.get("destination_site","")):
			button_line = "交付货物"; callback = _order_deliver; primary = true
	_button(parent,button_line,Vector2(0,350),Vector2(408,44),callback,primary)
	if site_id in ["city_market","shenyuan_market","frost_market"]:
		_button(parent,"三城合约  ›",Vector2(0,402),Vector2(408,36),_open_trade_contracts)
	elif status == "active":
		_text(parent,"在断碑营地交货",Vector2(0,402),Vector2(408,30),15,MUTED)

func _build_inn(parent: Control, cfg: Dictionary, state: Dictionary) -> void:
	var rest := _card(parent,Vector2(0,8),Vector2(408,152))
	_text(rest,"驿站歇脚",Vector2(18,12),Vector2(280,32),23,INK,true)
	_text(rest,"休息一夜，迎来新行情",Vector2(18,54),Vector2(370,28),16,MUTED)
	_button(rest,"歇脚换日 · %d 金" % int(cfg.get("rest_gold",22)),Vector2(18,96),Vector2(372,44),_rest,true)
	_text(parent,"今日差事",Vector2(0,178),Vector2(408,30),20,JADE,true)
	var y := 222.0
	for value in cfg.get("jobs",[]):
		var job: Dictionary = value
		if String(job.get("site_id","")) != site_id: continue
		var jid := String(job.get("id",""))
		var done := int((state.get("work",{}) as Dictionary).get(jid,0)) >= int(state.get("day",1))
		var card := _card(parent,Vector2(0,y),Vector2(408,88))
		_text(card,String(job.get("name","差事")),Vector2(16,10),Vector2(236,30),20,INK,true)
		_text(card,"%d 金 · %d 经验" % [int(job.get("gold",0)),int(job.get("exp",0))],Vector2(16,48),Vector2(250,26),16,MUTED)
		_button(card,"已完成" if done else "帮忙",Vector2(284,22),Vector2(108,44),func(): _work(jid),not done,done)
		y += 100

func _build_help(parent: Control, cfg: Dictionary) -> void:
	_text(parent,["货市规则","运单规则","驿站规则"][_page],Vector2(0,8),Vector2(408,36),23,JADE,true)
	var paragraphs: Array = []
	match _page:
		0:
			var quote := G.economy_quote(site_id,selected_good)
			paragraphs = ["买入价是付给商人的单价；卖出价是你收到的单价，已计入运损。", "库存与收购额度每日有限。换日后刷新，切换地点不会重置。", "%s：每件负重 %d，运损 %d 金。行囊上限 %d。" % [G.item_name(selected_good),int(quote.get("weight",1)),int(quote.get("haul_gold",0)),int(cfg.get("carry_limit",28))], "折线为近五日中价；成交以当前买入、卖出报价为准。"]
			if int(quote.get("event_pct",0)) != 0: paragraphs.append("路况：%s（%+d%%）。" % [String(quote.get("event_name","")),int(quote.get("event_pct",0))])
		1: paragraphs = ["先在始发地接单，再备齐实物，到目的地交货。", "净报酬在接单时锁定，购货费用另付。截止日按游戏日计算。", "断碑坡：盐 ×2、铁料 ×1。桥绳加固可抵减本批运费。", "霜关药单：药草 ×3、谷物 ×1。保证金、路线、延期与退单规则见药单条款。"]
		2: paragraphs = ["歇脚花费 %d 金，推进一个游戏日。" % int(cfg.get("rest_gold",22)), "换日会刷新行情、库存与收购额度，也会推进运单期限。", "每份差事每天只能完成一次，奖励直接到账。"]
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0,58)
	scroll.size = Vector2(408,318)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 388
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",18)
	scroll.add_child(list)
	for words in paragraphs:
		var lab := Craft.label(words,Vector2.ZERO,Vector2(388,28),17,INK)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(lab)
	_button(parent,"知道了",Vector2(0,390),Vector2(408,44),func(): _help = false; _rebuild())

func _open_trade_contracts() -> void:
	if _contract_panel != null: return
	_contract_panel = preload("res://src/ui/TradeContractsPanel.gd").new()
	add_child(_contract_panel)
	_contract_panel.open_contracts(site_id)
	_contract_panel.action_applied.connect(func(line: String): _message = line; _rebuild())
	_contract_panel.closed.connect(func(): _contract_panel = null)

func _open_frost_contract() -> void:
	if _contract_panel != null: return
	_contract_panel = FrostContractPanelScript.new()
	add_child(_contract_panel)
	_contract_panel.open_contract(site_id)
	_contract_panel.action_applied.connect(func(line: String): _message = line; _rebuild())
	_contract_panel.closed.connect(func(): _contract_panel = null)

func _trade(action: String) -> void:
	var result := G.economy_trade(site_id,selected_good,action,quantity)
	_message = "%s %s ×%d · %d 金" % ["买入" if action == "buy" else "卖出",G.item_name(selected_good),quantity,int(result.get("total_gold",0))] if bool(result.get("ok",false)) else String(result.get("err","交易失败"))
	_rebuild()

func _rest() -> void:
	var result := G.economy_rest(site_id)
	_message = "已到第 %d 日" % int(result.get("day",0)) if bool(result.get("ok",false)) else String(result.get("err","歇脚失败"))
	_rebuild()

func _order_accept() -> void:
	var result := G.economy_first_order_accept()
	_message = "运单已接，第 %d 日截止" % int(result.get("deadline_day",0)) if bool(result.get("ok",false)) else String(result.get("err","接单失败"))
	_rebuild()

func _order_deliver() -> void:
	var result := G.economy_first_order_deliver(site_id)
	_message = "运单完成：%d 金、%d 经验" % [int(result.get("gold",0)),int(result.get("exp",0))] if bool(result.get("ok",false)) else String(result.get("err","交单失败"))
	_rebuild()

func _work(job_id: String) -> void:
	var result := G.economy_work(site_id,job_id)
	_message = "差事完成：%d 金、%d 经验" % [int(result.get("gold",0)),int(result.get("exp",0))] if bool(result.get("ok",false)) else String(result.get("err","差事失败"))
	_rebuild()

func close() -> void:
	closed.emit()
	queue_free()

class PriceHistory extends Control:
	var history: Array = []
	func _draw() -> void:
		if history.is_empty(): return
		var low := 1000000.0
		var high := 0.0
		for value in history:
			low = minf(low,float(value.get("mid_gold",0)))
			high = maxf(high,float(value.get("mid_gold",0)))
		var points := PackedVector2Array()
		for i in history.size():
			var x := 14.0+i*(size.x-28)/maxi(1,history.size()-1)
			var y := 31.0-(float(history[i].get("mid_gold",0))-low)/maxf(1,high-low)*22.0
			points.append(Vector2(x,y))
			draw_string(G.font_reg,Vector2(x-10,y-5),str(int(history[i].get("mid_gold",0))),HORIZONTAL_ALIGNMENT_LEFT,-1,12,JADE)
			draw_string(G.font_reg,Vector2(x-12,56),"%d日" % int(history[i].get("day",0)),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
		draw_line(Vector2(0,35),Vector2(size.x,35),Color("b9a57a",.5))
		if points.size()>1: draw_polyline(points,JADE,1.5,true)
		for point in points: draw_circle(point,2.5,JADE)
