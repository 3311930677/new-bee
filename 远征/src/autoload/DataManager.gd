# DataManager.gd —— 数据表统一加载与查询（开发规范 §3.4）
# 启动时加载 data/*.json 并校验；缺表/字段错 push_error 并降级空表。
extends Node

const TABLES := {
	"roles": "res://data/roles.json",
	"growth": "res://data/growth.json",
	"skills": "res://data/skills.json",
	"combos": "res://data/combos.json",
	"monsters": "res://data/monsters.json",
	"pets": "res://data/pets.json",
	"traits": "res://data/traits.json",
	"nodes": "res://data/nodes.json",
	"maps": "res://data/maps.json",
}

var _tables: Dictionary = {}       # 表名 -> Array 或 Dictionary（原文）
var _index: Dictionary = {}        # 表名 -> {id -> 行}（仅数组表）


func _ready() -> void:
	for table_name in TABLES:
		_load_table(table_name, String(TABLES[table_name]))


func _load_table(table_name: String, path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("数据表缺失：%s（%s）" % [table_name, path])
		_tables[table_name] = []
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("数据表解析失败：%s（JSON 格式错误）" % table_name)
		_tables[table_name] = []
		return
	_tables[table_name] = parsed
	if parsed is Array:
		var idx := {}
		for row in parsed:
			if row is Dictionary and row.has("id"):
				idx[String(row["id"])] = row
		_index[table_name] = idx


# ---------- 通用查询 ----------
func get_row(table_name: String, id: String) -> Dictionary:
	var idx: Dictionary = _index.get(table_name, {})
	return idx.get(id, {})


func table(table_name: String) -> Variant:
	return _tables.get(table_name, [])


# ---------- 专用便捷查询 ----------
func get_role(role_id: String) -> Dictionary:
	return get_row("roles", role_id)


func get_skill(skill_id: String) -> Dictionary:
	return get_row("skills", skill_id)


func get_monster(mon_id: String) -> Dictionary:
	return get_row("monsters", mon_id)


func get_pet(pet_id: String) -> Dictionary:
	return get_row("pets", pet_id)


func get_trait(trait_id: String) -> Dictionary:
	return get_row("traits", trait_id)


func growth() -> Dictionary:
	return _tables.get("growth", {})


func nodes_config() -> Dictionary:
	return _tables.get("nodes", {})


func maps_config() -> Dictionary:
	return _tables.get("maps", {})


func theme_config(theme: String) -> Dictionary:
	var cfg: Dictionary = maps_config()
	var themes: Dictionary = cfg.get("themes", {})
	return themes.get(theme, {})
