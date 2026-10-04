extends RefCounted
## Prefer a dedicated standing pose when this character provides one.


static func stop(sprite: AnimatedSprite2D) -> void:
	var direction := String(sprite.animation).trim_prefix("walk_").trim_prefix("idle_")
	var idle := StringName("idle_" + direction)
	sprite.stop()
	if sprite.sprite_frames.has_animation(idle):
		sprite.animation = idle
		sprite.set_frame_and_progress(0, 0.0)
	else:
		sprite.frame = 1


static func change_walk_direction(sprite: AnimatedSprite2D, animation: StringName) -> void:
	if sprite.animation == animation:
		return
	var phase := 0.0
	if String(sprite.animation).begins_with("walk_"):
		var count := sprite.sprite_frames.get_frame_count(sprite.animation)
		if count > 0:
			phase = (float(sprite.frame) + sprite.frame_progress) / float(count)
	elif String(sprite.animation) == String(animation).replace("walk_", "idle_"):
		var direction := String(animation).trim_prefix("walk_")
		var start := int(sprite.sprite_frames.get_meta("idle_walk_start_" + direction, 0))
		var count := sprite.sprite_frames.get_frame_count(animation)
		if count > 0:
			sprite.animation = animation
			sprite.set_frame_and_progress(clampi(start, 0, count - 1), 0.0)
			return
	sprite.animation = animation
	var next_count := sprite.sprite_frames.get_frame_count(animation)
	var next_frame := phase * float(next_count)
	sprite.set_frame_and_progress(mini(floori(next_frame), next_count - 1), fposmod(next_frame, 1.0))
