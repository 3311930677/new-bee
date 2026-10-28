extends RefCounted

# Masks use displayed pixels and the same alpha cutoff as pixel_cutout.gdshader.
# A separate bottom contour for every column preserves doorways and spaced feet.
static var _cache: Dictionary = {}
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
	source.convert(Image.FORMAT_RGBA8)
	source.resize(width, height, Image.INTERPOLATE_NEAREST)
	var front := PackedInt32Array()
	front.resize(width)
	front.fill(-1)
	var floor_y := -1
	var top_y := height
	for x in width:
		for y in height:
			if source.get_pixel(x,y).a < .5: continue
			front[x] = y
			floor_y = maxi(floor_y,y)
			top_y = mini(top_y,y)
	if floor_y < 0: return {}
	var visible_height := floor_y - top_y + 1
	# High silhouettes (an arch, an arm, a canopy) never become a ground contact.
	# Transparent padding is excluded from both the threshold and cast length.
	var foot_band := maxi(3,roundi(visible_height * (.16 if kind == "actor" else .22)))
	var length := clampi(roundi(visible_height * .11),4,16)
	var pad := 3
	var extent := Vector2i(width + length + pad * 2,height + ceili(length * LIGHT_CAST.y) + pad * 2)
	var contact := Image.create(extent.x,extent.y,false,Image.FORMAT_RGBA8)
	var core := Image.create(extent.x,extent.y,false,Image.FORMAT_RGBA8)
	contact.fill(Color.TRANSPARENT)
	core.fill(Color.TRANSPARENT)
	var contact_strength := .62 if kind == "building" else .52
	var eligible := PackedInt32Array()
	eligible.resize(width)
	eligible.fill(-1)
	for x in width:
		var foot := front[x]
		if foot < floor_y - foot_band: continue
		eligible[x] = foot
		# The darkest pixel touches the visible bottom, with only 2 px outside it.
		for dx in range(-1,2):
			for dy in range(-2,4):
				var falloff: float = [.30,.72,1.0,.66,.26,.06][dy+2]
				var alpha := contact_strength * falloff * (1.0 if dx == 0 else .45)
				_set_alpha_max(contact,x+dx+pad,foot+dy+pad,alpha)
		# Extrude each actual foot, never bridge missing columns into an ellipse.
		# Start at contact; every step outward weakens the shadow.
		for step in range(length+1):
			var t := float(step) / float(length)
			var alpha := .26 * pow(1.0-t,1.35)
			var shift := Vector2i(roundi(step*LIGHT_CAST.x),roundi(step*LIGHT_CAST.y))
			for rear in range(-3,1):
				_set_alpha_max(core,x+pad+shift.x,foot+pad+shift.y+rear,alpha)
	var cast := core.duplicate()
	# A 1 px penumbra matches the pixel art; no broad blur or ground-color patch.
	for x in range(1,extent.x-1):
		for y in range(1,extent.y-1):
			var alpha := core.get_pixel(x,y).a
			for delta in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
				alpha = maxf(alpha,core.get_pixel(x+delta.x,y+delta.y).a*.40)
			cast.set_pixel(x,y,Color(1,1,1,alpha))
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
