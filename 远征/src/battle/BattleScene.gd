# BattleScene.gd —— 战斗场景：BattleSim 驱动的表现层 + 操作 UI（玩法文档 §2.1）
# 职责：每渲染帧按速度倍率步进 sim 并消费 events（飘字/位移/HP/死亡）；
#       技能条/药剂/换宠/托管/速度；结算浮层。数值与判定全在 BattleSim（本层零规则）。
class_name BattleScene
extends Control

signal battle_finished(result: String, hp_left: int)

const TICK_SEC := 1.0 / 30.0
const VIEW_W := 480.0
const VIEW_H := 800.0
const COL_X := 96.0            # col 0 的 x（5 列：96~384，中心 240）
const COL_GAP := 72.0
const ENEMY_BACK_Y := 148.0
const ENEMY_FRONT_Y := 226.0
const ALLY_FRONT_Y := 402.0
const ALLY_BACK_Y := 474.0

const ROLE_SPRITE := {  # 人物战斗表现复用行走帧（walk_down 首帧行走帧当待机）
	"zs": ["res://image/role/zs/pojun_walk_frames.tres", "pojun"],
	"ck": ["res://image/role/ck/chuanyang_walk_frames.tres", "chuanyang"],
	"fs": ["res://image/role/fs/shuangyu_walk_frames.tres", "shuangyu"],
	"fz": ["res://image/role/fz/chenxing_walk_frames.tres", "chenxing"],
}
const BUFF_ABBR := {  # buff 状态条缩写
	"poison": "毒", "bleed": "血", "slow": "缓", "stun": "晕", "fear": "惧",
	"taunt": "嘲", "shield": "盾", "atk_up": "攻", "atk_down": "衰", "lurk": "潜",
	"invincible": "免", "thorns": "荆", "lifesteal": "吸", "confusion": "乱",
	"def_break": "破", "def_up": "防", "spd_up": "疾", "deathproof": "生",
}
const MON_COLOR := {  # 怪物占位体色（tier 区分；精灵素材入库后热替换）
	"normal": Color("5f7186"), "elite": Color("7a4a9a"), "boss": Color("8a2f2f"),
}

## 场景切入前由调用方写入（远征循环 #7 落地前的冒烟入口也走此通道）
static var pending_cfg: Dictionary = {}

var sim := BattleSim.new()
var speed := 1.0

var _acc := 0.0
var _views: Dictionary = {}          # uid -> UnitView
var _field := Node2D.new()           # 战场（单位 + 地面）
var _fx_layer := Control.new()       # 飘字层（最上）
var _skill_btns: Array[Dictionary] = []  # {btn, name_l, cd_l, skill}
var _energy_fill := ColorRect.new()
var _energy_l := Label.new()
var _potion_l := Label.new()
var _pet_btn: Control = null
var _auto_btn: Control = null
var _speed_btn: Control = null
var _cast_tip := Label.new()
var _tip_tween: Tween = null
var _finished_ui := false
var _cfg: Dictionary = {}


func _ready() -> void:
	_cfg = pending_cfg
	pending_cfg = {}
	sim.record_events = true
	var seed_v: int = int(_cfg.get("seed", 0))
	if seed_v == 0:
		seed_v = randi()
	sim.setup(seed_v, _cfg.get("ally", {}), _cfg.get("enemy", {}))
	sim.events.clear()  # 丢弃 ready 事件
	_build_background()
	_build_field()
	_build_top_bar()
	_build_skill_bar()
	_build_func_row()
	_sync_views()
	sim.events.clear()


# ================= 布局 =================
func _build_background() -> void:
	# 战斗底色（主题 tint 渐变；bg_battle_* 素材入库后热替换）
	var theme: String = String(_cfg.get("enemy", {}).get("theme", "forest"))
	var tc := TableCache.theme_config(theme)
	var tint := Color(String(tc.get("tint", "ffffff")))
	var bg := ColorRect.new()
	bg.color = Color(tint.r * 0.22, tint.g * 0.22, tint.b * 0.24)
	bg.size = Vector2(VIEW_W, VIEW_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 主题 tile 平铺地面（战场区 y48~592）
	var tiles: Array = tc.get("tiles", [])
	if not tiles.is_empty():
		var asset_dir: String = String(TableCache.maps_config().get("asset_dir", "res://image/map"))
		var tex: Texture2D = load("%s/%s.png" % [asset_dir, String(tiles[0])])
		if tex != null:
			var ground := TextureRect.new()
			ground.texture = tex
			ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ground.stretch_mode = TextureRect.STRETCH_TILE
			ground.size = Vector2(VIEW_W, 544)
			ground.position = Vector2(0, 48)
			ground.modulate = Color(0.85, 0.85, 0.9)
			ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(ground)
	# 地面基线（手绘感双线）
	var line := _LineDrawer.new()
	line.position = Vector2(0, 338)
	line.color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.35)
	add_child(line)
	var line2 := _LineDrawer.new()
	line2.position = Vector2(0, 344)
	line2.color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.16)
	add_child(line2)


func _build_field() -> void:
	add_child(_field)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fx_layer)


func _build_top_bar() -> void:
	var tc := TableCache.theme_config(String(_cfg.get("enemy", {}).get("theme", "forest")))
	var nt: String = String(_cfg.get("enemy", {}).get("node_type", "normal"))
	var nt_name: String = {"normal": "遭遇战", "elite": "精英战", "boss": "首领战"}.get(nt, "遭遇战")
	var title := G.serif_label("%s · %s" % [String(tc.get("name", "未知")), nt_name], G.FS_MD, G.GOLD)
	title.position = Vector2(16, 14)
	add_child(title)

	_speed_btn = _func_chip("速度 ×1", 74)
	_speed_btn.position = Vector2(VIEW_W - 170, 12)
	_speed_btn.gui_input.connect(_on_speed)
	add_child(_speed_btn)

	_auto_btn = _func_chip("托管", 58)
	_auto_btn.position = Vector2(VIEW_W - 96, 12)
	_auto_btn.gui_input.connect(_on_auto)
	add_child(_auto_btn)

	_cast_tip = G.serif_label("", G.FS_SM, Color("ffe9b0"))
	_cast_tip.position = Vector2(0, 52)
	_cast_tip.custom_minimum_size = Vector2(VIEW_W, 0)
	_cast_tip.modulate.a = 0.0
	add_child(_cast_tip)


func _func_chip(text: String, w := 64.0) -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(w, 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.10, 0.05, 0.7)
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(1)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.3)
	root.add_theme_stylebox_override("panel", sb)
	root.add_child(G.gold_label(text, G.FS_XS, false, Color("d9b96e"), false))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root


func _chip_set_active(chip: Control, active: bool) -> void:
	var sb: StyleBoxFlat = chip.get_theme_stylebox("panel")
	if sb != null:
		sb.bg_color = Color(0.32, 0.2, 0.06, 0.92) if active else Color(0.15, 0.10, 0.05, 0.7)
		sb.border_color = G.GOLD_BRIGHT if active else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.3)
	var l := chip.get_child(0) as Label
	if l != null:
		l.add_theme_color_override("font_color", G.GOLD_BRIGHT if active else Color("d9b96e"))


func _build_skill_bar() -> void:
	# 能量条（人物专属）
	var ebg := ColorRect.new()
	ebg.color = Color(0.1, 0.08, 0.04, 0.85)
	ebg.position = Vector2(23, 598)
	ebg.size = Vector2(434, 14)
	add_child(ebg)
	_energy_fill.color = G.GOLD
	_energy_fill.position = Vector2(24, 599)
	_energy_fill.size = Vector2(0, 12)
	add_child(_energy_fill)
	_energy_l = G.gold_label("能量 0/100", G.FS_XS, false, G.TEXT_LIGHT, false)
	_energy_l.position = Vector2(0, 597)
	_energy_l.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(_energy_l)

	# 5 技能格
	var role := sim.role_unit()
	if role == null:
		return
	for i in range(role.skills.size()):
		var s: Dictionary = role.skills[i]
		var skill: Dictionary = s.def
		var btn := PanelContainer.new()
		btn.custom_minimum_size = Vector2(82, 88)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.11, 0.06, 0.88)
		sb.set_corner_radius_all(4)
		sb.set_border_width_all(2)
		sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.4)
		btn.add_theme_stylebox_override("panel", sb)
		btn.position = Vector2(23 + i * 88.0, 620)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)
		btn.add_child(box)
		box.add_child(G.serif_label(String(skill.get("name", "?")), G.FS_SM, Color("ffd97a")))
		box.add_child(G.gold_label("耗 %d" % int(skill.get("cost", 0)), G.FS_XS, false,
			Color("bfa987"), false))
		var cd_l := G.gold_label("", G.FS_LG, true, Color("ffffff"))
		cd_l.modulate.a = 0.0
		box.add_child(cd_l)
		var sid := String(skill.get("id", ""))
		btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_try_cast(sid))
		add_child(btn)
		_skill_btns.append({"btn": btn, "cd_l": cd_l, "skill": skill,
			"cd_max": int(skill.get("cd", 5))})


func _build_func_row() -> void:
	# 药剂
	var potion_btn := _func_chip("", 86)
	potion_btn.position = Vector2(23, 724)
	potion_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_use_potion())
	_potion_l = G.gold_label("", G.FS_XS, false, G.TEXT_LIGHT, false)
	_potion_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	potion_btn.add_child(_potion_l)
	add_child(potion_btn)
	# 换宠（无替补则隐藏）
	if sim.pet_bench_id != "":
		_pet_btn = _func_chip("换宠", 86)
		_pet_btn.position = Vector2(119, 724)
		_pet_btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_swap_pet())
		add_child(_pet_btn)
	# 撤退（放弃本节点）
	var flee_btn := _func_chip("撤退", 86)
	flee_btn.position = Vector2(23 + 3 * 96.0, 724)
	flee_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			sim.finished = true
			sim.result = "defeat")
	add_child(flee_btn)


# ================= 单位视图 =================
func _spawn_view(u: Combatant) -> UnitView:
	var v := UnitView.new()
	v.setup(u, ROLE_SPRITE, MON_COLOR)
	v.position = _grid_pos(u.side, u.row, u.col)
	_field.add_child(v)
	return v


func _grid_pos(side: String, row: int, col: int) -> Vector2:
	var x := COL_X + col * COL_GAP
	if side == "enemy":
		return Vector2(x, ENEMY_BACK_Y if row == Combatant.ROW_BACK else ENEMY_FRONT_Y)
	return Vector2(x, ALLY_BACK_Y if row == Combatant.ROW_BACK else ALLY_FRONT_Y)


func _sync_views() -> void:
	for u in sim.units:
		if not _views.has(u.uid):
			_views[u.uid] = _spawn_view(u)
			if sim.tick_count > 0:  # 战斗中入场（召唤/换宠）
				_views[u.uid].pop_in()
		_views[u.uid].sync(u)
	var gone: Array = []
	for uid in _views:
		if sim.unit_by_uid(int(uid)) == null:  # 已离场（换宠退场）
			gone.append(uid)
	for uid in gone:
		(_views[uid] as UnitView).vanish()
		_views.erase(uid)


# ================= 主循环 =================
func _process(delta: float) -> void:
	if sim.finished:
		if not _finished_ui:
			_finished_ui = true
			_sync_views()
			_show_result()
		return
	_acc += delta * speed
	while _acc >= TICK_SEC:
		_acc -= TICK_SEC
		sim.step()
		_consume_events()
		if sim.finished:
			break
	_sync_views()
	_refresh_hud()


func _consume_events() -> void:
	for e in sim.events:
		_on_event(e)
	sim.events.clear()


func _on_event(e: Dictionary) -> void:
	var t := String(e.t)
	var src: UnitView = _views.get(int(e.get("src", -1)))
	var dst: UnitView = _views.get(int(e.get("uid", -1)))
	match t:
		"basic", "cast":
			if src != null and dst != null and t == "basic":
				src.lunge(dst.position)
		"cast_start":
			var role := sim.role_unit()
			if role != null and int(e.uid) == role.uid:
				_show_tip("%s · %s" % [role.name, String(e.get("name", ""))])
			if src != null:
				src.cast_glow()
		"dmg":
			if dst != null:
				var amount := int(e.amount)
				if bool(e.get("crit", false)):
					dst.hit_flash()
					_float(dst.position, "暴 %d" % amount, Color("ffd24a"), G.FS_LG)
				elif bool(e.get("dot", false)):
					dst.hit_flash(0.4)
					_float(dst.position, "%d" % amount, Color("c9c9c9"), G.FS_XS)
				else:
					dst.hit_flash()
					_float(dst.position, "%d" % amount, Color("ff7a6a"), G.FS_MD)
		"heal":
			if dst != null:
				_float(dst.position, "+%d" % int(e.amount), Color("8ce89c"), G.FS_MD)
		"shield_add":
			if dst != null:
				_float(dst.position, "+盾", Color("8cc4ff"), G.FS_SM)
		"cleanse":
			if dst != null:
				_float(dst.position, "净化", Color("cfe8ff"), G.FS_SM)
		"immune":
			if dst != null:
				_float(dst.position, "免疫", Color("ffffff"), G.FS_SM)
		"death":
			if dst != null:
				dst.die()
		"deathproof":
			if dst != null:
				_float(dst.position, "不死", Color("ffe08a"), G.FS_LG)
		"second_wind":
			if dst != null:
				_float(dst.position, "回光返照", Color("ffe08a"), G.FS_LG)
		"buff":
			if dst != null:
				_float(dst.position, BUFF_ABBR.get(String(e.get("buff", "")), "?"),
					Color("a8d8ff"), G.FS_XS)
		"proc":
			if dst != null:
				_float(dst.position, BUFF_ABBR.get(String(e.get("buff", "")), "?"),
					Color("d8a8ff"), G.FS_XS)
		"knockback":
			if dst != null:
				_float(dst.position, "击退", Color("ffd0a0"), G.FS_SM)
		"summon":
			_show_tip("敌方召唤 reinforcements！")
		"pet_enter":
			_show_tip("替补宠物入场")
		"pet_leave":
			pass
		"victory", "defeat", "timeout":
			pass


func _refresh_hud() -> void:
	# 能量
	var role := sim.role_unit()
	if role != null:
		var ratio := float(role.energy) / float(Combatant.MAX_ENERGY)
		_energy_fill.size.x = 432.0 * ratio
		_energy_l.text = "能量 %d/100%s" % [role.energy, "  满" if role.energy >= Combatant.MAX_ENERGY else ""]
	# 技能格（CD 数字 + 可用性）
	for sbd in _skill_btns:
		var skill: Dictionary = sbd.skill
		var cd := _skill_cd(role, String(skill.get("id", "")))
		var cd_l: Label = sbd.cd_l
		var btn: PanelContainer = sbd.btn
		if cd > 0:
			cd_l.modulate.a = 1.0
			cd_l.text = "%.1f" % (float(cd) / 30.0)
			btn.modulate = Color(0.6, 0.6, 0.6)
		elif role != null and int(skill.get("cost", 0)) > role.energy:
			cd_l.modulate.a = 0.0
			btn.modulate = Color(0.75, 0.7, 0.6)
		else:
			cd_l.modulate.a = 0.0
			btn.modulate = Color.WHITE
	# 药剂 / 换宠
	_potion_l.text = "药剂 ×%d" % sim.potions_left
	if _pet_btn != null:
		_chip_set_active(_pet_btn, not sim.pet_swap_used and sim.pet_bench_id != "")


func _skill_cd(role: Combatant, sid: String) -> int:
	if role == null:
		return 0
	for s in role.skills:
		if String(s.def.get("id", "")) == sid:
			return int(s.cd_left)
	return 0


# ================= 操作 =================
func _try_cast(sid: String) -> void:
	if sim.finished:
		return
	var role := sim.role_unit()
	if role == null or not role.alive:
		return
	if sim.cast_skill(role.uid, sid):
		_consume_events()  # 立即消费 cast_start 提示


func _use_potion() -> void:
	if sim.use_potion():
		_consume_events()


func _swap_pet() -> void:
	if sim.swap_pet():
		_consume_events()
		_sync_views()


func _on_speed(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		speed = 2.0 if speed == 1.0 else 1.0
		_chip_set_active(_speed_btn, speed == 2.0)
		(_speed_btn.get_child(0) as Label).text = "速度 ×%d" % int(speed)


func _on_auto(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		sim.auto_mode = not sim.auto_mode
		_chip_set_active(_auto_btn, sim.auto_mode)


# ================= 飘字 / 提示 =================
func _float(pos: Vector2, text: String, color: Color, size := 16) -> void:
	var l := G.gold_label(text, size, true, color)
	l.position = pos + Vector2(randf_range(-14.0, 2.0), -44.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 36.0, 0.85).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


func _show_tip(msg: String) -> void:
	_cast_tip.text = msg
	_cast_tip.modulate.a = 1.0
	if _tip_tween != null and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_tween = _cast_tip.create_tween()
	_tip_tween.tween_interval(1.0)
	_tip_tween.tween_property(_cast_tip, "modulate:a", 0.0, 0.35)


# ================= 结算 =================
func _show_result() -> void:
	var win := sim.result == "victory"
	var role := sim.role_unit()
	var hp_left := role.hp if role != null else 0

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := G.parchment_box(380, 316, 24.0)
	panel.position = Vector2(50, 232)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	box.add_child(G.serif_label("胜  利" if win else "战  败", G.FS_HERO,
		Color("6a8a4a") if win else Color("8a4a3a")))
	box.add_child(G.gold_label("残存生命 %d" % hp_left, G.FS_SM, false, Color("7a5a2e"), false))

	if win:
		var nt: String = String(_cfg.get("enemy", {}).get("node_type", "normal"))
		var rw: Dictionary = TableCache.nodes_config().get("rewards", {}).get(nt, {})
		var lines := PackedStringArray()
		if rw.has("gold"):
			lines.append("金币 +%d" % int(rw.gold))
		if rw.has("expedition"):
			lines.append("远征币 +%d" % int(rw.expedition))
		if rw.has("soul"):
			lines.append("灵魂石 +%d" % int(rw.soul))
		if rw.has("exp"):
			lines.append("经验 +%d" % int(rw.exp))
		box.add_child(G.gold_label("  ·  ".join(lines), G.FS_SM, false, Color("8a6a34"), false))

	var btn := G.gold_button("继 续", 200, 48)
	btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			confirm_result())
	box.add_child(btn)


## 结算确认（远征循环 #7 接管信号；无监听时回主界面——冒烟入口）
func confirm_result() -> void:
	var role := sim.role_unit()
	var hp_left := role.hp if role != null else 0
	battle_finished.emit(sim.result, hp_left)
	if battle_finished.get_connections().is_empty():
		get_tree().change_scene_to_file("res://src/ui/GameHome.tscn")


# ================= 局部绘制 =================
class _LineDrawer extends Node2D:
	var color := Color.WHITE
	func _draw() -> void:
		draw_line(Vector2(24, 0), Vector2(456, 0), color, 2.0)


# ================= 单位视图（Node2D 自绘 + 复用人物行走帧） =================
class UnitView extends Node2D:
	var uid := 0
	var side := ""
	var is_role := false
	var body := Node2D.new()          # 位移/闪白的载体
	var sprite: AnimatedSprite2D = null
	var hp_bg := ColorRect.new()
	var hp_fg := ColorRect.new()
	var name_l := Label.new()
	var buff_l := Label.new()
	var _base_pos := Vector2.ZERO
	var _dead := false
	var _radius := 22.0
	var _draw_color := Color.WHITE
	var _is_blob := false            # 怪/宠 = 程序圆体；role = 精灵


	func setup(u: Combatant, role_sprites: Dictionary, mon_colors: Dictionary) -> void:
		uid = u.uid
		side = u.side
		is_role = u.kind == "role"
		add_child(body)
		if is_role:
			var cfg: Array = role_sprites.get(String(u.data.get("id", "")), [])
			if cfg.size() == 2:
				var frames: SpriteFrames = load(String(cfg[0]))
				if frames != null:
					sprite = AnimatedSprite2D.new()
					sprite.sprite_frames = frames
					sprite.animation = &"walk_down"
					sprite.scale = Vector2.ONE * 0.55
					sprite.position = Vector2(0, -26)
					body.add_child(sprite)
		else:
			_is_blob = true
			if u.kind == "monster":
				var tier := String(u.data.get("tier", "normal"))
				_draw_color = mon_colors.get(tier, Color.GRAY)
				_radius = 34.0 if tier == "boss" else (27.0 if tier == "elite" else 22.0)
			else:  # 宠物：金边小圆
				_draw_color = Color("9a7a3a")
				_radius = 17.0
			var blob := _Blob.new()
			blob.radius = _radius
			blob.color = _draw_color
			body.add_child(blob)
			body.position = Vector2(0, -_radius * 0.4)
		# 名字
		name_l = G.gold_label(u.name, G.FS_XS, false,
			Color("ffd0d0") if side == "enemy" else Color("c8e8c8"), false)
		name_l.position = Vector2(-36, -_radius - 34 if _is_blob else -92)
		name_l.custom_minimum_size = Vector2(72, 0)
		body.add_child(name_l)
		# HP 条
		hp_bg.color = Color(0, 0, 0, 0.55)
		hp_bg.position = Vector2(-22, _hp_bar_y())
		hp_bg.size = Vector2(44, 5)
		body.add_child(hp_bg)
		hp_fg.color = Color("e05a4a") if side == "enemy" else Color("5ab464")
		hp_fg.position = hp_bg.position + Vector2(1, 1)
		hp_fg.size = Vector2(42, 3)
		body.add_child(hp_fg)
		# buff 缩写
		buff_l = G.gold_label("", G.FS_XS, false, Color("a8d8ff"), false)
		buff_l.position = Vector2(-36, _hp_bar_y() + 7)
		buff_l.custom_minimum_size = Vector2(72, 0)
		body.add_child(buff_l)


	func _hp_bar_y() -> float:
		return -_radius - 20.0 if _is_blob else -12.0


	func sync(u: Combatant) -> void:
		if _dead:
			return
		_base_pos = _owner_grid(u)
		position = _base_pos
		var ratio := clampf(float(u.hp) / float(maxi(u.get_max_hp(), 1)), 0.0, 1.0)
		hp_fg.size.x = 42.0 * ratio
		var abbrs := PackedStringArray()
		for b in u.buffs:
			var a: String = BattleScene.BUFF_ABBR.get(String(b.type), "")
			if a != "" and not a in abbrs:
				abbrs.append(a)
		buff_l.text = " ".join(abbrs)
		if not u.alive:
			die()


	func _owner_grid(u: Combatant) -> Vector2:
		var x := BattleScene.COL_X + u.col * BattleScene.COL_GAP
		if u.side == "enemy":
			return Vector2(x, BattleScene.ENEMY_BACK_Y if u.row == 1 else BattleScene.ENEMY_FRONT_Y)
		return Vector2(x, BattleScene.ALLY_BACK_Y if u.row == 1 else BattleScene.ALLY_FRONT_Y)


	func lunge(target_pos: Vector2) -> void:
		var dir := (target_pos - _base_pos).normalized() * 16.0
		var tw := body.create_tween()
		tw.tween_property(body, "position", dir, 0.09).set_ease(Tween.EASE_OUT)
		tw.tween_property(body, "position", Vector2.ZERO, 0.14).set_ease(Tween.EASE_IN)


	func cast_glow() -> void:
		var old := body.modulate
		var tw := body.create_tween()
		tw.tween_property(body, "modulate", Color(1.4, 1.3, 0.9), 0.08)
		tw.tween_property(body, "modulate", old, 0.2)


	func hit_flash(strength := 1.0) -> void:
		var old := body.modulate
		var tw := body.create_tween()
		tw.tween_property(body, "modulate", Color(2.2, 0.7, 0.7).lerp(old, 1.0 - strength), 0.05)
		tw.tween_property(body, "modulate", old, 0.18)


	func pop_in() -> void:
		scale = Vector2(0.2, 0.2)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


	func die() -> void:
		if _dead:
			return
		_dead = true
		buff_l.text = ""
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.6)
		tw.tween_property(self, "scale", Vector2(0.85, 0.7), 0.6)


	func vanish() -> void:
		if _dead:
			queue_free()
			return
		_dead = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)


	## 怪物/宠物占位体（手绘感圆身 + 眼睛；精灵素材入库后替换）
	class _Blob extends Node2D:
		var radius := 22.0
		var color := Color.GRAY

		func _draw() -> void:
			draw_circle(Vector2(0, radius * 0.15), radius * 1.05, Color(0, 0, 0, 0.3))  # 底影
			draw_circle(Vector2.ZERO, radius, color)
			draw_circle(Vector2(-radius * 0.32, -radius * 0.18), radius * 0.14, Color(0.1, 0.08, 0.06))
			draw_circle(Vector2(radius * 0.32, -radius * 0.18), radius * 0.14, Color(0.1, 0.08, 0.06))
			draw_circle(Vector2(-radius * 0.27, -radius * 0.23), radius * 0.05, Color.WHITE)
			draw_circle(Vector2(radius * 0.37, -radius * 0.23), radius * 0.05, Color.WHITE)
