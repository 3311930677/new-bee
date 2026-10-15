extends RefCounted
## 设置页像素皮肤（assets/ui/settings_20261014）：从设置页参考稿 480 宽还原切出，1 美术像素 = 1 屏幕像素。
## 九宫格边距读 settings_kit.json / scene.json；中段平铺不拉伸，颗粒不会被拉坏。只给设置页用，共用控件不设 plate 时画法不变。
## 场景层（背景三段、返回键、旅人卡、图标）由 tools/slice_settings_scene.py 生成，坐标是参考稿 480 宽坐标。
const ROOT := "res://assets/ui/settings_20261014/"
static var _spec: Dictionary = {}
static var _scene: Dictionary = {}
static var _styles: Dictionary = {}

static func texture(id: String) -> Texture2D:
	var path := ROOT + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## scene.json 里一件素材的信息（size / pos / slice ...），没有时为空字典
static func scene(id: String) -> Dictionary:
	if _scene.is_empty():
		_scene = (JSON.parse_string(FileAccess.get_file_as_string(ROOT + "scene.json")) as Dictionary).get("items", {})
	return _scene.get(id, {})

## pad：文字与边框之间额外留的空（LineEdit 等需要内容边距的控件用）
static func style(id: String, pad := Vector2.ZERO) -> StyleBoxTexture:
	var key := "%s|%s" % [id, pad]
	if _styles.has(key): return _styles[key]
	if _spec.is_empty():
		_spec = (JSON.parse_string(FileAccess.get_file_as_string(ROOT + "settings_kit.json")) as Dictionary).get("items", {})
	var box := StyleBoxTexture.new()
	box.texture = texture(id)
	var sl: Array = _spec.get(id, {}).get("slice", scene(id).get("slice", []))
	if sl.size() == 4:
		box.texture_margin_left = sl[0]
		box.texture_margin_top = sl[1]
		box.texture_margin_right = sl[2]
		box.texture_margin_bottom = sl[3]
		box.content_margin_left = sl[0] + pad.x
		box.content_margin_right = sl[2] + pad.x
		box.content_margin_top = sl[1] + pad.y
		box.content_margin_bottom = sl[3] + pad.y
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_styles[key] = box
	return box

## 原尺寸贴图（1:1、不拦鼠标）
static func sprite(id: String) -> TextureRect:
	var t := TextureRect.new()
	t.name = id
	t.texture = texture(id)
	# 参考稿里没有的图标退回游戏通用像素图标（ic_door → pixel_icons/door）
	if t.texture == null and id.begins_with("ic_"):
		t.texture = preload("res://src/ui/UIIcons.gd").texture(id.trim_prefix("ic_"))
	t.custom_minimum_size = t.texture.get_size() if t.texture != null else Vector2.ZERO
	t.size = t.custom_minimum_size
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## 分组横幅：横幅底板 + 左侧图标（参考稿切出的 ic_sec_*，统一放在 36 宽的格里，标题对齐）+ 衬线标题。
static func section(words: String, icon: String) -> Control:
	const UI := preload("res://src/ui/TravelChestUI.gd")
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", style("section", Vector2(4, 0)))
	bar.custom_minimum_size.y = 44
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	if not icon.is_empty():
		var cell := CenterContainer.new()
		cell.custom_minimum_size = Vector2(36, 0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(sprite("ic_" + icon))
		row.add_child(cell)
	var title := UI.label(words, "section", UI.PAPER)
	title.add_theme_font_size_override("font_size", 19)
	row.add_child(title)
	return bar

## 行左侧的方形图标框：参考稿里整块切出（框 + 图标，ib_*）；没有对应素材时退回通用图标叠在空框上。
static func icon_box(icon: String) -> Control:
	if texture("ib_" + icon) != null:
		var box := sprite("ib_" + icon)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return box
	const UI := preload("res://src/ui/TravelChestUI.gd")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style("icon_box"))
	panel.custom_minimum_size = Vector2(36, 36)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := G.ui_icon(icon, Vector2(22, 22), UI.PAPER)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_child(mark)
	return panel

static func _text_width(caption: Label) -> float:
	return caption.get_theme_font("font").get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		caption.get_theme_font_size("font_size")).x

## 按钮图标。row=true：参考稿的行按钮，图标在左、文字左对齐、右侧箭头；
## 否则图标 + 文字作为一组居中（gap 为两者间距）。按下随文字下沉 1px，禁用时与文字一起压暗。
static func button_icon(b: Button, icon: String, row := false, gap := 12.0) -> void:
	var mark := sprite("ic_" + icon)
	b.add_child(mark)
	var chevron: TextureRect = null
	if row:
		b.set("caption_inset", 88.0)
		(b.get("caption") as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		chevron = sprite("ic_chevron")
		b.add_child(chevron)
	else:
		b.set("caption_inset", mark.size.x + gap)
	b.draw.connect(func():
		var sink := 1.0 if b.is_pressed() else 0.0
		var ink := Color(.6, .6, .6) if b.disabled else Color.WHITE
		mark.modulate = ink
		if row:
			mark.position = Vector2(roundf(46.0 - mark.size.x * .5), roundf((b.size.y - mark.size.y) * .5) + sink)
			chevron.position = Vector2(b.size.x - 38.0, roundf((b.size.y - chevron.size.y) * .5) + sink)
			chevron.modulate = ink
		else:
			var group := mark.size.x + gap + _text_width(b.get("caption"))
			mark.position = Vector2(roundf((b.size.x - group) * .5), roundf((b.size.y - mark.size.y) * .5) + sink))

## 主按钮两侧的菱形纹（参考稿"保存昵称"）
static func ornaments(b: Button) -> void:
	var left := sprite("ic_orn")
	var right := sprite("ic_orn")
	b.add_child(left)
	b.add_child(right)
	b.draw.connect(func():
		var w := _text_width(b.get("caption"))
		var y := roundf((b.size.y - left.size.y) * .5) + (1.0 if b.is_pressed() else 0.0)
		left.position = Vector2(roundf((b.size.x - w) * .5) - 20.0 - left.size.x, y)
		right.position = Vector2(roundf((b.size.x + w) * .5) + 20.0, y)
		for o in [left, right]: o.modulate = Color(.6, .6, .6) if b.disabled else Color.WHITE)

## 滑条：参考稿是蓝灰已填段 + 暗金未填段 + 金色十字方钮。
static func slider(sl: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("8a7552")
	track.border_color = Color("2a2024")
	track.set_border_width_all(1)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color("475665")
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := texture("grabber")
	sl.add_theme_icon_override("grabber", knob)
	sl.add_theme_icon_override("grabber_highlight", knob)
	sl.add_theme_icon_override("grabber_disabled", knob)
	sl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## 输入框；pencil=true 时左侧加参考稿的铅笔图标（恢复存档码那一栏）。
static func field(edit: LineEdit, pencil := false) -> void:
	var box := style("input", Vector2(6, 0))
	if pencil:
		box = box.duplicate() as StyleBoxTexture
		box.content_margin_left += 30.0
		var mark := sprite("ic_pencil")
		edit.add_child(mark)
		edit.resized.connect(func(): mark.position = Vector2(14, roundf((edit.size.y - mark.size.y) * .5)))
	for state in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(state, box)
	edit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## 圆形裁切（旅人卡头像用）
static func circle_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 c = texture(TEXTURE, UV); float d = distance(UV, vec2(.5)); c.a *= step(d, .5); COLOR = c; }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## 整页底图：上段夜景（标题与返回键已画在里面）+ 中段面板平铺 + 下段栏杆灯笼。
## 横向按 480 宽美术居中，纵向上段贴安全区顶、下段贴屏幕底；安全区以上补夜空色。
## 屏幕比参考稿（853）矮时，下段最多下沉 40px（只裁掉地砖，栏杆完整），给内容腾出位置。
class Backdrop extends Control:
	const ROOT := "res://assets/ui/settings_20261014/"
	var safe := Rect2()
	var art_x := 0.0
	var _top: Texture2D = load(ROOT + "bg_top.png")
	var _mid: Texture2D = load(ROOT + "bg_mid.png")
	var _bottom: Texture2D = load(ROOT + "bg_bottom.png")
	var _sky := Color("0b1a2e")
	const ART_H := 853.0
	const MAX_SINK := 40.0
	func bottom_y(view_h: float) -> float:
		return view_h - _bottom.get_height() + clampf(ART_H - view_h, 0.0, MAX_SINK)
	func _init() -> void:
		name = "SettingsBackdrop"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var info: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(ROOT + "scene.json")) as Dictionary).items.bg_top
		_sky = Color(String(info.get("sky", "0b1a2e")))
	func _draw() -> void:
		var w := float(_top.get_width())
		art_x = roundf((size.x - w) * .5)
		var top_y := safe.position.y
		var bottom_y := bottom_y(size.y)
		draw_rect(Rect2(Vector2.ZERO, size), _sky)
		var mid_y := top_y + _top.get_height()
		if bottom_y > mid_y:
			draw_texture_rect(_mid, Rect2(art_x, mid_y, w, bottom_y - mid_y), true)
		draw_texture(_bottom, Vector2(art_x, bottom_y))
		draw_texture(_top, Vector2(art_x, top_y))
