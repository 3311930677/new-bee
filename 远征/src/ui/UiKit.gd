extends RefCounted
## 生图还原的 UI 素材包（assets/ui/kit_20261013）。贴图按 1 美术像素 = 1 屏幕像素烘焙，与地图颗粒一致；
## 九宫格边距读 ui_kit_spec.json（美术像素 × art_to_screen），中段用平铺而不是拉伸，像素颗粒不会被拉坏。
const ROOT := "res://assets/ui/kit_20261013/"
static var _spec: Dictionary = {}
static var _px := 0.0  # art_to_screen，从 spec 读
static var _styles: Dictionary = {}

static func spec(id: String) -> Dictionary:
	if _spec.is_empty():
		var doc := JSON.parse_string(FileAccess.get_file_as_string(ROOT + "ui_kit_spec.json")) as Dictionary
		_spec = doc.get("items", {})
		_px = float(doc.get("art_to_screen", 1))
	return _spec.get(id, {})

static func px() -> float:
	if _px == 0.0: spec("")
	return _px

static func texture(id: String) -> Texture2D:
	var path := ROOT + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

## 九宫格样式；没有切线的素材（格子、圆座）整张不拉伸，按原尺寸居中使用。
## 部分生成素材比场景色调更艳，按素材统一压一档，和背景、角色的暗暖色板对齐。
## 主按钮已换成暗红如意纹版本（UI-01 第二版），无需再压色。
const TINT := {}

static func style(id: String) -> StyleBoxTexture:
	if _styles.has(id): return _styles[id]
	var tex := texture(id)
	if tex == null: return null
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.modulate_color = TINT.get(id, Color.WHITE)
	var sl: Variant = spec(id).get("slice")
	if sl is Array:
		box.texture_margin_left = float(sl[0]) * px()
		box.texture_margin_top = float(sl[1]) * px()
		box.texture_margin_right = float(sl[2]) * px()
		box.texture_margin_bottom = float(sl[3]) * px()
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_styles[id] = box
	return box

## 按素材原尺寸画出（格子、圆座、条填充等不做九宫格的素材）。
static func blit(canvas: CanvasItem, id: String, at: Vector2, tint := Color.WHITE) -> void:
	var tex := texture(id)
	if tex != null: canvas.draw_texture(tex, (at / px()).floor() * px(), tint)

## 把矩形对齐到美术像素网格，避免九宫格角块落在半像素上发虚。
static func snap(r: Rect2) -> Rect2:
	var g := px()
	var p := (r.position / g).floor() * g
	return Rect2(p, ((r.end / g).floor() * g) - p)
