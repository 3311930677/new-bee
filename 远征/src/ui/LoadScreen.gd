# LoadScreen.gd —— 清晰法师与古城背景 + 分帧预热资源 + 最短 3.5s
# 流程：Main → 本页（预热 image 素材索引与常用纹理，分帧加载不卡帧）
#       → 完成（且距进场 ≥3.5s）→ Title。加载文案轮换一点行军趣味话。
extends Control
const Wordmark := preload("res://src/ui/UIWordmark.gd")
const Grounding := preload("res://src/world/BuildingGrounding.gd")
const GROUND_IDS := ["hall", "gate", "barracks", "forge", "archive", "kennel", "storehouse", "shrine"]

const TITLE_SCENE := "res://src/ui/Title.tscn"
const MIN_SECONDS := 3.5
const PER_FRAME := 8        # 每帧预热的贴图数（59 项实际引用 + 行走帧 ≈ 数十张，分帧绰绰有余）
const CODE_PER_FRAME := 1   # 每帧顺带编译的脚本/场景数（编译只能在主线程，只能摊开几帧）
const BAR_W := 288.0        # 外框宽（问题 #1：进度条实际可用宽 = BAR_W - 2×BAR_INSET）
const BAR_H := 8.0
const BAR_INSET := 1.0

# 脚本/场景预热清单：这些「一次性开销」原本全砸在"玩家点进某个界面"的那一帧上——
# 实测 GameHome 首次进场景 533ms、第二次 31ms，差的 500ms 就是 GDScript 编译。
# 挪进加载页（这里有进度条，玩家知道在等），之后每个界面都能在 30ms 内到位。
const PRELOAD_CODE := [
	"res://src/ui/GameHome.tscn",      # 主界面（连带 GrowthPanel 六个子面板）
	"res://src/explore/MapScene.tscn", # 主城（城务层沿用 CityScene）
	"res://src/city/CityScene.tscn",   # 城务层独立入口和主世界嵌入共用
	"res://src/ui/RegionMapPanel.gd", # 主世界地区图
	"res://src/run/RouteScene.tscn",   # 路线图（连带 MapScene / BattleScene）
	"res://src/ui/WorldPanel.gd",
	"res://src/ui/CodexPanel.gd",
	"res://src/ui/GachaPanel.gd",
	"res://src/ui/ExchangePanel.gd",
	"res://src/ui/DeployPanel.gd",
	"res://src/ui/SettingsPanel.gd",
	"res://src/ui/QuestPanel.gd",
	"res://src/ui/CreateRole.tscn",
	"res://src/ui/Prologue.tscn",      # 序章（登录后入城前的一站）
	"res://src/ui/StoryBeat.tscn",     # 首领剧情演出（对峙/余韵）
	"res://src/ui/Title.tscn",
	"res://src/ui/Login.tscn",
	"res://src/ui/NameRecovery.tscn", # 旧档有职业而缺昵称时补填，不重建角色
]

# 音频预热：首播时解析 ogg 有几毫秒抖动，顺手一起热掉（音量大头是流式解码，不进这里）
const PRELOAD_AUDIO := [
	"res://assets/audio/bgm_home.ogg",
	"res://assets/audio/bgm_city.ogg",
	"res://assets/audio/bgm_title.ogg",
	"res://assets/audio/bgm_route.ogg",
	"res://assets/audio/bgm_map.ogg",
	"res://assets/audio/bgm_battle.ogg",
]

var _queue: Array[String] = []      # 待加载的贴图/音频
var _code: Array[String] = []       # 待编译的脚本/场景
var _ground: Array[String] = []
var _warm_art: Array[Texture2D] = []  # 保持预热纹理，确保同一 RID 的地基缓存被场景复用
var _total := 0
var _done := false
var _t0 := 0.0
var _bar_fill := Panel.new()
var _bar_l := Label.new()

## 测试接口：置 false 时预热带跑完也不切场景（tools/VerifyPerf.gd 直接驱动本页量耗时）
var auto_advance := true

# 行军小话：随进度轮换（0/25/50/75% 各一句）
const STAGES := [
	"整备行囊……",
	"点起篝火……",
	"擦拭兵器……",
	"准备启程……",
	"整备完成",
]


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	_build()
	_collect_queue()


func _build() -> void:
	G.page_background(self, 0.08, "res://image/background/enter.png", false)

	# 渐隐仅降低上下缘细节，保留背景原有光影。
	for which in ["top", "bottom"]:
		var grad := TextureRect.new()
		grad.set_anchors_preset(Control.PRESET_FULL_RECT)
		grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := GradientTexture2D.new()
		var g := Gradient.new()
		if which == "top":
			g.colors = PackedColorArray([Color(0.04, 0.035, 0.025, 0.52), Color(0, 0, 0, 0.0)])
			g.offsets = PackedFloat32Array([0.0, 0.35])
		else:
			g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.035, 0.03, 0.025, 0.72)])
			g.offsets = PackedFloat32Array([0.72, 1.0])
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_LINEAR
		tex.fill_from = Vector2.ZERO
		tex.fill_to = Vector2(0, 1)
		grad.texture = tex
		add_child(grad)

	var t := Wordmark.new()
	t.name = "ExpeditionWordmark"
	t.animated = false
	t.position = Vector2(100, 64)
	t.size = Vector2(280, 141)
	add_child(t)
	var sub := G.gold_label("昭元行旅录", G.FS_XS, false, Color("e3d4b8"), false)
	sub.position = Vector2(0, 212)
	sub.custom_minimum_size = Vector2(480, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	# 安静的细进度条。
	#
	# 坑（问题 #1）：原来外框是 PanelContainer、内填充是它"唯一的子控件"——
	# PanelContainer 会**无视子控件的 custom_minimum_size，把它强行铺满自己的内容矩形**，
	# 所以无论进度是多少，填充条永远是满格（0% 时看着像 100%）。
	# 改成 Panel（普通容器，不排版子节点）+ 子 Panel 显式设 size，宽度才真的按比例。
	var back := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("272b2b", 0.9)
	bsb.set_border_width_all(1)
	bsb.border_color = Color("aaa18a", 0.55)
	bsb.set_corner_radius_all(2)
	back.add_theme_stylebox_override("panel", bsb)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("d2bb88")
	fsb.set_corner_radius_all(1)
	_bar_fill.add_theme_stylebox_override("panel", fsb)
	back.position = Vector2(96, 748)
	back.size = Vector2(BAR_W, BAR_H)
	_bar_fill.position = Vector2(BAR_INSET, BAR_INSET)
	_bar_fill.size = Vector2(0, BAR_H - BAR_INSET * 2.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_bar_ratio(0.0)
	back.add_child(_bar_fill)
	add_child(back)

	_bar_l = G.gold_label("", G.FS_XS, false, Color("d8c8a8"), false)
	_bar_l.position = Vector2(96, 716)
	_bar_l.custom_minimum_size = Vector2(BAR_W, 0)
	_bar_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_bar_l)
	G.center_fixed_page.call_deferred(self)


## 进度条填充宽度（0~1）。钳制在 0~1，0 时宽度为 0（不能像 #1 那样一开始就满格）。
## 供回归用例直调：这条宽度必须真的随比例变化。
func _set_bar_ratio(ratio: float) -> void:
	var r := clampf(ratio, 0.0, 1.0)
	_bar_fill.size = Vector2((BAR_W - BAR_INSET * 2.0) * r, BAR_H - BAR_INSET * 2.0)


## 当前进度条填充宽（测试读它）
func bar_fill_width() -> float:
	return _bar_fill.size.x


## 预热清单：素材索引只建不逐张加载（场景 load 会自动带上依赖纹理，
## 全量预热 879 张图既白做又拖慢启动——实测裁掉后预热 <1s，
## 启动总时长收敛到 MIN_SECONDS 一档）。
## 只热：行走帧 + 界面大背景 + 音频 + 脚本/场景编译。
func _collect_queue() -> void:
	G._build_res_index()
	_queue.append("res://image/role/zs/pojun_walk_4dir.png")
	_queue.append("res://image/role/ck/chuanyang_walk_4dir.png")
	_queue.append("res://image/role/fs/shuangyu_walk_4dir.png")
	_queue.append("res://image/role/fz/chenxing_walk_4dir.png")
	# 三张界面大背景（1.5~2.4MB 一张，不预热的话进主城/回主页会各卡一下）
	for bg in ["home", "enter", "title", "login", "courtyard_visual_v2"]:
		if ResourceLoader.exists("res://image/background/%s.png" % bg):
			_queue.append("res://image/background/%s.png" % bg)
	for a in PRELOAD_AUDIO:
		if ResourceLoader.exists(a):
			_queue.append(a)
	# 音效（18 个小 wav）：全部热掉——第一次点击就该有回声，不该等到玩家点第二次才"热"起来
	for s in Audio.SFX_NAMES:
		var sp := Audio.sfx_path(String(s))
		if sp != "":
			_queue.append(sp)
	_code.clear()
	_code.assign(PRELOAD_CODE)   # 注意：Array[String] 不能用 = duplicate()，类型不匹配会静默失败
	_ground.assign(GROUND_IDS)
	_total = _queue.size() + _code.size() + _ground.size()


func _process(_d: float) -> void:
	if _done and not auto_advance:
		return
	for i in PER_FRAME:
		if _queue.is_empty():
			break
		load(_queue.pop_front() as String)
	for i in CODE_PER_FRAME:
		if _code.is_empty():
			break
		load(_code.pop_front() as String)
	# 一个地基一帧；点击进城时只复用已生成的接触影纹理。
	if not _ground.is_empty():
		var id := _ground.pop_front() as String
		var art := load("res://image/main_world/city_%s_reference_v2.png" % id) as Texture2D
		if art != null:
			_warm_art.append(art)
			Grounding.prepare(art, 192, roundi(192.0 * art.get_height() / art.get_width()))
	var left := _queue.size() + _code.size() + _ground.size()
	var ratio := 0.0 if _total == 0 else clampf(float(_total - left) / float(_total), 0.0, 1.0)
	var elapsed := float(Time.get_ticks_msec() - _t0) / 1000.0
	# 预热和入场动画都完成后才满格，避免快速加载后进度条长时间停在 100%。
	if auto_advance:
		ratio = minf(ratio, clampf(elapsed / MIN_SECONDS, 0.0, 1.0))
	_set_bar_ratio(ratio)
	var stage_i := mini(STAGES.size() - 1, int(ratio * float(STAGES.size())))
	_bar_l.text = "%s %d％" % [String(STAGES[stage_i]), roundi(ratio * 100.0)]
	if left == 0:
		_done = true   # 预热结束；进度条继续走完入场动画。
		if auto_advance and elapsed >= MIN_SECONDS:
			set_process(false)
			G.go(TITLE_SCENE)
