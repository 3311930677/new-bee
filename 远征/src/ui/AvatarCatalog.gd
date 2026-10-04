extends RefCounted
## 个人头像独立于职业，复用游戏内已有的像素伙伴素材。

const IDS := ["fox", "cat", "turtle", "snow"]
const NAMES := {"fox": "赤尾狐", "cat": "夜猫", "turtle": "石龟", "snow": "雪团"}
const PATHS := {
	"fox": "res://image/generated_362_xajh/ready/pet/d_pet_fire_fox.png",
	"cat": "res://image/generated_362_xajh/ready/pet/pet_eyescat.png",
	"turtle": "res://image/generated_362_xajh/ready/pet/d_pet_turtle_chancellor.png",
	"snow": "res://image/generated_362_xajh/ready/pet/d_pet_snow_mink.png",
}
const TINTS := {"fox": Color("f0e1cd"), "cat": Color("e3e0e9"),
	"turtle": Color("e0e5d3"), "snow": Color("e0e8e8")}
const LEGACY := {"zs": "fox", "ck": "cat", "fs": "snow", "fz": "turtle"}

static func resolve(id: String) -> String:
	return id if IDS.has(id) else String(LEGACY.get(id, "fox"))

static func texture(id: String) -> Texture2D:
	var path := String(PATHS[resolve(id)])
	var clean_path := path.get_base_dir()+"/refined/"+path.get_file()
	return load(clean_path if ResourceLoader.exists(clean_path) else path) as Texture2D
