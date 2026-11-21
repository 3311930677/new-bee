extends RefCounted

# Masks use displayed pixels and the same alpha cutoff as pixel_cutout.gdshader.
# A separate bottom contour for every column preserves doorways and spaced feet.
static var _cache: Dictionary = {}
static func clear_cache() -> void:
	_cache.clear()
const SHADOW_INK := Color("1d241f")
const SNOW_INK := Color("263038")
const LIGHT_CAST := Vector2(1.0, 0.55)

static func prepare(art: Texture2D, width: int, height: int) -> Dictionary:
	return _grounding(art, width, height, "building")

static func silhouette(art: Texture2D, width: int, height: int) -> Dictionary:
	return _grounding(art, width, height, "prop")

static func actor(art: Texture2D, width: int, height: int) -> Dictionary:
	return _grounding(art, width, height, "actor")

static func _art_key(art: Texture2D) -> String:
	# AtlasTexture shares its atlas RID. Region and margin identify its own feet.
	if art is AtlasTexture:
		return "%s:%s:%s" % [_art_key(art.atlas),art.region,art.margin]
	return art.resource_path if not art.resource_path.is_empty() else str(art.get_rid().get_id())

static func _grounding(art: Texture2D, width: int, height: int, kind: String) -> Dictionary:
	var source_key := _art_key(art)
	var key := "%s:%s:%d:%d" % [kind, source_key, width, height]
	if _cache.has(key): return _cache[key]
	var source := art.get_image()
	if source == null or source.is_empty(): return {}
	if source.is_compressed(): source.decompress()
	if source.get_format() != Image.FORMAT_RGBA8: source.convert(Image.FORMAT_RGBA8)
	source.resize(width, height, Image.INTERPOLATE_NEAREST)
	var src_bytes: PackedByteArray = source.get_data()
	var front := PackedInt32Array()
	front.resize(width)
	front.fill(-1)
	var floor_y := -1
	var top_y := height
	for x in width:
		var col_off := x * 4 + 3
		for y in range(height - 1, -1, -1):
			if src_bytes[y * width * 4 + col_off] >= 128:
				front[x] = y
				if y > floor_y: floor_y = y
				break
		if front[x] >= 0:
			for y in range(0, mini(top_y, front[x] + 1)):
				if src_bytes[y * width * 4 + col_off] >= 128:
					top_y = y
					break
	if floor_y < 0: return {}
	var visible_height := floor_y - top_y + 1
	# High silhouettes (an arch, an arm, a canopy) never become a ground contact.
	# Transparent padding is excluded from both the threshold and cast length.
	var foot_band := maxi(3,roundi(visible_height * (.16 if kind == "actor" else .22)))
	var length := clampi(roundi(visible_height * .11),4,16)
	var pad := 3
	var ext_w := width + length + pad * 2
	var ext_h := height + ceili(length * LIGHT_CAST.y) + pad * 2
	var contact_bytes := PackedByteArray()
	contact_bytes.resize(ext_w * ext_h * 4)
	var core_alpha := PackedByteArray()
	core_alpha.resize(ext_w * ext_h)
	var contact_strength := .62 if kind == "building" else .52
	var eligible := PackedInt32Array()
	eligible.resize(width)
	eligible.fill(-1)
	var band_min_y := ext_h
	var band_max_y := -1
	var falloffs := [0.30, 0.72, 1.0, 0.66, 0.26, 0.06]
	var step_alphas := PackedInt32Array()
	var step_sx := PackedInt32Array()
	var step_sy := PackedInt32Array()
	step_alphas.resize(length + 1)
	step_sx.resize(length + 1)
	step_sy.resize(length + 1)
	for step in range(length + 1):
		var t := float(step) / float(length)
		step_alphas[step] = clampi(roundi(255.0 * 0.26 * pow(1.0 - t, 1.35)), 0, 255)
		step_sx[step] = roundi(step * LIGHT_CAST.x)
		step_sy[step] = roundi(step * LIGHT_CAST.y)
	for x in width:
		var foot := front[x]
		if foot < floor_y - foot_band: continue
		eligible[x] = foot
		for dx in range(-1, 2):
			var cx := x + dx + pad
			if cx < 0 or cx >= ext_w: continue
			var dx_mul := 1.0 if dx == 0 else 0.45
			for dy in range(-2, 4):
				var cy := foot + dy + pad
				if cy < 0 or cy >= ext_h: continue
				var a_byte := clampi(roundi(255.0 * contact_strength * falloffs[dy + 2] * dx_mul), 0, 255)
				var off := (cy * ext_w + cx) * 4
				if a_byte > contact_bytes[off + 3]:
					contact_bytes[off] = 255
					contact_bytes[off + 1] = 255
					contact_bytes[off + 2] = 255
					contact_bytes[off + 3] = a_byte
		for step in range(length + 1):
			var a_byte := step_alphas[step]
			var px := x + pad + step_sx[step]
			if px < 0 or px >= ext_w: continue
			var base_py := foot + pad + step_sy[step]
			for rear in range(-3, 1):
				var py := base_py + rear
				if py < 0 or py >= ext_h: continue
				var idx := py * ext_w + px
				if a_byte > core_alpha[idx]:
					core_alpha[idx] = a_byte
				if py < band_min_y: band_min_y = py
				if py > band_max_y: band_max_y = py
	var cast_bytes := PackedByteArray()
	cast_bytes.resize(ext_w * ext_h * 4)
	if band_max_y >= band_min_y:
		var y_start := maxi(1, band_min_y - 1)
		var y_end := mini(ext_h - 1, band_max_y + 2)
		for y in range(y_start, y_end):
			var row := y * ext_w
			var row_up := row - ext_w
			var row_dn := row + ext_w
			for x in range(1, ext_w - 1):
				var idx := row + x
				var a := core_alpha[idx]
				var nb := maxi(maxi(core_alpha[idx - 1], core_alpha[idx + 1]), maxi(core_alpha[row_up + x], core_alpha[row_dn + x]))
				var pen := int(nb * 40 / 100)
				if pen > a: a = pen
				if a > 0:
					var off := idx * 4
					cast_bytes[off] = 255
					cast_bytes[off + 1] = 255
					cast_bytes[off + 2] = 255
					cast_bytes[off + 3] = a
	var contact := Image.create_from_data(ext_w, ext_h, false, Image.FORMAT_RGBA8, contact_bytes)
	var cast := Image.create_from_data(ext_w, ext_h, false, Image.FORMAT_RGBA8, cast_bytes)
	var row := {"cast":ImageTexture.create_from_image(cast),"contact":ImageTexture.create_from_image(contact),
		"offset":Vector2(-width*.5-pad,-pad),"visible_floor":floor_y,"image_height":height,
		"feet":eligible,"cast_length":length,"padding":pad}
	_cache[key] = row
	return row

static func _set_alpha_max(mask: Image, x: int, y: int, alpha: float) -> void:
	if x < 0 or y < 0 or x >= mask.get_width() or y >= mask.get_height(): return
	if alpha > mask.get_pixel(x,y).a: mask.set_pixel(x,y,Color(1,1,1,alpha))

static func draw_prop(canvas: CanvasItem, row: Dictionary, art_at: Vector2, width: float, snow := false) -> void:
	if row.is_empty(): return
	var at := art_at + Vector2(width*.5,0) + Vector2(row.offset)
	var ink := SNOW_INK if snow else SHADOW_INK
	canvas.draw_texture(row.cast,at,ink)
	canvas.draw_texture(row.contact,at,ink)

static func attach(parent: Node2D, row: Dictionary, art_top: float, snow: bool) -> void:
	if row.is_empty(): return
	var ground := Node2D.new()
	ground.name = "FoundationGround"
	ground.show_behind_parent = true
	ground.position = Vector2(0,art_top)
	parent.add_child(ground)
	ground.visible = parent.built()
	for kind in ["cast","contact"]:
		var sprite := Sprite2D.new()
		sprite.name = kind.capitalize()
		sprite.centered = false
		sprite.texture = row[kind]
		sprite.position = row.offset
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.use_parent_material = false
		sprite.modulate = SNOW_INK if snow else SHADOW_INK
		ground.add_child(sprite)
