# MapScene.gd —— 探索大地图（玩法文档 §2.7；阶段 2.3）
# 职责：进入战斗节点后的探索层——地图 32×42 格（1536×2016）自由移动；
#       散件 Y-sort 遮挡 + 碰撞；怪物游荡/警戒追击/接触开战（BattleScene 覆盖层）；
#       传送阵为节点出口（BOSS 节点需先胜首领解封）；地图上可用药剂/换宠（战斗外无 CD）。
# 编成（§2.5/§2.7）：普通区 3~4 小怪；精英区 1 精英 + 2 小怪；BOSS 区 1 首领守阵。
class_name MapScene
extends Control

signal map_finished(result: String)  # "cleared"（走传送阵）/ "defeat"（战斗失利）/ "exited"（中途撤离）

## 场景切入前由 RouteScene 写入：{"node": 节点字典, "run": RunState}
static var pending_cfg: Dictionary = {}

const VIEW_W := 480.0
const VIEW_H := 800.0
const ROLE_FRAMES := {  # 四方向行走帧（BattleScene 同款复用）
	"zs": ["res://image/role/zs/pojun_walk_frames.tres", "pojun"],
	"ck": ["res://image/role/ck/chuanyang_walk_frames.tres", "chuanyang"],
	"fs": ["res://image/role/fs/shuangyu_walk_frames.tres", "shuangyu"],
	"fz": ["res://image/role/fz/chenxing_walk_frames.tres", "chenxing"],
}
const MON_COLOR := {
	"normal": Color("5f7186"), "elite": Color("7a4a9a"), "boss": Color("8a2f2f"),
}
const INTERACT_R := 44.0      # 非战斗物件交互半径（maps.json 无此字段时的口径）
const MINI_W := 78.0          # 小地图尺寸：与 32×42 格地图同比例（1536:2016 ≈ 0.762）
const MINI_H := 102.0
const _MiniMapPos := Vector2(390, 14)
const AUTO_TIMEOUT := 26.0    # 自动前往超时（秒）：到不了就交还控制权，不把玩家困住
const StoryBeatScript := preload("res://src/ui/StoryBeat.gd")   # 首领剧情演出层（对峙/余韵）

var st: RunState
var node: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _world := Node2D.new()
var _player: CharacterBody2D
var _player_anim: AnimatedSprite2D
var _portal: _Portal
var _monsters: Array[_MapMonster] = []
var _contact_mon: _MapMonster = null
var _interactable: _Interactable = null   # 非战斗节点物件（宝箱/事件/商店/篝火）
var _remover: Control = null              # 篝火词条删除浮层
var _exit_ui: Control = null              # 撤离确认浮层
var _beat: Control = null                 # 首领剧情演出层（对峙/余韵）
var _battle_layer: CanvasLayer = null
var _battle: BattleScene = null
var _hud := CanvasLayer.new()
var _hp_fill := ColorRect.new()
var _pot_l := Label.new()
var _toast_lbl: Label = null
var _pet_btn: Control = null
var _picker: TraitPicker = null
var _joy: _Joystick
var _map_done := false
var _map_cfg: Dictionary = {}
var _theme_cfg: Dictionary = {}

# ---- 导航辅助（轮次 13：探索不再"盲走"）----
# 痛点：32×42 格地图只能看到约 1/5，玩家不知道自己在哪、目标在哪，只能一直往上走。
# 三件套：小地图（全局位置感）+ 目标罗盘（方向与距离，点它自动前往）+ 疾行（缩短空跑时间）。
var _minimap: _Minimap = null        # 右上角小地图（点击放大为大地图）
var _compass: _Compass = null        # 目标罗盘（含距离，点击开始/停止自动前往）
var _sprint_btn: Control = null      # 疾行开关
var _big_map: Control = null         # 大地图浮层（含图例与返回按钮）
var _sprint := false
var _auto_walk := false
var _auto_time := 0.0                # 自动前往累计时长（超时自停，防止绕过点卡死）
var _auto_stuck := 0.0
var _auto_dodge := 0.0
var _auto_dodge_side := 1.0
var _prev_pos := Vector2.ZERO


func _ready() -> void:
	Audio.play_bgm("bgm_map")
	var cfg := pending_cfg
	pending_cfg = {}
	st = cfg.get("run", null)
	node = cfg.get("node", {})
	if st == null:
		push_error("MapScene 缺少 run 状态")
		return
	_map_cfg = TableCache.maps_config()
	_theme_cfg = TableCache.theme_config(st.theme)
	_rng.seed = hash("%d_%d" % [st.run_seed, int(node.get("layer", 1)) * 10 + int(node.get("index", 0))])
	_build_ground()
	_build_world()
	_build_hud()


# ================= 构建 =================
func _build_ground() -> void:
	# 地面层：TileMapLayer 程序构建（主题 3 种 tile 加权平铺，无碰撞）
	var tl := TileMapLayer.new()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(48, 48)
	var tiles: Array = _theme_cfg.get("tiles", [])
	var asset_dir := String(_map_cfg.get("asset_dir", "res://image/map"))
	var weights := [0.6, 0.2, 0.2]
	for i in mini(3, tiles.size()):
		var src := TileSetAtlasSource.new()
		src.texture = load("%s/%s.png" % [asset_dir, String(tiles[i])])
		src.texture_region_size = Vector2i(48, 48)
		src.create_tile(Vector2i.ZERO)
		ts.add_source(src, i)
	tl.tile_set = ts
	var cols := int(_map_cfg.get("map_cols", 32))
	var rows := int(_map_cfg.get("map_rows", 42))
	for y in rows:
		for x in cols:
			var roll := _rng.randf()
			var sid := 0
			if roll > 0.8:
				sid = 2
			elif roll > 0.6:
				sid = 1
			if sid < ts.get_source_count():
				tl.set_cell(Vector2i(x, y), sid, Vector2i.ZERO, 0)
	add_child(tl)


func _build_ground_detail(cols: int, rows: int) -> void:
	# 地面细节层：主题土路套件（path_sheet，4×4＝16 块位掩码地形）+ 程序磨损斑块。
	# 目的：打破 48×48 地砖满屏重复的“棋盘感”。必须先于 _world 入树（压在地砖上、实体下）。
	var asset_dir := String(_map_cfg.get("asset_dir", "res://image/map"))
	var sheet := String(_theme_cfg.get("path_sheet", ""))
	var path := _path_cells(cols, rows)
	var road: Array = []  # 路面格中心：主题无 4×4 套件时改用程序绘制的踩实土路
	if sheet != "":
		var tex: Texture2D = load("%s/%s.png" % [asset_dir, sheet])
		if tex != null:
			var tl := TileMapLayer.new()
			var ts := TileSet.new()
			ts.tile_size = Vector2i(48, 48)
			var src := TileSetAtlasSource.new()
			src.texture = tex
			src.texture_region_size = Vector2i(48, 48)
			for i in 16:  # 套件按 00~15 逐行排列，编号即北1/东2/南4/西8 的出口位之和
				src.create_tile(Vector2i(i % 4, i / 4))
			ts.add_source(src, 0)
			tl.tile_set = ts
			for cell: Vector2i in path.keys():
				var mask := _path_mask(cell, path)
				tl.set_cell(cell, 0, Vector2i(mask % 4, mask / 4), 0)
			add_child(tl)
		else:
			sheet = ""
	if sheet == "":
		for cell: Vector2i in path.keys():
			road.append(Vector2(float(cell.x) * 48.0 + 24.0, float(cell.y) * 48.0 + 24.0))

	var tint := Color(String(_theme_cfg.get("tint", "ffffff")))
	var earth := Color("6b5334")
	var road_col := Color(earth.r * tint.r, earth.g * tint.g, earth.b * tint.b)
	var wear := _GroundWear.new()
	wear.setup(cols, rows, _rng, path, road, road_col)
	add_child(wear)


## 蜿蜒土路：自出生点（底部中央）走向传送阵（顶部中央），随机左右游走并偶尔加宽
func _path_cells(cols: int, rows: int) -> Dictionary:
	var cells: Dictionary = {}
	var cx := cols / 2
	var y := rows - 3
	while y >= 2:
		cells[Vector2i(cx, y)] = true
		var roll := _rng.randf()
		if roll < 0.34:
			cx -= 1
		elif roll > 0.66:
			cx += 1
		cx = clampi(cx, 4, cols - 5)
		if _rng.randf() < 0.28:  # 加宽一节：岔口由位掩码自动出三岔/四岔
			var side := 1 if _rng.randf() < 0.5 else -1
			cells[Vector2i(clampi(cx + side, 2, cols - 3), y)] = true
		y -= 1
	return cells


## 由相邻格推出出口掩码（北 1 / 东 2 / 南 4 / 西 8）
func _path_mask(cell: Vector2i, cells: Dictionary) -> int:
	var m := 0
	if cells.has(cell + Vector2i(0, -1)):
		m |= 1
	if cells.has(cell + Vector2i(1, 0)):
		m |= 2
	if cells.has(cell + Vector2i(0, 1)):
		m |= 4
	if cells.has(cell + Vector2i(-1, 0)):
		m |= 8
	return m


func _build_world() -> void:
	var cols := int(_map_cfg.get("map_cols", 32))
	var rows := int(_map_cfg.get("map_rows", 42))
	var map_w := float(cols * 48)
	var map_h := float(rows * 48)

	_build_ground_detail(cols, rows)  # 先于 _world 入树：绘制在地砖之上、实体之下

	_world.y_sort_enabled = true
	add_child(_world)

	_build_decos(cols, rows)
	_build_portal(map_w)
	_build_player(map_w, map_h)
	_build_monsters(map_w, map_h)


func _build_decos(cols: int, rows: int) -> void:
	# 散件：随机摆放（避开出生区/传送区/中央通道），origin 底部 + 脚部碰撞，Y-sort 遮挡
	var decos: Array = _theme_cfg.get("decos", [])
	if decos.is_empty():
		return
	var density := float(_theme_cfg.get("deco_density", 0.05))
	var asset_dir := String(_map_cfg.get("asset_dir", "res://image/map"))
	var spawn := Vector2(float(cols) * 24.0, float(rows) * 48.0 - 100.0)
	for gy in rows - 1:
		for gx in cols:
			var center_col := absi(gx - cols / 2) <= 1  # 中央通道密度略降（0.65），保证通行但不显秃
			var d := density * (0.65 if center_col else 1.0)
			if _rng.randf() > d:
				continue
			var pos := Vector2(gx * 48.0 + _rng.randf_range(8, 40),
				gy * 48.0 + _rng.randf_range(8, 40))
			if pos.distance_to(spawn) < 110.0 or pos.y < 200.0:
				continue
			var deco := _Deco.new()
			var tex: Texture2D = load("%s/%s.png" % [asset_dir, String(decos[_rng.randi_range(0, decos.size() - 1)])])
			deco.setup(tex, _rng.randf_range(0.85, 1.18))
			deco.position = pos
			_world.add_child(deco)


func _build_portal(map_w: float) -> void:
	_portal = _Portal.new()
	_portal.position = Vector2(map_w / 2.0, 120.0)
	_portal.locked = String(node.get("type", "normal")) == "boss"
	_world.add_child(_portal)


func _build_player(map_w: float, map_h: float) -> void:
	_player = CharacterBody2D.new()
	_player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player.position = Vector2(map_w / 2.0, map_h - 120.0)
	_player.collision_layer = 1
	_player.collision_mask = 2
	_world.add_child(_player)

	_player_anim = AnimatedSprite2D.new()
	var frames_path := String(ROLE_FRAMES.get(st.role_id, ROLE_FRAMES["zs"])[0])
	_player_anim.sprite_frames = load(frames_path)
	# 角色约占 128×128 帧内 y10~120（110px 高）。0.72 再叠 1.25 倍镜头 ⇒ 屏幕上约 99px＝两格；
	# 帧中心在 y=64，脚底 y=120 ⇒ 局部 +56×0.72＝40.3，故上移 19.3px 让脚踩在碰撞盒下沿（y=21）
	_player_anim.scale = Vector2.ONE * 0.72
	_player_anim.position = Vector2(0, -19.3)
	_player_anim.animation = &"walk_down"
	_player_anim.frame = 1 # neutral passing pose for the initial idle state
	_player_anim.stop()
	_player.add_child(_player_anim)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 26)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	_player.add_child(shape)

	var cam := Camera2D.new()
	# 1.25 倍：视野收到 384×640（约 8×13 格），人物与怪物都放大一圈，不再是"蚂蚁走大图"
	cam.zoom = Vector2.ONE * 1.25
	cam.position = Vector2(0, -56)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map_w)
	cam.limit_bottom = int(map_h)
	cam.enabled = true
	_player.add_child(cam)
	cam.make_current()


func _build_monsters(map_w: float, map_h: float) -> void:
	# 编成：普通 3~4 小怪 / 精英 1+2 / BOSS 1 守阵（§2.5）；散布中上部，互不重叠
	# 非战斗节点（宝箱/事件/商店/篝火）：无怪，放 1 个交互物件（§2.7）
	var nt := String(node.get("type", "normal"))
	if not MON_COLOR.has(nt):
		_build_interactable(map_w, map_h)
		return
	var comp: Array = []
	match nt:
		"boss":
			comp = ["boss"]
		"elite":
			comp = ["elite", "normal", "normal"]
		_:
			comp = ["normal", "normal", "normal", "normal"] if _rng.randf() < 0.5 \
				else ["normal", "normal", "normal"]
	var placed: Array[Vector2] = []
	var pool: Array = _theme_cfg.get("monsters", [])
	for tier in comp:
		var pos := Vector2.ZERO
		for attempt in 24:
			pos = Vector2(_rng.randf_range(120.0, map_w - 120.0),
				_rng.randf_range(460.0, map_h - 320.0))
			if nt == "boss":
				pos = _portal.position + Vector2(0, 130)  # 首领守传送阵
			var ok := true
			for p in placed:
				if p.distance_to(pos) < 140.0:
					ok = false
					break
			if ok:
				break
		placed.append(pos)
		var m := _MapMonster.new()
		m.tier = String(tier)
		# 首领用主题 boss id，其余从怪物池随机；接触开战会把这个 id 继承给战斗组队
		m.mon_id = String(_theme_cfg.get("boss", "")) if String(tier) == "boss" \
			else (String(pool[_rng.randi_range(0, maxi(0, pool.size() - 1))]) if not pool.is_empty() else "")
		m.position = pos
		m.home = pos
		m.map_ref = self
		_monsters.append(m)
		_world.add_child(m)


## 非战斗节点物件：置于玩家出生点与传送阵之间的中途（要走一段路）
func _build_interactable(map_w: float, map_h: float) -> void:
	var it := _Interactable.new()
	it.kind = String(node.get("type", "chest"))
	it.position = Vector2(map_w / 2.0, map_h * 0.45)
	it.map_ref = self
	_interactable = it
	_world.add_child(it)


# ================= HUD =================
## 暗角：中心留亮、四周渐暗（椭圆半径按 480×800 观感取），把视线收到人物身上，
## 同时压掉地图边缘那条直的"贴图断头"。纯视觉层，mouse_filter IGNORE 不吃点击。
func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.42, 0.78])
	grad.colors = PackedColorArray([
		Color(0.06, 0.04, 0.02, 0.0),
		Color(0.06, 0.04, 0.02, 0.0),
		Color(0.04, 0.03, 0.02, 0.60),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 480
	tex.height = 800
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var vig := TextureRect.new()
	vig.texture = tex
	vig.size = Vector2(VIEW_W, VIEW_H)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(vig)


func _build_hud() -> void:
	_hud.layer = 1
	add_child(_hud)
	_build_vignette()  # 最先入层：只在画面四周压暗，不遮住下方的 HUD 控件

	var tc_name := String(_theme_cfg.get("name", "未知"))
	var nt := String(node.get("type", "normal"))
	var nt_name: String = {
		"normal": "遭遇区", "elite": "精英区", "boss": "首领巢穴",
		"chest": "藏宝地", "event": "奇遇", "shop": "商队", "bonfire": "篝火地",
	}.get(nt, "探索")
	var top := G.parchment_box(300, 34, 8.0)
	top.position = Vector2(16, 12)
	_hud.add_child(top)
	var title := G.gold_label("%s · %s" % [tc_name, nt_name], G.FS_SM, false, Color("5a3a1e"), false)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.add_child(title)

	var goal_text := "寻找传送阵"
	if _portal.locked:
		goal_text = "击败首领，解除传送阵封印"
	else:
		goal_text = {
			"chest": "开启宝箱，然后前往传送阵",
			"event": "前方似乎有人影……",
			"shop": "商队在此驻留",
			"bonfire": "生火休整，再启程",
		}.get(nt, goal_text)
	# 目标小签：深色半透明底托，避免压在地图上不可读
	var goal_chip := PanelContainer.new()
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.13, 0.09, 0.05, 0.62)
	gsb.set_corner_radius_all(4)
	gsb.content_margin_left = 10.0
	gsb.content_margin_right = 10.0
	gsb.content_margin_top = 3.0
	gsb.content_margin_bottom = 3.0
	goal_chip.add_theme_stylebox_override("panel", gsb)
	goal_chip.position = Vector2(16, 52)
	var goal := G.gold_label(goal_text, G.FS_XS, false, Color("ffd9a0"), false)
	goal_chip.add_child(goal)
	_hud.add_child(goal_chip)

	# 目标罗盘：一眼看到"该往哪走、还有多远"，点它开始自动前往（手游不用一直搓摇杆）
	_compass = _Compass.new()
	_compass.position = Vector2(16, 78)
	_compass.tapped.connect(_on_compass_tapped)
	_hud.add_child(_compass)

	# HP 条 + 药剂 + 换宠（整行下移让位给目标罗盘小签）
	var panel := G.parchment_box(206, 56, 10.0)
	panel.position = Vector2(16, 114)
	_hud.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	box.add_child(hp_row)
	var bar_bg := Control.new()  # 不用容器布局——手动控制填充条宽度
	bar_bg.custom_minimum_size = Vector2(120, 12)
	bar_bg.clip_contents = true
	hp_row.add_child(bar_bg)
	var bar_sbg := ColorRect.new()
	bar_sbg.color = Color("3a2a18")
	bar_sbg.size = Vector2(120, 12)
	bar_bg.add_child(bar_sbg)
	_hp_fill.color = Color("c05a3a")
	_hp_fill.position = Vector2(2, 2)
	_hp_fill.size = Vector2(116, 8)
	bar_bg.add_child(_hp_fill)
	_pot_l = G.gold_label("", G.FS_XS, false, Color("5a3a1e"), false)
	_pot_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_row.add_child(_pot_l)
	_refresh_hud()

	var potion_btn := G.gold_button("药", 44, 40)
	potion_btn.position = Vector2(232, 122)
	potion_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_use_potion())
	_hud.add_child(potion_btn)

	_pet_btn = G.gold_button("换宠", 72, 40)
	_pet_btn.position = Vector2(284, 122)
	_pet_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_swap_pet())
	_hud.add_child(_pet_btn)

	# 撤离：手边就必须能退出去（PC 亦可按 ESC），点按后二次确认防误触
	# 位置让给右上角小地图（小地图 y 到 116），下移到地图正下方仍是拇指热区
	var exit_btn := G.gold_button("撤离", 60, 40)
	exit_btn.position = Vector2(404, 126)
	exit_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_ask_exit())
	_hud.add_child(exit_btn)

	# 右上角小地图：全局位置感（"我在哪、出口在哪、还有几个人"）
	_minimap = _Minimap.new()
	_minimap.map_ref = self
	_minimap.position = Vector2(_MiniMapPos.x, _MiniMapPos.y)
	_minimap.tapped.connect(_toggle_big_map)
	_hud.add_child(_minimap)

	# 疾行：地图纵深远、步行慢，空跑的那段路要能加速（数据配置 sprint_mult）
	_sprint_btn = G.gold_button("疾行 · 关", 78, 40, G.FS_SM)
	_sprint_btn.position = Vector2(386, VIEW_H - 200)
	_sprint_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_toggle_sprint())
	_hud.add_child(_sprint_btn)

	_joy = _Joystick.new()
	_joy.position = Vector2(28, VIEW_H - 176)
	_hud.add_child(_joy)
	_refresh_hud()  # 覆盖换宠按钮可见性（bench 为空时隐藏）


func _refresh_hud() -> void:
	var m := st.max_hp()
	var hp := m if st.hp < 0 else st.hp
	_hp_fill.size.x = 116.0 * clampf(float(hp) / float(m), 0.0, 1.0)
	_pot_l.text = "药剂 ×%d" % st.potions
	if _pet_btn != null:
		_pet_btn.visible = st.bench_pet != ""


func _use_potion() -> void:
	if _battle != null or _map_done:
		return
	if st.potions <= 0:
		_toast("药剂已用尽")
		return
	var m := st.max_hp()
	var hp := m if st.hp < 0 else st.hp
	if hp >= m:
		_toast("生命已满")
		return
	st.potions -= 1
	var pct := float(TableCache.nodes_config().get("shop", {}).get("potion_heal_pct", 0.35))
	var amt := int(float(m) * pct)
	st.heal(amt)
	_toast("使用药剂：回复 %d 点生命" % amt)
	_refresh_hud()


func _swap_pet() -> void:
	if _battle != null or _map_done or st.bench_pet == "":
		return
	var old := st.active_pet
	st.active_pet = st.bench_pet
	st.bench_pet = old
	_toast("出战宠物已更换")
	_refresh_hud()


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


# ================= 词条三选一 =================
func _show_trait_picker(rows: Array) -> void:
	_picker = TraitPicker.new()
	_picker.setup(rows)
	_picker.picked.connect(_on_trait_picked)
	_hud.add_child(_picker)  # HUD 同层最后添加，盖住其余 HUD


func _on_trait_picked(tid: String) -> void:
	_picker = null
	if tid != "":
		st.traits.append(tid)
		var tname := String(TableCache.get_trait(tid).get("name", ""))
		_toast("获得词条：%s" % tname)
	else:
		_toast("放弃了祝福")
	_refresh_hud()


# ================= 非战斗节点交互（§2.7 物件化） =================
func on_interactable(it: _Interactable) -> void:
	if _map_done or _battle != null or _picker != null or _remover != null:
		return
	it.used = true
	match it.kind:
		"chest":
			Audio.sfx("coin")
			st.add_reward("chest")
			_toast("宝箱开启：金币 +200 · 远征币 +30")
			it.queue_free()
		"event":
			Audio.sfx("coin")
			var gold := _rng.randi_range(80, 150)
			st.gold += gold
			_toast("旅人赠礼：金币 +%d" % gold)
			it.queue_free()
		"shop":
			_shop_supply()
			it.queue_free()
		"bonfire":
			Audio.sfx("reward")
			var amt := st.bonfire_heal()
			st.heal(amt)
			_refresh_hud()
			if st.traits.is_empty():
				_toast("篝火休整：回复 %d 点生命（无词条可弃）" % amt)
			else:
				_toast("篝火休整：回复 %d 点生命" % amt)
				_show_trait_remove()
			it.queue_free()
	_interactable = null


## 商队补给：金够扣钱购药；金不足免费赠 1 瓶（挫败感克制——每节点一次）
func _shop_supply() -> void:
	var shop: Dictionary = TableCache.nodes_config().get("shop", {})
	var cap := int(shop.get("potion_cap", 3))
	var price := int(shop.get("potion_price", 300))
	if st.potions >= cap:
		Audio.sfx("ui_locked")
		_toast("商队补给：药剂已达上限，祝你前路平安")
		return
	if st.gold >= price:
		Audio.sfx("coin")
		st.gold -= price
		st.potions += 1
		_toast("商队补给：购得治疗药剂 ×1（金币 -%d）" % price)
	else:
		Audio.sfx("reward")
		st.potions += 1
		_toast("商队钦佩你的勇气，赠你治疗药剂 ×1")
	_refresh_hud()


## 篝火词条删除浮层（§2.6 删 1 词条）：列表式选择舍弃，或保留全部
func _show_trait_remove() -> void:
	Audio.sfx("ui_open")
	_remover = Control.new()
	_remover.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(_remover, 0.66, true)

	var panel := G.parchment_box(336, 470, 20.0)
	panel.position = Vector2(72, 150)
	_remover.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(G.serif_label("篝火余温", G.FS_LG, Color("8a4a3a")))
	box.add_child(G.gold_label("选择一份舍弃的祝福（或全部保留）", G.FS_SM,
		false, Color("7a5a2e"), false))

	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(296, 300)
	box.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for tid in st.traits:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 36)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("d8c8a0")
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		row.add_theme_stylebox_override("panel", sb)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var t: Dictionary = TableCache.get_trait(String(tid))
		var lbl := G.gold_label(String(t.get("name", String(tid))), G.FS_MD,
			false, Color("3a2a14"), false)
		row.add_child(lbl)
		row.gui_input.connect(_on_remove_row.bind(String(tid)))
		list.add_child(row)

	var keep := G.gold_button("保 留 全 部", 200, 44)
	keep.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_remover("你带着全部祝福离开了篝火"))
	box.add_child(keep)
	_hud.add_child(_remover)


func _on_remove_row(e: InputEvent, tid: String) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var tname := String(TableCache.get_trait(tid).get("name", tid))
	st.traits.erase(tid)
	_close_remover("舍弃词条：%s" % tname)


func _close_remover(msg: String) -> void:
	Audio.sfx("ui_close")
	if _remover != null:
		_remover.queue_free()
		_remover = null
	_refresh_hud()
	if msg != "":
		_toast(msg)


# ================= 撤离 =================
func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:  # 全屏浮层（GM 控制台）优先，ESC 让给它
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	var vp := get_viewport()  # 切场景途中本节点可能已离场，viewport 会是 null
	if _big_map != null:   # 大地图优先：ESC 先收浮层，再谈撤离
		_close_big_map()
		if vp != null:
			vp.set_input_as_handled()
	elif _exit_ui != null:
		_cancel_exit()
		if vp != null:
			vp.set_input_as_handled()
	elif not (_map_done or _battle != null or _picker != null or _remover != null or _beat != null):
		_ask_exit()
		if vp != null:
			vp.set_input_as_handled()


## 撤离确认：本节点进度保留（可再次进入），但局内累计资源需重新挑战才结算
func _ask_exit() -> void:
	if _exit_ui != null or _map_done or _battle != null:
		return
	Audio.sfx("ui_open")
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_ui = layer
	_hud.add_child(layer)

	# 撤离确认底衬：统一工厂（深棕 + 暗角 + 斜纹），保持浮层质感一致
	G.veil(layer, 0.72, true)

	var banner := G.banner_box("撤离本节点", 260, 48)
	banner.position = Vector2((VIEW_W - 260.0) * 0.5, 264)
	layer.add_child(banner)

	var panel := G.parchment_box(340, 190, 16.0)
	panel.position = Vector2((VIEW_W - 340.0) * 0.5, 328)
	layer.add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var tip := G.gold_label("撤离将返回路线图，本节点进度保留，\n可稍后再次进入。", G.FS_SM, false, Color("5a3a1e"), false)
	tip.position = Vector2(0, 16)
	tip.custom_minimum_size = Vector2(308, 0)
	content.add_child(tip)

	var stay := G.gold_button("继 续 探 索", 140, 42)
	stay.position = Vector2(0, 100)
	stay.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_cancel_exit())
	content.add_child(stay)

	var leave := G.gold_button("撤 离", 140, 42)
	leave.position = Vector2(168, 100)
	leave.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _exit_ui != null:
				_exit_ui.queue_free()
				_exit_ui = null
			_finish_map("exited"))
	content.add_child(leave)


func _cancel_exit() -> void:
	Audio.sfx("ui_close")
	if _exit_ui != null:
		_exit_ui.queue_free()
		_exit_ui = null


# ================= 主循环 =================
func _physics_process(delta: float) -> void:
	if _map_done or _battle != null or _picker != null or _remover != null \
			or _exit_ui != null or _beat != null or _big_map != null:
		return
	if G.ui_blocked:  # GM 控制台等全屏浮层打开时冻结移动
		return
	if _player == null:
		return
	# 输入：WASD/方向键（PC）+ 摇杆向量（移动端）
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _joy != null:
		dir = (dir + _joy.vector).limit_length(1.0)
	# 手动输入优先级最高：一推摇杆/一键键盘就交还控制权（自动前往不会跟玩家抢方向盘）
	if _auto_walk and dir.length_squared() > 0.01:
		_stop_auto_walk("")
	elif _auto_walk:
		dir = _auto_dir(delta)
	var speed := float(_map_cfg.get("player_speed", 130.0))
	if _sprint:
		speed *= float(_map_cfg.get("sprint_mult", 1.6))
	_prev_pos = _player.position
	_player.velocity = dir * speed
	_player.move_and_slide()
	# 地图边界夹紧
	var cols := int(_map_cfg.get("map_cols", 32))
	var rows := int(_map_cfg.get("map_rows", 42))
	_player.position = _player.position.clamp(Vector2(24, 60), Vector2(cols * 48 - 24, rows * 48 - 24))
	_update_player_anim(dir)
	_tick_auto_walk(delta)
	_update_nav()
	_check_portal()


func _update_player_anim(dir: Vector2) -> void:
	if dir.length_squared() < 0.01:
		_player_anim.stop()
		_player_anim.frame = 1 # neutral passing pose, not a wide contact pose
		return
	var anim := &"walk_down"
	if absf(dir.x) > absf(dir.y):
		anim = &"walk_right" if dir.x > 0 else &"walk_left"
	else:
		anim = &"walk_down" if dir.y > 0 else &"walk_up"
	if _player_anim.animation != anim:
		_player_anim.animation = anim
	# 步频随实际移速缩放：4关键帧@8FPS，88px/s 时每循环约移动44px，
	# 摇杆半速推动时步子放慢，避免任何速度下的滑步感
	# 基准改为配置里的步行速度：疾行时步频自然加快，不再锁死在旧写死的 88
	_player_anim.speed_scale = clampf(_player.velocity.length()
		/ maxf(1.0, float(_map_cfg.get("player_speed", 100.0))), 0.55, 2.0)
	if not _player_anim.is_playing():
		_player_anim.play()


# ================= 导航三件套（小地图 / 目标罗盘 / 疾行） =================
## 地图世界尺寸（像素）
func _map_extent() -> Vector2:
	return Vector2(float(int(_map_cfg.get("map_cols", 32))) * 48.0,
		float(int(_map_cfg.get("map_rows", 42))) * 48.0)


## 当前该去哪：优先未使用过的物件（宝箱/事件/商店/篝火），
## 传送阵被封印时先指向守阵首领，其余一律指向传送阵
func _nav_info() -> Dictionary:
	if _interactable != null and not _interactable.used:
		var kind := String(_interactable.kind)
		var n: String = {"chest": "宝箱", "event": "奇遇", "shop": "商队",
			"bonfire": "篝火"}.get(kind, "目标")
		return {"name": n, "pos": _interactable.position, "kind": kind}
	if _portal != null and _portal.locked:
		for m in _monsters:
			if m.tier == "boss":
				return {"name": "首领", "pos": m.position, "kind": "boss"}
	if _portal != null:
		return {"name": "传送阵", "pos": _portal.position, "kind": "portal"}
	return {"name": "", "pos": Vector2.ZERO, "kind": ""}


func _update_nav() -> void:
	var info := _nav_info()
	if _compass != null:
		_compass.set_target(String(info.get("name", "")), info.get("pos", Vector2.ZERO),
			_player.position if _player != null else Vector2.ZERO, _auto_walk)
	if _minimap != null:
		_minimap.queue_redraw()


## 罗盘被点：开始 / 停止自动前往（把"按住摇杆走 20 秒"变成一次点击）
func _on_compass_tapped() -> void:
	if _auto_walk:
		_stop_auto_walk("")
		return
	if _map_done or _battle != null or _picker != null or _remover != null:
		return
	var info := _nav_info()
	if String(info.get("kind", "")).is_empty():
		return
	Audio.sfx("ui_confirm")
	_auto_walk = true
	_auto_time = 0.0
	_auto_stuck = 0.0
	_auto_dodge = 0.0
	_toast("前往%s · 推动摇杆可随时接手" % String(info.get("name", "目标")))


func _start_auto_walk() -> void:
	_on_compass_tapped()


func _stop_auto_walk(msg: String) -> void:
	if not _auto_walk:
		return
	_auto_walk = false
	_auto_time = 0.0
	_auto_stuck = 0.0
	_auto_dodge = 0.0
	if msg != "":
		_toast(msg)


## 自动前往的转向：直线朝目标；被散件挡住时先沿切线绕一段再回来
func _auto_dir(delta: float) -> Vector2:
	var info := _nav_info()
	var to := (info.get("pos", Vector2.ZERO) as Vector2) - _player.position
	if to.length() < 24.0:
		_stop_auto_walk("")
		return Vector2.ZERO
	_auto_time += delta
	if _auto_time > AUTO_TIMEOUT:
		_stop_auto_walk("前路不通——请你亲自来")
		return Vector2.ZERO
	if _auto_dodge > 0.0:
		_auto_dodge -= delta
		var side := to.normalized().rotated(PI * 0.5 * _auto_dodge_side)
		return side
	return to.normalized()


## 卡住判定：实际位移远低于预期持续一小段，就换一侧绕行（树林/岩石多的图不会卡死）
func _tick_auto_walk(delta: float) -> void:
	if not _auto_walk or _player == null:
		return
	var moved := _player.position.distance_to(_prev_pos)
	var expected := float(_map_cfg.get("player_speed", 88.0)) * delta * 0.45
	if moved < expected:
		_auto_stuck += delta
	else:
		_auto_stuck = 0.0
	if _auto_stuck > 0.22:
		_auto_stuck = 0.0
		_auto_dodge = 0.5
		_auto_dodge_side = -_auto_dodge_side


func _toggle_sprint() -> void:
	_sprint = not _sprint
	if _sprint_btn != null:
		var l := _sprint_btn.get_child(0) as Label
		if l != null:
			l.text = "疾行 · 开" if _sprint else "疾行 · 关"
	Audio.sfx("ui_click")


## 大地图：点小地图呼出，看清整片地形与全部目标；带图例与返回按钮
func _toggle_big_map() -> void:
	if _big_map != null:
		_close_big_map()
		return
	if _map_done or _battle != null:
		return
	Audio.sfx("ui_open")
	_big_map = Control.new()
	_big_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_big_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.add_child(_big_map)
	G.veil(_big_map, 0.74, true)

	var banner := G.banner_box("地 图", 200, 46)
	banner.position = Vector2((VIEW_W - 200.0) * 0.5, 40)
	_big_map.add_child(banner)

	var panel := G.parchment_box(400, 560, 16.0)
	panel.position = Vector2(40, 108)
	_big_map.add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var mm := _Minimap.new()
	mm.map_ref = self
	mm.big = true
	mm.position = Vector2(54, 6)
	content.add_child(mm)

	var ext := _map_extent()
	var lines := [
		"全图 %d × %d 格（约 %.0f × %.0f 步）" % [int(ext.x / 48.0), int(ext.y / 48.0),
			ext.x / 48.0, ext.y / 48.0],
		"金点：你所在的位置 · 亮框：当前视野",
		"青点：传送阵（封印时转紫）· 金菱：宝箱 / 事件 / 商队 / 篝火",
		"红点：敌影（视野内才会显形）",
		"点下方「前 往」自动走到当前目标；再推摇杆即可接手",
	]
	for i in lines.size():
		var l := G.text_label(String(lines[i]), G.FS_XS, Color("5a3a1e"))
		l.position = Vector2(16, 360 + float(i) * 21.0)
		l.custom_minimum_size = Vector2(336, 0)
		content.add_child(l)

	var go := G.gold_button("前 往", 148, 44)
	go.position = Vector2(24, 474)
	go.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_big_map()
			_start_auto_walk())
	content.add_child(go)
	var back := G.gold_button("返 回", 148, 44)
	back.position = Vector2(192, 474)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_big_map())
	content.add_child(back)


func _close_big_map() -> void:
	if _big_map == null:
		return
	Audio.sfx("ui_close")
	_big_map.queue_free()
	_big_map = null


func _check_portal() -> void:
	if _map_done:
		return
	if _player.position.distance_to(_portal.position) < 36.0:
		if _portal.locked:
			if not _portal.warned:
				_portal.warned = true
				_toast("传送阵被首领封印——先击败它！")
		else:
			_finish_map("cleared")


func _finish_map(result: String) -> void:
	if _map_done:
		return
	_map_done = true
	if result == "cleared":
		st.node_cleared(int(node.get("layer", 1)), int(node.get("index", 0)))
	map_finished.emit(result)


# ================= 怪物接触开战 =================
func on_monster_contact(m: _MapMonster) -> void:
	if _battle != null or _map_done:
		m.chasing_contact = false  # 并行触发的接触复位
		return
	_start_battle(m)


func _start_battle(m: _MapMonster) -> void:
	m.chasing_contact = true  # 接触怪冻结
	_contact_mon = m
	# BOSS 战前「对峙」：第一次挑战这片秘境的首领时演一段（看过的不再拦人）
	if m.tier == "boss" and not G.beat_seen(st.theme, "intro") \
			and not G.boss_beat_lines(st.theme, "intro").is_empty():
		G.mark_beat_seen(st.theme, "intro")
		_play_boss_beat("intro", func(): _launch_battle(m))
		return
	_launch_battle(m)


## 真正的开战（演出结束后 / 无演出时直接进）
func _launch_battle(m: _MapMonster) -> void:
	BattleScene.pending_cfg = {
		"ally": {
			"role_id": st.role_id,
			"level": st.level,
			"traits": st.traits.duplicate(),
			"active_pet": st.active_pet,
			"bench_pet": st.bench_pet,
			"potions": st.potions,
			"hp_override": st.hp,
			# 局外养成 6 线加成（天赋/装备/坐骑/称号 + 技能书等级 + 宠物养成快照）
			"growth": G.growth_bonuses(st.role_id),
			"skill_levels": G.prog.get("skills", {}),
			"pet_stats": G.battle_pet_stats([st.active_pet, st.bench_pet]),
		},
		"enemy": {"theme": st.theme, "node_type": m.tier,
			"layer": int(node.get("layer", 1)), "lead_mon": m.mon_id},
		"seed": st.next_battle_seed(),
	}
	_battle_layer = CanvasLayer.new()
	_battle_layer.layer = 2
	add_child(_battle_layer)
	_battle = (load("res://src/battle/BattleScene.tscn") as PackedScene).instantiate()
	_battle.battle_finished.connect(_on_battle_end)
	_battle_layer.add_child(_battle)


func _on_battle_end(result: String, hp_left: int) -> void:
	var battle := _battle
	var monster_tier := _contact_mon.tier if _contact_mon != null else ""
	_battle = null
	_battle_layer.queue_free()  # 级联释放 BattleScene
	_battle_layer = null
	st.apply_battle_result(battle.sim)

	if result != "victory":
		st.finished = true
		st.result = "defeat"
		_finish_map("defeat")
		return
	st.add_reward(monster_tier)  # 战利按接触怪 tier 累加（nodes.json rewards）
	_grant_drops(monster_tier)   # 材料掉落（data/drops.json）：刷图产出养成材料
	st.hp = hp_left
	# 主城委托上报：这一场打掉的怪算 1 只（"在某某秘境击杀 N 只"类委托靠它推进）
	var q_done := G.quest_report("slay", st.theme, 1)
	for t in q_done:
		_toast("委托办妥：%s —— 回城交付" % String(t))
	# 接触的怪离场
	if _contact_mon != null:
		_monsters.erase(_contact_mon)
		_contact_mon.queue_free()
		_contact_mon = null
	# 其余怪复位并返回巢穴
	for m in _monsters:
		m.chasing_contact = false
		m.retreat_home()
	# 首领解封传送阵；首次击败时先演一段「战后余韵」，再回词条三选一
	if monster_tier == "boss":
		if _portal != null:
			_portal.locked = false
			_toast("首领陨落——传送阵封印解除！")
		if not G.beat_seen(st.theme, "outro") \
				and not G.boss_beat_lines(st.theme, "outro").is_empty():
			G.mark_beat_seen(st.theme, "outro")
			_play_boss_beat("outro", _after_battle_rewards)
			_refresh_hud()
			return
	_after_battle_rewards()


## 掉落结算：掷表 → grant_item → 汇总一句 toast（没有掉落就安静）
func _grant_drops(tier: String) -> void:
	var rows := G.roll_drops(tier)
	if rows.is_empty():
		return
	var parts := PackedStringArray()
	for r in rows:
		var d := r as Dictionary
		var iid := String(d.get("item", ""))
		var n := int(d.get("n", 1))
		G.grant_item(iid, n)
		parts.append("%s ×%d" % [G.item_name(iid), n])
	_toast("拾获：" + " · ".join(parts))


func _after_battle_rewards() -> void:
	# 战斗胜利三选一词条（§2.4：槽1数值机制/槽2流派85%双刃15%/槽3全池）
	var choices := st.roll_trait_choices(_rng)
	if choices.is_empty():
		_toast("词条池已尽")
	else:
		_show_trait_picker(choices)
	_refresh_hud()


## 首领剧情演出（"intro" 对峙 / "outro" 余韵）：全屏演出层，结束后回调
func _play_boss_beat(kind: String, after: Callable) -> void:
	var beat := StoryBeatScript.new()
	beat.setup(st.theme, kind)
	beat.on_done = after
	var layer := CanvasLayer.new()
	layer.layer = 3   # 压过战斗层（2）与 HUD
	add_child(layer)
	beat.finished.connect(func():
		_beat = null
		layer.queue_free())
	_beat = beat
	layer.add_child(beat)


# ================= 局部节点 =================
## 地面磨损层：低透明度不规则斑块 + 碎屑点，打散地砖的规则重复感（不参与碰撞/Y-sort）
## 无套件主题的土路由"逐格方块"改为圆头连线（圆接头），消除 48px 方块的阶梯感
class _GroundWear extends Node2D:
	const ROAD_R := 20.0      # 路面半径（≈0.42 格，两侧各留 4px 地砖缝，免得像整格贴图）
	const ROAD_W := 40.0      # 连线宽度＝2R，与圆端等宽才对得上

	var _blobs: Array = []    # [pos, rx, ry, color]
	var _specks: Array = []   # [pos, r, color]
	var _road: Array = []     # 路面格中心（空＝该主题用套件贴图铺路）
	var _links: Array = []    # [[中心, 中心]] 相邻路格连线
	var _road_col := Color("6b5334")

	func setup(cols: int, rows: int, rng: RandomNumberGenerator, path: Dictionary,
			road: Array, road_col: Color) -> void:
		var w := float(cols * 48)
		var h := float(rows * 48)
		_road = road
		_road_col = road_col
		if not road.is_empty():
			# 邻居只取东/南/东南/东北，四向即可覆盖每一对相邻格且不重复成对。
			# 必须含对角：路径每上行一格就左右挪一列，只连正交会断成一串孤零零的圆饼。
			for cell: Vector2i in path.keys():
				var a := Vector2(float(cell.x) * 48.0 + 24.0, float(cell.y) * 48.0 + 24.0)
				for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
					if path.has(cell + d):
						_links.append([a, Vector2(float(cell.x + d.x) * 48.0 + 24.0,
							float(cell.y + d.y) * 48.0 + 24.0)])
			for c: Vector2 in _road:  # 土面碎屑：踩实的路不该是纯色块
				for i in 5:
					var p := c + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-16.0, 16.0))
					var a2 := rng.randf_range(0.07, 0.17)
					var col := Color(0.18, 0.14, 0.09, a2) if rng.randf() < 0.6 \
						else Color(0.98, 0.93, 0.80, a2 * 0.8)
					_specks.append([p, rng.randf_range(1.0, 2.0), col])
		# 地面磨损：小、淡、软。半径封在 0.4 格以内、透明度封在 0.07 以内——
		# 之前放到 38px/0.11 就成了满屏深色水渍，比它要打散的棋盘格还抢眼。
		for i in int(cols * rows * 0.16):
			var pos := Vector2(rng.randf_range(0.0, w), rng.randf_range(0.0, h))
			if path.has(Vector2i(int(pos.x / 48.0), int(pos.y / 48.0))):
				continue  # 土路上不压暗斑，免得路被糊掉
			var dark := rng.randf() < 0.62
			var a := rng.randf_range(0.030, 0.070)
			var col := Color(0.11, 0.09, 0.06, a) if dark else Color(1.0, 0.96, 0.84, a * 0.9)
			_blobs.append([pos, rng.randf_range(7.0, 20.0), rng.randf_range(5.0, 14.0), col])
		for i in int(cols * rows * 0.30):
			var pos := Vector2(rng.randf_range(0.0, w), rng.randf_range(0.0, h))
			var a := rng.randf_range(0.05, 0.13)
			var col := Color(0.12, 0.10, 0.07, a) if rng.randf() < 0.7 else Color(0.92, 0.88, 0.74, a)
			_specks.append([pos, rng.randf_range(1.0, 1.8), col])

	func _draw() -> void:
		if not _road.is_empty():
			_draw_road()
		_draw_wear()

	## 程序土路：一圈更宽的淡路缘（把路"融"进地砖）→ 暗边 → 亮面 → 极淡路心
	func _draw_road() -> void:
		var rim := _road_col.darkened(0.30)
		var top := _road_col.lightened(0.18)  # 踩干的土偏亮，深褐会像泥坑
		var feather := Color(rim.r, rim.g, rim.b, 0.16)
		for c: Vector2 in _road:
			draw_circle(c, ROAD_R + 7.0, feather)
		for l: Array in _links:
			draw_line(l[0], l[1], feather, ROAD_W + 14.0)
		for c: Vector2 in _road:
			draw_circle(c, ROAD_R + 2.5, rim)
		for l: Array in _links:
			draw_line(l[0], l[1], rim, ROAD_W + 5.0)
		for c: Vector2 in _road:
			draw_circle(c, ROAD_R, top)
		for l: Array in _links:
			draw_line(l[0], l[1], top, ROAD_W)
		# 中央被踩得更实：一条极淡的亮心，给路面一点起伏
		var crown := Color(top.r * 1.12, top.g * 1.09, top.b * 1.05, 0.14)
		for l: Array in _links:
			draw_line(l[0], l[1], crown, ROAD_W * 0.40)

	## 磨损斑块：同心两圈叠出柔和边缘（单圈实心会像水渍）
	func _draw_wear() -> void:
		for b: Array in _blobs:
			draw_set_transform(b[0], 0.0, Vector2(1.0, b[2] / b[1]))
			var col: Color = b[3]
			draw_circle(Vector2.ZERO, b[1], col)
			draw_circle(Vector2.ZERO, b[1] * 0.55, Color(col.r, col.g, col.b, col.a * 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for s: Array in _specks:
			draw_circle(s[0], s[1], s[2])


## 散件（origin 底部 + 脚部碰撞，参与 Y-sort）
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


## 传送阵（双环旋转；BOSS 节点初始封印）
class _Portal extends Node2D:
	var locked := false
	var warned := false
	var _rot := 0.0

	func _process(delta: float) -> void:
		_rot += delta * (0.6 if locked else 1.8)
		queue_redraw()

	func _draw() -> void:
		var base := Color("8a6a9a") if locked else Color("7ae0ff")
		var glow := Color(base.r, base.g, base.b, 0.25)
		draw_circle(Vector2.ZERO, 40.0, glow)
		var n := 24
		for i in n:
			var a := _rot + TAU * float(i) / float(n)
			var p := Vector2(cos(a), sin(a)) * 28.0
			draw_circle(p, 3.0, base if i % 2 == 0 else Color(base.r, base.g, base.b, 0.4))
		draw_arc(Vector2.ZERO, 18.0, _rot, _rot + TAU * 0.7, 16, base, 2.5)
		draw_circle(Vector2.ZERO, 8.0, Color(base.r, base.g, base.b, 0.6))


## 怪物（mon_ 精灵优先，无素材回退程序圆体；游荡/警戒/追击/接触回调）
class _MapMonster extends Node2D:
	var tier := "normal"
	var mon_id := ""                  # 具体怪 id（精灵与战斗组队都按它）
	var home := Vector2.ZERO
	var chasing_contact := false  # 本只已触发接触（开战中）
	var map_ref: MapScene = null
	var _state := "wander"  # wander / chase
	var _target := Vector2.ZERO
	var _wait := 0.0
	var _radius := 20.0
	var _aggro := 120.0
	var _contact := 26.0
	var _wander_r := 96.0
	var _t := 0.0
	var _sprite: Sprite2D = null    # 有 mon_ 素材时的精灵体
	var _lobe: Array = []  # 每只固定不变的轮廓起伏，避免看着像同一个圆

	func _ready() -> void:
		_radius = {"normal": 20.0, "elite": 25.0, "boss": 32.0}.get(tier, 20.0)
		var mc: Dictionary = TableCache.maps_config()
		_aggro = float(mc.get("aggro_radius", 120.0))
		_contact = float(mc.get("contact_radius", 26.0))
		_wander_r = float(mc.get("monster_wander_radius", 96.0))
		# 精灵体：boss 84 / elite 60 / normal 48 像素高，脚底对齐碰撞原点
		if mon_id != "":
			var tex: Texture2D = G.res_tex(mon_id)
			if tex != null:
				var h: float = {"normal": 48.0, "elite": 60.0, "boss": 84.0}.get(tier, 48.0)
				var s := h / float(tex.get_height())
				_sprite = Sprite2D.new()
				_sprite.texture = tex
				_sprite.scale = Vector2.ONE * s
				_sprite.offset = Vector2(0, -tex.get_height() / 2.0)
				add_child(_sprite)
		var h := float(absi(hash(Vector2(position).floor())))
		for i in 18:
			_lobe.append(sin(float(i) * 2.1 + h) * 0.13 + sin(float(i) * 0.7 + h * 0.5) * 0.09)
		_pick_wander_target()

	func _pick_wander_target() -> void:
		var a := randf() * TAU
		var d := randf() * _wander_r
		_target = home + Vector2(cos(a), sin(a)) * d

	func _process(delta: float) -> void:
		_t += delta
		if map_ref == null or map_ref._player == null:
			return
		if chasing_contact or map_ref._map_done or map_ref._battle != null or map_ref._picker != null:
			return  # 接触中 / 地图结束 / 战斗覆盖层 / 三选一期间冻结
		var player: CharacterBody2D = map_ref._player
		var dist := position.distance_to(player.position)
		if dist < _contact:
			chasing_contact = true
			map_ref.on_monster_contact(self)
			return
		if dist < _aggro and not map_ref._map_done and map_ref._battle == null:
			_state = "chase"
		elif _state == "chase" and dist > _aggro * 1.4:
			_state = "wander"
			_pick_wander_target()
		var speed := 40.0
		if _state == "chase":
			_target = player.position
			speed = float(TableCache.maps_config().get("player_speed", 130.0)) * 0.9
		var to := _target - position
		if to.length() > 6.0:
			position += to.normalized() * speed * delta
		elif _state == "wander":
			_wait += delta
			if _wait > randf_range(0.8, 2.2):
				_wait = 0.0
				_pick_wander_target()
		queue_redraw()

	func retreat_home() -> void:
		_state = "wander"
		_target = home

	func _draw() -> void:
		# 精灵体：只画地面影 + 追击警示环（追击时精灵边缘泛红圈）
		var col: Color = MapScene.MON_COLOR.get(tier, Color.GRAY)
		var bob := sin(_t * 5.0) * 1.6
		var r := _radius

		# 地面投影
		draw_set_transform(Vector2(0, r * 0.72), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, r * 1.02, Color(0, 0, 0, 0.32))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if _sprite != null:
			if _state == "chase":
				draw_arc(Vector2.ZERO, r + 8.0, 0.0, TAU, 20, Color(1.0, 0.4, 0.3, 0.85), 2.0)
			return

		# 程序占位怪物：不规则轮廓 + 背光边缘 + 发光眼 + 地面投影（不再是光秃秃一个圆）
		var body := col if _state == "wander" else col.lightened(0.22)

		# 轮廓：按固定起伏生成有机外形
		var pts := PackedVector2Array()
		var n := 18
		for i in n:
			var a := TAU * float(i) / float(n)
			var rr := r * (1.0 + float(_lobe[i]))
			pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.94 + bob))
		draw_colored_polygon(pts, body)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(0, 0, 0, 0.34), 2.0, true)

		# 体积：下腹压暗 + 左上高光 + 背光描边
		draw_circle(Vector2(0, r * 0.30 + bob), r * 0.62, Color(0, 0, 0, 0.16))
		draw_circle(Vector2(-r * 0.30, -r * 0.34 + bob), r * 0.30, Color(1, 1, 1, 0.10))
		draw_arc(Vector2(0, bob), r * 1.02, PI * 0.85, PI * 1.95, 14, Color(1, 1, 1, 0.16), 2.0)

		# 层级特征：立耳 / 尖冠 / 巨角
		var horn := Color(col.r * 0.55, col.g * 0.5, col.b * 0.55)
		match tier:
			"elite":
				for i in 5:
					var a := PI * 0.15 + PI * 0.7 * float(i) / 4.0
					var base := Vector2(cos(a), sin(a)) * r * 0.96 + Vector2(0, bob)
					draw_line(base, base + Vector2(cos(a), sin(a)) * 9.0, horn, 3.0)
			"boss":
				for i in 3:
					var a := -PI * 0.5 + (float(i) - 1.0) * 0.62
					var base := Vector2(cos(a), sin(a)) * r * 0.96 + Vector2(0, bob)
					draw_line(base, base + Vector2(cos(a), sin(a)) * 16.0, horn, 4.0)
				draw_arc(Vector2(0, bob), r + 5.0, -PI * 0.85, -PI * 0.15, 16, Color(1, 0.5, 0.35, 0.5), 2.0)
			_:
				for i in 2:
					var a := -PI * 0.5 + (float(i) * 2.0 - 1.0) * 0.45
					var base := Vector2(cos(a), sin(a)) * r * 0.96 + Vector2(0, bob)
					draw_line(base, base + Vector2(cos(a), sin(a)) * 8.0, horn, 3.0)

		# 眼睛：追击时亮起
		var eye := Color("ff5a4a") if tier == "boss" else Color("ffd25a")
		var eye_col := eye if _state == "chase" else Color(eye.r, eye.g, eye.b, 0.85)
		var ey := -r * 0.20 + bob
		draw_circle(Vector2(-r * 0.30, ey), r * 0.24, Color(0.06, 0.05, 0.07, 0.9))
		draw_circle(Vector2(r * 0.30, ey), r * 0.24, Color(0.06, 0.05, 0.07, 0.9))
		draw_circle(Vector2(-r * 0.30, ey), r * 0.13, eye_col)
		draw_circle(Vector2(r * 0.30, ey), r * 0.13, eye_col)

		# 追击警示
		if _state == "chase":
			draw_arc(Vector2(0, bob), r + 8.0, 0.0, TAU, 20, Color(1.0, 0.4, 0.3, 0.85), 2.0)


## 非战斗节点交互物件（node_* 素材优先，无素材回退程序绘制）
## 宝箱/商店/篝火/事件各有立绘；头顶金三角标可交互
class _Interactable extends Node2D:
	const KIND_ART := {  # kind → 素材名（generated node_* 系列）
		"chest": "node_chest", "event": "node_event",
		"shop": "node_shop", "bonfire": "node_campfire",
	}
	var kind := "chest"  # chest / event / shop / bonfire
	var used := false
	var map_ref: MapScene = null
	var _t := 0.0
	var _art := false       # 已用素材立绘（程序体跳过）
	var _art_h := 64.0      # 立绘显示高（三角提示的高度基准）

	func _ready() -> void:
		var tex: Texture2D = G.res_tex(String(KIND_ART.get(kind, "")))
		if tex != null:
			var s := _art_h / float(tex.get_height())
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.scale = Vector2.ONE * s
			spr.offset = Vector2(0, -tex.get_height() / 2.0)
			add_child(spr)
			_art = true

	func _process(delta: float) -> void:
		_t += delta
		if used or map_ref == null or map_ref._player == null:
			return
		if map_ref._battle != null or map_ref._picker != null or map_ref._remover != null:
			return  # 覆盖层期间不触发
		if position.distance_to(map_ref._player.position) < MapScene.INTERACT_R:
			map_ref.on_interactable(self)
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2(0, 6), 30.0, Color(0, 0, 0, 0.22))  # 落地影
		if not _art:
			match kind:
				"chest":
					_draw_chest()
				"event":
					_draw_event()
				"shop":
					_draw_shop()
				"bonfire":
					_draw_bonfire()
		# 头顶浮动金三角（可交互提示；立绘版抬高点避免压住画面）
		var bob := sin(_t * 2.2) * 4.0
		var tip := Vector2(0, (-_art_h - 8.0 if _art else -52.0) + bob)
		draw_colored_polygon([tip + Vector2(0, -7), tip + Vector2(6, 3), tip + Vector2(-6, 3)],
			Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.9))

	func _draw_chest() -> void:
		draw_rect(Rect2(-20, -18, 40, 26), Color("7a5228"))       # 箱体
		draw_rect(Rect2(-20, -26, 40, 12), Color("5a3a1a"))       # 箱盖
		draw_rect(Rect2(-20, -18, 40, 3), Color("3a2812"))        # 盖缝
		draw_rect(Rect2(-4, -20, 8, 12), Color(G.GOLD))           # 金锁
		draw_arc(Vector2.ZERO, 2.5, 0, TAU, 10, Color("5a3a1a"), 2.0)  # 锁孔

	func _draw_event() -> void:
		draw_rect(Rect2(-11, -34, 22, 40), Color("8a8578"))       # 石碑
		draw_circle(Vector2(0, -34), 11.0, Color("8a8578"))       # 圆顶
		draw_rect(Rect2(-13, -2, 26, 8), Color("6a655a"))         # 底座
		var ts := G.font_bold.get_string_size("?", HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		draw_string(G.font_bold, Vector2(-ts.x / 2.0, -16), "?",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color("3a3a30"))

	func _draw_shop() -> void:
		draw_colored_polygon([Vector2(0, -44), Vector2(26, 4), Vector2(-26, 4)],
			Color("5a8a4a"))                                       # 帐篷顶
		draw_rect(Rect2(-26, 4, 52, 6), Color("6b4a28"))          # 摊板
		draw_line(Vector2(-26, 4), Vector2(0, -44), Color("3a5a30"), 2.0)
		draw_line(Vector2(26, 4), Vector2(0, -44), Color("3a5a30"), 2.0)
		draw_rect(Rect2(-8, -10, 16, 12), Color("c9a44a"))        # 摊位货箱

	func _draw_bonfire() -> void:
		draw_line(Vector2(-16, 2), Vector2(14, -14), Color("5a3a1a"), 7.0)   # 交叉柴
		draw_line(Vector2(16, 2), Vector2(-14, -14), Color("4a2f14"), 7.0)
		draw_circle(Vector2(-10, 3), 6.0, Color("6a655a"))         # 垫石
		draw_circle(Vector2(10, 3), 6.0, Color("6a655a"))
		# 火苗（三层，sin 呼吸）
		var f := 1.0 + sin(_t * 6.0) * 0.15
		var glow := Color(1.0, 0.55, 0.2, 0.28)
		draw_circle(Vector2(0, -12), 22.0 * f, glow)
		draw_circle(Vector2(0, -12), 12.0 * f, Color("e07030"))
		draw_circle(Vector2(0, -15), 8.0 * f, Color("f0a040"))
		draw_circle(Vector2(0, -18), 4.5 * f, Color("ffd070"))


## 小地图：把整张 32×42 的地图装进方块里——黄框是当前视野，玩家一眼知道自己在哪、
## 出口在哪、目标物件在哪。点一下放大成大地图（看清全貌 + 图例）。
## 敌影只在视野附近显形（reveal_radius），远处保留"未知"，不至于变成上帝视角。
class _Minimap extends Control:
	signal tapped

	var map_ref: MapScene = null
	var big := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(260.0, 342.0) if big \
			else Vector2(MapScene.MINI_W, MapScene.MINI_H)
		size = custom_minimum_size   # 非容器控件不会自动吃最小尺寸，必须显式给宽高

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit()

	func _draw() -> void:
		if map_ref == null:
			return
		var sz := size
		if sz.x <= 1.0 or sz.y <= 1.0:
			sz = custom_minimum_size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.08, 0.06, 0.04, 0.74))
		draw_rect(Rect2(Vector2.ZERO, sz), Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.42), false, 1.5)

		var ext := map_ref._map_extent()
		var s := minf(sz.x / ext.x, sz.y / ext.y)
		var off := (sz - ext * s) * 0.5
		var at := func(p: Vector2) -> Vector2: return off + p * s
		draw_rect(Rect2(off, ext * s), Color(0.30, 0.25, 0.17, 0.50))

		var reveal := float(map_ref._map_cfg.get("map_reveal_radius", 520.0))
		var pp := map_ref._player.position if map_ref._player != null else Vector2.ZERO

		# 当前视野框（相机 1.25 倍 ⇒ 384×640；相机带 (0,-56) 偏移，位在玩家上方）
		var view := Vector2(384.0, 640.0)
		var vc := pp + Vector2(0, -56.0)
		draw_rect(Rect2(at.call(vc - view * 0.5), view * s),
			Color(1.0, 0.98, 0.90, 0.16), false, 1.5)

		# 传送阵（封印为紫）
		if map_ref._portal != null:
			var pc := Color("8a6a9a") if map_ref._portal.locked else Color("7ae0ff")
			_pt(at.call(map_ref._portal.position), 4.0, pc)
		# 目标物件（金菱）
		if map_ref._interactable != null and not map_ref._interactable.used:
			var ip: Vector2 = at.call(map_ref._interactable.position)
			draw_colored_polygon([ip + Vector2(0, -4.5), ip + Vector2(3.6, 0), ip + Vector2(-3.6, 0)],
				Color("ffd980"))
		# 敌影（视野内）
		for m in map_ref._monsters:
			if m.position.distance_to(pp) <= reveal or m.tier == "boss":
				_pt(at.call(m.position), 2.6, Color("e0664a"))
		# 玩家（金点 + 朝向短须）
		draw_circle(at.call(pp), 3.4, Color("ffe9a8"))
		var face := Vector2.ZERO
		if is_instance_valid(map_ref._player_anim):
			match String(map_ref._player_anim.animation):
				"walk_up": face = Vector2(0, -1)
				"walk_down": face = Vector2(0, 1)
				"walk_left": face = Vector2(-1, 0)
				_: face = Vector2(0, 1)
		draw_line(at.call(pp), at.call(pp) + face * 6.0, Color("ffe9a8"), 1.5)

	func _pt(p: Vector2, r: float, c: Color) -> void:
		draw_circle(p, r, c)


## 目标罗盘：一行小签告诉你「该往哪走、还有多远」，点它开始自动前往。
## 只放必要信息：朝向箭头 + 目标名 + 步数（1 步＝1 格），手机上拇指一点就能走。
class _Compass extends Control:
	signal tapped

	var _lbl: Label = null
	var _angle := 0.0
	var _key := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(216.0, 26.0)
		size = custom_minimum_size
		_lbl = G.gold_label("", G.FS_XS, false, Color("ffd9a0"), false)
		_lbl.position = Vector2(20, 3)
		_lbl.custom_minimum_size = Vector2(194, 0)
		add_child(_lbl)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit()

	func set_target(name: String, target: Vector2, player_pos: Vector2, auto: bool) -> void:
		if name.is_empty():
			_key = ""
			_lbl.text = "自由探索"
			_angle = 0.0
			queue_redraw()
			return
		var steps := int(player_pos.distance_to(target) / 48.0)
		var key := "%s|%d|%s" % [name, steps, str(auto)]
		if key != _key:
			_key = key
			_lbl.text = ("行进中 · %s %d 步" if auto else "%s · 还有 %d 步") % [name, steps]
		_angle = (target - player_pos).angle() + PI * 0.5
		queue_redraw()

	func _draw() -> void:
		var sz := size
		if sz.x <= 1.0:
			sz = custom_minimum_size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.13, 0.09, 0.05, 0.62))
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.13, 0.09, 0.05, 0), false, 1.0)
		if _key.is_empty():
			return
		# 箭头：绕自身旋转，永远指向目标
		draw_set_transform(Vector2(11, sz.y * 0.5), _angle, Vector2.ONE)
		draw_colored_polygon([Vector2(0, -6), Vector2(4.5, 3), Vector2(-4.5, 3)],
			Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.92))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 虚拟摇杆（触屏/鼠标拖拽；键盘方向并行可用）
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
		# 底盘：深木色半透明 + 细金环
		draw_circle(c, 46.0, Color(0.12, 0.09, 0.05, 0.40))
		draw_arc(c, 46.0, 0, TAU, 40, Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.45), 1.5)
		draw_arc(c, 30.0, 0, TAU, 32, Color(1, 1, 1, 0.07), 1.0)
		# 摇杆头：羊皮纸色 + 木色底圈
		var k := c + vector * 44.0
		draw_circle(k, 18.0, Color(0.30, 0.20, 0.10, 0.85))
		draw_circle(k, 15.0, Color(0.91, 0.84, 0.64, 0.92))
