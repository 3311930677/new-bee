# CityScene.gd —— 主城（据点）世界：一座能逛完的城
# 职责：24×20 格自由行走；建筑程序绘制（按 city.json style 分支），未落成的是工地；
#       NPC 常驻街头可对话，来访旅人每天在城门附近落脚；议事厅布告板领取城内活动，
#       城门访客簿管据点码与来往；图志阁/兽栏/演武场分别通向世界/图鉴/出征。
# 交互口径与 MapScene 一致：走近即触发，离开后才会再次触发；WASD/方向键 + 摇杆并行。
class_name CityScene
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0
const DirectionalIdle := preload("res://src/world/DirectionalIdle.gd")
const WorldArtFinish := preload("res://src/world/WorldArtFinish.gd")
const HudStyle := preload("res://src/ui/WorldHUD.gd")
const TILE := 48.0
const NPC_R := 52.0        # 人物交互半径
const BUILD_R := 26.0      # 建筑轮廓外扩的交互边距
const REARM_R := 90.0      # 走出这么远才允许再次触发

const Journal := preload("res://src/ui/JournalUI.gd")
const QuestPanelScript := preload("res://src/ui/QuestPanel.gd")   # 委托板（浮层）
const MountVisual := preload("res://src/world/MountVisual.gd")

const ROLE_FRAMES := {  # 与 MapScene 同源的四方向行走帧
	"zs": "res://image/role/zs/pojun_walk_frames.tres",
	"ck": "res://image/role/ck/chuanyang_walk_frames.tres",
	"fs": "res://image/role/fs/shuangyu_walk_frames.tres",
	"fz": "res://image/role/fz/chenxing_walk_frames.tres",
}

var _cfg: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _cols := 24
var _rows := 20

var _world := Node2D.new()
var _player: CharacterBody2D
var _player_anim: AnimatedSprite2D
var _buildings: Array = []
var _npcs: Array = []

var _hud := CanvasLayer.new()
var _overlay_layer := CanvasLayer.new()  # 复用面板（世界/图鉴/出征）必须压过 HUD
var _joy: _Joystick
var _stat_lbl: Label = null
var _quest_chip: Control = null
var _quest_lbl: Label = null
var _toast_lbl: Label = null
var _panel: Control = null      # 城内浮层（对话/建筑/布告板/访客簿）
var _overlay: Control = null    # 复用面板（世界/图鉴/出征）
var _talk_turns := {}           # npc_id -> 已聊次数（当天对话轮换）
var _dlg: Dictionary = {}       # 进行中的对话 {"id","guest","turn","line"}
var _embedded_map: MapScene = null
var _city_id := "lorin_wilds"


## 作为新主城地图的城务层运行；原有建筑、NPC、对话和面板仍由本场景维护。
func embed_in(map: MapScene, city_id := "lorin_wilds") -> void:
	_embedded_map = map
	_city_id = city_id


func has_modal() -> bool:
	return _panel != null or _overlay != null


func _ready() -> void:
	_cfg = TableCache.city_config_for(_city_id)
	_cols = int(_cfg.get("map_cols", 24))
	_rows = int(_cfg.get("map_rows", 20))
	if _embedded_map != null:
		_world = _embedded_map._world
		_player = _embedded_map._player
		_hud = _embedded_map._hud
		_build_buildings()
		_build_npcs()
		_build_embedded_hud()
		_overlay_layer.layer = 3
		add_child(_overlay_layer)
		return
	Audio.play_bgm("bgm_city")
	_rng.seed = 20260916  # 城是固定的：地被/散件布局不随进出变化
	_build_ground()
	_build_world()
	_build_hud()
	_overlay_layer.layer = 2
	add_child(_overlay_layer)


# ================= 地面 =================
func _build_ground() -> void:
	var g: Dictionary = _cfg.get("ground", {})
	var tiles: Array = g.get("tiles", [])
	var asset_dir := String(_cfg.get("asset_dir", "res://image/map_proc"))
	var tl := TileMapLayer.new()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(48, 48)
	for i in mini(3, tiles.size()):
		var src := TileSetAtlasSource.new()
		src.texture = load("%s/%s.png" % [asset_dir, String(tiles[i])])
		src.texture_region_size = Vector2i(48, 48)
		src.create_tile(Vector2i.ZERO)
		ts.add_source(src, i)
	tl.tile_set = ts
	for y in _rows:
		for x in _cols:
			var roll := _rng.randf()
			var sid := 0
			if roll > 0.8:
				sid = 2
			elif roll > 0.6:
				sid = 1
			if sid < ts.get_source_count():
				tl.set_cell(Vector2i(x, y), sid, Vector2i.ZERO, 0)
	add_child(tl)
	_build_roads(asset_dir, String(g.get("path_sheet", "")))


## 城内路网：一条主街（城门→议事厅）+ 三条横街，格子是写死的——城是规划出来的，不是野路
func _road_cells() -> Dictionary:
	var cells := {}
	for y in range(4, 20):       # 主街
		cells[Vector2i(12, y)] = true
	for x in range(4, 21):       # 北横街：图志阁 — 兽栏
		cells[Vector2i(x, 8)] = true
	for x in range(3, 22):       # 南横街：演武场 — 仓廪
		cells[Vector2i(x, 13)] = true
	for x in range(6, 19):       # 祭坛支路
		cells[Vector2i(x, 16)] = true
	return cells


func _build_roads(asset_dir: String, sheet: String) -> void:
	if sheet == "":
		return
	var tex: Texture2D = load("%s/%s.png" % [asset_dir, sheet])
	if tex == null:
		return
	var cells := _road_cells()
	var tl := TileMapLayer.new()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(48, 48)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(48, 48)
	for i in 16:  # 4×4 位掩码套件：编号＝北1/东2/南4/西8 之和
		src.create_tile(Vector2i(i % 4, i / 4))
	ts.add_source(src, 0)
	tl.tile_set = ts
	for cell: Vector2i in cells.keys():
		var mask := 0
		if cells.has(cell + Vector2i(0, -1)):
			mask |= 1
		if cells.has(cell + Vector2i(1, 0)):
			mask |= 2
		if cells.has(cell + Vector2i(0, 1)):
			mask |= 4
		if cells.has(cell + Vector2i(-1, 0)):
			mask |= 8
		tl.set_cell(cell, 0, Vector2i(mask % 4, mask / 4), 0)
	add_child(tl)


# ================= 世界 =================
func _build_world() -> void:
	_world.y_sort_enabled = true
	add_child(_world)
	_build_decos()
	_build_buildings()
	_build_npcs()
	_build_player()


func _spawn_px() -> Vector2:
	var sp: Array = _cfg.get("spawn", [12.0, 17.5])
	return Vector2(float(sp[0]) * TILE, float(sp[1]) * TILE)


func _city_pos(pos: Vector2) -> Vector2:
	if _embedded_map == null:
		return pos
	var map_size := Vector2(float(int(_embedded_map._map_cfg.get("map_cols", 20)) * 48),
		float(int(_embedded_map._map_cfg.get("map_rows", 26)) * 48))
	return pos * map_size / Vector2(float(_cols) * TILE, float(_rows) * TILE)


func _embedded_city_point(group: String, id: String, fallback: Vector2) -> Vector2:
	if _embedded_map == null:
		return fallback
	var positions: Dictionary = _embedded_map._main_cfg.get(group, {})
	var point: Variant = positions.get(id, [])
	if point is Array and (point as Array).size() >= 2:
		return Vector2(float(point[0]), float(point[1]))
	return _city_pos(fallback)


## 某点是否落在任一建筑轮廓内（散件避让用）
func _in_building(pos: Vector2) -> bool:
	for bd in _cfg.get("buildings", []):
		var b := bd as Dictionary
		var p: Array = b.get("pos", [0.0, 0.0])
		var s: Array = b.get("size", [2.0, 2.0])
		var c := Vector2(float(p[0]) * TILE, float(p[1]) * TILE)
		var hw := float(s[0]) * TILE * 0.5 + 24.0
		var hh := float(s[1]) * TILE * 0.5 + 24.0
		if absf(pos.x - c.x) < hw and absf(pos.y - c.y) < hh:
			return true
	return false


func _build_decos() -> void:
	var decos: Array = _cfg.get("decos", [])
	if decos.is_empty():
		return
	var density := float(_cfg.get("deco_density", 0.03))
	var asset_dir := String(_cfg.get("asset_dir", ""))
	# 同一种散件会在全城出现多次；进城时每种资源只查询一次。
	var deco_textures: Array[Texture2D] = []
	for deco_id in decos:
		deco_textures.append(load("%s/%s.png" % [asset_dir, String(deco_id)]) as Texture2D)
	var roads := _road_cells()
	var spawn := _spawn_px()
	for gy in _rows:
		for gx in _cols:
			if roads.has(Vector2i(gx, gy)):
				continue
			if _rng.randf() > density:
				continue
			var pos := Vector2(gx * TILE + _rng.randf_range(8, 40),
				gy * TILE + _rng.randf_range(8, 40))
			if pos.distance_to(spawn) < 150.0 or _in_building(pos):
				continue
			var deco := _Deco.new()
			var tex: Texture2D = deco_textures[_rng.randi_range(0, deco_textures.size() - 1)]
			deco.setup(tex, _rng.randf_range(0.85, 1.15))
			deco.position = pos
			_world.add_child(deco)


func _build_buildings() -> void:
	for bd in _cfg.get("buildings", []):
		var b := _Building.new()
		b.setup(bd)
		var p: Array = (bd as Dictionary).get("pos", [12.0, 10.0])
		b.position = _embedded_city_point("city_building_positions", String(bd.get("id", "")),
			Vector2(float(p[0]) * TILE, float(p[1]) * TILE))
		_buildings.append(b)
		_world.add_child(b)


func _build_npcs() -> void:
	var residents: Array = G.city_npcs() if _city_id == "lorin_wilds" else _cfg.get("npcs", [])
	for nd in residents:
		_spawn_npc(nd, false)
	if _city_id != "lorin_wilds":
		return
	# 今日来客：按「当天 + 据点码」确定性抽两位，在城门内侧落脚
	var guests := G.today_guests(2)
	var spots := [Vector2(10.6, 16.6), Vector2(13.6, 16.9)]
	var guest_points: Array = _embedded_map._main_cfg.get("city_guest_positions", []) \
		if _embedded_map != null else []
	for i in guests.size():
		var site := String(guests[i])
		_spawn_npc({
			"id": "guest_" + site, "name": site, "title": "来访旅人",
			"hue": 6, "lines": [G.guest_note(site)],
		}, true, _cfg_guest_point(guest_points, i, spots[i % spots.size()] * TILE))


func _cfg_guest_point(points: Array, idx: int, fallback: Vector2) -> Vector2:
	if _embedded_map != null and idx < points.size() and points[idx] is Array \
			and (points[idx] as Array).size() >= 2:
		return Vector2(float(points[idx][0]), float(points[idx][1]))
	return _city_pos(fallback)


func _spawn_npc(nd: Dictionary, guest: bool, at := Vector2.ZERO) -> void:
	var npc_id := String(nd.get("id", ""))
	var n := _CityNPC.new()
	n.data = nd
	n.guest = guest
	n.embedded = _embedded_map != null
	n.hue = int(nd.get("hue", 0))
	n.frames = _npc_idle_frames(npc_id, guest)   # 首选：idle 四帧条（像素小人会呼吸）
	# 四帧已可用时不再加载只供兜底的半身像；城务首次进场无需解码所有 NPC 立绘。
	n.art = _npc_world_tex(npc_id, guest) if n.frames == null else null
	if at == Vector2.ZERO:
		var p: Array = nd.get("pos", [12.0, 10.0])
		at = _embedded_city_point("city_npc_positions", npc_id,
			Vector2(float(p[0]) * TILE, float(p[1]) * TILE))
	n.position = at
	_npcs.append(n)
	_world.add_child(n)


func _build_player() -> void:
	_player = CharacterBody2D.new()
	_player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player.position = _spawn_px()
	_player.collision_layer = 1
	_player.collision_mask = 2
	_world.add_child(_player)

	_player_anim = AnimatedSprite2D.new()
	var frames_path: String = ROLE_FRAMES.get(G.selected_role, ROLE_FRAMES["zs"])
	_player_anim.sprite_frames = load(frames_path)
	_player_anim.material = WorldArtFinish.character_material(G.selected_role)
	# 与 MapScene 同一套标定：0.72 倍 + 上移 19.3px，让脚踩在碰撞盒下沿
	_player_anim.scale = Vector2.ONE * 0.72
	_player_anim.position = Vector2(0, -19.3)
	_player_anim.animation = &"walk_down"
	DirectionalIdle.stop(_player_anim)
	_player.add_child(_player_anim)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 26)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	_player.add_child(shape)

	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * 1.25
	cam.position = Vector2(0, -56)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = _cols * 48
	cam.limit_bottom = _rows * 48
	cam.enabled = true
	_player.add_child(cam)
	cam.make_current()


# ================= HUD =================
func _build_hud() -> void:
	_hud.layer = 1
	add_child(_hud)
	_build_vignette()

	var banner := G.banner_box(G.city_name(), 200, 46, G.FS_LG)
	banner.position = Vector2((VIEW_W - 200.0) * 0.5, 12)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 纯装饰：不参与点击争夺
	_hud.add_child(banner)

	# 左上：等级 + 金币小签（建造/宴会后会刷新）
	var chip := G.parchment_box(112, 38, 8.0)
	chip.position = Vector2(14, 16)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE     # 同上
	_hud.add_child(chip)
	_stat_lbl = G.gold_label("", G.FS_XS, false, Color("5a3a1e"), false)
	_stat_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	chip.add_child(_stat_lbl)

	# 左上第二行：今日委托小签（点开委托板）。委托是"每天回城有事做"的抓手，
	# 所以要常驻可见，而不是藏进建筑里等玩家去翻。
	_quest_chip = G.parchment_box(132, 34, 6.0)
	_quest_chip.position = Vector2(14, 60)
	_quest_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	_quest_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_quest_chip.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_quests())
	_hud.add_child(_quest_chip)
	_quest_lbl = G.gold_label("", G.FS_XS, false, Color("5a3a1e"), false)
	_quest_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quest_chip.add_child(_quest_lbl)
	_refresh_stat()

	# 右上：回营（返回养成主界面）
	var home := G.gold_button("回营", 62, 38)
	home.position = Vector2(VIEW_W - 76, 16)
	home.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_go_home())
	_hud.add_child(home)

	# 底部中央：出征（主页把出征搬进主城后，这里是主城最显眼的主操作）
	var go := G.gold_button("出 征", 190, 54, G.FS_LG)
	go.position = Vector2((VIEW_W - 190.0) * 0.5, VIEW_H - 78)
	go.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_deploy())
	_hud.add_child(go)

	# 右下：操作提示
	var hint_chip := G.InsetPanel.new()
	# 提示条：切角 + 内凹光（顶暗底亮），弃用圆角4的半透明块
	hint_chip.setup(Color(0.13, 0.09, 0.05, 0.55), Color("ffd9a0", 0.18),
		8.0, 8.0, 2.0, 2.0)
	hint_chip.position = Vector2(VIEW_W - 216, VIEW_H - 44)
	# 提示条是装饰，但它原本会吃掉「出征」按钮右下角的点击（实测有 71×20 的死区）
	hint_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_chip.add_child(G.gold_label("走近建筑或人物即可互动", G.FS_XS,
		false, Color("ffd9a0", 0.75), false))
	_hud.add_child(hint_chip)

	# 摇杆往左让出 10px：它的 124×124 命中区原本咬住「出征」按钮左上角
	_joy = _Joystick.new()
	_joy.position = Vector2(16, VIEW_H - 176)
	_hud.add_child(_joy)


func _build_embedded_hud() -> void:
	# 主世界的地图名和金币由 MapScene 显示。两城的小签指向各自可用服务。
	var task := HudStyle.task_chip(184, "daily")
	var task_button: Button = task.root
	_quest_chip = task_button
	_quest_chip.position = Vector2(16, 112)
	_quest_chip.tooltip_text = "查看城务委托" if _city_id == "border_town" else "查看城镇服务"
	task_button.pressed.connect(func():
		if not G.ui_blocked:
			if _city_id == "shenyuan_port":
				_open_first_order_preview("shenyuan_market")
			elif _city_id == "frost_post":
				_open_shop()
			else:
				_open_quests())
	_hud.add_child(_quest_chip)
	_quest_lbl = task.label
	_refresh_stat()
	# 城务入口晚于地图 HUD 创建；复用同一安全区，刘海屏上保持列对齐。
	preload("res://src/ui/UiSafeArea.gd").fit_hud(_hud, G.ui_safe_rect(self), get_viewport_rect())


func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.42, 0.78])
	grad.colors = PackedColorArray([
		Color(0.06, 0.04, 0.02, 0.0),
		Color(0.06, 0.04, 0.02, 0.0),
		Color(0.04, 0.03, 0.02, 0.42),  # 城里比野外亮堂：暗角收一档
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	# 渐变很平滑，没必要按 480×800 逐像素生成（那是 38 万次插值）；
	# 生成 1/4 分辨率再由 GPU 拉伸，观感一致，进场少卡一截
	tex.width = 120
	tex.height = 200
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var vig := TextureRect.new()
	vig.texture = tex
	vig.size = Vector2(VIEW_W, VIEW_H)
	vig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 项目默认 nearest，放大必须改线性
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(vig)


func _refresh_stat() -> void:
	if _stat_lbl != null:
		_stat_lbl.text = str(int(G.wallet.get("gold", 0))) if _embedded_map != null \
			else "Lv.%d · 金 %d" % [int(G.prog.get("level", 1)), int(G.wallet.get("gold", 0))]
	if _quest_lbl != null:
		match _city_id:
			"shenyuan_port": HudStyle.update_task(_quest_lbl, "港务 · 查看行情")
			"frost_post": HudStyle.update_task(_quest_lbl, "驿务 · 采买物资")
			_: HudStyle.update_task(_quest_lbl, G.quest_today_text())
		if _embedded_map != null:
			_quest_chip.tooltip_text = _quest_lbl.text + " · 查看城镇服务"


func _toast(msg: String) -> void:
	if _toast_lbl != null and not _toast_lbl.is_queued_for_deletion():
		_toast_lbl.queue_free()
	_toast_lbl = G.toast_label(msg)
	_toast_lbl.position = Vector2(24, maxf(VIEW_H, get_viewport_rect().size.y) - 240.0)
	_hud.add_child(_toast_lbl)
	_place_dialogue_toast.call_deferred()
	G.reveal_control(_toast_lbl)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast_lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_toast_lbl.queue_free)


# ================= 主循环 =================
func _physics_process(delta: float) -> void:
	if _embedded_map != null:
		if _embedded_map._modal_open() or _player == null:
			return
		_check_interact()
		return
	if _panel != null or _overlay != null:
		return
	if G.ui_blocked:  # GM 控制台等全屏浮层优先
		return
	if _player == null:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _joy != null:
		dir = (dir + _joy.vector).limit_length(1.0)
	var speed := float(_cfg.get("player_speed", 92.0))
	_player.velocity = dir * speed
	var before := _player.position
	_player.move_and_slide()
	_player.position = _player.position.clamp(Vector2(20, 40),
		Vector2(_cols * 48 - 20, _rows * 48 - 20))
	_update_player_anim((_player.position - before) / maxf(delta, 0.0001))
	_check_interact()


func _update_player_anim(dir: Vector2) -> void:
	if dir.length_squared() < 0.25:
		DirectionalIdle.stop(_player_anim)
		return
	var anim := &"walk_down"
	if absf(dir.x) > absf(dir.y):
		anim = &"walk_right" if dir.x > 0 else &"walk_left"
	else:
		anim = &"walk_down" if dir.y > 0 else &"walk_up"
	DirectionalIdle.change_walk_direction(_player_anim, anim)
	_player_anim.speed_scale = dir.length() / maxf(1.0, float(_cfg.get("player_speed", 92.0)))
	if not _player_anim.is_playing():
		_player_anim.play()


## 走近触发：建筑按轮廓外扩判定（正面不一定够得着，比如城门贴着地图下沿）；
## 触发过一次的对象要走出一段距离才会再次触发，免得关了面板立刻又弹出来
func _check_interact() -> void:
	var best: Node2D = null
	var best_d := 9999.0
	for b in _buildings:
		var d: float = b.dist_to(_player.position)
		if not b.cooled and d < BUILD_R and d < best_d:
			best = b
			best_d = d
		b.hover = d < BUILD_R + 24.0
		if d > REARM_R:
			b.cooled = false
	for n in _npcs:
		var nd: float = n.position.distance_to(_player.position)
		if not n.cooled and nd < NPC_R and nd < best_d:
			best = n
			best_d = nd
		n.hover = nd < NPC_R + 24.0
		n.label_near = (nd < 122.0 and not _npc_plate_overlaps_player(n)) \
			if _embedded_map != null else nd < 190.0
		if nd > REARM_R:
			n.cooled = false
	if best != null and not (best as Object).get("cooled"):
		best.set("cooled", true)
		if best is _Building:
			_open_building((best as _Building).data)
		else:
			_open_dialog((best as _CityNPC).data, (best as _CityNPC).guest)


## 城务名签不遮住主角名签或身体。靠近时优先保留主角轮廓；
## NPC 实体和交互仍在，离开重叠位置后名签自动恢复。
func _npc_plate_overlaps_player(n: _CityNPC) -> bool:
	if _embedded_map == null or _embedded_map._player_tag == null:
		return false
	var tag := _embedded_map._player_tag
	var player_rect := Rect2(_player.position + tag.position, tag.size)
	# NPC位于主角下方时，其头顶名牌也可能盖住主角身体。
	var draw_scale := float(_embedded_map._main_cfg.get("player_scale", 0.54))
	var body_rect := Rect2(_player.position + Vector2(-48.0, -120.0) * draw_scale,
		Vector2(96.0, 128.0) * draw_scale)
	player_rect = player_rect.merge(body_rect)
	var npc_rect := Rect2(n.position + Vector2(-n._plate_w * 0.5, n._plate_top),
		Vector2(n._plate_w, n._plate_h))
	return player_rect.grow(4.0).intersects(npc_rect)


# ================= 浮层骨架 =================
func _panel_base(title: String, w: float, h: float) -> Control:
	var layer := Control.new()
	layer.set_meta("visual_family",G.Visuals.title_family(title))
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），城内所有面板共用同一层质感
	G.veil(layer, 0.72, true)
	var visible_h := maxf(VIEW_H, get_viewport_rect().size.y)
	var banner := G.banner_box(title, 260, 48)
	banner.position = Vector2((VIEW_W - 260.0) * 0.5, (visible_h - h) * 0.5 - 58.0)
	layer.add_child(banner)
	var panel := G.parchment_box(w, h, 16.0)
	panel.position = Vector2((VIEW_W - w) * 0.5, (visible_h - h) * 0.5)
	layer.add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_panel = layer
	_hud.add_child(layer)
	G.fit_mobile_page.call_deferred(layer)
	return content


func _close_panel() -> void:
	Audio.sfx("ui_close")
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_dlg = {}


func _panel_back(content: Control, y: float, w := 120.0) -> void:
	var back := G.ghost_button("返回", w, 38)
	back.position = Vector2(((content.get_parent() as Control).custom_minimum_size.x - 32.0 - w) * 0.5, y)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel())
	content.add_child(back)


# ================= 建筑交互 =================
func _open_building(bd: Dictionary) -> void:
	if _panel != null:
		return
	# 进入城内建筑先下马；主世界马上切回步行脚点与碰撞盒。
	if G.mount_riding():
		if not G.mount_set_riding(false):
			_toast("下马状态未能保存，请稍后再试")
			return
		if _embedded_map != null:
			_embedded_map.call("_sync_mount_visual")
	var id := String(bd.get("id", ""))
	if bool(bd.get("port_built", false)) or G.is_built(id):
		_show_built_panel(bd)
	else:
		_show_build_panel(bd)


## 未落成：工地详情 + 造价 + 建造按钮
func _show_build_panel(bd: Dictionary) -> void:
	var id := String(bd.get("id", ""))
	var content := _panel_base(String(bd.get("name", "工地")), 360, 330)

	var state := G.build_state(id)
	var head := G.gold_label("一片圈好的空地 · %s" % state, G.FS_SM, false,
		Color("7a5a2e"), false)
	head.position = Vector2(0, 2)
	head.custom_minimum_size = Vector2(328, 0)
	content.add_child(head)

	var desc := G.text_label(String(bd.get("desc", "")), G.FS_SM, Color("5a4020"))
	desc.position = Vector2(0, 30)
	desc.custom_minimum_size = Vector2(328, 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	var cost: Dictionary = bd.get("cost", {})
	var y := 108.0
	if cost.is_empty():
		y -= 4.0
	else:
		var cl := G.gold_label("— 造价 —", G.FS_XS, false, Color("8a6a34"), false)
		cl.position = Vector2(0, y)
		cl.custom_minimum_size = Vector2(328, 0)
		content.add_child(cl)
		y += 22.0
		for k in cost.keys():
			var key := String(k)
			var need := int(cost[k])
			var have := int(G.wallet.get(key, 0))
			var enough := have >= need
			var line := G.gold_label("%s ×%d（现有 %d）" % [
				String(G.REWARD_NAMES.get(key, key)), need, have],
				G.FS_SM, false, Color("5a4020") if enough else Color("a03a2a"), false)
			line.position = Vector2(0, y)
			line.custom_minimum_size = Vector2(328, 0)
			content.add_child(line)
			y += 24.0

	var build := G.gold_button("建 造", 140, 42)
	build.position = Vector2(16, 252)
	build.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_try_build(id))
	content.add_child(build)
	var back := G.gold_button("返 回", 140, 42)
	back.position = Vector2(172, 252)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel())
	content.add_child(back)


func _try_build(id: String) -> void:
	if G.build(id):
		_close_panel()
		_refresh_city()
		_refresh_stat()
		_toast("「%s」落成了！" % String(G.city_building(id).get("name", id)))
	else:
		_toast(G.build_state(id))


## 建造/刷新后重建城市实体（新楼立起来，新 NPC 上街）
func _refresh_city() -> void:
	for b in _buildings:
		b.queue_free()
	_buildings.clear()
	for n in _npcs:
		n.queue_free()
	_npcs.clear()
	_build_buildings()
	_build_npcs()


## 已落成：标题、说明与操作放在同一张便笺，短内容不再撑出一整页空白。
func _show_built_panel(bd: Dictionary) -> void:
	var act := String(bd.get("action", ""))
	var actions: Array[Dictionary] = []
	var btn_text := ""
	match act:
		"notice": btn_text = "查看布告板"
		"visit": btn_text = "翻开访客簿"
		"worlds": btn_text = "翻阅世界图志"
		"codex": btn_text = "翻看宠物图鉴"
		"hatch": btn_text = "孵化潮纹蛋"
		"deploy": btn_text = "整备出征"
		"shop": btn_text = "采买物资"
		"trade:shenyuan_market": btn_text = "查看港口行情"
		"trade:frost_market": btn_text = "查看驿站行情"
		"mount": btn_text = "查看马厩"
		"soon": btn_text = "尚未开放"
	if act.begins_with("activity:"):
		btn_text = "领取 · %s" % G.activity_state(act.get_slice(":", 1))
	if not btn_text.is_empty():
		actions.append({"text": btn_text, "action": act})
	if act == "worlds":
		actions.append({"text": "深渊首领图志", "action": "abyss_codex"})
		actions.append({"text": "翻阅行旅图志", "action": "field_journal"})
		if G.story_step_done("s12"): actions.append({"text":"选择守碑誓约","action":"oath"})
	if String(bd.get("id", "")) == "frost_lodge":
		actions.append({"text": "伙伴协战", "action": "companion_training"})
	var desc := Journal.label(String(bd.get("desc", "")), 17, Journal.INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size.x = 344
	desc.add_theme_constant_override("line_spacing", 6)
	# 文字高度按实际换行计算；港口和后续章节的长说明同样能装下。
	var body_h := maxf(58, desc.get_minimum_size().y)
	var action_y := 146.0 + body_h + 22.0
	if act == "visit":
		action_y += 64
	var height := 24 + action_y + actions.size() * 56 + 44 + 24
	var content := _building_note_card(String(bd.get("name", "建筑")), height, String(bd.get("id", "")))
	desc.position.y = 146
	content.add_child(desc)
	if act == "visit":
		var book := Panel.new()
		book.position = Vector2(0, 158 + body_h)
		book.size = Vector2(344, 58)
		book.add_theme_stylebox_override("panel", Journal.surface(Color("e0d1a9"), Color("c2ad7d"), 1))
		book.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(book)
		var icon := _building_book_icon()
		icon.position = Vector2(14, 13)
		book.add_child(icon)
		var book_title := Journal.art_label("访客簿", 20)
		book_title.position = Vector2(56, 5)
		book.add_child(book_title)
		var book_hint := Journal.label("据点木牌 · 来访旅人", 14, Journal.MUTED)
		book_hint.position = Vector2(56, 32)
		book.add_child(book_hint)
	for i in actions.size():
		var entry := actions[i]
		var target := String(entry["action"])
		var go := Journal.button(String(entry["text"]), 344, 48, "primary" if i == 0 else "secondary")
		go.name = "BuildingAction%d" % i
		go.position.y = action_y + i * 56
		go.disabled = target == "soon"
		if go.disabled:
			go.modulate.a = 0.5
		go.pressed.connect(func():
			_close_panel()
			if target == "abyss_codex":
				_open_abyss_boss_codex()
			else:
				_built_action(target))
		content.add_child(go)
	var back := Journal.button("返回城内", 344, 44, "quiet")
	back.name = "BuildingBack"
	back.position.y = action_y + actions.size() * 56
	back.pressed.connect(_close_panel)
	content.add_child(back)


func _building_note_card(title: String, height: float, building_id: String) -> Control:
	var layer := Control.new()
	layer.set_meta("visual_family",G.Visuals.title_family(title))
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = layer
	_hud.add_child(layer)
	G.veil(layer, 0.70, true)
	var panel := Journal.paper(392, height)
	panel.set("header_height", 144.0)
	panel.name = "BuildingNote"
	panel.position = Vector2(44, (maxf(VIEW_H, get_viewport_rect().size.y) - height) * 0.5)
	layer.add_child(panel)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var art_id := "kennel" if building_id == "stable" else building_id
	var art_path := "res://image/main_world/city_%s_reference_v2.png" % art_id
	var texture := load(art_path) as Texture2D if ResourceLoader.exists(art_path) else G.res_tex("city_" + art_id)
	if texture != null:
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.texture = texture
		picture.position = Vector2(170, 4)
		picture.size = Vector2(170, 110)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(picture)
	var eyebrow := Journal.label("城内设施", 14, Color("c6b892"), true)
	eyebrow.position.y = 2
	content.add_child(eyebrow)
	var heading := Journal.art_label(title, 38 if title.length() < 5 else 25, Journal.GOLD)
	heading.position.y = 27
	heading.add_theme_color_override("font_shadow_color", Color("112c2a"))
	heading.add_theme_constant_override("shadow_offset_y", 2)
	content.add_child(heading)
	var location := Journal.label(String(_cfg.get("name", G.city_name())), 14, Color("c6b892"), true)
	location.position.y = 82
	content.add_child(location)
	var close := Journal.button("×", 44, 44, "dark_quiet")
	close.position = Vector2(318, -18)
	close.tooltip_text = "关闭"
	close.pressed.connect(_close_panel)
	content.add_child(close)
	return content


func _building_book_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = G.res_tex("itm_pet_book")
	icon.size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _built_action(act: String) -> void:
	if act == "oath":
		_close_panel()
		var oath_panel := preload("res://src/ui/OathPanel.gd").new()
		_overlay = oath_panel
		oath_panel.closed.connect(_close_overlay)
		_hud.visible = false
		_overlay_layer.add_child(oath_panel)
		return
	if act == "field_journal":
		_panel = preload("res://src/ui/FieldJournalPanel.gd").new()
		_panel.closed.connect(_close_panel)
		_hud.add_child(_panel)
		return
	if act == "companion_training":
		_panel = CompanionPanel.new()
		(_panel as CompanionPanel).closed.connect(_close_panel)
		(_panel as CompanionPanel).changed.connect(func():
			if _embedded_map == null: return
			var active := G.companion_active()
			_embedded_map.st.active_pet = active
			var other := G.owned_pets().filter(func(pid): return String(pid) != active)
			_embedded_map.st.bench_pet = String(other[0]) if not other.is_empty() else ""
			_embedded_map.call("_sync_world_companion")
			_embedded_map.call("_refresh_hud"))
		_hud.add_child(_panel)
		return
	if act == "trade:frost_market":
		_open_first_order_preview("frost_market")
		return
	if act == "trade:shenyuan_market":
		_open_first_order_preview("shenyuan_market")
		return
	if act.begins_with("activity:"):
		_claim_activity(act.get_slice(":", 1))
		return
	match act:
		"notice":
			_show_notice()
		"visit":
			_show_guests()
		"worlds":
			_open_worlds()
		"codex":
			_open_codex()
		"shipping":
			_open_shipping_panel()
		"hatch":
			_open_tide_hatch_panel()
		"deploy":
			_open_deploy()
		"shop":
			_open_shop()
		"mount":
			_open_first_mount_panel()
		"soon":
			_toast("匠人还没备好料，再等等")


func _claim_activity(id: String) -> void:
	var res := G.do_activity(id)
	if bool(res.get("ok", false)):
		var lines: Array = res.get("lines", [])
		_toast("%s：%s" % [String(res.get("name", "")),
			" · ".join(PackedStringArray(lines))])
	else:
		_toast(String(res.get("err", "还不能领取")))
	_refresh_stat()


# ================= 布告板（活动） =================
func _show_notice() -> void:
	if _panel != null:
		return
	var acts := G.city_activities()
	# P05-C：布告栏常驻一条「路西兽影」悬赏行（72px），线索与状态随支线／首胜变化
	var h := 120.0 + acts.size() * 60.0 + 76.0
	var content := _panel_base("布 告 板", 400, h)

	var tip := G.gold_label("城中的营生都在这儿。冷却好了就来领。",
		G.FS_XS, false, Color("7a5a2e"), false)
	tip.position = Vector2(0, 2)
	tip.custom_minimum_size = Vector2(368, 0)
	content.add_child(tip)

	for i in acts.size():
		var a := acts[i] as Dictionary
		var aid := String(a.get("id", ""))
		var y := 28.0 + i * 60.0
		var row := G.InsetPanel.new()
		row.custom_minimum_size = Vector2(368, 52)
		row.position = Vector2(0, y)
		row.setup(Color("d8c8a0"), Color("b1a181"), 10.0, 10.0, 4.0, 0.0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(row)

		var name_l := G.gold_label(String(a.get("name", aid)), G.FS_MD, false,
			Color("3a2a14"), false)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.position = Vector2(10, y + 4)
		content.add_child(name_l)
		var sub := G.activity_state(aid)
		if bool(a.get("daily", false)):
			sub += " · 连签 %d 天" % int(G.city.get("streak", 0))
		var sub_l := G.gold_label(sub, G.FS_XS, false, Color("8a6a34"), false)
		sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		sub_l.position = Vector2(10, y + 28)
		content.add_child(sub_l)

		if G.activity_ready(aid):
			var claim := G.gold_button("领 取", 72, 34, G.FS_SM)
			claim.position = Vector2(286, y + 9)
			claim.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					_close_panel()
					_claim_activity(aid))
			content.add_child(claim)

	# P05-C：布告栏「路西兽影」悬赏行（spec §5：城内布告栏给线索）。
	# 状态文案与支线／世界旗同源：未见 → 已接 → 已见过 → 首胜已了。
	var by := 28.0 + acts.size() * 60.0 + 6.0
	var brow := G.InsetPanel.new()
	brow.custom_minimum_size = Vector2(368, 66)
	brow.position = Vector2(0, by)
	brow.setup(Color("cbb890"), Color("a5906a"), 10.0, 10.0, 4.0, 0.0)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(brow)
	var b_title := G.gold_label("路西兽影 · 悬赏", G.FS_MD, false, Color("3a2a14"), false)
	b_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b_title.position = Vector2(10, by + 4)
	content.add_child(b_title)
	var b_sub := G.gold_label(_notice_lost_beast_line(), G.FS_XS, false, Color("6a4a24"), false)
	b_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b_sub.custom_minimum_size = Vector2(348, 0)
	b_sub.position = Vector2(10, by + 26)
	content.add_child(b_sub)

	_panel_back(content, h - 64.0)


## 布告栏「路西兽影」状态行（P05-C）：未接给线索，已接给目标，见过给回报，首胜给了结。
func _notice_lost_beast_line() -> String:
	if bool((G.prog.get("flags", {}) as Dictionary).get("act1_lost_beast_down", false)):
		return "失路兽已伏诛，断碑坡路西平安——悬赏已了。"
	var st := G.side_status_of("a1_elite_beast")
	if st == "ready":
		return "你已见过它——回城找闻叔回报。"
	if st == "active":
		return "目标：断碑坡找到失路兽（可战可察）。"
	return "断碑坡路西有东西在走，不像寻常野兽。"


# ================= 访客簿 =================
func _show_guests() -> void:
	if _panel != null:
		return
	var content := _panel_base("访 客 簿", 400, 470)

	var tip := G.gold_label("你的据点码——抄给别人，人家便能上门串门",
		G.FS_XS, false, Color("7a5a2e"), false)
	tip.position = Vector2(0, 2)
	tip.custom_minimum_size = Vector2(368, 0)
	content.add_child(tip)
	var code := G.serif_label(G.city_code(), G.FS_BIG, Color("8a4a2a"))
	code.position = Vector2(0, 22)
	code.custom_minimum_size = Vector2(368, 40)
	content.add_child(code)

	var gtip := G.gold_label("— 今日来客 —", G.FS_SM, false, Color("8a6a34"), false)
	gtip.position = Vector2(0, 72)
	gtip.custom_minimum_size = Vector2(368, 0)
	content.add_child(gtip)
	var guests := G.today_guests(3)
	for i in guests.size():
		var site := String(guests[i])
		var y := 100.0 + i * 56.0
		var name_l := G.gold_label(site, G.FS_MD, false, Color("3a2a14"), false)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.position = Vector2(4, y)
		content.add_child(name_l)
		var note := G.text_label(G.guest_note(site), G.FS_XS, Color("6a5330"))
		note.position = Vector2(4, y + 24)
		note.custom_minimum_size = Vector2(360, 0)
		content.add_child(note)

	var vtip := G.gold_label("— 访客簿（%d）—" % G.city_visits().size(),
		G.FS_SM, false, Color("8a6a34"), false)
	vtip.position = Vector2(0, 280)
	vtip.custom_minimum_size = Vector2(368, 0)
	content.add_child(vtip)
	var visits := G.city_visits()
	var vtxt := "还没有据点登门。把据点码送出去试试。"
	if not visits.is_empty():
		var names := PackedStringArray()
		for v in visits:
			names.append(String(v))
		vtxt = "、".join(names)
	var vl := G.text_label(vtxt, G.FS_SM, Color("5a4020"))
	vl.position = Vector2(0, 306)
	vl.custom_minimum_size = Vector2(368, 0)
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(vl)

	_panel_back(content, 406.0)


# ================= NPC 对话 =================
## 立绘寻址：npc_<id>_portrait 优先；三个老熟人沿用已有半身像；旅人用 idle 首帧裁切
const NPC_PORTRAIT_ALIAS := {
	"npc_smith": "npc_blacksmith",
	"npc_warden": "npc_merchant",
	"npc_keeper": "npc_courier",
	"npc_mentor": "npc_guard",
	"npc_stablemaster": "npc_courier",
}

## 城内站位（首选）：npc_<id>_idle 横向四帧条（512×128，128/帧）→ 呼吸循环。
## 帧条画法见 docs/人物素材需求.md §5（七位常驻 + 旅人 npc_guest_idle）；
## 缺图返回 null，调用方退回单帧立绘/色块。帧序列按 key 缓存：反复进城不该重建 8×4 张 AtlasTexture。
var _idle_frame_cache := {}


func _npc_idle_frames(npc_id: String, guest: bool) -> SpriteFrames:
	if not guest and FrostCityArt.rows().has(npc_id):
		return FrostCityArt.idle(npc_id)
	var key := "npc_guest_idle" if guest else "%s_idle" % npc_id
	if _idle_frame_cache.has(key):
		return _idle_frame_cache[key]
	var tex: Texture2D = G.res_tex(key)
	if tex == null or tex.get_width() < 512 or tex.get_height() < 128:
		_idle_frame_cache[key] = null
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 5.0)
	frames.set_animation_loop(&"idle", true)
	for c in 4:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(c * 128, 0, 128, 128)
		frames.add_frame(&"idle", at)
	_idle_frame_cache[key] = frames
	return frames


## 城内站位（兜底）：全身单帧 npc_<id>_idle_single；再缺就退回半身像
## 单帧站位图必须是小图（世界内 100px 级）。342_353 那批 source/ 里的
## *_idle_single 是 1254×1254 的高清插画，画风与像素小人不同、也不能当世界精灵用，
## 所以超过 320px 就当没有，直接走立绘/色块兜底。
func _npc_world_tex(npc_id: String, guest: bool) -> Texture2D:
	var tex := G.res_tex("%s_idle_single" % npc_id)
	if tex != null and tex.get_width() > 320:
		tex = null
	if tex == null:
		tex = _npc_portrait_tex(npc_id, guest)
	return tex


func _npc_portrait_tex(npc_id: String, guest: bool) -> Texture2D:
	if not guest and FrostCityArt.rows().has(npc_id):
		return FrostCityArt.portrait(npc_id)
	if guest:
		var single := G.res_tex("npc_guest_idle_single")
		if single != null:
			return single
		# 旅人没有单独半身像：从 idle 条首帧裁头肩顶上（对话框只有 64×64，够用）
		var strip: Texture2D = G.res_tex("npc_guest_idle")
		if strip != null and strip.get_width() >= 128:
			var at := AtlasTexture.new()
			at.atlas = strip
			at.region = Rect2(16, 4, 96, 96)
			return at
		return null
	var tex := G.res_tex("%s_portrait" % npc_id)
	if tex == null and NPC_PORTRAIT_ALIAS.has(npc_id):
		tex = G.res_tex(NPC_PORTRAIT_ALIAS[npc_id])
	if tex == null and (npc_id.begins_with("npc_port_") or npc_id == "npc_harbormaster"):
		var strip := G.res_tex("%s_idle" % npc_id)
		if strip != null and strip.get_width() >= 512:
			var portrait := AtlasTexture.new()
			portrait.atlas = strip
			portrait.region = Rect2(28, 4, 72, 86)
			return portrait
	return tex


func _open_dialog(nd: Dictionary, guest: bool, offer_return_job := true) -> void:
	if _panel != null:
		return
	Audio.sfx("ui_open")
	var id := String(nd.get("id", ""))
	if not guest and offer_return_job and String(G.story_current().get("target", "")) != id and not G.return_job_row(id).is_empty():
		_open_return_job(nd)
		return
	if not guest and offer_return_job and G.story_step_done("s36") and id not in ["npc_steward","npc_harbormaster","npc_frost_envoy"]:
		for row in G.side_quest_rows():
			if String(row.get("giver",""))==id and not (row.get("steps",[]) as Array).is_empty():
				_open_npc_jobs(nd)
				return
	if not guest and id == "npc_steward" and String(G.story_current().get("id", "")) == "s36":
		_open_campaign_ending()
		return
	if not guest and G.story_step_done("s36") and id in ["npc_steward", "npc_harbormaster", "npc_frost_envoy"]:
		_open_campaign_response(id)
		return
	if not guest and id == "npc_scribe" and String(G.story_current().get("id", "")) == "s32":
		_open_fourth_preparation_panel()
		return
	if not guest:
		var side_action := QuestService.side_npc_action(G.act1_state(), G._side_live_rows(), id)
		var side_row := QuestService.side_row(G.side_quest_rows(), String(side_action.get("qid", "")))
		if String(side_action.get("kind", "")) == "turn_in" and not (side_row.get("choices", {}) as Dictionary).is_empty():
			_open_port_side_panel(id)
			return
	if not guest and id == "npc_harbormaster" and String(G.story_current().get("id", "")) == "s20":
		_open_tide_choice_panel()
		return
	if not guest and id == "npc_frost_envoy" and String(G.story_current().get("id", "")) == "s28":
		_open_frost_choice_panel()
		return
	if not guest and id == "npc_harbormaster" and G.story_step_done("s16") \
		and String(G.story_current().get("target", "")) != id:
		_open_port_services()
		return
	if not guest and id == "npc_port_keeper":
		_open_tide_hatch_panel()
		return
	if not guest and id == "npc_smith" and String(G.story_current().get("id", "")) == "s11":
		_open_repair_panel()
		return
	if not guest and id == "npc_mentor":
		_open_mentor_panel()
		return
	if not guest and id == "npc_stablemaster" and G.first_mount_status() != "locked":
		_open_first_mount_panel()
		return
	# 阿豆原有的足迹支线仍走普通对话；只在 s04 已完成且尚未领取时切到结缘面板。
	if not guest and id == "npc_keeper" and G.rockturtle_status() == "ready":
		_open_rockturtle_panel()
		return
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := G.parchment_box(432, 150, 16.0)
	panel.position = Vector2(24, maxf(VIEW_H, get_viewport_rect().size.y) - 190.0)
	layer.add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var title := String(nd.get("title", ""))
	var head := String(nd.get("name", "???"))
	if title != "":
		head += " · " + title
	var name_l := G.serif_label(head, 24, G.BANNER)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(0, 0)
	content.add_child(name_l)

	# 对话立绘：优先生成图 npc_<id>_portrait，无则走旧三杰映射（merchant/blacksmith/courier）
	var text_x := 0.0
	var text_w := 400.0
	var portrait := _npc_portrait_tex(String(nd.get("id", "")), guest)
	if portrait != null:
		var frame := PanelContainer.new()
		var fsb := Journal.surface(Color("203938"), G.GOLD, 2)
		fsb.set_border_width_all(2)
		fsb.content_margin_left = 6.0
		fsb.content_margin_top = 6.0
		fsb.content_margin_right = 6.0
		fsb.content_margin_bottom = 6.0
		frame.add_theme_stylebox_override("panel", fsb)
		frame.position = Vector2(0, 34)
		frame.custom_minimum_size = Vector2(76, 76)
		var pic := TextureRect.new()
		pic.texture = portrait
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2(64, 64)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pic)
		content.add_child(frame)
		text_x = 84.0
		text_w = 316.0

	var line := G.text_label("", G.FS_MD, Color("3a2a14"))
	line.position = Vector2(text_x, 34)
	line.custom_minimum_size = Vector2(text_w, 0)
	line.size.x = text_w
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(line)

	var hint := G.gold_label("轻点继续", G.FS_XS, false, Color("8a6a34", 0.8), false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = Vector2(0, 100)
	hint.custom_minimum_size = Vector2(400, 0)
	content.add_child(hint)
	# 行脚商人仍先说原有的任务/修碑台词；现货从初期可逛，首单由送盐支线解锁。
	var market: Control = null
	if not guest and id in ["npc_warden", "npc_port_trader"]:
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		market = G.gold_button("市集交易", 122, 36, G.FS_XS)
		market.position = Vector2(274, 89)
		market.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_close_panel()
				_open_first_order_preview("shenyuan_market" if id == "npc_port_trader" else "city_market"))
		content.add_child(market)

	var leave := G.ghost_button("离开", 64, 30, G.FS_XS)
	leave.position = Vector2(336, -4)
	leave.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel())
	content.add_child(leave)

	# 点面板任意处换下一句
	panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_advance_dialog())

	_panel = layer
	_hud.add_child(layer)
	var offered_story := G.story_current() if not guest else {}
	var offered_dialogue := String(offered_story.get("dialogue", "")) \
		if String(offered_story.get("event", "")) == "talk" \
		and String(offered_story.get("target", "")) == id else ""
	_dlg = {"id": id, "guest": guest, "data": nd, "story_dialogue": offered_dialogue,
		"turn": 0 if not offered_dialogue.is_empty() else int(_talk_turns.get(id, 0)),
		"line": line, "paper": panel, "hint": hint, "market": market}
	# 支线接取/交付（P05-B）：先落地再显示第一句——接取与交付各有专属台词，写盘失败内部会回滚。
	var side_res := {}
	if not guest:
		side_res = G.side_npc_interact(id)
		if not side_res.is_empty():
			_dlg["side_line"] = String(side_res.get("line", ""))
	_show_dialog_line()
	if not guest:
		var story_result := G.story_event("talk", id, _city_id)
		if not story_result.is_empty():
			_toast("主线完成：%s" % String(story_result.get("title", "")))
			_refresh_stat()
			if _embedded_map != null:
				_embedded_map.call("_refresh_quest_entities")
				_embedded_map.call("_refresh_hud")
		if not side_res.is_empty():
			for t in side_res.get("toasts", []):
				_toast(String(t))
			_refresh_stat()
			if _embedded_map != null:
				_embedded_map.call("_refresh_quest_entities")
				_embedded_map.call("_refresh_hud")
	if guest:
		var site := String(nd.get("name", ""))
		if G.add_visitor(site):
			_toast("访客簿添了新名字：%s" % site)


## 行脚商人对话里的市集入口；现货从初期可逛，首单由送盐支线解锁。
func _open_first_order_preview(site_id := "city_market") -> void:
	var trade := TradePanel.new()
	_panel = trade
	_hud.add_child(trade)
	trade.open_site(site_id)
	trade.closed.connect(func():
		if _panel == trade:
			_panel = null
		_refresh_stat())


func _open_return_job(nd: Dictionary, reply := "", selected_qid := "") -> void:
	var row := G.return_job_row(String(nd.get("id", ""))) if selected_qid.is_empty() else QuestService.side_row(G.side_quest_rows(),selected_qid)
	if not row.is_empty() and (String(row.giver)!=String(nd.get("id","")) or (not String(row.get("requires_story","")).is_empty() and not G.story_step_done(String(row.requires_story)))):return
	if row.is_empty(): return
	var qid := String(row.id)
	var status := G.side_status_of(qid)
	var content := _panel_base("归路托付",432,496)
	var task_title := G.text_label(String(row.title),G.FS_MD,Color("815326"))
	task_title.position=Vector2(8,10)
	content.add_child(task_title)
	var words := reply
	if words.is_empty():
		words = String(row.get("accept_dialogue", "")) if status.is_empty() else G.side_npc_line(String(nd.id))
		if status == QuestService.SIDE_ACTIVE: words = String(row.progress_dialogue)
		elif status == QuestService.SIDE_READY: words = String(row.ready_dialogue)
		elif status == QuestService.SIDE_DONE:
			var choice := String(QuestService.side_get(G.act1_state(),qid).get("choice", ""))
			words = String((row.get("choices", {}) as Dictionary).get(choice, {}).get("dialogue",row.completion_dialogue))
	var intro := G.text_label(words,G.FS_SM,Color("493724"))
	intro.position=Vector2(8,52)
	intro.custom_minimum_size=Vector2(384,116)
	intro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var progress := QuestService.side_get(G.act1_state(),qid)
	var caption := "未接取" if status.is_empty() else ("已完成 · 变化已留在归路上" if status == QuestService.SIDE_DONE \
		else "进度 %d/%d%s" % [int(progress.get("progress",0)),QuestService.side_need(row)," · 可交付" if status==QuestService.SIDE_READY else ""])
	var state_label := G.text_label(caption,G.FS_SM,Color("3c6070"))
	state_label.position=Vector2(8,178)
	content.add_child(state_label)
	var goal := G.text_label(String(row.objective_text),G.FS_SM,Color("493724"))
	goal.position=Vector2(8,210)
	goal.custom_minimum_size=Vector2(384,64)
	goal.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(goal)
	var rewards := G.text_label("报酬："+" · ".join(G._side_reward_toasts(row.reward)),G.FS_SM,Color("815326"))
	rewards.position=Vector2(8,282)
	rewards.custom_minimum_size=Vector2(384,62)
	rewards.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	content.add_child(rewards)
	if status.is_empty():
		_return_job_button(content,"接下这份托付",Vector2(108,350),184,func():
			var result:=G.side_accept(qid)
			if not bool(result.get("ok",false)):
				_toast("托付未能保存，请稍后再试")
				return
			_close_panel()
			_open_return_job(nd,String(result.get("line","")),qid))
	elif status == QuestService.SIDE_READY:
		var choices: Dictionary=row.get("choices",{})
		if choices.is_empty():
			_return_job_button(content,"交付 · 领取报酬",Vector2(108,350),184,func(): _finish_return_job(nd,qid,""))
		else:
			var index:=0
			for key in choices:
				var choice:=String(key)
				_return_job_button(content,String(choices[key].title),Vector2(8+index*196,350),188,
					func(): _finish_return_job(nd,qid,choice))
				index+=1
	elif status == QuestService.SIDE_ACTIVE:
		_return_job_button(content,"追踪这份托付",Vector2(108,350),184,func():
			if not G.side_track(qid):
				_toast("追踪未能保存，请稍后再试")
				return
			_close_panel()
			_open_return_job(nd,"已追踪这份托付；地图任务栏和罗盘会指向下一处目标。",qid))
	_return_job_button(content,"原有事务",Vector2(8,414),120,func():
		_close_panel()
		_open_dialog(nd,false,false))
	_return_job_button(content,"其他托付",Vector2(140,414),120,func():
		_close_panel()
		_open_npc_jobs(nd))
	_panel_back(content,414,120)
	# Keep the back button beside the original-service entry.
	(content.get_child(content.get_child_count()-1) as Control).position.x=260
	if _embedded_map!=null:
		_embedded_map.call("_refresh_quest_entities")
		_embedded_map.call("_refresh_hud")


func _open_npc_jobs(nd:Dictionary)->void:
	var content:=_panel_base("%s · 沿路托付"%String(nd.get("name","旧识")),432,552)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(8,10)
	scroll.size=Vector2(384,446)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list:=VBoxContainer.new()
	list.custom_minimum_size.x=364
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	for row in G.side_quest_rows():
		if String(row.get("giver",""))!=String(nd.get("id","")):continue
		if not String(row.get("requires_story","")).is_empty() and not G.story_step_done(String(row.requires_story)):continue
		var qid:=String(row.id)
		var status:=G.side_status_of(qid)
		var words:={"":"未接取",QuestService.SIDE_ACTIVE:"进行中",QuestService.SIDE_READY:"可交付",QuestService.SIDE_DONE:"已完成"}
		var button:=G.gold_button("%s · %s"%[String(row.title),String(words.get(status,"进行中"))],364,54,G.FS_SM)
		button.set_meta("side_job_id",qid)
		button.gui_input.connect(func(event:InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
				_close_panel()
				_open_return_job(nd,"",qid))
		list.add_child(button)
	if list.get_child_count()==0:
		var empty:=G.text_label("继续走访归路后，会有新的托付。",G.FS_SM)
		list.add_child(empty)
	_return_job_button(content,"原有事务",Vector2(8,474),176,func():
		_close_panel()
		_open_dialog(nd,false,false))
	_panel_back(content,474)
	(content.get_child(content.get_child_count()-1) as Control).position.x=260


func _return_job_button(content: Control, title: String, at: Vector2, width: float, action: Callable) -> void:
	var button:=G.gold_button(title,width,44,G.FS_SM)
	button.position=at
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			action.call())
	content.add_child(button)


func _finish_return_job(nd: Dictionary, qid: String, choice: String) -> void:
	var result:=G._side_complete(qid,true,choice)
	if result.is_empty():
		_toast("本次交付未能保存，任务与物品仍保留")
		return
	_close_panel()
	for toast in result.get("toasts",[]): _toast(String(toast))
	_open_return_job(nd,String(result.get("line","")),qid)


func _open_campaign_ending() -> void:
	var content := _panel_base("归路仍在", 432, 386)
	var intro := G.text_label(String(G.story_current().get("dialogue", "")), G.FS_SM, Color("4b351e"))
	intro.position = Vector2(8,7)
	intro.custom_minimum_size = Vector2(384,112)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var choices := [["seal", "封渊留路", "封住渊脉，留下归路碑与三地往返的名字。"],
		["echo", "留声守望", "让回声留在碑中，交由三城共同守望。"]]
	for i in choices.size():
		var row: Array = choices[i]
		var desc := G.text_label(String(row[2]), G.FS_SM, Color("3d5360"))
		desc.position = Vector2(8,129 + i*91)
		desc.custom_minimum_size = Vector2(384,42)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc)
		var button := G.gold_button(String(row[1]), 176, 44, G.FS_SM)
		button.position = Vector2(112,172 + i*91)
		button.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var result := G.story_event("talk","npc_steward",_city_id,true,{"method":String(row[0])})
				if result.is_empty():
					_toast("请带回碑心记录，并检查存档状态")
					return
				_close_panel()
				_refresh_stat()
				if _embedded_map != null: _embedded_map.call("_refresh_hud")
				_open_campaign_response("npc_steward"))
		content.add_child(button)
	_panel_back(content,330)


func _campaign_response(id: String) -> String:
	var sealed := String(G.prog.get("flags",{}).get("act4_ending","")) == "seal"
	match id:
		"npc_steward":
			return "闻叔：归路碑立稳了，渊脉也已封住。青姨替那些往返的人补上名字。远征告一段落，这些路仍归你走。" if sealed else "闻叔：碑里留下了三地的声音。我们轮流守望，让后来的人听清来路。远征告一段落，这些路仍归你走。"
		"npc_harbormaster":
			return "沈澜：封记的拓片到了。潮钟照旧报时，归路碑的名字也刻进了港簿。下一班盐船，不必再摸黑。" if sealed else "沈澜：潮钟与碑声对上了。码头把守望的日子排进港簿，旧盐道的灯会一直亮着。"
		"npc_frost_envoy":
			return "宁砚：雪关收到封记了。岑雪终于能换岗，商队带回了碑上缺失的名字。关外有归路，我们也该让人回来。" if sealed else "宁砚：守关人的号角留在碑中了。岑雪会把换岗的人记下来，三城轮值，谁都不必独守到天亮。"
	return ""


func _open_campaign_response(id: String) -> void:
	var content := _panel_base("归路仍在 · " + ("封渊留路" if String(G.prog.flags.get("act4_ending","")) == "seal" else "留声守望"),432,300)
	var intro := G.text_label(_campaign_response(id),G.FS_SM,Color("4b351e"))
	intro.position = Vector2(8,12)
	intro.custom_minimum_size = Vector2(384,112)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var note := G.text_label("三城与归路碑仍可往返。渊口外环北侧出现了无名巡界者，可自由撤退。",G.FS_SM,Color("3d5360"))
	note.position = Vector2(8,132)
	note.custom_minimum_size = Vector2(384,65)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	if id in ["npc_harbormaster","npc_frost_envoy"]:
		_return_job_button(content,"沿路托付",Vector2(8,197),176,func():
			_close_panel()
			_open_npc_jobs(G.city_npc(id)))
	if id == "npc_harbormaster":
		var services := G.gold_button("港务事务",176,44,G.FS_SM)
		services.position = Vector2(208,197)
		services.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_close_panel()
				_open_port_services())
		content.add_child(services)
	_panel_back(content,246)


func _open_abyss_boss_codex(mid := "mon_abyss_avatar") -> void:
	var content := _panel_base("深渊首领图志",432,540)
	for i in 2:
		var id: String = ["mon_abyss_avatar","mon_nameless_warden"][i]
		var tab := G.gold_button(String(TableCache.get_monster(id).get("name",id)),184,44,G.FS_SM)
		tab.position = Vector2(8+i*200,8)
		tab.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_close_panel()
				_open_abyss_boss_codex(id))
		content.add_child(tab)
	var known := (G.act1_state()["discoveries"] as Array).has(mid)
	var tex := MonsterArt.texture(mid)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(80,66)
		pic.size = Vector2(240,226)
		if not known: pic.modulate = Color(.26,.26,.31)
		content.add_child(pic)
	var info := "已记入图志 · 首胜奖励只领一次" if known else "尚未击败 · 沿主线抵达巢穴"
	info += "\n碑心 · 补齐三地碑声后可挑战\n蓄力碑震后出现破绽；击破余响可使本体失衡。\n首通保底：归路武器与碑心记录。" if mid == "mon_abyss_avatar" else "\n渊口外环北侧 · 完成归路仍在后出现\n巡界横戟后出现破绽；挑战可自由撤退。\n首胜保底：本职业巡界武器。"
	var text_l := G.text_label(info,G.FS_SM,Color("4b351e"))
	text_l.position = Vector2(8,304)
	text_l.custom_minimum_size = Vector2(384,155)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(text_l)
	_panel_back(content,486)


func _open_fourth_preparation_panel() -> void:
	var content := _panel_base("旧卷新页", 432, 354)
	var intro := G.text_label("青姨：三地拓片缺失的名字拼成了一页。先听回声，或先稳碑座，都能为后来的人留下一条归路。", G.FS_SM, Color("4b351e"))
	intro.position = Vector2(8, 7)
	intro.custom_minimum_size = Vector2(384, 64)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var choices := [
		["listen", "先听回声", "对照三地拓片，把遗漏的声音记在归路凭证上。"],
		["brace", "先稳碑座", "复核碑座的裂纹，把往返的锚点记在归路凭证上。"]]
	for i in choices.size():
		var row: Array = choices[i]
		var desc := G.text_label(String(row[2]), G.FS_SM, Color("3d5360"))
		desc.position = Vector2(12, 82 + i * 108)
		desc.custom_minimum_size = Vector2(376, 48)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc)
		var button := G.gold_button(String(row[1]), 176, 44, G.FS_SM)
		button.position = Vector2(112, 132 + i * 108)
		button.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_commit_fourth_preparation(String(row[0])))
		content.add_child(button)
	_panel_back(content, 304.0)


func _commit_fourth_preparation(method: String) -> void:
	var result := G.story_event("talk", "npc_scribe", _city_id, true, {"method": method})
	if result.is_empty():
		_toast("请带回渊口回响，并检查存档状态")
		return
	_close_panel()
	_toast("主线完成：%s · 归路凭证已入袋" % String(result.get("title", "")))
	_refresh_stat()
	if _embedded_map != null: _embedded_map.call("_refresh_hud")


func _open_frost_choice_panel() -> void:
	var content := _panel_base("双关定路", 432, 354)
	var intro := G.text_label("宁砚：两关回讯已到，只能先放一队。两种选择的任务奖励相同；供货变化会显示在驿站行情。", G.FS_SM, Color("4b351e"))
	intro.position = Vector2(8, 7)
	intro.custom_minimum_size = Vector2(384, 64)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var choices := [
		["merchant", "商货先行", "谷价约 -8%，铁料约 +5%。谷车先回驿，守关铁料下一程。"],
		["wardens", "守关补给", "铁料约 -8%，药草约 +5%。关口先换岗，商队下一程。"]]
	for i in choices.size():
		var row: Array = choices[i]
		var desc := G.text_label(String(row[2]), G.FS_SM, Color("3d5360"))
		desc.position = Vector2(12, 82 + i * 108)
		desc.custom_minimum_size = Vector2(376, 48)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc)
		var button := G.gold_button(String(row[1]), 176, 44, G.FS_SM)
		button.position = Vector2(112, 132 + i * 108)
		button.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_commit_frost_choice(String(row[0])))
		content.add_child(button)
	_panel_back(content, 304.0)


func _commit_frost_choice(method: String) -> void:
	var result := G.story_event("talk", "npc_frost_envoy", _city_id, true, {"method": method})
	if result.is_empty():
		_toast("雪幕印或存档状态尚未准备好")
		return
	_close_panel()
	_toast("主线完成：%s" % String(result.get("title", "")))
	_refresh_stat()
	if _embedded_map != null:
		_embedded_map.call("_refresh_hud")


func _open_tide_choice_panel() -> void:
	var content := _panel_base("回港定路", 432, 354)
	var intro := G.text_label("沈澜：%s。港里先修一条供货路；两选奖励相同。" % _tide_route_reply(),
		G.FS_SM, Color("4b351e"))
	intro.position = Vector2(8, 7)
	intro.custom_minimum_size = Vector2(384, 64)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var dredge := G.text_label("疏浚盐渠：港口盐价约 -8%，铁料约 +5%。盐船先走，缺铁的修船匠会抬价。",
		G.FS_SM, Color("3d5360"))
	dredge.position = Vector2(12, 82)
	dredge.custom_minimum_size = Vector2(376, 53)
	dredge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(dredge)
	var dredge_btn := G.gold_button("疏浚盐渠", 176, 40, G.FS_SM)
	dredge_btn.position = Vector2(112, 132)
	dredge_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_commit_tide_choice("dredge"))
	content.add_child(dredge_btn)
	var embank := G.text_label("加固堤道：港口谷价约 -8%，药草约 +5%。谷车先走，滩涂采药队暂缓通行。",
		G.FS_SM, Color("3d5360"))
	embank.position = Vector2(12, 190)
	embank.custom_minimum_size = Vector2(376, 53)
	embank.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(embank)
	var embank_btn := G.gold_button("加固堤道", 176, 40, G.FS_SM)
	embank_btn.position = Vector2(112, 240)
	embank_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_commit_tide_choice("embank"))
	content.add_child(embank_btn)
	_panel_back(content, 304.0)


func _tide_route_reply() -> String:
	var flags: Dictionary = G.prog.get("flags", {})
	var bridge := bool(flags.get("act2_tide_bridge_open", false))
	var cargo := bool(flags.get("act2_tide_cargo_saved", false))
	if bridge and cargo: return "栈桥与货箱都保住"
	if bridge: return "栈桥先通，货箱可再救"
	if cargo: return "货箱先上岸，栈桥可再修"
	return "潮闸已开" if G.story_step_done("s19") else "潮闸仍待处理"


func _commit_tide_choice(method: String) -> void:
	var result := G.story_event("talk", "npc_harbormaster", _city_id, true, {"method": method})
	if result.is_empty():
		_toast("账芯或存档状态尚未准备好")
		return
	_close_panel()
	_toast("主线完成：%s" % String(result.get("title", "")))
	_refresh_stat()
	if _embedded_map != null:
		_embedded_map.call("_refresh_hud")


## P05-D4：马厩实体领取首骑；真正上马由主世界 HUD 操作，避免对话关闭后瞬间碰撞。
func _open_first_mount_panel() -> void:
	var status := G.first_mount_status()
	var content := _panel_base("边城马厩", 416, 302)
	var cfg := G.first_mount_cfg()
	var mid := String(cfg.get("mount_id", "horse"))
	var art_frames := MountVisual.frames_for(G.selected_role)
	if art_frames != null:
		var art := TextureRect.new()
		art.texture = art_frames.get_frame_texture(&"walk_down", 0)
		art.position = Vector2(0, 42)
		art.custom_minimum_size = Vector2(132, 124)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(art)
	var intro := G.text_label("马伯：北路走通了，这匹马认得回城的路。", G.FS_SM, Color("3a2a14"))
	intro.position = Vector2(8, 6)
	intro.custom_minimum_size = Vector2(368, 35)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var detail := "守住断碑坡的路后，再来挑一匹行路马。"
	match status:
		"ready":
			detail = "首骑 · %s\n剧情赠送，无需金币。野外可上马，接战会下马。" % String(G.mount_cfg(mid).get("name", mid))
		"owned":
			detail = "已拥有 · %s\n主世界右下可上马／下马；进建筑与接战自动下马。" % String(G.mount_cfg(mid).get("name", mid))
	var text_l := G.text_label(detail, G.FS_SM, Color("5a4020"))
	text_l.position = Vector2(140, 53)
	text_l.custom_minimum_size = Vector2(235, 116)
	text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(text_l)
	if status == "ready":
		var claim := G.gold_button("领取首骑", 176, 42, G.FS_SM)
		claim.position = Vector2(104, 190)
		claim.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var res := G.claim_first_mount()
				if bool(res.get("ok", false)):
					_toast("首骑已结缘：%s" % String(res.get("name", "")))
					if _embedded_map != null:
						_embedded_map.call("_sync_mount_visual")
				else:
					_toast("暂时不能领取，请稍后再试")
				_close_panel()
				_open_first_mount_panel())
		content.add_child(claim)
	_panel_back(content, 246.0)


## P05-D：导师是领取 → 实战熟练 → 二选一分支的同一个实体入口，不再另开孤立菜单。
func _open_mentor_panel() -> void:
	var content := _panel_base("巡界授业", 432, 390)
	var mentor_portrait := _npc_portrait_tex("npc_mentor", false)
	if mentor_portrait != null:
		var portrait := Sprite2D.new()
		portrait.texture = mentor_portrait
		portrait.position = Vector2(45, 47)
		portrait.scale = Vector2.ONE * (78.0 / maxf(mentor_portrait.get_width(),
			mentor_portrait.get_height()))
		content.add_child(portrait)
	var role_cfg := G.mentor_role_cfg()
	var sid := G.mentor_second_skill()
	var skill_name := String(TableCache.get_skill(sid).get("name", sid))
	var status := G.mentor_status()
	var intro_text := "岳教头：先把古道上的第一场硬仗打明白，再来学第二式。"
	match status:
		"ready":
			intro_text = "岳教头：第一式已站稳脚跟。现在教你「%s」，领悟后去野外真正用中一次。" % skill_name
		"practice":
			var mastery := int((G.mentor_state()["mastery"] as Dictionary).get(sid, 0))
			var need := maxi(1, int(G.mentor_cfg().get("mastery_target", 1)))
			intro_text = "岳教头：会按招式不算会用。让「%s」产生真实效果，再回来谈分支。\n熟练 %d/%d" % [skill_name, mastery, need]
		"choose":
			intro_text = "岳教头：这一式已经用活了。选一条路，改变它的消耗、节奏与效果。"
		"chosen":
			var choice := String((G.mentor_state()["variants"] as Dictionary).get(sid, ""))
			var vars: Dictionary = role_cfg.get("variants", {})
			var chosen: Dictionary = vars.get(choice, {})
			intro_text = "岳教头：你为「%s」选了【%s】。\n%s" % [skill_name,
				String(chosen.get("name", choice)), String(chosen.get("desc", ""))]
	var intro := G.text_label(intro_text, G.FS_SM, Color("3a2a14"))
	intro.position = Vector2(94, 8) if mentor_portrait != null else Vector2(8, 8)
	intro.custom_minimum_size = Vector2(290, 80) if mentor_portrait != null else Vector2(384, 80)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)

	if status == "ready":
		var learn := G.gold_button("领悟 · %s" % skill_name, 190, 42, G.FS_SM)
		learn.position = Vector2(101, 118)
		learn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var res := G.mentor_unlock_second()
				if bool(res.get("ok", false)):
					_toast("已解锁第二技能：%s" % String(res.get("name", skill_name)))
				_close_panel()
				_open_mentor_panel())
		content.add_child(learn)
	elif status == "choose":
		var variants: Dictionary = role_cfg.get("variants", {})
		var keys := variants.keys()
		for i in mini(2, keys.size()):
			var key := String(keys[i])
			var row := variants[key] as Dictionary
			var desc := G.text_label("【%s】%s" % [String(row.get("name", key)), String(row.get("desc", ""))],
				G.FS_XS, Color("4b351e"))
			desc.position = Vector2(8, 102 + i * 92)
			desc.custom_minimum_size = Vector2(384, 38)
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(desc)
			var choose := G.gold_button("选择 · %s" % String(row.get("name", key)), 176, 38, G.FS_SM)
			choose.position = Vector2(108, 145 + i * 92)
			choose.gui_input.connect(Callable(self, "_mentor_choice_input").bind(key))
			content.add_child(choose)
	elif status == "chosen":
		var cost := int(G.mentor_cfg().get("reset_cost_gold", 120))
		var reset := G.gold_button("重置分支 · %d 金" % cost, 190, 42, G.FS_SM)
		reset.position = Vector2(101, 138)
		if int(G.wallet.get("gold", 0)) < cost:
			reset.modulate = Color(0.62, 0.62, 0.62)
		reset.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var res := G.mentor_reset_variant()
				if bool(res.get("ok", false)):
					_toast("已重置，可重新选择分支")
				else:
					_toast("金币不足，暂时不能重置")
				_close_panel()
				_open_mentor_panel())
		content.add_child(reset)
	var later := G.gold_button("研习后续招式", 210, 44, G.FS_SM)
	later.position = Vector2(91, 278)
	later.set_meta("curriculum_action", "open")
	later.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel()
			_open_curriculum_panel())
	content.add_child(later)
	_panel_back(content, 330.0)

func _curriculum_reason(sid: String) -> String:
	var entry := MentorCurriculum.row(sid)
	match MentorCurriculum.status(G, sid):
		"level": return "需要等级 %d" % int(entry.level)
		"story": return "先完成：%s" % _curriculum_story_name(String(entry.after))
		"previous": return "先学会「%s」" % String(TableCache.get_skill(String(entry.previous)).get("name", entry.previous))
		"ready": return "可学习 · %d 金" % int(entry.gold)
		"practice": return "已学会 · 熟练 %d/%d" % [int(MentorCurriculum.state(G.prog).mastery.get(sid, 0)), int(entry.mastery_target)]
		"choose": return "熟练已满 · 可选分支"
		"chosen": return "分支：%s" % String(entry.variants[MentorCurriculum.state(G.prog).variants[sid]].name)
	return "暂不可学习"

func _curriculum_story_name(step_id: String) -> String:
	return String(QuestService.step_by_id(TableCache.story_quests_config().get("steps", []), step_id).get("title", step_id))

func _curriculum_text(content: Control, text: String, pos: Vector2, extent: Vector2, small := false) -> void:
	var label := G.text_label(text, G.FS_XS if small else G.FS_SM, Color("3a2a14"))
	label.position = pos
	label.custom_minimum_size = extent
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)

func _open_curriculum_panel() -> void:
	var content := _panel_base("巡界授业 · 后续三式", 432, 528)
	_curriculum_text(content, "岳教头：依序学招，在实战里用活它。", Vector2(8, 8), Vector2(384, 32))
	var entries := MentorCurriculum.rows(G.selected_role)
	for i in entries.size():
		var sid := String(entries[i].id)
		var skill := TableCache.get_skill(sid)
		var y := 48.0 + i * 128.0
		_curriculum_text(content, "第%d式 · %s" % [i + 3, String(skill.name)], Vector2(8, y), Vector2(384, 26))
		_curriculum_text(content, "%s；能量 %d · 冷却 %s秒" % [String(skill.get("desc", "")), int(skill.cost), str(skill.cd)], Vector2(8, y + 28), Vector2(384, 36), true)
		_curriculum_text(content, _curriculum_reason(sid), Vector2(8, y + 74), Vector2(228, 44), true)
		var go := G.gold_button("查看 / 研习", 144, 44, G.FS_SM)
		go.position = Vector2(240, y + 74)
		go.set_meta("curriculum_action", "detail")
		go.set_meta("curriculum_skill", sid)
		go.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_close_panel()
				_open_curriculum_skill(sid))
		content.add_child(go)
	_panel_back(content, 456.0)

func _curriculum_action_button(content: Control, sid: String, action: String, choice: String, text: String, y: float) -> void:
	var button := G.gold_button(text, 240, 44, G.FS_SM)
	button.position = Vector2(76, y)
	button.set_meta("curriculum_action", action)
	button.set_meta("curriculum_skill", sid)
	button.set_meta("curriculum_choice", choice)
	button.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var result := G.curriculum_apply(sid, action, choice)
			if bool(result.ok):
				_toast("招式已保存")
			else:
				var reason := String(result.get("reason", ""))
				_toast("金币不足" if reason == "gold" else ("未能写入存档，请重试" if reason == "save_failed" else "当前条件未满足"))
			_close_panel()
			_open_curriculum_skill(sid))
	content.add_child(button)

func _open_curriculum_skill(sid: String) -> void:
	var entry := MentorCurriculum.row(sid)
	var skill := TableCache.get_skill(sid)
	var content := _panel_base(String(skill.name) + " · 研习", 432, 496)
	_curriculum_text(content, "%s\n基础：能量 %d · 冷却 %s秒" % [String(skill.get("desc", "")), int(skill.cost), str(skill.cd)], Vector2(8, 8), Vector2(384, 56))
	_curriculum_text(content, "等级 %d · 完成%s\n先学「%s」 · 学费 %d 金" % [int(entry.level), _curriculum_story_name(String(entry.after)), String(TableCache.get_skill(String(entry.previous)).name), int(entry.gold)], Vector2(8, 76), Vector2(384, 56), true)
	_curriculum_text(content, _curriculum_reason(sid), Vector2(8, 140), Vector2(384, 34))
	var status := MentorCurriculum.status(G, sid)
	if status == "ready":
		_curriculum_action_button(content, sid, "learn", "", "学习 · %d 金" % int(entry.gold), 220)
	elif status == "choose":
		var choices: Array = entry.variants.keys()
		for i in choices.size():
			var choice := String(choices[i])
			var variant: Dictionary = entry.variants[choice]
			_curriculum_text(content, "【%s】%s" % [String(variant.name), String(variant.desc)], Vector2(8, 186 + i * 110), Vector2(384, 44), true)
			_curriculum_action_button(content, sid, "choose", choice, "选择 · " + String(variant.name), 232 + i * 110)
	elif status == "chosen":
		var variant: Dictionary = entry.variants[MentorCurriculum.state(G.prog).variants[sid]]
		_curriculum_text(content, String(variant.desc), Vector2(8, 192), Vector2(384, 62))
		_curriculum_action_button(content, sid, "reset", "", "重置分支 · 120 金", 280)
	else:
		_curriculum_text(content, "实战有效使用 %d 场后选分支。\n同一遭遇只计一次，空放不增长熟练。" % int(entry.mastery_target), Vector2(8, 206), Vector2(384, 74))
	var back := G.gold_button("返回招式表", 180, 44, G.FS_SM)
	back.position = Vector2(106, 432)
	back.set_meta("curriculum_action", "back")
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel()
			_open_curriculum_panel())
	content.add_child(back)


func _mentor_choice_input(e: InputEvent, key: String) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var res := G.mentor_choose_variant(key)
	if bool(res.get("ok", false)):
		_toast("专精已定：%s" % String(res.get("name", key)))
	_close_panel()
	_open_mentor_panel()


## P05-D2：s04 后由兽栏实体承接伙伴领取。展示、确认、写档在同一面板完成，
## 不把关键成长节点藏在主页菜单或无条件启动赠送里。
func _open_rockturtle_panel() -> void:
	var content := _panel_base("兽栏结缘", 432, 430)
	var pet_tex := G.res_tex("pet_rockturtle")
	if pet_tex != null:
		var halo := Panel.new()
		halo.position = Vector2(136, 14)
		halo.size = Vector2(128, 128)
		var halo_style := StyleBoxFlat.new()
		halo_style.bg_color = Color("4c6a45", 0.16)
		halo_style.border_color = Color("9a7437", 0.76)
		halo_style.set_border_width_all(2)
		halo_style.set_corner_radius_all(64)
		halo.add_theme_stylebox_override("panel", halo_style)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(halo)
		var pic := TextureRect.new()
		pic.texture = pet_tex
		pic.position = Vector2(8, 8)
		pic.size = Vector2(112, 112)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.add_child(pic)

	var name_l := G.serif_label("岩 龟", G.FS_LG, Color("744c21"))
	name_l.position = Vector2(0, 148)
	name_l.custom_minimum_size = Vector2(400, 32)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_l)
	var desc := G.text_label("阿豆：它总在门边等你。背甲很沉，脚步却稳；\n带它出城，它会跟在身后，也会与你一同接战。",
		G.FS_SM, Color("3a2a14"))
	desc.position = Vector2(22, 190)
	desc.custom_minimum_size = Vector2(356, 62)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)
	var trait_l := G.gold_label("守御伙伴 · 近战 · 冲撞", G.FS_SM, false, Color("6b512c"), false)
	trait_l.position = Vector2(0, 260)
	trait_l.custom_minimum_size = Vector2(400, 26)
	content.add_child(trait_l)

	var claim := G.gold_button("结 缘 · 带它同行", 210, 46, G.FS_SM)
	claim.position = Vector2(95, 304)
	claim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var res := G.claim_rockturtle()
			if bool(res.get("ok", false)):
				if _embedded_map != null:
					_embedded_map.st.active_pet = "pet_rockturtle"
					_embedded_map.call("_sync_world_companion")
				_toast("伙伴加入：岩龟")
			else:
				_toast("结缘未完成，请稍后再试")
			_close_panel())
	content.add_child(claim)
	_panel_back(content, 362.0)


## P07-D：港口兽栏的首枚宠物蛋。剧情给来源，购买给重复孵化的材料出口。
func _open_port_services() -> void:
	var content := _panel_base("沈澜 · 港务人", 432, 390)
	var stage := int((G.prog.get("flags", {}) as Dictionary).get("act2_shenlan_relation_stage", 0))
	var intro := G.text_label("港里的船照潮位走，账要一页一页核。\n%s。备齐实物可托船运出。\n\n关系：%s" % [_tide_route_reply(), "潮声旧账 · 已完成" if stage >= 1 else "尚未深谈"], G.FS_SM, Color("493724"))
	intro.position = Vector2(20, 24)
	intro.custom_minimum_size = Vector2(380, 120)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var ship := G.gold_button("查看船运订单", 220, 40, G.FS_SM)
	ship.position = Vector2(92, 144)
	ship.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel()
			_open_shipping_panel())
	content.add_child(ship)
	var talk := G.gold_button("潮声旧账 · 谈谈", 220, 40, G.FS_SM)
	talk.position = Vector2(92, 202)
	talk.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if not G.story_step_done("s20"):
				_toast("先处理潮闸并回港定路")
				return
			_close_panel()
			_open_port_relation())
	content.add_child(talk)
	_port_side_button(content, "npc_harbormaster", Vector2(92, 256))
	_panel_back(content, 332.0)


func _port_side_button(content: Control, npc_id: String, at: Vector2) -> void:
	var button := G.gold_button("本人的托付 · 支线", 220, 44, G.FS_SM)
	button.position = at
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_panel()
			_open_port_side_panel(npc_id))
	content.add_child(button)


func _open_port_side_panel(npc_id: String, reply := {}) -> void:
	var action := QuestService.side_npc_action(G.act1_state(), G._side_live_rows(), npc_id) if reply.is_empty() else {}
	var qid := String(reply.get("qid", action.get("qid", "")))
	var row := QuestService.side_row(G.side_quest_rows(), qid)
	var choices: Dictionary = row.get("choices", {})
	var choosing := String(action.get("kind", "")) == "turn_in" and not choices.is_empty()
	var result := reply if not reply.is_empty() else ({} if choosing else G.side_npc_interact(npc_id))
	var line := String(row.get("ready_dialogue", "")) if choosing else String(result.get("line", G.side_npc_line(npc_id)))
	if line.is_empty():
		line = "找回矿道记录后，可以来问霜关的托付。已完成的事不会重复发奖。" if _city_id == "frost_post" \
			else "把盐车账页交给沈澜后，可以来问港口的托付。已完成的事不会重复发奖。"
	var content := _panel_base("%s · 托付" % String(G.city_npc(npc_id).get("name", "港口人")), 432, 456)
	var label := G.text_label(line, G.FS_SM, Color("493724"))
	label.position = Vector2(20, 22)
	label.custom_minimum_size = Vector2(380, 100)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	var details := G.text_label("\n".join(G.side_info_lines(qid)) if not qid.is_empty() else "已接任务可在图志中切换追踪。", G.FS_SM, Color("493724"))
	details.position = Vector2(20, 126)
	details.custom_minimum_size = Vector2(380, 176)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(details)
	if choosing:
		var index := 0
		for key in choices:
			var choice := String(key)
			var option: Dictionary = choices[key]
			var button := G.gold_button(String(option.get("title", choice)), 184, 44, G.FS_SM)
			button.position = Vector2(12 + index * 194, 312)
			button.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					var completed := G._side_complete(qid, true, choice)
					if completed.is_empty():
						_toast("本次未能保存，托付仍待交付")
						return
					_close_panel()
					_toast(String(completed.get("line", "托付完成")))
					_open_port_side_panel(npc_id, completed))
			content.add_child(button)
			index += 1
	for toast in result.get("toasts", []): _toast(String(toast))
	if _embedded_map != null:
		_embedded_map.call("_refresh_quest_entities")
		_embedded_map.call("_refresh_hud")
	_panel_back(content, 396.0)


func _open_port_relation() -> void:
	var content := _panel_base("潮声旧账", 432, 420)
	var flags: Dictionary = G.prog.get("flags", {})
	var finished := int(flags.get("act2_shenlan_relation_stage", 0)) >= 1
	var words := "沈澜翻开旧账，里面夹着一封未寄出的家书。\n\n“从前我只信账上的数。潮闸关了以后，有些人的名字就再也没回来。”\n\n她把一枚磨平的石头放在桌边。\n“船可以晚一日，等船的人不能永远等下去。”\n\n完成这段谈话：防御宝石Ⅰ ×1，经验 +20。"
	if finished:
		words = "沈澜收起旧账，记得上次与你的谈话。\n\n“%s”\n\n关系第一段已完成，潮闸与船单仍可照常处理。\n宝石已入背包，在营帐的工坊宝石页选择护甲镶嵌：200 铜钱，防御 +2；可免费拆回。" % ("那些名字，我会好好记住。" if String(flags.get("act2_shenlan_relation_choice", "")) == "remember" else "下次开船前，我会先去渡口看看等船的人。")
	var label := G.text_label(words, G.FS_SM, Color("493724"))
	label.position = Vector2(20, 22)
	label.custom_minimum_size = Vector2(380, 268)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	if not finished:
		for i in 2:
			var choice := "remember" if i == 0 else "promise"
			var button := G.gold_button("记住那些名字" if i == 0 else "下次一起去渡口", 184, 42, G.FS_SM)
			button.position = Vector2(12 + i * 194, 304)
			button.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					var result := G.port_relation_choice(choice)
					_toast("关系推进 · 防御宝石Ⅰ ×1" if bool(result.get("ok", false)) else String(result.get("err", "未完成")))
					_close_panel()
					_open_port_relation()
					_refresh_stat())
			content.add_child(button)
	_panel_back(content, 366.0)


func _open_shipping_panel(order_id := "salt_ship") -> void:
	var content := _panel_base("港务船单", 432, 540)
	var info := G.shipping_order(order_id)
	for i in 2:
		var route_id := "salt_ship" if i == 0 else "herb_ship"
		var route := G.shipping_config(route_id)
		var tab := G.gold_button(String(route.get("name", "船单")), 184, 38, G.FS_SM) if route_id == order_id \
			else G.ghost_button(String(route.get("name", "船单")), 184, 38, G.FS_SM)
		tab.position = Vector2(12 + i * 194, 16)
		tab.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_close_panel()
				_open_shipping_panel(route_id))
		content.add_child(tab)
	var status := String(info.get("status", "locked"))
	var status_names := {"locked": "交清盐路账页后开放", "available": "可以接单", "active": "等待备货装船",
		"expired": "备货期限已过，可重新接单", "transit": "货船在途", "ready": "已到港，等待领取", "done": "本日已完成，明日可再接"}
	var cargo_lines: Array[String] = []
	for gid in (info.get("cargo", {}) as Dictionary):
		cargo_lines.append("%s  %d / %d" % [G.item_name(String(gid)), G.item_count(String(gid)), int(info["cargo"][gid])])
	var timing := "接单后 %d 日内备货，装船后 %d 日到港。" % [int(info.get("deadline_days", 3)), int(info.get("travel_days", 1))]
	if status == "active": timing = "当前第 %d 日 · 最迟第 %d 日装船" % [int(info["day"]), int(info["deadline_day"])]
	if status in ["transit", "ready"]: timing = "当前第 %d 日 · 第 %d 日到港" % [int(info["day"]), int(info["arrival_day"])]
	var aid_line := String(info.get("route_aid_note", ""))
	if bool(info.get("aid_applied", false)):
		aid_line = "路障已处理，运费折让已计入本批船单"
	var body := "%s\n\n备货（持有 / 所需）\n%s\n\n到手 %d 铜钱 · 已扣运费 %d\n采购参考 %d · 预计净收益 %d\n经验 +%d\n\n%s\n%s\n接单锁定报酬；市集歇脚推进游戏日。" % [
		String(status_names.get(status, status)), "\n".join(cargo_lines), int(info.get("payout_gold", 0)),
		int(info.get("freight_gold", 0)), int(info.get("purchase_gold", 0)), int(info.get("expected_profit_gold", 0)),
		int(info.get("reward_exp", 0)), timing, aid_line]
	var label := G.text_label(body, G.FS_SM, Color("493724"))
	label.custom_minimum_size = Vector2(358, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reading := ScrollContainer.new()
	reading.name = "ShippingDetails"
	reading.position = Vector2(20, 72)
	reading.size = Vector2(374, 324)
	reading.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var scroll_track := Journal.surface(Color("5b4435", 0.12), Color.TRANSPARENT, 0)
	scroll_track.set_content_margin_all(3)
	var scroll_grip := Journal.surface(Color("a68b63"), Color.TRANSPARENT, 0)
	scroll_grip.set_content_margin_all(3)
	var scrollbar := reading.get_v_scroll_bar()
	scrollbar.add_theme_stylebox_override("scroll", scroll_track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(state, scroll_grip)
	reading.add_child(label)
	content.add_child(reading)
	var actions := {"available": "接取船单", "expired": "重新接单", "active": "交货装船", "ready": "领取报酬"}
	if actions.has(status):
		var button := G.gold_button(String(actions[status]), 220, 42, G.FS_SM)
		button.name = "ShippingAction"
		button.position = Vector2(92, 414)
		button.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var result: Dictionary
				match status:
					"active": result = G.shipping_dispatch(order_id, "shenyuan_market")
					"ready": result = G.shipping_claim(order_id, "shenyuan_market")
					_: result = G.shipping_accept(order_id, "shenyuan_market")
				var messages := {"active": "货物已装船，明日到港", "ready": "船单报酬已入账"}
				_toast(String(messages.get(status, "已接单，请备齐实物")) if bool(result.get("ok", false)) else String(result.get("err", "未完成")))
				_close_panel()
				_open_shipping_panel(order_id)
				_refresh_stat())
		content.add_child(button)
	_panel_back(content, 474.0)


func _open_tide_hatch_panel() -> void:
	var content := _panel_base("潮羽孵化", 432, 488)
	var egg_count := G.item_count("tide_egg")
	var owned := G.owns_pet("pet_tide_gull")
	var egg_tex := G.res_tex("itm_tide_egg")
	var pet_tex := G.res_tex("pet_tide_gull")
	for pic_data in [
		{"tex": egg_tex, "x": 55.0}, {"tex": pet_tex, "x": 267.0}
	]:
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.texture = pic_data["tex"] as Texture2D
		pic.position = Vector2(float(pic_data["x"]), 14)
		pic.custom_minimum_size = Vector2(100, 100)
		pic.size = Vector2(100, 100)
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.clip_contents = true
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(pic)
		pic.size = Vector2(100, 100)
	var heading := G.serif_label("潮纹蛋  →  潮羽雏鸥", G.FS_MD, Color("76502b"))
	heading.position = Vector2(14, 120)
	heading.custom_minimum_size = Vector2(388, 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var status := "已结缘 · 再孵化得宠物粮 ×2" if owned else "未结缘 · 孵化后可随行接战"
	var info := G.text_label("持有潮纹蛋 %d 枚   ·   %s\n阿棠：港务交账后可领首枚，余下的在兽栏购入。" % [egg_count, status],
		G.FS_SM, Color("493724"))
	info.position = Vector2(20, 163)
	info.custom_minimum_size = Vector2(380, 74)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	if not G.story_step_done("s16"):
		var locked := G.text_label("先把盐车账页交给港务人，再来孵化。", G.FS_SM, Color("7a5a3a"))
		locked.position = Vector2(20, 266)
		locked.custom_minimum_size = Vector2(380, 42)
		content.add_child(locked)
	else:
		if not bool((G.prog.get("flags", {}) as Dictionary).get("act2_port_egg_claimed", false)):
			var gift := G.gold_button("领港务赠蛋 · 免费", 202, 38, G.FS_SM)
			gift.position = Vector2(99, 232)
			gift.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					var res := G.port_egg_claim()
					_toast("得到潮纹蛋 ×1" if bool(res.get("ok", false)) else "赠蛋已领取")
					_close_panel()
					_open_tide_hatch_panel())
			content.add_child(gift)
		var hatch := G.gold_button("孵 化 · 消耗 1 枚", 184, 44, G.FS_SM)
		hatch.position = Vector2(12, 280)
		hatch.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var res := G.port_egg_hatch()
				if bool(res.get("ok", false)):
					_toast("重复孵化 · 宠物粮 ×2" if bool(res.get("duplicate", false)) else "伙伴加入 · 潮羽雏鸥")
				else:
					_toast("没有可孵化的潮纹蛋")
				_close_panel()
				_open_tide_hatch_panel())
		content.add_child(hatch)
		var buy := G.gold_button("购 蛋 · 500 铜钱", 184, 44, G.FS_SM)
		buy.position = Vector2(206, 280)
		buy.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var res := G.port_egg_buy()
				_toast("购入潮纹蛋 ×1" if bool(res.get("ok", false)) else "铜钱不足或暂不能购买")
				_close_panel()
				_open_tide_hatch_panel())
		content.add_child(buy)
	_port_side_button(content, "npc_port_keeper", Vector2(92, 338))
	_panel_back(content, 414.0)


## P05-A：石头只提出两条修碑方法；玩家点选并付得起材料时才推进 s11。
func _open_repair_panel() -> void:
	var content := _panel_base("缺页回炉", 432, 360)
	var intro := G.text_label("石头：旧铁扣能锁住碑片。你想先锻合，还是请青姨拓录？",
		G.FS_SM, Color("3a2a14"))
	intro.position = Vector2(8, 8)
	intro.custom_minimum_size = Vector2(384, 54)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var frag := G.item_count("stele_fragment")
	var refine := G.item_count("refine_stone")
	var gold := int(G.wallet.get("gold", 0))
	var a := G.text_label("锻合 · 碑文碎片 1 / %d，精炼石 2 / %d\n稳固旧铁扣，修复后开放北路线索。" % [frag, refine],
		G.FS_SM, Color("4b351e"))
	a.position = Vector2(12, 68)
	a.custom_minimum_size = Vector2(376, 57)
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(a)
	var forge := G.gold_button("用精炼石锻合", 176, 40, G.FS_SM)
	forge.position = Vector2(110, 132)
	if frag < 1 or refine < 2:
		forge.modulate = Color(0.62, 0.62, 0.62)
	forge.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_commit_repair("forge"))
	content.add_child(forge)
	var b := G.text_label("拓录 · 碑文碎片 1 / %d，金币 120 / %d\n请青姨记下碑名，修复后开放同一条北路。" % [frag, gold],
		G.FS_SM, Color("4b351e"))
	b.position = Vector2(12, 182)
	b.custom_minimum_size = Vector2(376, 57)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(b)
	var scribe := G.gold_button("花金币拓录", 176, 40, G.FS_SM)
	scribe.position = Vector2(110, 245)
	if frag < 1 or gold < 120:
		scribe.modulate = Color(0.62, 0.62, 0.62)
	scribe.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_commit_repair("scribe"))
	content.add_child(scribe)
	var later := G.gold_button("暂不修复", 128, 36, G.FS_SM)
	later.position = Vector2(134, 301)
	later.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel())
	content.add_child(later)


func _commit_repair(method: String) -> void:
	var result := G.story_event("craft", "npc_smith", "lorin_wilds", true,
		{"method": method})
	if result.is_empty():
		_toast("材料不足，碑文尚未修复")
		return
	_close_panel()
	_toast("碑文已修复 · 主线完成：%s" % String(result.get("title", "")))
	_refresh_stat()
	if _embedded_map != null:
		_embedded_map.call("_refresh_hud")


func _show_dialog_line() -> void:
	var line: Label = _dlg.get("line", null)
	if line == null:
		return
	var txt := ""
	if bool(_dlg.get("guest", false)):
		var lines: Array = (_dlg.get("data", {}) as Dictionary).get("lines", [])
		if not lines.is_empty():
			txt = String(lines[int(_dlg.get("turn", 0)) % lines.size()])
	else:
		if int(_dlg.get("turn", 0)) == 0:
			txt = String(_dlg.get("story_dialogue", ""))
			if txt.is_empty() and bool((G.prog.get("flags", {}) as Dictionary).get("act1_stele_repaired", false)):
				var method := String((G.prog.get("act1", {}) as Dictionary).get("repair_method", ""))
				match String(_dlg.get("id", "")):
					"npc_smith":
						txt = "铁扣已锻稳，北路的碑名终于能看清了。" if method == "forge" else "青姨的拓片对上了，北路的碑名终于能看清了。"
					"npc_scribe":
						txt = "修碑时先留下拓片，图志阁如今多了一页。" if method == "scribe" else "修好的碑文送来一份摹本，图志阁如今多了一页。"
		# 支线台词优先于每日委托与闲聊（P05-B）：接取/交付当次 → 该 NPC 的支线态台词
		if txt == "" and int(_dlg.get("turn", 0)) == 0:
			txt = String(_dlg.get("side_line", ""))
		# P05-C：闻叔首胜后的新台词（世界旗 act1_lost_beast_down 同步变化）。
		# 排在支线当次台词之后：交付那一句该说 ready_dialogue，不抢它的位置。
		if txt == "" and int(_dlg.get("turn", 0)) == 0 \
				and String(_dlg.get("id", "")) == "npc_steward" \
				and bool((G.prog.get("flags", {}) as Dictionary).get("act1_lost_beast_down", false)):
			txt = "路西的兽影散了——碑坡那边的路，如今走得安心。"
		if int(_dlg.get("turn", 0)) == 0 \
				and String(_dlg.get("id", "")) == "npc_frost_miner" \
				and bool((G.prog.get("flags", {}) as Dictionary).get("frost_herb_first_done", false)):
			var herb_record: Dictionary = (G.economy_state().get("orders", {}) as Dictionary).get("frost_herb_supply", {})
			var delivery_line := "药箱绕旧驿到了，药架终于有货；多走的路没白费。" \
				if String(herb_record.get("route", "")) == "safe" else \
				"药箱穿过风沙近路到了，药架终于有货；今晚能替伤员换药。"
			txt = delivery_line + ("\n" + txt if not txt.is_empty() else "")
		if txt == "":
			txt = G.side_npc_line(String(_dlg.get("id", "")))
		if txt == "" and int(_dlg.get("turn", 0)) == 0 and String(_dlg.get("id", "")) == "npc_frost_miner" \
				and bool(G.prog.get("flags", {}).get("act3_mine_rooms_v1", false)) \
				and bool(G.prog.get("flags", {}).get("act3_mine_switch", false)):
			txt = "两座风轮排清了烟，北轨的矿车把我们都带了出来。三顶工帽留在入口，轮岗簿上也记着人名。"
		if txt == "" and int(_dlg.get("turn", 0)) == 0 \
				and bool((G.prog.get("flags", {}) as Dictionary).get("act1_stele_repaired", false)):
			var repair_method := String(G.act1_state().get("repair_method", ""))
			match String(_dlg.get("id", "")):
				"npc_steward":
					txt = "石头锻稳了%s，北路供货终于能走直道。" % G.restored_stele_name() \
						if repair_method == "forge" else "青姨拓出了%s旧文，商队照着路标绕开塌方。" % G.restored_stele_name()
				"npc_warden":
					txt = "锻合后坡口更稳，往北运货省了些脚力。" if repair_method == "forge" \
						else "拓片标出了旧路，送往断碑坡的供货不再摸黑。"
		# 身上挂着今日委托的发布者，第一句先说委托（接了/办完/交过口吻不同）
		if txt == "" and int(_dlg.get("turn", 0)) == 0:
			txt = G.npc_quest_line(String(_dlg.get("id", "")))
		if txt == "":
			txt = G.npc_line(String(_dlg.get("id", "")), int(_dlg.get("turn", 0)))
		if int(_dlg.get("turn",0)) == 1:
			var trust_line := preload("res://src/world/RegionalTrust.gd").npc_line(G,String(_dlg.get("id","")))
			if not trust_line.is_empty(): txt = trust_line
	line.text = txt
	_layout_dialogue.call_deferred()
	G.type_text(line)
	var id := String(_dlg.get("id", ""))
	_talk_turns[id] = int(_dlg.get("turn", 0)) + 1


## Keep the complete wrapped sentence above a separate footer, anchored to the bottom.
func _layout_dialogue() -> void:
	var line: Label = _dlg.get("line", null)
	var paper: Control = _dlg.get("paper", null)
	var hint: Label = _dlg.get("hint", null)
	if not is_instance_valid(line) or not is_instance_valid(paper) or not is_instance_valid(hint):
		return
	var body_h := maxf(76.0, line.get_minimum_size().y)
	line.size.y = body_h
	var footer_y := line.position.y + body_h + 14.0
	hint.position.y = footer_y
	var market: Control = _dlg.get("market", null)
	if is_instance_valid(market): market.position.y = footer_y - 8.0
	var panel_h := footer_y + (50.0 if is_instance_valid(market) else 42.0)
	paper.custom_minimum_size = Vector2(432, panel_h)
	paper.size = paper.custom_minimum_size
	var safe:=G.ui_safe_rect(self)
	paper.position.y = safe.end.y - panel_h - 40.0
	_place_dialogue_toast()


func _place_dialogue_toast() -> void:
	if not is_instance_valid(_toast_lbl) or _toast_lbl.is_queued_for_deletion(): return
	var paper: Control = _dlg.get("paper", null)
	if is_instance_valid(paper):
		_toast_lbl.position.y = minf(_toast_lbl.position.y, paper.position.y - _toast_lbl.size.y - 14.0)


func _advance_dialog() -> void:
	if _dlg.is_empty():
		return
	var line: Label = _dlg.get("line",null)
	if line != null and G.finish_text(line): return
	_dlg["turn"] = int(_dlg.get("turn", 0)) + 1
	_show_dialog_line()


# ================= 复用面板（世界 / 图鉴 / 出征） =================
func _open_worlds() -> void:
	if _overlay != null:
		return
	Audio.sfx("ui_open")
	var p := RegionMapPanel.new()
	_overlay = p
	p.closed.connect(_close_overlay)
	_hud.visible = false  # 全屏面板期间藏起城内 HUD，免得双层标题/摇杆穿帮
	_overlay_layer.add_child(p)


func _open_codex() -> void:
	if _overlay != null:
		return
	Audio.sfx("ui_open")
	var p := CodexPanel.new()
	_overlay = p
	p.closed.connect(_close_overlay)
	_hud.visible = false
	_overlay_layer.add_child(p)


## 物资铺（锻造铺落成后开放；P1-2 的金币出口）
func _open_shop() -> void:
	if _overlay != null:
		return
	Audio.sfx("ui_open")
	var p: Control = (load("res://src/ui/ShopPanel.gd") as GDScript).new()
	_overlay = p
	p.closed.connect(_close_overlay)
	_hud.visible = false
	_overlay_layer.add_child(p)


func _open_deploy() -> void:
	if not (G.prog.get("active_run", {}) as Dictionary).is_empty():
		RouteScene.pending_run = {"resume": true}
		G.go("res://src/run/RouteScene.tscn")
		return
	if _overlay != null:
		return
	Audio.sfx("ui_open")
	var p := DeployPanel.new()
	_overlay = p
	p.confirmed.connect(func(cfg: Dictionary):
		RouteScene.pending_run = cfg
		G.go("res://src/run/RouteScene.tscn"))
	p.canceled.connect(_close_overlay)
	_hud.visible = false
	_overlay_layer.add_child(p)


## 委托板（与 世界/图鉴/出征 同为全屏浮层）
func _open_quests() -> void:
	if _overlay != null:
		return
	var p := QuestPanelScript.new()   # QuestPanel 自己在 _ready 里响开层音
	_overlay = p
	p.closed.connect(_close_overlay)
	_hud.visible = false   # 全屏面板期间藏起城内 HUD，免得双层标题/摇杆穿帮
	_overlay_layer.add_child(p)


func _close_overlay() -> void:
	Audio.sfx("ui_close")
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_hud.visible = true
	_refresh_stat()   # 委托进度小签要跟着刷新（刚交付完）


# ================= 退出 =================
func _go_home() -> void:
	G.go("res://src/ui/GameHome.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _embedded_map != null and _overlay == null and _panel == null:
		return
	# 先拿 viewport：_go_home() 会触发切场景，本节点离场后 get_viewport() 返回 null
	var vp := get_viewport()
	if _overlay != null:
		_close_overlay()
	elif _panel != null:
		if _panel is TradePanel:
			(_panel as TradePanel).close()
		else:
			_close_panel()
	else:
		_go_home()
	if vp != null:
		vp.set_input_as_handled()


# ================= 局部节点 =================
## 散件（与 MapScene 同款：origin 底部 + 脚部碰撞，参与 Y-sort）
class _Deco extends StaticBody2D:
	func setup(tex: Texture2D, s: float) -> void:
		collision_layer = 2
		collision_mask = 0
		if tex == null:
			return
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.scale = Vector2.ONE * s
		spr.offset = Vector2(0, -tex.get_height() / 2.0)
		add_child(spr)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40.0 * s, 26.0)
		shape.shape = rect
		shape.position = Vector2(0, -13.0)
		add_child(shape)


## 城内建筑：程序绘制（按 style 分支），未落成的是圈起来的工地
class _Building extends StaticBody2D:
	const Grounding := preload("res://src/world/BuildingGrounding.gd")
	const TIMBER := Color("6b4a28")
	const TIMBER_D := Color("4a3018")
	const PLASTER := Color("e0d0ac")
	const STONE := Color("8a8578")
	const STONE_D := Color("6a655a")

	var data: Dictionary = {}
	var hover := false
	var cooled := false
	var _t := 0.0
	var _w := 96.0
	var _h := 96.0
	# 成品建筑贴图（256×192 等距像素楼）。有贴图就画贴图，缺图退回程序绘制——
	# 这样新素材到位时立刻生效，将来某张图缺失也不会让那座楼凭空消失。
	var art: Texture2D = null
	var _reference_art := false
	var _grounding: Dictionary = {}
	const REFERENCE_ART_IDS := ["hall", "archive", "barracks", "kennel", "storehouse", "gate", "shrine", "forge", "frost_lodge", "frost_supply", "frost_guardhouse"]
	# 贴图统一按 0.75 倍画（256×192 → 192×144，正好 4×3 格）。
	# 这批楼是同一台等距相机、同一比例出的：内容高都落在 161~181px，宽随楼本身宽窄变化
	# （城门宽、祭坛窄）。所以绝不能"按各楼占地宽度缩放"——那会让窄楼被拉扁、宽楼被撑肿，
	# 一排楼大小失控。统一倍数才能让它们看起来在同一片城里。
	const ART_SCALE := 0.75
	const ART_W := 256.0 * ART_SCALE    # 192
	const ART_H := 192.0 * ART_SCALE    # 144
	const ART_BOTTOM := 4.0             # 楼脚相对节点原点的下探量（压住落地影）

	func setup(d: Dictionary) -> void:
		data = d
		var s: Array = d.get("size", [2.0, 2.0])
		_w = float(s[0]) * 48.0
		_h = float(s[1]) * 48.0
		# 贴图只在落成后才画（_draw_built 才走 _draw_art），工地仍走 _draw_plot 的翻土画法。
		art = G.res_tex("city_%s" % String(d.get("id", "")))
		var art_id := String(d.get("id", ""))
		if art_id == "stable": art_id = "kennel"
		if art_id in REFERENCE_ART_IDS:
			var path := "res://image/main_world/city_%s_reference_v2.png" % art_id
			if ResourceLoader.exists(path):
				art = load(path) as Texture2D
				_reference_art = true
		if art_id.begins_with("frost_") and _reference_art:
			art = FrostCityArt.prop("city_" + art_id)
			material = FrostCityArt.cutout_material()
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		# 只有基座挡人：楼体能从后面走过（Y-sort 遮挡），脚下穿不过去
		rect.size = Vector2(_w * 0.80, _h * 0.30)
		shape.shape = rect
		shape.position = Vector2(0, _h * 0.5 - _h * 0.15)
		add_child(shape)
		if art != null:
			var displayed_height := ART_W * float(art.get_height()) / float(art.get_width()) if _reference_art else ART_H
			_grounding = Grounding.prepare(art, roundi(ART_W), roundi(displayed_height))
			Grounding.attach(self, _grounding, ART_BOTTOM - displayed_height, art_id.begins_with("frost_"))

	func built() -> bool:
		return bool(data.get("port_built", false)) or G.is_built(String(data.get("id", "")))

	## 玩家到建筑轮廓的距离（矩形外距；轮廓内为 0）
	func dist_to(p: Vector2) -> float:
		var d := (p - global_position).abs()
		var dx := maxf(0.0, d.x - _w * 0.5)
		var dy := maxf(0.0, d.y - _h * 0.5)
		return Vector2(dx, dy).length()

	func _process(delta: float) -> void:
		_t += delta
		var foundation := get_node_or_null("FoundationGround") as Node2D
		if foundation != null: foundation.visible = built()
		if hover:
			queue_redraw()

	func _roof_col() -> Color:
		return Color.from_hsv(float(int(data.get("hue", 0)) % 12) / 12.0, 0.40, 0.50)

	## 楼体可见轮廓的最高点（负值，越小越高）。木牌、功能图标、悬停指示都挂在这条线之上，
	## 免得贴图比程序绘制高时，装饰还按老高度摆就被楼顶顶穿。
	func _art_top() -> float:
		if art != null:
			if _reference_art:
				return ART_BOTTOM - ART_W * float(art.get_height()) / float(art.get_width())
			return ART_BOTTOM - float(data.get("art_visible_height", 192.0)) * ART_SCALE
		return -_h * 0.5

	func _draw() -> void:
		# 落地影统一由 _draw_built / _draw_plot 各自画（两者尺寸口径不同），这里不再重复。
		if built():
			_draw_built()
		else:
			_draw_plot()
		# 功能建筑使用统一的小图标标记；祭坛图标直接对应每日签到功能，
		# 让玩家不靠猜建筑用途，也不会把建筑做成一排无意义色块。
		_draw_function_icon()
		if hover:
			var bob := sin(_t * 2.4) * 3.0
			var top := _art_top()
			var tip := Vector2(-54, top - 12.0 + bob)
			draw_colored_polygon([tip + Vector2(0, -7), tip + Vector2(6, 3), tip + Vector2(-6, 3)],
				Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.9))
			var action := String(data.get("action", ""))
			if built() and action.begins_with("activity:"):
				var activity := G.city_activity(action.get_slice(":", 1))
				var activity_name := String(activity.get("name", "可互动"))
				var hint_size := G.font_reg.get_string_size(activity_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
				draw_rect(Rect2(-hint_size.x * 0.5 - 7, top - 50, hint_size.x + 14, 22),
					Color("3a2919", 0.92))
				draw_string(G.font_reg, Vector2(-hint_size.x * 0.5, top - 35),
					activity_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f4ddb0"))

	## 在建筑上方放置功能图标；无对应素材时不画，保持程序绘制的降级路径。
	func _draw_function_icon() -> void:
		if not built():
			return
		var icon_name := ""
		match String(data.get("id", "")):
			"shrine": icon_name = "icon_altar"
			"barracks": icon_name = "icon_double_edge"
			"archive": icon_name = "itm_pet_book"
			"storehouse": icon_name = "icon_vault"
			_: return
		var tex: Texture2D = G.res_tex(icon_name)
		if tex == null:
			return
		var icon_size := 24.0
		# Name plaque occupies x=-38..38. Keep function art beside it, never over characters.
		draw_texture_rect(tex, Rect2(44, _art_top() - 25.0, icon_size, icon_size), false,
			Color(1.0, 1.0, 1.0, 0.92))


	## 木牌：名字 (+ 状态)。P01 样板 §5：最小可读字号为 FS_XS(13)，
	## 状态行原来画 10px（低于任何一档），牌高与行距随之加高。
	func _plaque(txt: String, sub: String, y: float) -> void:
		var pw := maxf(60.0, G.font_display.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18)
		var ph := 24.0
		# Clip signs at the viewport edge instead of leaving detached half-labels.
		var screen_at: Vector2 = get_global_transform_with_canvas() * Vector2(0, y)
		var view := get_viewport_rect().size
		if screen_at.x < pw * 0.5 or screen_at.x > view.x - pw * 0.5 or screen_at.y < 90 or screen_at.y > view.y - 80:
			return
		if sub != "":
			ph = 44.0
		draw_rect(Rect2(-pw / 2, y, pw, ph), Color("e8d5a3"))
		draw_rect(Rect2(-pw / 2, y, pw, ph), Color("8a6220"), false, 1.5)
		var ts := G.font_display.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		draw_string(G.font_display, Vector2(-ts.x / 2, y + 17), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("3a2a14"))
		if sub != "":
			var ss := G.font_reg.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, G.FS_XS)
			draw_string(G.font_reg, Vector2(-ss.x / 2, y + 37), sub,
				HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_XS, Color("8a4a2a"))

	func _draw_plot() -> void:
		var w := _w
		var h := _h
		# 工地自身的落地影（原来在外层 _draw 统一画，现在各分支自管）
		draw_set_transform(Vector2(0, h * 0.5 - 4.0), 0.0, Vector2(1.0, 0.30))
		draw_circle(Vector2.ZERO, w * 0.46, Color(0, 0, 0, 0.10))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 翻过的地
		draw_rect(Rect2(-w / 2 + 6, -h / 2 + 6, w - 12, h - 12), Color(0.42, 0.35, 0.24, 0.30))
		for i in 5:  # 犁沟
			var gy := -h / 2 + 14.0 + i * (h - 28.0) / 4.0
			draw_line(Vector2(-w / 2 + 10, gy), Vector2(w / 2 - 10, gy - 3.0),
				Color(0.30, 0.24, 0.16, 0.35), 2.0)
		# 角桩 + 麻绳
		var cs := [Vector2(-w / 2 + 8, -h / 2 + 8), Vector2(w / 2 - 8, -h / 2 + 8),
			Vector2(w / 2 - 8, h / 2 - 8), Vector2(-w / 2 + 8, h / 2 - 8)]
		for c in cs:
			draw_rect(Rect2(c.x - 2, c.y - 12, 4, 14), TIMBER_D)
		var rope := PackedVector2Array()
		for c in cs:
			rope.append(c + Vector2(0, -10))
		rope.append(cs[0] + Vector2(0, -10))
		draw_polyline(rope, Color("c9b070", 0.85), 1.5)
		# 石料堆 + 木料
		draw_circle(Vector2(-w * 0.20, h * 0.16), 10.0, STONE)
		draw_circle(Vector2(-w * 0.20 + 13, h * 0.19), 7.5, STONE_D)
		draw_circle(Vector2(-w * 0.20 + 5, h * 0.09), 6.0, STONE.lightened(0.12))
		draw_line(Vector2(w * 0.12, h * 0.20), Vector2(w * 0.34, h * 0.15), TIMBER, 5.0)
		draw_line(Vector2(w * 0.13, h * 0.26), Vector2(w * 0.35, h * 0.21), TIMBER_D, 5.0)
		_plaque(String(data.get("name", "空地")), "待建", -h * 0.5 + 2.0)

	func _contact_shadow(width: float, bottom: float) -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-width * 0.45, bottom - 2),
			Vector2(width * 0.45, bottom - 2), Vector2(width * 0.50, bottom + 7),
			Vector2(-width * 0.39, bottom + 7)]), Color("17211d", 0.14))

	func _draw_built() -> void:
		# 贴图路径：不再叠程序绘制的石台（贴图自带台基），只补一圈贴地的接影。
		if art != null:
			_draw_art()
			return
		# 程序绘制路径：统一的落地影 + 石台基
		_contact_shadow(_w, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-_w * 0.5, 2), Vector2(_w * 0.5, 2),
			Vector2(_w * 0.46, -9), Vector2(-_w * 0.46, -9)]), Color("6b5a42"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-_w * 0.46, -9), Vector2(_w * 0.46, -9),
			Vector2(_w * 0.44, -12), Vector2(-_w * 0.44, -12)]), Color("8a7659"))
		match String(data.get("style", "")):
			"frost_house":
				_draw_frost_house()
			"hall":
				_draw_hall()
			"gate":
				_draw_gate()
			"archive":
				_draw_archive()
			"kennel":
				_draw_kennel()
			"barracks":
				_draw_barracks()
			"storehouse":
				_draw_storehouse()
			"shrine":
				_draw_shrine()
			"forge":
				_draw_forge()
			"port_market":
				_draw_port_market()
			_:
				_draw_hall()

	func _draw_frost_house() -> void:
		var w := _w
		var top := -_h * 0.5
		var bottom := _h * 0.5
		draw_rect(Rect2(-w * 0.43, top + 16, w * 0.86, _h - 22), Color("685949"))
		for x in [-w * 0.39, w * 0.39]:
			draw_rect(Rect2(x - 3, top + 16, 6, _h - 22), Color("403831"))
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.52, top + 20),
			Vector2(w * 0.52, top + 20), Vector2(w * 0.30, top - 18),
			Vector2(-w * 0.30, top - 18)]), Color("415663"))
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.51, top + 10),
			Vector2(w * 0.51, top + 10), Vector2(w * 0.30, top - 18),
			Vector2(-w * 0.30, top - 18)]), Color("dae7de"))
		draw_rect(Rect2(-14, bottom - 40, 28, 40), Color("342d28"))
		for x in [-w * 0.27, w * 0.27]:
			draw_rect(Rect2(x - 11, top + 38, 22, 20), Color("d7a55c"))
			draw_line(Vector2(x, top + 38), Vector2(x, top + 58), Color("4b4137"), 2)
		draw_rect(Rect2(-18, bottom - 4, 36, 8), Color("b4bcb4"))
		_plaque(String(data.get("name", "驿舍")), "", top - 35)

	func _draw_port_market() -> void:
		var w := _w
		var h := _h
		var top := -h * 0.5
		var bottom := h * 0.5
		# 栈桥市集使用横向布棚、布条与货箱，避免借用校场圆环。
		draw_rect(Rect2(-w * 0.46, top + 32, w * 0.92, h - 42), Color("795c43"))
		for px in [-w * 0.37, w * 0.37]:
			draw_line(Vector2(px, top + 22), Vector2(px, bottom - 8), Color("4e392c"), 7)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w * 0.55, top + 25), Vector2(w * 0.55, top + 25),
			Vector2(w * 0.40, top - 5), Vector2(-w * 0.40, top - 5)]), Color("6b8d86"))
		for stripe in [-2, -1, 0, 1, 2]:
			var sx := float(stripe) * w * 0.19
			draw_line(Vector2(sx, top + 25), Vector2(sx * 0.73, top - 3),
				Color("d7c69e", 0.65), 3)
		for px in [-w * 0.26, 0.0, w * 0.26]:
			draw_rect(Rect2(px - 15, bottom - 42, 30, 24), Color("aa8457"))
			draw_rect(Rect2(px - 15, bottom - 42, 30, 4), Color("d3b17b"))
		_plaque(String(data.get("name", "市集")), "", top - 22)

	# 成品贴图：统一 0.75 倍、水平居中、底缘对齐 ART_BOTTOM（踩住落地影）。
	# 贴图自带完整的台基与台阶，所以不再叠程序绘制的石台，免得两层台基打架。
	func _draw_art() -> void:
		var left := -ART_W * 0.5
		var height := ART_W * float(art.get_height()) / float(art.get_width()) \
			if _reference_art else ART_H
		var top := ART_BOTTOM - height
		draw_texture_rect(art, Rect2(left, top, ART_W, height), false)
		# 名牌移到楼顶之上：贴图本身细节很密，压在上面会糊掉
		_plaque(String(data.get("name", "")), "", _art_top() - 20.0)

	# 议事厅：石阶高台 + 四柱 + 大屋顶 + 门前布告板
	func _draw_hall() -> void:
		var w := _w
		var h := _h
		var b0 := h * 0.5
		var t0 := -h * 0.5
		var roof := _roof_col()
		draw_rect(Rect2(-w * 0.38, b0 - 14, w * 0.76, 6), STONE_D)    # 三级石阶
		draw_rect(Rect2(-w * 0.34, b0 - 20, w * 0.68, 6), STONE)
		draw_rect(Rect2(-w * 0.30, b0 - 26, w * 0.60, 6), STONE.lightened(0.10))
		draw_rect(Rect2(-w * 0.44, b0 - 38, w * 0.88, 14), STONE_D)   # 台基
		draw_rect(Rect2(-w * 0.38, t0 + 42, w * 0.76, b0 - 38 - (t0 + 42)), PLASTER.darkened(0.06))
		for fx in [-0.30, -0.11, 0.11, 0.30]:                          # 四柱
			draw_rect(Rect2(w * fx - 4, t0 + 38, 8, b0 - 38 - (t0 + 38)), TIMBER)
			draw_rect(Rect2(w * fx - 5, t0 + 38, 10, 4), TIMBER_D)
		# 大屋顶：梯形 + 屋脊 + 出檐
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w * 0.54, t0 + 40), Vector2(w * 0.54, t0 + 40),
			Vector2(w * 0.36, t0 + 4), Vector2(-w * 0.36, t0 + 4)]), roof)
		draw_line(Vector2(-w * 0.54, t0 + 40), Vector2(w * 0.54, t0 + 40), roof.darkened(0.3), 3.0)
		draw_rect(Rect2(-w * 0.38, t0, w * 0.76, 6), roof.darkened(0.25))
		draw_circle(Vector2(-w * 0.54, t0 + 40), 4.0, roof.darkened(0.2))  # 檐角
		draw_circle(Vector2(w * 0.54, t0 + 40), 4.0, roof.darkened(0.2))
		# 门与布告板
		draw_rect(Rect2(-13, b0 - 62, 26, 24), TIMBER_D)
		draw_rect(Rect2(w * 0.20, b0 - 58, 22, 16), Color("e8d5a3"))
		draw_rect(Rect2(w * 0.20, b0 - 58, 22, 16), TIMBER_D, false, 1.5)
		draw_line(Vector2(w * 0.20 + 3, b0 - 52), Vector2(w * 0.20 + 19, b0 - 52), Color("8a4a2a"), 1.0)
		draw_line(Vector2(w * 0.20 + 3, b0 - 47), Vector2(w * 0.20 + 15, b0 - 47), Color("8a4a2a"), 1.0)
		_plaque(String(data.get("name", "")), "", t0 + 46)

	# 城门：双石塔 + 拱洞 + 据点木牌
	func _draw_gate() -> void:
		var w := _w
		var h := _h
		var b0 := h * 0.5
		var t0 := -h * 0.5
		for side in [-1, 1]:
			var tx := w * 0.5 - 46.0 if side > 0 else -w * 0.5
			draw_rect(Rect2(tx, t0 + 6, 46, h - 6), STONE)
			for i in 3:  # 垛口
				draw_rect(Rect2(tx + 4.0 + i * 15.0, t0 - 2, 9, 10), STONE_D)
			draw_rect(Rect2(tx - 2, t0 + 2, 50, 6), STONE_D)
			draw_rect(Rect2(tx + 16, t0 + 30, 14, 18), Color(0.16, 0.12, 0.08))  # 塔窗
		# 墙体与拱洞
		draw_rect(Rect2(-w * 0.5 + 46, t0 + 22, w - 92, h - 22), STONE.lightened(0.08))
		draw_rect(Rect2(-w * 0.5 + 46, t0 + 22, w - 92, 5), STONE_D)
		var aw := 62.0
		draw_rect(Rect2(-aw / 2, b0 - 52, aw, 52), Color(0.14, 0.10, 0.07))
		draw_arc(Vector2(0, b0 - 52), aw / 2, PI, TAU, 18, Color(0.14, 0.10, 0.07), 6.0)
		draw_arc(Vector2(0, b0 - 52), aw / 2 + 3, PI, TAU, 18, STONE_D, 3.0)
		# 据点码木牌（带"据点码"前缀——裸码挂城门像乱码）
		_plaque(G.city_code(), "据点码", t0 + 30)

	# 图志阁：两层小阁 + 卷轴窗
	func _draw_archive() -> void:
		var w := _w
		var h := _h
		var b0 := h * 0.5
		var t0 := -h * 0.5
		var roof := _roof_col()
		draw_rect(Rect2(-w * 0.40, b0 - 46, w * 0.80, 46), PLASTER)
		draw_rect(Rect2(-w * 0.40, b0 - 46, w * 0.80, 4), TIMBER)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w * 0.50, b0 - 46), Vector2(w * 0.50, b0 - 46),
			Vector2(w * 0.34, b0 - 66), Vector2(-w * 0.34, b0 - 66)]), roof)
		draw_rect(Rect2(-w * 0.28, t0 + 18, w * 0.56, 22), PLASTER.darkened(0.04))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w * 0.38, t0 + 18), Vector2(w * 0.38, t0 + 18),
			Vector2(w * 0.22, t0), Vector2(-w * 0.22, t0)]), roof.darkened(0.08))
		# 卷轴窗：一排小圆轴
		for i in 4:
			var sx := -w * 0.24 + i * w * 0.16
			draw_circle(Vector2(sx, b0 - 26), 5.0, Color("e8d5a3"))
			draw_circle(Vector2(sx, b0 - 26), 2.0, Color("8a4a2a"))
		draw_rect(Rect2(-9, b0 - 20, 18, 20), TIMBER_D)
		_plaque(String(data.get("name", "")), "", b0 - 78)

	# 兽栏：木栅栏 + 草料棚 + 干草堆
	func _draw_kennel() -> void:
		var w := _w
		var h := _h
		var b0 := h * 0.5
		var t0 := -h * 0.5
		var roof := _roof_col()
		# 后排草料棚
		draw_rect(Rect2(-w * 0.34, t0 + 22, w * 0.42, 34), TIMBER)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w * 0.40, t0 + 22), Vector2(w * 0.14, t0 + 22),
			Vector2(w * 0.06, t0 + 6), Vector2(-w * 0.32, t0 + 6)]), roof)
		# 干草堆
		draw_set_transform(Vector2(w * 0.24, t0 + 44), 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, 14.0, Color("d8b84a"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2(w * 0.24, t0 + 40), 10.0, PI * 1.1, PI * 1.9, 8, Color("b89a30"), 2.0)
		# 围栏：两排桩 + 横杆
		for i in 7:
			var fx := -w * 0.44 + i * w * 0.147
			draw_rect(Rect2(fx - 2, b0 - 26, 4, 26), TIMBER_D)
		draw_line(Vector2(-w * 0.46, b0 - 20), Vector2(w * 0.46, b0 - 20), TIMBER, 3.0)
		draw_line(Vector2(-w * 0.46, b0 - 10), Vector2(w * 0.46, b0 - 10), TIMBER, 3.0)
		# 食槽
		draw_rect(Rect2(w * 0.10, b0 - 14, 26, 10), TIMBER_D)
		_plaque(String(data.get("name", "")), "", t0 - 12)

	# 演武场：夯土圆场 + 木人桩 + 兵器架
	func _draw_barracks() -> void:
		var w := _w
		var h := _h
		var b0 := h * 0.5
		var t0 := -h * 0.5
		draw_set_transform(Vector2(0, b0 * 0.30), 0.0, Vector2(1.0, 0.52))
		draw_circle(Vector2.ZERO, w * 0.40, Color("c9b184"))
		draw_arc(Vector2.ZERO, w * 0.40, 0, TAU, 32, Color("a8926a"), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 木人桩
		draw_rect(Rect2(-w * 0.26 - 3, t0 + 26, 7, 44), TIMBER)
		draw_circle(Vector2(-w * 0.26, t0 + 22), 8.0, Color("d8b84a"))
		draw_line(Vector2(-w * 0.26 - 12, t0 + 36), Vector2(-w * 0.26 + 12, t0 + 36), TIMBER_D, 4.0)
		# 兵器架
		draw_rect(Rect2(w * 0.18, t0 + 24, 5, 42), TIMBER_D)
		draw_rect(Rect2(w * 0.36, t0 + 24, 5, 42), TIMBER_D)
		draw_line(Vector2(w * 0.16, t0 + 28), Vector2(w * 0.40, t0 + 28), TIMBER, 3.0)
		for i in 3:
			var sx := w * 0.21 + i * w * 0.07
			draw_line(Vector2(sx, t0 + 18), Vector2(sx + 3, t0 + 44), STONE_D, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(sx, t0 + 12),
				Vector2(sx + 3, t0 + 20), Vector2(sx - 3, t0 + 20)]), STONE)
		_plaque(String(data.get("name", "")), "", t0 - 2)

	# 仓廪：高脚粮囤 + 梯子 + 麻袋
	func _draw_storehouse() -> void:
		var w := _w
		var h := _h
		var b0 := h * 0.5
		var t0 := -h * 0.5
		var roof := _roof_col()
		for fx in [-0.30, 0.30]:  # 高脚
			draw_rect(Rect2(w * fx - 4, b0 - 18, 8, 18), TIMBER_D)
		draw_rect(Rect2(-w * 0.40, t0 + 30, w * 0.80, 44), Color("c9a86a"))
		for i in 3:  # 板缝
			draw_line(Vector2(-w * 0.40, t0 + 40.0 + i * 11.0),
				Vector2(w * 0.40, t0 + 40.0 + i * 11.0), Color("a8884a"), 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w * 0.48, t0 + 30), Vector2(w * 0.48, t0 + 30),
			Vector2(0, t0 - 2)]), roof)
		draw_line(Vector2(-w * 0.48, t0 + 30), Vector2(0, t0 - 2), roof.darkened(0.3), 2.0)
		draw_line(Vector2(w * 0.48, t0 + 30), Vector2(0, t0 - 2), roof.darkened(0.3), 2.0)
		# 梯子
		draw_line(Vector2(w * 0.20, b0 - 2), Vector2(w * 0.30, t0 + 66), TIMBER_D, 3.0)
		draw_line(Vector2(w * 0.26, b0 - 2), Vector2(w * 0.36, t0 + 66), TIMBER_D, 3.0)
		for i in 4:
			var t := i / 3.0
			draw_line(Vector2(w * (0.20 + 0.06 * t) + 1, b0 - 2 - (b0 - t0 - 68.0) * t - 8 * t),
				Vector2(w * (0.26 + 0.06 * t) + 1, b0 - 2 - (b0 - t0 - 68.0) * t - 8 * t), TIMBER, 2.0)
		# 麻袋
		draw_circle(Vector2(-w * 0.30, b0 - 8), 9.0, Color("b89a5a"))
		draw_circle(Vector2(-w * 0.18, b0 - 6), 8.0, Color("a8884a"))
		_plaque(String(data.get("name", "")), "", t0 + 34)

	# 祭坛：三层石台 + 双柱 + 悬浮魂晶
	func _draw_shrine() -> void:
		var w := _w
		var h := _h
		var b0 := h * 0.5
		var t0 := -h * 0.5
		draw_rect(Rect2(-w * 0.42, b0 - 10, w * 0.84, 10), STONE_D)
		draw_rect(Rect2(-w * 0.34, b0 - 20, w * 0.68, 10), STONE)
		draw_rect(Rect2(-w * 0.26, b0 - 30, w * 0.52, 10), STONE.lightened(0.10))
		for fx in [-0.22, 0.16]:
			draw_rect(Rect2(w * fx, t0 + 26, 7, b0 - 30 - (t0 + 26)), STONE)
			draw_rect(Rect2(w * fx - 2, t0 + 22, 11, 5), STONE_D)
		# 魂晶：悬浮菱形 + 光晕
		var cx := 0.0
		var cy := t0 + 34.0 + sin(_t * 1.6) * 2.0
		draw_circle(Vector2(cx, cy), 14.0, Color(0.55, 0.75, 0.95, 0.20))
		draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 10),
			Vector2(cx + 7, cy), Vector2(cx, cy + 10), Vector2(cx - 7, cy)]),
			Color("9fd0e8"))
		draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 5),
			Vector2(cx + 3.5, cy), Vector2(cx, cy + 5), Vector2(cx - 3.5, cy)]),
			Color("e0f0fa"))
		_plaque(String(data.get("name", "")), "", b0 - 46)

	# 锻造铺（未开放也先立着炉子，只是还没生火）
	func _draw_forge() -> void:
		var w := _w
		var h := _h
		var b0 := h * 0.5
		var t0 := -h * 0.5
		var roof := _roof_col()
		# 炉体 + 烟囱
		draw_rect(Rect2(-w * 0.34, t0 + 34, w * 0.46, b0 - (t0 + 34)), STONE_D)
		draw_rect(Rect2(-w * 0.30, t0 + 10, 20, 28), STONE)
		draw_rect(Rect2(-w * 0.31, t0 + 6, 22, 5), STONE_D)
		# 炉口（冷的：青灰，不点火）
		draw_rect(Rect2(-w * 0.26, b0 - 26, 26, 18), Color(0.12, 0.10, 0.09))
		draw_arc(Vector2(-w * 0.26 + 13, b0 - 26), 13.0, PI, TAU, 12, STONE, 2.0)
		# 顶棚 + 铁砧 + 水槽
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, t0 + 30), Vector2(w * 0.44, t0 + 30),
			Vector2(w * 0.38, t0 + 44), Vector2(-2, t0 + 44)]), roof)
		draw_rect(Rect2(w * 0.12, b0 - 18, 24, 8), Color("4a4640"))
		draw_rect(Rect2(w * 0.12 + 8, b0 - 26, 8, 8), Color("5a564e"))
		draw_rect(Rect2(w * 0.28, b0 - 14, 20, 10), Color("5a7a8a"))
		_plaque(String(data.get("name", "")), "备料中", t0 + 48)


## 城里人：常驻 NPC 与每日来访旅人（idle 四帧条 → 呼吸小人；缺图退回立绘/程序小人 + 头顶名牌）
class _CityNPC extends Node2D:
	var data: Dictionary = {}
	var guest := false
	var embedded := false
	var label_near := true
	var hue := 0
	var hover := false
	var cooled := false
	var _t := 0.0
	var frames: SpriteFrames = null   # idle 四帧条（像素小人）；有它就不必让立绘站桩
	var art: Texture2D = null         # 兜底：半身立绘（ready/npcs 的 512 图）
	var _pad: PanelContainer = null   # 名牌底衬（屏内钳制要挪它）
	var _name_l: Label = null         # 名牌文字
	var _plate_top := 0.0             # 名牌本地 y（形象决定，钳制只动 x/按需上抬）
	var _plate_w := 160.0
	var _plate_h := 18.0
	# 与主角同一套标定：0.72 倍；idle 条帧内脚底 y≈123、帧心 64 → 反向抬 (123-64)×0.72，脚落在节点原点
	const IDLE_SCALE := 0.72
	const IDLE_LIFT := 42.5

	func _ready() -> void:
		if frames != null:
			var sp := AnimatedSprite2D.new()
			sp.name = "Idle"   # 显式命名：引擎自动名是 @AnimatedSprite2D@xx，回归断言没法按名找
			sp.sprite_frames = frames
			sp.animation = &"idle"
			var display_scale := 0.64 if embedded else IDLE_SCALE
			sp.scale = Vector2.ONE * display_scale
			sp.position = Vector2(0, -59.0 * display_scale if embedded else -IDLE_LIFT)
			if frames.get_meta("foot_registered", false):
				var canvas_height := float(frames.get_meta("canvas_height"))
				display_scale = float(frames.get_meta("world_height")) / canvas_height
				if not embedded: display_scale *= 84.0 / 76.0
				sp.scale = Vector2.ONE * display_scale
				sp.position = Vector2(0, -canvas_height * display_scale * 0.5)
				sp.material = FrostCityArt.cutout_material()
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			# 错开起始帧：一排 NPC 齐步呼吸，会像同一张贴图复制了八份
			sp.frame = int(absf(position.x + position.y)) % 4
			sp.play()
			add_child(sp)
		# 名字牌挂头顶（脚下会被 Y-sort 的建筑/行人来回遮挡，裁剪观感差）：
		# 半透明深底衬 + 居中，长名字也不会飘出屏幕
		var txt := String(data.get("name", "???"))
		var title := String(data.get("title", ""))
		if title != "" and embedded:
			set_meta("npc_title", title)
		# 名牌高度随形象变：像素小人身高 80（含头）→ -108；立绘 104 → -114；色块小人 → -52
		_plate_top = -108.0 if frames != null else (-114.0 if art != null else -52.0)
		if embedded and frames != null:
			# 成人名牌保留原安全高度，避免与0.66倍主角名牌相交后被隐藏。
			_plate_top = -78.0 if String(data.get("id", "")) == "npc_child" else -108.0
		_plate_w = clampf(G.font_bold.get_string_size(txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0, 56.0, 112.0) \
			if embedded else maxf(64.0, G.font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_XS).x + 20)
		_plate_h = 22.0 if embedded else 26.0
		# 字号收进六档（P01 样板 §5）：主世界里的城务 NPC 名签原来是不在档里的字面量 14
		_name_l = G.serif_label(txt,14,Color("fff5df"),false)
		_name_l.add_theme_font_override("font",G.font_art)
		_name_l.add_theme_font_size_override("font_size",16 if embedded else 14)
		_name_l.position = Vector2(-_plate_w * 0.5, _plate_top + 2)
		_name_l.custom_minimum_size = Vector2(_plate_w, 0)
		_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pad = PanelContainer.new()
		_pad.position = Vector2(-_plate_w * 0.5, _plate_top)
		_pad.custom_minimum_size = Vector2(_plate_w, _plate_h)
		_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var psb := StyleBoxFlat.new()
		# 深木硬边名牌与新的纸页/金钮共用材质语言。
		# 名牌按文字内容收紧，_clamp_plate() 按实际宽度钳制屏内位置。
		psb.bg_color = Color("373b36", 0.85)
		psb.set_corner_radius_all(0)
		psb.set_border_width_all(1)
		psb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.45)
		psb.shadow_color = Color.TRANSPARENT
		psb.shadow_size = 0
		_pad.add_theme_stylebox_override("panel", psb)
		add_child(_pad)
		add_child(_name_l)
		if embedded:
			_pad.modulate.a = 0.0
			_name_l.modulate.a = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _pad != null and _name_l != null:
			var alpha := move_toward(_pad.modulate.a, 1.0 if label_near else 0.0,
				delta * 5.0)
			_pad.modulate.a = alpha
			_name_l.modulate.a = alpha
		_clamp_plate()

	## 名牌屏内钳制：镜头跟主角走，NPC 挪到屏缘时名牌会被裁掉半块——
	## 每帧按画布坐标把名牌拨回屏内（左右留 4px）；落进左下摇杆区（约 160×160）的再抬 40px
	func _clamp_plate() -> void:
		if _pad == null or _name_l == null:
			return
		var xf := get_global_transform_with_canvas()
		var z: float = absf(xf.x.x)
		if z < 0.001:
			return
		var sx: float = xf.origin.x
		var sy: float = xf.origin.y
		# 本地 x 的可行区间：屏左 ≥4 且屏右 ≤476。
		var lo := (4.0 - sx) / z
		var hi := (476.0 - sx) / z - _plate_w
		var px := clampf(-_plate_w * 0.5, lo, hi) if lo <= hi else -_plate_w * 0.5
		var py := _plate_top
		var scr_left := sx + px * z
		var scr_top := sy + py * z
		if scr_left < 160.0 and scr_top + _plate_h * z > 624.0:
			py -= 40.0 / z   # 摇杆区上抬（屏幕 40px 折回本地坐标）
		_pad.position = Vector2(px, py)
		_name_l.position = Vector2(px, py + 2)
		var in_view := sx >= 0.0 and sx <= get_viewport_rect().size.x and sy > 95.0 and sy < get_viewport_rect().size.y - 65.0
		_pad.visible = in_view
		_name_l.visible = in_view

	func _draw() -> void:
		var bob := sin(_t * 2.0 + float(hue)) * 1.2
		# 落地影
		var sr := 11.0 if frames != null else 13.0   # 像素小人比立绘瘦一圈，影子跟着收
		draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, sr, Color(0, 0, 0, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if frames != null:
			# 本体交给 AnimatedSprite2D（5fps 呼吸），这里只管影子与悬停金三角
			_hover_mark(bob, -88.0)
			return
		if art != null:
			# 半身立绘立在地上：底缘压深渐隐，裁切不生硬（比色块小人像样得多）
			var h := 104.0
			var w := 104.0
			var top := -h + bob * 0.5
			draw_texture_rect(art, Rect2(-w * 0.5, top, w, h), false)
			for i in 8:
				var t := float(i) / 8.0
				var yy := top + h * (0.78 + 0.22 * t)
				draw_rect(Rect2(-w * 0.5, yy, w, h * 0.22 / 8.0 + 1.0),
					Color(0.05, 0.03, 0.02, 0.07 + 0.13 * t))
			_hover_mark(bob, -112.0)
			return
		var robe := Color.from_hsv(float(hue % 12) / 12.0, 0.32, 0.50)
		if guest:
			robe = Color("5a6a7a")  # 旅人一律靛青斗篷
		# 长袍
		draw_colored_polygon(PackedVector2Array([
			Vector2(-11, 2), Vector2(11, 2),
			Vector2(7, -20 + bob), Vector2(-7, -20 + bob)]), robe)
		draw_line(Vector2(-8, -8 + bob * 0.5), Vector2(8, -8 + bob * 0.5),
			robe.darkened(0.3), 2.5)
		# 头
		draw_circle(Vector2(0, -26 + bob), 7.5, Color("e8c8a0"))
		if guest:
			draw_arc(Vector2(0, -25 + bob), 8.5, PI * 0.9, TAU * 1.02, 10, Color("3a4a5a"), 4.5)
			# 行囊
			draw_rect(Rect2(7, -16 + bob, 7, 9), Color("8a6a3a"))
			draw_rect(Rect2(7, -16 + bob, 7, 9), Color("5a4a28"), false, 1.0)
		else:
			draw_arc(Vector2(0, -27 + bob), 7.5, PI * 0.9, TAU * 1.02, 10, Color("3a2c1c"), 5.0)
		if bool(data.get("frost_cloak", false)):
			draw_arc(Vector2(0, -29 + bob), 9, PI, TAU, 8, robe.darkened(0.25), 6)
			draw_line(Vector2(-10, -16 + bob), Vector2(10, -16 + bob), Color("dfded2"), 5)
		# 可交互金三角（名牌在头顶，三角再抬高避让）
		_hover_mark(bob, -78.0)


	## 头顶可交互金三角：立绘 NPC 与色块小人共用，只是挂的高度不同
	func _hover_mark(bob: float, y: float) -> void:
		if not hover:
			return
		var bb := sin(_t * 2.4) * 3.0
		var tip := Vector2(0, y + bb)
		draw_colored_polygon([tip + Vector2(0, -6), tip + Vector2(5, 2), tip + Vector2(-5, 2)],
			Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.9))


## 虚拟摇杆（与 MapScene 同款）
class _Joystick extends Control:
	var vector := Vector2.ZERO
	var _base := Vector2.ZERO
	var _active := false

	func _ready() -> void:
		custom_minimum_size = Vector2(124, 124)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_active = true
				_base = (e as InputEventMouseButton).position
			else:
				_active = false
				vector = Vector2.ZERO
				queue_redraw()
		elif e is InputEventMouseMotion and _active:
			vector = ((e as InputEventMouseMotion).position - _base).limit_length(44.0) / 44.0
			queue_redraw()

	func _draw() -> void:
		var c := custom_minimum_size / 2.0
		draw_circle(c, 46.0, Color(0.12, 0.09, 0.05, 0.40))
		draw_arc(c, 46.0, 0, TAU, 40, Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.45), 1.5)
		draw_arc(c, 30.0, 0, TAU, 32, Color(1, 1, 1, 0.07), 1.0)
		var k := c + vector * 44.0
		draw_circle(k, 18.0, Color(0.30, 0.20, 0.10, 0.85))
		draw_circle(k, 15.0, Color(0.91, 0.84, 0.64, 0.92))
