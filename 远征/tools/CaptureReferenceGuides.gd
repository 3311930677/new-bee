extends Node
func _ready() -> void:
	G.SAVE_PATH="res://shots/reference_rebuild_20261010/guide_save.json"
	var regions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/reference_rebuild_20261010/patches.json"))
	for id in regions:
		var viewport:=SubViewport.new();viewport.size=Vector2i(regions[id][2],regions[id][3]);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
		var art:=TextureRect.new();art.texture=load("res://assets/world/reference_rebuild_20261010/"+id+"_guide.svg");art.size=viewport.size;viewport.add_child(art)
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://assets/world/reference_rebuild_20261010/"+id+"_guide.png")
		viewport.queue_free();await get_tree().process_frame
	print("REFERENCE_GUIDE_CAPTURE_OK");get_tree().quit()
