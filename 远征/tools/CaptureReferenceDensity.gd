extends Node
const OUT:="res://shots/reference_complete_20261011/"
func _ready()->void:
	G.SAVE_PATH=OUT+"density_save.json"
	G.save_locked=true
	var hero:SpriteFrames=load("res://image/role/zs/pojun_walk_frames.tres")
	var old:=ImageTexture.create_from_image(Image.load_from_file("res://assets/world/reference_playable_20261010/ready/town_ground_natural.png"))
	var board:=Image.create(960,600,false,Image.FORMAT_RGBA8)
	var i:=0
	for kind in ["old","fine"]:
		var vp:=SubViewport.new()
		vp.size=Vector2i(480,600)
		vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var world:=Node2D.new()
		world.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		vp.add_child(world)
		if kind=="old":
			var ground:=Sprite2D.new();ground.centered=false;ground.texture=old
			ground.scale=Vector2(1200,2112)/Vector2(old.get_width(),old.get_height());world.add_child(ground)
		else:
			var ground:=preload("res://src/world/ReferenceFloor.gd").new()
			ground.setup("lorin_wilds",TableCache.main_world_map("lorin_wilds"));world.add_child(ground)
		var actor:=AnimatedSprite2D.new()
		actor.sprite_frames=hero
		actor.animation="idle_down"
		actor.scale=Vector2.ONE*.65
		actor.position=Vector2(600,1300-37.05)
		world.add_child(actor)
		var cam:=Camera2D.new()
		cam.position=Vector2(600,1300)
		cam.zoom=Vector2.ONE*1.15
		world.add_child(cam)
		cam.make_current()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image:=vp.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.save_png(OUT+"density_"+kind+".png")
		board.blit_rect(image,Rect2i(0,0,480,600),Vector2i(i*480,0))
		i+=1
		vp.queue_free()
		await get_tree().process_frame
	board.save_png(OUT+"density_comparison.png")
	print("DENSITY_CAPTURE_OK same hero, same zoom; old source texel=",1200.0/945.0," world; new texel=.5 world; hero=.65 world")
	get_tree().quit()
