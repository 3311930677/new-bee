extends Control
## Visual implementation of the equipment workshop. EquipPanel owns mutations.
const UI := preload("res://src/ui/TravelChestUI.gd")
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
var host: Control
var _stage: Control
var _slots: Control
var _focus: Control
var _tray: Control
var _tabs: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _actions: Control
var _back: Button
var _heading: Label
var _bag: Button
var _result: Label
var _modal: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	_stage = Fix.ContextStage.new("chest")
	add_child(_stage)
	_back = UI.action("‹","back")
	_back.tooltip_text = "返回"
	_back.pressed.connect(func(): host.closed.emit())
	add_child(_back)
	_heading = UI.label("装备整备","title")
	add_child(_heading)
	_bag = UI.action("背包","quiet")
	_bag.tooltip_text = "打开背包"
	_bag.pressed.connect(func(): host._open_bag())
	add_child(_bag)
	_slots = Control.new()
	add_child(_slots)
	_focus = Control.new()
	_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_focus)
	_tray = UI.Tray.new()
	add_child(_tray)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation",4)
	add_child(_tabs)
	_scroll = Page.scroll()
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",8)
	_scroll.add_child(_body)
	_actions = Control.new()
	add_child(_actions)
	_result = UI.label("","caption",UI.GOLD)
	add_child(_result)
	host._slots_row = _slots
	host._detail = self
	get_viewport().size_changed.connect(layout)
	refresh()

func layout(safe_override: Rect2 = Rect2()) -> void:
	var safe := safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var x := safe.position.x
	var y := safe.position.y
	var tray_top := maxf(y+300,safe.end.y-500)
	Page.place(_stage,Vector2.ZERO,get_viewport_rect().size)
	Page.place(_back,Vector2(x+8,y+6),Vector2(44,44))
	Page.place(_heading,Vector2(x+64,y+8),Vector2(300,40))
	Page.place(_bag,Vector2(safe.end.x-64,y+6),Vector2(56,44))
	Page.place(_slots,Vector2(x+12,y+64),Vector2(safe.size.x-24,80))
	var cell_width := floorf((_slots.size.x-32)/6)
	var slot_i:=0
	for child in _slots.get_children():
		if child is Button:
			child.custom_minimum_size.x=cell_width
			child.custom_minimum_size.y=70
			Page.place(child,Vector2(slot_i*(cell_width+4)+(12 if slot_i>=4 else 0),0),Vector2(cell_width,70))
			slot_i+=1
		else:
			Page.place(child,Vector2((slot_i-1)*(cell_width+4)+(12 if slot_i>4 else 0),72),Vector2(cell_width,20))
	Page.place(_focus,Vector2(x+20,y+160+(tray_top-y-300)*.5),Vector2(safe.size.x-40,108))
	Page.place(_tray,Vector2(x,tray_top),Vector2(safe.size.x,safe.end.y-tray_top))
	Page.place(_tabs,Vector2(x+12,tray_top+8),Vector2(safe.size.x-24,44))
	Page.place(_scroll,Vector2(x+20,tray_top+64),Vector2(safe.size.x-40,maxf(100,safe.end.y-tray_top-176)))
	Page.place(_result,Vector2(x+20,safe.end.y-104),Vector2(safe.size.x-40,32))
	Page.place(_actions,Vector2(x+12,safe.end.y-68),Vector2(safe.size.x-24,56))
	for child in _actions.get_children():
		if child.get_meta("main",false): Page.place(child,Vector2(144,0),Vector2(_actions.size.x-144,56))
		else: Page.place(child,Vector2.ZERO,Vector2(132,56))
	if is_instance_valid(host._toast):host._toast.position=Vector2(safe.get_center().x-180,safe.end.y-116)

func refresh() -> void:
	var old_scroll := _scroll.scroll_vertical
	for node in [_slots,_focus,_tabs,_body,_actions]: Page.clear(node)
	host._slot_lv.clear()
	var slot_defs: Array = G.equip_cfg().get("slots",[])
	for i in slot_defs.size():
		var cfg: Dictionary = slot_defs[i]
		var id := String(cfg.id)
		var cell := Page.ItemCell.new()
		cell.custom_minimum_size = Vector2(70,80)
		cell.size = Vector2(70,80)
		cell.position = Vector2(i*74 if i<4 else 308+(i-4)*74,0)
		cell.item_image.texture=Fix.item(String(G.equip_state(id).get("tpl","tpl_"+id+"_basic")))
		cell.image_px=52
		cell.heading.text = String(cfg.get("name",""))
		cell.show_name=false
		cell.amount.text = "+%d" % int(G.equip_state(id).get("lv",0)) if not G.equip_state(id).is_empty() else "空"
		cell.selected = id==host._sel
		cell.rarity = UI.COPPER if id==G.equip_weapon_slot() else UI.ASH
		cell.set_meta("sid",id)
		cell.tooltip_text = String(cfg.get("name",""))+(" · 本职业武器" if id==G.equip_weapon_slot() else "")
		cell.pressed.connect(func(): host._sel=id; refresh())
		_slots.add_child(cell)
		var label:=UI.label(String(cfg.get("name","")),"tag",UI.AGED)
		label.position=Vector2(cell.position.x,72)
		label.size=Vector2(70,20)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		_slots.add_child(label)
		host._slot_lv[id]=cell.amount
	var state := G.equip_state(host._sel)
	var worn := not state.is_empty()
	var tpl := G.equip_tpl(String(state.get("tpl",""))) if worn else G.equip_slot_cfg(host._sel)
	var frame := Page.ItemCell.new()
	frame.size=Vector2(96,96)
	frame.custom_minimum_size=Vector2(96,96)
	frame.image_px=80
	frame.rarity_rank=int(state.get("rarity",1))
	frame.rarity=G.equip_rarity_color(frame.rarity_rank)
	_focus.add_child(frame)
	var art := Page.picture(Fix.item(String(state.get("tpl",""))),Vector2(80,80))
	art.position = Vector2(8,8)
	frame.add_child(art)
	var name_l := UI.label(String(tpl.get("name","空槽位")),"object")
	name_l.position = Vector2(108,0)
	name_l.size = Vector2(310,32)
	_focus.add_child(name_l)
	var status := Page.line("%s · 强化 +%d" % [G.equip_rarity_name(int(state.get("rarity",1))),int(state.get("lv",0))] if worn else "从背包装备后可养成","caption",UI.AGED)
	Page.place(status,Vector2(108,34),Vector2(310,24))
	_focus.add_child(status)
	var stats := Page.line(host._bonus_summary(G.equip_slot_bonus(host._sel)) if worn else "当前槽位尚未装备","body")
	Page.place(stats,Vector2(108,62),Vector2(310,44))
	_focus.add_child(stats)
	for item in [["enhance","强化"],["gem","宝石"],["refine","精炼"]]:
		var id: String = item[0]
		var tab := UI.action(item[1],"tab")
		tab.selected = id==host._work_tab
		tab.set_meta("work_tab",id)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = 44
		tab.pressed.connect(func():
			if is_instance_valid(host._toast):host._toast.queue_free();host._toast=null
			host._work_tab=id
			refresh())
		_tabs.add_child(tab)
	_body.set_meta("work_page",host._work_tab)
	var un := UI.action("卸下","secondary")
	un.disabled = not worn
	un.pressed.connect(func():
		_modal = Page.confirm(self,"卸下装备","卸下后回到背包，确定继续？",func(): host._on_unequip()))
	_actions.add_child(un)
	match host._work_tab:
		"enhance": _enhance(state,worn)
		"gem": _gems(state,worn)
		"refine": _refine(state,worn)
	layout()
	_scroll.set_deferred("scroll_vertical",old_scroll)

func _primary(words: String, enabled: bool, callback: Callable, id: String) -> Button:
	var b := UI.action(words,"primary")
	b.set_meta("main",true)
	b.set_meta("work_action",id)
	b.disabled = not enabled or host._busy()
	b.pressed.connect(func():
		b.disabled = true
		callback.call())
	_actions.add_child(b)
	return b

func _cost(words: String, need: int, own: int) -> Control:
	return Fix.CostChip.new(words,need,own,G.res_tex(G.item_icon("lock_rune" if words=="锁符" else "refine_stone")))

func _enhance(state:Dictionary,worn:bool) -> void:
	var lv:=int(state.get("lv",0))
	var maxed:=lv>=G.equip_enhance_max()
	var next:=state.duplicate(true);next.lv=mini(lv+1,G.equip_enhance_max())
	var enh:Dictionary=G.equip_cfg().get("enhance",{})
	var rules:Array=["积累 %d/%d · 每次失败增加 %d%%，成功后重置"%[int(state.get("enhance_failures",0)),G.equip_enhance_failure_limit(host._sel),roundi(float(enh.get("failure_rate_bonus",.15))*100)],"失败扣费、不掉级。最高 +%d；+1 至 +%d 确定成功。"%[G.equip_enhance_max(),int(enh.get("guaranteed_target",3))]]
	var before:=G.equip_slot_bonus(host._sel)
	var after:=G.equip_instance_bonus(next)
	var differences:PackedStringArray=[]
	for pair in [["atk","攻击"],["hp","生命"],["def","防御"]]:
		var gain:=int(after.get(pair[0],0))-int(before.get(pair[0],0))
		if gain>0:differences.append("%s +%d"%[pair[1],gain])
	var delta:=" · ".join(differences)
	var invest:=Fix.Investment.new("+%d → +%d"%[lv,next.lv] if worn else "选一件装备开始整备",delta,"成功率 %.1f%% · 失败不掉级"%(G.equip_enhance_rate(host._sel)*100),rules)
	_body.add_child(invest)
	var cost:=G.equip_enhance_cost(host._sel)
	invest.costs.add_child(Fix.CostChip.new("金币",int(cost.gold),int(G.wallet.get("gold",0)),G.res_tex("cur_gold")))
	invest.costs.add_child(Fix.CostChip.new(G.item_name(String(cost.item)),int(cost.item_n),G.item_count(String(cost.item)),G.res_tex(G.item_icon(String(cost.item)))))
	var enough:=int(G.wallet.get("gold",0))>=int(cost.gold) and G.item_count(String(cost.item))>=int(cost.item_n)
	_result.text=""
	var action:=_primary("确认强化",worn and enough and not maxed,host._on_enhance,"enhance")
	action.set_meta("cost_summary","先从背包装备" if not worn else "已达到强化上限" if maxed else Fix.shortage([{"name":"金币","need":int(cost.gold),"have":int(G.wallet.get("gold",0))},{"name":G.item_name(String(cost.item)),"need":int(cost.item_n),"have":G.item_count(String(cost.item))}]) if not enough else "金币 %d · 强化石 %d"%[int(cost.gold),int(cost.item_n)])
	action.subtitle.text=String(action.get_meta("cost_summary"))
	_body.add_child(Page.line("强化积累 %d/%d"%[int(state.get("enhance_failures",0)),G.equip_enhance_failure_limit(host._sel)],"caption",UI.AGED))
	var sockets:=HBoxContainer.new();_body.add_child(sockets)
	sockets.add_child(UI.label("宝石","caption",UI.AGED))
	for i in G.equip_gem_sockets():sockets.add_child(host._socket_box(int(state.get("uid",0)),state.get("gems",[]),i))
	_body.add_child(Page.line("词条："+" · ".join((state.get("affixes",[]) as Array).map(func(a):return Page.affix_label(a))) if not (state.get("affixes",[]) as Array).is_empty() else "词条尚未精炼 · 切换精炼页签整备","caption",UI.AGED))

func _gems(state: Dictionary, worn: bool) -> void:
	var row := HBoxContainer.new()
	_body.add_child(row)
	for mode in [["socket","镶嵌"],["merge","合成"]]:
		var id: String = mode[0]
		var b := UI.action(mode[1],"tab")
		b.selected = id==host._gem_mode
		b.custom_minimum_size = Vector2(100,44)
		b.pressed.connect(func(): host._gem_mode=id; refresh())
		row.add_child(b)
	var sockets := HBoxContainer.new()
	sockets.add_theme_constant_override("separation",8)
	_body.add_child(sockets)
	for i in G.equip_gem_sockets():
		sockets.add_child(host._socket_box(int(state.get("uid",0)),state.get("gems",[]),i))
	_body.add_child(Page.line("合成费 %d 金币/次 · 同色同级 %d → 1" % [host._gem_merge_cost(),host._gem_merge_need()] if host._gem_mode=="merge" else "镶嵌费 %d 金币/次 · 点已镶宝石可拆除" % G.equip_socket_cost(),"caption",UI.AGED))
	var pager := HBoxContainer.new()
	_body.add_child(pager)
	var pages: int = host.gem_page_count()
	host._gem_page = clampi(host._gem_page,0,pages-1)
	for step in [-1,1]:
		var arrow := UI.action("‹" if step<0 else "›","quiet")
		arrow.custom_minimum_size = Vector2(44,44)
		arrow.disabled = host._gem_page+step<0 or host._gem_page+step>=pages
		arrow.pressed.connect(func(): host._gem_page+=step; refresh())
		pager.add_child(arrow)
	var count := UI.label("背包宝石  %d/%d" % [host._gem_page+1,pages],"caption")
	pager.add_child(count)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	_body.add_child(grid)
	for gid in host.gem_page_ids(): grid.add_child(host._gem_chip(String(gid)))
	if host._gem_inventory().is_empty(): _body.add_child(Page.line("背包暂无宝石 · 可前往兑换","caption",UI.AGED))
	_result.text = "选宝石合成更高一级" if host._gem_mode=="merge" else "选宝石镶嵌" if worn else "请先装备一件物品"
	_primary("前往背包",true,host._open_bag,"bag")

func _refine(state: Dictionary, worn: bool) -> void:
	_body.add_child(Page.line("锁住满意词条，再洗其余位置","section"))
	var affixes: Array = state.get("affixes",[])
	var locks := 0
	for i in affixes.size():
		_body.add_child(host._affix_row(affixes[i],i))
		if affixes[i].get("locked",false): locks+=1
	var cfg: Dictionary = G.equip_cfg().get("refine",{})
	for i in range(affixes.size(),int(cfg.get("affix_count",4))):
		var l := Page.line("— 空词条 —","caption",UI.ASH)
		l.custom_minimum_size.y = 44
		_body.add_child(l)
	var n := int(cfg.get("cost_item_n",2))
	var id := String(cfg.get("cost_item","refine_stone"))
	var costs := HBoxContainer.new()
	_body.add_child(costs)
	costs.add_child(_cost(G.item_name(id),n,G.item_count(id)))
	costs.add_child(_cost("锁符",locks,G.item_count("lock_rune")))
	var enough := G.item_count(id)>=n and G.item_count("lock_rune")>=locks
	_result.text = Fix.shortage([{"name":G.item_name(id),"need":n,"have":G.item_count(id)},{"name":"锁符","need":locks,"have":G.item_count("lock_rune")}]) if not enough else "已锁 %d 条 · 洗练消耗锁符 %d" % [locks,locks]
	_primary("确认洗练",worn and enough,host._on_refine,"refine")
