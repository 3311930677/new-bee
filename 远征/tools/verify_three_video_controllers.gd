extends SceneTree

const ROLES := {"zs": "pojun", "ck": "chuanyang", "fz": "chenxing", "fs": "shuangyu"}
const DIRECTIONS := {"down": Vector2(0, 60), "left": Vector2(-60, 0), "right": Vector2(60, 0), "up": Vector2(0, -60)}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path in ["res://src/city/CityScene.gd", "res://src/explore/MapScene.gd"]:
		var script = load(scene_path)
		for role_id in ROLES:
			var controller = script.new()
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = load("res://image/role/%s/%s_walk_frames.tres" % [role_id, ROLES[role_id]])
			controller.set("_player_anim", sprite)
			for direction in DIRECTIONS:
				var walk := StringName("walk_" + direction)
				var idle := StringName("idle_" + direction)
				controller.call("_update_player_anim", DIRECTIONS[direction])
				assert(sprite.animation == walk and sprite.is_playing())
				sprite.set_frame_and_progress(sprite.sprite_frames.get_frame_count(walk) - 1, 0.8)
				controller.call("_update_player_anim", Vector2.ZERO)
				assert(sprite.animation == idle and sprite.frame == 0 and not sprite.is_playing())
				controller.call("_update_player_anim", Vector2.ZERO)
				assert(sprite.animation == idle and sprite.frame == 0 and not sprite.is_playing())
				controller.call("_update_player_anim", DIRECTIONS[direction])
				assert(sprite.animation == walk and sprite.is_playing())
				assert(sprite.frame == int(sprite.sprite_frames.get_meta("idle_walk_start_" + direction)))
				assert(is_zero_approx(sprite.frame_progress))
			# Direction changes preserve phase across differing video cycle lengths.
			sprite.animation = &"walk_left"
			var left_count := sprite.sprite_frames.get_frame_count(&"walk_left")
			var right_count := sprite.sprite_frames.get_frame_count(&"walk_right")
			sprite.set_frame_and_progress(left_count / 2, 0.25)
			var expected := (float(sprite.frame) + sprite.frame_progress) / left_count
			controller.call("_update_player_anim", DIRECTIONS.right)
			var actual := (float(sprite.frame) + sprite.frame_progress) / right_count
			assert(is_equal_approx(actual, expected))
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
	print("THREE_VIDEO_CONTROLLERS_OK: 4 roles x 4 directions x city/map; stop, hold, matching-pose resume and phase-preserving turns")
	quit(0)
