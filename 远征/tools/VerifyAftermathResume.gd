extends Node

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_aftermath_resume.json"
	var ok := G.reload_save()
	var state := QuestService.side_get(G.act1_state(), "a1_secret_rubbing")
	ok = ok and String(state.get("status", "")) == "active" and int(state.get("progress", 0)) == 1
	ok = ok and not G.side_entity_visible("a1_secret_rubbing_step_1", "a1_secret_rubbing")
	ok = ok and G.side_entity_visible("a1_secret_rubbing_step_2", "a1_secret_rubbing")
	if not ok: push_error("FAIL: 第二进程恢复原阶段与实体去重")
	print("AFTERMATH_RESUME_OK" if ok else "AFTERMATH_RESUME_FAIL")
	get_tree().quit(0 if ok else 1)
