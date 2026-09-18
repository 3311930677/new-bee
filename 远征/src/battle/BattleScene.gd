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

# ---------- 打击感参数（只影响表现，不动 sim 规则） ----------
const HITSTOP_STEP := 0.07      # 一次顿帧的时长（秒）
const HITSTOP_SLOW := 0.18      # 顿帧期间的时间倍率（越小越"重"）
const HEAVY_RATIO := 0.12       # 单次伤害 ≥ 目标最大生命这个比例 → 算重击（顿帧 + 震屏）
const SHAKE_HEAVY := 7.0
const SHAKE_CRIT := 4.5
const SHAKE_HIT := 2.0
const LOW_HP_RATIO := 0.25      # 角色血量低于此比例 → 边缘红晕脉动

## 场景切入前由调用方写入（远征循环 #7 落地前的冒烟入口也走此通道）
static var pending_cfg: Dictionary = {}

var sim := BattleSim.new()
var speed := 1.0

var _acc := 0.0
var _views: Dictionary = {}          # uid -> UnitView
var _shake_root := Control.new()     # 背景 + 战场（震屏只抖这一层，HUD 不跟着晃）
var _field := Node2D.new()           # 战场（单位 + 地面）
var _fx_layer := Control.new()       # 飘字层（最上）
var _hitstop := 0.0                  # 顿帧剩余秒数
var _shake_tw: Tween = null
var _danger: TextureRect = null      # 低血红晕（挂在根节点，别放进飘字层：那儿会被清空断言检查）
var _danger_tip_done := false
var _dmg_out := 0                    # 我方造成的总伤害（战报用）
var _dmg_in := 0                     # 我方承受的总伤害
var _best_hit := 0                   # 我方最高单击
var _skill_btns: Array[Dictionary] = []  # {btn, name_l, cd_l, skill}
var _energy_fill := ColorRect.new()
var _energy_l := Label.new()
var _potion_l := Label.new()
var _pet_btn: Control = null
var _auto_btn: Control = null
var _speed_btn: Control = null
var _flee_btn: Control = null        # 撤退按钮（二次确认要改它的文案）
var _flee_armed := false             # 撤退已上膛（3 秒内再点才真正撤退）
var _cast_tip := Label.new()
var _tip_tween: Tween = null
var _combo_tip := Label.new()      # 连携窗口提示（能量条上方）
var _finished_ui := false
var _cfg: Dictionary = {}


func _ready() -> void:
	Audio.play_bgm("bgm_battle")
	_cfg = pending_cfg
	pending_cfg = {}
	sim.record_events = true
	var seed_v: int = int(_cfg.get("seed", 0))
	if seed_v == 0:
		seed_v = randi()
	sim.setup(seed_v, _cfg.get("ally", {}), _cfg.get("enemy", {}))
	sim.events.clear()  # 丢弃 ready 事件
	# 先摆震屏层：背景与战场都挂在它下面，受击时整屏一晃而 HUD 纹丝不动
	_shake_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shake_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shake_root)
	_build_background()
	_build_field()
	_build_danger_overlay()
	_build_top_bar()
	_build_skill_bar()
	_build_func_row()
	_sync_views()
	sim.events.clear()


# ================= 布局 =================
func _build_background() -> void:
	# 战斗背景：优先接主题 bg_battle_* 竖版手绘（971×1619，与 480×800 同比例）；
	# 无素材时回退主题 tint 底色 + tile 平铺地面
	var theme: String = String(_cfg.get("enemy", {}).get("theme", "forest"))
	var tc := TableCache.theme_config(theme)
	var bg_tex: Texture2D = G.res_tex(String(tc.get("battle_bg", "")))
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 必须在 size 前：否则被钳到原图尺寸
		bg.size = Vector2(VIEW_W, VIEW_H)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shake_root.add_child(bg)
		_add_shade_gradient(0.0, 96.0, true)     # 顶部压暗（标题可读）
		_add_shade_gradient(520.0, 280.0, false)  # 底部压暗（技能区可读）
	else:
		var tint := Color(String(tc.get("tint", "ffffff")))
		var flat := ColorRect.new()
		flat.color = Color(tint.r * 0.22, tint.g * 0.22, tint.b * 0.24)
		flat.size = Vector2(VIEW_W, VIEW_H)
		flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shake_root.add_child(flat)
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


## 上下缘压暗渐变（叠加在手绘背景上，保证 UI 文字对比度；不遮战场中区）
func _add_shade_gradient(y: float, h: float, top: bool) -> void:
	var grad := Gradient.new()
	var dark := Color(0.03, 0.02, 0.01, 0.5)
	grad.colors = PackedColorArray([dark, Color(dark.r, dark.g, dark.b, 0.0)]) if top \
		else PackedColorArray([Color(dark.r, dark.g, dark.b, 0.0), dark])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.position = Vector2(0, y)
	shade.size = Vector2(VIEW_W, h)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_field() -> void:
	_shake_root.add_child(_field)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fx_layer)


## 低血红晕：角色血量掉到阈值以下时脉动。挂在根节点靠前的位置（在 HUD 之下），
## 别放进 _fx_layer——那里会被"战斗结束后飘字层应清空"的断言检查。
func _build_danger_overlay() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	grad.colors = PackedColorArray([
		Color(0.62, 0.06, 0.06, 0.0), Color(0.62, 0.06, 0.06, 0.0),
		Color(0.78, 0.05, 0.05, 0.9),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 120
	tex.height = 200
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_danger = TextureRect.new()
	_danger.texture = tex
	_danger.size = Vector2(VIEW_W, VIEW_H)
	_danger.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 项目默认 nearest，放大必须改线性
	_danger.modulate.a = 0.0
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger)


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

	# 连携窗口提示：上一手命中 combo.first 且未过窗口 → 常驻小签提示"下一手"
	_combo_tip = G.serif_label("", G.FS_SM, G.GOLD_BRIGHT)
	_combo_tip.position = Vector2(0, 576)
	_combo_tip.custom_minimum_size = Vector2(VIEW_W, 0)
	_combo_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_tip.modulate.a = 0.0
	add_child(_combo_tip)

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
		# 技能图标（sk_<id>；无素材留空位）
		var icon_tex: Texture2D = G.res_tex("sk_%s" % String(skill.get("id", "")))
		if icon_tex != null:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.custom_minimum_size = Vector2(42, 42)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.add_child(icon)
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
	# 撤退（放弃本节点；二次确认防手滑）
	_flee_btn = _func_chip("撤退", 86)
	_flee_btn.position = Vector2(23 + 3 * 96.0, 724)
	_flee_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_flee())
	add_child(_flee_btn)


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
	# 顿帧衰减放在最前：结算那一帧也要把它收干净，别留下一个"粘住"的慢动作
	var time_scale := 1.0
	if _hitstop > 0.0:
		_hitstop = maxf(0.0, _hitstop - delta)
		time_scale = lerpf(1.0, HITSTOP_SLOW, clampf(_hitstop / HITSTOP_STEP, 0.0, 1.0))
	if sim.finished:
		if not _finished_ui:
			_finished_ui = true
			_stop_shake()
			_sync_views()
			_show_result()
		return
	_acc += delta * speed * time_scale
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
			# 连携触发：施法者头顶飘"连携"金字（e.combo 为连携名）
			if t == "cast" and String(e.get("combo", "")) != "":
				var cu: UnitView = _views.get(int(e.get("uid", -1)))
				if cu != null:
					_float(cu.position + Vector2(0, -44), "连携 · %s" % String(e.combo),
						Color("ffd97a"), G.FS_LG)
		"cast_start":
			var role := sim.role_unit()
			if role != null and int(e.uid) == role.uid:
				_show_tip("%s · %s" % [role.name, String(e.get("name", ""))])
				Audio.sfx("skill_cast")
			else:
				# 敌方施法必须看得见：被打了却不知道对方放了什么，战斗就成了看血条
				var tier := "normal"
				var caster := sim.unit_by_uid(int(e.get("uid", -1)))
				if caster != null:
					tier = String(caster.data.get("tier", "normal"))
				if tier == "boss":
					_show_tip("首领技 · %s" % String(e.get("name", "")), Color("ff8a6a"))
					_shake(SHAKE_HIT * 0.7)   # 首领抬手先晃一下，算预警
					Audio.sfx("boss_warn")
				else:
					_show_tip("敌方 · %s" % String(e.get("name", "")), Color("ffb0a0"))
					Audio.sfx("skill_cast", 0.06)   # 敌方普通施法也给声，抖动大一点免得与我方混淆
			if src != null:
				src.cast_glow()
		"dmg":
			var target := sim.unit_by_uid(int(e.get("uid", -1)))
			if dst == null:
				pass
			elif target == null:
				dst.hit_flash()
				_float(dst.position, "%d" % int(e.amount), Color("ff7a6a"), G.FS_MD)
			else:
				var amount := int(e.amount)
				var crit := bool(e.get("crit", false))
				var dot := bool(e.get("dot", false))
				var max_hp := maxi(target.get_max_hp(), 1)
				var heavy := amount >= int(float(max_hp) * HEAVY_RATIO)
				var role_u := sim.role_unit()
				var from_role := role_u != null and int(e.get("src", -1)) == role_u.uid
				var to_role := role_u != null and int(e.get("uid", -1)) == role_u.uid
				if from_role:
					_dmg_out += amount
					_best_hit = maxi(_best_hit, amount)
				if to_role:
					_dmg_in += amount
				if dot:
					dst.hit_flash(0.4)
					_float_dmg(dst.position, amount, "dot")
				elif crit:
					dst.hit_flash()
					_float_dmg(dst.position, amount, "crit")
					_shake(SHAKE_CRIT)
					_hit_stop(HITSTOP_STEP)
					Audio.sfx("hit_crit")
				elif heavy:
					dst.hit_flash()
					_float_dmg(dst.position, amount, "heavy")
					_shake(SHAKE_HEAVY)
					_hit_stop(HITSTOP_STEP)
					Audio.sfx("hit_heavy")
				else:
					dst.hit_flash()
					_float_dmg(dst.position, amount, "hit")
					Audio.sfx("hit_light")
					if to_role:
						_shake(SHAKE_HIT)   # 自己挨打也晃一下：让"被打"有实感
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
	# 低血警示：边缘红晕脉动（首次再补一句提示，之后只靠视觉，不吵）
	if _danger != null:
		var hp_ratio := 0.0
		if role != null:
			hp_ratio = float(role.hp) / float(maxi(role.get_max_hp(), 1))
		var low := role != null and role.alive and hp_ratio < LOW_HP_RATIO
		if low:
			var phase := float(Time.get_ticks_msec() % 1100) / 1100.0
			_danger.modulate.a = 0.20 + 0.32 * absf(sin(phase * PI))   # 边缘红晕：够警觉不糊屏
			if not _danger_tip_done:
				_danger_tip_done = true
				_show_tip("危急 · 血量过低，补药或撤退", Color("ff9a8a"))
				Audio.sfx("low_hp")
		else:
			_danger.modulate.a = 0.0
	# 连携可视化：窗口内的"下一手"技能格亮金粗框 + 能量条上方小签
	var combo_sid := _combo_next()
	var combo_row := _combo_row(combo_sid)
	if combo_sid != "" and role != null:
		var sname := combo_sid
		for s in role.skills:
			if String(s.def.get("id", "")) == combo_sid:
				sname = String(s.def.get("name", combo_sid))
				break
		var last: Dictionary = sim.last_cast.get(role.uid, {})
		var left_s := 0.0
		if not last.is_empty():
			left_s = float(combo_row.get("window", 5.0)) - float(sim.tick_count - int(last.get("tick", 0))) / 30.0
		_combo_tip.text = "连携 · %s %.1fs" % [sname, maxf(0.0, left_s)]
		_combo_tip.modulate.a = 1.0
	else:
		_combo_tip.modulate.a = 0.0
	# 技能格（CD 数字 + 可用性）
	for sbd in _skill_btns:
		var skill: Dictionary = sbd.skill
		var cd := _skill_cd(role, String(skill.get("id", "")))
		var cd_l: Label = sbd.cd_l
		var btn: PanelContainer = sbd.btn
		# 连携"下一手"：亮金粗边（即使 CD 中也亮，提示玩家这是连携目标）
		var sb: StyleBoxFlat = btn.get_theme_stylebox("panel")
		if String(skill.get("id", "")) == combo_sid:
			sb.border_color = G.GOLD_BRIGHT
			sb.set_border_width_all(3)
		else:
			sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.4)
			sb.set_border_width_all(2)
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
	# 药剂 / 换宠（药剂 CD 中显示剩余秒数）
	if sim.potion_cd_ticks > 0:
		_potion_l.text = "药剂 %.0fs" % (float(sim.potion_cd_ticks) / 30.0)
	else:
		_potion_l.text = "药剂 ×%d" % sim.potions_left
	if _pet_btn != null:
		_chip_set_active(_pet_btn, not sim.pet_swap_used and sim.pet_bench_id != "")


## 当前连携窗口内的"下一手"技能 id（上一手命中 combo.first 且窗口未过；无则空串）
func _combo_next() -> String:
	var role := sim.role_unit()
	if role == null:
		return ""
	var last: Dictionary = sim.last_cast.get(role.uid, {})
	if last.is_empty():
		return ""
	var last_id := String(last.get("skill_id", ""))
	if last_id == "":
		return ""
	var elapsed := sim.tick_count - int(last.get("tick", -99999))
	for c in TableCache.combos():
		if String(c.get("first", "")) == last_id \
				and elapsed <= int(float(c.get("window", 5.0)) * 30.0):
			return String(c.get("then", ""))
	return ""


## then == sid 的连携配置行（取 name/window 用；无则空字典）
func _combo_row(sid: String) -> Dictionary:
	if sid == "":
		return {}
	for c in TableCache.combos():
		if String(c.get("then", "")) == sid:
			return c
	return {}


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


## 撤退二次确认：首点变"确认撤退？"并亮起，3 秒内再点才真正撤退（超时自动解除）
func _on_flee() -> void:
	if sim.finished:
		return
	if _flee_armed:
		sim.finished = true
		sim.result = "defeat"
		return
	_flee_armed = true
	if _flee_btn != null:
		var l := _flee_btn.get_child(0) as Label
		if l != null:
			l.text = "确认撤退？"
		_chip_set_active(_flee_btn, true)
	get_tree().create_timer(3.0).timeout.connect(func():
		if _flee_armed and _flee_btn != null and is_instance_valid(_flee_btn):
			_flee_armed = false
			var l2 := _flee_btn.get_child(0) as Label
			if l2 != null:
				l2.text = "撤退"
			_chip_set_active(_flee_btn, false)
		else:
			_flee_armed = false)


func _on_speed(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		speed = 2.0 if speed == 1.0 else 1.0
		_chip_set_active(_speed_btn, speed == 2.0)
		(_speed_btn.get_child(0) as Label).text = "速度 ×%d" % int(speed)


func _on_auto(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		sim.auto_mode = not sim.auto_mode
		_chip_set_active(_auto_btn, sim.auto_mode)


# ================= 打击感（顿帧 / 震屏） =================
## 顿帧：重击瞬间把 sim 步进压慢一档（几十毫秒内回弹）。只改步进倍率，
## 玩家的 ×1/×2 速度设置不受影响，sim 规则也一行没动。
func _hit_stop(sec: float) -> void:
	_hitstop = maxf(_hitstop, sec)


## 震屏：只抖「背景 + 战场」这一层，HUD 与飘字不动（字跟着晃会花）
func _shake(power: float) -> void:
	if _shake_tw != null and _shake_tw.is_valid():
		_shake_tw.kill()
	var tw := create_tween()
	for i in 4:
		var amp := power * (1.0 - float(i) / 4.0)
		tw.tween_property(_shake_root, "position",
			Vector2(randf_range(-amp, amp), randf_range(-amp * 0.6, amp * 0.6)), 0.035)
	tw.tween_property(_shake_root, "position", Vector2.ZERO, 0.05)
	_shake_tw = tw


## 收招：结算时把震屏层强制归位（否则最后一击若正抖着，战场会一直歪着）
func _stop_shake() -> void:
	if _shake_tw != null and _shake_tw.is_valid():
		_shake_tw.kill()
	_shake_root.position = Vector2.ZERO


# ================= 飘字 / 提示 =================
## 飘字：pop > 1 时先小后"弹"到目标大小（数字有生命感，不是静态贴纸）
func _float(pos: Vector2, text: String, color: Color, size := 16, pop := 1.0) -> void:
	var l := G.gold_label(text, size, true, color)
	l.position = pos + Vector2(randf_range(-14.0, 2.0), -44.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.pivot_offset = Vector2(30.0, float(size) * 0.6)
	l.scale = Vector2.ONE * (pop * 0.7)
	_fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 36.0, 0.85).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.35)
	if not is_equal_approx(pop, 1.0):
		tw.tween_property(l, "scale", Vector2.ONE * pop, 0.12)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(l.queue_free)


## 伤害飘字分层：暴击最大最亮、重击次之、普通居中、持续伤害最淡最静
## —— 一眼分得出"这一下有多重"，而不是所有数字一个样
func _float_dmg(pos: Vector2, amount: int, kind: String) -> void:
	match kind:
		"crit":
			_float(pos, "暴 %d" % amount, Color("ffd24a"), G.FS_LG + 4, 1.32)
		"heavy":
			_float(pos, "%d" % amount, Color("ff9a6a"), G.FS_LG, 1.18)
		"dot":
			_float(pos, "%d" % amount, Color("b9b3aa"), G.FS_XS, 1.0)
		_:
			_float(pos, "%d" % amount, Color("ff7a6a"), G.FS_MD, 1.06)


func _show_tip(msg: String, color := Color("ffe9b0")) -> void:
	_cast_tip.add_theme_color_override("font_color", color)
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
	Audio.sfx("victory" if win else "defeat", 0.0)   # 结算音不抖音高：这是"定局"，不是随机反馈

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
	# 战报：打了多久、最高单击多少、谁在输出 —— 表现层统计（sim 规则未动）
	var secs := float(sim.tick_count) / 30.0
	box.add_child(G.gold_label("战报 · 用时 %.1fs · 最高单击 %d · 输出 %d · 承伤 %d"
		% [secs, _best_hit, _dmg_out, _dmg_in], G.FS_XS, false, Color("8a6a34"), false))

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
	var sprite: Node2D = null         # 角色 AnimatedSprite2D / 怪宠 Sprite2D
	var hp_bg := ColorRect.new()
	var hp_fg := ColorRect.new()
	var name_l := Label.new()
	var buff_l := Label.new()
	var _base_pos := Vector2.ZERO
	var _dead := false
	var _radius := 22.0
	var _draw_color := Color.WHITE
	var _is_blob := false            # 怪/宠无素材时回退程序圆体


	func setup(u: Combatant, role_sprites: Dictionary, mon_colors: Dictionary) -> void:
		uid = u.uid
		side = u.side
		is_role = u.kind == "role"
		add_child(body)
		var name_y := 0.0   # 名字 y（头顶上方）
		var hp_y := 0.0     # 血条 y（脚下）
		if is_role:
			var cfg: Array = role_sprites.get(String(u.data.get("id", "")), [])
			if cfg.size() == 2:
				var frames: SpriteFrames = load(String(cfg[0]))
				if frames != null:
					var asp := AnimatedSprite2D.new()
					asp.sprite_frames = frames
					asp.animation = &"walk_down"
					asp.scale = Vector2.ONE * 0.55
					asp.position = Vector2(0, -26)
					body.add_child(asp)
					sprite = asp
			# 行走帧 128×128 × 0.55：占位 -61~+9
			name_y = -75.0
			hp_y = 12.0
		else:
			var unit_id := String(u.data.get("id", ""))
			var tex: Texture2D = G.res_tex(unit_id)
			if tex != null:
				# 精灵素材（1254×1254 透明底，自带投影）：按档位缩放到目标身高
				var disp_h := 78.0
				if u.kind == "monster":
					var tier := String(u.data.get("tier", "normal"))
					disp_h = 128.0 if tier == "boss" else (94.0 if tier == "elite" else 78.0)
				else:
					disp_h = 64.0
				var sp := Sprite2D.new()
				sp.texture = tex
				sp.scale = Vector2.ONE * (disp_h / float(tex.get_height()))
				sp.position = Vector2(0, -disp_h * 0.42)  # 脚底落在站位附近
				if u.kind == "monster" and String(u.data.get("tier", "")) == "elite":
					sp.modulate = Color(1.06, 0.95, 1.12)  # 精英微紫晕（保档位辨识）
				body.add_child(sp)
				sprite = sp
				name_y = sp.position.y - disp_h * 0.5 - 14.0
				hp_y = sp.position.y + disp_h * 0.5 + 6.0
			else:
				# 回退：程序圆体
				_is_blob = true
				var blob := _Blob.new()
				if u.kind == "monster":
					var tier := String(u.data.get("tier", "normal"))
					_draw_color = mon_colors.get(tier, Color.GRAY)
					_radius = 34.0 if tier == "boss" else (27.0 if tier == "elite" else 22.0)
					blob.tier = tier
				else:  # 宠物：金边小伙伴
					_draw_color = Color("9a7a3a")
					_radius = 17.0
					blob.tier = "pet"
				blob.radius = _radius
				blob.color = _draw_color
				blob.seed = uid * 73 + 11
				body.add_child(blob)
				body.position = Vector2(0, -_radius * 0.4)
				name_y = -_radius - 14.0
				hp_y = _radius + 6.0
		# 名字（头顶）
		name_l = G.gold_label(u.name, G.FS_XS, false,
			Color("ffd0d0") if side == "enemy" else Color("c8e8c8"), false)
		name_l.position = Vector2(-36, name_y)
		name_l.custom_minimum_size = Vector2(72, 0)
		body.add_child(name_l)
		# HP 条（脚下）
		hp_bg.color = Color(0, 0, 0, 0.55)
		hp_bg.position = Vector2(-22, hp_y)
		hp_bg.size = Vector2(44, 5)
		body.add_child(hp_bg)
		hp_fg.color = Color("e05a4a") if side == "enemy" else Color("5ab464")
		hp_fg.position = hp_bg.position + Vector2(1, 1)
		hp_fg.size = Vector2(42, 3)
		body.add_child(hp_fg)
		# buff 缩写（血条正下）
		buff_l = G.gold_label("", G.FS_XS, false, Color("a8d8ff"), false)
		buff_l.position = Vector2(-36, hp_y + 7)
		buff_l.custom_minimum_size = Vector2(72, 0)
		body.add_child(buff_l)


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


	## 怪物/宠物程序体：有机多瓣轮廓 + 呼吸 + 尖角/耳朵（与探索图怪同族画法）
	class _Blob extends Node2D:
		var radius := 22.0
		var color := Color.GRAY
		var tier := "normal"   # normal / elite / boss / pet
		var seed := 1
		var _lobe := PackedFloat32Array()
		var _t := 0.0

		func _ready() -> void:
			var h := float(seed % 97) * 0.0628
			for i in 18:
				_lobe.append(sin(i * 2.1 + h) * 0.13 + sin(i * 0.7 + h * 0.5) * 0.09)

		func _process(delta: float) -> void:
			_t += delta
			queue_redraw()

		func _draw() -> void:
			var breathe := 1.0 + sin(_t * 2.2 + float(seed)) * 0.03
			var r := radius * breathe
			# 底影
			draw_set_transform(Vector2(0, r * 0.85), 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, r * 1.05, Color(0, 0, 0, 0.30))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# 有机身体：18 瓣轮廓
			var pts := PackedVector2Array()
			for i in 18:
				var a := TAU * i / 18.0
				var rr := r * (1.0 + _lobe[i])
				pts.append(Vector2(cos(a), sin(a) * 0.94) * rr)
			draw_colored_polygon(pts, color)
			# 腹部压暗 + 顶部受光
			var belly := PackedVector2Array()
			for i in 18:
				var a := TAU * i / 18.0
				if sin(a) > 0.1:
					belly.append(Vector2(cos(a), sin(a) * 0.94) * r * (0.98 + _lobe[i]))
			if belly.size() >= 3:
				belly.append(Vector2.ZERO)
				draw_colored_polygon(belly, color.darkened(0.18))
			draw_arc(Vector2(0, -r * 0.28), r * 0.52, PI * 1.15, PI * 1.85, 12,
				color.lightened(0.25), 3.0)
			if tier == "pet":
				_draw_pet_charm(r)
			else:
				_draw_monster_face(r)

		func _draw_monster_face(r: float) -> void:
			# 尖角按档位
			if tier == "elite" or tier == "boss":
				var horn := color.lightened(0.35)
				var horn_len := r * (0.62 if tier == "boss" else 0.45)
				for side in [-1, 1]:
					var bx: float = side * r * 0.42
					draw_colored_polygon(PackedVector2Array([
						Vector2(bx - side * 4, -r * 0.62), Vector2(bx + side * 5, -r * 0.58),
						Vector2(bx + side * 2, -r * 0.62 - horn_len)]), horn)
			# 眼：boss 发红光
			var eye_col := Color("ff5a4a") if tier == "boss" else Color(0.1, 0.08, 0.06)
			var eye_r := r * (0.16 if tier == "boss" else 0.13)
			if tier == "boss":
				draw_circle(Vector2(-r * 0.32, -r * 0.14), eye_r * 1.8, Color(1, 0.3, 0.2, 0.25))
				draw_circle(Vector2(r * 0.32, -r * 0.14), eye_r * 1.8, Color(1, 0.3, 0.2, 0.25))
			draw_circle(Vector2(-r * 0.32, -r * 0.14), eye_r, eye_col)
			draw_circle(Vector2(r * 0.32, -r * 0.14), eye_r, eye_col)
			draw_circle(Vector2(-r * 0.27, -r * 0.20), eye_r * 0.4, Color.WHITE)
			draw_circle(Vector2(r * 0.37, -r * 0.20), eye_r * 0.4, Color.WHITE)
			# 嘴
			draw_arc(Vector2(0, r * 0.12), r * 0.30, PI * 0.25, PI * 0.75, 8,
				color.darkened(0.45), 2.0)

		func _draw_pet_charm(r: float) -> void:
			# 耳朵
			for side in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([
					Vector2(side * r * 0.62, -r * 0.42), Vector2(side * r * 0.30, -r * 0.55),
					Vector2(side * r * 0.50, -r * 1.05)]), color.darkened(0.1))
			# 金项圈
			draw_arc(Vector2(0, r * 0.18), r * 0.72, PI * 0.2, PI * 0.8, 12,
				G.GOLD_BRIGHT, 2.5)
			# 圆眼
			draw_circle(Vector2(-r * 0.30, -r * 0.10), r * 0.15, Color(0.1, 0.08, 0.06))
			draw_circle(Vector2(r * 0.30, -r * 0.10), r * 0.15, Color(0.1, 0.08, 0.06))
			draw_circle(Vector2(-r * 0.25, -r * 0.16), r * 0.06, Color.WHITE)
			draw_circle(Vector2(r * 0.35, -r * 0.16), r * 0.06, Color.WHITE)
			# 鼻
			draw_circle(Vector2(0, r * 0.14), r * 0.09, Color("5a3a2a"))
