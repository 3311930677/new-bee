extends RefCounted
## Texture-only completion. Quest state, interactions and collision stay in their owners.
const ROOT := "res://assets/completion_20261024/"
const HOME_KEYS := ["coin", "expedition", "soul", "honor", "bag", "food"]
const SALT_PROPS := {
	"a4_secret_oralbook_feedback_0": "road_ledger",
	"a2_salt_mark_a": "salt_trace", "a2_salt_mark_b": "salt_trace",
	"a2_trade_weight_step_1": "cargo_tag", "a2_trade_weight_step_2": "cargo_tag",
	"a2_secret_tide_clock_feedback_0": "tide_board",
	"a2_trade_weight_feedback_0": "notice",
	"herb_ship_tide_aid": "salt_trace",
	"a2_secret_tide_clock_step_1": "salt_trace",
	"a2_secret_tide_clock_step_2": "salt_trace",
	"a2_secret_tide_clock_step_3": "salt_trace",
	"act2_tide_record": "itm_mine_record",
	"act2_tide_rescue_cargo": "tide_cargo",
	"act2_tide_repair_bridge": "bridge_planks",
	"a1_secret_rubbing_step_1": "rubbing_page",
	"a1_secret_rubbing_step_2": "rubbing_page",
	"a1_secret_rubbing_step_3": "rubbing_page",
	"a1_secret_rubbing_step_4": "rubbing_page",
	"a1_secret_rubbing_feedback_0": "road_ledger",
	"a3_secret_airshaft_feedback_0": "road_ledger",
	"act3_mine_record": "itm_mine_record",
}
const TRACK_PROPS := {
	"a1_tracks_a": "beast_tracks", "a1_tracks_b": "beast_tracks",
	"a1_rel_watch_step_1": "beast_tracks", "a1_rel_watch_step_2": "beast_tracks",
	"wc_sign_1": "ground_scuff", "wc_sign_2": "ground_scuff",
	"wc_bridge_1": "ground_fissure",
	"wc_turtle_1": "turtle_tracks", "wc_turtle_2": "turtle_tracks",
	"wc_rope_1": "ground_scuff",
	"wc_snow_1": "ground_fissure", "wc_snow_2": "beast_tracks", "wc_snow_3": "boot_tracks",
}
static var _manifest: Dictionary = {}
static var _cache: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_completion_20261024.json"))
	return _manifest

static func texture(key: String) -> Texture2D:
	if _cache.has(key): return _cache[key] as Texture2D
	var row: Dictionary = manifest().get(key, {})
	if row.is_empty(): return null
	var tex := load(String(row.file)) as Texture2D
	if row.has("rect") and tex != null:
		var part := AtlasTexture.new()
		part.atlas = tex
		var r: Array = row.rect
		part.region = Rect2(r[0], r[1], r[2], r[3])
		part.filter_clip = true
		tex = part
	if tex != null: tex.set_meta("pixel_art", true)
	_cache[key] = tex
	return tex

static func home_path(key: String) -> String:
	return ROOT + "ready/home/home_%s.png" % key if key in HOME_KEYS else ""

static func centered(c: CanvasItem, key: String, at: Vector2, width: float, tint := Color.WHITE) -> void:
	var tex := texture(key)
	if tex == null: return
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var size := Vector2(width, width * tex.get_height() / float(tex.get_width()))
	c.draw_texture_rect(tex, Rect2((at - size * .5).round(), size.round()), false, tint)

static func prop(c: CanvasItem, key: String, foot: Vector2, height: float, tint := Color.WHITE) -> void:
	var tex := texture(key)
	if tex == null: return
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var size := Vector2(height * tex.get_width() / float(tex.get_height()), height)
	c.draw_texture_rect(tex, Rect2((foot - Vector2(size.x * .5, size.y)).round(), size.round()), false, tint)

static func channel(c: CanvasItem, points: Array, active: bool) -> void:
	var tex := texture("rune_channel")
	if tex == null: return
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tint := Color("c9ece5") if active else Color("737a80")
	# Repeat a short material module, clipping the final one. No stretched long lines.
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var distance := a.distance_to(b)
		var height := 12.0
		var module := 36.0
		c.draw_set_transform(a, (b-a).angle())
		var x := 0.0
		while x < distance:
			var length := minf(module, distance-x)
			c.draw_texture_rect_region(tex, Rect2(x, -height*.5, length, height),
				Rect2(0, 0, tex.get_width()*length/module, tex.get_height()), tint)
			x += module
		c.draw_set_transform(Vector2.ZERO)

static func salt_key(eid: String) -> String:
	return String(SALT_PROPS.get(eid, "salt_trace"))

static func track_key(eid: String) -> String:
	return String(TRACK_PROPS.get(eid, "beast_tracks"))

static func quest_prop(c: CanvasItem, eid: String, art: String) -> void:
	if art == "tracks":
		var key := track_key(eid)
		centered(c, key, Vector2(0,-4), 54, Color("b5cccf") if eid.begins_with("wc_snow") else Color.WHITE)
		return
	var key := salt_key(eid)
	if key == "salt_trace":
		var water_mark := eid.contains("tide") or eid == "herb_ship_tide_aid"
		centered(c, key, Vector2(0,-3), 64, Color("81a4a7") if water_mark else Color.WHITE)
	elif key in ["cargo_tag", "rubbing_page", "itm_mine_record", "bridge_planks"]:
		centered(c, key, Vector2(0,-18), 48 if key != "bridge_planks" else 72)
	else:
		prop(c, key, Vector2.ZERO, 64)
