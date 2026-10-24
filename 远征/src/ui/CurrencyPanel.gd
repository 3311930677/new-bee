extends Control
signal closed
const Reading := preload("res://src/ui/ReadingSkin.gd")
const ICONS := {"gold":"coin","expedition":"expedition","soul":"soul","honor":"honor"}
var currency_id := "gold"
var _frame: PanelContainer
var _body: VBoxContainer
var _tabs: Dictionary = {}
var _title: Label
var _balance: Label
var _icon: TextureRect
var _scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("safe_layout_exempt",true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0.015,.025,.03,.8)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	_frame = Reading.frame(false,"market")
	_frame.name = "CurrencyDetails"
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	_frame.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",6)
	column.add_child(tabs)
	for row in TableCache.currencies_config().get("currencies",[]):
		var id := String(row.id)
		var tab := Reading.button(String(row.name))
		tab.custom_minimum_size.y = 60
		tab.name = "Currency_"+id
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(select_currency.bind(id))
		tabs.add_child(tab)
		_tabs[id] = tab
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",16)
	column.add_child(header)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(62,62)
	header.add_child(_icon)
	var captions := VBoxContainer.new()
	captions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(captions)
	_title = Reading.label("",28,Reading.TEXT)
	_balance = Reading.label("",24,Color("ecd197"))
	_balance.name = "ExactBalance"
	captions.add_child(_title)
	captions.add_child(_balance)
	var paper := Reading.frame(true)
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(paper)
	_scroll = ScrollContainer.new()
	_scroll.name = "CurrencyReading"
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation",12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	var close := Reading.button("返回",true)
	close.custom_minimum_size.y = 64
	close.name = "CloseCurrency"
	close.pressed.connect(func(): Audio.sfx("ui_close"); closed.emit())
	column.add_child(close)
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	select_currency(currency_id,false)
	layout()
	close.grab_focus.call_deferred()

func select_currency(id: String, sound := true) -> void:
	if not ICONS.has(id): id = "gold"
	currency_id = id
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for key in _tabs:
		_tabs[key].modulate = Color.WHITE if key == id else Color(.68,.72,.7)
	var record: Dictionary = {}
	for row in TableCache.currencies_config().get("currencies",[]):
		if String(row.id) == id: record = row; break
	_title.text = String(record.get("name",id))
	_balance.text = "持有 %d" % int(G.wallet.get(id,0))
	_icon.texture = G.res_tex(String(record.get("icon","cur_gold")))
	_body.add_child(Reading.label(String(record.get("scope","")),20,Color("73634e")))
	for field in [["如何获得","source"],["可以用于","use"]]:
		_body.add_child(Reading.label(field[0],23))
		var content := String(record.get(field[1],""))
		for line in content.replace("，","、").replace("；","、").split("、",false):
			_body.add_child(Reading.label("• "+line,22))
	_scroll.scroll_vertical = 0
	if sound: Audio.sfx("ui_page")

func layout() -> void:
	if _frame == null: return
	var safe := G.ui_safe_rect(self)
	# A currency is a reading page, so use the available height. Only its body
	# scrolls; tabs, identity, balance and return action retain their touch size.
	var extent := Vector2(minf(600,safe.size.x-24),safe.size.y-24)
	_frame.position = (safe.get_center()-extent*.5).round()
	_frame.size = extent
	_body.custom_minimum_size.x = maxf(120,extent.x-96)
