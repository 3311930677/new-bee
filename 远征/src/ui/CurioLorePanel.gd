extends Control
## Read-only navigation is separate from the two explicit reward/charge actions.
signal closed
const Reading := preload("res://src/ui/ReadingSkin.gd")
const KitV4 := preload("res://src/ui/KitV4.gd")
var _frame: PanelContainer
var _heading: Label
var _status: Label
var _scroll: ScrollContainer
var _body: VBoxContainer
var _footer: HBoxContainer
var _page := "overview"
var _history_index := 0
var _tier := "common"
var _busy := false
var _result: Dictionary = {}
var _result_parent := "overview"
var _back: Button
var _action: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("safe_layout_exempt",true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(.02,.02,.03,.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	_frame = Reading.frame()
	add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	_frame.add_child(column)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	column.add_child(head_row)
	_back = G.top_back_button(head_row, back, Vector2.ZERO, "关闭")
	_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var head_col := VBoxContainer.new()
	head_col.add_theme_constant_override("separation", 2)
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head_col)
	_heading = Reading.label("古碑鉴宝",G.FS_BIG,Reading.TEXT)
	head_col.add_child(_heading)
	_status = Reading.label("",G.FS_MD,Color("e5c98e"))
	head_col.add_child(_status)
	var paper := Reading.frame(false)
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(paper)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	paper.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation",16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation",10)
	column.add_child(_footer)
	get_viewport().size_changed.connect(layout)
	preload("res://src/ui/UiSafeArea.gd").watch(self,layout)
	navigate("overview")
	layout()

func _flags() -> Dictionary:
	return G.prog.get("flags",{})

func _history() -> Array:
	return _flags().get("curio_history",[])

func _line(words: String, px := 22) -> void:
	_body.add_child(Reading.label(words,px))

func _button(words: String, callback: Callable, primary := false) -> Button:
	var button := Reading.button(words,primary)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func navigate(page: String) -> void:
	if _busy: return
	_page = page
	_clear(_body)
	_clear(_footer)
	_action = null
	var count := int(_flags().get("curio_appraised_count",0))
	_status.text = "金币 %d · 累计鉴宝 %d 次"%[int(G.wallet.gold),count]
	_heading.text = {"overview":"古碑鉴宝","lore":"先祖古碑","appraise":"行商鉴宝","history":"鉴宝记录","record":"记录详情","result":"本次结果"}.get(page,"古碑鉴宝")
	match page:
		"overview":
			var prog_row := VBoxContainer.new()
			prog_row.add_theme_constant_override("separation", 6)
			_body.add_child(prog_row)
			prog_row.add_child(Reading.label("慧眼识珍 · " + ("已达成" if count >= 3 else "进度 %d / 3 次" % count), G.FS_MD, KitV4.GOLD))
			var pbar := KitV4.bar(Vector2(160, 12), "exp")
			pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pbar.set("ratio", clampf(float(count) / 3.0, 0.0, 1.0))
			prog_row.add_child(pbar)
			_body.add_child(_button("先祖古碑  ›", func(): navigate("lore"), true))
			_body.add_child(Reading.label("阅读当前职业碑文，参悟后获得首次共鸣奖励与职业称号。", G.FS_SM, KitV4.CREAM))
			_body.add_child(_button("行商鉴宝  ›", func(): navigate("appraise"), true))
			_body.add_child(Reading.label("鉴选蒙尘古匣与鎏金宝匣，获取宝石、材料与传世器物。", G.FS_SM, KitV4.CREAM))
			_body.add_child(_button("鉴宝记录  ›", func(): navigate("history"), false))
		"lore":
			var entry := G.lore_entry()
			var resonated := bool(_flags().get("lore_resonated_"+String(entry.role_id),false))
			_line(String(entry.heading),24)
			for line in entry.lines: _line(String(line))
			_line("已共鸣 · 可随时重温碑文" if resonated else "首次参悟：金币 +180 · 远征币 +40 · 魂晶 +25 · 荣誉 +30；称号【%s】"%entry.title_name,20)
			if not resonated:
				_action = _button("参悟古碑",resonate,true)
		"appraise":
			_line("选择匣型",24)
			var choices := HBoxContainer.new()
			choices.add_theme_constant_override("separation",8)
			_body.add_child(choices)
			for id in ["common","rare"]:
				var choice := _button(("✓ " if _tier==id else "")+("古匣" if id=="common" else "宝匣"),_select_tier.bind(id))
				choices.add_child(choice)
			_line("单次费用：%d 金币"%cost(),24)
			_line("古匣可鉴出宝石、辅助材料及器物。宝匣包含更高阶的宝石、养成材料，有1%概率鉴出史诗装备；古匣器物概率为0.2%。")
			_line("每日最多鉴定5次，两次间隔60秒。结果自动入包，满包进入待领取。",20)
			_action = _button("确认鉴定 · %d 金币"%cost(),appraise,true)
			_action.disabled = int(G.wallet.gold)<cost()
			if _action.disabled:_line("金币不足，还差 %d。"%(cost()-int(G.wallet.gold)),20)
		"history":
			if _history().is_empty():_line("暂无鉴宝记录。")
			for i in _history().size():
				var entry := _button("%02d  %s  ›"%[i+1,String(_history()[i]).get_slice("→",0)],_open_record.bind(i))
				entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_body.add_child(entry)
		"record":
			if _history_index < _history().size(): _line(String(_history()[_history_index]))
		"result":
			for line in _result.get("lines",[]): _line(String(line))
	_back.tooltip_text = "关闭" if page=="overview" else "确认" if page=="result" else "返回"
	if _action!=null:
		_footer.add_child(_action)
		_footer.visible = true
	else:
		_footer.visible = false
	_scroll.scroll_vertical = 0
	layout.call_deferred()
	_focus_back.call_deferred()

func _focus_back() -> void:
	if is_instance_valid(_back) and _back.is_inside_tree():_back.grab_focus()

func cost() -> int:
	return 680 if _tier=="rare" else 260

func _select_tier(tier: String) -> void:
	_tier = tier
	navigate("appraise")

func _open_record(index: int) -> void:
	_history_index = index
	navigate("record")

func resonate() -> void:
	if _busy or _page!="lore":return
	if bool(_flags().get("lore_resonated_"+String(G.lore_entry().role_id),false)):return
	_busy = true
	var result := G.lore_resonate()
	_result = {"lines":[String(result.heading),"\n\n".join(result.lines),"首次共鸣奖励已入包 · 获得称号【%s】"%result.title_name]}
	_result_parent = "lore"
	_busy = false
	navigate("result")
	Audio.sfx("reward")

func appraise() -> void:
	if _busy or _page!="appraise":return
	_busy = true
	var result := G.curio_appraise(_tier)
	_result = {"lines":[String(result.get("curio_name","鉴宝未完成")),String(result.get("reward_desc",result.get("err","")))]}
	if result.get("unlocked_title",false): _result.lines.append("获得称号【慧眼识珍】")
	_result_parent = "appraise"
	_busy = false
	navigate("result")
	Audio.sfx("reward" if result.get("ok",false) else "ui_locked")

func back() -> void:
	if _busy:return
	match _page:
		"overview":closed.emit()
		"record":navigate("history")
		"result":navigate(_result_parent)
		_:navigate("overview")

func layout() -> void:
	if _frame==null:return
	var safe := G.ui_safe_rect(self)
	var extent := Vector2(minf(560,safe.size.x-24),maxf(260,safe.size.y-24))
	_frame.position = (safe.get_center()-extent*.5).round()
	_frame.size = extent
	_body.custom_minimum_size.x = maxf(100,extent.x-88)

func _input(event: InputEvent) -> void:
	if G.ui_blocked: return
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()
