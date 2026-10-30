extends PanelContainer
## Reading layout: fixed title/action, scrollable report, no scaled text or buttons.
signal confirmed
const Reading := preload("res://src/ui/ReadingSkin.gd")
const KitV4 := preload("res://src/ui/KitV4.gd")
var report: Dictionary = {}
var _scroll: ScrollContainer
var _column: VBoxContainer
var _confirm: Button
var _loot: GridContainer

func _ready() -> void:
	name = "SettlementModal"
	var win := bool(report.get("win", false))
	var box := KitV4.style("modal_frame", 20)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, 18)
	add_theme_stylebox_override("panel", box)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	add_child(_column)
	var title := Reading.label(String(report.get("title", "战报")), G.FS_BIG, Color("ffe8a8") if win else Color("b8c4d4"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.name = "ReportScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_column.add_child(_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	_scroll.add_child(body)
	# 1. 顶部仪式区（E-03/E-04 头饰 + G-01 光芒 + 书法牌匾 + E-11 宝箱）
	var ceremony := Control.new()
	ceremony.custom_minimum_size = Vector2(0, 128)
	ceremony.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ceremony.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(ceremony)
	if win:
		var burst_tex: Texture2D = KitV4.commercial_tex("vfx_victory_burst")
		if burst_tex != null:
			var burst := TextureRect.new()
			burst.texture = burst_tex
			burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			burst.modulate = Color(1, 1, 1, 0.72)
			var burst_mat := CanvasItemMaterial.new()
			burst_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			burst.material = burst_mat
			burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ceremony.add_child(burst)
	var banner := TextureRect.new()
	var hdr_tex: Texture2D = KitV4.commercial_tex("settle_win_header" if win else "settle_lose_header")
	if hdr_tex == null:
		hdr_tex = load("res://assets/ui/battle_settle/victory_header_banner.png" if win else "res://assets/ui/battle_settle/defeat_header_banner.png")
	banner.texture = hdr_tex
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ceremony.add_child(banner)
	var stamp := Reading.label("★ ★ ★\n胜利" if win else "败退", G.FS_BIG, Color("fff3c4") if win else Color("b4c2d0"))
	if G.font_art != null:
		var fv := FontVariation.new()
		fv.base_font = G.font_art
		fv.spacing_glyph = 10
		stamp.add_theme_font_override("font", fv)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ceremony.add_child(stamp)
	var chest_tex: Texture2D = KitV4.commercial_tex("chest_open" if win else "chest_closed")
	if chest_tex != null:
		var chest_icon := TextureRect.new()
		chest_icon.texture = chest_tex
		chest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chest_icon.custom_minimum_size = Vector2(56, 56)
		chest_icon.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		chest_icon.offset_left = -68
		chest_icon.offset_top = -28
		chest_icon.offset_right = -12
		chest_icon.offset_bottom = 28
		chest_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ceremony.add_child(chest_icon)
	# 2. 战利品优先（首屏直见）
	_section(body, String(report.get("loot_heading", "凯旋战利品")) if win else "变强整备建议")
	if win:
		_loot = GridContainer.new()
		_loot.columns = 2
		_loot.add_theme_constant_override("h_separation", 10)
		_loot.add_theme_constant_override("v_separation", 10)
		body.add_child(_loot)
		var reward: Dictionary = report.get("rewards", {})
		for row in [["金币", "gold", "cur_gold", "slot_rare"], ["远征币", "expedition", "cur_expedition", "slot_epic"], ["魂晶", "soul", "cur_soul", "slot_legend"], ["历练经验", "exp", "exp", "slot_uncommon"]]:
			var card := Reading.frame(false)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_loot.add_child(card)
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 10)
			card.add_child(hbox)
			var slot_box := Control.new()
			slot_box.custom_minimum_size = Vector2(44, 44)
			hbox.add_child(slot_box)
			var slot_tex: Texture2D = KitV4.commercial_tex(String(row[3]))
			if slot_tex != null:
				var slot_bg := TextureRect.new()
				slot_bg.texture = slot_tex
				slot_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				slot_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				slot_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				slot_box.add_child(slot_bg)
			var ico_key: String = String(row[2])
			var ico_tex: Texture2D = KitV4.commercial_tex("tab_talent") if ico_key == "exp" else G.res_tex(ico_key)
			if ico_tex != null:
				var ico := TextureRect.new()
				ico.texture = ico_tex
				ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ico.position = Vector2(6, 6)
				ico.size = Vector2(32, 32)
				slot_box.add_child(ico)
			var rows := VBoxContainer.new()
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.add_theme_constant_override("separation", 4)
			hbox.add_child(rows)
			rows.add_child(Reading.label(String(row[0]), G.FS_MD, Reading.TEXT))
			rows.add_child(Reading.label("+%d" % int(reward.get(row[1], 0)), G.FS_LG, Color("ffe298")))
	else:
		for words in ["铁匠锻造：强化武器防具，精炼装备词条。", "灵兽协战：喂养与升星伙伴，分担承伤。", "招式药剂：调整技能衔接，备齐药剂再战。"]:
			var adv := Reading.frame(false)
			adv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(adv)
			adv.add_child(Reading.label(words, G.FS_MD, Reading.TEXT))
	# 3. 角色状态与四维战功录
	body.add_child(Reading.label("%s  ·  Lv.%d    剩余生命 %d / %d  ·  协战伙伴：%s" % [
		report.get("role_name", "旅人"), int(report.get("level", 1)),
		int(report.get("hp_left", 0)), int(report.get("hp_max", 1)), report.get("pet_name", "无")
	], G.FS_MD, Reading.TEXT))
	_section(body, "四维战功录")
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 10)
	stats.add_theme_constant_override("v_separation", 10)
	body.add_child(stats)
	for pair in [["战斗用时", "%.1f 秒" % float(report.get("seconds", 0))], ["最高单击", str(report.get("best_hit", 0))], ["我方输出", str(report.get("damage_out", 0))], ["承受伤害", str(report.get("damage_in", 0))]]:
		var card := Reading.frame(false)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(card)
		var rows := VBoxContainer.new()
		card.add_child(rows)
		rows.add_child(Reading.label(pair[0], G.FS_SM, Color("c7b69a")))
		rows.add_child(Reading.label(pair[1], G.FS_LG, Color("ffe298")))
	_confirm = Reading.button(String(report.get("action", "继续征途")), true)
	_confirm.name = "ConfirmSettlement"
	_confirm.custom_minimum_size.y = 60
	_confirm.pressed.connect(func():
		_confirm.disabled = true
		confirmed.emit())
	_column.add_child(_confirm)
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self, layout)
	layout()
	_confirm.grab_focus.call_deferred()

func _section(parent: VBoxContainer, words: String) -> void:
	parent.add_child(Reading.label(words, G.FS_SECTION, Color("e9c784")))

func layout() -> void:
	var safe := G.ui_safe_rect(self)
	var extent := Vector2(minf(600, safe.size.x - 24), safe.size.y - 24)
	position = (safe.get_center() - extent * 0.5).round()
	size = extent
	scale = Vector2.ONE
