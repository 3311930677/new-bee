extends Node2D

# Generated pixel materials on authored/random route masks, with independent gameplay clearance.
# The floor stays level; cache is bounded for long expedition runs.
const Layout := preload("res://src/explore/FlatGroundLayout.gd")
const MATERIAL_SHADER := preload("res://src/explore/FlatGroundMaterial.gdshader")
const PIXEL := 3
const PALETTES := {
	"forest": ["9fab48", "a7b451", "829743", "e5d68e", "d5c67d", "grass"],
	"snow": ["91aeba", "9bb7c3", "7e9fac", "e7eef0", "cddde2", "snow"],
	"volcano": ["554747", "60504b", "453d40", "a28e80", "8d796e", "stone"],
	"tomb": ["52585c", "5d6465", "424b4f", "b2b0a0", "9b9d93", "stone"],
	"desert": ["b28f5a", "be9c65", "9a7d50", "ead4a0", "d6bb86", "sand"],
	"glacier": ["6f9fae", "7dabb8", "5b8d9e", "d6e8e9", "bbd8dd", "snow"],
	"abyss": ["494657", "545065", "3c3d4b", "a6a4b5", "8f90a3", "stone"],
	"castle": ["76756a", "818175", "62665e", "cec5a7", "b7af96", "stone"]
}
static var _cache: Dictionary = {}
var texture: Texture2D
var extent := Vector2.ZERO
var routes: Array = []

func setup(dimensions: Vector2, centerlines: Array, palette: Array, seed_value: int,
		material_id := "", tint := Color.WHITE) -> void:
	extent = dimensions
	routes = centerlines.duplicate(true)
	var atlas_path := "res://image/main_world/flat_materials_v2/%s_atlas.png" % material_id
	var has_atlas := not material_id.is_empty() and ResourceLoader.exists(atlas_path)
	var key := str(dimensions) + JSON.stringify(centerlines) + JSON.stringify(palette) + str(seed_value) + str(has_atlas)
	if not _cache.has(key):
		if _cache.size() >= 32: _cache.clear()
		_cache[key] = _render_mask(dimensions, centerlines) if has_atlas else _render(dimensions, centerlines, palette, seed_value)
	texture = _cache[key]
	if has_atlas:
		var finish := ShaderMaterial.new()
		finish.shader = MATERIAL_SHADER
		finish.set_shader_parameter("surface_atlas", load(atlas_path))
		finish.set_shader_parameter("surface_tint", tint)
		finish.set_shader_parameter("surface_scale", dimensions / Vector2(768, 998.4))
		material = finish
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -20
	queue_redraw()

func _draw() -> void:
	if texture != null: draw_texture_rect(texture, Rect2(Vector2.ZERO, extent), false)

static func palette_for(theme: String, cfg: Dictionary) -> Array:
	return cfg.get("flat_palette", PALETTES.get(theme, PALETTES.forest))

static func material_for(theme: String, cfg: Dictionary) -> String:
	var defaults := {"forest": "forest", "snow": "snow", "volcano": "volcano", "tomb": "stone",
		"desert": "desert", "glacier": "snow", "abyss": "abyss", "castle": "stone"}
	return String(cfg.get("flat_material", defaults.get(theme, "forest")))

static func _render_mask(dimensions: Vector2, centerlines: Array) -> Texture2D:
	# Union signed distances first: overlapping route samples must not fill the edge noise back in.
	# Keep a readable core, with a broad, broken fringe instead of a continuous painted outline.
	const STEP := 2.0
	var w := ceili(dimensions.x / STEP)
	var h := ceili(dimensions.y / STEP)
	var distances: Dictionary = {}
	for route: Dictionary in Layout.sample_routes(_surface_routes(dimensions, centerlines)):
		for p: Vector2 in route.points:
			var width_scale := clampf(float(route.width) / 150.0, .45, 1.4)
			var radius := (float(route.width) * .43 + (sin(p.y * .017 + p.x * .011) * 6.0 +
				sin(p.y * .037 - p.x * .019) * 3.0) * width_scale) / STEP
			var c := p / STEP
			var outer := radius + 16.0
			for y in range(maxi(0, floori(c.y - outer)), mini(h, ceili(c.y + outer) + 1)):
				var half_row := sqrt(maxf(0, outer * outer - (y - c.y) * (y - c.y)))
				for x in range(maxi(0, floori(c.x - half_row)), mini(w, ceili(c.x + half_row) + 1)):
					var cell := Vector2i(x, y)
					var distance := (radius - Vector2(x, y).distance_to(c)) * STEP
					if distance > float(distances.get(cell, -1000.0)): distances[cell] = distance
	var patches := FastNoiseLite.new()
	patches.seed = 53
	patches.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	patches.frequency = .045
	patches.fractal_octaves = 2
	var blades := FastNoiseLite.new()
	blades.seed = 157
	blades.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	blades.frequency = .19
	blades.fractal_octaves = 1
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
	for cell: Vector2i in distances:
		var x := cell.x * STEP
		var y := cell.y * STEP
		var displacement := patches.get_noise_2d(x, y) * 23.0 + blades.get_noise_2d(x, y * .55) * 10.0
		var grain := (float(_hash(cell.x, cell.y, 53)) / 10000.0 - .5) * 5.0
		var distance := float(distances[cell])
		# Fine side paths retain a continuous walkable core; erosion belongs to the fringe.
		var edge_weight := 1.0 - smoothstep(8.0, 24.0, distance)
		var amount := smoothstep(-12.0, 12.0, distance + displacement * edge_weight + grain)
		# A handful of intermediate pixel colors retain crisp detail without a blurry halo.
		amount = snappedf(amount, .2)
		image.set_pixelv(cell, Color(amount, amount, amount, 1))
	return ImageTexture.create_from_image(image)

static func _surface_routes(dimensions: Vector2, centerlines: Array) -> Array:
	var result: Array = centerlines.duplicate(true)
	for route: Dictionary in result:
		var points: Array = route.get("points", [])
		if points.size() < 2: continue
		# An arrival near the map edge represents a continuing road, not a round brush cap.
		for endpoint in [0, -1]:
			var p := Layout.point(points[endpoint])
			var neighbor := Layout.point(points[1 if endpoint == 0 else -2])
			var direction := (p - neighbor).normalized()
			var edge_distances := [p.x, dimensions.x - p.x, p.y, dimensions.y - p.y]
			var normals := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
			var nearest := 0
			for i in range(1, 4):
				if edge_distances[i] < edge_distances[nearest]: nearest = i
			var outward: Vector2 = normals[nearest]
			var alignment := direction.dot(outward)
			if edge_distances[nearest] > 144.0 or alignment < .6: continue
			var extension := p + direction * ((float(edge_distances[nearest]) + float(route.width)) / alignment)
			if endpoint == 0: points.push_front([extension.x, extension.y])
			else: points.append([extension.x, extension.y])
	return result

static func _hash(x: int, y: int, salt: int) -> int:
	return absi((x * 374761 + y * 668265 + salt * 127) ^ ((x + salt) * (y + 31) * 1013)) % 10000

static func _render(dimensions: Vector2, centerlines: Array, palette: Array, seed_value: int) -> Texture2D:
	var w := ceili(dimensions.x / PIXEL)
	var h := ceili(dimensions.y / PIXEL)
	var mask: Dictionary = {}
	for route: Dictionary in Layout.sample_routes(centerlines):
		for p: Vector2 in route.points:
			# Slow edge changes create organic widening; centerline and minimum clearance stay stable.
			var radius := (float(route.width) * 0.5 + sin(p.y * .027 + p.x * .018) * 7.0 +
				sin(p.y * .061 - p.x * .025) * 3.0) / PIXEL
			var c := p / PIXEL
			for y in range(maxi(0, floori(c.y - radius)), mini(h, ceili(c.y + radius) + 1)):
				var dy := y - c.y
				var half_row := sqrt(maxf(0, radius * radius - dy * dy))
				for x in range(maxi(0, floori(c.x - half_row)), mini(w, ceili(c.x + half_row) + 1)):
					mask[Vector2i(x, y)] = true
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ground := Color(String(palette[0]))
	var ground_light := Color(String(palette[1]))
	var marks := Color(String(palette[2]))
	var road := Color(String(palette[3]))
	var road_marks := Color(String(palette[4]))
	var material_kind := String(palette[5])
	var salt := absi(seed_value) % 7919
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var on_road := mask.has(cell)
			var coarse := _hash(x / 14, y / 12, salt)
			var detail := _hash(x, y, salt)
			var patch := sin(x * .09 + sin(y * .07) * 2) + sin(y * .11 - x * .04)
			var col := road if on_road else (ground_light if patch > 1.05 else ground)
			if on_road:
				var edge := not mask.has(cell + Vector2i(3, 0)) or not mask.has(cell - Vector2i(3, 0)) or \
					not mask.has(cell + Vector2i(0, 3)) or not mask.has(cell - Vector2i(0, 3))
				if edge and detail < 3000:
					col = ground_light if detail < 1500 else marks.lerp(road, .45)
				elif coarse < 1400 and detail < 1800: col = road_marks
			else:
				# Clustered grass blades / salt grains / stone chips rather than full-screen dot noise.
				if coarse < 1650 and detail < 2000: col = marks if detail < 1400 else ground_light.lightened(.08)
				if material_kind == "grass" and coarse < 1650 and _hash(x, y / 3, salt) < 900: col = marks
				if material_kind == "snow" and coarse < 1500 and detail < 1100: col = ground_light.lightened(.12)
				if material_kind == "stone" and coarse < 1600 and y % 9 == 0 and detail < 4500: col = marks
			image.set_pixel(x, y, col)
	return ImageTexture.create_from_image(image)
