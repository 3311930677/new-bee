# ShopPanel.gd —— 主城物资铺（锻造铺落成后开放）：金币换养成材料（P1-2）
# 版式与其它浮层一致：统一 veil 底衬 + 木匾 + 羊皮纸；单列货架，行内明示买卖价。
class_name ShopPanel
extends Control

signal closed

# 同 DeployPanel/CodexPanel：440 羊皮纸 - 左右各 16 内边距 = 408
const CONTENT_W := 408.0

var _rows_box: Control = null
var _gold_l: Label = null
var _hint: Label = null


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()


func _build() -> void:
	G.veil(self, G.VEIL_MODAL_A)
	var banner := G.banner_box("物 资 铺", 300, 50)
	banner.position = Vector2(90, 36)
	add_child(banner)

	var panel := G.parchment_box(440, 600, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var service_mult := preload("res://src/world/RegionalTrust.gd").shop_mult(G,String(G.prog.get("main_world",{}).get("map_id","lorin_wilds")))
	var service_line := "材料可回收；购价与回收价均明示。" if service_mult==1.0 else "本城往来便利：材料购价 -%d%%，回收价不变。"%roundi((1.0-service_mult)*100)
	var tip := G.gold_label(service_line, G.FS_XS, false, G.TEXT_MUTED, false)
	tip.position = Vector2(0, 2)
	tip.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_child(tip)
	_gold_l = G.gold_label("", G.FS_SM, false, G.TEXT_DARK, false)
	_gold_l.position = Vector2(0, 24)
	_gold_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_child(_gold_l)
	_hint = G.gold_label("", G.FS_SM, false, Color("a04a3a"), false)
	_hint.position = Vector2(0, 46)
	_hint.custom_minimum_size = Vector2(CONTENT_W, 0)
	_hint.modulate.a = 0.0
	content.add_child(_hint)

	_rows_box = Control.new()
	_rows_box.position = Vector2(0, 74)
	_rows_box.size = Vector2(CONTENT_W, 380)
	content.add_child(_rows_box)

	var back := G.gold_button("返 回", 120, 38)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 500)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


## 刷新余额 + 重建货架（购买后持有数/价格文案同步）
func _refresh() -> void:
	if _gold_l == null:
		return
	_gold_l.text = "金币 ×%d" % int(G.wallet.get("gold", 0))
	for c in _rows_box.get_children():
		c.queue_free()
	var rows := G.shop_items()
	for i in rows.size():
		_make_row(i, rows[i] as Dictionary)


func _make_row(idx: int, row: Dictionary) -> void:
	var iid := String(row.get("item", ""))
	if iid.is_empty():
		return
	# 货架已由 G.shop_items() 校验过；这里只做"非法不上屏"，不再兜底成 1（问题 #20）
	var price := int(row.get("price", 0))
	if price <= 0:
		return
	var y := float(idx) * 46.0
	var band := G.InsetBand.new()
	band.position = Vector2(0, y)
	band.custom_minimum_size = Vector2(CONTENT_W, 42)
	band.size = Vector2(CONTENT_W, 42)
	# 内凹条带（切角 + 顶暗底亮 + 1px 描边），替代圆角6+2px 粗边的旧皮
	band.set_surface(G.BOX_BG, G.BOX_EDGE)
	_rows_box.add_child(band)

	var nm := G.gold_label("%s　持有 ×%d" % [G.item_name(iid), G.item_count(iid)],
		G.FS_XS, false, G.TEXT_DARK, false)
	nm.position = Vector2(10, 11)
	nm.size = Vector2(164, 20)
	band.add_child(nm)
	var sell_price := int(row.get("sell_price", 0))
	var pr := G.gold_label("购%d / 售%d" % [price, sell_price], G.FS_XS, false,
		Color("8a4a3a"), false)
	pr.position = Vector2(170, 11)
	pr.size = Vector2(94, 20)
	pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.add_child(pr)
	var buy := G.gold_button("购入", 64, 32, G.FS_XS)
	buy.position = Vector2(269, 5)
	buy.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_buy(iid))
	band.add_child(buy)
	var sell := G.ghost_button("出售", 64, 32, G.FS_XS)
	sell.position = Vector2(338, 5)
	sell.modulate.a = 0.5 if G.item_count(iid) <= 0 or sell_price <= 0 else 1.0
	sell.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_sell(iid))
	band.add_child(sell)


func _on_buy(iid: String) -> void:
	var res := G.shop_buy(iid)
	if bool(res.get("ok", false)):
		_note("已购入 %s" % G.item_name(iid), Color("4a7a44"))
	else:
		_note(String(res.get("err", "买不了")), Color("a04a3a"))
	_refresh()


func _on_sell(iid: String) -> void:
	var res := G.shop_sell(iid)
	if bool(res.get("ok", false)):
		_note("已出售 %s，金币 +%d" % [G.item_name(iid), int(res.get("gold", 0))], Color("4a7a44"))
	else:
		_note(String(res.get("err", "卖不了")), Color("a04a3a"))
	_refresh()


## 行内提示：1.5 秒后淡出（重复触发重置计时）
func _note(msg: String, color: Color) -> void:
	if _hint == null:
		return
	_hint.text = msg
	_hint.add_theme_color_override("font_color", color)
	_hint.modulate.a = 1.0
	var old: Tween = null
	if _hint.has_meta("fade_tw"):
		old = _hint.get_meta("fade_tw") as Tween
	if old != null:
		old.kill()
	var tw := _hint.create_tween()
	_hint.set_meta("fade_tw", tw)
	tw.tween_interval(1.5)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.45)
