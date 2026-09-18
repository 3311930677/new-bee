# EquipPanel.gd —— 装备面板（强化 + 宝石镶嵌 + 精炼洗词条）
# 武器 4 系绑人物（剑/枪/杖/锤各自独立强化线），甲/饰全人物通用；
# 当前角色对应的武器槽高亮。全部数值走 data/equip.json。
class_name EquipPanel
extends Control

signal closed

const CONTENT_W := 408.0
const SLOT_W := 62.0

var _sel := ""               # 当前选中槽位
var _detail: Control = null  # 详情区（重绘）
var _slots_row: Control = null
var _hint: Label = null
var _toast: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel = G.equip_weapon_slot()
	if _sel.is_empty():
		_sel = "armor"
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.78)

	var banner := G.banner_box("装 备", 240, 50)
	banner.position = Vector2(120, 30)
	add_child(banner)

	var panel := G.parchment_box(440, 620, 16.0)
	panel.position = Vector2(20, 96)
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

	_hint = G.text_label("", G.FS_XS, Color("8a6a34"))
	_hint.position = Vector2(0, 70)
	_hint.custom_minimum_size = Vector2(CONTENT_W - 40.0, 0)
	content.add_child(_hint)

	# 强化/宝石/精炼规则收进 ⓘ 弹层，不再铺满面板
	var enh: Dictionary = G.equip_cfg().get("enhance", {})
	var info := G.info_button("装备玩法", [
		"【强化】每级属性 +%d％，成功率随等级递减（失败不掉级），最高 %d 级。" % [
			roundi(float(enh.get("pct_per_level", 0.1)) * 100.0), int(enh.get("max_level", 20))],
		"【宝石】每件装备 3 孔，三色宝石各 5 级；开孔花金币，宝石可自由拆装。",
		"【精炼】洗出 4 条随机词条；中意的词条可用锁符锁定，下次洗练不会被冲掉。",
		"【武器】剑/枪/杖/锤四系各自独立强化，跟随对应职业；护甲与饰品全队通用。",
	], 24.0)
	info.position = Vector2(CONTENT_W - 28.0, 66)
	content.add_child(info)

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
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(SLOT_W, 62)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.bg_color = Color("f0e2bc") if sid == _sel else Color("d8c9a0")
	sb.border_color = G.GOLD_BRIGHT if sid == _sel else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5)
	# 当前角色武器槽：金底提示「本职业」
	if sid == G.equip_weapon_slot():
		sb.border_color = Color("c05030")
	G._apply_shadow(sb, 2.0, 1.0, 0.25)
	root.add_theme_stylebox_override("panel", sb)

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
		tr.position = Vector2(16, 2)
		inner.add_child(tr)
	var nm := G.gold_label(String(s.get("name", "")), G.FS_XS - 1, false, G.TEXT_DARK, false)
	nm.position = Vector2(0, 32)
	nm.custom_minimum_size = Vector2(SLOT_W, 0)
	inner.add_child(nm)
	var lv := G.gold_label("+%d" % int(G.equip_state(sid).get("lv", 0)), G.FS_XS - 1, true,
		Color("a06020"), false)
	lv.position = Vector2(0, 46)
	lv.custom_minimum_size = Vector2(SLOT_W, 0)
	inner.add_child(lv)

	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_sel = sid
			_refresh())
	return root


# ---------- 详情区 ----------
func _refresh() -> void:
	for c in _slots_row.get_children():
		var sid := String(c.get_meta("sid"))
		var sb := c.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.bg_color = Color("f0e2bc") if sid == _sel else Color("d8c9a0")
			sb.border_color = G.GOLD_BRIGHT if sid == _sel else Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5)
			if sid == G.equip_weapon_slot():
				sb.border_color = Color("c05030") if sid != _sel else Color("d06840")
		var lv_l := (c.get_child(0) as Control).get_child(2) as Label
		lv_l.text = "+%d" % int(G.equip_state(sid).get("lv", 0))
	var role_name := String(G.get_role(G.selected_role).get("name", ""))
	_hint.text = "红框为「%s」本职业武器" % role_name

	for c in _detail.get_children():
		c.queue_free()

	var cfg := G.equip_slot_cfg(_sel)
	if cfg.is_empty():
		return
	var st := G.equip_state(_sel)
	var bonus := G.equip_slot_bonus(_sel)

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
	var stat_l := G.gold_label("%s  +%d\n%s" % [String(cfg.get("name", "")),
		int(st.get("lv", 0)), " · ".join(stat_parts) if not stat_parts.is_empty() else "暂无加成"],
		G.FS_SM, false, G.TEXT_DARK, false)
	stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stat_l.position = Vector2(0, 0)
	_detail.add_child(stat_l)

	# 强化行
	var cost := G.equip_enhance_cost(_sel)
	var rate := G.equip_enhance_rate(_sel)
	var maxed := int(st.get("lv", 0)) >= G.equip_enhance_max()
	var enh_btn := G.gold_button("强 化", 120, 38, G.FS_MD)
	enh_btn.position = Vector2(0, 52)
	enh_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_enhance())
	_detail.add_child(enh_btn)
	var enh_l := G.text_label("已满级" if maxed else "金币 %d · 强化石×%d · 成功率 %d%%" % [
		int(cost["gold"]), int(cost["item_n"]), roundi(rate * 100.0)], G.FS_XS, Color("7a5a2e"))
	enh_l.position = Vector2(132, 60)
	_detail.add_child(enh_l)

	# 宝石行：3 孔 + 背包宝石
	var gem_t := G.serif_label("宝 石", G.FS_MD, Color("7a5a2e"))
	gem_t.position = Vector2(0, 104)
	_detail.add_child(gem_t)
	var gems: Array = st.get("gems", [])
	for i in G.equip_gem_sockets():
		var sock := _socket_box(gems, i)
		sock.position = Vector2(6 + i * 56.0, 130)
		_detail.add_child(sock)
	var inv := _gem_inventory()
	if inv.is_empty():
		var none := G.text_label("背包暂无宝石（兑换商店有售）", G.FS_XS, Color("8a6a34"))
		none.position = Vector2(186, 138)
		_detail.add_child(none)
	else:
		for i in mini(inv.size(), 6):
			var chip := _gem_chip(String(inv[i]))
			chip.position = Vector2(186 + (i % 3) * 54.0, 130 + (i / 3) * 40.0)
			_detail.add_child(chip)

	# 精炼区
	var rf_t := G.serif_label("精 炼", G.FS_MD, Color("7a5a2e"))
	rf_t.position = Vector2(0, 222)
	_detail.add_child(rf_t)
	var affixes: Array = st.get("affixes", [])
	if affixes.is_empty():
		var none := G.text_label("尚未精炼出词条", G.FS_XS, Color("8a6a34"))
		none.position = Vector2(0, 250)
		_detail.add_child(none)
	else:
		for i in affixes.size():
			var a := affixes[i] as Dictionary
			var row := _affix_row(a, i)
			row.position = Vector2(0, 248 + i * 30)
			_detail.add_child(row)
	var rc: Dictionary = G.equip_cfg().get("refine", {})
	var lock_n := 0
	for a in affixes:
		if bool((a as Dictionary).get("locked", false)):
			lock_n += 1
	var rf_btn := G.gold_button("洗 练", 120, 36, G.FS_MD)
	rf_btn.position = Vector2(CONTENT_W - 120, 218)
	rf_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_refine())
	_detail.add_child(rf_btn)
	var rf_cost := G.text_label("精炼石×%d%s" % [int(rc.get("cost_item_n", 2)),
		" + 锁符×%d" % lock_n if lock_n > 0 else ""], G.FS_XS, Color("7a5a2e"))
	rf_cost.position = Vector2(CONTENT_W - 120, 258)
	_detail.add_child(rf_cost)

	# 背包材料余量
	var mats := G.text_label("背包：强化石×%d · 精炼石×%d · 锁符×%d · 金币 %d" % [
		G.item_count("enhance_stone"), G.item_count("refine_stone"), G.item_count("lock_rune"),
		int(G.wallet.get("gold", 0))], G.FS_XS, Color("8a6a34"))
	mats.position = Vector2(0, 388)
	_detail.add_child(mats)


func _socket_box(gems: Array, idx: int) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2)
	sb.bg_color = Color("e0d0a8")
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5)
	root.add_theme_stylebox_override("panel", sb)
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
			tr.position = Vector2(7, 4)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(tr)
		var v := G.gold_label("+%d" % G.equip_gem_value(gid), G.FS_XS - 2, false, G.TEXT_DARK, false)
		v.position = Vector2(0, 34)
		v.custom_minimum_size = Vector2(48, 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(v)
	else:
		var l := G.gold_label("空", G.FS_XS, false, Color("a89468"), false)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _gem_chip(gid: String) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(48, 36)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f0e2bc")
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = G.GOLD
	root.add_theme_stylebox_override("panel", sb)
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
	root.tooltip_text = "%s  +%d" % [gid, G.equip_gem_value(gid)]
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
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
	var r := G.equip_enhance(_sel)
	if not bool(r.get("ok", false)):
		_toast_msg(String(r.get("err", "")))
	elif bool(r.get("success", false)):
		_toast_msg("强化成功！+%d" % int(r.get("lv", 0)))
	else:
		_toast_msg("强化失败，等级不变")
	_refresh()


func _on_refine() -> void:
	var r := G.equip_refine(_sel)
	_toast_msg("洗练完成" if bool(r.get("ok", false)) else String(r.get("err", "")))
	_refresh()


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_SM, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 726)
	_toast.custom_minimum_size = Vector2(480, 0)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
