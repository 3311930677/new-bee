extends Node
const BASE := "D:/new-bee/ui_review_input/reference_world_frontend_20261010/"
var measurements: Array = []
func tex(path: String) -> Texture2D:
	var im := Image.load_from_file(path)
	assert(im != null, path)
	return ImageTexture.create_from_image(im)
func _ready() -> void:
	var hero_source := tex("D:/new-bee/远征/image/role/zs/pojun_idle_video_v19.png")
	var hero := AtlasTexture.new()
	hero.atlas = hero_source
	hero.region = Rect2(0, 0, 128, 128)
	for item in [["A1", "A1_meadow_candidate.png", Vector2(960,2112)], ["A10", "A10_plaza_candidate.png", Vector2(960,1920)]]:
		var art := tex(BASE + "samples_prompt_v2/" + item[1])
		for mapping in ["whole", "patch"]:
			var extent: Vector2 = item[2] if mapping == "whole" else Vector2(480,1067)
			var board := Image.create(1440,840,false,Image.FORMAT_RGBA8)
			board.fill(Color("211c18"))
			var index := 0
			for zoom in [1.0,1.15,1.25]:
				var result := await capture(art,hero,extent,zoom,800)
				result.convert(Image.FORMAT_RGBA8)
				var name := "%s_%s_z%s.png" % [item[0],mapping,str(zoom).replace(".","_")]
				result.save_png(BASE+"integration_audit/"+name)
				board.blit_rect(result,Rect2i(0,0,480,800),Vector2i(index*480,40))
				index += 1
			# Header is a normal 2D label render; candidate textures remain unchanged.
			var header := SubViewport.new()
			header.size=Vector2i(1440,40)
			header.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			add_child(header)
			for i in 3:
				var label := Label.new()
				label.position=Vector2(i*480+12,6)
				label.text="%s | %s | zoom %s" % [item[0],mapping,str([1.0,1.15,1.25][i])]
				label.add_theme_font_size_override("font_size",20)
				header.add_child(label)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var header_image := header.get_texture().get_image()
			header_image.convert(Image.FORMAT_RGBA8)
			board.blit_rect(header_image,Rect2i(0,0,1440,40),Vector2i.ZERO)
			board.save_png(BASE+"integration_audit/"+item[0]+"_"+mapping+"_comparison.png")
			header.queue_free()
			var tall := await capture(art,hero,extent,1.15,1067)
			tall.save_png(BASE+"integration_audit/"+item[0]+"_"+mapping+"_tall.png")
	FileAccess.open(BASE+"integration_audit/measurements.json",FileAccess.WRITE).store_string(JSON.stringify(measurements,"  "))
	print("INTEGRATION_AUDIT_CAPTURE_OK: 16 cases, isolated 2D project, no game save or map data access")
	get_tree().quit()
func capture(art:Texture2D,hero:Texture2D,extent:Vector2,zoom:float,height:int)->Image:
	var vp:=SubViewport.new()
	vp.size=Vector2i(480,height)
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var world:=Node2D.new()
	world.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	vp.add_child(world)
	var bg:=Sprite2D.new()
	bg.texture=art
	bg.centered=false
	bg.scale=extent/Vector2(art.get_width(),art.get_height())
	world.add_child(bg)
	var player:=Sprite2D.new()
	player.texture=hero
	player.scale=Vector2.ONE*.65
	player.position=extent*.5+Vector2(0,-(121.0-64.0)*.65)
	world.add_child(player)
	var camera:=Camera2D.new()
	camera.zoom=Vector2.ONE*zoom
	camera.position=extent*.5
	world.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	var hud:=CanvasLayer.new()
	vp.add_child(hud)
	var top:=ColorRect.new()
	top.color=Color(.08,.06,.05,.65)
	top.size=Vector2(480,110)
	hud.add_child(top)
	var label:=Label.new()
	label.position=Vector2(14,14)
	label.text="2D scale audit / mock HUD\nWorld: %s x %s   Camera: %s\nView: %.1f x %.1f world units" % [extent.x,extent.y,zoom,480.0/zoom,float(height)/zoom]
	label.add_theme_font_size_override("font_size",18)
	hud.add_child(label)
	var bottom:=ColorRect.new()
	bottom.position=Vector2(0,height-130)
	bottom.size=Vector2(480,130)
	bottom.color=Color(.08,.06,.05,.65)
	hud.add_child(bottom)
	var foot:=Label.new()
	foot.position=Vector2(14,height-116)
	foot.text="Hero visible height: %.1f screen units\nStatic candidate: no collision or occlusion" % (110.0*.65*zoom)
	foot.add_theme_font_size_override("font_size",18)
	hud.add_child(foot)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var transform:=vp.get_canvas_transform()
	measurements.append({"world_extent":[extent.x,extent.y],"viewport":[480,height],"zoom":zoom,"actual_canvas_scale":[transform.x.length(),transform.y.length()],"image_native":[art.get_width(),art.get_height()],"texture_scale":[bg.scale.x,bg.scale.y],"hero_visible_world":71.5,"hero_visible_screen":71.5*zoom,"visible_world":[480.0/zoom,float(height)/zoom]})
	var output:=vp.get_texture().get_image()
	vp.queue_free()
	await get_tree().process_frame
	return output

