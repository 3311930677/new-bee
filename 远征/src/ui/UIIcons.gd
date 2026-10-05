extends RefCounted
## 小器物图标用实色切面与清楚的轮廓；人物、装备、技能继续使用原像素素材。

const REFINED_KEYS := ["settings", "coin", "expedition", "soul", "gem", "honor",
	"ticket", "ticket_sweep", "sound", "save", "person", "music", "shake", "story", "speed", "close"]
const RESOURCE_KEYS := {
	"cur_gold": "coin", "cur_expedition": "expedition", "cur_soul": "soul", "cur_honor": "honor",
	"itm_ticket_ten": "ticket", "itm_ticket_sweep": "ticket_sweep",
}

static var _cache: Dictionary = {}

static func resource_path(res_name: String) -> String:
	return refined_path(String(RESOURCE_KEYS[res_name])) if RESOURCE_KEYS.has(res_name) else ""

static func refined_path(key: String) -> String:
	return "res://assets/ui/refined_icons/%s.svg" % key if key in REFINED_KEYS else ""

static func colored(key: String) -> bool:
	return key in REFINED_KEYS or ResourceLoader.exists("res://assets/ui/pixel_icons/%s.png" % key)

static func texture(key: String) -> Texture2D:
	if not _cache.has(key):
		var path := refined_path(key)
		if path.is_empty(): path = "res://assets/ui/pixel_icons/%s.png" % key
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
	icon.set_meta("colored_icon", colored(key))
	icon.modulate = Color.WHITE if colored(key) else tint
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
	var icon := image(key, Vector2(22, 22), tint)
	holder.add_child(icon)
	button.add_child(holder)
	var style := button.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.content_margin_left += 28.0
	var place := func():
		var text_width := label.get_theme_font("font").get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		icon.position = Vector2(roundf((button.size.x - text_width) * 0.5 - 17.0), roundf((button.size.y - 22.0) * 0.5))
	button.resized.connect(place)
	label.minimum_size_changed.connect(place)
	place.call()

