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
const DirectionalIdle := preload("res://src/world/DirectionalIdle.gd")
const WorldPropArt := preload("res://src/world/WorldPropArt.gd")
const WorldArtFinish := preload("res://src/world/WorldArtFinish.gd")
const HudStyle := preload("res://src/ui/WorldHUD.gd")
const Cartography := preload("res://src/explore/MinimapCartography.gd")
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
const FourthActGroundScript := preload("res://src/explore/FourthActGround.gd")
const ReturnJourneyPropsScript := preload("res://src/explore/ReturnJourneyProps.gd")
const MINI_W := 104.0         # 留出舆图标题与展开提示，地图内容仍按世界比例居中。
const MINI_H := 136.0
const _MiniMapPos := Vector2(360, 16)
# HUD 常驻小钮（药 / 换宠 / 撤离 / 疾行）统一口径（C8）：同一高度、同一字号档，
# 宽度按字数给足（PanelContainer 会被文字撑大，给窄了彼此压边或出屏），右缘与小地图右缘对齐。
const HUD_BTN_H := 44.0         # P01 样板 §4：命中区最小 44×44（原 40 达不到触控下限）
const HUD_BTN_FS := 16          # = G.FS_SM，HUD 小钮一律这一档，不再混用 FS_MD
const HUD_BTN_Y := 144.0        # 与左侧 HP 面板（136..192）纵向居中，三枚并排钮统一基线
const HUD_BTN_RIGHT := 464.0    # = _MiniMapPos.x + MINI_W（右上角小地图右缘）
const AUTO_TIMEOUT := 26.0    # 自动前往超时（秒）：到不了就交还控制权，不把玩家困住
const FLEE_CONTACT_CD := 1.6  # 战斗撤退后的接触冷静期（秒）：防"刚退又被同一只怪拽回去"
const StoryBeatScript := preload("res://src/ui/StoryBeat.gd")   # 首领剧情演出层（对峙/余韵）
const RoadMailPanelScript := preload("res://src/ui/RoadMailPanel.gd")
const RoadMailServiceScript := preload("res://src/world/RoadMailService.gd")
const WorldPuzzlePanelScript := preload("res://src/ui/WorldPuzzlePanel.gd")
const MountVisual := preload("res://src/world/MountVisual.gd")
const Oaths := preload("res://src/world/OathService.gd")
const Contracts := preload("res://src/world/TradeContracts.gd")
const RunEvents := preload("res://src/run/RunEvents.gd")
const Trials := preload("res://src/world/DungeonTrial.gd")
const SpecialEvents := preload("res://src/world/SpecialEventService.gd")
const SpecialPanel := preload("res://src/ui/SpecialEventPanel.gd")
var _special_panel: Control = null
var _special_battle_id := ""
var _special_battle_token := ""
var _last_battle_trial := false
var _trial_saved_potions := -1
const ExplorationLinks := preload("res://src/world/ExplorationLinks.gd")
var _terrain_trace: Node2D = null
var _exploration_seen := {}
var _oath_trip := ""
var _oath_traveler: Node2D = null
const FirstActWeaponVisual := preload("res://src/world/FirstActWeaponVisual.gd")

var st: RunState
var node: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _deco_rng := RandomNumberGenerator.new()
const FlatGround := preload("res://src/explore/FlatMapGround.gd")
const GroundLayout := preload("res://src/explore/FlatGroundLayout.gd")
var _flat_ground: Node2D = null

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
var _stele_room_gates: Dictionary = {}            # 失声碑窟内部两道可恢复的实体门
var _tidal_room_gates: Dictionary = {}            # 退潮水闸的隔水门，随闸态拆除
var _tidal_water_bounds: Array[StaticBody2D] = [] # 两侧深水有实体边界，不能绕闸游过去
var _tidal_ground: TidalGateGround = null
var _mine_room_gates: Dictionary = {}
var _mine_ground: Node2D = null
var _interactable: _Interactable = null   # 非战斗节点物件（宝箱/事件/商店/篝火）
var _remover: Control = null              # 篝火词条删除浮层
var _exit_ui: Control = null              # 撤离确认浮层
var _trade_panel: TradePanel = null        # P06 野外驿点现货/订单
var _road_mail_panel: Control = null       # 通关后归路邮驿
var _puzzle_panel: Control = null          # 带线索的两选一机关
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
var _main_gold_chip: Button = null
var _main_story_l: Label = null
var _main_side_l: Label = null
var _side_chip: Control = null
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
var _arrival_exit_blocks: Dictionary = {}
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
var _journey_panel: Control = null
var _big_map: Control = null         # 大地图浮层（含图例与返回按钮）
var _sprint := false
var _mount_hoof_timer := 0.0
var _last_battle_pets: Array = []
var _auto_walk := false
var _auto_time := 0.0                # 自动前往累计时长（超时自停，防止绕过点卡死）
var _auto_stuck := 0.0
var _auto_dodge := 0.0
var _auto_dodge_side := 1.0
var _auto_fail := 0                  # 连续卡住计数：绕行多次无效即停手（P1-14）
var _prev_pos := Vector2.ZERO
var _prog := {}                      # 本节点探索进度（RunState.map_progress 的引用；P0-1）
var _feedback_frame:=-1
var _feedback_player_pos:=Vector2.INF
var _feedback_focus:Node2D=null


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
	Audio.play_ambience(_ambient_region())
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
	_deco_rng.seed = hash("ground_art_%s" % _main_map_id)
	_prog = st.map_progress(int(node.get("layer", 1)), int(node.get("index", 0)))
	if _mode == "main_world": _oath_trip = Oaths.enter(G,_main_map_id)
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
			_refresh_quest_entities.call_deferred()
	_refresh_explore_hud()   # 恢复的探索分/击杀数要在 HUD 上显出来
	if _mode == "main_world":
		var campaign_note := G.take_campaign_note()
		if not campaign_note.is_empty(): _toast(campaign_note)


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


func _uses_flat_ground() -> bool:
	return _mode != "main_world" or String(_main_cfg.get("ground_style", "")) == "flat"


func _build_ground() -> void:
	if _uses_flat_ground():
		if _mode != "main_world":
			# Consume the old floor rolls so existing expedition encounter seeds stay unchanged.
			for i in int(_map_cfg.get("map_cols", 32)) * int(_map_cfg.get("map_rows", 42)):
				_rng.randf()
		return  # The complete flat floor is built together with its visible routes below.
	if _mode == "main_world" and not String(_main_cfg.get("background", "")).is_empty():
		var path := String(_main_cfg.get("background", ""))
		var tex: Texture2D = G.visual_texture(path) if path != "" else null
		if tex == null:
			push_error("主世界背景缺失：%s" % path)
		else:
			var bg := TextureRect.new()
			bg.z_index = -20
			bg.texture = tex
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bg.modulate = _ground_tint()
			bg.size = Vector2(int(_map_cfg.get("map_cols", 32)) * 48,
				int(_map_cfg.get("map_rows", 42)) * 48)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(bg)
			if _main_map_id == "shenyuan_port":
				var harbor_state := PortGround.new()
				harbor_state.use_reference_ground = true
				add_child(harbor_state)
			return
	# 地面层：TileMapLayer 程序构建（主题 3 种 tile 加权平铺，无碰撞）
	var tl := TileMapLayer.new()
	tl.z_index = -20
	var ts := TileSet.new()
	ts.tile_size = Vector2i(48, 48)
	var tiles: Array = _theme_cfg.get("tiles", [])
	var asset_dir := _map_asset_dir
	var weights := [0.6, 0.2, 0.2]
	for i in mini(3, tiles.size()):
		var src := TileSetAtlasSource.new()
		src.texture = G.visual_texture("%s/%s.png" % [asset_dir, String(tiles[i])])
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
	if _mode == "main_world":
		var routes: Array = _main_cfg.get("flat_routes", [])
		_ground_path = GroundLayout.clearance(routes, cols, rows)
		if _uses_flat_ground():
			_add_flat_ground(cols, rows, routes)
		return
	if _uses_flat_ground():
		var legacy_path := _path_cells(cols, rows)
		var legacy_road: Array = []
		if String(_theme_cfg.get("path_sheet", "")).is_empty():
			for cell: Vector2i in legacy_path:
				legacy_road.append(Vector2(cell.x * 48 + 24, cell.y * 48 + 24))
		# Preserve the old random sequence for props, encounters and saved expeditions.
		# This temporary helper is never added to the scene: no old road or circular stains render.
		var legacy_wear := _GroundWear.new()
		legacy_wear.setup(cols, rows, _rng, legacy_path, legacy_road, Color("6b5334"))
		legacy_wear.free()
		var routes := GroundLayout.expedition_routes(legacy_path, cols, rows)
		_ground_path = GroundLayout.clearance(routes, cols, rows)
		_add_flat_ground(cols, rows, routes)
		return
	if _mode == "main_world" and bool(_main_cfg.get("authored_ground", false)):
		return
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
		var tex: Texture2D = G.visual_texture("%s/%s.png" % [asset_dir, sheet])
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


func _add_flat_ground(cols: int, rows: int, routes: Array) -> void:
	_flat_ground = FlatGround.new()
	_flat_ground.name = "FlatGround"
	_flat_ground.setup(Vector2(cols * 48, rows * 48), routes,
		FlatGround.palette_for(st.theme, _main_cfg), hash(_main_map_id) if _mode == "main_world" else st.run_seed,
		FlatGround.material_for(st.theme, _main_cfg), Color(String(_main_cfg.get("surface_tint", "ffffff"))))
	add_child(_flat_ground)


func _add_ground_overlay(ground: Node2D) -> void:
	ground.z_index = -10
	if _uses_flat_ground(): ground.set("flat_floor", true)
	add_child(ground)


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
	if _mode == "main_world" and _main_map_id == "stele_cavern":
		_add_ground_overlay(preload("res://src/explore/SteleRoomGround.gd").new())
	elif _mode == "main_world" and _main_map_id == "old_salt_road":
		_add_ground_overlay(SaltRoadGround.new())
	elif _mode == "main_world" and _main_map_id == "tideflat":
		_add_ground_overlay(TideflatGround.new())
	elif _mode == "main_world" and _main_map_id == "shenyuan_port" and _uses_flat_ground():
		_add_ground_overlay(PortGround.new())
	elif _mode == "main_world" and _main_map_id == "tidal_gate":
		_tidal_ground = TidalGateGround.new()
		_tidal_ground.dynamic_water = _tidal_rooms_enabled()
		_tidal_ground.upper_released = bool(G.prog.get("flags", {}).get("act2_tide_gate_1", false))
		_tidal_ground.bridge_drained = bool(G.prog.get("flags", {}).get("act2_tide_gate_2", false))
		_tidal_ground.passages = _tidal_passages()
		_add_ground_overlay(_tidal_ground)
	elif _mode == "main_world" and _main_map_id in ["red_sand_route", "frost_post", "rift_mine_road", "rift_mine_vault", "frost_boardwalk", "frost_pass"]:
		var ground := ThirdActGroundScript.new()
		ground.map_id = _main_map_id
		ground.use_reference_ground = _main_map_id == "frost_post" and not String(_main_cfg.get("background", "")).is_empty()
		_add_ground_overlay(ground)
	elif _mode == "main_world" and _main_map_id in ["stele_entry", "stele_resonance", "stele_core"]:
		var ground := FourthActGroundScript.new()
		ground.map_id = _main_map_id
		_add_ground_overlay(ground)

	_world.y_sort_enabled = true
	if _mode=="main_world" and _main_map_id=="maple_road":
		var bridge:=preload("res://src/explore/AftermathBridge.gd").new()
		bridge.z_index=-8
		_world.add_child(bridge)
	if _mode=="main_world" and _main_map_id in ["maple_road","old_salt_road","tideflat","frost_boardwalk","frost_post","stele_core"]:
		var return_props:=ReturnJourneyPropsScript.new()
		return_props.map_id=_main_map_id
		return_props.y_sort_enabled=true
		_world.add_child(return_props)
	add_child(_world)

	_build_decos(cols, rows)
	_build_portal(map_w)
	if _mode == "main_world":
		_build_world_exits()
		_build_world_blockers()
		_build_stele_room_gates()
		_build_tidal_water_bounds()
		_build_tidal_room_gates()
		_build_mine_rooms()
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
	var decos: Array = _main_cfg.get("decos", _theme_cfg.get("decos", [])) \
		if _mode == "main_world" else _theme_cfg.get("decos", [])
	if decos.is_empty():
		return
	var density := float(_main_cfg.get("deco_density", _theme_cfg.get("deco_density", 0.05)))
	var art_rng := _deco_rng if _mode == "main_world" else _rng
	var asset_dir := _map_asset_dir
	var tint := Color(String(_main_cfg.get("deco_tint", "ffffff"))) if _mode == "main_world" else _ground_tint()
	# 出生安全圈（P01 样板 §3）：按**本图真实出生点**避让 150px，不再用「地图底部中央」的估算点——
	# 估算点与 main_world_maps.json 的 spawn 差着上百像素，出生点旁边仍可能长出树。
	var spawn := _cfg_point(_main_cfg.get("spawn", []), Vector2.ZERO) if _mode == "main_world" \
		else Vector2(float(cols) * 24.0, float(rows) * 48.0 - 100.0)
	if spawn == Vector2.ZERO:
		spawn = Vector2(float(cols) * 24.0, float(rows) * 48.0 - 100.0)
	for gy in rows - 1:
		for gx in cols:
			if _mode == "main_world" and _ground_path.has(Vector2i(gx, gy)):
				continue  # 主路会游走出中央 5 列，凡路面格一律不落散件（P01：主路成带且不被树堵死）
			var center_col := absi(gx - cols / 2) <= 1  # 中央通道密度略降（0.65），保证通行但不显秃
			var d := density * (0.65 if center_col else 1.0)
			if art_rng.randf() > d:
				continue
			var pos := Vector2(gx * 48.0 + art_rng.randf_range(8, 40),
				gy * 48.0 + art_rng.randf_range(8, 40))
			if pos.distance_to(spawn) < 150.0 or pos.y < 200.0:
				continue
			var tex: Texture2D = load("%s/%s.png" % [asset_dir, String(decos[art_rng.randi_range(0, decos.size() - 1)])])
			var sc := art_rng.randf_range(0.85, 1.18)
			# 散件基座是**实体碰撞**（40×s × 26 @ y=−13）：格位避让还不够——散件在格内随机偏到
			# 右下角时，碰撞盒会溢进相邻的路面格，走路时被树根绊住（可走性实测里表现为「反复卡住」）。
			# 这里按碰撞盒真实覆盖的格再筛一遍（RNG 次序不变，故散件布局只少了压路的那几株）。
			if _foot_hits_road(pos, sc):
				continue
			if _mode == "main_world" and _foot_hits_patrol(pos, sc):
				continue
			var deco := _Deco.new()
			deco.setup(tex, sc)
			deco.modulate = tint
			deco.position = pos
			_world.add_child(deco)


## 散件脚部碰撞盒是否压到本图主路格（_ground_path）。盒：40×s 宽 × 26 高，底边在原点、中心上移 13。
func _foot_hits_road(pos: Vector2, s: float) -> bool:
	var footprint := Rect2(pos - Vector2(20.0 * s, 26), Vector2(40.0 * s, 26)).grow(18)
	for row: Dictionary in (_main_cfg.get("entities", {}) as Dictionary).values():
		var at := _cfg_point(row.get("at", []), Vector2(-1000, -1000))
		if footprint.intersects(Rect2(at - Vector2(58, 86), Vector2(116, 120))): return true
	for rect_v in (_main_cfg.get("clear_rects", []) as Array):
		if rect_v is Array and (rect_v as Array).size() == 4:
			var r: Array = rect_v
			if footprint.intersects(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))):
				return true
	if _ground_path.is_empty():
		return false
	for gy in range(floori(footprint.position.y / 48.0), floori(footprint.end.y / 48.0) + 1):
		for gx in range(floori(footprint.position.x / 48.0), floori(footprint.end.x / 48.0) + 1):
			if _ground_path.has(Vector2i(gx, gy)):
				return true
	return false


## 明雷巡逻与接触范围不能被随机岩石占住，否则敌人会卡在岩石边，角色无法接近。
## 保留散件原布局和随机顺序，仅剔除压住配置巡逻范围的实体基座。
func _foot_hits_patrol(pos: Vector2, scale_factor: float) -> bool:
	var footprint := Rect2(pos-Vector2(20.0*scale_factor,26),Vector2(40.0*scale_factor,26)).grow(18)
	var radius := float(_main_cfg.get("monster_wander_radius",0)) + float(_main_cfg.get("monster_contact_radius",40))
	for point in (_main_cfg.get("monster_positions",[]) as Array):
		var center := _cfg_point(point,Vector2.ZERO)
		if center.distance_to(center.clamp(footprint.position,footprint.end)) <= radius: return true
	return false

func _build_portal(map_w: float) -> void:
	_portal = _Portal.new()
	_portal.position = _cfg_point(_main_cfg.get("exit", []), Vector2(map_w / 2.0, 120.0)) \
		if _mode == "main_world" else Vector2(map_w / 2.0, 120.0)
	_portal.locked = String(node.get("type", "normal")) == "boss"
	_world.add_child(_portal)
	_portal.visible = _mode != "main_world"


## 世界图谱出口是道路指示牌；历练传送阵继续只服务随机节点。
func _build_world_blockers() -> void:
	for rect_v in (_main_cfg.get("block_rects", []) as Array):
		if not (rect_v is Array) or (rect_v as Array).size() != 4: continue
		var row: Array = rect_v
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = Vector2(float(row[0]) + float(row[2]) / 2, float(row[1]) + float(row[3]) / 2)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(float(row[2]), float(row[3]))
		var collider := CollisionShape2D.new()
		collider.shape = shape
		body.add_child(collider)
		_world.add_child(body)


func _stele_rooms_enabled() -> bool:
	return _mode == "main_world" and _main_map_id == "stele_cavern" and \
		(bool(G.prog.get("flags", {}).get("act1_stele_rooms_v1", false)) or \
		String(G.story_current().get("id", "")) == "s09")


func _stele_room_one_ready() -> bool:
	var flags: Dictionary = G.prog.get("flags", {})
	for key in ["act1_stele_clue", "act1_echo_crack_left", "act1_echo_crack_middle",
			"act1_echo_crack_right"]:
		if not bool(flags.get(key, false)): return false
	return true


func _build_stele_room_gates() -> void:
	if not _stele_rooms_enabled(): return
	if not _stele_room_one_ready():
		var first := _SteleRoomGate.new()
		first.position = Vector2(480, 755)
		first.caption = "听清三处石缝，再读青姨拓片"
		_world.add_child(first)
		_stele_room_gates["echo"] = first
	if not bool(G.prog.get("flags", {}).get("act1_stele_seat_2", false)):
		var second := _SteleRoomGate.new()
		second.position = Vector2(480, 540)
		second.caption = "两枚碑座未归位"
		_world.add_child(second)
		_stele_room_gates["heart"] = second


func _sync_stele_room_gates() -> void:
	if not _stele_rooms_enabled(): return
	if _stele_room_one_ready() and _stele_room_gates.has("echo"):
		(_stele_room_gates["echo"] as Node).queue_free()
		_stele_room_gates.erase("echo")
	if bool(G.prog.get("flags", {}).get("act1_stele_seat_2", false)) and \
			_stele_room_gates.has("heart"):
		(_stele_room_gates["heart"] as Node).queue_free()
		_stele_room_gates.erase("heart")
	_mark_nav_dirty()


func _tidal_rooms_enabled() -> bool:
	return _mode == "main_world" and _main_map_id == "tidal_gate" and \
		(bool(G.prog.get("flags", {}).get("act2_tidal_rooms_v1", false)) or \
		String(G.story_current().get("id", "")) == "s18")


func _mine_rooms_enabled() -> bool:
	return _mode == "main_world" and _main_map_id == "rift_mine_vault" and \
		bool(G.prog.get("flags", {}).get("act3_mine_rooms_v1", false))


func _build_mine_rooms() -> void:
	if not _mine_rooms_enabled(): return
	_mine_ground = preload("res://src/explore/MineRoomGround.gd").new()
	_mine_ground.z_index = -9
	_mine_ground.flat_floor = _uses_flat_ground()
	_world.add_child(_mine_ground)
	var rooms: Dictionary = _main_cfg.get("rooms", {})
	for key in rooms:
		var row: Dictionary = rooms[key]
		if bool(G.prog.get("flags", {}).get(String(row.get("open_flag", "")), false)): continue
		var gate := _SteleRoomGate.new()
		gate.position = _cfg_point(row.get("gate_at", []), Vector2.ZERO)
		gate.caption = String(row.get("hint", "先处理前房机关"))
		_world.add_child(gate)
		_mine_room_gates[key] = gate
	_sync_mine_rooms()


func _sync_mine_rooms() -> void:
	if not _mine_rooms_enabled(): return
	var flags: Dictionary = G.prog.get("flags", {})
	var rooms: Dictionary = _main_cfg.get("rooms", {})
	for key in _mine_room_gates.keys():
		if bool(flags.get(String(rooms.get(key, {}).get("open_flag", "")), false)):
			(_mine_room_gates[key] as Node).queue_free()
			_mine_room_gates.erase(key)
	if _mine_ground != null:
		_mine_ground.set("ventilated", bool(flags.get("act3_mine_second_wind", false)))
		_mine_ground.set("rescued", bool(flags.get("act3_mine_switch", false)))
		_mine_ground.queue_redraw()
	_mark_nav_dirty()


func _tidal_passages() -> String:
	var flags: Dictionary = G.prog.get("flags", {})
	if not bool(flags.get("act2_tide_gate_2", false)):
		return "sealed"
	var bridge := bool(flags.get("act2_tide_bridge_open", false))
	var cargo := bool(flags.get("act2_tide_cargo_saved", false))
	if bridge and cargo: return "both"
	if bridge: return "bridge"
	if cargo: return "cargo"
	return "both"  # 旧档已校准侧闸，但没有路线旗：保留原可走区域。


func _build_tidal_water_bounds() -> void:
	if not _tidal_rooms_enabled(): return
	for bounds in [Rect2(0, 0, 330, 1248), Rect2(630, 0, 330, 1248)]:
		var body := StaticBody2D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = bounds.get_center()
		var collider := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = bounds.size
		collider.shape = rect
		body.add_child(collider)
		_world.add_child(body)
		_tidal_water_bounds.append(body)


func _build_tidal_room_gates() -> void:
	if not _tidal_rooms_enabled(): return
	var flags: Dictionary = G.prog.get("flags", {})
	if not bool(flags.get("act2_tide_clue", false)):
		var record_gate := _TidalRoomGate.new()
		record_gate.position = Vector2(480, 770)
		record_gate.caption = "先读港务水痕，再进上闸"
		_world.add_child(record_gate)
		_tidal_room_gates["record"] = record_gate
	var priest_gate := _TidalRoomGate.new()
	priest_gate.position = Vector2(480, 475)
	priest_gate.caption = "排清栈桥侧闸积水"
	priest_gate.route = _tidal_passages()
	_world.add_child(priest_gate)
	_tidal_room_gates["priest"] = priest_gate


func _sync_tidal_room_gates() -> void:
	if not _tidal_rooms_enabled(): return
	var flags: Dictionary = G.prog.get("flags", {})
	if bool(flags.get("act2_tide_clue", false)) and _tidal_room_gates.has("record"):
		(_tidal_room_gates["record"] as Node).queue_free()
		_tidal_room_gates.erase("record")
	if _tidal_room_gates.has("priest"):
		(_tidal_room_gates["priest"] as _TidalRoomGate).set_route(_tidal_passages())
	if _tidal_ground != null:
		_tidal_ground.upper_released = bool(flags.get("act2_tide_gate_1", false))
		_tidal_ground.bridge_drained = bool(flags.get("act2_tide_gate_2", false))
		_tidal_ground.passages = _tidal_passages()
		_tidal_ground.queue_redraw()
	_mark_nav_dirty()


func _world_exit_sign_position(row: Dictionary) -> Vector2:
	var at := _cfg_point(row.get("at",[]),Vector2.ZERO)
	if at.y < 180.0: at.y = 240.0
	return at

func _world_exit_touch_rect(row: Dictionary) -> Rect2:
	# Sign art is 92x96 above its anchor. Enter near its middle, with player clearance.
	return Rect2(_world_exit_sign_position(row) + Vector2(-52,-84),Vector2(104,88))

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
		marker.position = _world_exit_sign_position(row)
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
	if _mode == "main_world":
		for exit_row: Dictionary in _main_cfg.get("exits",[]):
			if _world_exit_touch_rect(exit_row).has_point(spawn):
				_arrival_exit_blocks[String(exit_row.get("id",""))] = true
	_player.collision_layer = 1
	_player.collision_mask = 2
	_world.add_child(_player)

	_player_anim = AnimatedSprite2D.new()
	var frames_path := String(ROLE_FRAMES.get(st.role_id, ROLE_FRAMES["zs"])[0])
	_player_anim.sprite_frames = load(frames_path)
	_player_anim.material = WorldArtFinish.character_material(st.role_id)
	# 历练保留旧比例；主地图单独校准人物占屏，不靠放大整张草地底图。
	# 帧中心在 y=64，脚底 y=120，脚点偏移按旧比例校准，避免放大后脚底与碰撞点分离。
	var player_scale := float(_main_cfg.get("player_scale", 0.96)) if _mode == "main_world" else 0.72
	_player_anim.scale = Vector2.ONE * player_scale
	_player_anim.position = Vector2(0, 21.0 - 56.0 * player_scale)
	_player_anim.animation = &"walk_down"
	DirectionalIdle.stop(_player_anim)
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
		tag_style.set_corner_radius_all(0)
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
		_player_name_l = G.gold_label("", 14, false, Color("f1ffe9"), false)
		_player_name_l.add_theme_font_override("font",G.font_display)
		_player_name_l.add_theme_font_size_override("font_size",12)
		_player_name_l.position = Vector2(5, 1)
		_player_name_l.size = Vector2(130, 22)
		_player_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_player_name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_player_name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_player_tag.add_child(_player_name_l)
		_player_marker = Polygon2D.new()
		_player_marker.polygon = PackedVector2Array([
			Vector2(0, -7), Vector2(5, 0), Vector2(0, 8), Vector2(-5, 0)])
		_player_marker.color = Color("e54651")
		_player_marker.position = Vector2(0, name_y - 19.0)
		_player.add_child(_player_marker)
		_player_marker_gleam = Polygon2D.new()
		_player_marker_gleam.polygon = PackedVector2Array([
			Vector2(0, -5), Vector2(3, -1), Vector2(-2, 0)])
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
	if is_instance_valid(_terrain_trace): _terrain_trace.queue_free()
	_terrain_trace=null
	var terrain:=ExplorationLinks.trait_for(G.mount_active(),_main_map_id)
	if riding and not terrain.is_empty():
		var trail:=ExplorationLinks.Trail.new()
		trail.area=Rect2(terrain.rect[0],terrain.rect[1],terrain.rect[2],terrain.rect[3])
		trail.z_index=0
		_world.add_child(trail)
		_terrain_trace=trail
		if not _exploration_seen.has("terrain"):
			_exploration_seen.terrain=true
			_toast(String(terrain.line))
	var bear := riding and G.mount_active()=="bear"
	_mount_anim.sprite_frames=MountVisual.frames_for(st.role_id,"bear" if bear else "horse")
	_mount_anim.scale=Vector2.ONE*(.31 if bear else .34)
	_mount_anim.visible = riding
	_player_anim.visible = true
	_player_anim.z_index=1 if riding else 0
	var player_scale:=float(_main_cfg.get("player_scale",.96))
	_player_anim.scale=Vector2.ONE*(.38 if riding else player_scale)
	_player_anim.position=Vector2(0,MountVisual.rider_offset(G.mount_active(),String(_mount_anim.animation)) if riding else 21.0-56.0*player_scale)
	_mount_anim.position=MountVisual.mount_offset(G.mount_active(),String(_mount_anim.animation))
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
		_mount_btn.visible = G.mount_active() in ["horse","bear"] and G.mount_tier(G.mount_active()) > 0
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
	var trained := CompanionService.snapshot(G.prog,pid)
	if not trained.is_empty():
		var marks: Array = []
		for tid in trained: marks.append(String(trained[tid].name))
		var badge := G.gold_label(" · ".join(marks),G.FS_XS,true,G.C_COMPANION,true)
		badge.position = Vector2(-70,-83)
		badge.size = Vector2(140,20)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pet_follower.add_child(badge)


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
	_build_road_mail_ambush()
	_build_stele_shadow()


func _stele_shadow_resolved() -> bool:
	var flags: Dictionary = G.prog.get("flags", {})
	return bool(flags.get("act1_stele_shadow_avoided", false)) or \
		bool(flags.get("act1_stele_shadow_defeated", false))


func _build_stele_shadow() -> void:
	if not _stele_rooms_enabled() or _main_boss_cleared(): return
	var flags: Dictionary = G.prog.get("flags", {})
	if not bool(flags.get("act1_stele_shadow_challenged", false)) or \
			bool(flags.get("act1_stele_shadow_defeated", false)):
		return
	for existing in _monsters:
		if existing.idx == 3000: return
	var slot := {"idx": 3000, "tier": "normal", "mon_id": "mon_ghost",
		"position": Vector2(430, 570), "level_offset": 0,
		"wander_radius": 18.0, "contact_radius": 36.0}
	_main_spawn_slots.append(slot)
	_spawn_monster(slot)


func _road_mail_ambush_idx() -> int:
	return 2000 + int(G.road_mail_state().get("run_seq", 0))


func _build_road_mail_ambush() -> void:
	if _mode != "main_world" or _main_map_id != "red_sand_route":
		return
	var mail := G.road_mail_state()
	if String(mail.get("status", "")) != "active" or \
			String(mail.get("phase", "")) != "hazard" or String(mail.get("route", "")) != "quick":
		return
	var slot := {"idx": _road_mail_ambush_idx(), "tier": "normal",
		"mon_id": "mon_scorp", "position": Vector2(410, 860),
		"level_offset": 0, "wander_radius": 20.0, "contact_radius": 40.0}
	_main_spawn_slots.append(slot)
	_spawn_monster(slot)


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
		var required := String(o.get("requires_story", ""))
		if not required.is_empty() and not G.story_step_done(required):
			idx += 1
			continue
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
			"level": int(o.get("level", 0)),
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
		if MonsterArt.has(m.mon_id):
			m.sprite_path = MonsterArt.path(m.mon_id)
		m.contact_radius = float(slot.get("contact_radius", 0.0))
		m.wander_radius = float(slot.get("wander_radius", 0.0))
	m.display_level = CampaignGrowth.enemy_level(_main_map_id, slot,
		st.level + int(slot.get("level_offset", _main_cfg.get("monster_level_offset", 2)))) \
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
	var status := HudStyle.status(_main_hp_fill, _main_exp_fill)
	_hud.add_child(status.root)
	_main_level_l = status.level
	_main_hp_l = status.hp
	_main_exp_l = status.exp
	var currency := HudStyle.currency()
	var gold_chip: Button = currency.root
	_main_gold_chip = gold_chip
	gold_chip.pressed.connect(func():
		if not G.ui_blocked:
			G.show_info_popup(gold_chip, "行囊与货币", G.wallet_info_lines()))
	_hud.add_child(gold_chip)
	_main_gold_l = currency.value
	_hud.add_child(HudStyle.region_title(String(_main_cfg.get("name", "昭元边城"))))


func _build_hud() -> void:
	_hud.layer = 1
	add_child(_hud)
	_build_vignette()  # 最先入层：只在画面四周压暗，不遮住下方的 HUD 控件
	if _mode == "main_world":
		_build_main_world_status()
		var story := HudStyle.task_chip(336, "story")
		var story_chip: Button = story.root
		var task_y := HudStyle.CITY_TASK_Y if bool(_main_cfg.get("city", false)) else HudStyle.FIELD_TASK_Y
		story_chip.position = Vector2(16, task_y)
		story_chip.tooltip_text = "点击查看主线目标与奖励"
		story_chip.pressed.connect(func():
			if not G.ui_blocked:
				_open_story_info(story_chip))
		_main_story_l = story.label
		_hud.add_child(story_chip)

		var side := HudStyle.task_chip(336, "side")
		var side_button: Button = side.root
		_side_chip = side_button
		_side_chip.position = Vector2(16, task_y + HudStyle.TASK_GAP)
		_side_chip.tooltip_text = "点击查看当前追踪的支线"
		side_button.pressed.connect(func():
			if not G.ui_blocked:
				var special_goal := SpecialEvents.goal(G)
				if not special_goal.is_empty():
					G.show_info_popup(_side_chip,"追踪奇遇",[special_goal,"到标记的地点继续，谢礼在复命时领取。"],self)
				else: G.show_info_popup(_side_chip, "追踪支线", G.side_info_lines(), self))
		_main_side_l = side.label
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
	# 目标小签：深色半透明底托（切角 + 内凹光），避免压在地图上不可读
	var goal_chip := G.InsetPanel.new()
	goal_chip.setup(Color(0.13, 0.09, 0.05, 0.62), Color("ffd9a0", 0.20),
		10.0, 10.0, 3.0, 3.0)
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
		var exp_chip := G.InsetPanel.new()
		exp_chip.setup(Color(0.13, 0.09, 0.05, 0.62), Color("c8e0a0", 0.20),
			10.0, 10.0, 2.0, 2.0)
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
		var badge := G.PixelButton.new()
		badge.position = Vector2(35, -3)
		badge.custom_minimum_size = Vector2(19, 17)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 数量角标：切角小牌（凸起 + 硬影），弃用圆角8的"药丸"
		badge.set_content_margin(2.0)
		var bsb := badge.get_theme_stylebox("panel") as StyleBoxFlat
		bsb.content_margin_top = 0.0   # 竖直留白保持 0，13px 字不压
		bsb.content_margin_bottom = 0.0
		badge.set_surface(Color("142d2b"), G.GOLD)
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
	preload("res://src/ui/UiSafeArea.gd").fit_hud(_hud,G.ui_safe_rect(self),get_viewport_rect())
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
	hit.set_meta("visual_family",{"药剂":"market","伙伴":"garden","疾行":"atlas","营帐":"journal"}.get(caption,"journal"))
	hit.tooltip_text = hint
	hit.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			action.call())
	holder.add_child(hit)
	if icon_key.is_empty():
		var mark := G.gold_label("»", 27, true, G.GOLD_BRIGHT, false)
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
		var cap := G.serif_label(caption, G.FS_XS, G.GOLD_BRIGHT)
		cap.position = Vector2(0, 32)
		cap.size = Vector2(width, 18)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(cap)
	return holder


func _sync_campaign_level() -> void:
	if _mode != "main_world": return
	var level := int(G.prog.get("level", st.level))
	var bonus := G.growth_bonuses(st.role_id)
	if level <= st.level and bonus == st.growth_bonus: return
	var old_max := st.max_hp()
	st.level = maxi(st.level, level)
	st.growth_bonus = bonus
	if st.hp > 0: st.hp = clampi(st.hp + st.max_hp() - old_max, 1, st.max_hp())


func _refresh_hud() -> void:
	if _mode != "main_world" and not st.run_id.is_empty(): _checkpoint_run.call_deferred()
	_sync_campaign_level()
	var m := st.max_hp()
	var hp := m if st.hp < 0 else st.hp
	_hp_fill.size.x = 116.0 * clampf(float(hp) / float(m), 0.0, 1.0)
	if _mode == "main_world" and _main_level_l != null:
		var lv := int(G.prog.get("level", st.level))
		var exp := int(G.prog.get("exp", 0))
		var need := G.exp_to_next(lv)
		var exp_ratio := 1.0 if need <= 0 else clampf(float(exp) / float(need), 0.0, 1.0)
		_main_level_l.text = "Lv%d" % lv
		HudStyle.progress(_main_hp_fill, float(hp) / float(maxi(m, 1)))
		HudStyle.progress(_main_exp_fill, exp_ratio)
		_main_hp_fill.color = Color("e99978") if float(hp) / float(maxi(m, 1)) <= 0.3 else Color("92cbaa")
		_main_hp_l.text = "%d/%d" % [hp, m]
		_main_hp_l.tooltip_text = "生命 %d / %d" % [hp, m]
		_main_exp_l.text = "%d%%" % roundi(exp_ratio * 100.0)
		if _main_gold_l != null:
			HudStyle.update_currency(_main_gold_l, int(G.wallet.get("gold", 0)))
			_main_gold_chip.tooltip_text = "金币 %d · 点击查看全部货币" % int(G.wallet.get("gold", 0))
		if _main_story_l != null:
			HudStyle.update_task(_main_story_l, G.story_goal_short())
			_main_story_l.get_parent().tooltip_text = G.story_goal_short() + " · 查看目标与奖励"
		if _side_chip != null:
			var side_text := G.side_line()
			var commissions := WorldCommission.entities(G, _main_map_id)
			if not commissions.is_empty(): side_text = "委托 · " + String(commissions[0].name)
			var special_goal := SpecialEvents.goal(G)
			if not special_goal.is_empty(): side_text = "奇遇 · " + special_goal
			_side_chip.visible = not side_text.is_empty()
			HudStyle.update_task(_main_side_l, side_text)
			_side_chip.tooltip_text = side_text + " · 查看追踪支线"
		if _player_name_l != null:
			_player_name_l.text = "%s  Lv%d" % [G.display_name(), lv]
			var name_width := G.font_display.get_string_size(_player_name_l.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var tag_width := clampf(name_width + 16.0, 88.0, 180.0)
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
	if _mode=="main_world" and Trials.no_potions(G,_main_map_id):
		_toast("无药轮岗：本次副本内不能使用药剂；可结束挑战后正常补给")
		return
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
	var before_run := st.snapshot()
	st.potions -= 1
	var pct := float(TableCache.nodes_config().get("shop", {}).get("potion_heal_pct", 0.35))
	var oath_mult := float(Oaths.objective(G,_oath_trip).get("potion_mult",1.0)) if _mode=="main_world" else 1.0
	var amt := int(float(m) * pct * oath_mult)
	st.heal(amt)
	if not _checkpoint_run():
		st.restore(before_run)
		_prog=st.map_progress(int(node.get("layer",1)),int(node.get("index",0)))
		_refresh_hud()
		return
	_toast("使用药剂：回复 %d 点生命" % amt)
	_refresh_hud()


func _swap_pet() -> void:
	if _battle != null or _map_done or st.bench_pet == "":
		return
	var before_run := st.snapshot()
	var old := st.active_pet
	st.active_pet = st.bench_pet
	st.bench_pet = old
	if not _checkpoint_run():
		st.restore(before_run)
		_prog=st.map_progress(int(node.get("layer",1)),int(node.get("index",0)))
		return
	_sync_world_companion()
	_toast("出战宠物已更换")
	_refresh_hud()


func _toast(msg: String) -> void:
	if _toast_lbl != null and not _toast_lbl.is_queued_for_deletion():
		_toast_lbl.queue_free()
	_toast_lbl = G.toast_label(msg)
	_toast_lbl.position = Vector2(24, 560)
	_hud.add_child(_toast_lbl)
	G.reveal_control(_toast_lbl)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast_lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_toast_lbl.queue_free)


# ================= 词条三选一 =================
func _show_trait_picker(rows: Array) -> void:
	_prog["pending_choices"] = rows.duplicate(true)
	_prog["pending_trait_picks"] = _pending_trait_picks
	_picker = TraitPicker.new()
	_picker.setup(rows)
	_picker.picked.connect(_on_trait_picked)
	_hud.add_child(_picker)  # HUD 同层最后添加，盖住其余 HUD
	_checkpoint_run()


func _on_trait_picked(tid: String) -> void:
	if not _prog.has("pending_choices"):return
	if not tid.is_empty() and not (_prog.pending_choices as Array).any(func(row):return String(row.get("id",""))==tid):return
	var before_run:=st.snapshot()
	var choices:Array=_prog.get("pending_choices",[]).duplicate(true)
	_prog.erase("pending_choices")
	_picker = null
	if tid != "":
		st.traits.append(tid)
	if not _checkpoint_run():
		st.restore(before_run)
		_prog=st.map_progress(int(node.get("layer",1)),int(node.get("index",0)))
		_show_trait_picker.call_deferred(choices)
		return
	if tid != "":
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
	if it.used or G.save_locked: return
	if it.kind == "event":
		_open_run_event(it)
		return
	var before_run := st.snapshot()
	var before_rng := _rng.state
	it.used = true
	match it.kind:
		"chest":
			Audio.sfx("coin")
			var before_gold:=st.gold
			var before_currency:=st.expedition
			st.add_reward("chest")
			_toast("宝箱开启：金币 +%d · 远征币 +%d" % [st.gold-before_gold,st.expedition-before_currency])
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
			it.queue_free()
	_prog["interact_done"] = true   # 一次性物件记档：重进不再生成（P0-1）
	if not _checkpoint_run():
		st.restore(before_run)
		_rng.state = before_rng
		_prog = st.map_progress(int(node.get("layer", 1)), int(node.get("index", 0)))
		_interactable = null
		_build_interactable(float(_map_cfg.get("map_cols",32))*48, float(_map_cfg.get("map_rows",42))*48)
		_refresh_hud()
		return
	_interactable = null
	if it.kind == "bonfire" and not st.traits.is_empty(): _show_trait_remove()


func _open_run_event(it: _Interactable) -> void:
	if _puzzle_panel != null: return
	it.used = true
	_puzzle_panel = WorldPuzzlePanelScript.new()
	_hud.add_child(_puzzle_panel)
	_puzzle_panel.open_puzzle(RunEvents.row(st.theme))
	_puzzle_panel.choice_selected.connect(func(choice: String):
		var before_run := st.snapshot()
		var before_rng := _rng.state
		var result := RunEvents.apply(st, _prog, choice)
		if not bool(result.ok):
			_toast(String(result.get("message", "此选择当前不可用")))
			return
		if not _checkpoint_run():
			st.restore(before_run)
			_rng.state = before_rng
			_prog = st.map_progress(int(node.get("layer",1)),int(node.get("index",0)))
			return
		Audio.sfx("reward")
		_refresh_hud()
		it.queue_free()
		_interactable = null
		_toast("已休整，继续前行" if choice == "rest" else "所得记入本局报酬与补给，继续前行"))
	_puzzle_panel.closed.connect(func():
		_puzzle_panel = null
		if is_instance_valid(it) and not bool(_prog.get("interact_done", false)):
			it.used = false
			it.contact_cd = 1.0)


## 支线实体生成（P05-B）：表在 main_world_maps.json 的 entities；
## 生成与否完全由任务状态决定（未接不出现、采过/可交付/完成后不再出现）。
func _refresh_quest_entities() -> void:
	_feedback_frame=-1
	_feedback_focus=null
	var special_cooldowns:Dictionary={}
	for entity in _quest_entities:
		if is_instance_valid(entity):
			if not entity.special_event_id.is_empty() and entity.trade_cooled:
				special_cooldowns[entity.eid]=entity.position
			entity.queue_free()
	_quest_entities.clear()
	_build_quest_entities()
	for entity in _quest_entities:
		if special_cooldowns.get(entity.eid,Vector2.INF)==entity.position: entity.trade_cooled=true


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
		if String(row.get("kind", "")) == "feedback":
			if G.side_status_of(quest) != QuestService.SIDE_DONE: continue
			var prop := _QuestEntity.new()
			prop.eid = eid
			prop.kind = "feedback"
			prop.used = true
			prop.art = String(row.get("art", "post"))
			prop.caption = String(row.get("name", ""))
			prop.position = _cfg_point(row.get("at", []), Vector2.ZERO)
			prop.map_ref=self
			_world.add_child(prop)
			_quest_entities.append(prop)
			continue
		if String(row.get("kind", "")) == "road_mail" and not G.road_mail_entity_visible(eid):
			continue
		if String(row.get("kind", "")) == "shipping_aid" and not G.shipping_aid_visible(
				String(row.get("shipping_id", "")), eid):
			continue
		if String(row.get("kind", "")) == "frost_herb_route" and not G.frost_herb_route_visible(eid):
			continue
		if String(row.get("kind", "")) == "first_order_bridge" and not G.first_order_bridge_visible(eid):
			continue
		if String(row.get("kind", "")) in ["puzzle", "puzzle_choice"]:
			var required := String(row.get("requires_story", ""))
			if not required.is_empty() and not G.story_step_done(required): continue
			if eid == "act1_echo_west" and _stele_rooms_enabled() and not _stele_room_one_ready():
				continue
			if eid == "act1_echo_shadow" and not _stele_rooms_enabled(): continue
			if eid == "act1_echo_east" and _stele_rooms_enabled() and not _stele_shadow_resolved():
				continue
			if bool(G.prog.get("flags", {}).get(String(row.get("flag", "")), false)) \
				or WorldSession.entity_taken(_main_world_state(), eid): continue
		var flags_ready := true
		for key in row.get("requires_flags", []):
			if not bool(G.prog.get("flags", {}).get(String(key), false)): flags_ready = false
		if not flags_ready: continue
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
		ent.mail_action = String(row.get("mail_action", ""))
		ent.shipping_id = String(row.get("shipping_id", ""))
		ent.story_event_kind = String(row.get("story_event", "collect"))
		ent.art = String(row.get("art", "root"))
		ent.caption = String(row.get("name", ""))
		ent.position = _cfg_point(row.get("at", []), Vector2.ZERO)
		ent.map_ref = self
		_quest_entities.append(ent)
		_world.add_child(ent)
	_build_commission_entities()
	_build_special_event_entities()
	_mark_nav_dirty()


func _build_special_event_entities() -> void:
	for entry in SpecialEvents.entities(G,_main_map_id):
		var entity := _QuestEntity.new()
		entity.eid = "special|"+String(entry.id)+("|feedback" if bool(entry.feedback) else "|"+String(entry.point.map))
		entity.special_event_id = String(entry.id)
		entity.kind = "feedback" if bool(entry.feedback) else "special_event"
		entity.used = bool(entry.feedback)
		entity.art = String(entry.point.art)
		entity.caption = String(entry.name)
		entity.position = _cfg_point(entry.point.at,Vector2.ZERO)
		entity.map_ref = self
		_world.add_child(entity)
		_quest_entities.append(entity)


func _build_commission_entities() -> void:
	if is_instance_valid(_oath_traveler): _oath_traveler.queue_free()
	_oath_traveler=null
	var trust_script := preload("res://src/world/RegionalTrust.gd")
	var region := String(trust_script.CITIES.get(_main_map_id,""))
	if not region.is_empty() and int(trust_script.info(G,region).tier)>0:
		var prop := _QuestEntity.new()
		prop.used = true
		prop.kind = "feedback"
		prop.art = "trust_"+region
		prop.feedback_tier=int(trust_script.info(G,region).tier)
		prop.caption = {"zhaoyuan":"路簿灯架 · 留有你的名字", "shenyuan":"港务旧潮线纸", "frost":"轮岗簿的新一页"}[region]
		prop.position = {"zhaoyuan":Vector2(580,730),"shenyuan":Vector2(610,720),"frost":Vector2(580,1010)}[region]
		prop.map_ref=self
		_world.add_child(prop)
		_quest_entities.append(prop)
	for m in _monsters.duplicate():
		if (not m.commission_posting.is_empty() or not m.oath_trip.is_empty() or m.trial) and m != _contact_mon:
			_monsters.erase(m)
			m.queue_free()
	_build_trial_entities()
	_build_contract_entities()
	if String(Oaths.trip(G,_oath_trip).get("status",""))=="active":
		var oath := Oaths.objective(G,_oath_trip)
		var at := _cfg_point(_main_cfg.get("spawn",[]),Vector2(480,1000))+Vector2(0,-180)
		if String(oath.action)=="defeat" and not (_main_cfg.get("monster_ids",[]) as Array).is_empty():
			_spawn_monster({"idx":800000000+absi(_oath_trip.hash()),"tier":"normal",
				"mon_id":String(TableCache.theme_config(st.theme).get("monsters",["mon_wolf"])[0]),"position":at,"contact_radius":38.0,"wander_radius":32.0})
			_monsters.back().oath_trip=_oath_trip
		else:
			var target := _QuestEntity.new()
			target.kind="oath"
			target.art=String(oath.art)
			target.caption="誓约 · "+String(oath.target)
			target.position=at
			if String(oath.id)=="shelter":
				if int(Oaths.trip(G,_oath_trip).get("phase",0))==0:
					target.caption="誓约 · 接应路边旅人"
				else:
					target.caption="誓约 · 旅人抵达安全点"
					target.position+=Vector2(0,-240)
					var traveler:=_OathTraveler.new()
					traveler.map_ref=self
					traveler.position=_player.position
					_world.add_child(traveler)
					_oath_traveler=traveler
			target.map_ref=self
			_world.add_child(target)
			_quest_entities.append(target)
	for step in WorldCommission.entities(G, _main_map_id):
		if String(step.kind) == "defeat":
			_spawn_monster({"idx":900000000 + absi(String(step.posting).hash()),
				"tier":"normal", "mon_id":String(step.enemy), "position":_cfg_point(step.at,Vector2.ZERO),
				"contact_radius":38.0, "wander_radius":40.0})
			_monsters.back().commission_posting = String(step.posting)
			continue
		var ent := _QuestEntity.new()
		ent.eid = String(step.id)
		ent.commission_posting = String(step.posting)
		ent.kind = "world_commission"
		ent.art = String(step.art)
		ent.caption = "委托 · " + String(step.name)
		ent.position = _cfg_point(step.at, Vector2.ZERO)
		ent.map_ref = self
		_quest_entities.append(ent)
		_world.add_child(ent)

func _commission_interact(e: _QuestEntity) -> void:
	var step := WorldCommission.current(WorldCommission.state(G).get(e.commission_posting,{}))
	if not (step.get("choices",{}) as Dictionary).is_empty():
		if _puzzle_panel != null or e.trade_cooled: return
		e.trade_cooled = true
		_puzzle_panel = WorldPuzzlePanelScript.new()
		_hud.add_child(_puzzle_panel)
		_puzzle_panel.open_puzzle(step)
		_puzzle_panel.choice_selected.connect(func(choice:String):
			var res := WorldCommission.action(G,e.commission_posting,_main_map_id,e.eid,choice)
			_toast(String(res.line))
			if bool(res.ok):
				e.used = true
				_refresh_quest_entities.call_deferred()
			_refresh_hud())
		_puzzle_panel.closed.connect(func(): _puzzle_panel = null)
		return
	var res := WorldCommission.action(G,e.commission_posting,_main_map_id,e.eid)
	_toast(String(res.line))
	if bool(res.ok):
		e.used = true
		_refresh_quest_entities.call_deferred()
	else: e.trade_cooled = true
	_refresh_hud()

func _build_contract_entities() -> void:
	for id in Contracts.state(G):
		var record:Dictionary=Contracts.state(G)[id]
		if String(record.status)!="active" or bool(record.aid):continue
		var definition:=Contracts.row(String(record.template))
		if String(definition.route_map)!=_main_map_id:continue
		var entity:=_QuestEntity.new()
		entity.eid="contract_"+String(id)
		entity.contract_id=String(id)
		entity.kind="trade_contract"
		entity.art="post"
		entity.caption=String(definition.route_name)
		entity.position=_cfg_point(definition.at,Vector2.ZERO)
		entity.map_ref=self
		_world.add_child(entity)
		_quest_entities.append(entity)


func _build_trial_entities()->void:
	if not Trials.unlocked(G,_main_map_id):return
	var board:=_QuestEntity.new()
	board.eid="trial_board"
	board.kind="trial_board"
	board.art="post"
	board.caption="首通后挑战 · "+String(Trials.row(_main_map_id).name)
	board.position=_cfg_point(_main_cfg.get("spawn",[]),Vector2(480,1050))+Vector2(120,-115)
	board.map_ref=self
	_world.add_child(board)
	_quest_entities.append(board)
	var step:=Trials.current(G,_main_map_id)
	if step.is_empty():return
	if String(step.kind)=="defeat":
		_spawn_monster({"idx":700000000+absi(("%s|%d"%[_main_map_id,int(Trials.record(G,_main_map_id).attempt)]).hash()),
			"tier":"boss","mon_id":String(step.enemy),"position":_cfg_point(step.at,Vector2.ZERO),"optional":true})
		_monsters.back().trial=true
		return
	var entity:=_QuestEntity.new()
	entity.eid=String(step.id)
	entity.kind="trial"
	entity.art=String(step.art)
	entity.caption="挑战 · "+String(step.name)
	entity.position=_cfg_point(step.at,Vector2.ZERO)
	entity.map_ref=self
	_world.add_child(entity)
	_quest_entities.append(entity)

func _trial_interact(e:_QuestEntity)->void:
	if e.trade_cooled:return
	var board:=e.kind=="trial_board"
	var step:=Trials.current(G,_main_map_id)
	var choice:=board or not (step.get("choices",{}) as Dictionary).is_empty()
	if choice:
		if _puzzle_panel!=null:return
		e.trade_cooled=true
		_puzzle_panel=WorldPuzzlePanelScript.new()
		_hud.add_child(_puzzle_panel)
		var display:Dictionary=step.duplicate(true)
		if board:
			var definition:=Trials.row(_main_map_id)
			display={"name":String(definition.name),"clue":String(definition.desc),"choices":{"begin":"继续挑战" if not step.is_empty() else "开始附加挑战","abort":"结束本次挑战"}}
		_puzzle_panel.open_puzzle(display)
		_puzzle_panel.choice_selected.connect(func(selected:String):
			var result:=Trials.choose(G,_main_map_id,selected) if board else Trials.advance(G,_main_map_id,e.eid,selected)
			_toast(String(result.line))
			if bool(result.ok):
				e.used=true
				_refresh_quest_entities.call_deferred()
			_refresh_hud())
		_puzzle_panel.closed.connect(func():_puzzle_panel=null)
		return
	var result:=Trials.advance(G,_main_map_id,e.eid)
	_toast(String(result.line))
	if bool(result.ok):
		e.used=true
		_refresh_quest_entities.call_deferred()
	else:e.trade_cooled=true
	_refresh_hud()


## 支线实体交互（P05-B）：采集/观察/送达。成功推进即从地图消失，提示走 toast。
func on_quest_entity(e: _QuestEntity) -> void:
	if _map_done or _battle != null or e.used or _modal_open(): return
	if e.kind=="special_event":
		if not e.trade_cooled:
			e.trade_cooled=true
			_show_special_event(SpecialEvents.presentation(G,e.special_event_id,_main_map_id))
		return
	if e.kind in ["trial","trial_board"]:
		_trial_interact(e)
		return
	if e.kind == "oath":
		if e.trade_cooled: return
		var shelter := String(Oaths.objective(G,_oath_trip).get("id",""))=="shelter"
		var start_escort := shelter and int(Oaths.trip(G,_oath_trip).get("phase",0))==0
		if shelter and not start_escort and is_instance_valid(_oath_traveler) and _oath_traveler.position.distance_to(e.position)>140:
			_toast("等旅人也抵达路灯旁再确认")
			return
		var res := Oaths.begin_escort(G,_oath_trip) if start_escort else Oaths.finish(G,_oath_trip)
		_toast(String(res.line))
		if bool(res.ok):
			e.used=true
			_refresh_quest_entities.call_deferred()
		else: e.trade_cooled=true
		_refresh_hud()
		return
	if e.kind == "trade_contract":
		if e.trade_cooled:return
		var value:=Contracts.action(G,e.contract_id,"aid")
		_toast(String(value.line))
		e.trade_cooled=true
		if bool(value.ok):_refresh_quest_entities.call_deferred()
		return
	if e.kind == "world_commission":
		if not e.trade_cooled: _commission_interact(e)
		return
	if not e.quest.is_empty():
		var row := QuestService.side_row(G.side_quest_rows(), e.quest)
		var step := QuestService.side_objective(row, QuestService.side_get(G.act1_state(), e.quest))
		if not (step.get("choices", {}) as Dictionary).is_empty():
			_open_side_choice(e, step)
			return
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
	if e.kind == "road_mail":
		if e.mail_action == "board":
			_open_road_mail_panel()
			e.trade_cooled = true
			return
		if e.mail_action in ["quick", "safe"]:
			_open_road_mail_choice(e)
			e.trade_cooled = true
			return
		if e.mail_action == "safe_hazard":
			_open_road_mail_hazard(e)
			e.trade_cooled = true
			return
		var mail_result := G.road_mail_action(e.mail_action, _main_map_id)
		if not bool(mail_result.get("ok", false)):
			_toast("邮路状态未保存，请回驿站核对")
			return
		e.used = true
		e.queue_free()
		_toast(String(mail_result.get("line", "")))
		_refresh_quest_entities.call_deferred()
		_refresh_hud()
		return
	if e.kind == "shipping_aid":
		var aid_result := G.shipping_route_aid(e.shipping_id, _main_map_id, e.eid)
		if not bool(aid_result.get("ok", false)):
			_toast(String(aid_result.get("err", "船单路况未保存")))
			return
		e.used = true
		e.queue_free()
		_toast(String(aid_result.get("line", "")))
		_refresh_hud()
		return
	if e.kind == "frost_herb_route":
		var route_result := G.frost_herb_route(_main_map_id, e.eid)
		if not bool(route_result.get("ok", false)):
			_toast(String(route_result.get("err", "药箱路线未记录")))
			e.trade_cooled = true
			return
		e.used = true
		e.queue_free()
		_toast(String(route_result.get("line", "")))
		_refresh_quest_entities.call_deferred()
		_refresh_hud()
		return
	if e.kind == "first_order_bridge":
		var bridge_result := G.first_order_bridge(_main_map_id, e.eid)
		if not bool(bridge_result.get("ok", false)):
			_toast(String(bridge_result.get("err", "桥面处理未保存")))
			e.trade_cooled = true
			return
		e.used = true
		e.queue_free()
		_toast(String(bridge_result.get("line", "")))
		_refresh_quest_entities.call_deferred()
		_refresh_hud()
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
	if e.kind == "puzzle":
		var result := G.world_puzzle_interact(_main_map_id, e.eid)
		if not bool(result.get("ok", false)):
			_toast("机关尚未齐备" if String(result.get("reason", "")) == "locked" else "机关未保存，请稍后重试")
			return
		e.used = true
		e.queue_free()
		_sync_stele_room_gates()
		_sync_tidal_room_gates()
		_sync_mine_rooms()
		_mark_nav_dirty()
		_toast(String(result.get("line", "")))
		_refresh_hud()
		_refresh_quest_entities.call_deferred()
		return
	if e.kind == "puzzle_choice":
		_open_world_puzzle_panel(e)
		e.trade_cooled = true
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
	_refresh_quest_entities.call_deferred()


func _show_special_event(display: Dictionary) -> void:
	if _special_panel!=null or display.is_empty(): return
	var id := String(display.id)
	_special_panel = SpecialPanel.new()
	_hud.add_child(_special_panel)
	_special_panel.open_event(display)
	_special_panel.closed.connect(func(): _special_panel=null)
	_special_panel.action_selected.connect(func(choice: String):
		if choice=="battle":
			_special_panel.close()
			_start_special_battle(id)
			return
		var result := SpecialEvents.action(G,id,_main_map_id,choice)
		if not bool(result.get("ok",false)):
			_toast(String(result.get("line","这一步未保存，请重试。")))
			return
		_special_panel.close()
		_refresh_quest_entities.call_deferred()
		_refresh_hud()
		if String(SpecialEvents.record(G,id).get("phase",""))=="battle":
			_start_special_battle(id)
			return
		var summary := SpecialEvents.presentation(G,id,_main_map_id)
		summary["choices"]={}
		summary["body"]=String(result.line)+("\n\n下一步："+SpecialEvents.goal(G,id) if not SpecialEvents.goal(G,id).is_empty() else "\n\n"+String(SpecialEvents.row(id).note))
		_show_special_event(summary))


func _start_special_battle(id: String) -> void:
	if _battle!=null or _modal_open(): return
	var ally := {"role_id":st.role_id,"level":st.level,"traits":[],
		"active_pet":st.active_pet,"bench_pet":st.bench_pet,"potions":2,"hp_override":-1,
		"growth":G.growth_bonuses(st.role_id),"skill_levels":G.prog.get("skills",{}),
		"unlocked_skills":G.act1_unlocked_skills(st.role_id),"skill_variants":G.act1_skill_variants(st.role_id),
		"pet_stats":G.battle_pet_stats([st.active_pet,st.bench_pet])}
	var prepared := SpecialEvents.prepare_battle(G,id,_main_map_id,ally)
	if not bool(prepared.get("ok",false)):
		_toast(String(prepared.get("line","尚未开战，请重试。")))
		return
	_stop_auto_walk("")
	_special_battle_id=id
	_special_battle_token=String(prepared.battle.token)
	BattleScene.pending_cfg=(prepared.battle as Dictionary).duplicate(true)
	BattleScene.pending_cfg["region_floor_tint"]=_ground_tint().to_html(false)
	_world.visible=false
	_hud.visible=false
	_battle_layer=CanvasLayer.new()
	_battle_layer.layer=2
	add_child(_battle_layer)
	_battle=(load("res://src/battle/BattleScene.tscn") as PackedScene).instantiate()
	_battle.battle_finished.connect(_on_special_battle_end)
	_battle_layer.add_child(_battle)


func _on_special_battle_end(result: String, _hp_left: int) -> void:
	if _special_battle_id.is_empty(): return
	var outcome := SpecialEvents.resolve_battle(G,_special_battle_id,_main_map_id,_special_battle_token,result)
	_battle=null
	_battle_layer.queue_free()
	_battle_layer=null
	_world.visible=true
	_hud.visible=true
	Audio.play_bgm("bgm_map")
	Audio.play_ambience(_ambient_region())
	_restore_after_battle()
	_refresh_quest_entities.call_deferred()
	_refresh_hud()
	var display := SpecialEvents.presentation(G,_special_battle_id,_main_map_id)
	display["choices"]={}
	display["body"]=String(outcome.line)+"\n\n下一步："+SpecialEvents.goal(G,_special_battle_id)
	_show_special_event(display)
	_special_battle_id=""
	_special_battle_token=""


func _open_side_choice(e: _QuestEntity, step: Dictionary) -> void:
	if _puzzle_panel != null or e.trade_cooled: return
	e.trade_cooled = true
	_puzzle_panel = WorldPuzzlePanelScript.new()
	_hud.add_child(_puzzle_panel)
	var display := step.duplicate(true)
	display["name"] = e.caption
	_puzzle_panel.open_puzzle(display)
	_puzzle_panel.choice_selected.connect(func(choice: String):
		var result := G.side_entity_interact(e.kind, e.eid, _main_map_id, e.quest, choice)
		if bool(result.get("ok", false)):
			e.used = true
			for line in result.get("toasts", []): _toast(String(line))
			_refresh_quest_entities.call_deferred()
			_refresh_hud()
		else:
			_toast(String(result.get("line", "操作未保存，请稍后重试"))))
	_puzzle_panel.closed.connect(func(): _puzzle_panel = null)


## 追踪支线在当前地图的实体坐标（P05-B 小地图蓝菱用）。
func _tracked_side_points() -> Array:
	var out: Array = []
	var special_id := SpecialEvents.tracked(G)
	if not special_id.is_empty():
		var target := SpecialEvents.objective(G,special_id)
		if String(target.get("map",""))==_main_map_id:
			return [_cfg_point(target.at,Vector2.ZERO)]
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
		var row := G.InsetPanel.new()
		row.custom_minimum_size = Vector2(0, 36)
		row.setup(Color("d8c8a0"), Color("b1a181"), 10.0, 10.0, 0.0, 0.0)
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
	var before_run:=st.snapshot()
	st.traits.erase(tid)
	if not _checkpoint_run():
		st.restore(before_run)
		_prog=st.map_progress(int(node.get("layer",1)),int(node.get("index",0)))
		return
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
	elif _journey_panel != null:
		_journey_panel.close()
		if vp != null: vp.set_input_as_handled()
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
		speed *= ExplorationLinks.speed_mult(G.mount_active(),_main_map_id,_player.position,true)
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
			_mount_anim.play(mount_dir)
			_player_anim.animation=mount_dir
			DirectionalIdle.stop(_player_anim)
			_player_anim.position.y=MountVisual.rider_offset(G.mount_active(),String(mount_dir))+sin(float(Time.get_ticks_msec())*.016)
			_mount_anim.position=MountVisual.mount_offset(G.mount_active(),String(mount_dir))
		else:
			_mount_anim.stop()
			_mount_anim.frame=1
		return
	if dir.length_squared() < 0.25:
		DirectionalIdle.stop(_player_anim)
		return
	var anim := &"walk_down"
	if absf(dir.x) > absf(dir.y):
		anim = &"walk_right" if dir.x > 0 else &"walk_left"
	else:
		anim = &"walk_down" if dir.y > 0 else &"walk_up"
	DirectionalIdle.change_walk_direction(_player_anim, anim)
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
	if _mode != "main_world" and not st.run_id.is_empty():
		if _prog.has("rng_state"): _rng.state = int(String(_prog.rng_state))
		if _prog.has("resume_position"): _player.position = _cfg_point(_prog.resume_position, _player.position)
		var pending: Array = _prog.get("pending_choices", [])
		_pending_trait_picks = int(_prog.get("pending_trait_picks", 0))
		if not pending.is_empty(): _show_trait_picker(pending)


func _checkpoint_run() -> bool:
	if _mode == "main_world" or st.run_id.is_empty() or _battle != null or _map_done: return true
	if st.finished: return true
	var active: Dictionary = G.prog.get("active_run", {})
	if String(active.get("state", {}).get("run_id", "")) != st.run_id: return true
	_prog["rng_state"] = str(_rng.state)
	_prog["pending_trait_picks"] = _pending_trait_picks
	if _player != null: _prog["resume_position"] = [roundi(_player.position.x), roundi(_player.position.y)]
	if not G.run_checkpoint(st, node):
		_toast("历练进度未保存，请检查存档后重试")
		return false
	return true


func on_spot(s: _Spot) -> void:
	if _map_done or _battle != null:
		return
	if s.kind == "vein":
		if G.save_locked: return
		var before_run := st.snapshot()
		var before_items := G.items.duplicate(true)
		var before_rng := _rng.state
		var items: Array = _cfg_range("vein_items", ["enhance_stone"])
		var am: Array = _cfg_range("vein_amount", [1, 2])
		var n := _rng.randi_range(int(am[0]), int(am[1]))
		var iid := String(items[_rng.randi_range(0, maxi(0, items.size() - 1))])
		G.grant_item(iid, n, false)
		Audio.sfx("pickup")
		_toast("采得矿脉：%s ×%d" % [G.item_name(iid), n])
		_add_score(_cfg_int("pickup_score", 6), "矿脉")
		# 进度落表：矿脉同样是一次性兴趣点，不记就会"撤离→重进"反复采（P0-1 漏网项）
		if not _prog["spots"].has(s.idx):
			_prog["spots"].append(s.idx)
		if not _checkpoint_run():
			G.items = before_items
			st.restore(before_run)
			_prog = st.map_progress(int(node.get("layer", 1)), int(node.get("index", 0)))
			_score = int(_prog.get("score", 0))
			_rng.state = before_rng
			return
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
	if G.save_locked or (s!=null and s.used):return
	if st.gold < cost:
		Audio.sfx("ui_locked")
		_toast("金币不足，碑灵沉默不语")
		return
	var before_run:=st.snapshot()
	var before_rng:=_rng.state
	st.gold -= cost
	Audio.sfx("altar")
	var choices := st.roll_trait_choices(_rng)
	if choices.is_empty():
		# 词条池已尽：全额退款且不熄灯（否则玩家钱退了、祭坛却永久用掉）
		_toast("碑灵无言——词条池已尽，金子退你了")
		st.gold += cost
		return
	if s!=null and not _prog["spots"].has(s.idx):_prog["spots"].append(s.idx)
	_prog["pending_choices"]=choices.duplicate(true)
	_add_score(_cfg_int("pickup_score", 6), "祭坛")
	if not _checkpoint_run():
		st.restore(before_run)
		_rng.state=before_rng
		_prog=st.map_progress(int(node.get("layer",1)),int(node.get("index",0)))
		_score=int(_prog.get("score",0))
		return
	_close_altar(s, true)   # 保存成功后才熄灯。
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
func on_pickup(p: _Pickup) -> bool:
	if _map_done or G.save_locked or not _pickups.has(p):return false
	var before_run:=st.snapshot()
	var before_rng:=_rng.state
	if not _prog["taken"].has(p.idx):
		_prog["taken"].append(p.idx)   # 进度落表：重进不再撒同一个（P0-1）
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
	if not _checkpoint_run():
		st.restore(before_run)
		_rng.state=before_rng
		_prog=st.map_progress(int(node.get("layer",1)),int(node.get("index",0)))
		_score=int(_prog.get("score",0))
		return false
	_pickups.erase(p)
	_mark_nav_dirty()   # 拾取物消失要立刻从地图上抹掉（问题 #15：节流不能让"点了没反应"）
	return true


# ================= 导航三件套（小地图 / 目标罗盘 / 疾行） =================
## 地图世界尺寸（像素）
func _map_extent() -> Vector2:
	return Vector2(float(int(_map_cfg.get("map_cols", 32))) * 48.0,
		float(int(_map_cfg.get("map_rows", 42))) * 48.0)


## 当前该去哪：优先未使用过的物件（宝箱/事件/商店/篝火），
## 传送阵被封印时先指向守阵首领，其余一律指向传送阵
func _closest_feedback()->Node2D:
	if _player==null:return null
	var frame:=Engine.get_physics_frames()
	if frame==_feedback_frame and _player.position==_feedback_player_pos:
		if _feedback_focus==null:return null
		if is_instance_valid(_feedback_focus) and not _feedback_focus.is_queued_for_deletion():return _feedback_focus
	_feedback_frame=frame
	_feedback_player_pos=_player.position
	_feedback_focus=null
	var closest:=140.0*140.0
	for entity in _quest_entities:
		if not is_instance_valid(entity) or entity.is_queued_for_deletion() or entity.kind!="feedback":continue
		var distance:=entity.position.distance_squared_to(_player.position)
		if distance<closest:
			closest=distance
			_feedback_focus=entity
	return _feedback_focus

func _nav_info() -> Dictionary:
	var special_id := SpecialEvents.tracked(G) if _mode=="main_world" else ""
	if not special_id.is_empty():
		var target := SpecialEvents.objective(G,special_id)
		if String(target.get("map",""))==_main_map_id:
			return {"name":"奇遇 · "+String(target.get("name",SpecialEvents.row(special_id).giver)),
				"pos":_cfg_point(target.at,Vector2.ZERO),"kind":"quest"}
	for entity in _quest_entities:
		if is_instance_valid(entity) and not entity.used and entity.kind=="trade_contract":return {"name":entity.caption,"pos":entity.position,"kind":"quest"}
		if is_instance_valid(entity) and not entity.used and entity.kind=="trial":return {"name":entity.caption,"pos":entity.position,"kind":"quest"}
	for m in _monsters:
		if m.trial:return {"name":"附加挑战 · 练习残影","pos":m.position,"kind":"monster"}
	for entity in _quest_entities:
		if is_instance_valid(entity) and not entity.used and not entity.commission_posting.is_empty():
			return {"name":entity.caption, "pos":entity.position, "kind":"quest"}
	for m in _monsters:
		if not m.commission_posting.is_empty():
			return {"name":"委托 · 守住岗火", "pos":m.position, "kind":"monster"}
	for entity in _quest_entities:
		if is_instance_valid(entity) and not entity.used and entity.kind=="oath":
			return {"name":entity.caption,"pos":entity.position,"kind":"quest"}
	for m in _monsters:
		if not m.oath_trip.is_empty():return {"name":"誓约 · 前哨","pos":m.position,"kind":"monster"}
	if _mine_rooms_enabled() and not _main_boss_cleared():
		for objective in ["act3_mine_record", "act3_mine_wheel", "act3_mine_second_wheel", "act3_mine_switch"]:
			for entity in _quest_entities:
				if is_instance_valid(entity) and not entity.used and entity.eid == objective:
					return {"name": entity.caption, "pos": entity.position, "kind": "puzzle"}
	if _stele_rooms_enabled() and not _main_boss_cleared():
		for objective in ["act1_echo_crack_left", "act1_echo_crack_middle",
				"act1_echo_crack_right", "act1_echo_rubbing", "act1_echo_west",
				"act1_echo_shadow", "act1_echo_east"]:
			for entity in _quest_entities:
				if is_instance_valid(entity) and not entity.used and entity.eid == objective:
					return {"name": entity.caption, "pos": entity.position, "kind": "puzzle"}
	if _tidal_rooms_enabled() and not _main_boss_cleared():
		for objective in ["act2_tide_record", "act2_tide_upper", "act2_tide_bridge",
				"act2_tide_rescue_cargo", "act2_tide_repair_bridge"]:
			for entity in _quest_entities:
				if is_instance_valid(entity) and not entity.used and entity.eid == objective:
					return {"name": entity.caption, "pos": entity.position, "kind": "puzzle"}
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
	if _mode=="main_world" and _player!=null and st!=null:
		var hint_key:=st.active_pet+"|"+_main_map_id
		if not _exploration_seen.has(hint_key) and _player.position.distance_to(info.get("pos",Vector2.ZERO))<300:
			var hint:=ExplorationLinks.pet_hint(G,st.active_pet,_main_map_id,String(info.get("kind","")))
			if not hint.is_empty():
				_exploration_seen[hint_key]=true
				_toast(hint)
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
		"金箭：你所在的位置 · 亮框：当前视野 · 铜线：道路",
		"青点：传送阵（封印时转紫）· 金菱：宝箱 / 事件 / 商队 / 篝火",
		"红点：敌影（视野内才会显形）· 亮点：散落的钱袋 / 魂晶（走近自动入袋）",
		"清光全图怪物有额外赏，走的越细、离开时的评价越高",
		"紫菱：碑灵祭坛（献金重摇一次祝福）· 灰点：矿脉（白拿养成材料）",
		"点下方「前 往」自动走到当前目标；再推摇杆即可接手",
	]
	if _mode == "main_world":
		lines = ["首次探索沿道路前进；已经去过的地点可乘驿车", "首次到访解锁落点，地图任务条件仍须满足", "携带商货、运单或护送途中请亲自走路"]
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
	if _mode == "main_world":
		go.position.y = 432
		back.position.y = 432
		var journey := G.gold_button("驿路与传世",316,44,G.FS_SM)
		journey.position = Vector2(24,484)
		journey.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_close_big_map()
				_open_journey())
		content.add_child(journey)


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
		var id := String(row.get("id",""))
		var touching := _world_exit_touch_rect(row).has_point(_player.position)
		# Arriving or resuming inside a sign does not immediately send the player back.
		if _arrival_exit_blocks.has(id):
			if not touching: _arrival_exit_blocks.erase(id)
			continue
		if not touching:
			continue
		var required := String(row.get("requires_story", ""))
		if not required.is_empty() and not G.story_step_done(required):
			_world_exit_cd = 2.0
			_toast(String(row.get("locked_hint", "前路尚未开放——先完成当前主线")))
			return
		var blocked := false
		for key in row.get("requires_flags", []):
			if not bool(G.prog.get("flags", {}).get(String(key), false)): blocked = true
		if blocked:
			_world_exit_cd = 2.0
			_toast(String(row.get("locked_hint", "先点亮本房的归路锚点")))
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
	var visited: Array = state.get("visited_maps", [])
	if not visited.has(_main_map_id): visited.append(_main_map_id)
	state["visited_maps"] = visited
	if _mine_rooms_enabled():
		state["room_id"] = "furnace" if bool(G.prog.get("flags", {}).get("act3_mine_switch", false)) else \
			("ventilation" if bool(G.prog.get("flags", {}).get("act3_mine_clue", false)) else "record")
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
	return _special_panel != null or _journey_panel != null or _battle != null or _map_done or _picker != null or _remover != null \
		or _big_map != null or _altar_ui != null or _exit_ui != null or _beat != null \
		or _trade_panel != null or _road_mail_panel != null or _puzzle_panel != null \
		or _fishing_panel != null \
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


func _open_road_mail_panel() -> void:
	if _road_mail_panel != null:
		return
	_road_mail_panel = RoadMailPanelScript.new()
	_hud.add_child(_road_mail_panel)
	_road_mail_panel.open_board()
	_road_mail_panel.action_requested.connect(func(action: String):
		var result := G.road_mail_action(action, _main_map_id)
		_toast(String(result.get("line", "")) if bool(result.get("ok", false)) else
			"邮驿未能保存这次操作，请稍后重试")
		if bool(result.get("ok", false)):
			_refresh_quest_entities.call_deferred()
			_refresh_hud())
	_road_mail_panel.closed.connect(func(): _road_mail_panel = null)


func _open_road_mail_choice(e: _QuestEntity) -> void:
	if _puzzle_panel != null:
		return
	var state := G.road_mail_state()
	var clues: Array = state.get("observed_clues", [])
	var choices := {"pass_supply": "付 18 金，请驿亭引路"}
	if "stone" in clues:
		choices = {"pass_observe": "照旧刻痕辨路 · 免费",
			"pass_supply": "付 18 金，请驿亭引路"}
	_puzzle_panel = WorldPuzzlePanelScript.new()
	_hud.add_child(_puzzle_panel)
	_puzzle_panel.open_puzzle({"name": "邮 路 · 风 口",
		"clue": "路标缺了一角。可以先查看附近风蚀石的旧刻痕，自己辨路；也可付 18 金请驿亭引路。两种办法都能把信送到。",
		"choices": choices})
	_puzzle_panel.choice_selected.connect(func(choice: String):
		var result := G.road_mail_action(choice, _main_map_id)
		_toast(String(result.get("line", "")) if bool(result.get("ok", false)) else
			"邮路未能结算；请核对金币与存档后重试")
		if bool(result.get("ok", false)):
			e.used = true
			e.queue_free()
			_build_road_mail_ambush()
			_refresh_quest_entities.call_deferred()
			_refresh_hud())
	_puzzle_panel.closed.connect(func(): _puzzle_panel = null)


func _open_road_mail_hazard(e: _QuestEntity) -> void:
	if _puzzle_panel != null:
		return
	_puzzle_panel = WorldPuzzlePanelScript.new()
	_hud.add_child(_puzzle_panel)
	_puzzle_panel.open_puzzle({"name": "邮 路 · 受 伤 信 使",
		"clue": "背风驿亭边有位信使扭伤了脚。付 12 金请驿亭包扎，可以按时送信；免费扶他慢行到港口，本趟报酬会少 20 金。",
		"choices": {"hazard_help": "付 12 金包扎 · 报酬不减",
			"hazard_escort": "扶他慢行 · 少 20 金"}})
	_puzzle_panel.choice_selected.connect(func(choice: String):
		var result := G.road_mail_action(choice, _main_map_id)
		_toast(String(result.get("line", "")) if bool(result.get("ok", false)) else
			"邮路未能结算；请核对金币与存档后重试")
		if bool(result.get("ok", false)):
			e.used = true
			e.queue_free()
			_refresh_quest_entities.call_deferred()
			_refresh_hud())
	_puzzle_panel.closed.connect(func(): _puzzle_panel = null)


func _open_world_puzzle_panel(e: _QuestEntity) -> void:
	if _puzzle_panel != null:
		return
	var row: Dictionary = _main_cfg.get("entities", {}).get(e.eid, {})
	_puzzle_panel = WorldPuzzlePanelScript.new()
	_hud.add_child(_puzzle_panel)
	_puzzle_panel.open_puzzle(row)
	_puzzle_panel.choice_selected.connect(func(choice: String):
		var result := G.world_puzzle_interact(_main_map_id, e.eid, choice)
		if not String(result.get("line", "")).is_empty():
			_toast(String(result.get("line", "")))
		elif not bool(result.get("ok", false)):
			_toast("机关未能保存，请稍后重试")
		if bool(result.get("ok", false)):
			e.used = true
			e.queue_free()
			_sync_stele_room_gates()
			_sync_tidal_room_gates()
			_sync_mine_rooms()
			_build_stele_shadow()
			_refresh_quest_entities.call_deferred()
			_refresh_hud())
	_puzzle_panel.closed.connect(func(): _puzzle_panel = null)


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
func _battle_reward_preview(m: _MapMonster) -> Dictionary:
	if m.trial: return {}
	if _mode=="main_world":
		if _main_map_id=="red_sand_route" and m.idx==_road_mail_ambush_idx(): return {}
		return (_main_cfg.get("battle_rewards",{}).get(m.tier,{}) as Dictionary).duplicate(true)
	var reward:Dictionary=TableCache.nodes_config().get("rewards",{}).get(m.tier,{}).duplicate(true)
	for key in reward: reward[key]=roundi(float(reward[key])*st.reward_mult())
	return reward


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
	var tide_boss := _mode == "main_world" and _main_map_id == "tidal_gate" and \
		m.mon_id == "mon_tide_priest"
	var tide_flags: Dictionary = G.prog.get("flags", {}) if tide_boss else {}
	var tide_route := ""
	if tide_boss:
		var bridge_open := bool(tide_flags.get("act2_tide_bridge_open", false))
		var cargo_saved := bool(tide_flags.get("act2_tide_cargo_saved", false))
		tide_route = "both" if bridge_open and cargo_saved else \
			"bridge" if bridge_open else "cargo" if cargo_saved else "legacy"
	var tide_preclear := tide_boss and not G.story_step_done("s19")
	var tide_supply := tide_preclear and (bool(tide_flags.get("act2_tide_bridge_supply_claimed", false)) \
		or bool(tide_flags.get("act2_tide_cargo_supply_claimed", false)))
	var tide_break := tide_preclear and tide_route == "both"
	var battle_potions := mini(G.run_potions_max(), st.potions + (1 if tide_supply else 0)) \
		if tide_boss else st.potions
	_trial_saved_potions=-1
	if m.trial and Trials.no_potions(G,_main_map_id):
		_trial_saved_potions=st.potions
		battle_potions=0
	var battle_growth := G.growth_bonuses(st.role_id)
	if _mode=="main_world":
		for key in Oaths.objective(G,_oath_trip).get("bonus",{}):
			battle_growth[key]=float(battle_growth.get(key,0))+float(Oaths.objective(G,_oath_trip).bonus[key])
	BattleScene.pending_cfg = {
		"ally": {
			"role_id": st.role_id,
			"level": st.level,
			"traits": st.traits.duplicate(),
			"active_pet": st.active_pet,
			"bench_pet": st.bench_pet,
			"potions": battle_potions,
			"hp_override": st.hp,
			# 局外养成 6 线加成（天赋/装备/坐骑/称号 + 技能书等级 + 宠物养成快照）
			"growth": battle_growth,
			"potion_effect_mult":float(Oaths.objective(G,_oath_trip).get("potion_mult",1.0)) if _mode=="main_world" else 1.0,
			"skill_levels": G.prog.get("skills", {}),
			"unlocked_skills": G.act1_unlocked_skills(st.role_id),
			"skill_variants": G.act1_skill_variants(st.role_id),
			"pet_stats": G.battle_pet_stats([st.active_pet, st.bench_pet]),
		},
		"enemy": {"theme": st.theme, "node_type": m.tier,
			"world_map_id":_main_map_id if _mode == "main_world" else "",
			"layer": int(node.get("layer", 1)), "lead_mon": m.mon_id,
			"solo": _mode == "main_world" and bool(_main_cfg.get("encounter_solo", true)),
			"display_level": m.display_level,
			"sprite_path": m.sprite_path if _mode == "main_world" else "",
			# P05-C：召唤物（失路兽召的影狼）按单位 id 取自己的立绘，覆盖 leader 那张
			"sprite_paths": _main_cfg.get("monster_sprite_paths", {}) if _mode == "main_world" else {},
			# 苦行局（轮次 22）：敌人强度倍率由 RunState 决定，战斗内核只吃数字
			"enemy_mult": st.enemy_mult(),
			"opening_def_break": {"monster_id": "mon_tide_priest", "pct": 0.15,
				"ticks": 180} if tide_break else {}},
		"mode": "pve",   # 超时按远征失利显示（口径 D3；问题 #21）
		"reward_preview":_battle_reward_preview(m),
		"presentation": "classic_inline" if _mode == "main_world" else "default",
		"stele_echo_ready": _mode == "main_world" and _main_map_id == "stele_cavern" \
			and m.mon_id == "mon_stele_warden" and \
			bool(G.prog.get("flags", {}).get("act1_stele_seat_2", false)),
		"tide_route": tide_route,
		"tide_supply_bonus": tide_supply,
		"tide_dual_route_ready": tide_break,
		"region_floor_tint": _ground_tint().to_html(false),
		# P03：撤退规则。主线首领（失声碑灵）不可撤退——按钮置灰并写明后果，
		# 由 BattleScene 直接读这一项，规则不写在表现层里。
		# P05-C：可选首领（失路兽）可自由撤退——不是必经关，撤退不该把玩家钉死在巢穴边。
		"flee_rule": "blocked" if _boss_flee_blocked(m.tier, m.optional) else "free",
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


func _ambient_region() -> String:
	if _mode == "main_world":
		if _main_map_id in ["shenyuan_port", "tideflat", "tidal_gate"]: return "port"
		if _main_map_id in ["rift_mine_road", "rift_mine_vault"]: return "mine"
	return st.theme


func _on_battle_end(result: String, hp_left: int) -> void:
	var battle := _battle
	_last_battle_pets = battle.sim.companion_participants.duplicate() if battle != null else []
	var mastery_lines: Array = []
	if _mode == "main_world" and battle != null:
		mastery_lines = G.mentor_report_effective(battle.effective_skills)
		mastery_lines.append_array(G.curriculum_report_effective(battle.effective_skills,
			String(_encounter.get("encounter_id", ""))))
	var monster_tier := _contact_mon.tier if _contact_mon != null else ""
	var defeated_mon_id := _contact_mon.mon_id if _contact_mon != null else ""
	_last_battle_tier = monster_tier   # 战后三选一次数按档位给（B3）
	# P05-C：可选首领标记——本场决定「可撤退、不掷装备、首胜单发」三项口径，
	# 结算与银行都在本函数之后读它，必须在 _settle_main_world 之前算好。
	_last_battle_optional = _contact_mon != null and _contact_mon.optional
	_last_battle_trial = _contact_mon != null and _contact_mon.trial
	_battle = null
	if result in ["victory", "flee"]:
		Audio.play_bgm("bgm_map")
		Audio.play_ambience(_ambient_region())
	_battle_layer.queue_free()  # 级联释放 BattleScene
	_battle_layer = null
	if _mode == "main_world":
		_world.visible = true
		_hud.visible = true
	st.apply_battle_result(battle.sim)
	if _trial_saved_potions>=0:
		st.potions=_trial_saved_potions
		_trial_saved_potions=-1
	for mastery_line_v in mastery_lines:
		_toast(String(mastery_line_v))
	# P03：收到结果先落到 result_pending（仅内存）。进程死在这一步 → 存档里仍是 battle，
	# 重进后这场遭遇是 open 的，可以重打一次并按 result_id 只结算一次。
	if _mode == "main_world":
		_advance_encounter(WorldSession.ST_RESULT_PENDING)
	# P03：撤退规则写在按钮上（flee_rule=blocked）；万一表现层仍然发出 flee，这里兜住，
	# 不让玩家从主线首领手里溜走（按败收场，与超时口径一致）。
	# P05-C：可选首领不在兜住范围内——它的 flee_rule 本就是 free，撤退按正常撤退走。
	if result == "flee" and _boss_flee_blocked(monster_tier, _last_battle_optional):
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
		elif settle_res in ["save_failed", "quest_missing", "quest_failed", "settle_failed"]:
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
func _boss_flee_blocked(tier: String, optional: bool) -> bool:
	return _mode == "main_world" and tier == "boss" and not optional \
		and not bool(_main_cfg.get("allow_boss_flee", false))


func _story_battle_ready(mon_id: String) -> bool:
	if _mine_rooms_enabled() and mon_id == "mon_redsand_guard" and \
			not bool(G.prog.get("flags", {}).get("act3_mine_switch", false)):
		_toast("先核对翻车记录，调稳两座风轮，再让矿车带人撤离")
		return false
	if _stele_rooms_enabled() and mon_id == "mon_stele_warden" and \
			(not _stele_room_one_ready() or \
			not _stele_shadow_resolved() or \
			not bool(G.prog.get("flags", {}).get("act1_stele_seat_2", false))):
		_toast("先听清石缝，处理守影，再调稳两枚碑座")
		return false
	if _tidal_rooms_enabled() and mon_id == "mon_tide_priest" and \
			not bool(G.prog.get("flags", {}).get("act2_tide_gate_2", false)):
		_toast("先核对水痕、泄向旧渠，再排清栈桥侧闸")
		return false
	var row := G.story_current()
	if String(row.get("event", "")) != "defeat" or String(row.get("target", "")) != mon_id:
		return true
	if mon_id == String(_main_cfg.get("boss_id", "")):
		var gate: Dictionary = _main_cfg.get("boss_puzzle_gate", {})
		var flags: Dictionary = G.prog.get("flags", {})
		if not gate.is_empty() and bool(flags.get(String(gate.get("start_flag", "")), false)) \
				and not bool(flags.get(String(gate.get("finish_flag", "")), false)):
			_toast(String(gate.get("hint", "先处理地图机关")))
			return false
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
	var before_hp := st.hp
	var before_growth := st.growth_bonus.duplicate(true)
	var rewards: Variant = _main_cfg.get("battle_rewards", {})
	var reward: Variant = (rewards as Dictionary).get(tier, {}) if rewards is Dictionary else {}
	var gold := 0
	var exp := 0
	if reward is Dictionary:
		gold = maxi(0, int((reward as Dictionary).get("gold", 0)))
		exp = maxi(0, int((reward as Dictionary).get("exp", 0)))
	var is_mail_ambush := _main_map_id == "red_sand_route" and _contact_mon != null \
		and _contact_mon.idx == _road_mail_ambush_idx()
	var is_stele_shadow := _main_map_id == "stele_cavern" and _contact_mon != null \
		and _contact_mon.idx == 3000
	if is_mail_ambush:
		gold = 0
		exp = 0  # 邮路每日已有固定报酬；伏击不额外变成刷金点。
	if _last_battle_trial:
		gold=0
		exp=0
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
	if reward_msg.is_empty():
		# R-08：奖励事务未落地（账本拒绝/装备预检不通过）。与写盘失败同一条回滚路径：
		# 战利、刷点、遭遇推进与临时状态全部退回，磁盘上只剩可重打的 battle。
		# 不能带着"已推进"的世界状态留下一场没发奖的胜利。
		G.prog = before_prog
		G.wallet = before_wallet
		G.items = before_items
		_main_respawn_at = before_respawn
		st.gold = before_gold
		st.exp = before_exp
		st.level = before_level
		st.hp = before_hp
		st.growth_bonus = before_growth
		_toast("战利未落袋（结算未通过），本场可重新挑战")
		return "settle_failed"
	# P05-C：可选首领首胜（固定职业适配蓝装 + 图鉴条目 + 世界旗）。单事务、同一 ID 只发一次；
	# 调用返回快照，写盘失败时用它把首胜那部分（钱包/物品/进度含账本与背包）整体回滚。
	var first_row: Dictionary = _optional_boss_row(defeated_mon_id) if _last_battle_optional else {}
	var first_cfg: Dictionary = first_row.get("first_kill", {})
	var first_needed := not first_cfg.is_empty() and not RewardLedger.applied(G.ledger(),
		RewardLedger.tx_id(String(first_cfg.get("tx_scope", "act1")), String(first_row.get("id", defeated_mon_id)), "first"))
	var first_kill := _apply_optional_first_kill(defeated_mon_id) if _last_battle_optional else {}
	# 战利、主线目标与遭遇状态一起写盘。中间任何一步退出时，磁盘上
	# 要么还是可重打的 battle，要么已完整结算，不能只留下半份奖励。
	# P05-B：支线讨伐计数（只对已接支线生效）。与主线、遭遇状态同一次写盘：
	# 写盘失败时连支线计数一起退回，磁盘上不留半份。
	var side_touched := G.side_report("defeat", defeated_mon_id, _main_map_id, false) if not _last_battle_trial else []
	var expected_story := G.story_current()
	var story_result := G.story_event("defeat", defeated_mon_id, _main_map_id, false) if not _last_battle_trial else {}
	if (String(expected_story.get("event", "")) == "defeat" \
		and String(expected_story.get("target", "")) == defeated_mon_id and story_result.is_empty()) \
		or (first_needed and first_kill.is_empty()):
		# A cleared story boss and its quest item must commit together.
		G.prog = before_prog
		G.wallet = before_wallet
		G.items = before_items
		_main_respawn_at = before_respawn
		st.gold = before_gold
		st.exp = before_exp
		st.level = before_level
		st.hp = before_hp
		st.growth_bonus = before_growth
		_toast("主线战利未保存，本场可重新挑战")
		return "save_failed" if G.save_locked else "quest_failed"
	if not _encounter.is_empty() and G.story_step_done(String(CompanionService.config().get("requires_story","s24"))):
		CompanionService.record_win(G.prog,_last_battle_pets)
	if is_mail_ambush:
		var mail_plan: Dictionary = RoadMailServiceScript.transition(G.road_mail_state(),
			"hazard_battle", _main_map_id, int(G.economy_state().get("day", 1)))
		if not bool(mail_plan.get("ok", false)):
			G.prog = before_prog
			G.wallet = before_wallet
			G.items = before_items
			_main_respawn_at = before_respawn
			st.gold = before_gold
			st.exp = before_exp
			st.level = before_level
			st.hp = before_hp
			st.growth_bonus = before_growth
			return "quest_failed"
		G.prog["road_mail"] = mail_plan["next"]
	if is_stele_shadow:
		var flags: Dictionary = G.prog.get("flags", {})
		flags["act1_stele_shadow_defeated"] = true
		G.prog["flags"] = flags
	if _contact_mon != null and not _contact_mon.commission_posting.is_empty():
		var posting := _contact_mon.commission_posting
		var objective := WorldCommission.current(WorldCommission.state(G).get(posting,{}))
		# Participates in this encounter's single save and existing complete rollback.
		WorldCommission.action(G,posting,_main_map_id,String(objective.get("id","")),"",true,false)
	if _contact_mon != null and not _contact_mon.oath_trip.is_empty():
		Oaths.finish(G,_contact_mon.oath_trip,false)
	if _last_battle_trial:
		Trials.advance(G,_main_map_id,String(Trials.current(G,_main_map_id).get("id","")),"",true,false)
	if not G.save_game():
		G.prog = before_prog
		G.wallet = before_wallet
		G.items = before_items
		_main_respawn_at = before_respawn
		st.gold = before_gold
		st.exp = before_exp
		st.level = before_level
		st.hp = before_hp
		st.growth_bonus = before_growth
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
	if is_stele_shadow:
		_toast("守影退去，第二枚碑座重新显露")
		_refresh_quest_entities.call_deferred()
	if _contact_mon != null and not _contact_mon.commission_posting.is_empty():
		_toast("夜岗守稳了 · 回昭元公告栏交付")
		_refresh_quest_entities.call_deferred()
	if _contact_mon != null and not _contact_mon.oath_trip.is_empty():
		_toast("前哨誓约已记录 · 材料入袋")
		_refresh_quest_entities.call_deferred()
	if _last_battle_trial:
		_toast("附加挑战已完成 · 主线首通奖励不重发")
		_refresh_quest_entities.call_deferred()
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
		if _last_battle_tier == "boss" and not _last_battle_optional and not _last_battle_trial:
			var town := String(preload("res://src/world/JourneyService.gd").cfg().get("return_towns",{}).get(_main_map_id,""))
			if not town.is_empty(): _open_journey(town)
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
		if not RewardLedger.applied(G.ledger(), txid) and not _last_battle_trial:
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
			if not _last_battle_optional and not bool(_main_cfg.get("fixed_boss_rewards", false)):
				var drop := Inventory.roll_drop(G.equip_cfg(), TableCache.drops_config(),
					_last_battle_tier, _rng)
				if not drop.is_empty():
					var dtpl := G.equip_tpl(String(drop.get("tpl", "")))
					grants["equip:%s:%d" % [String(drop.get("tpl", "")), int(drop.get("rarity", 1))]] = 1
					msg_suffix = " · 装备 %s" % String(dtpl.get("name", "?"))
		var tx := RewardLedger.make(txid, {}, grants, {})
		var res := RewardLedger.apply(tx, G.ledger(), G)
		if not bool(res.get("ok", false)):
			# R-08：奖励事务未落地时**既不能吞掉战利，也不能继续报喜**。
			# 旧实现只清掉装备后缀就往下走：st.gold/st.exp 在下面被无条件清零、
			# 金币经验根本没进钱包，而调用方仍把「遭遇已推进、刷点已重置」写盘 ——
			# 玩家看到「战利 · 铜钱 +N」却没到账，且因为遭遇已推进而无法重打这批怪。
			# 现在返回空串表示本场未入账，调用方按与写盘失败同一条路径整体回滚，
			# 磁盘上仍然只留下可重打的 battle。
			push_warning("战斗结算未落地：%s" % String(res.get("err", "")))
			return ""
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
	_sync_campaign_level()
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
	var _retry_cd:=0.0

	func _process(delta: float) -> void:
		_t += delta
		_retry_cd=maxf(0,_retry_cd-delta)
		if _retry_cd>0:return
		if used or map_ref == null or map_ref._player == null:
			return
		if map_ref._map_done or map_ref._battle != null:
			return
		var r := float(map_ref._cfg_int("pickup_radius", 30))
		if position.distance_to(map_ref._player.position) < r:
			used = true
			if map_ref.on_pickup(self):queue_free()
			else:
				used=false
				_retry_cd=1.0
			return
		queue_redraw()

	func _draw() -> void:
		MapScene.WorldPropArt.shadow(self,13)
		var bob := roundf(sin(_t*3)*3)
		var tex := G.res_tex("cur_gold" if kind=="coin" else "cur_soul")
		if tex!=null: draw_texture_rect(tex,Rect2(-10,-13+bob,20,20),false)


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
		if kind=="vein": MapScene.WorldPropArt.vein(self,used)
		else: MapScene.WorldPropArt.altar(self,used)


class _SteleRoomGate extends StaticBody2D:
	var caption := ""

	func _ready() -> void:
		collision_layer = 2
		collision_mask = 0
		var collider := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(960, 36)
		collider.shape = rect
		add_child(collider)
		var label := G.gold_label(caption, G.FS_XS, true, Color("f0dfbd"), true)
		label.position = Vector2(-192, -54)
		label.size = Vector2(384, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		queue_redraw()

	func _draw() -> void:
		MapScene.WorldPropArt.barrier(self,-480,960,44,Color("c6bfd6"))


## 水闸的隔水堰：第二闸按选择打开左侧栈桥或右侧货箱暗渠。
class _TidalRoomGate extends StaticBody2D:
	var caption := ""
	var route := "sealed"
	var _colliders: Array[CollisionShape2D] = []
	var _label: Label = null

	func _ready() -> void:
		collision_layer = 2
		collision_mask = 0
		_label = G.gold_label(caption, G.FS_XS, true, Color("e7f5ee"), true)
		_label.position = Vector2(-200, -57)
		_label.size = Vector2(400, 24)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		_rebuild()

	func set_route(value: String) -> void:
		if value == route: return
		route = value
		if is_inside_tree(): _rebuild()

	func _segments() -> Array[Vector2]:
		match route:
			"bridge": return [Vector2(-480, -115), Vector2(-15, 480)]
			"cargo": return [Vector2(-480, 15), Vector2(115, 480)]
			"both": return [Vector2(-480, -115), Vector2(-15, 15), Vector2(115, 480)]
		return [Vector2(-480, 480)]

	func _rebuild() -> void:
		for collider in _colliders:
			remove_child(collider)
			collider.queue_free()
		_colliders.clear()
		for segment in _segments():
			var collider := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(segment.y - segment.x, 40)
			collider.shape = rect
			collider.position.x = (segment.x + segment.y) / 2.0
			add_child(collider)
			_colliders.append(collider)
		if _label != null:
			_label.text = caption if route == "sealed" else \
				("栈桥与暗渠均可通行" if route == "both" else \
				("栈桥步道已通" if route == "bridge" else "货箱暗渠已通"))
		queue_redraw()

	func _draw() -> void:
		for segment in _segments():
			MapScene.WorldPropArt.barrier(self,segment.x,segment.y-segment.x,48,Color("b9d9dc"))


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
	var _caption_label: Label

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if gate_style=="sealed": material = MapScene.WorldPropArt.muted_material()
		var caption_color := Color("ffe2a0") if gate_style == "restored" else \
			(Color("d7d5cd") if gate_style == "sealed" else Color("fff1c4"))
		var label := G.gold_label(caption, G.FS_XS, true, caption_color, true)
		_caption_label = label
		label.position = Vector2(-84, -116)
		label.size = Vector2(168, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		queue_redraw()

	func _process(_delta: float) -> void:
		if _caption_label == null: return
		var screen_at := get_global_transform_with_canvas() * _caption_label.position
		var viewport_size := get_viewport_rect().size
		var label_rect := Rect2(screen_at, _caption_label.size)
		var status_area := Rect2(0, 0, 352, 196)
		var minimap_area := Rect2(viewport_size.x - 128, 0, 128, MapScene.MINI_H + MapScene._MiniMapPos.y + 4)
		_caption_label.visible = not label_rect.intersects(status_area) \
			and not label_rect.intersects(minimap_area) \
			and screen_at.x >= 2 and label_rect.end.x <= viewport_size.x - 2

	func _draw() -> void:
		MapScene.WorldPropArt.signpost(self,gate_style)


class _MapMonster extends CharacterBody2D:
	var trial := false
	var oath_trip := ""
	var commission_posting := ""
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
	var _grounding: Dictionary = {}
	var _art_rect := Rect2()
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
			var registered := MonsterArt.has(mon_id)
			if registered: tex = MonsterArt.texture(mon_id)
			if tex != null:
				var h: float = sprite_height if not sprite_path.is_empty() else {"normal": 48.0, "elite": 60.0, "boss": 84.0}.get(tier, 48.0)
				var s := h / float(tex.get_height())
				if registered: s = MonsterArt.display_scale(mon_id, h)
				_sprite = Sprite2D.new()
				_sprite.texture = tex
				_sprite.scale = Vector2.ONE * s
				_sprite.offset = Vector2(0, -tex.get_height() / 2.0)
				if registered:
					_sprite.material = FrostCityArt.cutout_material()
					_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				add_child(_sprite)
				var display_size := Vector2(tex.get_size()) * s
				_art_rect = Rect2(Vector2(-display_size.x*.5,-display_size.y),display_size)
				_grounding = preload("res://src/world/BuildingGrounding.gd").actor(tex,roundi(display_size.x),roundi(display_size.y))
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
			if _sprite != null and MonsterArt.has(mon_id):
				_label_top = -_sprite.texture.get_height() * _sprite.scale.y - LABEL_H - 7.0
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
		if map_ref != null and map_ref._side_chip != null and map_ref._side_chip.visible:
			top = maxf(top, map_ref._side_chip.position.y + map_ref._side_chip.size.y + 2.0)
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

		if _sprite != null:
			preload("res://src/world/BuildingGrounding.gd").draw_prop(self,_grounding,_art_rect.position,_art_rect.size.x)
			if _state == "chase":
				draw_arc(Vector2.ZERO, r + 8.0, 0.0, TAU, 20, Color(1.0, 0.4, 0.3, 0.85), 2.0)
			return
		# Procedural fallbacks have no alpha contour; their bodies reach this plane.
		draw_set_transform(Vector2(0,r*.72),0.0,Vector2(1.0,.38))
		draw_circle(Vector2.ZERO,r*1.02,Color(0,0,0,.32))
		draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
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
	var contact_cd := 0.0
	var kind := "chest"  # chest / event / shop / bonfire
	var used := false
	var map_ref: MapScene = null
	var _t := 0.0
	var _art := false       # 已用素材立绘（程序体跳过）
	var _art_h := 64.0      # 立绘显示高（三角提示的高度基准）
	var _grounding: Dictionary = {}
	var _art_rect := Rect2()

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
			var display_size := Vector2(tex.get_size()) * s
			_art_rect = Rect2(Vector2(-display_size.x*.5,-display_size.y),display_size)
			_grounding = preload("res://src/world/BuildingGrounding.gd").silhouette(tex,roundi(display_size.x),roundi(display_size.y))

	func _process(delta: float) -> void:
		_t += delta
		contact_cd = maxf(0, contact_cd-delta)
		if contact_cd > 0: return
		if used or map_ref == null or map_ref._player == null:
			return
		if map_ref._modal_open():
			return  # 覆盖层期间不触发（含看大地图/演出，P1-10）
		if position.distance_to(map_ref._player.position) < MapScene.INTERACT_R:
			map_ref.on_interactable(self)
		queue_redraw()

	func _draw() -> void:
		if _art:
			preload("res://src/world/BuildingGrounding.gd").draw_prop(self,_grounding,_art_rect.position,_art_rect.size.x)
		else:
			draw_set_transform(Vector2(0,6),0,Vector2(1,.3))
			draw_circle(Vector2.ZERO,30,Color(0,0,0,.22))
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
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
		MapScene.WorldPropArt.marker(self,tip,G.GOLD_BRIGHT)

	func _draw_chest() -> void:
		MapScene.WorldPropArt.chest(self)


	func _draw_event() -> void:
		MapScene.WorldPropArt.altar(self,used)


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
class _OathTraveler extends CharacterBody2D:
	var map_ref: MapScene
	var trail:Array[Vector2]=[]
	var last_player:=Vector2.INF
	var sprite:AnimatedSprite2D
	func _ready()->void:
		motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
		collision_layer=0
		collision_mask=2
		var shape:=CollisionShape2D.new()
		var rect:=RectangleShape2D.new()
		rect.size=Vector2(18,16)
		shape.shape=rect
		shape.position.y=5
		add_child(shape)
		var texture:=G.res_tex("npc_guest_idle")
		if texture!=null and texture.get_width()>=512:
			var frames:=SpriteFrames.new()
			frames.add_animation(&"idle")
			frames.set_animation_speed(&"idle",4)
			for i in 4:
				var atlas:=AtlasTexture.new()
				atlas.atlas=texture
				atlas.region=Rect2(i*128,0,128,128)
				frames.add_frame(&"idle",atlas)
			sprite=AnimatedSprite2D.new()
			sprite.sprite_frames=frames
			sprite.scale=Vector2.ONE*.55
			sprite.position.y=-32
			sprite.play(&"idle")
			add_child(sprite)
	func _physics_process(_delta:float)->void:
		velocity=Vector2.ZERO
		if map_ref==null or map_ref._player==null or map_ref._battle!=null or map_ref._modal_open():return
		var player:=map_ref._player.position
		if last_player==Vector2.INF or last_player.distance_to(player)>18:
			trail.append(player)
			last_player=player
		while trail.size()>1 and position.distance_to(trail[0])<12:trail.pop_front()
		if not trail.is_empty() and (trail.size()>1 or position.distance_to(player)>48):
			velocity=position.direction_to(trail[0])*145
			move_and_slide()
		if sprite!=null:
			sprite.speed_scale=1.0 if velocity.length()>0 else .5
	func _draw()->void:
		draw_ellipse_shadow()
		if sprite!=null:return
		draw_rect(Rect2(-9,-26,18,24),Color("729b8e"))
		draw_circle(Vector2(0,-33),8,Color("d6b88b"))
		draw_line(Vector2(-5,-3),Vector2(-6,6),Color("3d4d52"),4)
		draw_line(Vector2(5,-3),Vector2(6,6),Color("3d4d52"),4)
	func draw_ellipse_shadow()->void:
		draw_set_transform(Vector2(0,6),0,Vector2(1,.35))
		draw_circle(Vector2.ZERO,16,Color(0,0,0,.2))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

class _QuestEntity extends Node2D:
	var special_event_id := ""
	var feedback_tier:=0
	var commission_posting := ""
	var eid := ""
	var quest := ""
	var contract_id := ""
	var kind := "collect"        # collect / observe / deliver
	var mail_action := ""
	var shipping_id := ""
	var story_event_kind := "collect"
	var art := "root"            # chime / root / tracks / post
	var caption := ""
	var used := false
	var trade_cooled := false
	var map_ref: MapScene = null
	var _t := 0.0
	var _trade_tex: Texture2D = null
	var _trade_ground: Dictionary = {}
	var _uses_ground_art := false
	var _caption_label:Label

	func _ready() -> void:
		if art == "trade_stall":
			_trade_tex = G.res_tex("trade_stall")
			if _trade_tex != null:
				_trade_ground = preload("res://src/world/BuildingGrounding.gd").silhouette(_trade_tex,_trade_tex.get_width(),_trade_tex.get_height())
		_uses_ground_art = art == "frost_brazier" and map_ref != null and map_ref._main_map_id == "frost_post"
		var label := G.gold_label(caption, G.FS_XS, true,
			Color("ffe2a0") if kind in ["cache", "trade", "story", "road_mail", "puzzle_choice", "shipping_aid", "frost_herb_route", "first_order_bridge"] else Color("cfe3ff"), true)
		label.position = Vector2(-84, -124 if art in ["trade_stall", "salt_cart", "tide_cargo"] else -70)
		if _uses_ground_art: label.position.y = -98
		label.size = Vector2(168, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption_label=label
		if kind=="feedback":label.visible=false
		add_child(label)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if kind=="feedback":
			_caption_label.visible=map_ref!=null and map_ref._closest_feedback()==self
			return
		if used or map_ref == null or map_ref._player == null:
			return
		if kind in ["special_event", "trade_contract", "trial", "trial_board", "oath", "world_commission", "trade", "fishing", "puzzle_choice", "align", "switch", "repair", "mark", "frost_herb_route", "first_order_bridge"] or \
				(kind == "road_mail" and mail_action == "board"):
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
		if art == "trade_stall" and _trade_tex != null:
			preload("res://src/world/BuildingGrounding.gd").draw_prop(self,_trade_ground,Vector2(-56,-96),_trade_tex.get_width())
		elif art not in ["trust_zhaoyuan","trust_shenyuan","trust_frost","return_lamp","return_letter","return_tidebud","return_snowflower","return_rune","stele_anchor","frost_brazier","frost_lichen","mine_vent","frost_echo","signal_ribbons","mine_cart","rope","feather","tide_cargo","salt_cart","chime","cache","post"]:
			draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.36))
			draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.24))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		match art:
			"trust_zhaoyuan","trust_shenyuan","trust_frost":
				preload("res://src/explore/RegionalMemoryScenes.gd").draw_scene(self,art.trim_prefix("trust_"),feedback_tier)
			"return_lamp", "return_letter", "return_tidebud", "return_snowflower", "return_rune":
				MapScene.ReturnJourneyPropsScript.draw_prop(self,art)
			"stele_anchor":
				MapScene.WorldPropArt.altar(self,false)
			"resonance":
				# 地表原图承接碑座本体；程序层只叠加可交互的三地共鸣光纹。
				for i in 3:
					var p := Vector2(-24 + i * 24, -18)
					var color: Color = [Color("93bf95"), Color("82bacb"), Color("d1dceb")][i]
					draw_arc(p, 9, 0, TAU, 12, color, 2)
					draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), color, 2)
				draw_arc(Vector2(0, -18), 44, .2, PI - .2, 20, Color(.74, .58, .87, .45), 2)
			"frost_brazier":
				# Permanent scene art owns the body at frost_post.
				if not _uses_ground_art: MapScene.WorldPropArt.story(self,"frost_brazier",76)
			"frost_nameplate":
				var plate := G.res_tex("itm_frost_nameplate")
				if plate != null: draw_texture_rect(plate, Rect2(-22, -42, 44, 44), false)
			"frost_lichen":
				MapScene.WorldPropArt.story(self,"frost_lichen",40)
			"mine_vent":
				MapScene.WorldPropArt.vent(self)
			"frost_courier":
				var strip := G.res_tex("npc_port_worker_idle")
				if strip != null:
					draw_texture_rect_region(strip,Rect2(-42,-84,84,84),Rect2(0,0,128,128),Color("cee3e6"))
				else: MapScene.WorldPropArt.post(self)
			"frost_echo":
				MapScene.WorldPropArt.story(self,"frost_echo",76)
			"signal_ribbons":
				MapScene.WorldPropArt.signal_flags(self)
			"mine_cart":
				MapScene.WorldPropArt.story(self,"mine_cart",68)
			"rope":
				MapScene.WorldPropArt.story(self,"rope",48)
			"feather":
				MapScene.WorldPropArt.story(self,"feather",44)
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
		if kind=="feedback":return
		# 固定奇遇金三角，支线蓝三角：地图上可直接分辨两个事件。
		var bob := sin(_t * 2.2) * 4.0
		var tip := Vector2(0, (-142.0 if art in ["trade_stall", "salt_cart", "tide_cargo"] else -88.0) + bob)
		if _uses_ground_art: tip.y = -116.0 + bob
		MapScene.WorldPropArt.marker(self,tip,Color("ffd279") if kind in ["cache","trade","story"] else Color("9fd0ff"))

	func _draw_salt_cart() -> void:
		MapScene.WorldPropArt.story(self,"salt_cart",94)

	func _draw_fishing() -> void:
		draw_set_transform(Vector2(0,8),0.0,Vector2(1.4,.48))
		draw_circle(Vector2.ZERO,34,Color("4d8a94"))
		draw_arc(Vector2.ZERO,23+sin(_t*2)*3,0,TAU,24,Color("b3d5d0"),2)
		draw_set_transform(Vector2.ZERO)
		MapScene.WorldPropArt.supplementary(self,"fishing",68)

	func _draw_tide_cargo() -> void:
		MapScene.WorldPropArt.story(self,"tide_cargo",72)

	func _draw_cache() -> void:
		MapScene.WorldPropArt.chest(self)


	func _draw_chime() -> void:
		MapScene.WorldPropArt.chime(self,sin(_t*2.4)*2.5)


	func _draw_root() -> void:
		MapScene.WorldPropArt.herb(self)


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
		MapScene.WorldPropArt.post(self)


class _Minimap extends Control:
	signal tapped

	var map_ref: MapScene = null
	var big := false
	var _frame_style := MapScene.HudStyle.surface(MapScene.HudStyle.WOOD, MapScene.HudStyle.EDGE)
	var _shadow_style := MapScene.HudStyle.surface(Color("101f23", 0.55), Color.TRANSPARENT)
	var _cartography := MapScene.Cartography.new()
	var _hovered := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_ALL
		tooltip_text = "展开地图与图例"
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(func(): _hovered = true; queue_redraw())
		mouse_exited.connect(func(): _hovered = false; queue_redraw())
		custom_minimum_size = Vector2(260.0, 342.0) if big \
			else Vector2(MapScene.MINI_W, MapScene.MINI_H if map_ref != null and map_ref._mode == "main_world" else 120.0)
		size = custom_minimum_size   # 非容器控件不会自动吃最小尺寸，必须显式给宽高
		theme = MapScene.HudStyle.hud_theme()
		var title := MapScene.HudStyle.label("地域舆图" if big else "地图", 16 if big else 13, Color("f0d39f"), true)
		title.position = Vector2(10, 1)
		title.size = Vector2(size.x - 45, 28 if big else 20)
		add_child(title)
		var north := MapScene.HudStyle.label("北", 12, Color("c3c9b4"))
		north.position = Vector2(size.x - 22, 2)
		north.size = Vector2(16, 20)
		add_child(north)
		var footer := MapScene.HudStyle.label("金箭 · 当前位置" if big else "展开地图", 12, Color("d3c9aa"))
		footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.position = Vector2(9, size.y - 22)
		footer.size = Vector2(size.x - (18 if big else 30), 20)
		add_child(footer)
		if map_ref != null:
			var source: Array = map_ref._main_cfg.get("flat_routes", [])
			if map_ref._flat_ground != null: source = map_ref._flat_ground.routes
			elif source.is_empty() and not map_ref._ground_path.is_empty():
				source = MapScene.GroundLayout.expedition_routes(map_ref._ground_path,
					int(map_ref._map_cfg.get("map_cols", 32)), int(map_ref._map_cfg.get("map_rows", 42)))
			_cartography.setup(source)

	func _map_rect() -> Rect2:
		return MapScene.Cartography.fitted_rect(size, map_ref._map_extent(), big)

	func _project(point: Vector2) -> Vector2:
		return MapScene.Cartography.project(point, map_ref._map_extent(), _map_rect())

	func _gui_input(e: InputEvent) -> void:
		if G.ui_blocked: return
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
				or e.is_action_pressed("ui_accept"):
			tapped.emit()
			accept_event()

	func _draw() -> void:
		if map_ref == null:
			return
		var sz := size
		if sz.x <= 1.0 or sz.y <= 1.0:
			sz = custom_minimum_size
		_frame_style.border_color = Color("ae9567") if _hovered or has_focus() else MapScene.HudStyle.EDGE
		draw_style_box(_shadow_style, Rect2(Vector2(0, 2), sz))
		draw_style_box(_frame_style, Rect2(Vector2.ZERO, sz))
		MapScene.HudStyle.finish(self, sz, MapScene.HudStyle.BRASS)

		var ext := map_ref._map_extent()
		var map_rect := _map_rect()
		var at := func(p: Vector2) -> Vector2: return _project(p)
		var s := map_rect.size.x / ext.x
		draw_rect(map_rect.grow(1), Color("0f2427"))
		draw_rect(map_rect, MapScene.Cartography.ground_color(map_ref.st.theme))
		_cartography.draw_roads(self, map_rect, ext, big)
		if map_ref._city_content != null:
			for building in map_ref._city_content._buildings:
				var built: bool = building.built()
				MapScene.Cartography.draw_house(self, at.call(building.position), big, built)

		var reveal := float(map_ref._map_cfg.get("map_reveal_radius", 520.0))
		var pp := map_ref._player.position if map_ref._player != null else Vector2.ZERO

		# 视野范围仅在展开图显示，避免小图的框线盖住路线与定位箭头。
		if big:
			var camera := map_ref.get_viewport().get_camera_2d()
			var zoom := camera.zoom if camera != null else Vector2(1.25, 1.25)
			var view := map_ref.get_viewport_rect().size / zoom
			var center := camera.get_screen_center_position() if camera != null else pp
			var view_rect := Rect2(at.call(center - view * 0.5), view * s).intersection(map_rect)
			draw_rect(view_rect, Color("e5efcc", 0.09))
			draw_rect(view_rect, Color("e6d7a6", 0.62), false, 1)

		# 传送阵（封印为紫）
		if map_ref._portal != null and map_ref._portal.visible:
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
				var ep: Vector2 = at.call(map_ref._world_exit_sign_position(row))
				var col := Color("9fe06a")
				var req := String(row.get("requires_story", ""))
				if not req.is_empty() and not G.story_step_done(req):
					if not big: continue
					col = Color("8f8f8a")
				var marker_scale := 1.0 if big else 0.75
				draw_colored_polygon([ep + Vector2(0, -6.0) * marker_scale, ep + Vector2(5.0, 0) * marker_scale,
					ep + Vector2(0, 6.0) * marker_scale, ep + Vector2(-5.0, 0) * marker_scale], Color("14292d"))
				draw_colored_polygon([ep + Vector2(0, -4.0) * marker_scale, ep + Vector2(3.0, 0) * marker_scale,
					ep + Vector2(0, 4.0) * marker_scale, ep + Vector2(-3.0, 0) * marker_scale], col)
		# 目标物件（金菱）
		if map_ref._interactable != null and not map_ref._interactable.used:
			var ip: Vector2 = at.call(map_ref._interactable.position)
			draw_colored_polygon([ip + Vector2(0, -4.5), ip + Vector2(3.6, 0), ip + Vector2(-3.6, 0)],
				Color("ffd980"))
		# 追踪支线的野外实体（蓝菱）：与主线金标区分，一眼知道该往哪采／去哪交（P05-B）
		var side_points := map_ref._tracked_side_points()
		if not big and side_points.size() > 1:
			var nearest: Vector2 = side_points[0]
			for candidate: Vector2 in side_points:
				if candidate.distance_squared_to(pp) < nearest.distance_squared_to(pp): nearest = candidate
			side_points = [nearest]
		for qp_v in side_points:
			var qp: Vector2 = at.call(qp_v)
			if not big:
				var opacity := 0.88 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.002)
				if qp.distance_to(at.call(pp)) >= 7: _pt(qp, 2.0, Color(Color("9fd0ff"), opacity))
				continue
			draw_colored_polygon([qp + Vector2(0, -4.5), qp + Vector2(3.6, 0),
				qp + Vector2(0, 4.5), qp + Vector2(-3.6, 0)], Color("9fd0ff"))
		# 未拾取的拾取物（金点=钱袋 / 淡青=魂晶）：与地面光斑同色，指路用
		for p in map_ref._pickups:
			if p.used or not big:
				continue
			_pt(at.call(p.position), 2.6, Color("ffe9a8") if p.kind == "coin" else Color("9fe0f0"))
		# 兴趣点：紫菱=祭坛（花金重摇祝福）· 灰点=矿脉（材料）
		# 注意别用 s 当循环名：本函数上面已经有一个 s = 地图缩放比（同名会直接编译失败）
		for spot in map_ref._spots:
			if spot.used or not big:
				continue
			var sp: Vector2 = at.call(spot.position)
			if spot.kind == "altar":
				draw_colored_polygon([sp + Vector2(0, -4.5), sp + Vector2(3.6, 0),
					sp + Vector2(0, 4.5), sp + Vector2(-3.6, 0)], Color("c9a0ff"))
			else:
				_pt(sp, 2.4, Color("cfd6e0"))
		# 小图以导航为主：不铺满普通敌影，只保留首领警示；展开图显示全部已揭示敌影。
		for m in map_ref._monsters:
			if not big and m.tier != "boss": continue
			if m.position.distance_to(pp) <= reveal or m.tier == "boss":
				_pt(at.call(m.position), 2.6, Color("e0664a"))
		# 玩家金箭使用真实面向，小图去掉定位外圈，展开图保留柔和光环。
		var face := Vector2.DOWN
		if is_instance_valid(map_ref._player_anim):
			match String(map_ref._player_anim.animation):
				"walk_up": face = Vector2(0, -1)
				"walk_down": face = Vector2(0, 1)
				"walk_left": face = Vector2(-1, 0)
				"walk_right": face = Vector2(1, 0)
				_: face = Vector2(0, 1)
		MapScene.Cartography.draw_player(self, at.call(pp), face, big)
		# 北向固定的双色罗针；下缘给出明确的展开入口。
		var needle := Vector2(sz.x - 30, 12)
		draw_colored_polygon(PackedVector2Array([needle + Vector2(0, -5), needle + Vector2(-3, 3), needle]), Color("efd5a0"))
		draw_colored_polygon(PackedVector2Array([needle + Vector2(0, -5), needle + Vector2(3, 3), needle]), Color("a47a49"))
		draw_line(Vector2(9, sz.y - 23), Vector2(sz.x - 9, sz.y - 23), Color("bca16c", 0.32), 1)
		if not big:
			var expand := Vector2(sz.x - 16, sz.y - 11)
			draw_polyline(PackedVector2Array([expand + Vector2(-3, -3), expand + Vector2(3, -3), expand + Vector2(3, 3)]), Color("dfc18a"), 1, true)
			draw_line(expand + Vector2(-3, 3), expand + Vector2(3, -3), Color("dfc18a"), 1, true)
		if has_focus(): draw_rect(Rect2(Vector2.ONE * 2, sz - Vector2.ONE * 4), Color("f6d89a"), false, 1)

	func _pt(p: Vector2, r: float, c: Color) -> void:
		draw_circle(p, r + 1, Color("14292d", 0.85))
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


## 驿路浮层冻结世界接触；首领结算完后同一入口提供返程。
func _open_journey(recommended := "") -> void:
	if _mode != "main_world" or _battle != null or _map_done or _journey_panel != null: return
	_stop_auto_walk("")
	_persist_main_world_progress()
	var page := preload("res://src/ui/JourneyPanel.gd").new()
	page.recommended = recommended
	_journey_panel = page
	_hud.add_child(page)
	page.closed.connect(func(): _journey_panel = null)
	page.travel_requested.connect(func(map_id: String):
		if not G.can_go("res://src/explore/MapScene.tscn"): return
		_persist_main_world_progress()
		var result := preload("res://src/world/JourneyService.gd").travel(G,map_id)
		if bool(result.ok): G.enter_main_world(map_id)
		else: page.show_message(String(result.line)))
