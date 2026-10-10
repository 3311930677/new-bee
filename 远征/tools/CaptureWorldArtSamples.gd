extends Node
const OUT:="res://shots/world_art_samples_20261010/"
var measurements:Array=[]
var phase:="before"
var shot_count:=0
func frames(count:int=8) -> void:
	for i in count:await get_tree().process_frame
func sprite_measure(sprite:Node2D) -> Dictionary:
	var tex:Texture2D=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame) if sprite is AnimatedSprite2D else sprite.texture
	var used:=tex.get_image().get_used_rect()
	var transform:=sprite.get_global_transform_with_canvas()
	var extent:Vector2=tex.get_size()
	var visible_rect:=transform*Rect2(Vector2(used.position)-extent*.5,Vector2(used.size))
	return {"frame_canvas":extent,"visible_source":used,"visible_display":visible_rect,"local_scale":sprite.scale,"filter":sprite.texture_filter}
func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():phase=OS.get_cmdline_user_args()[0]
	G.SAVE_PATH=OUT+phase+"_isolated_save.json"
	G.set_meta("ui_review_mode",true)
	G.set_meta("sunny_sample_disabled",phase=="before")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+phase))
	for height in [800,1067]:
		get_window().size=Vector2i(480,height);await frames()
		for id in ["lorin_wilds","maple_road"]:
			G._init_state_defaults();G.save_locked=false;G.selected_role="zs";G.player_name="行旅人";G.prog.level=12
			G.collect_pet("pet_rockturtle");G.collect_pet("pet_thunderhawk")
			var run:=RunState.new();run.setup({"role_id":"zs","theme":"forest","level":12,"active_pet":"pet_rockturtle","potions":2,"seed":17})
			MapScene.pending_cfg={"mode":"main_world","main_map_id":id,"run":run,"node":{"type":"normal","layer":0,"index":0}}
			var map:=preload("res://src/explore/MapScene.tscn").instantiate();add_child(map);await frames()
			var camera:=map.get_viewport().get_camera_2d()
			var info:Dictionary={"map":id,"height":height,"camera_zoom":camera.zoom,"grid_display":camera.zoom*48,"hero":sprite_measure(map._player_anim),"buildings":[],"npcs":[]}
			if map._city_content!=null:
				for building in map._city_content._buildings:
					var shape:CollisionShape2D
					for child in building.get_children():
						if child is CollisionShape2D:shape=child;break
					info.buildings.append({"id":building.data.id,"built":building.built(),"at":building.position,"modulate":building.modulate,"art":building.art.resource_path if building.art!=null else "","shape":shape.shape.size})
				for npc in map._city_content._npcs:
					var entry:Dictionary={"id":npc.data.id,"name":npc.data.name,"at":npc.position}
					if npc.get_node_or_null("Idle")!=null:entry.merge(sprite_measure(npc.get_node("Idle")))
					info.npcs.append(entry)
			measurements.append(info)
			await shot(map,id+"_spawn_%d"%height)
			if height==800:
				map._player.position=Vector2(480,420) if id=="lorin_wilds" else Vector2(480,700)
				await frames(12);await shot(map,id+"_sample_800")
				if id=="lorin_wilds":
					map._player.position=Vector2(330,370);map._hud.visible=false
					await frames(12);await shot(map,"hall_npc_art_debug_800")
			map.queue_free();await frames()
	var file:=FileAccess.open(OUT+phase+"/measurements.json",FileAccess.WRITE);file.store_string(JSON.stringify(measurements,"\t"))
	print("WORLD_SAMPLE_CAPTURE_OK ",phase," views=",shot_count);get_tree().quit()
func shot(map:MapScene,name:String) -> void:
	shot_count+=1
	await RenderingServer.frame_post_draw
	var result:=get_viewport().get_texture().get_image().save_png(OUT+phase+"/"+name+".png")
	if result!=OK:push_error("WORLD_SAMPLE_CAPTURE_FAIL "+name);get_tree().quit(1)
