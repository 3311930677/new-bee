extends "res://tools/CurrentVisualAudit.gd"
## 商业化评审补拍：主世界 NPC 对话、营帐确认、首领对峙/余韵、序章。存档隔离到本目录。

func _ready() -> void:
	OUT = "res://shots/commercial_review_20261028/extra/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_window().size = Vector2i(480, 800)
	fixture()
	G.prog.tips_seen = {"pet_raise": true, "deploy": true}
	await frames(10)

	await attach(make_map("lorin_wilds"))
	await pause(0.6)
	var city: Node = current.get("_city_content")
	if city != null:
		for id in ["npc_steward", "npc_warden"]:
			city.call("_open_dialog", G.city_npc(id), false)
			await pause(0.6)
			await shot("x01_dialog_" + id)
			if city.get("_panel") != null and is_instance_valid(city.get("_panel")):
				city.get("_panel").queue_free()
				city.set("_panel", null)
			await frames(4)
	current.call("_ask_exit")
	await pause(0.5)
	await shot("x02_map_exit_modal")
	await clean()

	for kind in ["intro", "outro"]:
		var beat := preload("res://src/ui/StoryBeat.gd").new()
		beat.setup("forest", kind)
		await attach(beat)
		await pause(3.0)
		await shot("x03_storybeat_" + kind)
		await clean()

	await attach(preload("res://src/ui/Prologue.tscn").instantiate())
	await pause(1.5)
	await shot("x04_prologue")
	await clean()

	print("COMMERCIAL_EXTRA_OK")
	get_tree().quit()
