extends Node
## Plays the installed Pojun assets in the real map with an isolated preview save.

const DIRS := ["down", "left", "right", "up"]
const LABELS := ["向下", "向左", "向右", "向上"]
const NEW_ART := "res://image/role/zs/pojun_walk_frames.tres"
const OLD_ART := "res://image/role_pixel_studio/zs/original/pojun_walk_frames.tres"
var world: MapScene
var original := false
var busy := false
var status := Label.new()

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_pixel_studio_preview.json"
	G.set_meta("ui_review_mode", true)
	G.selected_role = "zs"
	G.player_name = "破军"
	G.prog["level"] = 5
	G.prog["main_world"] = {"map_id": "lorin_wilds"}
	G.mount_set_riding(false, false)
	var run := RunState.new()
	run.setup({"theme": "forest", "role_id": "zs", "level": 5,
		"active_pet": "", "bench_pet": "", "potions": 2, "seed": 19})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	world = (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate()
	add_child(world)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(10, 202)
	panel.size = Vector2(460, 103)
	layer.add_child(panel)
	status.position = Vector2(12, 6)
	status.add_theme_font_size_override("font_size", 16)
	panel.add_child(status)
	for i in range(4):
		var button := Button.new()
		button.position = Vector2(12 + i * 110, 37)
		button.size = Vector2(103, 34)
		button.text = "%d %s" % [i + 1, LABELS[i]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_walk.bind(i))
		panel.add_child(button)
	var hint := Label.new()
	hint.position = Vector2(12, 78)
	hint.text = "方向键 / WASD 行走 · 空格切换原版对比"
	hint.add_theme_font_size_override("font_size", 13)
	panel.add_child(hint)
	_apply_art()
	for i in range(6):
		await get_tree().process_frame
	if "--verify-pixel" in OS.get_cmdline_user_args():
		await _verify()
	elif "--capture-pixel" in OS.get_cmdline_user_args():
		await _capture()
	else:
		print("PIXEL_INTERACTIVE_READY: installed Pojun four-direction walk; arrows/WASD; Space comparison.")

func _apply_art() -> void:
	var previous: StringName = world._player_anim.animation
	var phase := world._player_anim.frame
	world._player_anim.sprite_frames = load(OLD_ART if original else NEW_ART) as SpriteFrames
	var frames := world._player_anim.sprite_frames
	world._player_anim.animation = previous if frames.has_animation(previous) else &"walk_down"
	world._player_anim.frame = mini(phase, frames.get_frame_count(world._player_anim.animation) - 1)
	world._player_anim.stop()
	status.text = "破军 · %s四方向行走" % ("原版 " if original else "Pixel Art Studio ")
	if is_instance_valid(world._first_act_weapon):
		world._first_act_weapon.visible = false
	if is_instance_valid(world._player_weapon_spr):
		world._player_weapon_spr.visible = false

func _walk(index: int) -> void:
	if busy:
		return
	busy = true
	var action := StringName("move_" + DIRS[index])
	Input.action_press(action)
	await get_tree().create_timer(1.2).timeout
	Input.action_release(action)
	busy = false

func _unhandled_key_input(event: InputEvent) -> void:
	if busy or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		_walk(event.keycode - KEY_1)
	elif event.keycode == KEY_SPACE:
		original = not original
		_apply_art()

func _verify() -> void:
	var frames := world._player_anim.sprite_frames
	var count := 0
	for dir: String in DIRS:
		var anim := StringName("walk_" + dir)
		assert(frames.has_animation(anim))
		assert(frames.get_frame_count(anim) == 8)
		assert(absf(frames.get_animation_speed(anim) - 1000.0 / 110.0) < 0.01)
		for phase in range(8):
			var tex := frames.get_frame_texture(anim, phase) as AtlasTexture
			assert(tex != null and tex.region.size == Vector2(128, 128))
			assert(tex.atlas.get_size() == Vector2(1024, 512))
			count += 1
		var before := world._player.position
		Input.action_press(StringName("move_" + dir))
		for i in range(10):
			await get_tree().physics_frame
		Input.action_release(StringName("move_" + dir))
		assert(world._player.position.distance_to(before) > 1.0, "player did not move")
		assert(world._player_anim.animation == anim, "wrong facing animation")
		for i in range(2):
			await get_tree().physics_frame
		assert(not world._player_anim.is_playing(), "animation did not stop")
		print("PIXEL_DIRECTION_OK: ", dir)
	original = true
	_apply_art()
	assert(world._player_anim.sprite_frames.get_frame_count(&"walk_down") == 6)
	original = false
	_apply_art()
	assert(world._player_anim.sprite_frames.get_frame_count(&"walk_down") == 8)
	print("PIXEL_WORLD_VERIFY_OK: %d frames; moved and stopped in all four directions; original comparison works." % count)
	get_tree().quit(0)

func _capture() -> void:
	var folder := "res://image/role_pixel_studio/zs/review/world"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var captures: Array = []
	for dir: String in DIRS:
		for phase in range(8):
			world._player_anim.animation = StringName("walk_" + dir)
			world._player_anim.frame = phase
			await RenderingServer.frame_post_draw
			var screenshot := get_viewport().get_texture().get_image()
			var file := "%s/%s_%02d.png" % [folder, dir, phase]
			assert(screenshot.save_png(file) == OK)
			var center := world._player_anim.get_global_transform_with_canvas().origin
			captures.append({"direction": dir, "phase": phase, "file": file,
				"sprite_center": [center.x, center.y]})
	var meta := FileAccess.open(folder + "/captures.json", FileAccess.WRITE)
	meta.store_string(JSON.stringify(captures, "\t"))
	print("PIXEL_WORLD_CAPTURE_OK: real MapScene, four directions, eight phases each.")
	get_tree().quit(0)
