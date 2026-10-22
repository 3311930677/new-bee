## 首骑四向图：一张 2×2 透明图，按 down/left/right/up 顺序分格。
## 仅负责地图外观；坐骑归属、骑乘状态和速度归 G 管，战斗仍显示人物本身。
extends RefCounted

const ROLE_SHEETS := {
	"zs": "res://image/mounts/first_horse_zs.png",
	"ck": "res://image/mounts/first_horse_ck.png",
	"fs": "res://image/mounts/first_horse_fs.png",
	"fz": "res://image/mounts/first_horse_fz.png",
}
const DIRECTIONS := ["walk_down", "walk_left", "walk_right", "walk_up"]
static var _cache: Dictionary = {}


static func frames_for(role_id: String, mount_id := "horse") -> SpriteFrames:
	if mount_id == "bear": return _bear_frames()
	if mount_id == "horse": return _horse_frames()
	if _cache.has(role_id):
		return _cache[role_id] as SpriteFrames
	var path := String(ROLE_SHEETS.get(role_id, ROLE_SHEETS["zs"]))
	var sheet: Texture2D = load(path)
	if sheet == null:
		push_error("首骑四向素材缺失：%s" % path)
		return null
	var cell := Vector2i(sheet.get_width() / 2, sheet.get_height() / 2)
	var frames := SpriteFrames.new()
	for i in DIRECTIONS.size():
		var anim := StringName(DIRECTIONS[i])
		frames.add_animation(anim)
		frames.set_animation_loop(anim, false)
		frames.set_animation_speed(anim, 1.0)
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2i((i % 2) * cell.x, (i / 2) * cell.y, cell.x, cell.y)
		frames.add_frame(anim, atlas)
	_cache[role_id] = frames
	return frames

static func _bear_frames() -> SpriteFrames:
	if _cache.has("bear"): return _cache.bear
	var sheet: Texture2D = load("res://image/mounts/bear_walk_v2.png")
	var frames := SpriteFrames.new()
	for i in 4:
		frames.add_animation(DIRECTIONS[i])
		frames.set_animation_speed(DIRECTIONS[i], 8.0)
		frames.set_animation_loop(DIRECTIONS[i], true)
		for col in 3:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(col * 362, i * 362, 362, 362)
			frames.add_frame(DIRECTIONS[i], atlas)
	_cache.bear = frames
	return frames

static func bear_offset(_direction: String) -> Vector2:
	return Vector2(0, -29.0)

static func _horse_frames() -> SpriteFrames:
	if _cache.has("horse_walk"): return _cache.horse_walk
	var sheet: Texture2D = load("res://image/mounts/horse_walk_v2.png")
	var frames := SpriteFrames.new()
	for direction in 4:
		frames.add_animation(DIRECTIONS[direction])
		frames.set_animation_speed(DIRECTIONS[direction], 8.0)
		frames.set_animation_loop(DIRECTIONS[direction], true)
		for phase in 3:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(phase * 362, direction * 362, 362, 362)
			frames.add_frame(DIRECTIONS[direction], atlas)
	_cache.horse_walk = frames
	return frames

static func rider_frames_for(role_id: String, base_frames: SpriteFrames) -> SpriteFrames:
	var key := "rider_" + role_id
	if _cache.has(key):
		return _cache[key] as SpriteFrames
	if base_frames == null:
		return null
	var frames := SpriteFrames.new()
	var crop_heights := {"down": 68.0, "left": 86.0, "right": 86.0, "up": 82.0}
	for dir_suffix in ["down", "left", "right", "up"]:
		var walk_anim := StringName("walk_" + dir_suffix)
		var idle_anim := StringName("idle_" + dir_suffix)
		var src_anim := idle_anim if base_frames.has_animation(idle_anim) else walk_anim
		var src_tex: Texture2D = base_frames.get_frame_texture(src_anim, 0) if base_frames.has_animation(src_anim) and base_frames.get_frame_count(src_anim) > 0 else null
		var seated_tex: Texture2D = src_tex
		if src_tex is AtlasTexture:
			var orig := src_tex as AtlasTexture
			var at := AtlasTexture.new()
			at.atlas = orig.atlas
			var ch := float(crop_heights.get(dir_suffix, 84.0))
			var orig_h := orig.region.size.y if orig.region.size.y > 0.0 else 128.0
			at.region = Rect2(orig.region.position.x, orig.region.position.y, orig.region.size.x, minf(ch, orig_h))
			at.margin = Rect2(0.0, 0.0, 0.0, maxf(0.0, orig_h - ch))
			at.filter_clip = true
			seated_tex = at
		for anim_name in [walk_anim, idle_anim]:
			if not frames.has_animation(anim_name):
				frames.add_animation(anim_name)
			frames.set_animation_loop(anim_name, false)
			frames.set_animation_speed(anim_name, 1.0)
			if seated_tex != null:
				frames.add_frame(anim_name, seated_tex)
	_cache[key] = frames
	return frames

static func mount_offset(mount_id: String, direction: String) -> Vector2:
	if mount_id == "bear": return bear_offset(direction)
	return Vector2(0, -31.0)

static func rider_offset(mount_id: String, direction: String) -> float:
	var dir_key := direction.replace("idle_", "walk_")
	if mount_id == "bear": return -45.0 if dir_key in ["walk_down", "walk_up"] else -39.0
	return float({"walk_down": -55.0, "walk_left": -43.0, "walk_right": -43.0, "walk_up": -48.0}.get(dir_key, -46.0))

static func rider_pos(mount_id: String, direction: String, stride_bob := 0.0) -> Vector2:
	var dir_key := direction.replace("idle_", "walk_")
	var rx := 3.0 if dir_key == "walk_left" else (-3.0 if dir_key == "walk_right" else 0.0)
	return Vector2(rx, rider_offset(mount_id, dir_key) + stride_bob)
