# ShotRunner.gd —— 界面截图工具（窗口模式运行，非 headless）
# 用法：godot --path . res://tools/ShotRunner.tscn -- --scene=title [--frames=45]
# 输出：user://shots/<scene>.png
extends Node

var _scene := "title"
var _frames := 45


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			_scene = a.trim_prefix("--scene=")
		elif a.begins_with("--frames="):
			_frames = int(a.trim_prefix("--frames="))
	await _setup()
	for i in _frames:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://shots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shots/%s.png" % _scene)
	print("SHOT_SAVED ", _scene)
	get_tree().quit()


func _make_run() -> RunState:
	var st := RunState.new()
	st.setup({
		"theme": "forest", "role_id": "zs", "level": 5,
		"active_pet": "pet_rockturtle", "bench_pet": "pet_thunderhawk",
		"potions": 2, "seed": 7,
	})
	return st


func _setup() -> void:
	match _scene:
		"title":
			add_child(load("res://src/ui/Title.tscn").instantiate())
		"login":
			add_child(load("res://src/ui/Login.tscn").instantiate())
		"createrole":
			add_child(load("res://src/ui/CreateRole.tscn").instantiate())
		"home":
			add_child(load("res://src/ui/GameHome.tscn").instantiate())
		"route":
			RouteScene.pending_run = {
				"theme": "forest", "role_id": "zs", "level": 5,
				"active_pet": "pet_rockturtle", "bench_pet": "pet_thunderhawk",
				"potions": 2, "seed": 7,
			}
			add_child(load("res://src/run/RouteScene.tscn").instantiate())
		"map":
			MapScene.pending_cfg = {
				"node": {"type": "normal", "layer": 1, "index": 0}, "run": _make_run()}
			add_child(load("res://src/explore/MapScene.tscn").instantiate())
		"map_boss":
			MapScene.pending_cfg = {
				"node": {"type": "boss", "layer": 4, "index": 0}, "run": _make_run()}
			add_child(load("res://src/explore/MapScene.tscn").instantiate())
		"battle":
			BattleScene.pending_cfg = {
				"ally": {
					"role_id": "zs", "level": 5, "traits": [],
					"active_pet": "pet_rockturtle", "bench_pet": "pet_thunderhawk",
					"potions": 2, "hp_override": -1,
				},
				"enemy": {"theme": "forest", "node_type": "normal", "layer": 1},
				"seed": 7,
			}
			add_child(load("res://src/battle/BattleScene.tscn").instantiate())
		"picker":
			var p := TraitPicker.new()
			var rows: Array = []
			for t in TableCache.traits().slice(0, 3):
				rows.append(t)
			add_child(p)
			p.setup(rows)
		_:
			push_error("未知场景：" + _scene)
			get_tree().quit(1)
