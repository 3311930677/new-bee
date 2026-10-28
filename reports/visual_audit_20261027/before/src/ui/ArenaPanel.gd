# ArenaPanel.gd —— 演武场（PVP 首版）：傀儡对手 + 段位分
extends Control

signal closed

const BattleScenePacked := "res://src/battle/BattleScene.tscn"
const VIEW_W := 480.0
const VIEW_H := 800.0
const CONTENT_W := 408.0

var _panel: PanelContainer = null
var _rank_icon: TextureRect = null   # 段位徽章（升档后 _refresh 要换图）
var _info: Label = null
var _streak_l: Label = null      # 连胜行（轮次 19）
var _rank_title: Label = null    # 段位进度标题
var _rank_bar: Panel = null      # 段位进度填充条
var _rank_sub: Label = null      # 下一段位门槛说明
var _season_l: Label = null      # 赛季奖励（连胜荣誉口径）
var _rec_l: Label = null         # 战绩（胜负 / 胜率）
var _foe_l: Label = null
var _foe_lv := 1
var _mirror := false          # 对手模式：false=演武傀儡（默认，好上手）true=镜影（自己的镜像）
var _foe_tip: Label = null
var _battle_layer: CanvasLayer = null
var _busy := false
var _go_btn: Control = null


var _score_num_l: Label = null
var _score_unit_l: Label = null
var _duel_stage: Control = null
var _hero_tag_l: Label = null


class _ArenaDuelStage extends Control:
	var _bg_tex: Texture2D
	var _hero_asp: AnimatedSprite2D
	var _foe_sp: Sprite2D
	var _foe_asp: AnimatedSprite2D

	func _ready() -> void:
		_bg_tex = G.visual_texture("res://assets/ui/arena_v2/arena_duel_stage.png")
		_hero_asp = AnimatedSprite2D.new()
		_hero_asp.position = Vector2(88, 74)
		_hero_asp.scale = Vector2(0.55, 0.55)
		add_child(_hero_asp)

		_foe_sp = Sprite2D.new()
		_foe_sp.position = Vector2(316, 64)
		_foe_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_foe_sp)

		_foe_asp = AnimatedSprite2D.new()
		_foe_asp.position = Vector2(316, 74)
		_foe_asp.scale = Vector2(0.55, 0.55)
		_foe_asp.flip_h = true
		_foe_asp.modulate = Color(0.75, 0.62, 0.98, 0.95)
		add_child(_foe_asp)

	func sync_duel(role_id: String, _lv: int, foe_data: Dictionary, is_mirror: bool) -> void:
		var r_id := role_id if not role_id.is_empty() else "zs"
		var frames: SpriteFrames = BattleScene.battle_frames(r_id)
		if frames != null:
			_hero_asp.sprite_frames = frames
			_hero_asp.animation = &"idle" if frames.has_animation(&"idle") else frames.get_animation_names()[0]
			_hero_asp.play()
			_hero_asp.visible = true
		else:
			_hero_asp.visible = false

		if is_mirror and frames != null:
			_foe_sp.visible = false
			_foe_asp.sprite_frames = frames
			_foe_asp.animation = &"idle" if frames.has_animation(&"idle") else frames.get_animation_names()[0]
			_foe_asp.play()
			_foe_asp.visible = true
		else:
			_foe_asp.visible = false
			var mon_id := String(foe_data.get("id", "mon_arena_dummy"))
			var f_tex: Texture2D = MonsterArt.texture(mon_id) if MonsterArt.has(mon_id) else G.res_tex(mon_id)
			if f_tex == null:
				f_tex = G.res_tex("icon_double_edge")
			_foe_sp.texture = f_tex
			if f_tex != null:
				var sc := 60.0 / float(maxi(1, f_tex.get_height()))
				if MonsterArt.has(mon_id):
					sc = MonsterArt.display_scale(mon_id, 64.0, true)
				_foe_sp.scale = Vector2.ONE * sc
				_foe_sp.flip_h = true
			_foe_sp.visible = f_tex != null
		queue_redraw()

	func _draw() -> void:
		if _bg_tex != null:
			draw_texture_rect(_bg_tex, Rect2(0, 0, size.x, size.y), false)


static func _tex(path: String) -> Texture2D:
	return G.visual_texture(path)


static func _sb_tex(path: String, l: float, t: float, r: float, b: float,
		cl := -1.0, ct := -1.0, cr := -1.0, cb := -1.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(path)
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


static func _plate_button(caption: String, rect: Rect2, is_red: bool, fs: int, on_click: Callable) -> Control:
	var btn := Panel.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.custom_minimum_size = rect.size
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tex_path := "res://assets/ui/introduction_20261015/button_red.png" if is_red else "res://assets/ui/introduction_20261015/button_dark.png"
	btn.add_theme_stylebox_override("panel", _sb_tex(tex_path, 24, 14, 24, 14, 8, 4, 8, 4))
	var lbl := _styled_label(caption, _font_spaced(G.font_serif, 2), fs,
		Color("fff2d4") if is_red else Color("eee0c4"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	lbl.position = Vector2(4, 0)
	lbl.size = rect.size - Vector2(8, 2)
	btn.add_child(lbl)
	btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on_click.call())
	return btn


static func _feature_card(title_txt: String, sub_txt: String, slot_path: String, icon_tex: Texture2D, rect: Rect2, on_click: Callable) -> Control:
	var card := Panel.new()
	card.position = rect.position
	card.size = rect.size
	card.custom_minimum_size = rect.size
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/settings_20261014/btn_row.png", 16, 10, 16, 10))

	var slot := TextureRect.new()
	slot.texture = _tex(slot_path)
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = TextureRect.STRETCH_SCALE
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.position = Vector2(10, 9)
	slot.size = Vector2(44, 44)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(slot)

	if icon_tex != null:
		var ic := TextureRect.new()
		ic.texture = icon_tex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.position = Vector2(6, 6)
		ic.size = Vector2(32, 32)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ic)

	var t_lbl := _styled_label(title_txt, _font_spaced(G.font_serif, 1), 16, Color("ffe8b0"), HORIZONTAL_ALIGNMENT_LEFT, 3)
	t_lbl.position = Vector2(60, 7)
	t_lbl.size = Vector2(128, 24)
	card.add_child(t_lbl)

	var s_lbl := _styled_label(sub_txt, G.font_reg, 11, Color("cabaa0"), HORIZONTAL_ALIGNMENT_LEFT, 2)
	s_lbl.position = Vector2(60, 32)
	s_lbl.size = Vector2(128, 20)
	card.add_child(s_lbl)

	card.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on_click.call())
	return card


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.sfx("ui_open")
	_foe_lv = maxi(1, int(G.prog.get("level", 1)))
	_build()


func _build() -> void:
	G.veil(self, G.VEIL_TAKEOVER_A)

	# 外框：采用 kit_20261013/panel_iron.png 九宫格乌木铁框
	_panel = PanelContainer.new()
	_panel.position = Vector2(20, 44)
	_panel.size = Vector2(440, 712)
	_panel.custom_minimum_size = Vector2(440, 712)
	_panel.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/kit_20261013/panel_iron.png", 36, 36, 36, 36, 16, 16, 16, 16))
	_panel.z_index = 1
	add_child(_panel)

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(content)

	# 底部石灯笼与木栏意境底图 (settings_20261014/bg_bottom.png)
	var bottom_art := TextureRect.new()
	bottom_art.texture = _tex("res://assets/ui/settings_20261014/bg_bottom.png")
	bottom_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bottom_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bottom_art.position = Vector2(2, 514)
	bottom_art.size = Vector2(404, 160)
	bottom_art.modulate = Color(1, 1, 1, 0.42)
	bottom_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bottom_art)

	# 顶部乌木鎏金匾额 (plaque_title.png) + 毛笔行书大题名 (G.font_art)
	var plaque := TextureRect.new()
	plaque.texture = _tex("res://assets/ui/kit_20261013/plaque_title.png")
	plaque.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaque.stretch_mode = TextureRect.STRETCH_SCALE
	plaque.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plaque.position = Vector2(64, -4)
	plaque.size = Vector2(280, 50)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(plaque)

	var title_lbl := _styled_label("演武校场", _font_spaced(G.font_art, 6), 27,
		Color("ffe8a8"), HORIZONTAL_ALIGNMENT_CENTER, 4)
	title_lbl.position = Vector2(0, 2)
	title_lbl.size = Vector2(280, 44)
	plaque.add_child(title_lbl)

	var rules := G.info_button("演武规则", _rules_lines(), 26.0)
	rules.position = Vector2(CONTENT_W - 30.0, 8.0)
	content.add_child(rules)

	# ── 区块一（R2+R3核心升级）：演武校场实景对决擂台 (_ArenaDuelStage, 404x136)
	_duel_stage = _ArenaDuelStage.new()
	_duel_stage.position = Vector2(2, 50)
	_duel_stage.size = Vector2(404, 136)
	_duel_stage.custom_minimum_size = Vector2(404, 136)
	_duel_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_duel_stage.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_duel_stage.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_mirror = not _mirror
			Audio.sfx("ui_confirm")
			_refresh())
	content.add_child(_duel_stage)

	var vs_lbl := _styled_label("战", G.font_art, 24, Color("fff0c2"), HORIZONTAL_ALIGNMENT_CENTER, 4)
	vs_lbl.position = Vector2(177, 26)
	vs_lbl.size = Vector2(50, 48)
	_duel_stage.add_child(vs_lbl)

	_foe_tip = _styled_label("", G.font_reg, 11, Color("ffe29a"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	_foe_tip.position = Vector2(72, 6)
	_foe_tip.size = Vector2(260, 18)
	_duel_stage.add_child(_foe_tip)

	_hero_tag_l = _styled_label("", G.font_serif, 13, Color("f6e8cc"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	_hero_tag_l.position = Vector2(10, 108)
	_hero_tag_l.size = Vector2(176, 22)
	_duel_stage.add_child(_hero_tag_l)

	_foe_l = _styled_label("", G.font_serif, 13, Color("ffd896"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	_foe_l.position = Vector2(218, 108)
	_foe_l.size = Vector2(176, 22)
	_duel_stage.add_child(_foe_l)

	# ── 区块二：段位与连胜主卡 (settings_20261014/btn_row.png 云锦九宫格 + 武魁朱印)
	var rank_card := Panel.new()
	rank_card.position = Vector2(2, 194)
	rank_card.size = Vector2(404, 96)
	rank_card.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/settings_20261014/btn_row.png", 16, 10, 16, 10))
	rank_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rank_card)

	var seal_sheet := _tex("res://assets/ui/battle_settle/seal_stamps.png")
	if seal_sheet != null:
		var seal_at := AtlasTexture.new()
		seal_at.atlas = seal_sheet
		seal_at.region = Rect2(112, 0, 56, 56)
		var seal_tr := TextureRect.new()
		seal_tr.texture = seal_at
		seal_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		seal_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		seal_tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		seal_tr.position = Vector2(348, 6)
		seal_tr.size = Vector2(44, 44)
		seal_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rank_card.add_child(seal_tr)

	var icon_frame := TextureRect.new()
	icon_frame.texture = _tex("res://assets/ui/kit_20261013/sortie_medal.png")
	icon_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_frame.position = Vector2(12, 14)
	icon_frame.size = Vector2(66, 66)
	rank_card.add_child(icon_frame)

	_rank_icon = TextureRect.new()
	_rank_icon.texture = G.res_tex(_rank_icon_name())
	_rank_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rank_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rank_icon.position = Vector2(12, 12)
	_rank_icon.size = Vector2(42, 42)
	_rank_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(_rank_icon)

	# 段位名（宋刻衬线体）+ 段位分（硬朗展示数字体）+ 单位「分」（宋刻衬线体）
	_info = _styled_label("", _font_spaced(G.font_serif, 1), 19, Color("ffe8b0"), HORIZONTAL_ALIGNMENT_LEFT, 3)
	_info.position = Vector2(88, 8)
	_info.size = Vector2(64, 26)
	rank_card.add_child(_info)

	_score_num_l = _styled_label("", G.font_display, 23, Color("ffd468"), HORIZONTAL_ALIGNMENT_RIGHT, 3)
	_score_num_l.position = Vector2(142, 6)
	_score_num_l.size = Vector2(58, 28)
	rank_card.add_child(_score_num_l)

	_score_unit_l = _styled_label("分", G.font_serif, 14, Color("e6d4b4"), HORIZONTAL_ALIGNMENT_LEFT, 2)
	_score_unit_l.position = Vector2(204, 10)
	_score_unit_l.size = Vector2(28, 24)
	rank_card.add_child(_score_unit_l)

	_streak_l = _styled_label("", G.font_reg, 12, Color("f0c878"), HORIZONTAL_ALIGNMENT_LEFT, 2)
	_streak_l.position = Vector2(88, 34)
	_streak_l.size = Vector2(250, 20)
	rank_card.add_child(_streak_l)

	_rank_title = _styled_label("", G.font_reg, 12, Color("d8ccb4"), HORIZONTAL_ALIGNMENT_LEFT, 2)
	_rank_title.position = Vector2(88, 54)
	_rank_title.size = Vector2(196, 18)
	rank_card.add_child(_rank_title)

	_rank_sub = _styled_label("", G.font_serif, 12, Color("90e2ac"), HORIZONTAL_ALIGNMENT_RIGHT, 2)
	_rank_sub.position = Vector2(280, 54)
	_rank_sub.size = Vector2(110, 18)
	rank_card.add_child(_rank_sub)

	var bar_bg := Panel.new()
	bar_bg.position = Vector2(88, 74)
	bar_bg.size = Vector2(302, 13)
	bar_bg.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/kit_20261013/bar_frame.png", 8, 4, 8, 4))
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_card.add_child(bar_bg)

	_rank_bar = Panel.new()
	_rank_bar.position = Vector2(91, 77)
	_rank_bar.size = Vector2(0, 7)
	_rank_bar.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/kit_20261013/bar_fill_exp.png", 4, 2, 4, 2))
	_rank_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_card.add_child(_rank_bar)

	# ── 区块三：羊皮签条（赛季荣誉 / 历史战绩，采用 kit_20261013/quest_slip.png）
	var slip_l := Panel.new()
	slip_l.position = Vector2(2, 298)
	slip_l.size = Vector2(198, 42)
	slip_l.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/kit_20261013/quest_slip.png", 26, 8, 14, 8))
	content.add_child(slip_l)

	_season_l = _styled_label("", G.font_serif, 13, Color("4a2414"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	_season_l.position = Vector2(26, 4)
	_season_l.size = Vector2(164, 34)
	slip_l.add_child(_season_l)

	var slip_r := Panel.new()
	slip_r.position = Vector2(208, 298)
	slip_r.size = Vector2(198, 42)
	slip_r.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/kit_20261013/quest_slip.png", 26, 8, 14, 8))
	content.add_child(slip_r)

	_rec_l = _styled_label("", G.font_serif, 13, Color("4a2414"), HORIZONTAL_ALIGNMENT_LEFT, 0)
	_rec_l.position = Vector2(26, 4)
	_rec_l.size = Vector2(164, 34)
	slip_r.add_child(_rec_l)

	# ── 区块四：主次分明切磋按钮行（乌金次按钮 + 朱红鎏金主按钮）
	var reroll := _plate_button("换 对 手", Rect2(2, 348, 136, 50), false, 16, func():
		HapticFeedback.light()
		Audio.sfx("ui_page")
		_foe_lv = clampi(_foe_lv + (1 if randf() < 0.5 else -1), 1, 99)
		_refresh())
	content.add_child(reroll)

	_go_btn = _plate_button("开 始 切 磋", Rect2(148, 346, 258, 54), true, 20, func():
		HapticFeedback.medium()
		_start_battle())
	content.add_child(_go_btn)

	# ── 区块五（R3升级）：校场武备与古碑奇珍分栏 + 图文双列展柜卡
	var sec_sub := Panel.new()
	sec_sub.position = Vector2(2, 408)
	sec_sub.size = Vector2(404, 34)
	sec_sub.add_theme_stylebox_override("panel",
		_sb_tex("res://assets/ui/settings_20261014/section.png", 16, 8, 48, 8))
	content.add_child(sec_sub)

	var ss_orn := TextureRect.new()
	ss_orn.texture = _tex("res://assets/ui/settings_20261014/ic_orn.png")
	ss_orn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ss_orn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ss_orn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ss_orn.position = Vector2(14, 9)
	ss_orn.size = Vector2(16, 16)
	sec_sub.add_child(ss_orn)

	var ss_lbl := _styled_label("校场武备与古碑奇珍", _font_spaced(G.font_serif, 1), 15, Color("f6e6c4"))
	ss_lbl.position = Vector2(36, 0)
	ss_lbl.size = Vector2(320, 34)
	sec_sub.add_child(ss_lbl)

	var bow_ic := _tex("res://assets/ui/settings_20261014/ic_sec_battle.png")
	var archery_btn := _feature_card("校场射艺", "挽弓测风 · 赢取荣誉",
		"res://assets/ui/kit_20261013/slot_rare.png", bow_ic, Rect2(2, 448, 198, 62), func():
		Audio.sfx("ui_open")
		_open_archery())
	archery_btn.name = "OpenArcheryButton"
	content.add_child(archery_btn)

	var curio_ic := _tex("res://assets/ui/pixel_icons/book.png")
	var curio_btn := _feature_card("古碑鉴宝", "参悟铭文 · 鉴匣得宝",
		"res://assets/ui/kit_20261013/slot_epic.png", curio_ic, Rect2(208, 448, 198, 62), func():
		Audio.sfx("ui_open")
		_open_curio_modal())
	curio_btn.name = "OpenCurioButton"
	content.add_child(curio_btn)

	var back := _plate_button("返 回 主 城", Rect2(114, 526, 180, 46), false, 16, func():
		Audio.sfx("ui_close")
		closed.emit())
	content.add_child(back)

	var subtitle := _styled_label("擂台试锋 · 不损装备，不耗资源", G.font_reg, 13,
		Color("d0c0a4"), HORIZONTAL_ALIGNMENT_CENTER, 3)
	subtitle.position = Vector2(0, 584)
	subtitle.size = Vector2(CONTENT_W, 22)
	content.add_child(subtitle)

	_refresh()


var _archery_overlay: Control = null
var _curio_overlay: Control = null


func _open_archery() -> void:
	if _archery_overlay != null or _busy:
		return
	var ap: Control = (load("res://src/ui/ArcheryPanel.gd") as GDScript).new()
	_archery_overlay = ap
	ap.z_index = 20
	ap.closed.connect(func():
		if _archery_overlay != null:
			_archery_overlay.queue_free()
			_archery_overlay = null
		_refresh())
	add_child(ap)


func _open_curio_modal() -> void:
	if _curio_overlay != null or _busy: return
	var page := preload("res://src/ui/CurioLorePanel.gd").new()
	page.name = "CurioLoreOverlay"
	page.z_index = 20
	_curio_overlay = page
	page.closed.connect(func():
		if is_instance_valid(_curio_overlay): _curio_overlay.queue_free()
		_curio_overlay = null
		_refresh())
	add_child(page)


func _rank_icon_name() -> String:
	match G.arena_rank():
		"铜印": return "rank_bronze"
		"银印": return "rank_silver"
		"金印": return "rank_gold"
		"铂印": return "rank_platinum"
		"钻印": return "rank_diamond"
	return "rank_bronze"


## 段位档位表（data/arena.json ranks）：面板内统一从这里取，避免各处重复解析
func _ranks() -> Array:
	var ranks: Variant = TableCache.arena_config().get("ranks", [])
	return ranks if ranks is Array else []


## 演武规则弹层文案：数值全读 data/arena.json，改数值不动代码
func _rules_lines() -> Array:
	var scfg: Variant = TableCache.arena_config().get("score", {})
	var sc: Dictionary = scfg if scfg is Dictionary else {}
	var cfg := G.arena_streak_cfg()
	var step := maxi(1, int(cfg.get("step", 3)))
	var honor_per := maxi(0, int(cfg.get("honor_per_milestone", 0)))
	var per_streak := maxi(0, int(cfg.get("score_bonus_per_streak", 0)))
	var cap := maxi(0, int(cfg.get("score_bonus_cap", 0)))
	var lines: Array = [
		"切磋不损装备、不耗资源；平局或中途退出不判负，段位分不变。",
		"胜利 +%d~%d 分，落败 -%d 分（段位分最低 0，不会跌破）。" % [
			int(sc.get("win_min", 18)), int(sc.get("win_max", 26)), int(sc.get("loss", 12))],
	]
	if per_streak > 0:
		lines.append("连胜每场额外 +%d 分，单场最多 +%d。" % [per_streak, cap])
	lines.append("每累计 %d 连胜额外发放 %d 荣誉，落败则连胜清零。" % [step, honor_per])
	var parts: PackedStringArray = []
	for r in _ranks():
		if r is Dictionary:
			parts.append("%s %d" % [String(r.get("name", "")), int(r.get("min", 0))])
	if not parts.is_empty():
		lines.append("段位按段位分划分：%s。" % " / ".join(parts))
	lines.append("点对手卡可在「镜影」（同套技能加成）与「演武傀儡」之间切换。")
	return lines


func _refresh() -> void:
	var score := int(G.arena.get("score", 0))
	var wins := int(G.arena.get("wins", 0))
	var losses := int(G.arena.get("losses", 0))

	_info.text = G.arena_rank()
	if _score_num_l != null:
		_score_num_l.text = "%d" % score
	_rank_icon.texture = G.res_tex(_rank_icon_name())

	var cur_min := 0
	var next_name := ""
	var next_min := -1
	for r in _ranks():
		if not (r is Dictionary):
			continue
		var lo := int((r as Dictionary).get("min", 0))
		if lo <= score and lo >= cur_min:
			cur_min = lo
		if lo > score and (next_min < 0 or lo < next_min):
			next_min = lo
			next_name = String((r as Dictionary).get("name", ""))
	if next_min < 0:
		_rank_title.text = "段位进度 · 已封顶"
		_rank_bar.size = Vector2(296.0, 7)
		_rank_sub.text = "最高段位"
	else:
		var span := maxi(1, next_min - cur_min)
		var ratio := clampf(float(score - cur_min) / float(span), 0.0, 1.0)
		_rank_bar.size = Vector2(maxf(6.0, roundf(296.0 * ratio)), 7)
		_rank_title.text = "段位进度 · %s → %s" % [G.arena_rank(), next_name]
		_rank_sub.text = "还差 %d 分" % (next_min - score)

	var st := G.arena_streak()
	_streak_l.text = "当前连胜 %d 场 · 历史最佳 %d 场" % [st, maxi(st, int(G.arena.get("best_streak", 0)))]
	_streak_l.add_theme_color_override("font_color",
		Color("ffd478") if st > 0 else Color("c8bca4"))

	var cfg := G.arena_streak_cfg()
	var step := maxi(1, int(cfg.get("step", 3)))
	var honor_per := maxi(0, int(cfg.get("honor_per_milestone", 0)))
	var to_next := step if st <= 0 else step - (st % step)
	_season_l.text = "赛季荣誉 %d · 再胜%d场+%d" % [
		int(G.wallet.get("honor", 0)), to_next, honor_per]

	var total := wins + losses
	var rate := 0 if total <= 0 else roundi(float(wins) * 100.0 / float(total))
	_rec_l.text = "%d胜 %d负 · 胜率 %d%%" % [wins, losses, rate]

	var p_lv := maxi(1, int(G.prog.get("level", 1)))
	if _hero_tag_l != null:
		_hero_tag_l.text = "我方 · %s Lv.%d" % [G.display_name(), p_lv]
	var foe_dict := _foe()
	_foe_l.text = "对手 · %s" % String(foe_dict.get("name", ""))
	if _foe_tip != null:
		_foe_tip.text = ("镜影对局（同套技能）· 点擂台换傀儡" if _mirror \
			else "练手对局（随级缩放）· 点擂台换镜影")
	if _duel_stage != null and _duel_stage.has_method("sync_duel"):
		_duel_stage.call("sync_duel", G.selected_role, p_lv, foe_dict, _mirror)


func _foe() -> Dictionary:
	if _mirror:
		return G.make_arena_mirror(G.selected_role, _foe_lv)
	return G.make_arena_foe(_foe_lv)


func _start_battle() -> void:
	if _busy:
		return
	_busy = true
	var foe := _foe()
	var pet := ""
	var owned: Array = G.owned_pets()
	if owned.size() > 0:
		pet = String(owned[0])
	BattleScene.pending_cfg = {
		"ally": {"role_id": G.selected_role, "level": int(G.prog.get("level", 1)),
			"traits": [], "active_pet": pet, "bench_pet": "", "potions": 2,
			"growth": G.growth_bonuses(G.selected_role),
			"skill_levels": G.prog.get("skills", {}),
			"pet_stats": G.battle_pet_stats([pet])},
		"enemy": {"theme": "forest", "node_type": "normal", "custom_mon": foe},
		"mode": "arena",   # 超时文案按"未分胜负"显示（口径 D3；问题 #21）
		"seed": 0,
	}
	_set_busy_look(true)   # 切磋进行中：主按钮压灰，避免连点重复开局（§26 禁用态要看得见）
	_battle_layer = CanvasLayer.new()
	_battle_layer.layer = 5
	add_child(_battle_layer)
	var b: Node = (load(BattleScenePacked) as PackedScene).instantiate()
	b.battle_finished.connect(_on_battle_end)
	_battle_layer.add_child(b)


func _on_battle_end(result: String, _hp_left: int) -> void:
	if _battle_layer != null:
		_battle_layer.queue_free()
		_battle_layer = null
	if result == "draw":
		# 超时平局：不判负、不动段位分（口径 D3）
		_busy = false
		_set_busy_look(false)
		_toast("未分胜负 · 段位分不变")
		_refresh()
		return
	if result == "flee":
		# 退出切磋（与远征撤退同义）：不判负、不动段位分
		_busy = false
		_set_busy_look(false)
		_toast("已退出切磋 · 段位分不变")
		_refresh()
		return
	var win := result == "victory"
	var res: Dictionary = G.arena_result(win)
	_busy = false
	_set_busy_look(false)
	_toast("切磋%s · 段位分 %+d（%s · %d 分）" % ["得胜" if win else "落败",
		int(res.get("delta", 0)), String(res.get("rank", "")), int(res.get("score", 0))])
	if bool(res.get("milestone", false)):
		Audio.sfx("reward")
		_toast("%d 连胜！额外荣誉 +%d" % [int(res.get("streak", 0)), int(res.get("honor", 0))])
	_refresh()


## 切磋中的按钮禁用态：压灰 + 不接点击（不是"点了没反应"）
func _set_busy_look(busy: bool) -> void:
	if _go_btn == null:
		return
	_go_btn.modulate = Color(1, 1, 1, 0.55) if busy else Color.WHITE
	_go_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP


func _toast(msg: String) -> void:
	var l := G.gold_label(msg, G.FS_SM, false, Color("ffe9b0"))
	l.position = Vector2(0, 616)
	l.custom_minimum_size = Vector2(VIEW_W, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14：ESC 只在最上层生效）
		return
	if event.is_action_pressed("ui_cancel") and not _busy:
		Audio.sfx("ui_close")
		closed.emit()
		get_viewport().set_input_as_handled()


class _CurioStageCanvas extends Control:
	var _tex_stage: Texture2D
	var _tex_stele: Texture2D
	var _tex_chests: Texture2D

	var resonated := false
	var appraised_count := 0
	var role_id := "zs"
	var on_stele_clicked: Callable
	var on_chest_clicked: Callable
	var _t := 0.0
	var _fx_mode := ""
	var _fx_banner := ""
	var _fx_t := 0.0

	static func _load_png_tex(path: String) -> Texture2D:
		if ResourceLoader.exists(path):
			var t := load(path) as Texture2D
			if t != null:
				return t
		var abs_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_p):
			var img := Image.load_from_file(abs_p)
			if img != null and not img.is_empty():
				var it := ImageTexture.create_from_image(img)
				it.take_over_path(path)
				return it
		return null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_tex_stage = _load_png_tex("res://assets/ui/minigames/curio_stage_bg.png")
		_tex_stele = _load_png_tex("res://assets/ui/minigames/stele_monument_sheet.png")
		_tex_chests = _load_png_tex("res://assets/ui/minigames/curio_chests_sheet.png")

	func trigger_fx(mode: String, banner: String) -> void:
		_fx_mode = mode
		_fx_banner = banner
		_fx_t = 1.6
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if _fx_t > 0.0:
			_fx_t = maxf(0.0, _fx_t - delta)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if event.position.x < 204.0:
				if on_stele_clicked.is_valid():
					on_stele_clicked.call()
			elif event.position.x < 306.0:
				if on_chest_clicked.is_valid():
					on_chest_clicked.call("common")
			else:
				if on_chest_clicked.is_valid():
					on_chest_clicked.call("rare")

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var fnt: Font = G.font_reg

		# 1. 双舞台实景贴图（左：先祖古碑坛；右：行商木案灯火鉴宝席）
		if _tex_stage != null:
			draw_texture_rect(_tex_stage, Rect2(0, 0, w, h), false)
		else:
			draw_rect(Rect2(0, 0, w, h), Color("18100b"))

		# 2. 左半幅：先祖古碑（未共鸣态 Frame 0 / 铭文发光共鸣态 Frame 1）
		if _tex_stele != null:
			var s_frame := 1 if resonated else 0
			var s_src := Rect2(s_frame * 120.0, 0.0, 120.0, 140.0)
			var s_dst := Rect2(41.0, 34.0, 120.0, 140.0)
			if resonated:
				var pulse := 0.55 + 0.35 * sin(_t * 3.8)
				draw_circle(Vector2(101, 102), 54.0, Color(1.0, 0.82, 0.36, 0.16 * pulse))
			draw_texture_rect_region(_tex_stele, s_dst, s_src)

		# 左区顶栏与底座铭牌
		var l_top := Rect2(10, 8, 182, 24)
		draw_rect(l_top, Color(0.10, 0.07, 0.05, 0.88))
		draw_rect(l_top, Color("c89c52"), false, 1.0)
		var st_txt := "先祖古碑 · " + ("已共鸣" if resonated else "待参悟")
		draw_string_outline(fnt, Vector2(18, 25), st_txt, HORIZONTAL_ALIGNMENT_CENTER, 166, G.FS_XS, 3, Color(0.05, 0.03, 0.02, 0.95))
		draw_string(fnt, Vector2(18, 25), st_txt, HORIZONTAL_ALIGNMENT_CENTER, 166, G.FS_XS, Color("84f0a8") if resonated else Color("f3d486"))

		var l_bot := Rect2(22, h - 28, 158, 22)
		draw_rect(l_bot, Color(0.10, 0.06, 0.04, 0.88))
		draw_rect(l_bot, Color("b88c46"), false, 1.0)
		draw_string_outline(fnt, Vector2(28, h - 12), "点古碑参悟铭文", HORIZONTAL_ALIGNMENT_CENTER, 146, G.FS_XS, 3, Color(0.05, 0.03, 0.02, 0.95))
		draw_string(fnt, Vector2(28, h - 12), "点古碑参悟铭文", HORIZONTAL_ALIGNMENT_CENTER, 146, G.FS_XS, Color("f3e3c0"))

		# 3. 右半幅：慧眼识珍三段进度槽 + 双古玩宝匣（蒙尘古匣 & 鎏金秘宝匣）
		var r_top := Rect2(214, 8, 184, 24)
		draw_rect(r_top, Color(0.10, 0.07, 0.05, 0.88))
		draw_rect(r_top, Color("c89c52"), false, 1.0)
		draw_string_outline(fnt, Vector2(222, 25), "慧眼识珍进度：", HORIZONTAL_ALIGNMENT_LEFT, 110, G.FS_XS, 3, Color(0.05, 0.03, 0.02, 0.95))
		draw_string(fnt, Vector2(222, 25), "慧眼识珍进度：", HORIZONTAL_ALIGNMENT_LEFT, 110, G.FS_XS, Color("f3e3c0"))
		for pi in 3:
			var pc := Vector2(342 + pi * 18, 20)
			var lit := pi < appraised_count
			draw_circle(pc, 6.0, Color("2a1a10"))
			draw_circle(pc, 4.5, Color("ffd460") if lit else Color("58422c"))

		if _tex_chests != null:
			# 左侧：蒙尘古石匣 (260金)
			var c1_open := _fx_t > 0.0 and _fx_mode == "common"
			var c1_src := Rect2((2 if c1_open else 0) * 96.0, 0.0, 96.0, 96.0)
			draw_texture_rect_region(_tex_chests, Rect2(210.0, 68.0, 92.0, 92.0), c1_src)
			# 右侧：鎏金秘宝匣 (680金)
			var c2_open := _fx_t > 0.0 and _fx_mode == "rare"
			var c2_src := Rect2((2 if c2_open else 1) * 96.0, 0.0, 96.0, 96.0)
			draw_texture_rect_region(_tex_chests, Rect2(306.0, 64.0, 94.0, 94.0), c2_src)

		var tag1 := Rect2(214, h - 28, 86, 22)
		draw_rect(tag1, Color(0.10, 0.06, 0.04, 0.90))
		draw_rect(tag1, Color("b88c46"), false, 1.0)
		draw_string_outline(fnt, Vector2(218, h - 12), "古石匣 260金", HORIZONTAL_ALIGNMENT_CENTER, 78, G.FS_XS, 3, Color(0.05, 0.03, 0.02, 0.95))
		draw_string(fnt, Vector2(218, h - 12), "古石匣 260金", HORIZONTAL_ALIGNMENT_CENTER, 78, G.FS_XS, Color("e6cfa0"))

		var tag2 := Rect2(308, h - 28, 90, 22)
		draw_rect(tag2, Color(0.16, 0.06, 0.05, 0.92))
		draw_rect(tag2, Color("f2c76a"), false, 1.0)
		draw_string_outline(fnt, Vector2(312, h - 12), "秘宝匣 680金", HORIZONTAL_ALIGNMENT_CENTER, 82, G.FS_XS, 3, Color(0.05, 0.03, 0.02, 0.95))
		draw_string(fnt, Vector2(312, h - 12), "秘宝匣 680金", HORIZONTAL_ALIGNMENT_CENTER, 82, G.FS_XS, Color("ffe28a"))

		# 4. 参悟/开匣瞬间的金辉光环与顶部捷报
		if _fx_t > 0.0:
			var ratio := clampf(_fx_t / 1.6, 0.0, 1.0)
			var fx_center := Vector2(101, 102) if _fx_mode == "stele" else (Vector2(256, 112) if _fx_mode == "common" else Vector2(353, 110))
			var ring_r := (1.0 - ratio) * 62.0 + 14.0
			draw_arc(fx_center, ring_r, 0.0, TAU, 28, Color(1.0, 0.88, 0.45, ratio * 0.85), 2.5)
			var b_rect := Rect2(34, 38, w - 68, 26)
			draw_rect(b_rect, Color(0.14, 0.08, 0.04, 0.94 * ratio))
			draw_rect(b_rect, Color(0.98, 0.82, 0.42, ratio), false, 1.5)
			draw_string_outline(fnt, Vector2(44, 57), _fx_banner, HORIZONTAL_ALIGNMENT_CENTER, w - 88, G.FS_XS, 3, Color(0.05, 0.03, 0.02, 0.95 * ratio))
			draw_string(fnt, Vector2(44, 57), _fx_banner, HORIZONTAL_ALIGNMENT_CENTER, w - 88, G.FS_XS, Color(1.0, 0.92, 0.62, ratio))

