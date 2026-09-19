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


func _refresh() -> void:
	_expedition_l.text = "远征币 %d · 「%s」" % [
		int(G.wallet.get("expedition", 0)),
		String(G.get_role(G.selected_role).get("name", ""))]
	var role := G.get_role(G.selected_role)
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
	# 打开先落在「未满级」的技能上（都从 LV1 开始，落第 0 个即可）
	_deck.go(0, true)


## 一页一个大卡片：技能名 + 大号等级珠 + 描述 + 大升级按钮
func _skill_page(sid: String) -> Control:
	var sd := TableCache.get_skill(sid)
	var lv := G.skill_level(sid)
	var mx := G.skill_max_level()
	var cost := G.skill_upgrade_cost(sid)

	var page := Control.new()
	page.custom_minimum_size = Vector2(CONTENT_W, DECK_H)
	page.size = Vector2(CONTENT_W, DECK_H)

	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CONTENT_W, DECK_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f0e2bc")
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(G.GOLD.r, G.GOLD.g, G.GOLD.b, 0.5)
	G._apply_shadow(sb, 3.0, 2.0, 0.22)
	root.add_theme_stylebox_override("panel", sb)
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
		dot.position = Vector2(dot_x + i * 30.0, 80)
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
	lv_l.position = Vector2(0, 116)
	lv_l.custom_minimum_size = Vector2(CONTENT_W, 0)
	inner.add_child(lv_l)

	# 效果描述：一行，居中
	var k0 := float(sd.get("k", 0.0))
	var eff := String(sd.get("desc", ""))
	var mult := G.skill_k_mult(sid)
	if k0 > 0.0 and mult > 1.001:
		eff += " · 强度 +%d％" % roundi((mult - 1.0) * 100.0)
	var k_l := G.text_label(eff, G.FS_SM, Color("5a3a1e"))
	k_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k_l.position = Vector2(20, 156)
	k_l.custom_minimum_size = Vector2(CONTENT_W - 40, 0)
	k_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(k_l)

	# 大升级按钮：底部居中
	var btn := G.gold_button("已满级" if cost <= 0 else "升 级 · %d 远征币" % cost,
		G.BTN_L.x, G.BTN_L.y, G.FS_MD)
	btn.position = Vector2((CONTENT_W - G.BTN_L.x) * 0.5, 260)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_upgrade(sid))
	inner.add_child(btn)
	return page


func _on_upgrade(sid: String) -> void:
	if G.skill_upgrade(sid):
		_toast_msg("「%s」升至 LV%d" % [String(TableCache.get_skill(sid).get("name", sid)), G.skill_level(sid)])
	else:
		_toast_msg("远征币不足或已满级")
	_refresh()


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
