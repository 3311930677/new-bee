# BagPanel.gd — container layout and inherited inventory theme; actions use G.inv_*.
class_name BagPanel
extends Control
signal closed

const BagTheme := preload("res://src/ui/InventoryTheme.gd")
const Craft := preload("res://src/ui/CraftUI.gd")
const VIEW_W := 480.0
const CONTENT_W := 408.0
const ROWS_PER_PAGE := 8
const TABS := [["equip","装备"],["mat","材料"],["gem","宝石"],["pending","待领取"]]
var _tab := "equip"
var _page := 0
var _sel_uid := 0
var _confirm_uid := 0
var _tabs: HBoxContainer
var _list: VBoxContainer
var _detail: PanelContainer
var _count_l: Label
var _toast: Label
var _toast_tween: Tween
var _panel_root: PanelContainer
var _banner: Control
var _close_btn: Button
var _center: CenterContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _pending_l: Label
var _tab_buttons: Dictionary = {}
var _item_buttons: Array[Button] = []
var _action_buttons: Array[Button] = []
var _focus_return: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _focus_return==null: _focus_return = get_viewport().gui_get_focus_owner()
	theme = BagTheme.create()
	_build()
	resized.connect(_resize_frame)
	_refresh()
	_tab_buttons[_tab].grab_focus.call_deferred()

func _label(words: String,kind := "",wrap := false) -> Label:
	var l := Label.new()
	l.text = words
	l.theme_type_variation = kind
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _button(words: String,kind := "",width := 0.0) -> Button:
	var b := InventoryAction.new()
	b.text = words
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.theme_type_variation = kind
	b.custom_minimum_size = Vector2(width,44)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if words == "领取": G.Feedback.mark_ready(b)
	return b

func _icon(tex: Texture2D,extent: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = extent
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _build() -> void:
	G.veil(self,.80)
	_center = CenterContainer.new()
	_center.name = "InventoryFrameLayout"
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_panel_root = InventoryFrame.new()
	_panel_root.name = "InventoryWindow"
	_panel_root.theme_type_variation = "BagWindow"
	_center.add_child(_panel_root)
	_content = VBoxContainer.new()
	_content.name = "InventoryContent"
	_panel_root.add_child(_content)
	var heading := HBoxContainer.new()
	heading.custom_minimum_size.y = 52
	_banner = heading
	_content.add_child(heading)
	var emblem := Craft.Field.Prop.new()
	emblem.key = "bag"
	emblem.custom_minimum_size = Vector2(42,42)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(emblem)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation",0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(titles)
	titles.add_child(_label("行旅背包","BagTitle"))
	titles.add_child(_label("整备随身器物 · 保管沿途收获","BagMuted"))
	var close := _button("×","",44)
	close.name = "CloseInventory"
	close.tooltip_text = "返回"
	close.pressed.connect(_close)
	heading.add_child(close)
	var summary := HBoxContainer.new()
	summary.name = "InventorySummary"
	summary.custom_minimum_size.y = 28
	_content.add_child(summary)
	_count_l = _label("","BagMuted")
	_count_l.name = "Capacity"
	_count_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_l.tooltip_text = "装备占用 / 容量；在身装备、材料和宝石不占格"
	summary.add_child(_count_l)
	_pending_l = _label("","BagMuted")
	summary.add_child(_pending_l)
	summary.add_child(_icon(G.res_tex("cur_gold"),Vector2(18,18)))
	var gold := _label(str(G.wallet.get("gold",0)),"BagMuted")
	gold.name = "GoldBalance"
	summary.add_child(gold)
	_tabs = HBoxContainer.new()
	_tabs.name = "Categories"
	_tabs.add_theme_constant_override("separation",4)
	_content.add_child(_tabs)
	for entry in TABS:
		var key: String = entry[0]
		var button := _button(entry[1],"BagTab")
		button.name = "Tab_"+key
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(key))
		_tabs.add_child(button)
		_tab_buttons[key] = button
	_list = VBoxContainer.new()
	_list.name = "ItemsAndPagination"
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size.y = 100
	_content.add_child(_list)
	_detail = PanelContainer.new()
	_detail.name = "SelectedItemDetail"
	_detail.theme_type_variation = "BagDetail"
	_detail.theme = BagTheme.detail()
	_content.add_child(_detail)
	var footer := HBoxContainer.new()
	footer.name = "InventoryFooter"
	_content.add_child(footer)
	var note := _label("材料与宝石不占背包格","BagMuted",true)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(note)
	_close_btn = _button("返回","",104)
	_close_btn.name = "ReturnButton"
	_close_btn.pressed.connect(_close)
	footer.add_child(_close_btn)
	_resize_frame()

func _resize_frame() -> void:
	if _panel_root == null: return
	var safe := G.ui_safe_rect(self)
	_center.offset_left = safe.position.x
	_center.offset_top = safe.position.y
	_center.offset_right = safe.end.x-size.x
	_center.offset_bottom = safe.end.y-size.y
	var preferred_height := 760.0 if _tab=="equip" else 900.0
	_panel_root.custom_minimum_size = Vector2(minf(448,safe.size.x-24),minf(preferred_height,safe.size.y-48))
	_detail.custom_minimum_size.y = minf(236,safe.size.y*.30) if _tab=="equip" else 92

func _select_tab(key: String) -> void:
	_tab = key
	_page = 0
	_confirm_uid = 0
	Audio.sfx("ui_page")
	_refresh()
	_tab_buttons[key].grab_focus()

func _refresh() -> void:
	var focus_uid := 0
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null: focus_uid = int(focused.get_meta("gear_uid",0))
	_clear(_list)
	_clear(_detail)
	_item_buttons.clear()
	_action_buttons.clear()
	for key in _tab_buttons:
		var b: Button = _tab_buttons[key]
		b.theme_type_variation = "BagSelectedTab" if key==_tab else "BagTab"
		b.set_meta("tab_selected",key==_tab)
	_count_l.text = "已用 %d/%d" % [G.inv_count(),G.inv_capacity()]
	_pending_l.text = "待领 %d" % G.inv_pending().size() if not G.inv_pending().is_empty() else ""
	(_content.find_child("GoldBalance",true,false) as Label).text = str(G.wallet.get("gold",0))
	_scroll = ScrollContainer.new()
	_scroll.name = "ItemScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 6
	_list.add_child(_scroll)
	match _tab:
		"equip": _build_equip_tab()
		"mat": _build_supplies(false)
		"gem": _build_supplies(true)
		"pending": _build_pending_tab()
	_resize_frame()
	_wire_focus()
	if focus_uid>0:
		for b in _item_buttons:
			if int(b.get_meta("gear_uid",0))==focus_uid: b.grab_focus.call_deferred()

func _pager(pages: int,total: int) -> void:
	var row := HBoxContainer.new()
	row.name = "Pagination"
	_list.add_child(row)
	var label := _label("%d 件 · %d/%d 页" % [total,_page+1,pages],"BagMuted")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	for data in [["◀",-1],["▶",1]]:
		var b := _button(data[0],"",44)
		b.tooltip_text = "上一页" if data[1]<0 else "下一页"
		b.disabled = _page==0 if data[1]<0 else _page==pages-1
		b.pressed.connect(_change_page.bind(data[1],pages))
		row.add_child(b)

func _change_page(step: int,pages: int) -> void:
	_page = clampi(_page+step,0,pages-1)
	Audio.sfx("ui_page")
	_refresh()
	if not _item_buttons.is_empty(): _item_buttons[0].grab_focus.call_deferred()

func _empty(words: String,hint: String) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 280
	center.add_child(box)
	var icon := G.ui_icon("bag",Vector2(48,48))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var title := _label(words,"BagItemTitle",true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var l := _label(hint,"BagMuted",true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)

func _build_equip_tab() -> void:
	var items := _bag_items()
	var pages := maxi(1,ceili(float(items.size())/ROWS_PER_PAGE))
	_page = clampi(_page,0,pages-1)
	if items.is_empty():
		_empty("背包里没有装备","沿途掉落会自动入包，满包后存入待领取箱。")
	else:
		var grid := GridContainer.new()
		grid.name = "EquipmentGrid"
		grid.columns = 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.add_child(grid)
		for index in range(_page*ROWS_PER_PAGE,mini((_page+1)*ROWS_PER_PAGE,items.size())):
			grid.add_child(_item_row(items[index]))
		_pager(pages,items.size())
	_build_detail()

func _item_row(inst: Dictionary) -> Control:
	var uid := int(inst.get("uid",0))
	var rarity := int(inst.get("rarity",1))
	var tpl := G.equip_tpl(String(inst.get("tpl","")))
	var b := _button("","BagSelectedGear" if uid==_sel_uid else "BagGear")
	b.name = "Equipment_"+str(uid)
	b.set_meta("gear_uid",uid)
	b.set_meta("rarity_accent",G.equip_rarity_color(rarity))
	b.custom_minimum_size = Vector2(80,108)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "%s · %s · 强化 +%d%s" % [tpl.get("name","装备"),G.equip_rarity_name(rarity),int(inst.get("lv",0))," · 已锁定" if inst.get("locked",false) else ""]
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	var meta := HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meta)
	var rank := _label(G.equip_rarity_name(rarity),"BagMuted")
	rank.add_theme_color_override("font_color",G.equip_rarity_color(rarity).lightened(.30))
	rank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(rank)
	meta.add_child(_label("锁" if inst.get("locked",false) else "+%d" % int(inst.get("lv",0)),"BagMuted"))
	var icon := _icon(G.res_tex(String(tpl.get("icon",""))),Vector2(48,48))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var name_l := _label(String(tpl.get("name","装备")))
	name_l.add_theme_font_size_override("font_size",14)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_l)
	b.pressed.connect(_select_item.bind(uid))
	_item_buttons.append(b)
	return b

class InventoryFrame extends PanelContainer:
	func _draw() -> void:
		var edge := Color("a88b55")
		for p in [Vector2(4,4),Vector2(size.x-4,4),Vector2(4,size.y-4),size-Vector2(4,4)]:
			var direction := Vector2(1 if p.x<size.x*.5 else -1,1 if p.y<size.y*.5 else -1)
			draw_line(p,p+Vector2(15*direction.x,0),edge,1)
			draw_line(p,p+Vector2(0,15*direction.y),edge,1)
		draw_line(Vector2(24,2),Vector2(size.x-24,2),Color("f8edd3",.7),1)
		draw_line(Vector2(16,83),Vector2(size.x-16,83),Color("d6b981",.25),1)

class InventoryAction extends Button:
	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	func _draw() -> void:
		if disabled: return
		var accent: Color = get_meta("rarity_accent",Color("a88b55"))
		if theme_type_variation in ["BagGear","BagSelectedGear"]:
			var center := Vector2(size.x*.5,53)
			draw_circle(center,25,Color(accent,.055))
			draw_arc(center,25,PI*.12,PI*.88,24,Color(accent,.28),1,true)
			draw_line(Vector2(8,1),Vector2(size.x-8,1),Color(accent,.60),1)
		if theme_type_variation == "BagSelectedGear":
			draw_rect(Rect2(8,size.y-3,size.x-16,2),Color(accent,.9))
			draw_colored_polygon(PackedVector2Array([Vector2(size.x-11,2),Vector2(size.x-2,2),Vector2(size.x-2,11)]),Color("f3d595"))
		elif theme_type_variation == "BagSelectedTab":
			draw_line(Vector2(12,size.y-3),Vector2(size.x-12,size.y-3),Color("fff0c3",.65),1)
		elif is_hovered() and size.x>50:
			draw_line(Vector2(10,size.y-2),Vector2(size.x-10,size.y-2),Color(accent,.5),1)

func _select_item(uid: int) -> void:
	_sel_uid = uid
	_confirm_uid = 0
	_refresh()
	for b in _item_buttons:
		if int(b.get_meta("gear_uid",0))==uid: b.grab_focus.call_deferred()

func _detail_body() -> VBoxContainer:
	var outer := VBoxContainer.new()
	_detail.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().custom_minimum_size.x = 6
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",6)
	scroll.add_child(body)
	return body

func _build_detail() -> void:
	var inst := G.inv_find(_sel_uid)
	var body := _detail_body()
	if inst.is_empty():
		body.add_child(_label("选中一件装备查看详情与比较","BagItemTitle",true))
		body.add_child(_label("品质从高到低排列；装备后可在养成中强化与镶嵌。","BagMuted",true))
		return
	var uid := int(inst.uid)
	var tpl := G.equip_tpl(String(inst.tpl))
	var slot := String(inst.get("slot",""))
	var worn := G.inv_worn_uids().has(uid)
	var rarity := int(inst.get("rarity",1))
	var top := HBoxContainer.new()
	body.add_child(top)
	top.add_child(_icon(G.res_tex(String(tpl.get("icon",""))),Vector2(60,60)))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation",2)
	top.add_child(titles)
	var title := _label(String(tpl.get("name","装备")),"BagItemTitle",true)
	title.add_theme_color_override("font_color",G.paper_ink(G.equip_rarity_color(rarity)))
	titles.add_child(title)
	titles.add_child(_label("%s · 强化 +%d%s" % [G.equip_rarity_name(rarity),int(inst.get("lv",0))," · 在身" if worn else ""],"BagMuted"))
	body.add_child(_label(" · ".join(_stat_parts(G.equip_instance_bonus(inst))),"",true))
	var compare := _label(_compare_text(slot,inst),"BagMuted",true)
	compare.name = "EquipmentComparison"
	body.add_child(compare)
	var source := CampaignGear.source_text(inst)
	var requirement := "需求 Lv%d" % int(tpl.get("requires_level",1))
	body.add_child(_label(requirement + (" · " + source if not source.is_empty() else ""),"BagMuted",true))
	if not String(tpl.get("special_desc", "")).is_empty():
		body.add_child(_label(String(tpl.special_desc),"BagMuted",true))
	var sockets := HBoxContainer.new()
	sockets.add_child(_label("宝石孔","BagMuted"))
	var gems: Array = inst.get("gems",[])
	for index in int(G.equip_cfg().get("gem_slots",3)):
		sockets.add_child(_socket_box(uid,gems,index))
	body.add_child(sockets)
	var affixes: Array = inst.get("affixes",[])
	var words: PackedStringArray = []
	for entry in affixes:
		words.append(G.affix_label(entry)+("［锁］" if entry.get("locked",false) else ""))
	if not words.is_empty(): body.add_child(_label("词条："+" · ".join(words),"BagMuted",true))
	var actions := HBoxContainer.new()
	actions.name = "EquipmentActions"
	_detail.get_child(0).add_child(actions)
	var wear := _button("卸 下" if worn else "装 备","BagPrimary")
	wear.pressed.connect(_do_equip_or_unequip.bind(uid,slot,worn))
	actions.add_child(wear)
	var locked := bool(inst.get("locked",false))
	var lock_b := _button("解锁" if locked else "锁定")
	lock_b.pressed.connect(func():
		var result := G.inv_set_locked(uid,not locked)
		_toast_msg(_ok_msg(result,"已锁定" if not locked else "已解锁"))
		_refresh())
	actions.add_child(lock_b)
	var sell := _button("卖出 %d 金" % G.inv_sell_price(uid),"BagDanger")
	sell.disabled = locked or worn
	sell.tooltip_text = "已锁定的装备不能卖出" if locked else ("请先卸下装备" if worn else "卖出可获得 %d 金；高品质装备需要再次确认" % G.inv_sell_price(uid))
	sell.pressed.connect(_do_sell.bind(uid))
	actions.add_child(sell)
	for b: Button in actions.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_buttons.append(b)

func _socket_box(uid: int,gems: Array,index: int) -> Control:
	var b := _button("空","BagSocket",44)
	if index<gems.size():
		var id := String(gems[index])
		b.text = ""
		b.tooltip_text = "%s +%d · 点击拆除" % [G.gem_label(id),G.equip_gem_value(id)]
		var icon := _icon(G.res_tex(id),Vector2(28,28))
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 7
		icon.offset_top = 7
		icon.offset_right = -7
		icon.offset_bottom = -7
		b.add_child(icon)
		b.pressed.connect(func():
			var result := G.inv_gem_pop(uid,index)
			_toast_msg(_ok_msg(result,"已拆除 "+G.gem_label(id)))
			_refresh())
	else:
		b.disabled = true
		b.tooltip_text = "空宝石孔 · 在养成 → 装备中镶嵌"
	return b

func _build_supplies(gems: bool) -> void:
	var ids: Array[String] = []
	for key in G.items:
		if String(key).begins_with("gem_")==gems and G.item_count(key)>0: ids.append(String(key))
	ids.sort()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(box)
	if ids.is_empty():
		box.add_child(_label("暂无宝石" if gems else "暂无材料","BagItemTitle"))
		box.add_child(_label("沿途掉落和兑换所得会收纳在这里。","BagMuted",true))
	for id in ids:
		var card := PanelContainer.new()
		card.theme_type_variation = "BagQuietPanel"
		box.add_child(card)
		var row := HBoxContainer.new()
		card.add_child(row)
		row.add_child(_icon(G.res_tex(G.item_icon(id)),Vector2(38,38)))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation",1)
		row.add_child(words)
		words.add_child(_label(G.gem_label(id) if gems else G.item_name(id),"",true))
		words.add_child(_label("属性加成 +%d" % G.equip_gem_value(id) if gems else "行旅材料 · 可堆叠","BagMuted"))
		var count := _label("×%d" % G.item_count(id),"BagNumber")
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(count)
	var body := _detail_body()
	body.add_child(_label("宝石镶嵌与合成" if gems else "材料加工","BagItemTitle"))
	body.add_child(_label("3 颗同级同色宝石可合成更高级宝石；前往养成 → 装备 → 宝石。" if gems else "强化、精炼等加工操作位于养成 → 装备。材料可堆叠，不占装备格。","BagMuted",true))

func _build_pending_tab() -> void:
	var pending := G.inv_pending()
	var pages := maxi(1,ceili(float(pending.size())/ROWS_PER_PAGE))
	_page = clampi(_page,0,pages-1)
	if pending.is_empty():
		_empty("待领取箱是空的","背包满时，沿途掉落会暂存这里。")
	else:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.add_child(box)
		for index in range(_page*ROWS_PER_PAGE,mini((_page+1)*ROWS_PER_PAGE,pending.size())):
			var inst: Dictionary = pending[index]
			var tpl := G.equip_tpl(String(inst.tpl))
			var card := PanelContainer.new()
			card.theme_type_variation = "BagQuietPanel"
			box.add_child(card)
			var row := HBoxContainer.new()
			card.add_child(row)
			row.add_child(_icon(G.res_tex(String(tpl.get("icon",""))),Vector2(38,38)))
			var title := _label("%s\n%s · 强化 +%d" % [tpl.get("name","装备"),G.equip_rarity_name(int(inst.get("rarity",1))),int(inst.get("lv",0))],"",true)
			row.add_child(title)
			var claim := _button("领 取","BagPrimary",80)
			var uid := int(inst.uid)
			claim.set_meta("gear_uid",uid)
			claim.disabled = G.inv_count()>=G.inv_capacity()
			claim.tooltip_text = "背包已满，请先腾出装备格" if claim.disabled else "领取到背包"
			claim.pressed.connect(func():
				_toast_msg(_ok_msg(G.inv_claim(uid),"已领取"))
				_refresh())
			row.add_child(claim)
			_item_buttons.append(claim)
		_pager(pages,pending.size())
	var body := _detail_body()
	body.add_child(_label("待领取物品会保留在这里","BagItemTitle",true))
	body.add_child(_label("腾出装备格后即可领取；领取不会额外消耗资源。","BagMuted",true))

func _wire_focus() -> void:
	var available: Array[Button] = []
	_collect_buttons(_panel_root,available)
	for key in _tab_buttons:
		_tab_buttons[key].focus_neighbor_bottom = NodePath()
	for i in available.size():
		available[i].focus_next = available[(i+1)%available.size()].get_path()
		available[i].focus_previous = available[(i-1+available.size())%available.size()].get_path()
	if not _item_buttons.is_empty():
		_tab_buttons[_tab].focus_neighbor_bottom = _item_buttons[0].get_path()
		for i in _item_buttons.size():
			var b := _item_buttons[i]
			b.focus_neighbor_top = _item_buttons[i-4].get_path() if i>=4 and _tab=="equip" else _tab_buttons[_tab].get_path()
			b.focus_neighbor_bottom = _item_buttons[i+4].get_path() if i+4<_item_buttons.size() and _tab=="equip" else (_action_buttons[0].get_path() if not _action_buttons.is_empty() else _close_btn.get_path())
			if _tab=="equip":
				b.focus_neighbor_left = _item_buttons[i-1].get_path() if i%4>0 else b.get_path()
				b.focus_neighbor_right = _item_buttons[i+1].get_path() if i%4<3 and i+1<_item_buttons.size() else b.get_path()

func _collect_buttons(root: Node,out: Array[Button]) -> void:
	for child in root.get_children():
		if child is Button and not child.disabled: out.append(child)
		_collect_buttons(child,out)

func _toast_msg(msg: String) -> void:
	if msg.is_empty(): return
	if _toast_tween!=null and _toast_tween.is_valid(): _toast_tween.kill()
	if is_instance_valid(_toast): _toast.queue_free()
	_toast = _label(msg)
	_toast.name = "InventoryFeedback"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_color_override("font_color",Color("fff0cd"))
	_toast.add_theme_color_override("font_outline_color",Color("27313a"))
	_toast.add_theme_constant_override("outline_size",1)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_top = -42
	_toast.offset_bottom = -8
	_toast.offset_left = 24
	_toast.offset_right = -24
	add_child(_toast)
	var current := _toast
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(current,"modulate:a",0.0,.3)
	_toast_tween.tween_callback(current.queue_free)

func _close() -> void:
	if is_instance_valid(_focus_return): _focus_return.grab_focus.call_deferred()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
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
		_confirm_uid = uid
		_toast_msg("再次点击确认卖出")
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
