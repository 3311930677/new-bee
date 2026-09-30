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
const ThirdActGroundScript := preload("res://src/explore/ThirdActGround.gd")
const MINI_W := 78.0          # 小地图尺寸：与 32×42 格地图同比例（1536:2016 ≈ 0.762）
const MINI_H := 102.0
const _MiniMapPos := Vector2(390, 14)
# HUD 常驻小钮（药 / 换宠 / 撤离 / 疾行）统一口径（C8）：同一高度、同一字号档，
# 宽度按字数给足（PanelContainer 会被文字撑大，给窄了彼此压边或出屏），右缘与小地图右缘对齐。
const HUD_BTN_H := 44.0         # P01 样板 §4：命中区最小 44×44（原 40 达不到触控下限）
const HUD_BTN_FS := 16          # = G.FS_SM，HUD 小钮一律这一档，不再混用 FS_MD
const HUD_BTN_Y := 144.0        # 与左侧 HP 面板（136..192）纵向居中，三枚并排钮统一基线
const HUD_BTN_RIGHT := 468.0    # = _MiniMapPos.x + MINI_W（右上角小地图右缘）
const AUTO_TIMEOUT := 26.0    # 自动前往超时（秒）：到不了就交还控制权，不把玩家困住
const FLEE_CONTACT_CD := 1.6  # 战斗撤退后的接触冷静期（秒）：防"刚退又被同一只怪拽回去"
const StoryBeatScript := preload("res://src/ui/StoryBeat.gd")   # 首领剧情演出层（对峙/余韵）
const MountVisual := preload("res://src/world/MountVisual.gd")
const FirstActWeaponVisual := preload("res://src/world/FirstActWeaponVisual.gd")

var st: RunState
var node: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _world := Node2D.new()
var _ground_path: Dictionary = {}   # 本图主路格（_build_ground_detail 生成，散件避让要用同一份）
var _player: CharacterBody2D
var _player_anim: AnimatedSprite2D
var _mount_anim: AnimatedSprite2D = null
var _player_shape: CollisionShape2D = null
var _player_marker: Polygon2D = null
var _player_marker_gleam: Polygon2D = null
var _pet_follower: Node2D = null       # P05-D2：主世界出战伙伴的无碰撞跟随实体
var _pet_follower_sprite: Sprite2D = null
var _pet_last_dir := Vector2.DOWN
var _portal: _Portal
var _monsters: Array[_MapMonster] = []
var _contact_mon: _MapMonster = null
var _quest_entities: Array[_QuestEntity] = []   # P05-B：支线实体（采集/观察/送达）
var _interactable: _Interactable = null   # 非战斗节点物件（宝箱/事件/商店/篝火）
var _remover: Control = null              # 篝火词条删除浮层
var _exit_ui: Control = null              # 撤离确认浮层
var _trade_panel: TradePanel = null        # P06 野外驿点现货/订单
var _fishing_panel: FishingPanel = null
var _beat: Control = null                 # 首领剧情演出层（对峙/余韵）
var _battle_layer: CanvasLayer = null
var _battle: BattleScene = null
var _city_content: Node = null
var _hud := CanvasLayer.new()
var _hp_fill := ColorRect.new()
var _pot_l := Label.new()
var _main_hp_fill := ColorRect.new()
var _main_exp_fill := ColorRect.new()
var _main_level_l: Label = null
var _main_exp_l: Label = null
var _main_hp_l: Label = null
var _main_gold_l: Label = null
var _main_story_l: Label = null
var _main_side_l: Label = null
var _side_chip: Panel = null
var _player_name_l: Label = null
var _player_tag: Panel = null
var _player_tag_style: StyleBoxFlat = null   # P04：名签底板，描边色随在身武器稀有度变化
var _player_weapon_spr: Sprite2D = null      # P04：手中武器小图标（换装即刻可见）
var _first_act_weapon: Node2D = null         # P05-D：首章蓝武器的四种可辨轮廓
var _toast_lbl: Label = null
var _pet_btn: Control = null
var _potion_badge: Label = null
var _picker: TraitPicker = null
var _joy: _Joystick
var _map_done := false
var _map_cfg: Dictionary = {}
var _map_asset_dir := ""   # 地图素材成品目录（maps.json 的 asset_dir；缺配置时退回 FALLBACK_ASSET_DIR）
const FALLBACK_ASSET_DIR := "res://image/map_proc"
var _theme_cfg: Dictionary = {}
var _mode := "expedition"
var _main_map_id := ""
var _main_cfg: Dictionary = {}
var _main_resume_pos := Vector2(-1.0, -1.0)
var _main_respawn_at: Dictionary = {}
var _main_spawn_slots: Array[Dictionary] = []
var _main_respawn_tick := 0.0
var _world_exit_cd := 1.5
# P02：当前接战的遭遇上下文（EncounterContext，见 docs/plans/2026-09-28-p02-world-session-design.md）
# 用来给这场战斗一个稳定 ID：结算只落地一次，重放同一 ID 不发第二次奖。
var _encounter: Dictionary = {}

# ---- 探索动机（轮次 16：清场不再是"浪费时间"）----
# 原来最优解永远是直线冲传送阵：绕开怪物零成本。现在清怪与拾取都给探索分，
# 探索分决定本节点的评价与额外赏金，"走一趟"与"清一遍"变成真正的取舍。
var _pickups: Array[_Pickup] = []
var _spots: Array[_Spot] = []          # 兴趣点（碑灵祭坛 / 矿脉）
var _altar_ui: Control = null          # 祭坛浮层
## 战后三选一：精英/首领多给几次（B3），一次选完接着弹下一次
var _pending_trait_picks := 0
var _last_battle_tier := ""
var _last_battle_optional := false   # 上一场打的是可选首领（P05-C：自由撤退、不掷装备）
## 可选首领「接触前观察」上报记录（本图一次）：只在 180px 内看见时上报一次，避免逐帧写档
var _optional_seen := {}
var _score := 0
var _kills := 0
var _total_monsters := 0
var _cleared_bonus := false
var _explore_lbl: Label = null

# ---- 导航辅助（轮次 13：探索不再"盲走"）----
# 痛点：32×42 格地图只能看到约 1/5，玩家不知道自己在哪、目标在哪，只能一直往上走。
# 三件套：小地图（全局位置感）+ 目标罗盘（方向与距离，点它自动前往）+ 疾行（缩短空跑时间）。
var _minimap: _Minimap = null        # 右上角小地图（点击放大为大地图）
const MINIMAP_INTERVAL := 0.1        # 小地图重绘间隔（约 10Hz；问题 #15）
var _nav_acc := 0.0
var _nav_dirty := true               # 事件类变化置脏，下一帧立即刷新（不等节流窗口）
var _compass: _Compass = null        # 目标罗盘（含距离，点击开始/停止自动前往）
var _sprint_btn: Control = null      # 疾行开关
var _mount_btn: Control = null       # 第一幕首骑上马／下马
var _big_map: Control = null         # 大地图浮层（含图例与返回按钮）
var _sprint := false
var _mount_hoof_timer := 0.0
var _auto_walk := false
var _auto_time := 0.0                # 自动前往累计时长（超时自停，防止绕过点卡死）
var _auto_stuck := 0.0
var _auto_dodge := 0.0
var _auto_dodge_side := 1.0
var _auto_fail := 0                  # 连续卡住计数：绕行多次无效即停手（P1-14）
var _prev_pos := Vector2.ZERO
var _prog := {}                      # 本节点探索进度（RunState.map_progress 的引用；P0-1）


func _ready() -> void:
	Audio.play_bgm("bgm_map")
	var cfg := pending_cfg
	pending_cfg = {}
	_mode = String(cfg.get("mode", "expedition"))
	_main_map_id = String(cfg.get("main_map_id", ""))
	if _mode == "main_world":
		if _main_map_id.is_empty():
			_main_map_id = TableCache.default_main_world_map()
		_main_cfg = TableCache.main_world_map(_main_map_id)
		if _main_cfg.is_empty():
			push_error("主世界地图配置缺失：%s" % _main_map_id)
			return
		if bool(_main_cfg.get("dismount_on_entry", false)) and G.mount_riding():
			G.mount_set_riding(false)
		var world_state: Variant = G.prog.get("main_world", {})
		if world_state is Dictionary and String((world_state as Dictionary).get("map_id", "")) == _main_map_id:
			var saved_pos: Variant = (world_state as Dictionary).get("position", [])
			if saved_pos is Array and (saved_pos as Array).size() >= 2:
				_main_resume_pos = Vector2(float((saved_pos as Array)[0]), float((saved_pos as Array)[1]))
			# 首版洛林郊野是 32×42 格；缩图时把旧档坐标按比例迁移，
			# 避免只做边界钳制而把旅人挤到新地图的右下角。
			if _main_map_id == "lorin_wilds" \
					and int((world_state as Dictionary).get("layout_version", 1)) < 2 \
					and _main_resume_pos.x >= 0.0 and _main_resume_pos.y >= 0.0:
				_main_resume_pos *= Vector2(
					float(int(_main_cfg.get("map_cols", 20))) / 32.0,
					float(int(_main_cfg.get("map_rows", 26))) / 42.0)
			# 上版旧出生点在道路中段。只迁移仍停在那里的角色，不动玩家自行走到的坐标。
			if _main_map_id == "lorin_wilds" \
					and int((world_state as Dictionary).get("layout_version", 1)) == 2 \
					and _main_resume_pos.distance_to(Vector2(480, 980)) < 25.0:
				_main_resume_pos = _cfg_point(_main_cfg.get("spawn", []), Vector2(480, 930))
			var per_map: Variant = (world_state as Dictionary).get("respawn_by_map", {})
			var saved_respawn: Variant = {}
			if per_map is Dictionary and (per_map as Dictionary).has(_main_map_id):
				saved_respawn = (per_map as Dictionary)[_main_map_id]
			elif not (per_map is Dictionary) or (per_map as Dictionary).is_empty():
				saved_respawn = (world_state as Dictionary).get("respawn_at", {})
			if saved_respawn is Dictionary:
				_main_respawn_at = (saved_respawn as Dictionary).duplicate()
			# 旧档永久击杀记录迁移为一次限时刷新。
			var saved_killed: Variant = (world_state as Dictionary).get("killed", [])
			if saved_killed is Array:
				for old_id in saved_killed:
					var key := str(old_id)
					if not _main_respawn_at.has(key):
						_main_respawn_at[key] = Time.get_unix_time_from_system() + _main_respawn_seconds()
		var arrival := String(cfg.get("arrival", ""))
		if not arrival.is_empty():
			var points: Variant = _main_cfg.get("spawn_points", {})
			if points is Dictionary and (points as Dictionary).has(arrival):
				_main_resume_pos = _cfg_point((points as Dictionary)[arrival],
					_cfg_point(_main_cfg.get("spawn", []), Vector2(480, 930)))
	st = cfg.get("run", null)
	node = cfg.get("node", {})
	if st == null:
		push_error("MapScene 缺少 run 状态")
		return
	_map_cfg = TableCache.maps_config().duplicate(true)
	if _mode == "main_world":
		_map_cfg["map_cols"] = int(_main_cfg.get("map_cols", _map_cfg.get("map_cols", 32)))
		_map_cfg["map_rows"] = int(_main_cfg.get("map_rows", _map_cfg.get("map_rows", 42)))
		st.theme = String(_main_cfg.get("theme", st.theme))
	_theme_cfg = TableCache.theme_config(st.theme)
	# 世界主题规则（C 批）：揭示半径这条不属于战斗 tick，只能在大地图侧按主题覆盖。
	# 必须 duplicate 后再写——原地改 _map_cfg 就是改 TableCache 的缓存，跨场景串味。
	var rule := TableCache.theme_rule(st.theme)
	if String(rule.get("id", "")) == "abyss_dark":
		var mult := float((rule.get("params", {}) as Dictionary).get("reveal_mult", 0.5))
		_map_cfg["map_reveal_radius"] = float(_map_cfg.get("map_reveal_radius", 520.0)) * mult
	# 地图素材目录必须是**明确的成品配置**（问题 #34）：以前这里没有默认值兜底，
	# 也没人报缺配置，maps.json 少了 asset_dir 就会静默去 load 一个不存在的母稿路径。
	_map_asset_dir = String(_map_cfg.get("asset_dir", ""))
	if _map_asset_dir.is_empty():
		_map_asset_dir = FALLBACK_ASSET_DIR
		push_warning("maps.json 缺 asset_dir，地图素材退回 %s（请在表里显式配置）" % FALLBACK_ASSET_DIR)
	var node_seed := int(node.get("layer", 1)) * 10 + int(node.get("index", 0))
	# 历练沿用原种子文本，保证旧局布局、测试 fixture 与存档恢复完全不漂移。
	_rng.seed = hash("main_world_%s" % _main_map_id) \
		if _mode == "main_world" else hash("%d_%d" % [st.run_seed, node_seed])
	_prog = st.map_progress(int(node.get("layer", 1)), int(node.get("index", 0)))
	_build_ground()
	_build_world()
	_build_hud()
	if _mode == "main_world" and bool(_main_cfg.get("city", false)):
		_attach_city_content()
	if _mode == "main_world":
		var story_result := G.story_event("visit", _main_map_id, _main_map_id)
		if not story_result.is_empty():
			_toast("主线完成：%s" % String(story_result.get("title", "")))
			_refresh_hud()
	_refresh_explore_hud()   # 恢复的探索分/击杀数要在 HUD 上显出来


func _attach_city_content() -> void:
	_city_content = (load("res://src/city/CityScene.tscn") as PackedScene).instantiate()
	_city_content.call("embed_in", self, _main_map_id)
	add_child(_city_content)


# ================= 构建 =================
## 地表光色（P01 样板 §7）：主题 tint 乘以本图 tint，让边城／古道／断碑坡／碑窟一眼可分。
## 边城（整图底图）与碑窟（墓砖）保留各自原色，只给两张野外 forest 图叠地区色。
func _ground_tint() -> Color:
	var t := Color(String(_theme_cfg.get("tint", "ffffff")))
	if _mode == "main_world":
		t *= Color(String(_main_cfg.get("tint", "ffffff")))
		if _main_map_id == "broken_slope" and bool((G.prog.get("flags", {}) as Dictionary).get("act1_stele_repaired", false)):
			t *= Color("fff0d8")
	return t


func _build_ground() -> void:
	if _mode == "main_world" and not String(_main_cfg.get("background", "")).is_empty():
		var path := String(_main_cfg.get("background", ""))
		var tex: Texture2D = load(path) if path != "" else null
		if tex == null:
			push_error("主世界背景缺失：%s" % path)
		else:
			var bg := TextureRect.new()
			bg.texture = tex
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bg.modulate = _ground_tint()
			bg.size = Vector2(int(_map_cfg.get("map_cols", 32)) * 48,
				int(_map_cfg.get("map_rows", 42)) * 48)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(bg)
			return
	# 地面层：TileMapLayer 程序构建（主题 3 种 tile 加权平铺，无碰撞）
	var tl := TileMapLayer.new()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(48, 48)
	var tiles: Array = _theme_cfg.get("tiles", [])
	var asset_dir := _map_asset_dir
	var weights := [0.6, 0.2, 0.2]
	for i in mini(3, tiles.size()):
		var src := TileSetAtlasSource.new()
		src.texture = load("%s/%s.png" % [asset_dir, String(tiles[i])])
		src.texture_region_size = Vector2i(48, 48)
		src.create_tile(Vector2i.ZERO)
		ts.add_source(src, i)
	tl.tile_set = ts
	tl.modulate = _ground_tint()
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
	if _mode == "main_world" and _main_map_id == "shenyuan_port":
		var harbor_ground := PortGround.new()
		add_child(harbor_ground)


func _build_ground_detail(cols: int, rows: int) -> void:
	if _mode == "main_world" and bool(_main_cfg.get("city", false)):
		return
	# 地面细节层：主题土路套件（path_sheet，4×4＝16 块位掩码地形）+ 程序磨损斑块。
	# 目的：打破 48×48 地砖满屏重复的“棋盘感”。必须先于 _world 入树（压在地砖上、实体下）。
	var asset_dir := _map_asset_dir
	var sheet := String(_theme_cfg.get("path_sheet", ""))
	var path := _path_cells(cols, rows)
	_ground_path = path
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
			tl.modulate = _ground_tint()
			for cell: Vector2i in path.keys():
				var mask := _path_mask(cell, path)
				tl.set_cell(cell, 0, Vector2i(mask % 4, mask / 4), 0)
			add_child(tl)
		else:
			sheet = ""
	if sheet == "":
		for cell: Vector2i in path.keys():
			road.append(Vector2(float(cell.x) * 48.0 + 24.0, float(cell.y) * 48.0 + 24.0))

	var tint := _ground_tint()
	var earth := Color("6b5334")
	var road_col := Color(earth.r * tint.r, earth.g * tint.g, earth.b * tint.b)
	var wear := _GroundWear.new()
	wear.setup(cols, rows, _rng, path, road, road_col)
	add_child(wear)


## 蜿蜒土路：自出生点（底部中央）走向传送阵（顶部中央），随机左右游走。
## P01 样板 §3：路面必须**成带**——每行铺 2 格（净宽 96px），且相邻两行至少共有一列，
## 于是每一格都有正交邻居，4×4 位掩码（北1/东2/南4/西8）不会退化成孤立土块。
## 旧写法每行只落 1 格、转角补 1 格横路，路面只有 48px 宽，基线截图里就成了一串细碎土块。
func _path_cells(cols: int, rows: int) -> Dictionary:
	var cells: Dictionary = {}
	var cx := cols / 2
	var y := rows - 3
	var heading := 0
	var until_turn := 0
	while y >= 2:
		# 本行路带：[cx, cx+1]。cx 每行最多变 1，与上一行必然共享一列 → 正交连通。
		cells[Vector2i(cx, y)] = true
		cells[Vector2i(cx + 1, y)] = true
		var next_x := cx
		if _mode == "main_world":
			# 一段直路后才转弯，转弯后继续前行；避免相邻两行反复左右横跳形成方框。
			if until_turn <= 0:
				heading = _rng.randi_range(-1, 1)
				until_turn = _rng.randi_range(3, 5)
			next_x += heading
			until_turn -= 1
		else:
			var roll := _rng.randf()
			if roll < 0.34:
				next_x -= 1
			elif roll > 0.66:
				next_x += 1
		next_x = clampi(next_x, 4, cols - 5)
		if _mode != "main_world" and _rng.randf() < 0.28:  # 历练才有随机岔口；世界主路要清楚
			var side := 1 if _rng.randf() < 0.5 else -1
			cells[Vector2i(clampi(cx + side, 2, cols - 3), y)] = true
		cx = next_x
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


## JSON 坐标安全读取；格式错误时回退，不让一张地图表拖垮整个场景。
func _cfg_point(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


func _build_world() -> void:
	var cols := int(_map_cfg.get("map_cols", 32))
	var rows := int(_map_cfg.get("map_rows", 42))
	var map_w := float(cols * 48)
	var map_h := float(rows * 48)

	_build_ground_detail(cols, rows)  # 先于 _world 入树：绘制在地砖之上、实体之下
	if _mode == "main_world" and _main_map_id == "old_salt_road":
		add_child(SaltRoadGround.new())
	elif _mode == "main_world" and _main_map_id == "tideflat":
		add_child(TideflatGround.new())
	elif _mode == "main_world" and _main_map_id == "tidal_gate":
		add_child(TidalGateGround.new())
	elif _mode == "main_world" and _main_map_id in ["red_sand_route", "frost_post", "rift_mine_road", "rift_mine_vault", "frost_boardwalk", "frost_pass"]:
		var ground := ThirdActGroundScript.new()
		ground.map_id = _main_map_id
		add_child(ground)

	_world.y_sort_enabled = true
	add_child(_world)

	_build_decos(cols, rows)
	_build_portal(map_w)
	if _mode == "main_world":
		_build_world_exits()
	_build_player(map_w, map_h)
	_sync_world_companion()
	_build_monsters(map_w, map_h)
	_build_quest_entities()   # P05-B：支线实体（未接不生成、采过不再生成）
	_apply_safe_resume()   # P02：读档位置不能落在怪物身上（崩溃点矩阵 #1）
	if _mode != "main_world":
		_build_pickups(cols, rows)   # 历练专属：散落拾取物
		_build_spots(cols, rows)     # 历练专属：祭坛 / 矿脉
	_restore_node_state()        # 恢复本节点进度：打过的不复活、不重发奖励（P0-1）


func _build_decos(cols: int, rows: int) -> void:
	if _mode == "main_world" and bool(_main_cfg.get("city", false)):
		return
	# 散件：随机摆放（避开出生区/传送区/中央通道），origin 底部 + 脚部碰撞，Y-sort 遮挡
	# 主世界每图可用 decos 指定自己的地貌识别点（枫林古道＝枫树灌木、断碑坡＝枯树墓碑）
	var decos: Array = _main_cfg.get("decos", []) if _mode == "main_world" else []
	if decos.is_empty():
		decos = _theme_cfg.get("decos", [])
	if decos.is_empty():
		return
	var density := float(_theme_cfg.get("deco_density", 0.05))
	var asset_dir := _map_asset_dir
	var tint := _ground_tint()
	# 出生安全圈（P01 样板 §3）：按**本图真实出生点**避让 150px，不再用「地图底部中央」的估算点——
	# 估算点与 main_world_maps.json 的 spawn 差着上百像素，出生点旁边仍可能长出树。
	var spawn := _cfg_point(_main_cfg.get("spawn", []), Vector2.ZERO) if _mode == "main_world" \
		else Vector2(float(cols) * 24.0, float(rows) * 48.0 - 100.0)
	if spawn == Vector2.ZERO:
		spawn = Vector2(float(cols) * 24.0, float(rows) * 48.0 - 100.0)
	for gy in rows - 1:
		for gx in cols:
			if _mode == "main_world" and absi(gx - cols / 2) <= 2:
				continue  # 野外主路保持通行，散件留在道路两侧。
			if _mode == "main_world" and _ground_path.has(Vector2i(gx, gy)):
				continue  # 主路会游走出中央 5 列，凡路面格一律不落散件（P01：主路成带且不被树堵死）
			var center_col := absi(gx - cols / 2) <= 1  # 中央通道密度略降（0.65），保证通行但不显秃
			var d := density * (0.65 if center_col else 1.0)
			if _rng.randf() > d:
				continue
			var pos := Vector2(gx * 48.0 + _rng.randf_range(8, 40),
				gy * 48.0 + _rng.randf_range(8, 40))
			if pos.distance_to(spawn) < 150.0 or pos.y < 200.0:
				continue
			var tex: Texture2D = load("%s/%s.png" % [asset_dir, String(decos[_rng.randi_range(0, decos.size() - 1)])])
			var sc := _rng.randf_range(0.85, 1.18)
			# 散件基座是**实体碰撞**（40×s × 26 @ y=−13）：格位避让还不够——散件在格内随机偏到
			# 右下角时，碰撞盒会溢进相邻的路面格，走路时被树根绊住（可走性实测里表现为「反复卡住」）。
			# 这里按碰撞盒真实覆盖的格再筛一遍（RNG 次序不变，故散件布局只少了压路的那几株）。
			if _mode == "main_world" and _foot_hits_road(pos, sc):
				continue
			var deco := _Deco.new()
			deco.setup(tex, sc)
			deco.modulate = tint
			deco.position = pos
			_world.add_child(deco)


## 散件脚部碰撞盒是否压到本图主路格（_ground_path）。盒：40×s 宽 × 26 高，底边在原点、中心上移 13。
func _foot_hits_road(pos: Vector2, s: float) -> bool:
	var footprint := Rect2(pos - Vector2(20.0 * s, 26), Vector2(40.0 * s, 26)).grow(18)
	for rect_v in (_main_cfg.get("clear_rects", []) as Array):
		if rect_v is Array and (rect_v as Array).size() == 4:
			var r: Array = rect_v
			if footprint.intersects(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))):
				return true
	if _ground_path.is_empty():
		return false
	var hw := 20.0 * s
	for gy in range(int(floor((pos.y - 26.0) / 48.0)), int(floor(pos.y / 48.0)) + 1):
		for gx in range(int(floor((pos.x - hw) / 48.0)), int(floor((pos.x + hw) / 48.0)) + 1):
			if _ground_path.has(Vector2i(gx, gy)):
				return true
	return false


func _build_portal(map_w: float) -> void:
	_portal = _Portal.new()
	_portal.position = _cfg_point(_main_cfg.get("exit", []), Vector2(map_w / 2.0, 120.0)) \
		if _mode == "main_world" else Vector2(map_w / 2.0, 120.0)
	_portal.locked = String(node.get("type", "normal")) == "boss"
	_world.add_child(_portal)
	_portal.visible = _mode != "main_world"


## 世界图谱出口是道路指示牌；历练传送阵继续只服务随机节点。
func _build_world_exits() -> void:
	var exits: Variant = _main_cfg.get("exits", [])
	if not (exits is Array):
		return
	for row_v in exits:
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		var destination := String(row.get("to", ""))
		if TableCache.main_world_map(destination).is_empty():
			push_error("世界出口指向不存在的地图：%s" % destination)
			continue
		var marker := _WorldExit.new()
		marker.position = _cfg_point(row.get("at", []), Vector2.ZERO)
		# 北口触发圈在 y≈96；路牌若也立在那里，手机顶部状态栏会把整块牌遮住。
		# 视觉路牌提前立在路上，真正切图判定仍读 exits.at，不改移动与触发距离。
		if marker.position.y < 180.0:
			marker.position.y = 240.0
		marker.caption = String(row.get("label", destination))
		if destination == "stele_cavern":
			var repaired := bool((G.prog.get("flags", {}) as Dictionary).get("act1_stele_repaired", false))
			marker.gate_style = "restored" if repaired else "sealed"
			if repaired:
				marker.caption = "%s · %s" % [G.restored_stele_name(), marker.caption]
		var required := String(row.get("requires_story", ""))
		if not required.is_empty() and not G.story_step_done(required):
			marker.caption += " · 封"
		_world.add_child(marker)


func _build_player(map_w: float, map_h: float) -> void:
	_player = CharacterBody2D.new()
	_player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var spawn := _cfg_point(_main_cfg.get("spawn", []), Vector2(map_w / 2.0, map_h - 120.0)) \
		if _mode == "main_world" else Vector2(map_w / 2.0, map_h - 120.0)
	if _mode == "main_world" and _main_resume_pos.x >= 0.0 and _main_resume_pos.y >= 0.0:
		spawn = _main_resume_pos.clamp(Vector2(48.0, 48.0), Vector2(map_w - 48.0, map_h - 48.0))
		# 离开时站在传送阵上也不能让重进后马上再次触发出口。
		if spawn.distance_to(_portal.position) < 80.0:
			spawn = (_portal.position + Vector2(0, 110)).clamp(
				Vector2(48.0, 48.0), Vector2(map_w - 48.0, map_h - 48.0))
	_player.position = spawn
	_player.collision_layer = 1
	_player.collision_mask = 2
	_world.add_child(_player)

	_player_anim = AnimatedSprite2D.new()
	var frames_path := String(ROLE_FRAMES.get(st.role_id, ROLE_FRAMES["zs"])[0])
	_player_anim.sprite_frames = load(frames_path)
	# 历练保留旧比例；主地图单独校准人物占屏，不靠放大整张草地底图。
	# 帧中心在 y=64，脚底 y=120，脚点偏移按旧比例校准，避免放大后脚底与碰撞点分离。
	var player_scale := float(_main_cfg.get("player_scale", 0.96)) if _mode == "main_world" else 0.72
	_player_anim.scale = Vector2.ONE * player_scale
	_player_anim.position = Vector2(0, 21.0 - 56.0 * player_scale)
	_player_anim.animation = &"walk_down"
	_player_anim.frame = 1 # neutral passing pose for the initial idle state
	_player_anim.stop()
	_player.add_child(_player_anim)
	if _mode == "main_world":
		_mount_anim = AnimatedSprite2D.new()
		_mount_anim.sprite_frames = MountVisual.frames_for(st.role_id)
		_mount_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_mount_anim.scale = Vector2.ONE * 0.18
		_mount_anim.position = Vector2(0, -50)
		_mount_anim.animation = &"walk_down"
		_mount_anim.visible = false
		_player.add_child(_mount_anim)
	if _mode == "main_world":
		# 深底名牌保证绿地、浅色道路上都可读；红色菱形仍标识玩家。
		_player_tag = Panel.new()
		var name_y := -38.0 - 60.0 * player_scale
		_player_tag.position = Vector2(-70, name_y)
		_player_tag.size = Vector2(140, 24)
		_player_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag_style := StyleBoxFlat.new()
		tag_style.bg_color = Color(0.07, 0.13, 0.09, 0.91)
		tag_style.border_color = Color("90c79c", 0.8)
		tag_style.set_border_width_all(1)
		tag_style.set_corner_radius_all(7)
		_player_tag.add_theme_stylebox_override("panel", tag_style)
		_player_tag_style = tag_style
		_player.add_child(_player_tag)
		# 手中武器小图标（P04 §6.4）：换装后这里立刻变样，是"可见换装"的半边证据
		_player_weapon_spr = Sprite2D.new()
		_player_weapon_spr.position = Vector2(11, -2)
		_player_weapon_spr.visible = false
		_player.add_child(_player_weapon_spr)
		_first_act_weapon = FirstActWeaponVisual.new()
		_first_act_weapon.position = Vector2(19, -22)
		_first_act_weapon.scale = Vector2.ONE * 0.7
		_first_act_weapon.visible = false
		_player.add_child(_first_act_weapon)
		# 字号收进六档（P01 样板 §5）：原来是不在档里的字面量 14，比 NPC 名签还小
		_player_name_l = G.gold_label("", G.FS_SM, true, Color("f1ffe9"), false)
		_player_name_l.position = Vector2(5, 1)
		_player_name_l.size = Vector2(130, 22)
		_player_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_player_name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_player_name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_player_tag.add_child(_player_name_l)
		_player_marker = Polygon2D.new()
		_player_marker.polygon = PackedVector2Array([
			Vector2(0, -11), Vector2(9, 0), Vector2(0, 13), Vector2(-9, 0)])
		_player_marker.color = Color("e54651")
		_player_marker.position = Vector2(0, name_y - 19.0)
		_player.add_child(_player_marker)
		_player_marker_gleam = Polygon2D.new()
		_player_marker_gleam.polygon = PackedVector2Array([
			Vector2(0, -8), Vector2(5, -1), Vector2(-4, 0)])
		_player_marker_gleam.color = Color("fff0da")
		_player_marker_gleam.position = _player_marker.position
		_player.add_child(_player_marker_gleam)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 26)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	_player.add_child(shape)
	_player_shape = shape

	var cam := Camera2D.new()
	# 主世界镜头由素材像素密度决定；历练保持原 1.25 倍，不改变旧地图观察范围。
	var camera_zoom := float(_main_cfg.get("camera_zoom", 1.35)) if _mode == "main_world" else 1.25
	cam.zoom = Vector2.ONE * camera_zoom
	cam.position = Vector2(0, -34 if _mode == "main_world" else -56)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map_w)
	cam.limit_bottom = int(map_h)
	cam.enabled = true
	_player.add_child(cam)
	cam.make_current()
	_sync_mount_visual()


## 角色、马和名字共享碰撞脚点；图格保持原始透明边，故用固定居中和脚点偏移。
## 城务层领取／进建筑后可调用，避免切图才能看见变化。
func _sync_mount_visual() -> void:
	if _mode != "main_world" or _mount_anim == null:
		return
	var riding := G.mount_riding()
	_mount_anim.visible = riding
	_player_anim.visible = not riding
	if _player_shape != null:
		(_player_shape.shape as RectangleShape2D).size = Vector2(42, 28) if riding else Vector2(30, 26)
	if _player_tag != null:
		var tag_y := -126.0 if riding else -38.0 - 60.0 * float(_main_cfg.get("player_scale", 0.96))
		_player_tag.position.y = tag_y
		if _player_marker != null:
			_player_marker.position.y = tag_y - 19.0
		if _player_marker_gleam != null:
			_player_marker_gleam.position.y = tag_y - 19.0
	if _first_act_weapon != null:
		_first_act_weapon.visible = _first_act_weapon.get("weapon_tpl") != "" and not riding
	if _player_weapon_spr != null:
		_player_weapon_spr.visible = _player_weapon_spr.texture != null and not riding \
			and (_first_act_weapon == null or not _first_act_weapon.visible)
	if _mount_btn != null:
		_mount_btn.visible = G.mount_tier(String(G.first_mount_cfg().get("mount_id", "horse"))) > 0
		_mount_btn.tooltip_text = "下马" if riding else "上马"


func _mount_clearance() -> bool:
	if _player == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(42, 28)
	query.shape = shape
	query.transform = Transform2D(0.0, _player.global_position + Vector2(0, 8))
	query.collision_mask = _player.collision_mask
	query.exclude = [_player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _toggle_mount() -> void:
	if _mode != "main_world" or _battle != null or _modal_open():
		return
	var ride := not G.mount_riding()
	if ride and bool(_main_cfg.get("dismount_on_entry", false)):
		_toast("栈道与关隘路窄，请步行通过")
		return
	if ride and not _mount_clearance():
		_toast("这里太窄，先走到开阔处再上马")
		return
	if not G.mount_set_riding(ride):
		_toast("暂时不能骑乘")
		return
	if ride and _sprint:
		_toggle_sprint()
	_sync_mount_visual()
	_mount_hoof_timer = 0.0
	Audio.sfx("mount_toggle", 0.0)
	_toast("已上马 · 行路更快" if ride else "已下马")


## 主世界伙伴是探索层实体：跟随、进战后随 _world 一起隐藏，不带碰撞，也不参与触发判定。
## 公开给嵌入城市场景调用，兽栏领取后无需切图就能立即看到伙伴。
func _sync_world_companion() -> void:
	if _pet_follower != null and is_instance_valid(_pet_follower):
		_pet_follower.queue_free()
	_pet_follower = null
	_pet_follower_sprite = null
	if _mode != "main_world" or _player == null or st == null:
		return
	var pid := String(st.active_pet)
	if pid.is_empty() or not G.owns_pet(pid):
		return
	var tex := G.res_tex(pid)
	if tex == null:
		push_warning("主世界伙伴素材缺失：%s" % pid)
		return
	_pet_follower = Node2D.new()
	_pet_follower.name = "WorldCompanion"
	# 起步站在人物左后方：避开人物头顶名字／等级牌，也不挡脚下道路。
	_pet_follower.position = _player.position + Vector2(-64, -24)
	_world.add_child(_pet_follower)

	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-19, -3), Vector2(-12, -7), Vector2(12, -7), Vector2(19, -3),
		Vector2(12, 1), Vector2(-12, 1)])
	shadow.color = Color(0.08, 0.07, 0.04, 0.32)
	_pet_follower.add_child(shadow)
	_pet_follower_sprite = Sprite2D.new()
	_pet_follower_sprite.texture = tex
	_pet_follower_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pet_follower_sprite.scale = Vector2.ONE * (56.0 / maxf(1.0, float(tex.get_width())))
	_pet_follower_sprite.position = Vector2(0, -27)
	_pet_follower.add_child(_pet_follower_sprite)

	var pet_name := String(TableCache.get_pet(pid).get("name", pid))
	var tag := G.gold_label(pet_name, G.FS_XS, true, Color("f3e7c4"), false)
	tag.position = Vector2(-35, -63)
	tag.size = Vector2(70, 20)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pet_follower.add_child(tag)


func _update_world_companion(delta: float, move_dir: Vector2) -> void:
	if _pet_follower == null or not is_instance_valid(_pet_follower) or _player == null:
		return
	if move_dir.length_squared() > 0.04:
		_pet_last_dir = move_dir.normalized()
		if _pet_follower_sprite != null and absf(move_dir.x) > 0.12:
			_pet_follower_sprite.flip_h = move_dir.x < 0.0
	var side := Vector2(-_pet_last_dir.y, _pet_last_dir.x) * 64.0
	var target := _player.position - _pet_last_dir * 24.0 + side
	var dist := _pet_follower.position.distance_to(target)
	if dist > 220.0:
		_pet_follower.position = target
	elif dist > 7.0:
		_pet_follower.position = _pet_follower.position.move_toward(target, 132.0 * delta)
	if _pet_follower_sprite != null:
		_pet_follower_sprite.position.y = -27.0 + sin(Time.get_ticks_msec() * 0.006) * 1.2


func _build_monsters(map_w: float, map_h: float) -> void:
	# 编成：普通 3~4 小怪 / 精英 1+2 / BOSS 1 守阵（§2.5）；散布中上部，互不重叠
	# 非战斗节点（宝箱/事件/商店/篝火）：无怪，放 1 个交互物件（§2.7）
	var nt := String(_main_cfg.get("node_type", "normal")) if _mode == "main_world" \
		else String(node.get("type", "normal"))
	if not MON_COLOR.has(nt):
		_build_interactable(map_w, map_h)
		_total_monsters = 0
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
	if _mode == "main_world" and nt == "normal":
		comp.clear()
		for i in maxi(0, int(_main_cfg.get("monster_count", 4))):
			comp.append("normal")
	var placed: Array[Vector2] = []
	var pool: Array = _theme_cfg.get("monsters", [])
	var main_positions: Array = _main_cfg.get("monster_positions", []) if _mode == "main_world" else []
	var slot_ids: Array = _main_cfg.get("monster_slot_ids", []) if _mode == "main_world" else []
	if _mode == "main_world":
		var main_pool: Variant = _main_cfg.get("monster_ids", [])
		if main_pool is Array and not (main_pool as Array).is_empty():
			pool = main_pool
	for i in comp.size():
		var tier := String(comp[i])
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
		if i < main_positions.size():
			pos = _cfg_point(main_positions[i], pos).clamp(
				Vector2(72.0, 72.0), Vector2(map_w - 72.0, map_h - 72.0))
		placed.append(pos)
		var mon_id := String(_main_cfg.get("boss_id", _theme_cfg.get("boss", ""))) if tier == "boss" \
			else (String(pool[_rng.randi_range(0, maxi(0, pool.size() - 1))]) if not pool.is_empty() else "")
		if tier != "boss" and i < slot_ids.size():
			mon_id = String(slot_ids[i])
		var slot := {"idx": i, "tier": tier, "mon_id": mon_id, "position": pos}
		if _mode == "main_world":
			_main_spawn_slots.append(slot)
			if tier == "boss" and _main_boss_cleared():
				continue
			if float(_main_respawn_at.get(str(i), 0.0)) > Time.get_unix_time_from_system():
				continue
			_main_respawn_at.erase(str(i))
		_spawn_monster(slot)
	_total_monsters = comp.size() if _mode == "main_world" else _monsters.size()
	_build_optional_bosses()


## 可选首领刷点（P05-C）：独立于 monster_ids 随机池，序号从 1000 起（不与普通槽撞键）。
## 走与普通怪同一条 _main_spawn_slots / _main_respawn_at 机制：被击败后限时重刷，
## 不写 mark_boss_cleared（那不是「必经首领」）。
func _build_optional_bosses() -> void:
	if _mode != "main_world":
		return
	var rows: Variant = _main_cfg.get("optional_bosses", [])
	if not (rows is Array):
		return
	var idx := 1000
	for row_v in (rows as Array):
		if not (row_v is Dictionary):
			continue
		var o := row_v as Dictionary
		var mon_id := String(o.get("mon_id", ""))
		if mon_id.is_empty():
			continue
		var slot := {
			"idx": idx, "tier": "boss", "mon_id": mon_id,
			"position": _cfg_point(o.get("at", []), Vector2(140.0, 880.0)),
			"optional": true,
			"sprite": String(o.get("sprite", "")),
			"height": float(o.get("height", 0.0)),
			"level_offset": int(o.get("level_offset", 0)),
			"contact_radius": float(o.get("contact_radius", 0.0)),
			"wander_radius": float(o.get("wander_radius", 0.0)),
			"respawn_seconds": float(o.get("respawn_seconds", 600.0)),
		}
		idx += 1
		_main_spawn_slots.append(slot)
		if float(_main_respawn_at.get(str(slot["idx"]), 0.0)) > Time.get_unix_time_from_system():
			continue
		_main_respawn_at.erase(str(slot["idx"]))
		_spawn_monster(slot)


func _spawn_monster(slot: Dictionary) -> void:
	var m := _MapMonster.new()
	m.idx = int(slot["idx"]) if _mode == "main_world" else _monsters.size()
	m.tier = String(slot["tier"])
	m.mon_id = String(slot["mon_id"])
	m.optional = bool(slot.get("optional", false))
	if _mode == "main_world":
		m.sprite_path = String(_main_cfg.get("monster_sprite", ""))
		var paths: Dictionary = _main_cfg.get("monster_sprite_paths", {})
		if paths.has(m.mon_id):
			m.sprite_path = String(paths[m.mon_id])
		m.sprite_height = float(_main_cfg.get("monster_height", 48.0))
		# 槽级覆盖（P05-C 可选首领）：体型与接触/游荡半径按巢穴单独给，
		# 不改整张图的普通怪口径
		if not String(slot.get("sprite", "")).is_empty():
			m.sprite_path = String(slot["sprite"])
		if float(slot.get("height", 0.0)) > 0.0:
			m.sprite_height = float(slot["height"])
		m.contact_radius = float(slot.get("contact_radius", 0.0))
		m.wander_radius = float(slot.get("wander_radius", 0.0))
	m.display_level = st.level + int(slot.get("level_offset", _main_cfg.get("monster_level_offset", 2))) \
		if _mode == "main_world" else 0
	m.wander_only = _mode == "main_world" \
		and bool(_main_cfg.get("monster_wander_only", true))
	m.position = slot["position"]
	m.home = m.position
	m.map_ref = self
	_monsters.append(m)
	_world.add_child(m)
	_mark_nav_dirty()


func _main_respawn_seconds() -> float:
	return maxf(1.0, float(_main_cfg.get("monster_respawn_seconds", 30.0)))


## 可选首领的刷新间隔（P05-C）：从槽位自身取（默认 600 秒），找不到槽就退回普通怪口径。
func _optional_respawn_seconds(idx: int) -> float:
	for slot in _main_spawn_slots:
		if int(slot.get("idx", -1)) == idx:
			return maxf(1.0, float(slot.get("respawn_seconds", 600.0)))
	return _main_respawn_seconds()


func _main_boss_cleared() -> bool:
	return WorldSession.boss_cleared(_main_world_state(), _main_map_id)


## 主世界会话状态（prog.main_world）；缺结构时先归一，避免某张图缺键丢字段。
func _main_world_state() -> Dictionary:
	var w: Variant = G.prog.get("main_world", {})
	if not (w is Dictionary):
		w = {"map_id": _main_map_id}
	return WorldSession.normalize_state(w as Dictionary)


## 读档位置纠偏（P02 崩溃点 #1）：存档坐标若正好压在怪物/出口上，回落到安全位，
## 否则玩家一进图就被接触判定拖进战斗，或被出口立刻弹走。
func _apply_safe_resume() -> void:
	if _mode != "main_world" or _player == null:
		return
	var dangers: Array = []
	for m in _monsters:
		dangers.append(m.position)
	var safe := WorldSession.safe_position(_player.position, dangers,
		_portal.position if _portal != null else Vector2.ZERO, _map_extent())
	if safe != _player.position:
		_player.position = safe
		_main_resume_pos = safe


## 本场战斗的事务 ID（P03）：直接用具名 result_id（"res|<encounter_id>|victory"）。
## 同一场战斗重复结算拿到的字符串恒定，奖励账本据此只落地一次。
func _encounter_tx_id() -> String:
	if _encounter.is_empty():
		return ""
	return WorldSession.result_id(_encounter, "victory")


## 推进本场遭遇的状态（P03）：非法转移只警告不落盘，保证状态机不会被写坏。
func _advance_encounter(to: String) -> void:
	if _mode != "main_world" or _encounter.is_empty():
		return
	var ws := _main_world_state()
	var res := WorldSession.advance(ws, _encounter, to)
	G.prog["main_world"] = ws
	if not bool(res.get("ok", false)) and String(res.get("reason", "")) != "same":
		push_warning("遭遇状态转移被拒：%s → %s（%s）"
			% [String(res.get("from", "")), to, String(res.get("reason", ""))])


func _tick_main_respawns(delta: float) -> void:
	if _mode != "main_world" or _map_done:
		return
	_main_respawn_tick += delta
	if _main_respawn_tick < 1.0:
		return
	_main_respawn_tick = 0.0
	var now := Time.get_unix_time_from_system()
	for slot in _main_spawn_slots:
		# P05-C：可选首领复用 tier=="boss"（战斗档位与奖励档），但不吃「必经首领已清」的
		# 永久跳过——它按自己的 respawn 时限重刷，所以这里必须排除 optional 槽。
		if String(slot.get("tier", "")) == "boss" and _main_boss_cleared() \
				and not bool(slot.get("optional", false)):
			continue
		var key := str(slot["idx"])
		if not _main_respawn_at.has(key) or float(_main_respawn_at[key]) > now:
			continue
		if _player.position.distance_to(slot["position"]) < 100.0:
			continue
		_main_respawn_at.erase(key)
		_spawn_monster(slot)
		_persist_main_world_progress()
		G.save_game()


## 非战斗节点物件：置于玩家出生点与传送阵之间的中途（要走一段路）
func _build_interactable(map_w: float, map_h: float) -> void:
	if bool(_prog.get("interact_done", false)):
		return  # 一次性物件已用掉：重进不再生成（P0-1）
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
	if _mode == "main_world":
		return  # 原版草地主场景明亮平坦；历练暗角不带进常驻江湖
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


func _build_main_world_status() -> void:
	# 生命、经验拆成两条清楚的轨道，字与底图保持足够对比。
	var root := Panel.new()
	root.position = Vector2(14, 12)
	root.size = Vector2(176, 80)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.07, 0.91)
	sb.set_border_width_all(1)
	sb.border_color = Color("b6a064")
	sb.set_corner_radius_all(7)
	root.add_theme_stylebox_override("panel", sb)
	_hud.add_child(root)
	_main_level_l = G.gold_label("", 16, true, Color("ffdf89"), false)
	_main_level_l.position = Vector2(7, 8)
	_main_level_l.custom_minimum_size = Vector2(42, 0)
	root.add_child(_main_level_l)
	var hp_bg := ColorRect.new()
	hp_bg.color = Color("35251e")
	hp_bg.position = Vector2(51, 11)
	hp_bg.size = Vector2(117, 12)
	root.add_child(hp_bg)
	_main_hp_fill.color = Color("eac54c")
	_main_hp_fill.position = Vector2(52, 12)
	_main_hp_fill.size = Vector2(115, 10)
	root.add_child(_main_hp_fill)
	_main_hp_l = G.gold_label("", 13, true, Color("fff2d4"), false)
	_main_hp_l.position = Vector2(51, 25)
	_main_hp_l.custom_minimum_size = Vector2(117, 0)
	root.add_child(_main_hp_l)
	var exp_bg := ColorRect.new()
	exp_bg.color = Color("24342b")
	exp_bg.position = Vector2(51, 48)
	exp_bg.size = Vector2(117, 9)
	root.add_child(exp_bg)
	_main_exp_fill.color = Color("75c995")
	_main_exp_fill.position = Vector2(52, 49)
	_main_exp_fill.size = Vector2(0, 7)
	root.add_child(_main_exp_fill)
	_main_exp_l = G.gold_label("", 13, true, Color("c4efd1"), false)
	_main_exp_l.position = Vector2(51, 59)
	_main_exp_l.custom_minimum_size = Vector2(117, 0)
	root.add_child(_main_exp_l)

	# 主世界常驻只显示金币；三种专用资源点开查看，不占探索视野。
	var gold_chip := Panel.new()
	gold_chip.position = Vector2(202, 14)
	gold_chip.size = Vector2(145, 34)
	gold_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	gold_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var gold_style := StyleBoxFlat.new()
	gold_style.bg_color = Color(0.07, 0.10, 0.07, 0.91)
	gold_style.set_border_width_all(1)
	gold_style.border_color = Color("b6a064")
	gold_style.set_corner_radius_all(6)
	gold_chip.add_theme_stylebox_override("panel", gold_style)
	gold_chip.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.show_info_popup(gold_chip, "行囊与货币", G.wallet_info_lines()))
	_hud.add_child(gold_chip)
	var gold_icon := TextureRect.new()
	gold_icon.texture = G.res_tex("cur_gold")
	gold_icon.position = Vector2(9, 7)
	gold_icon.size = Vector2(20, 20)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_chip.add_child(gold_icon)
	_main_gold_l = G.gold_label("", G.FS_XS, true, Color("ffdf89"), false)
	_main_gold_l.position = Vector2(35, 7)
	_main_gold_l.size = Vector2(104, 20)
	_main_gold_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_chip.add_child(_main_gold_l)
	var region := G.gold_label(String(_main_cfg.get("name", "昭元边城")), G.FS_XS,
		true, Color("f1e5bb"), true)
	region.position = Vector2(205, 53)
	region.size = Vector2(147, 22)
	region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(region)


func _build_hud() -> void:
	_hud.layer = 1
	add_child(_hud)
	_build_vignette()  # 最先入层：只在画面四周压暗，不遮住下方的 HUD 控件
	if _mode == "main_world":
		_build_main_world_status()
		var story_chip := Panel.new()
		var story_style := StyleBoxFlat.new()
		story_style.bg_color = Color(0.07, 0.10, 0.07, 0.84)
		story_style.set_corner_radius_all(4)
		story_style.border_color = Color("b6a064", 0.72)
		story_style.set_border_width_all(1)
		story_chip.add_theme_stylebox_override("panel", story_style)
		# 城内委托快捷签占 y98–130；主线紧接在下方，野外则贴状态栏。
		story_chip.position = Vector2(14, 138) if bool(_main_cfg.get("city", false)) \
			else Vector2(14, 100)
		story_chip.size = Vector2(334, 30)
		story_chip.mouse_filter = Control.MOUSE_FILTER_STOP
		story_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		story_chip.tooltip_text = "点击查看主线目标与奖励"
		story_chip.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT \
					and not G.ui_blocked:
				_open_story_info(story_chip))
		_main_story_l = G.gold_label("", G.FS_XS, false, Color("ffe0ad"), false)
		_main_story_l.position = Vector2(8, 4)
		_main_story_l.size = Vector2(318, 22)
		_main_story_l.clip_text = true
		_main_story_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		story_chip.add_child(_main_story_l)
		_hud.add_child(story_chip)

		# 追踪支线蓝签（P05-B §4）：只显示当前追踪的一条；无追踪时整签隐藏。
		# 城内主线签在 y138–168，蓝签接 y172；野外主线签贴状态栏，蓝签接 y132。
		_side_chip = Panel.new()
		var side_style := StyleBoxFlat.new()
		side_style.bg_color = Color(0.06, 0.09, 0.12, 0.84)
		side_style.set_corner_radius_all(4)
		side_style.border_color = Color("9fd0ff", 0.72)
		side_style.set_border_width_all(1)
		_side_chip.add_theme_stylebox_override("panel", side_style)
		_side_chip.position = Vector2(14, 172) if bool(_main_cfg.get("city", false)) \
			else Vector2(14, 132)
		_side_chip.size = Vector2(334, 24)
		_side_chip.mouse_filter = Control.MOUSE_FILTER_STOP
		_side_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_side_chip.tooltip_text = "点击查看当前追踪的支线"
		_side_chip.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT \
					and not G.ui_blocked:
				G.show_info_popup(_side_chip, "追踪支线", G.side_info_lines(), self))
		_main_side_l = G.gold_label("", G.FS_XS, false, Color("cfe3ff"), false)
		_main_side_l.position = Vector2(8, 2)
		_main_side_l.size = Vector2(318, 20)
		_main_side_l.clip_text = true
		_main_side_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_side_chip.add_child(_main_side_l)
		_hud.add_child(_side_chip)
		_side_chip.visible = false   # 由 _refresh_hud 按追踪状态显隐

	var tc_name := String(_main_cfg.get("name", "江湖")) if _mode == "main_world" \
		else String(_theme_cfg.get("name", "未知"))
	var nt := String(node.get("type", "normal"))
	var nt_name: String = "主地图" if _mode == "main_world" else {
		"normal": "遭遇区", "elite": "精英区", "boss": "首领巢穴",
		"chest": "藏宝地", "event": "奇遇", "shop": "商队", "bonfire": "篝火地",
	}.get(nt, "探索")
	var top := G.parchment_box(300, 34, 8.0)
	top.position = Vector2(16, 12)
	_hud.add_child(top)
	top.visible = _mode != "main_world"
	var title := G.gold_label("%s · %s" % [tc_name, nt_name], G.FS_SM, false, Color("5a3a1e"), false)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.add_child(title)

	var goal_text := String(_main_cfg.get("goal", "沿道路探索")) if _mode == "main_world" \
		else "寻找传送阵"
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
	goal_chip.visible = _mode != "main_world"

	# 目标罗盘：一眼看到"该往哪走、还有多远"，点它开始自动前往（手游不用一直搓摇杆）
	_compass = _Compass.new()
	_compass.position = Vector2(16, 78)
	_compass.tapped.connect(_on_compass_tapped)
	_hud.add_child(_compass)
	_compass.visible = _mode != "main_world"

	if _mode != "main_world":
		# 历练进度只属于肉鸽探索，主世界不显示清剿评价。
		var exp_chip := PanelContainer.new()
		var esb := StyleBoxFlat.new()
		esb.bg_color = Color(0.13, 0.09, 0.05, 0.62)
		esb.set_corner_radius_all(4)
		esb.content_margin_left = 10.0
		esb.content_margin_right = 10.0
		esb.content_margin_top = 2.0
		esb.content_margin_bottom = 2.0
		exp_chip.add_theme_stylebox_override("panel", esb)
		exp_chip.position = Vector2(16, 110)
		_explore_lbl = G.gold_label("", G.FS_XS, false, Color("c8e0a0"), false)
		exp_chip.add_child(_explore_lbl)
		_hud.add_child(exp_chip)
		_refresh_explore_hud()

	# HP 条 + 药剂 + 换宠（整行下移让位给目标罗盘与探索小签）
	var panel := G.parchment_box(206, 56, 10.0)
	panel.position = Vector2(16, 136)
	_hud.add_child(panel)
	panel.visible = _mode != "main_world"
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
	# 主世界以 480×800 为基准；长屏把拇指按钮贴住视口底部，
	# 右侧按钮和小地图也跟随右边缘，避免 720×1600 下悬在画面中段。
	var extra_h := maxf(0.0, get_viewport_rect().size.y - VIEW_H) if _mode == "main_world" else 0.0
	var extra_w := maxf(0.0, get_viewport_rect().size.x - VIEW_W) if _mode == "main_world" else 0.0
	var action_y := 674.0 + extra_h if _mode == "main_world" else HUD_BTN_Y

	var potion_btn := _hud_icon_button("itm_potion_hp_s", 52.0,
		"使用药剂", func(): _use_potion(), "药剂", 52.0) if _mode == "main_world" \
		else G.gold_button("药", 48, HUD_BTN_H, HUD_BTN_FS)
	potion_btn.position = Vector2(350 + extra_w, action_y) if _mode == "main_world" else Vector2(232, action_y)
	if _mode == "main_world":
		var badge := PanelContainer.new()
		badge.position = Vector2(35, -3)
		badge.custom_minimum_size = Vector2(19, 17)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color("4b2817")
		badge_style.border_color = Color("e5ba68")
		badge_style.set_border_width_all(1)
		badge_style.set_corner_radius_all(8)
		badge_style.content_margin_left = 2
		badge_style.content_margin_right = 2
		badge.add_theme_stylebox_override("panel", badge_style)
		_potion_badge = G.gold_label("", G.FS_XS, true, Color("fff2c9"), true)
		_potion_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(_potion_badge)
		potion_btn.add_child(badge)
	else:
		potion_btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_use_potion())
	_hud.add_child(potion_btn)

	_pet_btn = _hud_icon_button("f6_icon_pet", 52.0,
		"切换出战宠物", func(): _swap_pet(), "伙伴", 52.0) if _mode == "main_world" \
		else G.gold_button("换宠", 66, HUD_BTN_H, HUD_BTN_FS)
	_pet_btn.position = Vector2(408 + extra_w, action_y) if _mode == "main_world" else Vector2(288, action_y)
	if _mode != "main_world":
		_pet_btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_swap_pet())
	_hud.add_child(_pet_btn)

	# 撤离：手边就必须能退出去（PC 亦可按 ESC），点按后二次确认防误触
	# 位置让给右上角小地图（小地图 y 到 116），下移到地图正下方仍是拇指热区；右缘与小地图对齐
	var exit_btn := _hud_icon_button("node_campfire", 52.0,
		"返回营帐", func(): _ask_exit(), "营帐", 52.0) if _mode == "main_world" \
		else G.gold_button("撤离", 66, HUD_BTN_H, HUD_BTN_FS)
	exit_btn.position = Vector2(408 + extra_w, 732 + extra_h) if _mode == "main_world" \
		else Vector2(HUD_BTN_RIGHT - 66.0, action_y)
	if _mode != "main_world":
		exit_btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_ask_exit())
	_hud.add_child(exit_btn)

	# 右上角小地图：全局位置感（"我在哪、出口在哪、还有几个人"）
	_minimap = _Minimap.new()
	_minimap.map_ref = self
	_minimap.position = Vector2(_MiniMapPos.x + extra_w, _MiniMapPos.y)
	_minimap.tapped.connect(_toggle_big_map)
	_hud.add_child(_minimap)

	# 疾行：地图纵深远、步行慢，空跑的那段路要能加速（数据配置 sprint_mult）
	_sprint_btn = _hud_icon_button("", 52.0,
		"疾行：关闭", func(): _toggle_sprint(), "疾行", 52.0) if _mode == "main_world" \
		else G.gold_button("疾行 · 关", 100, HUD_BTN_H, HUD_BTN_FS)
	_sprint_btn.position = Vector2(350 + extra_w, 732 + extra_h) if _mode == "main_world" \
		else Vector2(HUD_BTN_RIGHT - 100.0, VIEW_H - 200)
	if _mode != "main_world":
		_sprint_btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_toggle_sprint())
	_hud.add_child(_sprint_btn)
	if _mode == "main_world":
		_mount_btn = _hud_icon_button("f6_icon_mount", 52.0,
			"上马／下马", func(): _toggle_mount(), "骑乘", 52.0)
		_mount_btn.position = Vector2(292 + extra_w, 732 + extra_h)
		_hud.add_child(_mount_btn)
		_sync_mount_visual()

	_joy = _Joystick.new()
	_joy.position = Vector2(28, VIEW_H - 176 + extra_h)
	_hud.add_child(_joy)
	_refresh_hud()  # 覆盖换宠按钮可见性（bench 为空时隐藏）


func _open_story_info(anchor: Control) -> void:
	var row := G.story_current()
	if row.is_empty():
		G.show_info_popup(anchor, "边城线索", ["失声碑文已经修复。可继续探索各地、养成伙伴与挑战界碑历练。"], self)
		return
	var title := String(row.get("title", "主线"))
	var map_name := String(TableCache.main_world_map(String(row.get("map", ""))).get("name", "昭元边城"))
	var reward: Dictionary = row.get("reward", {})
	var lines: Array = ["目标：%s" % String(row.get("goal", "")), "地点：%s" % map_name]
	for reward_line in G.reward_lines(reward):
		lines.append(String(reward_line))
	G.show_info_popup(anchor, title, lines, self)


func _hud_icon_button(icon_key: String, width: float, hint: String, action: Callable,
		caption := "", height := HUD_BTN_H) -> Control:
	var holder := Control.new()
	holder.size = Vector2(width, height)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var hit := G.gold_button("", width, height, HUD_BTN_FS)
	hit.tooltip_text = hint
	hit.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			action.call())
	holder.add_child(hit)
	if icon_key.is_empty():
		var mark := G.gold_label("»", 27, true, Color("3d2a16"), false)
		mark.position = Vector2(0, -5)
		mark.size = Vector2(width, 37)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(mark)
	else:
		var icon := Sprite2D.new()
		icon.texture = load("res://image/generated_362_xajh/ready/ui/%s.png" % icon_key) as Texture2D \
			if icon_key.begins_with("f6_") else G.res_tex(icon_key)
		icon.position = Vector2(width * 0.5, 19.0 if not caption.is_empty() else height * 0.5)
		if icon.texture != null:
			var icon_px := 28.0 if not caption.is_empty() else 34.0
			icon.scale = Vector2.ONE * (icon_px / maxf(icon.texture.get_width(), icon.texture.get_height()))
		holder.add_child(icon)
	if not caption.is_empty():
		var cap := G.gold_label(caption, G.FS_XS, true, Color("3d2a16"), false)
		cap.position = Vector2(0, 32)
		cap.size = Vector2(width, 18)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cap)
	return holder


func _refresh_hud() -> void:
	var m := st.max_hp()
	var hp := m if st.hp < 0 else st.hp
	_hp_fill.size.x = 116.0 * clampf(float(hp) / float(m), 0.0, 1.0)
	if _mode == "main_world" and _main_level_l != null:
		var lv := int(G.prog.get("level", st.level))
		var exp := int(G.prog.get("exp", 0))
		var need := G.exp_to_next(lv)
		var exp_ratio := 1.0 if need <= 0 else clampf(float(exp) / float(need), 0.0, 1.0)
		_main_level_l.text = "Lv%d" % lv
		_main_hp_fill.size.x = 115.0 * clampf(float(hp) / float(maxi(m, 1)), 0.0, 1.0)
		_main_exp_fill.size.x = 115.0 * exp_ratio
		_main_hp_l.text = "生命 %d/%d" % [hp, m]
		_main_exp_l.text = "EXP %d%%" % roundi(exp_ratio * 100.0)
		if _main_gold_l != null:
			_main_gold_l.text = str(int(G.wallet.get("gold", 0)))
		if _main_story_l != null:
			_main_story_l.text = G.story_goal_short()
		if _side_chip != null:
			var side_text := G.side_line()
			_side_chip.visible = not side_text.is_empty()
			_main_side_l.text = side_text
		if _player_name_l != null:
			_player_name_l.text = "%s  Lv%d" % [G.display_name(), lv]
			var name_width := G.font_bold.get_string_size(_player_name_l.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_SM).x
			var tag_width := clampf(name_width + 16.0, 126.0, 290.0)
			_player_tag.size.x = tag_width
			_player_tag.position.x = -tag_width * 0.5
			_player_name_l.size.x = tag_width - 10.0
		_refresh_player_appearance()
	# 苦行局要在 HUD 上一直看得见：玩家必须清楚"这局敌人更强、收益更高"，
	# 而不是打着打着忘了自己开过什么
	_pot_l.text = "药剂 ×%d" % st.potions if not st.ascetic \
		else "苦行 · 药剂 ×%d" % st.potions
	if _potion_badge != null:
		_potion_badge.text = str(st.potions)
	if _pet_btn != null:
		_pet_btn.visible = st.bench_pet != ""


## 可见换装（P04 §6.4）：在身武器的稀有度决定名签描边色，并在手中画一件武器小图标。
## 无武器时回落到原描边色、隐藏图标 —— 这是"换装在地图上看得见"的落点。
func _refresh_player_appearance() -> void:
	if _mode != "main_world" or _player_tag_style == null:
		return
	var app := G.equip_appearance()
	var hex := String(app.get("color", ""))
	if app.is_empty() or hex.is_empty():
		_player_tag_style.border_color = Color("90c79c", 0.8)
	else:
		_player_tag_style.border_color = Color(hex)
	if _player_weapon_spr == null:
		return
	var icon := String(app.get("weapon_icon", ""))
	var tex: Texture2D = G.res_tex(icon) if not icon.is_empty() else null
	var tpl := String(app.get("weapon_tpl", ""))
	var first_act_blue := tpl in ["tpl_sword_ruin", "tpl_spear_iron", "tpl_staff_frost", "tpl_hammer_dawn"] \
		and int(app.get("rarity", 0)) >= 3
	if _first_act_weapon != null:
		_first_act_weapon.call("set_weapon", tpl if first_act_blue else "")
		_first_act_weapon.visible = first_act_blue and not G.mount_riding()
	_player_weapon_spr.texture = tex
	_player_weapon_spr.visible = tex != null and not G.mount_riding() and not first_act_blue
	if tex != null:
		_player_weapon_spr.scale = Vector2.ONE * (14.0 / maxf(1.0, float(tex.get_width())))


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
	_sync_world_companion()
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
	# 精英/首领的额外选择：上一张收完立刻接着弹下一张（B3）
	if _pending_trait_picks > 0:
		_next_trait_pick()


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
	_prog["interact_done"] = true   # 一次性物件记档：重进不再生成（P0-1）
	_interactable = null


## 支线实体生成（P05-B）：表在 main_world_maps.json 的 entities；
## 生成与否完全由任务状态决定（未接不出现、采过/可交付/完成后不再出现）。
func _refresh_quest_entities() -> void:
	for entity in _quest_entities:
		if is_instance_valid(entity): entity.queue_free()
	_quest_entities.clear()
	_build_quest_entities()


func _build_quest_entities() -> void:
	if _mode != "main_world":
		return
	var ents: Variant = _main_cfg.get("entities", {})
	if not (ents is Dictionary):
		return
	for eid_v in (ents as Dictionary):
		var eid := String(eid_v)
		var row_v: Variant = (ents as Dictionary)[eid_v]
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		var quest := String(row.get("quest", ""))
		if String(row.get("kind", "")) == "story":
			var step_id := String(row.get("story_step", ""))
			var shown: Array = row.get("show_steps", [step_id])
			if G.story_step_done(step_id) or not shown.has(String(G.story_current().get("id", ""))):
				continue
		if eid == G.WAYSTONE_CACHE_ID and not G.waystone_cache_available():
			continue
		if not G.side_entity_visible(eid, quest):
			continue
		var ent := _QuestEntity.new()
		ent.eid = eid
		ent.quest = quest
		ent.kind = String(row.get("kind", "collect"))
		ent.story_event_kind = String(row.get("story_event", "collect"))
		ent.art = String(row.get("art", "root"))
		ent.caption = String(row.get("name", ""))
		ent.position = _cfg_point(row.get("at", []), Vector2.ZERO)
		ent.map_ref = self
		_quest_entities.append(ent)
		_world.add_child(ent)
	_mark_nav_dirty()


## 支线实体交互（P05-B）：采集/观察/送达。成功推进即从地图消失，提示走 toast。
func on_quest_entity(e: _QuestEntity) -> void:
	if _map_done or _battle != null or e.used:
		return
	if _modal_open():
		return
	if e.kind == "fishing":
		_fishing_panel = FishingPanel.new()
		_hud.add_child(_fishing_panel)
		_fishing_panel.open_spot(e.eid)
		_fishing_panel.closed.connect(func():
			_fishing_panel = null
			_refresh_hud())
		e.trade_cooled = true
		return
	if e.kind == "trade":
		for site in (TableCache.economy_config().get("sites", []) as Array):
			if String((site as Dictionary).get("entity_id", "")) == e.eid:
				_open_trade_panel(String((site as Dictionary).get("id", "")))
				e.trade_cooled = true
				return
		return
	if e.kind == "story":
		var result := G.story_event(e.story_event_kind, e.eid, _main_map_id)
		if result.is_empty():
			_toast("先按主线顺序调查这里")
			return
		e.used = true
		e.queue_free()
		_mark_nav_dirty()
		_toast("主线完成：%s" % String(result.get("title", "")))
		_refresh_hud()
		return
	var res := G.claim_waystone_cache() if e.kind == "cache" and e.eid == G.WAYSTONE_CACHE_ID \
		else G.side_entity_interact(e.kind, e.eid, _main_map_id, e.quest)
	if not bool(res.get("ok", false)):
		if String(res.get("reason", "")) == "no_progress":
			_toast("这里眼下没有可做的事")
		return
	e.used = true
	e.queue_free()
	_mark_nav_dirty()
	for t in res.get("toasts", []):
		_toast(String(t))
	_refresh_hud()   # 蓝签进度/可交付状态即时刷新


## 追踪支线在当前地图的实体坐标（P05-B 小地图蓝菱用）。
func _tracked_side_points() -> Array:
	var out: Array = []
	var qid := G.side_tracked()
	if qid.is_empty():
		return out
	for e in _quest_entities:
		if is_instance_valid(e) and not e.used and e.quest == qid:
			out.append(e.position)
	return out


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
	if _city_content != null and bool(_city_content.call("has_modal")):
		return
	if G.ui_blocked:  # 全屏浮层（GM 控制台）优先，ESC 让给它
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	var vp := get_viewport()  # 切场景途中本节点可能已离场，viewport 会是 null
	if _altar_ui != null:  # 祭坛选择框在最上层（只关它，不动大地图/撤离）
		for s in _spots:
			if s.kind == "altar":
				_close_altar(s, false)   # ESC 只关浮层，不消耗祭坛（P2-22）
				break
		if vp != null:
			vp.set_input_as_handled()
	elif _fishing_panel != null:
		_fishing_panel.close()
		if vp != null:
			vp.set_input_as_handled()
	elif _trade_panel != null:
		_trade_panel.close()
		if vp != null:
			vp.set_input_as_handled()
	elif _big_map != null:   # 大地图：ESC 先收浮层，再谈撤离
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
	if _exit_ui != null or _map_done or _battle != null \
			or (_city_content != null and bool(_city_content.call("has_modal"))):
		return
	Audio.sfx("ui_open")
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_ui = layer
	_hud.add_child(layer)

	# 撤离确认底衬：统一工厂（深棕 + 暗角 + 斜纹），保持浮层质感一致
	G.veil(layer, 0.72, true)

	var banner := G.banner_box("返回营帐" if _mode == "main_world" else "撤离本节点", 260, 48)
	banner.position = Vector2((VIEW_W - 260.0) * 0.5, 264)
	layer.add_child(banner)

	var panel := G.parchment_box(340, 190, 16.0)
	panel.position = Vector2((VIEW_W - 340.0) * 0.5, 328)
	layer.add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var tip_text := "返回营帐后可随时再进主城，\n人物位置与怪物刷新时间会保留。" if _mode == "main_world" \
		else "撤离将返回路线图，本节点进度保留，\n可稍后再次进入。"
	var tip := G.gold_label(tip_text, G.FS_SM, false, Color("5a3a1e"), false)
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
	_tick_main_respawns(delta)
	_world_exit_cd = maxf(0.0, _world_exit_cd - delta)
	if _modal_open():
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
	var speed := TableCache.map_player_speed()
	if _mode == "main_world" and G.mount_riding():
		speed *= float(G.first_mount_cfg().get("world_speed_mult", 1.25))
	if _sprint and not G.mount_riding():
		speed *= float(_map_cfg.get("sprint_mult", 1.6))
	_prev_pos = _player.position
	_player.velocity = dir * speed
	_player.move_and_slide()
	# 地图边界夹紧
	var cols := int(_map_cfg.get("map_cols", 32))
	var rows := int(_map_cfg.get("map_rows", 42))
	_player.position = _player.position.clamp(Vector2(24, 60), Vector2(cols * 48 - 24, rows * 48 - 24))
	var actual_dir := (_player.position - _prev_pos) / maxf(delta, 0.0001)
	_update_player_anim(actual_dir)
	_tick_mount_hoof(delta, actual_dir)
	_update_world_companion(delta, actual_dir)
	_tick_auto_walk(delta)
	_update_nav(delta)
	_check_portal()


func _tick_mount_hoof(delta: float, actual_dir: Vector2) -> void:
	if _mode != "main_world" or not G.mount_riding() or actual_dir.length_squared() < 0.25:
		_mount_hoof_timer = 0.0
		return
	_mount_hoof_timer -= delta
	if _mount_hoof_timer <= 0.0:
		Audio.sfx("mount_hoof", 0.02)
		_mount_hoof_timer = 0.43


func _update_player_anim(dir: Vector2) -> void:
	if _mode == "main_world" and G.mount_riding() and _mount_anim != null:
		if dir.length_squared() >= 0.25:
			var mount_dir := &"walk_down"
			if absf(dir.x) > absf(dir.y):
				mount_dir = &"walk_right" if dir.x > 0 else &"walk_left"
			else:
				mount_dir = &"walk_down" if dir.y > 0 else &"walk_up"
			_mount_anim.animation = mount_dir
			_mount_anim.position.y = -50.0 + sin(float(Time.get_ticks_msec()) * 0.016) * 1.2
		else:
			_mount_anim.position.y = -50.0
		return
	if dir.length_squared() < 0.25:
		_player_anim.stop()
		_player_anim.frame = 1 # neutral passing pose, not a wide contact pose
		return
	var anim := &"walk_down"
	if absf(dir.x) > absf(dir.y):
		anim = &"walk_right" if dir.x > 0 else &"walk_left"
	else:
		anim = &"walk_down" if dir.y > 0 else &"walk_up"
	if _player_anim.animation != anim:
		var gait_frame := _player_anim.frame
		var gait_progress := _player_anim.frame_progress
		_player_anim.animation = anim
		_player_anim.set_frame_and_progress(gait_frame, gait_progress)
	if _first_act_weapon != null:
		_first_act_weapon.position = Vector2(-19, -22) if anim == &"walk_left" else Vector2(19, -22)
		_first_act_weapon.scale = Vector2(-0.7, 0.7) if anim == &"walk_left" else Vector2(0.7, 0.7)
	# 实际位移决定步频；贴墙停止，低速摇杆也不强制播放半速动画。
	_player_anim.speed_scale = dir.length() / maxf(1.0, TableCache.map_player_speed())
	if not _player_anim.is_playing():
		_player_anim.play()


# ================= 探索动机（轮次 16） =================
## 探索配置（nodes.json 的 explore 段），数据表驱动，缺表给保守默认
func _explore_cfg() -> Dictionary:
	var e: Variant = TableCache.nodes_config().get("explore", {})
	return e as Dictionary if e is Dictionary else {}


func _cfg_range(key: String, fallback: Array) -> Array:
	var e := _explore_cfg()
	var arr: Variant = e.get(key, fallback)
	return arr as Array if arr is Array else fallback


func _cfg_int(key: String, fallback: int) -> int:
	var e := _explore_cfg()
	return int(e.get(key, fallback))


## 探索评价：分档给名字与附加赏金（0 档 = 匆匆过客，不给附加赏）
func _rank() -> Dictionary:
	var th := _cfg_range("rank_thresholds", [30, 70, 105])
	var gold := _cfg_range("rank_bonus_gold", [40, 90, 160])
	var names := ["匆匆过客", "踏遍此地", "寸土必争"]
	var rank := 0
	for i in th.size():
		if _score >= int(th[i]):
			rank = i + 1
	var bonus := 0
	if rank > 0 and rank - 1 < gold.size():
		bonus = int(gold[rank - 1])
	return {"name": String(names[mini(rank, names.size() - 1)]), "bonus": bonus, "tier": rank}


func _refresh_explore_hud() -> void:
	if _explore_lbl == null:
		return
	var total := _total_monsters
	var killed := _kills
	if total > 0:
		_explore_lbl.text = "清剿 %d/%d · %s" % [killed, total, String(_rank().get("name", ""))]
	else:
		_explore_lbl.text = "探索分 %d · %s" % [_score, String(_rank().get("name", ""))]


func _add_score(n: int, why: String) -> void:
	if n <= 0:
		return
	var before := int(_rank().get("tier", 0))
	_score += n
	_prog["score"] = _score   # 进度落表（P0-1）
	_refresh_explore_hud()
	var after := int(_rank().get("tier", 0))
	if after > before:
		Audio.sfx("reward")
		_toast("探索评价提升 · %s" % String(_rank().get("name", "")))


## 全图怪物清空：给"清场"这件事一个明确的落点（额外赏 + 一句交代）
func _on_area_cleared() -> void:
	if _cleared_bonus or _total_monsters <= 0:
		return
	_cleared_bonus = true
	_prog["cleared_bonus"] = true   # 清剿赏只发一次：重进不再给（P0-1）
	st.add_reward("clear")
	Audio.sfx("reward")
	_toast("本区已清剿 · 赏金入袋（金币 +%d）"
		% int(TableCache.nodes_config().get("rewards", {}).get("clear", {}).get("gold", 0)))
	_add_score(_cfg_int("clear_bonus_score", 30), "清剿")


## 散落拾取物：地图上撒几个，走过去自动拾取——路上有微反馈，不再是纯赶路
func _build_pickups(cols: int, rows: int) -> void:
	var rng_cfg := _cfg_range("pickup_count", [3, 5])
	var lo := int(rng_cfg[0]) if rng_cfg.size() > 0 else 3
	var hi := int(rng_cfg[1]) if rng_cfg.size() > 1 else 5
	var n := _rng.randi_range(maxi(0, lo), maxi(lo, hi))
	var map_w := float(cols * 48)
	var spawn := Vector2(map_w / 2.0, float(rows) * 48.0 - 120.0)
	for i in n:
		var pos := Vector2.ZERO
		for attempt in 20:
			pos = Vector2(_rng.randf_range(80.0, map_w - 80.0),
				_rng.randf_range(180.0, float(rows) * 48.0 - 200.0))
			if pos.distance_to(spawn) > 150.0:
				break
		var p := _Pickup.new()
		p.idx = i
		p.position = pos
		p.map_ref = self
		p.kind = "soul" if i % 3 == 2 else "coin"
		_pickups.append(p)
		_world.add_child(p)


## 兴趣点：碑灵祭坛（花金重摇祝福）/ 矿脉（白拿材料）
## 与拾取物的区别：拾取是被动入袋的微奖励，兴趣点是"要不要花代价"的选择——这是探索层的取舍
func _build_spots(cols: int, rows: int) -> void:
	var map_w := float(cols * 48)
	var map_h := float(rows * 48)
	var spawn := Vector2(map_w / 2.0, map_h - 120.0)
	var portal_y := 120.0
	if _rng.randf() < float(_explore_cfg().get("altar_chance", 0.6)):
		var a := _Spot.new()
		a.idx = _spots.size()
		a.kind = "altar"
		a.position = Vector2(_rng.randf_range(120.0, map_w - 120.0),
			_rng.randf_range(320.0, map_h - 360.0))
		a.map_ref = self
		_spots.append(a)
		_world.add_child(a)
	var vr := _cfg_range("vein_count", [1, 2])
	var vn := _rng.randi_range(int(vr[0]), int(vr[1]))
	for i in vn:
		var v := _Spot.new()
		v.idx = _spots.size()
		v.kind = "vein"
		var pos := Vector2.ZERO
		for attempt in 20:
			pos = Vector2(_rng.randf_range(100.0, map_w - 100.0),
				_rng.randf_range(240.0, map_h - 240.0))
			if pos.distance_to(spawn) > 140.0 and absf(pos.y - portal_y) > 120.0:
				break
		v.position = pos
		v.map_ref = self
		_spots.append(v)
		_world.add_child(v)


## 恢复本节点探索进度（P0-1）：构建顺序与随机流保持完全一致，只在建完后「摘掉」已完成的部分——
## 打过的不复活、不重发奖励；拾取过的消失；用过的祭坛/矿脉留场但熄灭（可看不可用）
func _restore_node_state() -> void:
	var killed: Array = [] if _mode == "main_world" else _prog.get("killed", [])
	if not killed.is_empty():
		var kept_m: Array[_MapMonster] = []
		for m in _monsters:
			if killed.has(m.idx):
				m.queue_free()
			else:
				kept_m.append(m)
		_monsters = kept_m
		_kills = killed.size()
	if bool(_prog.get("boss_down", false)) and _portal != null:
		_portal.locked = false
	var taken: Array = _prog.get("taken", [])
	if not taken.is_empty():
		var kept_p: Array[_Pickup] = []
		for p in _pickups:
			if taken.has(p.idx):
				p.queue_free()
			else:
				kept_p.append(p)
		_pickups = kept_p
	var used_spots: Array = _prog.get("spots", [])
	if not used_spots.is_empty():
		for s in _spots:
			if used_spots.has(s.idx):
				s.used = true
				s.queue_redraw()   # 熄灭态（_draw 依 used 表达）
	_score = int(_prog.get("score", 0))
	_cleared_bonus = bool(_prog.get("cleared_bonus", false))


func on_spot(s: _Spot) -> void:
	if _map_done or _battle != null:
		return
	if s.kind == "vein":
		var items: Array = _cfg_range("vein_items", ["enhance_stone"])
		var am: Array = _cfg_range("vein_amount", [1, 2])
		var n := _rng.randi_range(int(am[0]), int(am[1]))
		var iid := String(items[_rng.randi_range(0, maxi(0, items.size() - 1))])
		G.grant_item(iid, n)
		Audio.sfx("pickup")
		_toast("采得矿脉：%s ×%d" % [G.item_name(iid), n])
		_add_score(_cfg_int("pickup_score", 6), "矿脉")
		# 进度落表：矿脉同样是一次性兴趣点，不记就会"撤离→重进"反复采（P0-1 漏网项）
		if not _prog["spots"].has(s.idx):
			_prog["spots"].append(s.idx)
		_spots.erase(s)
		s.queue_free()
		_mark_nav_dirty()   # 兴趣点用掉后要立刻从地图消失（问题 #15）
		return
	_open_altar(s)


## 碑灵祭坛：花金换一次「祝福重择」——花的是局内金币（会被远征结算算进去，是真代价）
func _open_altar(s: _Spot) -> void:
	if _altar_ui != null:
		return
	var cost := _cfg_int("altar_gold", 200)
	Audio.sfx("ui_open")
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_altar_ui = layer
	_hud.add_child(layer)
	G.veil(layer, 0.72, true)

	var banner := G.banner_box("碑 灵 祭 坛", 260, 48)
	banner.position = Vector2((VIEW_W - 260.0) * 0.5, 236)
	layer.add_child(banner)

	var panel := G.parchment_box(340, 232, 16.0)
	panel.position = Vector2((VIEW_W - 340.0) * 0.5, 300)
	layer.add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	var tip := G.gold_label("碑上的字还在动。献上 %d 金，\n可重择一次祝福（当前持有 %d 词条）。"
		% [cost, st.traits.size()], G.FS_SM, false, Color("5a3a1e"), false)
	tip.position = Vector2(0, 14)
	tip.custom_minimum_size = Vector2(308, 0)
	content.add_child(tip)

	var pay := G.gold_button("献 金 %d" % cost, 140, 42, G.FS_SM)
	pay.position = Vector2(0, 96)
	pay.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_altar_pay(s, cost))
	content.add_child(pay)
	var leave := G.gold_button("离 开", 140, 42, G.FS_SM)
	leave.position = Vector2(168, 96)
	leave.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_altar(s, false))   # 离开不消耗：误触/犹豫不熄灯（P2-22）
	content.add_child(leave)
	var hint := G.gold_label("献金后原地重摇祝福；祭坛用掉即熄。", G.FS_XS, false, Color("8a6a34"), false)
	hint.position = Vector2(0, 158)
	hint.custom_minimum_size = Vector2(308, 0)
	content.add_child(hint)


func _altar_pay(s: _Spot, cost: int) -> void:
	if st.gold < cost:
		Audio.sfx("ui_locked")
		_toast("金币不足，碑灵沉默不语")
		return
	st.gold -= cost
	Audio.sfx("altar")
	var choices := st.roll_trait_choices(_rng)
	if choices.is_empty():
		# 词条池已尽：全额退款且不熄灯（否则玩家钱退了、祭坛却永久用掉）
		_toast("碑灵无言——词条池已尽，金子退你了")
		st.gold += cost
		return
	_close_altar(s, true)   # 献过金且真能重择，祭坛才熄，不再重复打扰
	_add_score(_cfg_int("pickup_score", 6), "祭坛")
	_toast("碑灵应声 · 祝福重择")
	_show_trait_picker(choices)


func _close_altar(s: _Spot, leave: bool) -> void:
	Audio.sfx("ui_close")
	if _altar_ui != null:
		_altar_ui.queue_free()
		_altar_ui = null
	# 关掉就给一小段冷却：否则玩家还站在触发圈内，浮层会被 _Spot._process 立刻重新弹开
	if s != null:
		s.cd = 0.9
	if leave and s != null:
		# 只有献金才熄灯；「离开」不消耗（P2-22）。祭坛留在场上画熄灭态，不再触发交互
		s.used = true
		if not _prog["spots"].has(s.idx):
			_prog["spots"].append(s.idx)


## 拾取结算：金 + 远征币 + 探索分，一条 toast（同一帧捡两个也不刷屏——后一个覆盖前一个）
func on_pickup(p: _Pickup) -> void:
	if _map_done or _pickups.is_empty():
		return
	if not _prog["taken"].has(p.idx):
		_prog["taken"].append(p.idx)   # 进度落表：重进不再撒同一个（P0-1）
	_pickups.erase(p)
	var g := _cfg_range("pickup_gold", [18, 42])
	var c := _cfg_range("pickup_currency_amount", [3, 8])
	var gold := _rng.randi_range(int(g[0]) if g.size() > 0 else 18,
		int(g[1]) if g.size() > 1 else 42)
	var cur := _rng.randi_range(int(c[0]) if c.size() > 0 else 3,
		int(c[1]) if c.size() > 1 else 8)
	st.gold += gold
	st.expedition += cur
	Audio.sfx("pickup")   # 与战斗后的 coin 区分：一局要捡好几次，听感不能太重
	_toast("拾获 · 金币 +%d · 远征币 +%d" % [gold, cur])
	_add_score(_cfg_int("pickup_score", 6), "拾取")
	_mark_nav_dirty()   # 拾取物消失要立刻从地图上抹掉（问题 #15：节流不能让"点了没反应"）


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


func _update_nav(delta: float = 0.0) -> void:
	var info := _nav_info()
	if _compass != null:
		_compass.set_target(String(info.get("name", "")), info.get("pos", Vector2.ZERO),
			_player.position if _player != null else Vector2.ZERO, _auto_walk)
	if _minimap == null:
		return
	# 小地图重绘上限 ~10Hz（问题 #15）：一次 _draw 要遍历怪物/拾取物/兴趣点/传送阵多个集合，
	# 每帧重绘纯属浪费。位置类变化走节流；拾取/击杀/用掉兴趣点/开关大地图这类**事件**
	# 由 _mark_nav_dirty() 置脏，下一帧立刻刷新，不会出现"点了却半天不变"。
	_nav_acc += delta
	if _nav_dirty or _nav_acc >= MINIMAP_INTERVAL:
		_nav_acc = 0.0
		_nav_dirty = false
		_minimap.queue_redraw()


func _mark_nav_dirty() -> void:
	_nav_dirty = true


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
	_auto_fail = 0
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
	_auto_fail = 0
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
	# 按剩余距离给余量（2.5 倍步行时长）：远路不再被固定 26s 误判成"前路不通"（P1-14）
	var allowed := maxf(AUTO_TIMEOUT, to.length() / 100.0 * 2.5)
	if _auto_time > allowed:
		_stop_auto_walk("走得太久——请你亲自来")
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
	var expected := TableCache.map_player_speed() * delta * 0.45
	if moved < expected:
		_auto_stuck += delta
	else:
		_auto_stuck = 0.0
		_auto_fail = 0
	if _auto_stuck > 0.22:
		_auto_stuck = 0.0
		_auto_dodge = 0.5
		_auto_dodge_side = -_auto_dodge_side
		# 来回绕仍卡住 → 停手交还控制（不再无限对撞，P1-14）
		_auto_fail += 1
		if _auto_fail >= 4:
			_stop_auto_walk("前路受阻——请你亲自来")
			return


func _toggle_sprint() -> void:
	_sprint = not _sprint
	if _sprint_btn != null:
		if _mode == "main_world":
			var mark := _sprint_btn.get_child(1) as Label
			if mark != null:
				mark.text = "»»" if _sprint else "»"
			(_sprint_btn.get_child(0) as Control).tooltip_text = \
				"疾行：开启" if _sprint else "疾行：关闭"
		else:
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
	_mark_nav_dirty()   # 打开大地图时数据必须是最新的（问题 #15）
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
		"红点：敌影（视野内才会显形）· 亮点：散落的钱袋 / 魂晶（走近自动入袋）",
		"清光全图怪物有额外赏，走的越细、离开时的评价越高",
		"紫菱：碑灵祭坛（献金重摇一次祝福）· 灰点：矿脉（白拿养成材料）",
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
	if _mode == "main_world":
		_check_world_exits()
		return
	if _player.position.distance_to(_portal.position) < 36.0:
		if _portal.locked:
			if not _portal.warned:
				_portal.warned = true
				_toast("传送阵被首领封印——先击败它！")
		else:
			_finish_map("cleared")


func _check_world_exits() -> void:
	if _world_exit_cd > 0.0 or _player == null:
		return
	var exits: Variant = _main_cfg.get("exits", [])
	if not (exits is Array):
		return
	for row_v in exits:
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		if _player.position.distance_to(_cfg_point(row.get("at", []), Vector2.ZERO)) > 38.0:
			continue
		var required := String(row.get("requires_story", ""))
		if not required.is_empty() and not G.story_step_done(required):
			_world_exit_cd = 2.0
			_toast(String(row.get("locked_hint", "前路尚未开放——先完成当前主线")))
			return
		var target := String(row.get("to", ""))
		var target_cfg := TableCache.main_world_map(target)
		if target_cfg.is_empty() or not G.can_go("res://src/explore/MapScene.tscn"):
			return
		_world_exit_cd = 2.0
		var before_prog := G.prog.duplicate(true)
		_persist_main_world_progress()
		var state: Dictionary = G.prog.get("main_world", {}).duplicate(true)
		state["map_id"] = target
		state["layout_version"] = int(target_cfg.get("layout_version", 1))
		var arrival := String(row.get("arrival", ""))
		var points: Variant = target_cfg.get("spawn_points", {})
		var target_pos := _cfg_point(target_cfg.get("spawn", []), Vector2(480, 930))
		if points is Dictionary and (points as Dictionary).has(arrival):
			target_pos = _cfg_point((points as Dictionary)[arrival], target_pos)
		state["position"] = [roundi(target_pos.x), roundi(target_pos.y)]
		G.prog["main_world"] = WorldSession.normalize_state(state)
		if bool(target_cfg.get("dismount_on_entry", false)):
			G.mount_set_riding(false, false)
		if not G.save_game():
			G.prog = before_prog
			_toast("存档未能写入，留在当前地图")
			return
		G.enter_main_world(target, arrival)
		return


func _persist_main_world_progress() -> void:
	if _mode != "main_world":
		return
	var state: Dictionary = {}
	var previous: Variant = G.prog.get("main_world", {})
	if previous is Dictionary:
		state = (previous as Dictionary).duplicate(true)
	state["map_id"] = _main_map_id
	state["layout_version"] = int(_main_cfg.get("layout_version", 1))
	state.erase("killed")
	state["respawn_at"] = _main_respawn_at.duplicate()
	var per_map: Variant = state.get("respawn_by_map", {})
	if not (per_map is Dictionary):
		per_map = {}
	(per_map as Dictionary)[_main_map_id] = _main_respawn_at.duplicate()
	state["respawn_by_map"] = per_map
	if _player != null:
		var pos := _player.position
		if _portal != null and pos.distance_to(_portal.position) < 80.0:
			pos = _portal.position + Vector2(0, 110)
		state["position"] = [roundi(pos.x), roundi(pos.y)]
	G.prog["main_world"] = WorldSession.normalize_state(state)


func _finish_map(result: String) -> void:
	if _map_done:
		return
	_map_done = true
	if _mode == "main_world":
		_persist_main_world_progress()
		G.save_game()
		map_finished.emit(result)
		if map_finished.get_connections().is_empty():
			G.go("res://src/ui/GameHome.tscn")
		return
	if result == "cleared":
		st.node_cleared(int(node.get("layer", 1)), int(node.get("index", 0)))
		# 探索评价附加赏：走完节点时结算，"清一遍"的收益在这里落袋
		var r := _rank()
		var bonus := int(r.get("bonus", 0))
		if bonus > 0:
			st.gold += bonus
			Audio.sfx("reward")
			_toast("探索评价 · %s（金币 +%d）" % [String(r.get("name", "")), bonus])
	map_finished.emit(result)


# ================= 怪物接触开战 =================
## 任一浮层/演出/看地图打开时冻结怪物与接触判定（防"看地图被偷袭"，P1-10）
func _modal_open() -> bool:
	return _battle != null or _map_done or _picker != null or _remover != null \
		or _big_map != null or _altar_ui != null or _exit_ui != null or _beat != null \
		or _trade_panel != null or _fishing_panel != null \
		or (_city_content != null and bool(_city_content.call("has_modal"))) \
		or G.ui_blocked   # 转场 / GM 控制台：玩家被冻结时怪物也该冻结


func _open_trade_panel(site_id: String) -> void:
	if _trade_panel != null:
		return
	_trade_panel = TradePanel.new()
	_hud.add_child(_trade_panel)
	_trade_panel.open_site(site_id)
	_trade_panel.closed.connect(func():
		_trade_panel = null
		_refresh_hud())


func on_monster_contact(m: _MapMonster) -> void:
	if _modal_open():
		m.chasing_contact = false  # 浮层/战斗中并行触发的接触复位
		return
	_start_battle(m)


## 可选首领「接触前观察」上报（P05-C，spec §5「可战可察」）：
## 180px 内看见即算一次 observe（拍板口径：大于接触半径 56px，玩家不必开战）；
## 只推进已接的支线（未接不计数，P05 §4），同一只本图只上报一次（首次调用方已记 _optional_seen）。
func on_optional_boss_seen(mon_id: String) -> void:
	if _mode != "main_world" or _map_done:
		return
	var touched := G.side_report("observe", mon_id, _main_map_id, true)
	for qid_v in touched:
		var s_title := String(QuestService.side_row(G.side_quest_rows(), String(qid_v)).get("title", ""))
		if not s_title.is_empty():
			_toast("支线推进：%s" % s_title)


func _start_battle(m: _MapMonster) -> void:
	if _mode == "main_world" and not _story_battle_ready(m.mon_id):
		m.chasing_contact = false
		m.contact_cd = FLEE_CONTACT_CD
		return
	# 遇敌即停自动前往（战斗结束也不自动续走，要续走需再点罗盘）——防"一键全自动跑完整张图"
	_stop_auto_walk("")
	m.chasing_contact = true  # 接触怪冻结
	_contact_mon = m
	# P02：给这场接战一个稳定遭遇 ID（EncounterContext）。只用时间戳取唯一性，
	# 不消耗战斗种子——战斗内 RNG 的确定性不能被这场记录改坏。
	if _mode == "main_world":
		# 接战先落地；遭遇与步行状态在同一轮地图保存中落盘。
		if G.mount_riding():
			G.mount_set_riding(false, false)
			_sync_mount_visual()
		_encounter = WorldSession.new_encounter(_main_map_id, m.idx, m.position, m.mon_id,
			m.display_level, _player.position, "", 0, Time.get_ticks_usec())
		# P03：接触即推进 approach → locked 并落盘。崩在这里，重载后能解释成
		# 「这场遭遇已确认、尚未进战斗」——怪物还在图上，安全位纠偏后重新接触即可。
		_advance_encounter(WorldSession.ST_APPROACH)
		_advance_encounter(WorldSession.ST_LOCKED)
		_persist_main_world_progress()
		G.save_game()
	else:
		_encounter = {}
	# BOSS 战前「对峙」：第一次挑战这片秘境的首领时演一段（看过的不再拦人；
	# 设置里关掉演出则直接开打，且**不标记已看**——回头打开设置还能补看）
	if _mode != "main_world" and m.tier == "boss" and not bool(G.setting_get("skip_story", false)) \
			and not G.beat_seen(st.theme, "intro") \
			and not G.boss_beat_lines(st.theme, "intro").is_empty():
		G.mark_beat_seen(st.theme, "intro")
		_play_boss_beat("intro", func(): _launch_battle(m))
		return
	_launch_battle(m)


## 真正的开战（演出结束后 / 无演出时直接进）
func _launch_battle(m: _MapMonster) -> void:
	# 主题没有怪物池时拒绝开战：空池战斗会「一 tick 判胜并照发奖励」（A6 同批收口）
	var mons: Variant = TableCache.theme_config(st.theme).get("monsters", [])
	if mons is Array and (mons as Array).is_empty():
		push_error("主题怪物池为空，拒绝开战：%s" % st.theme)
		_toast("这片秘境空无一人")
		Audio.sfx("ui_locked")
		m.chasing_contact = false
		m.contact_cd = FLEE_CONTACT_CD
		m.retreat_home()
		_contact_mon = null
		return
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
			"unlocked_skills": G.act1_unlocked_skills(st.role_id),
			"skill_variants": G.act1_skill_variants(st.role_id),
			"pet_stats": G.battle_pet_stats([st.active_pet, st.bench_pet]),
		},
		"enemy": {"theme": st.theme, "node_type": m.tier,
			"layer": int(node.get("layer", 1)), "lead_mon": m.mon_id,
			"solo": _mode == "main_world" and bool(_main_cfg.get("encounter_solo", true)),
			"display_level": m.display_level,
			"sprite_path": m.sprite_path if _mode == "main_world" else "",
			# P05-C：召唤物（失路兽召的影狼）按单位 id 取自己的立绘，覆盖 leader 那张
			"sprite_paths": _main_cfg.get("monster_sprite_paths", {}) if _mode == "main_world" else {},
			# 苦行局（轮次 22）：敌人强度倍率由 RunState 决定，战斗内核只吃数字
			"enemy_mult": st.enemy_mult()},
		"mode": "pve",   # 超时按远征失利显示（口径 D3；问题 #21）
		"presentation": "classic_inline" if _mode == "main_world" else "default",
		# P03：撤退规则。主线首领（失声碑灵）不可撤退——按钮置灰并写明后果，
		# 由 BattleScene 直接读这一项，规则不写在表现层里。
		# P05-C：可选首领（失路兽）可自由撤退——不是必经关，撤退不该把玩家钉死在巢穴边。
		"flee_rule": "blocked" if (_mode == "main_world" and m.tier == "boss" and not m.optional) else "free",
		"player_name": G.display_name(),
		"seed": st.next_battle_seed(),
	}
	if _mode == "main_world":
		# 战斗单位由 BattleScene 接管；只留下地图底图，避免玩家/怪物和 HUD 各画两遍。
		_world.visible = false
		_hud.visible = false
	_battle_layer = CanvasLayer.new()
	_battle_layer.layer = 2
	add_child(_battle_layer)
	_battle = (load("res://src/battle/BattleScene.tscn") as PackedScene).instantiate()
	_battle.battle_finished.connect(_on_battle_end)
	_battle_layer.add_child(_battle)
	if _mode == "main_world":
		# P03：战斗层真的建起来了才写 battle（崩在中途 → 遭遇仍是 open，重打不二次发奖）
		_advance_encounter(WorldSession.ST_BATTLE)
		_persist_main_world_progress()
		G.save_game()


func _on_battle_end(result: String, hp_left: int) -> void:
	var battle := _battle
	var mastery_lines: Array = []
	if _mode == "main_world" and battle != null:
		mastery_lines = G.mentor_report_effective(battle.effective_skills)
	var monster_tier := _contact_mon.tier if _contact_mon != null else ""
	var defeated_mon_id := _contact_mon.mon_id if _contact_mon != null else ""
	_last_battle_tier = monster_tier   # 战后三选一次数按档位给（B3）
	# P05-C：可选首领标记——本场决定「可撤退、不掷装备、首胜单发」三项口径，
	# 结算与银行都在本函数之后读它，必须在 _settle_main_world 之前算好。
	_last_battle_optional = _contact_mon != null and _contact_mon.optional
	_battle = null
	_battle_layer.queue_free()  # 级联释放 BattleScene
	_battle_layer = null
	if _mode == "main_world":
		_world.visible = true
		_hud.visible = true
	st.apply_battle_result(battle.sim)
	for mastery_line_v in mastery_lines:
		_toast(String(mastery_line_v))
	# P03：收到结果先落到 result_pending（仅内存）。进程死在这一步 → 存档里仍是 battle，
	# 重进后这场遭遇是 open 的，可以重打一次并按 result_id 只结算一次。
	if _mode == "main_world":
		_advance_encounter(WorldSession.ST_RESULT_PENDING)
	# P03：撤退规则写在按钮上（flee_rule=blocked）；万一表现层仍然发出 flee，这里兜住，
	# 不让玩家从主线首领手里溜走（按败收场，与超时口径一致）。
	# P05-C：可选首领不在兜住范围内——它的 flee_rule 本就是 free，撤退按正常撤退走。
	if result == "flee" and _mode == "main_world" and monster_tier == "boss" and not _last_battle_optional:
		push_warning("首领战不允许撤退，按战败处理")
		result = "defeat"

	if result == "flee":
		# 撤退 = 退出本节点（与地图「撤离」同义）：保留战损与节点进度，不判负、不结束本局
		st.hp = hp_left
		if _contact_mon != null:
			_contact_mon.chasing_contact = false
			# 接触冷静期：否则玩家还在接触半径内，下一物理帧就被同一只怪二次拖进战斗
			_contact_mon.contact_cd = FLEE_CONTACT_CD
			_contact_mon.retreat_home()
			_contact_mon = null
		for m in _monsters:
			m.chasing_contact = false
		if _mode == "main_world":
			_advance_encounter(WorldSession.ST_FLED)
			_restore_after_battle()
			_advance_encounter(WorldSession.ST_RETURN)
			_encounter = {}
			_persist_main_world_progress()
			G.save_game()
		_refresh_hud()
		_toast("已撤退——节点进度已保留")
		return

	if result != "victory":
		# 含超时平局（draw）：PVE 里一律按败收场（口径 D3；演武场单独判平局）
		st.finished = true
		st.result = "defeat"
		if _mode == "main_world":
			# P03：failed 是终态，之后这场不会再被结算发奖（_finish_map 里会落盘）
			_advance_encounter(WorldSession.ST_FAILED)
		_finish_map("defeat")
		return
	if _mode == "main_world":
		# P03：唯一结算入口；已结算过（同 result_id 重复上报）则不发任何奖励。
		# R-04：写盘失败由 _settle_main_world 自己提示，这里不再改口成"已经结算过了"误导玩家。
		var settle_res := _settle_main_world(monster_tier, defeated_mon_id)
		if settle_res == "dup":
			_toast("这场战斗已经结算过了")
		elif settle_res in ["save_failed", "quest_missing"]:
			# 战利和刷点都已回滚；留在地图上可重新接触同一只怪。
			_encounter = {}
			if _contact_mon != null:
				_contact_mon.contact_cd = FLEE_CONTACT_CD
				_contact_mon = null
			_refresh_hud()
			return
		_encounter = {}
		st.hp = hp_left
	else:
		st.add_reward(monster_tier)  # 历练战利仍按 nodes.json 结算。
		_grant_drops(monster_tier)   # 材料掉落（data/drops.json）：刷图产出养成材料
		st.hp = hp_left
	# 主城委托上报：这一场打掉的怪算 1 只（"在某某秘境击杀 N 只"类委托靠它推进）
	if _mode != "main_world":
		var q_done := G.quest_report("slay", st.theme, 1)
		for t in q_done:
			_toast("委托办妥：%s —— 回城交付" % String(t))
	# 接触的怪离场；进度落表（重进不再复活、不重发奖励，P0-1）
	if _contact_mon != null:
		if _mode != "main_world" and not _prog["killed"].has(_contact_mon.idx):
			_prog["killed"].append(_contact_mon.idx)
		_monsters.erase(_contact_mon)
		_contact_mon.queue_free()
		_contact_mon = null
		_mark_nav_dirty()   # 击杀后小地图上的红点要立刻消失（问题 #15）
	if monster_tier == "boss" and _mode != "main_world":
		_prog["boss_down"] = true
	_kills += 1
	if _mode != "main_world":
		_add_score(_cfg_int("kill_score", 12), "击杀")
	if _mode != "main_world" and _monsters.is_empty() and _total_monsters > 0:
		_on_area_cleared()   # 清场：额外赏 + 评价提升（轮次 16）
	# 其余怪复位并返回巢穴
	for m in _monsters:
		m.chasing_contact = false
		m.retreat_home()
	# 首领解封传送阵；首次击败时先演一段「战后余韵」，再回词条三选一
	if monster_tier == "boss" and _mode != "main_world":
		if _portal != null:
			_portal.locked = false
			_toast("首领陨落——传送阵封印解除！")
		if not bool(G.setting_get("skip_story", false)) \
				and not G.beat_seen(st.theme, "outro") \
				and not G.boss_beat_lines(st.theme, "outro").is_empty():
			G.mark_beat_seen(st.theme, "outro")
			_play_boss_beat("outro", _after_battle_rewards)
			_refresh_hud()
			return
	_after_battle_rewards()


## 主世界胜利结算（P03 §1.1）：唯一发奖入口，按 result_id 幂等。
## 返回 "ok" = 本场第一次结算且已落盘；"dup" = 重复上报，什么都没做；
## "save_failed" = 已经结算但写盘失败（R-04：战利不算入袋，不显示成功提示）。
func _story_battle_ready(mon_id: String) -> bool:
	var row := G.story_current()
	if String(row.get("event", "")) != "defeat" or String(row.get("target", "")) != mon_id:
		return true
	var item := String(row.get("requires_item", ""))
	if not item.is_empty() and G.item_count(item) < 1:
		_toast("先备好%s，再挑战首领" % G.item_name(item))
		return false
	return true


func _settle_main_world(tier: String, defeated_mon_id: String) -> String:
	if not _story_battle_ready(defeated_mon_id):
		return "quest_missing"
	# 一次胜利会同时改动世界刷点、钱包、背包、主线和临时战利。
	# 写盘失败必须退回结算之前，而不是只退回最后一段支线进度。
	var before_prog := G.prog.duplicate(true)
	var before_wallet := G.wallet.duplicate(true)
	var before_items := G.items.duplicate(true)
	var before_respawn := _main_respawn_at.duplicate(true)
	var before_gold := st.gold
	var before_exp := st.exp
	var before_level := st.level
	var rewards: Variant = _main_cfg.get("battle_rewards", {})
	var reward: Variant = (rewards as Dictionary).get(tier, {}) if rewards is Dictionary else {}
	var gold := 0
	var exp := 0
	if reward is Dictionary:
		gold = maxi(0, int((reward as Dictionary).get("gold", 0)))
		exp = maxi(0, int((reward as Dictionary).get("exp", 0)))
	var ws := _main_world_state()
	# 去重闸门：同一个 result_id 只落地一次（重复上报 false → 一分钱不发、一件材料不掉）
	var settled := _encounter.is_empty() \
		or WorldSession.settle_result(ws, _encounter, "victory")
	if not settled:
		G.prog["main_world"] = ws
		return "dup"
	if _contact_mon != null:
		if _contact_mon.optional:
			# P05-C：可选首领不走 mark_boss_cleared（它不是必经首领，不能给传送阵解封
			# 之类的主线语义），走与普通怪同一条刷点重刷机制，时限按巢穴槽位自己给。
			var until := Time.get_unix_time_from_system() + _optional_respawn_seconds(_contact_mon.idx)
			WorldSession.mark_spawn_defeated(ws, _main_map_id, _contact_mon.idx, until)
			_main_respawn_at[str(_contact_mon.idx)] = until
		elif tier == "boss":
			WorldSession.mark_boss_cleared(ws, _main_map_id)
		else:
			var until2 := Time.get_unix_time_from_system() + _main_respawn_seconds()
			WorldSession.mark_spawn_defeated(ws, _main_map_id, _contact_mon.idx, until2)
			_main_respawn_at[str(_contact_mon.idx)] = until2
	WorldSession.advance(ws, _encounter, WorldSession.ST_RETURN)
	G.prog["main_world"] = ws
	# 主世界只产日常金币和经验；历练币/魂晶/荣誉由各自玩法产出。
	st.gold += gold
	st.exp += exp
	_restore_after_battle()
	var reward_msg := _bank_main_world_rewards(_encounter_tx_id())
	# P05-C：可选首领首胜（固定职业适配蓝装 + 图鉴条目 + 世界旗）。单事务、同一 ID 只发一次；
	# 调用返回快照，写盘失败时用它把首胜那部分（钱包/物品/进度含账本与背包）整体回滚。
	var first_kill := _apply_optional_first_kill(defeated_mon_id) if _last_battle_optional else {}
	# 战利、主线目标与遭遇状态一起写盘。中间任何一步退出时，磁盘上
	# 要么还是可重打的 battle，要么已完整结算，不能只留下半份奖励。
	# P05-B：支线讨伐计数（只对已接支线生效）。与主线、遭遇状态同一次写盘：
	# 写盘失败时连支线计数一起退回，磁盘上不留半份。
	var side_touched := G.side_report("defeat", defeated_mon_id, _main_map_id, false)
	var story_result := G.story_event("defeat", defeated_mon_id, _main_map_id, false)
	if not G.save_game():
		G.prog = before_prog
		G.wallet = before_wallet
		G.items = before_items
		_main_respawn_at = before_respawn
		st.gold = before_gold
		st.exp = before_exp
		st.level = before_level
		_toast("存档写入失败：战利未落袋（请检查磁盘空间后重进本图）")
		return "save_failed"
	_toast(reward_msg)
	if not first_kill.is_empty():
		_toast(String(first_kill.get("msg", "")))
	if not story_result.is_empty():
		_toast("主线完成：%s" % String(story_result.get("title", "")))
	for qid_v in side_touched:
		var s_title := String(QuestService.side_row(G.side_quest_rows(), String(qid_v)).get("title", ""))
		if not s_title.is_empty():
			_toast("支线推进：%s" % s_title)
	_refresh_hud()
	return "ok"


## 战后恢复（P03 §5）。主世界战斗是叠在地图上的表现层（classic_inline），
## 地图／玩家／相机全程不销毁，所以位置与镜头天然保留；这里把「会不会被二次拖进战斗」
## 这类残留状态显式收干净，并且是可断言的：
##   1) 玩家动画回到待机（战斗期间冻结在行走帧）
##   2) 玩家不在任何存活怪的接触半径内（否则结算层消失的下一帧就被拽回去）
##   3) 清接触锁并给存活怪一段接触冷静期
func _restore_after_battle() -> void:
	if _mode != "main_world":
		return
	if _player != null:
		var dangers: Array = []
		for m in _monsters:
			if m != _contact_mon and is_instance_valid(m):
				dangers.append(m.position)
		var safe := WorldSession.safe_position(_player.position, dangers,
			_portal.position if _portal != null else Vector2.ZERO, _map_extent())
		if safe != _player.position:
			_player.position = safe
		if _player_anim != null:
			_update_player_anim(Vector2.ZERO)
	for m2 in _monsters:
		if not is_instance_valid(m2):
			continue
		m2.chasing_contact = false
		m2.contact_cd = FLEE_CONTACT_CD


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


## 战后三选一次数（nodes.json run.trait_choices，B3）：精英 +1、首领 +2
func _trait_pick_count(tier: String) -> int:
	var run_v: Variant = TableCache.nodes_config().get("run", {})
	if not (run_v is Dictionary):
		return 1
	var tc: Variant = (run_v as Dictionary).get("trait_choices", {})
	if not (tc is Dictionary):
		return 1
	return maxi(1, int((tc as Dictionary).get(tier, 1)))


func _after_battle_rewards() -> void:
	if _mode == "main_world":
		_refresh_hud()
		return
	_pending_trait_picks = _trait_pick_count(_last_battle_tier)
	_next_trait_pick()


## 可选首领行（P05-C §5）：从本图 optional_bosses 按 mon_id 找整行（含 first_kill 配置）。
func _optional_boss_row(mon_id: String) -> Dictionary:
	var rows: Variant = _main_cfg.get("optional_bosses", [])
	if not (rows is Array):
		return {}
	for row_v in (rows as Array):
		if row_v is Dictionary and String((row_v as Dictionary).get("mon_id", "")) == mon_id:
			return row_v as Dictionary
	return {}


## 可选首领首胜（P05-C §5）：固定一件职业适配蓝装 + 图鉴条目 + 世界旗，单事务幂等。
## tx = act1|<行 id>|first|（行 id 即 spec §5 的 `act1|lost_beast|first`），重打命中
## applied → 什么都不发，只拿普通收益。
## 返回 {} = 无配置／已拿过／事务未落地；否则 {snapshot:[prog,wallet,items], msg}，
## 快照供调用方写盘失败时把首胜那部分整体回滚（含账本 applied 与背包实例）。
func _apply_optional_first_kill(mon_id: String) -> Dictionary:
	var row := _optional_boss_row(mon_id)
	var fkv: Variant = row.get("first_kill", {})
	if not (fkv is Dictionary) or (fkv as Dictionary).is_empty():
		return {}
	var fk := fkv as Dictionary
	var row_id := String(row.get("id", mon_id))
	var tid := RewardLedger.tx_id(String(fk.get("tx_scope", "act1")), row_id, "first")
	if RewardLedger.applied(G.ledger(), tid):
		return {}
	var equips: Variant = fk.get("equips", {})
	var pick: Variant = (equips as Dictionary).get(st.role_id, {}) if equips is Dictionary else {}
	var tpl := String((pick as Dictionary).get("tpl", "")) if pick is Dictionary else ""
	if tpl.is_empty():
		push_warning("首胜配置缺少职业装备：%s / %s" % [mon_id, st.role_id])
		return {}
	var grant_key := "equip:%s:%d" % [tpl, int((pick as Dictionary).get("rarity", 3))]
	var flag := String(fk.get("flag", ""))
	var flags := {flag: true} if not flag.is_empty() else {}
	var tx := RewardLedger.make(tid, {}, {grant_key: 1}, flags)
	var before_prog := G.prog.duplicate(true)
	var before_wallet := G.wallet.duplicate(true)
	var before_items := G.items.duplicate(true)
	var res := RewardLedger.apply(tx, G.ledger(), G)
	if not bool(res.get("ok", false)):
		push_warning("首胜战利未落地：%s" % String(res.get("err", "")))
		return {}
	# 图鉴条目 + 首杀记录：与事务同一批内存状态，随调用方统一写盘
	var disc := String(fk.get("discovery", ""))
	if not disc.is_empty():
		var discs: Array = G.act1_state()["discoveries"]
		if not discs.has(disc):
			discs.append(disc)
	var fkills: Array = G.act1_state()["first_kills"]
	if not fkills.has(mon_id):
		fkills.append(mon_id)
	var tpl_name := String(G.equip_tpl(tpl).get("name", tpl))
	return {"snapshot": [before_prog, before_wallet, before_items],
		"msg": "首胜战利 · 装备 %s" % tpl_name}


## 主世界是常驻成长：每场胜利立刻入账，异常退出也不会吞掉已经取得的战利。
## txid 非空时走奖励账本（P02）：同一遭遇重复结算只会入账一次。
func _bank_main_world_rewards(txid := "") -> String:
	_persist_main_world_progress()
	var gold := st.gold
	var exp := st.exp
	var level_ups := 0
	var msg_suffix := ""
	var material_parts := PackedStringArray()
	if txid.is_empty():
		G.deposit(gold, 0, 0, 0)
		level_ups = G.gain_exp(exp)
	else:
		var before := int(G.prog.get("level", 1))
		var grants := {"gold": gold, "exp": exp}
		# 装备掉落（P04 §5）：只在事务**尚未落地**时掷一次，并进同一笔事务。
		# 同一 txid 重放会命中 applied → 不再掷、不再发，与金币经验同一条幂等口径。
		if not RewardLedger.applied(G.ledger(), txid):
			for row_v in G.roll_drops(_last_battle_tier):
				var row := row_v as Dictionary
				var iid := String(row.get("item", ""))
				var n := int(row.get("n", 0))
				if iid.is_empty() or n <= 0:
					continue
				var key := "item:%s" % iid
				grants[key] = int(grants.get(key, 0)) + n
				material_parts.append("%s ×%d" % [G.item_name(iid), n])
			# P05-C：可选首领不掷随机装备——首胜的定向蓝装由 _apply_optional_first_kill
			# 单发；重打只给材料／金币／经验（spec §5「再次挑战只给普通材料、经验和有上限的金币」）。
			if not _last_battle_optional:
				var drop := Inventory.roll_drop(G.equip_cfg(), TableCache.drops_config(),
					_last_battle_tier, _rng)
				if not drop.is_empty():
					var dtpl := G.equip_tpl(String(drop.get("tpl", "")))
					grants["equip:%s:%d" % [String(drop.get("tpl", "")), int(drop.get("rarity", 1))]] = 1
					msg_suffix = " · 装备 %s" % String(dtpl.get("name", "?"))
		var tx := RewardLedger.make(txid, {}, grants, {})
		var res := RewardLedger.apply(tx, G.ledger(), G)
		if not bool(res.get("ok", false)):
			push_warning("战斗结算未落地：%s" % String(res.get("err", "")))
			msg_suffix = ""
		elif bool(res.get("duplicate", false)):
			_toast("这场战斗已经结算过了")
			msg_suffix = ""
		level_ups = maxi(0, int(G.prog.get("level", before)) - before)
		# 调用方在主线事件也入内存后统一写盘；事务内禁止提前保存。
	st.gold = 0
	st.expedition = 0
	st.soul = 0
	st.honor = 0
	st.exp = 0
	st.level = int(G.prog.get("level", st.level))
	if _city_content != null:
		_city_content.call("_refresh_stat")
	var msg := "战利 · 铜钱 +%d · 经验 +%d%s" % [gold, exp, msg_suffix]
	if level_ups > 0:
		msg += " · 升级 ×%d" % level_ups
	if not material_parts.is_empty():
		msg += " · %s" % material_parts[0]
		if material_parts.size() > 1:
			msg += " 等"
	return msg


func _next_trait_pick() -> void:
	if _pending_trait_picks <= 0:
		return
	var choices := st.roll_trait_choices(_rng)
	if choices.is_empty():
		# 词条池已尽：剩余次数静默跳过，不再逐次弹「已尽」刷屏
		_pending_trait_picks = 0
		_toast("词条池已尽")
		return
	_pending_trait_picks -= 1
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


## 散落拾取物（魂晶 / 钱袋）：走过去自动入袋，给"空跑的那段路"一点微反馈
class _Pickup extends Node2D:
	var idx := 0              # 稳定序号（进度表按它记「已拾取」，P0-1）
	var kind := "coin"        # coin / soul（只影响画法与提示色调）
	var map_ref: MapScene = null
	var used := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if used or map_ref == null or map_ref._player == null:
			return
		if map_ref._map_done or map_ref._battle != null:
			return
		var r := float(map_ref._cfg_int("pickup_radius", 30))
		if position.distance_to(map_ref._player.position) < r:
			used = true
			map_ref.on_pickup(self)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var bob := sin(_t * 3.0) * 3.0
		var base := Color("f0c060") if kind == "coin" else Color("8ad0e8")
		# 地面光斑：远处也能一眼看到（配合小地图上的同色小点）
		draw_set_transform(Vector2(0, 5), 0.0, Vector2(1.0, 0.36))
		draw_circle(Vector2.ZERO, 13.0, Color(base.r, base.g, base.b, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var c := Vector2(0, bob)
		if kind == "coin":
			draw_circle(c, 8.0, Color("a8761e"))
			draw_circle(c, 6.5, base)
			draw_circle(c + Vector2(-1.6, -1.6), 2.0, Color(1, 1, 1, 0.65))
		else:
			var pts := PackedVector2Array([c + Vector2(0, -10), c + Vector2(6, -1),
				c + Vector2(0, 10), c + Vector2(-6, -1)])
			draw_colored_polygon(pts, base)
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
				Color(1, 1, 1, 0.5), 1.2, true)


## 兴趣点（碑灵祭坛 / 矿脉）：走近触发一次交互。与拾取物的差别是"要不要做"——
## 祭坛弹选择框（花金重摇祝福），矿脉白拿材料。用掉即熄，不重复打扰。
class _Spot extends Node2D:
	var idx := 0              # 稳定序号（进度表按它记「已用过」，P0-1）
	var kind := "vein"        # altar / vein
	var map_ref: MapScene = null
	var used := false
	var cd := 0.0             # 触发冷却：关闭浮层后短暂不再触发（防重弹）
	var _t := 0.0
	var _bob := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if cd > 0.0:
			cd -= delta
		if used or map_ref == null or map_ref._player == null:
			return
		if map_ref._modal_open() or cd > 0.0:
			return
		var r := float(map_ref._cfg_int("spot_radius", 34))
		if position.distance_to(map_ref._player.position) < r:
			# 矿脉：立刻锁死并交接入袋（回调里 queue_free）
			# 祭坛：不锁——由 _altar_ui != null 的守卫防重入，玩家选完（献金或离开）才标记用过
			if kind == "vein":
				used = true
			map_ref.on_spot(self)
			return
		queue_redraw()

	func _draw() -> void:
		_bob = sin(_t * 2.0) * 2.0
		if kind == "vein":
			# 矿脉：灰蓝岩块上嵌几颗亮矿点
			draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.36))
			draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.26))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var rock := Color("6b6f78")
			draw_colored_polygon(PackedVector2Array([Vector2(-22, 10), Vector2(-12, -12),
				Vector2(6, -16), Vector2(22, -2), Vector2(16, 10)]), rock)
			draw_polyline(PackedVector2Array([Vector2(-22, 10), Vector2(-12, -12),
				Vector2(6, -16), Vector2(22, -2), Vector2(16, 10), Vector2(-22, 10)]),
				Color(0, 0, 0, 0.35), 2.0, true)
			for p in [Vector2(-8, -6), Vector2(4, -9), Vector2(10, 0)]:
				draw_circle(p + Vector2(0, _bob), 3.4, Color("9fe0f0"))
			return
		# 碑灵祭坛：立着的断碑 + 顶部浮动的青色碑火
		draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, 24.0, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(-16, -34, 32, 46), Color("7d7a86") if not used else Color("64616c"))
		draw_rect(Rect2(-16, -34, 32, 7), Color("5f5c68") if not used else Color("4d4b55"))
		draw_rect(Rect2(-20, 8, 40, 8), Color("57545e"))
		for i in 3:   # 碑文：三条阴刻线（不是文字，避免烧字进图）
			draw_line(Vector2(-9, -24 + i * 11), Vector2(9, -24 + i * 11), Color(0, 0, 0, 0.30), 2.0)
		var flame := Vector2(0, -46 + _bob)
		if used:
			draw_circle(flame, 7.0, Color(0.42, 0.45, 0.5, 0.30))  # 已熄：只剩一圈冷灰
			return
		draw_circle(flame, 13.0, Color(0.55, 0.9, 1.0, 0.20))
		draw_circle(flame, 6.5, Color("7ae0ff"))
		draw_circle(flame + Vector2(0, -2), 3.0, Color(1, 1, 1, 0.85))


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


## 道路出口：无烧字素材，目的地文字由引擎渲染。
class _WorldExit extends Node2D:
	var caption := ""
	var gate_style := "normal"  # 碑窟北口：修碑前灰石，修碑后暖金

	func _ready() -> void:
		var caption_color := Color("ffe2a0") if gate_style == "restored" else \
			(Color("d7d5cd") if gate_style == "sealed" else Color("fff1c4"))
		var label := G.gold_label(caption, G.FS_XS, true, caption_color, true)
		label.position = Vector2(-72, -70)
		label.size = Vector2(144, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		queue_redraw()

	func _draw() -> void:
		var board := Color("c49650") if gate_style == "restored" else \
			(Color("777875") if gate_style == "sealed" else Color("b18445"))
		var edge := Color("ffe1a0") if gate_style == "restored" else \
			(Color("aeb0ac") if gate_style == "sealed" else Color("ead19a"))
		draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, 34.0, Color(0.08, 0.11, 0.08, 0.42))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(-3, -48, 6, 42), Color("765b3b") if gate_style == "restored" else Color("6e4c2c"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-37, -54), Vector2(32, -54), Vector2(42, -43),
			Vector2(32, -32), Vector2(-37, -32)]), board)
		draw_line(Vector2(-35, -52), Vector2(31, -52), edge, 2.0)
		draw_line(Vector2(-35, -34), Vector2(31, -34), Color("5c3b25"), 2.0)


## 怪物（mon_ 精灵优先，无素材回退程序圆体；游荡/警戒/追击/接触回调）
class _MapMonster extends CharacterBody2D:
	var idx := 0                      # 稳定序号（进度表按它记「已击杀」，P0-1）
	var contact_cd := 0.0             # 接触冷静期（撤退后不再立刻重新开战）
	var tier := "normal"
	var mon_id := ""                  # 具体怪 id（精灵与战斗组队都按它）
	var optional := false             # 可选首领（P05-C）：自由撤退、不掷装备、独立重刷
	var sprite_path := ""
	var sprite_height := 48.0
	var contact_radius := 0.0         # 槽级接触半径覆盖（0 = 沿用本图普通怪口径）
	var wander_radius := 0.0          # 槽级游荡半径覆盖（0 = 同上）
	var display_level := 0
	var wander_only := false
	var level_l: Label = null
	var _label_top := 0.0            # 名签本地 y（由形象高度决定；钳制只动 x，见 _clamp_label）
	const LABEL_H := 22.0            # 名签行高（FS_SM 16 + 描边）：算屏内重叠用
	const OPTIONAL_SEEN_RADIUS := 180.0  # 可选首领「接触前观察」半径（P05-C 拍板口径）
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
	# 卡住检测（问题 #23）：move_and_slide 顶着散件时"速度有值、位置不动"，
	# 所以只能用**实际位移**判断有没有进展。连续卡住就绕行，绕不动就放弃当前目标。
	const STALL_SEC := 0.6        # 连续这么久几乎没有实际位移 → 判定卡住
	const STALL_MIN_RATIO := 0.35  # 实际位移低于期望位移的这个比例就算没进展
	const STALL_GIVE_UP := 3       # 连续卡住这么多次 → 放弃当前目标（不传送，只换目标）
	var _stall := 0.0
	var _stalls := 0
	var _detour := 0.0             # 绕行剩余时间：>0 时先横向挪开，别继续顶
	var _detour_to := Vector2.ZERO

	func _ready() -> void:
		_radius = {"normal": 20.0, "elite": 25.0, "boss": 32.0}.get(tier, 20.0)
		# 参与碰撞：只撞散件层（mask 2），用 move_and_slide 走位——不再穿树（P1-15）
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		collision_layer = 1
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var cir := CircleShape2D.new()
		cir.radius = _radius * 0.75
		cs.shape = cir
		# 碰撞圆对准身体（原点上方）：散件的碰撞盒也在脚上方，圆若压在脚下会从盒底滑过去（实测穿树）
		cs.position = Vector2(0, -_radius * 0.5)
		add_child(cs)
		var mc: Dictionary = TableCache.maps_config()
		_aggro = float(mc.get("aggro_radius", 120.0))
		_contact = float(mc.get("contact_radius", 26.0))
		_wander_r = float(mc.get("monster_wander_radius", 96.0))
		if wander_only:
			_contact = float(map_ref._main_cfg.get("monster_contact_radius", 42.0))
			_wander_r = float(map_ref._main_cfg.get("monster_wander_radius", 48.0))
		if optional:
			# 首领巢穴的接触/游荡半径按刷点单独给：接触圈要够大（撞上就开战），
			# 游荡圈要够小（守着巢口，不巡到主街上挡路）
			if contact_radius > 0.0:
				_contact = contact_radius
			if wander_radius > 0.0:
				_wander_r = wander_radius
		# 精灵体：boss 84 / elite 60 / normal 48 像素高，脚底对齐碰撞原点
		if mon_id != "":
			var tex: Texture2D = load(sprite_path) as Texture2D if not sprite_path.is_empty() else G.res_tex(mon_id)
			if tex != null:
				var h: float = sprite_height if not sprite_path.is_empty() else {"normal": 48.0, "elite": 60.0, "boss": 84.0}.get(tier, 48.0)
				var s := h / float(tex.get_height())
				_sprite = Sprite2D.new()
				_sprite.texture = tex
				_sprite.scale = Vector2.ONE * s
				_sprite.offset = Vector2(0, -tex.get_height() / 2.0)
				add_child(_sprite)
		if display_level > 0:
			var mon_name := String(TableCache.get_monster(mon_id).get("name", "怪物"))
			var txt := "Lv%d %s" % [display_level, mon_name]
			# 普通明雷的信息层压低一档；精英／首领仍保留醒目的紫色等级提示。
			var label_fs := G.FS_SM if tier in ["elite", "boss"] else G.FS_XS
			var label_color := Color("c46cdd") if tier in ["elite", "boss"] \
				else Color("c9b2d1", 0.9)
			level_l = G.gold_label(txt, label_fs, true, label_color, true)
			# P01 样板 §6：盒宽按文本实测（旧值固定 132，长名截断、短名留白），
			# 位置再按画布坐标钳回屏内，避免怪物走到屏缘时名签被裁掉半边。
			var label_w := clampf(G.font_bold.get_string_size(txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_fs).x + 10.0, 72.0, 150.0)
			_label_top = -sprite_height - 7.0
			level_l.position = Vector2(-label_w * 0.5, _label_top)
			level_l.custom_minimum_size = Vector2(label_w, 0)
			level_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(level_l)
		var h := float(absi(hash(Vector2(position).floor())))
		for i in 18:
			_lobe.append(sin(float(i) * 2.1 + h) * 0.13 + sin(float(i) * 0.7 + h * 0.5) * 0.09)
		_pick_wander_target()

	## 名签屏内钳制（P01 样板 §6）：怪物贴到屏缘时，居中的「Lv n 名字」会被裁掉半边。
	## 照 CityScene._CityNPC._clamp_plate() 的做法，按画布坐标把名签拨回屏内（左右各留 4px）。
	func _clamp_label() -> void:
		if level_l == null:
			return
		var xf := get_global_transform_with_canvas()
		var z: float = absf(xf.x.x)
		if z < 0.001:
			return
		var viewport_w := map_ref.get_viewport_rect().size.x if map_ref != null else 480.0
		# 怪物本体已经离开画面时不能只把名签钳在边缘，否则会在城务 NPC
		# 附近留下与实体脱节的「Lv 怪物」浮字。
		if xf.origin.x < 0.0 or xf.origin.x > viewport_w:
			level_l.visible = false
			return
		var w: float = level_l.custom_minimum_size.x
		var lo := (4.0 - xf.origin.x) / z
		var hi := (viewport_w - 4.0 - xf.origin.x) / z - w
		var px := clampf(-w * 0.5, lo, hi) if lo <= hi else -w * 0.5
		level_l.position = Vector2(px, _label_top)
		# 名签不得盖住 HUD（P01 样板 §6）：落进上方状态面板／主线条或下方按钮与摇杆区
		# 就隐藏——HUD 是半透明的，压在下面照样透出来。
		var scr_top := xf.origin.y + _label_top * z
		level_l.visible = scr_top >= _hud_safe_top() and scr_top + LABEL_H * z <= 600.0

	## 上方 HUD 禁区下缘：取状态面板与主线签的实际落位（城内主线签更低），不是写死 116
	func _hud_safe_top() -> float:
		var top := 116.0
		if map_ref != null and map_ref._main_story_l != null:
			var chip := map_ref._main_story_l.get_parent() as Control
			if chip != null:
				top = maxf(top, chip.position.y + chip.size.y + 2.0)
		return top

	func _pick_wander_target() -> void:
		var a := randf() * TAU
		var d := randf() * _wander_r
		_target = home + Vector2(cos(a), sin(a)) * d

	func _physics_process(delta: float) -> void:
		_t += delta
		_clamp_label()
		if map_ref == null or map_ref._player == null:
			return
		if chasing_contact or map_ref._modal_open():
			return  # 接触中 / 任意浮层或演出打开期间冻结（含看地图，P1-10）
		if contact_cd > 0.0:
			contact_cd -= delta
		var player: CharacterBody2D = map_ref._player
		var dist := position.distance_to(player.position)
		if optional and dist < OPTIONAL_SEEN_RADIUS and not map_ref._optional_seen.has(mon_id):
			# 「接触前观察」（P05-C 拍板口径：180px > 接触半径 56px）：先看见就算见过，
			# 支线「路西兽影」据此可回城回报；同一只在本图只上报一次（不逐帧写档）
			map_ref._optional_seen[mon_id] = true
			map_ref.on_optional_boss_seen(mon_id)
		if contact_cd <= 0.0 and dist < _contact:
			chasing_contact = true
			map_ref.on_monster_contact(self)
			return
		if wander_only:
			_state = "wander"
		elif dist < _aggro and not map_ref._map_done and map_ref._battle == null:
			_state = "chase"
		elif _state == "chase" and dist > _aggro * 1.4:
			_state = "wander"
			_pick_wander_target()
		var speed := 40.0
		if _state == "chase":
			_target = player.position
			speed = TableCache.map_player_speed() * 0.9
		if _detour > 0.0:
			_detour -= delta
			_target = _detour_to   # 绕行期间先走侧移点，绕完再回到原目标
		var to := _target - position
		var pre := position
		if to.length() > 6.0:
			velocity = to.normalized() * speed
			move_and_slide()   # 散件阻挡 + 沿边滑行（P1-15）
			# 实际位移远小于期望 → 被挡住了（速度仍有值）。累计到阈值就绕行，别一直顶着树抖。
			var want := speed * delta
			if want > 0.001 and position.distance_to(pre) < want * STALL_MIN_RATIO:
				_stall += delta
				if _stall >= STALL_SEC:
					_stall = 0.0
					_on_stalled()
			else:
				_stall = 0.0
				_stalls = 0   # 有进展就重置计数，避免把"走得慢"累计成"卡住"
		elif _state == "wander":
			_wait += delta
			if _wait > randf_range(0.8, 2.2):
				_wait = 0.0
				_pick_wander_target()
		queue_redraw()

	## 卡住一次：先绕行；连续绕不动就放弃当前目标。
	## **不做穿墙传送**——只换目标点，位置永远由 move_and_slide 决定。
	func _on_stalled() -> void:
		_stalls += 1
		if _stalls >= STALL_GIVE_UP:
			_stalls = 0
			_detour = 0.0
			if _state == "chase":
				_state = "wander"   # 追不到就不追了，别再顶着障碍抖
			_target = home
			return
		_start_detour()

	## 绕行点：追击时沿"目标方向"的侧向挪开（不往玩家接触圈里挤），游荡时随机换个方向。
	func _start_detour() -> void:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		if _state == "chase" and map_ref != null and map_ref._player != null:
			var to_p := (map_ref._player.position - position).normalized()
			var perp := Vector2(-to_p.y, to_p.x)
			if perp.dot(home - position) < 0.0:
				perp = -perp
			dir = (perp + to_p * 0.35).normalized()
		_detour_to = position + dir * 72.0
		_detour = 0.5

	## 撤退后回巢：必须一并清掉绕行/卡住状态（问题 #23）——否则它可能带着上一段的
	## 侧移目标继续往障碍里顶，"回巢"就成了空话。
	func retreat_home() -> void:
		_state = "wander"
		_target = home
		_detour = 0.0
		_stall = 0.0
		_stalls = 0

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
		if mon_id == "mon_salt_crab":
			_draw_salt_crab(bob)
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
		if _state == "chase":
			draw_arc(Vector2(0, bob), r + 8.0, 0.0, TAU, 20, Color(1.0, 0.4, 0.3, 0.85), 2.0)

	func _draw_salt_crab(bob: float) -> void:
		var water := Color("315d68")
		var shell := Color("d7e4d5")
		var rim := Color("83adb0")
		for side: float in [-1.0, 1.0]:
			for i in 3:
				var y := -7.0 + float(i) * 10.0 + bob
				var x := side * (22.0 + float(i % 2) * 4.0)
				draw_line(Vector2(side * 14.0, y), Vector2(x, y + 8.0), water, 4.0)
				draw_line(Vector2(x, y + 8.0), Vector2(x + side * 9.0, y + 12.0), rim, 3.0)
			draw_line(Vector2(side * 19.0, -11.0 + bob), Vector2(side * 32.0, -24.0 + bob), water, 5.0)
			draw_circle(Vector2(side * 35.0, -25.0 + bob), 8.0, rim)
			draw_colored_polygon(PackedVector2Array([
			Vector2(side * 35.0, -25.0 + bob), Vector2(side * 44.0, -36.0 + bob),
			Vector2(side * 42.0, -20.0 + bob)]), shell)
		draw_set_transform(Vector2(0.0, -1.5 + bob), 0.0, Vector2(1.0, 0.78))
		draw_circle(Vector2.ZERO, 25.0, water)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2(0.0, -2.0 + bob), 25.0, PI * 1.06, PI * 1.94, 20, rim, 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-19.0, -24.0 + bob), Vector2(-8.0, -34.0 + bob),
			Vector2(10.0, -33.0 + bob), Vector2(21.0, -20.0 + bob),
			Vector2(13.0, 2.0 + bob), Vector2(-15.0, 2.0 + bob)]), shell)
		for side: float in [-1.0, 1.0]:
			draw_line(Vector2(side * 8.0, -27.0 + bob), Vector2(side * 11.0, -37.0 + bob), water, 3.0)
			draw_circle(Vector2(side * 11.0, -39.0 + bob), 3.5, Color("18343d"))


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
		if map_ref._modal_open():
			return  # 覆盖层期间不触发（含看大地图/演出，P1-10）
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


## 支线实体（P05-B）：旧风铃／草根／足迹／驿亭。是否生成完全由任务状态决定
## （见 _build_quest_entities），交互成功即从地图消失；头顶蓝三角与主线金标区分。
class _QuestEntity extends Node2D:
	var eid := ""
	var quest := ""
	var kind := "collect"        # collect / observe / deliver
	var story_event_kind := "collect"
	var art := "root"            # chime / root / tracks / post
	var caption := ""
	var used := false
	var trade_cooled := false
	var map_ref: MapScene = null
	var _t := 0.0
	var _trade_tex: Texture2D = null

	func _ready() -> void:
		if art == "trade_stall":
			_trade_tex = G.res_tex("trade_stall")
		var label := G.gold_label(caption, G.FS_XS, true,
			Color("ffe2a0") if kind in ["cache", "trade", "story"] else Color("cfe3ff"), true)
		label.position = Vector2(-84, -124 if art in ["trade_stall", "salt_cart", "tide_cargo"] else -70)
		label.size = Vector2(168, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if used or map_ref == null or map_ref._player == null:
			return
		if kind in ["trade", "fishing"]:
			if position.distance_to(map_ref._player.position) > MapScene.INTERACT_R + 32:
				trade_cooled = false
			elif trade_cooled:
				return
		if map_ref._modal_open():
			return  # 覆盖层期间不触发（与 _Interactable 同口径）
		if position.distance_to(map_ref._player.position) < MapScene.INTERACT_R:
			map_ref.on_quest_entity(self)
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.36))
		draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.24))   # 落地影
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		match art:
			"frost_brazier":
				draw_rect(Rect2(-7, -46, 14, 46), Color("53483c"))
				draw_rect(Rect2(-16, -63, 32, 22), Color("c19b65"))
				draw_rect(Rect2(-19, -68, 38, 7), Color("dddcd0"))
				draw_line(Vector2(-3, -62), Vector2(8, -43), Color("604d3f"), 3)
			"frost_nameplate":
				var plate := G.res_tex("itm_frost_nameplate")
				if plate != null: draw_texture_rect(plate, Rect2(-22, -42, 44, 44), false)
			"frost_lichen":
				for p in [Vector2(-19, -8), Vector2(0, -17), Vector2(19, -5)]:
					draw_rect(Rect2(p - Vector2(10, 9), Vector2(20, 17)), Color("7caea5"))
					draw_rect(Rect2(p - Vector2(6, 8), Vector2(12, 5)), Color("d5e5dc"))
			"mine_vent":
				draw_rect(Rect2(-25, -25, 50, 24), Color("53616b"))
				draw_circle(Vector2(0, -37), 20, Color("a78553"))
				draw_circle(Vector2(0, -37), 12, Color("42545c"))
				for angle in [0.0, PI / 2, PI, PI * 1.5]:
					draw_line(Vector2(0, -37), Vector2(0, -37) + Vector2.from_angle(angle) * 18, Color("c5ad7c"), 4)
			"frost_courier":
				# 接应人沿用霜关 NPC 的原生人物比例，蓝绳药包握在身侧。
				draw_rect(Rect2(-10, -64, 20, 20), Color("76533b"))
				draw_rect(Rect2(-8, -59, 16, 16), Color("dbbd92"))
				draw_rect(Rect2(-13, -43, 26, 28), Color("638e9e"))
				draw_rect(Rect2(-17, -38, 6, 19), Color("83bfc6"))
				draw_rect(Rect2(11, -38, 6, 19), Color("83bfc6"))
				draw_rect(Rect2(-10, -15, 8, 15), Color("4e453b"))
				draw_rect(Rect2(3, -15, 8, 15), Color("4e453b"))
				draw_rect(Rect2(12, -25, 17, 17), Color("c9ba91"))
				draw_line(Vector2(15, -18), Vector2(27, -18), Color("83bfc6"), 3)
			"frost_echo":
				draw_rect(Rect2(-23, -61, 46, 60), Color("718f9b"))
				draw_rect(Rect2(-16, -53, 32, 43), Color("bddbe1"))
				draw_line(Vector2(-8, -46), Vector2(9, -18), Color("4e7c90"), 4)
				draw_arc(Vector2(0, -35), 31, -PI * .75, -PI * .25, 10, Color("a0cfd3"), 2)
			"signal_ribbons":
				for x in [-26.0, 26.0]:
					draw_rect(Rect2(x - 3, -75, 6, 80), Color("635543"))
					var flag_color := Color("c9b477") if x < 0 else Color("83bfc6")
					draw_rect(Rect2(x, -72, 25, 38), flag_color)
					draw_line(Vector2(x + 5, -65), Vector2(x + 18, -46), Color("f1eee0"), 3)
			"mine_cart":
				draw_rect(Rect2(-46, -46, 82, 34), Color("495862"))
				draw_rect(Rect2(-48, -49, 86, 7), Color("9da9a7"))
				for x in [-28.0, 24.0]:
					draw_circle(Vector2(x, -10), 12, Color("272e31"))
					draw_circle(Vector2(x, -10), 6, Color("a48a64"))
				for p in [Vector2(-27, -51), Vector2(-5, -60), Vector2(18, -53)]:
					draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0), p + Vector2(-8, -15), p + Vector2(9, -20), p + Vector2(15, 1)]), Color("846b4c"))
				draw_rect(Rect2(35, -26, 22, 19), Color("e4cf9c"))
				for y in [-22.0, -17.0, -12.0]:
					draw_line(Vector2(38, y), Vector2(54, y), Color("745642"), 2)
			"rope":
				draw_rect(Rect2(-4, -30, 8, 36), Color("5d4532"))
				for offset in [0.0, 5.0, 10.0]:
					draw_arc(Vector2(-12 + offset, -12), 14, 0.0, TAU * 0.85, 20, Color("b99765"), 3)
			"feather":
				draw_colored_polygon(PackedVector2Array([Vector2(-16, -6), Vector2(-8, -28), Vector2(10, -38), Vector2(14, -16), Vector2(0, 0)]), Color("92b9c7"))
				draw_line(Vector2(-5, 1), Vector2(9, -30), Color("dddcca"), 2)
			"salt_marks":
				for offset in [0.0, 8.0, 16.0]:
					draw_polyline(PackedVector2Array([Vector2(-23, -8 + offset), Vector2(-7, -16 + offset), Vector2(14, -11 + offset), Vector2(25, -17 + offset)]), Color("d9dbc9"), 3)
			"courier":
				var strip := G.res_tex("npc_port_worker_idle")
				if strip != null:
					draw_texture_rect_region(strip, Rect2(-38, -75, 76, 76), Rect2(0, 0, 128, 128))
				else:
					_draw_post()
			"fishing":
				_draw_fishing()
			"tide_cargo":
				_draw_tide_cargo()
			"salt_cart":
				_draw_salt_cart()
			"trade_stall":
				if _trade_tex != null:
					draw_texture(_trade_tex, Vector2(-56, -96))
				else:
					_draw_post()
			"chime":
				_draw_chime()
			"cache":
				_draw_cache()
			"tracks":
				_draw_tracks()
			"post":
				_draw_post()
			_:
				_draw_root()
		# 固定奇遇金三角，支线蓝三角：地图上可直接分辨两个事件。
		var bob := sin(_t * 2.2) * 4.0
		var tip := Vector2(0, (-142.0 if art in ["trade_stall", "salt_cart", "tide_cargo"] else -88.0) + bob)
		draw_colored_polygon([tip + Vector2(0, -7), tip + Vector2(6, 3), tip + Vector2(-6, 3)],
			Color("ffd279") if kind in ["cache", "trade", "story"] else Color("9fd0ff"))

	func _draw_salt_cart() -> void:
		# 断轴木车：白盐袋与散落账页构成固定主线识别点。
		draw_colored_polygon(PackedVector2Array([
			Vector2(-52, -42), Vector2(42, -42), Vector2(36, -17), Vector2(-46, -17)]),
			Color("5b402b"))
		draw_rect(Rect2(-46, -64, 82, 30), Color("a37a4b"))
		draw_rect(Rect2(-48, -67, 86, 6), Color("d1a969"))
		for wheel_x in [-32.0, 28.0]:
			draw_circle(Vector2(wheel_x, -16), 13, Color("3e2f27"))
			draw_circle(Vector2(wheel_x, -16), 8, Color("966e42"))
			draw_circle(Vector2(wheel_x, -16), 3, Color("d8bd85"))
		draw_line(Vector2(40, -44), Vector2(62, -30), Color("694b32"), 6)
		draw_line(Vector2(66, -27), Vector2(79, -19), Color("694b32"), 6)
		for sack_x in [-30.0, -5.0, 20.0]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(sack_x - 13, -68), Vector2(sack_x - 11, -90),
				Vector2(sack_x + 9, -94), Vector2(sack_x + 15, -67)]), Color("e0d1aa"))
			draw_line(Vector2(sack_x - 10, -70), Vector2(sack_x + 13, -70),
				Color("9f8a66"), 2)
		draw_rect(Rect2(7, -72, 18, 15), Color("e3c486"))
		draw_line(Vector2(10, -66), Vector2(23, -66), Color("547079"), 2)

	func _draw_fishing() -> void:
		draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.4, 0.48))
		draw_circle(Vector2.ZERO, 34, Color("4d8a94"))
		draw_arc(Vector2.ZERO, 23 + sin(_t * 2) * 3, 0, TAU, 24, Color("b3d5d0"), 2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_line(Vector2(-26, 3), Vector2(-9, -46), Color("ad8350"), 4)
		draw_line(Vector2(-9, -46), Vector2(14, -17), Color("ddd3b6"), 1)
		draw_circle(Vector2(14, -15 + sin(_t * 3)), 4, Color("dd6e4c"))
		draw_rect(Rect2(-37, 5, 25, 12), Color("705738"))

	func _draw_tide_cargo() -> void:
		# 水浸的木箱，白盐结晶与蓝色潮印提示调查目标。
		draw_rect(Rect2(-49, -58, 98, 42), Color("665541"))
		draw_rect(Rect2(-45, -65, 90, 13), Color("a9875e"))
		for x in [-34.0, 0.0, 34.0]:
			draw_line(Vector2(x, -60), Vector2(x + 6, -19), Color("3e352d"), 4)
		draw_circle(Vector2(0, -42), 11, Color("4b7984"))
		draw_line(Vector2(-8, -41), Vector2(7, -41), Color("b5d6d0"), 3)
		for p in [Vector2(-55, -16), Vector2(52, -12), Vector2(28, -7)]:
			draw_circle(p, 5, Color("e2e8d9", 0.86))

	## 旧路石匣：有石质基座与金属封边，区别于野外普通掉落包。
	func _draw_cache() -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-27, -8), Vector2(-20, -22), Vector2(22, -22), Vector2(27, -8),
			Vector2(20, 2), Vector2(-20, 2)]), Color("6d6557"))
		draw_rect(Rect2(-22, -28, 44, 19), Color("8b795f"))
		draw_rect(Rect2(-22, -28, 44, 4), Color("c2a36e"))
		draw_rect(Rect2(-22, -11, 44, 4), Color("4e4338"))
		draw_rect(Rect2(-4, -25, 8, 14), Color("c89a4c"))
		draw_circle(Vector2(0, -18), 2.0, Color("49301b"))

	## 旧风铃：枯枝上挂一只旧铜铃，轻摆
	func _draw_chime() -> void:
		var sway := sin(_t * 2.4) * 2.5
		draw_line(Vector2(-16, -44), Vector2(14, -38), Color("6e4c2c"), 4.0)   # 枯枝
		draw_line(Vector2(0, -41), Vector2(0, -30), Color("8a6a44"), 2.0)      # 挂绳
		draw_set_transform(Vector2(sway, 0), 0.0, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -30), Vector2(8, -30),
			Vector2(11, -12), Vector2(-11, -12)]), Color("b8925a"))            # 铃身
		draw_rect(Rect2(-11, -14, 22, 3), Color("8a6a44"))                     # 铃口
		draw_line(Vector2(0, -11), Vector2(0, -5), Color("6a4a26"), 2.0)       # 铃舌
		draw_circle(Vector2(0, -4), 3.0, Color("8a6a44"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## 草根：土块上露出的草叶与根须
	func _draw_root() -> void:
		draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, 17.0, Color("6b4a28"))                       # 土块
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 3:
			var a := -PI * 0.5 + (float(i) - 1.0) * 0.42
			draw_line(Vector2(0, -2), Vector2(0, -2) + Vector2(cos(a), sin(a)) * 20.0,
				Color("7fae5a"), 3.0)                                          # 草叶
		draw_line(Vector2(-6, 3), Vector2(-13, 11), Color("8a6a44"), 2.0)      # 根须
		draw_line(Vector2(5, 3), Vector2(12, 11), Color("8a6a44"), 2.0)

	## 足迹：两对爪印斜向排开（观察用，不消失于地面杂质）
	func _draw_tracks() -> void:
		for i in 2:
			_paw(Vector2(-13.0 + float(i) * 26.0, -6.0 + float(i) * 13.0))

	func _paw(c: Vector2) -> void:
		draw_circle(c, 5.0, Color("6f6858"))                                   # 掌垫
		for j in 3:
			var a := -PI * 0.5 + (float(j) - 1.0) * 0.5
			draw_circle(c + Vector2(cos(a), sin(a)) * 8.5, 2.2, Color("6f6858"))  # 趾

	## 驿亭：柱、顶与招幡（送达点）
	func _draw_post() -> void:
		draw_rect(Rect2(-3, -46, 6, 50), Color("6e4c2c"))                      # 亭柱
		draw_colored_polygon(PackedVector2Array([Vector2(-30, -46), Vector2(30, -46),
			Vector2(22, -58), Vector2(-22, -58)]), Color("5a3a1a"))            # 亭顶
		draw_rect(Rect2(2, -40, 14, 22), Color("c9b490"))                      # 招幡
		draw_rect(Rect2(2, -40, 14, 4), Color("8a6a44"))


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
		# 世界出口（P01 样板 §3）：北门／南道的木牌常在本屏外，小地图上补一枚绿菱指方向，
		# 于是「出生点或主街任一位置都能看见至少一块出口点」。封着的出口画成灰菱。
		var exits: Variant = map_ref._main_cfg.get("exits", [])
		if exits is Array:
			for row_v in exits:
				if not (row_v is Dictionary):
					continue
				var row := row_v as Dictionary
				var at_arr: Variant = row.get("at", [])
				if not (at_arr is Array) or (at_arr as Array).size() < 2:
					continue
				var ep: Vector2 = at.call(Vector2(float(at_arr[0]), float(at_arr[1])))
				var col := Color("9fe06a")
				var req := String(row.get("requires_story", ""))
				if not req.is_empty() and not G.story_step_done(req):
					col = Color("8f8f8a")
				draw_colored_polygon([ep + Vector2(0, -5.0), ep + Vector2(4.0, 0),
					ep + Vector2(0, 5.0), ep + Vector2(-4.0, 0)], col)
		# 目标物件（金菱）
		if map_ref._interactable != null and not map_ref._interactable.used:
			var ip: Vector2 = at.call(map_ref._interactable.position)
			draw_colored_polygon([ip + Vector2(0, -4.5), ip + Vector2(3.6, 0), ip + Vector2(-3.6, 0)],
				Color("ffd980"))
		# 追踪支线的野外实体（蓝菱）：与主线金标区分，一眼知道该往哪采／去哪交（P05-B）
		for qp_v in map_ref._tracked_side_points():
			var qp: Vector2 = at.call(qp_v)
			draw_colored_polygon([qp + Vector2(0, -4.5), qp + Vector2(3.6, 0),
				qp + Vector2(0, 4.5), qp + Vector2(-3.6, 0)], Color("9fd0ff"))
		# 未拾取的拾取物（金点=钱袋 / 淡青=魂晶）：与地面光斑同色，指路用
		for p in map_ref._pickups:
			if p.used:
				continue
			_pt(at.call(p.position), 2.6, Color("ffe9a8") if p.kind == "coin" else Color("9fe0f0"))
		# 兴趣点：紫菱=祭坛（花金重摇祝福）· 灰点=矿脉（材料）
		# 注意别用 s 当循环名：本函数上面已经有一个 s = 地图缩放比（同名会直接编译失败）
		for spot in map_ref._spots:
			if spot.used:
				continue
			var sp: Vector2 = at.call(spot.position)
			if spot.kind == "altar":
				draw_colored_polygon([sp + Vector2(0, -4.5), sp + Vector2(3.6, 0),
					sp + Vector2(0, 4.5), sp + Vector2(-3.6, 0)], Color("c9a0ff"))
			else:
				_pt(sp, 2.4, Color("cfd6e0"))
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
