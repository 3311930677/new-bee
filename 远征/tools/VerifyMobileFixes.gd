extends Node
const Currency := preload("res://src/ui/CurrencyPanel.gd")
const Gathering := preload("res://src/ui/CampGatheringPanel.gd")
const Safe := preload("res://src/ui/UiSafeArea.gd")
const Mount := preload("res://src/world/MountVisual.gd")
const OUT := "res://shots/mobile_fixes_20261024/"
var failures := 0
var checks := 0
var capture := false

func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("MOBILE_FAIL "+words)

func frames(count := 3) -> void:
	for i in count: await get_tree().process_frame

func photo(name: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT+name+".png")

func discard(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await frames()

func _ready() -> void:
	capture = "--capture-mobile" in OS.get_cmdline_user_args()
	G.SAVE_PATH = "res://tools/_logs/mobile_fixes_save.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.player_name = "手机验收"
	G.set_meta("ui_review_mode",true)
	Audio.set_suspended(false)
	DirAccess.make_dir_recursive_absolute(OUT)
	# Export-style named lookup: no runtime directory enumeration is needed.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_manifest.json"))
	G._res_index = manifest.duplicate()
	G._res_indexed = true
	G._tex_cache.clear()
	for key in manifest:
		check(ResourceLoader.exists(String(manifest[key])),"manifest path "+String(key))
	for stat in ["atk","def","hp"]:
		for tier in range(1,6):
			var id := "gem_%s_%d" % [stat,tier]
			G.items[id] = 9
			check(G.res_tex(G.item_icon(id)) != null,"export lookup "+id)
	for id in ["iron_ore","enhance_stone","pet_food"]:
		G.items[id] = 99
		check(G.res_tex(G.item_icon(id)) != null,"material lookup "+id)
	check(GmConsole._bar_layer == null,"default build never creates covering GM bar")
	get_window().unresizable = false
	get_window().min_size = Vector2i(320,480)
	for size in [Vector2i(480,800),Vector2i(480,853),Vector2i(480,1067),Vector2i(480,960),Vector2i(480,640)]:
		get_window().size = size
		get_window().content_scale_size = size
		await frames()
		var view := get_viewport().get_visible_rect()
		check(absf(view.size.y-size.y)<1,"actual viewport height matches requested case")
		var safe := Rect2(8,36,view.size.x-16,view.size.y-64)
		G.set_meta("test_safe_rect",safe)
		var suffix := "%dx%d" % [size.x,size.y]
		var wallet_before := G.wallet.duplicate(true)
		for id in ["gold","expedition","soul","honor"]:
			var currency := Currency.new()
			currency.currency_id = id
			add_child(currency)
			await frames(6)
			check(safe.encloses(currency._frame.get_global_rect()),"currency safe "+id+suffix)
			check(currency.currency_id==id and str(G.wallet[id]) in currency._balance.text,"exact selected balance "+id)
			check(currency._icon.texture!=null,"currency icon "+id)
			check(currency._scroll.size.y>60,"reading viewport remains useful "+suffix)
			if id=="gold": await photo("currency_"+suffix)
			await discard(currency)
		check(G.wallet==wallet_before,"currency reading never changes balances")
		var bag := preload("res://src/ui/BagPanel.gd").new()
		add_child(bag)
		await frames()
		bag._select_tab("gem")
		await frames()
		for cell in bag._item_buttons:
			check(cell.item_image.texture!=null,"occupied gem never blank")
		check(safe.encloses(bag._close_btn.get_global_rect()),"bag return safe "+suffix)
		await photo("gems_"+suffix)
		await discard(bag)
		var gathering := Gathering.new()
		add_child(gathering)
		await frames(8)
		check(safe.encloses(gathering._frame.get_global_rect()),"gathering page safe "+suffix)
		for i in gathering.stories.size():
			gathering.listen(i)
			check(String(gathering.stories[i].text) in gathering.page.text,"story fully readable")
		await photo("gathering_"+suffix)
		await discard(gathering)
		var activity := preload("res://src/ui/ActivityPanel.gd").new()
		add_child(activity)
		await frames(6)
		check(safe.encloses(activity._back.get_global_rect()),"activity back anchored "+suffix)
		check(activity._content.position.y+activity._content.size.y*activity._content.scale.y <= activity._back.position.y,"activity scroll avoids back action")
		await photo("activity_"+suffix)
		await discard(activity)
	G.remove_meta("test_safe_rect")
	get_window().size = Vector2i(480,800)
	await frames()
	G.wallet.gold = 100000
	G.mount_buy("horse")
	G.mount_buy("bear")
	for role in ["zs","ck","fs","fz"]:
		G.selected_role = role
		for mount in ["horse","bear"]:
			G.mount_set_active(mount)
			G.mount_set_riding(true,false)
			var run := RunState.new()
			run.setup({"role_id":role,"theme":"forest","level":20,"seed":71})
			MapScene.pending_cfg={"mode":"main_world","main_map_id":"lorin_wilds","run":run,"node":{"type":"normal","layer":1,"index":0}}
			var map := preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
			add_child(map)
			await frames(6)
			map.set_physics_process(false)
			map._player.position = Vector2(480,700)
			var pose := Mount.frames_for(role,mount)
			for direction in Mount.DIRECTIONS:
				check(pose.get_frame_texture(direction,0).get_size().x>1,"dedicated seated pose "+role+direction)
				var vector: Vector2 = {"walk_down":Vector2.DOWN,"walk_left":Vector2.LEFT,"walk_right":Vector2.RIGHT,"walk_up":Vector2.UP}[direction]
				map._update_player_anim(vector*180)
				map._mount_anim.pause()
				check(not map._player_anim.visible and (map._mount_foreground==null or not map._mount_foreground.visible),"one integrated rider and mount")
				check(map._mount_anim.sprite_frames.get_frame_count(direction)==8,"sequential walk gait "+mount+direction)
				await frames()
				await photo("rider_%s_%s_%s" % [role,mount,direction])
				# Sound follows contact phase, never a timer independent of animation.
				Audio._last_events.clear()
				Audio.event_log.clear()
				for voice in Audio._sfx_pool: voice.stop()
				map._mount_hoof_timer=0
				map._mount_contact_frame=-1
				map._mount_anim.frame=0
				map._tick_mount_hoof(.1,vector*180)
				check(Audio.event_log.size()==1,"one event per contact")
				map._tick_mount_hoof(.1,vector*180)
				check(Audio.event_log.size()==1,"held frame never repeats sound")
				map._tick_mount_hoof(.1,Vector2.ZERO)
				check(map._mount_contact_frame==-1,"stop clears stride state")
			await discard(map)
	G.selected_role="zs"
	G.mount_set_riding(false,false)
	print("MOBILE_FIXES_OK checks=%d failures=%d" % [checks,failures])
	await frames()
	get_tree().quit(0 if failures==0 else 1)
