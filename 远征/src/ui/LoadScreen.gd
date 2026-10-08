# LoadScreen.gd —— 原背景 + 完整书法标识 + 黑铁魔晶剑槽 + 分帧预热
# 流程：Main → 本页（预热 image 素材索引与常用纹理，分帧加载不卡帧）
#       → 完成（且距进场 ≥3.5s）→ Title。加载文案轮换一点行军趣味话。
extends Control
const Wordmark := preload("res://src/ui/UIWordmark.gd")
const Relic := preload("res://src/ui/LoadingRelic.gd")
const Grounding := preload("res://src/world/BuildingGrounding.gd")
const GROUND_IDS := ["hall", "gate", "barracks", "forge", "archive", "kennel", "storehouse", "shrine"]

const TITLE_SCENE := "res://src/ui/Title.tscn"
const MIN_SECONDS := 3.5
const PER_FRAME := 8        # 每帧预热的贴图数（59 项实际引用 + 行走帧 ≈ 数十张，分帧绰绰有余）
const CODE_PER_FRAME := 1   # 每帧顺带编译的脚本/场景数（编译只能在主线程，只能摊开几帧）

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
	"res://src/ui/IntroductionPanel.gd",
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
var _bar_fill: Control
var _bar_l: Label
var _percent_l: Label
var _hint_l: Label
var _brand: Control
var _brand_mark: TextureRect
var _gauge: Control

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
const LOADING_TIPS := [
	"北境的夜晚比传闻中更加寒冷。",
	"旧碑上的名字，仍有人记得。",
	"漫长的旅途，也需要片刻歇脚。",
]


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	_build()
	_collect_queue()


func _build() -> void:
	# Keep the original artwork, crop policy and pixel filter untouched.
	G.page_background(self, 0.08, "res://image/background/enter.png", false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font = G.font_serif
	theme.default_font_size = 16
	theme.set_color("font_color","Label",Color("eadbc0"))

	var bottom := TextureRect.new()
	bottom.name = "LoadingContrast"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0,0,0,0),Color(.025,.018,.012,.76)])
	gradient.offsets = PackedFloat32Array([.80,1.0])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2.ZERO
	fade.fill_to = Vector2(0,1)
	bottom.texture = fade
	add_child(bottom)

	_brand = Control.new()
	_brand.name = "LoadingBrand"
	_brand.size = Vector2(400,190)
	_brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_brand)

	var atlas := AtlasTexture.new()
	atlas.atlas = Wordmark.ART
	atlas.region = Rect2(Vector2.ZERO,Wordmark.ART.get_size())
	_brand_mark = TextureRect.new()
	_brand_mark.name = "ExpeditionWordmark"
	_brand_mark.position = Vector2(20,0)
	_brand_mark.size = Vector2(360,186)
	_brand_mark.texture = atlas
	_brand_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brand_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_brand_mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_brand_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand.add_child(_brand_mark)

	_gauge = Relic.new()
	_gauge.name = "LoadingGauge"
	_gauge.size = Vector2(416,66)
	add_child(_gauge)
	_bar_fill = _gauge.get("lit_blade") as Control
	_bar_l = _label(STAGES[0],14,Color("f2dc87"))
	_bar_l.name = "LoadingStatus"
	_bar_l.position = Vector2(88,10)
	_bar_l.size = Vector2(240,20)
	_gauge.add_child(_bar_l)
	_percent_l = _label("0%",14,Color("f5e7c8"))
	_percent_l.name = "LoadingPercent"
	_percent_l.position = Vector2(356,34)
	_percent_l.size = Vector2(48,22)
	_percent_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gauge.add_child(_percent_l)
	# Pick once per entry; do not consume the global gameplay random stream.
	var tip_i := 0 if bool(G.get_meta("ui_review_mode",false)) else int(Time.get_ticks_usec()%LOADING_TIPS.size())
	_hint_l = _label("「%s」"%LOADING_TIPS[tip_i],14,Color("e4d4ba"))
	_hint_l.name = "LoadingTip"
	_hint_l.size = Vector2(416,24)
	add_child(_hint_l)
	resized.connect(_layout)
	_layout()
	_layout.call_deferred()
	_set_bar_ratio(0.0)


func _label(text: String, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",ink)
	label.add_theme_color_override("font_shadow_color",Color("100d09",.8))
	label.add_theme_constant_override("shadow_offset_x",0)
	label.add_theme_constant_override("shadow_offset_y",1)
	return label


func _layout(safe_override := Rect2()) -> void:
	if _brand == null or _gauge == null:
		return
	var safe := safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var factor := minf(1.0,minf(safe.size.x/480.0,safe.size.y/600.0))
	var center := safe.get_center().x
	_brand.scale = Vector2.ONE*factor
	_brand.position = Vector2(center-200.0*factor,
		safe.position.y+clampf(safe.size.y*.085,56.0,96.0)*factor).round()
	_gauge.scale = Vector2.ONE*factor
	_hint_l.scale = Vector2.ONE*factor
	# Bottom anchoring survives tall displays and device safe-area insets.
	var floor_y := safe.end.y-24.0*factor
	_hint_l.position = Vector2(center-208.0*factor,floor_y-20.0*factor).round()
	_gauge.position = Vector2(center-208.0*factor,_hint_l.position.y-74.0*factor).round()


## Fill width, jewel position, percentage and status use one clamped value.
func _set_bar_ratio(ratio: float) -> void:
	var r := clampf(ratio,0.0,1.0)
	_gauge.set_ratio(r)
	_percent_l.text = "%d%%" % (100 if r>=1.0 else mini(99,floori(r*100.0)))
	var stage_i := STAGES.size()-1 if r >= 1.0 else mini(STAGES.size()-2,int(r*float(STAGES.size())))
	_bar_l.text = String(STAGES[stage_i])


## Regression interface: the actual lit instrument width.
func bar_fill_width() -> float:
	return _gauge.fill_width()


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
	_queue.append("res://image/ui/frontend_polish_20261007/journey_world.png")
	for key in ["charter_menu","silk_action","folio_window","journey_atlas"]:
		_queue.append("res://image/ui/designer_20261007/%s.png" % key)
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
	if left == 0:
		_done = true   # 预热结束；进度条继续走完入场动画。
		if auto_advance and elapsed >= MIN_SECONDS:
			set_process(false)
			G.go(TITLE_SCENE)
