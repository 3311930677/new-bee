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


static func pets() -> Array:
	return _rows("pets")


static func growth() -> Dictionary:
	var v: Variant = _load("res://data/growth.json")
	return v if v is Dictionary else {}


static func nodes_config() -> Dictionary:
	var v: Variant = _load("res://data/nodes.json")
	return v if v is Dictionary else {}


static func maps_config() -> Dictionary:
	var v: Variant = _load("res://data/maps.json")
	return v if v is Dictionary else {}


static func arena_config() -> Dictionary:
	var v: Variant = _load("res://data/arena.json")
	return v if v is Dictionary else {}


static func city_config() -> Dictionary:
	var v: Variant = _load("res://data/city.json")
	return v if v is Dictionary else {}


static func codex_config() -> Dictionary:
	var v: Variant = _load("res://data/codex.json")
	return v if v is Dictionary else {}


static func lore_config() -> Dictionary:
	var v: Variant = _load("res://data/lore.json")
	return v if v is Dictionary else {}


static func quests_config() -> Dictionary:
	var v: Variant = _load("res://data/quests.json")
	return v if v is Dictionary else {}


static func drops_config() -> Dictionary:
	var v: Variant = _load("res://data/drops.json")
	return v if v is Dictionary else {}


static func talents_config() -> Dictionary:
	var v: Variant = _load("res://data/talents.json")
	return v if v is Dictionary else {}


static func equip_config() -> Dictionary:
	var v: Variant = _load("res://data/equip.json")
	return v if v is Dictionary else {}


static func skillbook_config() -> Dictionary:
	var v: Variant = _load("res://data/skillbook.json")
	return v if v is Dictionary else {}


static func mounts_config() -> Dictionary:
	var v: Variant = _load("res://data/mounts.json")
	return v if v is Dictionary else {}


static func titles_config() -> Dictionary:
	var v: Variant = _load("res://data/titles.json")
	return v if v is Dictionary else {}


static func theme_config(theme: String) -> Dictionary:
	var maps: Dictionary = maps_config()
	var themes: Dictionary = maps.get("themes", {})
	return themes.get(theme, {})


## 角色等级属性（roles.json base + growth.json 成长）
##
## 一律「base + per_level × (level-1)」：等级 1 就是 base，和表里的写法一一对应。
## 暴击以前写死 `0.05 + 0.001*level`，把 roles.json 里四职业的 base.crit 与
## growth.json 的 per_level.crit 全忽略了（问题 #29）——穿杨（ck）表里是 0.07 的暴击职业，
## 实战里却和破军一个暴击率。
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
		"crit": float(base.get("crit", 0.05)) + float(per.get("crit", 0.001)) * float(lv),
	}


## 当前经验公式类型（未知/缺省返回空串）。回归用例据此断言"没有退化成硬编码兜底"。
static func exp_formula_kind() -> String:
	var e: Variant = growth().get("exp", {})
	return String((e as Dictionary).get("type", "")) if e is Dictionary else ""


## 升到 lv+1 所需经验。
## 公式类型与全部参数都读 growth.json 的 exp.type / exp.*；表里那句 exp_formula_note 只是说明文字。
## 未知 type 一律 push_error 并退回既定曲线——绝不把表里的字符串丢给 Expression 执行。
static func exp_to_next(level: int) -> int:
	var e: Variant = growth().get("exp", {})
	if e is Dictionary:
		var d := e as Dictionary
		var kind := String(d.get("type", ""))
		if kind == "linear_plus_exp":
			return int(float(d.get("linear", 100)) * float(level)
				+ float(d.get("scale", 2)) * pow(float(d.get("base", 5)),
					float(d.get("rate", 0.1)) * float(level)))
		if kind != "":
			push_error("growth.json exp.type 未知：%s（拒绝执行任意公式，退回既定曲线）" % kind)
	return int(float(level) * 100.0 + 2.0 * pow(5.0, 0.1 * float(level)))
