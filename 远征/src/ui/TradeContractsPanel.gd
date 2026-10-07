extends Control
signal closed
signal action_applied(line: String)
const Contracts:=preload("res://src/world/TradeContracts.gd")
const Style := preload("res://src/ui/LedgerStyle.gd")
var site_id:=""
var list:VBoxContainer
var message:Label
var confirm:=""
func open_contracts(site:String) -> void:
	site_id=site
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	G.veil(self,.86)
	var paper := Style.panel(Vector2(20,56),Vector2(440,688))
	add_child(paper)
	var title:=G.serif_label("三城保价与延期合约",G.FS_LG,G.TEXT_DARK)
	title.position=Vector2(44,80)
	add_child(title)
	message=Style.text("同时最多两张未结单；只看游戏日，离线不会过期。",15,Style.MUTED)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.size=Vector2(392,60)
	message.position=Vector2(44,125)
	add_child(message)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(40,192)
	scroll.size=Vector2(400,466)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",14)
	scroll.add_child(list)
	var back:=G.ghost_button("返回市集",220,44)
	Style.apply_button(back,"quiet")
	back.position=Vector2(130,683)
	back.gui_input.connect(func(e:InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
			closed.emit()
			queue_free())
	add_child(back)
	refresh()
func text(parent:Node,line:String,big:=false) -> void:
	var label:=Style.text(line,18 if big else 15,Style.JADE if big else Style.INK)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x=348
	parent.add_child(label)
func button(parent:Node,line:String,callback:Callable) -> void:
	var control:=G.gold_button(line,172,44,G.FS_SM)
	Style.apply_button(control,"danger" if line == "退单" else "primary")
	control.gui_input.connect(func(e:InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:callback.call())
	parent.add_child(control)
func result(value:Dictionary) -> void:
	message.text=String(value.line)
	if bool(value.ok):action_applied.emit(String(value.line))
	confirm=""
	refresh()
func cancel(id:String) -> void:
	if confirm!=id:
		confirm=id
		message.text="退单不扣货物：按条款返还押金。再次点击该单退单按钮确认。"
		return
	result(Contracts.action(G,id,"cancel",site_id))
func refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	text(list,"第%d游戏日 · 未结%d/2 · 金币%d"%[Contracts.day(G),Contracts.active_count(G),int(G.wallet.gold)],true)
	for definition in Contracts.templates():
		if String(definition.origin)!=site_id:continue
		var id:=String(definition.id)+"|"+str(Contracts.day(G))
		if Contracts.state(G).has(id):continue
		var card := Style.list_card(list)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation",8)
		card.add_child(heading)
		var name_label := Style.text(String(definition.name),18,Style.JADE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(name_label)
		heading.add_child(Style.badge("可签约" if G.story_step_done(String(definition.unlock)) else "未开放",
			"available" if G.story_step_done(String(definition.unlock)) else "locked"))
		if not G.story_step_done(String(definition.unlock)):
			text(card,"沿归路主线抵达后开放，不参与合约也能通关。")
			continue
		var insured:=Contracts.quote(G,String(definition.id),"insured")
		var own:=Contracts.quote(G,String(definition.id),"self")
		var cargo:Array=[]
		for good in definition.cargo:cargo.append(G.item_name(String(good))+"×"+str(int(definition.cargo[good])))
		text(card,"货物："+"、".join(cargo)+"；交到"+String(EconomyService.site(TableCache.economy_config(),String(definition.destination)).name))
		text(card,"签约参照货款%d金，押金%d金，第%d日内交付。签约不扣货，交货时一次扣除。"%[int(own.reference),int(own.deposit),int(own.due)])
		text(card,"保价：固定利差25金，保价费8金在退押中扣，退押52金。自担：利差30–55金，退押60金；路点核准可免25金路阻扣款。")
		text(card,"最多损失：保价8金、自担30金；一次延期另付12金，补2日。长期逾期自动退押且不扣货。含延期的最大损失仍小于60金押金。")
		text(card,"补货可正常买入；路点："+String(definition.route_name)+"。不会查看或修改现实日期。")
		var actions:=HBoxContainer.new()
		card.add_child(actions)
		button(actions,"保价签约 · 押60",func():result(Contracts.sign(G,String(definition.id),"insured",site_id)))
		button(actions,"自担签约 · 押60",func():result(Contracts.sign(G,String(definition.id),"self",site_id)))
	for id in Contracts.state(G):
		var record:Dictionary=Contracts.state(G)[id]
		if String(record.status)!="active":continue
		var definition:=Contracts.row(String(record.template))
		var card := Style.list_card(list)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation",8)
		card.add_child(heading)
		var name_label := Style.text(String(definition.name)+" · "+("保价" if record.mode=="insured" else "自担"),18,Style.JADE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(name_label)
		heading.add_child(Style.badge("运送中","active"))
		var payout:=Contracts.payout(record)
		var returned:=int(record.rules.deposit)-(int(record.rules.insured_fee) if record.mode=="insured" else 0)
		text(card,"到期第%d日 · 交货款%d金＋退押%d金 · 参照货款%d金。"%[int(record.due_day),payout,returned,int(record.reference)])
		text(card,"交货地："+String(EconomyService.site(TableCache.economy_config(),String(definition.destination)).name)+"；"+("路线已核准" if bool(record.aid) else "路线未核准："+String(definition.route_name)))
		text(card,"退单返%d金、不扣货。"%Contracts.refund(record))
		var actions:=HBoxContainer.new()
		card.add_child(actions)
		if site_id==String(definition.destination):button(actions,"到货交付",func():result(Contracts.action(G,String(id),"deliver",site_id)))
		if site_id in [String(definition.origin),String(definition.destination)]:
			button(actions,"退单",func():cancel(String(id)))
			if not bool(record.extended) and Contracts.day(G)>int(record.due_day):button(card,"延期一次 · 付12金",func():result(Contracts.action(G,String(id),"extend",site_id)))
func _unhandled_input(event:InputEvent) -> void:
	if G.ui_blocked:return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
