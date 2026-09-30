# ShotRunner.gd —— 界面截图工具（窗口模式运行，非 headless）
# 用法：godot --path . res://tools/ShotRunner.tscn -- --scene=title [--frames=45] [--theme=castle] [--out=<png>]
# 输出：user://shots/<scene>.png
extends Node

var _scene := "title"
var _frames := 45
var _theme := "forest"
var _output := ""
var _role := "zs"
var _direction := "down"


func _ready() -> void:
	# 截图工具绝不能碰真实存档：_demo_prog()/ensure_starter_equip() 会就地改写 G.prog 并落盘，
	# 直接把玩家的 prog 换成演示档。与 PreviewMainWorld 同一做法，重定向到 tools/_logs/。
	G.SAVE_PATH = "res://tools/_logs/save_shot_runner.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			_scene = a.trim_prefix("--scene=")
		elif a.begins_with("--frames="):
			_frames = int(a.trim_prefix("--frames="))
		elif a.begins_with("--theme="):
			_theme = a.trim_prefix("--theme=")
		elif a.begins_with("--out="):
			_output = a.trim_prefix("--out=")
		elif a.begins_with("--role="):
			_role = a.trim_prefix("--role=")
		elif a.begins_with("--direction="):
			_direction = a.trim_prefix("--direction=")
	await _setup()
	for i in _frames:
		await get_tree().process_frame
	if _output == "":
		DirAccess.make_dir_recursive_absolute("user://shots")
		_output = "user://shots/%s.png" % _scene
	else:
		DirAccess.make_dir_recursive_absolute(_output.get_base_dir())
	var img := get_viewport().get_texture().get_image()
	var save_err := img.save_png(_output)
	if save_err != OK:
		push_error("SHOT_SAVE_FAILED %s (%d)" % [_output, save_err])
	else:
		print("SHOT_SAVED ", _output)
	get_tree().quit()


func _demo_prog() -> void:
	G.prog = {"level": 12, "exp": 340, "worlds_unlocked": 3,
		"world_cleared": {"forest": true, "snow": true}, "pets": [],
		"main_world": {"map_id": "lorin_wilds"}}
	G.collect_pet("pet_rockturtle")
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
	# P04：装备是实例；先发 6 件基础装再逐件加点，截图才有内容
	G.ensure_starter_equip(true)
	G.equip_state("sword")["lv"] = 3
	G.equip_state("sword")["gems"] = ["gem_atk_3"]
	G.equip_state("sword")["affixes"] = [{"stat": "atk_pct", "v": 0.05, "locked": false}]
	G.equip_state("armor")["lv"] = 2
	G.equip_state("accessory")["lv"] = 1
	G.equip_state("accessory")["gems"] = ["gem_hp_2"]
	G.prog["skills"] = {"zs_lieshan": 3}
	G.prog["mounts"] = {"owned": {"horse": 1}, "active": "horse"}
	G.prog["titles"] = {"owned": ["t_rookie"], "active": "t_rookie"}
	G.prog["pet_stat"] = {"pet_rockturtle": {"lv": 5, "exp": 40, "star": 4, "brk": 1}}
	G.items = {"enhance_stone": 12, "refine_stone": 6, "lock_rune": 3,
		"pet_food": 4, "break_crystal": 18, "aptitude_fruit": 1,
		"gem_atk_3": 1, "gem_hp_2": 1, "gem_def_1": 2}


## P05-C 首领战演示档：进断碑坡 → 接触失路兽开战 → 交回 MapScene（_battle 已就绪）
func _beast_battle() -> MapScene:
	G.SAVE_PATH = "res://tools/_logs/save_shot_main_world.json"
	_demo_prog()
	G.account = "演示账号"
	G.player_name = "角色昵称"
	G.side_accept("a1_elite_beast")
	var r := _make_run()
	r.level = int(G.prog.get("level", r.level))
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "broken_slope",
		"node": {"type": "normal", "layer": 0, "index": 0}, "run": r}
	var world: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	var beast = null
	for m in world._monsters:
		if m.mon_id == "mon_lost_beast":
			beast = m
	if beast == null:
		push_error("SHOT_SETUP_FAILED 断碑坡没有失路兽刷点")
		return null
	world._start_battle(beast)
	# 开战即冻结（speed=0 让 cur_speed() 归零，_process 不再累积 tick）。实测开战瞬间
	# tick=0、前摇队列为空——冻结后 AI 不会起手，后面手动入队/召唤都拍得到。
	if world._battle != null:
		world._battle.speed = 0.0
	await get_tree().process_frame
	return world


## 按怪物表 id 找战斗单位（失路兽 / 影狼）
func _beast_unit(battle: BattleScene, mon_id: String) -> Combatant:
	for u in battle.sim.units:
		if u.side == "enemy" and String(u.data.get("id", "")) == mon_id:
			return u
	return null


func _setup() -> void:
	match _scene:
		"load":
			add_child(load("res://src/ui/LoadScreen.tscn").instantiate())
		"title":
			add_child(load("res://src/ui/Title.tscn").instantiate())
		"title_settings":
			# 标题页 → 游戏设置（验证外置设置入口不再是「开发中」）
			var ts: Node = load("res://src/ui/Title.tscn").instantiate()
			add_child(ts)
			ts.call("_open_settings")
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
		"avatar":
			_demo_prog()
			G.selected_role = "zs"
			G.player_name = "演示旅人"
			var hav: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hav)
			hav.call("_open_avatar_panel")
		"deploy":
			_demo_prog()
			G.prog["tips_seen"] = {"deploy": true}   # 压掉首次引导弹层，截图看版式
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
			G.prog["tips_seen"] = {"deploy": true}
			var hd: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hd)
			var ed := InputEventMouseButton.new()
			ed.pressed = true
			ed.button_index = MOUSE_BUTTON_LEFT
			hd.call("_on_expedition", ed)
			hd.get("_deploy").call("_goto_step", 1 if _scene == "deploy_role" else 2)
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
		"main_world", "mentor_world", "main_world_battle", "main_world_battle_commands", "main_world_battle_skills", "main_world_battle_projectile", "main_world_pet_guard":
			G.SAVE_PATH = "res://tools/_logs/save_shot_main_world.json"
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			var world_run := _make_run()
			world_run.level = int(G.prog.get("level", world_run.level))
			MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds",
				"node": {"type": "normal", "layer": 0, "index": 0}, "run": world_run}
			var world: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
			add_child(world)
			if _scene == "mentor_world":
				world._player.position = Vector2(480, 710)
			if _scene in ["main_world_battle", "main_world_battle_commands", "main_world_battle_skills",
				"main_world_battle_projectile", "main_world_pet_guard"]:
				await get_tree().process_frame
				world._start_battle(world._monsters[0])
				if _scene == "main_world_battle_projectile" and world._battle != null:
					world._battle.speed = 0.0
					var role := world._battle.sim.role_unit()
					var targets := world._battle.sim.alive_units("enemy")
					if role != null and not targets.is_empty():
						role.attack_range = "range"
						var target: Combatant = targets[0]
						var amount := mini(18, maxi(target.hp - 1, 1))
						target.hp -= amount
						world._battle._on_event({"t": "basic", "src": role.uid, "uid": target.uid})
						world._battle._on_event({"t": "dmg", "src": role.uid, "uid": target.uid,
							"amount": amount, "crit": false, "dot": false})
						world._battle._sync_views()
				elif _scene == "main_world_battle_skills" and world._battle != null:
					world._battle._show_command_skills()
				elif _scene == "main_world_pet_guard" and world._battle != null:
					world._battle.speed = 0.0
					var turtle: Combatant = null
					for unit_v in world._battle.sim.units:
						var unit := unit_v as Combatant
						if unit.kind == "pet" and String(unit.data.get("id", "")) == "pet_rockturtle":
							turtle = unit
					if turtle != null:
						for skill_v in turtle.skills:
							var pet_skill := skill_v as Dictionary
							if String(pet_skill.get("id", "")) == "pw_shellguard":
								var guard_def := pet_skill.get("def", {}) as Dictionary
								# 截图在战斗启动后手动定格；清掉启动帧 AI 排队的冲撞，
								# 否则 can_cast 会因同一宠物正在前摇而拒绝护主甲结算。
								world._battle.sim.cast_queue.clear()
								world._battle.sim.events.clear()
								SkillSystem.enqueue_cast(world._battle.sim, turtle, guard_def)
								world._battle.sim.cast_queue.clear()
								SkillSystem.resolve_cast(world._battle.sim,
									{"uid": turtle.uid, "skill": guard_def})
								world._battle._consume_events()
								break
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
		"battle_cast":
			# 施法瞬间：满能量开局，0.25s 后强点「回风斩」——截图抓蓄力架势 + 技能图标闪现
			BattleScene.pending_cfg = {
				"ally": {
					"role_id": "zs", "level": 5, "traits": [],
					"active_pet": "pet_rockturtle", "bench_pet": "pet_thunderhawk",
					"potions": 2, "hp_override": -1,
				},
				"enemy": {"theme": "forest", "node_type": "normal", "layer": 1},
				"seed": 7,
			}
			var bc: Node = load("res://src/battle/BattleScene.tscn").instantiate()
			add_child(bc)
			get_tree().create_timer(0.25).timeout.connect(func():
				var role = bc.sim.role_unit()
				if role != null:
					role.energy = 100
					bc.call("_try_cast", "zs_huifeng"))
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
		"city_repair":
			_demo_prog()
			G.prog["story"] = {"step": "s11", "done": [], "goals": {}}
			G.items["stele_fragment"] = 1
			G.items["refine_stone"] = 2
			var cr: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(cr)
			cr.call("_open_repair_panel")
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
		"city_all":
			# 八座建筑全落成，镜头拉到城中央俯看：一张图核对 8 张贴图的尺寸/接地/木牌位置
			_demo_prog()
			G.wallet["gold"] = 999999
			G.wallet["soul"] = 9999
			G.wallet["expedition"] = 9999
			G.prog["level"] = 20
			for bid in ["archive", "kennel", "barracks", "storehouse", "shrine", "forge"]:
				G.build(bid)
			var ca: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(ca)
			ca._player.position = Vector2(576, 480)  # 城中央：四周建筑都进画
		"city_mix":
			# 落成 vs 工地同框：核对贴图建筑与程序绘制的空地不会看起来像两种游戏
			_demo_prog()
			G.wallet["gold"] = 99999
			G.build("archive")
			var cm: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(cm)
			# 图志阁（已落成，左）与演武场（工地，右下）之间的空地
			cm._player.position = Vector2(360, 400)
		"quests":
			# 演示档：今日牌固定成"一条可交付 + 一条进行中"，截图才看得出两种状态
			_demo_prog()
			G.quest = {"day": G.today_key(), "offer": ["q_slay_forest", "q_deliver_food"],
				"active": {"q_slay_forest": 3, "q_deliver_food": 0}, "claimed": []}
			G.items["pet_food"] = 0
			var cq: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(cq)
			cq.call("_open_quests")
		"city_deploy":
			_demo_prog()
			var cc: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(cc)
			cc.call("_open_deploy")
		"side_world_chime", "side_world_tracks":
			# P05-B 支线纵切（野外）：支线实体 + HUD 蓝签 + 小地图蓝菱同框
			G.SAVE_PATH = "res://tools/_logs/save_shot_main_world.json"
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			var is_chime := _scene == "side_world_chime"
			G.side_accept("a1_rel_child" if is_chime else "a1_eco_tracks")
			var side_run := _make_run()
			side_run.level = int(G.prog.get("level", side_run.level))
			MapScene.pending_cfg = {"mode": "main_world",
				"main_map_id": "maple_road" if is_chime else "broken_slope",
				"node": {"type": "normal", "layer": 0, "index": 0}, "run": side_run}
			var side_world: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
			add_child(side_world)
			await get_tree().process_frame
			# 站位离实体 60~90px：进画但不触发采集（INTERACT_R=44），且远离怪物接触半径（40+漂移48）
			side_world._player.position = Vector2(395, 700) if is_chime else Vector2(620, 545)
		"side_city_accept":
			# P05-B：城内 NPC 接取支线（台词优先级 + 接取 toast）
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			var side_city: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(side_city)
			await get_tree().process_frame
			side_city._player.position = Vector2(720, 700)
			side_city.call("_open_dialog", G.city_npc("npc_child"), false)
		"waystone_world":
			# P05-D 固定奇遇：站在触发圈外，让旧路石匣与旧风铃同屏。
			G.SAVE_PATH = "res://tools/_logs/save_shot_main_world.json"
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			G.side_accept("a1_rel_child")
			var cache_run := _make_run()
			cache_run.level = int(G.prog.get("level", cache_run.level))
			MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "maple_road",
				"node": {"type": "normal", "layer": 0, "index": 0}, "run": cache_run}
			var cache_world: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
			add_child(cache_world)
			await get_tree().process_frame
			cache_world._player.position = Vector2(505, 725)
		"beast_world":
			# P05-C：断碑坡路西的失路兽明雷——紫色首领名签 + 追踪支线蓝签 + 小地图蓝菱
			G.SAVE_PATH = "res://tools/_logs/save_shot_main_world.json"
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			G.side_accept("a1_elite_beast")
			var bw_run := _make_run()
			bw_run.level = int(G.prog.get("level", bw_run.level))
			MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "broken_slope",
				"node": {"type": "normal", "layer": 0, "index": 0}, "run": bw_run}
			var bw: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
			add_child(bw)
			await get_tree().process_frame
			# 站位距巢穴 ~211px：首领进画，但不触发 180px 观察上报，也不进 56px 接触圈
			bw._player.position = Vector2(250, 1060)
		"beast_windup":
			# P05-C 机制①：失路兽「嗅踪」2 秒预兆——首领脚下重环 + 前排目标环 + 逐帧倒数字幕
			var w1: MapScene = await _beast_battle()
			if w1 != null and w1._battle != null:
				var b1 := w1._battle
				b1.speed = 0.0   # 冻结 tick：环与字幕照常逐帧画，但这一招不会真的落地
				var boss1 := _beast_unit(b1, "mon_lost_beast")
				if boss1 != null and not boss1.skills.is_empty():
					SkillSystem.enqueue_cast(b1.sim, boss1, boss1.skills[0].def)
					b1._consume_events()
					for q in b1.sim.cast_queue:
						if int(q.get("uid", -1)) == boss1.uid:
							q["windup"] = 36   # 前摇推进到 1.2s：收缩环收了一半，字幕在倒数
		"beast_break":
			# P05-C 机制②：迷路低吼召影狼 → 影狼先死 → 首领 4 秒破绽（「绽」飘字 + 横幅）
			var w2: MapScene = await _beast_battle()
			if w2 != null and w2._battle != null:
				var b2 := w2._battle
				b2.speed = 0.0
				var boss2 := _beast_unit(b2, "mon_lost_beast")
				if boss2 != null:
					# ① 掉到 40%：走真实阶段路径（低吼横幅 + 解锁召唤技）
					boss2.hp = maxi(1, int(float(boss2.get_max_hp()) * 0.4))
					b2.sim._apply_phases()
					b2._consume_events()
					await get_tree().create_timer(2.1).timeout   # 等低吼横幅自己淡完，两张横幅不叠
					# ② 表驱动召唤影狼
					for s in boss2.skills:
						if String(s.def.get("id", "")) == "boss_roar_summon":
							SkillSystem.resolve_cast(b2.sim, {"uid": boss2.uid, "skill": s.def})
							break
					b2._consume_events()
					await get_tree().create_timer(0.3).timeout
					# ③ 影狼先死：黑雾散开 + 首领拿到 break_window（「绽」飘字走 buff 事件）
					var wolf := _beast_unit(b2, "mon_shadow_wolf")
					if wolf != null:
						wolf.take_damage(99999, boss2, b2.sim)
						b2._consume_events()
		"beast_notice":
			# P05-C：城内布告栏「路西兽影」——首胜世界旗生效后的一行
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			G.prog["flags"] = {"act1_lost_beast_down": true}
			var bn: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(bn)
			await get_tree().process_frame
			bn.call("_show_notice")
		"mentor_choice":
			# P05-D1：第二技能已在野外产生真实效果，回城选择第一条行为分支。
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			G.selected_role = "zs"
			G.prog["story"] = {"step": "s04", "done": ["s01", "s02", "s03"],
				"goals": {"s01": "done", "s02": "done", "s03": "done"}}
			G.prog["act1"] = {"mentor": {"unlocked": ["zs_pozhen"],
				"mastery": {"zs_pozhen": 1}, "variants": {}}}
			var mc: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(mc)
			await get_tree().process_frame
			mc.call("_open_mentor_panel")
		"order_preview":
			# P06：驿亭送盐后，驿商打开可操作的现货／运单市集。
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			G.prog["act1"] = {"side_quests": {"a1_trade_cart": {"status": "done"}},
				"repair_method": "forge", "discoveries": ["order_preview"]}
			var order_city: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(order_city)
			await get_tree().process_frame
			order_city.call("_open_first_order_preview")
		"trade_warden_dialog":
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			var warden_city: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(warden_city)
			await get_tree().process_frame
			warden_city.call("_open_dialog", G.city_npc("npc_warden"), false)
		"third_route", "third_post", "third_post_south", "third_mine", "third_dialog", "third_regions", "third_items":
			G.SAVE_PATH = "res://tools/_logs/save_shot_third_act.json"
			_demo_prog()
			G.player_name = "双关行者"
			G.selected_role = "zs"
			var third_done: Array = []
			for i in range(1, 23): third_done.append("s%02d" % i)
			if _scene in ["third_mine", "third_regions", "third_items"]: third_done.append("s23")
			G.prog["story"] = {"step": "s24" if third_done.has("s23") else "s23", "done": third_done, "goals": {}}
			G.items["frost_letter"] = 1
			G.items["mine_record"] = 1
			var third_map := "frost_post"
			if _scene == "third_route": third_map = "red_sand_route"
			if _scene == "third_mine": third_map = "rift_mine_road"
			G.prog["main_world"] = {"map_id": third_map}
			if _scene == "third_regions":
				add_child(RegionMapPanel.new())
			elif _scene == "third_items":
				var bag := BagPanel.new()
				bag._tab = "mat"
				add_child(bag)
			else:
				MapScene.pending_cfg = {"mode": "main_world", "main_map_id": third_map,
					"node": {"type": "normal", "layer": 0, "index": 0}, "run": _make_run()}
				var third_world: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
				add_child(third_world)
				third_world._player.position = Vector2(480, 575)
				if _scene in ["third_post", "third_dialog"]: third_world._player.position = Vector2(425, 520)
				if _scene == "third_post_south": third_world._player.position = Vector2(480, 930)
				if _scene == "third_dialog": third_world._city_content._open_dialog(G.city_npc("npc_frost_envoy"), false)
		"second_salt", "second_port", "second_port_south", "second_hatch", "second_relation", "second_shipping", "second_fishing", "second_tideflat", "second_gate", "second_gate_battle", "second_gate_windup", "second_gate_ebb", "second_crab_battle", "second_side_rope", "second_side_choice", "second_side_grass", "second_side_courier", "second_side_repaired":
			G.SAVE_PATH = "res://tools/_logs/save_shot_second_act.json"
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "盐路行者"
			G.selected_role = "zs"
			var preview_step := "s15"
			if _scene in ["second_port", "second_port_south"]: preview_step = "s16"
			if _scene in ["second_hatch", "second_relation", "second_shipping", "second_fishing"]: preview_step = "s17"
			if _scene.begins_with("second_side_"): preview_step = "s17"
			if _scene == "second_relation": preview_step = "s21"
			if _scene in ["second_tideflat", "second_crab_battle"]: preview_step = "s17"
			if _scene in ["second_gate", "second_gate_battle", "second_gate_windup", "second_gate_ebb"]: preview_step = "s19"
			var preview_done := ["s12", "s13", "s14"]
			if preview_step != "s15": preview_done.append("s15")
			if preview_step in ["s17", "s19"]: preview_done.append("s16")
			if preview_step == "s19":
				preview_done.append_array(["s17", "s18"])
				G.items["gate_clue"] = 1
			if preview_step == "s21": preview_done.append_array(["s16", "s17", "s18", "s19", "s20"])
			G.prog["story"] = {"step": preview_step, "done": preview_done, "goals": {}}
			if _scene in ["second_side_rope", "second_side_choice", "second_side_repaired"]:
				G.side_accept("a2_rel_rope")
				if _scene != "second_side_rope": G.side_entity_interact("observe", "a2_loose_rope", "shenyuan_port", "a2_rel_rope")
				if _scene == "second_side_repaired": G._side_complete("a2_rel_rope", true, "replace")
			if _scene == "second_side_grass": G.side_accept("a2_eco_grass")
			if _scene == "second_side_courier": G.side_accept("a2_trade_message")
			var second_run := _make_run()
			second_run.level = int(G.prog.get("level", second_run.level))
			var preview_map := "shenyuan_port"
			if _scene == "second_salt": preview_map = "old_salt_road"
			if _scene == "second_side_courier": preview_map = "old_salt_road"
			if _scene == "second_side_grass": preview_map = "tideflat"
			if _scene in ["second_tideflat", "second_crab_battle"]: preview_map = "tideflat"
			if _scene in ["second_gate", "second_gate_battle", "second_gate_windup", "second_gate_ebb"]: preview_map = "tidal_gate"
			MapScene.pending_cfg = {"mode": "main_world", "main_map_id": preview_map,
				"node": {"type": "normal", "layer": 0, "index": 0}, "run": second_run}
			var second_world: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
			add_child(second_world)
			second_world._player.position = Vector2(480, 700 if _scene == "second_tideflat" else 620)
			if _scene == "second_port_south": second_world._player.position = Vector2(480, 1000)
			if _scene in ["second_side_rope", "second_side_repaired"]: second_world._player.position = Vector2(480, 720)
			if _scene == "second_side_courier": second_world._player.position = Vector2(480, 860)
			if _scene == "second_side_grass": second_world._player.position = Vector2(480, 380)
			if _scene == "second_side_choice": second_world._city_content._open_dialog(G.city_npc("npc_port_worker"), false)
			if _scene == "second_hatch" and second_world._city_content != null:
				second_world._city_content._built_action("hatch")
			if _scene == "second_relation" and second_world._city_content != null:
				second_world._city_content._open_port_relation()
			if _scene == "second_shipping" and second_world._city_content != null:
				second_world._city_content._built_action("shipping")
			if _scene == "second_fishing":
				for ent in second_world._quest_entities:
					if ent.eid == "fish_port_pier":
						second_world.on_quest_entity(ent)
						second_world._fishing_panel._act()
			if _scene in ["second_gate_battle", "second_gate_windup", "second_gate_ebb", "second_crab_battle"]:
				await get_tree().process_frame
				second_world._start_battle(second_world._monsters[1] if _scene == "second_crab_battle" else second_world._monsters[0])
				if second_world._battle != null:
					second_world._battle.speed = 0.0
					var bs := second_world._battle
					for unit in bs.sim.units:
						if String(unit.data.get("id", "")) != "mon_tide_priest": continue
						if _scene == "second_gate_windup":
							SkillSystem.enqueue_cast(bs.sim, unit, (unit.skills[0] as Dictionary).get("def", {}))
							bs._consume_events()
							for q in bs.sim.cast_queue:
								if int(q.get("uid", -1)) == unit.uid: q["windup"] = 42
						if _scene == "second_gate_ebb":
							unit.hp = int(float(unit.get_max_hp()) * 0.20)
							bs.sim.step()
							bs._consume_events()
		"trade_slope_world", "trade_slope_panel":
			G.SAVE_PATH = "res://tools/_logs/save_shot_main_world.json"
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			var trade_run := _make_run()
			trade_run.level = int(G.prog.get("level", trade_run.level))
			MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "broken_slope",
				"node": {"type": "normal", "layer": 0, "index": 0}, "run": trade_run}
			var trade_world: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
			add_child(trade_world)
			await get_tree().process_frame
			trade_world._player.position = Vector2(475, 1030)
			if _scene == "trade_slope_panel":
				trade_world._open_trade_panel("slope_camp")
		"mount_claim":
			# P05-D4：s06 后从马伯手里领取第一匹坐骑。
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			G.selected_role = "zs"
			G.prog["mounts"] = {"owned": {}, "active": ""}
			G.prog["story"] = {"step": "s07", "done": ["s01", "s02", "s03", "s04", "s05", "s06"],
				"goals": {}}
			var stable_city: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(stable_city)
			await get_tree().process_frame
			stable_city.call("_open_first_mount_panel")
		"mount_world":
			# P05-D4：实地查看四职业四向骑姿、脚点、名签与骑乘按钮。
			G.SAVE_PATH = "res://tools/_logs/save_shot_main_world.json"
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			G.selected_role = _role
			G.prog["mounts"] = {"owned": {"horse": 1}, "active": "horse", "riding": true}
			var mount_run := RunState.new()
			mount_run.setup({"theme": _theme, "role_id": _role,
				"level": int(G.prog.get("level", 12)), "active_pet": "pet_rockturtle",
				"bench_pet": "", "potions": 2, "seed": 7})
			MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds",
				"node": {"type": "normal", "layer": 0, "index": 0}, "run": mount_run}
			var mount_world: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
			add_child(mount_world)
			await get_tree().process_frame
			mount_world._player.position = Vector2(480, 930)
			if _direction in ["down", "left", "right", "up"]:
				mount_world._mount_anim.animation = StringName("walk_" + _direction)
		"act1_blue_weapon":
			# P05-D：四职业实装失路兽首胜蓝武器，拍真实主世界节点。
			var blue_by_role := {"zs": "tpl_sword_ruin", "ck": "tpl_spear_iron",
				"fs": "tpl_staff_frost", "fz": "tpl_hammer_dawn"}
			if not blue_by_role.has(_role):
				push_error("SHOT_SETUP_FAILED 未知职业 %s" % _role)
				return
			G.SAVE_PATH = "res://tools/_logs/save_shot_main_world.json"
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			G.selected_role = _role
			G.ensure_starter_equip(true)
			var blue_tpl := String(blue_by_role[_role])
			G.inv_grant_equip({"tpl": blue_tpl, "rarity": 3, "n": 1}, false)
			for item_v in G.inv_instances():
				var item := item_v as Dictionary
				if String(item.get("tpl", "")) == blue_tpl:
					G.inv_equip(int(item.get("uid", 0)))
					break
			var blue_run := RunState.new()
			blue_run.setup({"theme": _theme, "role_id": _role, "level": 12,
				"active_pet": "", "bench_pet": "", "potions": 2, "seed": 7})
			MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "lorin_wilds",
				"node": {"type": "normal", "layer": 0, "index": 0}, "run": blue_run}
			var blue_world: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
			add_child(blue_world)
			await get_tree().process_frame
			blue_world._player.position = Vector2(480, 1000)
		"chapter_archive":
			# P05-D 章末：图志阁从修碑后的世界旗读取旧碑名与修法。
			_demo_prog()
			G.prog["flags"] = {"act1_stele_repaired": true}
			G.prog["act1"] = {"repair_method": "forge"}
			add_child(RegionMapPanel.new())
		"chapter_gate":
			# P05-D 章末：断碑坡北口路牌从灰石改为暖金并标新碑名。
			G.SAVE_PATH = "res://tools/_logs/save_shot_main_world.json"
			_demo_prog()
			G.prog["flags"] = {"act1_stele_repaired": true}
			G.prog["act1"] = {"repair_method": "forge"}
			G.prog["story"] = {"step": "s12", "done": ["s01", "s02", "s03", "s04",
				"s05", "s06", "s07", "s08", "s09", "s10", "s11"], "goals": {}}
			G.prog["main_world"] = {"map_id": "broken_slope", "layout_version": 2}
			var gate_run := _make_run()
			MapScene.pending_cfg = {"mode": "main_world", "main_map_id": "broken_slope",
				"node": {"type": "normal", "layer": 0, "index": 0}, "run": gate_run}
			var gate_map: MapScene = load("res://src/explore/MapScene.tscn").instantiate()
			add_child(gate_map)
			await get_tree().process_frame
			gate_map._player.position = Vector2(480, 410)
		"pet_claim":
			# P05-D2：第四步主线结束后，阿豆在兽栏让玩家主动确认结缘。
			_demo_prog()
			G.account = "演示账号"
			G.player_name = "角色昵称"
			G.prog["pets"] = []
			G.prog["flags"] = {}
			G.prog["story"] = {"step": "s05", "done": ["s01", "s02", "s03", "s04"],
				"goals": {"s01": "done", "s02": "done", "s03": "done", "s04": "done"}}
			var pc: Node = load("res://src/city/CityScene.tscn").instantiate()
			add_child(pc)
			await get_tree().process_frame
			pc.call("_open_rockturtle_panel")
		"story_intro":
			# 首领战前对峙（instant：一次铺满，截图不用等逐行动画）
			_demo_prog()
			var sb: Control = (load("res://src/ui/StoryBeat.tscn") as PackedScene).instantiate()
			sb.set("instant", true)
			sb.call("setup", "forest", "intro")
			add_child(sb)
		"story_outro":
			# 战后余韵（换一片大陆，展示 outro 的另一种色调）
			_demo_prog()
			var so: Control = (load("res://src/ui/StoryBeat.tscn") as PackedScene).instantiate()
			so.set("instant", true)
			so.call("setup", "tomb", "outro")
			add_child(so)
		"arena":
			# 演武场面板
			_demo_prog()
			var ha: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(ha)
			ha.call("_open_arena")
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
		"settings", "settings2":
			_demo_prog()
			var hs: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hs)
			var es := InputEventMouseButton.new()
			es.pressed = true
			es.button_index = MOUSE_BUTTON_LEFT
			hs.call("_open_settings", es)
			if _scene == "settings2":   # 第二页（存档与系统）：翻页后再截
				await get_tree().process_frame
				var sp: Node = hs.get("_settings")
				if sp != null:
					(sp.get("_deck") as Node).call("go", 1, true)
		"growth":
			_growth_demo()
			var hgr: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hgr)
			hgr.call("_open_growth")
		"bag", "bag_full":
			# P04 背包浮层（页签/容量/列表/详情）：补几件掉落入包的实例，否则装备页只有空态
			_growth_demo()
			G.inv_grant_equip({"tpl": "tpl_sword_wolf", "rarity": 2, "n": 1})
			G.inv_grant_equip({"tpl": "tpl_armor_scale", "rarity": 2, "n": 1})
			G.inv_grant_equip({"tpl": "tpl_accessory_moon", "rarity": 3, "n": 1})
			if _scene == "bag_full":
				G.inv_grant_equip({"tpl": "tpl_sword_wolf", "rarity": 2, "n": 6})
			var hb: Node = load("res://src/ui/GameHome.tscn").instantiate()
			add_child(hb)
			hb.call("_open_bag")
			# 选中一件背包装备，让右侧详情（对比/操作按钮）也进画
			var bp: Node = hb.get("_bag")
			if bp != null:
				var worn_u: Dictionary = G.inv_worn_uids()
				for it in G.inv_instances():
					var dc := it as Dictionary
					if not worn_u.has(int(dc.get("uid", 0))):
						bp.set("_sel_uid", int(dc.get("uid", 0)))
						break
				bp.call("_refresh")
		"forge_enhance", "forge_gem", "forge_refine":
			_growth_demo()
			var forge := (load("res://src/ui/EquipPanel.gd") as GDScript).new() as Control
			add_child(forge)
			forge.set("_work_tab", _scene.trim_prefix("forge_"))
			forge.call("_refresh")
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
