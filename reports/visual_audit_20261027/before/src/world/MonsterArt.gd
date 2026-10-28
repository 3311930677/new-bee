class_name MonsterArt
extends RefCounted

static var _textures: Dictionary = {}

static func rows() -> Dictionary:
	var config: Variant = TableCache._load("res://data/monster_art.json")
	if not config is Dictionary:
		return {}
	var monsters: Variant = config.get("monsters", {})
	return monsters if monsters is Dictionary else {}

static func has(id: String) -> bool:
	return rows().has(id)

static func path(id: String) -> String:
	return String(rows().get(id, {}).get("path", ""))

static func texture(id: String) -> Texture2D:
	if _textures.has(id): return _textures[id]
	var row: Dictionary = rows().get(id, {})
	if row.is_empty(): return null
	var tex := AtlasTexture.new()
	tex.atlas = load(String(row.path)) as Texture2D
	var r: Array = row.region
	tex.region = Rect2(r[0], r[1], r[2], r[3])
	tex.filter_clip = true
	_textures[id] = tex
	return tex

static func display_scale(id: String, height: float, battle := false) -> float:
	var tex := texture(id)
	if tex == null: return 1.0
	var row: Dictionary = rows()[id]
	var width_cap := float(row.get("battle_max_width" if battle else "map_max_width", 128.0))
	return minf(height / tex.get_height(), width_cap / tex.get_width())
