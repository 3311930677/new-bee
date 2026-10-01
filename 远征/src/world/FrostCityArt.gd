class_name FrostCityArt
extends RefCounted

# Source PNGs stay untouched; AtlasTexture margins register all four soles.
static var _frames: Dictionary = {}
static var _portraits: Dictionary = {}
static var _props: Dictionary = {}

static func prop(id: String) -> Texture2D:
	if _props.has(id): return _props[id]
	var row: Dictionary = TableCache._load("res://data/frost_city_art.json").get("props", {}).get(id, {})
	if row.is_empty(): return null
	var at := AtlasTexture.new()
	at.atlas = load(String(row.path)) as Texture2D
	var r: Array = row.region
	at.region = Rect2(r[0], r[1], r[2], r[3])
	at.filter_clip = true
	_props[id] = at
	return at

static func rows() -> Dictionary:
	return TableCache._load("res://data/frost_city_art.json").get("npcs", {})

static func idle(npc_id: String) -> SpriteFrames:
	if _frames.has(npc_id): return _frames[npc_id]
	var row: Dictionary = rows().get(npc_id, {})
	if row.is_empty(): return null
	var source := load(String(row.path)) as Texture2D
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 5.0)
	frames.set_animation_loop(&"idle", true)
	for frame in row.frames:
		var at := AtlasTexture.new()
		at.atlas = source
		var r: Array = frame.region
		var m: Array = frame.margin
		at.region = Rect2(r[0], r[1], r[2], r[3])
		at.margin = Rect2(m[0], m[1], m[2], m[3])
		at.filter_clip = true
		frames.add_frame(&"idle", at)
	frames.set_meta("foot_registered", true)
	frames.set_meta("world_height", float(row.world_height))
	frames.set_meta("canvas_height", float(row.canvas[1]))
	_frames[npc_id] = frames
	return frames

static func portrait(npc_id: String) -> Texture2D:
	if _portraits.has(npc_id): return _portraits[npc_id]
	var row: Dictionary = rows().get(npc_id, {})
	if row.is_empty(): return null
	var at := AtlasTexture.new()
	at.atlas = load(String(row.path)) as Texture2D
	var r: Array = row.portrait
	at.region = Rect2(r[0], r[1], r[2], r[3])
	at.filter_clip = true
	_portraits[npc_id] = at
	return at

static func cutout_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://src/world/pixel_cutout.gdshader")
	return result
