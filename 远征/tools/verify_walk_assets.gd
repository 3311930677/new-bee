extends SceneTree

const Actor = preload("res://src/preview/WalkActor.gd")
const Idle = preload("res://src/world/DirectionalIdle.gd")
const ROLES = {"zs": "pojun", "ck": "chuanyang", "fs": "shuangyu", "fz": "chenxing"}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var checked := 0
	for role_id in ROLES:
		var path := "res://image/role/%s/%s_walk_frames.tres" % [role_id, ROLES[role_id]]
		var frames := load(path) as SpriteFrames
		assert(frames != null, path)
		var direct_video := bool(frames.get_meta("direct_video", false))
		var source_report: Dictionary = {}
		if direct_video:
			var report_path := String(frames.get_meta("video_source_manifest", "res://shots/three_roles_video_20261004/%s/runtime_source_checks.json" % role_id))
			source_report = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		for row in range(4):
			var direction: String = ["down", "left", "right", "up"][row]
			var animation := StringName("walk_" + direction)
			assert(frames.has_animation(animation))
			var direct_video_side: bool = role_id == "fs" and direction in ["left", "right"]
			var count := int(source_report.directions[direction].count) if direct_video else (30 if direct_video_side else 6)
			assert(frames.get_frame_count(animation) == count)
			assert(frames.get_animation_loop(animation))
			if direct_video_side:
				assert(is_equal_approx(frames.get_animation_speed(animation), 30.0))
			if direct_video:
				var expected_fps := float(source_report.directions[direction].get("playback_fps", 24.0))
				assert(is_equal_approx(frames.get_animation_speed(animation), expected_fps))
				var idle := StringName("idle_" + direction)
				assert(frames.get_frame_count(idle) == 1 and not frames.get_animation_loop(idle))
				var slot := int(frames.get_meta("idle_walk_start_" + direction))
				assert(slot == int(source_report.directions[direction].idle_walk_slot))
				assert(frames.get_frame_texture(idle, 0).get_image().get_data() == frames.get_frame_texture(animation, slot).get_image().get_data())
			for col in range(count):
				var tex := frames.get_frame_texture(animation, col) as AtlasTexture
				assert(tex != null)
				var atlas_row := row - 1 if direct_video_side else row
				if direct_video:
					atlas_row = int(source_report.directions[direction].get("atlas_row", atlas_row))
				assert(tex.region == Rect2(col * 128, atlas_row * 128, 128, 128))
				var expected_size := Vector2(3840, 256) if direct_video_side else Vector2(count * 128, 512)
				if direct_video:
					var columns := 0
					for entry in source_report.directions.values():
						columns = maxi(columns, int(entry.count))
					expected_size = Vector2(columns * 128, 512)
					if source_report.directions[direction].has("atlas_size"):
						var dimensions: Array = source_report.directions[direction].atlas_size
						expected_size = Vector2(dimensions[0], dimensions[1])
				assert(tex.atlas.get_size() == expected_size, "unexpected atlas size: %s" % tex.atlas.get_size())
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
			if direct_video:
				assert(actor.sprite.animation == StringName("idle_" + direction))
				var start := int(frames.get_meta("idle_walk_start_" + direction))
				Idle.change_walk_direction(actor.sprite, StringName("walk_" + direction))
				assert(actor.sprite.frame == start and is_zero_approx(actor.sprite.frame_progress))
				Idle.stop(actor.sprite)
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
