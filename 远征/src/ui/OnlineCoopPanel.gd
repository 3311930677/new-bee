extends Control
## 2-4 人合作副本（失声碑窟 / 退潮水闸）、个人掉落箱与枫林公共首领面板。

signal closed
signal action_requested(kind: String, payload: Dictionary)

var _status: Label
var _tab := "dungeons"
var _tab_btns: Dictionary = {}
var _overview: Dictionary = {}
var _instance: Dictionary = {}
var _world_boss: Dictionary = {}
var _self_char_id := ""
var _selected_dungeon := "stele_cavern"
var _difficulty := "standard"
var _goal := "first_clear"
var _friends_only := false
var _next_seq := 1
var _list: VBoxContainer
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	G.veil(self, 0.96, true)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.add_child(G.gold_label("合作副本与公共首领", G.FS_BIG))
	_status = G.gold_label("正在读取合作副本列表……", G.FS_SM, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for entry in [["dungeons", "集结"], ["instance", "副本"], ["drops", "掉落箱"], ["boss", "首领"]]:
		var key := String(entry[0])
		_tab_btns[key] = _btn(tabs, String(entry[1]), func() -> void:
			_tab = key
			_rebuild())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	col.add_child(footer)
	_btn(footer, "刷新状态", func() -> void: action_requested.emit("refresh", {}))
	_btn(footer, "关闭副本", func() -> void: closed.emit())
	_refresh_tabs()


func _refresh_tabs() -> void:
	for k in _tab_btns:
		_set_btn_active(_tab_btns[k] as Control, String(k) == _tab)


func _set_btn_active(btn: Control, active: bool) -> void:
	if not is_instance_valid(btn):
		return
	btn.set_meta("primary_action", active)
	var lbl := btn.get_child(0) as Label
	if lbl != null:
		lbl.add_theme_color_override("font_color", G.GOLD_BRIGHT if active else Color("d8c8a8"))
	btn.queue_redraw()


func _hp_bar(parent: Control, cur_val: int, max_val: int, fill_col: Color, h := 10) -> void:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = h
	bar.max_value = maxi(1, max_val)
	bar.value = clampi(cur_val, 0, maxi(1, max_val))
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = G.BG_DEEP
	track.border_color = Color("6e5a3a", 0.75)
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)


func _role_name(id: String) -> String:
	return String({"zs": "破军", "ck": "穿杨", "fs": "霜语", "fz": "晨星"}.get(id, id))


func _status_name(st: String) -> String:
	return String({"ready": "等待就绪", "active": "进行中", "completed": "已通关", "retreated": "已撤退", "idle": "备战中", "online": "在线", "offline": "离线", "disconnected": "断线护防", "scheduled": "预告中", "defeated": "已讨伐", "closed": "已结束"}.get(st, st))


func _map_name(mid: String) -> String:
	return String({"lorin_wilds": "昭元边城", "maple_road": "枫林古道", "shenyuan_port": "沉渊港"}.get(mid, mid))


func _tier_name(t: String) -> String:
	return String({"none": "未达标", "basic": "基础赏", "bronze": "基础赏", "silver": "精锐赏", "elite": "精锐赏", "gold": "首功赏", "mvp": "首功赏", "full": "全额赏", "assist": "协战赏", "stage": "阶段赏", "defeat": "讨伐赏"}.get(t, t))


func _dungeon_name(did: String) -> String:
	return String({"stele_cavern": "失声碑窟", "tidal_gate": "退潮水闸", "ore_vein": "赤砂矿脉", "abyss_core": "界碑深处"}.get(did, did))


func _diff_name(d: String) -> String:
	return "普通" if d == "standard" else "困难"


func _goal_name(g: String) -> String:
	return "首通" if g == "first_clear" else ("素材" if g == "materials" else "助战")


func _unhandled_input(event: InputEvent) -> void:
	if visible and not G.ui_blocked and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func set_busy(flag: bool) -> void:
	_busy = flag


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func set_tab(tab_id: String) -> void:
	_tab = tab_id
	_rebuild()


func apply_state(overview: Dictionary, instance_data: Dictionary, world_boss: Dictionary, self_char_id: String) -> void:
	_overview = overview
	_instance = instance_data
	_world_boss = world_boss
	_self_char_id = self_char_id
	if not _instance.is_empty():
		var snap: Variant = _instance.get("battle_snapshot")
		if snap is Dictionary:
			_next_seq = int((_instance.get("battle_confirmed_seq", 0))) + 1
	_rebuild()


func _btn(parent: Control, label_text: String, cb: Callable) -> Control:
	var b := G.ghost_button(label_text, 0, 44, G.FS_SM)
	b.custom_minimum_size.y = 44
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if _busy:
			return
		if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed) or ev.is_action_pressed("ui_accept"):
			b.accept_event()
			cb.call())
	parent.add_child(b)
	return b


func _card(title: String, body_lines: Array[String]) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.08, 0.92)
	style.border_color = Color(0.76, 0.63, 0.34, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	_list.add_child(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	if not title.is_empty():
		var head := G.gold_label(title, G.FS_MD)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(head)
	for line in body_lines:
		if line.is_empty():
			continue
		var lbl := G.gold_label(line, G.FS_SM, false)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(lbl)
	return box


func _rebuild() -> void:
	_refresh_tabs()
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	match _tab:
		"dungeons":
			_build_dungeons()
		"instance":
			_build_instance()
		"drops":
			_build_drops()
		"boss":
			_build_world_boss()


func _build_dungeons() -> void:
	var q: Dictionary = _overview.get("queue", {})
	if String(q.get("status", "")) == "queued":
		var q_box := _card("正在寻找队友：%s" % _dungeon_name(String(q.get("dungeon_id", ""))), [
			"难度：%s  目标：%s" % [_diff_name(String(q.get("difficulty", ""))), _goal_name(String(q.get("goal", "")))],
			"已加入公开匹配队列，凑齐2-4名兼容旅人后自动生成副本实例。",
		])
		_btn(q_box, "取消匹配", func() -> void: action_requested.emit("queue_leave", {}))
	elif String(q.get("status", "")) == "matched" and not String(q.get("matched_instance_id", "")).is_empty():
		var m_id := String(q.get("matched_instance_id", ""))
		var m_box := _card("匹配成功", ["副本实例 %s 已就绪，请切入副本准备确认。" % m_id.left(8)])
		_btn(m_box, "进入就绪实例", func() -> void:
			_tab = "instance"
			action_requested.emit("open_instance", {"instance_id": m_id}))

	var opts := _card("入队筛选（无需固定职业，四职皆可）", [
		"当前筛选：难度=%s  目标=%s  仅好友=%s" % [
			_diff_name(_difficulty),
			_goal_name(_goal),
			"是" if _friends_only else "否",
		],
	])
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 6)
	opts.add_child(r1)
	_set_btn_active(_btn(r1, "普通", func() -> void: _difficulty = "standard"; _rebuild()), _difficulty == "standard")
	_set_btn_active(_btn(r1, "困难", func() -> void: _difficulty = "heroic"; _rebuild()), _difficulty == "heroic")
	_set_btn_active(_btn(r1, "仅好友:%s" % ("开" if _friends_only else "关"), func() -> void: _friends_only = not _friends_only; _rebuild()), _friends_only)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	opts.add_child(r2)
	_set_btn_active(_btn(r2, "首通", func() -> void: _goal = "first_clear"; _rebuild()), _goal == "first_clear")
	_set_btn_active(_btn(r2, "素材", func() -> void: _goal = "materials"; _rebuild()), _goal == "materials")
	_set_btn_active(_btn(r2, "助战", func() -> void: _goal = "mentor"; _rebuild()), _goal == "mentor")

	for dv in _overview.get("dungeons", []):
		var d := dv as Dictionary
		var did := String(d.get("id", ""))
		var unlocked := bool(d.get("unlocked", false))
		var cleared := bool(d.get("first_cleared", false))
		var box := _card("%s · 推荐Lv.%d %s" % [
			String(d.get("name", did)),
			int(d.get("recommended_level", 1)),
			("（已首通）" if cleared else ("（已解锁）" if unlocked else "（未解锁）")),
		], [
			String(d.get("pet_notice", "")),
			String(d.get("potion_notice", "")),
			String(d.get("first_clear_notice", "")),
		])
		if unlocked:
			var acts := HBoxContainer.new()
			acts.add_theme_constant_override("separation", 6)
			box.add_child(acts)
			_btn(acts, "队伍开启", func() -> void:
				_selected_dungeon = did
				action_requested.emit("create_instance", {"dungeon_id": did, "difficulty": _difficulty, "goal": _goal, "allow_solo": false}))
			_btn(acts, "单人试探", func() -> void:
				_selected_dungeon = did
				action_requested.emit("create_instance", {"dungeon_id": did, "difficulty": _difficulty, "goal": _goal, "allow_solo": true}))
			_btn(acts, "匹配队列", func() -> void:
				_selected_dungeon = did
				action_requested.emit("queue_join", {"dungeon_id": did, "difficulty": _difficulty, "goal": _goal, "friends_only": _friends_only}))


func _build_instance() -> void:
	if _instance.is_empty():
		_card("尚无活跃副本实例", ["请先在「集结」页通过队伍开启、单人进入或公开匹配创建副本实例。"])
		return
	var iid := String(_instance.get("id", ""))
	var did := String(_instance.get("dungeon_id", ""))
	var st := String(_instance.get("status", ""))
	var stage_idx := int(_instance.get("stage_index", 0))
	var stage_total := int(_instance.get("stage_total", 3))
	var cp := int(_instance.get("checkpoint_stage", 0))
	var stage_v: Variant = _instance.get("current_stage", {})
	var stage: Dictionary = stage_v if stage_v is Dictionary else {}
	var head_lines: Array[String] = [
		"状态：%s · 关卡 %d/%d · 存档点 %d · 人数 %d" % [_status_name(st), mini(stage_idx + 1, stage_total), stage_total, cp + 1, int(_instance.get("member_count", 1))],
		"当前阶段：%s · %s" % [String(stage.get("name", "已通关")), String(stage.get("hint", ""))],
	]
	var room_state: Dictionary = _instance.get("room_state", {}) if _instance.get("room_state") is Dictionary else {}
	for msg in room_state.get("stage_messages", []):
		head_lines.append("· " + String(msg))
	var head_box := _card(String(_instance.get("dungeon_name", did)), head_lines)

	if st == "ready":
		var r_row := HBoxContainer.new()
		r_row.add_theme_constant_override("separation", 6)
		head_box.add_child(r_row)
		_btn(r_row, "确认准备就绪", func() -> void: action_requested.emit("instance_ready", {"instance_id": iid, "ready": true}))
		_btn(r_row, "取消准备", func() -> void: action_requested.emit("instance_ready", {"instance_id": iid, "ready": false}))

	var downed_uid := 0
	var bsnap: Dictionary = _instance.get("battle_snapshot", {}) if _instance.get("battle_snapshot") is Dictionary else {}
	var coop_m: Dictionary = bsnap.get("coop_members", {}) if bsnap.get("coop_members") is Dictionary else {}
	var m_card := _card("队员与参与状态", [])
	for mv in _instance.get("members", []):
		var m := mv as Dictionary
		var cid := String(m.get("character_id", ""))
		var cs: Dictionary = coop_m.get(cid, {}) if coop_m.get(cid) is Dictionary else {}
		var hp_txt := ""
		if not cs.is_empty():
			hp_txt = " · 气血 %d/%d" % [int(cs.get("hp", 0)), int(cs.get("max_hp", 0))]
			if bool(cs.get("downed", false)):
				hp_txt += " [倒地可救]"
				downed_uid = int(cs.get("uid", 0))
		var mlbl := G.gold_label("%s（%s）Lv.%d%s [%s%s%s]%s" % [
			String(m.get("nickname", "")),
			_role_name(String(m.get("role_id", ""))),
			int(m.get("synced_level", 1)),
			(" 导师同步" if bool(m.get("is_mentor", false)) else ""),
			_status_name(String(m.get("status", ""))),
			(" · 已准备" if bool(m.get("ready", false)) else ""),
			(" · 挂机警示" if bool(m.get("afk_warn", false)) else ""),
			hp_txt,
		], G.FS_SM, false, G.GOLD_BRIGHT if cid == _self_char_id else G.PARCHMENT)
		mlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_card.add_child(mlbl)
		if not cs.is_empty():
			_hp_bar(m_card, int(cs.get("hp", 0)), int(cs.get("max_hp", 1)), Color("3fa876"), 8)

	if st == "active":
		var skind := String(stage.get("kind", ""))
		if skind == "puzzle":
			var pbox := _card("合作房间机关（可由不同队友分别操作）", ["请按线索协作完成全部机关即可开启下一段石门。"])
			if did == "stele_cavern":
				var row1 := HBoxContainer.new()
				row1.add_theme_constant_override("separation", 6)
				pbox.add_child(row1)
				_btn(row1, "读拓片线索", func() -> void: action_requested.emit("interact", {"instance_id": iid, "mechanic_id": "echo_clue"}))
				_btn(row1, "西座:两声轻响", func() -> void: action_requested.emit("interact", {"instance_id": iid, "mechanic_id": "west_stele", "choice": "old"}))
				_btn(row1, "东座:朝向碑心", func() -> void: action_requested.emit("interact", {"instance_id": iid, "mechanic_id": "east_stele", "choice": "heart"}))
			elif did == "tidal_gate":
				var row1 := HBoxContainer.new()
				row1.add_theme_constant_override("separation", 6)
				pbox.add_child(row1)
				_btn(row1, "读港务水痕", func() -> void: action_requested.emit("interact", {"instance_id": iid, "mechanic_id": "tide_record"}))
				_btn(row1, "上闸:先泄旧渠", func() -> void: action_requested.emit("interact", {"instance_id": iid, "mechanic_id": "upper_sluice", "choice": "old"}))
				var row2 := HBoxContainer.new()
				row2.add_theme_constant_override("separation", 6)
				pbox.add_child(row2)
				_btn(row2, "栈桥:先通步道", func() -> void: action_requested.emit("interact", {"instance_id": iid, "mechanic_id": "bridge_sluice", "choice": "bridge"}))
				_btn(row2, "救回堤边货箱", func() -> void: action_requested.emit("interact", {"instance_id": iid, "mechanic_id": "cargo_rescue"}))
		elif skind in ["battle", "boss"]:
			var bstatus := String(_instance.get("battle_status", "idle"))
			if bstatus != "active":
				var sbox := _card("阶段战斗准备", ["当前阶段为 %s，确认队友在线后开启多人协同战斗。" % String(stage.get("name", ""))])
				_btn(sbox, "开启权威多人战斗", func() -> void: action_requested.emit("battle_start", {"instance_id": iid}))
			else:
				var bbox := _card("多人战况 · 用时 %.1f 秒 · %s" % [float(_instance.get("battle_tick", 0)) / 30.0, _status_name(bstatus)], [])
				for uv in bsnap.get("units", []):
					var u := uv as Dictionary
					if String(u.get("side", "")) == "enemy":
						var elbl := G.gold_label("%s · 气血 %d/%d %s" % [String(u.get("name", "")), int(u.get("hp", 0)), int(u.get("max_hp", 0)), ("（已击败）" if not bool(u.get("alive", true)) else "")], G.FS_SM, false, Color("f0b4a8"))
						elbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
						bbox.add_child(elbl)
						_hp_bar(bbox, int(u.get("hp", 0)), int(u.get("max_hp", 1)), Color("cc4438"), 12)
				var cmd1 := HBoxContainer.new()
				cmd1.add_theme_constant_override("separation", 6)
				bbox.add_child(cmd1)
				_btn(cmd1, "普攻", func() -> void: action_requested.emit("battle_cmd", {"instance_id": iid, "sequence": _next_seq, "action": "attack"}))
				_btn(cmd1, "技能", func() -> void: action_requested.emit("battle_cmd", {"instance_id": iid, "sequence": _next_seq, "action": "skill", "skill_id": "s1"}))
				_btn(cmd1, "喝药", func() -> void: action_requested.emit("battle_cmd", {"instance_id": iid, "sequence": _next_seq, "action": "potion"}))
				var cmd2 := HBoxContainer.new()
				cmd2.add_theme_constant_override("separation", 6)
				bbox.add_child(cmd2)
				_btn(cmd2, "救援队友", func() -> void: action_requested.emit("battle_cmd", {"instance_id": iid, "sequence": _next_seq, "action": "rescue", "target_uid": downed_uid}))
				_btn(cmd2, "推进战斗", func() -> void: action_requested.emit("battle_tick", {"instance_id": iid, "advance_ticks": 60}))

	if st in ["ready", "active"]:
		var exit_row := HBoxContainer.new()
		exit_row.add_theme_constant_override("separation", 6)
		head_box.add_child(exit_row)
		_btn(exit_row, "发起撤退", func() -> void: action_requested.emit("retreat", {"instance_id": iid, "vote": true}))
		_btn(exit_row, "离开副本", func() -> void: action_requested.emit("leave_instance", {"instance_id": iid}))


func _build_drops() -> void:
	var drops: Array = _overview.get("unclaimed_drops", [])
	if drops.is_empty():
		_card("个人战利品箱为空", ["通关合作副本且达成有效参与（伤害/治疗/救援/机关）后，个人战利品将发放至此；掉线超时后仍可安全补领。"])
		return
	for dv in drops:
		var d := dv as Dictionary
		var did := String(d.get("id", ""))
		var box := _card("%s x%d %s" % [
			String(d.get("item_name", d.get("item_template_id", ""))),
			int(d.get("quantity", 1)),
			("（首通）" if bool(d.get("is_first_clear", false)) else ("（助战）" if bool(d.get("is_mentor_bonus", false)) else "")),
		], [
			"金币 +%d  经验 +%d" % [int(d.get("gold_amount", 0)), int(d.get("experience_amount", 0))],
			"独立个人掉落，同队他人所得不会削减你的奖励。",
		])
		_btn(box, "领取进线上行囊", func() -> void: action_requested.emit("claim_drop", {"drop_id": did}))


func _build_world_boss() -> void:
	var bosses: Array = _world_boss.get("bosses", [])
	if bosses.is_empty() and not _world_boss.is_empty():
		bosses = [_world_boss]
	if bosses.is_empty():
		_card("地区公共首领", ["当前暂无活跃公告，请点击刷新获取最新枫林古道 / 沉渊港首领动向。"])
		return
	for bv in bosses:
		if not bv is Dictionary:
			continue
		var boss := bv as Dictionary
		var eid := String(boss.get("id", ""))
		var map_id := String(boss.get("map_id", "maple_road"))
		var objs: Array = boss.get("objectives", ["inspect_trail", "disrupt_howl"])
		var p: Dictionary = boss.get("participation", {}) if boss.get("participation") is Dictionary else {}
		var lines: Array[String] = [
			"地点：%s · 状态：%s · 第 %d 阶段" % [_map_name(map_id), _status_name(String(boss.get("state", ""))), int(boss.get("stage", 0))],
			"首领生命：%d / %d" % [int(boss.get("current_hp", 0)), int(boss.get("max_hp", 0))],
			"个人战绩：阶段目标 %d · 累计伤害 %d · 奖档：%s" % [int(p.get("objective_steps", 0)), int(p.get("damage_dealt", 0)), _tier_name(String(p.get("reward_tier", "none")))],
			"每账号每次公共首领窗口仅领一次主奖励；迟到仍可做阶段目标领取基础材料。",
		]
		var box := _card(String(boss.get("name", "公共首领")), lines)
		_hp_bar(box, int(boss.get("current_hp", 0)), int(boss.get("max_hp", 1)), Color("cc4438"), 14)
		if eid.is_empty():
			_btn(box, "切至 %s 激活事件" % _map_name(map_id), func() -> void: action_requested.emit("wb_select_map", {"map_id": map_id}))
			continue
		var obj1 := String(objs[0]) if objs.size() > 0 else "inspect_trail"
		var obj2 := String(objs[1]) if objs.size() > 1 else obj1
		var row1 := HBoxContainer.new()
		row1.add_theme_constant_override("separation", 6)
		box.add_child(row1)
		_btn(row1, "阶段目标一", func() -> void: action_requested.emit("wb_objective", {"event_id": eid, "objective_id": obj1}))
		_btn(row1, "阶段目标二", func() -> void: action_requested.emit("wb_objective", {"event_id": eid, "objective_id": obj2}))
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 6)
		box.add_child(row2)
		var engage_btn := _btn(row2, "协同讨伐(权威)", func() -> void: action_requested.emit("wb_engage", {"event_id": eid}))
		_set_btn_active(engage_btn, true)
		_btn(row2, "领取首领赏赐", func() -> void: action_requested.emit("wb_claim", {"event_id": eid}))
