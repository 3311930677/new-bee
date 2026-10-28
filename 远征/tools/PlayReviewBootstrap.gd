extends Node
## Development-only entry: isolates the save while preserving the real startup flow.

class ReviewObserver extends Node:
	var index := 0
	func _ready() -> void:
		for file in DirAccess.get_files_at("res://shots/play_iteration_20261026"):
			if file.begins_with("manual_") and file.ends_with(".png"): index += 1
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
			capture.call_deferred()
	func capture() -> void:
		await RenderingServer.frame_post_draw
		index += 1
		var path := "res://shots/play_iteration_20261026/manual_%02d.png" % index
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		var scene := get_tree().current_scene
		var map_info := {}
		if scene is MapScene:
			map_info = {"map": scene._main_map_id, "player": str(scene._player.position), "nav": str(scene._hud_target_info()), "auto": scene._auto_walk}
		print("PLAY_REVIEW ", JSON.stringify({"shot": path, "scene": scene.scene_file_path if scene != null else "", "story": G.prog.get("story", {}), "wallet": G.wallet, "navigation": map_info}))

func _ready() -> void:
	G.SAVE_PATH = ProjectSettings.globalize_path("res://../reports/play_iteration_20261026/runtime/manual_save.json")
	G._init_state_defaults()
	G._load_save()
	G.ensure_starter_buildings()
	get_tree().root.add_child.call_deferred(ReviewObserver.new())
	get_tree().change_scene_to_file.call_deferred("res://src/main/Main.tscn")
