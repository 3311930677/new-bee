# PetRaisePanel.gd —— 宠物养成（升级·宠物粮 / 突破·突破晶+魂石 / 资质·资质果）
# 版式：顶部是「一屏一只」的灵宠轮播（大图居中 + 名字/等级/星级），
#      下方只留养成操作 —— 旧版一排 52×64 小头像既挤又看不清，换成大卡后一眼认得出是谁。
# 培养链路见玩法文档 §3.2；战斗属性快照由 G.battle_pet_stats 传给 BattleSim。
class_name PetRaisePanel
extends Control

signal closed

# 新 class_name 尚未进编辑器全局类缓存，按项目惯例 preload 路径取脚本
const PageDeckScript := preload("res://src/ui/PageDeck.gd")
const SlideCardScript := preload("res://src/ui/SlideCard.gd")

const CONTENT_W := 408.0
const DECK_H := 196.0        # 卡高要装得下：页眉 18 + 插画 + 名字 30 + 星级 18 + 间距
const DETAIL_Y := 226.0

var _sel := ""
var _owned: Array = []
var _content: Control = null
var _deck_holder: Control = null
var _deck = null            # PageDeck（类型不写死，避免全局类缓存未刷新时报错）
var _detail: Control = null
var _toast: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_owned = G.owned_pets()
	if not _owned.is_empty():
		_sel = String(_owned[0])
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var banner := G.banner_box("灵宠养成", 240, 50)
	banner.position = Vector2(120, 30)
	add_child(banner)

	var panel := G.parchment_box(440, 620, 16.0)
	panel.position = Vector2(20, 96)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_content = content

	# 灵宠轮播（一屏一只）：←→/AD 或拖拽切换，圆点在卡下页脚
	_deck_holder = Control.new()
	_deck_holder.position = Vector2(0, 0)
	_deck_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_deck_holder)

	_detail = Control.new()
	_detail.position = Vector2(0, DETAIL_Y)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_detail)

	var close_btn := G.gold_button("返 回", 130, 36, G.FS_MD)
	close_btn.position = Vector2(CONTENT_W / 2.0 - 65, 544)
	close_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(close_btn)

	_refresh()


func _refresh() -> void:
	_owned = G.owned_pets()
	if not _owned.is_empty() and (_sel.is_empty() or not _owned.has(_sel)):
		_sel = String(_owned[0])
	_rebuild_deck()
	_build_detail()


## 重建轮播：技能/突破会改变卡片上的数值，干脆整块重建（灵宠通常只有几只，开销可忽略）
func _rebuild_deck() -> void:
	if _deck != null:
		_deck_holder.remove_child(_deck)
		_deck.queue_free()
		_deck = null
	var start := maxi(0, _owned.find(_sel))
	_deck = PageDeckScript.new(CONTENT_W, DECK_H, 22.0)
	_deck.key_mode = "both"   # 方向键 / WASD 都能换灵宠
	_deck.page_changed.connect(_on_pet_page)
	if _owned.is_empty():
		_deck_holder.add_child(_deck)
		return
	for i in _owned.size():
		var pid := String(_owned[i])
		_deck.add_page(SlideCardScript.page(_pet_card(pid, i), CONTENT_W, DECK_H),
			Vector2(CONTENT_W, DECK_H))
	_deck_holder.add_child(_deck)
	_deck.go(start, true)


func _on_pet_page(i: int) -> void:
	if i < 0 or i >= _owned.size():
		return
	var pid := String(_owned[i])
	if pid == _sel:
		return
	_sel = pid
	_build_detail()


## 轮播卡：大图 + 名字（含等级）+ 星级；突破层数放副标题，一眼看出养成度
func _pet_card(pid: String, idx: int) -> Control:
	var pd := TableCache.get_pet(pid)
	var st := G.pet_stat(pid)
	var lv := int(st.get("lv", 1))
	var star := int(st.get("star", 3))
	var brk := int(st.get("brk", 0))
	var stars := ""
	for i in 5:
		stars += "★" if i < star else "☆"
	return SlideCardScript.new({
		"kicker": "灵 宠 %02d / %02d" % [idx + 1, _owned.size()],
		"title": "%s  Lv%d" % [String(pd.get("name", pid)), lv],
		"subtitle": "%s · 突破 %d / 5" % [stars, brk],
		"art_names": ["%s_art" % pid, pid],
		"art_hint": "%s.png" % pid,
		"art_tint": Color("c09a55"),
		"art_fit": "contain",
		"art_ratio": 0.34,
		"badge": "出战主力" if idx == 0 else "",
		"badge_color": Color("8a4a2a"),
	})


func _build_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	if _owned.is_empty():
		var none := G.text_label("尚未收集任何灵宠", G.FS_SM, Color("8a6a34"))
		none.position = Vector2(0, 40)
		_detail.add_child(none)
		return

	var pd := TableCache.get_pet(_sel)
	var st := G.pet_stat(_sel)
	var lv := int(st.get("lv", 1))
	var brk := int(st.get("brk", 0))

	# 突破进度（名字/星级已在上方轮播卡里，这里不重复画一遍）
	var brk_l := G.gold_label("突破 %d / 5 层（每层全属性 +8%%）" % brk, G.FS_XS, false,
		Color("7a5a2e"), false)
	brk_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	brk_l.position = Vector2(40, 0)
	_detail.add_child(brk_l)

	# 经验条
	var cap := int(G.prog.get("level", 1))
	var need := G.pet_exp_to_next(lv)
	var cur := int(st.get("exp", 0))
	var bar_bg := ColorRect.new()
	bar_bg.color = Color("b8a884")
	bar_bg.position = Vector2(40, 24)
	bar_bg.size = Vector2(240, 12)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = Color("d8a838")
	bar.position = Vector2(41, 25)
	bar.size = Vector2(238.0 * clampf(float(cur) / maxf(1.0, float(need)), 0.0, 1.0), 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(bar)
	var exp_l := G.text_label("本级满（达人物等级上限）" if lv >= cap else "经验 %d / %d" % [cur, need],
		G.FS_XS, Color("7a5a2e"))
	exp_l.position = Vector2(286, 22)
	_detail.add_child(exp_l)

	# 当前属性预览（按养成状态）
	var base: Dictionary = pd.get("base", {})
	var growth: Dictionary = pd.get("growth", {})
	var gmult := G.pet_growth_mult(_sel)
	var smult := G.pet_stat_mult(_sel)
	var hp := int((float(int(base.get("hp", 50))) + float(growth.get("hp", 0)) * float(lv - 1) * gmult) * smult)
	var atk := int((float(int(base.get("atk", 10))) + float(growth.get("atk", 0)) * float(lv - 1) * gmult) * smult)
	var def := int((float(int(base.get("def", 5))) + float(growth.get("def", 0)) * float(lv - 1) * gmult) * smult)
	var stat_l := G.gold_label("血 %d · 攻 %d · 防 %d" % [hp, atk, def], G.FS_SM, true,
		Color("a06020"), false)
	stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stat_l.position = Vector2(40, 48)
	_detail.add_child(stat_l)

	# 三操作：喂养 / 突破 / 重随资质
	var feed_btn := _op_btn("喂 养", "宠物粮 ×%d（%d 经验/份）" % [G.item_count("pet_food"), 100])
	feed_btn.position = Vector2(40, 76)
	feed_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_feed())
	_detail.add_child(feed_btn)

	var cost := G.pet_break_cost(_sel)
	var brk_text := "已至五层" if cost.is_empty() else "突破晶×%d + 魂石 %d" % [int(cost["crystal"]), int(cost["soul"])]
	var brk_btn := _op_btn("突 破", "%s（持有 ×%d）" % [brk_text, G.item_count("break_crystal")])
	brk_btn.position = Vector2(40, 138)
	brk_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_break())
	_detail.add_child(brk_btn)

	var star_btn := _op_btn("洗资质", "资质果 ×%d（随机 1~5 星）" % G.item_count("aptitude_fruit"))
	star_btn.position = Vector2(40, 200)
	star_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_reroll())
	_detail.add_child(star_btn)

	var tip := G.text_label("材料产出自「兑换」商店与远征掉落；资质影响每级成长（1星×0.8 ~ 5星×1.6）。",
		G.FS_XS, Color("8a6a34"))
	tip.position = Vector2(40, 264)
	tip.custom_minimum_size = Vector2(CONTENT_W - 80.0, 0)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(tip)


func _op_btn(label: String, sub: String) -> Control:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(CONTENT_W - 80.0, 56)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = G.GOLD_BTN
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = G.GOLD_BTN_EDGE
	G._apply_shadow(sb, 4.0, 2.0, 0.3)
	root.add_theme_stylebox_override("panel", sb)
	var inner := Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inner)
	var l := G.gold_label(label, G.FS_MD, true, G.TEXT_DARK, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.position = Vector2(18, 6)
	inner.add_child(l)
	var s := G.text_label(sub, G.FS_XS, Color("5a4018"))
	s.position = Vector2(14, 32)
	inner.add_child(s)
	return root


func _on_feed() -> void:
	var r := G.pet_feed(_sel)
	if not bool(r.get("ok", false)):
		_toast_msg(String(r.get("err", "")))
	elif int(r.get("ups", 0)) > 0:
		_toast_msg("升到 Lv%d！" % int(r.get("lv", 1)))
	else:
		_toast_msg("经验 +100")
	_refresh()


func _on_break() -> void:
	var r := G.pet_break(_sel)
	_toast_msg("突破成功！当前 %d 层" % int(r.get("brk", 0)) if bool(r.get("ok", false))
		else String(r.get("err", "")))
	_refresh()


func _on_reroll() -> void:
	var r := G.pet_reroll_star(_sel)
	_toast_msg("新资质 %d 星！" % int(r.get("star", 0)) if bool(r.get("ok", false))
		else String(r.get("err", "")))
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
