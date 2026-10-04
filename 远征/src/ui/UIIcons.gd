extends RefCounted
## 导航符号是一组同笔宽的矢量图；物品、人物、技能继续使用原像素素材。

static var _cache: Dictionary = {}

static func texture(key: String) -> Texture2D:
	if not _cache.has(key):
		var path := "res://assets/ui/pixel_icons/%s.png" % key
		if not ResourceLoader.exists(path): path = "res://assets/ui/navigation/%s.svg" % key
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key] as Texture2D

static func image(key: String, dimensions := Vector2(20, 20), tint := Color.WHITE) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture(key)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = dimensions
	icon.custom_minimum_size = dimensions
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color.WHITE if ResourceLoader.exists("res://assets/ui/pixel_icons/%s.png" % key) else tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

static func button_icon(button: Control, key: String, tint: Color) -> void:
	if button.has_meta("navigation_icon") or texture(key) == null:
		return
	var label := button.get_child(0) as Label
	if label == null:
		return
	button.set_meta("navigation_icon", key)
	# Node2D 不参与 PanelContainer 布局，保留既有第一个 Label 和按钮热区。
	var holder := Node2D.new()
	holder.name = "NavigationIcon"
	var icon := image(key, Vector2(18, 18), tint)
	holder.add_child(icon)
	button.add_child(holder)
	var style := button.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.content_margin_left += 24.0
	var place := func():
		var text_width := label.get_theme_font("font").get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		icon.position = Vector2((button.size.x - text_width) * 0.5 - 15.0, (button.size.y - 18.0) * 0.5)
	button.resized.connect(place)
	label.minimum_size_changed.connect(place)
	place.call()

