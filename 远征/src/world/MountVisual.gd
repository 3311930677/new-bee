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
const RIDER_ATLAS := "res://image/mounts/riders_seated_v3.png"
static var _cache: Dictionary = {}
static var _head_cache: Dictionary = {}

static func foreground_for(texture: Texture2D) -> Texture2D:
	var source := texture as AtlasTexture
	if source == null: return null
	var key := str(source.region)
	if _head_cache.has(key): return _head_cache[key]
	# The horse's muzzle is in front of the rider's knees when facing south.
	# Keep the original full-cell canvas so it registers exactly with the gait.
	var crop := Rect2(130,128,110,112)
	var part := AtlasTexture.new()
	part.atlas = source.atlas
	part.region = Rect2(source.region.position+crop.position,crop.size)
	part.margin = Rect2(crop.position,source.region.size-crop.size)
	part.filter_clip = true
	_head_cache[key] = part
	return part


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
		frames.set_animation_speed(DIRECTIONS[i], 6.0)
		frames.set_animation_loop(DIRECTIONS[i], true)
		for col in [0,1,2,1]:
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
		frames.set_animation_speed(DIRECTIONS[direction], 6.0)
		frames.set_animation_loop(DIRECTIONS[direction], true)
		for phase in [0,1,2,1]:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(phase * 362, direction * 362, 362, 362)
			frames.add_frame(DIRECTIONS[direction], atlas)
	_cache.horse_walk = frames
	return frames

static func rider_frames_for(role_id: String, _base_frames: SpriteFrames) -> SpriteFrames:
	var key := "rider_seated_" + role_id
	if _cache.has(key): return _cache[key]
	var sheet := load(RIDER_ATLAS) as Texture2D
	var cell := sheet.get_size()/4.0
	var column: int = {"zs":0,"ck":1,"fs":2,"fz":3}.get(role_id,0)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in 4:
		var part := AtlasTexture.new()
		part.atlas = sheet
		part.region = Rect2(Vector2(column,row)*cell,cell)
		part.filter_clip = true
		for name in [DIRECTIONS[row], DIRECTIONS[row].replace("walk_","idle_")]:
			frames.add_animation(name)
			frames.set_animation_loop(name,false)
			frames.add_frame(name,part)
	_cache[key] = frames
	return frames

static func rider_scale() -> float:
	# The atlas has an explicit saddle anchor at (0.5, 0.60) in every cell.
	var sheet := load(RIDER_ATLAS) as Texture2D
	return 74.0/(sheet.get_height()/4.0)

static func mount_offset(mount_id: String, direction: String) -> Vector2:
	if mount_id == "bear": return bear_offset(direction)
	return Vector2(0, -31.0)

static func rider_offset(mount_id: String, direction: String) -> float:
	var dir_key := direction.replace("idle_", "walk_")
	if mount_id == "bear": return -49.0 if dir_key == "walk_up" else -46.0
	return float({"walk_down": -51.0, "walk_left": -48.0, "walk_right": -48.0, "walk_up": -58.0}.get(dir_key, -46.0))

static func rider_pos(mount_id: String, direction: String, stride_bob := 0.0) -> Vector2:
	var dir_key := direction.replace("idle_", "walk_")
	var rx := 0.0
	return Vector2(rx, rider_offset(mount_id, dir_key) + stride_bob)
