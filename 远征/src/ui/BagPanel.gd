# BagPanel.gd —— 背包：装备 / 材料 / 宝石 / 待领取（P04）
#
# 为什么需要它：
#   P04 之前装备只是 6 个槽上的等级，没有"背包"这个概念：掉落的装备无处可放，
#   满包/待领取箱根本不存在。这里把「拥有池里没穿在身上的实例」列出来，
#   支持比较（与在身同槽差值）、装备/卸下、锁定、卖出、拆宝石、领取待领取箱。
#
# 数据全部走 G 的薄封装（G.inv_* / G.equip_*），本面板不直接碰 prog。
class_name BagPanel
extends Control

signal closed

const VIEW_W := 480.0
const CONTENT_W := 408.0
const ROWS_PER_PAGE := 8
const ROW_H := 34.0

const TABS := [["equip", "装备"], ["mat", "材料"], ["gem", "宝石"], ["pending", "待领取"]]

var _tab := "equip"
var _page := 0
var _sel_uid := 0
var _confirm_uid := 0    # 已提示"再次点击确认卖出"的实例
var _tabs: Control = null
var _list: Control = null
var _detail: Control = null
var _count_l: Label = null
var _toast: Label = null
var _panel_root: PanelContainer = null
var _banner: Control = null
var _close_btn: Control = null
var _panel_lift := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	G.veil(self, 0.78)
	_panel_lift = maxf(0.0, get_viewport_rect().size.y - 800.0) * 0.5

	_banner = G.banner_box("背 包", 240, 50)
	_banner.position = Vector2(120, 30 + _panel_lift)
	add_child(_banner)

	_panel_root = G.parchment_box(440, 620, 16.0)
	_panel_root.position = Vector2(20, 96 + _panel_lift)
	add_child(_panel_root)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(content)

	_tabs = Control.new()
	_tabs.position = Vector2(0, 0)
	content.add_child(_tabs)

	_count_l = G.gold_label("", G.FS_XS, false, G.TEXT_MUTED, false)
	_count_l.position = Vector2(CONTENT_W - 70.0, 8)
	_count_l.custom_minimum_size = Vector2(68, 0)
	_count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_l.tooltip_text = "背包装备已用格数 / 容量；在身装备不占格"
	content.add_child(_count_l)

	_list = Control.new()
	_list.position = Vector2(6, 42)
	content.add_child(_list)

	_detail = Control.new()
	_detail.position = Vector2(6, 322)
	content.add_child(_detail)

	_close_btn = G.gold_button("返 回", 130, 36, G.FS_MD)
	_close_btn.position = Vector2(CONTENT_W / 2.0 - 65, 556)
	_close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(_close_btn)

	_refresh()


# ---------- 页签 ----------
func _refresh() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for c in _list.get_children():
		c.queue_free()
	for c in _detail.get_children():
		c.queue_free()
	for i in TABS.size():
		var tid := String(TABS[i][0])
		var active := tid == _tab
		var b := G.gold_button(String(TABS[i][1]), 82, 30, G.FS_SM)
		b.position = Vector2(2 + i * 83.0, 0)
		if not active:
			b.modulate = Color(0.78, 0.78, 0.78)
		var t := tid
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_tab = t
				_page = 0
				Audio.sfx("ui_page")
				_refresh())
		_tabs.add_child(b)
	_count_l.text = "已用 %d/%d" % [G.inv_count(), G.inv_capacity()]
	match _tab:
		"equip": _build_equip_tab()
		"mat":
			_layout_panel(ROWS_PER_PAGE)
			_build_mat_tab()
		"gem":
			_layout_panel(ROWS_PER_PAGE)
			_build_gem_tab()
		"pending":
			_layout_panel(ROWS_PER_PAGE)
			_build_pending_tab()


## 装备只有几件时收起空白列表区；详情和按钮跟着上移，弹页整体保持居中。
func _layout_panel(visible_rows: int, page_header := 0.0) -> void:
	var detail_y := minf(322.0 + page_header,
		42.0 + page_header + float(maxi(2, visible_rows)) * ROW_H + 18.0)
	var saved := 322.0 - detail_y
	var panel_h := 620.0 - saved
	_detail.position.y = detail_y
	_close_btn.position.y = 556.0 - saved
	_panel_root.custom_minimum_size.y = panel_h
	_panel_root.size.y = panel_h
	_panel_root.position.y = 96.0 + saved * 0.5 + _panel_lift
	_banner.position.y = 30.0 + saved * 0.5 + _panel_lift


# ---------- 装备页 ----------
## 背包里的实例（拥有池中未被 equip_map 指向的），按稀有度降序、uid 升序
func _bag_items() -> Array:
	var worn := G.inv_worn_uids()
	var out: Array = []
	for it in G.inv_instances():
		var d := it as Dictionary
		if not worn.has(int(d.get("uid", 0))):
			out.append(d)
	out.sort_custom(func(a, b):
		var ra := int((a as Dictionary).get("rarity", 1))
		var rb := int((b as Dictionary).get("rarity", 1))
		if ra != rb:
			return ra > rb
		return int((a as Dictionary).get("uid", 0)) < int((b as Dictionary).get("uid", 0)))
	return out


func _build_equip_tab() -> void:
	var items := _bag_items()
	var pages := maxi(1, int(ceil(float(items.size()) / float(ROWS_PER_PAGE))))
	_page = clampi(_page, 0, pages - 1)
	var page_header := 32.0 if pages > 1 else 0.0
	_layout_panel(clampi(items.size() - _page * ROWS_PER_PAGE, 0, ROWS_PER_PAGE), page_header)
	if items.is_empty():
		var none := G.text_label("背包里没有装备。打怪掉落会自动入包，满了先进待领取箱。",
			G.FS_SM, G.TEXT_MUTED)
		none.position = Vector2(4, 8)
		_list.add_child(none)
	else:
		var begin := _page * ROWS_PER_PAGE
		for i in range(begin, mini(begin + ROWS_PER_PAGE, items.size())):
			var row := _item_row(items[i] as Dictionary)
			row.position = Vector2(0, page_header + (i - begin) * ROW_H)
			_list.add_child(row)
		if pages > 1:
			var pg := G.gold_label("%d/%d" % [_page + 1, pages], G.FS_XS, false, G.TEXT_MUTED, false)
			pg.position = Vector2(CONTENT_W - 216.0, 8)
			pg.custom_minimum_size = Vector2(60, 0)
			pg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_list.add_child(pg)
			for arrow in [["◀", -1, CONTENT_W - 274.0], ["▶", 1, CONTENT_W - 92.0]]:
				var ab := G.ghost_button(String(arrow[0]), 44, 22, G.FS_XS)
				ab.position = Vector2(float(arrow[2]), 8)
				var step := int(arrow[1])
				ab.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						_page = clampi(_page + step, 0, pages - 1)
						Audio.sfx("ui_page")
						_refresh())
				_list.add_child(ab)
	_build_detail()


func _item_row(inst: Dictionary) -> Control:
	var uid := int(inst.get("uid", 0))
	var rarity := int(inst.get("rarity", 1))
	# PixelButton 皮：切角+厚度+硬影；选中态换金底深边（原先是直角纯色块）
	var root := G.PixelButton.new()
	root.set_meta("gear_uid", uid)
	root.custom_minimum_size = Vector2(CONTENT_W - 12.0, ROW_H - 2.0)
	root.set_content_margin(0.0)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	if uid == _sel_uid:
		root.set_surface(Color("e2c275"), G.WOOD_DARK)
	else:
		root.set_surface(G.PARCHMENT, Color("c2ad7b"))
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)
	var tpl := G.equip_tpl(String(inst.get("tpl", "")))
	var tex: Texture2D = G.res_tex(String(tpl.get("icon", "")))
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(26, 26)
		tr.size = Vector2(26, 26)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(8, 2)
		inner.add_child(tr)
	var txt := "%s  [%s] +%d" % [String(tpl.get("name", "?")), G.equip_rarity_name(rarity),
		int(inst.get("lv", 0))]
	var nm := G.gold_label(txt, G.FS_SM, false, G.TEXT_DARK, false)
	nm.position = Vector2(42, 4)
	inner.add_child(nm)
	if bool(inst.get("locked", false)):
		var lk := G.gold_label("锁", G.FS_XS, true, Color("a03020"), false)
		lk.position = Vector2(CONTENT_W - 60.0, 6)
		inner.add_child(lk)
	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_sel_uid = uid
			_confirm_uid = 0
			_refresh())
	return root


## 详情区：名称/稀有度/强化/基础属性/宝石孔/词条 + 比较 + 操作
func _build_detail() -> void:
	var inst := G.inv_find(_sel_uid)
	if inst.is_empty():
		var hint := G.text_label("选中一件装备查看详情与比较", G.FS_SM, G.TEXT_MUTED)
		hint.position = Vector2(4, 4)
		_detail.add_child(hint)
		return
	var uid := int(inst.get("uid", 0))
	var tpl := G.equip_tpl(String(inst.get("tpl", "")))
	var slot := String(inst.get("slot", ""))
	var worn := G.inv_worn_uids().has(uid)
	var rarity := int(inst.get("rarity", 1))
	var bonus := G.equip_instance_bonus(inst)

	var title := "%s  [%s]%s" % [String(tpl.get("name", "?")), G.equip_rarity_name(rarity),
		"（在身）" if worn else ""]
	var title_l := G.gold_label(title, G.FS_MD, true, G.paper_ink(G.equip_rarity_color(rarity)), false)
	title_l.position = Vector2(0, 0)
	_detail.add_child(title_l)

	var parts := _stat_parts(bonus)
	var stat_l := G.text_label("+%d · %s" % [int(inst.get("lv", 0)),
		" · ".join(parts) if not parts.is_empty() else "暂无加成"], G.FS_XS, G.TEXT_MUTED)
	stat_l.position = Vector2(0, 26)
	_detail.add_child(stat_l)

	# 比较：与在身同槽实例逐项差值
	var cmp_l := G.text_label(_compare_text(slot, inst), G.FS_XS, G.TEXT_MUTED)
	cmp_l.position = Vector2(0, 46)
	_detail.add_child(cmp_l)

	# 宝石孔（点已镶孔位 = 拆除宝石）
	var gem_t := G.gold_label("宝石孔（点已镶孔位拆除）", G.FS_XS, false, G.TEXT_MUTED, false)
	gem_t.position = Vector2(0, 70)
	_detail.add_child(gem_t)
	var gems: Array = inst.get("gems", [])
	for i in maxi(1, int(inst.get("sockets", 0))):
		var box := _socket_box(uid, gems, i)
		box.position = Vector2(6 + i * 46.0, 88)
		_detail.add_child(box)

	# 词条
	var affixes: Array = inst.get("affixes", [])
	var aff_txt := "（无词条）"
	if not affixes.is_empty():
		var names := {"atk_pct": "攻击", "def_pct": "防御", "maxhp_pct": "生命",
			"crit_add": "暴击", "spd_pct": "速度"}
		var ap := PackedStringArray()
		for a in affixes:
			var ad := a as Dictionary
			var s := String(ad.get("stat", ""))
			if s.is_empty():
				continue
			ap.append("%s+%0.1f%%" % [String(names.get(s, s)), float(ad.get("v", 0.0)) * 100.0])
		if not ap.is_empty():
			aff_txt = "词条：" + " · ".join(ap)
	var aff_l := G.text_label(aff_txt, G.FS_XS, G.TEXT_MUTED)
	aff_l.position = Vector2(0, 140)
	_detail.add_child(aff_l)
	var provenance := CampaignGear.source_text(inst)
	var need := int(tpl.get("requires_level", 0))
	if need > 0 or not provenance.is_empty():
		var line := "需求 Lv%d · %s" % [maxi(1, need), provenance] if need > 0 else provenance
		var source_l := G.text_label(line, G.FS_XS, G.TEXT_MUTED)
		source_l.position = Vector2(0, 160)
		_detail.add_child(source_l)

	_build_detail_buttons(inst, worn)


func _build_detail_buttons(inst: Dictionary, worn: bool) -> void:
	var uid := int(inst.get("uid", 0))
	var slot := String(inst.get("slot", ""))
	var y := 168.0
	if int(G.equip_tpl(String(inst.get("tpl", ""))).get("requires_level", 0)) > 0 or not CampaignGear.source_text(inst).is_empty(): y = 188.0
	# 装备 / 卸下
	var act := G.gold_button("卸 下" if worn else "装 备", 110, 34, G.FS_SM)
	act.position = Vector2(0, y)
	act.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_do_equip_or_unequip(uid, slot, worn))
	_detail.add_child(act)

	# 锁定 / 解锁
	var locked := bool(inst.get("locked", false))
	var lk := G.gold_button("解 锁" if locked else "锁 定", 110, 34, G.FS_SM)
	lk.position = Vector2(120, y)
	lk.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var r := G.inv_set_locked(uid, not locked)
			_toast_msg("已锁定" if bool(r.get("ok", false)) else String(r.get("err", "")))
			_refresh())
	_detail.add_child(lk)

	# 卖出（在身/锁定拒绝；强化过或稀有需二次确认）
	var price := G.inv_sell_price(uid)
	var sell := G.gold_button("卖出 %d 金" % price if price > 0 else "卖 出", 150, 34, G.FS_SM)
	sell.position = Vector2(240, y)
	sell.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_do_sell(uid))
	_detail.add_child(sell)


func _do_equip_or_unequip(uid: int, slot: String, worn: bool) -> void:
	var r: Dictionary
	if worn:
		r = G.inv_unequip(slot)
	else:
		r = G.inv_equip(uid)
	_toast_msg(_ok_msg(r, "已换上" if not worn else "已卸下"))
	_refresh()


func _do_sell(uid: int) -> void:
	var confirm := _confirm_uid == uid
	var r := G.inv_sell(uid, confirm)
	if bool(r.get("need_confirm", false)):
		_confirm_uid = uid
		_toast_msg("再次点击确认卖出")
		return
	if bool(r.get("ok", false)):
		_confirm_uid = 0
		_sel_uid = 0
		_toast_msg("已卖出 · 铜钱 +%d" % int(r.get("gold", 0)))
	else:
		_toast_msg(String(r.get("err", "")))
	_refresh()


func _ok_msg(r: Dictionary, ok_text: String) -> String:
	return ok_text if bool(r.get("ok", false)) else String(r.get("err", ""))


## 与在身同槽实例的比较文案（攻击 +2 / 攻击 -2 / 持平）
func _compare_text(slot: String, inst: Dictionary) -> String:
	var other := G.equip_state(slot)
	if slot.is_empty():
		return ""
	if other.is_empty():
		return "比较：该部位未装备，换上即为当前面板"
	var mine := G.equip_instance_bonus(inst)
	var theirs := G.equip_instance_bonus(other)
	var names := {"atk": "攻击", "def": "防御", "hp": "生命"}
	var parts := PackedStringArray()
	for k in ["atk", "def", "hp"]:
		var d := int(mine.get(k, 0)) - int(theirs.get(k, 0))
		if d > 0:
			parts.append("%s +%d" % [String(names[k]), d])
		elif d < 0:
			parts.append("%s %d" % [String(names[k]), d])
	var dc := float(mine.get("crit", 0.0)) - float(theirs.get("crit", 0.0))
	if absf(dc) > 0.0001:
		parts.append("暴击 %+d%%" % roundi(dc * 100.0))
	if parts.is_empty():
		return "比较：与在身持平"
	return "比较：" + " · ".join(parts)


func _stat_parts(bonus: Dictionary) -> PackedStringArray:
	var parts := PackedStringArray()
	if int(bonus.get("atk", 0)) > 0:
		parts.append("攻击 +%d" % int(bonus["atk"]))
	if int(bonus.get("def", 0)) > 0:
		parts.append("防御 +%d" % int(bonus["def"]))
	if int(bonus.get("hp", 0)) > 0:
		parts.append("生命 +%d" % int(bonus["hp"]))
	if float(bonus.get("crit", 0.0)) > 0.0:
		parts.append("暴击 +%d%%" % roundi(float(bonus["crit"]) * 100.0))
	return parts


func _socket_box(uid: int, gems: Array, idx: int) -> Control:
	# 宝石孔：内凹槽（凹进去的镶嵌位），宝石浮在槽里；空槽躺一枚浅「空」字
	var root := G.inset_slot(40, 40)
	root.setup(Color("e0d0a8"), Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5))
	if idx < gems.size():
		var gid := String(gems[idx])
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		root.tooltip_text = "%s  +%d（点击拆除）" % [G.gem_label(gid), G.equip_gem_value(gid)]
		var tex: Texture2D = G.res_tex(gid)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.custom_minimum_size = Vector2(28, 28)
			tr.size = Vector2(28, 28)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(6, 6)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(tr)
		root.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				var r := G.inv_gem_pop(uid, idx)
				_toast_msg("已拆除 %s" % G.gem_label(gid) if bool(r.get("ok", false))
					else String(r.get("err", "")))
				_refresh())
	else:
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := G.gold_label("空", G.FS_XS, false, Color("a89468"), false)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.custom_minimum_size = Vector2(40, 0)
		l.position = Vector2(0, 11)
		root.add_child(l)
	return root


# ---------- 材料页（只读汇总） ----------
func _build_mat_tab() -> void:
	var ids: Array = []
	for k in G.items.keys():
		var id := String(k)
		if id.begins_with("gem_"):
			continue
		if int(G.items[k]) > 0:
			ids.append(id)
	ids.sort()
	if ids.is_empty():
		var none := G.text_label("暂无材料。打怪掉落的强化石、精炼石等会堆叠在这里（不占背包格）。",
			G.FS_SM, G.TEXT_MUTED)
		none.position = Vector2(4, 8)
		_list.add_child(none)
	else:
		for i in ids.size():
			var id := String(ids[i])
			var row := G.text_label("%s ×%d" % [G.item_name(id), G.item_count(id)],
				G.FS_SM, G.TEXT_DARK)
			row.position = Vector2(8, i * 26.0)
			_list.add_child(row)
	var hint := G.text_label("材料与宝石不占背包格；加工操作在「养成 → 装备」里。",
		G.FS_XS, G.TEXT_MUTED)
	hint.position = Vector2(4, 0)
	_detail.add_child(hint)


# ---------- 宝石页（只读汇总） ----------
func _build_gem_tab() -> void:
	var ids: Array = []
	for k in G.items.keys():
		var id := String(k)
		if id.begins_with("gem_") and int(G.items[k]) > 0:
			ids.append(id)
	ids.sort()
	if ids.is_empty():
		var none := G.text_label("暂无宝石（兑换商店有售）。镶嵌与 3 合 1 合成在「养成 → 装备」。",
			G.FS_SM, G.TEXT_MUTED)
		none.position = Vector2(4, 8)
		_list.add_child(none)
	else:
		for i in ids.size():
			var id := String(ids[i])
			var row := G.text_label("%s  +%d  ×%d" % [G.gem_label(id), G.equip_gem_value(id),
				G.item_count(id)], G.FS_SM, G.TEXT_DARK)
			row.position = Vector2(8, i * 26.0)
			_list.add_child(row)
	var hint := G.text_label("3 颗同级同色可合成 1 颗更高级（在「养成 → 装备 → 宝石」操作）。",
		G.FS_XS, G.TEXT_MUTED)
	hint.position = Vector2(4, 0)
	_detail.add_child(hint)


# ---------- 待领取页 ----------
func _build_pending_tab() -> void:
	var pend := G.inv_pending()
	var pages := maxi(1, int(ceil(float(pend.size()) / float(ROWS_PER_PAGE))))
	_page = clampi(_page, 0, pages-1)
	var header := 32.0 if pages > 1 else 0.0
	_layout_panel(clampi(pend.size()-_page*ROWS_PER_PAGE,0,ROWS_PER_PAGE),header)
	if pend.is_empty():
		var none := G.text_label("待领取箱是空的。背包满时掉落会先存这里，绝不会丢。",
			G.FS_SM, G.TEXT_MUTED)
		none.position = Vector2(4, 8)
		_list.add_child(none)
		return
	if pages > 1:
		var page_l := G.gold_label("%d/%d" % [_page+1,pages],G.FS_XS,false,G.TEXT_MUTED,false)
		page_l.position = Vector2(CONTENT_W-216,8)
		page_l.custom_minimum_size.x = 60
		page_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(page_l)
		for arrow in [["◀",-1,CONTENT_W-274],["▶",1,CONTENT_W-92]]:
			var button := G.ghost_button(String(arrow[0]),44,22,G.FS_XS)
			button.position = Vector2(float(arrow[2]),8)
			var step := int(arrow[1])
			button.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					_page = clampi(_page+step,0,pages-1)
					_refresh())
			_list.add_child(button)
	var begin := _page*ROWS_PER_PAGE
	for i in range(begin,mini(begin+ROWS_PER_PAGE,pend.size())):
		var inst := pend[i] as Dictionary
		var uid := int(inst.get("uid", 0))
		var tpl := G.equip_tpl(String(inst.get("tpl", "")))
		var row := G.PixelButton.new()
		row.custom_minimum_size = Vector2(CONTENT_W - 12.0, ROW_H - 2.0)
		row.set_content_margin(0.0)
		row.set_surface(Color("e6d8b0"), G.equip_rarity_color(int(inst.get("rarity", 1))))
		var inner := Control.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(inner)
		var nm := G.gold_label("%s  [%s] +%d" % [String(tpl.get("name", "?")),
			G.equip_rarity_name(int(inst.get("rarity", 1))), int(inst.get("lv", 0))],
			G.FS_SM, false, G.TEXT_DARK, false)
		nm.position = Vector2(10, 4)
		inner.add_child(nm)
		row.position = Vector2(0, header+(i-begin)*ROW_H)
		_list.add_child(row)
		var btn := G.gold_button("领 取", 90, 26, G.FS_XS)
		btn.set_meta("gear_uid", uid)
		btn.position = Vector2(CONTENT_W - 108.0, header+(i-begin)*ROW_H+4)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				var r := G.inv_claim(uid)
				_toast_msg(_ok_msg(r, "已领取"))
				_refresh())
		_list.add_child(btn)


func _toast_msg(msg: String) -> void:
	if msg.is_empty():
		return
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
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
