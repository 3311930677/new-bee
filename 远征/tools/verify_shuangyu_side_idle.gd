extends SceneTree

const Actor := preload("res://src/preview/WalkActor.gd")
const Idle := preload("res://src/world/DirectionalIdle.gd")
const DIRECTIONS := {"down": Vector2(0, 60), "left": Vector2(-60, 0), "right": Vector2(60, 0), "up": Vector2(0, -60)}


func _initialize() -> void:
	call_deferred("_run")


func _check_standing(sprite: AnimatedSprite2D, direction: String) -> void:
	assert(sprite.animation == StringName("idle_" + direction), "must select real side idle")
	assert(sprite.frame == 0 and not sprite.is_playing(), "standing must remain still")
	var idle_tex := sprite.sprite_frames.get_frame_texture(sprite.animation, 0) as AtlasTexture
	var idle_path := "shuangyu_idle_side_video_v18.png" if direction in ["left", "right"] else "shuangyu_idle_vertical_video_v20.png"
	assert(idle_tex.atlas.resource_path.ends_with(idle_path), "must use video-derived idle")
	var source_slot := int(sprite.sprite_frames.get_meta("idle_walk_start_" + direction))
	var walk_tex := sprite.sprite_frames.get_frame_texture(StringName("walk_" + direction), source_slot) as AtlasTexture
	assert(idle_tex.get_image().get_data() == walk_tex.get_image().get_data(), "idle must match the exact video character pixels")
	assert(sprite.sprite_frames.get_frame_count(sprite.animation) == 1)
	assert(not sprite.sprite_frames.get_animation_loop(sprite.animation))


func _run() -> void:
	var frames := load("res://image/role/fs/shuangyu_walk_frames.tres") as SpriteFrames
	assert(frames != null)
	for direction in ["left", "right"]:
		assert(frames.has_animation(StringName("idle_" + direction)))
		assert(frames.get_frame_count(StringName("walk_" + direction)) == 30)
		assert(is_equal_approx(frames.get_animation_speed(StringName("walk_" + direction)), 30.0))
	for direction in ["down", "up"]:
		var walk := StringName("walk_" + direction)
		var cycle := float(frames.get_frame_count(walk)) / frames.get_animation_speed(walk)
		assert(is_equal_approx(cycle, 6.0 / 7.0), "preserve the user-selected slower gait period")
	# Exercise the real city and map animation handlers without starting a new game.
	var city_script = load("res://src/city/CityScene.gd")
	var map_script = load("res://src/explore/MapScene.gd")
	for controller in [city_script.new(), map_script.new()]:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		controller.set("_player_anim", sprite)
		for direction in DIRECTIONS:
			var velocity: Vector2 = DIRECTIONS[direction]
			controller.call("_update_player_anim", velocity)
			assert(sprite.animation == StringName("walk_" + direction) and sprite.is_playing())
			sprite.set_frame_and_progress(frames.get_frame_count(StringName("walk_" + direction)) - 1, 0.8)
			controller.call("_update_player_anim", Vector2.ZERO)
			_check_standing(sprite, direction)
			controller.call("_update_player_anim", Vector2.ZERO)
			_check_standing(sprite, direction)
			controller.call("_update_player_anim", velocity)
			assert(sprite.animation == StringName("walk_" + direction) and sprite.is_playing())
			assert(sprite.frame == int(frames.get_meta("idle_walk_start_" + direction)), "resume from the matching video idle pose")
		# Preserve cycle phase across different numbers of consecutive video frames.
		sprite.animation = &"walk_left"
		sprite.set_frame_and_progress(15, 0.4)
		controller.call("_update_player_anim", Vector2(0, 60))
		assert(sprite.animation == &"walk_down")
		var phase := (float(sprite.frame) + sprite.frame_progress) / frames.get_frame_count(&"walk_down")
		assert(is_equal_approx(phase, 15.4 / 30.0))
		controller.call("_update_player_anim", Vector2(60, 0))
		assert(sprite.animation == &"walk_right" and sprite.frame == 15)
		assert(is_equal_approx(sprite.frame_progress, 0.4))
		# Constructors allocate detached HUD/world nodes even without _ready().
		var detached: Array[Node] = []
		for property in controller.get_property_list():
			if not String(property.name).begins_with("_"):
				continue
			var value = controller.get(property.name)
			if value is Node and value != sprite and not value.get_parent() and not detached.has(value):
				detached.append(value)
		for node in detached:
			if is_instance_valid(node):
				node.free()
		sprite.free()
		controller.free()
	var actor := Actor.new()
	actor.configure(frames)
	actor.position = Vector2(240, 400)
	actor.controlled = true
	root.add_child(actor)
	for direction in DIRECTIONS:
		Input.action_press(StringName("ui_" + direction))
		for i in range(12):
			await physics_frame
		assert(actor.sprite.animation == StringName("walk_" + direction))
		Input.action_release(StringName("ui_" + direction))
		await physics_frame
		await physics_frame
		_check_standing(actor.sprite, direction)
	actor.queue_free()
	await process_frame
	# Other characters retain their existing stop behavior until they have idle art.
	var other := AnimatedSprite2D.new()
	other.sprite_frames = (load("res://image/role/ck/chuanyang_walk_frames.tres") as SpriteFrames).duplicate()
	for animation in other.sprite_frames.get_animation_names():
		if String(animation).begins_with("idle_"):
			other.sprite_frames.remove_animation(animation)
	other.animation = &"walk_left"
	other.play()
	Idle.stop(other)
	assert(other.animation == &"walk_left" and other.frame == 1 and not other.is_playing())
	other.free()
	print("SHUANGYU_SIDE_IDLE_OK: city, map and preview; left/right stop, hold and resume; fallback verified")
	quit(0)
