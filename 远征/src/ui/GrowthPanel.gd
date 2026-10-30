# GrowthPanel.gd —— 养成 6 线主面板（玩法文档 §6）
# 六条养成线入口枢纽：天赋 / 装备 / 宠物 / 技能书 / 坐骑 / 称号。
# 子面板以全屏浮层叠在本面板之上，关闭后回到本页并刷新状态行。
class_name GrowthPanel
extends Control

signal closed

const UI := preload("res://src/ui/TravelChestUI.gd")
const KitV4 := preload("res://src/ui/KitV4.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const FixUI := preload("res://src/ui/ReviewFixUI.gd")
var _page: Control
var _stage: Control
var _stage_bg: TextureRect
var _tray: Control
var _row_scroll: ScrollContainer
var _heading: Control
var _back: Button
var _hero: Control
var _portrait: TextureRect
var _hero_name: Label
var _pool: TextureRect
var _stats: GridContainer
var _surround_slots: Dictionary = {}
var _top_tabs: HBoxContainer
var _recommend: Button
var _next_id := ""

const CONTENT_W := 408.0
const Field := preload("res://src/ui/FieldUI.gd")
const Craft := preload("res://src/ui/CraftUI.gd")
# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const TalentPanelScript := preload("res://src/ui/TalentPanel.gd")
const EquipPanelScript := preload("res://src/ui/EquipPanel.gd")
const PetRaisePanelScript := preload("res://src/ui/PetRaisePanel.gd")
const SkillBookPanelScript := preload("res://src/ui/SkillBookPanel.gd")
const MountPanelScript := preload("res://src/ui/MountPanel.gd")
const TitlePanelScript := preload("res://src/ui/TitlePanel.gd")

var _rows: Array = []        # 各行状态 Label 引用（刷新用）
var _sub: Control = null     # 当前打开的子面板
var _toast: Label = null
var _summary: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	theme = UI.theme()
	_page = Control.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_page)
	_stage = Page.Stage.new()
	_page.add_child(_stage)
	# §4.4-1 角色内室独立背景（E-07，不透主城）
	var stage_tex := KitV4.commercial_tex("bg_character_stage")
	if stage_tex != null:
		_stage_bg = TextureRect.new()
		_stage_bg.texture = stage_tex
		_stage_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_stage_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_stage_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_page.add_child(_stage_bg)
	_pool = Page.picture(UI.texture("stage_pool"), Vector2(256, 60))
	_pool.modulate.a = .65
	_page.add_child(_pool)
	_hero = Field.portrait(G.selected_role, Vector2.ZERO, Vector2(200, 200))
	_page.add_child(_hero)
	# §4.4-2 职业半身立绘
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_portrait)
	# §4.4-2 两侧环绕 6 个穿戴槽（左：主武/护甲/饰品；右：灵宠/坐骑/称号）
	_surround_slots.clear()
	for sdef in [
		["weapon", "主武", "equip", "slot_silhouette_weapon"],
		["armor", "护甲", "equip", "slot_silhouette_armor"],
		["accessory", "饰品", "equip", "slot_silhouette_accessory"],
		["pet", "灵宠", "pet", "slot_silhouette_pet"],
		["mount", "坐骑", "mount", "slot_silhouette_mount"],
		["title", "称号", "title", "slot_silhouette_title"],
	]:
		var sid_key: String = sdef[0]
		var target_page: String = sdef[2]
		var sil_key: String = sdef[3]
		var cell := Page.ItemCell.new()
		cell.name = "SurroundSlot_" + sid_key
		cell.custom_minimum_size = Vector2(56, 56)
		cell.size = Vector2(56, 56)
		cell.image_px = 40.0
		cell.show_name = false
		cell.set_meta("sil_key", sil_key)
		cell.tooltip_text = String(sdef[1])
		cell.pressed.connect(func(): _open(target_page))
		_page.add_child(cell)
		_surround_slots[sid_key] = cell
	_hero_name = UI.label("", "section")
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(_hero_name)

	# §4.4-4 横排双列 6 格属性卡（生命/攻击/防御/暴击/速度/能量回复）
	var stats_card := PanelContainer.new()
	stats_card.name = "StatsCard"
	var sc_box := KitV4.style("inset_pit", 8)
	sc_box.content_margin_left = 10
	sc_box.content_margin_right = 10
	sc_box.content_margin_top = 6
	sc_box.content_margin_bottom = 6
	stats_card.add_theme_stylebox_override("panel", sc_box)
	_page.add_child(stats_card)

	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 14)
	_stats.add_theme_constant_override("v_separation", 4)
	stats_card.add_child(_stats)

	_back = UI.action("‹", "back")
	_back.tooltip_text = "返回营帐"
	_back.pressed.connect(_close)
	_page.add_child(_back)
	_heading = UI.label("人物养成", "title")
	_page.add_child(_heading)
	_tray = UI.Tray.new()
	_page.add_child(_tray)

	# §4.4-5 顶部 6 枚圆形图文页签（C-05，可升级带红点）
	_top_tabs = HBoxContainer.new()
	_top_tabs.name = "TopGrowthTabs"
	_top_tabs.add_theme_constant_override("separation", 6)
	_page.add_child(_top_tabs)
	for tdef in [
		["equip", "装备", "tab_equip"],
		["talent", "天赋", "tab_talent"],
		["skill", "技能", "tab_skill"],
		["pet", "灵宠", "tab_pet"],
		["mount", "坐骑", "tab_mount"],
		["title", "称号", "tab_title"],
	]:
		var tid: String = tdef[0]
		var tname: String = tdef[1]
		var tkey: String = tdef[2]
		var tb := Button.new()
		tb.name = "TabIcon_" + tid
		tb.custom_minimum_size = Vector2(56, 54)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.focus_mode = Control.FOCUS_NONE
		var tsb := KitV4.style("tab_inactive", 8)
		for st in ["normal", "hover", "pressed"]:
			tb.add_theme_stylebox_override(st, tsb)
		tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var ic := TextureRect.new()
		ic.texture = KitV4.commercial_tex(tkey)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(14, 3)
		ic.size = Vector2(28, 28)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(ic)
		var tl := UI.label(tname, "tag", KitV4.CREAM)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.position = Vector2(0, 32)
		tl.size = Vector2(56, 18)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(tl)
		var dot := KitV4.red_dot()
		dot.name = "RedDot"
		dot.position = Vector2(40, 2)
		dot.visible = false
		tb.add_child(dot)
		tb.pressed.connect(func(): _open(tid))
		_top_tabs.add_child(tb)

	_recommend = Page.GrowthRow.new("下一步", "fury")
	_recommend.set_meta("recommendation", true)
	_recommend.custom_minimum_size.y = 44
	_recommend.pressed.connect(func(): if not _next_id.is_empty(): _open(_next_id))
	_page.add_child(_recommend)
	_summary = _recommend.heading
	_row_scroll = Page.scroll()
	_page.add_child(_row_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	_row_scroll.add_child(box)
	for group in [["修习与装备", ["equip", "talent", "skill"]], ["同行与荣誉", ["pet", "mount", "title"]]]:
		if group[0] == "同行与荣誉":
			var gap := Control.new(); gap.custom_minimum_size.y = 8; box.add_child(gap)
		var section := UI.label(group[0], "caption", UI.AGED)
		section.custom_minimum_size.y = 22
		box.add_child(section)
		for id in group[1]:
			box.add_child(_entry_row({"equip": "装备", "talent": "天赋", "skill": "技能书", "pet": "宠物", "mount": "坐骑", "title": "称号"}[id], "fury" if id == "talent" else id, id))
	_refresh()
	get_viewport().size_changed.connect(_layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self, _layout)
	_layout()

func _layout(safe_override: Rect2 = Rect2()) -> void:
	var safe := safe_override if safe_override.has_area() else G.ui_safe_rect(self)
	var x := safe.position.x
	var y := safe.position.y
	var extra := maxf(0.0, safe.size.y - 800.0)
	var tray_h := minf(roundf(clampf(392.0 + extra * 0.55, 392.0, 560.0)), safe.size.y - 340.0)
	var top := safe.end.y - tray_h
	Page.place(_stage, Vector2.ZERO, get_viewport_rect().size)
	if _stage_bg != null:
		Page.place(_stage_bg, Vector2.ZERO, get_viewport_rect().size)
	Page.place(_back, Vector2(x + 12, y + 8), Vector2(44, 44))
	_heading.clip_text = true
	Page.place(_heading, Vector2(x + 68, y + 10), Vector2(safe.size.x - 80, 40))

	# 舞台中心角色 + 左右各 3 个穿戴槽 + 下方战力条 + 双列 6 格属性卡
	var stage_top := y + 54.0
	var stats_h := 76.0
	var stats_y := top - stats_h - 6.0
	var name_y := stats_y - 28.0
	var avail_stage_h := maxf(150.0, name_y - stage_top)
	var cx := safe.get_center().x
	var hero_h := clampf(avail_stage_h - 8.0, 140.0, 196.0)
	var hero_y := stage_top + maxf(0.0, (avail_stage_h - hero_h) * 0.5)
	_pool.custom_minimum_size = Vector2.ZERO
	Page.place(_pool, Vector2(cx - 110.0, hero_y + hero_h - 28.0), Vector2(220.0, 40.0))
	if _portrait != null and _portrait.texture != null:
		var pw := hero_h * (256.0 / 384.0)
		Page.place(_portrait, Vector2(cx - pw * 0.5, hero_y), Vector2(pw, hero_h))
		_portrait.visible = true
		_hero.visible = false
	else:
		if _portrait != null: _portrait.visible = false
		_hero.visible = true
		Page.place(_hero, Vector2(cx - hero_h * 0.5, hero_y), Vector2(hero_h, hero_h))

	# 左右环绕 6 槽
	var slot_sz := Vector2(54, 54)
	var left_x := x + 18.0
	var right_x := safe.end.x - 18.0 - slot_sz.x
	var left_keys := ["weapon", "armor", "accessory"]
	var right_keys := ["pet", "mount", "title"]
	var slot_step := 58.0
	var slot_start_y := stage_top + maxf(2.0, (avail_stage_h - (slot_step * 2.0 + slot_sz.y)) * 0.5)
	for i in 3:
		var lc: Control = _surround_slots.get(left_keys[i])
		if lc != null:
			Page.place(lc, Vector2(left_x, slot_start_y + i * slot_step), slot_sz)
		var rc: Control = _surround_slots.get(right_keys[i])
		if rc != null:
			Page.place(rc, Vector2(right_x, slot_start_y + i * slot_step), slot_sz)

	_hero_name.clip_text = true
	Page.place(_hero_name, Vector2(x + 16, name_y), Vector2(safe.size.x - 32, 26))
	var sc: Control = _page.get_node_or_null("StatsCard")
	if sc != null:
		Page.place(sc, Vector2(x + 16, stats_y), Vector2(safe.size.x - 32, stats_h))

	Page.place(_tray, Vector2(x, top), Vector2(safe.size.x, tray_h))
	Page.place(_top_tabs, Vector2(x + 16, top + 8), Vector2(safe.size.x - 32, 54))
	for tb_c in _top_tabs.get_children():
		var tb: Control = tb_c
		var tl: Label = tb.get_child(1) as Label
		if tl != null:
			tl.size.x = maxf(48.0, (safe.size.x - 32.0 - 30.0) / 6.0)
	Page.place(_recommend, Vector2(x + 16, top + 66), Vector2(safe.size.x - 32, 42))
	Page.place(_row_scroll, Vector2(x + 16, top + 112), Vector2(safe.size.x - 32, maxf(80.0, tray_h - 122.0)))

func _entry_row(words: String, icon: String, id: String) -> Control:
	var row := Page.GrowthRow.new(words, icon)
	row.name = "Growth_" + id
	row.set_meta("growth_id", id)
	row.tooltip_text = "打开" + words
	_rows.append({"id": id, "label": row.status, "action": row, "words": words})
	row.pressed.connect(func(): _open(id))
	return row

func _refresh() -> void:
	var left := G.talent_points_left()
	var rid := G.selected_role if not G.selected_role.is_empty() else "zs"
	if _portrait != null:
		_portrait.texture = KitV4.commercial_tex("%s_portrait" % rid)
	var lv := int(G.prog.get("level", 1))
	var base := TableCache.role_stats(rid, lv)
	var bonus := G.growth_bonuses(rid)
	var total_hp := TraitSystem.role_max_hp(rid, lv, [], bonus) if not base.is_empty() else 100
	var base_hp := int(base.get("max_hp", base.get("hp", 100)))
	var base_atk := int(base.get("atk", 10))
	var total_atk := maxi(1, int(float(base_atk) * (1.0 + float(bonus.get("atk_pct", 0.0))) + float(bonus.get("atk_add", 0.0))))
	var base_def := int(base.get("def", 5))
	var total_def := maxi(0, int(float(base_def) * (1.0 + float(bonus.get("def_pct", 0.0))) + float(bonus.get("def_add", 0.0))))
	var base_crit := float(base.get("crit", 0.05))
	var total_crit := clampf(base_crit + float(bonus.get("crit_add", 0.0)), 0.0, 0.95)
	var base_spd := float(base.get("spd", 1.0))
	var total_spd := base_spd * (1.0 + float(bonus.get("spd_pct", 0.0)))
	var en_pct := roundi(float(bonus.get("energy_pct", 0.0)) * 100.0)
	var power_val := int(roundf(float(total_hp) * 0.5 + float(total_atk) * 4.5 + float(total_def) * 3.0 + float(lv) * 28.0))
	_hero_name.text = "%s · Lv.%d    ▲ 战力 %s" % [G.get_role(rid).get("name", "旅人"), lv, KitV4.fmt_compact(power_val)]

	# 刷新 6 个环绕穿戴槽
	var ws: String = G.equip_weapon_slot(rid)
	for sk in ["weapon", "armor", "accessory", "pet", "mount", "title"]:
		var cell: Page.ItemCell = _surround_slots.get(sk)
		if cell == null: continue
		var sil_tex := KitV4.commercial_tex(String(cell.get_meta("sil_key", "")))
		cell.amount.text = ""
		cell.rarity_rank = 1
		if sk in ["weapon", "armor", "accessory"]:
			var actual_slot: String = ws if sk == "weapon" else String(sk)
			var est := G.equip_state(actual_slot)
			if not est.is_empty():
				cell.item_image.texture = FixUI.item(String(est.get("tpl", "tpl_" + actual_slot + "_basic")))
				cell.item_image.modulate = Color.WHITE
				cell.amount.text = "+%d" % int(est.get("lv", 0))
				cell.rarity_rank = int(est.get("rarity", 1))
			else:
				cell.item_image.texture = sil_tex
				cell.item_image.modulate = Color(1, 1, 1, 0.55)
		elif sk == "pet":
			var pets := G.owned_pets()
			if not pets.is_empty():
				var pid := String(pets[0])
				cell.item_image.texture = FixUI.pet(pid)
				cell.item_image.modulate = Color.WHITE
				cell.amount.text = "Lv.%d" % int(G.pet_stat(pid).get("lv", 1))
				cell.rarity_rank = 3
			else:
				cell.item_image.texture = sil_tex
				cell.item_image.modulate = Color(1, 1, 1, 0.55)
		elif sk == "mount":
			var mid := G.mount_active()
			if not mid.is_empty():
				var mcfg := G.mount_cfg(mid)
				var mtier := G.mount_tier(mid)
				cell.item_image.texture = G.res_tex(String(mcfg.get("icon2" if mtier >= 2 else "icon", "")))
				cell.item_image.modulate = Color.WHITE
				cell.amount.text = "%d阶" % mtier
				cell.rarity_rank = 3
			else:
				cell.item_image.texture = sil_tex
				cell.item_image.modulate = Color(1, 1, 1, 0.55)
		elif sk == "title":
			var tid := G.title_active()
			if not tid.is_empty():
				cell.item_image.texture = Page.title_badge_tex(tid)
				cell.item_image.modulate = Color.WHITE
				cell.amount.text = "佩戴"
				cell.rarity_rank = 4
			else:
				cell.item_image.texture = sil_tex
				cell.item_image.modulate = Color(1, 1, 1, 0.55)
		cell.queue_redraw()

	# 刷新双列 6 格属性卡（主数值金色 + 养成加成绿色括号）
	Page.clear(_stats)
	var stat_entries := [
		["生命", str(total_hp), "+%d" % maxi(0, total_hp - base_hp) if total_hp > base_hp else ""],
		["攻击", str(total_atk), "+%d" % maxi(0, total_atk - base_atk) if total_atk > base_atk else ""],
		["防御", str(total_def), "+%d" % maxi(0, total_def - base_def) if total_def > base_def else ""],
		["暴击", "%.1f%%" % (total_crit * 100.0), "+%.1f%%" % ((total_crit - base_crit) * 100.0) if total_crit > base_crit + 0.0005 else ""],
		["速度", "%.2f" % total_spd, "+%.2f" % (total_spd - base_spd) if total_spd > base_spd + 0.005 else ""],
		["回能", "%d%%" % (100 + en_pct), "+%d%%" % en_pct if en_pct > 0 else ""],
	]
	for se in stat_entries:
		var srow := HBoxContainer.new()
		srow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_theme_constant_override("separation", 4)
		var slbl := UI.label(String(se[0]), "caption", KitV4.MUTED)
		slbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(slbl)
		var sval := UI.label(String(se[1]), "number", KitV4.BRIGHT)
		sval.add_theme_font_size_override("font_size", G.FS_XS)
		srow.add_child(sval)
		if not String(se[2]).is_empty():
			var sbon := UI.label("(%s)" % String(se[2]), "tag", KitV4.GOOD)
			sbon.add_theme_font_size_override("font_size", G.FS_XS)
			srow.add_child(sbon)
		_stats.add_child(srow)

	_next_id = "talent" if left > 0 else ""
	_summary.text = "尚有 %d 点天赋待分配" % left if left > 0 else "天赋点已分配完毕"
	_summary.add_theme_color_override("font_color", UI.GOLD if left > 0 else UI.AGED)
	var equip_ready := false
	for slot in [ws, "armor", "accessory"]:
		var cost := G.equip_enhance_cost(slot)
		if not G.equip_state(slot).is_empty() and int(G.equip_state(slot).get("lv", 0)) < G.equip_enhance_max() and int(G.wallet.get("gold", 0)) >= int(cost.gold) and G.item_count(String(cost.item)) >= int(cost.item_n):
			equip_ready = true
			break
	for r in _rows:
		var l := (r as Dictionary)["label"] as Label
		var rid_row := String((r as Dictionary)["id"])
		match rid_row:
			"talent":
				l.text = "可分配 %d 点" % left
			"equip":
				l.text = "兵刃 +%d · 铠甲 +%d · 宝饰 +%d" % [
					int(G.equip_state(ws).get("lv", 0)), int(G.equip_state("armor").get("lv", 0)),
					int(G.equip_state("accessory").get("lv", 0))]
			"pet":
				l.text = "已收 %d / %d" % [G.owned_pets().size(), TableCache.pets().size()]
			"skill":
				var n := 0
				for k in (G.prog.get("skills", {}) as Dictionary):
					if int((G.prog["skills"] as Dictionary)[k]) > 1:
						n += 1
				l.text = "精研 %d 门" % n
			"mount":
				var mid := G.mount_active()
				l.text = ("骑乘：%s" % String(G.mount_cfg(mid).get("name", ""))) if not mid.is_empty() else "尚未骑乘"
			"title":
				var tid := G.title_active()
				l.text = ("佩戴：%s" % String(G.title_cfg(tid).get("name", ""))) if not tid.is_empty() else "未佩戴"

		var action: Button = r.action
		action.actionable = rid_row == "talent" and left > 0
		action.next_action.text = "分配天赋" if action.actionable else ""
		if rid_row == "equip" and equip_ready:
			action.actionable = true
			action.next_action.text = "可强化"
			if left <= 0:
				_next_id = "equip"
				_summary.text = "行前推荐 · 装备材料已齐，可以强化"
				_summary.add_theme_color_override("font_color", UI.GOLD)
		action.queue_redraw()
		(r as Dictionary)["action"].tooltip_text = "打开" + String((r as Dictionary)["words"]) + " · " + l.text
		if _top_tabs != null:
			var tbtn := _top_tabs.get_node_or_null("TabIcon_" + rid_row)
			if tbtn != null:
				var dot := tbtn.get_node_or_null("RedDot") as CanvasItem
				if dot != null:
					dot.visible = action.actionable
	_recommend.disabled = _next_id.is_empty()
	_recommend.actionable = not _next_id.is_empty()
	var rec_tex: Texture2D = Page.talent_icon_tex("fury_1") if _next_id == "talent" else KitV4.commercial_tex("tab_equip")
	_recommend.image.texture = rec_tex if rec_tex != null else Page.texture("equip")
	_recommend.status.text = ""
	_recommend.next_action.text = ""
	_summary.text = "下一步 · 天赋可分配 %d 点" % left if _next_id == "talent" else "下一步 · 装备材料已齐" if _next_id == "equip" else "装备强化 %d/%d/%d · 灵宠 %d/%d" % [int(G.equip_state(ws).get("lv", 0)), int(G.equip_state("armor").get("lv", 0)), int(G.equip_state("accessory").get("lv", 0)), G.owned_pets().size(), TableCache.pets().size()]
	_summary.add_theme_font_size_override("font_size", G.FS_XS)
	_recommend.queue_redraw()


# ---------- 子面板 ----------
func _open(id: String) -> void:
	if _sub != null:
		return
	match id:
		"talent":
			_sub = TalentPanelScript.new()
		"equip":
			_sub = EquipPanelScript.new()
		"pet":
			_sub = PetRaisePanelScript.new()
		"skill":
			_sub = SkillBookPanelScript.new()
		"mount":
			_sub = MountPanelScript.new()
		"title":
			_sub = TitlePanelScript.new()
	if _sub == null:
		return
	Audio.sfx("ui_open")
	_sub.set("z_index", 10)
	_sub.connect("closed", func():
		Audio.sfx("ui_close")
		_sub.queue_free()
		_sub = null
		_set_page_visible(true)
		_refresh())
	_set_page_visible(false)
	add_child(_sub)


func _set_page_visible(shown: bool) -> void:
	for child in get_children():
		if child is CanvasItem and child != _sub:
			child.visible = shown

func _close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel") and _sub == null:
		_close()
		get_viewport().set_input_as_handled()
