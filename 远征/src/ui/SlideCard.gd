# SlideCard.gd —— 轮播大卡（一屏一项：插画位 → 标题 → 状态 → 说明）
# 版式：卡片尺寸由外部给定（PageDeck 的一页），插画高度按卡片高度自适应（art_ratio），
#      所以同一套卡能塞进不同高度的面板，不必逐处改坐标。
# 插画：优先按 art_names（G.res_tex 索引名）找图，其次 art_fallback（直接 res:// 路径）；
#      找不到就画「柔光 + 远山」占位并在卡上标出素材名 —— 图生成后按名丢进
#      image/generated_*/ready/ 即可自动生效，不用改代码。
#
# cfg 字段：
#   kicker       左上角小字（如「秘 境 03 / 08」）
#   title        主标题（宋体大字）
#   subtitle     副标题一行（可选）
#   lines        说明行数组（可选，最多 3 行，自动换行居中）
#   footer       卡底提示（可选；有 on_click 时写「点击选定」之类）
#   badge        右上角状态徽标文字（空则不显示）
#   badge_color  徽标底色
#   art_names    素材名候选（Array[String]）
#   art_fallback 兜底资源路径（如 res://image/role/zs/pojun_icon.png）
#   art_hint     无图时显示的素材文件名（如 world_forest.png）
#   art_tint     占位与边框的色标（通常给主题色/稀有度色）
#   art_fit      contain（整图居中）/ cover（铺满裁切，默认 contain）
#   art_dim      true 时压暗插画（未解锁 / 未收集）
#   art_frame    叠加在插画上的外框素材名（如稀有度方框）
#   art_ratio    插画高占卡片高的比例（默认 0.52）
#   selected     初始选中态
#   on_click     点击回调（无参 Callable）；给了才会响应点击并启用 PASS 事件透传
class_name SlideCard
extends PanelContainer

var cfg: Dictionary = {}

var _sb: StyleBoxFlat = null
var _art: PanelContainer = null
var _inner: _ArtInner = null
var _head: HBoxContainer = null
var _kicker: Label = null
var _title: Label = null
var _subtitle: Label = null
var _lines: VBoxContainer = null
var _footer: Label = null
var _badge_box: PanelContainer = null
var _badge: Label = null
var _badge_sb: StyleBoxFlat = null
var _on_click: Callable = Callable()
var _pressed := false
var _press_pos := Vector2.ZERO


func _init(config: Dictionary = {}) -> void:
	cfg = config
	_on_click = cfg.get("on_click", Callable())
	# 可点击的卡用 PASS：自己吃掉点击，同时把拖拽事件透给 PageDeck 翻页
	mouse_filter = Control.MOUSE_FILTER_PASS if _on_click.is_valid() \
		else Control.MOUSE_FILTER_IGNORE
	if _on_click.is_valid():
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	_build()
	_apply_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_size()


## 把卡片包成 PageDeck 的一页：左右留出 gutter 给箭头，卡片居中
static func page(card: Control, deck_w: float, h: float, gutter := 40.0) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(deck_w, h)
	holder.size = Vector2(deck_w, h)
	card.position = Vector2(gutter, 0)
	card.custom_minimum_size = Vector2(maxf(80.0, deck_w - gutter * 2.0), h)
	card.size = card.custom_minimum_size
	holder.add_child(card)
	return holder


# ---------- 构建 ----------
func _build() -> void:
	_sb = StyleBoxFlat.new()
	_sb.bg_color = Color("f0e4c4")
	# 四角微差，避免机器感对称（与面板其它卡片同口径）
	_sb.corner_radius_top_left = 16
	_sb.corner_radius_top_right = 18
	_sb.corner_radius_bottom_left = 17
	_sb.corner_radius_bottom_right = 15
	_sb.set_border_width_all(1)
	_sb.border_color = Color("c0a068")
	G._apply_shadow(_sb, 6.0, 3.0, 0.32)
	_sb.content_margin_left = 18.0
	_sb.content_margin_right = 18.0
	_sb.content_margin_top = 14.0
	_sb.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", _sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	# 页眉：序号小字（左）+ 状态徽标（右）
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 6)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_head)

	_kicker = G.gold_label(String(cfg.get("kicker", "")), G.FS_XS, false, Color("8a6a34"), false)
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_kicker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.add_child(_kicker)

	_badge_sb = StyleBoxFlat.new()
	_badge_sb.bg_color = Color("7a7263")
	_badge_sb.set_corner_radius_all(9)
	_badge_sb.content_margin_left = 8.0
	_badge_sb.content_margin_right = 8.0
	_badge_sb.content_margin_top = 1.0
	_badge_sb.content_margin_bottom = 1.0
	_badge_box = PanelContainer.new()
	_badge_box.add_theme_stylebox_override("panel", _badge_sb)
	_badge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge = G.gold_label("", G.FS_XS, false, G.TEXT_LIGHT, false)
	_badge_box.add_child(_badge)
	_head.add_child(_badge_box)

	# 插画位：有图铺图，无图画占位（占位提示同时充当「该生成哪张图」的清单）
	_art = PanelContainer.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.clip_contents = true
	# 富余空间几乎全给插画（卡底那行提示只留 1 份），图才够大够居中
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.size_flags_stretch_ratio = 8.0
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color("faf3e0")
	asb.set_corner_radius_all(12)
	asb.set_border_width_all(1)
	var tint: Color = cfg.get("art_tint", Color("8d8474"))
	asb.border_color = Color(tint.r, tint.g, tint.b, 0.22)
	_art.add_theme_stylebox_override("panel", asb)
	col.add_child(_art)

	_inner = _ArtInner.new()
	_inner.setup(cfg)
	_art.add_child(_inner)

	_title = G.serif_label(String(cfg.get("title", "")), G.FS_LG, G.TEXT_DARK)
	col.add_child(_title)

	var sub_text := String(cfg.get("subtitle", ""))
	if sub_text != "":
		_subtitle = G.gold_label(sub_text, G.FS_XS, false, Color("8a6a34"), false)
		col.add_child(_subtitle)

	var rows: Array = cfg.get("lines", [])
	if not rows.is_empty():
		_lines = VBoxContainer.new()
		_lines.add_theme_constant_override("separation", 2)
		_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_lines)
		for s in rows:
			var l := G.gold_label(String(s), G.FS_SM, false, Color("5a4020"), false)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_lines.add_child(l)

	# 卡底提示行常驻（哪怕初始为空）：选中态刷新时只改文案，不必重建卡片
	_footer = G.gold_label(String(cfg.get("footer", "")), G.FS_XS, false, Color("8a6a34", 0.92), false)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_footer.size_flags_stretch_ratio = 1.0
	_footer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_footer.visible = _footer.text != ""
	col.add_child(_footer)

	set_badge(String(cfg.get("badge", "")), cfg.get("badge_color", Color("7a7263")))
	if bool(cfg.get("selected", false)):
		set_selected(true)


## 插画高 = 卡片高 × art_ratio，只作「下限」用：多出来的空间由 art 的 EXPAND 吸收，
## 所以给个小比例（0.35 上下）既让图占满，又不会把下面的文案顶出卡片
func _apply_size() -> void:
	if _art == null:
		return
	var ratio := float(cfg.get("art_ratio", 0.36))
	_art.custom_minimum_size.y = clampf(size.y * ratio, 44.0, 320.0)


# ---------- 状态 ----------
func set_selected(on: bool) -> void:
	if _sb == null:
		return
	_sb.bg_color = Color("f7eed4") if on else Color("f0e4c4")
	_sb.border_color = G.GOLD_BRIGHT if on else Color("c0a068")
	_sb.set_border_width_all(2 if on else 1)


func set_badge(text: String, color := Color("7a7263")) -> void:
	if _badge == null:
		return
	_badge.text = text
	_badge_box.visible = text != ""
	if text != "":
		var c: Color = color
		_badge_sb.bg_color = Color(c.r, c.g, c.b, 0.92)
	_sync_head()


func set_footer(text: String) -> void:
	if _footer == null:
		return
	_footer.text = text
	_footer.visible = text != ""


func _sync_head() -> void:
	if _head != null:
		_head.visible = (_kicker != null and _kicker.text != "") \
			or (_badge_box != null and _badge_box.visible)


func _gui_input(e: InputEvent) -> void:
	if not _on_click.is_valid():
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if (e as InputEventMouseButton).pressed:
			_pressed = true
			_press_pos = (e as InputEventMouseButton).global_position
		elif _pressed:
			_pressed = false
			# 位移小于阈值才算点击：拖拽翻页时不该顺带选中
			if (e as InputEventMouseButton).global_position.distance_to(_press_pos) < 12.0:
				_on_click.call()


# ---------- 插画内胆 ----------
## 有图：按 fit 铺满或居中，可叠加稀有度外框、可压暗；
## 无图：画柔光 + 远山占位，并标出「该生成哪张图」的素材名（留白等后续生成）
class _ArtInner extends Control:
	var tex: Texture2D = null
	var frame_tex: Texture2D = null
	var fit := "contain"
	var tint := Color("8d8474")
	var hint := ""
	var dim := false
	var _h1: Label = null
	var _h2: Label = null

	func setup(c: Dictionary) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint = c.get("art_tint", Color("8d8474"))
		fit = String(c.get("art_fit", "contain"))
		hint = String(c.get("art_hint", ""))
		dim = bool(c.get("art_dim", false))
		tex = _first_tex(c.get("art_names", []), String(c.get("art_fallback", "")))
		var frame_name := String(c.get("art_frame", ""))
		if frame_name != "":
			frame_tex = G.res_tex(frame_name)
		if tex != null:
			var pic := TextureRect.new()
			pic.texture = tex
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if fit == "cover" \
				else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.set_anchors_preset(Control.PRESET_FULL_RECT)
			pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# 大图缩小显示会起锯齿：铺满类插画走线性过滤，像素小图保持 nearest
			if fit == "cover":
				pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			if dim:
				pic.modulate = Color(0.34, 0.31, 0.29, 0.9)
			add_child(pic)
		if frame_tex != null:
			var fr := TextureRect.new()
			fr.texture = frame_tex
			fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			fr.stretch_mode = TextureRect.STRETCH_SCALE
			fr.set_anchors_preset(Control.PRESET_FULL_RECT)
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if dim:
				fr.modulate = Color(0.55, 0.55, 0.55, 0.85)
			add_child(fr)
		if tex == null and hint != "":
			_h1 = G.gold_label("此处留白 · 待补插画", G.FS_XS - 1, false, Color("9a8c6c"), false)
			_h2 = G.gold_label(hint, G.FS_XS - 2, false, Color("a89a7c"), false)
			add_child(_h1)
			add_child(_h2)

	func _ready() -> void:
		_layout()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_layout()

	func _layout() -> void:
		if _h1 == null:
			return
		_h1.custom_minimum_size = Vector2(size.x, 0)
		_h1.position = Vector2(0, size.y - 46.0)
		_h2.custom_minimum_size = Vector2(size.x, 0)
		_h2.position = Vector2(0, size.y - 28.0)

	func _draw() -> void:
		if tex != null or size.x <= 0.0 or size.y <= 0.0:
			return
		var w := size.x
		var h := size.y
		var cx := w * 0.5
		# 底：极淡主题色 + 中央柔光；远山轮廓收在下方，和两行小字错开 ——
		# 一眼看出是「配图位」而不是渲染失败
		# 只留一枚极淡的印记：不画山形，免得看着像「图裂了」
		draw_rect(Rect2(0, 0, w, h), Color(tint.r, tint.g, tint.b, 0.16))
		draw_circle(Vector2(cx, h * 0.42), minf(w, h) * 0.22, Color(tint.r, tint.g, tint.b, 0.14))
		var r := minf(w, h) * 0.085
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, h * 0.42 - r), Vector2(cx + r * 0.8, h * 0.42),
			Vector2(cx, h * 0.42 + r), Vector2(cx - r * 0.8, h * 0.42)]),
			Color(tint.r, tint.g, tint.b, 0.22))

	## 依次尝试索引名，再试兜底路径；都没有返回 null
	func _first_tex(names: Array, fallback: String) -> Texture2D:
		for n in names:
			var t: Texture2D = G.res_tex(String(n))
			if t != null:
				return t
		if fallback != "" and ResourceLoader.exists(fallback):
			return load(fallback) as Texture2D
		return null
