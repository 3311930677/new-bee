extends Node
const Journey := preload("res://src/world/JourneyService.gd")
## 验证开发者「解锁全部世界」能放行主世界出口与驿路，且不改写剧情进度。
func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/verify_gm_world_open_save.json"
	G._init_state_defaults()
	G.save_locked = false
	var fails := 0
	var locked: Dictionary = Journey.status(G, "stele_core")
	if bool(locked.get("ok", false)): fails += 1; print("FAIL: 未放行时碑心不应可达")
	G.gm_unlocked = OS.is_debug_build()
	G.gm_unlock_all_worlds()
	var maps: Dictionary = TableCache.main_world_config().get("maps", {})
	for id in maps:
		var st: Dictionary = Journey.status(G, String(id))
		if not Journey.point(String(id)).is_empty() and not bool(st.get("ok", false)):
			fails += 1; print("FAIL: 驿路仍被拦：", id, " ", st.get("line", ""))
	if not G.world_gate_open(): fails += 1; print("FAIL: world_gate_open 未生效")
	if not (G.prog.get("story", {}).get("done", []) as Array).is_empty():
		fails += 1; print("FAIL: 放行改写了剧情进度")
	G.gm_unlocked = false
	if G.world_gate_open(): fails += 1; print("FAIL: 关闭开发者权限后仍放行")
	print("GM_WORLD_OPEN_OK" if fails == 0 else "GM_WORLD_OPEN_FAIL fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
