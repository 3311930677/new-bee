# TableCache.gd —— 战斗内核专用静态读表缓存
# 不引用任何 autoload（-s headless 测试模式下 autoload 标识符不可编译），
# 正常游戏模式下与 Data autoload 并存（数据同源，均为 data/*.json）。
class_name TableCache

static var _cache: Dictionary = {}


static func _load(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("TableCache 表缺失：%s" % path)
		_cache[path] = []
		return []
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("TableCache 表解析失败：%s" % path)
		parsed = []
	_cache[path] = parsed
	return parsed


static func _rows(table: String) -> Array:
	var arr: Variant = _load("res://data/%s.json" % table)
	return arr if arr is Array else []


static func _row_by_id(table: String, id: String) -> Dictionary:
	for r in _rows(table):
		if r is Dictionary and String(r.get("id", "")) == id:
			return r
	return {}


static func get_role(id: String) -> Dictionary:
	return _row_by_id("roles", id)


static func get_skill(id: String) -> Dictionary:
	return _row_by_id("skills", id)


static func get_combo(id: String) -> Dictionary:
	return _row_by_id("combos", id)


static func get_monster(id: String) -> Dictionary:
	return _row_by_id("monsters", id)


static func get_pet(id: String) -> Dictionary:
	return _row_by_id("pets", id)


static func get_trait(id: String) -> Dictionary:
	return _row_by_id("traits", id)


static func skills() -> Array:
	return _rows("skills")


static func combos() -> Array:
	return _rows("combos")


static func monsters() -> Array:
	return _rows("monsters")


static func traits() -> Array:
	return _rows("traits")


static func growth() -> Dictionary:
	var v: Variant = _load("res://data/growth.json")
	return v if v is Dictionary else {}


static func nodes_config() -> Dictionary:
	var v: Variant = _load("res://data/nodes.json")
	return v if v is Dictionary else {}


static func maps_config() -> Dictionary:
	var v: Variant = _load("res://data/maps.json")
	return v if v is Dictionary else {}


static func theme_config(theme: String) -> Dictionary:
	var maps: Dictionary = maps_config()
	var themes: Dictionary = maps.get("themes", {})
	return themes.get(theme, {})


## 角色等级属性（roles.json base + growth.json 成长）
static func role_stats(role_id: String, level: int) -> Dictionary:
	var role := get_role(role_id)
	if role.is_empty():
		return {}
	var base: Dictionary = role.get("base", {})
	var g := growth()
	var per: Dictionary = g.get("per_level", {})
	var lv := maxi(1, level) - 1
	return {
		"max_hp": int(base.get("hp", 100)) + int(per.get("hp", 40)) * lv,
		"atk": int(base.get("atk", 20)) + int(per.get("atk", 4)) * lv,
		"def": int(base.get("def", 10)) + int(per.get("def", 2)) * lv,
		"spd": float(base.get("spd", 1.0)),
		"crit": 0.05 + 0.001 * float(level),
	}


## 升到 lv+1 所需经验
static func exp_to_next(level: int) -> int:
	return int(float(level) * 100.0 + 2.0 * pow(5.0, 0.1 * float(level)))
