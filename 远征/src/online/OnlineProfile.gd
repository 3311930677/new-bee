extends RefCounted
## 在线角色只带入身份建议。本地数值、资源和调试状态没有上传入口。

const ROLE_IDS := ["zs", "ck", "fs", "fz"]
const RULESET_VERSION := "online-0.1"

static func import_preview(local: Dictionary) -> Dictionary:
	var role := String(local.get("selected_role", "zs"))
	if not ROLE_IDS.has(role):
		role = "zs"
	return {
		"identity": {
			"nickname": String(local.get("player_name", "")).strip_edges().left(12),
			"role_id": role,
			"appearance_id": "default",
		},
		"not_imported": ["等级与经验", "金币与货币", "装备与强化", "宠物战力", "背包物品", "任务奖励"],
		"notice": "在线角色从新的旅程开始，原单机进度仍可继续游玩。",
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
