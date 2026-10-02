# BattleScene.gd —— 战斗场景：BattleSim 驱动的表现层 + 操作 UI（玩法文档 §2.1）
# 职责：每渲染帧按速度倍率步进 sim 并消费 events（飘字/位移/HP/死亡）；
#       技能条/药剂/换宠/托管/速度；结算浮层。数值与判定全在 BattleSim（本层零规则）。
class_name BattleScene
extends Control

signal battle_finished(result: String, hp_left: int)

const CombatFX := preload("res://src/battle/BattleEffects.gd")

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
const CLASSIC_BAR_X := 39.0
const CLASSIC_SKILL_W := 74.0
const CLASSIC_SKILL_H := 54.0
const CLASSIC_SKILL_STEP := 82.0
const CLASSIC_SKILL_Y := 738.0
const CLASSIC_FUNC_Y := 744.0
## 像素木牌描边色：经典模式的底板（径向指令 / 技能格 / 小签）统一这一支暗金，
## 方角 + 2px 厚边压像素地图才立得住（原来 3~6px 圆角 + 1px 淡金边是现代 UI 语言）
const WOOD_BORDER := Color("8a6524")
# ---------- 主世界同图战斗指令：像素图标配可读文字，集中在战场下缘 ----------
# 四枚 16×16 字符网格像素图标，运行时烤成 ImageTexture 后 2 倍放大（nearest，不糊）。
# 图例：k 深褐描边 / s 钢亮 S 钢暗 / g 金亮 G 金暗 / h 木亮 H 木暗
#       p 纸页亮 P 纸页线 / b 书皮 / c 软木塞 / w 玻璃 r 药液 R 液面
const CMD_ICON_PALETTE := {
	"k": Color("241608"), "s": Color("c7d2e0"), "S": Color("7e8aa0"),
	"g": Color("e8b84a"), "G": Color("a87a20"), "h": Color("8a5a30"),
	"H": Color("5a3a1a"), "p": Color("f0e6c8"), "P": Color("c9b888"),
	"b": Color("7a4a26"), "c": Color("c49a5a"), "w": Color("d8ecf0"),
	"r": Color("d8483a"), "R": Color("a02a20"),
}
const CMD_ICON_ATTACK := [  # 双剑十字：钢刃 + 金护手 + 木柄
	".....k....k.....",
	"...kSSk.kSSk....",
	"...kSSk.kSSk....",
	"...kSSk.kSSk....",
	"...kSSk.kSSk....",
	"...kSSk.kSSk....",
	"...kSSkkSSk.....",
	"..kSSSkkSSSk..",
	"..kgggggggggk...",
	"..kGggggggggGk..",
	"....khk..khk....",
	"....khk..khk....",
	"...khhk.khhk....",
	"...kGGk.kGGk....",
	"................",
	"................",
]
const CMD_ICON_SKILL := [  # 摊开的技能书：纸页 V 形下凹 + 两条字线 + 书皮
	"................",
	"................",
	"....k......k....",
	"...kpk....kpk...",
	"...kppk..kppk...",
	"...kpppkkpppk...",
	"...kppppppppk...",
	"...kpPPPPPPpk...",
	"...kppppppppk...",
	"...kpPPPPPPpk...",
	"...kppppppppk...",
	"...kbbbbbbbbk...",
	"...kbbbbbbbbk...",
	"....kkkkkkkk....",
	"................",
	"................",
]
const CMD_ICON_ITEM := [  # 圆底药瓶：软木塞 + 玻璃瓶颈 + 红药液
	"................",
	".....kkkkkk.....",
	".....kcccck.....",
	".....kcccck.....",
	"....kkkkkkkk....",
	"....kwwwwwwk....",
	"....kwwwwwwk....",
	"...kkwwwwwwkk...",
	"..kwwwwwwwwwwk..",
	".kkRRRRRRRRRRkk.",
	".kwrrrrrrrrrrwk.",
	"kwrrrrrrrrrrrrwk",
	"kwrrrrrrrrrrrrwk",
	".kwrrrrrrrrrrwk.",
	"..kkrrrrrrrrkk..",
	"....kkkkkkkk....",
]
const CMD_ICON_FLEE := [  # 撤退靴：靴筒 + 靴头右探 + 深色靴底
	"................",
	"...kkkk.........",
	"..khhhHk........",
	"..khhhHk........",
	"..khhhk.........",
	"..khhhk.........",
	"..khhhk.........",
	"..khhhk.........",
	"..khhhk.........",
	"..khhhk.........",
	"..khhhk.........",
	"..khhhhhhhhk....",
	"..khhhhhhhhk....",
	"..khhhhhhhhk....",
	"..kHHHHHHHHHk...",
	"..kkkkkkkkkkk...",
]
const RADIAL_BTN := 38.0      # 图标 tile 边长（32 图标 + 3 内边距 ×2）
const RADIAL_LABEL_H := 16.0  # tile 下方文字带高
const CLASSIC_CMD_W := 88.0
const CLASSIC_CMD_H := 50.0
const CLASSIC_CMD_Y := 585.0
const PAGE_PANEL_POS := Vector2(39.0, 740.0)
const PAGE_PANEL_SIZE := Vector2(402.0, 42.0)
# 技能/道具页整宽竖排；每行 44px，触屏不会挤到相邻技能。
# 面板底边固定不动（PAGE_PANEL_BOTTOM），行数多时向上长，玩家的手指始终落在同一片区域。
const PAGE_ROW_H := 44.0
const PAGE_PANEL_BOTTOM := PAGE_PANEL_POS.y + PAGE_PANEL_SIZE.y
const ENEMY_BACK_Y := 148.0
const ENEMY_FRONT_Y := 226.0
const ALLY_FRONT_Y := 402.0
const ALLY_BACK_Y := 474.0
const CLASSIC_COL_Y := 180.0
const CLASSIC_COL_GAP := 80.0
const CLASSIC_ENEMY_BACK_X := 395.0
const CLASSIC_ENEMY_FRONT_X := 335.0
const CLASSIC_ALLY_FRONT_X := 130.0
const CLASSIC_ALLY_BACK_X := 75.0

const ROLE_SPRITE := {  # 人物战斗行走帧（探索/进出场用）
	"zs": ["res://image/role/zs/pojun_walk_frames.tres", "pojun"],
	"ck": ["res://image/role/ck/chuanyang_walk_frames.tres", "chuanyang"],
	"fs": ["res://image/role/fs/shuangyu_walk_frames.tres", "shuangyu"],
	"fz": ["res://image/role/fz/chenxing_walk_frames.tres", "chenxing"],
}
# 战斗五态 spritesheet（4 列 × 5 行 @128px：待机/普攻/施法/受击/倒下）。
# Godot 3 的 .tres 在 4.7 下不稳，统一运行时从整图重建（与 GameHome/CreateRole 同口径）。
const ROLE_BATTLE_SHEET := {
	"zs": "res://image/role/zs/pojun_spritesheet.png",
	"ck": "res://image/role/ck/chuanyang_spritesheet.png",
	"fs": "res://image/role/fs/shuangyu_spritesheet.png",
	"fz": "res://image/role/fz/chenxing_spritesheet.png",
}
const BATTLE_ROWS := [  # [动画名, 行号, 是否循环, 帧率]
	["idle", 0, true, 5.0], ["attack", 1, false, 11.0], ["cast", 2, false, 8.0],
	["hit", 3, false, 10.0], ["death", 4, false, 6.0],
]
static var _battle_frames_cache := {}

## 按职业构建战斗五态帧；无素材返回 null（调用方回退行走帧）
static func battle_frames(role_id: String) -> SpriteFrames:
	if _battle_frames_cache.has(role_id):
		return _battle_frames_cache[role_id]
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


## 像素字符网格 → ImageTexture（16×16；调用方以 STRETCH_SCALE + nearest 2 倍放大）。
## 与 _Blob/_HitBurst 同族：图标不进 assets，全部运行时生成，保持像素硬边。
static func cmd_icon_tex(grid: Array) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in mini(16, grid.size()):
		var row: String = String(grid[y])
		for x in mini(16, row.length()):
			var col: Variant = CMD_ICON_PALETTE.get(row[x], null)
			if col != null:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

const BUFF_ABBR := {  # buff 状态条缩写
	"poison": "毒", "bleed": "血", "slow": "缓", "stun": "晕", "fear": "惧",
	"taunt": "嘲", "shield": "盾", "atk_up": "攻", "atk_down": "衰", "lurk": "潜",
	"invincible": "免", "thorns": "荆", "lifesteal": "吸", "confusion": "乱",
	"def_break": "破", "def_up": "防", "spd_up": "疾", "deathproof": "生",
	"break_window": "绽",   # P03：首领施法后露出的反击窗口（受伤放大）
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
var effective_skills: Array = []         # P05-D：本场真正生效过的玩家技能（每个 id 只记一次）
var _energy_fill: ColorRect = null       # 底部能量横条（经典模式不建：能量只走角色脚下蓝条）
var _energy_bar_w := VIEW_W - BAR_X * 2.0
var _energy_l: Label = null              # 底部能量文字（同上）
var _page_energy_l: Label = null         # 「技」页展开时的能量读数（底部撤条后的数值入口）
var _potion_l := Label.new()
var _pet_btn: Control = null
var _auto_btn: Control = null
var _speed_btn: Control = null
var _flee_btn: Control = null        # 撤退按钮（二次确认要改它的文案）
var _flee_armed := false             # 撤退已上膛（3 秒内再点才真正撤退）
var _cmd_root: Control = null          # 径向指令菜单根（角色周围四枚像素图标）
var _cmd_btns: Array[Dictionary] = []  # {key, root, tile_sb, label}
var _page_panel: Panel = null          # 技能页 / 道具页弹出条（PAGE_PANEL_POS）
var _command_page := "root"            # root / skills / items
var _ranged_waiting: Dictionary = {}  # "src:dst" -> 命中前正在飞行的弹道状态
var _skill_motion_sources: Dictionary = {} # Casts resolved in the current event batch.
var _cast_tip := Label.new()
var _tip_tween: Tween = null
var _combo_tip := Label.new()      # 连携窗口提示（能量条上方）
var _finished_ui := false
var _cfg: Dictionary = {}
# ---------- P03 表现层：预兆 / 阶段横幅 ----------
var _omens: Node2D = null              # 预兆层：施法者脚下 + 将要被打者身上的脉动环
var _windup_uid := -1                  # 正在前摇倒数的敌人 uid（-1 = 没有）
var _windup_tier := "normal"
var _windup_total: Dictionary = {}     # uid -> 起手前摇 tick 数（算环的收缩比例）
var _windup_name := ""                 # 正在前摇的技能名（实时倒数用）
var _boss_phase_name := ""             # 首领当前阶段名（追加在顶部血条后面）
# ---------- P03 四指令详情 ----------
var _page_rows := 0                    # 当前弹出页已排行数（queue_free 是延迟的，不能靠子节点数）
var _flee_blocked := false             # 剧情首领战禁止撤退（按钮置灰 + 点击出文案）
var _cmd_info_l: Label = null          # 常驻信息条（四枚指令之上）：攻/技/物的当前关键事实


func _classic_presentation() -> bool:
	return String(_cfg.get("presentation", "default")) == "classic_inline" \
		and bool(G.setting_get("classic_combat_presentation", true))


func _standard_extra_y() -> float:
	return maxf(0.0, get_viewport_rect().size.y - VIEW_H) if not _classic_presentation() else 0.0

func _classic_extra_y() -> float:
	return maxf(0.0, get_viewport_rect().size.y - VIEW_H) if _classic_presentation() else 0.0


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
	_build_classic_command_ui()
	_sync_views()
	sim.events.clear()


# ================= 布局 =================
func _build_background() -> void:
	# 保留现有战斗/回图生命周期，表现层使用独立地区地表构图。
	if _classic_presentation():
		_build_classic_region_floor()
		return
	# 战斗背景：优先接主题 bg_battle_* 竖版手绘（971×1619，与 480×800 同比例）；
	# 无素材时回退主题 tint 底色 + tile 平铺地面
	var theme: String = String(_cfg.get("enemy", {}).get("theme", "forest"))
	var tc := TableCache.theme_config(theme)
	var bg_tex: Texture2D = G.res_tex(String(tc.get("battle_bg", "")))
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 必须在 size 前：否则被钳到原图尺寸
		bg.size = Vector2(VIEW_W, maxf(VIEW_H, get_viewport_rect().size.y))
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shake_root.add_child(bg)
		_add_shade_gradient(0.0, 96.0, true)     # 顶部压暗（标题可读）
		_add_shade_gradient(520.0, maxf(280.0, get_viewport_rect().size.y - 520.0), false)  # 底部压暗（技能区可读）
	else:
		var tint := Color(String(tc.get("tint", "ffffff")))
		var flat := ColorRect.new()
		flat.color = Color(tint.r * 0.22, tint.g * 0.22, tint.b * 0.24)
		flat.size = Vector2(VIEW_W, maxf(VIEW_H, get_viewport_rect().size.y))
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


func _build_classic_region_floor() -> void:
	var theme := String(_cfg.get("enemy", {}).get("theme", "forest"))
	var tiles: Array = TableCache.theme_config(theme).get("tiles", [])
	if tiles.is_empty(): return
	var asset_dir := String(TableCache.maps_config().get("asset_dir", "res://image/map_proc"))
	var is_grass := theme == "forest"
	var texture: Texture2D = load("res://image/main_world/classic_floor_reference_v2.png" if is_grass else "%s/%s.png" % [asset_dir, String(tiles[0])])
	if texture == null: return
	var ground := TextureRect.new()
	ground.name = "ClassicRegionFloor"
	ground.texture = texture
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if is_grass else TextureRect.STRETCH_TILE
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.size = Vector2(VIEW_W, maxf(VIEW_H, get_viewport_rect().size.y))
	ground.modulate = Color(String(_cfg.get("region_floor_tint", "ffffff")))
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_root.add_child(ground)


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
	_field.position.y = _classic_extra_y() + _standard_extra_y() * 0.5
	# 预兆层垫在战场最底（单位之下、地面上），随震屏层一起抖；把「谁在起手、要打谁」画出来
	_omens = _Omens.new()
	_omens.z_index = -1
	_field.add_child(_omens)
	_shake_root.add_child(_field)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.position.y = _classic_extra_y() + _standard_extra_y() * 0.5
	# P05-C：飘字层是本层「最上」——但阶段/破绽横幅是事件发生时 add_child 的，后添加者
	# 反而压在上面，把同时刻的飘字（如影狼死的「绽」）整块盖住。显式置顶，让"最上"成立。
	_fx_layer.z_index = 10
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
	_danger.size = Vector2(VIEW_W, maxf(VIEW_H, get_viewport_rect().size.y))
	_danger.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 项目默认 nearest，放大必须改线性
	_danger.modulate.a = 0.0
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger)


func _build_top_bar() -> void:
	var tc := TableCache.theme_config(String(_cfg.get("enemy", {}).get("theme", "forest")))
	var nt: String = String(_cfg.get("enemy", {}).get("node_type", "normal"))
	var nt_name: String = {"normal": "遭遇战", "elite": "精英战", "boss": "首领战"}.get(nt, "遭遇战")
	if _classic_presentation():
		var title := G.gold_label(nt_name, G.FS_LG, true, Color("e65b35"), true)
		title.position = Vector2(0, 16)
		title.custom_minimum_size = Vector2(VIEW_W, 34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(title)
	else:
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
	_speed_btn = _pixel_chip("速度 ×%d" % int(sp), 74) if _classic_presentation() \
		else _func_chip("速度 ×%d" % int(sp), 74)
	_speed_btn.position = Vector2(12, 12) if _classic_presentation() else Vector2(VIEW_W - 170, 12)
	_speed_btn.gui_input.connect(_on_speed)
	_chip_set_active(_speed_btn, sp >= 1.5)
	add_child(_speed_btn)

	# 自动：经典模式与速度同族像素木牌（原来常驻红底圆角按钮，与像素地图不是一套语言）。
	# 开/关走 _chip_set_active 的亮金态，一眼能看出"现在是不是托管中"
	_auto_btn = _pixel_chip("自动", 58) if _classic_presentation() else _func_chip("托管", 58)
	_auto_btn.position = Vector2(VIEW_W - 74, 12) if _classic_presentation() else Vector2(VIEW_W - 96, 12)
	_auto_btn.gui_input.connect(_on_auto)
	_chip_set_active(_auto_btn, sim.auto_mode)
	add_child(_auto_btn)

	_cast_tip = G.serif_label("", G.FS_SM, Color("ffe9b0"))
	# 角色与敌怪占据 y≈240–450；施法提示放到其下方的空带。
	_cast_tip.position = Vector2(0, 462 + _classic_extra_y() + _standard_extra_y() * 0.5)
	_cast_tip.custom_minimum_size = Vector2(VIEW_W, 28)
	_cast_tip.add_theme_color_override("font_outline_color", Color("17211d"))
	_cast_tip.add_theme_constant_override("outline_size", 2)
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
	# P05-C：进阶段后名字后面要追「· 迷路低吼」（首领名 4 字 + 双空格 + 百分比 + 双空格
	# + 中点 + 4 字阶段名 ≈ 170px），旧宽 118 会把阶段名连着裁掉——那等于"进阶段了但
	# 玩家看不见规则变了"。留到 200px：既覆盖 100% 三位数，也不至于把血条挤太短。
	_boss_name_l.custom_minimum_size = Vector2(200, 0)
	_boss_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss_name_l.clip_text = true
	add_child(_boss_name_l)
	var bx := BAR_X + 204.0
	_boss_bar_w = VIEW_W - BAR_X * 2.0 - 204.0
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
	# 深色功能签：切角 + 内凹光（顶暗底亮），弃用圆角3的平面色块；
	# 交互态换肤走 InsetPanel.set_surface，不再直接改 StyleBoxFlat 的颜色字段
	var root := G.InsetPanel.new()
	root.custom_minimum_size = Vector2(w, 30)
	root.setup(Color(0.15, 0.10, 0.05, 0.7), Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.3),
		0.0, 0.0, 0.0, 0.0)
	root.add_child(G.gold_label(text, G.FS_XS, false, Color("d9b96e"), false))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	return root


## 功能签常态底色：像素经典模式换成暗木底 + 暗金厚边（与径向指令同一套牌子语言）
func _chip_idle_surface() -> Array:
	if _classic_presentation():
		return [Color(0.12, 0.08, 0.045, 0.86), WOOD_BORDER]
	return [Color(0.15, 0.10, 0.05, 0.7), Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.3)]


func _chip_set_active(chip: Control, active: bool) -> void:
	var panel := chip as G.InsetPanel
	if panel != null:
		var surf := [Color(0.32, 0.2, 0.06, 0.92), G.GOLD_BRIGHT] if active else _chip_idle_surface()
		panel.set_surface(surf[0], surf[1])
	var l := chip.get_child(0) as Label
	if l != null:
		l.add_theme_color_override("font_color", G.GOLD_BRIGHT if active else Color("d9b96e"))


## 经典模式像素木牌小签：在 _func_chip 上换皮——方角、2px 暗金厚边、深木底。
## 顶部速度/自动、弹出页按钮共用，和径向指令、技能格是同一套牌子语言。
func _pixel_chip(text: String, w := 64.0) -> PanelContainer:
	var root := _func_chip(text, w)
	(root as G.InsetPanel).set_surface(Color(0.12, 0.08, 0.045, 0.86), WOOD_BORDER)
	return root


func _build_skill_bar() -> void:
	var classic := _classic_presentation()
	var bar_x := CLASSIC_BAR_X if classic else BAR_X
	_energy_bar_w = VIEW_W - bar_x * 2.0
	var energy_y := 598.0 + _standard_extra_y()
	var skill_y := CLASSIC_SKILL_Y if classic else SKILL_Y + _standard_extra_y()
	var skill_w := CLASSIC_SKILL_W if classic else SKILL_W
	var skill_h := CLASSIC_SKILL_H if classic else SKILL_H
	var skill_step := CLASSIC_SKILL_STEP if classic else SKILL_STEP
	# 能量条（人物专属）：经典模式撤掉底部横条 + 数字——角色脚下的蓝条（原版红蓝双条）
	# 已经在表达同一件事，两处显示只是把底部越撑越重。数值改由「技」页展开时给一眼。
	if not classic:
		var ebg := ColorRect.new()
		ebg.color = Color(0.1, 0.08, 0.04, 0.85)
		ebg.position = Vector2(bar_x, energy_y)
		ebg.size = Vector2(_energy_bar_w, 14)
		add_child(ebg)
		_energy_fill = ColorRect.new()
		_energy_fill.color = G.GOLD
		_energy_fill.position = Vector2(bar_x + 1, energy_y + 1)
		_energy_fill.size = Vector2(0, 12)
		add_child(_energy_fill)
		# 能量文字压在能量条正上方：原来 y=597 与条(y=598..612)重叠，字被条的深底吃掉一半。
		# 上移到 578，并改用暖金 + 描边（TEXT_LIGHT 压草地上没有描边会发飘）
		_energy_l = G.gold_label("能量 0/100", G.FS_XS, true, Color("ffe9b8"), true)
		_energy_l.position = Vector2(0, 578 + _standard_extra_y())
		_energy_l.custom_minimum_size = Vector2(VIEW_W, 0)
		add_child(_energy_l)

	# 连携窗口提示：经典模式没有底部能量条，提示落在技能栏上沿与角色之间
	_combo_tip = G.serif_label("", G.FS_SM, G.GOLD_BRIGHT)
	_combo_tip.position = Vector2(0, 706 + _classic_extra_y() if classic else 558 + _standard_extra_y())
	_combo_tip.custom_minimum_size = Vector2(VIEW_W, 0)
	_combo_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_tip.modulate.a = 0.0
	add_child(_combo_tip)
	# 主世界战斗由“技能”指令展开同一组技能。常驻技能格会重复占据
	# 画面下缘，也让玩家误以为两套入口有不同规则。
	if classic:
		return

	# 5 技能格。网格基准 SKILL_STEP 同时也是功能行的列距基准（见 _build_func_row）：
	# 原来技能格用 88、功能行用 96，两行从第 4 列起就错开一格，「撤退」悬在技能格上方不伦不类
	var role := sim.role_unit()
	if role == null:
		return
	for i in range(role.skills.size()):
		var s: Dictionary = role.skills[i]
		var skill: Dictionary = s.def
		var btn := PanelContainer.new()
		btn.custom_minimum_size = Vector2(skill_w, skill_h)
		var sb := StyleBoxFlat.new()
		# 经典模式：像素木牌（方角 + 2px 暗金厚边），与径向指令同一套牌子语言；
		# 常规版也收成 2px 切角，不和大圆角混用
		sb.bg_color = Color(0.12, 0.08, 0.045, 0.9) if classic else Color(0.16, 0.11, 0.06, 0.92)
		sb.set_corner_radius_all(2)
		sb.set_border_width_all(2)
		sb.border_color = WOOD_BORDER if classic else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.45)
		btn.add_theme_stylebox_override("panel", sb)
		btn.position = Vector2(bar_x + i * skill_step, skill_y)
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
			icon.custom_minimum_size = Vector2(30, 30) if classic else Vector2(42, 42)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			box.add_child(icon)
		# 技能名：宋体在深底小字号下笔画发糊（截图里「回风斩」几乎连成一片），
		# 换黑体加粗 + 亮金，深底上才立得住（§32 常规按钮文字必须清楚）
		var skill_text := "%s %d" % [String(skill.get("name", "?")), int(skill.get("cost", 0))] \
			if classic else String(skill.get("name", "?"))
		box.add_child(G.gold_label(skill_text, G.FS_XS if classic else G.FS_SM,
			true, Color("ffe0a0"), true))
		# 耗能：原来是 bfa987 压深底 13px，对比度约 3:1，几乎看不清。提亮到暖米色
		if not classic:
			box.add_child(G.gold_label("耗 %d" % int(skill.get("cost", 0)), G.FS_XS, false,
				Color("dcc9a4"), true))
		var cd_l := G.gold_label("", G.FS_XS if classic else G.FS_LG,
			true, Color("ffffff"))
		cd_l.modulate.a = 0.0
		if classic:
			# 技能格压到 54 高：CD 数字不再占第三行，改成压在图标上的浮字
			# （挂场景而不是进 VBox，否则会被容器排版挤回格内）
			cd_l.add_theme_font_size_override("font_size", G.FS_SM)
			cd_l.position = Vector2(bar_x + i * skill_step, skill_y + 12.0)
			cd_l.custom_minimum_size = Vector2(skill_w, 0)
			cd_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(cd_l)
		else:
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
		glow.position = Vector2(bar_x + i * skill_step - 3.0, skill_y - 3.0)
		glow.size = Vector2(skill_w + 6.0, skill_h + 6.0)
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color(0, 0, 0, 0)
		gsb.set_corner_radius_all(2)
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
	if _classic_presentation():
		return   # 经典模式：药剂/换宠/撤退全部并入身周径向指令（物/逃），底部不再占行
	var classic := _classic_presentation()
	var row_x := CLASSIC_BAR_X if classic else BAR_X
	var row_y := CLASSIC_FUNC_Y if classic else FUNC_Y + _standard_extra_y()
	var row_w := CLASSIC_SKILL_W if classic else SKILL_W
	var row_step := CLASSIC_SKILL_STEP if classic else SKILL_STEP
	# 药剂
	var potion_btn := _func_chip("", row_w)
	potion_btn.position = Vector2(row_x, row_y)
	potion_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_use_potion())
	_potion_l = G.gold_label("", G.FS_XS, false, G.TEXT_LIGHT, false)
	_potion_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	potion_btn.add_child(_potion_l)
	add_child(potion_btn)
	# 换宠（无替补则隐藏）：紧贴药剂右侧，同宽同高
	if sim.pet_bench_id != "":
		_pet_btn = _func_chip("换宠", row_w)
		_pet_btn.position = Vector2(row_x + row_step, row_y)
		_pet_btn.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_swap_pet())
		add_child(_pet_btn)
	# 撤退（放弃本节点；二次确认防手滑）：靠右对齐到技能栏右沿，
	# 与第 4 技能格列同基准（原来用 3*96 手算，与技能格网格错位）
	_flee_btn = _func_chip("撤退", row_w)
	_flee_btn.position = Vector2(row_x + 4 * row_step, row_y)
	_flee_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_flee())
	add_child(_flee_btn)


## 经典战斗指令层：四枚像素图标集中排列，战斗人物与敌怪四周留给名称和动作。
## 常驻显示无需开关；「技」「物」弹出底部页条（技能 / 道具），「逃」两步确认撤退。
## 关闭经典表现开关时不插入任何新 UI。
func _build_classic_command_ui() -> void:
	if not _classic_presentation():
		return
	_cmd_root = Control.new()
	_cmd_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cmd_root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 只在四枚图标上吃输入
	add_child(_cmd_root)
	_add_radial_option("attack", "攻击", CMD_ICON_ATTACK, Callable(self, "_command_attack"),
		"循环选择可攻击的敌方目标")
	_add_radial_option("skill", "技能", CMD_ICON_SKILL, Callable(self, "_show_command_skills"),
		"打开技能选择")
	_add_radial_option("item", "道具", CMD_ICON_ITEM, Callable(self, "_command_item"),
		"使用道具（药剂 / 换宠）")
	_add_radial_option("flee", "撤退", CMD_ICON_FLEE, Callable(self, "_command_flee"),
		"撤退需在确认时间内再点一次")
	# P03：剧情首领战不可撤退——按钮置灰 + 文案说清后果，别让玩家点了才发现走不了
	_flee_blocked = String(_cfg.get("flee_rule", "")) == "blocked"
	if _flee_blocked:
		_set_radial_disabled("flee", true)
		_set_radial_hint("flee", "首领战不可撤退")
	else:
		_set_radial_hint("flee", "退出本节点，保留战损与进度")
	# 常驻信息条：四枚指令之上，一行说清「攻谁 / 有没有技 / 药剩几瓶」
	var info_bg := Panel.new()
	info_bg.position = Vector2(CLASSIC_BAR_X, CLASSIC_CMD_Y - 26.0 + _classic_extra_y())
	info_bg.size = Vector2(PAGE_PANEL_SIZE.x, 23.0)
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.10, 0.07, 0.04, 0.78)
	info_style.set_corner_radius_all(2)
	info_bg.add_theme_stylebox_override("panel", info_style)
	info_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cmd_root.add_child(info_bg)
	_cmd_info_l = G.gold_label("", G.FS_XS, true, Color("e8d9a8"), true)
	_cmd_info_l.position = Vector2(CLASSIC_BAR_X, CLASSIC_CMD_Y - 22.0 + _classic_extra_y())
	_cmd_info_l.custom_minimum_size = Vector2(PAGE_PANEL_SIZE.x, 0)
	_cmd_info_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cmd_root.add_child(_cmd_info_l)
	_position_radial_menu()
	# 技能 / 道具弹出页（默认隐藏，点在身周图标上才展开）
	_page_panel = Panel.new()
	_page_panel.position = PAGE_PANEL_POS + Vector2(0, _classic_extra_y())
	_page_panel.size = PAGE_PANEL_SIZE
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.10, 0.07, 0.04, 0.98)
	psb.set_corner_radius_all(2)
	psb.set_border_width_all(2)
	psb.border_color = WOOD_BORDER
	_page_panel.add_theme_stylebox_override("panel", psb)
	_page_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_page_panel.hide()
	add_child(_page_panel)
	# 能量读数：底部横条撤掉后，数值只在「技」页展开时给一眼（常驻信息交给脚下蓝条）
	_page_energy_l = G.gold_label("", G.FS_XS, true, Color("ffe9b8"), true)
	_page_energy_l.position = PAGE_PANEL_POS + Vector2(0, _classic_extra_y() - 20)
	_page_energy_l.custom_minimum_size = Vector2(PAGE_PANEL_SIZE.x, 0)
	_page_energy_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_energy_l.hide()
	add_child(_page_energy_l)


## 单枚战斗指令：横向木牌 + 32px 像素图标 + 常用全称。
## 按压回弹与技能格同族（pivot 居中缩到 0.88 再弹回）。
func _add_radial_option(key: String, text: String, grid: Array,
		action: Callable, tooltip := "") -> void:
	var root := Control.new()
	root.custom_minimum_size = Vector2(CLASSIC_CMD_W, CLASSIC_CMD_H)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.tooltip_text = tooltip
	var tile := Panel.new()
	tile.size = Vector2(CLASSIC_CMD_W, CLASSIC_CMD_H)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	# 像素木牌：方角 + 2px 暗金厚边。原来 6px 圆角 + 1px 淡金边是现代 UI 语言，
	# 四块深色圆角贴纸上亮色草地后成了全屏最重的元素，把角色和地图都压住了。
	sb.bg_color = Color(0.12, 0.08, 0.045, 0.86)
	sb.set_corner_radius_all(2)
	sb.set_border_width_all(2)
	sb.border_color = WOOD_BORDER
	tile.add_theme_stylebox_override("panel", sb)
	root.add_child(tile)
	var icon := TextureRect.new()
	icon.texture = cmd_icon_tex(grid)
	icon.position = Vector2(6, 9)
	icon.size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	var l := G.gold_label(text, G.FS_XS, true, Color("ffe9b0"), true)
	l.position = Vector2(39, 8)
	l.custom_minimum_size = Vector2(46, CLASSIC_CMD_H - 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			root.pivot_offset = root.size * 0.5
			var tw := root.create_tween()
			tw.tween_property(root, "scale", Vector2.ONE * 0.88, 0.05)
			tw.tween_property(root, "scale", Vector2.ONE, 0.09)
			action.call())
	_cmd_root.add_child(root)
	_cmd_btns.append({"key": key, "root": root, "tile_sb": sb, "label": l, "hint": tooltip})


## 四枚指令固定在下方操作带，战斗对象移动时按键不会跳位。
## 角色倒下 / 结算时由 _refresh_hud 整组隐藏。
func _position_radial_menu() -> void:
	if _cmd_root == null:
		return
	for i in _cmd_btns.size():
		(_cmd_btns[i].root as Control).position = Vector2(39.0 + i * 101.0,
			CLASSIC_CMD_Y + _classic_extra_y())


## 径向指令"上膛"态描边（撤退二次确认用）：暖橙粗边亮起，取消时收回金边
func _set_radial_armed(key: String, armed: bool) -> void:
	for cbd in _cmd_btns:
		if String(cbd.key) != key:
			continue
		var sb: StyleBoxFlat = cbd.tile_sb
		if sb != null:
			# 常态收回木牌暗金边（原来收成 1px 半透明金，边缘虚掉不像同一块牌子）
			sb.border_color = Color("f08a4b") if armed else WOOD_BORDER
			sb.set_border_width_all(2)


## 径向指令置灰（P03：剧情首领战不可撤退）：灰边 + 整块压暗，点了只出文案
func _set_radial_disabled(key: String, disabled: bool) -> void:
	for cbd in _cmd_btns:
		if String(cbd.key) != key:
			continue
		var root := cbd.root as Control
		var sb: StyleBoxFlat = cbd.tile_sb
		if sb != null:
			sb.border_color = Color(0.32, 0.27, 0.22) if disabled else WOOD_BORDER
			sb.set_border_width_all(2)
		root.modulate = Color(0.55, 0.52, 0.48) if disabled else Color.WHITE
		var l := cbd.label as Label
		if l != null:
			l.add_theme_color_override("font_color",
				Color("7d7266") if disabled else Color("ffe9b0"))
		cbd["disabled"] = disabled


## 径向指令是否被置灰
func _radial_disabled(key: String) -> bool:
	for cbd in _cmd_btns:
		if String(cbd.key) == key:
			return bool(cbd.get("disabled", false))
	return false


## 改写某枚指令的后果文案（P03：普通怪「退出本节点，保留战损与进度」／剧情首领「首领战不可撤退」）
func _set_radial_hint(key: String, text: String) -> void:
	for cbd in _cmd_btns:
		if String(cbd.key) != key:
			continue
		cbd["hint"] = text
		var root := cbd.root as Control
		if root != null:
			root.tooltip_text = text


## 某枚指令的当前后果文案
func _radial_hint(key: String) -> String:
	for cbd in _cmd_btns:
		if String(cbd.key) == key:
			return String(cbd.get("hint", ""))
	return ""


## 收页：收起技能/道具弹出条，回到常驻径向菜单
func _close_page() -> void:
	if _page_panel != null:
		_page_panel.hide()
	if _page_energy_l != null:
		_page_energy_l.hide()
	_command_page = "root"
	if _cmd_root != null and not sim.finished:
		_cmd_root.show()


func _clear_command_options() -> void:
	_page_rows = 0
	if _page_panel == null:
		return
	for child in _page_panel.get_children():
		child.queue_free()


## 按行数把弹出页撑成「底边不动、向上生长」的竖排列表；行高固定 PAGE_ROW_H
func _open_page_panel(rows: int) -> void:
	if _page_panel == null:
		return
	_page_panel.size = Vector2(PAGE_PANEL_SIZE.x, float(rows) * PAGE_ROW_H + 4.0)
	_page_panel.position = Vector2(PAGE_PANEL_POS.x,
		PAGE_PANEL_BOTTOM + _classic_extra_y() - _page_panel.size.y)
	if _cmd_root != null:
		_cmd_root.hide()
	_page_panel.show()


## 弹页里的一行：左名（亮） + 右侧灰色详情，整行可点。行高 28 → 触控达标。
func _add_command_row(name_text: String, detail_text: String, action: Callable,
		tooltip := "", name_color := Color("ffe9b0")) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(PAGE_PANEL_SIZE.x, PAGE_ROW_H)
	row.size = Vector2(PAGE_PANEL_SIZE.x, PAGE_ROW_H)
	row.position = Vector2(0, 2.0 + float(_page_rows) * PAGE_ROW_H)
	row.tooltip_text = tooltip
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var nl := G.gold_label(name_text, G.FS_SM, true, name_color, true)
	nl.position = Vector2(8, 8)
	nl.custom_minimum_size = Vector2(148, PAGE_ROW_H - 16)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.clip_text = true
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nl)
	var dl := G.gold_label(detail_text, G.FS_XS, false, Color("e5d4ac"), true)
	dl.position = Vector2(158, 8)
	dl.custom_minimum_size = Vector2(PAGE_PANEL_SIZE.x - 166.0, PAGE_ROW_H - 16)
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dl.clip_text = true
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dl)
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			action.call())
	_page_panel.add_child(row)
	_page_rows += 1
	return row


## 技能范围的玩家话术（详情列用）
func _range_text(target_type: String) -> String:
	return {
		"enemy_single": "单体", "enemy_front_all": "前排全体", "enemy_all": "全体",
		"enemy_back_single": "后排单体", "enemy_random": "随机单体",
		"ally_single": "友方单体", "ally_all": "友方全体", "self": "自身",
	}.get(target_type, "单体")


## 技能等级：与 BattleSim 用同一来源（ally.skill_levels），无则回落局外养成值
func _skill_lv(sid: String) -> int:
	var levels: Variant = (_cfg.get("ally", {}) as Dictionary).get("skill_levels")
	if levels is Dictionary and (levels as Dictionary).has(sid):
		return maxi(1, int((levels as Dictionary)[sid]))
	return G.skill_level(sid)


## 技能页：整宽竖排——每个技能一行（名 + Lv/耗/冷/范围），底部一行返回，点按释放后收页
func _show_command_skills() -> void:
	if _page_panel == null:
		return
	var role := sim.role_unit()
	if sim.finished or role == null or role.skills.is_empty():
		_show_tip("当前没有可用技能")
		_close_page()
		return
	_command_page = "skills"
	_clear_command_options()
	for i in mini(5, role.skills.size()):
		var skill: Dictionary = role.skills[i]
		var sdef: Dictionary = skill.def
		var sid := String(sdef.get("id", ""))
		var sname := String(sdef.get("name", sid))
		var cost := int(sdef.get("cost", 0))
		var cd_left := _skill_cd(role, sid)
		var cd_txt := "就绪" if cd_left <= 0 else "%.1fs" % (float(cd_left) / 30.0)
		var detail := "Lv%d · 耗%d · 冷 %s · %s" % [self._skill_lv(sid), cost, cd_txt,
			_range_text(String(sdef.get("target", "")))]
		var usable := cd_left <= 0 and cost <= role.energy
		_add_command_row(sname, detail, Callable(self, "_cast_command_skill").bind(sid),
			"%s · 消耗 %d 能量" % [sname, cost],
			Color("ffe9b0") if usable else Color("8f8068"))
	_add_command_row("返", "返回战场指令", Callable(self, "_close_page"), "返回战场指令")
	_open_page_panel(_page_rows)
	# 底部能量横条撤掉后，能量数值就在这一页露一次（常驻表达交给脚下蓝条）
	if _page_energy_l != null:
		_page_energy_l.position = Vector2(PAGE_PANEL_POS.x, _page_panel.position.y - 20.0)
		_page_energy_l.text = "能量 %d/%d" % [role.energy, Combatant.MAX_ENERGY]
		_page_energy_l.show()


## 道具页：药剂（剩余数 / 冷却 / 回复比例）+ 换宠（每场一次 / 替补名）+ 返回
func _show_command_items() -> void:
	if _page_panel == null:
		return
	_command_page = "items"
	_clear_command_options()
	var potion_detail := "恢复 %d%% 生命" % roundi(float(BattleSim.POTION_HEAL_PCT) * 100.0)
	if sim.potion_cd_ticks > 0:
		_add_command_row("药剂 ×%d" % sim.potions_left,
			"冷却 %.0fs · %s" % [float(sim.potion_cd_ticks) / 30.0, potion_detail],
			Callable(self, "_command_use_potion"), "恢复生命；冷却中不可用",
			Color("8f8068"))
	else:
		_add_command_row("药剂 ×%d" % sim.potions_left, potion_detail,
			Callable(self, "_command_use_potion"), "恢复生命；冷却中不可用")
	if sim.pet_bench_id != "":
		var pet_name := String(TableCache.get_pet(sim.pet_bench_id).get("name", sim.pet_bench_id))
		var swap_txt := "本场已换过" if sim.pet_swap_used else "每场一次"
		_add_command_row("换宠", "%s · %s" % [swap_txt, pet_name],
			Callable(self, "_command_swap_pet"), "换上替补宠物（每场一次）",
			Color("ffe9b0") if not sim.pet_swap_used else Color("8f8068"))
	_add_command_row("返", "返回战场指令", Callable(self, "_close_page"), "返回战场指令")
	_open_page_panel(_page_rows)


func _command_attack() -> void:
	if sim.finished:
		_close_page()
		return
	var role := sim.role_unit()
	var enemies := sim.alive_units("enemy")
	if role != null and role.attack_range == "melee":
		var front: Array[Combatant] = []
		for enemy in enemies:
			if enemy.row == Combatant.ROW_FRONT:
				front.append(enemy)
		if not front.is_empty():
			enemies = front
	if enemies.is_empty():
		_show_tip("没有可攻击的目标")
		_close_page()
		return
	var current := -1
	for i in enemies.size():
		if enemies[i].uid == sim.role_focus_target_uid:
			current = i
			break
	var target: Combatant = enemies[(current + 1) % enemies.size()]
	if sim.set_role_focus_target(target.uid):
		_sync_views()
		_show_tip("集火目标 · %s" % target.name, Color("ffe08a"))
	_close_page()


func _cast_command_skill(sid: String) -> void:
	_try_cast(sid)
	_close_page()


## 「物」：开道具页（药剂 / 换宠），不再直接喝药——与底部功能行撤掉后的入口对齐
func _command_item() -> void:
	if sim.finished:
		_close_page()
		return
	_show_command_items()


func _command_use_potion() -> void:
	var before := sim.potions_left
	_use_potion()
	if sim.potions_left == before:
		_show_tip("药剂暂不可用")
	else:
		_close_page()


func _command_swap_pet() -> void:
	if not sim.swap_pet():
		_show_tip("本场已换过宠物")
		return
	_consume_events()
	_sync_views()
	_close_page()


func _command_flee() -> void:
	_close_page()
	# P03：剧情首领战禁止撤退——按钮已置灰，这里再兜一层（键盘/脚本调用也不放行）
	if _flee_blocked:
		_show_tip("首领战不可撤退", G.C_COST, G.FS_MD, Color("3a0e0a"), 2)
		return
	_on_flee()


# ================= 单位视图 =================
func _spawn_view(u: Combatant) -> UnitView:
	var v := UnitView.new()
	var enemy_cfg: Dictionary = _cfg.get("enemy", {})
	# P05-C：怪物立绘先按单位 id 查 sprite_paths（首领召唤的影狼要用自己的图），
	# 查不到再退回本场 lead_mon 的那张。玩家/宠物恒走职业立绘。
	var mon_sprite := ""
	if u.kind == "monster":
		mon_sprite = String(enemy_cfg.get("sprite_path", ""))
		var paths: Variant = enemy_cfg.get("sprite_paths", {})
		if paths is Dictionary:
			var override := String((paths as Dictionary).get(String(u.data.get("id", "")), ""))
			if not override.is_empty():
				mon_sprite = override
	v.setup(u, ROLE_SPRITE, MON_COLOR, _classic_presentation(), mon_sprite)
	v.position = _grid_pos(u.side, u.row, u.col)
	if _classic_presentation():
		if u.kind == "role":
			var player_name := String(_cfg.get("player_name", ""))
			if player_name.is_empty():
				player_name = "旅人"
			# 原版功能机风：名牌贴角色身右、纯绿字无底板，格式去掉「Lv」前缀
			v.set_classic_name("%s %d" % [player_name,
				int((_cfg.get("ally", {}) as Dictionary).get("level", 1))],
				Color("d7ffb0"))
		elif u.kind == "monster":
			var lv := int(enemy_cfg.get("display_level", 0))
			v._hideable_name = false
			v.set_classic_name("Lv%d %s" % [lv, u.name] if lv > 0 else u.name,
				Color("ebbbff"))
		else:
			v.set_classic_name(u.name, Color("e8e4bd"))
		if u.kind == "pet":
			# 经典模式宠物站到角色左下：原来贴右上时，宠物名牌左缘离「攻」木牌右缘
			# 只差 1px，两块牌子视觉上粘在一起；挪到左下后与最左的「技」「逃」木牌
			# 错开一整格，同时把身右一线全让给玩家名牌。
			# 注意宠物自己那一格比角色高一行（col 小 1），必须按"角色锚点 + 偏移"
			# 反算基准位移，不能直接给死值，否则宠物会落在角色侧上方压住「技」木牌。
			var anchor := _grid_pos(u.side, u.row, u.col)
			var role_u := sim.role_unit()
			var role_anchor := _grid_pos(role_u.side, role_u.row, role_u.col) \
				if role_u != null else anchor
			v.set_body_home(role_anchor + Vector2(-72.0, 96.0) - anchor)
	_field.add_child(v)
	return v


func _grid_pos(side: String, row: int, col: int) -> Vector2:
	return classic_grid_pos(side, row, col)


static func classic_grid_pos(side: String, row: int, col: int) -> Vector2:
	var y := CLASSIC_COL_Y + col * CLASSIC_COL_GAP
	if side == "enemy":
		return Vector2(CLASSIC_ENEMY_BACK_X if row == Combatant.ROW_BACK \
			else CLASSIC_ENEMY_FRONT_X, y)
	return Vector2(CLASSIC_ALLY_BACK_X if row == Combatant.ROW_BACK \
		else CLASSIC_ALLY_FRONT_X, y)


func _sync_views() -> void:
	var spread_boss := false
	var enemy_count := 0
	for unit in sim.units:
		if unit.side == "enemy":
			enemy_count += 1
			if unit.kind == "monster" and String(unit.data.get("tier", "")) == "boss":
				spread_boss = true
	spread_boss = spread_boss and enemy_count > 1
	for u in sim.units:
		if not _views.has(u.uid):
			_views[u.uid] = _spawn_view(u)
			if sim.tick_count > 0:  # 战斗中入场（召唤/换宠）
				_views[u.uid].pop_in()
		var view: UnitView = _views[u.uid]
		# Large boss art and summoned front units need separate horizontal lanes.
		view._formation_offset = Vector2.ZERO
		if spread_boss and u.side == "enemy":
			view._formation_offset.x = -50.0 if String(u.data.get("tier", "")) == "boss" \
				else (65.0 if u.row == Combatant.ROW_FRONT else 0.0)
		view.sync(u)
		(_views[u.uid] as UnitView).set_focused(
			u.alive and u.uid == sim.role_focus_target_uid)
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
			_refresh_omens()   # 收招后预兆环必须消失，别留在结算画面上
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
	_refresh_omens()
	_refresh_hud()


func _consume_events() -> void:
	_skill_motion_sources.clear()
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
				src.play_state(&"attack")
				var attacker := sim.unit_by_uid(src.uid)
				if attacker != null and attacker.attack_range == "range":
					_launch_ranged_shot(src, dst)
				else:
					_launch_melee_strike(src, dst)
			if t == "cast": _skill_motion_sources[int(e.get("uid", -1))] = true
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
				# P03：进前摇就报「谁 · 哪招 · 还要蓄多久」，每帧按剩余前摇倒数（预兆环同时画在地上）
				_windup_uid = int(e.get("uid", -1))
				_windup_tier = tier
				_windup_name = String(e.get("name", ""))
				_windup_total[_windup_uid] = maxi(1, _windup_ticks(_windup_uid, 12))
				_announce_windup()
				if tier == "boss":
					_shake(SHAKE_HIT * 0.7)   # 首领抬手先晃一下，算预警
					Audio.sfx("boss_warn")
				else:
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
				if not dot and _defer_ranged_hit(e):
					return
				if not dot and src != null and _skill_motion_sources.has(src.uid):
					var attacker := sim.unit_by_uid(src.uid)
					if attacker != null and attacker.side != target.side:
						if attacker.attack_range == "range": _launch_ranged_shot(src, dst)
						else: _launch_melee_strike(src, dst)
						if _defer_ranged_hit(e): return
				_present_damage_feedback(dst, e, heavy, to_role)
		"heal":
			if dst != null:
				_float(dst.position, "+%d" % int(e.amount), G.C_GAIN, G.FS_MD)
				CombatFX.impact(_fx_layer, dst.body.global_position-_fx_layer.global_position+Vector2(0,-24), "heal",Color("a6efbc"))
		"shield_add":
			if dst != null:
				_float(dst.position, "+盾", Color("8cc4ff"), G.FS_SM)
		"skill_effective", "curriculum_effective":
			var role_effect := sim.role_unit()
			var sid := String(e.get("skill", ""))
			if role_effect != null and int(e.get("uid", -1)) == role_effect.uid \
					and not sid.is_empty() and not effective_skills.has(sid):
				effective_skills.append(sid)
		"cleanse":
			if dst != null:
				_float(dst.position, "净化", Color("cfe8ff"), G.FS_SM)
		"companion_trait":
			var trait_id := String(e.get("trait",""))
			var title := "护卫" if trait_id == "comp_guard" else ("追击" if trait_id == "comp_pursuit" else "元素响应")
			if src != null:
				src.play_state(&"attack" if trait_id == "comp_pursuit" else &"cast")
				src.cast_glow()
				if dst != null and trait_id == "comp_pursuit": src.lunge(dst.position)
			if src != null and dst != null: _companion_effect(src,dst,trait_id)
			if dst != null: _float(dst.position+Vector2(0,-40),title,G.C_COMPANION,G.FS_SM)
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
			# P05-C 顺手修：文案里混了个英文单词（"敌方召唤 reinforcements！"），全中文 UI 里
			# 只有这一处漏网；失路兽召影狼正好会走到这里，趁机制落地一并统一口径。
			_show_tip("敌方召唤援兵！")
		"pet_enter":
			_show_tip("替补宠物入场")
		"pet_leave":
			pass
		"phase":
			# P03：首领进入新阶段——居中横幅 + 血条追加阶段名，让玩家知道「规则变了」
			_boss_phase_name = String(e.get("name", ""))
			_show_phase_banner(_boss_phase_name, String(e.get("announce", "")))
			_shake(SHAKE_HIT)
			Audio.sfx("boss_warn")
		"victory", "defeat", "timeout":
			pass


func _refresh_hud() -> void:
	# 能量
	var role := sim.role_unit()
	# 经典模式不建底部能量横条（为 null），能量只走角色脚下蓝条；数值改在「技」页露一次
	if role != null and _energy_fill != null:
		var ratio := float(role.energy) / float(Combatant.MAX_ENERGY)
		# 填充宽 = 底条宽 - 左右各 1px 内缩，与 _build_skill_bar 的 _energy_fill 起点/尺寸一致
		_energy_fill.size.x = (_energy_bar_w - 2.0) * ratio
		_energy_l.text = "能量 %d/100%s" % [role.energy, "  满" if role.energy >= Combatant.MAX_ENERGY else ""]
	if role != null and _page_energy_l != null and _page_energy_l.visible:
		_page_energy_l.text = "能量 %d/%d" % [role.energy, Combatant.MAX_ENERGY]
	# B4 首领血条刷新：名字 + 百分比，填充宽按当前血量比例缩放（P03：进阶段后追阶段名）
	if _boss_fill != null:
		var boss := _boss_unit()
		if boss != null:
			var bratio := clampf(float(boss.hp) / float(maxi(boss.get_max_hp(), 1)), 0.0, 1.0)
			_boss_fill.size.x = (_boss_bar_w - 2.0) * bratio
			var suffix := "  · %s" % _boss_phase_name if _boss_phase_name != "" else ""
			_boss_name_l.text = "%s  %d%%%s" % [boss.name, roundi(bratio * 100.0), suffix]
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
			_danger.modulate.a = 0.12 + 0.23 * absf(sin(phase * PI))   # 边缘红晕：够警觉不糊屏
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
			# 经典模式常态收回木牌暗金边，和指令牌 / 弹页牌是同一块牌子的同一支边色
			sb.border_color = WOOD_BORDER if _classic_presentation() \
				else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.4)
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
	# 药剂 / 换宠（药剂 CD 中显示剩余秒数；经典模式无底部功能行， _potion_l 为 null）
	if _potion_l != null:
		if sim.potion_cd_ticks > 0:
			_potion_l.text = "药剂 %.0fs" % (float(sim.potion_cd_ticks) / 30.0)
		else:
			_potion_l.text = "药剂 ×%d" % sim.potions_left
	if _pet_btn != null:
		_chip_set_active(_pet_btn, not sim.pet_swap_used and sim.pet_bench_id != "")
	# 径向指令菜单：角色倒下 / 结算后整组隐藏，弹出页同步收掉
	if _cmd_root != null:
		var cmd_alive := role != null and role.alive and not sim.finished
		_cmd_root.visible = cmd_alive and _command_page == "root"
		if not cmd_alive:
			_close_page()
	# P03：敌方前摇实时倒数（预兆环在地面同步收缩）
	_refresh_windup_tip()
	_refresh_cmd_info()


## P03 常驻信息条：四枚指令之上的一行事实——攻谁 / 几个技能放得出来 / 药还剩几瓶。
## 只读 sim 与已缓存的 _cfg，**不调用 pick_basic_target**（混乱态会摇随机，逐帧调用会污染确定性）。
func _refresh_cmd_info() -> void:
	if _cmd_info_l == null:
		return
	var role := sim.role_unit()
	var atk_txt := "自动选敌"
	var focus := sim.unit_by_uid(sim.role_focus_target_uid)
	if focus != null and focus.alive and focus.side == "enemy":
		var pct := roundi(100.0 * float(focus.hp) / float(maxi(focus.get_max_hp(), 1)))
		atk_txt = "集火 %s %d%%" % [focus.name, pct]
	var usable := 0
	if role != null:
		for s in role.skills:
			if int(s.cd_left) <= 0 and int(s.def.get("cost", 0)) <= role.energy:
				usable += 1
	var pot_txt := "药×%d" % sim.potions_left
	if sim.potion_cd_ticks > 0:
		pot_txt = "药%.0fs" % (float(sim.potion_cd_ticks) / 30.0)
	_cmd_info_l.text = "攻 %s ｜ 技 %d/%d ｜ 物 %s" % [atk_txt, usable,
		role.skills.size() if role != null else 0, pot_txt]


## P03 预兆（文字）：把「首领技 · 碑震 · 蓄力 0.4s」按剩余前摇逐帧倒数。
## 只在真的还有这条前摇时才改写提示；前摇一落地就放手，让下一条提示（伤害/连携）自己说话。
func _refresh_windup_tip() -> void:
	if _windup_uid < 0:
		return
	var remain := -1
	for q in sim.cast_queue:
		if int(q.get("uid", -1)) == _windup_uid:
			remain = int(q.get("windup", 0))
			_windup_name = String((q.get("skill", {}) as Dictionary).get("name", _windup_name))
			break
	if remain < 0:
		_windup_uid = -1
		return
	_announce_windup()


## 写一条前摇提示（首帧与逐帧倒数共用同一处文案口径）
func _announce_windup() -> void:
	var prefix := "首领技" if _windup_tier == "boss" else "敌方"
	var color := Color("ff8a6a") if _windup_tier == "boss" else Color("ffb0a0")
	var secs := _windup_remain_sec()
	if secs > 0.0:
		_show_tip("%s · %s · 蓄力 %.1fs" % [prefix, _windup_name, secs], color)
	else:
		_show_tip("%s · %s" % [prefix, _windup_name], color)


## 指定单位当前前摇剩余秒数（不在队列里返回 0）
func _windup_remain_sec() -> float:
	for q in sim.cast_queue:
		if int(q.get("uid", -1)) == _windup_uid:
			return float(int(q.get("windup", 0))) * TICK_SEC
	return 0.0


## 指定单位当前前摇的剩余 tick（用于算预兆环的收缩比例；无则回退 fallback）
func _windup_ticks(uid: int, fallback: int) -> int:
	for q in sim.cast_queue:
		if int(q.get("uid", -1)) == uid:
			return int(q.get("windup", fallback))
	return fallback


## P03 预兆（图形）：把 cast_queue 翻译成地上的脉动环——施法者脚下 + 将要被打者身上。
## 纯读 sim（不摇随机、不写规则）；只对敌方起手出环，玩家看的就是「接下来会挨谁的打」。
func _refresh_omens() -> void:
	if _omens == null:
		return
	var rings: Array[Dictionary] = []
	if not sim.finished:
		for q in sim.cast_queue:
			var caster := sim.unit_by_uid(int(q.get("uid", -1)))
			if caster == null or not caster.alive or caster.side != "enemy":
				continue
			var skill: Dictionary = q.get("skill", {}) if q.get("skill") is Dictionary else {}
			var heavy := String(caster.data.get("tier", "normal")) == "boss"
			var total := float(_windup_total.get(caster.uid, maxi(1, int(q.get("windup", 1)))))
			var ratio := clampf(float(int(q.get("windup", 0))) / maxf(1.0, total), 0.0, 1.0)
			var caster_view: UnitView = _views.get(caster.uid)
			if caster_view != null:
				rings.append({"pos": caster_view.position, "radius": 40.0 if heavy else 30.0,
					"ratio": ratio, "heavy": heavy, "target": false})
			for t in _omen_targets(caster, String(skill.get("target", ""))):
				var tv: UnitView = _views.get(t.uid)
				if tv != null:
					rings.append({"pos": tv.position, "radius": 34.0 if heavy else 26.0,
						"ratio": ratio, "heavy": heavy, "target": true})
	_omens.rings = rings
	_omens.queue_redraw()


## 预兆预览的目标（确定性镜像 _pick_targets 的常见分支：不摇随机、不改 sim 状态）
func _omen_targets(caster: Combatant, target_type: String) -> Array[Combatant]:
	var opp := sim.alive_units("enemy" if caster.side == "ally" else "ally")
	var out: Array[Combatant] = []
	match target_type:
		"enemy_front_all":
			for e in opp:
				if e.row == Combatant.ROW_FRONT:
					out.append(e)
		"enemy_all":
			out = opp
		"enemy_back_single":
			var best: Combatant = null
			for e in opp:
				if e.row == Combatant.ROW_BACK and (best == null or e.hp < best.hp):
					best = e
			if best != null:
				out.append(best)
		"self", "ally_single", "ally_all":
			out.append(caster)
		_:
			# enemy_single / enemy_random / 未标注：按「最低血」预告（与 basic/boss AI 同一口径）
			var low: Combatant = null
			for e in opp:
				if low == null or e.hp < low.hp:
					low = e
			if low != null:
				out.append(low)
	return out


## P03：阶段横幅——居中一条暗底带 + 阶段名 + 一句宣告，弹入后停留再淡出。
## 挂在根节点（HUD 之下与其他常驻层同族），**不放进 _fx_layer**（那儿有"战后清空"的断言）。
func _show_phase_banner(pname: String, announce: String) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var band := ColorRect.new()
	band.color = Color(0.10, 0.04, 0.02, 0.84)
	band.position = Vector2(0, 250)
	band.size = Vector2(VIEW_W, 58)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	var tl := G.gold_label("阶段 · %s" % pname, G.FS_LG, true, Color("ffd08a"), true)
	tl.position = Vector2(0, 254)
	tl.custom_minimum_size = Vector2(VIEW_W, 0)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	var al := G.gold_label(announce, G.FS_SM, true, Color("ffe9c8"), true)
	al.position = Vector2(0, 284)
	al.custom_minimum_size = Vector2(VIEW_W, 0)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	al.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(al)
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.18)
	tw.tween_interval(1.5)
	tw.tween_property(root, "modulate:a", 0.0, 0.4)
	tw.tween_callback(root.queue_free)


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
		_set_radial_armed("flee", false)
		return
	_flee_armed = true
	if _flee_btn != null:
		var l := _flee_btn.get_child(0) as Label
		if l != null:
			l.text = "确认撤退？"
		_chip_set_active(_flee_btn, true)
	else:
		# 经典模式没有撤退 chip：飘字提示 + 「逃」图标暖橙描边作为二次确认反馈。
		# 提示里带上后果口径（普通怪=退出本节点保留战损；首领战根本走不到这里）
		_show_tip("再次点击「逃」确认 · %s" % _radial_hint("flee"), Color("ffb0a0"))
		_set_radial_armed("flee", true)
	get_tree().create_timer(3.0).timeout.connect(func():
		if _flee_armed and _flee_btn != null and is_instance_valid(_flee_btn):
			_flee_armed = false
			var l2 := _flee_btn.get_child(0) as Label
			if l2 != null:
				l2.text = "撤退"
			_chip_set_active(_flee_btn, false)
		else:
			_flee_armed = false
			_set_radial_armed("flee", false))


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
	if _classic_presentation():
		match kind:
			"crit":
				_float(pos, "-%d\n暴击" % amount, Color("ef5a35"), G.FS_LG + 3, 1.30)
			"heavy":
				_float(pos, "-%d\n重击" % amount, Color("ef5a35"), G.FS_LG, 1.20)
			"dot":
				_float(pos, "-%d" % amount, Color("c7b39c"), G.FS_XS, 1.0)
			_:
				_float(pos, "-%d" % amount, Color("f0bd3f"), G.FS_MD, 1.08)
		return
	match kind:
		"crit":
			_float(pos, "暴 %d" % amount, Color("ffd24a"), G.FS_LG + 4, 1.32)
		"heavy":
			_float(pos, "%d" % amount, Color("ff9a6a"), G.FS_LG, 1.18)
		"dot":
			_float(pos, "%d" % amount, Color("b9b3aa"), G.FS_XS, 1.0)
		_:
			_float(pos, "%d" % amount, Color("ff7a6a"), G.FS_MD, 1.06)


func _hit_burst(pos: Vector2, strong: bool) -> void:
	var fx := _HitBurst.new()
	fx.position = pos
	fx.radius = 34.0 if strong else 24.0
	_fx_layer.add_child(fx)
	fx.scale = Vector2.ONE * 0.55
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector2.ONE * 1.18, 0.09).set_trans(Tween.TRANS_BACK)
	tw.tween_property(fx, "modulate:a", 0.0, 0.18).set_delay(0.07)
	tw.chain().tween_callback(fx.queue_free)

## 短暂的盾弧 / 追击连线 / 净化圈，和战斗飘字共用自动清理层。
func _companion_effect(src: UnitView, dst: UnitView, tid: String) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = G.GOLD_BRIGHT if tid == "comp_pursuit" else (G.C_COMPANION_GUARD if tid == "comp_guard" else G.C_COMPANION)
	var at := dst.global_position - _fx_layer.global_position + Vector2(0,-20)
	if tid == "comp_pursuit":
		line.add_point(src.global_position - _fx_layer.global_position + Vector2(0,-20))
		line.add_point(at)
	else:
		line.position = at
		var start := -PI * 0.85 if tid == "comp_guard" else 0.0
		var span := PI * 0.7 if tid == "comp_guard" else TAU
		for i in 25:
			var angle := start + span * i / 24.0
			line.add_point(Vector2(cos(angle)*32,sin(angle)*38))
	_fx_layer.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line,"modulate:a",0.0,0.65)
	tween.tween_callback(line.queue_free)


## 远程普攻先飞弹，再播放命中反馈；伤害结算仍在 BattleSim 原 tick 完成。
func _strike_style(src: UnitView) -> Dictionary:
	var unit := sim.unit_by_uid(src.uid)
	var id := String(unit.data.get("id", "")) if unit != null else ""
	match id:
		"ck": return {"kind":"pierce", "tint":Color("9de6ef")}
		"fs": return {"kind":"arcane", "tint":Color("91c7ff")}
		"fz": return {"kind":"hammer", "tint":Color("ffe4a3")}
	return {"kind":"slash", "tint":Color("ffe08a") if src.side == "ally" else Color("ff9a73")}


func _launch_melee_strike(src: UnitView, dst: UnitView) -> void:
	var key := "%d:%d" % [src.uid,dst.uid]
	var state := {"key":key,"event":{},"target":null,"dst":dst,"arrived":false,"shot":null}
	var waiting: Array = _ranged_waiting.get(key,[])
	waiting.append(state)
	_ranged_waiting[key] = waiting
	dst.hold_hp_bar()
	var style := _strike_style(src)
	CombatFX.trail(_fx_layer,src.body,style.tint)
	var duration := src.lunge(dst.position+dst._body_home)
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(Callable(self,"_on_ranged_shot_arrived").bind(key,state))


func _launch_ranged_shot(src: UnitView, dst: UnitView) -> void:
	var key := "%d:%d" % [src.uid, dst.uid]
	var state := {"key": key, "event": {}, "target": null, "dst": dst,
		"arrived": false, "shot": null}
	var waiting: Array = _ranged_waiting.get(key, [])
	waiting.append(state)
	_ranged_waiting[key] = waiting
	dst.hold_hp_bar()

	var shot := _RangedShot.new()
	var style := _strike_style(src)
	shot.tint = style.tint
	shot.kind = style.kind
	var start: Vector2 = src.body.global_position + Vector2(0, -28) - _fx_layer.global_position
	var finish: Vector2 = dst.body.global_position + Vector2(0, -28) - _fx_layer.global_position
	shot.position = start
	shot.rotation = (finish - start).angle()
	state["shot"] = shot
	_fx_layer.add_child(shot)
	var duration := clampf(start.distance_to(finish) / 1500.0, 0.075, 0.18)
	var tw := create_tween()
	tw.tween_property(shot, "position", finish, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(Callable(self, "_on_ranged_shot_arrived").bind(key, state))


func _defer_ranged_hit(e: Dictionary) -> bool:
	var key := "%d:%d" % [int(e.get("src", -1)), int(e.get("uid", -1))]
	var waiting: Array = _ranged_waiting.get(key, [])
	for item in waiting:
		var state: Dictionary = item
		var hit_event: Dictionary = state.get("event", {})
		if hit_event.is_empty():
			state["event"] = e.duplicate(true)
			state["target"] = sim.unit_by_uid(int(e.get("uid", -1)))
			if bool(state.get("arrived", false)):
				_finish_ranged_shot(key, state)
			return true
	return false


func _on_ranged_shot_arrived(key: String, state: Dictionary) -> void:
	state["arrived"] = true
	_finish_ranged_shot(key, state)


func _finish_ranged_shot(key: String, state: Dictionary) -> void:
	var shot: Node2D = state.get("shot")
	if is_instance_valid(shot):
		shot.queue_free()
	var dst: UnitView = state.get("dst")
	var e: Dictionary = state.get("event", {})
	if not e.is_empty() and is_instance_valid(dst):
		var target: Combatant = state.get("target")
		if target != null:
			var amount := int(e.get("amount", 0))
			var heavy := amount >= int(float(maxi(target.get_max_hp(), 1)) * HEAVY_RATIO)
			var role := sim.role_unit()
			var to_role := role != null and int(e.get("uid", -1)) == role.uid
			_present_damage_feedback(dst, e, heavy, to_role)
	if is_instance_valid(dst):
		dst.release_hp_bar()
	_remove_ranged_state(key, state)


func _remove_ranged_state(key: String, state: Dictionary) -> void:
	var waiting: Array = _ranged_waiting.get(key, [])
	waiting.erase(state)
	if waiting.is_empty():
		_ranged_waiting.erase(key)
	else:
		_ranged_waiting[key] = waiting


func _present_damage_feedback(dst: UnitView, e: Dictionary, heavy: bool, to_role: bool) -> void:
	var amount := int(e.get("amount", 0))
	var crit := bool(e.get("crit", false))
	var dot := bool(e.get("dot", false))
	var fx_pos: Vector2 = dst.body.global_position - _fx_layer.global_position
	if dot:
		dst.hit_flash(0.4)
		_float_dmg(fx_pos, amount, "dot")
	elif crit:
		dst.hit_flash()
		_float_dmg(fx_pos, amount, "crit")
		_shake(SHAKE_CRIT)
		_hit_stop(HITSTOP_STEP)
		Audio.sfx("hit_crit")
	elif heavy:
		dst.hit_flash()
		_float_dmg(fx_pos, amount, "heavy")
		_shake(SHAKE_HEAVY)
		_hit_stop(HITSTOP_STEP)
		Audio.sfx("hit_heavy")
	else:
		dst.hit_flash()
		_float_dmg(fx_pos, amount, "hit")
		Audio.sfx("hit_light")
		if to_role:
			_shake(SHAKE_HIT)
	if not dot:
		_hit_burst(fx_pos + Vector2(0, -22), crit or heavy)
		var source: UnitView = _views.get(int(e.get("src",-1)))
		var style := _strike_style(source) if source != null else {"kind":"slash","tint":Color("ffce92")}
		CombatFX.impact(_fx_layer,fx_pos+Vector2(0,-28),style.kind,style.tint,crit or heavy)
		if source != null: dst.recoil(source.position)
	if to_role and not dot:
		dst.play_state(&"hit")


func _show_tip(msg: String, color := Color("ffe9b0"), size := 0,
		outline_color := Color(0, 0, 0, 0), outline_size := 0) -> void:
	_cast_tip.add_theme_color_override("font_color", color)
	# 字号/描边按调用重置：危急提示要"红字 + 深红描边"更刺眼，普通提示回到常态，
	# 避免上一次的告警样式残留到后一条提示上
	_cast_tip.add_theme_font_size_override("font_size", size if size > 0 else G.FS_SM)
	_cast_tip.add_theme_constant_override("outline_size", maxi(2, outline_size))
	_cast_tip.add_theme_color_override("font_outline_color",
		outline_color if outline_size > 0 else Color(0.10, 0.07, 0.04, 0.9))
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
		for pet_v in TableCache.pets():
			for pet_skill_v in (pet_v as Dictionary).get("skills", []):
				if String((pet_skill_v as Dictionary).get("id", "")) == skill_id:
					sd = pet_skill_v as Dictionary
					break
			if not sd.is_empty():
				break
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
	# A pet may trigger its own skill and a guard response on the same frame.
	# Keep one current action card per caster so neither name is half-covered.
	for previous in _fx_layer.get_children():
		if previous.get_meta("skill_caster", -1) == caster.uid:
			_fx_layer.remove_child(previous)
			previous.queue_free()
	var tex: Texture2D = G.res_tex("sk_%s" % skill_id)
	var sname := String(TableCache.get_skill(skill_id).get("name", skill_id))
	if tex == null and sim != null:
		var caster_unit := sim.unit_by_uid(caster.uid)
		if caster_unit != null and caster_unit.kind == "pet":
			tex = G.res_tex(String(caster_unit.data.get("id", "")))
			for slot_v in caster_unit.skills:
				var slot := slot_v as Dictionary
				if String(slot.get("id", "")) == skill_id:
					sname = String((slot.get("def", {}) as Dictionary).get("name", skill_id))
					break
	if tex == null:
		return
	var card := G.InsetPanel.new()
	card.set_meta("skill_caster", caster.uid)
	# 施法信息卡：切角 + 金描边，弃用圆角5的平面块
	card.setup(Color("203437", 0.96), G.GOLD_BRIGHT, 6.0, 10.0, 4.0, 4.0)
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
	card.position.x = clampf(card.position.x, 12.0, VIEW_W - w - 12.0)
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
	_close_page()
	if _cmd_root != null:
		_cmd_root.hide()
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
## P03 预兆层：把「谁在起手、这一招要打谁」画成地面的脉动环。
## 纯表现：只拿到 BattleScene 每帧算好的 rings，自己不含任何 sim 访问与随机。
class _Omens extends Node2D:
	var rings: Array[Dictionary] = []

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec() % 900) / 900.0 * TAU)
		for r in rings:
			var pos: Vector2 = r.get("pos", Vector2.ZERO)
			var ratio := clampf(float(r.get("ratio", 1.0)), 0.0, 1.0)
			var heavy := bool(r.get("heavy", false))
			var base_r := float(r.get("radius", 30.0))
			var rad := base_r * (0.35 + 0.65 * ratio)      # 随剩余前摇收缩：越紧越危险
			var col := Color("ff8a5a") if heavy else Color("ffd08a")
			var w := 4.0 if heavy else 2.0
			var a := (0.30 + 0.30 * (1.0 - ratio)) * (0.7 + 0.3 * pulse)
			col.a = a
			draw_arc(pos, rad, 0.0, TAU, 48, col, w, true)
			draw_arc(pos, rad * 0.58, 0.0, TAU, 36,
				Color(col.r, col.g, col.b, a * 0.5), 1.0, true)
			if bool(r.get("target", false)):
				# 将要挨打的人：环内再填一层薄色，玩家一眼认出「这圈里的会吃到」
				draw_circle(pos, rad * 0.92, Color(col.r, col.g, col.b, a * 0.20))


class _LineDrawer extends Node2D:
	var color := Color.WHITE
	func _draw() -> void:
		draw_line(Vector2(24, 0), Vector2(456, 0), color, 2.0)


## 原版式硬边星芒：白黄亮心、黄橙放射、红褐尖角，短促而清晰。
class _HitBurst extends Node2D:
	var radius := 24.0
	func _ready() -> void:
		queue_redraw()
	func _draw() -> void:
		var outer := _star(16, radius, 0.28, 0.0)
		draw_colored_polygon(outer, Color("b63824"))
		_draw_outline(outer, Color("61261d"), 2.0)
		var middle := _star(16, radius * 0.74, 0.22, 0.10)
		draw_colored_polygon(middle, Color("ef722c"))
		_draw_outline(middle, Color("b63824"), 1.0)
		var core := _star(8, radius * 0.38, 0.40, 0.0)
		draw_colored_polygon(core, Color("ffcf3a"))
		var glint := PackedVector2Array([
			Vector2(0, -radius * 0.22), Vector2(radius * 0.14, 0),
			Vector2(0, radius * 0.24), Vector2(-radius * 0.13, 0),
		])
		draw_colored_polygon(glint, Color("fff4c6"))

	func _star(count: int, r: float, inner: float, offset: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in count:
			var angle := TAU * float(i) / float(count) + offset
			var length := r if i % 2 == 0 else r * inner
			points.append(Vector2(cos(angle), sin(angle)) * length)
		return points

	func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
		var edge := points.duplicate()
		edge.append(points[0])
		draw_polyline(edge, color, width, false)


## 横向小箭矢只作远程普攻表现，不承载命中判定或伤害数值。
class _RangedShot extends Node2D:
	var tint := Color("ffe08a")
	var kind := "pierce"
	func _ready() -> void:
		queue_redraw()
	func _draw() -> void:
		draw_line(Vector2(-36,0),Vector2(2,0),Color(tint,.22),8)
		draw_line(Vector2(-28,-2),Vector2(4,-2),Color(tint,.65),2)
		if kind == "arcane":
			draw_circle(Vector2(6,0),9,Color(tint,.3))
			draw_colored_polygon(PackedVector2Array([Vector2(16,0),Vector2(6,-6),Vector2(-2,0),Vector2(6,6)]),tint)
			draw_line(Vector2(6,-9),Vector2(6,9),Color("eef9ff"),2)
			return
		draw_line(Vector2(-16, 2), Vector2(7, 2), Color(0.16, 0.09, 0.04, 0.7), 6.0, true)
		draw_line(Vector2(-18, 0), Vector2(5, 0), tint.darkened(0.35), 3.0, true)
		draw_line(Vector2(-17, -1), Vector2(3, -1), tint.lightened(0.26), 1.2, true)
		var head := PackedVector2Array([
			Vector2(13, 0), Vector2(3, -5), Vector2(5, 0), Vector2(3, 5),
		])
		draw_colored_polygon(head, tint)
		draw_line(Vector2(-10, 0), Vector2(-18, -4), tint, 1.4, true)
		draw_line(Vector2(-10, 0), Vector2(-18, 4), tint, 1.4, true)


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
	var energy_bg := ColorRect.new()
	var energy_fg := ColorRect.new()
	var name_l := Label.new()
	var name_bg: Panel = null
	var buff_l := Label.new()
	var shield_ring: Line2D = null
	var _target_mark: Polygon2D = null
	var _base_pos := Vector2.ZERO
	## 身体基准位移：经典模式给宠物挪位（左下避开身周木牌）也写这里。
	## body.position 是战斗动画共用通道（lunge / 复位都往它写），直接改会被下一次
	## 动作抹掉——所以基准位移必须单独存，动画只做"基准 + 摆动"。
	var _body_home := Vector2.ZERO
	var _formation_offset := Vector2.ZERO
	var _dead := false
	var _radius := 22.0
	var _draw_color := Color.WHITE
	var _is_blob := false            # 怪/宠无素材时回退程序圆体
	var _hideable_name := false      # 杂兵名签：常态隐藏、受击亮 1.4s
	var _name_fade := 0.0
	var _last_hp := -1
	var _hp_ratio := 1.0               # B2 真实血量比例（sync 更新）
	var _pending_hp_ratio := 1.0       # 远程命中抵达前暂存的新血量
	var _hp_hold_count := 0
	var _ghost_ratio := 1.0            # B2 残影条比例（_process 缓动追赶）
	var _classic := false
	var _motion_tween: Tween
	var _contact_msec := 0
	var _recoil_tween: Tween
	var _sprite_home := Vector2.ZERO


	func setup(u: Combatant, role_sprites: Dictionary, mon_colors: Dictionary,
			classic := false, monster_sprite_path := "") -> void:
		uid = u.uid
		side = u.side
		is_role = u.kind == "role"
		_classic = classic
		add_child(body)
		var name_y := 0.0   # 名字 y（头顶上方）
		var hp_y := 0.0     # 血条 y（脚下）
		if is_role:
			# 岩龟「护主甲」与人物自带护盾共用这条状态提示：蓝色轮廓随真实 shield buff 显隐。
			shield_ring = Line2D.new()
			shield_ring.width = 2.5
			shield_ring.default_color = Color("9bd8ff", 0.82)
			shield_ring.z_index = -1
			for ring_i in 25:
				var a := TAU * float(ring_i) / 24.0
				shield_ring.add_point(Vector2(cos(a) * 38.0, -26.0 + sin(a) * 58.0))
			shield_ring.visible = false
			body.add_child(shield_ring)
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
				var role_scale := 0.75 if _classic else 0.55
				asp.scale = Vector2.ONE * role_scale
				asp.position = Vector2(0, 5.0-56.0*role_scale)
				asp.play()
				asp.flip_h = side == "enemy"
				# 一次性动作（普攻/施法/受击）播完自动回待机
				asp.animation_finished.connect(func():
					if not _dead and asp.animation != &"idle":
						asp.play(&"idle"))
				body.add_child(asp)
				sprite = asp
			# 128px帧按表现模式缩放，脚点仍约在单位原点下方5px。
			name_y = -100.0 if _classic else -75.0
			hp_y = 12.0
		else:
			var unit_id := String(u.data.get("id", ""))
			var tex: Texture2D = load(monster_sprite_path) as Texture2D \
				if _classic and u.kind == "monster" and not monster_sprite_path.is_empty() \
				else G.res_tex(unit_id)
			var registered := u.kind == "monster" and MonsterArt.has(unit_id)
			if registered: tex = MonsterArt.texture(unit_id)
			if tex != null:
				# 精灵素材（1254×1254 透明底，自带投影）：按档位缩放到目标身高
				var disp_h := 78.0
				if u.kind == "monster":
					var tier := String(u.data.get("tier", "normal"))
					disp_h = 128.0 if tier == "boss" else (94.0 if tier == "elite" else (110.0 if _classic else 78.0))
				else:
					disp_h = 64.0
				var sp := Sprite2D.new()
				sp.flip_h = side == "enemy"
				sp.texture = tex
				sp.scale = Vector2.ONE * (disp_h / float(tex.get_height()))
				sp.position = Vector2(0, -disp_h * 0.42)  # 脚底落在站位附近
				if registered:
					if _classic and String(u.data.get("tier", "normal")) == "normal": disp_h = 84.0
					sp.scale = Vector2.ONE * MonsterArt.display_scale(unit_id, disp_h, true)
					disp_h = tex.get_height() * sp.scale.y
					sp.position = Vector2(0, -disp_h * 0.5)
					sp.material = FrostCityArt.cutout_material()
					sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				if u.kind == "monster" and String(u.data.get("tier", "")) == "elite":
					sp.modulate = Color(1.06, 0.95, 1.12)  # 精英微紫晕（保档位辨识）
				body.add_child(sp)
				sprite = sp
				name_y = sp.position.y - disp_h * 0.5 - 14.0
				if registered: name_y -= 10.0
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
				_body_home = Vector2(0, -_radius * 0.4)
				body.position = _body_home
				name_y = -_radius - 14.0
				hp_y = _radius + 6.0
		if sprite != null: _sprite_home = sprite.position
		# 名字（头顶）——亮底战场上必须带描边，否则敌方名字糊成一片白
		name_l = G.gold_label(u.name, G.FS_XS, false,
			Color("ffd0d0") if side == "enemy" else Color("c8e8c8"), true)
		name_l.position = Vector2(-36, name_y)
		name_l.custom_minimum_size = Vector2(72, 0)
		body.add_child(name_l)
		if _classic and side == "enemy":
			_target_mark = Polygon2D.new()
			_target_mark.polygon = PackedVector2Array([
				Vector2(-7, -7), Vector2(7, -7), Vector2(0, 2)])
			_target_mark.position = Vector2(0, name_y - 11.0)
			_target_mark.color = Color("ffc94a")
			_target_mark.visible = false
			body.add_child(_target_mark)
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
		hp_fg.color = Color("e05a4a") if _classic or side == "enemy" else Color("5ab464")
		hp_fg.position = hp_bg.position + Vector2(1, 1)
		hp_fg.size = Vector2(42, 3)
		body.add_child(hp_fg)
		if _classic and is_role:
			energy_bg.color = Color(0, 0, 0, 0.65)
			energy_bg.position = hp_bg.position + Vector2(0, 6)
			energy_bg.size = Vector2(44, 4)
			body.add_child(energy_bg)
			energy_fg.color = Color("4c8fd8")
			energy_fg.position = energy_bg.position + Vector2(1, 1)
			energy_fg.size = Vector2(0, 2)
			body.add_child(energy_fg)
		# buff 缩写（血条正下）
		buff_l = G.gold_label("", G.FS_XS, false, Color("a8d8ff"), false)
		buff_l.position = Vector2(-36, hp_y + 7)
		buff_l.custom_minimum_size = Vector2(72, 0)
		body.add_child(buff_l)
		# 经典模式宠物的左下错位在 _spawn_view 里统一给（近战/远程同一位，让开身周木牌）


	func set_classic_name(value: String, color: Color, right_side := false) -> void:
		# 统一名牌语言：粗字 + 2px 深描边、无底板。原来敌宠走"深色圆角底板白字"、
		# 玩家走"裸绿字"，两套画法混在一起；玩家名压亮草地几乎看不见，敌宠底板又比
		# 名字本身抢眼。字号同时从 13 提到 16，亮底战场上先保证读得清。
		name_l.text = value
		name_l.modulate.a = 1.0
		name_l.add_theme_font_override("font", G.font_bold)
		name_l.add_theme_font_size_override("font_size", G.FS_SM)
		name_l.add_theme_color_override("font_color", color)
		name_l.add_theme_color_override("font_outline_color", Color("1c1208", 0.92))
		name_l.add_theme_constant_override("outline_size", 2)
		if name_bg != null:
			name_bg.hide()
		var text_w := ceilf(G.font_bold.get_string_size(value,
			HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_SM).x)
		if right_side:
			# 玩家：贴角色身右、纯文字无底板，与身周径向指令错高不抢图标。
			# 右缘放不下（长名字）时先左移贴精灵，再放不下就截断加省略号
			# ——等级数字必须常驻可见，名字可以短，信息不能缺。
			var x := 38.0
			var room := BattleScene.VIEW_W - 4.0 - (position.x + x)
			# 角色站在画面右侧时，优先把完整名签放到身左；旧逻辑只在剩余不足 40px
			# 才左移，54px 这种常见宽度会把四字昵称截成「角色…12」。
			if text_w > room and text_w + 16.0 <= position.x:
				x = -text_w - 12.0
				room = text_w + 4.0
			var show := value
			if text_w > room:
				# 截断时把末尾的等级数字留出来：名字可以先短，等级是战斗信息，不能缺。
				# 玩家名格式固定为 "<名字> <等级>"，按最后一个空格切出等级后缀单独保留。
				var suffix := ""
				var head := value
				var sp := value.rfind(" ")
				if sp > 0 and value.substr(sp + 1).is_valid_int():
					suffix = value.substr(sp)
					head = value.substr(0, sp)
				for i in range(head.length() - 1, -1, -1):
					show = head.substr(0, i) + "…" + suffix
					if G.font_bold.get_string_size(show,
							HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_SM).x <= room:
						break
				text_w = ceilf(G.font_bold.get_string_size(show,
					HORIZONTAL_ALIGNMENT_LEFT, -1, G.FS_SM).x)
			name_l.text = show
			name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			name_l.position = Vector2(x, -58.0)
			name_l.custom_minimum_size = Vector2(text_w + 4.0, 20.0)
			name_l.size = Vector2(text_w + 4.0, 20.0)
			name_l.clip_text = false
			return
		# 敌方 / 宠物：头顶居中、宽度自适应。底板撤掉后全屏只剩角色身周四枚木牌
		# 这一组"重"元素，名字退成纯信息层，不再和指令抢注意力。
		var width := clampf(text_w + 8.0, 40.0, 160.0)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.position.x = -width * 0.5
		name_l.custom_minimum_size = Vector2(width, 20.0)
		name_l.size = Vector2(width, 20.0)
		name_l.clip_text = false


	func sync(u: Combatant) -> void:
		if _dead:
			return
		_base_pos = _owner_grid(u)
		position = _base_pos
		var ratio := clampf(float(u.hp) / float(maxi(u.get_max_hp(), 1)), 0.0, 1.0)
		_pending_hp_ratio = ratio
		if _hp_hold_count <= 0:
			_hp_ratio = ratio
			hp_fg.size.x = 42.0 * ratio
		if _classic and is_role:
			energy_fg.size.x = 42.0 * clampf(float(u.energy) / float(Combatant.MAX_ENERGY), 0.0, 1.0)
		if shield_ring != null:
			shield_ring.visible = u.has_buff("shield")
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


	func hold_hp_bar() -> void:
		_hp_hold_count += 1


	func release_hp_bar() -> void:
		_hp_hold_count = maxi(0, _hp_hold_count - 1)
		if _hp_hold_count == 0 and not _dead:
			_hp_ratio = _pending_hp_ratio
			hp_fg.size.x = 42.0 * _hp_ratio


	func set_focused(active: bool) -> void:
		if _target_mark != null:
			_target_mark.visible = active and not _dead


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
		return BattleScene.classic_grid_pos(u.side, u.row, u.col)+_formation_offset


	func lunge(target_pos: Vector2) -> float:
		if _dead: return .01
		if _motion_tween != null and _motion_tween.is_running():
			return maxf(.01,float(_contact_msec-Time.get_ticks_msec())/1000.0)
		var delta := target_pos-(_base_pos+_body_home)
		var travel := delta.normalized()*maxf(0,delta.length()-48.0)
		var duration := clampf(travel.length()/1050.0,.12,.23)
		_contact_msec = Time.get_ticks_msec()+int(duration*1000)
		_motion_tween = body.create_tween()
		_motion_tween.tween_property(body,"position",_body_home+travel,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_motion_tween.tween_interval(.09)
		_motion_tween.tween_property(body,"position",_body_home,.21).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		return duration

	func recoil(from: Vector2) -> void:
		if sprite == null or _dead: return
		if _recoil_tween != null and _recoil_tween.is_running(): _recoil_tween.kill()
		var push := (position-from).normalized()*7
		_recoil_tween = sprite.create_tween()
		_recoil_tween.tween_property(sprite,"position",_sprite_home+push,.06)
		_recoil_tween.tween_property(sprite,"position",_sprite_home,.15)


	## 经典模式站位微调（宠物挪到角色左下）：写基准位移，动画结束后能准确回位
	func set_body_home(off: Vector2) -> void:
		_body_home = off
		body.position = _body_home


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
