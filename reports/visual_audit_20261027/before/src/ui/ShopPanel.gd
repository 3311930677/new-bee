# ShopPanel.gd —— 主城物资铺：金币换养成材料
# 商业级手游排版：深漆木箱质感 + 完整物品像素图标 + 规整货架货品卡片 + 双向交易
class_name ShopPanel
extends Control

signal closed

const UI := preload("res://src/ui/TravelChestUI.gd")
const VIEW_W := 480.0
const VIEW_H := 800.0
const PANEL_W := 440.0
const PANEL_H := 540.0
const CONTENT_W := 408.0

var _panel: Panel = null
var _rows_box: VBoxContainer = null
var _gold_l: Label = null
var _hint: Label = null


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()


func _build() -> void:
	G.veil(self, 0.76)

	# 居中典雅外框（九宫格玄铁木柜 + 顶部雕花牌匾）
	_panel = Panel.new()
	_panel.name = "ShopCabinet"
	_panel.size = Vector2(PANEL_W, PANEL_H)
	_panel.position = Vector2((VIEW_W - PANEL_W) * 0.5, (VIEW_H - PANEL_H) * 0.5)
	var iron_tex := G.Visuals._kit_tex("panel_iron.png")
	if iron_tex != null:
		var sb_iron := StyleBoxTexture.new()
		sb_iron.texture = iron_tex
		sb_iron.texture_margin_left = 16.0
		sb_iron.texture_margin_right = 16.0
		sb_iron.texture_margin_top = 16.0
		sb_iron.texture_margin_bottom = 16.0
		_panel.add_theme_stylebox_override("panel", sb_iron)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("141118", 0.96)
		style.border_color = Color("c29a5b", 0.90)
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.shadow_color = Color(0, 0, 0, 0.6)
		style.shadow_size = 16
		_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# 顶部标题匾牌 + 像素场景横幅
	var header := Panel.new()
	header.size = Vector2(PANEL_W - 12, 54)
	header.position = Vector2(6, 6)
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color("231c26", 0.95)
	h_style.border_color = Color("b89658", 0.75)
	h_style.border_width_bottom = 2
	h_style.corner_radius_top_left = 4
	h_style.corner_radius_top_right = 4
	header.add_theme_stylebox_override("panel", h_style)
	_panel.add_child(header)

	var banner_art := TextureRect.new()
	banner_art.texture = G.Visuals._kit_tex("shop_header_banner.png")
	banner_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	banner_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner_art.position = Vector2(2, 2)
	banner_art.size = Vector2(PANEL_W - 16, 50)
	banner_art.modulate = Color(1, 1, 1, 0.75)
	banner_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(banner_art)

	var plaque_bg := TextureRect.new()
	plaque_bg.texture = G.Visuals._kit_tex("plaque_title.png")
	plaque_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaque_bg.stretch_mode = TextureRect.STRETCH_SCALE
	plaque_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaque_bg.position = Vector2(8, 6)
	plaque_bg.size = Vector2(142, 40)
	plaque_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(plaque_bg)

	var title_l := UI.label("物 资 铺", "title", UI.GOLD)
	title_l.position = Vector2(18, 12)
	title_l.size = Vector2(122, 28)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title_l)

	# 钱包余额标签
	var gold_chip := Panel.new()
	gold_chip.size = Vector2(148, 30)
	gold_chip.position = Vector2(PANEL_W - 170, 12)
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color("120f14", 0.90)
	chip_style.border_color = Color("c29a5b", 0.85)
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(3)
	gold_chip.add_theme_stylebox_override("panel", chip_style)
	header.add_child(gold_chip)

	var coin_ico := G.ui_icon("coin", Vector2(18, 18))
	coin_ico.position = Vector2(8, 6)
	gold_chip.add_child(coin_ico)

	_gold_l = UI.label("", "caption", UI.GOLD)
	_gold_l.position = Vector2(30, 4)
	_gold_l.size = Vector2(110, 22)
	_gold_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gold_chip.add_child(_gold_l)

	# 提示小说明
	var service_mult := preload("res://src/world/RegionalTrust.gd").shop_mult(G, String(G.prog.get("main_world",{}).get("map_id","lorin_wilds")))
	var service_line := "◆ 材料可自由买卖 · 购价与回收价均明示" if service_mult == 1.0 else "◆ 边城特惠：材料购价 -%d%% · 回收价不变" % roundi((1.0 - service_mult) * 100)
	var tip := UI.label(service_line, "tag", UI.AGED)
	tip.position = Vector2(16, 62)
	tip.size = Vector2(CONTENT_W, 20)
	_panel.add_child(tip)

	# 商品行容器
	_rows_box = VBoxContainer.new()
	_rows_box.name = "GoodsRows"
	_rows_box.position = Vector2(16, 84)
	_rows_box.size = Vector2(CONTENT_W, 368)
	_rows_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_rows_box)

	# 交易提示气泡
	_hint = UI.label("", "caption", UI.JADE)
	_hint.position = Vector2(16, 458)
	_hint.size = Vector2(CONTENT_W, 20)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.modulate.a = 0.0
	_panel.add_child(_hint)

	# 底部返回按钮
	var back_btn := Button.new()
	back_btn.text = "返 回"
	back_btn.size = Vector2(140, 38)
	back_btn.position = Vector2((PANEL_W - 140) * 0.5, 486)
	var dark_tex := G.Visuals._kit_tex("button_dark.png")
	if dark_tex != null:
		var sb_dark := StyleBoxTexture.new()
		sb_dark.texture = dark_tex
		sb_dark.texture_margin_left = 10.0
		sb_dark.texture_margin_right = 10.0
		sb_dark.texture_margin_top = 8.0
		sb_dark.texture_margin_bottom = 8.0
		back_btn.add_theme_stylebox_override("normal", sb_dark)
		back_btn.add_theme_stylebox_override("hover", sb_dark)
		back_btn.add_theme_stylebox_override("pressed", sb_dark)
	else:
		var btn_norm := StyleBoxFlat.new()
		btn_norm.bg_color = Color("231d27", 0.9)
		btn_norm.border_color = Color("6e5434", 0.8)
		btn_norm.set_border_width_all(1)
		btn_norm.set_corner_radius_all(3)
		back_btn.add_theme_stylebox_override("normal", btn_norm)
		back_btn.add_theme_stylebox_override("hover", btn_norm)
		back_btn.add_theme_stylebox_override("pressed", btn_norm)
	back_btn.add_theme_color_override("font_color", UI.PAPER)
	back_btn.add_theme_font_override("font", G.font_serif)
	back_btn.add_theme_font_size_override("font_size", G.FS_SM)
	back_btn.pressed.connect(_close_self)
	_panel.add_child(back_btn)


func _close_self() -> void:
	G.close_page(self, func(): closed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_self()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _gold_l == null:
		return
	_gold_l.text = "%s 金" % UI.format_number(int(G.wallet.get("gold", 0)))
	for c in _rows_box.get_children():
		c.queue_free()
	var rows := G.shop_items()
	for i in rows.size():
		_make_row(i, rows[i] as Dictionary)


func _make_row(_idx: int, row: Dictionary) -> void:
	var iid := String(row.get("item", ""))
	if iid.is_empty():
		return
	var price := int(row.get("price", 0))
	if price <= 0:
		return
	var sell_price := int(row.get("sell_price", 0))
	var stock := G.item_count(iid)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(CONTENT_W, 64)
	card.size = Vector2(CONTENT_W, 64)
	var row_tex := G.Visuals._kit_tex("btn_row.png")
	if row_tex != null:
		var sb_row := StyleBoxTexture.new()
		sb_row.texture = row_tex
		sb_row.texture_margin_left = 10.0
		sb_row.texture_margin_right = 10.0
		sb_row.texture_margin_top = 8.0
		sb_row.texture_margin_bottom = 8.0
		card.add_theme_stylebox_override("panel", sb_row)
	else:
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("211b26", 0.92)
		card_style.border_color = Color("4b3b2c", 0.7)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(3)
		card.add_theme_stylebox_override("panel", card_style)
	_rows_box.add_child(card)

	# 1. 物品图标插槽（九宫格金属卡槽）
	var icon_slot := Panel.new()
	icon_slot.size = Vector2(48, 48)
	icon_slot.position = Vector2(8, 8)
	var slot_tex := G.Visuals._kit_tex("slot_rare.png")
	if slot_tex != null:
		var sb_slot := StyleBoxTexture.new()
		sb_slot.texture = slot_tex
		sb_slot.texture_margin_left = 6.0
		sb_slot.texture_margin_right = 6.0
		sb_slot.texture_margin_top = 6.0
		sb_slot.texture_margin_bottom = 6.0
		icon_slot.add_theme_stylebox_override("panel", sb_slot)
	else:
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color("120f14", 0.85)
		slot_style.border_color = Color("6e5434", 0.8)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(2)
		icon_slot.add_theme_stylebox_override("panel", slot_style)
	card.add_child(icon_slot)

	var item_icon := TextureRect.new()
	var icon_name := G.item_icon(iid)
	item_icon.texture = G.res_tex(icon_name)
	item_icon.size = Vector2(36, 36)
	item_icon.position = Vector2(6, 6)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_slot.add_child(item_icon)

	# 2. 物品名称与持有数量
	var name_l := UI.label(G.item_name(iid), "object", UI.PAPER)
	name_l.position = Vector2(64, 10)
	name_l.size = Vector2(120, 22)
	name_l.clip_text = true
	card.add_child(name_l)

	var stock_l := UI.label("持有: %d" % stock, "tag", UI.JADE if stock > 0 else UI.AGED)
	stock_l.position = Vector2(64, 34)
	stock_l.size = Vector2(100, 22)
	card.add_child(stock_l)

	# 3. 价格标签
	var price_panel := VBoxContainer.new()
	price_panel.position = Vector2(188, 12)
	price_panel.size = Vector2(80, 40)
	price_panel.add_theme_constant_override("separation", 2)
	card.add_child(price_panel)

	var buy_price_l := UI.label("购: %d 金" % price, "caption", UI.GOLD)
	price_panel.add_child(buy_price_l)

	var sell_price_l := UI.label("售: %d 金" % sell_price, "tag", Color("b8865d"))
	price_panel.add_child(sell_price_l)

	# 4. 购买按钮 (朱砂金漆九宫格)
	var buy_btn := Button.new()
	buy_btn.text = "购 入"
	buy_btn.size = Vector2(60, 34)
	buy_btn.position = Vector2(276, 15)
	var red_tex := G.Visuals._kit_tex("button_red.png")
	if red_tex != null:
		var sb_red := StyleBoxTexture.new()
		sb_red.texture = red_tex
		sb_red.texture_margin_left = 8.0
		sb_red.texture_margin_right = 8.0
		sb_red.texture_margin_top = 6.0
		sb_red.texture_margin_bottom = 6.0
		buy_btn.add_theme_stylebox_override("normal", sb_red)
		buy_btn.add_theme_stylebox_override("hover", sb_red)
		buy_btn.add_theme_stylebox_override("pressed", sb_red)
	else:
		var buy_style := StyleBoxFlat.new()
		buy_style.bg_color = Color("7a2e20", 0.95)
		buy_style.border_color = Color("d99748", 0.8)
		buy_style.set_border_width_all(1)
		buy_style.set_corner_radius_all(2)
		buy_btn.add_theme_stylebox_override("normal", buy_style)
		buy_btn.add_theme_stylebox_override("hover", buy_style)
		buy_btn.add_theme_stylebox_override("pressed", buy_style)
	buy_btn.add_theme_color_override("font_color", UI.PAPER)
	buy_btn.add_theme_font_override("font", G.font_serif)
	buy_btn.add_theme_font_size_override("font_size", G.FS_XS)
	buy_btn.pressed.connect(func(): _on_buy(iid))
	card.add_child(buy_btn)

	# 5. 出售按钮 (玄铁铜边九宫格)
	var sell_btn := Button.new()
	sell_btn.text = "出 售"
	sell_btn.size = Vector2(60, 34)
	sell_btn.position = Vector2(342, 15)
	var dark_tex := G.Visuals._kit_tex("button_dark.png")
	if dark_tex != null:
		var sb_sell := StyleBoxTexture.new()
		sb_sell.texture = dark_tex
		sb_sell.texture_margin_left = 8.0
		sb_sell.texture_margin_right = 8.0
		sb_sell.texture_margin_top = 6.0
		sb_sell.texture_margin_bottom = 6.0
		sell_btn.add_theme_stylebox_override("normal", sb_sell)
		sell_btn.add_theme_stylebox_override("hover", sb_sell)
		sell_btn.add_theme_stylebox_override("pressed", sb_sell)
		sell_btn.add_theme_stylebox_override("disabled", sb_sell)
	else:
		var sell_style := StyleBoxFlat.new()
		sell_style.bg_color = Color("231e28", 0.9)
		sell_style.border_color = Color("5e4b38", 0.8)
		sell_style.set_border_width_all(1)
		sell_style.set_corner_radius_all(2)
		sell_btn.add_theme_stylebox_override("normal", sell_style)
		sell_btn.add_theme_stylebox_override("hover", sell_style)
		sell_btn.add_theme_stylebox_override("pressed", sell_style)
	sell_btn.add_theme_color_override("font_color", UI.PAPER if stock > 0 else Color(0.5, 0.5, 0.5))
	sell_btn.add_theme_font_override("font", G.font_serif)
	sell_btn.add_theme_font_size_override("font_size", G.FS_XS)
	sell_btn.disabled = stock <= 0 or sell_price <= 0
	sell_btn.modulate.a = 0.5 if stock <= 0 else 1.0
	sell_btn.pressed.connect(func(): _on_sell(iid))
	card.add_child(sell_btn)


func _on_buy(iid: String) -> void:
	var res := G.shop_buy(iid)
	if bool(res.get("ok", false)):
		_note("已购入 %s" % G.item_name(iid), UI.JADE)
	else:
		_note(String(res.get("err", "金币不足")), Color("d95448"))
	_refresh()


func _on_sell(iid: String) -> void:
	var res := G.shop_sell(iid)
	if bool(res.get("ok", false)):
		_note("已出售 %s · 获得 %d 金币" % [G.item_name(iid), int(res.get("gold", 0))], UI.JADE)
	else:
		_note(String(res.get("err", "未能出售")), Color("d95448"))
	_refresh()


func _note(msg: String, color: Color) -> void:
	if _hint == null:
		return
	_hint.text = msg
	_hint.add_theme_color_override("font_color", color)
	_hint.modulate.a = 1.0
	var old: Tween = null
	if _hint.has_meta("fade_tw"):
		old = _hint.get_meta("fade_tw") as Tween
	if old != null and old.is_valid():
		old.kill()
	var tw := _hint.create_tween()
	_hint.set_meta("fade_tw", tw)
	tw.tween_interval(1.5)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.45)
