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


static func frames_for(role_id: String) -> SpriteFrames:
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
