# DeployPanel.gd —— 出征筹备浮层（选秘境 → 选人物 → 选宠物；预填默认可直接出征）
# 从 GameHome 的内部类抽出，营帐与主城两处入口共用同一份筹备面板
class_name DeployPanel
extends Control

signal confirmed(cfg: Dictionary)
signal canceled

var _theme := "forest"
var _role := "zs"
var _active_pet := "pet_rockturtle"
var _bench_pet := ""
# 秘境色标：maps.json 的 tint 是给地图叠色用的（8 个都接近白），当色卡完全分不出来，
# 所以另起一套辨识色 —— 林绿 / 雪蓝 / 火岩红 / 墓紫 / 沙黄 / 冰川青 / 深渊靛 / 城石灰
const THEME_HUE := {
	"forest": Color("5f8a46"), "snow": Color("7fa8cf"), "volcano": Color("b0523a"),
	"tomb": Color("6b5f88"), "desert": Color("c09a55"), "glacier": Color("6fb3ba"),
	"abyss": Color("6d5a9e"), "castle": Color("8d8474"),
}
# 稀有度色：宠物卡左侧色条按它来，一眼分出白/蓝/紫/金档
const RARITY_HUE := {
	"white": Color("a89e88"), "blue": Color("6f9fd0"),
	"purple": Color("a273c9"), "gold": Color("d8ab48"),
}
# 立绘文件名映射（原本是内部类拿不到外层类的 _role_name()，抽出后仍然自持一份）
const ROLE_ART := {"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}
# 羊皮纸 440 宽 - 左右各 16 内边距 = 内容可用宽。子控件坐标一律以这个宽度为基准，
# 因为子控件挂的是 content（已被 PanelContainer 内缩过），再按 440 算就会整体右偏 16px
const CONTENT_W := 408.0

var _theme_btns := {}    # id -> PanelContainer
var _role_btns := {}     # id -> PanelContainer
var _pet_btns := {}    # id -> PanelContainer
var _pet_labels := {}    # id -> Label（宠物名单独存，卡片里第一个子节点不再是 Label 了）
var _hint: Label = null
var _sweep_btn: Control = null   # 扫荡按钮（持有引用用于刷新券余量）

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if G.selected_role != "":
		_role = G.selected_role
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# 这里别用 set_anchors_preset 定位：浮层自己的 rect 要等一帧才结算完，
	# 锚点基准取到的是 0，横幅会被推到屏幕左边外面去，直接写死坐标最稳
	var banner := G.banner_box("出征筹备", 300, 50)
	banner.position = Vector2(90, 36)
	add_child(banner)

	var panel := G.parchment_box(440, 560, 16.0)
	panel.position = Vector2(20, 108)
	add_child(panel)

	# PanelContainer 是 Container，直接放子控件会被布局系统覆盖位置；
	# 包一层 Control 再手动布局
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	_section(content, "远征秘境（未解锁的需先通关前一世界）", 12)
	var maps: Dictionary = TableCache.maps_config()
	var order: Array = maps.get("theme_order", [])
	var themes: Dictionary = maps.get("themes", {})
	for i in order.size():
		var tid := String(order[i])
		var hue: Color = THEME_HUE.get(tid, Color("8d8474"))
		var t_open: bool = G.is_world_unlocked(tid)
		var btn := _theme_card(String(themes.get(tid, {}).get("name", tid)), hue, 96, 40, t_open)
		btn.position = Vector2((i % 4) * 104, 34 + (i / 4) * 48)
		btn.gui_input.connect(func(e: InputEvent): _on_opt_click(e, _select_theme, tid))
		_theme_btns[tid] = btn
		content.add_child(btn)

	_section(content, "出战人物", 130)
	for i in G.roles.size():
		var r: Dictionary = G.roles[i]
		var rid := String(r.get("id", ""))
		var rbtn := _role_card(rid, String(r.get("name", rid)), 96, 100)
		rbtn.position = Vector2(i * 104, 152)
		rbtn.gui_input.connect(func(e: InputEvent): _on_opt_click(e, _select_role, rid))
		_role_btns[rid] = rbtn
		content.add_child(rbtn)

	_section(content, "随行宠物（先点出战，再点替补；未收集的不可选）", 260)
	var pets: Array = TableCache.pets()
	for i in pets.size():
		var p: Dictionary = pets[i]
		var pid := String(p.get("id", ""))
		var p_open: bool = G.owns_pet(pid)
		var pbtn := _pet_card(pid, String(p.get("name", pid)),
			RARITY_HUE.get(String(p.get("rarity", "white")), Color("a89e88")), 96, 54, p_open)
		pbtn.position = Vector2((i % 4) * 104, 284 + (i / 4) * 58)
		pbtn.gui_input.connect(func(e: InputEvent): _on_opt_click(e, _select_pet, pid))
		_pet_btns[pid] = pbtn
		content.add_child(pbtn)

	_hint = G.gold_label("▶ 出战 · ◇ 替补 · 再点取消", G.FS_XS, false, Color("8a6a34"), false)
	_hint.position = Vector2(0, 404)
	_hint.custom_minimum_size = Vector2(CONTENT_W, 0)
	content.add_child(_hint)

	# 扫荡：已通关秘境 + 1 张扫荡券 = 标准路线收益一键入账（免跑图）
	_sweep_btn = G.gold_button("扫荡×%d" % G.item_count("ticket_sweep"), 118, 44, G.FS_SM)
	_sweep_btn.position = Vector2(32, 438)
	_sweep_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_sweep())
	content.add_child(_sweep_btn)

	var go := G.gold_button("出 征", 200, 48)
	go.position = Vector2(176, 436)
	go.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_confirm())
	content.add_child(go)

	var back := G.gold_button("返 回", 120, 36)
	back.position = Vector2((CONTENT_W - 120.0) * 0.5, 492)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			canceled.emit())
	content.add_child(back)

	_refresh_sel()

func _section(panel: Control, text: String, y: float) -> void:
	var l := G.gold_label(text, G.FS_SM, false, Color("7a5a2e"), false)
	l.position = Vector2(0, y)
	l.custom_minimum_size = Vector2(CONTENT_W, 0)
	panel.add_child(l)

## 卡片底：羊皮纸色 + 棕金细边 + 柔投影。四角刻意微差（5/7/6/4），别做成规整圆角矩形
func _card_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.BOX_BG
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 4
	sb.set_border_width_all(2)
	sb.border_color = G.BOX_EDGE
	G._apply_shadow(sb, 4.0, 2.0, 0.32)
	return sb

## 一条竖色条：不给整卡上色（选中态要能整体换成金色），只在左侧插一小段颜色当识别标
func _hue_bar(hue: Color, w: float) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = hue
	bar.custom_minimum_size = Vector2(w, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

## 秘境卡：左色条 + 名称（locked 时整体压灰，点它会提示解锁条件）
func _theme_card(title: String, hue: Color, w: float, h: float, unlocked := true) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := _card_sb()
	if not unlocked:
		sb.bg_color = Color("b0a68e")
		sb.border_color = Color("8a7f68")
	sb.content_margin_left = 8.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	root.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_hue_bar(hue if unlocked else Color(hue.r, hue.g, hue.b, 0.32), 6.0))
	var l := G.gold_label(title, G.FS_SM, false,
		G.TEXT_DARK if unlocked else Color("6a6152"), false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	root.add_child(row)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("locked", not unlocked)
	return root

## 人物卡：立绘头像（128px 像素图缩到卡宽内，nearest 采样保锐）+ 名字
func _role_card(rid: String, title: String, w: float, h: float) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := _card_sb()
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 3.0
	root.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	var art := String(ROLE_ART.get(rid, rid))
	var tex: Texture2D = load(G.role_dir(rid) + art + "_icon.png")
	pic.texture = tex
	pic.custom_minimum_size = Vector2(0, 66)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	col.add_child(G.gold_label(title, G.FS_SM, false, G.TEXT_DARK, false))
	root.add_child(col)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root

## 宠物卡：立绘头像 + 稀有度色条 + 名字（名字单独留引用，_refresh_sel 要往上面写 ▶/◇）
func _pet_card(pid: String, title: String, hue: Color, w: float, h: float, owned := true) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, h)
	var sb := _card_sb()
	if not owned:
		sb.bg_color = Color("b0a68e")
		sb.border_color = Color("8a7f68")
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	root.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 小头像（未收集显示暗剪影，只留轮廓）
	var tex: Texture2D = G.res_tex(pid)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.custom_minimum_size = Vector2(34, 34)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not owned:
			pic.modulate = Color(0.3, 0.27, 0.24, 0.9)
		row.add_child(pic)
	row.add_child(_hue_bar(hue if owned else Color(hue.r, hue.g, hue.b, 0.32), 4.0))
	var l := G.gold_label(title, G.FS_XS, false,
		G.TEXT_DARK if owned else Color("6a6152"), false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	_pet_labels[pid] = l
	root.add_child(row)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("locked", not owned)
	return root

func _on_opt_click(e: InputEvent, fn: Callable, id: String) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		fn.call(id)

func _select_theme(id: String) -> void:
	if not G.is_world_unlocked(id):
		_warn("「%s」尚未解锁：先通关前一世界的首领" % G.world_name(id))
		return
	_theme = id
	_refresh_sel()

func _select_role(id: String) -> void:
	_role = id
	_refresh_sel()

func _select_pet(id: String) -> void:
	if not G.owns_pet(id):
		_warn("「%s」未收集：%s" % [
			String(TableCache.get_pet(id).get("name", id)), G.pet_unlock_text(id)])
		return
	if id == _active_pet:
		if _bench_pet != "":
			_active_pet = _bench_pet
			_bench_pet = ""
		else:
			_active_pet = ""
	elif id == _bench_pet:
		_bench_pet = ""
	else:
		if _active_pet == "":
			_active_pet = id
		else:
			_bench_pet = id
	_refresh_sel()

func _refresh_sel() -> void:
	if _hint != null:
		_hint.text = "▶ 出战 · ◇ 替补 · 再点取消"
		_hint.add_theme_color_override("font_color", Color("8a6a34"))
	for id in _theme_btns:
		_set_sel(_theme_btns[id], id == _theme)
	for id in _role_btns:
		_set_sel(_role_btns[id], id == _role)
	for id in _pet_btns:
		var btn: PanelContainer = _pet_btns[id]
		_set_sel(btn, id == _active_pet or id == _bench_pet)
		# 卡片改版后第一个子节点成了 HBoxContainer，取不到 Label，得走 _pet_labels
		var l: Label = _pet_labels.get(id)
		var txt := String(TableCache.get_pet(String(id)).get("name", String(id)))
		if not G.owns_pet(String(id)):
			txt = "未收集 · " + txt
		elif id == _active_pet:
			txt = "▶ " + txt
		elif id == _bench_pet:
			txt = "◇ " + txt
		if l != null:
			l.text = txt

func _set_sel(btn: PanelContainer, on: bool) -> void:
	var sb: StyleBoxFlat = btn.get_theme_stylebox("panel")
	if sb == null:
		return
	if bool(btn.get_meta("locked", false)):
		sb.bg_color = Color("b0a68e")
		sb.border_color = Color("8a7f68")
		return
	sb.bg_color = G.GOLD_BTN if on else G.BOX_BG
	sb.border_color = G.GOLD_BTN_EDGE if on else G.BOX_EDGE

func _warn(msg: String) -> void:
	if _hint == null:
		return
	_hint.text = msg
	_hint.add_theme_color_override("font_color", Color("a04a3a"))

## 扫荡：已通关秘境 + 1 张扫荡券 → 标准路线收益（×0.7）直接入账
func _on_sweep() -> void:
	if not G.is_world_cleared(_theme):
		_warn("「%s」尚未通关首领，不能扫荡" % G.world_name(_theme))
		return
	if G.item_count("ticket_sweep") < 1:
		_warn("扫荡券不足（可在荣誉兑换补给）")
		return
	var gains := G.sweep_world(_theme)
	if gains.is_empty():
		_warn("扫荡失败：条件不满足")
		return
	var ups := int(gains.get("level_ups", 0))
	var msg := "扫荡入账：金+%d 币+%d 魂+%d 荣誉+%d" % [
		int(gains["gold"]), int(gains["expedition"]), int(gains["soul"]), int(gains["honor"])]
	if ups > 0:
		msg += " · 升 %d 级" % ups
	_hint.text = msg
	_hint.add_theme_color_override("font_color", Color("4a7a44"))
	# 刷新按钮上的券余量
	if _sweep_btn != null and _sweep_btn.get_child_count() > 0:
		(_sweep_btn.get_child(0) as Label).text = "扫荡×%d" % G.item_count("ticket_sweep")


func _on_confirm() -> void:
	if _active_pet == "":
		_warn("请先点选一只出战宠物")
		return
	if not G.owns_pet(_active_pet):
		_warn("出战宠物尚未收集：%s" % G.pet_unlock_text(_active_pet))
		return
	if not G.is_world_unlocked(_theme):
		_warn("「%s」尚未解锁" % G.world_name(_theme))
		return
	confirmed.emit({
		"theme": _theme,
		"role_id": _role,
		"level": int(G.prog.get("level", 1)),
		"active_pet": _active_pet,
		"bench_pet": _bench_pet,
		"potions": 2,
		"seed": 0,
	})
