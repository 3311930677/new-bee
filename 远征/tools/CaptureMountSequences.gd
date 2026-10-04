# Rendering fixture only; inspect real moving rider/mount pairing at both view heights.
extends Node
var records:Array=[]
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_mount_motion_qa.json"
	G._init_state_defaults()
	G.save_locked=false
	G.wallet.gold=10000
	for mount in ["horse","bear"]:G.mount_buy(mount)
	DirAccess.make_dir_recursive_absolute("res://shots/body_mount_motion_20261004")
	for height in [800,1067]:
		get_window().size=Vector2i(480,height)
		await get_tree().process_frame
		for mount in ["horse","bear"]:
			for role in ["zs","ck","fs","fz"]:
				G.selected_role=role
				G.mount_set_active(mount)
				G.mount_set_riding(true)
				G.prog.main_world={"map_id":"frost_post"}
				var run:=RunState.new()
				run.setup({"role_id":role,"theme":"snow","level":20,"seed":71})
				MapScene.pending_cfg={"mode":"main_world","main_map_id":"frost_post","run":run,"node":{"type":"normal","layer":1,"index":0}}
				var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
				add_child(map)
				await get_tree().process_frame
				map._city_content.set_physics_process(false)
				await get_tree().create_timer(2.6).timeout
				for direction in ["down","left","right","up"]:
					map._player.position=Vector2(480,1030)
					for child in map._player.get_children():
						if child is Camera2D:child.reset_smoothing()
					var frames:Dictionary={}
					Input.action_press("move_"+direction)
					for i in 36:
						await get_tree().physics_frame
						frames[int(map._mount_anim.frame)]=true
					await RenderingServer.frame_post_draw
					var name:="%s_%s_%s_%d.png"%[mount,role,direction,height]
					get_viewport().get_texture().get_image().save_png("res://shots/body_mount_motion_20261004/"+name)
					var foot:=map._player.get_global_transform_with_canvas().origin
					records.append({"image":name,"foot":[foot.x,foot.y],"frames":frames.keys(),"animation":String(map._mount_anim.animation),"moving":map._player.velocity.length()>0,"rider_visible":map._player_anim.visible,"mount_visible":map._mount_anim.visible})
					Input.action_release("move_"+direction)
				map.queue_free()
				await get_tree().process_frame
	var file:=FileAccess.open("res://tools/_logs/mount_motion_qa.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records))
	file.close()
	print("MOUNT_MOTION_QA_OK renders=%d"%records.size())
	get_tree().quit()
