# EquipPanel.gd —— 装备面板（强化 + 宝石镶嵌 + 精炼洗词条）
# 武器 4 系绑人物（剑/枪/杖/锤各自独立强化线），甲/饰全人物通用；
# 当前角色对应的武器槽高亮。全部数值走 data/equip.json。
class_name EquipPanel
extends Control

signal closed

const CONTENT_W := 408.0
const SLOT_W := 62.0
# 背包宝石区：4 列 × 2 行 = 8 格一页（问题 #4；15 种宝石分 2 页）
const GEM_COLS := 4
const GEM_ROWS := 2

# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const BagPanelScript := preload("res://src/ui/BagPanel.gd")

var _sel := ""               # 当前选中槽位
var _detail: Control = null  # 详情区（重绘）
var _slots_row: Control = null
var _hint: Label = null
var _toast: Label = null
var _bag: Control = null     # 背包浮层（P04：装备面板直达）
## 宝石区两种动作：镶嵌（默认）/ 合成（3 合 1）；点同一排的宝石格在两种动作下含义不同
var _gem_mode := "socket"
var _work_tab := "enhance"  # 一次只展示一条工坊操作线，减少同屏文字竞争
## 槽位等级 Label 的直引用（问题 #14）：原来靠 get_child(0).get_child(2) 数节点，
#  缺图标时子节点数变化就取错节点、刷新时崩或被静默跳过
var _slot_lv: Dictionary = {}
var _gem_page := 0           # 背包宝石分页（问题 #4）：以前只列前 6 种，持有 15 种也选不到后面的


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel = G.equip_weapon_slot()
	if _sel.is_empty():
		_sel = "armor"
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.78)
	var panel_shift := maxf(0.0, get_viewport_rect().size.y - 800.0) * 0.5
	var panel_shift_x := maxf(0.0, get_viewport_rect().size.x - 480.0) * 0.5

	var banner := G.banner_box("装 备", 240, 50)
	banner.position = Vector2(120 + panel_shift_x, 30 + panel_shift)
	add_child(banner)

	var panel := G.parchment_box(440, 620, 16.0)
	panel.position = Vector2(20 + panel_shift_x, 96 + panel_shift)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)

	# 槽位行：6 槽横排
	_slots_row = Control.new()
	_slots_row.position = Vector2(0, 0)
	content.add_child(_slots_row)
	var slots: Array = G.equip_cfg().get("slots", [])
	for i in slots.size():
		var s := slots[i] as Dictionary
		var sid := String(s.get("id", ""))
		var btn := _slot_button(s)
		btn.position = Vector2(i * (SLOT_W + 5.0), 0)
		btn.set_meta("sid", sid)
		_slots_row.add_child(btn)

	_hint = G.text_label("", G.FS_XS, G.TEXT_MUTED)
	_hint.position = Vector2(0, 70)
	_hint.custom_minimum_size = Vector2(CONTENT_W - 40.0, 0)
	content.add_child(_hint)

	# 强化/宝石/精炼规则收进 ⓘ 弹层，不再铺满面板
	var enh: Dictionary = G.equip_cfg().get("enhance", {})
	var info := G.info_button("装备玩法", [
		"【强化】每级属性 +%d％，目标+1至+%d确定成功，最高%d级。" % [
			roundi(float(enh.get("pct_per_level", 0.1)) * 100.0),
			int(enh.get("guaranteed_target", 3)), int(enh.get("max_level", 20))],
		"【积累】中高阶每失败一次，成功率增加%d个百分点，最高100%%；成功后清零。失败扣本次金币与强化石，不掉级。积累随装备保存。" % roundi(float(enh.get("failure_rate_bonus", 0.15)) * 100.0),
		"【宝石】每件装备 3 孔，三色宝石各 5 级；开孔花金币，宝石可自由拆装。",
		"【精炼】洗出 4 条随机词条；中意的词条可用锁符锁定，下次洗练不会被冲掉。",
		"【武器】剑/枪/杖/锤四系各自独立强化，跟随对应职业；护甲与饰品全队通用。",
	], 24.0)
	info.position = Vector2(CONTENT_W - 28.0, 66)
	content.add_child(info)

	# 背包直达（P04）：换下来的装备、待领取箱、卖装备都在背包里，不再要求先退回主城
	var bag_btn := G.ghost_button("背包", 108, 38, G.FS_SM, G.TEXT_LIGHT)
	G.button_icon(bag_btn, "bag", G.TEXT_LIGHT)
	bag_btn.position = Vector2(348 + panel_shift_x, 36 + panel_shift)
	bag_btn.tooltip_text = "打开背包：装备实例 / 材料 / 宝石 / 待领取箱"
	bag_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_bag())
	add_child(bag_btn)

	# 详情区（选中槽的强化/宝石/精炼）
	_detail = Control.new()
	_detail.position = Vector2(0, 94)
	content.add_child(_detail)

	var close_btn := G.gold_button("返 回", 130, 36, G.FS_MD)
	close_btn.position = Vector2(CONTENT_W / 2.0 - 65, 556)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(close_btn)

	_refresh()


# ---------- 槽位按钮 ----------
func _slot_button(s: Dictionary) -> Control:
	var sid := String(s.get("id", ""))
	var root := G.PixelButton.new()
	root.custom_minimum_size = Vector2(SLOT_W, 68)
	root.set_content_margin(0.0)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_slot_surface(root, sid)

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)
	var tex: Texture2D = G.res_tex(String(s.get("icon", "")))
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(30, 30)
		tr.size = Vector2(30, 30)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(16, 1)
		inner.add_child(tr)
	var nm := G.gold_label(String(s.get("name", "")), G.FS_XS - 1, false, G.TEXT_DARK, false)
	nm.position = Vector2(0, 29)
	nm.custom_minimum_size = Vector2(SLOT_W, 0)
	inner.add_child(nm)
	var lv := G.gold_label("+%d" % int(G.equip_state(sid).get("lv", 0)), G.FS_XS - 1, true,
		Color("a06020"), false)
	lv.position = Vector2(0, 47)
	lv.custom_minimum_size = Vector2(SLOT_W, 0)
	inner.add_child(lv)
	_slot_lv[sid] = lv   # 直引用，刷新时不再数节点下标

	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_sel = sid
			_refresh())
	return root


# ---------- 详情区 ----------
## 槽位皮：选中金亮底/普通米底；本职业武器槽红边提示（PixelButton.set_surface）
func _slot_surface(btn: Control, sid: String) -> void:
	if btn is G.PixelButton:
		var edge := G.GOLD_BRIGHT if sid == _sel else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5)
		if sid == G.equip_weapon_slot():
			edge = Color("d06840") if sid == _sel else Color("c05030")
		(btn as G.PixelButton).set_surface(
			Color("f0e2bc") if sid == _sel else Color("d8c9a0"), edge)

func _refresh() -> void:
	for c in _slots_row.get_children():
		var sid := String(c.get_meta("sid"))
		_slot_surface(c, sid)
		var lv_l := _slot_lv.get(sid) as Label
		if lv_l != null:
			lv_l.text = "+%d" % int(G.equip_state(sid).get("lv", 0))
	var role_name := String(G.get_role(G.selected_role).get("name", ""))
	_hint.text = "红框为「%s」本职业武器" % role_name

	for c in _detail.get_children():
		c.queue_free()

	var cfg := G.equip_slot_cfg(_sel)
	if cfg.is_empty():
		return
	var st := G.equip_state(_sel)
	var has_worn := not st.is_empty()
	var bonus := G.equip_slot_bonus(_sel) if has_worn else {}

	# 属性行
	var stat_parts := PackedStringArray()
	if int(bonus.get("atk", 0)) > 0:
		stat_parts.append("攻击 +%d" % int(bonus["atk"]))
	if int(bonus.get("def", 0)) > 0:
		stat_parts.append("防御 +%d" % int(bonus["def"]))
	if int(bonus.get("hp", 0)) > 0:
		stat_parts.append("生命 +%d" % int(bonus["hp"]))
	if float(bonus.get("crit", 0.0)) > 0.0:
		stat_parts.append("暴击 +%d%%" % roundi(float(bonus["crit"]) * 100.0))
	var stat_l := G.gold_label("%s  %s\n%s" % [String(cfg.get("name", "")),
		"+%d" % int(st.get("lv", 0)) if has_worn else "未装备",
		" · ".join(stat_parts) if not stat_parts.is_empty() else "从背包装备后可养成"],
		G.FS_SM, false, G.TEXT_DARK, false)
	stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stat_l.position = Vector2(0, 0)
	_detail.add_child(stat_l)
	for tab in [["enhance", "强化", 0.0], ["gem", "宝石", 138.0],
		["refine", "精炼", 276.0]]:
		var tab_id := String(tab[0])
		var tab_btn := G.gold_button(String(tab[1]), 132, 36, G.FS_SM) \
			if _work_tab == tab_id else G.ghost_button(String(tab[1]), 132, 36, G.FS_SM)
		tab_btn.set_meta("work_tab", tab_id)
		G.button_icon(tab_btn, {"enhance": "hammer", "gem": "gem", "refine": "spark"}[tab_id])
		tab_btn.position = Vector2(float(tab[2]), 52)
		tab_btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_work_tab = tab_id
				Audio.sfx("ui_page")
				_refresh())
		_detail.add_child(tab_btn)
	var enh_group := Control.new()
	enh_group.set_meta("work_page", "enhance")
	enh_group.position = Vector2(0, 112)
	enh_group.visible = _work_tab == "enhance"
	_detail.add_child(enh_group)

	# 强化行
	var cost := G.equip_enhance_cost(_sel)
	var rate := G.equip_enhance_rate(_sel)
	var level := int(st.get("lv", 0))
	var maxed := level >= G.equip_enhance_max()
	var next_st := st.duplicate(true)
	next_st["lv"] = level + 1
	var next_bonus := G.equip_instance_bonus(next_st)
	var enh_title := G.serif_label("先从背包装备一件物品" if not has_worn else
		"强化预览  +%d → +%d" % [level, mini(level + 1,
		G.equip_enhance_max())], G.FS_MD, Color("664119"))
	enh_title.position = Vector2(0, 0)
	enh_group.add_child(enh_title)
	for card in [["当前属性", bonus, 0.0], ["成功后", next_bonus, 208.0]]:
		var box := G.parchment_box(198, 94, 8.0)
		box.position = Vector2(float(card[2]), 36)
		enh_group.add_child(box)
		var card_content := Control.new()
		card_content.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(card_content)
		var caption := G.gold_label(String(card[0]), G.FS_XS, false, Color("78532c"), false)
		caption.position = Vector2(10, 8)
		card_content.add_child(caption)
		var stat_text := G.text_label(_bonus_summary(card[1] as Dictionary), G.FS_SM,
			Color("3f3524"))
		stat_text.position = Vector2(10, 32)
		stat_text.custom_minimum_size = Vector2(178, 54)
		stat_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_content.add_child(stat_text)
	var enh_l := G.text_label("空槽不能强化" if not has_worn else "已满级" if maxed else
		"消耗：金币 %d · 强化石×%d" % [
		int(cost["gold"]), int(cost["item_n"])], G.FS_SM, Color("664119"))
	enh_l.position = Vector2(0, 138)
	enh_group.add_child(enh_l)
	var guaranteed := int(G.equip_cfg().get("enhance", {}).get("guaranteed_target", 3))
	var rate_text := "成功率 100% · 本次确定成功" \
		if level + 1 <= guaranteed else "成功率%.1f%% · 失败扣费、不掉级\n积累%d/%d · 失败 +%d%%，成功重置" % [
			rate * 100.0, int(st.get("enhance_failures", 0)), G.equip_enhance_failure_limit(_sel),
			roundi(float(G.equip_cfg().get("enhance", {}).get("failure_rate_bonus", 0.15)) * 100.0)]
	var rate_l := G.text_label("请先点右上角背包，为这个槽位穿上装备" if not has_worn else
		"满级，无需继续强化" if maxed else rate_text,
		G.FS_XS, Color("8a5836"))
	rate_l.position = Vector2(0, 166)
	rate_l.custom_minimum_size = Vector2(408, 30)
	rate_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enh_group.add_child(rate_l)
	var enough := has_worn and int(G.wallet.get("gold", 0)) >= int(cost["gold"]) \
		and G.item_count(String(cost["item"])) >= int(cost["item_n"])
	var ready_text := ("先装备，再决定是否强化" if not has_worn else
		"可以强化" if enough and not maxed else \
		"材料不足，请先去背包或委托补足" if not maxed else "此装备已到强化上限")
	var enh_btn := G.gold_button("确认强化", 160, 40, G.FS_MD)
	G.button_icon(enh_btn, "hammer")
	enh_btn.tooltip_text = ready_text
	enh_btn.position = Vector2(124, 220)
	enh_btn.set_meta("work_action", "enhance")
	enh_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if maxed or not has_worn else Control.MOUSE_FILTER_STOP
	enh_btn.modulate.a = 0.55 if maxed or not has_worn else 1.0
	enh_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_enhance())
	enh_group.add_child(enh_btn)
	var gem_group := Control.new()
	gem_group.set_meta("work_page", "gem")
	gem_group.position = Vector2(0, 112)
	gem_group.visible = _work_tab == "gem"
	_detail.add_child(gem_group)

	# 宝石行：3 孔 + 背包宝石
	var gem_t := G.serif_label("宝 石", G.FS_MD, G.TEXT_MUTED)
	gem_t.position = Vector2(0, 0)
	gem_group.add_child(gem_t)
	# 镶嵌 / 合成 两种动作共用这一排宝石格（P04 §6.2）
	var mode_btn := G.gold_button("合 成" if _gem_mode == "socket" else "镶 嵌", 64, 24, G.FS_XS)
	mode_btn.position = Vector2(78, -2)
	mode_btn.tooltip_text = "切换到宝石 3 合 1" if _gem_mode == "socket" else "切换到宝石镶嵌"
	mode_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_gem_mode = "merge" if _gem_mode == "socket" else "socket"
			Audio.sfx("ui_page")
			_refresh())
	gem_group.add_child(mode_btn)
	var uid := int(st.get("uid", 0))
	var gems: Array = st.get("gems", [])
	for i in G.equip_gem_sockets():
		var sock := _socket_box(uid, gems, i)
		sock.position = Vector2(6 + i * 56.0, 48)
		gem_group.add_child(sock)
	# 镶嵌费必须写在按钮旁边（问题 #5）：它是"每次成功镶嵌"扣的金币，不是一次性开孔费。
	# 数值直接读 equip_socket_cost()，与扣费同源，改表即同步。合成模式下改写成合成费与口径。
	var fee_txt := "镶嵌费 %d 金币/次 · 每次镶嵌即扣" % G.equip_socket_cost()
	if _gem_mode == "merge":
		fee_txt = "合成费 %d 金币/次 · 同级同色 %d 颗 → 1 颗更高级" % [
			_gem_merge_cost(), _gem_merge_need()]
	var fee := G.text_label(fee_txt, G.FS_XS, G.TEXT_MUTED)
	fee.position = Vector2(0, 132)
	gem_group.add_child(fee)
	var gem_guide := G.text_label("右侧点同色同级宝石合成；已镶宝石仍可拆除。"
		if _gem_mode == "merge" else "先从背包装备，再镶嵌宝石。" if not has_worn
		else "右侧选宝石镶嵌；左侧点已镶宝石可拆除。",
		G.FS_XS, G.TEXT_MUTED)
	gem_guide.position = Vector2(0, 204)
	gem_group.add_child(gem_guide)

	# 背包宝石分页（问题 #4）：装备表有 15 种宝石（3 色 × 5 级），原来只列前 6 种，
	# 后面的永远选不到。改成 4 列 × 2 行 = 8 格一页，翻页按钮只在多于 1 页时出现。
	var inv := _gem_inventory()
	if inv.is_empty():
		var none := G.text_label("背包暂无宝石（兑换商店有售）", G.FS_XS, G.TEXT_MUTED)
		none.position = Vector2(184, 56)
		gem_group.add_child(none)
	else:
		var pages := gem_page_count()
		_gem_page = clampi(_gem_page, 0, pages - 1)
		var ids := gem_page_ids()
		for slot_i in ids.size():
			var chip := _gem_chip(String(ids[slot_i]))
			chip.position = Vector2(186 + (slot_i % GEM_COLS) * 52.0,
				48 + (slot_i / GEM_COLS) * 40.0)
			gem_group.add_child(chip)
		if pages > 1:
			var pg := G.gold_label("%d/%d" % [_gem_page + 1, pages], G.FS_XS, false,
				G.TEXT_MUTED, false)
			pg.position = Vector2(300, 0)
			pg.custom_minimum_size = Vector2(44, 0)
			pg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gem_group.add_child(pg)
			for arrow in [["◀", -1, 194.0], ["▶", 1, 356.0]]:
				var ab := G.ghost_button(String(arrow[0]), 44, 22, G.FS_XS)
				ab.position = Vector2(float(arrow[2]), 0)
				var step := int(arrow[1])
				ab.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						_gem_page = clampi(_gem_page + step, 0, pages - 1)
						Audio.sfx("ui_page")
						_refresh())
				gem_group.add_child(ab)
	var ref_group := Control.new()
	ref_group.set_meta("work_page", "refine")
	ref_group.position = Vector2(0, 112)
	ref_group.visible = _work_tab == "refine"
	_detail.add_child(ref_group)

	# 精炼区
	var rf_t := G.serif_label("精 炼", G.FS_MD, G.TEXT_MUTED)
	rf_t.position = Vector2(0, 0)
	ref_group.add_child(rf_t)
	var rf_hint := G.text_label("锁住满意词条，再洗其余位置", G.FS_XS, G.TEXT_MUTED)
	rf_hint.position = Vector2(80, 2)
	ref_group.add_child(rf_hint)
	var affixes: Array = st.get("affixes", [])
	if affixes.is_empty():
		var none := G.text_label("尚未精炼出词条", G.FS_XS, G.TEXT_MUTED)
		none.position = Vector2(0, 48)
		ref_group.add_child(none)
	else:
		for i in affixes.size():
			var a := affixes[i] as Dictionary
			var row := _affix_row(a, i)
			row.position = Vector2(0, 44 + i * 34)
			ref_group.add_child(row)
	for i in range(affixes.size(), int(G.equip_cfg().get("refine", {}).get("affix_count", 4))):
		var empty_line := G.text_label("— 空词条 —", G.FS_XS, Color("a48a65"))
		empty_line.position = Vector2(6, 46 + i * 34)
		ref_group.add_child(empty_line)
	var rc: Dictionary = G.equip_cfg().get("refine", {})
	var lock_n := 0
	for a in affixes:
		if bool((a as Dictionary).get("locked", false)):
			lock_n += 1
	var rf_btn := G.gold_button("洗 练", 120, 36, G.FS_MD)
	rf_btn.position = Vector2(144, 224)
	rf_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if not has_worn else Control.MOUSE_FILTER_STOP
	rf_btn.modulate.a = 0.55 if not has_worn else 1.0
	rf_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_refine())
	ref_group.add_child(rf_btn)
	var rf_cost := G.text_label("先从背包装备一件物品" if not has_worn else
		"精炼石×%d%s" % [int(rc.get("cost_item_n", 2)),
		" + 锁符×%d" % lock_n if lock_n > 0 else ""], G.FS_XS, G.TEXT_MUTED)
	rf_cost.position = Vector2(0, 200)
	ref_group.add_child(rf_cost)

	# 背包材料余量
	var mats := G.text_label("背包：强化石×%d · 精炼石×%d · 锁符×%d · 金币 %d" % [
		G.item_count("enhance_stone"), G.item_count("refine_stone"), G.item_count("lock_rune"),
		int(G.wallet.get("gold", 0))], G.FS_XS, G.TEXT_MUTED)
	mats.position = Vector2(0, 380)
	_detail.add_child(mats)

	# 卸下（P04 §6.2）：卸下的装备回背包；背包满时拒绝并提示，不会凭空消失。
	var un_btn := G.gold_button("卸 下", 120, 36, G.FS_MD)
	un_btn.position = Vector2(0, 410)
	un_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_unequip())
	_detail.add_child(un_btn)
	var un_hint := G.text_label("卸下后回到背包（背包满时会拒绝）", G.FS_XS, G.TEXT_MUTED)
	un_hint.position = Vector2(130, 420)
	_detail.add_child(un_hint)


func _bonus_summary(bonus: Dictionary) -> String:
	var lines := PackedStringArray()
	for pair in [["atk", "攻击"], ["def", "防御"], ["hp", "生命"]]:
		var n := int(bonus.get(String(pair[0]), 0))
		if n > 0:
			lines.append("%s +%d" % [String(pair[1]), n])
	var crit := float(bonus.get("crit", 0.0))
	if crit > 0.0:
		lines.append("暴击 +%d%%" % roundi(crit * 100.0))
	return " · ".join(lines) if not lines.is_empty() else "暂无加成"


## 宝石孔。已镶孔位可点：拆除宝石回背包（P04，修掉「只能镶不能拆」的旧问题）
func _socket_box(uid: int, gems: Array, idx: int) -> Control:
	# 内凹镶嵌槽（与背包宝石孔同一语言）
	var root := G.inset_slot(48, 48)
	root.setup(Color("e0d0a8"), Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if idx < gems.size():
		var gid := String(gems[idx])
		var tex: Texture2D = G.res_tex(gid)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(34, 34)
			tr.size = Vector2(34, 34)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(7, 5)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(tr)
		var v := G.gold_label("+%d" % G.equip_gem_value(gid), G.FS_XS - 2, false, G.TEXT_DARK, false)
		v.position = Vector2(0, 34)
		v.custom_minimum_size = Vector2(48, 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(v)
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		root.tooltip_text = "%s  +%d（点击拆除）" % [G.gem_label(gid), G.equip_gem_value(gid)]
		root.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				var r := G.inv_gem_pop(uid, idx)
				_toast_msg("已拆除 %s" % G.gem_label(gid) if bool(r.get("ok", false))
					else String(r.get("err", "")))
				_refresh())
	else:
		var l := G.gold_label("空", G.FS_XS, false, Color("a89468"), false)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.custom_minimum_size = Vector2(48, 0)
		l.position = Vector2(0, 15)
		root.add_child(l)
	return root


## 背包里的宝石 id 列表（gem_*_*）
func _gem_inventory() -> Array:
	var out: Array = []
	for k in G.items.keys():
		var id := String(k)
		if id.begins_with("gem_") and int(G.items[k]) > 0:
			out.append(id)
	out.sort()
	return out


## 宝石区分几页（每页 GEM_COLS×GEM_ROWS）
func gem_page_count() -> int:
	var inv := _gem_inventory()
	return maxi(1, int(ceil(float(inv.size()) / float(GEM_COLS * GEM_ROWS))))


## 当前页实际列出的宝石 id（回归用例据此断言"持有 15 种也全都翻得到"）
func gem_page_ids() -> Array:
	var inv := _gem_inventory()
	var page_size := GEM_COLS * GEM_ROWS
	var begin := _gem_page * page_size
	var out: Array = []
	for k in range(begin, mini(begin + page_size, inv.size())):
		out.append(String(inv[k]))
	return out


func _gem_chip(gid: String) -> Control:
	var root := G.PixelButton.new()
	root.custom_minimum_size = Vector2(48, 36)
	root.set_content_margin(0.0)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_surface(Color("f0e2bc"), G.GOLD)
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)
	var tex: Texture2D = G.res_tex(gid)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(22, 22)
		tr.size = Vector2(22, 22)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(2, 7)
		inner.add_child(tr)
	var cnt := G.gold_label("×%d" % G.item_count(gid), G.FS_XS - 2, false, G.TEXT_DARK, false)
	cnt.position = Vector2(24, 9)
	inner.add_child(cnt)
	root.tooltip_text = "%s  +%d%s" % [G.gem_label(gid), G.equip_gem_value(gid),
		"（点击合成）" if _gem_mode == "merge" else "（点击镶嵌）"]
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _gem_mode == "merge":
				_on_gem_merge(gid)
			else:
				if G.equip_state(_sel).is_empty():
					_toast_msg("先从背包装备一件物品")
					return
				var r := G.equip_socket_gem(_sel, gid)
				_toast_msg("已镶嵌" if bool(r.get("ok", false)) else String(r.get("err", "")))
				_refresh())
	return root


func _affix_row(a: Dictionary, idx: int) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(CONTENT_W, 26)
	var stat := String(a.get("stat", ""))
	var names := {"atk_pct": "攻击", "def_pct": "防御", "maxhp_pct": "生命", "crit_add": "暴击", "spd_pct": "速度"}
	var txt := "「%s」+%0.1f%%" % [String(names.get(stat, stat)), float(a.get("v", 0.0)) * 100.0]
	if stat.is_empty():
		txt = "（空词条）"
	var l := G.text_label(txt, G.FS_SM, G.TEXT_DARK)
	l.position = Vector2(6, 2)
	root.add_child(l)
	var locked := bool(a.get("locked", false))
	var lock_btn := G.gold_button("锁" if locked else "开", 52, 24, G.FS_XS)
	lock_btn.position = Vector2(200, 0)
	if locked:
		(lock_btn.get_child(0) as Label).add_theme_color_override("font_color", Color("a03020"))
	lock_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			G.equip_toggle_lock(_sel, idx)
			_refresh())
	root.add_child(lock_btn)
	return root


func _on_enhance() -> void:
	if G.equip_state(_sel).is_empty():
		_toast_msg("先从背包装备一件物品")
		return
	var r := G.equip_enhance(_sel)
	if not bool(r.get("ok", false)):
		_toast_msg(String(r.get("err", "")))
	elif bool(r.get("success", false)):
		_toast_msg("强化成功！+%d" % int(r.get("lv", 0)))
	else:
		_toast_msg("未成功，等级不变 · 积累%d次，下次%.1f%%" % [
			int(r.get("failures", 0)), float(r.get("next_rate", 0.0)) * 100.0])
	_refresh()


func _on_refine() -> void:
	if G.equip_state(_sel).is_empty():
		_toast_msg("先从背包装备一件物品")
		return
	var r := G.equip_refine(_sel)
	_toast_msg("洗练完成" if bool(r.get("ok", false)) else String(r.get("err", "")))
	_refresh()


# ---------- P04：卸下 / 宝石合成 / 背包直达 ----------

func _on_unequip() -> void:
	var r := G.inv_unequip(_sel)
	_toast_msg("已卸下，装备回到背包" if bool(r.get("ok", false)) else String(r.get("err", "")))
	_refresh()


## 合成口径与扣费同源（data/equip.json 的 merge 段）
func _gem_merge_need() -> int:
	var mc: Dictionary = G.equip_cfg().get("merge", {})
	return maxi(2, int(mc.get("gem_merge_n", 3)))


func _gem_merge_cost() -> int:
	var mc: Dictionary = G.equip_cfg().get("merge", {})
	return maxi(0, int(mc.get("gem_merge_cost_gold", 300)))


func _on_gem_merge(gid: String) -> void:
	var r := G.inv_gem_merge(gid)
	_toast_msg("合成成功 → %s" % G.gem_label(String(r.get("gem", "")))
		if bool(r.get("ok", false)) else String(r.get("err", "")))
	_refresh()


func _open_bag() -> void:
	if _bag != null:
		return
	Audio.sfx("ui_open")
	_bag = BagPanelScript.new()
	_bag.set("z_index", 20)
	_bag.closed.connect(func():
		Audio.sfx("ui_close")
		_bag.queue_free()
		_bag = null
		_refresh())   # 背包里换装/拆宝石都会改动在身实例，关掉后重绘工坊
	add_child(_bag)


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_SM, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 726 + maxf(0.0, get_viewport_rect().size.y - 800.0) * 0.5)
	_toast.custom_minimum_size = Vector2(480, 0)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if _bag != null:   # 背包浮层叠在上面，ESC 交给它，别一次关掉两层
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
