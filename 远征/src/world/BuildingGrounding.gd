extends RefCounted

# Ground effects are registered to the visible foundation, including its steps.
# Work in displayed pixels and cache the result; source artwork stays untouched.
static var _cache: Dictionary = {}

static func prepare(art: Texture2D, width: int, height: int) -> Dictionary:
	var source_key := art.resource_path if not art.resource_path.is_empty() else str(art.get_rid().get_id())
	var key := "%s:%d:%d" % [source_key, width, height]
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
	for x in width:
		for y in range(height - 1, -1, -1):
			if source.get_pixel(x, y).a >= 0.5:
				front[x] = y
				floor_y = maxi(floor_y, y)
				break
	if floor_y < 0: return {}
	var threshold := floor_y - roundi(height * 0.27)
	var left := width
	var right := -1
	var min_y := floor_y
	for x in width:
		if front[x] >= threshold:
			left = mini(left, x)
			right = maxi(right, x)
			min_y = mini(min_y, front[x])
	if right <= left: return {}
	# Any holes between stone blocks belong to the same continuous foundation.
	for x in range(left, right + 1):
		if front[x] < threshold:
			front[x] = front[x - 1] if x > left else floor_y
	var pad := 16
	var rear_depth := 18
	var top := mini(min_y - rear_depth - pad, floor_y - 26)
	var canvas_size := Vector2i(width + pad * 2, floor_y - top + 33)
	var contact := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	var cast := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	var wear := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	contact.fill(Color.TRANSPARENT)
	cast.fill(Color.TRANSPARENT)
	wear.fill(Color.TRANSPARENT)
	for x in range(left - 12, right + 13):
		var sample_x := clampi(x, left, right)
		var side_distance := absf(float(x - sample_x))
		var boundary := float(front[sample_x])
		for y in range(top, floor_y + 33):
			var edge_distance := maxf(side_distance, maxf(float(y) - boundary, boundary - rear_depth - float(y)))
			var px := x + pad
			var py := y - top
			if edge_distance <= 3.0:
				contact.set_pixel(px, py, Color(1, 1, 1, 0.46 * clampf((4.0 - edge_distance) / 4.0, 0, 1)))
			# Directional cast follows the same contour and fades over a few pixels.
			var cast_x := clampi(x - 4, left, right)
			var cast_edge := maxf(absf(float(x - 4 - cast_x)), maxf(float(y - 3 - front[cast_x]), float(front[cast_x] - rear_depth - y + 3)))
			if cast_edge < 5.0:
				cast.set_pixel(px, py, Color(1, 1, 1, 0.23 * clampf((5.0 - cast_edge) / 5.0, 0, 1)))
			var chips := float(posmod(x * 19 + y * 23 + x * y, 11)) / 11.0
			if edge_distance < 11.0:
				wear.set_pixel(px, py, Color(1, 1, 1, (0.045 + chips * 0.045) * clampf((11.0 - edge_distance) / 8.0, 0, 1)))
			# Worn ground continues out from the front stairs, with broken edges.
			if absf(x - width * 0.5) < 15.0 - chips * 4.0 and y > floor_y - 4 and y < floor_y + 23 - chips * 6:
				wear.set_pixel(px, py, Color(1, 1, 1, 0.11 + chips * 0.10))
	var row := {"contact": ImageTexture.create_from_image(contact),
		"cast": ImageTexture.create_from_image(cast), "wear": ImageTexture.create_from_image(wear),
		"offset": Vector2(-width * 0.5 - pad, top), "visible_floor": floor_y,
		"visible_width": right - left + 1, "image_height": height}
	var projection := silhouette(art, width, height)
	if not projection.is_empty():
		row["cast"] = projection.cast
		row["cast_offset"] = projection.offset
	_cache[key] = row
	return row

# A finite, flattened silhouette rather than an ellipse or infinite 2D light shadow.
# Alpha bounds determine the contact plane, so transparent export padding cannot
# leave the prop floating. The same upper-left light direction serves every prop.
static func silhouette(art: Texture2D, width: int, height: int) -> Dictionary:
	var source_key := art.resource_path if not art.resource_path.is_empty() else str(art.get_rid().get_id())
	var key := "silhouette:%s:%d:%d" % [source_key, width, height]
	if _cache.has(key): return _cache[key]
	var source := art.get_image()
	if source == null or source.is_empty(): return {}
	if source.is_compressed(): source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	source.resize(width, height, Image.INTERPOLATE_NEAREST)
	var bounds := source.get_used_rect()
	if not bounds.has_area(): return {}
	var floor_y := bounds.end.y - 1
	var pad := 6
	var extent := Vector2i(width + ceili(height * .38) + pad * 2, height + ceili(height * .24) + pad)
	var mask := Image.create(extent.x,extent.y,false,Image.FORMAT_RGBA8)
	var cast := Image.create(extent.x,extent.y,false,Image.FORMAT_RGBA8)
	var contact := Image.create(extent.x,extent.y,false,Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	cast.fill(Color.TRANSPARENT)
	contact.fill(Color.TRANSPARENT)
	for x in width:
		var foot := -1
		for y in height:
			var alpha := source.get_pixel(x,y).a
			if alpha < .5: continue
			foot = y
			var above := float(floor_y - y)
			var px := roundi(x + above * .38) + pad
			var py := roundi(floor_y + above * .24)
			# Preserve roof edges and pole gaps instead of filling a generic oval.
			mask.set_pixel(px,py,Color(1,1,1,.20 - .06 * above / maxf(1,height)))
		if foot < floor_y - height * .26: continue
		for dx in range(-2,3):
			for dy in range(-3,5):
				var distance := maxf(absf(dx)*1.4,absf(dy)*.9)
				var px := x + dx + pad
				var py := foot + dy
				if px < 0 or py < 0 or px >= extent.x or py >= extent.y: continue
				var alpha := .30 * clampf(1-distance/4.5,0,1)
				if alpha > contact.get_pixel(px,py).a: contact.set_pixel(px,py,Color(1,1,1,alpha))
	# A one-pixel penumbra softens stair steps without blurring pixel artwork.
	for x in range(1,extent.x-1):
		for y in range(maxi(1,floor_y-2),extent.y-1):
			var core := mask.get_pixel(x,y).a
			var edge := 0.0
			for offset in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
				edge = maxf(edge,mask.get_pixel(x+offset.x,y+offset.y).a*.45)
			cast.set_pixel(x,y,Color(1,1,1,maxf(core,edge)))
	var row := {"cast":ImageTexture.create_from_image(cast),"contact":ImageTexture.create_from_image(contact),
		"offset":Vector2(-width*.5-pad,0),"visible_floor":floor_y}
	_cache[key] = row
	return row

static func draw_prop(canvas: CanvasItem, row: Dictionary, art_at: Vector2, width: float, snow := false) -> void:
	if row.is_empty(): return
	var at := art_at + Vector2(width*.5,0) + Vector2(row.offset)
	var ink := Color("273337") if snow else Color("293126")
	canvas.draw_texture(row.cast,at,ink)
	canvas.draw_texture(row.contact,at,ink)

static func attach(parent: Node2D, row: Dictionary, art_top: float, snow: bool) -> void:
	if row.is_empty(): return
	var ground := Node2D.new()
	ground.name = "FoundationGround"
	ground.show_behind_parent = true
	ground.position = Vector2(0, art_top)
	parent.add_child(ground)
	ground.visible = parent.built()
	for kind in ["wear", "cast", "contact"]:
		var sprite := Sprite2D.new()
		sprite.name = kind.capitalize()
		sprite.centered = false
		sprite.texture = row[kind]
		sprite.position = row.get("cast_offset",row.offset) if kind == "cast" else row.offset
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.use_parent_material = false
		sprite.modulate = Color("626363") if snow and kind == "wear" else Color("6c5b3d") if kind == "wear" else Color("273337") if snow else Color("293126")
		ground.add_child(sprite)
