## Rider and mount are authored together in every cel; one stable world foot point.
extends RefCounted
const CELL := 192
const FOOT := Vector2(96,176)
const DIRECTIONS := ["walk_down","walk_left","walk_right","walk_up"]
const ACTIONS := {"idle":[0,4,4.0],"walk":[4,8,7.0],"run":[12,12,11.5]}
static var _cache: Dictionary = {}
static var _manifest: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/mount_animation_20261024.json"))
	return _manifest

static func frames_for(role_id: String,mount_id := "horse") -> SpriteFrames:
	var key := mount_id+"_"+role_id
	if _cache.has(key):return _cache[key]
	var paths: Dictionary = manifest().get(mount_id,{}).get(role_id,{})
	if paths.size()!=4:
		push_error("骑乘连续帧缺失："+key)
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for direction in ["down","left","right","up"]:
		var sheet: Texture2D = load(String(paths[direction]))
		if sheet==null or sheet.get_width()!=CELL*4 or sheet.get_height()!=CELL*6:
			push_error("骑乘图集导入无效："+String(paths[direction]))
			return null
		for action in ACTIONS:
			var animation := StringName(action+"_"+direction)
			var spec: Array = ACTIONS[action]
			frames.add_animation(animation)
			frames.set_animation_loop(animation,true)
			frames.set_animation_speed(animation,float(spec[2]))
			for index in range(int(spec[0]),int(spec[0])+int(spec[1])):
				var cel := AtlasTexture.new()
				cel.atlas = sheet
				cel.region = Rect2((index%4)*CELL,(index/4)*CELL,CELL,CELL)
				cel.filter_clip = true
				frames.add_frame(animation,cel)
	_cache[key] = frames
	return frames

static func mount_offset(_mount_id: String,_direction: String, display_scale := 1.0) -> Vector2:
	return (Vector2(CELL*.5,CELL*.5)-FOOT)*display_scale+Vector2(0,22)

static func contact_frames(animation: String) -> Array:
	return [0,1,6,7] if animation.begins_with("run_") else [0,2,4,6] if animation.begins_with("walk_") else []
