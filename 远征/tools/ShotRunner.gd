# ShotRunner.gd —— 界面截图工具（窗口模式运行，非 headless）
# 用法：godot --path . res://tools/ShotRunner.tscn -- --scene=title [--frames=45] [--theme=castle]
# 输出：user://shots/<scene>.png
extends Node

var _scene := "title"
var _frames := 45
var _theme := "forest"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			_scene = a.trim_prefix("--scene=")
		elif a.begins_with("--frames="):
			_frames = int(a.trim_prefix("--frames="))
		elif a.begins_with("--theme="):
			_theme = a.trim_prefix("--theme=")
	await _setup()
	for i in _frames:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://shots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shots/%s.png" % _scene)
	print("SHOT_SAVED ", _scene)
	get_tree().quit()


func _demo_prog() -> void:
	G.prog = {"level": 12, "exp": 340, "worlds_unlocked": 3,
		"world_cleared": {"forest": true, "snow": true}, "pets": []}
	G.ensure_starter_pets()
	G.collect_pet("pet_thunderhawk")
	G.collect_pet("pet_frostwolf")
	G.wallet = {"gold": 12800, "expedition": 240, "soul": 36, "honor": 900}


func _make_run() -> RunState:
	var st := RunState.new()
	st.setup({
		"theme": _theme, "role_id": "zs", "level": 5,
		"active_pet": "pet_rockturtle", "bench_pet": "pet_thunderhawk",
		"potions": 2, "seed": 7,
	})
	return st


## 养成线演示档：天赋/装备/技能/坐骑/称号/宠物各有一点进度，截图才有内容
func _growth_demo() -> void:
	_demo_prog()
	G.selected_role = "zs"
	G.prog["talents"] = {"fury_1": 1}
	G.prog["equip"] = {
		"sword": {"lv": 3, "gems": ["gem_atk_3"],
			"affixes": [{"stat": "atk_pct", "v": 0.05, "locked": false}]},
		"armor": {"lv": 2, "gems": [], "affixes": []},
		"accessory": {"lv": 1, "gems": ["gem_hp_2"], "affixes": []},
	}
	G.prog["skills"] = {"zs_lieshan": 3}
	G.prog["mounts"] = {"owned": {"horse": 1}, "active": "horse"}
	G.prog["titles"] = {"owned": ["t_rookie"], "active": "t_rookie"}
	G.prog["pet_stat"] = {"pet_rockturtle": {"lv": 5, "exp": 40, "star": 4, "brk": 1}}
	G.items = {"enhance_stone": 12, "refine_stone": 6, "lock_rune": 3,
		"pet_food": 4, "break_crystal": 18, "aptitude_fruit": 1,
		"gem_atk_3": 1, "gem_hp_2": 1, "gem_def_1": 2}


func _setup() -> void:
	match _scene:
		"load":
			add_child(load("res://src/ui/LoadScreen.tscn").instantiate())
		"title":
			add_child(load("res://src/ui/Title.tscn").instantiate())
		"login":
			add_child(load("res://src/ui/Login.tscn").instantiate())
		"prologue":
			_demo_prog()
			add_child(load("res://src/ui/Prologue.tscn").instantiate())
		"createrole":
			add_child(load("res://src/ui/CreateRole.tscn").instantiate())
		"home":
			_demo_prog()
			add_child(load("res://src/ui/GameHome.tscn").instantiate())
		"deploy":
			_demo_prog()
			var home: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(home)
			var ev := InputEventMouseButton.new()
			ev.pressed = true
			ev.button_index = MOUSE_BUTTON_LEFT
			home.call("_on_expedition", ev)
		"deploy_plain":
			# 压掉首次引导弹层，只为看清秘境卡版式（题记 + 状态两行是否放得下）
			_demo_prog()
			G.prog["tips_seen"] = {"deploy": true}
			var hp: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hp)
			var ep := InputEventMouseButton.new()
			ep.pressed = true
			ep.button_index = MOUSE_BUTTON_LEFT
			hp.call("_on_expedition", ep)
		"deploy_role", "deploy_pet":
			# 出征筹备的另两个页签（人物 / 宠物），方便逐页看图
			_demo_prog()
			var hd: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hd)
			var ed := InputEventMouseButton.new()
			ed.pressed = true
			ed.button_index = MOUSE_BUTTON_LEFT
			hd.call("_on_expedition", ed)
			hd.get("_deploy").call("_goto_step", 1 if _scene == "deploy_role" else 2)
			_demo_prog()
			var hw: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hw)
			var ew := InputEventMouseButton.new()
			ew.pressed = true
			ew.button_index = MOUSE_BUTTON_LEFT
			hw.call("_open_worlds", ew)
		"worlds":
			_demo_prog()
			var hw: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hw)
			var ew := InputEventMouseButton.new()
			ew.pressed = true
			ew.button_index = MOUSE_BUTTON_LEFT
			hw.call("_open_worlds", ew)
		"codex":
			_demo_prog()
			var hc: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hc)
			var ec := InputEventMouseButton.new()
			ec.pressed = true
			ec.button_index = MOUSE_BUTTON_LEFT
			hc.call("_open_codex", ec)
		"gm":
			G.gm_unlocked = false
			_demo_prog()
			add_child(load("res://src/ui/GameHome.tscn").instantiate())
			GmConsole.open()
		"gm_open":
			G.gm_unlocked = true
			_demo_prog()
			add_child(load("res://src/ui/GameHome.tscn").instantiate())
			GmConsole.open()
			GmConsole.call("_flash", "口令正确 · 开发者权限已开启")
		"route":
			RouteScene.pending_run = {
				"theme": _theme, "role_id": "zs", "level": 5,
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
		"battle_low":
			# 低血警示：hp_override 把角色压到 10% 左右，看边缘红晕与"危急"提示
			BattleScene.pending_cfg = {
				"ally": {
					"role_id": "zs", "level": 5, "traits": [],
					"active_pet": "pet_rockturtle", "bench_pet": "pet_thunderhawk",
					"potions": 2, "hp_override": 18,
				},
				"enemy": {"theme": "forest", "node_type": "boss", "layer": 3},
				"seed": 5,
			}
			add_child(load("res://src/battle/BattleScene.tscn").instantiate())
		"picker":
			var p := TraitPicker.new()
			var rows: Array = []
			for t in TableCache.traits().slice(0, 3):
				rows.append(t)
			add_child(p)
			p.setup(rows)
		"picker_school":
			# 专挑带流派的词条，验证 school_* 图标接线与尺寸
			var rows2: Array = []
			for t in TableCache.traits():
				if String((t as Dictionary).get("school", "none")) != "none":
					rows2.append(t)
				if rows2.size() >= 3:
					break
			var ps := TraitPicker.new()
			add_child(ps)
			ps.setup(rows2)
		"city":
			_demo_prog()
			add_child(load("res://src/city/CityScene.tscn").instantiate())
		"city_built":
			_demo_prog()
			G.wallet["gold"] = 99999
			G.wallet["soul"] = 999
			G.wallet["expedition"] = 999
			for bid in ["archive", "kennel", "barracks", "storehouse", "shrine"]:
				G.build(bid)
			var c: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(c)
			c._player.position = Vector2(576, 400)  # 镜头拉到议事厅门前看建筑群
		"city_deploy":
			_demo_prog()
			var cc: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(cc)
			cc.call("_open_deploy")
		"gacha":
			_demo_prog()
			var hg: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hg)
			hg.call("_open_gacha")
		"exchange":
			_demo_prog()
			var he: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(he)
			he.call("_open_exchange")
		"settings":
			_demo_prog()
			var hs: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hs)
			var es := InputEventMouseButton.new()
			es.pressed = true
			es.button_index = MOUSE_BUTTON_LEFT
			hs.call("_open_settings", es)
		"growth":
			_growth_demo()
			var hgr: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hgr)
			hgr.call("_open_growth")
		"talent", "equip", "pet_raise", "skillbook", "mount", "titles":
			_growth_demo()
			var h2: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(h2)
			h2.call("_open_growth")
			var sub_id := _scene.replace("pet_raise", "pet").replace("skillbook", "skill").replace("titles", "title")
			(h2.get("_growth") as Control).call("_open", sub_id)
		_:
			push_error("未知场景：" + _scene)
			get_tree().quit(1)
