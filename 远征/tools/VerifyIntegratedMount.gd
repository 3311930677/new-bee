extends Node
const Mount := preload("res://src/world/MountVisual.gd")
const OUT := "res://shots/full_issue_fix_20261024/mount/"
var checks := 0
var failures := 0
var capture := false
var records: Array = []

func check(ok: bool,detail: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("INTEGRATED_MOUNT_FAIL "+detail)

func frames(n:=3) -> void:
	for i in n:await get_tree().process_frame

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	var prototype := "--prototype" in OS.get_cmdline_user_args()
	G.SAVE_PATH="res://tools/_logs/integrated_mount_save.json"
	G._init_state_defaults()
	G.save_locked=false
	G.wallet.gold=100000
	G.player_name="骑乘连续帧验收"
	G.set_meta("ui_review_mode",true)
	for mount in ["horse","bear"]:G.mount_buy(mount)
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(480,800)
	get_window().content_scale_size=Vector2i(480,800)
	for mount in (["horse"] if prototype else ["horse","bear"]):
		for role in (["zs"] if prototype else ["zs","ck","fs","fz"]):
			await verify_actor(mount,role)
	var file:=FileAccess.open("res://tools/_logs/integrated_mount_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"));file.close()
	print("INTEGRATED_MOUNT_OK checks=%d failures=%d actors=%d"%[checks,failures,records.size()])
	Audio.stop_bgm();Audio.set_suspended(true)
	await get_tree().create_timer(.2).timeout
	await frames(8)
	get_tree().quit(0 if failures==0 else 1)

func verify_actor(mount: String,role: String) -> void:
	G.selected_role=role
	G.mount_set_active(mount)
	G.mount_set_riding(true,false)
	G.prog.main_world={"map_id":"lorin_wilds"}
	var run:=RunState.new()
	run.setup({"role_id":role,"theme":"forest","level":20,"seed":71})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":"lorin_wilds","run":run,"node":{"type":"normal","layer":1,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await frames(6)
	map.set_physics_process(false)
	if map._city_content!=null:map._city_content.set_physics_process(false)
	map._player.position=Vector2(480,700)
	var actor:=map._mount_anim
	check(actor.sprite_frames!=null,"all authored frames exist "+mount+role)
	if actor.sprite_frames==null:
		map.queue_free();await frames();return
	check(actor.visible and not map._player_anim.visible,"one integrated actor "+mount+role)
	check(map._mount_foreground==null or not map._mount_foreground.visible,"no overlay muzzle")
	check((map._player_shape.shape as RectangleShape2D).size==Vector2(42,28),"mounted collision preserved")
	var samples: Array=[]
	for direction in ["down","left","right","up"]:
		var vector: Vector2={"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP}[direction]
		for action in ["idle","walk","run"]:
			map._sprint=action=="run"
			map._update_player_anim(vector*180)
			map._update_player_anim(Vector2.ZERO if action=="idle" else vector*180)
			var name: String=action+"_"+direction
			check(String(actor.animation)==name,"state transition "+name)
			var count: int={"idle":4,"walk":8,"run":12}[action]
			check(actor.sprite_frames.get_frame_count(name)==count,"distinct poses "+name)
			for index in count:
				var texture:=actor.sprite_frames.get_frame_texture(name,index) as AtlasTexture
				check(texture!=null and texture.atlas!=null and texture.atlas.get_width()>0,"cel texture imports "+name+str(index))
			check(actor.position+(Mount.FOOT-Vector2.ONE*Mount.CELL*.5)*actor.scale==Vector2(0,22),"stable foot registration on ground shadow")
			actor.speed_scale=1
			var seen: Dictionary={}
			for tick in 65:
				await get_tree().physics_frame
				seen[actor.frame]=true
			check(seen.size()==count,"all sequential frames play "+name+" "+str(seen.keys()))
			samples.append({"animation":name,"seen":seen.keys()})
			if capture:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(OUT+mount+"_"+role+"_"+name+".png")
		# A held contact never repeats a sound; idle never creates hoof audio.
		map._sprint=false;map._update_player_anim(vector*180);actor.pause();actor.frame=0
		Audio._last_events.clear();Audio.event_log.clear()
		for voice in Audio._sfx_pool:voice.stop()
		map._mount_contact_frame=-1;map._mount_hoof_timer=0
		map._tick_mount_hoof(.1,vector*180);map._tick_mount_hoof(.1,vector*180)
		check(Audio.event_log.size()==1,"held contact sounds once")
		map._update_player_anim(Vector2.ZERO)
		var before:=Audio.event_log.size()
		map._tick_mount_hoof(.1,Vector2.ZERO)
		check(Audio.event_log.size()==before and map._mount_contact_frame==-1,"idle clears hoof contact")
	G.mount_set_riding(false,false);map._sync_mount_visual()
	check(map._player_anim.visible and not actor.visible,"dismount restores walking person")
	check((map._player_shape.shape as RectangleShape2D).size==Vector2(30,26),"dismount collision restored")
	records.append({"mount":mount,"role":role,"animations":samples})
	remove_child(map);map.queue_free();await frames(5)
