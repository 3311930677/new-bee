extends Control
signal closed
const Reading := preload("res://src/ui/ReadingSkin.gd")
const View := preload("res://src/ui/ShowcaseUI.gd")
const TouchScroll := preload("res://src/ui/TouchScroll.gd")
var _category := "all"
var _category_buttons: Dictionary = {}
var _categories: HBoxContainer
var _hero: Control
var _entries: Array = []
var _btns: Dictionary = {}
var _cost_l: Dictionary = {}
var _times: Dictionary = {}
var _panel: PanelContainer
var _scroll: TouchScroll
var _grid: GridContainer
var _honor_l: Label
var _hint: Label
var _back: Button
var _detail: PanelContainer
var _detail_body: VBoxContainer
var _confirm: Button
var _selected := ""
var _busy := false
var _detail_back: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("safe_layout_exempt",true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_entries = TableCache._load("res://data/exchange.json").get("entries",[]).duplicate(true)
	var veil := ColorRect.new()
	veil.color = Color(.02,.02,.03,.86)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	_panel = View.frame(18)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	_panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	heading.add_child(View.text("荣誉商城","title",View.GOLD))
	var balance := HBoxContainer.new()
	heading.add_child(balance)
	balance.add_child(G.NavigationIcons.image("honor",Vector2(24,24)))
	_honor_l = View.text("","object",View.GOLD)
	_honor_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_honor_l.size_flags_horizontal = Control.SIZE_SHRINK_END
	balance.add_child(_honor_l)
	_hero = View.banner("行旅备藏","以演武荣誉，备齐下一程。\n材料与宝石，按需兑换。",load("res://assets/ui/experience_20261026/market_banner.png"))
	column.add_child(_hero)
	_categories = HBoxContainer.new()
	_categories.add_theme_constant_override("separation",8)
	var category_strip := ScrollContainer.new()
	category_strip.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	category_strip.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	category_strip.custom_minimum_size.y=60
	_categories.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	category_strip.add_child(_categories)
	column.add_child(category_strip)
	var groups := {"all":"全部"}
	var names := {"material":"锻造材料","gem":"宝石"}
	for category in TableCache._load("res://data/exchange.json").get("categories",[]):
		names[String(category.id)]=String(category.name)
	for entry in _entries:
		var kind := _category_of(entry)
		groups[kind]=String(names.get(kind,entry.get("category_name",kind)))
	for group in groups:
		if group!="all" and not _has_category(group):continue
		var key := String(group)
		var tab := View.button(groups[group])
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func():_set_category(key))
		_categories.add_child(tab)
		_category_buttons[key] = tab
	_scroll = View.scroll()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation",12)
	_grid.add_theme_constant_override("v_separation",12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)
	_rebuild_products()
	_hint = View.text("选择商品查看用途与兑换详情","caption",View.MUTED)
	column.add_child(_hint)
	_back = View.button("返回")
	_back.pressed.connect(func():closed.emit())
	column.add_child(_back)
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	_panel.minimum_size_changed.connect(layout.call_deferred)
	_refresh()
	layout()
	_back.grab_focus.call_deferred()

func _picture(entry: Dictionary, px: float) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = G.res_tex(String(entry.get("icon","")))
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.custom_minimum_size = Vector2(px,px)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture

func _category_of(entry: Dictionary) -> String:
	return String(entry.get("category","gem" if String(entry.id).begins_with("gem_") else "material"))

func _has_category(key: String) -> bool:
	for entry in _entries:
		if _category_of(entry)==key:return true
	return false

func _set_category(key: String) -> void:
	_category = key
	_scroll.scroll_vertical = 0
	_rebuild_products()
	_refresh()
	layout()

func _rebuild_products() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_btns.clear()
	_cost_l.clear()
	for key in _category_buttons:_category_buttons[key].set_pressed_no_signal(key==_category)
	for entry in _entries:
		if _category=="all" or _category_of(entry)==_category:_grid.add_child(_product(entry))
	if _grid.get_child_count()==0:_grid.add_child(View.text("该分类暂无商品","body",View.MUTED))

func _product(entry: Dictionary) -> Control:
	var card := View.frame(12)
	card.name = "Product_"+String(entry.id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := View.column(6)
	card.add_child(column)
	column.add_child(View.text(String(entry.get("badge","宝石镶嵌" if _category_of(entry)=="gem" else "装备锻造")),"tag",View.JADE))
	column.add_child(_picture(entry,76 if entry.get("display_template","compact")=="compact" else 120))
	var title := View.text(String(entry.name),"object")
	title.custom_minimum_size.y = 48
	column.add_child(title)
	var price := View.text("%d 荣誉"%int(entry.cost),"section",View.GOLD)
	column.add_child(price)
	var button := View.button("查看详情")
	button.pressed.connect(open_product.bind(String(entry.id)))
	column.add_child(button)
	_btns[entry.id] = button
	_cost_l[entry.id] = price
	return card

func _supported(entry: Dictionary) -> bool:
	var give: Dictionary = entry.get("give",{})
	if give.is_empty() or int(entry.get("cost",0))<=0:return false
	for key in give:
		if not String(key).begins_with("item_") or int(give[key])<=0:return false
	return true

func _find(id: String) -> Dictionary:
	for entry in _entries:
		if String(entry.id)==id:return entry
	return {}

func entries() -> Array:
	return _entries.duplicate(true)

func _on_back() -> void:
	if is_instance_valid(_detail):close_product()
	else:closed.emit()

func open_product(id: String) -> void:
	if _busy or _find(id).is_empty() or _scroll.gesture_active():return
	close_product()
	_selected = id
	var entry := _find(id)
	_detail = Reading.frame(false,"market")
	_detail.minimum_size_changed.connect(layout.call_deferred)
	_detail.z_index = 10
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_detail)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	_detail.add_child(column)
	column.add_child(Reading.label("商品详情",28,Reading.TEXT))
	column.add_child(_picture(entry,80))
	column.add_child(Reading.label(String(entry.name),24,Reading.TEXT))
	column.add_child(Reading.label("单次消耗 %d 荣誉 · 持有 %d"%[int(entry.cost),int(G.wallet.honor)],20,Color("e7ce97")))
	var paper := Reading.frame(true)
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(paper)
	var reading := ScrollContainer.new()
	reading.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(reading)
	_detail_body = VBoxContainer.new()
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation",12)
	reading.add_child(_detail_body)
	for key in entry.give:
		var item := String(key).trim_prefix("item_")
		_detail_body.add_child(Reading.label("获得 %s ×%d"%[G.item_name(item),int(entry.give[key])],22))
		var purpose: String = String(entry.get("description",{"enhance_stone":"用于强化装备。","refine_stone":"用于精炼装备。","lock_rune":"用于锁定装备属性。"}.get(item,"可在养成中的装备宝石槽镶嵌，提升对应属性。" if item.begins_with("gem_") else "行旅物品，可在背包查看。")))
		_detail_body.add_child(Reading.label(String(purpose),20))
	_confirm = Reading.button("确认兑换 · %d 荣誉"%int(entry.cost),true)
	_confirm.disabled = int(G.wallet.honor)<int(entry.cost) or not _supported(entry)
	_confirm.pressed.connect(confirm_purchase)
	column.add_child(_confirm)
	var back := Reading.button("返回商品区")
	_detail_back = back
	back.pressed.connect(close_product)
	column.add_child(back)
	layout()
	layout.call_deferred()
	_focus_detail.call_deferred()

func _focus_detail() -> void:
	if is_instance_valid(_detail_back) and _detail_back.is_inside_tree():_detail_back.grab_focus()

func confirm_purchase() -> void:
	if _busy or _selected.is_empty() or _confirm==null or _confirm.disabled:return
	var id := _selected
	_selected = ""
	_confirm.disabled = true
	if do_exchange(id):
		_confirm.text = "兑换完成"
		_detail_body.add_child(Reading.label("物品已入包。",22))
	else:
		_confirm.text = "兑换未完成"
		_detail_body.add_child(Reading.label(_hint.text,20))

func close_product() -> void:
	if is_instance_valid(_detail):
		remove_child(_detail)
		_detail.queue_free()
	_detail = null
	_confirm = null
	_detail_back = null
	_selected = ""

func do_exchange(id: String) -> bool:
	if _busy:return false
	var entry := _find(id)
	if entry.is_empty():return false
	var give: Dictionary = entry.get("give",{})
	if not _supported(entry):return false
	for key in give:
		if not String(key).begins_with("item_") or int(give[key])<=0:return false
	var cost := int(entry.cost)
	if int(G.wallet.honor)<cost:
		_hint.text = "荣誉不足，还差 %d 点"%(cost-int(G.wallet.honor))
		return false
	_busy = true
	var before_wallet := G.wallet.duplicate(true)
	var before_items := G.items.duplicate(true)
	G.wallet.honor = int(G.wallet.honor)-cost
	for key in give:G.grant_item(String(key).trim_prefix("item_"),int(give[key]),false)
	if not G.save_game():
		G.wallet = before_wallet
		G.items = before_items
		_hint.text = "保存失败，请稍后重试。"
		_busy = false
		_refresh()
		return false
	_times[id] = int(_times.get(id,0))+1
	_busy = false
	_hint.text = "已兑换「%s」"%String(entry.name)
	Audio.sfx("coin")
	_refresh()
	return true

func _refresh() -> void:
	_honor_l.text = "荣誉 %d"%int(G.wallet.honor)
	for id in _btns:
		var price := int(_find(id).cost)
		(_cost_l[id] as Label).add_theme_color_override("font_color",View.RED if int(G.wallet.honor)<price else View.GOLD)
		(_btns[id] as Button).text = "荣誉不足" if int(G.wallet.honor)<price else "查看详情"
		(_btns[id] as Button).modulate.a = .5 if int(G.wallet.honor)<price else 1.0

func layout() -> void:
	if _panel==null:return
	var safe := G.ui_safe_rect(self)
	var extent := Vector2(minf(620,safe.size.x-24),safe.size.y-24)
	_panel.size = extent
	_panel.position = (safe.get_center()-extent*.5).round()
	_hero.visible = safe.size.y>=700
	_grid.columns = 2 if extent.x-44>=300 else 1
	var card_width := (extent.x-56)/2 if _grid.columns==2 else extent.x-44
	for card in _grid.get_children():card.custom_minimum_size.x = card_width
	if is_instance_valid(_detail):
		_detail.position = _panel.position
		_detail.size = extent
		_detail_body.custom_minimum_size.x = maxf(80,extent.x-88)

func _input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):return
	if is_instance_valid(_detail):close_product()
	else:closed.emit()
	get_viewport().set_input_as_handled()
