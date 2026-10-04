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
	if _cache.has("bear"):return _cache.bear
	var sheet:Texture2D=load("res://image/mounts/bear_walk_v2.png")
	var frames:=SpriteFrames.new()
	# Native atlas regions follow the painted row gutters, preserving every paw.
	var rows: Array=[Vector2i(0,400),Vector2i(400,320),Vector2i(720,310),Vector2i(1030,418)]
	for i in 4:
		frames.add_animation(DIRECTIONS[i])
		frames.set_animation_speed(DIRECTIONS[i],6)
		frames.set_animation_loop(DIRECTIONS[i],true)
		for col in 3:
			var atlas:=AtlasTexture.new()
			atlas.atlas=sheet
			atlas.region=Rect2(col*362,rows[i].x,362,rows[i].y)
			frames.add_frame(DIRECTIONS[i],atlas)
	_cache.bear=frames
	return frames

static func bear_offset(direction:String)->Vector2:
	return Vector2(0,{"walk_down":-53.0,"walk_left":-35.0,"walk_right":-33.0,"walk_up":-35.0}.get(direction,-53.0))

static func _horse_frames() -> SpriteFrames:
	if _cache.has("horse_walk"): return _cache.horse_walk
	var sheet: Texture2D = load("res://image/mounts/horse_walk_v2.png")
	var frames := SpriteFrames.new()
	# Use natural gutters; equal rows would cut the rear-facing ears.
	var rows := [Vector2i(0,385),Vector2i(385,335),Vector2i(720,315),Vector2i(1035,413)]
	var columns := [[50,380,708],[40,400,740],[25,380,740],[50,380,708]]
	for direction in 4:
		frames.add_animation(DIRECTIONS[direction])
		frames.set_animation_speed(DIRECTIONS[direction],6)
		frames.set_animation_loop(DIRECTIONS[direction],true)
		for phase in 3:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(int(columns[direction][phase]),rows[direction].x,330,rows[direction].y)
			frames.add_frame(DIRECTIONS[direction],atlas)
	_cache.horse_walk = frames
	return frames

static func mount_offset(mount_id: String,direction: String) -> Vector2:
	if mount_id=="bear":return bear_offset(direction)
	return Vector2(0,{"walk_down":-52.0,"walk_left":-41.0,"walk_right":-43.0,"walk_up":-40.0}.get(direction,-52.0))

static func rider_offset(mount_id: String,direction: String) -> float:
	if mount_id=="bear":return -86.0 if direction in ["walk_down","walk_up"] else -70.0
	return {"walk_down":-72.0,"walk_left":-74.0,"walk_right":-74.0,"walk_up":-86.0}.get(direction,-72.0)
