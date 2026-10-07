extends Control
signal closed
const Trust := preload("res://src/world/RegionalTrust.gd")
const Style := preload("res://src/ui/LedgerStyle.gd")

var _list: VBoxContainer
var _line: Label
var _region := "zhaoyuan"
var _confirm := ""
var _tabs: Array[Control] = []

func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	G.veil(self, 0.86)
	var paper := Style.panel(Vector2(20,56),Vector2(440,688))
	add_child(paper)
	var content := Control.new()
	paper.add_child(content)
	var title := G.serif_label("三城世界事务", G.FS_LG, G.TEXT_DARK)
	content.add_child(title)
	for i in 3:
		var tab := G.gold_button(WorldCommission.NAMES[i],130,42,G.FS_SM)
		Style.apply_button(tab,"secondary")
		tab.position = Vector2(i*138,45)
		tab.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_region=WorldCommission.REGIONS[i]
				_confirm=""
				_refresh())
		content.add_child(tab)
		_tabs.append(tab)
	_line = Style.text("未接候选每日更换 · 已接目标跨日保留",14,Style.MUTED)
	_line.position=Vector2(0,96)
	_line.custom_minimum_size=Vector2(408,56)
	_line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_line)
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(0,155)
	scroll.size=Vector2(408,432)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list=VBoxContainer.new()
	_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation",12)
	scroll.add_child(_list)
	var back := G.ghost_button("返回历练委托",200,44)
	Style.apply_button(back,"quiet")
	back.position=Vector2(104,605)
	back.gui_input.connect(func(e:InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: closed.emit())
	content.add_child(back)
	var mid := String(G.prog.get("main_world",{}).get("map_id","lorin_wilds"))
	if mid=="shenyuan_port": _region="shenyuan"
	if mid=="frost_post": _region="frost"
	_refresh()

func _text(parent:Node, text:String, big:=false)->void:
	var label:=Style.text(text,18 if big else 15,Style.JADE if big else Style.INK)
	label.custom_minimum_size.x=348
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _refresh()->void:
	for i in _tabs.size():
		Style.apply_button(_tabs[i],"primary" if WorldCommission.REGIONS[i] == _region else "secondary")
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if not WorldCommission.available(G,_region):
		_text(_list,"尚未抵达这座城。沿归路主线推进后，公告栏会开放；事务不会阻挡主线。")
		return
	var trust := Trust.info(G,_region)
	_text(_list,"本城往来 · %s（%d 件实事）"%[trust.name,int(trust.count)],true)
	_text(_list,String(trust.hint))
	if int(trust.tier)>0: _text(_list,"再与本城代表交谈，会听见路簿、潮线纸或轮岗簿的后续。")
	for offer in WorldCommission.offers(G,_region):
		var posting:=String(offer.posting)
		var row:=WorldCommission.row(String(offer.template))
		var record:Dictionary=WorldCommission.state(G).get(posting,{})
		var status:=String(record.get("status","open"))
		var card := Style.list_card(_list)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation",8)
		card.add_child(heading)
		var name_label := Style.text(String(row.title),18,Style.JADE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(name_label)
		heading.add_child(Style.badge({"open":"可接取","active":"进行中","ready":"可交付","done":"已交付","abandoned":"已放弃"}.get(status,"待查看"),status))
		_text(card,String(row.desc))
		_text(card,"%s · %s · %s"%[String(offer.day),String(row.minutes)," / ".join(G.reward_lines(row.reward))])
		var step:=WorldCommission.current(record)
		if not step.is_empty():
			_text(card,"下一步：%s · %s（%d/%d）"%[String(TableCache.main_world_map(String(step.map)).get("name",step.map)),String(step.name),int(record.progress),(row.steps as Array).size()])
			var costs:Dictionary=step.get("costs",{})
			for key in costs: _text(card,"现场消耗：%s × %d"%[G.item_name(String(key).trim_prefix("item:")),int(costs[key])])
		var buttons:=HBoxContainer.new()
		card.add_child(buttons)
		var labels:Dictionary={"open":"接取","active":"目标已标在地图","ready":"回本城交付","done":"已交付","abandoned":"本单已放弃"}
		var act:=G.gold_button(String(labels.get(status,"")),220,42,G.FS_SM)
		Style.apply_button(act,"primary" if status in ["open","ready"] else "secondary")
		buttons.add_child(act)
		if status in ["open","ready"]:
			act.gui_input.connect(func(e:InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
					var res:Dictionary=WorldCommission.accept(G,posting,_region) if status=="open" else WorldCommission.claim(G,posting,String(G.prog.get("main_world",{}).get("map_id","lorin_wilds")))
					_line.text=String(res.line)
					_confirm=""
					_refresh())
		else: act.modulate=Color(.7,.7,.7)
		if status in ["active","ready"]:
			var drop:=G.ghost_button("确认放弃" if _confirm==posting else "放弃",120,42)
			Style.apply_button(drop,"danger")
			buttons.add_child(drop)
			drop.gui_input.connect(func(e:InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
					if _confirm!=posting:
						_confirm=posting
						_line.text="再次按确认放弃。本公布不可重接，已用于修补的材料不返还。"
					else:
						_line.text=String(WorldCommission.abandon(G,posting).line)
						_confirm=""
					_refresh())

func _unhandled_input(e:InputEvent)->void:
	if not G.ui_blocked and e.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
