# verify_data.gd —— 数据表加载校验（headless：godot --headless --path . -s tools/verify_data.gd）
# 注：-s 脚本模式下 autoload 标识符不可用，故手动实例化 DataManager。
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dm: Node = (load("res://src/autoload/DataManager.gd") as GDScript).new()
	root.add_child(dm)

	var roles: Variant = dm.table("roles")
	assert(roles is Array and roles.size() == 4, "roles 应为 4 人")
	assert(dm.get_role("zs").get("name") == "破军")
	assert(dm.get_skill("zs_lieshan").get("k") == 1.5)
	assert(dm.get_monster("mon_boss_forest").get("tier") == "boss")
	assert(dm.get_pet("pet_frostwolf").get("rarity") == "blue")
	assert(dm.get_trait("de_ranxue").get("type") == "double")
	assert((dm.table("traits") as Array).size() == 44, "traits 应为 44 条")
	assert((dm.table("skills") as Array).size() == 20, "skills 应为 20 条")
	assert((dm.table("monsters") as Array).size() == 35, "monsters 应为 35 条")
	assert((dm.table("pets") as Array).size() == 8, "pets 应为 8 只")
	assert((dm.table("combos") as Array).size() == 4, "combos 应为 4 条")
	assert(dm.theme_config("forest").get("boss") == "mon_boss_forest")
	assert(dm.nodes_config().get("layers") == 3)
	var themes: Dictionary = dm.maps_config().get("themes", {})
	assert(themes.size() == 8, "maps 主题应为 8 个")

	# 每个主题的怪物与 BOSS 均可查到
	for theme in dm.maps_config().get("theme_order", []):
		var tc: Dictionary = dm.theme_config(String(theme))
		for mon_id in tc.get("monsters", []):
			assert(not dm.get_monster(String(mon_id)).is_empty(), "怪物缺失：%s" % mon_id)
		assert(not dm.get_monster(String(tc.get("boss", ""))).is_empty())
		for tile in tc.get("tiles", []):
			assert(FileAccess.file_exists("res://image/map/%s.png" % tile),
				"贴图缺失：%s" % tile)
		for deco in tc.get("decos", []):
			assert(FileAccess.file_exists("res://image/map/%s.png" % deco),
				"散件缺失：%s" % deco)

	# 技能表字段完整性
	for sk in dm.table("skills"):
		assert(String(sk.get("id", "")).length() > 0)
		assert(sk.has("k") and sk.has("cd") and sk.has("cost") and sk.has("target"))
	# 词条六系口径：12 数值 + 16 机制 + 12 流派 + 4 双刃
	var cnt := {"num": 0, "mech": 0, "link": 0, "double": 0}
	for tr in dm.table("traits"):
		cnt[String(tr.get("type"))] += 1
	assert(cnt["num"] == 12 and cnt["mech"] == 16 and cnt["link"] == 12 and cnt["double"] == 4,
		"词条分系计数不符：%s" % str(cnt))

	print("DATA_OK roles=4 skills=20 monsters=35 pets=8 traits=44(12+16+12+4) combos=4 themes=8 tiles_ok")
	quit(0)
