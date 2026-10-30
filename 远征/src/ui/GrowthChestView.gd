extends Control
## Extension template for the four growth systems absent from the design screenshots.
const UI := preload("res://src/ui/TravelChestUI.gd")
const KitV4 := preload("res://src/ui/KitV4.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const Fix := preload("res://src/ui/ReviewFixUI.gd")
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
	_main.pressed.connect(func(): HapticFeedback.light())
	_main.pressed.connect(_activate)
	add_child(_main)
	_secondary=UI.action("切换骑乘","secondary")
	_secondary.pressed.connect(func():
		HapticFeedback.light()
		if system=="mount" and G.mount_set_active(selection):host._toast_msg("已选择坐骑");refresh()
		elif system=="talent":
			G.show_choice_popup(self, "重置天赋", ["免费退回全部已分配点数，之后可以重新选择流派。"], [
				{"text": "取消", "cb": func(): pass},
				{"text": "确认重置", "cb": func():
					var result := G.talent_reset()
					_info.text = "天赋点已全部退回" if result.ok else String(result.get("err", "未能保存"))
					refresh()},
			]))
	add_child(_secondary)
	_help=UI.action("说明","quiet")
	_help.pressed.connect(func():
		var d:=UI.Modal.new()
		d.heading="灵宠养成 · 怎么玩"
		d.lines=host.PET_TIPS
		d.closed.connect(d.queue_free)
		add_child(d))
	add_child(_help)
	if system=="talent":
		host._info_l=_info
		var astro_tex := KitV4.commercial_tex("bg_talent_astrolabe")
		if astro_tex != null and _stage.get("background") != null:
			_stage.background.texture = astro_tex
	if system=="title":host._scroll=_scroll
	if system=="pet":G.tip_once.call_deferred("pet_raise","灵宠养成 · 怎么玩",host.PET_TIPS,host)
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	refresh()

func layout(safe_override: Rect2=Rect2()) -> void:
	var safe:=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var x:=safe.position.x
	var extra:=maxf(0.0,safe.size.y-800.0)
	var tray_h:=minf(roundf(clampf(472.0+extra*0.58,472.0,636.0)),safe.size.y-260.0)
	var top:=safe.end.y-tray_h
	var list_h:=maxf(60,tray_h-244.0)
	var stage_h:=top-(safe.position.y+56.0)
	var art_extent:=minf(144,maxf(72,stage_h-66.0))
	var art_top:=roundf(safe.position.y+56.0+maxf(0.0,(stage_h-art_extent-62.0)*0.5))
	Page.place(_stage,Vector2.ZERO,get_viewport_rect().size)
	Page.place(_back,Vector2(x+12,safe.position.y+8),Vector2(44,44))
	_title.clip_text=true
	Page.place(_title,Vector2(x+68,safe.position.y+10),Vector2(safe.size.x-(148 if system=="pet" else 80),40))
	Page.place(_help,Vector2(safe.end.x-72,safe.position.y+8),Vector2(64,44))
	_art.custom_minimum_size=Vector2.ZERO
	Page.place(_art,Vector2(safe.get_center().x-art_extent*.5,art_top),Vector2.ONE*art_extent)
	Page.place(_name,Vector2(x+16,art_top+art_extent+2),Vector2(safe.size.x-32,30))
	_status.clip_text=true
	_status.add_theme_font_size_override("font_size",G.FS_DENSE if safe.size.x<380 else G.FS_XS)
	Page.place(_status,Vector2(x+12,art_top+art_extent+32),Vector2(safe.size.x-24,26))
	Page.place(_tray,Vector2(x,top),Vector2(safe.size.x,tray_h))
	Page.place(_tabs,Vector2(x+16,top+12),Vector2(safe.size.x-32,44))
	Page.place(_scroll,Vector2(x+16,top+64),Vector2(safe.size.x-32,list_h))
	Page.place(_reading,Vector2(x+20,top+76+list_h),Vector2(safe.size.x-40,68))
	Page.place(_info,Vector2(x+20,safe.end.y-104),Vector2(safe.size.x-40,24))
	var secondary_w:=minf(132,safe.size.x*.34)
	Page.place(_secondary,Vector2(x+12,safe.end.y-68),Vector2(secondary_w,56))
	var main_x:=x+24+secondary_w if _secondary.visible else x+12
	Page.place(_main,Vector2(main_x,safe.end.y-68),Vector2(safe.end.x-main_x-12,56))
	if system!="talent" and is_instance_valid(host._toast):host._toast.position=Vector2(safe.get_center().x-180,safe.end.y-116)

func _tab(words: String,id: String,current: String,callback: Callable) -> void:
	var b:=UI.action(words,"tab")
	b.custom_minimum_size.y=44
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.selected=id==current
	b.pressed.connect(callback)
	_tabs.add_child(b)

func _row(words: String,hint: String,id: String,selected: bool,ready: bool=false) -> void:
	var b:=Page.GrowthRow.new(words, id)
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
	_secondary.visible=true
	_secondary.text="重置天赋"
	_secondary.caption.text="重置天赋"
	_secondary.disabled=G.save_locked or G.talent_points_spent()<=0
	var branches:Array=G.talents_cfg().get("branches",[])
	if selection.is_empty() and not branches.is_empty():selection=String(branches[0].nodes[0].id)
	var selected:=G.talent_node(selection)
	var branch_id:=String(selected.get("branch",""))
	for branch in branches:
		for node in branch.nodes:
			if String(node.id)==selection:branch_id=String(branch.id)
	var active_nodes:Array=[]
	for branch in branches:
		var id:=String(branch.id)
		_tab(String(branch.name),id,branch_id,func():selection=String(branch.nodes[0].id);refresh())
		if id==branch_id:
			active_nodes=branch.nodes
	# §4.6-2 10 阶星盘路径树（带连线 + 4 态节点框 A-10 + 30 个专属图标 D-01..D-03）
	if not active_nodes.is_empty():
		var path_tree := TalentPathStrip.new(active_nodes, selection, func(nid: String): selection = nid; refresh())
		_rows.add_child(path_tree)
	for node in active_nodes:
		var n:=int((G.prog.get("talents",{}) as Dictionary).get(String(node.id),0))
		_row(String(node.name),"第%d阶 · %d / %d" % [int(node.get("tier",1)),n,int(node.get("max",1))],String(node.id),String(node.id)==selection,G.talent_can_add(String(node.id)))
	var t_tex := Page.talent_icon_tex(selection)
	if t_tex == null:
		var t_row := Page.GrowthRow.new("", selection)
		t_tex = t_row.image.texture if t_row.image != null and t_row.image.texture != null else Page.texture("skill")
	_art.texture = t_tex
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_name.text=String(selected.get("name","天赋修习"))
	_status.text="剩余天赋点 %d / %d" % [G.talent_points_left(),G.talent_points_total()]
	_details.text=String(selected.get("desc",""))+"\n每 5 级获得 1 点，可免费重置；需本系投入 %d 点" % maxi(0,int(selected.get("tier",1))-1)
	_set_main("分配天赋",G.talent_can_add(selection))

func _pet() -> void:
	var pets:=G.owned_pets()
	if not pets.has(selection):selection=String(pets[0]) if not pets.is_empty() else ""
	host._sel=selection
	# §4.8 横向卡片轮播条（88×96）
	if not pets.is_empty():
		var hscroll := ScrollContainer.new()
		hscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		hscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		hscroll.custom_minimum_size.y = 92
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hscroll.add_child(hbox)
		for pet in pets:
			var pid := String(pet)
			var pcfg := TableCache.get_pet(pid)
			var pst := G.pet_stat(pid)
			var cell := Page.ItemCell.new()
			cell.custom_minimum_size = Vector2(84, 86)
			cell.image_px = 48.0
			cell.item_image.texture = Fix.pet(pid)
			cell.heading.text = String(pcfg.get("name", pid))
			cell.show_name = true
			cell.amount.text = "Lv.%d" % int(pst.get("lv", 1))
			cell.selected = pid == selection
			cell.rarity_rank = 3
			cell.pressed.connect(func(): selection = pid; refresh())
			hbox.add_child(cell)
		_rows.add_child(hscroll)
	for pet in pets:
		var id:=String(pet)
		_row(String(TableCache.get_pet(id).get("name",id)),"Lv.%d · 突破 %d/5 · 羁绊 %d/5" % [int(G.pet_stat(id).get("lv",1)),int(G.pet_stat(id).get("brk",0)),G.pet_bond_level(id)],id,id==selection)
	for item in [["feed","喂养"],["break","突破"],["star","洗资质"],["bond","羁绊"]]:
		var id:String=item[0]
		_tab(item[1],id,operation,func():operation=id;refresh())
	var cfg:=TableCache.get_pet(selection)
	var state:=G.pet_stat(selection) if not selection.is_empty() else {}
	_art.texture=Fix.pet(selection+"_hd") if not selection.is_empty() else Page.texture("pet")
	_name.text=String(cfg.get("name","尚未收集灵宠"))
	_status.text="Lv.%d · 资质 %d 星 · 突破 %d/5 · 羁绊 %d/5" % [int(state.get("lv",1)),int(state.get("star",3)),int(state.get("brk",0)),G.pet_bond_level(selection)]
	var enabled:=not selection.is_empty()
	match operation:
		"feed":
			_details.text="宠物粮 1 / %d（需要 / 持有）\n每份 +100 经验 · 当前 %d / %d · 上限 Lv.%d" % [G.item_count("pet_food"),int(state.get("exp",0)),G.pet_exp_to_next(int(state.get("lv",1))),int(G.prog.get("level",1))]
			enabled=enabled and G.item_count("pet_food")>0 and int(state.get("lv",1))<int(G.prog.get("level",1))
		"break":
			var cost:=G.pet_break_cost(selection)
			_details.text="已至五层" if cost.is_empty() else "突破晶 %d / %d · 魂石 %d / %d\n每层全属性 +8%% ▲" % [int(cost.crystal),G.item_count("break_crystal"),int(cost.soul),int(G.wallet.get("soul",0))]
			enabled=enabled and not cost.is_empty() and G.item_count("break_crystal")>=int(cost.get("crystal",0)) and int(G.wallet.get("soul",0))>=int(cost.get("soul",0))
		"star":
			_details.text="资质果 1 / %d（需要 / 持有）\n重新随机 1～5 星，可能降低资质" % G.item_count("aptitude_fruit")
			enabled=enabled and G.item_count("aptitude_fruit")>0
		"bond":
			var bcost:=G.pet_bond_cost(selection)
			_details.text="已达五阶灵犀共鸣（灵宠属性+15% · 主角生命+75/攻击+10）" if bcost.is_empty() else "宠粮 %d/%d · 金币 %d（每阶属性+3%% · 主角生命+15/攻击+2 ▲）" % [int(bcost.get("pet_food",1)),G.item_count("pet_food"),int(bcost.get("gold",80))]
			enabled=enabled and not bcost.is_empty() and G.item_count("pet_food")>=int(bcost.get("pet_food",1)) and int(G.wallet.get("gold",0))>=int(bcost.get("gold",80))
	if not selection.is_empty():
		var stats:PackedStringArray=[]
		for pair in [["hp","生命",50],["atk","攻击",10],["def","防御",5]]:
			var base:Dictionary=cfg.get("base",{})
			var growth:Dictionary=cfg.get("growth",{})
			var value:=int((float(base.get(pair[0],pair[2]))+float(growth.get(pair[0],0))*(int(state.get("lv",1))-1)*G.pet_growth_mult(selection))*G.pet_stat_mult(selection))
			stats.append("%s %d"%[pair[1],value])
		_details.text=" · ".join(stats)+"\n"+_details.text
	_set_main({"feed":"确认喂养","break":"确认突破","star":"重洗资质","bond":"羁绊互动"}[operation],enabled)

func _mount() -> void:
	_secondary.text="切换骑乘"
	_secondary.caption.text="切换骑乘"
	_secondary.disabled=false
	var mounts:=G.mounts_cfg()
	if selection.is_empty():selection=G.mount_active() if not G.mount_active().is_empty() else String(mounts[0].id)
	# §4.8 横向坐骑卡片轮播条
	if not mounts.is_empty():
		var hscroll := ScrollContainer.new()
		hscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		hscroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		hscroll.custom_minimum_size.y = 92
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		hscroll.add_child(hbox)
		for m in mounts:
			var mid := String(m.id)
			var mtier := G.mount_tier(mid)
			var cell := Page.ItemCell.new()
			cell.custom_minimum_size = Vector2(84, 86)
			cell.image_px = 48.0
			cell.item_image.texture = G.res_tex(String(m.get("icon2" if mtier >= 2 else "icon", "")))
			cell.item_image.modulate = Color.WHITE if mtier > 0 else Color(0.55, 0.55, 0.55)
			cell.heading.text = String(m.get("name", mid))
			cell.show_name = true
			cell.amount.text = "未拥有" if mtier == 0 else ("%d阶" % mtier)
			cell.selected = mid == selection
			cell.rarity_rank = 4 if mtier >= 2 else (3 if mtier == 1 else 1)
			cell.pressed.connect(func(): selection = mid; refresh())
			hbox.add_child(cell)
		_rows.add_child(hscroll)
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
	# §4.8 D-04 25 枚独立称号徽章图标
	_art.texture=Page.title_badge_tex(selection)
	_name.text=String(cfg.get("name","称号"))
	_status.text="当前佩戴 · "+String(G.title_cfg(G.title_active()).get("name","尚未佩戴"))
	_details.text=String(cfg.get("desc",""))+"\n"+host._bonus_text(cfg.get("bonus",{}))+" "+wallet_cost(cfg.get("cost",{}))
	_set_main("卸下称号" if G.title_active()==selection else "佩戴称号" if G.title_owned(selection) else "领取称号",G.title_owned(selection) or G.title_cond_met(cfg) or (not (cfg.get("cost",{}) as Dictionary).is_empty() and G.has_cost(cfg.cost)))

class TalentPathStrip extends Control:
	const KitV4 = preload("res://src/ui/KitV4.gd")
	const Page = preload("res://src/ui/ChestPageUI.gd")
	const UI = preload("res://src/ui/TravelChestUI.gd")
	var _nodes: Array = []
	var _sel: String = ""
	var _on_pick: Callable
	var _centers: Array[Vector2] = []

	func _init(nodes: Array, sel: String, on_pick: Callable) -> void:
		_nodes = nodes
		_sel = sel
		_on_pick = on_pick
		custom_minimum_size = Vector2(0, 140)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _ready() -> void:
		resized.connect(_rebuild)
		_rebuild()

	func _rebuild() -> void:
		Page.clear(self)
		_centers.clear()
		var w := maxf(340.0, size.x)
		var pad_x := 34.0
		var step_x := (w - pad_x * 2.0) / 4.0
		for i in _nodes.size():
			var nd: Dictionary = _nodes[i]
			var nid := String(nd.get("id", ""))
			var tier := int(nd.get("tier", i + 1))
			var cur := int((G.prog.get("talents", {}) as Dictionary).get(nid, 0))
			var mx := int(nd.get("max", 1))
			var can_add := G.talent_can_add(nid)
			var row_idx := 0 if i < 5 else 1
			var col_idx := i if i < 5 else (9 - i)
			var c := Vector2(pad_x + float(col_idx) * step_x, 34.0 if row_idx == 0 else 102.0)
			_centers.append(c)
			var nsz := Vector2(54, 54) if tier == 10 else Vector2(46, 46)
			var btn := Button.new()
			btn.position = c - nsz * 0.5
			btn.size = nsz
			btn.focus_mode = Control.FOCUS_NONE
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			var fkey := "talent_node_ult" if tier == 10 else ("talent_node_max" if cur >= mx else ("talent_node_avail" if (can_add or cur > 0) else "talent_node_locked"))
			var ftex := KitV4.commercial_tex(fkey)
			if ftex != null:
				var ftr := TextureRect.new()
				ftr.texture = ftex
				ftr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ftr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ftr.size = nsz
				ftr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(ftr)
			var itex := Page.talent_icon_tex(nid)
			if itex != null:
				var itr := TextureRect.new()
				itr.texture = itex
				itr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				itr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				itr.position = Vector2(8, 8)
				itr.size = nsz - Vector2(16, 16)
				itr.modulate = Color.WHITE if (cur > 0 or can_add) else Color(0.5, 0.5, 0.5, 0.85)
				itr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(itr)
			var lv_lbl := UI.label("%d/%d" % [cur, mx], "tag", KitV4.BRIGHT if cur >= mx else (KitV4.CREAM if cur > 0 else KitV4.MUTED))
			lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lv_lbl.add_theme_font_size_override("font_size", G.FS_DENSE)
			lv_lbl.position = Vector2(-4, nsz.y - 12)
			lv_lbl.size = Vector2(nsz.x + 8, 18)
			lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(lv_lbl)
			btn.pressed.connect(func(): _on_pick.call(nid))
			add_child(btn)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.07, 0.72), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(KitV4.TRIM, 0.55), false, 1.0)
		for i in range(_centers.size() - 1):
			var n0: Dictionary = _nodes[i]
			var cur0 := int((G.prog.get("talents", {}) as Dictionary).get(String(n0.get("id", "")), 0))
			var col := KitV4.BRIGHT if cur0 > 0 else Color("584836", 0.65)
			draw_line(_centers[i], _centers[i + 1], col, 3.0 if cur0 > 0 else 2.0, true)
		for i in _centers.size():
			var nd: Dictionary = _nodes[i]
			if String(nd.get("id", "")) == _sel:
				draw_arc(_centers[i], 26.0, 0.0, TAU, 28, KitV4.BRIGHT, 2.0, true)

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
				"bond":host._on_bond()
		"mount":host._on_buy(selection)
		"title":
			if G.title_active()==selection:G.title_set_active("");refresh()
			elif G.title_owned(selection):G.title_set_active(selection);refresh()
			else:host._on_claim(selection)
