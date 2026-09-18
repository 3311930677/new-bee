# CityScene.gd —— 主城（据点）世界：一座能逛完的城
# 职责：24×20 格自由行走；建筑程序绘制（按 city.json style 分支），未落成的是工地；
#       NPC 常驻街头可对话，来访旅人每天在城门附近落脚；议事厅布告板领取城内活动，
#       城门访客簿管据点码与来往；图志阁/兽栏/演武场分别通向世界/图鉴/出征。
# 交互口径与 MapScene 一致：走近即触发，离开后才会再次触发；WASD/方向键 + 摇杆并行。
class_name CityScene
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0
const TILE := 48.0
const NPC_R := 52.0        # 人物交互半径
const BUILD_R := 26.0      # 建筑轮廓外扩的交互边距
const REARM_R := 90.0      # 走出这么远才允许再次触发

const QuestPanelScript := preload("res://src/ui/QuestPanel.gd")   # 委托板（浮层）

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
var _quest_chip: PanelContainer = null
var _quest_lbl: Label = null
var _toast_lbl: Label = null
var _panel: Control = null      # 城内浮层（对话/建筑/布告板/访客簿）
var _overlay: Control = null    # 复用面板（世界/图鉴/出征）
var _talk_turns := {}           # npc_id -> 已聊次数（当天对话轮换）
var _dlg: Dictionary = {}       # 进行中的对话 {"id","guest","turn","line"}


func _ready() -> void:
	Audio.play_bgm("bgm_city")
	_cfg = G.city_config()
	_cols = int(_cfg.get("map_cols", 24))
	_rows = int(_cfg.get("map_rows", 20))
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
			var tex: Texture2D = load("%s/%s.png" % [asset_dir,
				String(decos[_rng.randi_range(0, decos.size() - 1)])])
			deco.setup(tex, _rng.randf_range(0.85, 1.15))
			deco.position = pos
			_world.add_child(deco)


func _build_buildings() -> void:
	for bd in _cfg.get("buildings", []):
		var b := _Building.new()
		b.setup(bd)
		var p: Array = (bd as Dictionary).get("pos", [12.0, 10.0])
		b.position = Vector2(float(p[0]) * TILE, float(p[1]) * TILE)
		_buildings.append(b)
		_world.add_child(b)


func _build_npcs() -> void:
	for nd in G.city_npcs():
		_spawn_npc(nd, false)
	# 今日来客：按「当天 + 据点码」确定性抽两位，在城门内侧落脚
	var guests := G.today_guests(2)
	var spots := [Vector2(10.6, 16.6), Vector2(13.6, 16.9)]
	for i in guests.size():
		var site := String(guests[i])
		_spawn_npc({
			"id": "guest_" + site, "name": site, "title": "来访旅人",
			"hue": 6, "lines": [G.guest_note(site)],
		}, true, spots[i % spots.size()] * TILE)


func _spawn_npc(nd: Dictionary, guest: bool, at := Vector2.ZERO) -> void:
	var n := _CityNPC.new()
	n.data = nd
	n.guest = guest
	n.hue = int(nd.get("hue", 0))
	n.art = _npc_world_tex(String(nd.get("id", "")), guest)   # 有立绘就用立绘，别再画色块小人
	if at == Vector2.ZERO:
		var p: Array = nd.get("pos", [12.0, 10.0])
		at = Vector2(float(p[0]) * TILE, float(p[1]) * TILE)
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
	# 与 MapScene 同一套标定：0.72 倍 + 上移 19.3px，让脚踩在碰撞盒下沿
	_player_anim.scale = Vector2.ONE * 0.72
	_player_anim.position = Vector2(0, -19.3)
	_player_anim.animation = &"walk_down"
	_player_anim.frame = 1
	_player_anim.stop()
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
	var hint_chip := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.13, 0.09, 0.05, 0.55)
	hsb.set_corner_radius_all(4)
	hsb.content_margin_left = 8.0
	hsb.content_margin_right = 8.0
	hsb.content_margin_top = 2.0
	hsb.content_margin_bottom = 2.0
	hint_chip.add_theme_stylebox_override("panel", hsb)
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
		_stat_lbl.text = "Lv.%d · 金 %d" % [int(G.prog.get("level", 1)),
			int(G.wallet.get("gold", 0))]
	if _quest_lbl != null:
		_quest_lbl.text = G.quest_today_text()


func _toast(msg: String) -> void:
	if _toast_lbl != null and not _toast_lbl.is_queued_for_deletion():
		_toast_lbl.queue_free()
	_toast_lbl = G.gold_label(msg, G.FS_MD, false, Color("ffe9b0"))
	_toast_lbl.position = Vector2(0, 560)
	_toast_lbl.custom_minimum_size = Vector2(VIEW_W, 0)
	_hud.add_child(_toast_lbl)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast_lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_toast_lbl.queue_free)


# ================= 主循环 =================
func _physics_process(_delta: float) -> void:
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
	_player.move_and_slide()
	_player.position = _player.position.clamp(Vector2(20, 40),
		Vector2(_cols * 48 - 20, _rows * 48 - 20))
	_update_player_anim(dir)
	_check_interact()


func _update_player_anim(dir: Vector2) -> void:
	if dir.length_squared() < 0.01:
		_player_anim.stop()
		_player_anim.frame = 1
		return
	var anim := &"walk_down"
	if absf(dir.x) > absf(dir.y):
		anim = &"walk_right" if dir.x > 0 else &"walk_left"
	else:
		anim = &"walk_down" if dir.y > 0 else &"walk_up"
	if _player_anim.animation != anim:
		_player_anim.animation = anim
	_player_anim.speed_scale = clampf(_player.velocity.length() / 92.0, 0.55, 2.0)
	if not _player_anim.is_playing():
		_player_anim.play()


## 走近触发：建筑按轮廓外扩判定（正面不一定够得着，比如城门贴着地图下沿）；
## 触发过一次的对象要走出一段距离才会再次触发，免得关了面板立刻又弹出来
func _check_interact() -> void:
	var best: Node2D = null
	var best_d := 9999.0
	for b in _buildings:
		var d: float = b.dist_to(_player.position)
		if d < BUILD_R and d < best_d:
			best = b
			best_d = d
		b.hover = d < BUILD_R + 24.0
		if d > REARM_R:
			b.cooled = false
	for n in _npcs:
		var nd: float = n.position.distance_to(_player.position)
		if nd < NPC_R and nd < best_d:
			best = n
			best_d = nd
		n.hover = nd < NPC_R + 24.0
		if nd > REARM_R:
			n.cooled = false
	if best != null and not (best as Object).get("cooled"):
		best.set("cooled", true)
		if best is _Building:
			_open_building((best as _Building).data)
		else:
			_open_dialog((best as _CityNPC).data, (best as _CityNPC).guest)


# ================= 浮层骨架 =================
func _panel_base(title: String, w: float, h: float) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var banner := G.banner_box(title, 260, 48)
	banner.position = Vector2((VIEW_W - 260.0) * 0.5, (VIEW_H - h) * 0.5 - 58.0)
	layer.add_child(banner)
	var panel := G.parchment_box(w, h, 16.0)
	panel.position = Vector2((VIEW_W - w) * 0.5, (VIEW_H - h) * 0.5)
	layer.add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_panel = layer
	_hud.add_child(layer)
	return content


func _close_panel() -> void:
	Audio.sfx("ui_close")
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_dlg = {}


func _panel_back(content: Control, y: float, w := 120.0) -> void:
	var back := G.gold_button("返 回", w, 38)
	back.position = Vector2(((content.get_parent() as Control).custom_minimum_size.x - 32.0 - w) * 0.5, y)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel())
	content.add_child(back)


# ================= 建筑交互 =================
func _open_building(bd: Dictionary) -> void:
	if _panel != null:
		return
	var id := String(bd.get("id", ""))
	if G.is_built(id):
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


## 已落成：建筑简介 + 它的用途按钮
func _show_built_panel(bd: Dictionary) -> void:
	var act := String(bd.get("action", ""))
	var content := _panel_base(String(bd.get("name", "建筑")), 360, 300)

	var desc := G.text_label(String(bd.get("desc", "")), G.FS_SM, Color("5a4020"))
	desc.position = Vector2(0, 8)
	desc.custom_minimum_size = Vector2(328, 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	var btn_text := ""
	match act:
		"notice":
			btn_text = "查看布告板"
		"visit":
			btn_text = "翻开访客簿"
		"worlds":
			btn_text = "翻阅世界图志"
		"codex":
			btn_text = "翻看宠物图鉴"
		"deploy":
			btn_text = "整备出征"
		"soon":
			btn_text = "尚未开放"
	if act.begins_with("activity:"):
		btn_text = "领取 · %s" % G.activity_state(act.get_slice(":", 1))

	var go := G.gold_button(btn_text, 240, 44)
	go.position = Vector2(44, 176)
	go.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel()
			_built_action(act))
	content.add_child(go)
	var back := G.gold_button("返 回", 240, 38)
	back.position = Vector2(44, 232)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_panel())
	content.add_child(back)


func _built_action(act: String) -> void:
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
		"deploy":
			_open_deploy()
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
	var h := 120.0 + acts.size() * 60.0
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
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(368, 52)
		row.position = Vector2(0, y)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("d8c8a0")
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 4.0
		row.add_theme_stylebox_override("panel", sb)
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

	_panel_back(content, h - 64.0)


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
## 立绘寻址：npc_<id>_portrait 优先；三个老熟人沿用已有半身像；旅人暂无
const NPC_PORTRAIT_ALIAS := {
	"npc_smith": "npc_blacksmith",
	"npc_warden": "npc_merchant",
	"npc_keeper": "npc_courier",
}

## 城内站位图：优先全身立绘 npc_<id>_idle_single（346~353），缺了退回半身像
func _npc_world_tex(npc_id: String, guest: bool) -> Texture2D:
	var tex := G.res_tex("%s_idle_single" % npc_id)
	if tex == null:
		tex = _npc_portrait_tex(npc_id, guest)
	return tex


func _npc_portrait_tex(npc_id: String, guest: bool) -> Texture2D:
	if guest:
		return G.res_tex("npc_guest_idle_single")
	var tex := G.res_tex("%s_portrait" % npc_id)
	if tex == null and NPC_PORTRAIT_ALIAS.has(npc_id):
		tex = G.res_tex(NPC_PORTRAIT_ALIAS[npc_id])
	return tex


func _open_dialog(nd: Dictionary, guest: bool) -> void:
	if _panel != null:
		return
	Audio.sfx("ui_open")
	var id := String(nd.get("id", ""))
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := G.parchment_box(432, 150, 16.0)
	panel.position = Vector2(24, VIEW_H - 190)
	layer.add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var title := String(nd.get("title", ""))
	var head := String(nd.get("name", "???"))
	if title != "":
		head += " · " + title
	var name_l := G.gold_label(head, G.FS_SM, true, Color("8a4a2a"), false)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_l.position = Vector2(0, 0)
	content.add_child(name_l)

	# 对话立绘：优先生成图 npc_<id>_portrait，无则走旧三杰映射（merchant/blacksmith/courier）
	var text_x := 0.0
	var text_w := 400.0
	var portrait := _npc_portrait_tex(String(nd.get("id", "")), guest)
	if portrait != null:
		var frame := PanelContainer.new()
		var fsb := StyleBoxTexture.new()
		var frame_tex: Texture2D = G.res_tex("panel_border_brown")
		if frame_tex != null:
			fsb.texture = frame_tex
			fsb.texture_margin_left = 8.0
			fsb.texture_margin_right = 8.0
			fsb.texture_margin_top = 8.0
			fsb.texture_margin_bottom = 8.0
			fsb.content_margin_left = 6.0
			fsb.content_margin_top = 6.0
			fsb.content_margin_right = 6.0
			fsb.content_margin_bottom = 6.0
			frame.add_theme_stylebox_override("panel", fsb)
		frame.position = Vector2(0, 26)
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
	line.position = Vector2(text_x, 30)
	line.custom_minimum_size = Vector2(text_w, 64)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(line)

	var hint := G.gold_label("轻点继续", G.FS_XS, false, Color("8a6a34", 0.8), false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = Vector2(0, 100)
	hint.custom_minimum_size = Vector2(400, 0)
	content.add_child(hint)

	var leave := G.gold_button("离 开", 64, 30, G.FS_XS)
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
	_dlg = {"id": id, "guest": guest, "data": nd,
		"turn": int(_talk_turns.get(id, 0)), "line": line}
	_show_dialog_line()
	if guest:
		var site := String(nd.get("name", ""))
		if G.add_visitor(site):
			_toast("访客簿添了新名字：%s" % site)


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
		# 身上挂着今日委托的发布者，第一句先说委托（接了/办完/交过口吻不同）
		if int(_dlg.get("turn", 0)) == 0:
			txt = G.npc_quest_line(String(_dlg.get("id", "")))
		if txt == "":
			txt = G.npc_line(String(_dlg.get("id", "")), int(_dlg.get("turn", 0)))
	line.text = txt
	var id := String(_dlg.get("id", ""))
	_talk_turns[id] = int(_dlg.get("turn", 0)) + 1


func _advance_dialog() -> void:
	if _dlg.is_empty():
		return
	_dlg["turn"] = int(_dlg.get("turn", 0)) + 1
	_show_dialog_line()


# ================= 复用面板（世界 / 图鉴 / 出征） =================
func _open_worlds() -> void:
	if _overlay != null:
		return
	Audio.sfx("ui_open")
	var p := WorldPanel.new()
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


func _open_deploy() -> void:
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
	# 先拿 viewport：_go_home() 会触发切场景，本节点离场后 get_viewport() 返回 null
	var vp := get_viewport()
	if _overlay != null:
		_close_overlay()
	elif _panel != null:
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

	func setup(d: Dictionary) -> void:
		data = d
		var s: Array = d.get("size", [2.0, 2.0])
		_w = float(s[0]) * 48.0
		_h = float(s[1]) * 48.0
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		# 只有基座挡人：楼体能从后面走过（Y-sort 遮挡），脚下穿不过去
		rect.size = Vector2(_w * 0.80, _h * 0.30)
		shape.shape = rect
		shape.position = Vector2(0, _h * 0.5 - _h * 0.15)
		add_child(shape)

	func built() -> bool:
		return G.is_built(String(data.get("id", "")))

	## 玩家到建筑轮廓的距离（矩形外距；轮廓内为 0）
	func dist_to(p: Vector2) -> float:
		var d := (p - global_position).abs()
		var dx := maxf(0.0, d.x - _w * 0.5)
		var dy := maxf(0.0, d.y - _h * 0.5)
		return Vector2(dx, dy).length()

	func _process(delta: float) -> void:
		_t += delta
		if hover:
			queue_redraw()

	func _roof_col() -> Color:
		return Color.from_hsv(float(int(data.get("hue", 0)) % 12) / 12.0, 0.40, 0.50)

	func _draw() -> void:
		# 落地影
		draw_set_transform(Vector2(0, _h * 0.5 - 4.0), 0.0, Vector2(1.0, 0.30))
		draw_circle(Vector2.ZERO, _w * 0.46, Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if built():
			_draw_built()
		else:
			_draw_plot()
		if hover:
			var bob := sin(_t * 2.4) * 3.0
			var tip := Vector2(0, -_h * 0.5 - 16.0 + bob)
			draw_colored_polygon([tip + Vector2(0, -7), tip + Vector2(6, 3), tip + Vector2(-6, 3)],
				Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.9))

	## 木牌：名字 (+ 状态)
	func _plaque(txt: String, sub: String, y: float) -> void:
		var pw := 76.0
		var ph := 18.0
		if sub != "":
			ph = 30.0
		draw_rect(Rect2(-pw / 2, y, pw, ph), Color("e8d5a3"))
		draw_rect(Rect2(-pw / 2, y, pw, ph), Color("8a6220"), false, 1.5)
		var ts := G.font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		draw_string(G.font_bold, Vector2(-ts.x / 2, y + 14), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("3a2a14"))
		if sub != "":
			var ss := G.font_reg.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			draw_string(G.font_reg, Vector2(-ss.x / 2, y + 26), sub,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8a4a2a"))

	func _draw_plot() -> void:
		var w := _w
		var h := _h
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

	func _draw_built() -> void:
		# 统一的落地影 + 石台基：所有建筑都踩在地上，不再像色块浮在路面
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.34))
		draw_circle(Vector2.ZERO, _w * 0.54, Color(0, 0, 0, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-_w * 0.5, 2), Vector2(_w * 0.5, 2),
			Vector2(_w * 0.46, -9), Vector2(-_w * 0.46, -9)]), Color("6b5a42"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-_w * 0.46, -9), Vector2(_w * 0.46, -9),
			Vector2(_w * 0.44, -12), Vector2(-_w * 0.44, -12)]), Color("8a7659"))
		match String(data.get("style", "")):
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
			_:
				_draw_hall()

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


## 城里人：常驻 NPC 与每日来访旅人（程序绘制长袍小人 + 脚下名牌）
class _CityNPC extends Node2D:
	var data: Dictionary = {}
	var guest := false
	var hue := 0
	var hover := false
	var cooled := false
	var _t := 0.0
	var art: Texture2D = null   # 半身立绘（ready/npcs 的 512 图）；没有就退回色块小人

	func _ready() -> void:
		# 名字牌挂头顶（脚下会被 Y-sort 的建筑/行人来回遮挡，裁剪观感差）：
		# 半透明深底衬 + 居中，长名字也不会飘出屏幕
		var txt := String(data.get("name", "???"))
		var title := String(data.get("title", ""))
		if title != "":
			txt += " · " + title
		var top := -114.0 if art != null else -52.0   # 立绘更高，名牌跟着抬
		var l := G.gold_label(txt, G.FS_XS, false, Color("f5ead0"), true)
		l.position = Vector2(-80, top + 2)
		l.custom_minimum_size = Vector2(160, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pad := PanelContainer.new()
		pad.position = Vector2(-80, top)
		pad.custom_minimum_size = Vector2(160, 18)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.08, 0.05, 0.03, 0.55)
		psb.set_corner_radius_all(3)
		pad.add_theme_stylebox_override("panel", psb)
		add_child(pad)
		add_child(l)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var bob := sin(_t * 2.0 + float(hue)) * 1.2
		# 落地影
		draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.30))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
