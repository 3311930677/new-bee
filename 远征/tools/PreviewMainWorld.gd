# 调试用：在无交互模式生成 480×800 主世界截图，供 UI/素材同屏检查。
# 用法（**必须窗口模式**，headless 没有 viewport 纹理，会 PREVIEW_FAIL）：
#   ... PreviewMainWorld.tscn -- <map_id>             无标注原图 → tools/_logs/preview_<map>.png
#   ... PreviewMainWorld.tscn -- <map_id> battle      战斗图     → tools/_logs/preview_<map>_battle.png
#   ... PreviewMainWorld.tscn -- <map_id> annotate    标注图     → shots/style_20260928/spec_0N_<map>.png
#   ... PreviewMainWorld.tscn -- <map_id> walk        新档实机行走至最远出口并截图 → shots/style_20260928/walk_<map>.png
#   ... PreviewMainWorld.tscn -- <map_id> equip_basic 基础武器（名签绿边、无手中武器） → shots/p04_20260928/equip_basic_<map>.png
#   ... PreviewMainWorld.tscn -- <map_id> equip_rare  稀有武器（名签蓝边 + 手中武器）   → shots/p04_20260928/equip_rare_<map>.png
extends Node

const SHOT_DIR := "res://shots/style_20260928"
## P04 可见换装对照图（默认基础武器 vs 稀有武器）
const SHOT_DIR_P04 := "res://shots/p04_20260928"

# 四图在标注图里的编号（与 style-spec §8 的 spec_0N 对应）
const SPEC_ORDER := ["lorin_wilds", "maple_road", "broken_slope", "stele_cavern"]

var _map: MapScene = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id := String(args[0]) if not args.is_empty() else "lorin_wilds"
	var mode := String(args[1]) if args.size() > 1 else ""
	G.SAVE_PATH = "res://tools/_logs/save_preview_world.json"
	G.selected_role = "zs"
	G.player_name = "试剑"
	G.prog["level"] = 5
	G.prog["exp"] = 20
	G.prog["main_world"] = {"map_id": map_id}
	var run := RunState.new()
	run.setup({"theme": "forest", "role_id": "zs", "level": 5,
		"active_pet": "pet_rockturtle", "bench_pet": "", "potions": 2, "seed": 19})
	MapScene.pending_cfg = {"mode": "main_world", "main_map_id": map_id, "run": run,
		"node": {"type": "normal", "layer": 0, "index": 0}}
	_map = (load("res://src/explore/MapScene.tscn") as PackedScene).instantiate()
	add_child(_map)
	for i in 5:
		await get_tree().process_frame

	var out_path := "res://tools/_logs/preview_%s" % map_id
	if mode == "battle":
		if not _map._monsters.is_empty():
			_map._start_battle(_map._monsters[0])
			for i in 8:
				await get_tree().process_frame
		out_path += "_battle"
	elif mode == "annotate":
		_add_annotation(map_id)
		out_path = "%s/spec_%02d_%s" % [SHOT_DIR, SPEC_ORDER.find(map_id) + 1, map_id]
	elif mode == "walk":
		var ok := await _walk_to_farthest_exit(map_id)
		if not ok:
			print("WALK_NOTE %s 未走到出口，截图仅供排查" % map_id)
		out_path = "%s/walk_%s" % [SHOT_DIR, map_id]
	elif mode == "equip_basic" or mode == "equip_rare":
		# P04 可见换装对照（验收链「穿上后地图上至少一处外观变化」）：
		# basic = 卸下武器（名签描边回落原绿、手中无武器）；rare = 换上稀有武器
		# （名签描边随稀有度变蓝 5aa0e0 + 手中出现武器图标）。两图除在身武器外完全同参，可直接对照。
		G.ensure_starter_equip(true)
		var wslot := G.equip_weapon_slot("zs")
		if mode == "equip_basic":
			G.inv_unequip(wslot)
		else:
			G.inv_grant_equip({"tpl": "tpl_sword_ruin", "rarity": 3, "n": 1})
			var ruid := 0
			for it in G.inv_instances():
				var dd := it as Dictionary
				if String(dd.get("tpl", "")) == "tpl_sword_ruin" and String(dd.get("slot", "")) == wslot:
					ruid = int(dd.get("uid", 0))
			if ruid > 0:
				G.inv_equip(ruid)
		_map.call("_refresh_player_appearance")
		print("EQUIP_APPEARANCE %s slot=%s %s" % [mode, wslot,
			JSON.stringify(G.equip_appearance())])
		for i in 4:
			await get_tree().process_frame
		out_path = "%s/equip_%s_%s" % [SHOT_DIR_P04, mode.trim_prefix("equip_"), map_id]

	for i in 2:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if image == null:
		print("PREVIEW_FAIL renderer has no viewport texture")
		get_tree().quit(1)
		return
	var abs_path := ProjectSettings.globalize_path(out_path + ".png")
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := image.save_png(abs_path)
	if err == OK:
		print("PREVIEW_OK " + abs_path)
	else:
		print("PREVIEW_FAIL %d %s" % [err, abs_path])
	get_tree().quit(0 if err == OK else 1)


# ================= 标注图 =================
func _add_annotation(map_id: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	var ov := _Annotate.new()
	ov.map_ref = _map
	ov.notes = _notes(map_id)
	if map_id == "lorin_wilds":
		ov.street = _street_metrics()
	layer.add_child(ov)


func _notes(_map_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("[红线=四周12px安全边距] zoom1.15 ⇒ 同屏 417×696px")
	var offs := PackedStringArray()
	for row_v in _map._main_cfg.get("exits", []):
		var row := row_v as Dictionary
		var at: Array = row.get("at", [])
		if at.size() < 2:
			continue
		var p := Vector2(float(at[0]), float(at[1]))
		var s := _map.get_viewport().get_canvas_transform() * p
		if s.x < 0.0 or s.x > 480.0 or s.y < 0.0 or s.y > 800.0:
			offs.append("%s(y=%.0f)" % [String(row.get("label", "")), p.y])
	if not offs.is_empty():
		out.append("屏外出口：%s —— 靠右上小地图绿菱指路" % ", ".join(offs))
	return out


## 主街净宽：主城左右两列建筑的**基座碰撞带**内缘间距。
## 碰撞盒口径取自 CityScene._Building.setup：`_w*0.80 × _h*0.30`。返回最窄那一行的左右内缘与净宽。
func _street_metrics() -> Dictionary:
	var city: Dictionary = G.city_config()
	var pos_map: Dictionary = _map._main_cfg.get("city_building_positions", {})
	var left: Array = []
	var right: Array = []
	var cx := float(int(_map._main_cfg.get("map_cols", 20)) * 48) * 0.5
	for row_v in city.get("buildings", []):
		var b := row_v as Dictionary
		var id := String(b.get("id", ""))
		if not pos_map.has(id):
			continue
		var p: Array = pos_map[id]
		var s: Array = b.get("size", [2.0, 2.0])
		var half := float(s[0]) * 48.0 * 0.80 * 0.5
		var bx := float(p[0])
		var by := float(p[1])
		if bx < cx:
			left.append({"x": bx + half, "y": by})
		else:
			right.append({"x": bx - half, "y": by})
	var best := {}
	for l in left:
		for r in right:
			# 同一排（y 相差不到一格）才算主街同侧对照
			if absf(float(l["y"]) - float(r["y"])) > 48.0:
				continue
			var w := float(r["x"]) - float(l["x"])
			if best.is_empty() or w < float(best["width"]):
				best = {"left": float(l["x"]), "right": float(r["x"]),
					"width": w, "y": float(l["y"])}
	return best


# ================= 新档实机行走 =================
## 用真输入动作（WASD 动作名）在真实碰撞下走完整条主路到最远出口，停在触发半径外，截图存证。
## 野外图按 `_ground_path`（本图主路格）逐行取最近格当路点，于是走的正是那条新铺的路带；
## 边城没有格子主路（整图底图），直接沿主街直线北上。
func _walk_to_farthest_exit(map_id: String) -> bool:
	var target := Vector2.ZERO
	var best := -1.0
	for row_v in _map._main_cfg.get("exits", []):
		var row := row_v as Dictionary
		var at: Array = row.get("at", [])
		if at.size() < 2:
			continue
		var p := Vector2(float(at[0]), float(at[1]))
		var d := p.distance_to(_map._player.position)
		if d > best:
			best = d
			target = p
	if best < 0.0:
		print("WALK_FAIL %s 无出口配置" % map_id)
		return false
	var route := _road_waypoints(target)
	route.append(target)
	const STOP := 62.0     # 出口触发半径 38，停在 62 外，避免真的切图
	const ARRIVE := 30.0
	print("WALK_START %s from=%s to=%s dist=%.0f waypoints=%d" % [map_id,
		_map._player.position, target, best, route.size()])
	var frames := 0
	var stuck_total := 0
	var wi := 0
	while wi < route.size() and frames < 4800:
		var wp: Vector2 = route[wi]
		var last_wp := wi == route.size() - 1
		var arrive := STOP if last_wp else ARRIVE
		var budget := 1200 if last_wp else 460
		var fp := 0
		var last := _map._player.position
		while fp < budget and frames < 4800 and _map._player.position.distance_to(wp) > arrive:
			# 可走性测试不测战斗：把怪冻在「接触中」状态，于是它们既不追人也不开战，
			# 半路不会弹出遭遇战浮层把移动逻辑冻住（战斗由 VerifyBattleScene / 战斗截图覆盖）。
			for m in _map._monsters:
				if not m.chasing_contact:
					m.chasing_contact = true
			_steer(wp)
			await get_tree().physics_frame
			frames += 1
			fp += 1
			if fp % 30 == 0:
				if _map._player.position.distance_to(last) < 5.0:
					# 被散件基座挡死：往侧向挪一小段再继续，模拟玩家绕树走
					stuck_total += 1
					await _nudge(wp, stuck_total % 2 == 0)
					last = _map._player.position
				else:
					last = _map._player.position
		wi += 1
	_release_all()
	var dist := _map._player.position.distance_to(target)
	# 判定只看「是否停在出口触发圈外沿」：途中偶发贴树让路（nudge）不算失败，抵达即通过。
	var ok := dist <= STOP + 16.0
	print("WALK_%s %s frames=%d dist=%.1f pos=%s stuck=%d" % ["OK" if ok else "FAIL",
		map_id, frames, dist, _map._player.position, stuck_total])
	return ok


## 本图主路格 → 由出生行朝出口行逐步推进的路点串（每行取离上一个路点最近的格心）。
## 只保留「出生行 ↔ 目标行」之间那一段，避免先绕到地图另一端再折回。
## 边城（city）没有格子主路，返回空数组，调用方退化成沿主街直线走向出口。
func _road_waypoints(target: Vector2) -> Array:
	var path: Dictionary = _map._ground_path
	if path.is_empty():
		return []
	var spawn_row := roundi(_map._player.position.y / 48.0)
	var target_row := roundi(target.y / 48.0)
	var up := target_row < spawn_row
	var rows := {}
	for c in path.keys():
		var cy: int = (c as Vector2i).y
		if not rows.has(cy):
			rows[cy] = []
		(rows[cy] as Array).append(c)
	var ys: Array = rows.keys()
	ys.sort()
	if not up:
		ys.reverse()
	var out: Array = []
	var last := Vector2i(roundi(_map._player.position.x / 48.0), spawn_row)
	for y in ys:
		if up and (int(y) > spawn_row or int(y) < target_row):
			continue
		if not up and (int(y) < spawn_row or int(y) > target_row):
			continue
		var best_cell: Vector2i = last
		var bd := 1.0e9
		for c in rows[y]:
			var cc := c as Vector2i
			var d := absf(float(cc.x - last.x)) + absf(float(cc.y - last.y))
			if d < bd:
				bd = d
				best_cell = cc
		out.append(Vector2(best_cell.x * 48.0 + 24.0, best_cell.y * 48.0 + 24.0))
		last = best_cell
	return out


func _nudge(target: Vector2, flip: bool) -> void:
	var d := (target - _map._player.position).normalized()
	var side := Vector2(-d.y, d.x) if not flip else Vector2(d.y, -d.x)
	_key("move_left", side.x < -0.4)
	_key("move_right", side.x > 0.4)
	_key("move_up", side.y < -0.4)
	_key("move_down", side.y > 0.4)
	for i in 26:
		await get_tree().physics_frame
	_release_all()


func _steer(target: Vector2) -> void:
	var d := target - _map._player.position
	_key("move_left", d.x < -6.0)
	_key("move_right", d.x > 6.0)
	_key("move_up", d.y < -6.0)
	_key("move_down", d.y > 6.0)


func _key(action: String, down: bool) -> void:
	if down:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


# ================= 标注叠加层 =================
## 世界坐标 → 屏幕：与 MapScene._clamp_label 同一口径（画布变换）。
class _Annotate extends Control:
	var map_ref: MapScene = null
	var street: Dictionary = {}
	var notes: PackedStringArray = []

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _w2s(p: Vector2) -> Vector2:
		return get_viewport().get_canvas_transform() * p

	func _z() -> float:
		return absf(get_viewport().get_canvas_transform().x.x)

	func _draw() -> void:
		if map_ref == null:
			return
		var z := _z()
		# 1) 四周 12px 安全边距（样板 §4）
		draw_rect(Rect2(12.0, 12.0, 456.0, 776.0), Color("ff6b6b"), false, 1.0)
		# 2) 出生安全圈（样板 §3：150px 内无散件/怪物）
		var sp := _arr(map_ref._main_cfg.get("spawn", []))
		if sp != Vector2.ZERO:
			var c := _w2s(sp)
			draw_arc(c, 150.0 * z, 0.0, TAU, 64, Color("7ee081"), 1.5)
			_lbl(c + Vector2(6.0, -150.0 * z - 6.0), "[出生安全圈 r150]", Color("9ff0a2"))
		# 3) 脚点线（样板 §2：脚点 = 碰撞盒下沿 +21）
		if map_ref._player != null:
			var pp := map_ref._player.global_position
			var foot := _w2s(pp + Vector2(0, 21))
			draw_line(foot + Vector2(-56, 0), foot + Vector2(56, 0), Color("ffe066"), 2.0)
			_lbl(foot + Vector2(-56, 15), "[脚点 y+21]", Color("ffe066"))
			# 4) 名签（样板 §2：140×22 @ (−70, −70.4)）
			var tag := _w2s(pp + Vector2(-70, -70.4))
			draw_rect(Rect2(tag, Vector2(140, 22) * z), Color("8ad4ff"), false, 1.0)
			_lbl(tag + Vector2(146, 10), "[名签 140×22 / FS_SM16]", Color("8ad4ff"))
		# 5) 主街净宽（样板 §3：最窄行 ≥240px）
		if not street.is_empty():
			var lx := _w2s(Vector2(float(street["left"]), float(street["y"])))
			var rx := _w2s(Vector2(float(street["right"]), float(street["y"])))
			var top := _w2s(Vector2(float(street["left"]), 200.0)).y
			var bot := _w2s(Vector2(float(street["left"]), 1240.0)).y
			draw_line(Vector2(lx.x, top), Vector2(lx.x, bot), Color("ff7ad9"), 1.0)
			draw_line(Vector2(rx.x, top), Vector2(rx.x, bot), Color("ff7ad9"), 1.0)
			var mid := (lx + rx) * 0.5
			draw_line(Vector2(lx.x, mid.y), Vector2(rx.x, mid.y), Color("ff7ad9"), 2.0)
			_lbl(Vector2((lx.x + rx.x) * 0.5 - 62.0, mid.y + 16.0),
				"[主街净宽 %.0fpx ≥240]" % float(street["width"]), Color("ff9ce6"))
		# 6) 出口：本屏内的画圆点，屏外的在 notes 里点名
		for row_v in map_ref._main_cfg.get("exits", []):
			var row := row_v as Dictionary
			var at: Array = row.get("at", [])
			if at.size() < 2:
				continue
			var e := _w2s(Vector2(float(at[0]), float(at[1])))
			if e.x < 0.0 or e.x > 480.0 or e.y < 0.0 or e.y > 800.0:
				continue
			draw_circle(e, 6.0, Color("9fe06a"))
			_lbl(e + Vector2(8, -6), "[%s]" % String(row.get("label", "")), Color("bdf08a"))
		# 7) 文字备注（左下角深色底：不压上方状态面板，也不压右下按钮）
		var notes_h := 8.0 + 17.0 * float(notes.size())
		var box := Rect2(14.0, 684.0 - notes_h, 452.0, notes_h + 4.0)
		draw_rect(box, Color(0.05, 0.04, 0.03, 0.78))
		draw_rect(box, Color(1.0, 1.0, 1.0, 0.20), false, 1.0)
		var ty := box.position.y + 13.0
		for n in notes:
			_lbl(Vector2(20.0, ty), n, Color("ffe9a8"))
			ty += 17.0

	func _lbl(pos: Vector2, text: String, col: Color) -> void:
		var f: Font = G.font_reg
		if f == null:
			return
		for off in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(f, pos + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_XS,
				Color(0, 0, 0, 0.85))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_XS, col)

	func _arr(v: Variant) -> Vector2:
		if v is Array and (v as Array).size() >= 2:
			return Vector2(float((v as Array)[0]), float((v as Array)[1]))
		return Vector2.ZERO
