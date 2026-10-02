extends RefCounted

# Tile to world units, clipping the last row/column instead of stretching a strip.
# Shared cache avoids loading textures during every redraw of a story prop.
static var _textures: Dictionary = {}

static func tiled(canvas: CanvasItem, path: String, rect: Rect2,
		tile_size := Vector2(96, 96), tint := Color.WHITE, source_region := Rect2()) -> void:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	var tex: Texture2D = _textures[path]
	if tex == null: return
	if source_region.size == Vector2.ZERO:
		source_region = Rect2(Vector2.ZERO, tex.get_size())
	var y := rect.position.y
	while y < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var cell := Vector2(minf(tile_size.x, rect.end.x - x), minf(tile_size.y, rect.end.y - y))
			canvas.draw_texture_rect_region(tex, Rect2(Vector2(x, y), cell),
				Rect2(source_region.position, source_region.size * cell / tile_size), tint)
			x += tile_size.x
		y += tile_size.y
