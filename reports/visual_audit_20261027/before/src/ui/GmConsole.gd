# GmConsole.gd —— GM 开发者控制台（全平台触控 + 全功能界面解锁直达）
# 唤起方式：
#   1. 手机/触控：屏幕顶部常驻可拖拽「ESC 返回 | GM 开发者」胶囊按钮，或「设置 → 开发者控制台」；
#   2. 键盘快捷键：F10 或 `（见 G.ACTIONS.gm_console）。
# 支持：
#   - 一键全功能大满贯解锁（全剧情/全建筑/16主世界地图/8秘境/全灵宠满阶进化/全坐骑称号/传世神装/全道具）
#   - 游戏全部 38 个功能界面与小游戏一键直达
#   - 16 张主世界地图 + 8 大远征秘境一键传送
extends CanvasLayer

const VIEW_W := 480.0
const PANEL_X := 20.0
const PANEL_W := 440.0
const PANEL_H_LOCKED := 268.0
const PANEL_H_OPEN := 620.0

var _root: Control = null
var _banner: Control = null
var _panel: PanelContainer = null
var _pw: LineEdit = null
var _unlock_btn: Control = null
var _quick_unlock_btn: Control = null
var _hint: Label = null
var _tools: Control = null
var _locked_info: Control = null
var _close_btn: Control = null

var _tab_idx := 0
var _tab_btns: Array[Control] = []
var _tab_pages: Array[Control] = []

var _bar_layer: CanvasLayer = null
var _float_bar: PanelContainer = null
var _drag_active := false
var _drag_moved := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO


func _ready() -> void:
	layer = 100
	visible = false
	# 常驻最上层：任何界面（含手机正式导出包）都能唤起
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.is_debug_build() and "--gm-touch-bar" in OS.get_cmdline_user_args():
		_build_float_bar.call_deferred()


func _process(_delta: float) -> void:
	if _bar_layer != null:
		var review_hide := bool(G.get_meta("ui_review_mode", false))
		_bar_layer.visible = not review_hide and OS.is_debug_build()
		if _float_bar != null:
			var safe := G.ui_safe_rect(_float_bar)
			_float_bar.position = _float_bar.position.clamp(safe.position+Vector2(4,4), (safe.end-_float_bar.size-Vector2(4,4)).max(safe.position+Vector2(4,4)))


## 用 _input 抢在各界面之前：否则底层场景的 ESC 处理会先把按键吃掉
func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("gm_console"):
		toggle()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		return
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		var vp2 := get_viewport()
		if vp2 != null:
			vp2.set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## 手机端 / 设置页免口令直接开启开发者控制台
func open_unlocked() -> void:
	G.gm_unlocked = true
	open()


func open() -> void:
	if _root == null:
		_build()
	_layout_modal()
	visible = true
	G.ui_blocked = true
	_sync_state()
	if not G.gm_unlocked and _pw != null:
		_pw.grab_focus()


func close() -> void:
	visible = false
	G.ui_blocked = false


# ================= 手机常驻触控胶囊（ESC 返回 + GM 开发者） =================
func _build_float_bar() -> void:
	if _bar_layer != null:
		return
	_bar_layer = CanvasLayer.new()
	_bar_layer.name = "GmTouchBarLayer"
	_bar_layer.layer = 101
	_bar_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bar_layer)

	_float_bar = PanelContainer.new()
	_float_bar.name = "GmMobileFloatBar"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("16131a", 0.86)
	sb.border_color = Color("c8a45c", 0.82)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(17)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	_float_bar.add_theme_stylebox_override("panel", sb)
	_float_bar.custom_minimum_size = Vector2(148, 34)
	_float_bar.position = Vector2(VIEW_W - 156.0, 8.0)
	_float_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar_layer.add_child(_float_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_bar.add_child(row)

	var esc_btn := _make_pill_btn("ESC 返回", Color("26383a"), Color("e8dcc0"), func():
		if visible:
			close()
		else:
			G.trigger_cancel())
	row.add_child(esc_btn)

	var gm_btn := _make_pill_btn("GM 全解锁", Color("5a3e1b"), Color("ffe39e"), func():
		if visible:
			close()
		else:
			open_unlocked())
	row.add_child(gm_btn)


func _make_pill_btn(txt: String, bg: Color, fg: Color, tap_cb: Callable) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color("b89658", 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(13)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(66, 26)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var lbl := G.gold_label(txt, 13, false, fg, false)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)

	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			var mb := e as InputEventMouseButton
			if mb.pressed:
				_drag_active = true
				_drag_moved = false
				_drag_start_mouse = mb.global_position
				_drag_start_pos = _float_bar.position
			else:
				var was_moved := _drag_moved
				_drag_active = false
				_drag_moved = false
				if not was_moved:
					G._sfx("ui_click")
					tap_cb.call()
		elif e is InputEventMouseMotion and _drag_active:
			var mm := e as InputEventMouseMotion
			var delta := mm.global_position - _drag_start_mouse
			if delta.length() > 8.0:
				_drag_moved = true
			if _drag_moved and _float_bar != null:
				var vp_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(480, 800)
				var target := _drag_start_pos + delta
				_float_bar.position = Vector2(
					clampf(target.x, 4.0, maxf(4.0, vp_size.x - _float_bar.size.x - 4.0)),
					clampf(target.y, 4.0, maxf(4.0, vp_size.y - _float_bar.size.y - 4.0))
				))
	return p


# ================= 控制台主面板构建 =================
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	G.veil(_root, 0.80, true)

	_banner = G.banner_box("开发者控制台", 300, 48)
	_root.add_child(_banner)

	_panel = G.parchment_box(PANEL_W, PANEL_H_LOCKED, 16.0)
	_root.add_child(_panel)

	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(content)

	_pw = LineEdit.new()
	_pw.secret = true
	_pw.placeholder_text = "开发者口令（或点下方免密开启）"
	_pw.custom_minimum_size = Vector2(276, 40)
	_pw.position = Vector2(0, 8)
	G.style_line_edit(_pw)
	_pw.text_submitted.connect(func(_t: String): _try_unlock())
	content.add_child(_pw)

	_unlock_btn = G.gold_button("解 锁", 120, 40)
	_unlock_btn.position = Vector2(286, 8)
	_unlock_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_try_unlock())
	content.add_child(_unlock_btn)

	_hint = G.gold_label("", G.FS_XS, false, G.TEXT_MUTED, false)
	_hint.position = Vector2(0, 52)
	_hint.custom_minimum_size = Vector2(406, 0)
	content.add_child(_hint)

	# 未解锁态说明 + 手机端免密一键开启按钮
	_locked_info = Control.new()
	_locked_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_locked_info)

	_quick_unlock_btn = G.gold_button("手机免密一键开启开发者权限", 406, 44, G.FS_MD)
	_quick_unlock_btn.position = Vector2(0, 78)
	_quick_unlock_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if not OS.is_debug_build() or G.save_locked: return
			G.gm_unlocked = true
			_sync_state()
			_flash("开发者权限已开启 · 可直接解锁全部功能与界面"))
	_locked_info.add_child(_quick_unlock_btn)

	var info_lines := [
		"· 全功能大满贯：全剧情/建筑/16主世界图/8秘境/全养成满配",
		"· 界面直达：养成/活动/商贸/垂钓/射艺/鉴宝等 38 页一键直达",
		"· 屏幕右上角常驻「ESC返回｜GM全解锁」可按住任意拖动",
	]
	for i in info_lines.size():
		var ln := G.text_label(info_lines[i], G.FS_XS, Color("6a5a3a"))
		ln.position = Vector2(0, 130 + i * 20)
		ln.custom_minimum_size = Vector2(406, 0)
		_locked_info.add_child(ln)

	# 已解锁态：三页签（1.全解锁与作弊  2.功能界面直达  3.全地图与秘境直传）
	_tools = Control.new()
	_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_tools)

	var tab_titles := ["全解锁与作弊", "功能界面直达", "全地图与秘境"]
	_tab_btns.clear()
	_tab_pages.clear()
	for i in tab_titles.size():
		var tb := G.gold_button(tab_titles[i], 130, 38, G.FS_XS)
		tb.position = Vector2(i * 138.0, 4)
		var idx := i
		tb.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_switch_tab(idx))
		_tools.add_child(tb)
		_tab_btns.append(tb)

		var page := Control.new()
		page.position = Vector2(0, 50)
		page.size = Vector2(408, 480)
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tools.add_child(page)
		_tab_pages.append(page)

	_build_tab_cheats(_tab_pages[0])
	_build_tab_features(_tab_pages[1])
	_build_tab_maps(_tab_pages[2])
	_switch_tab(0)

	_close_btn = G.gold_button("关  闭  (ESC)", 200, 40, G.FS_SM)
	_close_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	content.add_child(_close_btn)


func _switch_tab(idx: int) -> void:
	_tab_idx = clampi(idx, 0, _tab_pages.size() - 1)
	for i in _tab_pages.size():
		_tab_pages[i].visible = (i == _tab_idx)
		if i < _tab_btns.size():
			_tab_btns[i].modulate = Color(1.0, 1.0, 1.0, 1.0) if i == _tab_idx else Color(0.76, 0.72, 0.64, 0.88)


# ================= 页签 1：全解锁与作弊 =================
func _build_tab_cheats(parent: Control) -> void:
	var scroll := _make_scroll(parent, Vector2(404, 476))
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(396, 0)
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	box.add_child(_section_header("★ 终极全功能解锁（推荐）"))

	var unlock_all_btn := G.gold_button("★ 一键全功能大满贯解锁（全剧情/地图/养成）", 396, 44, G.FS_SM)
	unlock_all_btn.name = "GmUnlockAllFeaturesButton"
	unlock_all_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.gm_unlock_all_features()
			_refresh_active_scene()
			_flash("已全解锁：全剧情/全建筑/16地图/8秘境/全灵宠满阶/传世神装！"))
	box.add_child(unlock_all_btn)

	var grant_all_btn := G.gold_button("一键满配（Lv.60 + 全世界/灵宠 + 四币）", 396, 42, G.FS_SM)
	grant_all_btn.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			G.gm_grant_all()
			_refresh_active_scene()
			_flash("已满配：世界/宠物全解锁，等级满级，资源管够"))
	box.add_child(grant_all_btn)

	box.add_child(_section_header("◆ 角色与资源快捷指令"))
	_add_grid_pair(box,
		"满 级 (Lv.60)", func():
			G.gm_max_level()
			_refresh_active_scene()
			_flash("主角等级已升至上限 Lv.60"),
		"四币 +999999", func():
			G.gm_add_currency(999999)
			_refresh_active_scene()
			_flash("金币 / 远征币 / 魂石 / 荣誉 各 +999999")
	)
	_add_grid_pair(box,
		"全道具/宝石 ×99", func():
			var cargo_ids := ["trade_grain", "trade_salt", "trade_herb", "trade_iron", "salt_pack"]
			for item_id in G.ITEM_NAMES.keys():
				var k := String(item_id)
				if k in cargo_ids:
					G.items.erase(k)
				else:
					G.items[k] = maxi(99, int(G.items.get(k, 0)))
			for gem_kind in ["atk", "def", "hp", "spd", "crit"]:
				for gem_lv in [1, 2, 3]:
					var gid := "gem_%s_%d" % [gem_kind, gem_lv]
					G.items[gid] = maxi(20, int(G.items.get(gid, 0)))
			G.save_game()
			_refresh_active_scene()
			_flash("全养成材料、鱼获、古物、宝石已补满（已排除拦路商货）"),
		"全城建筑立即落成", func():
			var built: Array = G.city.get("built", []) if G.city.get("built") is Array else []
			for bid in ["hall", "gate", "archive", "kennel", "barracks", "storehouse", "shrine", "forge", "frost_lodge"]:
				if not built.has(bid):
					built.append(bid)
			G.city["built"] = built
			G.save_game()
			_refresh_active_scene()
			_flash("边城与霜关全部建筑已落成")
	)

	box.add_child(_section_header("◆ 世界、灵宠与装备"))
	_add_grid_pair(box,
		"解锁全部世界", func():
			G.gm_unlock_all_worlds()
			_refresh_active_scene()
			_flash("全部世界与主世界跨图限制已解除"),
		"全部标记已通关", func():
			G.gm_clear_all_worlds()
			_refresh_active_scene()
			_flash("全部 8 大世界已记为通关（可自由扫荡）")
	)
	_add_grid_pair(box,
		"解锁全部宠物", func():
			G.gm_unlock_all_pets()
			_refresh_active_scene()
			_flash("全部 10 只灵宠已收入图鉴"),
		"全灵宠满阶进化", func():
			G.gm_unlock_all_features()
			_refresh_active_scene()
			_flash("全部灵宠已满级、满突破、满资质并完成进化")
	)
	_add_grid_pair(box,
		"切换四大职业", func():
			var order := ["zs", "ck", "fs", "fz"]
			var cur := order.find(G.selected_role)
			var next_role: String = order[(cur + 1) % order.size()]
			G.selected_role = next_role
			G.ensure_starter_equip()
			G.save_game()
			_refresh_active_scene()
			var rname := String(G.get_role(next_role).get("name", next_role))
			_flash("已切换当前职业为：%s（%s）" % [rname, next_role]),
		"重置本地存档", func():
			G.gm_reset_save()
			_refresh_active_scene()
			_flash("养成进度与钱包已重置为初始状态")
	)


# ================= 页签 2：功能界面直达（38 个功能界面） =================
func _build_tab_features(parent: Control) -> void:
	var scroll := _make_scroll(parent, Vector2(404, 476))
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(396, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	box.add_child(_section_header("◆ 核心主城与大世界枢纽（点击自动全解锁并打开）"))
	_add_feature_pair(box, "主城总览 (月下山城)", "home", "可行走边城 (昭元漫步)", "main_world")
	_add_feature_pair(box, "出征筹备 (秘境编队)", "deploy", "世界地区行路图", "worlds")
	_add_feature_pair(box, "驿路行辕 (快行驿车)", "journey", "传世圣坛 (神兵圣鹿)", "relic_hunt")

	box.add_child(_section_header("◆ 角色六线养成与背包工坊"))
	_add_feature_pair(box, "人物养成总览", "growth", "行旅背包 (穿戴/箱子)", "bag")
	_add_feature_pair(box, "装备强化/精炼/宝石", "growth:equip", "职业天赋树配点", "growth:talent")
	_add_feature_pair(box, "技能书研习升级", "growth:skill", "灵宠喂养/突破/资质", "growth:pet")
	_add_feature_pair(box, "坐骑栏与升阶", "growth:mount", "称号簿与佩戴", "growth:title")
	_add_feature_pair(box, "同行伙伴协战训练", "companion", "灵宠图鉴与进化", "codex")

	box.add_child(_section_header("◆ 召唤 · 竞技 · 射艺 · 鉴宝 · 集市"))
	_add_feature_pair(box, "唤灵阁 (魂石抽宠)", "gacha", "荣誉集市 (材料兑换)", "exchange")
	_add_feature_pair(box, "演武场 (傀儡/镜影)", "arena", "校场射艺 (弯弓射靶)", "archery")
	_add_feature_pair(box, "古碑鉴宝 (参悟/开匣)", "curio", "边城物资铺 (采买)", "shop")

	box.add_child(_section_header("◆ 营火小聚 · 活动 · 委托 · 邮驿 · 商贸"))
	_add_feature_pair(box, "营火小聚 (伙伴夜话)", "gathering", "行旅活动告示", "activities")
	_add_feature_pair(box, "任务卷宗 (主线/委托)", "quests", "归路邮驿 (信使护送)", "mail")
	_add_feature_pair(box, "边城现货贸易", "trade:city", "沉渊港贸易与船单", "trade:port")
	_add_feature_pair(box, "霜关驿站贸易", "trade:frost", "霜关缺药加急运单", "contract")

	box.add_child(_section_header("◆ 四大水域垂钓小游戏"))
	_add_feature_pair(box, "垂钓 · 断桥盐泉", "fishing:salt", "垂钓 · 沉渊港栈桥", "fishing:port")
	_add_feature_pair(box, "垂钓 · 潮痕浅池", "fishing:tide", "垂钓 · 霜关冰缘池", "fishing:frost")

	box.add_child(_section_header("◆ 行旅图志 · 守碑誓约 · 创角 · 教学"))
	_add_feature_pair(box, "行旅图志 (地理/博物)", "journal", "守碑出行誓约", "oath")
	_add_feature_pair(box, "新手指引 (11步教学)", "tutorial", "重选角色 (四命途易职)", "reselect")
	_add_feature_pair(box, "更换旅人头像", "avatar", "行囊设置 (倍速/存档)", "settings")
	_add_feature_pair(box, "世界观序章演出", "prologue", "返回标题登录页", "title")


# ================= 页签 3：全地图与秘境直传 =================
func _build_tab_maps(parent: Control) -> void:
	var scroll := _make_scroll(parent, Vector2(404, 476))
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(396, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	box.add_child(_section_header("◆ 第一幕 · 昭元边城与碑窟（点击直接传送）"))
	_add_map_pair(box, "昭元边城 (主城)", "lorin_wilds", "落枫古道", "maple_road")
	_add_map_pair(box, "断碑坡", "broken_slope", "失声碑窟 (首领)", "stele_cavern")

	box.add_child(_section_header("◆ 第二幕 · 沉渊港与退潮水闸"))
	_add_map_pair(box, "旧盐道", "old_salt_road", "沉渊港 (港口城)", "shenyuan_port")
	_add_map_pair(box, "退潮滩涂", "tideflat", "退潮水闸 (首领)", "tidal_gate")

	box.add_child(_section_header("◆ 第三幕 · 霜关驿与裂谷矿脉"))
	_add_map_pair(box, "赤砂商路", "red_sand_route", "霜关驿 (雪城)", "frost_post")
	_add_map_pair(box, "裂谷矿道", "rift_mine_road", "矿脉深库", "rift_mine_vault")
	_add_map_pair(box, "寒霜栈道", "frost_boardwalk", "霜陨关隘 (首领)", "frost_pass")

	box.add_child(_section_header("◆ 第四幕 · 渊口外环与归路碑心"))
	_add_map_pair(box, "渊口外环", "abyss_ring", "归路碑心 (终章首领)", "stele_core")

	box.add_child(_section_header("◆ 八大远征秘境直进（直接开启路线探索）"))
	_add_expedition_pair(box, "1. 苍绿林海", "forest", "2. 凛冬雪原", "snow")
	_add_expedition_pair(box, "3. 流沙荒漠", "desert", "4. 瘴气沼泽", "marsh")
	_add_expedition_pair(box, "5. 熔岩火域", "volcano", "6. 幽暗古墓", "tomb")
	_add_expedition_pair(box, "7. 暮色古堡", "castle", "8. 永夜深渊", "abyss")


# ================= 列表辅助与跳转派发 =================
func _make_scroll(parent: Control, sz: Vector2) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.position = Vector2.ZERO
	sc.size = sz
	sc.custom_minimum_size = sz
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	return sc


func _section_header(text: String) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", 4)
	wrap.add_theme_constant_override("margin_bottom", 2)
	var lbl := G.gold_label(text, G.FS_XS, false, Color("7a4e1d"), false)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	wrap.add_child(lbl)
	return wrap


func _add_grid_pair(box: VBoxContainer, t1: String, fn1: Callable, t2: String, fn2: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	for item in [[t1, fn1], [t2, fn2]]:
		var b := G.gold_button(String(item[0]), 194, 40, G.FS_XS)
		var cb: Callable = item[1]
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				cb.call())
		row.add_child(b)


func _add_feature_pair(box: VBoxContainer, t1: String, f1: String, t2: String, f2: String) -> void:
	_add_grid_pair(box, t1, func(): _launch_feature(f1), t2, func(): _launch_feature(f2))


func _add_map_pair(box: VBoxContainer, t1: String, m1: String, t2: String, m2: String) -> void:
	_add_grid_pair(box, t1, func(): _teleport_main_map(m1), t2, func(): _teleport_main_map(m2))


func _add_expedition_pair(box: VBoxContainer, t1: String, th1: String, t2: String, th2: String) -> void:
	_add_grid_pair(box, t1, func(): _start_expedition(th1), t2, func(): _start_expedition(th2))


func _ensure_ready_for_jump() -> void:
	var rh_wins := int((G.prog.get("relic_hunts", {}) as Dictionary).get("wins", 0)) if G.prog.get("relic_hunts") is Dictionary else 0
	if G.selected_role.is_empty() or not G.gm_world_open or not G.story_step_done("s36") or rh_wins < 120:
		G.gm_unlock_all_features()


func _launch_feature(feature_id: String) -> void:
	_ensure_ready_for_jump()
	close()
	if feature_id == "title":
		G.go("res://src/ui/Title.tscn")
		return
	if feature_id == "prologue":
		G.go("res://src/ui/Prologue.tscn")
		return
	if feature_id == "reselect":
		G.set_meta("reselect_from_home", true)
		G.go("res://src/ui/CreateRole.tscn")
		return
	if feature_id == "main_world":
		G.enter_main_world()
		return
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("open_gm_feature") and not G.transit_busy():
		scene.call("open_gm_feature", feature_id)
		return
	G.set_meta("gm_pending_feature", feature_id)
	G.go("res://src/ui/GameHome.tscn")


func _teleport_main_map(map_id: String) -> void:
	_ensure_ready_for_jump()
	close()
	G.enter_main_world(map_id)


func _start_expedition(theme_id: String) -> void:
	_ensure_ready_for_jump()
	close()
	var pets := G.owned_pets()
	var active_pet := G.companion_active()
	if active_pet.is_empty() and not pets.is_empty():
		active_pet = String(pets[0])
	var bench_pet := ""
	for p in pets:
		if String(p) != active_pet:
			bench_pet = String(p)
			break
	RouteScene.pending_run = {
		"theme": theme_id,
		"role_id": G.selected_role if not G.selected_role.is_empty() else "zs",
		"level": int(G.prog.get("level", 60)),
		"active_pet": active_pet,
		"bench_pet": bench_pet,
		"potions": G.run_potions_max(),
		"ascetic": false,
	}
	G.go("res://src/run/RouteScene.tscn")


func _refresh_active_scene() -> void:
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return
	if scene.has_method("_refresh_wallet"):
		scene.call("_refresh_wallet")
	var cv: Variant = scene.get("_chest_view")
	if cv != null and is_instance_valid(cv):
		if (cv as Object).get("_gathering_unlocked") != null:
			(cv as Object).set("_gathering_unlocked", true)
		if (cv as Object).has_method("refresh"):
			(cv as Object).call("refresh")
	if scene.has_method("_refresh_hud"):
		scene.call("_refresh_hud")
	if scene.has_method("_sync_mount_visual"):
		scene.call("_sync_mount_visual")
	if scene.has_method("_sync_world_companion"):
		scene.call("_sync_world_companion")
	var cc: Variant = scene.get("_city_content")
	if cc != null and is_instance_valid(cc):
		if (cc as Object).has_method("_refresh_city"):
			(cc as Object).call("_refresh_city")
		if (cc as Object).has_method("_refresh_stat"):
			(cc as Object).call("_refresh_stat")


# ================= 口令与状态 =================
func _try_unlock() -> void:
	if G.gm_check_password(_pw.text):
		_pw.text = ""
		_sync_state()
		_flash("口令正确 · 开发者权限已开启")
	else:
		_pw.text = ""
		_flash("口令错误（可直接点下方「手机免密一键开启」）")


func _layout_modal() -> void:
	var vp_h := 800.0
	if get_viewport() != null:
		vp_h = maxf(800.0, get_viewport().get_visible_rect().size.y)
	var unlocked := G.gm_unlocked
	var panel_h := PANEL_H_OPEN if unlocked else PANEL_H_LOCKED
	var panel_y := roundf((vp_h - panel_h) * 0.5 + 16.0)
	if _banner != null:
		_banner.position = Vector2((VIEW_W - 300.0) * 0.5, panel_y - 60.0)
	if _panel != null:
		_panel.position = Vector2(PANEL_X, panel_y)
		_panel.custom_minimum_size = Vector2(PANEL_W, panel_h)
		_panel.size = Vector2(PANEL_W, panel_h)
	if _close_btn != null:
		_close_btn.position = Vector2((PANEL_W - 32.0 - 200.0) * 0.5, panel_h - 72.0)


func _sync_state() -> void:
	var unlocked := G.gm_unlocked
	if _pw != null:
		_pw.visible = not unlocked
	if _unlock_btn != null:
		_unlock_btn.visible = not unlocked
	if _tools != null:
		_tools.visible = unlocked
	if _locked_info != null:
		_locked_info.visible = not unlocked
	if _hint != null:
		_hint.visible = not unlocked
		_hint.text = "输入开发者口令，或直接点击下方免密开启"
		_hint.add_theme_color_override("font_color", G.TEXT_MUTED)
	_layout_modal()


var _flash_l: Label = null
var _flash_tw: Tween = null

## 面板内的一次性反馈（不弹窗、不打断操作）
func _flash(msg: String) -> void:
	if _flash_l != null:
		_flash_l.queue_free()
		_flash_l = null
	if _flash_tw != null:
		_flash_tw.kill()
		_flash_tw = null
	_flash_l = G.gold_label(msg, G.FS_XS, false, Color("ffe29a"), true)
	var panel_h := PANEL_H_OPEN if G.gm_unlocked else PANEL_H_LOCKED
	var panel_y := _panel.position.y if _panel != null else 160.0
	_flash_l.position = Vector2(PANEL_X, panel_y + panel_h + 8.0)
	_flash_l.custom_minimum_size = Vector2(PANEL_W, 0)
	if _root != null:
		_root.add_child(_flash_l)
	_flash_tw = create_tween()
	_flash_tw.tween_interval(2.0)
	_flash_tw.tween_property(_flash_l, "modulate:a", 0.0, 0.45)
	_flash_tw.tween_callback(func():
		if _flash_l != null:
			_flash_l.queue_free()
			_flash_l = null)
