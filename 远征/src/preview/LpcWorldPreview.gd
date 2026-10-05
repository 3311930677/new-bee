extends Node
## Trial in the actual world scene; saved progress is redirected to a preview file.

const IDS = ["zs", "ck", "fs", "fz"]
const SLUGS = ["pojun", "chuanyang", "shuangyu", "chenxing"]
const NAMES = ["破军", "穿杨", "霜语", "晨星"]
var world: MapScene
var selected := 0
var use_lpc := true
var busy := false
var status := Label.new()

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_lpc_preview.json"
	G.set_meta("ui_review_mode", true)
	G.prog["level"] = 5
	G.prog["main_world"] = {"map_id": "lorin_wilds"}
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(10, 202)
	panel.size = Vector2(460, 99)
	layer.add_child(panel)
	status.position = Vector2(12, 5)
	status.add_theme_font_size_override("font_size", 16)
	panel.add_child(status)
	for i in range(4):
		var button := Button.new()
		button.position = Vector2(12 + i * 110, 37)
		button.size = Vector2(103, 34)
		button.text = "%d %s" % [i + 1, NAMES[i]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select.bind(i))
		panel.add_child(button)
	var hint := Label.new()
	hint.position = Vector2(12, 74)
	hint.text = "方向键行走 · 数字1–4换人 · 空格对比原版"
	hint.add_theme_font_size_override("font_size", 13)
	panel.add_child(hint)
	await _build(0)
	if "--capture-lpc" in OS.get_cmdline_user_args():
		await _capture()
	elif "--verify-lpc" in OS.get_cmdline_user_args():
		await _verify()

func _select(index: int) -> void:
	if not busy:
		_build(index)

func _build(index: int) -> void:
	busy = true
	selected = index
	if is_instance_valid(world):
		world.queue_free()
		await get_tree().process_frame
	G.selected_role = IDS[index]
	G.player_name = NAMES[index]
	var run := RunState.new()
	run.setup({"theme": "forest", "role_id": IDS[index], "level": 5,
		"active_pet": "", "bench_pet": "", "potions": 2, "seed": 19})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds", "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	world = (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate()
	add_child(world)
	_apply_art()
	for i in range(6):
		await get_tree().process_frame
	busy = false

func _apply_art() -> void:
	var directory := "role_lpc" if use_lpc else "role"
	var path := "res://image/%s/%s/%s_walk_frames.tres" % [directory, IDS[selected], SLUGS[selected]]
	world._player_anim.sprite_frames = load(path) as SpriteFrames
	world._player_anim.animation = &"walk_down"
	world._player_anim.frame = 1
	world._player_anim.stop()
	status.text = "%s · %s行走试用" % [NAMES[selected], "Universal LPC " if use_lpc else "原版 "]
	# Selected LPC sheets already include the weapon; keep their silhouette readable.
	if is_instance_valid(world._first_act_weapon):
		world._first_act_weapon.visible = not use_lpc
	if is_instance_valid(world._player_weapon_spr):
		world._player_weapon_spr.visible = not use_lpc

func _unhandled_key_input(event: InputEvent) -> void:
	if busy or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_4:
		_select(event.keycode - KEY_1)
	elif event.keycode == KEY_SPACE:
		use_lpc = not use_lpc
		_apply_art()

func _capture() -> void:
	var folder := "res://image/role_lpc/review/world"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for role in range(4):
		await _build(role)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		for phase in range(8):
			world._player_anim.animation = &"walk_down"
			world._player_anim.frame = phase
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var err := image.save_png("%s/%s_%02d.png" % [folder, IDS[role], phase])
			assert(err == OK, "preview capture failed")
	print("LPC_WORLD_CAPTURE_OK: actual MapScene, four roles, eight phases each.")
	get_tree().quit(0)

func _verify() -> void:
	var count := 0
	for role in range(4):
		await _build(role)
		var frames := world._player_anim.sprite_frames
		for dir in ["down", "left", "right", "up"]:
			var anim := StringName("walk_" + dir)
			assert(frames.get_frame_count(anim) == 8)
			for phase in range(8):
				var tex := frames.get_frame_texture(anim, phase) as AtlasTexture
				assert(tex != null and tex.region.size == Vector2(128, 128))
				assert(tex.atlas.get_size() == Vector2(1152, 512))
				count += 1
			var before := world._player.position
			Input.action_press(StringName("move_" + dir))
			for i in range(10):
				await get_tree().physics_frame
			Input.action_release(StringName("move_" + dir))
			assert(world._player.position.distance_to(before) > 1.0, "role did not move")
			assert(world._player_anim.animation == anim, "wrong facing animation")
			for i in range(2):
				await get_tree().physics_frame
			assert(not world._player_anim.is_playing(), "walking continued after stopping")
	print("LPC_WORLD_VERIFY_OK: %d walk frames; all roles moved in four directions and stopped." % count)
	get_tree().quit(0)
