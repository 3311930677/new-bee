extends RefCounted
## World-only sampling; UI and character atlases keep their own rendering.
static func nearest() -> bool:
	return OS.get_environment("YUANZHENG_BACKGROUND_NEAREST")=="1"

static func sampling() -> int:
	return CanvasItem.TEXTURE_FILTER_NEAREST if nearest() else CanvasItem.TEXTURE_FILTER_LINEAR

static func original_art() -> bool:
	return OS.get_environment("YUANZHENG_LEGACY_BACKGROUND")=="" or OS.get_environment("YUANZHENG_LEGACY_BACKGROUND")=="0"

const NPC_ENLARGEMENT := 0.96
const SCENERY_ENLARGEMENT := 1.12
const BUILDING_ENLARGEMENT := 1.24

static func background_path(path: String) -> String:
	if original_art() and path.begins_with("res://assets/world/maps_rebuild_20261015/"):
		var raw:="res://assets/world/original_backgrounds_20261026/"+path.get_file().trim_suffix("_floor.png")+".png"
		if ResourceLoader.exists(raw):return raw
	return path

static func mount_scale(player_scale: float) -> float:
	return player_scale/.70*.86
