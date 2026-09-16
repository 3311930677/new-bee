extends CharacterBody2D
## Foot origin (64,120); pixels/second drives both translation and gait playback.

var controlled := false
var movement_enabled := true
var speed := 60.0
var facing := "down"
var sprite := AnimatedSprite2D.new()


func configure(frames: SpriteFrames, speed_multiplier := 1.0) -> void:
	speed = 60.0 * speed_multiplier
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = Vector2(-64, -120)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.animation = &"walk_down"
	sprite.frame = 1
	add_child(sprite)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 12)
	collision.shape = shape
	collision.position = Vector2(0, -6)
	add_child(collision)


func _physics_process(delta: float) -> void:
	var axis := Vector2.ZERO
	if controlled and movement_enabled:
		axis = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = axis * speed
	var before := global_position
	move_and_slide()
	global_position.x = clampf(global_position.x, 48.0, 432.0)
	global_position.y = clampf(global_position.y, 230.0, 690.0)
	var actual_velocity := (global_position - before) / delta
	if actual_velocity.length() < 0.5:
		sprite.stop()
		sprite.frame = 1 # passing pose is the most neutral grounded stop frame
		return
	if absf(actual_velocity.x) > absf(actual_velocity.y):
		facing = "right" if actual_velocity.x > 0 else "left"
	else:
		facing = "down" if actual_velocity.y > 0 else "up"
	var animation := StringName("walk_" + facing)
	if sprite.animation != animation:
		sprite.animation = animation
		sprite.frame = 0
	# 4 key frames / 8 FPS = .5 seconds; playback follows actual speed.
	sprite.speed_scale = actual_velocity.length() / 60.0
	sprite.play(animation)
