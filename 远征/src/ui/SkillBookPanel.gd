# SkillBookPanel.gd —— 技能书（当前角色 5 技能，每级 k+5%，上限 10 级，耗远征币）
# 一屏一项（皇室战争式大卡聚焦）：PageDeck 翻页，每张卡大留白 + 大号等级珠 + 大升级按钮，
# 不再把 5 张带等级珠的卡片平铺在一屏。
class_name SkillBookPanel
extends Control

signal closed

const CONTENT_W := 408.0
const DECK_H := 400.0
const PageDeckScript := preload("res://src/ui/PageDeck.gd")

var _deck: Control = null
var _expedition_l: Label = null
var _toast: Label = null
var _content: Control = null
var _sids: Array = []


func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# 浮层底衬：统一走 G.veil（深棕 + 暗角 + 斜纹），不再各写一块纯灰
	G.veil(self, 0.78)

	var banner := G.banner_box("技 能 书", 240, 50)
	banner.position = Vector2(120, 30)
	add_child(banner)

	var panel := G.parchment_box(440, 600, 16.0)
	panel.position = Vector2(20, 96)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_content = content

	var role := G.get_role(G.selected_role)
	_expedition_l = G.gold_label("", G.FS_SM, true, Color("4a7a8a"), false)
	_expedition_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_expedition_l.position = Vector2(0, 0)
	content.add_child(_expedition_l)
	# 升级规则收进 ⓘ 弹层，主面板不再铺说明文字
	var info := G.info_button("技能书规则", [
		"每个技能最高 %d 级，每升一级伤害/效果系数 +%d％。" % [
			G.skill_max_level(),
			roundi(float(TableCache.skillbook_config().get("k_per_level", 0.05)) * 100.0)],
		"升级消耗远征币，等级越高费用越贵。",
		"远征币由远征战斗结算产出，战败也有份。",
	], 24.0)
	info.position = Vector2(CONTENT_W - 28.0, -2)
	content.add_child(info)

	# 一屏一项大卡翻页（技能 id 列表由 _refresh 填）
	_deck = PageDeckScript.new(CONTENT_W, DECK_H, 30.0)
	_deck.position = Vector2(0, 40)
	_deck.key_mode = "both"
	content.add_child(_deck)

	var close_btn := G.gold_button("返 回", G.BTN_S.x, G.BTN_S.y, G.FS_SM)
	close_btn.position = Vector2((CONTENT_W - G.BTN_S.x) * 0.5, 466)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(close_btn)

	_refresh()


## 重建卡片。preserve=true 时保留当前页（升级一个技能后不该被弹回第 1 页——问题 #3）；
## preserve=false（首次打开）时落在第一个未满级技能上。
func _refresh(preserve := false) -> void:
	_expedition_l.text = "远征币 %d · 「%s」" % [
		int(G.wallet.get("expedition", 0)),
		String(G.get_role(G.selected_role).get("name", ""))]
	var role := G.get_role(G.selected_role)
	var prev := row_want(preserve)
	_sids = role.get("skills", [])
	# 重建 PageDeck：技能升级会改变等级珠与按钮文案，整块重建（技能少，开销可忽略）
	if _deck != null:
		_deck.queue_free()
	_deck = PageDeckScript.new(CONTENT_W, DECK_H, 30.0)
	_deck.position = Vector2(0, 40)
	_deck.key_mode = "both"
	_deck.set_factory(_sids.size(), func(i: int) -> Control:
		return _skill_page(String(_sids[i])), Vector2(CONTENT_W, DECK_H))
	_content.add_child(_deck)
	# 重建后回到原来的页（列表变短时钳制回退），而不是无条件 go(0)
	_deck.go(clampi(prev, 0, maxi(0, _sids.size() - 1)), true)


## 重建后该回哪一页：保留态就回原页；首次打开则找第一个未满级技能。
func row_want(preserve: bool) -> int:
	if preserve and _deck != null:
		return int(_deck.current)
	for i in _sids.size():
		if G.skill_level(String(_sids[i])) < G.skill_max_level():
			return i
	return 0


## 一页一个大卡片：技能名 + 大号等级珠 + 描述 + 大升级按钮
func _skill_page(sid: String) -> Control:
	var sd := TableCache.get_skill(sid)
	var lv := G.skill_level(sid)
	var mx := G.skill_max_level()
	var cost := G.skill_upgrade_cost(sid)

	var page := Control.new()
	page.custom_minimum_size = Vector2(CONTENT_W, DECK_H)
	page.size = Vector2(CONTENT_W, DECK_H)

	# 内凹贴片语言（G.InsetPanel）：切角 + 顶暗底亮，替代圆角10+软影
	var root := G.InsetPanel.new()
	root.custom_minimum_size = Vector2(CONTENT_W, DECK_H)
	root.setup(Color("f0e2bc"), Color("c9ab5e"), 0.0, 0.0, 0.0, 0.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(0, 0)
	page.add_child(root)

	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)

	# 技能名：宋体大标题，居中
	var name_l := G.serif_label(String(sd.get("name", sid)), G.FS_BIG, G.TEXT_DARK)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(0, 20)
	name_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	inner.add_child(name_l)

	# 大号等级珠：10 颗，居中横排，一眼看出等级
	var dots_w := mx * 30.0
	var dot_x := (CONTENT_W - dots_w) * 0.5
	for i in mx:
		var dot := Panel.new()
		dot.position = Vector2(dot_x + i * 30.0, 68)
		dot.size = Vector2(22, 22)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dsb := StyleBoxFlat.new()
		dsb.set_corner_radius_all(11)
		dsb.bg_color = Color("4a7a9a") if i < lv else Color("d0c09a")
		if i == lv and lv < mx:
			dsb.border_color = G.GOLD_BRIGHT
			dsb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", dsb)
		inner.add_child(dot)

	# 等级文字：「LV3 / 10」
	var lv_l := G.gold_label("LV%d / %d" % [lv, mx], G.FS_MD, true, Color("4a7a8a"), false)
	lv_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_l.position = Vector2(0, 96)
	lv_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	inner.add_child(lv_l)

	# 效果描述：一行，居中（强度百分比移到下面的对比区，不在同一屏说两遍）
	var k0 := float(sd.get("k", 0.0))
	var k_l := G.text_label(String(sd.get("desc", "")), G.FS_SM, Color("5a3a1e"))
	k_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k_l.position = Vector2(20, 128)
	k_l.custom_minimum_size = Vector2(CONTENT_W - 40, 0)
	k_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(k_l)

	# ── 升级对比区：把"当前等级 → 下一等级"的强度变化并排摆出来，升级前就能看到收益
	# 数值口径与 BattleSim 一致：等级只缩放伤害系数 k（k × (1 + k_per×(lv-1))）；
	# 效果型技能（k=0）在战斗里确实不吃等级加成，这里如实说明，不编造缩放数字。
	var k_per := float(TableCache.skillbook_config().get("k_per_level", 0.05))
	var cmp := Control.new()
	cmp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cmp.position = Vector2(0, 172)
	cmp.custom_minimum_size = Vector2(CONTENT_W, 96)
	inner.add_child(cmp)

	# 左右各留 28：PageDeck 的翻页箭头骑在页宽最外侧 26px，留 28 才不会被箭头压住边角
	var m := 28.0
	var inner_w := CONTENT_W - m * 2.0

	if k0 <= 0.0:
		var eff_cell := _cmp_cell(inner_w, 96.0, "效果型技能 LV%d" % lv,
			"效果固定", "升级不改变强度数值", false)
		eff_cell.position = Vector2(m, 0)
		cmp.add_child(eff_cell)
	elif lv >= mx:
		var cap_cell := _cmp_cell(inner_w, 96.0, "已达最高等级 LV%d" % mx,
			"×%.2f" % (k0 * (1.0 + k_per * float(mx - 1))),
			_pct_text(roundi(k_per * float(mx - 1) * 100.0)), true)
		cap_cell.position = Vector2(m, 0)
		cmp.add_child(cap_cell)
	else:
		var gap := 24.0
		var cw := (inner_w - gap) * 0.5
		var cur_cell := _cmp_cell(cw, 96.0, "当前 LV%d" % lv,
			"×%.2f" % (k0 * (1.0 + k_per * float(lv - 1))),
			_pct_text(roundi(k_per * float(lv - 1) * 100.0)), false)
		cur_cell.position = Vector2(m, 0)
		cmp.add_child(cur_cell)
		var next_cell := _cmp_cell(cw, 96.0, "升级后 LV%d" % (lv + 1),
			"×%.2f" % (k0 * (1.0 + k_per * float(lv))),
			_pct_text(roundi(k_per * float(lv) * 100.0)), true)
		next_cell.position = Vector2(CONTENT_W - m - cw, 0)
		cmp.add_child(next_cell)
		var arrow := G.gold_label("→", G.FS_LG, true, Color("8a5a1a"), false)
		arrow.position = Vector2(m + cw, 34)
		arrow.custom_minimum_size = Vector2(gap, 0)
		cmp.add_child(arrow)

	# 大升级按钮：底部居中
	var btn := G.gold_button("已满级" if cost <= 0 else "升 级 · %d 远征币" % cost,
		G.BTN_L.x, G.BTN_L.y, G.FS_MD)
	btn.position = Vector2((CONTENT_W - G.BTN_L.x) * 0.5, 286)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_upgrade(sid))
	inner.add_child(btn)
	return page


## 强度百分比文案：0% 说成"基础强度"，避免出现"+0％"这种废话
func _pct_text(pct: int) -> String:
	return "基础强度" if pct <= 0 else "强度 +%d％" % pct


## 对比区单元格：等宽小牌，三行（标题 / 数值 / 副标）；accent=true 用于"升级后"一侧
func _cmp_cell(w: float, h: float, title: String, value: String, sub: String, accent: bool) -> Control:
	var cell := G.InsetSlot.new()
	cell.custom_minimum_size = Vector2(w, h)
	cell.size = Vector2(w, h)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.setup(Color("f7ecc8") if accent else Color("e6dab6"),
		G.GOLD_BTN_EDGE if accent else Color("c0a868"))

	var t := G.gold_label(title, G.FS_XS, false, Color("8a5a1a") if accent else Color("6a5230"), false)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 12)
	t.custom_minimum_size = Vector2(w, 0)
	cell.add_child(t)

	var v := G.gold_label(value, G.FS_LG, true, Color("8a5a1a") if accent else G.TEXT_DARK, false)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.position = Vector2(0, 34)
	v.custom_minimum_size = Vector2(w, 0)
	cell.add_child(v)

	var s := G.gold_label(sub, G.FS_XS, false, Color("6a5230"), false)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position = Vector2(0, 66)
	s.custom_minimum_size = Vector2(w, 0)
	cell.add_child(s)
	return cell


func _on_upgrade(sid: String) -> void:
	if G.skill_upgrade(sid):
		_toast_msg("「%s」升至 LV%d" % [String(TableCache.get_skill(sid).get("name", sid)), G.skill_level(sid)])
	else:
		_toast_msg("远征币不足或已满级")
	_refresh(true)   # 升级后留在同一页（问题 #3：以前会跳回第 1 页）


func _toast_msg(msg: String) -> void:
	if _toast != null:
		_toast.queue_free()
	_toast = G.gold_label(msg, G.FS_SM, false, Color("ffd0d0"))
	_toast.position = Vector2(0, 706)
	_toast.custom_minimum_size = Vector2(480, 0)
	add_child(_toast)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:   # GM 控制台等全屏层优先（轮次 14）
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
