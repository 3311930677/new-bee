extends Node
## Isolated A/B review in the actual world; production art and animation stay recoverable.
const ART := "res://image/style_review_20261005/"
const OUT := "res://shots/style_review_20261005/"
const RuntimeArt := preload("res://src/world/WorldArtFinish.gd")
var world: MapScene
var ground: TextureRect
var original_ground: Texture2D
var original_pet: Texture2D
var original_player_material: Material
var original_pet_material: Material
var adjusted := true
var hint: Label

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_art_style_preview.json"
	G.set_meta("ui_review_mode", true)
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "fs"
	G.player_name = "陆川愿"
	G.prog.level = 12
	G.prog.exp = 100
	G.prog.pets = ["pet_rockturtle"]
	G.ensure_starter_buildings()
	for building in G.city_buildings():
		if not G.city.built.has(building.id): G.city.built.append(building.id)
	G.wallet = {"gold":100789,"expedition":1011,"soul":979,"honor":9}
	G.prog.main_world = {"map_id":"lorin_wilds"}
	G.mount_set_riding(false, false)
	var run := RunState.new()
	run.setup({"theme":"forest","role_id":"fs","level":12,
		"active_pet":"pet_rockturtle","bench_pet":"","potions":2,"seed":19})
	MapScene.pending_cfg = {"mode":"main_world","main_map_id":"lorin_wilds",
		"run":run,"node":{"type":"normal","layer":0,"index":0}}
	world = preload("res://src/explore/MapScene.tscn").instantiate()
	add_child(world)
	world._player.position = Vector2(480,775)
	world._pet_follower.position = world._player.position + Vector2(-64,-24)
	for child in world.get_children():
		if child is TextureRect and child.texture != null and child.size.x > 900:
			ground = child
			break
	assert(ground != null, "Preview ground not found")
	original_ground = load("res://image/main_world/lorin_wilds_reference_v6.png")
	original_pet = load("res://image/generated_362_xajh/ready/pet/refined/pet_rockturtle.png")
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	hint = Label.new()
	hint.position = Vector2(12,210)
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color("fff1ca"))
	hint.add_theme_color_override("font_outline_color",Color("17251c"))
	hint.add_theme_constant_override("outline_size",5)
	layer.add_child(hint)
	var production := "--capture-production" in OS.get_cmdline_user_args()
	if not production: _apply()
	for i in 8: await get_tree().process_frame
	if production:
		await _capture_production()
	elif "--capture-style" in OS.get_cmdline_user_args():
		await _capture()
	else:
		print("ART_STYLE_PREVIEW_READY: Space A/B, arrows/WASD move, 1 town north, 2 town south.")

func _apply() -> void:
	ground.texture = load(ART+"ground_crisp_v1.png") if adjusted else original_ground
	world._player_anim.material = RuntimeArt.character_material("fs") if adjusted else original_player_material
	world._pet_follower_sprite.texture = RuntimeArt.turtle_texture() if adjusted else original_pet
	world._pet_follower_sprite.material = original_pet_material
	world._pet_follower_sprite.scale = Vector2.ONE * (56.0 / world._pet_follower_sprite.texture.get_width())
	hint.text = ("调整版" if adjusted else "原版") + " · 空格切换对照 · 方向键行走 · 1/2 看上下城区"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_SPACE:
		adjusted = not adjusted
		_apply()
	elif event.keycode in [KEY_1,KEY_2]:
		world._player.position = Vector2(480,775 if event.keycode==KEY_1 else 1030)
		world._pet_follower.position = world._player.position + Vector2(-64,-24)
		_reset_camera()

func _reset_camera() -> void:
	for child in world._player.get_children():
		if child is Camera2D:
			child.reset_smoothing()
			child.force_update_scroll()

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	hint.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		for location in ["north","south"]:
			world._player.position = Vector2(480,775 if location=="north" else 1030)
			world._pet_follower.position = world._player.position + Vector2(-64,-24)
			_reset_camera()
			for version in [false,true]:
				adjusted = version
				_apply()
				for i in 6: await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var path := OUT+"%s_%s_%d.png" % [location,"after" if version else "before",height]
				assert(get_viewport().get_texture().get_image().save_png(path)==OK)
	print("ART_STYLE_CAPTURE_OK: actual map, unchanged animation frames, two positions and sizes, A/B.")
	world.queue_free()
	for i in 3: await get_tree().process_frame
	get_tree().quit()

func _capture_production() -> void:
	# Do not call _apply(): validate assets loaded through normal game initialization.
	assert(ground.texture.resource_path == String(TableCache.main_world_map("lorin_wilds").get("background", "")))
	assert(world._player_anim.material == RuntimeArt.character_material("fs"))
	assert(world._pet_follower_sprite.texture == G.res_tex("pet_rockturtle"))
	assert(world._pet_follower_sprite.texture.get_size() == Vector2(96,96))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	hint.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
		world._update_player_anim(direction*60.0)
		assert(world._player_anim.is_playing())
		world._update_player_anim(Vector2.ZERO)
		assert(not world._player_anim.is_playing())
	world._update_player_anim(Vector2.DOWN*60.0)
	world._update_player_anim(Vector2.ZERO)
	for height in [800,1067]:
		get_window().size = Vector2i(480,height)
		_reset_camera()
		for i in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(OUT+"production_%d.png" % height)==OK)
	print("ART_STYLE_PRODUCTION_OK: normal game initialization, new ground and pet, four-direction player finish.")
	world.queue_free()
	for i in 3: await get_tree().process_frame
	get_tree().quit()
