extends Node
func _ready() -> void:
	G.SAVE_PATH="res://shots/full_review_fixes_20261009/map_guide_save.json"
	get_window().size=Vector2i(720,800)
	var view:=SubViewport.new();view.size=Vector2i(1440,1600);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(view)
	var art:=TextureRect.new();art.texture=load("res://assets/ui/full_review_fixes_20261009/map_guide.svg");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.size=Vector2(1440,1600);view.add_child(art)
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://assets/ui/full_review_fixes_20261009/map_guide.png")
	print("MAP_GUIDE_OK");get_tree().quit()
