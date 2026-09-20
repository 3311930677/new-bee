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
		if c is Label:
			out.append(String((c as Label).text))
		_texts(c, out)
	return out


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

	# ---- #2 / #10 称号：组内滚动 + 刷新不跳组 ----
	var tp: Control = (load("res://src/ui/TitlePanel.gd") as GDScript).new()
	add_child(tp)
	await get_tree().process_frame
	var groups: Array = tp.get("_groups")
	_check(groups.size() >= 2, "称号应至少分成 2 组，实为 %d" % groups.size())
	var card_w: float = float(tp.get("CARD_W"))
	for gi in groups.size():
		var page: Control = tp._group_page(gi)
		# 必须真的挂进场景树再量：不在树上的控件不会布局，size 全是 0，
		# 那样断言只会"因为拿不到尺寸而假通过"。
		add_child(page)
		await get_tree().process_frame
		var scroll: ScrollContainer = null
		for c in page.get_children():
			if c is ScrollContainer:
				scroll = c
		_check(scroll != null, "第 %d 组页应有纵向滚动区（否则组内多于 4~5 条就永远点不到）" % gi)
		if scroll == null:
			page.queue_free()
			continue
		var box: Control = scroll.get_child(0)
		var want_n := (tp._sorted_group(gi) as Array).size()
		_check(box.get_child_count() == want_n,
			"第 %d 组的滚动区应放下全部 %d 张卡，实为 %d" % [gi, want_n, box.get_child_count()])
		if box.get_child_count() > 0:
			var last: Control = box.get_child(box.get_child_count() - 1)
			_check(box.size.y + 1.0 >= last.position.y + last.size.y,
				"最后一张卡应落在滚动内容高度内（内容 %.1f < 卡底 %.1f）"
				% [box.size.y, last.position.y + last.size.y])
			# 卡宽由容器给（滚动条出现与否会差几个像素），所以只要求不小于给滚动条
			# 让位后的 CARD_W——真正要守的是"卡内元素不越界"，见下面那条。
			_check(last.size.x >= card_w - 1.0,
				"卡片宽度不应小于 CARD_W（%.1f vs %.1f）" % [last.size.x, card_w])
			var over := _overflow_right(last, last.size.x)
			_check(over == "",
				"第 %d 组卡片内有控件超出卡的右边界（%s）——滚动条一出现右侧按钮就会被裁掉"
				% [gi, over])
			if want_n >= 5:
				_check(box.size.y > scroll.size.y,
					"该组有 %d 张卡，内容应高于视口才需要滚动（内容 %.1f 视口 %.1f）"
					% [want_n, box.size.y, scroll.size.y])
		page.queue_free()
		await get_tree().process_frame
	# 刷新保留当前组：跳到最后一组后 _refresh(true) 不该弹回默认组。
	# ⚠ _refresh 会 queue_free 旧 deck 并新建一个，断言必须重新取 sb._deck，否则量的是旧对象。
	var tp_deck: Control = tp.get("_deck")
	if int(tp_deck.page_count) >= 3:
		tp_deck.go(2, true)
		var before_cur := int(tp_deck.current)
		_check(before_cur == 2, "应能把称号切到第 3 组（实为 %d）" % before_cur)
		tp._refresh(true)
		tp_deck = tp.get("_deck")
		_check(int(tp_deck.current) == 2,
			"佩戴/领取后应留在当前组（#10：以前总是回默认组，实为 %d）" % int(tp_deck.current))
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
	var ok_lv := true
	for sid in lv_refs:
		var l: Label = lv_refs[sid]
		if l == null or not l.text.begins_with("+"):
			ok_lv = false
	_check(ok_lv, "刷新后每个槽位等级都应写成 +N")
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
	# 镶嵌费必须写在界面上，且与扣费同源
	var fee_txt := " ".join(_texts(ep))
	_check(fee_txt.contains("镶嵌费") and fee_txt.contains(str(G.equip_socket_cost())),
		"界面应显示镶嵌费且数值来自 equip_socket_cost（当前 %d）" % G.equip_socket_cost())
	# 宝石 tooltip 用本地化名，不裸露内部 id
	var chip: Control = null
	for c in (ep.get("_detail") as Control).get_children():
		if c is PanelContainer and String((c as Control).tooltip_text).contains("宝石"):
			chip = c
	_check(chip != null and not String(chip.tooltip_text).contains("gem_"),
		"宝石 tooltip 应使用本地化名而不是内部 id（实为「%s」）"
		% ("" if chip == null else String(chip.tooltip_text)))
	ep.queue_free()
	await get_tree().process_frame

	if _fails == 0:
		print("UI_LAYOUT_OK all tests passed")
	else:
		print("UI_LAYOUT_FAIL fails=%d" % _fails)
