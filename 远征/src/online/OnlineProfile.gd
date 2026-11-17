extends RefCounted
## 在线角色只带入身份建议。本地数值、资源和调试状态没有上传入口。

const ROLE_IDS := ["zs", "ck", "fs", "fz"]
const RULESET_VERSION := "online-0.1"
const GENDER_IDS := ["unspecified", "male", "female"]
const GENDER_NAMES := ["未指定", "男", "女"]
const AVATAR_IDS := ["role_default", "role_zs", "role_ck", "role_fs", "role_fz"]
const AVATAR_NAMES := ["随职业", "破军小像", "穿杨小像", "霜语小像", "晨星小像"]


static func safe_role(value: String) -> String:
	return value if ROLE_IDS.has(value) else "zs"


static func gender_name(value: String) -> String:
	return GENDER_NAMES[maxi(0, GENDER_IDS.find(value))]


static func avatar_role(identity: Dictionary) -> String:
	var avatar := String(identity.get("avatar_id", "role_default"))
	return avatar.trim_prefix("role_") if AVATAR_IDS.has(avatar) and avatar != "role_default" else safe_role(String(identity.get("role_id", "zs")))


static func catalogue_matches(manifest: Dictionary) -> bool:
	return manifest.get("gender_ids", []) == GENDER_IDS and manifest.get("avatar_ids", []) == AVATAR_IDS


static func identity_supported(manifest: Dictionary) -> bool:
	var features: Variant = manifest.get("features", [])
	return features is Array and features.has("character_identity")

static func import_preview(local: Dictionary) -> Dictionary:
	var role := safe_role(String(local.get("selected_role", "zs")))
	var gender := String(local.get("gender_id", local.get("gender", "unspecified")))
	if gender in ["男", "女"]:
		gender = "male" if gender == "男" else "female"
	if not GENDER_IDS.has(gender):
		gender = "unspecified"
	var avatar := String(local.get("avatar_id", "role_default"))
	var custom := bool(local.get("avatar_use_custom", false))
	if custom or not AVATAR_IDS.has(avatar):
		avatar = "role_default"
	return {
		"identity": {
			"nickname": String(local.get("player_name", "")).strip_edges().left(12),
			"role_id": role,
			"appearance_id": "default",
			"gender_id": gender,
			"avatar_id": avatar,
		},
		"not_imported": ["等级与经验", "金币与货币", "装备与强化", "宠物战力", "背包物品", "任务奖励"],
		"notice": "在线角色从新的旅程开始，原单机进度仍可继续游玩。",
		"avatar_notice": "单机自选图片仅在本机；联机先使用职业头像。" if custom else "联机使用已开放的职业小像。",
	}

static func content_version() -> String:
	var directory := DirAccess.open("res://data")
	if directory == null:
		return ""
	var files: Array[String] = []
	for file in directory.get_files():
		if file.ends_with(".json"):
			files.append(file)
	files.sort()
	if files.is_empty():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	for file in files:
		var path := "res://data/%s" % file
		if not FileAccess.file_exists(path):
			return ""
		context.update(String(file).to_utf8_buffer())
		context.update(PackedByteArray([0]))
		context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()
