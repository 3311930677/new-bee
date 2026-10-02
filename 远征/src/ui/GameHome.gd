# GameHome.gd —— 养成主城：主角立绘 + 等级/经验 + 四币 + 世界进度 + 功能入口
# 养成主线（玩法文档 §6）：主城为唯一据点，世界按 theme_order 逐个解锁，
#   宠物/资源靠打怪升级与通关世界首领积累；此处是查看成长与决定下一步的枢纽。
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0

# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const GrowthPanelScript := preload("res://src/ui/GrowthPanel.gd")
const BagPanelScript := preload("res://src/ui/BagPanel.gd")
const QuestPanelScript := preload("res://src/ui/QuestPanel.gd")

const SPRITE_SCALE := 1.35       # 营帐的角色预览不盖住导航与主世界入口
const PED_Y := 374.0            # 营地展示人物的脚底位置
const BASE_OFFSET := 59.0       # 清理后素材脚底相对帧中心的偏移（基线 y=123）
const ANIM_Y := PED_Y - BASE_OFFSET * SPRITE_SCALE

const ENTRIES := [
	["主城", false],
	["世界", false],
	["图鉴", false],
	["出征", false],
	["设置", false],
]

var _anim: AnimatedSprite2D
var _toast: Label = null
var _deploy: DeployPanel = null
var _quests: Control = null      # 任务窗口（主线目标 + 今日委托）
var _worlds: RegionMapPanel = null
var _codex: CodexPanel = null
var _gacha: GachaPanel = null      # 召唤（魂石抽宠物）
var _exchange: ExchangePanel = null  # 荣誉兑换
var _settings: SettingsPanel = null  # 设置（存档/键位）
var _arena: Control = null       # 演武场（PVP 首版）
const ArenaPanelScript := preload("res://src/ui/ArenaPanel.gd")
var _growth: Control = null      # 养成 6 线（GrowthPanel）
var _bag: Control = null         # 背包（BagPanel，P04）
const AvatarPanelScript := preload("res://src/ui/AvatarPanel.gd")
var _avatar_panel: Control = null   # 更换头像浮层
var _avatar_frame: Panel = null     # 头像外框（悬停亮边用）
var _avatar_pic: TextureRect = null
var _home_content_hidden := false


func _set_home_content_visible(visible: bool) -> void:
	_home_content_hidden = not visible
	for child in get_children():
		if child != _deploy and child != _worlds and child != _codex and child != _gacha \
			and child != _exchange and child != _settings and child != _arena and child != _growth \
			and child != _bag and child != _avatar_panel and child != _quests:
			child.visible = visible


func _ready() -> void:
	Audio.play_bgm("bgm_home")
	var role: Dictionary = G.get_role(G.selected_role)
	_build_background()
	_build_profile(role)
	_build_top(role)
	_build_stage(role)
	_build_entries()
	_layout_tall_home()
	_prompt_save_locked()


# ---------- 坏档提示（A7） ----------
## 读档被判非法时，内存是干净默认态：写盘会覆盖玩家真档，所以进主界面第一件事
## 就是把选择权交回玩家——继续（放弃原档）或去设置里导入旧档。原档已备份，丢不了。
func _prompt_save_locked() -> void:
	if not G.save_locked:
		return
	if String(G.last_load_report.get("mode", "")) == "future":
		G.show_choice_popup(self, "请使用更新版本读取", [
			"此存档来自更新的游戏版本，已兼容读取可识别的进度。",
			"为保留全部投入与未知字段，本版本暂不允许继续写盘。",
			"原档已备份：",
			G.save_backup_path if G.save_backup_path != "" else "（无备份）",
			"请用更新版本继续，或导入本版本支持的旧档。",
		], [
			{"text": "返回标题", "cb": func(): G.go("res://src/ui/Title.tscn")},
			{"text": "导入旧档", "cb": func(): _open_settings(_click_ev())},
		])
		return
	var lines := [
		"存档校验未通过，进度暂时没有读入。",
		"原因：%s" % G.save_lock_reason,
		"原档已备份，本程序不会擅自覆盖它：",
		G.save_backup_path if G.save_backup_path != "" else "（无备份）",
		"选择「继续」= 放弃原档、以新进度开始；",
		"选择「导入旧档」= 去设置里粘贴存档码恢复。",
	]
	var home := self
	var go_import := func():
		_open_settings(_click_ev())
	G.show_choice_popup(home, "存档未能读入", lines, [
		{"text": "继 续", "cb": func():
			G.save_locked = false
			G.save_lock_reason = ""},
		{"text": "导入旧档", "cb": go_import},
	])


# ---------- 背景（黄昏营地插画 + 轻压暗，保持暖调通透） ----------
func _build_background() -> void:
	G.page_background(self, 0.16, "res://image/background/home.png")


func _build_profile(role: Dictionary) -> void:
	# 头像：登录页选过的/上传过的都从 G 取；点它就能换（含上传本地图片）
	_avatar_frame = Panel.new()
	_avatar_frame.position = Vector2(16, 18)
	_avatar_frame.custom_minimum_size = Vector2(56, 56)
	_avatar_frame.size = Vector2(56, 56)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.10, 0.07, 0.04, 0.55)
	# 金边方框：2px 微倒角（切角语言），弃用大圆角
	fs.set_corner_radius_all(2)
	fs.set_border_width_all(2)
	fs.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.60)
	_avatar_frame.add_theme_stylebox_override("panel", fs)
	_avatar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avatar_frame)

	_avatar_pic = TextureRect.new()
	_avatar_pic.texture = G.avatar_texture()
	_avatar_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_pic.custom_minimum_size = Vector2(50, 50)
	_avatar_pic.position = Vector2(3, 3)
	_avatar_pic.size = Vector2(50, 50)
	_avatar_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_frame.add_child(_avatar_pic)
	if _avatar_pic.texture == null:
		var nm := String(role.get("name", "旅"))
		var d := _disc_panel(50, nm.substr(0, 1))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_avatar_frame.add_child(d)

	# 整块头像都是热区：悬停亮边、点击开更换头像浮层（§26 状态齐全，不做无反馈的装饰图）
	var hit := Control.new()
	hit.position = Vector2(16, 18)
	hit.custom_minimum_size = Vector2(56, 56)
	hit.size = Vector2(56, 56)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.tooltip_text = "点击更换头像"
	hit.mouse_entered.connect(func():
		fs.border_color = Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.95))
	hit.mouse_exited.connect(func():
		fs.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.60))
	hit.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_avatar_panel())
	add_child(hit)

	var name_txt: String = G.display_name()
	var nl := G.serif_label(name_txt, G.FS_MD + 1, Color("dcf2d3"), true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nl.position = Vector2(82, 20)
	nl.custom_minimum_size = Vector2(160, 0)
	add_child(nl)

	var lv := int(G.prog.get("level", 1))
	var cur := int(G.prog.get("exp", 0))
	var need := G.exp_to_next(lv)
	var lv_l := G.gold_label("LV %d" % lv, G.FS_MD, true, Color("efe6cd"), true)
	lv_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lv_l.position = Vector2(82, 52)
	lv_l.custom_minimum_size = Vector2(52, 0)
	add_child(lv_l)
	_add_exp_bar(Vector2(136, 58), 118.0, cur, need)


## 顶部经验条（金色圆角，满级时按满格画）
func _add_exp_bar(at: Vector2, w: float, cur: int, need: int) -> void:
	var ratio := 1.0 if need <= 0 else clampf(float(cur) / float(need), 0.0, 1.0)
	var track := Control.new()
	track.position = at
	track.custom_minimum_size = Vector2(w, 12)
	track.size = Vector2(w, 12)
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color("4a3a24")
	track.add_theme_stylebox_override("panel", ts)   # 只为了复用圆角画风，实际用 Panel 画
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(w, 12)
	bg.size = Vector2(w, 12)
	bg.add_theme_stylebox_override("panel", ts)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(bg)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("e8b84a")
	var fg := Panel.new()
	fg.position = Vector2(1, 1)
	fg.custom_minimum_size = Vector2(maxf(0.0, (w - 2.0) * ratio), 10)
	fg.size = Vector2(maxf(0.0, (w - 2.0) * ratio), 10)
	fg.add_theme_stylebox_override("panel", fs)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fg)


## 金边圆牌（头像缺素材时的回退）
func _disc_panel(px: float, glyph: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.06, 0.86)
	sb.set_corner_radius_all(int(px * 0.5))
	sb.set_border_width_all(2)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.55)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(G.serif_label(glyph, G.FS_LG, Color("9f947a")))
	return p


# ---------- 顶部：徽标 + 账号小字 + 重建入口 ----------
func _build_top(role: Dictionary) -> void:
	# 营帐是整备页，实际探索主界面已经在可走的昭元边城。
	var b := G.banner_box("行旅营帐", 230, 50)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.position = Vector2(-115, 86)
	add_child(b)

	# 主线目标与今日委托收进「任务」窗口，首页只留一个木质入口；
	# 目标文字直接压在营地背景上既难读也显得杂（这里原来就是那行主线小字）。
	var quests_btn := _wood_entry("任务", "", _QUEST_SIGN, "主线与今日委托")
	quests_btn.set_meta("home_entry", true)
	quests_btn.position = Vector2((VIEW_W - 320.0) * 0.5, 142)
	quests_btn.tooltip_text = "查看主线目标与今日委托"
	if _quest_claimable():
		G.badge_dot(quests_btn, Vector2(301, 7))
	quests_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_quests())
	add_child(quests_btn)
	G.reveal_control(quests_btn, 0.05)

	# 账号小字与「重新创建角色」撤出顶栏：一个和头像/名字挤在一起，一个压住货币条。
	# 账号不再常驻主页（游客没信息量），重建入口挪进「设置」面板。

	# 资源栏统一底框（§15）：四币共用一条横带、同一套 [图标][数值] 结构，
	# 而不是几个裸数字各自飘在背景上——资源栏最能体现"是不是真产品"
	var strip := G.InsetBand.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 内凹条带（切角 + 顶暗底亮 + 1px 金描边），替代圆角9的"药丸横带"
	strip.set_surface(Color("203437", 0.94), Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.22))
	add_child(strip)

	# 钱包四币（金/远征币/魂石/荣誉——存档累计，远征结算入账）
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)   # 图标与数字贴紧，币种之间靠间隔件分开
	row.position = Vector2(206.0, 30)   # 顶部横带：四币（图标+数字）靠右一行
	# 点货币条 → 讲清四种币各是什么、从哪来
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.show_info_popup(row, "资源说明", G.wallet_info_lines()))
	add_child(row)
	var wallet_meta := [
		["金币", "f0c060", "gold", "cur_gold"], ["远征币", "7ac0c8", "expedition", "cur_expedition"],
		["魂晶", "b08ad0", "soul", "cur_soul"], ["荣誉", "d07a5a", "honor", "cur_honor"],
	]
	for i in wallet_meta.size():
		var meta: Array = wallet_meta[i]
		if i > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(8, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
		# 货币图标（无素材回退小圆点色标）
		var icon_tex: Texture2D = G.res_tex(String(meta[3]))
		if icon_tex != null:
			var icon := TextureRect.new()
			icon.texture = icon_tex
			icon.custom_minimum_size = Vector2(G.ICON_WALLET, G.ICON_WALLET)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 别把货币条的点击吃掉
			row.add_child(icon)
		else:
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(7, 7)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var dot_sb := StyleBoxFlat.new()
			dot_sb.bg_color = Color(String(meta[1]))
			dot_sb.set_corner_radius_all(4)
			dot.add_theme_stylebox_override("panel", dot_sb)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(dot)
		var name_l := G.gold_label(String(meta[0]), G.FS_XS, false, G.TEXT_MUTED, false)
		name_l.tooltip_text = String(meta[0])
		name_l.visible = false   # 顶栏只留 图标+数字（参考手游主页的货币条），名字进悬停提示
		row.add_child(name_l)
		var num_l := G.gold_label(str(int(G.wallet.get(String(meta[2]), 0))),
			G.FS_XS, true, Color(String(meta[1])), false)
		num_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(num_l)

	# 底框按资源栏实际宽度贴合（数字长度会变，不能写死宽度）
	var ms := row.get_combined_minimum_size()
	strip.position = row.position - Vector2(9.0, 5.0)
	strip.size = ms + Vector2(18.0, 10.0)

	# 召唤 / 养成 / 兑换移到右侧竖列（见 _build_entries），这里只留钱包与玩家条


# ---------- 角色展示台（金色圆台 + 光圈 + 待机动画） ----------
func _build_stage(role: Dictionary) -> void:
	var contact := _HomeContact.new()
	contact.position = Vector2(VIEW_W * 0.5, PED_Y)
	contact.set_meta("actor_shadow", true)
	add_child(contact)
	var pad := _Pedestal.new()
	pad.rx = 42.0
	pad.ry = 14.0
	pad.position = Vector2(VIEW_W / 2.0, PED_Y)
	# The courtyard already supplies a floor; no luminous platform under the actor.
	pad.visible = false
	add_child(pad)

	var ring := _RingDrawer.new()
	ring.rx = 48.0
	ring.ry = 17.0
	ring.position = Vector2(VIEW_W / 2.0, PED_Y + 6)
	ring.visible = false
	add_child(ring)

	_anim = AnimatedSprite2D.new()
	_anim.scale = Vector2.ONE * SPRITE_SCALE
	_anim.position = Vector2(VIEW_W / 2.0, ANIM_Y)
	add_child(_anim)

	var role_id: String = String(role.get("id", "zs"))
	_anim.sprite_frames = _frames(role_id)
	_anim.animation = &"idle"
	_anim.play()


func _layout_tall_home() -> void:
	var extra := maxf(0.0, get_viewport_rect().size.y - 800.0)
	if extra <= 0: return
	_anim.position.y += extra * 0.5
	for child in get_children():
		if child is Node2D and child.get_meta("actor_shadow", false):
			child.position.y += extra * 0.5
		if child is Control and child.get_meta("home_entry", false):
			child.position.y += extra * 0.5
	var return_button := get_node("ReturnToWorld") as Control
	return_button.position.y += extra

func _frames(role_id: String) -> SpriteFrames:
	var tex: Texture2D = load(G.role_dir(role_id) + _role_name(role_id) + "_idle.png")
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 5.0)
	frames.set_animation_loop(&"idle", true)
	for c in 4:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(c * 128, 0, 128, 128)
		frames.add_frame(&"idle", at)
	return frames

class _HomeContact extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.19))
		draw_circle(Vector2.ZERO, 34, Color("1d201a", 0.18))
		draw_circle(Vector2(0, -2), 22, Color("1d201a", 0.16))


func _role_name(id: String) -> String:
	match id:
		"zs": return "pojun"
		"ck": return "chuanyang"
		"fs": return "shuangyu"
		"fz": return "chenxing"
	return id


## 右侧竖列：活动与系统入口（出征已搬进主城）
const RAIL_R := [
	["世界", "界", "world"], ["竞技", "武", "swords"],
	["图鉴", "图", "book"], ["养成", "养", "growth"],
	["背包", "包", "bag"],
	["兑换", "兑", "exchange"], ["召唤", "召", "summon"],
	["设置", "设", "settings"],
]

func _build_entries() -> void:
	# 右侧竖列：活动与系统入口（出征已搬进主城，主页只留浏览与设置）
	for i in RAIL_R.size():
		var b := _round_entry(String(RAIL_R[i][0]), String(RAIL_R[i][1]), String(RAIL_R[i][2]))
		b.set_meta("home_entry", true)
		b.position = Vector2(24 + (i % 2) * 220, 388 + (i / 2) * 73)
		add_child(b)
		G.reveal_control(b, 0.08 + i * 0.025)

	# 明确的主要动作；不再用底部无边界的整屏隐形热区。
	var state: Variant = G.prog.get("main_world", {})
	var map_id := String((state as Dictionary).get("map_id", "lorin_wilds")) \
		if state is Dictionary else "lorin_wilds"
	var map_name := String(TableCache.main_world_map(map_id).get("name", "昭元边城"))
	var back_to_world := G.gold_button("继续旅程", 412, 56, G.FS_MD)
	G.button_icon(back_to_world, "world")
	back_to_world.name = "ReturnToWorld"
	back_to_world.position = Vector2(34, 709)
	back_to_world.tooltip_text = "返回主世界 · %s" % map_name
	back_to_world.gui_input.connect(_open_city)
	add_child(back_to_world)


## 任务卷宗的像素符号（9×9，2px/格）：与标题页按钮的像素符号同一语言。
const _QUEST_SIGN := [
	"111111111",
	"100000001",
	"101111101",
	"100000001",
	"101111101",
	"100000001",
	"101111101",
	"100000001",
	"111111111",
]


## 木质入口构造（八宫格与「任务」宽钮共用）：木纹底 + 图标槽/像素符号 + 铆钉。
func _wood_entry(label: String, icon_name: String, sign: Array = [],
		subtitle := "", glyph := "") -> Control:
	var root := _WoodEntry.new()
	root.custom_minimum_size = Vector2(320, 44) if subtitle != "" else Vector2(208, 62)
	root.size = root.custom_minimum_size
	root.setup(label, icon_name, sign, subtitle, glyph)
	G._bind_press_feedback(root)
	return root


## 八宫格入口：图标 + 木牌 + 角标（glyph 是图标缺素材时的字母回退）
func _round_entry(label: String, glyph: String, icon_name: String) -> Control:
	var root := _wood_entry(label, icon_name, [], "", glyph)
	if _entry_has_badge(label): G.badge_dot(root, Vector2(187, 10))
	root.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_dispatch_entry(label))
	return root


## 木质功能入口：此前是"平面蓝绿圆角矩形 + 1px 细金框"，八块一模一样的
## 色块排成阵列正是"AI 生成界面"的典型长相；换成与标题页同料的木牌——
## 有纹理、有厚度、图标嵌在内凹的槽里，四角钉上铆钉。
class _WoodEntry extends Panel:
	var _tex: ImageTexture = null
	var _icon: TextureRect = null
	var _glyph: Label = null
	var _label: Label = null
	var _sub: Label = null
	var _sign: Array = []

	func setup(text: String, icon_name: String, sign: Array = [],
			subtitle := "", glyph := "") -> void:
		_sign = sign
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_tex = G.wood_grain(Color("403023"))
		_label = G.serif_label(text, G.FS_MD, Color("efdfbd"))
		_label.add_theme_color_override("font_shadow_color", Color("141008", 0.9))
		_label.add_theme_constant_override("shadow_offset_y", 1)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		if subtitle != "":
			_sub = G.gold_label(subtitle, G.FS_XS, false, Color("cdbb90", 0.9), false)
			_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_sub)
		if icon_name != "":
			var t: Texture2D = G.NavigationIcons.texture(icon_name)
			if t != null:
				_icon = TextureRect.new()
				_icon.texture = t
				_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				_icon.modulate = Color("e8d5a3")
				_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(_icon)
			elif glyph != "":
				_glyph = G.gold_label(glyph, G.FS_LG, true, G.GOLD_BRIGHT, false)
				_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(_glyph)
		item_rect_changed.connect(_layout)
		_layout()

	func _layout() -> void:
		var h := size.y
		if _sign.size() == 9:
			# 宽版（任务入口）：像素符号居左，标题随后，副题靠右
			_label.position = Vector2(42, (h - 24.0) * 0.5)
			if _sub != null:
				var sw := _sub.get_combined_minimum_size().x
				_sub.position = Vector2(size.x - 16.0 - sw, (h - 18.0) * 0.5 + 1.0)
		else:
			if _icon != null:
				_icon.position = Vector2(15, (h - 34.0) * 0.5)
				_icon.size = Vector2(34, 34)
			if _glyph != null:
				_glyph.position = Vector2(12, (h - 38.0) * 0.5)
				_glyph.size = Vector2(38, 38)
			_label.position = Vector2(64, (h - 24.0) * 0.5)
		queue_redraw()

	func _octa_at(r: Rect2, cut: float) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(r.position.x + cut, r.position.y),
			Vector2(r.end.x - cut, r.position.y),
			Vector2(r.end.x, r.position.y + cut),
			Vector2(r.end.x, r.end.y - cut),
			Vector2(r.end.x - cut, r.end.y),
			Vector2(r.position.x + cut, r.end.y),
			Vector2(r.position.x, r.end.y - cut),
			Vector2(r.position.x, r.position.y + cut),
		])

	func _draw() -> void:
		if size.x < 8.0 or size.y < 8.0:
			return
		G.draw_wood_body(self, size, _tex, 3.0)
		if _icon != null or _glyph != null:
			# 内凹图标槽：深底 + 暗金边，顶压暗/底透光——凹进去，而不是浮起来
			var sr := Rect2(10.0, (size.y - 42.0) * 0.5, 42.0, 42.0)
			draw_colored_polygon(_octa_at(sr, 2.0), Color("221a11"))
			var rim := _octa_at(sr.grow(-1.0), 2.0)
			rim.append(rim[0])
			draw_polyline(rim, Color("6f5a38"), 1.0)
			draw_line(Vector2(sr.position.x + 4, sr.position.y + 2),
				Vector2(sr.end.x - 4, sr.position.y + 2), Color("120d07", 0.7), 1.0)
			draw_line(Vector2(sr.position.x + 4, sr.end.y - 2),
				Vector2(sr.end.x - 4, sr.end.y - 2), Color("9a8355", 0.45), 1.0)
		if _sign.size() == 9:
			# 像素卷宗符号：先垫 1px 暗影再点金，和标题页像素符号同款做法
			var org := Vector2(13.0, (size.y - 18.0) * 0.5)
			for y in 9:
				var row := String(_sign[y])
				for x in 9:
					if x < row.length() and row[x] == "1":
						var at := org + Vector2(x * 2.0, y * 2.0)
						draw_rect(Rect2(at + Vector2(0, 1), Vector2(2, 2)), Color("100e0a", 0.7))
						draw_rect(Rect2(at, Vector2(2, 2)), Color("beaa80"))
		# 四角铆钉：与标题页按钮同一细节
		for at in [Vector2(5, 5), Vector2(size.x - 8, 5),
				Vector2(5, size.y - 9), Vector2(size.x - 8, size.y - 9)]:
			draw_rect(Rect2(at - Vector2.ONE, Vector2(4, 4)), Color("17130e"))
			draw_rect(Rect2(at, Vector2(2, 2)), Color("b19a70"))


func _entry_has_badge(label: String) -> bool:
	match label:
		"召唤": return G.item_count("ticket_ten") > 0
		"兑换":
			var min_cost := G.exchange_min_cost()
			return min_cost > 0 and int(G.wallet.get("honor", 0)) >= min_cost
	return false


## 任务红点：只在「今日委托有可交付」时亮——主线常在，常亮就是噪音（§28 口径）
func _quest_claimable() -> bool:
	for qid in G.quest_offer():
		if G.quest_active(String(qid)) and G.quest_completed(String(qid)):
			return true
	return false


func _dispatch_entry(label: String) -> void:
	match label:
		"主城": _open_main_world(_click_ev())
		"世界": _open_worlds(_click_ev())
		"竞技": _open_arena()
		"图鉴": _open_codex(_click_ev())
		"养成": _open_growth()
		"背包": _open_bag()
		"兑换": _open_exchange()
		"召唤": _open_gacha()
		"设置": _open_settings(_click_ev())


## 几个入口函数按鼠标事件判定，这里补一个"左键按下"事件喂给它们
func _click_ev() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


# ---------- 主城入口（可行走据点：建筑 / NPC / 活动 / 访客） ----------
func _open_city(e: InputEvent) -> void:
	_open_main_world(e)


## 主城唯一入口：新地图承载城务、NPC、明雷和同图战斗。
func _open_main_world(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	G.enter_main_world()


# ---------- 远征入口（阶段 2.7：出征筹备 DEPLOY——选秘境→选人物→选宠物） ----------
func _on_expedition(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _deploy != null:
			return
		_deploy = DeployPanel.new()
		_deploy.confirmed.connect(func(cfg: Dictionary):
			RouteScene.pending_run = cfg
			G.go("res://src/run/RouteScene.tscn"))
		_deploy.canceled.connect(func():
			_deploy.queue_free()
			_deploy = null
			_set_home_content_visible(true))
		# 出征筹备是沉浸式整屏浮层：主城的横幅/入口从面纱后透出来会显得版面很脏
		_set_home_content_visible(false)
		add_child(_deploy)


# ---------- 任务入口（主线目标 + 今日委托，独立浮层窗口） ----------
func _open_quests() -> void:
	if _quests != null:
		return
	Audio.sfx("ui_open")
	_quests = QuestPanelScript.new()
	_quests.closed.connect(func():
		Audio.sfx("ui_close")
		_quests.queue_free()
		_quests = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_quests)


# ---------- 世界入口（8 片大陆的解锁进度） ----------
func _open_worlds(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _worlds != null:
		return
	Audio.sfx("ui_open")
	_worlds = RegionMapPanel.new()
	_worlds.closed.connect(func():
		Audio.sfx("ui_close")
		_worlds.queue_free()
		_worlds = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_worlds)


# ---------- 竞技入口（演武场：傀儡切磋 + 段位分） ----------
func _open_arena() -> void:
	if _arena != null:
		return
	Audio.sfx("ui_open")
	_arena = ArenaPanelScript.new()
	_arena.closed.connect(func():
		Audio.sfx("ui_close")
		_arena.queue_free()
		_arena = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_arena)


# ---------- 图鉴入口（宠物收集进度 + 解锁条件） ----------
func _open_codex(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _codex != null:
		return
	Audio.sfx("ui_open")
	_codex = CodexPanel.new()
	_codex.closed.connect(func():
		Audio.sfx("ui_close")
		_codex.queue_free()
		_codex = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_codex)


# ---------- 召唤入口（魂石抽宠物：单抽/十连 + 保底 + 重复炼金） ----------
func _open_gacha() -> void:
	if _gacha != null:
		return
	Audio.sfx("ui_open")
	_gacha = GachaPanel.new()
	_gacha.closed.connect(func():
		Audio.sfx("ui_close")
		_gacha.queue_free()
		_gacha = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_gacha)


# ---------- 演武荣誉补给入口 ----------
func _open_exchange() -> void:
	if _exchange != null:
		return
	Audio.sfx("ui_open")
	_exchange = ExchangePanel.new()
	_exchange.closed.connect(func():
		Audio.sfx("ui_close")
		_exchange.queue_free()
		_exchange = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_exchange)


# ---------- 养成入口（六线：天赋/装备/宠物/技能书/坐骑/称号） ----------
func _open_growth() -> void:
	if _growth != null:
		return
	Audio.sfx("ui_open")
	_growth = GrowthPanelScript.new()
	_growth.closed.connect(func():
		Audio.sfx("ui_close")
		_growth.queue_free()
		_growth = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_growth)


# ---------- 背包入口（装备实例 / 材料 / 宝石 / 待领取箱，P04） ----------
func _open_bag() -> void:
	if _bag != null:
		return
	Audio.sfx("ui_open")
	_bag = BagPanelScript.new()
	_bag.closed.connect(func():
		Audio.sfx("ui_close")
		_bag.queue_free()
		_bag = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_bag)


# ---------- 设置入口（存档导出导入 / 键位说明 / 回标题 / 重置） ----------
# ---------- 更换头像（主页点左上角头像；上传本地图片或切回职业头像） ----------
func _open_avatar_panel() -> void:
	if _avatar_panel != null:
		return
	Audio.sfx("ui_open")
	_avatar_panel = AvatarPanelScript.new()
	_avatar_panel.changed.connect(func():
		if _avatar_pic != null:
			_avatar_pic.texture = G.avatar_texture())
	_avatar_panel.closed.connect(func():
		Audio.sfx("ui_close")
		_avatar_panel.queue_free()
		_avatar_panel = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_avatar_panel)


func _open_settings(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _settings != null:
		return
	Audio.sfx("ui_open")
	_settings = SettingsPanel.new()
	_settings.closed.connect(func():
		Audio.sfx("ui_close")
		_settings.queue_free()
		_settings = null
		_set_home_content_visible(true))
	# 设置页里的「更换头像」把请求交给主界面：设置先收起来，再叠出头像浮层，
	# 免得两个面板叠在一起（设置卡片在下面、头像卡片在上面，两套返回键容易点错）
	_settings.avatar_requested.connect(func():
		if _settings != null:
			_settings.closed.emit()
		_open_avatar_panel())
	_set_home_content_visible(false)
	add_child(_settings)


# ---------- 交互 ----------
func _on_back(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		G.go("res://src/ui/CreateRole.tscn")


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_MD, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 672)
	_toast.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or G.ui_blocked:
		return
	if _close_overlay_with_escape():
		get_viewport().set_input_as_handled()
		return
	# 主界面没有“返回上一级”；ESC 应打开设置，而不是突然跳到创角页。
	_open_settings(_click_ev())
	get_viewport().set_input_as_handled()


func _close_overlay_with_escape() -> bool:
	if _quests != null:
		_quests.closed.emit()
		return true
	if _settings != null:
		_settings.closed.emit()
		return true
	if _worlds != null:
		_worlds.closed.emit()
		return true
	if _codex != null:
		_codex.closed.emit()
		return true
	if _deploy != null:
		_deploy.canceled.emit()
		return true
	if _gacha != null:
		_gacha.closed.emit()
		return true
	if _exchange != null:
		_exchange.closed.emit()
		return true
	if _arena != null:
		Audio.sfx("ui_close")
		_arena.queue_free()
		_arena = null
		return true
	if _growth != null:
		Audio.sfx("ui_close")
		_growth.queue_free()
		_growth = null
		return true
	return false


# ---------- 自绘：金色圆台 / 脚下光圈 ----------
class _Pedestal extends Node2D:
	var rx := 64.0
	var ry := 40.0
	func _draw() -> void:
		var s := ry / rx
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, s))
		draw_circle(Vector2(0, 6.0 / s), rx * 1.05, Color(0, 0, 0, 0.35))
		draw_circle(Vector2.ZERO, rx, Color("8a6a28"))
		draw_circle(Vector2(0, -3.0 / s), rx * 0.8, Color("c9a44a"))
		draw_circle(Vector2(0, -5.0 / s), rx * 0.5, Color("e8c668"))


class _RingDrawer extends Node2D:
	var rx := 80.0
	var ry := 48.0
	func _draw() -> void:
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var n := 64
		for i in n + 1:
			var a := TAU * float(i) / float(n)
			outer.append(Vector2(cos(a) * rx, sin(a) * ry))
			inner.append(Vector2(cos(a) * rx * 0.9, sin(a) * ry * 0.9))
		draw_polyline(outer, G.GOLD_BRIGHT, 3.0)
		draw_polyline(inner, Color(G.GOLD_BRIGHT.r, G.GOLD_BRIGHT.g, G.GOLD_BRIGHT.b, 0.5), 2.0)
