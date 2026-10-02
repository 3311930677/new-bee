extends Node

const CONFIG_PATH := "res://data/monster_art.json"

func _ready() -> void:
	var original: Variant = TableCache._load(CONFIG_PATH)
	assert(original is Dictionary, "Monster art registry must exist")
	for id in ["mon_zombie", "mon_wolf"]:
		assert(MonsterArt.has(id), "Available sprite must be registered: " + id)
		var tex := MonsterArt.texture(id)
		assert(tex is AtlasTexture and (tex as AtlasTexture).atlas != null,
			"Registered sprite must load: " + id)
		assert(tex.get_width() > 0 and tex.get_height() > 0)
		assert(MonsterArt.display_scale(id, 76.0) > 0)
	assert(not MonsterArt.has("unregistered_monster"))
	assert(MonsterArt.path("unregistered_monster").is_empty())
	assert(MonsterArt.texture("unregistered_monster") == null)
	# Reproduce the loader's missing/invalid JSON result and malformed registries.
	for invalid in [[], null, {"monsters": []}, {"monsters": null}, {}]:
		TableCache._cache[CONFIG_PATH] = invalid
		assert(MonsterArt.rows().is_empty(), "Invalid registry must allow legacy art fallback")
		assert(not MonsterArt.has("mon_zombie"))
		assert(MonsterArt.path("mon_zombie").is_empty())
	TableCache._cache[CONFIG_PATH] = original
	print("MONSTER_ART_OK")
	get_tree().quit()
