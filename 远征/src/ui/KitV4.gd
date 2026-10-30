class_name KitV4
extends RefCounted
## 玄漆鎏金 v4 统一视觉规范入口（2026-10-28 商业化画面重构方案 §3.1–3.8）。
## 提供色板、字阶、九宫格面板、三级按钮、页签、顶栏、底抽屉、品质槽位、角标、大数缩写与新素材表寻址。

const UiKit := preload("res://src/ui/UiKit.gd")

# ── §3.1 全局色板（玄漆鎏金） ──
const NIGHT := Color("120e0c")         # 玄漆底（弹窗/全屏底）
const FACE := Color("1a1412")          # 面板底（一级卡片）
const SELECTED := Color("2a201a")      # 选中底（当前选中项、激活页签）
const INSET := Color("0c0908")         # 凹槽底（进度条槽、输入框、空装备槽）
const TRIM := Color("c9a45c")          # 鎏金边（所有面板与卡片描边）
const BRIGHT := Color("f2c76a")        # 亮金高光（重要标题、选中描边、大数字）
const GOLD := BRIGHT                   # 金色别名
const CREAM := Color("f3e3c0")         # 象牙白（暗底正文）
const MUTED := Color("8f8376")         # 暖灰（次要说明、禁用文字）
const LACQUER_TOP := Color("9e2b25")   # 朱漆主色上沿
const LACQUER_BOT := Color("6e1a12")   # 朱漆主色下沿
const JADE := Color("55d8a8")          # 翠玉状态（仅用于增益/已完成/推荐文字与进度条）
const GOOD := JADE                     # 增益/正向对比色别名
const RED := Color("e2402c")           # 警示红（仅用于红点、不足、危险确认）
const PAPER := Color("e8dcc0")         # 内衬纸张（仅作暗框内衬阅读区）
const INK := Color("2d2218")           # 纸面墨字
const INK_SUB := Color("5a4430")       # 纸面次级墨字

const RARITY := [
	Color("8a8072"), # R0 凡品（铁灰）
	Color("4a7aa8"), # R1 良品（青钢）
	Color("7848a0"), # R2 珍品（紫晶）
	Color("a86820"), # R3 极品（赤金）
	Color("c9a45c"), # R4 绝品（鎏金）
	Color("b82a20"), # R5 传世（朱金）
]

const MANIFEST_PATH := "res://data/commercial_20261028.json"
const KEY_ALIASES := {
	"paper_card": "card_paper",
	"modal_frame": "panel_iron",
	"card_bg": "panel_iron",
	"bottom_drawer": "sheet_panel",
	"header_banner": "plaque_title",
	"name_plate": "nameplate",
	"player_card_bg": "player_card",
	"btn_primary_normal": "hero_normal",
	"btn_primary_hover": "hero_normal",
	"btn_primary_pressed": "hero_pressed",
	"btn_primary_disabled": "hero_disabled",
	"btn_secondary_normal": "btn_normal",
	"btn_secondary_hover": "btn_normal",
	"btn_secondary_pressed": "btn_pressed",
	"btn_secondary_disabled": "btn_disabled",
	"bg_character_stage": "role_stage_bg",
	"bg_talent_astrolabe": "talent_starfield_bg",
	"settle_win_header": "victory_header",
	"settle_lose_header": "defeat_header",
	"chest_open": "settlement_chest_open",
	"chest_closed": "settlement_chest_closed",
	"vfx_victory_burst": "vfx_victory_rays",
	"slot_silhouette_weapon": "slot_sil_weapon",
	"slot_silhouette_armor": "slot_sil_armor",
	"slot_silhouette_accessory": "slot_sil_accessory",
	"slot_silhouette_pet": "tab_pet",
	"slot_silhouette_mount": "tab_mount",
	"slot_silhouette_title": "tab_title",
	"talent_node_locked": "node_locked",
	"talent_node_avail": "node_open",
	"talent_node_max": "node_lit",
	"talent_node_ult": "node_ultimate",
	# Group F Regional Map Props (mapped to verified extracted components in assets/commercial_20261028/map/)
	# Broken Slope & Stele Cavern (F-06 sheet in raw)
	"f02a_broken_stele_1": "f06a_4",
	"f02a_broken_stele_2": "f06a_5",
	"f02a_fallen_tablet": "f06b_2",
	"f02b_moss_boulder_1": "f06a_1",
	"f02b_moss_boulder_2": "f06a_2",
	"f02b_stone_lantern": "f06a_6",
	# Salt Road, Port, Tideflat & Tidal Gate (F-03 sheet in raw)
	"f03a_salt_crystal_1": "f03b_4",
	"f03a_salt_crystal_2": "f03a_1",
	"f03a_salt_cart": "f03a_2",
	"f03b_wood_post_1": "f03b_9",
	"f03b_wood_post_2": "f03a_3",
	"f03b_salt_bucket": "f03b_1",
	# Red Sand Route (F-02 sheet in raw)
	"f04a_sandstone_1": "f02a_1",
	"f04a_sandstone_2": "f02a_4",
	"f04a_camel_bones": "f02b_1",
	"f04b_dry_shrub_1": "f02b_4",
	"f04b_dry_shrub_2": "f02b_5",
	"f04b_caravan_post": "f02b_8",
	# Rift Mine & Abyss / Stele Sanctum (F-05 sheet in raw)
	"f05a_mine_timber": "f05a_5",
	"f05a_rail_track": "f05b_7",
	"f05a_mine_cart": "f05a_3",
	"f05b_ore_crystal_1": "f05a_3",
	"f05b_ore_crystal_2": "f05a_4",
	"f05b_pickaxe_crate": "f05b_8",
	"f06a_abyss_pillar_1": "f05a_1",
	"f06a_abyss_pillar_2": "f05a_2",
	"f06a_rune_slab": "f05b_8",
	"f06b_obsidian_rock_1": "f05a_3",
	"f06b_obsidian_rock_2": "f05b_1",
	"f06b_void_brazier": "f05b_7",
}
static var _manifest: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func is_cancel(event: InputEvent) -> bool:
	return not G.ui_blocked and event.is_action_pressed("ui_cancel")


static func _ensure_manifest() -> void:
	if not _manifest.is_empty():
		return
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		_manifest = parsed


static func commercial_path(key: String) -> String:
	_ensure_manifest()
	var resolved: String = String(KEY_ALIASES.get(key, key))
	for candidate in [key, resolved]:
		if _manifest.has("assets") and _manifest["assets"] is Dictionary:
			var assets: Dictionary = _manifest["assets"]
			if assets.has(candidate):
				var entry: Variant = assets[candidate]
				if entry is Dictionary:
					return String((entry as Dictionary).get("file", ""))
				return String(entry)
		if _manifest.has(candidate):
			var top_entry: Variant = _manifest[candidate]
			if top_entry is Dictionary:
				return String((top_entry as Dictionary).get("file", ""))
			return String(top_entry)
	return ""


static func commercial_tex(key: String) -> Texture2D:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var resolved: String = String(KEY_ALIASES.get(key, key))
	var path := commercial_path(key)
	var tex: Texture2D = null
	if not path.is_empty():
		var abs_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_p):
			var img := Image.load_from_file(abs_p)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
		if tex == null and ResourceLoader.exists(path):
			tex = load(path) as Texture2D
	if tex == null:
		tex = UiKit.tex(key)
	if tex == null and resolved != key:
		tex = UiKit.tex(resolved)
	if tex != null:
		_tex_cache[key] = tex
	return tex


static func kit_tex(id: String) -> Texture2D:
	var resolved: String = String(KEY_ALIASES.get(id, id))
	var t := UiKit.tex(id)
	return t if t != null else UiKit.tex(resolved)


static func style(id: String, content_margin := -1) -> StyleBox:
	var resolved: String = String(KEY_ALIASES.get(id, id))
	var sb := UiKit.style(id, content_margin)
	if sb == null and resolved != id:
		sb = UiKit.style(resolved, content_margin)
	if sb != null:
		return sb
	var ctex := commercial_tex(id)
	if ctex != null:
		var st := StyleBoxTexture.new()
		st.texture = ctex
		var m := mini(18, mini(ctex.get_width(), ctex.get_height()) / 3)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			st.set_texture_margin(side, m)
			st.set_content_margin(side, content_margin if content_margin >= 0 else 12)
		return st
	var flat := StyleBoxFlat.new()
	var is_paper := id.contains("paper") or resolved.contains("paper")
	flat.bg_color = PAPER if is_paper else FACE
	flat.border_color = TRIM
	flat.set_border_width_all(1)
	flat.set_corner_radius_all(3)
	if content_margin >= 0:
		flat.set_content_margin_all(content_margin)
	return flat


## §3.4 / §3.8 统一数字缩写：
## < 10000 保持完整数字；10000..99999999 显示 "12.8万"；>= 100000000 显示 "1.2亿"。
static func fmt_compact(n: int) -> String:
	var v := absi(n)
	var sign_prefix := "-" if n < 0 else ""
	if v >= 100000000:
		var yi_tenths := roundi(float(v) / 10000000.0)
		return "%s%d.%d亿" % [sign_prefix, yi_tenths / 10, yi_tenths % 10]
	if v >= 10000:
		return "%s%d.%d万" % [sign_prefix, v / 10000, (v % 10000) / 1000]
	return str(n)


## §3.8 面板工厂：kind in ["night", "face", "selected", "inset", "paper", "banner"]
static func panel(kind := "face", pad := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var kit_id := "card_normal"
	match kind:
		"night", "body":
			kit_id = "panel_body"
		"sub":
			kit_id = "panel_sub"
		"selected":
			kit_id = "card_selected"
		"paper":
			kit_id = "card_paper"
		"banner":
			kit_id = "banner_stage"
		"inset":
			var flat := StyleBoxFlat.new()
			flat.bg_color = INSET
			flat.border_color = Color(TRIM, 0.55)
			flat.set_border_width_all(1)
			flat.set_corner_radius_all(3)
			flat.set_content_margin_all(pad)
			p.add_theme_stylebox_override("panel", flat)
			return p
	p.add_theme_stylebox_override("panel", style(kit_id, pad))
	return p


## §3.3 / §3.8 三级按钮工厂：tier in ["primary", "secondary", "ghost"]
static func button(text: String, tier := "primary", sub := "") -> Button:
	var b := Button.new()
	b.text = "" if not sub.is_empty() else text
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var is_primary := tier == "primary"
	var is_ghost := tier == "ghost"
	var min_h := 48.0 if is_primary else (34.0 if is_ghost else 40.0)
	b.custom_minimum_size = Vector2(96.0, min_h)
	var fs := G.FS_MD if is_primary else (G.FS_XS if is_ghost else G.FS_SM)
	var fnt := G.spaced_font(2 if is_primary else 1, is_primary, true)
	b.add_theme_font_override("font", fnt)
	b.add_theme_font_size_override("font_size", fs)
	var txt_col := BRIGHT if is_ghost else CREAM
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(k, txt_col)
	b.add_theme_color_override("font_pressed_color", BRIGHT)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.92))
	b.add_theme_constant_override("outline_size", 2)

	if is_ghost:
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(FACE, 0.45 if st == "hover" else (0.65 if st == "pressed" else 0.18))
			sb.border_color = BRIGHT if st == "hover" else Color(TRIM, 0.60)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(3)
			sb.content_margin_left = 10
			sb.content_margin_right = 10
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			b.add_theme_stylebox_override(st, sb)
	else:
		var styles: Dictionary = UiKit.button_styles("hero" if is_primary else "btn")
		for st in styles:
			b.add_theme_stylebox_override(st, styles[st])
		var focus_sb := styles.get("hover", styles.get("normal")) as StyleBox
		if focus_sb != null:
			b.add_theme_stylebox_override("focus", focus_sb)

	if not sub.is_empty():
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 0)
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var main_l := Label.new()
		main_l.text = text
		main_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_l.add_theme_font_override("font", fnt)
		main_l.add_theme_font_size_override("font_size", fs)
		main_l.add_theme_color_override("font_color", txt_col)
		main_l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.92))
		main_l.add_theme_constant_override("outline_size", 2)
		main_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(main_l)
		var sub_l := Label.new()
		sub_l.text = sub
		sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_l.add_theme_font_override("font", G.font_reg)
		sub_l.add_theme_font_size_override("font_size", G.FS_XS)
		sub_l.add_theme_color_override("font_color", BRIGHT if is_primary else MUTED)
		sub_l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.92))
		sub_l.add_theme_constant_override("outline_size", 2)
		sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(sub_l)
		b.add_child(vbox)
	b.pressed.connect(func(): Audio.sfx("ui_click"))
	return b


## §3.8 统一页签栏：激活态用 tab_active（朱漆底或亮金底描边），未激活用 tab_idle。
static func tabs(names: Array, on_select := Callable()) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var buttons: Array[Button] = []
	var apply_state := func(active_idx: int) -> void:
		for j in buttons.size():
			var tb := buttons[j]
			var sel := j == active_idx
			var sb := style("tab_active" if sel else "tab_idle", 6)
			for st in ["normal", "hover", "pressed", "focus"]:
				tb.add_theme_stylebox_override(st, sb)
			for ck in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				tb.add_theme_color_override(ck, BRIGHT if sel else MUTED)
	for i in names.size():
		var idx := i
		var tb := Button.new()
		tb.text = String(names[i])
		tb.toggle_mode = true
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(68, 36)
		tb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tb.add_theme_font_override("font", G.spaced_font(1, true, true))
		tb.add_theme_font_size_override("font_size", G.FS_XS)
		tb.pressed.connect(func():
			Audio.sfx("ui_page")
			apply_state.call(idx)
			if on_select.is_valid():
				on_select.call(idx))
		buttons.append(tb)
		row.add_child(tb)
	apply_state.call(0)
	return row


## §3.5 / §3.8 统一顶栏：高 52，左菱形返回键（40×40）、中鎏金标题牌匾、右货币胶囊或说明键。
static func top_bar(title: String, currencies := [], on_back := Callable(), on_help := Callable()) -> Control:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(480, 52)
	bar.size = Vector2(480, 52)
	bar.add_theme_stylebox_override("panel", style("header_bar", 0))
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var back := Button.new()
	back.name = "BackButton"
	back.text = "‹"
	back.tooltip_text = "返回"
	back.position = Vector2(10, 6)
	back.size = Vector2(40, 40)
	back.custom_minimum_size = Vector2(40, 40)
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.add_theme_font_override("font", G.font_bold)
	back.add_theme_font_size_override("font_size", G.FS_LG)
	for ck in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		back.add_theme_color_override(ck, BRIGHT)
	var back_sb := style("back_diamond", 0)
	for st in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(st, back_sb)
	if on_back.is_valid():
		back.pressed.connect(func():
			Audio.sfx("ui_close")
			on_back.call())
	bar.add_child(back)

	var plaque := Panel.new()
	plaque.position = Vector2(112, 4)
	plaque.size = Vector2(256, 44)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_theme_stylebox_override("panel", style("plaque_title", 0))
	bar.add_child(plaque)

	var title_l := Label.new()
	title_l.text = title
	title_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_l.add_theme_font_override("font", G.spaced_art_font(3))
	title_l.add_theme_font_size_override("font_size", G.FS_SECTION)
	title_l.add_theme_color_override("font_color", BRIGHT)
	title_l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.94))
	title_l.add_theme_constant_override("outline_size", 3)
	title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(title_l)

	if not currencies.is_empty():
		var cx := 468.0
		for i in range(currencies.size() - 1, -1, -1):
			var cur_key := String(currencies[i])
			var pill := Panel.new()
			pill.size = Vector2(96, 28)
			cx -= 96.0
			pill.position = Vector2(cx, 12)
			cx -= 6.0
			pill.add_theme_stylebox_override("panel", style("pill_currency", 4))
			pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var val_l := Label.new()
			val_l.text = fmt_compact(int(G.wallet.get(cur_key, 0)))
			val_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			val_l.add_theme_font_override("font", G.font_display)
			val_l.add_theme_font_size_override("font_size", G.FS_XS)
			val_l.add_theme_color_override("font_color", CREAM)
			pill.add_child(val_l)
			bar.add_child(pill)
	elif on_help.is_valid():
		var help := Button.new()
		help.name = "HelpButton"
		help.text = "?"
		help.tooltip_text = "规则说明"
		help.position = Vector2(432, 8)
		help.size = Vector2(36, 36)
		help.custom_minimum_size = Vector2(36, 36)
		help.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		help.add_theme_font_override("font", G.font_bold)
		help.add_theme_font_size_override("font_size", G.FS_SM)
		for ck in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			help.add_theme_color_override(ck, BRIGHT)
		var help_sb := style("btn_help", 0)
		for st in ["normal", "hover", "pressed", "focus"]:
			help.add_theme_stylebox_override(st, help_sb)
		help.pressed.connect(func():
			Audio.sfx("ui_click")
			on_help.call())
		bar.add_child(help)
	return bar


## §3.5 / §3.8 底部抽屉容器（T2 上舞台 + 下抽屉）
static func bottom_sheet(height := 360.0) -> PanelContainer:
	var sheet := panel("night", 16)
	sheet.custom_minimum_size = Vector2(480, height)
	sheet.size = Vector2(480, height)
	return sheet


## §3.8 品质槽位（64×64，slot_r0..slot_r4）
static func rarity_slot(rarity: int, icon: Texture2D = null, count := 0) -> Panel:
	var r := clampi(rarity, 0, 4)
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(64, 64)
	cell.size = Vector2(64, 64)
	cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cell.add_theme_stylebox_override("panel", style("slot_r%d" % r, 6))
	if icon != null:
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.texture = icon
		tr.position = Vector2(8, 8)
		tr.size = Vector2(48, 48)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tr)
	if count > 1:
		var cnt := Label.new()
		cnt.text = fmt_compact(count)
		cnt.position = Vector2(6, 40)
		cnt.size = Vector2(52, 20)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cnt.add_theme_font_override("font", G.font_display)
		cnt.add_theme_font_size_override("font_size", G.FS_XS)
		cnt.add_theme_color_override("font_color", CREAM)
		cnt.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.95))
		cnt.add_theme_constant_override("outline_size", 3)
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cnt)
	return cell


## §3.8 角标与印章：kind in ["dot", "lock", "check", "equip", "seal"]
static func badge(kind := "dot", text := "") -> Control:
	var map_id := {
		"dot": "badge_dot",
		"lock": "badge_lock",
		"check": "badge_check",
		"equip": "tag_equip",
		"seal": "seal_stamp",
	}
	var kit_id := String(map_id.get(kind, "badge_dot"))
	var sz_map := {
		"dot": Vector2(14, 14),
		"lock": Vector2(20, 20),
		"check": Vector2(20, 20),
		"equip": Vector2(36, 18),
		"seal": Vector2(44, 44),
	}
	var sz: Vector2 = sz_map.get(kind, Vector2(20, 20))
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.texture = kit_tex(kit_id)
	tr.custom_minimum_size = sz
	tr.size = sz
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not text.is_empty():
		var lbl := Label.new()
		lbl.text = text
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", G.font_bold)
		lbl.add_theme_font_size_override("font_size", G.FS_XS)
		lbl.add_theme_color_override("font_color", CREAM)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.add_child(lbl)
	return tr


static func slot_key(rarity_rank: int) -> String:
	match clampi(rarity_rank, 1, 5):
		1: return "slot_common"
		2: return "slot_uncommon"
		3: return "slot_rare"
		4: return "slot_epic"
		_: return "slot_legend"


static func red_dot() -> Control:
	return badge("dot")


class ProgressStrip extends Control:
	var bar_kind := "hp"
	var ratio := 0.0:
		set(v):
			ratio = clampf(v, 0.0, 1.0)
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		resized.connect(queue_redraw)

	func _draw() -> void:
		var track_sb := KitV4.style("bar_track", 0)
		if track_sb == null:
			track_sb = KitV4.style("bar_frame", 0)
		if track_sb != null:
			draw_style_box(track_sb, Rect2(Vector2.ZERO, size))
		else:
			draw_rect(Rect2(Vector2.ZERO, size), KitV4.INSET)
			draw_rect(Rect2(Vector2.ZERO, size), KitV4.TRIM, false, 1.0)
		var fill_w := maxf(0.0, (size.x - 4.0) * ratio)
		if fill_w > 0.5:
			var fill_rect := Rect2(Vector2(2.0, 2.0), Vector2(fill_w, maxf(2.0, size.y - 4.0)))
			var fill_sb := KitV4.style("bar_fill_" + bar_kind, 0)
			if fill_sb != null:
				draw_style_box(fill_sb, fill_rect)
			else:
				var col := KitV4.JADE if bar_kind == "exp" else (KitV4.RED if bar_kind == "hp" else KitV4.GOLD)
				draw_rect(fill_rect, col)


static func bar(sz := Vector2(200, 14), kind := "hp") -> Control:
	var b := ProgressStrip.new()
	b.bar_kind = kind
	b.custom_minimum_size = sz
	b.size = sz
	return b

