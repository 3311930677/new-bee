## 地图内的驿路与终局挑战，容器布局适配短屏；战斗时禁止旅行。
extends Control
signal closed
signal travel_requested(map_id: String)
const Journey := preload("res://src/world/JourneyService.gd")
const Relics := preload("res://src/world/RelicService.gd")
const Flow := preload("res://src/ui/FlowChestUI.gd")

const MAP_META := {
	"lorin_wilds": {"chap": "第一幕 · 边城主城", "icon": "town"},
	"maple_road": {"chap": "第一幕 · 郊野驿路", "icon": "maple"},
	"broken_slope": {"chap": "第一幕 · 古碑山道", "icon": "stele"},
	"stele_cavern": {"chap": "第一幕 · 首领秘境", "icon": "cavern"},
	"shenyuan_port": {"chap": "第二幕 · 潮汐海港", "icon": "port"},
	"tidal_gate": {"chap": "第二幕 · 潮闸要塞", "icon": "sluice"},
	"frost_post": {"chap": "第三幕 · 极北边关", "icon": "frost"},
	"rift_mine_vault": {"chap": "第三幕 · 裂谷深矿", "icon": "mine"},
	"frost_pass": {"chap": "第三幕 · 极北雪隘", "icon": "pass"},
	"abyss_ring": {"chap": "终幕 · 渊口外环", "icon": "sand"},
	"stele_entry": {"chap": "终幕 · 归路门厅", "icon": "stele"},
	"stele_core": {"chap": "终幕 · 归路碑心", "icon": "cavern"},
}

var recommended := ""
var _tab := "travel"
var _list: VBoxContainer
var _message: Label
var _paper: PanelContainer
var _banner_rect: TextureRect
var _banner_sub: Label
var _tab_travel_btn: Control
var _tab_hunt_btn: Control
var _msg_box: PanelContainer
var _battle: Control = null
var _layer: CanvasLayer
var _ticket: Dictionary = {}
var _settle_result := ""
var _participants: Array = []
var _confirm := ""

static func _sb_tex(path: String, l: float, t: float, r: float, b: float,
		cl := -1.0, ct := -1.0, cr := -1.0, cb := -1.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = G.visual_texture(path)
	sb.texture_margin_left = l
	sb.texture_margin_top = t
	sb.texture_margin_right = r
	sb.texture_margin_bottom = b
	sb.content_margin_left = l if cl < 0.0 else cl
	sb.content_margin_top = t if ct < 0.0 else ct
	sb.content_margin_right = r if cr < 0.0 else cr
	sb.content_margin_bottom = b if cb < 0.0 else cb
	return sb

static func _font_spaced(base_font: Font, glyph_space: int) -> Font:
	if base_font == null or glyph_space == 0:
		return base_font
	var fv := FontVariation.new()
	fv.base_font = base_font
	fv.spacing_glyph = glyph_space
	return fv

static func _styled_label(txt: String, fnt: Font, sz: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, outline := 3) -> Label:
	var l := Label.new()
	l.text = txt
	if fnt != null:
		l.add_theme_font_override("font", fnt)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.94))
		l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	G.veil(self, .90)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_paper = PanelContainer.new()
	_paper.custom_minimum_size = Vector2(436, 724)
	_paper.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/kit_20261013/panel_iron.png", 36, 36, 36, 36, 16, 12, 16, 12))
	center.add_child(_paper)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	_paper.add_child(body)

	# 1. 顶部乌木鎏金匾额 (plaque_title.png) + 毛笔行书题名 (G.font_art)
	var top_wrap := Control.new()
	top_wrap.custom_minimum_size = Vector2(404, 48)
	body.add_child(top_wrap)

	var plaque := TextureRect.new()
	plaque.texture = G.visual_texture("res://assets/ui/kit_20261013/plaque_title.png")
	plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaque.stretch_mode = TextureRect.STRETCH_SCALE
	plaque.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaque.position = Vector2(57, 0)
	plaque.size = Vector2(290, 48)
	top_wrap.add_child(plaque)

	var title := _styled_label("驿路与传世", _font_spaced(G.font_art, 4), 26,
		Color("ffe8a8"), HORIZONTAL_ALIGNMENT_CENTER, 4)
	title.position = Vector2(0, 2)
	title.size = Vector2(290, 42)
	plaque.add_child(title)

	# 2. 像素实景舞台横幅 (404x102)
	_banner_rect = TextureRect.new()
	_banner_rect.custom_minimum_size = Vector2(404, 102)
	_banner_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_banner_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(_banner_rect)

	_banner_sub = _styled_label("", _font_spaced(G.font_serif, 1), 16, Color("ffe8a8"), HORIZONTAL_ALIGNMENT_LEFT, 3)
	_banner_sub.position = Vector2(102, 16)
	_banner_sub.size = Vector2(236, 26)
	_banner_rect.add_child(_banner_sub)

	var banner_desc := _styled_label("", G.font_reg, 12, Color("e6dcc8"), HORIZONTAL_ALIGNMENT_LEFT, 3)
	banner_desc.name = "BannerDesc"
	banner_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_desc.clip_text = false
	banner_desc.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	banner_desc.position = Vector2(102, 44)
	banner_desc.size = Vector2(198, 44)
	_banner_rect.add_child(banner_desc)

	# 3. 双页签切换条（采用 settings_20261014/tab_selected.png 与 tab_normal.png）
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	_tab_travel_btn = _button(tabs, "已探索地点", func(): _tab = "travel"; _confirm = ""; _refresh())
	_tab_hunt_btn = _button(tabs, "传世挑战", func(): _tab = "hunt"; _confirm = ""; _refresh())
	_tab_travel_btn.custom_minimum_size.y = 40
	_tab_hunt_btn.custom_minimum_size.y = 40

	# 4. 羊皮签条状态提示横幅 (quest_slip.png)
	_msg_box = PanelContainer.new()
	_msg_box.custom_minimum_size = Vector2(404, 40)
	_msg_box.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/kit_20261013/quest_slip.png", 26, 8, 14, 8, 28, 4, 14, 4))
	body.add_child(_msg_box)

	_message = _styled_label("", G.font_serif, 13, Color("4a2414"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	_message.custom_minimum_size = Vector2(358, 30)
	_message.clip_text = false
	_message.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_box.add_child(_message)

	# 5. 列表滚动区
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	body.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	# 6. 底部返回主按钮 (button_dark.png)
	var close_btn := _button(body, "继 续 探 索", close)
	close_btn.custom_minimum_size.y = 46

	resized.connect(_resize)
	_resize()
	_refresh()

func _resize() -> void:
	var target_w := minf(436.0, maxf(360.0, size.x - 32.0))
	var target_h := minf(724.0, maxf(520.0, size.y - 44.0))
	_paper.custom_minimum_size = Vector2(target_w, target_h)
	_paper.size = Vector2(target_w, target_h)

func _text(parent: Node, words: String, big := false) -> Label:
	var label := _styled_label(words, G.font_serif if big else G.font_reg,
		15 if big else 13, Color("ffe298") if big else Color("d4c4a8"), HORIZONTAL_ALIGNMENT_LEFT, 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent: Node, words: String, callback: Callable, disabled := false, primary_tint := false) -> Control:
	var btn := Panel.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 40)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	var tex_path := "res://assets/ui/introduction_20261015/button_red.png" if primary_tint and not disabled else "res://assets/ui/introduction_20261015/button_dark.png"
	btn.add_theme_stylebox_override("panel", _sb_tex(tex_path, 22, 12, 22, 12, 8, 4, 8, 4))
	var lbl := _styled_label(words, _font_spaced(G.font_serif, 1), 15,
		Color("9a8e7c") if disabled else Color("fff0d0"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(lbl)
	btn.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	btn.modulate = Color(0.62, 0.60, 0.58, 0.85) if disabled else Color.WHITE
	btn.gui_input.connect(func(e: InputEvent):
		if disabled: return
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or e.is_action_pressed("ui_accept"):
			callback.call()
			btn.accept_event())
	parent.add_child(btn)
	return btn

func _style_tabs() -> void:
	var is_trv := _tab == "travel"
	for pair in [[_tab_travel_btn, is_trv], [_tab_hunt_btn, not is_trv]]:
		var btn: Panel = pair[0] as Panel
		var sel: bool = pair[1]
		if btn != null:
			var t_path := "res://assets/ui/settings_20261014/tab_selected.png" if sel else "res://assets/ui/settings_20261014/tab_normal.png"
			btn.add_theme_stylebox_override("panel", _sb_tex(t_path, 16, 10, 16, 10, 8, 4, 8, 4))
			var lbl := btn.get_child(0) as Label
			if lbl != null:
				lbl.add_theme_color_override("font_color", Color("ffe89c") if sel else Color("bfb096"))

func show_message(words: String) -> void:
	if not words.is_empty():
		_message.text = words

func _make_card(min_h: float, is_highlight := false) -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(394, min_h)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var path := "res://assets/ui/settings_20261014/tab_selected.png" if is_highlight else "res://assets/ui/settings_20261014/btn_row.png"
	card.add_theme_stylebox_override("panel", _sb_tex(path, 16, 10, 16, 10))
	_list.add_child(card)
	return card

func _add_icon_box(card: Panel, pos: Vector2, sz: Vector2, tex: Texture2D, slot_kind := "rare") -> void:
	var slot_map := {
		"legend": "res://assets/ui/kit_20261013/slot_legend.png",
		"epic": "res://assets/ui/kit_20261013/slot_epic.png",
		"rare": "res://assets/ui/kit_20261013/slot_rare.png",
		"uncommon": "res://assets/ui/kit_20261013/slot_uncommon.png",
	}
	var box := TextureRect.new()
	box.position = pos
	box.size = sz
	box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.stretch_mode = TextureRect.STRETCH_SCALE
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.texture = G.visual_texture(String(slot_map.get(slot_kind, slot_map["rare"])))
	card.add_child(box)
	if tex != null:
		var tr := TextureRect.new()
		tr.position = Vector2(5, 5)
		tr.size = sz - Vector2(10, 10)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.texture = tex
		box.add_child(tr)

func _add_card_label(card: Panel, words: String, rect: Rect2, fnt: Font, fs: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false) -> Label:
	var lbl := _styled_label(words, fnt, fs, col, align, 2)
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.clip_text = false
		lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	lbl.position = rect.position
	lbl.size = rect.size
	card.add_child(lbl)
	return lbl

func _add_card_action(card: Panel, rect: Rect2, caption: String, cb: Callable, disabled: bool, highlight := false) -> Control:
	var btn := Panel.new()
	btn.custom_minimum_size = rect.size
	btn.position = rect.position
	btn.size = rect.size
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	var tex_path := "res://assets/ui/settings_20261014/btn_primary.png" if highlight and not disabled else "res://assets/ui/settings_20261014/tab_normal.png"
	btn.add_theme_stylebox_override("panel", _sb_tex(tex_path, 12, 8, 12, 8, 4, 2, 4, 2))
	var lbl := _styled_label(caption, G.font_serif, 13,
		Color("8e8476") if disabled else Color("fff2d4"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	lbl.position = Vector2(2, 0)
	lbl.size = rect.size - Vector2(4, 2)
	btn.add_child(lbl)
	btn.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	btn.modulate = Color(0.58, 0.56, 0.54, 0.80) if disabled else Color.WHITE
	btn.gui_input.connect(func(e: InputEvent):
		if disabled: return
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or e.is_action_pressed("ui_accept"):
			cb.call()
			btn.accept_event())
	card.add_child(btn)
	return btn

func _refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_style_tabs()
	var relic_sheet := G.visual_texture("res://assets/ui/journey_relic/relic_showcase_icons.png")
	var b_desc := _banner_rect.get_node_or_null("BannerDesc") as Label
	if _tab == "travel":
		_banner_rect.texture = G.visual_texture("res://assets/ui/journey_relic/journey_travel_banner.png")
		_banner_sub.text = "驿路行辕 · 已访驿站免费直达"
		if b_desc != null:
			b_desc.text = "车马已备 · 点击已解锁驿站即可免费乘车前往"
		_message.text = "首次到访解锁驿路 · 免费直达旧地点（护送途中需步行）"
		if not recommended.is_empty():
			_message.text = "首领已击败，可乘车返城交付任务，或继续探索。"

		var cur_map := String(G.prog.get("main_world", {}).get("map_id", ""))
		for row in Journey.cfg().get("points", []):
			var id := String(row.map)
			var status := Journey.status(G, id)
			var ok := bool(status.ok)
			var is_rec := id == recommended
			var is_cur := id == cur_map
			var meta: Dictionary = MAP_META.get(id, {"chap": "远征驿站", "icon": "town"})

			var card := _make_card(58, is_rec)
			var lm_tex := Flow.texture(String(meta.get("icon", "town")))
			if lm_tex == null and relic_sheet != null:
				var at := AtlasTexture.new()
				at.atlas = relic_sheet
				at.region = Rect2(128, 0, 64, 64)
				lm_tex = at
			_add_icon_box(card, Vector2(10, 7), Vector2(44, 44), lm_tex,
				"legend" if is_rec else ("rare" if ok else "uncommon"))

			var caption := String(row.name)
			if is_rec:
				caption += " · 推荐返程"
			elif is_cur:
				caption += " · 当前驻地"
			_add_card_label(card, caption, Rect2(62, 6, 222, 24), _font_spaced(G.font_serif, 1), 15,
				Color("ffe28a") if is_rec else (Color("f6e8cc") if ok else Color("9e9280")))

			_add_card_label(card, "%s · %s" % [String(meta.get("chap", "驿路")), String(status.line)],
				Rect2(62, 30, 222, 20), G.font_reg, 12,
				Color("88e2a8") if ok else Color("a89a86"))

			var btn_txt := "乘车返程" if is_rec else ("乘车前往" if ok else "暂不可往")
			_add_card_action(card, Rect2(290, 11, 94, 36), btn_txt,
				func(): travel_requested.emit(id), not ok, is_rec or ok)
	else:
		_banner_rect.texture = G.visual_texture("res://assets/ui/journey_relic/journey_hunt_banner.png")
		_banner_sub.text = "传世圣坛 · 神兵与圣鹿试炼"
		if b_desc != null:
			b_desc.text = "挑战60级传世首领 · 赢取本职神兵与归路圣鹿"

		var config := Relics.cfg()
		var state := Relics.state(G)
		var role := G.selected_role if not G.selected_role.is_empty() else "zs"
		var pending: Dictionary = state.get("pending", {})
		if not pending.is_empty(): role = String(pending.role)
		var miss := int(state.get("misses", {}).get(role, 0))
		var wins := int(state.get("wins", 0))
		var pity_max := maxi(1, int(config.pity_wins))
		_message.text = "通关60级开放 · 掉率%.1f%% · 本职保底 %d/%d · 累计%d胜" % [
			float(config.drop_chance) * 100.0, miss, pity_max, wins]

		# 1) 保底进度与规则卡（雕花进度槽 + 硬朗展示数字）
		var pity_card := _make_card(60, false)
		_add_card_label(pity_card, "传世神兵保底进度", Rect2(14, 5, 136, 20), G.font_serif, 13, Color("f2dfc0"))

		_add_card_label(pity_card, "保底 %d/%d · 掉率 %.1f%% · %d胜" % [miss, pity_max, float(config.drop_chance) * 100.0, wins],
			Rect2(148, 4, 234, 22), G.font_display, 14, Color("ffd468"), HORIZONTAL_ALIGNMENT_RIGHT)

		var p_track := Panel.new()
		p_track.position = Vector2(14, 26)
		p_track.size = Vector2(366, 11)
		p_track.add_theme_stylebox_override("panel",
			_sb_tex("res://assets/ui/kit_20261013/bar_frame.png", 8, 4, 8, 4))
		pity_card.add_child(p_track)

		var p_fill := Panel.new()
		p_fill.position = Vector2(17, 29)
		p_fill.size = Vector2(maxf(6.0 if miss > 0 else 0.0, roundf(360.0 * clampf(float(miss) / float(pity_max), 0.0, 1.0))), 5)
		p_fill.add_theme_stylebox_override("panel",
			_sb_tex("res://assets/ui/kit_20261013/bar_fill_exp.png", 4, 2, 4, 2))
		pity_card.add_child(p_fill)

		_add_card_label(pity_card, "每次胜利必得：精炼石×1 · 宠物粮×2（败北不计保底）",
			Rect2(14, 38, 366, 16), G.font_reg, 11, Color("c8b89e"))

		# 2) 三大传世首领试炼卡
		for row in config.hunts:
			var id := String(row.id)
			var resume := not pending.is_empty() and String(pending.hunt) == id
			var can_fight := Relics.ready(G) and (pending.is_empty() or resume)
			var h_card := _make_card(58, resume)

			var boss_tex := G.res_tex(String(row.get("boss", "")))
			_add_icon_box(h_card, Vector2(10, 7), Vector2(44, 44), boss_tex, "epic")

			_add_card_label(h_card, String(row.name),
				Rect2(60, 5, 140, 22), _font_spaced(G.font_serif, 1), 15, Color("ffe294"))

			_add_card_label(h_card, "Lv.%d" % int(row.get("level", 60)),
				Rect2(198, 5, 76, 22), G.font_display, 16, Color("ffbe64"))

			var short_hint := String(row.hint).replace("提前准备护盾或药剂；", "备护盾药剂 · ").replace("。", "")
			_add_card_label(h_card, short_hint,
				Rect2(60, 30, 224, 22), G.font_reg, 11, Color("cabaa0"))

			_add_card_action(h_card, Rect2(290, 11, 94, 36),
				"继续挑战" if resume else "挑战首领",
				_start_hunt.bind(id), not can_fight, true)

		# 3) 传世神兵直购展柜卡
		var tpl := G.equip_tpl(Relics.template(role))
		var w_card := _make_card(60, true)
		var w_tex: Texture2D = null
		if relic_sheet != null:
			var w_at := AtlasTexture.new()
			w_at.atlas = relic_sheet
			w_at.region = Rect2(0, 0, 64, 64)
			w_tex = w_at
		_add_icon_box(w_card, Vector2(10, 8), Vector2(44, 44), w_tex, "legend")

		_add_card_label(w_card, "%s · 回收2.5万金" % String(tpl.get("name", "传世武器")),
			Rect2(60, 6, 224, 22), _font_spaced(G.font_serif, 1), 15, Color("ffd478"))

		var raw_spec := String(tpl.get("special_desc", "")).split("；")[0].split("，")[0].split("。")[0]
		var spec_short := raw_spec.replace("：开场获得", " · 开场").replace("最大生命", "生命")
		var w_sub := _add_card_label(w_card, "20胜直购 · %s" % spec_short,
			Rect2(60, 30, 226, 22), G.font_reg, 11, Color("e2d0b4"))
		w_sub.clip_text = false
		w_sub.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

		var can_buy := Relics.ready(G) and wins >= int(config.buy_requires_wins) and pending.is_empty()
		_add_card_action(w_card, Rect2(290, 12, 94, 36),
			"确认购入" if _confirm == "buy" else "9万金购入",
			_buy.bind(role), not can_buy, can_buy)

		# 4) 传世·归路圣鹿结缘展柜卡
		var p_card := _make_card(60, false)
		var d_tex: Texture2D = null
		if relic_sheet != null:
			var d_at := AtlasTexture.new()
			d_at.atlas = relic_sheet
			d_at.region = Rect2(64, 0, 64, 64)
			d_tex = d_at
		if d_tex == null:
			d_tex = G.res_tex("pet_return_deer")
		_add_icon_box(p_card, Vector2(10, 8), Vector2(44, 44), d_tex, "epic")

		var owned_deer := G.owns_pet(String(config.pet_id))
		_add_card_label(p_card, "传世·归路圣鹿",
			Rect2(60, 6, 134, 22), _font_spaced(G.font_serif, 1), 15, Color("98f0bc"))

		_add_card_label(p_card, "%d/%d胜" % [wins, int(config.pet_requires_wins)],
			Rect2(196, 6, 86, 22), G.font_display, 16, Color("ffd878"), HORIZONTAL_ALIGNMENT_RIGHT)

		_add_card_label(p_card, "初始25级4星 · 群体治疗护盾 · 传世品阶",
			Rect2(60, 30, 224, 22), G.font_reg, 12, Color("c8dcd0"))

		var can_claim := Relics.ready(G) and wins >= int(config.pet_requires_wins) and not owned_deer and pending.is_empty()
		_add_card_action(p_card, Rect2(290, 12, 94, 36),
			"已结缘" if owned_deer else "120胜领取",
			_claim_pet, not can_claim, can_claim)

		if not _settle_result.is_empty():
			_button(_list, "重试本场结算", _settle, false, true)

func _start_hunt(id: String) -> void:
	if _battle != null or not _settle_result.is_empty(): return
	var role := G.selected_role if not G.selected_role.is_empty() else "zs"
	var begin := Relics.begin(G, id, role)
	if not bool(begin.ok): show_message(String(begin.line)); return
	_ticket = begin.ticket
	role = String(_ticket.role)
	var hunt := Relics.hunt(String(_ticket.hunt))
	var pets := G.owned_pets()
	var active := G.companion_active()
	var bench := ""
	for pid in pets:
		if String(pid) != active: bench = String(pid); break
	BattleScene.pending_cfg = {"ally":{"role_id":role,"level":int(G.prog.level),"growth":G.growth_bonuses(role),
		"skill_levels":G.prog.get("skills",{}),"unlocked_skills":G.act1_unlocked_skills(role),"skill_variants":G.act1_skill_variants(role),
		"active_pet":active,"bench_pet":bench,"pet_stats":G.battle_pet_stats([active,bench]),"potions":G.run_potions_base()},
		"enemy":{"theme":String(hunt.theme),"node_type":"boss","solo":true,"lead_mon":String(hunt.boss),
			"display_level":int(hunt.level),"world_map_id":String(hunt.map),"difficulty_override":hunt.difficulty},
		"mode":"pve","flee_rule":"free","seed":int(_ticket.seed),"player_name":G.display_name()}
	_layer = CanvasLayer.new()
	_layer.layer = 7
	add_child(_layer)
	_battle = (load("res://src/battle/BattleScene.tscn") as PackedScene).instantiate()
	_battle.battle_finished.connect(_battle_finished)
	_layer.add_child(_battle)

func _battle_finished(result: String, _hp: int) -> void:
	if _battle == null or not _battle.sim.finished: return
	# Use the simulator's final outcome; its timeout is a failed PVE hunt.
	if result != "flee": result = "victory" if _battle.sim.result == "victory" else "defeat"
	_participants = _battle.sim.companion_participants.duplicate()
	_layer.queue_free()
	_battle = null
	_settle_result = result
	_settle()

func _settle() -> void:
	var result := Relics.finish(G, String(_ticket.get("id", "")), _settle_result, _participants)
	if bool(result.ok): _settle_result = ""; _ticket = {}
	_refresh()
	show_message(String(result.line))

func _buy(role: String) -> void:
	if _confirm != "buy":
		_confirm = "buy"
		_refresh()
		show_message("再次点购买确认花费%d金币购买本职业传世武器。" % int(Relics.cfg().buy_gold))
		return
	_confirm = ""
	var result := Relics.buy(G, role)
	_refresh()
	show_message(String(result.line))

func _claim_pet() -> void:
	var result := Relics.claim_pet(G)
	_refresh()
	show_message(String(result.line))

func close() -> void:
	if _battle != null: return
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if event.is_action_pressed("ui_cancel") and _battle == null:
		get_viewport().set_input_as_handled()
		close()
