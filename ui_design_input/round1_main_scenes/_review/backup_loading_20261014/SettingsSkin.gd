extends RefCounted
## 设置页像素皮肤（assets/ui/settings_20261014）：从设置页参考稿 480 宽还原切出，1 美术像素 = 1 屏幕像素。
## 九宫格边距读 settings_kit.json；中段平铺不拉伸，颗粒不会被拉坏。只给设置页用，共用控件不设 plate 时画法不变。
const ROOT := "res://assets/ui/settings_20261014/"
static var _spec: Dictionary = {}
static var _styles: Dictionary = {}

static func texture(id: String) -> Texture2D:
	var path := ROOT + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## pad：文字与边框之间额外留的空（LineEdit 等需要内容边距的控件用）
static func style(id: String, pad := Vector2.ZERO) -> StyleBoxTexture:
	var key := "%s|%s" % [id, pad]
	if _styles.has(key): return _styles[key]
	if _spec.is_empty():
		_spec = (JSON.parse_string(FileAccess.get_file_as_string(ROOT + "settings_kit.json")) as Dictionary).get("items", {})
	var box := StyleBoxTexture.new()
	box.texture = texture(id)
	var sl: Array = _spec.get(id, {}).get("slice", [])
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

## 分组横幅：横幅底板 + 左侧图标 + 衬线标题。
static func section(words: String, icon: String) -> Control:
	const UI := preload("res://src/ui/TravelChestUI.gd")
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", style("section", Vector2(4, 0)))
	bar.custom_minimum_size.y = 44
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	if not icon.is_empty():
		var mark := G.ui_icon(icon, Vector2(22, 22), UI.PAPER)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
	row.add_child(UI.label(words, "section", UI.PAPER))
	return bar

## 行左侧的方形图标框（音乐、音效、静音……）。返回的控件 36×36，不拦鼠标。
static func icon_box(icon: String) -> Control:
	const UI := preload("res://src/ui/TravelChestUI.gd")
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style("icon_box"))
	box.custom_minimum_size = Vector2(36, 36)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := G.ui_icon(icon, Vector2(22, 22), UI.PAPER)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(mark)
	return box

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

static func field(edit: LineEdit) -> void:
	for state in ["normal", "focus", "read_only"]:
		edit.add_theme_stylebox_override(state, style("input", Vector2(6, 0)))
	edit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
