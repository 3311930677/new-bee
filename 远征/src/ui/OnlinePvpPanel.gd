extends Control
## L5 演武场（1v1 / 2v2 / 3v3 好友切磋、随机补位排位、六角色可读战局与战局回放）。

signal closed
signal action_requested(kind: String, payload: Dictionary)

var _status: Label
var _list: VBoxContainer
var _tab := "arena"
var _tab_btns: Dictionary = {}
var _mode := "1v1"
var _allow_fill := true
var _overview: Dictionary = {}
var _replay: Dictionary = {}
var _selected_target_uid := 0
var _replay_step := 0
var _busy := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	G.veil(self, 0.96, true)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(G.gold_label("昭元演武场（切磋与排位）", G.FS_BIG))
	_status = G.gold_label("正在同步竞技场段位与战局……", G.FS_SM, false)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for entry in [["arena", "演武"], ["match", "战局"], ["replay", "回放"], ["season", "赛季榜"]]:
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
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	col.add_child(footer)
	_btn(footer, "刷新演武", func() -> void: action_requested.emit("refresh", {"mode": _mode}))
	_btn(footer, "离开演武场", func() -> void: closed.emit())
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


func _bar(parent: Control, cur_v: int, max_v: int, fill_col: Color, h := 9) -> void:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = h
	bar.max_value = maxi(1, max_v)
	bar.value = clampi(cur_v, 0, maxi(1, max_v))
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = G.BG_DEEP
	track.border_color = Color("6e5a3a", 0.7)
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)


func _role_name(id: String) -> String:
	return String({"zs": "破军", "ck": "穿杨", "fs": "霜语", "fz": "晨星"}.get(id, id))


func _status_name(st: String) -> String:
	return String({"ready": "备战就绪", "active": "激战中", "completed": "已完结", "queued": "匹配中", "aborted": "已中止"}.get(st, st))


func _side_name(s: String) -> String:
	return String({"ally": "蓝方阵", "enemy": "红方阵", "draw": "平局"}.get(s, s))


func _kind_name(k: String) -> String:
	return "切磋" if k == "sparring" else ("排位" if k == "ranked" else k)


func _reason_name(r: String) -> String:
	return String({"ko": "击败对手", "knockout": "击倒致胜", "forfeit": "认输结算", "forfeited": "已认输", "aborted_before_start": "开局前取消", "timeout": "计时结算", "draw": "平局", "attacked": "命中", "cast": "施放技能", "used": "使用药剂", "timeout_default": "超时兜底", "focused": "切换集火", "ok": "确认"}.get(r, r))


func _act_name(a: String) -> String:
	return String({"attack": "普攻", "skill": "技能", "potion": "喝药", "focus": "集火", "defend": "防御", "forfeit": "认输", "auto_basic": "自动普攻", "auto_defend": "自动防御"}.get(a, a))


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


func selected_mode() -> String:
	return _mode


func apply_state(overview: Dictionary, replay_data: Dictionary = {}) -> void:
	_overview = overview
	if not replay_data.is_empty():
		_replay = replay_data
		var ins: Array = _replay.get("inputs", []) if _replay.get("inputs") is Array else []
		_replay_step = ins.size()
	_rebuild()


func _btn(parent: Control, label_text: String, cb: Callable) -> Control:
	var b := G.ghost_button(label_text, 0, 40, G.FS_SM)
	b.custom_minimum_size.y = 40
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if _busy:
			return
		if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed) or ev.is_action_pressed("ui_accept"):
			b.accept_event()
			cb.call())
	parent.add_child(b)
	return b


func _card(title: String, body_lines: Array[String], border_col := Color(0.76, 0.63, 0.34, 0.65)) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.08, 0.92)
	style.border_color = border_col
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	_list.add_child(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
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
	for ch in _list.get_children():
		ch.queue_free()
	match _tab:
		"arena":
			_build_arena()
		"match":
			_build_match()
		"replay":
			_build_replay()
		"season":
			_build_season()


func _build_arena() -> void:
	var ratings: Dictionary = _overview.get("ratings", {}) if _overview.get("ratings") is Dictionary else {}
	var rlines: Array[String] = [String(_overview.get("rules_summary", ""))]
	for m in ["1v1", "2v2", "3v3"]:
		var r: Dictionary = ratings.get(m, {}) if ratings.get(m) is Dictionary else {}
		rlines.append("%s 独立段位：%s · %d分 (%d胜/%d负/%d平)%s" % [
			m, String(r.get("tier_name", "青铜演武")), int(r.get("rating", 1000)),
			int(r.get("wins", 0)), int(r.get("losses", 0)), int(r.get("draws", 0)),
			" [当前]" if m == _mode else ""
		])
	var mbox := _card("人数模式与独立排位分", rlines)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 6)
	mbox.add_child(mrow)
	for m in ["1v1", "2v2", "3v3"]:
		var mk := String(m)
		_set_btn_active(_btn(mrow, ("✓ " + mk) if mk == _mode else mk, func() -> void:
			_mode = mk
			action_requested.emit("refresh", {"mode": _mode})), mk == _mode)

	var q_v: Variant = _overview.get("queue")
	if q_v is Dictionary and not (q_v as Dictionary).is_empty():
		var q := q_v as Dictionary
		var qbox := _card("排位匹配中 (%s)" % String(q.get("mode", _mode)), [
			"随机补位：%s · 状态：%s" % ["开启" if bool(q.get("allow_random_fill", false)) else "关闭", _status_name(String(q.get("status", "")))],
		])
		_btn(qbox, "取消匹配", func() -> void: action_requested.emit("queue_leave", {}))
	else:
		var qbox := _card("排位队列（%s 预组或补位）" % _mode, [
			"补齐人数后自动入场；好友掉线受补位保护。",
		])
		var qrow := HBoxContainer.new()
		qrow.add_theme_constant_override("separation", 6)
		qbox.add_child(qrow)
		_set_btn_active(_btn(qrow, "补位:%s" % ("开" if _allow_fill else "关"), func() -> void:
			_allow_fill = not _allow_fill
			_rebuild()), _allow_fill)
		_btn(qrow, "加入 %s 排位" % _mode, func() -> void:
			action_requested.emit("queue_join", {"mode": _mode, "allow_random_fill": _allow_fill}))

	var active_v: Variant = _overview.get("active_match")
	if active_v is Dictionary and not (active_v as Dictionary).is_empty():
		var abox := _card("当前有进行中对局", ["状态：%s · 请切换至「战局」页操作。" % _status_name(String((active_v as Dictionary).get("status", "")))])
		_btn(abox, "进入战局", func() -> void:
			_tab = "match"
			_rebuild())

	var chs: Array = _overview.get("challenges", []) if _overview.get("challenges") is Array else []
	for cv in chs:
		if not cv is Dictionary:
			continue
		var ch := cv as Dictionary
		var cid := String(ch.get("id", ""))
		var cbox := _card("好友切磋邀请 · %s" % String(ch.get("mode", "1v1")), [
			"%s 对阵 %s（切磋不扣分、不掉装备）" % [String(ch.get("challenger_name", "")), String(ch.get("target_name", ""))],
		])
		if String(ch.get("direction", "")) == "incoming":
			var crow := HBoxContainer.new()
			crow.add_theme_constant_override("separation", 6)
			cbox.add_child(crow)
			_btn(crow, "应战(%s)" % String(ch.get("mode", "")), func() -> void:
				action_requested.emit("challenge_respond", {"id": cid, "accept": true}))
			_btn(crow, "谢绝", func() -> void:
				action_requested.emit("challenge_respond", {"id": cid, "accept": false}))

	var friends: Array = _overview.get("friends", []) if _overview.get("friends") is Array else []
	if friends.is_empty():
		_card("好友切磋", ["暂无好友；可在「社交」添加好友后发起不计分 %s 切磋。" % _mode])
	else:
		var fbox := _card("向好友发起 %s 切磋（不计段位）" % _mode, [])
		for fv in friends:
			if not fv is Dictionary:
				continue
			var f := fv as Dictionary
			var fid := String(f.get("character_id", ""))
			_btn(fbox, "邀战 %s (Lv.%d)" % [String(f.get("nickname", "")), int(f.get("level", 1))], func() -> void:
				action_requested.emit("challenge_send", {"mode": _mode, "target_character_id": fid}))


func _build_match() -> void:
	var mv: Variant = _overview.get("active_match")
	if not (mv is Dictionary) or (mv as Dictionary).is_empty():
		_card("暂无进行中战局", ["请先在「演武」匹配排位或应战好友切磋；已完成战局可在「回放」查看。"])
		return
	var m := mv as Dictionary
	var mid := String(m.get("id", ""))
	var st := String(m.get("status", "ready"))
	var my_side := String(m.get("my_side", "ally"))
	var seq := int(m.get("confirmed_sequence", 0)) + 1
	var tick := int(m.get("battle_tick", 0))
	var last_act := int(m.get("last_action_tick", 0))
	var tout := int(m.get("turn_timeout_ticks", 450))
	var remain_sec := maxf(0.0, float(tout - (tick - last_act)) / 30.0)

	var head := _card("%s %s · 状态：%s · 时长 %.1f 秒" % [
		String(m.get("mode", "1v1")),
		"好友切磋" if String(m.get("match_kind", "")) == "sparring" else "排位赛",
		_status_name(st), float(tick) / 30.0,
	], [
		"本方阵营：%s · 操作倒计时：%.1f 秒（超时将执行自动普攻/防御兜底，已触发 %d 次）" % [
			"蓝方阵" if my_side == "ally" else "红方阵", remain_sec, int(m.get("timeout_defaults_applied", 0)),
		],
	])
	if st == "ready":
		var rrow := HBoxContainer.new()
		rrow.add_theme_constant_override("separation", 6)
		head.add_child(rrow)
		_set_btn_active(_btn(rrow, "确认入场就绪", func() -> void: action_requested.emit("match_ready", {"match_id": mid, "ready": true})), true)
		_btn(rrow, "取消退场", func() -> void: action_requested.emit("match_forfeit", {"match_id": mid}))
		return

	# Mobile-readable 6-character formation view: Opponent side row + Ally side row, pets summarized compactly
	var snap: Dictionary = m.get("battle_snapshot", {}) if m.get("battle_snapshot") is Dictionary else {}
	var units: Array = snap.get("units", []) if snap.get("units") is Array else []
	var opp_side := "enemy" if my_side == "ally" else "ally"
	var pets_by_owner: Dictionary = {}
	var opp_roles: Array[Dictionary] = []
	var ally_roles: Array[Dictionary] = []
	for uv in units:
		if not uv is Dictionary:
			continue
		var u := uv as Dictionary
		if String(u.get("kind", "")) == "pet":
			pets_by_owner[int(u.get("owner_uid", 0))] = u
		elif String(u.get("kind", "")) == "role":
			if String(u.get("side", "")) == opp_side:
				opp_roles.append(u)
			else:
				ally_roles.append(u)

	_render_team_band("对手阵容（点击下方按钮选为集火目标）", opp_roles, pets_by_owner, true, mid, seq)
	_render_team_band("我方阵容（最多 3 人 · 附带随行伙伴）", ally_roles, pets_by_owner, false, mid, seq)

	var act_box := _card("演武指令", [])
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 6)
	act_box.add_child(r1)
	_set_btn_active(_btn(r1, "普攻", func() -> void: action_requested.emit("match_cmd", {"match_id": mid, "sequence": seq, "action": "attack", "target_uid": _selected_target_uid})), true)
	_btn(r1, "技能一", func() -> void: action_requested.emit("match_cmd", {"match_id": mid, "sequence": seq, "action": "skill", "skill_id": "s1", "target_uid": _selected_target_uid}))
	_btn(r1, "喝药", func() -> void: action_requested.emit("match_cmd", {"match_id": mid, "sequence": seq, "action": "potion"}))
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	act_box.add_child(r2)
	_btn(r2, "推进战局", func() -> void: action_requested.emit("match_tick", {"match_id": mid, "advance_ticks": 60}))
	_btn(r2, "模拟断线重连", func() -> void: action_requested.emit("match_reconnect_cycle", {"match_id": mid}))
	_btn(r2, "认输", func() -> void: action_requested.emit("match_forfeit", {"match_id": mid}))


func _render_team_band(title: String, roles: Array[Dictionary], pets_by_owner: Dictionary, selectable: bool, mid: String, seq: int) -> void:
	var border_col := Color("cf5648", 0.85) if selectable else Color("4b94d4", 0.85)
	var box := _card(title, [], border_col)
	var hp_col := Color("cc4438") if selectable else Color("3fa876")
	for u in roles:
		var uid := int(u.get("uid", 0))
		var pet_note := ""
		if pets_by_owner.has(uid):
			var p: Dictionary = pets_by_owner[uid]
			pet_note = " · 宠:%s" % String(p.get("name", "岩龟"))
		var focused := selectable and _selected_target_uid == uid
		var mark := "★集火 " if focused else ""
		var alive := bool(u.get("alive", true))
		var lbl_col := G.GOLD_BRIGHT if focused else (Color("8f8376") if not alive else (Color("f0b4a8") if selectable else Color("a8d8f0")))
		var lbl := G.gold_label("%s%s · 气血 %d/%d · 能量 %d · %s%s" % [
			mark, String(u.get("name", "")), int(u.get("hp", 0)), int(u.get("max_hp", 0)),
			int(u.get("energy", 0)), ("已阵亡" if not alive else "存活"), pet_note,
		], G.FS_SM, false, lbl_col)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(lbl)
		_bar(box, int(u.get("hp", 0)), int(u.get("max_hp", 1)), hp_col, 9)
		_bar(box, clampi(int(u.get("energy", 0)), 0, 100), 100, Color("4b8fd4"), 5)
	if selectable and not roles.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		for u in roles:
			if not bool(u.get("alive", true)):
				continue
			var uid := int(u.get("uid", 0))
			var is_sel := _selected_target_uid == uid
			var btn := _btn(row, ("%s:%s" % ["★已锁" if is_sel else "锁定", String(u.get("name", "")).left(4)]), func() -> void:
				_selected_target_uid = uid
				action_requested.emit("match_cmd", {"match_id": mid, "sequence": seq, "action": "focus", "target_uid": uid}))
			_set_btn_active(btn, is_sel)


func _build_replay() -> void:
	if not _replay.is_empty():
		var ins: Array = _replay.get("inputs", []) if _replay.get("inputs") is Array else []
		_replay_step = clampi(_replay_step, 0, ins.size())
		var lines: Array[String] = [
			"模式：%s（%s）· 胜方：%s（%s）" % [
				String(_replay.get("mode", "")), _kind_name(String(_replay.get("match_kind", ""))),
				_side_name(String(_replay.get("winner_side", ""))), _reason_name(String(_replay.get("result_reason", ""))),
			],
			"重演校验：%s · 状态摘要 %s" % [
				"通过" if bool(_replay.get("replay_verified", false)) else "异常",
				String(_replay.get("replayed_hash", "")).left(12),
			],
			"已展示指令进度：%d / %d" % [_replay_step, ins.size()],
		]
		for i in range(maxi(0, _replay_step - 4), _replay_step):
			var ev := ins[i] as Dictionary
			var act: Dictionary = ev.get("action", {}) if ev.get("action") is Dictionary else {}
			lines.append("#%d %.1fs %s（%s）" % [
				int(ev.get("sequence", i + 1)), float(ev.get("tick", 0)) / 30.0,
				_act_name(String(act.get("action", ""))), _reason_name(String(ev.get("reason", ""))),
			])
		var rbox := _card("权威战局回放器", lines)
		var ctrl := HBoxContainer.new()
		ctrl.add_theme_constant_override("separation", 6)
		rbox.add_child(ctrl)
		_btn(ctrl, "上一步", func() -> void:
			_replay_step = maxi(0, _replay_step - 1)
			_rebuild())
		_btn(ctrl, "下一步", func() -> void:
			_replay_step = mini(ins.size(), _replay_step + 1)
			_rebuild())
		_btn(ctrl, "关闭回放", func() -> void:
			_replay = {}
			_rebuild())

	var recs: Array = _overview.get("recent_matches", []) if _overview.get("recent_matches") is Array else []
	if recs.is_empty():
		_card("最近演武记录", ["完成任意 1v1 / 2v2 / 3v3 对局后，可在此拉取服务端不可篡改操作序列进行逐帧回放核验。"])
		return
	for rv in recs:
		if not rv is Dictionary:
			continue
		var r := rv as Dictionary
		var mid := String(r.get("id", ""))
		var box := _card("%s %s · %s" % [
			String(r.get("mode", "")),
			"切磋" if String(r.get("match_kind", "")) == "sparring" else "排位",
			"胜利" if String(r.get("winner_side", "")) == String(r.get("my_side", "")) else ("平局" if String(r.get("winner_side", "")) == "draw" else "惜败"),
		], [
			"段位分：%s%d · 荣誉 +%d · 时长 %.1f 秒" % [
				"+" if int(r.get("rating_delta", 0)) >= 0 else "",
				int(r.get("rating_delta", 0)),
				int(r.get("honor_delta", 0)),
				float(r.get("battle_tick", 0)) / 30.0,
			],
		])
		_btn(box, "查看权威回放", func() -> void: action_requested.emit("replay", {"match_id": mid}))


func _build_season() -> void:
	var season: Dictionary = _overview.get("season", {}) if _overview.get("season") is Dictionary else {}
	var claimed := bool(season.get("claimed", false))
	var sbox := _card("%s（%s）" % [String(season.get("name", "第一赛季")), String(season.get("id", "S1"))], [
		"荣誉点：%d · 本周荣誉上限：%d / %d" % [
			int(_overview.get("honor_balance", 0)),
			int(_overview.get("weekly_honor", 0)),
			int(_overview.get("weekly_honor_cap", 300)),
		],
		"奖励为非顶级战力荣誉材料及外观称号框；非竞技玩家不影响剧情与养成。",
	])
	if not claimed:
		_btn(sbox, "领取当前赛季段位奖励", func() -> void: action_requested.emit("season_claim", {}))

	var shop: Array = _overview.get("honor_shop", []) if _overview.get("honor_shop") is Array else []
	if not shop.is_empty():
		var shbox := _card("演武荣誉兑换（非顶级数值材料）", [])
		for sv in shop:
			if not sv is Dictionary:
				continue
			var it := sv as Dictionary
			var iid := String(it.get("item_id", ""))
			_btn(shbox, "兑换 %s（%d 荣誉）" % [String(it.get("label", iid)), int(it.get("price_honor", 0))], func() -> void:
				action_requested.emit("honor_buy", {"item_id": iid}))

	var lb: Array = _overview.get("leaderboard", []) if _overview.get("leaderboard") is Array else []
	var lb_mode := String(_overview.get("leaderboard_mode", _mode))
	var lblines: Array[String] = ["当前榜模式：%s" % lb_mode]
	for rowv in lb:
		if not rowv is Dictionary:
			continue
		var r := rowv as Dictionary
		lblines.append("#%d %s（%s）· %s %d分 (%d胜)" % [
			int(r.get("rank", 0)), String(r.get("nickname", "")), _role_name(String(r.get("role_id", ""))),
			String(r.get("tier_name", "")), int(r.get("rating", 1000)), int(r.get("wins", 0)),
		])
	var lbox := _card("独立模式排位榜单", lblines)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 6)
	lbox.add_child(lrow)
	for m in ["1v1", "2v2", "3v3"]:
		var mk := String(m)
		_set_btn_active(_btn(lrow, "%s榜" % mk, func() -> void:
			_mode = mk
			action_requested.emit("refresh", {"mode": mk})), mk == lb_mode)
