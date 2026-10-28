# BagPanel.gd — full-page travel chest, 5-column scrolling inventory.
class_name BagPanel
extends Control
signal closed
const UI := preload("res://src/ui/TravelChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const TouchScroll := preload("res://src/ui/TouchScroll.gd")
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
const Art := preload("res://src/ui/InventoryQuestSkin.gd")
const Descriptions := preload("res://src/ui/ItemDescriptions.gd")
const TABS := [["equip","装备"],["mat","材料"],["gem","宝石"],["pending","待领取"]]
var _tab := "equip"
var _page := 0
var _sel_uid := 0
var _confirm_uid := 0
var _sel_supply := ""
var _panel_root: Control
var _stage: Control
var _banner: Label
var _close_btn: Button
var _count_l: Label
var _pending_l: Label
var _gold: Label
var _gold_bg: Panel = null
var _tabs: HBoxContainer
var _list: Control
var _scroll: TouchScroll
var _detail: Control
var _detail_scroll: ScrollContainer
var _detail_body: VBoxContainer
var _actions: Control
var _tray: Control
var _toast: Control
var _modal: Control
var _tab_buttons: Dictionary = {}
var _item_buttons: Array[Button] = []
var _action_buttons: Array[Button] = []
var _focus_return: Control
var _header: Panel
var _list_plate: Panel
var _bag_mark: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _focus_return==null: _focus_return=get_viewport().gui_get_focus_owner()
	theme=Art.theme()
	_build()
	get_viewport().size_changed.connect(_resize_frame)
	preload("res://src/ui/UiSafeArea.gd").watch(self,_resize_frame)
	_refresh()
	_tab_buttons[_tab].grab_focus.call_deferred()

func _build() -> void:
	_stage=Art.Stage.new()
	add_child(_stage)
	_panel_root=Control.new()
	_panel_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)
	_header=Art.plate("header")
	_panel_root.add_child(_header)
	_bag_mark=G.ui_icon("bag",Vector2(28,28),Art.GOLD)
	_panel_root.add_child(_bag_mark)
	_close_btn=Art.action("‹","back")
	_close_btn.name="ReturnButton"
	_close_btn.tooltip_text="返回"
	_close_btn.pressed.connect(_close)
	_panel_root.add_child(_close_btn)
	_banner=Art.label("行旅背包","title",Art.GOLD)
	_panel_root.add_child(_banner)
	_count_l=Art.label("","caption",Art.MUTED)
	_count_l.name="Capacity"
	_panel_root.add_child(_count_l)
	_pending_l=Art.label("","caption",Art.MUTED)
	_panel_root.add_child(_pending_l)
	_gold_bg=Panel.new()
	_gold_bg.name="GoldPill"
	_gold_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_gold_bg.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_gold_bg.add_theme_stylebox_override("panel",Art.box("secondary",0))
	_panel_root.add_child(_gold_bg)
	_gold=Art.label("","number",Art.GOLD)
	_gold.name="GoldBalance"
	_gold.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_panel_root.add_child(_gold)
	_tabs=HBoxContainer.new()
	_tabs.name="Categories"
	_tabs.add_theme_constant_override("separation",6)
	_panel_root.add_child(_tabs)
	for entry in TABS:
		var key: String=entry[0]
		var b=Art.action(entry[1],"tab")
		b.custom_minimum_size.y=60
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.name="Tab_"+key
		b.pressed.connect(_select_tab.bind(key))
		_tabs.add_child(b)
		_tab_buttons[key]=b
	_list_plate=Art.plate("card")
	_panel_root.add_child(_list_plate)
	_list=Control.new()
	_list.name="Items"
	_panel_root.add_child(_list)
	_scroll=preload("res://src/ui/TouchScroll.gd").new()
	_scroll.name="ItemScroll"
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list.add_child(_scroll)
	_tray=Art.plate("paper")
	_panel_root.add_child(_tray)
	_detail=Control.new()
	_detail.name="SelectedItemDetail"
	_panel_root.add_child(_detail)
	_detail_scroll=Page.scroll()
	_detail_scroll.name="DetailScroll"
	_detail.add_child(_detail_scroll)
	_detail_body=VBoxContainer.new()
	_detail_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation",4)
	_detail_scroll.add_child(_detail_body)
	_actions=Control.new()
	_actions.name="EquipmentActions"
	_detail.add_child(_actions)
	_resize_frame()

func _resize_frame(safe_override: Rect2=Rect2()) -> void:
	if _panel_root==null:return
	var safe:=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	# Keep the reading column usable on tablets without shrinking phone controls.
	if safe.size.x>640:
		safe=Rect2(Vector2(safe.get_center().x-320,safe.position.y),Vector2(640,safe.size.y))
	Page.place(_stage,Vector2.ZERO,get_viewport_rect().size)
	Page.place(_panel_root,safe.position,safe.size)
	var w:=safe.size.x
	Page.place(_header,Vector2(12,8),Vector2(w-24,72))
	Page.place(_close_btn,Vector2(18,16),Vector2(56,56))
	Page.place(_bag_mark,Vector2(86,28),Vector2(32,32))
	Page.place(_banner,Vector2(128,18),Vector2(w-152,52))
	Page.place(_count_l,Vector2(24,84),Vector2(w*.34,36))
	Page.place(_pending_l,Vector2(w*.38,84),Vector2(w*.23,36))
	if _gold_bg!=null:Page.place(_gold_bg,Vector2(w*.64,84),Vector2(w*.36-24,36))
	Page.place(_gold,Vector2(w*.64,84),Vector2(w*.36-24,36))
	Page.place(_tabs,Vector2(20,126),Vector2(w-40,60))
	var compact:=(_tab=="equip" and G.inv_find(_sel_uid).is_empty()) or (_tab=="pending" and _sel_uid==0) or (_tab in ["mat","gem"] and _sel_supply.is_empty())
	var tray_h:=184.0 if compact else minf(340,safe.size.y*.42)
	tray_h=minf(tray_h,maxf(156,safe.size.y-376))
	var tray_top:=safe.size.y-tray_h-16
	Page.place(_list_plate,Vector2(12,196),Vector2(w-24,maxf(96,tray_top-204)))
	Page.place(_list,Vector2(24,208),Vector2(w-48,maxf(72,tray_top-228)))
	if _scroll.get_child_count()>0 and _scroll.get_child(0) is GridContainer:
		var grid:=_scroll.get_child(0) as GridContainer
		grid.columns=clampi(floori((_list.size.x+8)/104),2,6)
		for cell in grid.get_children():
			var cell_w:=floorf((_list.size.x-8*(grid.columns-1))/grid.columns)
			cell.custom_minimum_size = Vector2(cell_w,cell_w)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Page.place(_tray,Vector2(16,tray_top),Vector2(w-32,tray_h))
	Page.place(_detail,Vector2(38,tray_top+20),Vector2(w-76,tray_h-40))
	Page.place(_detail_scroll,Vector2(0,0),Vector2(_detail.size.x,maxf(48,_detail.size.y-(72 if not _action_buttons.is_empty() else 0))))
	Page.place(_actions,Vector2(0,maxf(0,_detail.size.y-64)),Vector2(_detail.size.x,64))
	var unit:=(_actions.size.x-16)/3.0
	for b in _action_buttons:
		match b.get_meta("action",""):
			"sell":Page.place(b,Vector2.ZERO,Vector2(unit,64))
			"lock":Page.place(b,Vector2(unit+8,0),Vector2(unit,64))
			_:Page.place(b,Vector2((unit+8)*2,0),Vector2(unit,64))

func _select_tab(key: String) -> void:
	if key=="pending" or _tab=="pending":_sel_uid=0
	_tab=key
	_confirm_uid=0
	_sel_supply=""
	_scroll.scroll_vertical=0
	Audio.sfx("ui_page")
	_refresh()
	_tab_buttons[key].grab_focus()

func _refresh() -> void:
	var offset:=_scroll.scroll_vertical
	Page.clear(_scroll)
	Page.clear(_detail_body)
	Page.clear(_actions)
	_item_buttons.clear()
	_action_buttons.clear()
	for key in _tab_buttons:
		_tab_buttons[key].selected=key==_tab
		_tab_buttons[key].queue_redraw()
	_count_l.text="装备 %d / %d" % [G.inv_count(),G.inv_capacity()]
	_count_l.add_theme_color_override("font_color",UI.RED if G.inv_count()>=G.inv_capacity() else UI.AGED)
	_pending_l.text="待领取 %d" % G.inv_pending().size()
	_gold.text="金币 "+UI.format_number(int(G.wallet.get("gold",0)))
	match _tab:
		"equip":_build_equip_tab()
		"mat":_build_supplies(false)
		"gem":_build_supplies(true)
		"pending":_build_pending_tab()
	Art.paper_ink(_detail_body)
	_resize_frame()
	_wire_focus()
	_scroll.set_deferred("scroll_vertical",offset)

func _grid() -> GridContainer:
	var grid:=GridContainer.new()
	grid.columns=clampi(floori((_list.size.x+8)/104),2,6)
	grid.name="EquipmentGrid" if _tab=="equip" else "SupplyGrid"
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_scroll.add_child(grid)
	return grid

func _min_grid_slots(count: int) -> int:
	var columns:=clampi(floori((_list.size.x+8)/104),2,6)
	var cell_width:=(_list.size.x-8*(columns-1))/columns
	var rows:=maxi(1,ceili((_list.size.y+8)/(cell_width+8)))
	return maxi(rows*columns,ceili(float(count)/columns)*columns)

func _build_equip_tab() -> void:
	var items:=_bag_items()
	var grid:=_grid()
	for inst in items:
		var cell:=Art.ItemCell.new()
		var uid:=int(inst.uid)
		var tpl:=G.equip_tpl(String(inst.tpl))
		cell.name="Equipment_"+str(uid)
		cell.set_meta("gear_uid",uid)
		cell.rarity=G.equip_rarity_color(int(inst.get("rarity",1)))
		cell.item_image.texture=Fix.item(String(inst.tpl))
		cell.rarity_rank=int(inst.get("rarity",1))
		cell.locked=bool(inst.get("locked",false))
		cell.heading.text=String(tpl.get("name","装备"))
		cell.show_name=true
		cell.image_px=54
		cell.flag.text="锁" if inst.get("locked",false) else ""
		cell.amount.text="+%d" % int(inst.get("lv",0))
		cell.selected=uid==_sel_uid
		cell.tooltip_text=String(tpl.get("name","装备"))+" · "+G.equip_rarity_name(int(inst.get("rarity",1)))
		cell.pressed.connect(_select_item.bind(uid))
		grid.add_child(cell)
		_item_buttons.append(cell)
	var min_slots: int = _min_grid_slots(items.size())
	for i in range(items.size(), min_slots):
		var empty_cell := Art.ItemCell.new()
		empty_cell.disabled = true
		empty_cell.focus_mode = Control.FOCUS_NONE
		grid.add_child(empty_cell)
	_build_detail()

func _select_item(uid: int) -> void:
	if _scroll.gesture_active():return
	_sel_uid=uid
	_confirm_uid=0
	_detail_scroll.scroll_vertical=0
	_refresh()
	for b in _item_buttons:
		if int(b.get_meta("gear_uid",0))==uid:b.grab_focus.call_deferred()
	if _tab=="pending":
		var preview:=find_child("PendingPreview_"+str(uid),true,false)
		if preview!=null:preview.grab_focus.call_deferred()

func _empty(words: String, hint: String) -> void:
	var box:=VBoxContainer.new()
	box.name="PendingEmptyState"
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.y=maxf(280,_list.size.y)
	box.alignment=BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation",12)
	_scroll.add_child(box)
	var picture:=Page.picture(Art.texture("chest"),Vector2(260,220))
	picture.name="PendingChestArtwork"
	picture.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	box.add_child(picture)
	var heading:=Art.label(words,"object",Art.GOLD)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var caption:=Art.label(hint,"caption",Art.MUTED)
	caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)

func _build_detail() -> void:
	var inst:=G.inv_find(_sel_uid)
	if _tab=="pending":
		inst={}
		for pending in G.inv_pending():
			if int(pending.uid)==_sel_uid:inst=pending;break
	if inst.is_empty():
		_detail_body.add_child(Page.line("选中器物，查看详情与比较","section"))
		_detail_body.add_child(Page.line("品质从高到低排列；装备后可在养成中强化与镶嵌。","caption",UI.AGED))
		return
	var uid:=int(inst.uid)
	var tpl:=G.equip_tpl(String(inst.tpl))
	var slot:=String(inst.get("slot",""))
	var worn:=G.inv_worn_uids().has(uid)
	var top:=HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_detail_body.add_child(top)
	var icon_cell := Art.ItemCell.new()
	icon_cell.custom_minimum_size = Vector2(64, 64)
	icon_cell.size = Vector2(64, 64)
	icon_cell.rarity_rank = int(inst.get("rarity", 1))
	icon_cell.rarity = G.equip_rarity_color(icon_cell.rarity_rank)
	icon_cell.item_image.texture = Fix.item(String(inst.tpl))
	icon_cell.image_px = 52
	icon_cell.disabled = true
	icon_cell.focus_mode = Control.FOCUS_NONE
	top.add_child(icon_cell)
	var names:=VBoxContainer.new()
	names.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var level:=int(tpl.get("requires_level",1))
	var source:=CampaignGear.source_text(inst)
	var mine:=G.equip_instance_bonus(inst)
	var theirs:=G.equip_slot_bonus(slot)
	var my_power := roundi(float(mine.get("atk", 0)) * 3.0 + float(mine.get("def", 0)) * 2.5 + float(mine.get("hp", 0)) * 0.4 + float(mine.get("crit", 0.0)) * 600.0)
	var cur_power := roundi(float(theirs.get("atk", 0)) * 3.0 + float(theirs.get("def", 0)) * 2.5 + float(theirs.get("hp", 0)) * 0.4 + float(theirs.get("crit", 0.0)) * 600.0)
	var p_delta := my_power - cur_power
	var p_tail := "持平" if p_delta == 0 else ("%+d%s" % [p_delta, "▲" if p_delta > 0 else "▼"])
	names.add_child(Page.line(String(tpl.get("name","装备")),"object",G.equip_rarity_color(int(inst.get("rarity",1))).darkened(.15)))
	names.add_child(Page.line("%s · +%d%s · 战力评估 %d(%s)" % [G.equip_rarity_name(int(inst.get("rarity",1))),int(inst.get("lv",0))," · 在身" if worn else "", my_power, p_tail],"caption",UI.AGED))
	var stat_box := PanelContainer.new()
	var stat_sb := StyleBoxFlat.new()
	stat_sb.bg_color = Color("987a4f", 0.16)
	stat_sb.border_color = Color("856843", 0.5)
	stat_sb.set_border_width_all(1)
	stat_sb.set_corner_radius_all(0)
	stat_sb.set_content_margin_all(4)
	stat_box.add_theme_stylebox_override("panel", stat_sb)
	_detail_body.add_child(stat_box)
	var stat_vbox := VBoxContainer.new()
	stat_vbox.add_theme_constant_override("separation", 2)
	stat_box.add_child(stat_vbox)
	stat_vbox.add_child(Page.line(" · ".join(_stat_parts(mine)),"body", UI.PAPER))
	var comparison:=HBoxContainer.new()
	comparison.name="EquipmentComparison"
	comparison.add_child(UI.label("对比已装备：","tag",UI.AGED))
	stat_vbox.add_child(comparison)
	var differences:=0
	for pair in [["atk","攻击"],["def","防御"],["hp","生命"],["crit","暴击"]]:
		var delta:=float(mine.get(pair[0],0))-float(theirs.get(pair[0],0))
		if absf(delta)<.0001:continue
		differences+=1
		comparison.add_child(UI.label("%s %+d%s %s" % [pair[1],roundi(delta*(100 if pair[0]=="crit" else 1)),"%" if pair[0]=="crit" else "","▲" if delta>0 else "▼"],"caption",UI.JADE if delta>0 else UI.RED))
	if differences==0:comparison.add_child(UI.label("与在身持平","caption",UI.AGED))
	_detail_body.add_child(Page.line("需求 Lv.%d"%level+(" · "+source if not source.is_empty() else ""),"caption",UI.RED if int(G.prog.get("level",1))<level else UI.AGED))
	if not String(tpl.get("special_desc","")).is_empty():_detail_body.add_child(Page.line(tpl.special_desc,"caption",UI.AGED))
	var sockets:=HBoxContainer.new()
	sockets.add_child(UI.label("宝石孔","caption",UI.AGED))
	for i in G.equip_gem_sockets():sockets.add_child(_socket_box(uid,inst.get("gems",[]),i))
	sockets.add_child(UI.label("可镶嵌 %d"%G.equip_gem_sockets(),"tag",UI.AGED))
	_detail_body.add_child(sockets)
	var affixes:PackedStringArray=[]
	for a in inst.get("affixes",[]):affixes.append(Page.affix_label(a)+("［锁］" if a.get("locked",false) else ""))
	if not affixes.is_empty():_detail_body.add_child(Page.line("词条："+" · ".join(affixes),"caption",UI.AGED))
	if _tab=="pending":
		_detail_body.add_child(Page.line("背包满时暂存于此。腾出装备格后可领取，查看详情不会领取或消耗资源。","caption",UI.AGED))
		var claim:=_action("领取","primary","wear",func():_toast_msg(_ok_msg(G.inv_claim(uid),"已领取"));_sel_uid=0;_refresh())
		claim.disabled=G.inv_count()>=G.inv_capacity()
		return
	var locked:=bool(inst.get("locked",false))
	var sell:=_action("卖出 %d 金" % G.inv_sell_price(uid),"secondary","sell",_do_sell.bind(uid))
	sell.caption.add_theme_font_size_override("font_size",G.FS_XS)
	sell.caption.add_theme_color_override("font_color",UI.RED)
	sell.disabled=locked or worn
	sell.tooltip_text="已锁定，不能卖出" if locked else "请先卸下装备" if worn else "高品质装备需再次确认"
	_action("解锁" if locked else "锁定","secondary","lock",func():
		_toast_msg(_ok_msg(G.inv_set_locked(uid,not locked),"已解锁" if locked else "已锁定"))
		_refresh())
	var wear:=_action("卸下" if worn else "装备","primary","wear",_do_equip_or_unequip.bind(uid,slot,worn))
	wear.disabled=not worn and int(G.prog.get("level",1))<level
	wear.tooltip_text="需求 Lv.%d，当前 Lv.%d" % [level,int(G.prog.get("level",1))] if wear.disabled else "卸下回背包" if worn else "装备到对应部位"

func _action(words: String,skin: String,id: String, callback: Callable) -> Button:
	var b:=Art.action(words,skin)
	b.set_meta("action",id)
	b.pressed.connect(func(): HapticFeedback.light())
	b.pressed.connect(callback)
	_actions.add_child(b)
	_action_buttons.append(b)
	return b

func _socket_box(uid:int,gems:Array,index:int) -> Button:
	var id:=String(gems[index]) if index<gems.size() else ""
	var b:=Page.GemSocket.new(G.res_tex(id) if not id.is_empty() else null)
	b.theme_type_variation="BagSocket"
	b.tooltip_text=G.gem_label(id)+" · 点击拆除" if not id.is_empty() else "空宝石孔 · 在装备中镶嵌"
	b.disabled=id.is_empty() or _tab=="pending"
	if not b.disabled:b.pressed.connect(func():_toast_msg(_ok_msg(G.inv_gem_pop(uid,index),"已拆除 "+G.gem_label(id)));_refresh())
	return b

func _build_supplies(gems: bool) -> void:
	var ids:Array[String]=[]
	for key in G.items:
		if String(key).begins_with("gem_")==gems and G.item_count(key)>0:ids.append(String(key))
	ids.sort()
	if not ids.has(_sel_supply):_sel_supply=""
	var grid:=_grid()
	for id in ids:
		var b:=Art.ItemCell.new()
		b.item_image.texture=G.res_tex(G.item_icon(id))
		b.heading.text=G.gem_label(id).replace("宝石","").replace(" ","") if gems else G.item_name(id)
		b.name="Supply_"+id
		b.tooltip_text=G.item_name(id)+" ×%d" % G.item_count(id)
		b.show_name=true
		b.image_px=54
		b.amount.text="×%d" % G.item_count(id)
		b.selected=id==_sel_supply
		b.set_meta("supply_id",id)
		b.pressed.connect(func():
			if _scroll.gesture_active():return
			_sel_supply=id
			_detail_scroll.scroll_vertical=0
			_refresh()
			for item in _item_buttons:
				if item.get_meta("supply_id","")==id:item.grab_focus.call_deferred())
		grid.add_child(b)
		_item_buttons.append(b)
	var min_slots: int = _min_grid_slots(ids.size())
	for i in range(ids.size(), min_slots):
		var empty_cell := Art.ItemCell.new()
		empty_cell.disabled = true
		empty_cell.focus_mode = Control.FOCUS_NONE
		grid.add_child(empty_cell)
	if ids.is_empty():
		_detail_body.add_child(Page.line("暂无宝石" if gems else "暂无材料", "section"))
		_detail_body.add_child(Page.line("沿途掉落和兑换所得会收纳在这里。", "caption", UI.AGED))
	_detail_body.add_child(Page.line(G.gem_label(_sel_supply) if gems and not _sel_supply.is_empty() else G.item_name(_sel_supply) if not _sel_supply.is_empty() else "宝石镶嵌与合成" if gems else "行旅材料","object"))
	if not _sel_supply.is_empty():
		_detail_body.add_child(Page.line("持有 ×%d · %s" % [G.item_count(_sel_supply),"宝石" if gems else "随行物品"],"body"))
		var description:=Page.line(Descriptions.describe(_sel_supply),"caption",UI.AGED)
		description.name="ItemUsage"
		_detail_body.add_child(description)
	_detail_body.add_child(Page.line("可堆叠，不占装备格。点击上方物品可切换说明。","caption",UI.AGED))

func _build_pending_tab() -> void:
	var box:=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",8)
	_scroll.add_child(box)
	for inst in G.inv_pending():
		var row:=HBoxContainer.new()
		row.custom_minimum_size.y=64
		box.add_child(row)
		var tpl:=G.equip_tpl(String(inst.tpl))
		var preview:=Art.ItemCell.new()
		preview.name="PendingPreview_"+str(inst.uid)
		preview.item_image.texture=Fix.item(String(inst.tpl))
		preview.custom_minimum_size=Vector2(56,56)
		preview.image_px=42
		preview.selected=int(inst.uid)==_sel_uid
		preview.pressed.connect(_select_item.bind(int(inst.uid)))
		row.add_child(preview)
		var title:=Page.line("%s
%s · 强化 +%d" % [tpl.get("name","装备"),G.equip_rarity_name(int(inst.get("rarity",1))),int(inst.get("lv",0))],"body")
		row.add_child(title)
		var b:=Art.action("领取","primary")
		var uid:=int(inst.uid)
		b.custom_minimum_size=Vector2(80,56)
		b.set_meta("gear_uid",uid)
		b.disabled=G.inv_count()>=G.inv_capacity()
		b.tooltip_text="背包已满，先腾出装备格" if b.disabled else "领取到背包"
		b.pressed.connect(func():_toast_msg(_ok_msg(G.inv_claim(uid),"已领取"));_refresh())
		row.add_child(b)
		_item_buttons.append(b)
	if G.inv_pending().is_empty():_empty("暂无待领取物品","背包满时，掉落将暂存于此")
	if _sel_uid!=0:_build_detail()
	else:
		_detail_body.add_child(Page.line("点击物品图标，预览装备详情","section"))
		_detail_body.add_child(Page.line("待领取物品会保留在这里。腾出装备格后可领取。","caption",UI.AGED))

func _wire_focus() -> void:
	var available:Array[Button]=[]
	_collect_buttons(_panel_root,available)
	for i in available.size():
		available[i].focus_next=available[(i+1)%available.size()].get_path()
		available[i].focus_previous=available[posmod(i-1,available.size())].get_path()
	for key in _tab_buttons:_tab_buttons[key].focus_neighbor_bottom=NodePath()
	if _item_buttons.is_empty():return
	_tab_buttons[_tab].focus_neighbor_bottom=_item_buttons[0].get_path()
	var columns := 1
	if _scroll.get_child_count()>0 and _scroll.get_child(0) is GridContainer:
		columns = (_scroll.get_child(0) as GridContainer).columns
	for i in _item_buttons.size():
		var b:=_item_buttons[i]
		b.focus_neighbor_top=_item_buttons[i-columns].get_path() if i>=columns else _tab_buttons[_tab].get_path()
		b.focus_neighbor_bottom=_item_buttons[i+columns].get_path() if i+columns<_item_buttons.size() else _close_btn.get_path()
		b.focus_entered.connect(func():
			if not _scroll.gesture_active() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_scroll.ensure_control_visible(b))

func _collect_buttons(root: Node,out: Array[Button]) -> void:
	for child in root.get_children():
		if child is Button and not child.disabled:out.append(child)
		_collect_buttons(child,out)

func _toast_msg(msg: String) -> void:
	if is_instance_valid(_toast):_toast.queue_free()
	_toast=UI.toast(self,msg)
	_toast.z_index=UI.Z_FEEDBACK

func _close() -> void:
	if is_instance_valid(_focus_return):_focus_return.grab_focus.call_deferred()
	G.close_page(self, func(): closed.emit())

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _bag_items() -> Array:
	var worn := G.inv_worn_uids()
	var out: Array = []
	for it in G.inv_instances():
		var d := it as Dictionary
		if not worn.has(int(d.get("uid", 0))):
			out.append(d)
	out.sort_custom(func(a, b):
		var ra := int((a as Dictionary).get("rarity", 1))
		var rb := int((b as Dictionary).get("rarity", 1))
		if ra != rb:
			return ra > rb
		return int((a as Dictionary).get("uid", 0)) < int((b as Dictionary).get("uid", 0)))
	return out



func _do_equip_or_unequip(uid: int, slot: String, worn: bool) -> void:
	var r: Dictionary
	if worn:
		r = G.inv_unequip(slot)
	else:
		r = G.inv_equip(uid)
	_toast_msg(_ok_msg(r, "已换上" if not worn else "已卸下"))
	_refresh()


func _do_sell(uid: int) -> void:
	var confirm := _confirm_uid == uid
	var r := G.inv_sell(uid, confirm)
	if bool(r.get("need_confirm", false)):
		_modal=Page.confirm(self,"卖出高品质装备","卖出后获得 %d 金币，确认继续？" % G.inv_sell_price(uid),func(): _confirm_uid=uid; _do_sell(uid))
		_modal.closed.connect(func():_confirm_uid=0)
		return
	if bool(r.get("ok", false)):
		_confirm_uid = 0
		_sel_uid = 0
		_toast_msg("已卖出 · 铜钱 +%d" % int(r.get("gold", 0)))
	else:
		_toast_msg(String(r.get("err", "")))
	_refresh()


func _ok_msg(r: Dictionary, ok_text: String) -> String:
	return ok_text if bool(r.get("ok", false)) else String(r.get("err", ""))


## 与在身同槽实例的比较文案（攻击 +2 / 攻击 -2 / 持平）
func _compare_text(slot: String, inst: Dictionary) -> String:
	var other := G.equip_state(slot)
	if slot.is_empty():
		return ""
	if other.is_empty():
		return "比较：该部位未装备，换上即为当前面板"
	var mine := G.equip_instance_bonus(inst)
	var theirs := G.equip_instance_bonus(other)
	var names := {"atk": "攻击", "def": "防御", "hp": "生命"}
	var parts := PackedStringArray()
	for k in ["atk", "def", "hp"]:
		var d := int(mine.get(k, 0)) - int(theirs.get(k, 0))
		if d > 0:
			parts.append("%s +%d" % [String(names[k]), d])
		elif d < 0:
			parts.append("%s %d" % [String(names[k]), d])
	var dc := float(mine.get("crit", 0.0)) - float(theirs.get("crit", 0.0))
	if absf(dc) > 0.0001:
		parts.append("暴击 %+d%%" % roundi(dc * 100.0))
	if parts.is_empty():
		return "比较：与在身持平"
	return "比较：" + " · ".join(parts)


func _stat_parts(bonus: Dictionary) -> PackedStringArray:
	var parts := PackedStringArray()
	if int(bonus.get("atk", 0)) > 0:
		parts.append("攻击 +%d" % int(bonus["atk"]))
	if int(bonus.get("def", 0)) > 0:
		parts.append("防御 +%d" % int(bonus["def"]))
	if int(bonus.get("hp", 0)) > 0:
		parts.append("生命 +%d" % int(bonus["hp"]))
	if float(bonus.get("crit", 0.0)) > 0.0:
		parts.append("暴击 +%d%%" % roundi(float(bonus["crit"]) * 100.0))
	return parts
