# BagPanel.gd — full-page travel chest, 5-column scrolling inventory.
class_name BagPanel
extends Control
signal closed
const UI := preload("res://src/ui/TravelChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
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
var _tabs: HBoxContainer
var _list: Control
var _scroll: ScrollContainer
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _focus_return==null: _focus_return=get_viewport().gui_get_focus_owner()
	theme=UI.theme()
	_build()
	get_viewport().size_changed.connect(_resize_frame)
	_refresh()
	_tab_buttons[_tab].grab_focus.call_deferred()

func _build() -> void:
	_stage=Fix.ContextStage.new("chest")
	add_child(_stage)
	_panel_root=Control.new()
	_panel_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)
	_close_btn=UI.action("‹","back")
	_close_btn.name="ReturnButton"
	_close_btn.tooltip_text="返回"
	_close_btn.pressed.connect(_close)
	_panel_root.add_child(_close_btn)
	_banner=UI.label("行旅背包","title")
	_panel_root.add_child(_banner)
	_count_l=UI.label("","caption",UI.AGED)
	_count_l.name="Capacity"
	_panel_root.add_child(_count_l)
	_pending_l=UI.label("","caption",UI.AGED)
	_panel_root.add_child(_pending_l)
	_gold=UI.label("","number",UI.GOLD)
	_gold.name="GoldBalance"
	_gold.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_panel_root.add_child(_gold)
	_tabs=HBoxContainer.new()
	_tabs.name="Categories"
	_tabs.add_theme_constant_override("separation",4)
	_panel_root.add_child(_tabs)
	for entry in TABS:
		var key: String=entry[0]
		var b=UI.action(entry[1],"tab")
		b.custom_minimum_size.y=44
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.name="Tab_"+key
		b.pressed.connect(_select_tab.bind(key))
		_tabs.add_child(b)
		_tab_buttons[key]=b
	_list=Control.new()
	_list.name="Items"
	_panel_root.add_child(_list)
	_scroll=Page.scroll()
	_scroll.name="ItemScroll"
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list.add_child(_scroll)
	_tray=UI.Tray.new()
	_panel_root.add_child(_tray)
	_detail=Control.new()
	_detail.name="SelectedItemDetail"
	_panel_root.add_child(_detail)
	_detail_scroll=Page.scroll()
	_detail_scroll.name="DetailScroll"
	_detail.add_child(_detail_scroll)
	_detail_body=VBoxContainer.new()
	_detail_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation",6)
	_detail_scroll.add_child(_detail_body)
	_actions=Control.new()
	_actions.name="EquipmentActions"
	_detail.add_child(_actions)
	_resize_frame()

func _resize_frame(safe_override: Rect2=Rect2()) -> void:
	if _panel_root==null:return
	var safe:=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	Page.place(_stage,Vector2.ZERO,get_viewport_rect().size)
	Page.place(_panel_root,safe.position,safe.size)
	Page.place(_close_btn,Vector2(8,6),Vector2(44,44))
	Page.place(_banner,Vector2(64,8),Vector2(300,40))
	Page.place(_count_l,Vector2(12,52),Vector2(176,44))
	Page.place(_pending_l,Vector2(172,52),Vector2(130,44))
	Page.place(_gold,Vector2(safe.size.x-172,52),Vector2(160,44))
	Page.place(_tabs,Vector2(12,100),Vector2(safe.size.x-24,44))
	var tray_top:=safe.size.y-328
	Page.place(_list,Vector2(12,152),Vector2(safe.size.x-24,maxf(148,tray_top-156)))
	if _scroll.get_child_count()>0 and _scroll.get_child(0) is GridContainer:
		for cell in _scroll.get_child(0).get_children():
			cell.custom_minimum_size.x = floorf((_list.size.x-36)/5)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Page.place(_tray,Vector2(0,tray_top),Vector2(safe.size.x,328))
	Page.place(_detail,Vector2(12,tray_top+16),Vector2(safe.size.x-24,300))
	Page.place(_detail_scroll,Vector2(8,0),Vector2(_detail.size.x-16,232))
	Page.place(_actions,Vector2(0,244),Vector2(_detail.size.x,56))
	for b in _action_buttons:
		match b.get_meta("action",""):
			"sell":Page.place(b,Vector2.ZERO,Vector2(120,56))
			"lock":Page.place(b,Vector2(128,0),Vector2(56,56))
			_:Page.place(b,Vector2(192,0),Vector2(_actions.size.x-192,56))

func _select_tab(key: String) -> void:
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
	_resize_frame()
	_wire_focus()
	_scroll.set_deferred("scroll_vertical",offset)

func _grid() -> GridContainer:
	var grid:=GridContainer.new()
	grid.columns=5
	grid.name="EquipmentGrid" if _tab=="equip" else "SupplyGrid"
	grid.add_theme_constant_override("h_separation",9)
	grid.add_theme_constant_override("v_separation",8)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_scroll.add_child(grid)
	return grid

func _build_equip_tab() -> void:
	var items:=_bag_items()
	var grid:=_grid()
	for inst in items:
		var cell:=Page.ItemCell.new()
		var uid:=int(inst.uid)
		var tpl:=G.equip_tpl(String(inst.tpl))
		cell.name="Equipment_"+str(uid)
		cell.set_meta("gear_uid",uid)
		cell.rarity=G.equip_rarity_color(int(inst.get("rarity",1)))
		cell.item_image.texture=Fix.item(String(inst.tpl))
		cell.rarity_rank=int(inst.get("rarity",1))
		cell.locked=bool(inst.get("locked",false))
		cell.heading.text=String(tpl.get("name","装备"))
		cell.flag.text="锁" if inst.get("locked",false) else ""
		cell.amount.text="+%d" % int(inst.get("lv",0))
		cell.selected=uid==_sel_uid
		cell.tooltip_text=String(tpl.get("name","装备"))+" · "+G.equip_rarity_name(int(inst.get("rarity",1)))
		cell.pressed.connect(_select_item.bind(uid))
		grid.add_child(cell)
		_item_buttons.append(cell)
	if items.is_empty():_empty("背包里没有装备","沿途掉落会自动入包，满包后存入待领取箱。")
	_build_detail()

func _select_item(uid: int) -> void:
	_sel_uid=uid
	_confirm_uid=0
	_detail_scroll.scroll_vertical=0
	_refresh()
	for b in _item_buttons:
		if int(b.get_meta("gear_uid",0))==uid:b.grab_focus.call_deferred()

func _empty(words: String, hint: String) -> void:
	var box:=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_scroll.add_child(box)
	box.add_child(Page.line(words,"section"))
	box.add_child(Page.line(hint,"caption",UI.AGED))

func _build_detail() -> void:
	var inst:=G.inv_find(_sel_uid)
	if inst.is_empty():
		_detail_body.add_child(Page.line("选中器物，查看详情与比较","section"))
		_detail_body.add_child(Page.line("品质从高到低排列；装备后可在养成中强化与镶嵌。","caption",UI.AGED))
		return
	var uid:=int(inst.uid)
	var tpl:=G.equip_tpl(String(inst.tpl))
	var slot:=String(inst.get("slot",""))
	var worn:=G.inv_worn_uids().has(uid)
	var top:=HBoxContainer.new()
	_detail_body.add_child(top)
	top.add_child(Page.picture(Fix.item(String(inst.tpl)),Vector2(80,80)))
	var names:=VBoxContainer.new()
	names.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(names)
	names.add_child(Page.line(String(tpl.get("name","装备")),"object",G.equip_rarity_color(int(inst.get("rarity",1))).darkened(.15)))
	names.add_child(Page.line("%s · 强化 +%d%s" % [G.equip_rarity_name(int(inst.get("rarity",1))),int(inst.get("lv",0))," · 在身" if worn else ""],"caption",UI.AGED))
	_detail_body.add_child(Page.line(" · ".join(_stat_parts(G.equip_instance_bonus(inst))),"body"))
	var comparison:=HBoxContainer.new()
	comparison.name="EquipmentComparison"
	comparison.add_child(UI.label("对比已装备：","tag",UI.AGED))
	_detail_body.add_child(comparison)
	var mine:=G.equip_instance_bonus(inst)
	var theirs:=G.equip_slot_bonus(slot)
	var differences:=0
	for pair in [["atk","攻击"],["def","防御"],["hp","生命"],["crit","暴击"]]:
		var delta:=float(mine.get(pair[0],0))-float(theirs.get(pair[0],0))
		if absf(delta)<.0001:continue
		differences+=1
		comparison.add_child(UI.label("%s %+d%s %s" % [pair[1],roundi(delta*(100 if pair[0]=="crit" else 1)),"%" if pair[0]=="crit" else "","▲" if delta>0 else "▼"],"caption",UI.JADE if delta>0 else UI.RED))
	if differences==0:comparison.add_child(UI.label("与在身持平","caption",UI.AGED))
	var level:=int(tpl.get("requires_level",1))
	var source:=CampaignGear.source_text(inst)
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
	var locked:=bool(inst.get("locked",false))
	var sell:=_action("卖出 %d 金" % G.inv_sell_price(uid),"secondary","sell",_do_sell.bind(uid))
	sell.caption.add_theme_font_size_override("font_size",14)
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
	var b:=UI.action(words,skin)
	b.set_meta("action",id)
	b.pressed.connect(callback)
	_actions.add_child(b)
	_action_buttons.append(b)
	return b

func _socket_box(uid:int,gems:Array,index:int) -> Button:
	var id:=String(gems[index]) if index<gems.size() else ""
	var b:=Page.GemSocket.new(G.res_tex(id) if not id.is_empty() else null)
	b.theme_type_variation="BagSocket"
	b.tooltip_text=G.gem_label(id)+" · 点击拆除" if not id.is_empty() else "空宝石孔 · 在装备中镶嵌"
	b.disabled=id.is_empty()
	if not id.is_empty():b.pressed.connect(func():_toast_msg(_ok_msg(G.inv_gem_pop(uid,index),"已拆除 "+G.gem_label(id)));_refresh())
	return b

func _build_supplies(gems: bool) -> void:
	var ids:Array[String]=[]
	for key in G.items:
		if String(key).begins_with("gem_")==gems and G.item_count(key)>0:ids.append(String(key))
	ids.sort()
	var grid:=_grid()
	for id in ids:
		var b:=Page.ItemCell.new()
		b.item_image.texture=G.res_tex(G.item_icon(id))
		b.heading.text=G.gem_label(id) if gems else G.item_name(id)
		b.amount.text="×%d" % G.item_count(id)
		b.selected=id==_sel_supply
		b.set_meta("supply_id",id)
		b.pressed.connect(func():_sel_supply=id;_refresh())
		grid.add_child(b)
		_item_buttons.append(b)
	if ids.is_empty():_empty("暂无宝石" if gems else "暂无材料","沿途掉落和兑换所得会收纳在这里。")
	_detail_body.add_child(Page.line(G.gem_label(_sel_supply) if gems and not _sel_supply.is_empty() else G.item_name(_sel_supply) if not _sel_supply.is_empty() else "宝石镶嵌与合成" if gems else "行旅材料","object"))
	if not _sel_supply.is_empty():_detail_body.add_child(Page.line("持有 ×%d%s" % [G.item_count(_sel_supply)," · 属性加成 +%d" % G.equip_gem_value(_sel_supply) if gems else ""],"body"))
	_detail_body.add_child(Page.line("3 颗同级同色宝石可合成更高级宝石；前往养成 → 装备 → 宝石。" if gems else "材料可堆叠，不占装备格。强化、精炼等加工操作位于养成 → 装备。","caption",UI.AGED))

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
		row.add_child(Page.picture(Fix.item(String(inst.tpl)),Vector2(48,48)))
		var title:=Page.line("%s
%s · 强化 +%d" % [tpl.get("name","装备"),G.equip_rarity_name(int(inst.get("rarity",1))),int(inst.get("lv",0))],"body")
		row.add_child(title)
		var b:=UI.action("领取","secondary")
		var uid:=int(inst.uid)
		b.custom_minimum_size=Vector2(80,56)
		b.set_meta("gear_uid",uid)
		b.disabled=G.inv_count()>=G.inv_capacity()
		b.tooltip_text="背包已满，先腾出装备格" if b.disabled else "领取到背包"
		b.pressed.connect(func():_toast_msg(_ok_msg(G.inv_claim(uid),"已领取"));_refresh())
		row.add_child(b)
		_item_buttons.append(b)
	if G.inv_pending().is_empty():_empty("待领取箱是空的","背包满时，沿途掉落会暂存这里。")
	_detail_body.add_child(Page.line("待领取物品会保留在这里","section"))
	_detail_body.add_child(Page.line("腾出装备格后即可领取；领取不会额外消耗资源。","caption",UI.AGED))

func _wire_focus() -> void:
	var available:Array[Button]=[]
	_collect_buttons(_panel_root,available)
	for i in available.size():
		available[i].focus_next=available[(i+1)%available.size()].get_path()
		available[i].focus_previous=available[posmod(i-1,available.size())].get_path()
	for key in _tab_buttons:_tab_buttons[key].focus_neighbor_bottom=NodePath()
	if _item_buttons.is_empty():return
	_tab_buttons[_tab].focus_neighbor_bottom=_item_buttons[0].get_path()
	for i in _item_buttons.size():
		var b:=_item_buttons[i]
		b.focus_neighbor_top=_item_buttons[i-5].get_path() if i>=5 and _tab!="pending" else _tab_buttons[_tab].get_path()
		b.focus_neighbor_bottom=_item_buttons[i+5].get_path() if i+5<_item_buttons.size() and _tab!="pending" else _close_btn.get_path()
		b.focus_entered.connect(func():_scroll.ensure_control_visible(b))

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
	closed.emit()

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
