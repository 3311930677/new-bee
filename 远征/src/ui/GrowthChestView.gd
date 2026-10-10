extends Control
## Extension template for the four growth systems absent from the design screenshots.
const UI := preload("res://src/ui/TravelChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
var host: Control
var system := ""
var selection := ""
var operation := "feed"
var _stage: Control
var _art: TextureRect
var _name: Label
var _status: Label
var _tray: Control
var _tabs: HBoxContainer
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _details: Label
var _reading: ScrollContainer
var _main: Button
var _secondary: Button
var _back: Button
var _title: Label
var _help: Button
var _info: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=UI.theme()
	_stage=Page.Stage.new()
	add_child(_stage)
	_art=Page.picture(null,Vector2(144,144))
	add_child(_art)
	_name=UI.label("","object")
	_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)
	_status=UI.label("","caption",UI.AGED)
	_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)
	_back=UI.action("‹","back")
	_back.tooltip_text="返回养成"
	_back.pressed.connect(func():host.closed.emit())
	add_child(_back)
	_title=UI.label({"talent":"天赋修习","pet":"灵宠养成","mount":"坐骑结伴","title":"称号荣誉"}[system],"title")
	add_child(_title)
	_tray=UI.Tray.new()
	add_child(_tray)
	_tabs=HBoxContainer.new()
	_tabs.add_theme_constant_override("separation",4)
	add_child(_tabs)
	_scroll=Page.scroll()
	add_child(_scroll)
	_rows=VBoxContainer.new()
	_rows.add_theme_constant_override("separation",6)
	_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	_details=Page.line("","body",UI.AGED)
	_details.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	_reading=Page.scroll()
	_reading.add_child(_details)
	add_child(_reading)
	_info=UI.label("","caption",UI.GOLD)
	_info.clip_text=true
	_info.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_info)
	_main=UI.action("","primary")
	_main.pressed.connect(_activate)
	add_child(_main)
	_secondary=UI.action("切换骑乘","secondary")
	_secondary.pressed.connect(func():
		if system=="mount" and G.mount_set_active(selection):host._toast_msg("已选择坐骑");refresh())
	add_child(_secondary)
	_help=UI.action("说明","quiet")
	_help.pressed.connect(func():
		var d:=UI.Modal.new()
		d.heading="灵宠养成 · 怎么玩"
		d.lines=host.PET_TIPS
		d.closed.connect(d.queue_free)
		add_child(d))
	add_child(_help)
	if system=="talent":host._info_l=_info
	if system=="title":host._scroll=_scroll
	if system=="pet":G.tip_once.call_deferred("pet_raise","灵宠养成 · 怎么玩",host.PET_TIPS,host)
	get_viewport().size_changed.connect(layout)
	refresh()

func layout(safe_override: Rect2=Rect2()) -> void:
	var safe:=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var x:=safe.position.x
	var top:=safe.end.y-472
	Page.place(_stage,Vector2.ZERO,get_viewport_rect().size)
	Page.place(_back,Vector2(x+8,safe.position.y+6),Vector2(44,44))
	Page.place(_title,Vector2(x+64,safe.position.y+8),Vector2(300,40))
	Page.place(_help,Vector2(safe.end.x-72,safe.position.y+6),Vector2(64,44))
	Page.place(_art,Vector2(safe.get_center().x-72,top-218),Vector2(144,144))
	Page.place(_name,Vector2(x+16,top-70),Vector2(safe.size.x-32,32))
	Page.place(_status,Vector2(x+16,top-38),Vector2(safe.size.x-32,26))
	Page.place(_tray,Vector2(x,top),Vector2(safe.size.x,472))
	Page.place(_tabs,Vector2(x+16,top+12),Vector2(safe.size.x-32,44))
	Page.place(_scroll,Vector2(x+16,top+64),Vector2(safe.size.x-32,228))
	Page.place(_reading,Vector2(x+20,top+304),Vector2(safe.size.x-40,68))
	Page.place(_info,Vector2(x+20,top+376),Vector2(safe.size.x-40,24))
	Page.place(_secondary,Vector2(x+12,safe.end.y-68),Vector2(132,56))
	Page.place(_main,Vector2(x+156,safe.end.y-68),Vector2(safe.size.x-168,56))
	if not _secondary.visible:Page.place(_main,Vector2(x+156,safe.end.y-68),Vector2(safe.size.x-168,56))
	if system!="talent" and is_instance_valid(host._toast):host._toast.position=Vector2(safe.get_center().x-180,safe.end.y-116)

func _tab(words: String,id: String,current: String,callback: Callable) -> void:
	var b:=UI.action(words,"tab")
	b.custom_minimum_size.y=44
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.selected=id==current
	b.pressed.connect(callback)
	_tabs.add_child(b)

func _row(words: String,hint: String,id: String,selected: bool,ready: bool=false) -> void:
	var b:=Page.GrowthRow.new(words,system)
	b.custom_minimum_size.x=0
	b.set_meta("growth_selection",id)
	b.status.text=hint
	b.status.clip_text=true
	b.status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	b.heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	b.heading.clip_text=true
	b.actionable=ready
	b.next_action.text="已选" if selected else "选择"
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():selection=id;refresh())
	_rows.add_child(b)

func refresh() -> void:
	var offset:=_scroll.scroll_vertical
	Page.clear(_rows)
	Page.clear(_tabs)
	_secondary.visible=false
	_help.visible=system=="pet"
	match system:
		"talent":_talent()
		"pet":_pet()
		"mount":_mount()
		"title":_honor()
	layout()
	_scroll.set_deferred("scroll_vertical",offset)

func _set_main(words: String,enabled: bool) -> void:
	_main.text=words
	_main.caption.text=words
	_main.disabled=not enabled
	_main.queue_redraw()

func _talent() -> void:
	var branches:Array=G.talents_cfg().get("branches",[])
	if selection.is_empty() and not branches.is_empty():selection=String(branches[0].nodes[0].id)
	var selected:=G.talent_node(selection)
	var branch_id:=String(selected.get("branch",""))
	# Some tables keep branch only on the containing tree.
	for branch in branches:
		for node in branch.nodes:
			if String(node.id)==selection:branch_id=String(branch.id)
	for branch in branches:
		var id:=String(branch.id)
		_tab(String(branch.name),id,branch_id,func():selection=String(branch.nodes[0].id);refresh())
		if id!=branch_id:continue
		for node in branch.nodes:
			var n:=int((G.prog.get("talents",{}) as Dictionary).get(String(node.id),0))
			_row(String(node.name),"第%d阶 · %d / %d" % [int(node.get("tier",1)),n,int(node.get("max",1))],String(node.id),String(node.id)==selection,G.talent_can_add(String(node.id)))
	_art.texture=Page.texture("talent")
	_name.text=String(selected.get("name","天赋修习"))
	_status.text="剩余天赋点 %d / %d" % [G.talent_points_left(),G.talent_points_total()]
	_details.text=String(selected.get("desc",""))+"\n每 5 级获得 1 点；需本系投入 %d 点" % maxi(0,int(selected.get("tier",1))-1)
	_set_main("分配天赋",G.talent_can_add(selection))

func _pet() -> void:
	var pets:=G.owned_pets()
	if not pets.has(selection):selection=String(pets[0]) if not pets.is_empty() else ""
	host._sel=selection
	for pet in pets:
		var id:=String(pet)
		_row(String(TableCache.get_pet(id).get("name",id)),"Lv.%d · 突破 %d/5" % [int(G.pet_stat(id).get("lv",1)),int(G.pet_stat(id).get("brk",0))],id,id==selection)
	for item in [["feed","喂养"],["break","突破"],["star","洗资质"]]:
		var id:String=item[0]
		_tab(item[1],id,operation,func():operation=id;refresh())
	var cfg:=TableCache.get_pet(selection)
	var state:=G.pet_stat(selection) if not selection.is_empty() else {}
	_art.texture=preload("res://src/ui/ReviewFixUI.gd").pet(selection) if not selection.is_empty() else Page.texture("pet")
	_name.text=String(cfg.get("name","尚未收集灵宠"))
	_status.text="Lv.%d · 资质 %d 星 · 突破 %d/5" % [int(state.get("lv",1)),int(state.get("star",3)),int(state.get("brk",0))]
	var enabled:=not selection.is_empty()
	match operation:
		"feed":
			_details.text="宠物粮 1 / %d（需要 / 持有）\n每份 +100 经验 · 当前 %d / %d · 上限 Lv.%d" % [G.item_count("pet_food"),int(state.get("exp",0)),G.pet_exp_to_next(int(state.get("lv",1))),int(G.prog.get("level",1))]
			enabled=enabled and G.item_count("pet_food")>0 and int(state.get("lv",1))<int(G.prog.get("level",1))
		"break":
			var cost:=G.pet_break_cost(selection)
			_details.text="已至五层" if cost.is_empty() else "突破晶 %d / %d · 魂石 %d / %d\n每层全属性 +8%%" % [int(cost.crystal),G.item_count("break_crystal"),int(cost.soul),int(G.wallet.get("soul",0))]
			enabled=enabled and not cost.is_empty() and G.item_count("break_crystal")>=int(cost.get("crystal",0)) and int(G.wallet.get("soul",0))>=int(cost.get("soul",0))
		"star":
			_details.text="资质果 1 / %d（需要 / 持有）\n重新随机 1～5 星，可能降低资质" % G.item_count("aptitude_fruit")
			enabled=enabled and G.item_count("aptitude_fruit")>0
	if not selection.is_empty():
		var stats:PackedStringArray=[]
		for pair in [["hp","生命",50],["atk","攻击",10],["def","防御",5]]:
			var base:Dictionary=cfg.get("base",{})
			var growth:Dictionary=cfg.get("growth",{})
			var value:=int((float(base.get(pair[0],pair[2]))+float(growth.get(pair[0],0))*(int(state.get("lv",1))-1)*G.pet_growth_mult(selection))*G.pet_stat_mult(selection))
			stats.append("%s %d"%[pair[1],value])
		_details.text=" · ".join(stats)+"\n"+_details.text
	_set_main({"feed":"确认喂养","break":"确认突破","star":"重洗资质"}[operation],enabled)

func _mount() -> void:
	var mounts:=G.mounts_cfg()
	if selection.is_empty():selection=G.mount_active() if not G.mount_active().is_empty() else String(mounts[0].id)
	for m in mounts:
		var id:=String(m.id)
		_row(String(m.name),"未拥有" if G.mount_tier(id)==0 else "%d阶%s" % [G.mount_tier(id)," · 当前同行" if G.mount_active()==id else ""],id,id==selection)
	var cfg:=G.mount_cfg(selection)
	var tier:=G.mount_tier(selection)
	var tiers:Array=cfg.get("tiers",[])
	var info:Dictionary=tiers[mini(tier,tiers.size()-1)]
	_art.texture=G.res_tex(String(cfg.get("icon2" if tier>=2 else "icon","")))
	_name.text=String(cfg.get("name","坐骑"))
	_status.text="未拥有" if tier==0 else "当前 %d 阶 · %s" % [tier,"同行中" if selection==G.mount_active() else "未选择"]
	var cost:Dictionary=info.get("cost",{}) if tier<tiers.size() else {}
	_details.text=host._bonus_text(info.get("bonus",{}))+"\n"+wallet_cost(cost)
	_set_main("购买坐骑" if tier==0 else "升至二阶" if tier<tiers.size() else "已达最高阶",tier<tiers.size() and G.has_cost(cost))
	_secondary.visible=tier>0
	_secondary.disabled=selection==G.mount_active()
	_secondary.caption.text="同行中" if _secondary.disabled else "选择同行"

func _honor() -> void:
	host._split_groups()
	var all:Array=[]
	for i in host._groups.size():
		_rows.add_child(UI.label(host._group_names[i],"caption",UI.AGED))
		for cfg in host._sorted_group(i):
			all.append(cfg)
			var id:=String(cfg.id)
			_row(String(cfg.name),"佩戴中" if G.title_active()==id else "已拥有" if G.title_owned(id) else "可领取" if G.title_cond_met(cfg) else String(cfg.get("desc","未达成")),id,id==selection,G.title_cond_met(cfg) and not G.title_owned(id))
	if selection.is_empty() and not all.is_empty():selection=String(all[0].id)
	var cfg:=G.title_cfg(selection)
	_art.texture=Page.texture("title")
	_name.text=String(cfg.get("name","称号"))
	_status.text="当前佩戴 · "+String(G.title_cfg(G.title_active()).get("name","尚未佩戴"))
	_details.text=String(cfg.get("desc",""))+"\n"+host._bonus_text(cfg.get("bonus",{}))+" "+wallet_cost(cfg.get("cost",{}))
	_set_main("卸下称号" if G.title_active()==selection else "佩戴称号" if G.title_owned(selection) else "领取称号",G.title_owned(selection) or G.title_cond_met(cfg) or (not (cfg.get("cost",{}) as Dictionary).is_empty() and G.has_cost(cfg.cost)))

func wallet_cost(cost: Dictionary) -> String:
	var parts:PackedStringArray=[]
	for key in cost:
		parts.append("%s %d / %d" % [{"gold":"金币","soul":"魂石","honor":"荣誉","expedition":"远征币"}.get(key,key),int(cost[key]),int(G.wallet.get(key,0))])
	return " · ".join(parts)+("（需要 / 持有）" if not parts.is_empty() else "")

func _activate() -> void:
	match system:
		"talent":host._on_node(selection)
		"pet":
			match operation:
				"feed":host._on_feed()
				"break":host._on_break()
				"star":Page.confirm(self,"重洗资质","新资质可能低于当前星级，确定消耗资质果？",host._on_reroll)
		"mount":host._on_buy(selection)
		"title":
			if G.title_active()==selection:G.title_set_active("");refresh()
			elif G.title_owned(selection):G.title_set_active(selection);refresh()
			else:host._on_claim(selection)
