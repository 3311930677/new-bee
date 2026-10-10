# VerifyUiLayout.gd —— 界面布局与刷新回归（场景模式：godot --headless --path . res://tools/VerifyUiLayout.tscn）
# 守问题清单 C1 批：#1 加载进度条比例、#2 称号组内滚动、#3 技能书刷新不跳页、
#                     #4 装备宝石分页、#5 镶嵌费展示、#10 称号组刷新不跳组、#14 槽位等级直引用。
# 这些缺陷的共同点是"静态看代码都对，只有实例化后量尺寸/数节点才露馅"，所以这里一律实例化后测。
extends Node

var _fails := 0


func _ready() -> void:
	G.SAVE_PATH = "user://save_verify_uilayout.json"
	await _run()
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		push_error("FAIL: " + msg)


func _texts(root: Node, out: Array = []) -> Array:
	for c in root.get_children():
		if c is Label or c is Button:
			out.append(String(c.text))
		_texts(c, out)
	return out


func _gem_chip_with_tooltip(root: Node) -> Control:
	for c in root.get_children():
		if c is Control and c.has_meta("gem_id"):
			return c as Control
		var nested := _gem_chip_with_tooltip(c)
		if nested != null:
			return nested
	return null


func _forge_child(root: Control, meta_key: String, meta_value: String) -> Control:
	for child in root.get_children():
		if child is Control and String(child.get_meta(meta_key, "")) == meta_value:
			return child as Control
		if child is Control:
			var nested := _forge_child(child,meta_key,meta_value)
			if nested!=null:return nested
	return null


## 递归找出右边界越界的控件（问题 #12 那一类：固定坐标写死、容器一变宽就压出去）。
## 返回第一个越界控件的描述，没有越界返回空串。
func _overflow_right(node: Node, limit: float, dx := 0.0) -> String:
	for c in node.get_children():
		if not (c is Control):
			continue
		var ctrl := c as Control
		var left := dx + ctrl.position.x
		if left + ctrl.size.x > limit + 1.0:
			var what := ctrl.name
			if ctrl is Label:
				what = String((ctrl as Label).text)
			return "%s 右缘 %.1f > %.1f" % [what, left + ctrl.size.x, limit]
		var sub := _overflow_right(ctrl, limit, left)
		if sub != "":
			return sub
	return ""


func _run() -> void:
	G.wallet = {"gold": 0, "expedition": 0, "soul": 0, "honor": 0}
	G.items = {}
	G.selected_role = "zs"
	G.ensure_starter_pets()

	# ---- #1 加载进度条必须按比例，且 0% 时不能是满格 ----
	var load: Control = load("res://src/ui/LoadScreen.tscn").instantiate()
	load.auto_advance = false   # 不要真的切场景
	add_child(load)
	await get_tree().process_frame
	load._set_bar_ratio(0.0)
	var w0: float = load.bar_fill_width()
	load._set_bar_ratio(0.5)
	var w5: float = load.bar_fill_width()
	load._set_bar_ratio(1.0)
	var w1: float = load.bar_fill_width()
	load._set_bar_ratio(0.0)
	var w0b: float = load.bar_fill_width()
	_check(w0 <= 0.001, "0%% 时填充条宽度应为 0（旧实现被 PanelContainer 撑满，实为 %.1f）" % w0)
	_check(absf(w5 - w1 * 0.5) < 1.0, "50%% 宽度应约为满格一半（%.1f vs %.1f）" % [w5, w1])
	_check(w1 > 100.0, "满格宽度应接近进度条可用宽（实为 %.1f）" % w1)
	_check(absf(w0b - w0) < 0.001, "比例应可反复设置（0→0.5→1→0 回到 0，实为 %.1f）" % w0b)
	var bar: Control = load.get("_bar_fill")
	_check(bar.get_parent() != null and not (bar.get_parent() is Container),
		"填充条不能挂在会强行拉伸子控件的容器下（这正是 #1 的成因）")
	load.queue_free()
	await get_tree().process_frame

	# ---- #2 / #10 称号：单一纵向滚动列表 + 刷新不跳滚动位置 ----
	var tp: Control = (load("res://src/ui/TitlePanel.gd") as GDScript).new()
	add_child(tp)
	await get_tree().process_frame
	var groups: Array = tp.get("_groups")
	_check(groups.size() >= 2, "称号应至少分成 2 组，实为 %d" % groups.size())
	var card_w: float = float(tp.get("CARD_W"))
	var scroll: ScrollContainer = tp.get("_scroll")
	_check(scroll != null, "称号面板应是单一纵向滚动列表（_scroll 缺失）")
	if scroll != null:
		_check(scroll.get_child_count() == 1, "滚动区应只有一个列表容器")
		var box: Control = scroll.get_child(0)
		var want_cards := 0
		for gi in groups.size():
			want_cards += (tp._sorted_group(gi) as Array).size()
		var got_cards := 0
		var last: Control = null
		for c in box.get_children():
			if c is Button and c.has_meta("growth_selection"):
				got_cards += 1
				last = c
		_check(got_cards == want_cards, "滚动列表应放下全部 %d 张称号卡，实为 %d" % [want_cards, got_cards])
		if last != null:
			_check(box.size.y + 1.0 >= last.position.y + last.size.y,
				"最后一张卡应落在滚动内容高度内（内容 %.1f < 卡底 %.1f）"
				% [box.size.y, last.position.y + last.size.y])
			_check(last.size.x >= card_w - 1.0,
				"卡片宽度不应小于 CARD_W（%.1f vs %.1f）" % [last.size.x, card_w])
			var over := _overflow_right(last, last.size.x)
			_check(over == "", "称号卡内有控件超出卡的右边界（%s）" % over)
		_check(box.size.y > scroll.size.y,
			"内容应高于视口才需要滚动（内容 %.1f 视口 %.1f）" % [box.size.y, scroll.size.y])
		# 刷新保留滚动位置（#10 的新形态：列表只有一条，留位置即留组）
		scroll.scroll_vertical = 200
		await get_tree().process_frame
		tp._refresh(true)
		scroll = tp.get("_scroll")
		await get_tree().process_frame
		await get_tree().process_frame   # set_deferred 的 scroll_vertical 要等一帧才生效
		_check(absf(float(scroll.scroll_vertical) - 200.0) < 2.0,
			"佩戴/领取后应留在原滚动位置（#10，实为 %d）" % int(scroll.scroll_vertical))
	tp.queue_free()
	await get_tree().process_frame

	# ---- #3 技能书：升级后刷新不跳页 ----
	G.wallet["expedition"] = 9999
	var sb: Control = (load("res://src/ui/SkillBookPanel.gd") as GDScript).new()
	add_child(sb)
	await get_tree().process_frame
	# _refresh 会整块重建 deck：每次刷新后都必须重新取 sb._deck，
	# 否则断言读的是已经被 queue_free 的旧对象（会得到"看起来对"的假通过）。
	var deck: Control = sb.get("_deck")
	var n_pages := int(deck.page_count)
	_check(n_pages >= 3, "技能书应有至少 3 页技能，实为 %d" % n_pages)
	deck.go(2, true)
	_check(int(sb.get("_deck").current) == 2, "应能把技能书翻到第 3 页")
	sb._refresh(true)
	deck = sb.get("_deck")
	_check(int(deck.page_count) == n_pages, "重建后页数应保持 %d，实为 %d" % [n_pages, int(deck.page_count)])
	_check(int(deck.current) == 2,
		"升级后应留在第 3 页（#3：以前无条件 go(0)，实为 %d）" % int(deck.current))
	# 首次打开（preserve=false）应落在第一个未满级技能上
	var first_unmaxed := -1
	var sids: Array = sb.get("_sids")
	for i in sids.size():
		if G.skill_level(String(sids[i])) < G.skill_max_level():
			first_unmaxed = i
			break
	sb._refresh(false)
	deck = sb.get("_deck")
	_check(int(deck.current) == maxi(0, first_unmaxed),
		"首次打开应落在第一个未满级技能（期望 %d，实为 %d）" % [maxi(0, first_unmaxed), int(deck.current)])
	sb.queue_free()
	await get_tree().process_frame

	# ---- #14 / #4 / #5 装备面板 ----
	G.ensure_starter_equip()
	# 持有全部 15 种宝石（3 色 × 5 级）——#4 的原始表现就是后 9 种永远选不到
	var all_gems: Array = []
	for color in ["atk", "def", "hp"]:
		for lv in range(1, 6):
			var gid := "gem_%s_%d" % [color, lv]
			all_gems.append(gid)
			G.items[gid] = 2
	var ep: Control = (load("res://src/ui/EquipPanel.gd") as GDScript).new()
	add_child(ep)
	await get_tree().process_frame
	# 槽位等级直引用：每个槽都要有一个 Label 引用，不能靠 get_child(2) 数节点
	var slot_n := (G.equip_cfg().get("slots", []) as Array).size()
	var lv_refs: Dictionary = ep.get("_slot_lv")
	_check(lv_refs.size() == slot_n, "应持有全部 %d 个槽位的等级 Label 直引用，实为 %d" % [slot_n, lv_refs.size()])
	ep._refresh()   # 缺图/多图都不该让刷新崩掉或取错节点
	lv_refs=ep.get("_slot_lv")
	var ok_lv := true
	for sid in lv_refs:
		var l: Label = lv_refs[sid]
		if l == null or not l.text.begins_with("+"):
			ok_lv = false
	_check(ok_lv, "刷新后每个槽位等级都应写成 +N")
	await get_tree().process_frame
	var gem_tab := _forge_child(ep.get("_detail") as Control, "work_tab", "gem")
	var tab_press := InputEventMouseButton.new()
	tab_press.button_index = MOUSE_BUTTON_LEFT
	tab_press.pressed = true
	if gem_tab != null:
		(gem_tab as Button).pressed.emit()
	await get_tree().process_frame
	var gem_page := _forge_child(ep.get("_detail") as Control, "work_page", "gem")
	var enhance_page := _forge_child(ep.get("_detail") as Control, "work_page", "enhance")
	_check(ep.get("_work_tab") == "gem"
		and gem_page != null and gem_page.visible
		and enhance_page == null,
		"工坊页签应把宝石操作单独显示")
	# 分页可覆盖全部宝石
	var pages := int(ep.gem_page_count())
	var seen := {}
	for p in pages:
		ep.set("_gem_page", p)
		ep._refresh()
		for gid2 in ep.gem_page_ids():
			seen[String(gid2)] = true
	_check(pages >= 2, "15 种宝石应分成多页，实为 %d 页" % pages)
	_check(seen.size() == all_gems.size(),
		"翻完全部页应能触达全部 %d 种宝石，实为 %d" % [all_gems.size(), seen.size()])
	ep.set("_work_tab", "gem")
	ep._refresh()
	# 镶嵌费必须写在界面上，且与扣费同源
	var fee_txt := " ".join(_texts(ep))
	_check(fee_txt.contains("镶嵌费") and fee_txt.contains(str(G.equip_socket_cost())),
		"界面应显示镶嵌费且数值来自 equip_socket_cost（当前 %d）" % G.equip_socket_cost())
	# 宝石 tooltip 用本地化名，不裸露内部 id
	var chip := _gem_chip_with_tooltip(ep.get("_detail") as Control)
	_check(chip != null and not String(chip.tooltip_text).contains("gem_"),
		"宝石 tooltip 应使用本地化名而不是内部 id（实为「%s」）"
		% ("" if chip == null else String(chip.tooltip_text)))
	await get_tree().process_frame
	var refine_tab := _forge_child(ep.get("_detail") as Control, "work_tab", "refine")
	if refine_tab != null:
		(refine_tab as Button).pressed.emit()
	await get_tree().process_frame
	var refine_page := _forge_child(ep.get("_detail") as Control, "work_page", "refine")
	_check(ep.get("_work_tab") == "refine"
		and refine_page != null and refine_page.visible,
		"工坊精炼页签应可从宝石页切换")
	var gold_before_empty := int(G.wallet.get("gold", 0))
	var stone_before_empty := G.item_count("enhance_stone")
	_check(bool(G.inv_unequip("sword").get("ok", false)), "空槽验证前应能卸下测试大剑")
	ep.set("_sel", "sword")
	ep.call("_on_enhance")
	_check(G.equip_state("sword").is_empty()
		and int(G.wallet.get("gold", 0)) == gold_before_empty
		and G.item_count("enhance_stone") == stone_before_empty,
		"空槽点击强化不能暗中补出基础装备或扣除材料")
	ep.queue_free()
	await get_tree().process_frame

	# ---- P04 背包面板 ----
	# 背包要有四个页签、显示已用/容量，空包时也要给出可操作的指引（不能只画个空壳）
	var bp: Control = (load("res://src/ui/BagPanel.gd") as GDScript).new()
	add_child(bp)
	await get_tree().process_frame
	var bag_txt := " ".join(_texts(bp))
	_check(bag_txt.contains("装备") and bag_txt.contains("材料") and bag_txt.contains("宝石")
		and bag_txt.contains("待领取"),
		"背包应有四个页签（装备/材料/宝石/待领取），现有文案：%s" % bag_txt)
	_check(bag_txt.contains("装备 %d / %d" % [G.inv_count(),G.inv_capacity()]),
		"背包应显示「已用/容量」（容量 %d），现有文案：%s" % [G.inv_capacity(), bag_txt])
	_check(bag_txt.contains("选中器物") or bag_txt.contains("背包里没有装备"),
		"背包装备页应给出可操作的空态/选中指引，现有文案：%s" % bag_txt)
	bp.queue_free()
	await get_tree().process_frame

	# ---- #6 详情弹层的模态所有权：栈 + ESC 只关栈顶 + owner 退出自动释放 ----
	G.ui_blocked = false
	_check(G.modal_count() == 0, "初始不该有模态弹层")
	_check(not G.ui_blocked, "没有弹层时 ui_blocked 应为 false")
	var anchor := Control.new()
	add_child(anchor)
	await get_tree().process_frame
	var m1: CanvasLayer = G.show_info_popup(anchor, "测试弹层一", ["第一层"])
	await get_tree().process_frame
	_check(G.modal_count() == 1, "弹层应入栈（实为 %d）" % G.modal_count())
	_check(G.ui_blocked, "弹层打开时 ui_blocked 必须为真——否则底下的面板会抢走 ESC 与移动")
	var m2: CanvasLayer = G.show_info_popup(anchor, "测试弹层二", ["第二层"])
	await get_tree().process_frame
	_check(G.modal_count() == 2, "第二个弹层应叠在栈上（实为 %d）" % G.modal_count())
	# ESC 只关最上层：第一次 ESC 之后还应该剩一层
	G._unhandled_input(_esc())
	await get_tree().process_frame
	_check(G.modal_count() == 1, "ESC 只应关掉栈顶一层（实为 %d）" % G.modal_count())
	# 被关的那个此时可能已经真的 free 掉了，所以只断言"不再是一个活着的弹层"
	_check(not is_instance_valid(m2) or m2.is_queued_for_deletion(), "被关掉的应是后开的那个弹层")
	_check(is_instance_valid(m1) and not m1.is_queued_for_deletion(), "先开的弹层不该被一起关掉")
	G._unhandled_input(_esc())
	await get_tree().process_frame
	_check(G.modal_count() == 0, "再按一次 ESC 应清空（实为 %d）" % G.modal_count())
	_check(not G.ui_blocked, "弹层全部关闭后 ui_blocked 应回到 false")
	# 重复关闭要安全：再按 ESC 不该报错、也不该影响别的状态
	G._unhandled_input(_esc())
	_check(G.modal_count() == 0, "无弹层时按 ESC 应无副作用")
	# owner 退出 → 弹层自动释放（否则会成为挂在根上的孤儿）
	var owner_node := Control.new()
	add_child(owner_node)
	await get_tree().process_frame
	G.show_info_popup(owner_node, "归属弹层", ["owner 退出时应一起消失"], owner_node)
	await get_tree().process_frame
	_check(G.modal_count() == 1, "带 owner 的弹层应入栈")
	owner_node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(G.modal_count() == 0, "owner 被释放后弹层必须自动出栈（实为 %d）" % G.modal_count())
	_check(not G.ui_blocked, "owner 退出后不该留着阻塞")
	# 转场/GM 自己的锁与模态栈要取并集，不能互相覆盖
	G.ui_blocked = true
	G.show_info_popup(anchor, "锁叠加", ["内部锁 + 弹层"])
	await get_tree().process_frame
	_check(G.ui_blocked, "内部锁与弹层任一为真时 ui_blocked 都应为真")
	G.close_info_popup(null)
	await get_tree().process_frame
	_check(G.modal_count() == 1, "close(null) 不该误删栈里的弹层")
	var m3: CanvasLayer = G._modals[0].get("layer")
	G.close_info_popup(m3)
	await get_tree().process_frame
	_check(G.ui_blocked, "弹层关掉后内部锁还在，ui_blocked 应仍为真（不能把别人的锁放掉）")
	G.ui_blocked = false
	_check(not G.ui_blocked, "内部锁释放后应回到 false")
	anchor.queue_free()
	await get_tree().process_frame

	# ---- #13 委托卡：文字必须在卡片内容矩形内，且不许互相压字 ----
	G.quest["day"] = ""   # 逼一次跨日重刷，保证牌面上一定有委托
	G.quest["offer"] = []
	G.quest["claimed"] = []
	var qp: Control = load("res://src/ui/QuestPanel.tscn").instantiate() \
		if ResourceLoader.exists("res://src/ui/QuestPanel.tscn") else null
	if qp == null:
		qp = (load("res://src/ui/QuestPanel.gd") as GDScript).new()
	add_child(qp)
	await get_tree().process_frame
	var list: Control = qp.get("_list")
	var inner_w: float = float(qp.get("INNER_W"))
	var cards := 0
	for card in list.get_children():
		if not (card is PanelContainer):
			continue
		cards += 1
		_check(card.get_child_count() == 1,
			"委托卡应只有一个内容容器（文字直接挂 _list 会绕过卡片内边距，实为 %d 个子节点）"
			% card.get_child_count())
		var inner: Control = card.get_child(0) as Control
		if inner == null:
			continue
		var over := _overflow_right(inner, inner_w)
		_check(over == "", "委托卡内有控件超出内容宽度（%s）" % over)
		# 同一行的任务名与委托人不得压字
		var row_labels: Array = []
		for c in inner.get_children():
			if c is Label:
				row_labels.append(c as Label)
		if row_labels.size() >= 2:
			var a: Label = row_labels[0]
			var b: Label = row_labels[1]
			_check(a.position.x + a.size.x <= b.position.x + 1.0,
				"任务名与委托人压字（名右缘 %.1f > 委托人左缘 %.1f）"
				% [a.position.x + a.size.x, b.position.x])
	_check(cards >= 1, "今日委托板应至少有一张卡（实为 %d）" % cards)
	qp.queue_free()
	await get_tree().process_frame

	if _fails == 0:
		print("UI_LAYOUT_OK all tests passed")
	else:
		print("UI_LAYOUT_FAIL fails=%d" % _fails)


func _esc() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	return ev
