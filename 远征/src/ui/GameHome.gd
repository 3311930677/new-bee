# GameHome.gd —— 养成主城：主角立绘 + 等级/经验 + 四币 + 世界进度 + 功能入口
# 养成主线（玩法文档 §6）：主城为唯一据点，世界按 theme_order 逐个解锁，
#   宠物/资源靠打怪升级与通关世界首领积累；此处是查看成长与决定下一步的枢纽。
extends Control

const ChestUI := preload("res://src/ui/TravelChestUI.gd")
const ChestView := preload("res://src/ui/CampChestView.gd")
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
var _avatar_frame: Control = null     # 头像外框（悬停亮边用）
var _avatar_pic: TextureRect = null
var _home_content_hidden := false
var _gathering:Control=null
var _activities: Control = null
var _wallet_row: HBoxContainer = null
var _wallet_labels: Array = []
var _chest_view: Control
var _chest_dialog: Control
var _dialog_return_focus: Control


func _set_home_content_visible(visible: bool) -> void:
	_home_content_hidden = not visible
	if visible: _refresh_wallet()
	for child in get_children():
		if child == _chest_view:
			_chest_view.content.visible = visible
			if visible:
				_chest_view.modulate.a = 1
				_chest_view._hero.disabled = false
				_chest_view.refresh()
			continue
		if child != _deploy and child != _worlds and child != _codex and child != _gacha \
			and child != _exchange and child != _settings and child != _arena and child != _growth \
			and child != _bag and child != _avatar_panel and child != _quests and child != _gathering and child != _activities:
			child.visible = visible


func _ready() -> void:
	Audio.play_bgm("bgm_home")
	_chest_view = ChestView.new()
	_chest_view.name = "CampChest"
	_chest_view.host = self
	add_child(_chest_view)
	_prompt_save_locked()

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
func _refresh_wallet() -> void:
	if _chest_view != null: _chest_view.refresh()

func _layout_tall_home() -> void:
	if _chest_view != null: _chest_view.layout()

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

func _role_name(id: String) -> String:
	match id:
		"zs": return "pojun"
		"ck": return "chuanyang"
		"fs": return "shuangyu"
		"fz": return "chenxing"
	return id


# 四件行旅器物为主导航，活动在下方独立排列。
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
	if _chest_dialog != null:
		_close_chest_dialog()
		return true
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



func _show_chest_dialog(title: String, lines: Array, choices: Array = [], cb: Callable = Callable()) -> void:
	if _chest_dialog != null: return
	_dialog_return_focus = get_viewport().gui_get_focus_owner()
	var dialog := ChestUI.Modal.new()
	dialog.heading = title
	dialog.lines = lines
	dialog.choices = choices
	dialog.closed.connect(_close_chest_dialog)
	dialog.selected.connect(func(index: int):
		_close_chest_dialog()
		if cb.is_valid(): cb.call(index))
	_chest_dialog = dialog
	add_child(dialog)

func _close_chest_dialog() -> void:
	if _chest_dialog == null: return
	_chest_dialog.queue_free()
	_chest_dialog = null
	if is_instance_valid(_dialog_return_focus) and _dialog_return_focus.is_visible_in_tree(): _dialog_return_focus.grab_focus()
