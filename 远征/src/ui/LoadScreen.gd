# LoadScreen.gd —— 参考稿背景 + 罗盘 Logo + 城堡灯塔进度条 + 分帧预热
# 流程：Main → 本页（预热 image 素材索引与常用纹理，分帧加载不卡帧）
#       → 完成（且距进场 ≥3.5s）→ Title。加载文案轮换一点行军趣味话。
extends Control
const Chest := preload("res://src/ui/TravelChestUI.gd")
const ReviewFix:=preload("res://src/ui/ReviewFixUI.gd")
const Grounding := preload("res://src/world/BuildingGrounding.gd")
const GROUND_IDS := ["hall", "gate", "barracks", "forge", "archive", "kennel", "storehouse", "shrine"]

const TITLE_SCENE := "res://src/ui/Title.tscn"
const KIT := "res://assets/ui/loading_20261014/"
const BRAND_SIZE := Vector2(320, 138)  # title_logo.png 1654×713 等比，与标题页一致
const STATUS_GAP := 4.0
const TIP_H := 36.0
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
static var _warm_cache: Array[Resource] = []  # 保持预热脚本/场景/贴图常驻，避免离开加载页后引用归零被卸载
var _total := 0
var _done := false
var _t0 := 0.0
var _bar_fill: Control
var _bar_l: Label
var _percent_l: Label
var _hint_l: Label
var _brand: Control
var _brand_mark: TextureRect
var _gauge: Gauge
var _kit: Dictionary
var _backdrop: TextureRect
var _floor: ColorRect
var _art: TextureRect

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
	# 背景、Logo、进度条都来自加载页参考稿（assets/ui/loading_20261014，build_loading_kit.py 生成）。
	# 背景里原本烙死在 63% 的进度条已抹掉，改由 Gauge 按真实进度点亮；背景跟着进度条走，二者始终对齐。
	G.register_ui_page(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font = G.font_serif
	theme.default_font_size = G.FS_SM
	theme.set_color("font_color","Label",Color("eadbc0"))
	_kit = JSON.parse_string(FileAccess.get_file_as_string(KIT + "loading_kit.json"))
	# 屏幕比原图高时露出的部分：原图天空段的模糊放大版铺底，下沿补地面色。
	_backdrop = TextureRect.new()
	_backdrop.name = "LoadingBackdrop"
	_backdrop.texture = load(KIT + "loading_backdrop.png")
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_floor = ColorRect.new()
	_floor.name = "LoadingGround"
	_floor.color = Color(String(_kit.ground_color))
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floor)
	_art = TextureRect.new()
	_art.name = "PageBackground"
	_art.texture = load(KIT + "loading_bg.png")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 高屏时原图上下沿渐隐进铺底，不留硬边。
	var edge := Shader.new()
	edge.code = "shader_type canvas_item; uniform float fade_px = 0.0; uniform float fade_bottom = 0.0; uniform float art_h = 853.0; void fragment(){ vec4 c = texture(TEXTURE, UV); float y = UV.y * art_h; if (fade_px > 0.0) { c.a *= smoothstep(0.0, fade_px, y); } if (fade_bottom > 0.0) { c.a *= smoothstep(0.0, fade_bottom, art_h - y); } COLOR = c; }"
	var edge_mat := ShaderMaterial.new()
	edge_mat.shader = edge
	_art.material = edge_mat
	add_child(_art)

	# 底部压暗：阶段文字与行军小话落在岩石上时仍可读。
	var bottom := TextureRect.new()
	bottom.name = "LoadingContrast"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0,0,0,0),Color(.03,.02,.02,.5),Color(.03,.02,.02,.85)])
	gradient.offsets = PackedFloat32Array([.8,.9,1.0])
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2.ZERO
	fade.fill_to = Vector2(0,1)
	bottom.texture = fade
	add_child(bottom)

	_brand = Control.new()
	_brand.name = "LoadingBrand"
	_brand.size = BRAND_SIZE
	_brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_brand)
	_brand_mark = TextureRect.new()
	_brand_mark.name = "ExpeditionWordmark"
	_brand_mark.texture = load("res://assets/ui/title_20261014/title_logo.png")
	_brand_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brand_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_brand_mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_brand_mark.size = BRAND_SIZE
	_brand_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brand.add_child(_brand_mark)
	# 进场淡入；审查模式直接显示，截图稳定。
	if not bool(G.get_meta("ui_review_mode",false)):
		_brand_mark.modulate.a = 0.0
		create_tween().tween_property(_brand_mark,"modulate:a",1.0,0.6).set_delay(0.15)

	_gauge = Gauge.new(_kit)
	_gauge.name = "LoadingGauge"
	add_child(_gauge)
	_bar_fill = _gauge.lit_blade
	_percent_l = _label("0%",G.FS_XS,Color("f5e7c8"))
	_percent_l.name = "LoadingPercent"
	var box: Array = _kit.percent_box
	_percent_l.position = Vector2(box[0],box[1]) - _gauge.origin
	_percent_l.size = Vector2(box[2]-box[0],box[3]-box[1])
	_gauge.add_child(_percent_l)
	_bar_l = _label(STAGES[0],G.FS_XS,Color("f2dc87"))
	_bar_l.name = "LoadingStatus"
	_bar_l.position = Vector2(0,_gauge.size.y+STATUS_GAP)
	_bar_l.size = Vector2(_gauge.size.x,22)
	_gauge.add_child(_bar_l)
	# Pick once per entry; do not consume the global gameplay random stream.
	var tip_i := 0 if bool(G.get_meta("ui_review_mode",false)) else int(Time.get_ticks_usec()%LOADING_TIPS.size())
	_hint_l = _label("「%s」"%LOADING_TIPS[tip_i],G.FS_XS,Color("e4d4ba"))
	_hint_l.name = "LoadingTip"
	_hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	label.add_theme_font_size_override("font_size",maxi(font_size, G.FS_XS))
	label.add_theme_color_override("font_color",ink)
	label.add_theme_color_override("font_outline_color",Color("100d09"))
	label.add_theme_constant_override("outline_size",3)
	return label


## 自下而上排：行军小话贴安全区底，阶段文字在其上，再上是进度条；背景 1:1 跟着进度条定位。
func _layout(safe_override:=Rect2()) -> void:
	if _brand==null or _gauge==null:return
	var safe:=safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var view := get_viewport_rect().size
	_art.size = _art.texture.get_size()
	var bottom_art_y := safe.end.y - TIP_H - 6.0 - STATUS_GAP - 22.0 - _gauge.size.y - _gauge.origin.y
	var centered_art_y := roundf(safe.position.y + (safe.size.y - _art.size.y) * 0.45)
	var art_y := minf(bottom_art_y, centered_art_y)
	_art.position = Vector2(roundf(safe.get_center().x - _art.size.x * 0.5), art_y)
	_gauge.position = Vector2(roundf(safe.get_center().x-_gauge.size.x*.5), _art.position.y + _gauge.origin.y)
	_hint_l.position = Vector2(safe.position.x+24, minf(safe.end.y-TIP_H-12.0, _gauge.position.y+_gauge.size.y+STATUS_GAP+26.0))
	_hint_l.size = Vector2(safe.size.x-48, TIP_H)
	var mat := _art.material as ShaderMaterial
	mat.set_shader_parameter("art_h", _art.size.y)
	mat.set_shader_parameter("fade_px", 96.0 if _art.position.y > 0.5 else 0.0)
	mat.set_shader_parameter("fade_bottom", 64.0 if _art.position.y + _art.size.y < view.y - 0.5 else 0.0)
	_backdrop.position = Vector2.ZERO
	_backdrop.size = view
	var floor_y := maxf(0.0, _art.position.y + _art.size.y - (64.0 if _art.position.y + _art.size.y < view.y - 0.5 else 0.0))
	_floor.position = Vector2(0, floor_y)
	_floor.size = Vector2(view.x, maxf(0.0, view.y-_floor.position.y))
	_brand.position = Vector2(roundf(safe.get_center().x-BRAND_SIZE.x*.5), safe.position.y+36.0+maxf(0.0, art_y*0.55))

func _set_bar_ratio(ratio: float) -> void:
	var r := clampf(ratio,0.0,1.0)
	_gauge.set_ratio(r)
	_percent_l.text = "%d%%" % (100 if r>=1.0 else mini(99,floori(r*100.0)))
	var stage_i := STAGES.size()-1 if r >= 1.0 else mini(STAGES.size()-2,int(r*float(STAGES.size())))
	_bar_l.text = String(STAGES[stage_i])


## Regression interface: the actual lit instrument width.
func bar_fill_width() -> float:
	return _gauge.fill_width()

## 满格时的点亮宽度（审查脚本按它核对比例）。
func full_fill_width() -> float:
	return _gauge.full_width


## 参考稿进度条：未点亮底板 + 从左裁切的点亮管 + 逐个点亮的节点（灯塔 + 圆盘）。
## 全部 1:1，位置读 loading_kit.json；最前面那个已点亮节点缓慢呼吸。
class Gauge extends Control:
	const KIT := "res://assets/ui/loading_20261014/"
	var lit_blade: Control
	var origin := Vector2.ZERO
	var full_width := 0.0
	var _nodes: Array[TextureRect] = []
	var _node_x: Array[float] = []
	var _clock := 0.0
	var _ratio := 0.0
	func _init(kit: Dictionary) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var layers: Dictionary = kit.layers
		var base: Dictionary = layers.bar_base
		origin = Vector2(base.pos[0], base.pos[1])
		size = Vector2(base.size[0], base.size[1])
		add_child(_layer("bar_base", base))
		var fill: Dictionary = layers.bar_fill
		full_width = float(fill.size[0])
		lit_blade = Control.new()
		lit_blade.name = "LitBlade"
		lit_blade.clip_contents = true
		lit_blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lit_blade.position = Vector2(fill.pos[0], fill.pos[1]) - origin
		lit_blade.size = Vector2(0, fill.size[1])
		var strip := _layer("bar_fill", fill)
		strip.position = Vector2.ZERO
		lit_blade.add_child(strip)
		add_child(lit_blade)
		for i in (kit.node_x as Array).size():
			var n := _layer("node_%d" % i, layers["node_%d" % i])
			n.visible = false
			add_child(n)
			_nodes.append(n)
			_node_x.append(float(kit.node_x[i]) - float(fill.pos[0]))
	func _layer(id: String, info: Dictionary) -> TextureRect:
		var t := TextureRect.new()
		t.name = id
		t.texture = load(KIT + id + ".png")
		t.position = Vector2(info.pos[0], info.pos[1]) - origin
		t.size = Vector2(info.size[0], info.size[1])
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	func set_ratio(r: float) -> void:
		_ratio = clampf(r, 0.0, 1.0)
		lit_blade.size.x = roundf(full_width * _ratio)
		for i in _nodes.size():
			_nodes[i].visible = lit_blade.size.x >= _node_x[i]
	func fill_width() -> float:
		return lit_blade.size.x
	func _process(delta: float) -> void:
		_clock += delta
		var lead := -1
		for i in _nodes.size():
			if _nodes[i].visible: lead = i
		for i in _nodes.size():
			var glow := .5+.5*sin(_clock*3.0)
			_nodes[i].modulate = Color(1.0+.2*glow,1.0+.12*glow,1.0) if i == lead and _ratio < 1.0 else Color.WHITE


## 预热清单：素材索引只建不逐张加载（场景 load 会自动带上依赖纹理，
## 全量预热 879 张图既白做又拖慢启动——实测裁掉后预热 <1s，
## 启动总时长收敛到 MIN_SECONDS 一档）。
## 只热：行走帧 + 界面大背景 + 音频 + 脚本/场景编译。
func _collect_queue() -> void:
	G._build_res_index()
	Chest.theme()
	preload("res://src/ui/SettingsSkin.gd").warm()
	preload("res://src/ui/RegionChestMap.gd").warm()
	for id in ["primary_normal","primary_pressed","primary_disabled","hero_normal","hero_pressed","hero_disabled","world","bag","growth","codex","event","arena","summon","exchange","reunion","settings","back","journey","tray_rim","stage_pool","camp_sky"]:
		_queue.append("chest:"+id)
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
	# Warm the new atlas regions in the existing loading queue, before any panel opens.
	var review_regions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ReviewFix.ROOT+"regions.json"))
	for id in review_regions:_queue.append("reviewfix:"+String(id))
	if FileAccess.file_exists("res://assets/ui/next_review_20261009/regions.json"):
		var next_regions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/next_review_20261009/regions.json"))
		for id in next_regions:_queue.append("reviewfix:"+String(id))
	_queue.append("res://assets/ui/next_review_20261009/map.png")
	if ReferenceWorldArt.active("lorin_wilds"):
		for group in ["buildings","npcs","foliage","props"]:
			for id in ReferenceWorldArt.manifest().get(group,{}):_queue.append(ReferenceWorldArt.ROOT+String(id)+".png")
		# Load the current town's ground only; field chunks load when entering the field.
		for suffix in ["_floor_top","_floor_bottom"]:_queue.append(String(TableCache.main_world_map("lorin_wilds").get("reference_floor_root",ReferenceWorldArt.ROOT))+"lorin_wilds"+suffix+".png")
	if preload("res://src/world/SunnyTravelArt.gd").active("lorin_wilds"):_queue.append("sunny:prepare")
	_code.assign(PRELOAD_CODE)   # 注意：Array[String] 不能用 = duplicate()，类型不匹配会静默失败
	_ground.assign(GROUND_IDS)
	_total = _queue.size() + _code.size() + _ground.size()


func _process(_d: float) -> void:
	if _done and not auto_advance:
		return
	for i in PER_FRAME:
		if _queue.is_empty():
			break
		var path := _queue.pop_front() as String
		if path.begins_with("chest:"): Chest.texture(path.trim_prefix("chest:"))
		elif path.begins_with("reviewfix:"):ReviewFix.texture(path.trim_prefix("reviewfix:"))
		elif path=="sunny:prepare":preload("res://src/world/SunnyTravelArt.gd").prepare()
		else:
			var res := load(path)
			if res != null: _warm_cache.append(res)
	for i in CODE_PER_FRAME:
		if _code.is_empty():
			break
		var code_res := load(_code.pop_front() as String)
		if code_res != null: _warm_cache.append(code_res)
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
