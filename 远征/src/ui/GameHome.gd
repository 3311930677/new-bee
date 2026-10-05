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
const Journal := preload("res://src/ui/JournalUI.gd")
const Field := preload("res://src/ui/FieldUI.gd")
const Craft := preload("res://src/ui/CraftUI.gd")
const ActivityPanelScript := preload("res://src/ui/ActivityPanel.gd")

const SPRITE_SCALE := 2.0       # 营帐的角色预览不盖住导航与主世界入口
const PED_Y := 514.0            # 营地展示人物的脚底位置
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
var _gathering:Control=null
var _activities: Control = null
var _wallet_row: HBoxContainer = null
var _wallet_labels: Array = []


func _set_home_content_visible(visible: bool) -> void:
	_home_content_hidden = not visible
	if visible: _refresh_wallet()
	for child in get_children():
		if child != _deploy and child != _worlds and child != _codex and child != _gacha \
			and child != _exchange and child != _settings and child != _arena and child != _growth \
			and child != _bag and child != _avatar_panel and child != _quests and child != _gathering and child != _activities:
			child.visible = visible


func _ready() -> void:
	Audio.play_bgm("bgm_home")
	var role: Dictionary = G.get_role(G.selected_role)
	_build_background()
	_build_profile(role)
	_build_top(role)
	_build_stage(role)
	_build_entries()
	_clean_home_text(self)
	_layout_tall_home()
	G.fit_mobile_page.call_deferred(self)
	_prompt_save_locked()

func _clean_home_text(node: Node) -> void:
	if node is Label: Craft.clean_label(node)
	for child in node.get_children(): _clean_home_text(child)


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
	Craft.scene(self)

func _build_profile(_role: Dictionary) -> void:
	_avatar_frame = Panel.new()
	_avatar_frame.position = Vector2(24, 24)
	_avatar_frame.size = Vector2(48, 48)
	var fs := StyleBoxFlat.new()
	fs.bg_color = G.FIELD_DARK
	fs.border_color = G.FIELD_COPPER
	fs.set_border_width_all(2)
	fs.set_corner_radius_all(24)
	fs.shadow_color = Color("050c12",.45)
	fs.shadow_size = 3
	_avatar_frame.add_theme_stylebox_override("panel", fs)
	_avatar_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_avatar_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_avatar_frame.tooltip_text = "更换头像"
	_avatar_frame.mouse_entered.connect(func(): fs.border_color = G.FIELD_PAPER_LIGHT)
	_avatar_frame.mouse_exited.connect(func(): fs.border_color = G.FIELD_COPPER)
	_avatar_frame.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_avatar_panel())
	add_child(_avatar_frame)
	_avatar_pic = TextureRect.new()
	_avatar_pic.texture = G.avatar_texture()
	_avatar_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar_pic.position = Vector2(5, 5)
	_avatar_pic.size = Vector2(38, 38)
	_avatar_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_frame.add_child(_avatar_pic)
	var name_l := Field.label(G.display_name(), Vector2(84, 20), Vector2(248, 30), 20, G.FIELD_PAPER_LIGHT, true)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(name_l)
	var lv := int(G.prog.get("level", 1))
	add_child(Field.label("LV %02d" % lv, Vector2(84, 48), Vector2(64, 24), 14, G.FIELD_COPPER, true))
	_add_exp_bar(Vector2(150, 58), 116, int(G.prog.get("exp",0)), G.exp_to_next(lv))
	var settings := Craft.action("", Vector2(404,24), Vector2(52,48))
	settings.quiet = true
	settings.skin = "tool"
	settings.tooltip_text = "设置"
	var icon := G.ui_icon("settings", Vector2(34,34))
	icon.position = Vector2(9,7)
	icon.pivot_offset = Vector2(17,17)
	settings.add_child(icon)
	var turn_icon := func(active: bool):
		if G.get_meta("ui_review_mode", false): return
		var old: Tween = icon.get_meta("gear_motion") if icon.has_meta("gear_motion") else null
		if old != null and old.is_valid(): old.kill()
		var motion := icon.create_tween()
		icon.set_meta("gear_motion", motion)
		motion.tween_property(icon,"rotation",PI / 12.0 if active else 0.0,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	settings.mouse_entered.connect(func(): turn_icon.call(true))
	settings.mouse_exited.connect(func(): turn_icon.call(settings.has_focus()))
	settings.focus_entered.connect(func(): turn_icon.call(true))
	settings.focus_exited.connect(func(): turn_icon.call(false))
	settings.activated.connect(func(): _open_settings(_click_ev()))
	add_child(settings)

## 顶部经验条（金色圆角，满级时按满格画）
func _add_exp_bar(at: Vector2, w: float, cur: int, need: int) -> void:
	var ratio := 1.0 if need <= 0 else clampf(float(cur) / float(need), 0.0, 1.0)
	var track := ColorRect.new()
	track.color = G.FIELD_DARK
	track.position = at
	track.size = Vector2(w, 4)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	var fill := ColorRect.new()
	fill.color = G.FIELD_COPPER
	fill.size = Vector2(w * ratio, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)

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
	add_child(Craft.panel(Vector2(24,86),Vector2(432,44),.88))
	# 固定四等份宽度；大额缩写，完整数字留在提示中，永不挤出屏幕。
	var wallet_row := HBoxContainer.new()
	_wallet_row = wallet_row
	wallet_row.position = Vector2(32,86)
	wallet_row.size = Vector2(416,44)
	wallet_row.add_theme_constant_override("separation", 0)
	wallet_row.mouse_filter = Control.MOUSE_FILTER_STOP
	wallet_row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wallet_row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.show_info_popup(wallet_row, "资源说明", [wallet_row.tooltip_text] + G.wallet_info_lines()))
	add_child(wallet_row)
	for data in [["金币","gold","cur_gold"],["远征币","expedition","cur_expedition"],
			["魂晶","soul","cur_soul"],["荣誉","honor","cur_honor"]]:
		var icon := TextureRect.new()
		icon.texture = G.res_tex(data[2])
		icon.custom_minimum_size = Vector2(24,24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wallet_row.add_child(icon)
		var key := Field.label(data[0], Vector2.ZERO,Vector2.ZERO)
		key.visible = false
		wallet_row.add_child(key)
		var n := int(G.wallet.get(data[1],0))
		var words := str(n) if n < 1000000 else ("%.1f万" % (n / 10000.0) if n < 100000000 else "%.1f亿" % (n / 100000000.0))
		var amount := Field.label(words, Vector2.ZERO,Vector2(80,44),16,G.FIELD_PAPER_LIGHT,true)
		amount.tooltip_text = "%s：%d" % [data[0],n]
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wallet_row.add_child(amount)
		_wallet_labels.append({"label":amount,"key":data[1],"name":data[0]})
	_refresh_wallet()
	add_child(Craft.label("行旅营帐",Vector2(26,132),Vector2(220,38),26,Craft.GOLD,false,true))
	var quests_btn := Craft.action("任务",Vector2(24,176),Vector2(212,70),"scroll")
	quests_btn.caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	quests_btn.caption.position = Vector2(42,4)
	quests_btn.caption.set_meta("fixed_y",4)
	quests_btn.caption.size = Vector2(154,30)
	quests_btn.caption.add_theme_font_size_override("font_size",16)
	Craft.icon(quests_btn,"book",Vector2(12,9),Vector2(23,23))
	var goal := String(G.story_current().get("goal","主线 / 今日委托"))
	var goal_l := Craft.label(goal,Vector2(14,34),Vector2(184,30),13,Craft.MUTED)
	goal_l.add_theme_color_override("font_color",Color("656c60"))
	goal_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	quests_btn.tooltip_text = goal + "\n查看主线与今日委托"
	quests_btn.add_child(goal_l)
	quests_btn.activated.connect(_open_quests)
	if _quest_claimable(): G.badge_dot(quests_btn,Vector2(197,8))
	add_child(quests_btn)



func _refresh_wallet() -> void:
	if _wallet_row == null: return
	var lines: Array[String] = []
	for entry in _wallet_labels:
		var n := int(G.wallet.get(entry.key,0))
		entry.label.text = str(n) if n < 1000000 else ("%.1f万" % (n / 10000.0) if n < 100000000 else "%.1f亿" % (n / 100000000.0))
		lines.append("%s：%d" % [entry.name,n])
	_wallet_row.tooltip_text = "\n".join(lines)

# ---------- 角色展示台（金色圆台 + 光圈 + 待机动画） ----------
func _build_stage(role: Dictionary) -> void:
	var stage := Craft.Stage.new()
	stage.position = Vector2(144,294)
	stage.size = Vector2(192,248)
	stage.hue = Craft.ROLE_COLORS.get(G.selected_role,Craft.GOLD)
	stage.set_meta("home_shift",.60)
	add_child(stage)
	var contact := _HomeContact.new()
	contact.position = Vector2(240,PED_Y)
	contact.set_meta("actor_shadow",true)
	add_child(contact)
	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.scale = Vector2.ONE * SPRITE_SCALE
	_anim.position = Vector2(240,ANIM_Y)
	add_child(_anim)
	_anim.sprite_frames = _frames(String(role.get("id","zs")))
	_anim.animation = &"idle"
	_anim.play()
	var identity := Craft.panel(Vector2(142,536),Vector2(196,66),.88)
	identity.set_meta("home_shift",.60)
	add_child(identity)
	var name_l := Craft.label(String(role.get("name","旅人")),Vector2(8,0),Vector2(180,40),28,Craft.WHITE,false,true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.add_child(name_l)
	var job := Craft.label("%s · LV %02d" % [role.get("job",""),int(G.prog.get("level",1))],Vector2(8,40),Vector2(180,22),14,Craft.GOLD)
	job.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.add_child(job)

func _layout_tall_home() -> void:
	var extra := maxf(0.0,get_viewport_rect().size.y-VIEW_H)
	if extra<=0: return
	_anim.position.y += extra*.60
	for child in get_children():
		if child is Node2D and child.get_meta("actor_shadow",false): child.position.y += extra*.60
		if child is Control and child.has_meta("home_shift"):
			child.position.y += extra*float(child.get_meta("home_shift"))

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


# 四件行旅器物为主导航，活动在下方独立排列。
func _build_entries() -> void:
	var activities := Craft.action("活动",Vector2(24,264),Vector2(124,48),"ribbon")
	activities.caption.position.x = 40
	activities.caption.size.x = 72
	Craft.icon(activities,"spark",Vector2(12,12),Vector2(24,24))
	activities.name = "ActivitiesEntry"
	activities.set_meta("home_shift",.45)
	activities.activated.connect(_open_activities)
	add_child(activities)
	# Secondary shortcuts frame the actor; the stable navigation lives at the bottom.
	for i in 3:
		var e: Array = [["竞技","swords"],["召唤","summon"],["兑换","exchange"]][i]
		var b := Craft.action(e[0],Vector2(388,262+i*86),Vector2(68,78),"badge")
		b.set_meta("badge_shape",["shield","circle","hex"][i])
		b.set_meta("badge_hue",[Color("dda775"),Color("a6aadf"),Color("82b7b0")][i])
		b.set_meta("home_shift",.45)
		b.caption.position = Vector2(0,56)
		b.caption.size = Vector2(68,22)
		b.caption.set_meta("fixed_y",56)
		b.caption.add_theme_font_size_override("font_size",14)
		Craft.icon(b,e[1],Vector2(14,7),Vector2(40,40))
		var words: String = e[0]
		if _entry_has_badge(words): G.badge_dot(b,Vector2(58,5))
		b.activated.connect(func(): _dispatch_entry(words))
		add_child(b)
	if G.side_status_of("a4_rel_nighttable") == QuestService.SIDE_DONE:
		var gathering := Craft.action("归路小聚",Vector2(24,324),Vector2(124,48))
		gathering.set_meta("home_shift",.45)
		gathering.caption.add_theme_font_size_override("font_size",15)
		gathering.activated.connect(_open_gathering)
		add_child(gathering)
	var state: Dictionary = G.prog.get("main_world",{})
	var map_name := String(TableCache.main_world_map(String(state.get("map_id","lorin_wilds"))).get("name","昭元边城"))
	var travel := Craft.action("继续旅程",Vector2(32,622),Vector2(416,70),"primary")
	travel.name = "ReturnToWorld"
	travel.set_meta("home_shift",1.0)
	travel.tooltip_text = "返回主世界 · " + map_name
	travel.caption.position = Vector2(64,6)
	travel.caption.set_meta("fixed_y",6)
	travel.caption.size = Vector2(286,34)
	travel.caption.add_theme_font_size_override("font_size",25)
	travel.caption.add_theme_font_override("font",G.font_art)
	var destination := Craft.label(map_name,Vector2(64,41),Vector2(286,20),13,Color("51412a"))
	destination.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	destination.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	travel.add_child(destination)
	Craft.icon(travel,"world",Vector2(18,13),Vector2(42,42))
	Craft.icon(travel,"forward",Vector2(379,27),Vector2(16,16))
	travel.activated.connect(func(): _open_city(_click_ev()))
	add_child(travel)
	var nav := Craft.panel(Vector2(12,712),Vector2(456,76),.90)
	nav.set_meta("home_shift",1.0)
	add_child(nav)
	var entries := [["世界","world"],["背包","bag"],["养成","growth"],["图鉴","book"]]
	for i in entries.size():
		var b := Craft.action(entries[i][0],Vector2(16+i*112,714),Vector2(112,72),"nav")
		b.set_meta("home_shift",1.0)
		b.caption.position = Vector2(0,46)
		b.caption.size = Vector2(112,24)
		b.caption.set_meta("fixed_y",46)
		b.caption.add_theme_font_size_override("font_size",16)
		Craft.icon(b,entries[i][1],Vector2(37,7),Vector2(38,38))
		var words: String = entries[i][0]
		b.activated.connect(func(): _dispatch_entry(words))
		add_child(b)

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
		"活动": _open_activities()


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
		if not (G.prog.get("active_run", {}) as Dictionary).is_empty():
			RouteScene.pending_run = {"resume": true}
			G.go("res://src/run/RouteScene.tscn")
			return
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
func _open_gathering()->void:
	if _gathering!=null:return
	_gathering=preload("res://src/ui/CampGatheringPanel.gd").new()
	_gathering.closed.connect(func():
		_gathering.queue_free()
		_gathering=null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_gathering)

func _open_activities() -> void:
	if _activities!=null: return
	Audio.sfx("ui_open")
	_activities = ActivityPanelScript.new()
	_activities.closed.connect(func():
		_activities.queue_free()
		_activities = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_activities)

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
	_bag._focus_return = get_viewport().gui_get_focus_owner()
	_bag.closed.connect(func():
		Audio.sfx("ui_close")
		_bag.queue_free()
		_bag = null
		_set_home_content_visible(true))
	_set_home_content_visible(false)
	add_child(_bag)


# ---------- 设置入口（存档导出导入 / 键位说明 / 回标题 / 重置） ----------
# ---------- 更换头像（主页点左上角头像；选择本机图片或趣味头像） ----------
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
	if _activities!=null:
		_activities.go_back()
		return true
	if _gathering!=null:
		_gathering.closed.emit()
		return true
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
		_arena.closed.emit()
		return true
	if _growth != null:
		_growth.closed.emit()
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
