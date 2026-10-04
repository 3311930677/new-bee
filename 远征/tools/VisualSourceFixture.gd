extends Node
## Deterministic layout fixture, not evidence of a natural campaign playthrough.
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://tools/_logs/visual_fixture")
	G.SAVE_PATH = "res://tools/_logs/visual_fixture/source.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "东方舟影"
	G.account = "界面预览"
	G.avatar_id = "fox"
	G.prog.level = 42
	G.prog.exp = 180
	var completed: Array = []
	for i in range(1,29): completed.append("s%02d" % i)
	G.prog.story = {"step":"s29","done":completed,"goals":{}}
	G.prog.flags = {"act1_stele_repaired":true,"act1_lost_beast_down":true}
	G.prog.main_world = {"map_id":"frost_post"}
	G.prog.tips_seen = {"deploy":true,"pet_raise":true}
	G.wallet = {"gold":12800,"expedition":240,"soul":36,"honor":900}
	G.ensure_starter_pets()
	G.ensure_starter_equip(true)
	G.mentor_state().unlocked.append(G.mentor_second_skill())
	G.items["enhance_stone"] = 12
	G.items["pet_food"] = 6
	if not G.save_game() or not G.reload_save() or G.save_locked:
		push_error("VISUAL_SOURCE_FIXTURE_FAILED")
		get_tree().quit(1)
		return
	print("VISUAL_SOURCE_FIXTURE_OK staged_layout role=%s chapter=%d" % [G.selected_role,G.prog.story.done.size()])
	get_tree().quit()
