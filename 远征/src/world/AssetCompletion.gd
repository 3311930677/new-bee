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

static func channel(c: CanvasItem, points: Array, active: bool, voice_color := Color("c9ece5")) -> void:
	var K := preload("res://src/ui/KitV4.gd")
	var base_tex := K.commercial_tex("f07_base_h")
	var glow_tex := K.commercial_tex("f07_glow_h")
	if base_tex == null:
		base_tex = texture("rune_channel")
	if base_tex == null: return
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pulse := 0.82 + 0.18 * sin(float(Time.get_ticks_msec()) * 0.00314)
	var base_tint := Color("98a8ba") if active else Color("6c7888")
	var glow_tint := Color(voice_color.r, voice_color.g, voice_color.b, pulse if active else 0.72)
	var draw_w := 44.0
	var draw_h := 24.0
	var src_w := float(base_tex.get_width())
	var src_h := float(base_tex.get_height())
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var distance := a.distance_to(b)
		c.draw_set_transform(a, (b-a).angle())
		var x := 0.0
		while x < distance:
			var length := minf(draw_w, distance-x)
			var src_len := src_w * (length / draw_w)
			c.draw_texture_rect_region(base_tex, Rect2(x, -draw_h*.5, length, draw_h),
				Rect2(0, 0, src_len, src_h), base_tint)
			if glow_tex != null:
				var gw := float(glow_tex.get_width())
				var gh := float(glow_tex.get_height())
				c.draw_texture_rect_region(glow_tex, Rect2(x, -draw_h*.5, length, draw_h),
					Rect2(0, 0, gw * (length / draw_w), gh), glow_tint)
			x += draw_w
		c.draw_line(Vector2(2, 0), Vector2(maxf(2, distance - 2), 0), Color(voice_color.r, voice_color.g, voice_color.b, (0.78 * pulse) if active else 0.42), 3.0)
		c.draw_set_transform(Vector2.ZERO)

static func channel_junction(c: CanvasItem, at: Vector2, active: bool, voice_color := Color("c9ece5"), kind := "t") -> void:
	var K := preload("res://src/ui/KitV4.gd")
	var base_tex := K.commercial_tex("f07_base_" + kind)
	var glow_tex := K.commercial_tex("f07_glow_" + kind)
	if base_tex == null: return
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pulse := 0.82 + 0.18 * sin(float(Time.get_ticks_msec()) * 0.00314)
	var sz := Vector2(28, 28)
	c.draw_texture_rect(base_tex, Rect2((at - sz * 0.5).round(), sz), false, Color("98a8ba") if active else Color("6c7888"))
	if glow_tex != null:
		c.draw_texture_rect(glow_tex, Rect2((at - sz * 0.5).round(), sz), false, Color(voice_color.r, voice_color.g, voice_color.b, pulse if active else 0.75))
	c.draw_circle(at, 3.5, Color(voice_color.r, voice_color.g, voice_color.b, (0.85 * pulse) if active else 0.52))

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
