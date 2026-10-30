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
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",16)
	column.add_child(header)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(62,62)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(_icon)
	var captions := VBoxContainer.new()
	captions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(captions)
	_title = Reading.label("",G.FS_BIG,Reading.TEXT)
	_balance = Reading.label("",G.FS_LG,Color("ecd197"))
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
	_body.add_theme_constant_override("separation",8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_body.minimum_size_changed.connect(func(): layout.call_deferred())
	var close := Reading.button("返回",true)
	close.custom_minimum_size.y = 56
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
	_body.add_child(Reading.label(String(record.get("scope","")),G.FS_SM,Color("73634e")))
	for field in [["如何获得","source"],["可以用于","use"]]:
		_body.add_child(Reading.label(field[0],G.FS_READING))
		var content := String(record.get(field[1],""))
		for line in content.replace("；","，").split("，",false):
			var row_lbl := Reading.label("• "+line,G.FS_MD)
			row_lbl.custom_minimum_size.y = 32
			var go_btn := Button.new()
			go_btn.text = "前往 ›"
			go_btn.flat = true
			go_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			go_btn.add_theme_font_override("font", G.font_serif)
			go_btn.add_theme_font_size_override("font_size", G.FS_XS)
			go_btn.add_theme_color_override("font_color", Color("7a4e1d"))
			go_btn.add_theme_color_override("font_hover_color", Color("b86e22"))
			go_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			go_btn.offset_left = -56.0
			go_btn.offset_right = -2.0
			go_btn.offset_top = -13.0
			go_btn.offset_bottom = 13.0
			go_btn.pressed.connect(func(): Audio.sfx("ui_click"); closed.emit())
			row_lbl.add_child(go_btn)
			_body.add_child(row_lbl)
	_scroll.scroll_vertical = 0
	layout()
	if sound: Audio.sfx("ui_page")

func layout() -> void:
	if _frame == null: return
	var safe := G.ui_safe_rect(self)
	# A single-currency card grows with its text and caps at the safe reading area.
	var width := minf(420,safe.size.x-32)
	_body.custom_minimum_size.x = maxf(120,width-88)
	var body_h := 0.0
	for i in _body.get_child_count():
		var ch := _body.get_child(i) as Control
		if ch != null:
			body_h += maxf(26.0, ch.get_combined_minimum_size().y)
			if i > 0:
				body_h += 8.0
	var wanted := maxf(_body.get_combined_minimum_size().y, body_h) + 272.0
	var extent := Vector2(width,clampf(wanted,420.0,minf(716.0,safe.size.y-28)))
	_frame.position = (safe.get_center()-extent*.5).round()
	_frame.size = extent

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
