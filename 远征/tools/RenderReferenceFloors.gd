extends Node
const OUT:="res://assets/world/reference_complete_20261011/ready/"
func _ready()->void:
	G.SAVE_PATH="res://shots/reference_complete_20261011/terrain_capture_save.json"
	G.save_locked=true
	var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/reference_complete_20261011/layout.json"))
	for id in plan.regions:
		var region:Dictionary=plan.regions[id]
		var viewport:=SubViewport.new()
		viewport.size=Vector2i(region.extent[0],region.extent[1])
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var terrain:=preload("res://src/world/ReferenceTerrain.gd").new()
		terrain.setup(id,Vector2(region.extent[0],region.extent[1]))
		viewport.add_child(terrain)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		assert(image.save_png(OUT+id+"_floor.png")==OK)
		viewport.remove_child(terrain)
		terrain.free()
		viewport.queue_free()
		await get_tree().process_frame
		for side in ["top","bottom"]:
			var vp:=SubViewport.new()
			vp.size=Vector2i(int(region.extent[0])*2,int(region.extent[1]))
			vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(vp)
			var world:=Node2D.new();world.scale=Vector2.ONE*2;vp.add_child(world)
			var fine:=preload("res://src/world/ReferenceTerrain.gd").new()
			fine.setup(id,Vector2(region.extent[0],region.extent[1]))
			fine.position=Vector2(0,-float(region.extent[1])*.5 if side=="bottom" else 0)
			world.add_child(fine)
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			assert(vp.get_texture().get_image().save_png(OUT+id+"_floor_"+side+".png")==OK)
			world.remove_child(fine);fine.free();vp.queue_free();await get_tree().process_frame
	print("REFERENCE_FLOORS_OK")
	get_tree().quit()
