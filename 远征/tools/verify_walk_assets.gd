extends SceneTree

const Actor = preload("res://src/preview/WalkActor.gd")
const ROLES = {"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var checked := 0
	for role_id in ROLES:
		var path := "res://image/role/%s/%s_walk_frames.tres" % [role_id, ROLES[role_id]]
		var frames := load(path) as SpriteFrames
		assert(frames != null, path)
		for row in range(4):
			var direction: String = ["down", "left", "right", "up"][row]
			var animation := StringName("walk_" + direction)
			assert(frames.has_animation(animation))
			assert(frames.get_frame_count(animation) == 8)
			assert(frames.get_animation_loop(animation))
			for col in range(8):
				var tex := frames.get_frame_texture(animation, col) as AtlasTexture
				assert(tex != null)
				assert(tex.region == Rect2(col * 128, row * 128, 128, 128))
				assert(tex.atlas.get_size() == Vector2(1024, 512))
				assert(tex.filter_clip)
				checked += 1
		var actor := Actor.new()
		actor.configure(frames)
		actor.position = Vector2(240, 400)
		actor.controlled = true
		root.add_child(actor)
		await physics_frame
		for direction in ["down", "left", "right", "up"]:
			var action := StringName("ui_" + direction)
			var before := actor.position
			Input.action_press(action)
			for i in range(12):
				await physics_frame
			Input.action_release(action)
			var displacement := actor.position - before
			assert(displacement.length() > 5.0 and displacement.length() < 20.0, "translation must use pixels/second")
			assert(actor.sprite.animation == StringName("walk_" + direction))
			await physics_frame
			await physics_frame
			assert(not actor.sprite.is_playing())
		# Diagonal motion is normalized, not sqrt(2) faster.
		actor.position = Vector2(240, 400)
		Input.action_press(&"ui_right")
		Input.action_press(&"ui_down")
		await physics_frame
		await physics_frame
		assert(is_equal_approx(actor.velocity.length(), 60.0))
		Input.action_release(&"ui_right")
		Input.action_release(&"ui_down")
		await physics_frame
		actor.queue_free()
		await process_frame
	print("WALK_ASSETS_OK: %d atlas frames; four roles x four movement directions; stop and diagonal normalization verified." % checked)
	quit(0)
