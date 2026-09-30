# GameHome.gd —— 养成主城：主角立绘 + 等级/经验 + 四币 + 世界进度 + 功能入口
# 养成主线（玩法文档 §6）：主城为唯一据点，世界按 theme_order 逐个解锁，
#   宠物/资源靠打怪升级与通关世界首领积累；此处是查看成长与决定下一步的枢纽。
extends Control

const VIEW_W := 480.0
const VIEW_H := 800.0

# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const GrowthPanelScript := preload("res://src/ui/GrowthPanel.gd")
const BagPanelScript := preload("res://src/ui/BagPanel.gd")

const SPRITE_SCALE := 1.8       # 营帐的角色预览不盖住导航与主世界入口
const PED_Y := 602.0            # 金色圆台中心 y
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
			and child != _bag and child != _avatar_panel:
			child.visible = visible


func _ready() -> void:
	Audio.play_bgm("bgm_home")
	var role: Dictionary = G.get_role(G.selected_role)
	_build_background()
	_build_profile(role)
	_build_top(role)
	_build_stage(role)
	_build_entries()
	_prompt_save_locked()


# ---------- 坏档提示（A7） ----------
## 读档被判非法时，内存是干净默认态：写盘会覆盖玩家真档，所以进主界面第一件事
## 就是把选择权交回玩家——继续（放弃原档）或去设置里导入旧档。原档已备份，丢不了。
func _prompt_save_locked() -> void:
	if not G.save_locked:
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
	var tr := TextureRect.new()
	tr.texture = load("res://image/background/home.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	# 上浅下深的压暗：顶部文字清晰，底部角色台与面板自然融入地面
	var grad := Gradient.new()
	grad.set_color(0, Color(0.10, 0.06, 0.03, 0.35))
	grad.set_color(1, Color(0.08, 0.05, 0.03, 0.62))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	var dim := TextureRect.new()
	dim.texture = grad_tex
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)


# ---------- 左上角：个人信息（头像 + 名字 + 等级经验） ----------
func _build_profile(role: Dictionary) -> void:
	# 头像：登录页选过的/上传过的都从 G 取；点它就能换（含上传本地图片）
	_avatar_frame = Panel.new()
	_avatar_frame.position = Vector2(16, 18)
	_avatar_frame.custom_minimum_size = Vector2(56, 56)
	_avatar_frame.size = Vector2(56, 56)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.10, 0.07, 0.04, 0.55)
	fs.set_corner_radius_all(9)
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
	var nl := G.serif_label(name_txt, G.FS_MD + 1, G.NAME_GREEN)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nl.position = Vector2(82, 20)
	nl.custom_minimum_size = Vector2(160, 0)
	add_child(nl)

	var lv := int(G.prog.get("level", 1))
	var cur := int(G.prog.get("exp", 0))
	var need := G.exp_to_next(lv)
	var lv_l := G.gold_label("LV %d" % lv, G.FS_MD, true, Color("f0c060"), false)
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
	ts.set_corner_radius_all(6)
	track.add_theme_stylebox_override("panel", ts)   # 只为了复用圆角画风，实际用 Panel 画
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(w, 12)
	bg.size = Vector2(w, 12)
	bg.add_theme_stylebox_override("panel", ts)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(bg)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("e8b84a")
	fs.set_corner_radius_all(6)
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
	p.add_child(G.serif_label(glyph, G.FS_LG, Color("f0c060")))
	return p


# ---------- 顶部：徽标 + 账号小字 + 重建入口 ----------
func _build_top(role: Dictionary) -> void:
	# 营帐是整备页，实际探索主界面已经在可走的昭元边城。
	var b := G.banner_box("行旅营帐", 230, 50)
	b.set_anchors_preset(Control.PRESET_CENTER_TOP)
	b.position = Vector2(-115, 86)
	add_child(b)

	# 主线提示只读主世界任务；历练的旧首领目标不再误占营帐首页。
	var story := G.story_current()
	var gl := G.gold_label(G.story_goal_short(), G.FS_XS, false,
		Color("fff0ca"), true)
	gl.position = Vector2(42, 144)
	gl.size = Vector2(350, 25)
	gl.clip_text = true
	gl.mouse_filter = Control.MOUSE_FILTER_STOP
	gl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gl.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var lines: Array = ["当前目标：%s" % String(story.get("goal", "自由探索"))]
			if not story.is_empty():
				var target_cfg := TableCache.main_world_map(String(story.get("map", "")))
				lines.append("前往：%s" % String(target_cfg.get("name", "昭元边城")))
				for reward_line in G.reward_lines(story.get("reward", {})):
					lines.append(String(reward_line))
			G.show_info_popup(gl, String(story.get("title", "当前主线")), lines))
	add_child(gl)

	# 账号小字与「重新创建角色」撤出顶栏：一个和头像/名字挤在一起，一个压住货币条。
	# 账号不再常驻主页（游客没信息量），重建入口挪进「设置」面板。

	# 资源栏统一底框（§15）：四币共用一条横带、同一套 [图标][数值] 结构，
	# 而不是几个裸数字各自飘在背景上——资源栏最能体现"是不是真产品"
	var strip := Panel.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var strip_sb := StyleBoxFlat.new()
	strip_sb.bg_color = Color(0.07, 0.05, 0.03, 0.42)
	strip_sb.set_corner_radius_all(9)
	strip_sb.set_border_width_all(1)
	strip_sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.22)
	strip.add_theme_stylebox_override("panel", strip_sb)
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
		var name_l := G.gold_label(String(meta[0]), G.FS_XS, false, Color("bfa987"), false)
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
	var pad := _Pedestal.new()
	pad.rx = 62.0
	pad.ry = 36.0
	pad.position = Vector2(VIEW_W / 2.0, PED_Y)
	add_child(pad)

	var ring := _RingDrawer.new()
	ring.rx = 76.0
	ring.ry = 40.0
	ring.position = Vector2(VIEW_W / 2.0, PED_Y + 6)
	add_child(ring)

	_anim = AnimatedSprite2D.new()
	_anim.scale = Vector2.ONE * SPRITE_SCALE
	_anim.position = Vector2(VIEW_W / 2.0, ANIM_Y)
	add_child(_anim)

	var role_id: String = String(role.get("id", "zs"))
	_anim.sprite_frames = _frames(role_id)
	_anim.animation = &"idle"
	_anim.play()


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


## 右侧竖列：活动与系统入口（出征已搬进主城）
const RAIL_R := [
	["世界", "界", "node_start"], ["竞技", "武", "icon_double_edge"],
	["图鉴", "图", "itm_pet_book"], ["养成", "养", "gem_hp_3"],
	["背包", "包", "itm_mithril"],
	["兑换", "兑", "icon_vault"], ["召唤", "召", "icon_altar"],
	["设置", "设", "slot_accessory"],
]

func _build_entries() -> void:
	# 右侧竖列：活动与系统入口（出征已搬进主城，主页只留浏览与设置）
	for i in RAIL_R.size():
		var b := _round_entry(String(RAIL_R[i][0]), String(RAIL_R[i][1]), String(RAIL_R[i][2]))
		b.position = Vector2(VIEW_W - 80.0, 182 + i * 64.0)
		add_child(b)

	# 明确的主要动作；不再用底部无边界的整屏隐形热区。
	var state: Variant = G.prog.get("main_world", {})
	var map_id := String((state as Dictionary).get("map_id", "lorin_wilds")) \
		if state is Dictionary else "lorin_wilds"
	var map_name := String(TableCache.main_world_map(map_id).get("name", "昭元边城"))
	var back_to_world := G.gold_button("返回主世界 · %s" % map_name, 412, 56, G.FS_MD)
	back_to_world.name = "ReturnToWorld"
	back_to_world.position = Vector2(34, 709)
	back_to_world.tooltip_text = "返回上次所在的主世界地区"
	back_to_world.gui_input.connect(_open_city)
	add_child(back_to_world)


## 圆形入口：功能图标 + 金边圆底 + 下方小字
func _round_entry(label: String, glyph: String, icon_name: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(64, 64)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var disc := PanelContainer.new()
	disc.custom_minimum_size = Vector2(48, 48)
	disc.position = Vector2(8, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.05, 0.92)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(2)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.55)
	G._apply_shadow(sb, 4.0, 2.0, 0.30)
	disc.add_theme_stylebox_override("panel", sb)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_tex: Texture2D = G.res_tex(icon_name)
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_size := minf(G.ICON_RAIL, 40.0)
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size = Vector2(icon_size, icon_size)
		icon.position = Vector2((48.0 - icon_size) * 0.5, (48.0 - icon_size) * 0.5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disc.add_child(icon)
	else:
		disc.add_child(G.serif_label(glyph, G.FS_LG, Color("f0c060")))
	root.add_child(disc)

	var cap := G.gold_label(label, G.FS_XS, false, Color("f4ddb0"), true)
	cap.position = Vector2(0, 49)
	cap.custom_minimum_size = Vector2(64, 0)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cap)

	if _entry_has_badge(label):
		G.badge_dot(root, Vector2(52, 2))

	root.mouse_entered.connect(func(): root.modulate = Color(1.06, 1.04, 1.0))
	root.mouse_exited.connect(func(): root.modulate = Color.WHITE)
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			root.pivot_offset = root.size * 0.5
			var tw := root.create_tween()
			if e.pressed:
				Audio.sfx("ui_click")
				tw.tween_property(root, "scale", Vector2.ONE * 0.95, 0.06)
			else:
				tw.tween_property(root, "scale", Vector2.ONE, 0.12)
				_dispatch_entry(label))
	return root


## 入口红点：只在现在确实有可操作内容时出现，避免把每个入口都做成警报。
func _entry_has_badge(label: String) -> bool:
	match label:
		"召唤": return G.item_count("ticket_ten") > 0
		"兑换":
			var min_cost := G.exchange_min_cost()
			return min_cost > 0 and int(G.wallet.get("honor", 0)) >= min_cost
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
