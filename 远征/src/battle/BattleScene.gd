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
# ---------- 底部技能栏网格（§5 网格系统：技能格与功能行共用同一列基准）----------
# 5 格 × 82 宽、列距 88 → 23..457，左右边距各 23，对称。
# 功能行（药剂/换宠/撤退）不再各自手算坐标，一律 BAR_X + n*SKILL_STEP。
const BAR_X := 23.0
const SKILL_W := 82.0
const SKILL_H := 88.0
const SKILL_STEP := 88.0
const SKILL_Y := 620.0
const FUNC_Y := 724.0
const ENEMY_BACK_Y := 148.0
const ENEMY_FRONT_Y := 226.0
const ALLY_FRONT_Y := 402.0
const ALLY_BACK_Y := 474.0

const ROLE_SPRITE := {  # 人物战斗行走帧（探索/进出场用）
	"zs": ["res://image/role/zs/pojun_walk_frames.tres", "pojun"],
	"ls": ["res://image/role/ls/chuanyang_walk_frames.tres", "chuanyang"],
	"fs": ["res://image/role/fs/shuangyu_walk_frames.tres", "shuangyu"],
}
# 战斗五态 spritesheet（4 列 × 5 行 @128px：待机/普攻/施法/受击/倒下）。
# Godot 3 的 .tres 在 4.7 下不稳，统一运行时从整图重建（与 GameHome/CreateRole 同口径）。
const ROLE_BATTLE_SHEET := {
	"zs": "res://image/role/zs/pojun_spritesheet.png",
	"ls": "res://image/role/ls/chuanyang_spritesheet.png",
	"fs": "res://image/role/fs/shuangyu_spritesheet.png",
}
const BATTLE_ROWS := [  # [动画名, 行号, 是否循环, 帧率]
	["idle", 0, true, 5.0], ["attack", 1, false, 11.0], ["cast", 2, false, 8.0],
	["hit", 3, false, 10.0], ["death", 4, false, 6.0],
]
static var _battle_frames_cache := {}

## 复刻版五态（AI 只有 A2 单帧，没有五态套图）：以单帧为底，按状态**平移/缩放**出四帧。
## 只做 blit_rect 与 resize（都在 C++ 侧，20 帧约 1~2ms）；逐像素染色在 GDScript 里要几百毫秒。
## 五态各 4 帧、格子 128×128 的接口保持不变——视图的偏移标定与 has_animation("hit") 判断照旧。
const PROC_FRAME := {
	"idle": [[Vector2i(0, 0), 1.0], [Vector2i(0, -2), 1.0], [Vector2i(0, 0), 1.0], [Vector2i(0, 1), 1.0]],
	"attack": [[Vector2i(0, 0), 1.0], [Vector2i(-6, 0), 1.0], [Vector2i(-8, -1), 1.0], [Vector2i(-3, 0), 1.0]],
	"cast": [[Vector2i(0, 0), 1.0], [Vector2i(0, -2), 1.0], [Vector2i(0, -3), 1.0], [Vector2i(0, -1), 1.0]],
	"hit": [[Vector2i(0, 0), 1.0], [Vector2i(6, 0), 1.0], [Vector2i(-6, 1), 1.0], [Vector2i(0, 0), 1.0]],
	"death": [[Vector2i(0, 0), 1.0], [Vector2i(0, 4), 0.90], [Vector2i(0, 10), 0.78], [Vector2i(0, 16), 0.62]],
}
const XA_CELL := 128

static func _xa_battle_frames(role_id: String) -> SpriteFrames:
	var tex := G.xa_combat_tex(role_id)
	if tex == null:
		return null
	var src: Image = tex.get_image()
	if src == null or src.is_empty():
		return null
	src = src.duplicate()
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for r in BATTLE_ROWS:
		var anim := StringName(r[0])
		frames.add_animation(anim)
		frames.set_animation_loop(anim, bool(r[2]))
		frames.set_animation_speed(anim, float(r[3]))
		var plan: Array = PROC_FRAME.get(String(anim), [])
		for c in 4:
			var step: Array = plan[c % plan.size()] if not plan.is_empty() else [Vector2i.ZERO, 1.0]
			var body := src
			var s := float(step[1])
			if not is_equal_approx(s, 1.0):
				body = src.duplicate()
				body.resize(maxi(1, int(src.get_width() * s)), maxi(1, int(src.get_height() * s)),
					Image.INTERPOLATE_NEAREST)
			var canvas := Image.create(XA_CELL, XA_CELL, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0, 0, 0, 0))
			var off: Vector2i = step[0]
			canvas.blit_rect(body, Rect2i(Vector2i.ZERO, body.get_size()),
				Vector2i((XA_CELL - body.get_width()) / 2 + off.x,
					(XA_CELL - body.get_height()) / 2 + off.y))
			frames.add_frame(anim, ImageTexture.create_from_image(canvas))
	return frames


## 按职业构建战斗五态帧；无素材返回 null（调用方回退行走帧）
static func battle_frames(role_id: String) -> SpriteFrames:
	if _battle_frames_cache.has(role_id):
		return _battle_frames_cache[role_id]
	var xa := _xa_battle_frames(role_id)     # 复刻版：AI 单帧 + 程序动作优先
	if xa != null:
		_battle_frames_cache[role_id] = xa
		return xa
	var path: String = ROLE_BATTLE_SHEET.get(role_id, "")
	var tex: Texture2D = load(path) if path != "" else null
	var frames: SpriteFrames = null
	if tex != null:
		frames = SpriteFrames.new()
		frames.remove_animation(&"default")
		for r in BATTLE_ROWS:
			var anim := StringName(r[0])
			frames.add_animation(anim)
			frames.set_animation_loop(anim, bool(r[2]))
			frames.set_animation_speed(anim, float(r[3]))
			for c in 4:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(c * 128, int(r[1]) * 128, 128, 128)
				frames.add_frame(anim, at)
	_battle_frames_cache[role_id] = frames
	return frames

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
## 战斗倍速。**负数 = "还没人指定过"**，此时用设置里的默认档（见 cur_speed()）。
## 之所以不复用 1.0 当默认值：外部（如回归用例、将来的观战/录像）会在 add_child 之前
## 直接写 speed，若 _build_hud 再赋一次默认值就会把人家设的档吃掉——曾经因此让
## 「12 倍速跑完一场」变成 1 倍速，用例等到超时也等不到结算。
var speed := -1.0

var _acc := 0.0
var _views: Dictionary = {}          # uid -> UnitView
var _shake_root := Control.new()     # 背景 + 战场（震屏只抖这一层，HUD 不跟着晃）
var _field := Node2D.new()           # 战场（单位 + 地面）
var _fx_layer := Control.new()       # 飘字层（最上）
var _hitstop := 0.0                  # 顿帧剩余秒数
var _shake_tw: Tween = null
var _danger: TextureRect = null      # 低血红晕（挂在根节点，别放进飘字层：那儿会被清空断言检查）
var _danger_tip_done := false
var _boss_name_l: Label = null       # B4 首领战顶部大血条：左侧名字
var _boss_fill: ColorRect = null      # B4 首领血条填充
var _boss_bar_w := 0.0                # B4 血条满宽（算一次，刷新时按比例缩）
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
	_show_enter_banner()


## 入场横幅（原版「遭遇战 / 精英战 / 首领战」横幅，Task 2.1）：
## 从上方压下来 → 停 0.5s → 上滑淡出。挂在根节点且不进 _fx_layer（那里有清空断言）。
func _show_enter_banner() -> void:
	if bool(_cfg.get("no_banner", false)):
		return
	var nt: String = String(_cfg.get("enemy", {}).get("node_type", "normal"))
	var title: String = {"normal": "遭 遇 战", "elite": "精 英 战",
		"boss": "首 领 战"}.get(nt, "遭 遇 战")
	var b := G.mk_plaque(title, 300.0, 76.0, G.FS_BIG)
	b.position = Vector2((VIEW_W - 300.0) * 0.5, -90.0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "position:y", 132.0, 0.28).set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(b, "position:y", -90.0, 0.24).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(b.queue_free)


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
	# 标题垫一块与右侧按钮同族的深底 chip：亮天空下宋体金字不再糊进背景
	var title_chip := _func_chip("", 178)
	title_chip.position = Vector2(12, 12)
	title_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := G.serif_label("%s · %s" % [String(tc.get("name", "未知")), nt_name], G.FS_MD, G.GOLD)
	title_chip.add_child(title)
	add_child(title_chip)

	# 开局倍速读设置里的默认档（设置里改了不必每场再点一次）；进战斗后仍可随时切换。
	# 外部已指定过 speed 的场合（负哨兵被覆盖）不会走到 cur_speed() 的默认分支。
	var sp := cur_speed()
	_speed_btn = _func_chip("速度 ×%d" % int(sp), 74)
	_speed_btn.position = Vector2(VIEW_W - 170, 12)
	_speed_btn.gui_input.connect(_on_speed)
	_chip_set_active(_speed_btn, sp >= 1.5)
	add_child(_speed_btn)

	# 复刻版：挂机键移到右下角做成红色「自动」键（原版实录形态），顶栏不再放第二个开关

	_cast_tip = G.serif_label("", G.FS_SM, Color("ffe9b0"))
	# 战场中部的空带（敌方前排血条之下、我方前排名字之上）：原来放 y=52，
	# 和后排敌人头顶的名字撞成一串
	_cast_tip.position = Vector2(0, 306)
	_cast_tip.custom_minimum_size = Vector2(VIEW_W, 0)
	_cast_tip.modulate.a = 0.0
	add_child(_cast_tip)

	_build_boss_bar()


## B4 首领战顶部大血条：标题 chip 之下（y=46）一条横贯的大血条，左名右条。
## 首领体型大、头顶小血条既挤又看不清，改由顶部专条承担"还剩多少"的职责。
func _build_boss_bar() -> void:
	if not sim.has_boss():
		return
	_boss_name_l = G.gold_label("", G.FS_SM, true, Color("ffd98a"), true)
	_boss_name_l.position = Vector2(BAR_X, 46)
	_boss_name_l.custom_minimum_size = Vector2(118, 0)
	_boss_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss_name_l.clip_text = true
	add_child(_boss_name_l)
	var bx := BAR_X + 122.0
	_boss_bar_w = VIEW_W - BAR_X * 2.0 - 122.0
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.03, 0.8)
	bg.position = Vector2(bx, 48)
	bg.size = Vector2(_boss_bar_w, 14)
	add_child(bg)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color("d8483a")
	_boss_fill.position = Vector2(bx + 1, 49)
	_boss_fill.size = Vector2(_boss_bar_w - 2, 12)
	add_child(_boss_fill)
	# 下沿细白描边 + 金外框：暗底战场上把条的边界勾清楚
	var edge := ColorRect.new()
	edge.color = Color(1, 0.96, 0.9, 0.45)
	edge.position = Vector2(bx, 61)
	edge.size = Vector2(_boss_bar_w, 1)
	add_child(edge)
	var frame := Panel.new()
	frame.position = Vector2(bx - 1, 47)
	frame.size = Vector2(_boss_bar_w + 2, 16)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)
	fsb.set_border_width_all(1)
	fsb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.75)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)


## 当前活着的首领单位（无则 null）
func _boss_unit() -> Combatant:
	for u in sim.units:
		if u.alive and u.side == "enemy" and u.ai_type == "boss":
			return u
	return null


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
	ebg.position = Vector2(BAR_X, 598)
	ebg.size = Vector2(VIEW_W - BAR_X * 2.0, 14)
	add_child(ebg)
	_energy_fill.color = G.GOLD
	_energy_fill.position = Vector2(BAR_X + 1, 599)
	_energy_fill.size = Vector2(0, 12)
	add_child(_energy_fill)
	# 能量文字压在能量条正上方：原来 y=597 与条(y=598..612)重叠，字被条的深底吃掉一半。
	# 上移到 580，并改用暖金 + 描边（TEXT_LIGHT 压草地上没有描边会发飘）
	_energy_l = G.gold_label("能量 0/100", G.FS_XS, true, Color("ffe9b8"), true)
	_energy_l.position = Vector2(0, 578)
	_energy_l.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(_energy_l)

	# 连携窗口提示：让到能量条与能量文字上方，不再和它们挤在一起
	_combo_tip = G.serif_label("", G.FS_SM, G.GOLD_BRIGHT)
	_combo_tip.position = Vector2(0, 558)
	_combo_tip.custom_minimum_size = Vector2(VIEW_W, 0)
	_combo_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_tip.modulate.a = 0.0
	add_child(_combo_tip)

	# 5 技能格。网格基准 SKILL_STEP 同时也是功能行的列距基准（见 _build_func_row）：
	# 原来技能格用 88、功能行用 96，两行从第 4 列起就错开一格，「撤退」悬在技能格上方不伦不类
	var role := sim.role_unit()
	if role == null:
		return
	for i in range(role.skills.size()):
		var s: Dictionary = role.skills[i]
		var skill: Dictionary = s.def
		var btn := PanelContainer.new()
		btn.custom_minimum_size = Vector2(SKILL_W, SKILL_H)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.11, 0.06, 0.92)
		sb.set_corner_radius_all(4)
		sb.set_border_width_all(2)
		sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.45)
		btn.add_theme_stylebox_override("panel", sb)
		btn.position = Vector2(BAR_X + i * SKILL_STEP, SKILL_Y)
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
		# 技能名：宋体在深底小字号下笔画发糊（截图里「回风斩」几乎连成一片），
		# 换黑体加粗 + 亮金，深底上才立得住（§32 常规按钮文字必须清楚）
		box.add_child(G.gold_label(String(skill.get("name", "?")), G.FS_SM, true, Color("ffe0a0"), true))
		# 耗能：原来是 bfa987 压深底 13px，对比度约 3:1，几乎看不清。提亮到暖米色
		box.add_child(G.gold_label("耗 %d" % int(skill.get("cost", 0)), G.FS_XS, false,
			Color("dcc9a4"), true))
		var cd_l := G.gold_label("", G.FS_LG, true, Color("ffffff"))
		cd_l.modulate.a = 0.0
		box.add_child(cd_l)
		var sid := String(skill.get("id", ""))
		btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				# 按下回弹：pivot 居中后缩到 0.92 再弹回，给技能键一点"按得动"的手感
				btn.pivot_offset = btn.size * 0.5
				var tw := btn.create_tween()
				if e.pressed:
					tw.tween_property(btn, "scale", Vector2.ONE * 0.92, 0.06)
					_try_cast(sid)
				else:
					tw.tween_property(btn, "scale", Vector2.ONE, 0.10))
		# B1 呼吸光圈：外扩 3px 的金色描边环，能量够且不在 CD 时呼吸闪烁——
		# 商业战斗界面"该放技能了"的标准提示。环用独立 Panel 挂在场景上（不进
		# PanelContainer，否则会被容器布局压回按钮内侧），常态 alpha=0 不打扰。
		var glow := Panel.new()
		glow.position = Vector2(BAR_X + i * SKILL_STEP - 3.0, SKILL_Y - 3.0)
		glow.size = Vector2(SKILL_W + 6.0, SKILL_H + 6.0)
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color(0, 0, 0, 0)
		gsb.set_corner_radius_all(6)
		gsb.set_border_width_all(2)
		gsb.border_color = G.GOLD_BRIGHT
		glow.add_theme_stylebox_override("panel", gsb)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.modulate.a = 0.0
		add_child(glow)
		add_child(btn)
		_skill_btns.append({"btn": btn, "cd_l": cd_l, "skill": skill, "glow": glow,
			"cd_max": int(skill.get("cd", 5))})


func _build_func_row() -> void:
	# 药剂
	var potion_btn := _func_chip("", SKILL_W)
	potion_btn.position = Vector2(BAR_X, FUNC_Y)
	potion_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_use_potion())
	_potion_l = G.gold_label("", G.FS_XS, false, G.TEXT_LIGHT, false)
	_potion_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	potion_btn.add_child(_potion_l)
	add_child(potion_btn)
	# 换宠（无替补则隐藏）：紧贴药剂右侧，同宽同高
	if sim.pet_bench_id != "":
		_pet_btn = _func_chip("换宠", SKILL_W)
		_pet_btn.position = Vector2(BAR_X + SKILL_STEP, FUNC_Y)
		_pet_btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_swap_pet())
		add_child(_pet_btn)
	# 撤退（放弃本节点；二次确认防手滑）：与技能格同网格，第 4 列
	_flee_btn = _func_chip("撤退", SKILL_W)
	_flee_btn.position = Vector2(BAR_X + 3 * SKILL_STEP, FUNC_Y)
	_flee_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_flee())
	add_child(_flee_btn)
	# 右下「自动」键（原版形态：红底挂机键）。与顶栏时代不同，这里就一个开关，不重复。
	_auto_btn = _auto_chip()
	_auto_btn.position = Vector2(BAR_X + 4 * SKILL_STEP, FUNC_Y)
	_auto_btn.gui_input.connect(_on_auto)
	_chip_set_active(_auto_btn, sim.auto_mode)
	add_child(_auto_btn)


## 红色「自动」键：底色血红 + 亮金描边，激活时压暗表示"正在挂机"
func _auto_chip() -> PanelContainer:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(SKILL_W, 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.62, 0.14, 0.10, 0.95)
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2)
	sb.border_color = Color("e8c06a")
	root.add_theme_stylebox_override("panel", sb)
	root.add_child(G.gold_label("自 动", G.FS_SM, true, Color("ffe6b0"), true))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root


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
	_acc += delta * cur_speed() * time_scale
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
				src.play_state(&"attack")   # 普攻：挥剑动作 + 前冲
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
				# 我方施法不再走顶部通报：技能名跟着施法者头顶的图标牌走（_skill_splash）
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
			# 不同技能不同架势：单击用挥砍（attack 行），群攻/大招/增益用蓄力（cast 行）
			var caster_view: UnitView = _views.get(int(e.get("uid", -1)))
			if caster_view != null:
				caster_view.play_state(_skill_anim(String(e.get("skill", ""))))
				caster_view.cast_glow()
			_skill_splash(caster_view, String(e.get("skill", "")))
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
				# 命中星爆（原版命中特效）：白黄五角星 + 橙色放射光线
				if not dot:
					_burst(dst.position)
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
				# 角色挨打播受击架势（格挡/踉跄行）；dot 跳血太频繁不抢动作
				if to_role and not dot and dst != null:
					dst.play_state(&"hit")
		"heal":
			if dst != null:
				_float(dst.position, "+%d" % int(e.amount), G.C_GAIN, G.FS_MD)
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
		# 填充宽 = 底条宽 - 左右各 1px 内缩，与 _build_skill_bar 的 _energy_fill 起点/尺寸一致
		_energy_fill.size.x = (VIEW_W - BAR_X * 2.0 - 2.0) * ratio
		_energy_l.text = "能量 %d/100%s" % [role.energy, "  满" if role.energy >= Combatant.MAX_ENERGY else ""]
	# B4 首领血条刷新：名字 + 百分比，填充宽按当前血量比例缩放
	if _boss_fill != null:
		var boss := _boss_unit()
		if boss != null:
			var bratio := clampf(float(boss.hp) / float(maxi(boss.get_max_hp(), 1)), 0.0, 1.0)
			_boss_fill.size.x = (_boss_bar_w - 2.0) * bratio
			_boss_name_l.text = "%s  %d%%" % [boss.name, roundi(bratio * 100.0)]
		else:
			_boss_fill.size.x = 0.0
			_boss_name_l.text = "首领 · 已击破"
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
				_show_tip("危急 · 血量过低，补药或撤退", G.C_COST, G.FS_MD,
					Color("3a0e0a"), 2)
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
	var glow_a := 0.28 + 0.42 * absf(sin(float(Time.get_ticks_msec() % 1400) / 1400.0 * PI))
	for sbd in _skill_btns:
		var skill: Dictionary = sbd.skill
		var cd := _skill_cd(role, String(skill.get("id", "")))
		var cd_l: Label = sbd.cd_l
		var btn: PanelContainer = sbd.btn
		var glow: Panel = sbd.get("glow", null)
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
			if glow != null:
				glow.modulate.a = 0.0
		elif role != null and int(skill.get("cost", 0)) > role.energy:
			cd_l.modulate.a = 0.0
			btn.modulate = Color(0.75, 0.7, 0.6)
			if glow != null:
				glow.modulate.a = 0.0
		else:
			cd_l.modulate.a = 0.0
			btn.modulate = Color.WHITE
			if glow != null:
				glow.modulate.a = glow_a
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
		# 撤退 = 退出本节点（与地图「撤离」同义）：MapScene 保留节点进度，不判负、不结束本局
		sim.finished = true
		sim.result = "flee"
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


## 当前实际倍速：外部显式给过就照用，否则取设置里的默认档（>=1.5 视为 ×2）
func cur_speed() -> float:
	if speed >= 0.0:
		return speed
	return 2.0 if float(G.setting_get("battle_speed", 1.0)) >= 1.5 else 1.0


func _on_speed(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		speed = 2.0 if cur_speed() < 1.5 else 1.0
		_chip_set_active(_speed_btn, speed >= 1.5)
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


## 命中星爆（原版命中特效）：白黄五角星 + 橙色放射光线，0.22s 内扩散淡出。
## 挂在 _field 下（与单位同一坐标系），不进 _fx_layer——飘字层有「战斗结束应清空」断言。
func _burst(pos: Vector2) -> void:
	if not bool(G.setting_get("shake", true)):
		return   # 与震屏同一开关：关掉打击感表现时不再放特效
	var b := UnitView._HitBurst.new()
	b.position = pos
	_field.add_child(b)


## 震屏：只抖「背景 + 战场」这一层，HUD 与飘字不动（字跟着晃会花）
func _shake(power: float) -> void:
	if not bool(G.setting_get("shake", true)):
		return   # 设置里关了震屏：只保留顿帧/飘字/音效，画面不晃（§15 设置项要真生效）
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


func _show_tip(msg: String, color := Color("ffe9b0"), size := 0,
		outline_color := Color(0, 0, 0, 0), outline_size := 0) -> void:
	_cast_tip.add_theme_color_override("font_color", color)
	# 字号/描边按调用重置：危急提示要"红字 + 深红描边"更刺眼，普通提示回到常态，
	# 避免上一次的告警样式残留到后一条提示上
	_cast_tip.add_theme_font_size_override("font_size", size if size > 0 else G.FS_SM)
	_cast_tip.add_theme_constant_override("outline_size", outline_size)
	_cast_tip.add_theme_color_override("font_outline_color",
		outline_color if outline_size > 0 else Color(0, 0, 0, 0))
	_cast_tip.text = msg
	_cast_tip.modulate.a = 1.0
	if _tip_tween != null and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_tween = _cast_tip.create_tween()
	_tip_tween.tween_interval(1.0)
	_tip_tween.tween_property(_cast_tip, "modulate:a", 0.0, 0.35)


## 技能 → 人物架势：单体直击用挥砍（attack 行），群攻/高费大招/辅助用蓄力（cast 行）
func _skill_anim(skill_id: String) -> StringName:
	var sd := TableCache.get_skill(skill_id)
	if sd.is_empty():
		return &"attack"
	var heavy_hit := int(sd.get("cost", 0)) >= 50 or \
		String(sd.get("target", "")) in ["enemy_all", "enemy_front_all", "enemy_random"]
	if float(sd.get("k", 0.0)) <= 0.0 or heavy_hit:
		return &"cast"
	return &"attack"


## 施法时技能牌在施法者头顶闪现（图标 + 技能名：弹起 → 悬停 → 淡出），
## 生成的技能图不只躺在技能栏里，战斗中也能认得出"放的是哪一招、是谁放的"
func _skill_splash(caster: UnitView, skill_id: String) -> void:
	if caster == null:
		return
	var tex: Texture2D = G.res_tex("sk_%s" % skill_id)
	if tex == null:
		return
	var sname := String(TableCache.get_skill(skill_id).get("name", skill_id))
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.03, 0.92)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = G.GOLD_BRIGHT
	sb.content_margin_left = 6.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(34, 34)
	pic.size = Vector2(34, 34)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var nl := G.gold_label(sname, G.FS_SM, true, Color("ffe9b0"), true)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nl)
	card.add_child(row)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(card)
	card.reset_size()   # 让 PanelContainer 按内容结算出真实宽高，居中定位才准
	var w := card.size.x
	card.position = caster.position + Vector2(-w * 0.5, -138)
	card.position.y = maxf(card.position.y, 46.0)   # 后排敌人贴顶栏，牌子别钻进标题下
	card.pivot_offset = Vector2(w * 0.5, card.size.y * 0.5)
	card.scale = Vector2.ONE * 0.3
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "position:y", card.position.y - 14.0, 0.5)
	tw.tween_interval(0.3)
	tw.tween_property(card, "modulate:a", 0.0, 0.22)
	tw.tween_callback(card.queue_free)


# ================= 结算 =================
func _show_result() -> void:
	# 结算帧收干净低血红晕（P2-19：胜残血时不该在结算层背后留一块红）
	if _danger != null:
		_danger.modulate.a = 0.0
	var win := sim.result == "victory"
	var flee := sim.result == "flee"
	var draw := sim.result == "draw"
	# 超时（draw）在两种模式下说法不同（问题 #21，口径 D3）：
	#   远征 PVE：超时就是失败——显示"超时，远征失利"，与结算一致；
	#   演武场：不判负、不扣段位分——显示"未分胜负"。
	# 同一个战斗场景被两处复用，所以用显式 mode 而不是靠"有没有 custom_mon"猜。
	var arena_mode := String(_cfg.get("mode", "pve")) == "arena"
	var role := sim.role_unit()
	var hp_left := role.hp if role != null else 0
	# 结算音不抖音高：这是"定局"，不是随机反馈（撤退/平局用轻音，不判负）
	Audio.sfx("victory" if win else ("defeat" if not flee and not draw else "ui_close"), 0.0)

	# 结算底衬：整屏接管，走统一工厂（深棕 + 暗角 + 斜纹）
	G.veil(self, G.VEIL_TAKEOVER_A)

	var panel := G.parchment_box(380, 316, 24.0)
	panel.position = Vector2(50, 232)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var title_text := "战  败"
	var title_col := Color("8a4a3a")
	if win:
		title_text = "胜  利"
		title_col = Color("6a8a4a")
	elif flee:
		title_text = "已 撤 退"
		title_col = Color("8a6a34")
	elif draw:
		title_text = "未分胜负" if arena_mode else "超  时"
		title_col = Color("7a5a2e") if arena_mode else Color("a04a3a")
	box.add_child(G.serif_label(title_text, G.FS_HERO, title_col))
	box.add_child(G.gold_label("残存生命 %d" % hp_left, G.FS_SM, false, Color("7a5a2e"), false))
	if flee:
		box.add_child(G.gold_label("节点进度已保留 · 可再次进入", G.FS_SM, false, Color("6a8a4a"), false))
	elif draw:
		box.add_child(G.gold_label(
			"时间耗尽 · 本局不计胜负" if arena_mode else "时间耗尽 · 远征失利",
			G.FS_SM, false, Color("7a5a2e") if arena_mode else Color("a04a3a"), false))
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

	var btn := G.gold_button("返 回" if flee else "继 续", 200, 48)
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
		# 无人接管的兜底路径（主要给 headless 冒烟）：不走转场，立即回主城
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
	var hp_ghost := ColorRect.new()    # B2 白残影条：停在旧血量，缓动追上真实值
	var hp_fg := ColorRect.new()
	var mp_bg := ColorRect.new()      # 脚下蓝 MP 条（仅人物）
	var mp_fg := ColorRect.new()
	var name_l := Label.new()
	var buff_l := Label.new()
	var _base_pos := Vector2.ZERO
	var _dead := false
	var _radius := 22.0
	var _draw_color := Color.WHITE
	var _is_blob := false            # 怪/宠无素材时回退程序圆体
	var _hideable_name := false      # 杂兵名签：常态隐藏、受击亮 1.4s
	var _name_fade := 0.0
	var _last_hp := -1
	var _hp_ratio := 1.0               # B2 真实血量比例（sync 更新）
	var _ghost_ratio := 1.0            # B2 残影条比例（_process 缓动追赶）


	func setup(u: Combatant, role_sprites: Dictionary, mon_colors: Dictionary) -> void:
		uid = u.uid
		side = u.side
		is_role = u.kind == "role"
		add_child(body)
		var name_y := 0.0   # 名字 y（头顶上方）
		var hp_y := 0.0     # 血条 y（脚下）
		if is_role:
			var role_id := String(u.data.get("id", ""))
			# 优先战斗五态帧（待机/普攻/施法/受击/倒下），缺素材回退行走帧
			var frames: SpriteFrames = BattleScene.battle_frames(role_id)
			if frames == null:
				var cfg: Array = role_sprites.get(role_id, [])
				if cfg.size() == 2:
					frames = load(String(cfg[0]))
			if frames != null:
				var asp := AnimatedSprite2D.new()
				asp.sprite_frames = frames
				asp.animation = &"idle" if frames.has_animation(&"idle") else &"walk_down"
				asp.scale = Vector2.ONE * 0.55
				asp.position = Vector2(0, -26)
				asp.play()
				# 一次性动作（普攻/施法/受击）播完自动回待机
				asp.animation_finished.connect(func():
					if not _dead and asp.animation != &"idle":
						asp.play(&"idle"))
				body.add_child(asp)
				sprite = asp
			# 行走帧 128×128 × 0.55：占位 -61~+9
			name_y = -75.0
			hp_y = 12.0
		else:
			var unit_id := String(u.data.get("id", ""))
			var tex: Texture2D = G.art(unit_id)   # 复刻版素材优先（Task 1.5）
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
		# 名字（头顶）——亮底战场上必须带描边，否则敌方名字糊成一片白。
		# 复刻版口径：怪物标签 = 紫色「Lv{n}名」，我方 = 绿色（原版实录）
		var label := u.name
		if side == "enemy" and u.kind == "monster":
			label = "Lv%d%s" % [maxi(1, int(u.data.get("lv", 1))), u.name]
		name_l = G.gold_label(label, G.FS_XS, false,
			Color("c88ae8") if side == "enemy" else Color("c8e8c8"), true)
		name_l.position = Vector2(-36, name_y)
		name_l.custom_minimum_size = Vector2(72, 0)
		body.add_child(name_l)
		# 杂兵名签常态隐藏：首领战五人同屏时名签挤成一团、比血条还抢戏。
		# 只在受击时亮 1.4s（精英/首领/我方单位常驻显示）
		_hideable_name = side == "enemy" and u.kind == "monster" \
			and String(u.data.get("tier", "normal")) == "normal"
		if _hideable_name:
			name_l.modulate.a = 0.0
		# HP 条（脚下）
		hp_bg.color = Color(0, 0, 0, 0.55)
		hp_bg.position = Vector2(-22, hp_y)
		hp_bg.size = Vector2(44, 5)
		body.add_child(hp_bg)
		# B2 两段式削减：白残影条垫在前色条之下，被打时前色条瞬减、残影条停在旧值
		# 再缓动追上（街霸式），一眼看清"这一次掉了多少"
		hp_ghost.color = Color(1.0, 0.94, 0.86, 0.9)
		hp_ghost.position = hp_bg.position + Vector2(1, 1)
		hp_ghost.size = Vector2(42, 3)
		body.add_child(hp_ghost)
		hp_fg.color = Color("e05a4a") if side == "enemy" else Color("5ab464")
		hp_fg.position = hp_bg.position + Vector2(1, 1)
		hp_fg.size = Vector2(42, 3)
		body.add_child(hp_fg)
		# MP 蓝条（脚下、HP 条之下）：原版战斗是脚下「红血条 + 蓝 MP 条」双条，
		# 只有吃能量的单位（人物）才有，怪物/宠物不给蓝条
		if u.kind == "role":
			mp_bg.color = Color(0, 0, 0, 0.55)
			mp_bg.position = Vector2(-22, hp_y + 6)
			mp_bg.size = Vector2(44, 4)
			body.add_child(mp_bg)
			mp_fg.color = Color("4a90d0")
			mp_fg.position = mp_bg.position + Vector2(1, 1)
			mp_fg.size = Vector2(42, 2)
			body.add_child(mp_fg)
		# buff 缩写（血条正下）
		buff_l = G.gold_label("", G.FS_XS, false, Color("a8d8ff"), false)
		buff_l.position = Vector2(-36, hp_y + (12 if u.kind == "role" else 7))
		buff_l.custom_minimum_size = Vector2(72, 0)
		body.add_child(buff_l)


	func sync(u: Combatant) -> void:
		if _dead:
			return
		_base_pos = _owner_grid(u)
		position = _base_pos
		var ratio := clampf(float(u.hp) / float(maxi(u.get_max_hp(), 1)), 0.0, 1.0)
		_hp_ratio = ratio
		hp_fg.size.x = 42.0 * ratio
		if u.kind == "role":
			mp_fg.size.x = 42.0 * clampf(float(u.energy) / float(Combatant.MAX_ENERGY), 0.0, 1.0)
		# 杂兵受击亮名：掉血瞬间把名签唤出 1.4s，随后 _process 里淡掉
		if _hideable_name:
			if _last_hp >= 0 and u.hp < _last_hp and u.alive:
				_name_fade = 1.4
				name_l.modulate.a = 1.0
			_last_hp = u.hp
		var abbrs := PackedStringArray()
		for b in u.buffs:
			var a: String = BattleScene.BUFF_ABBR.get(String(b.type), "")
			if a != "" and not a in abbrs:
				abbrs.append(a)
		buff_l.text = " ".join(abbrs)
		if not u.alive:
			die()


	## 杂兵名签的淡出计时：最后 0.4s 线性消隐，亮名期间被打断会重新计满。
	## 同时驱动 B2 血条残影条：掉血时缓动追上真实值，回血时立刻跟上（不留假残影）。
	func _process(delta: float) -> void:
		if _name_fade > 0.0:
			_name_fade -= delta
			name_l.modulate.a = clampf(_name_fade / 0.4, 0.0, 1.0)
		if is_equal_approx(_ghost_ratio, _hp_ratio):
			pass
		elif _ghost_ratio < _hp_ratio:
			_ghost_ratio = _hp_ratio
			hp_ghost.size.x = 42.0 * _ghost_ratio
		else:
			_ghost_ratio = maxf(_hp_ratio, lerpf(_ghost_ratio, _hp_ratio, 1.0 - exp(-delta * 6.0)))
			hp_ghost.size.x = 42.0 * _ghost_ratio


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


	## 播一次性动作（普攻/施法/受击）；播完由 animation_finished 带回待机。
	## 同名动作正在播时不打断自己（受击连掉三滴血不至于鬼畜抽搐）
	func play_state(anim: StringName) -> void:
		var asp := sprite as AnimatedSprite2D
		if asp == null or _dead:
			return
		if not asp.sprite_frames.has_animation(anim):
			return
		if asp.animation == anim and asp.is_playing():
			return
		asp.play(anim)


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
		# 角色有倒下动画：先播完（4 帧 @6fps ≈ 0.67s）再淡出；怪宠维持原地缩放淡出
		var asp := sprite as AnimatedSprite2D
		if asp != null and asp.sprite_frames != null and asp.sprite_frames.has_animation(&"death"):
			asp.play(&"death")
			var tw := create_tween()
			tw.tween_interval(0.7)
			tw.tween_property(self, "modulate:a", 0.0, 0.45)
			tw.parallel().tween_property(self, "scale", Vector2(0.9, 0.8), 0.45)
			return
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


	## 命中星爆：白黄五角星 + 橙色放射光线（原版战斗命中特效，Task 2.1）
	class _HitBurst extends Node2D:
		const LIFE := 0.22
		var _t := 0.0
		var _r := 15.0

		func _process(delta: float) -> void:
			_t += delta
			if _t >= LIFE:
				queue_free()
				return
			queue_redraw()

		func _draw() -> void:
			var k := _t / LIFE
			var r := _r * (0.55 + 0.95 * k)
			var a := 1.0 - k
			for i in 6:   # 放射光线
				var ang := TAU * float(i) / 6.0 + k * 0.7
				var d := Vector2(cos(ang), sin(ang))
				draw_line(d * r * 0.7, d * r * 1.75, Color(1.0, 0.62, 0.24, a * 0.9), 2.0)
			var pts := PackedVector2Array()   # 五角星
			for i in 10:
				var ang := -PI / 2.0 + TAU * float(i) / 10.0
				var rr := r * (1.0 if i % 2 == 0 else 0.45)
				pts.append(Vector2(cos(ang), sin(ang)) * rr)
			draw_colored_polygon(pts, Color(1.0, 0.95, 0.72, a))


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
