# MapScene.gd —— 探索大地图（玩法文档 §2.7；阶段 2.3）
# 职责：进入战斗节点后的探索层——地图 32×42 格（1536×2016）自由移动；
#       散件 Y-sort 遮挡 + 碰撞；怪物游荡/警戒追击/接触开战（BattleScene 覆盖层）；
#       传送阵为节点出口（BOSS 节点需先胜首领解封）；地图上可用药剂/换宠（战斗外无 CD）。
# 编成（§2.5/§2.7）：普通区 3~4 小怪；精英区 1 精英 + 2 小怪；BOSS 区 1 首领守阵。
class_name MapScene
extends Control

signal map_finished(result: String)  # "cleared"（走传送阵）/ "defeat"（战斗失利）

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


func _ready() -> void:
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


func _build_world() -> void:
	_world.y_sort_enabled = true
	add_child(_world)

	var cols := int(_map_cfg.get("map_cols", 32))
	var rows := int(_map_cfg.get("map_rows", 42))
	var map_w := float(cols * 48)
	var map_h := float(rows * 48)

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
			var center_col := absi(gx - cols / 2) <= 1  # 中央通道密度减半
			var d := density * (0.5 if center_col else 1.0)
			if _rng.randf() > d:
				continue
			var pos := Vector2(gx * 48.0 + _rng.randf_range(8, 40),
				gy * 48.0 + _rng.randf_range(8, 40))
			if pos.distance_to(spawn) < 220.0 or pos.y < 200.0:
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
	_player_anim.scale = Vector2.ONE * 0.5
	_player_anim.position = Vector2(0, -18)
	_player_anim.animation = &"walk_down"
	_player_anim.stop()
	_player.add_child(_player_anim)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 26)
	shape.shape = rect
	shape.position = Vector2(0, 8)
	_player.add_child(shape)

	var cam := Camera2D.new()
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
func _build_hud() -> void:
	_hud.layer = 1
	add_child(_hud)

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

	# HP 条 + 药剂 + 换宠
	var panel := G.parchment_box(206, 56, 10.0)
	panel.position = Vector2(16, 88)
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
	potion_btn.position = Vector2(232, 96)
	potion_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_use_potion())
	_hud.add_child(potion_btn)

	_pet_btn = G.gold_button("换宠", 72, 40)
	_pet_btn.position = Vector2(284, 96)
	_pet_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_swap_pet())
	_hud.add_child(_pet_btn)

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
			st.add_reward("chest")
			_toast("宝箱开启：金币 +200 · 远征币 +30")
			it.queue_free()
		"event":
			var gold := _rng.randi_range(80, 150)
			st.gold += gold
			_toast("旅人赠礼：金币 +%d" % gold)
			it.queue_free()
		"shop":
			_shop_supply()
			it.queue_free()
		"bonfire":
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
		_toast("商队补给：药剂已达上限，祝你前路平安")
		return
	if st.gold >= price:
		st.gold -= price
		st.potions += 1
		_toast("商队补给：购得治疗药剂 ×1（金币 -%d）" % price)
	else:
		st.potions += 1
		_toast("商队钦佩你的勇气，赠你治疗药剂 ×1")
	_refresh_hud()


## 篝火词条删除浮层（§2.6 删 1 词条）：列表式选择舍弃，或保留全部
func _show_trait_remove() -> void:
	_remover = Control.new()
	_remover.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_remover.add_child(dim)

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
	if _remover != null:
		_remover.queue_free()
		_remover = null
	_refresh_hud()
	if msg != "":
		_toast(msg)


# ================= 主循环 =================
func _physics_process(delta: float) -> void:
	if _map_done or _battle != null or _picker != null or _remover != null:
		return
	if _player == null:
		return
	# 输入：键盘方向 + 摇杆向量
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _joy != null:
		dir = (dir + _joy.vector).limit_length(1.0)
	var speed := float(_map_cfg.get("player_speed", 130.0))
	_player.velocity = dir * speed
	_player.move_and_slide()
	# 地图边界夹紧
	var cols := int(_map_cfg.get("map_cols", 32))
	var rows := int(_map_cfg.get("map_rows", 42))
	_player.position = _player.position.clamp(Vector2(24, 60), Vector2(cols * 48 - 24, rows * 48 - 24))
	_update_player_anim(dir)
	_check_portal()


func _update_player_anim(dir: Vector2) -> void:
	if dir.length_squared() < 0.01:
		_player_anim.stop()
		return
	var anim := &"walk_down"
	if absf(dir.x) > absf(dir.y):
		anim = &"walk_right" if dir.x > 0 else &"walk_left"
	else:
		anim = &"walk_down" if dir.y > 0 else &"walk_up"
	if _player_anim.animation != anim:
		_player_anim.animation = anim
	if not _player_anim.is_playing():
		_player_anim.play()


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
	BattleScene.pending_cfg = {
		"ally": {
			"role_id": st.role_id,
			"level": st.level,
			"traits": st.traits.duplicate(),
			"active_pet": st.active_pet,
			"bench_pet": st.bench_pet,
			"potions": st.potions,
			"hp_override": st.hp,
		},
		"enemy": {"theme": st.theme, "node_type": m.tier,
			"layer": int(node.get("layer", 1))},
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
	st.hp = hp_left
	# 接触的怪离场
	if _contact_mon != null:
		_monsters.erase(_contact_mon)
		_contact_mon.queue_free()
		_contact_mon = null
	# 其余怪复位并返回巢穴
	for m in _monsters:
		m.chasing_contact = false
		m.retreat_home()
	# 首领解封传送阵
	if monster_tier == "boss" and _portal != null:
		_portal.locked = false
		_toast("首领陨落——传送阵封印解除！")
	# 战斗胜利三选一词条（§2.4：槽1数值机制/槽2流派85%双刃15%/槽3全池）
	var choices := st.roll_trait_choices(_rng)
	if choices.is_empty():
		_toast("词条池已尽")
	else:
		_show_trait_picker(choices)
	_refresh_hud()


# ================= 局部节点 =================
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


## 怪物（程序占位圆体；游荡/警戒/追击/接触回调；素材入库后热替换为精灵）
class _MapMonster extends Node2D:
	var tier := "normal"
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

	func _ready() -> void:
		_radius = {"normal": 20.0, "elite": 25.0, "boss": 32.0}.get(tier, 20.0)
		var mc: Dictionary = TableCache.maps_config()
		_aggro = float(mc.get("aggro_radius", 120.0))
		_contact = float(mc.get("contact_radius", 26.0))
		_wander_r = float(mc.get("monster_wander_radius", 96.0))
		_pick_wander_target()

	func _pick_wander_target() -> void:
		var a := randf() * TAU
		var d := randf() * _wander_r
		_target = home + Vector2(cos(a), sin(a)) * d

	func _process(delta: float) -> void:
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
		var col: Color = MapScene.MON_COLOR.get(tier, Color.GRAY)
		var body := col if _state == "wander" else col.lightened(0.25)
		draw_circle(Vector2(0, 4), _radius, Color(0, 0, 0, 0.3))
		draw_circle(Vector2.ZERO, _radius, body)
		draw_circle(Vector2.ZERO, _radius - 6.0, Color(col.r, col.g, col.b, 0.6))
		# 追击警示环
		if _state == "chase":
			draw_arc(Vector2.ZERO, _radius + 7.0, 0, TAU, 20, Color(1.0, 0.4, 0.3, 0.8), 2.0)
		# 眼睛（朝向差异感）
		draw_circle(Vector2(-6, -4), 3.0, Color(0.1, 0.1, 0.12))
		draw_circle(Vector2(6, -4), 3.0, Color(0.1, 0.1, 0.12))


## 非战斗节点交互物件（程序占位绘制；素材入库后热替换）
## 宝箱=棕箱金锁 / 事件=石碑问号 / 商店=绿帐篷 / 篝火=柴堆火苗；头顶金三角标可交互
class _Interactable extends Node2D:
	var kind := "chest"  # chest / event / shop / bonfire
	var used := false
	var map_ref: MapScene = null
	var _t := 0.0

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
		match kind:
			"chest":
				_draw_chest()
			"event":
				_draw_event()
			"shop":
				_draw_shop()
			"bonfire":
				_draw_bonfire()
		# 头顶浮动金三角（可交互提示）
		var bob := sin(_t * 2.2) * 4.0
		var tip := Vector2(0, -52.0 + bob)
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
