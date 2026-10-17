# ArcheryPanel.gd —— 第一轮内容扩充：边城校场射艺（可交互瞄准+蓄力+风偏+移动靶射箭小游戏）
class_name ArcheryPanel
extends Control

signal closed

const UI := preload("res://src/ui/TravelChestUI.gd")
const Page := preload("res://src/ui/ChestPageUI.gd")
const Flow := preload("res://src/ui/FlowChestUI.gd")

var shell: Control
var _range: _RangeCanvas
var _mode_tabs: HBoxContainer
var _status_label: Label
var _wind_label: Label
var _log_label: Label
var _reward_label: Label
var _fire_btn: Button
var _steady_btn: Button
var _reset_btn: Button

var _cfg: Dictionary = {}
var _modes: Array = []
var _mode_idx := 0
var _arrows_left := 5
var _arrows_max := 5
var _score := 0
var _bullseyes_this_round := 0
var _wind := 0.0
var _time := 0.0
var _target_pos := Vector2(240, 148)
var _aim_pos := Vector2(240, 148)
var _charging := false
var _charge := 0.0
var _charge_dir := 1.0
var _flying := false
var _fly_t := 0.0
var _fly_from := Vector2(240, 320)
var _fly_to := Vector2(240, 148)
var _last_banner := ""
var _last_banner_t := 0.0
var _round_finished := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	_cfg = TableCache._load("res://data/archery.json")
	_modes = _cfg.get("modes", [])
	_build()
	_select_mode(0)
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	Audio.sfx("ui_close")
	closed.emit()


func _build() -> void:
	shell = Flow.Shell.new("校场射艺 · 演武靶场", 296)
	shell.closed = _close
	add_child(shell)

	_range = _RangeCanvas.new()
	_range.name = "ArcheryRangeCanvas"
	_range.panel_ref = self
	_range.mouse_filter = Control.MOUSE_FILTER_STOP
	_range.gui_input.connect(_on_range_input)
	shell.stage.add_child(_range)

	_mode_tabs = HBoxContainer.new()
	_mode_tabs.add_theme_constant_override("separation", 6)
	shell.body.add_child(_mode_tabs)
	for i in _modes.size():
		var idx: int = i
		var m: Dictionary = _modes[i]
		var tb := Flow.button(String(m.get("name", "模式")), func(): _select_mode(idx))
		tb.name = "ArcheryMode_" + String(m.get("id", str(i)))
		tb.skin = "tab"
		tb.custom_minimum_size.y = 44
		tb.caption.add_theme_font_size_override("font_size", G.FS_XS)
		_mode_tabs.add_child(tb)

	_status_label = Flow.text("", "section", UI.GOLD)
	shell.body.add_child(_status_label)

	_wind_label = Flow.text("", "caption", UI.PAPER)
	shell.body.add_child(_wind_label)

	var aim_row := HBoxContainer.new()
	aim_row.add_theme_constant_override("separation", 6)
	shell.body.add_child(aim_row)
	var left_b := Flow.button("准星左移", func(): _nudge_aim(Vector2(-18, 0)))
	left_b.custom_minimum_size.y = 44
	left_b.caption.add_theme_font_size_override("font_size", G.FS_XS)
	aim_row.add_child(left_b)
	_steady_btn = Flow.button("听风校准", _auto_compensate_wind)
	_steady_btn.name = "CompensateWindButton"
	_steady_btn.custom_minimum_size.y = 44
	_steady_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	aim_row.add_child(_steady_btn)
	var right_b := Flow.button("准星右移", func(): _nudge_aim(Vector2(18, 0)))
	right_b.custom_minimum_size.y = 44
	right_b.caption.add_theme_font_size_override("font_size", G.FS_XS)
	aim_row.add_child(right_b)

	_log_label = Flow.text("", "caption", UI.PAPER)
	shell.body.add_child(_log_label)

	_reward_label = Flow.text("", "caption", UI.AGED)
	shell.body.add_child(_reward_label)

	_reset_btn = Flow.button("重开一局", func(): _select_mode(_mode_idx))
	_reset_btn.name = "ResetArcheryButton"
	shell.footer.add_child(_reset_btn)

	_fire_btn = Flow.button("按住蓄力射箭", _on_fire_quick_press, true)
	_fire_btn.name = "FireArrowButton"
	_fire_btn.button_down.connect(_on_fire_down)
	_fire_btn.button_up.connect(_on_fire_up)
	shell.footer.add_child(_fire_btn)


func _relayout() -> void:
	if shell == null:
		return
	shell.layout()
	if _range != null:
		Page.place(_range, Vector2.ZERO, shell.stage.size)


static func ensure_archery_state(host: Object) -> Dictionary:
	if not (host.prog.get("flags") is Dictionary):
		host.prog["flags"] = {}
	var flags: Dictionary = host.prog["flags"]
	if not (flags.get("archery_state") is Dictionary):
		flags["archery_state"] = {
			"best_scores": {},
			"cleared": {},
			"first_claimed": {},
			"total_plays": 0,
			"total_bullseyes": 0,
		}
	var st: Dictionary = flags["archery_state"]
	for k in ["best_scores", "cleared", "first_claimed"]:
		if not (st.get(k) is Dictionary):
			st[k] = {}
	return st


func _current_mode() -> Dictionary:
	if _modes.is_empty():
		return {"id": "novice", "name": "初试百步", "arrows": 5, "target_speed": 48.0, "target_bob": 8.0, "wind_max": 16.0, "pass_score": 28, "master_score": 42}
	return _modes[clampi(_mode_idx, 0, _modes.size() - 1)]


func _select_mode(idx: int) -> void:
	_mode_idx = clampi(idx, 0, maxi(0, _modes.size() - 1))
	var m := _current_mode()
	_arrows_max = int(m.get("arrows", 5))
	_arrows_left = _arrows_max
	_score = 0
	_bullseyes_this_round = 0
	_round_finished = false
	_charging = false
	_charge = 0.0
	_flying = false
	_range.pins.clear()
	var w := maxf(360.0, shell.stage.size.x if shell.stage.size.x > 0 else 480.0)
	_target_pos = Vector2(w * 0.5, 146.0)
	_aim_pos = _target_pos
	_roll_wind()
	_log_label.text = "点「听风校准」瞄准，按住「蓄力射箭」在绿区松手正中红心！"
	_sync_ui()


func _roll_wind() -> void:
	var m := _current_mode()
	var wmax := float(m.get("wind_max", 16.0))
	_wind = snappedf(_rng.randf_range(-wmax, wmax), 0.5)


func _nudge_aim(delta_v: Vector2) -> void:
	if _round_finished or _flying:
		return
	var w := maxf(360.0, _range.size.x if _range.size.x > 0 else 480.0)
	_aim_pos.x = clampf(_aim_pos.x + delta_v.x, 64.0, w - 64.0)
	_aim_pos.y = clampf(_aim_pos.y + delta_v.y, 68.0, 224.0)
	_range.queue_redraw()


func _auto_compensate_wind() -> void:
	if _round_finished or _flying:
		return
	Audio.sfx("ui_click")
	# 自动将准星预偏到当前靶心逆风位，方便手机单手微调
	_aim_pos = Vector2(
		clampf(_target_pos.x - _wind * 0.65, 64.0, maxf(360.0, _range.size.x) - 64.0),
		_target_pos.y
	)
	_last_banner = "已听风校准准星"
	_last_banner_t = 1.1
	_range.queue_redraw()


func _on_range_input(event: InputEvent) -> void:
	if _round_finished or _flying:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_aim_pos.x = clampf(event.position.x, 64.0, maxf(360.0, _range.size.x) - 64.0)
		_aim_pos.y = clampf(event.position.y, 68.0, 224.0)
		_range.queue_redraw()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_aim_pos.x = clampf(event.position.x, 64.0, maxf(360.0, _range.size.x) - 64.0)
		_aim_pos.y = clampf(event.position.y, 68.0, 224.0)
		_range.queue_redraw()


func _on_fire_down() -> void:
	if _round_finished or _flying or _arrows_left <= 0:
		return
	_charging = true
	_charge = 0.15
	_charge_dir = 1.0


func _on_fire_up() -> void:
	if not _charging:
		return
	_charging = false
	_release_arrow(_charge)


func _on_fire_quick_press() -> void:
	# 支持直接点按快速满弦射出（无障碍与自动化测试友好）
	if _charging or _flying or _round_finished or _arrows_left <= 0:
		return
	_release_arrow(0.80)


func shoot_with_params(aim: Vector2, charge_power: float) -> Dictionary:
	## 供自动化测试或一键演练确定性调用
	_aim_pos = aim
	_charge = clampf(charge_power, 0.0, 1.0)
	_charging = false
	return _resolve_shot(_aim_pos, _charge, true)


func _release_arrow(power: float) -> void:
	if _arrows_left <= 0 or _round_finished:
		return
	Audio.sfx("ui_confirm")
	_flying = true
	_fly_t = 0.0
	var w := maxf(360.0, _range.size.x if _range.size.x > 0 else 480.0)
	_fly_from = Vector2(w * 0.5, 310.0)
	var drift_x := _wind * 0.65
	var drop_y := (0.80 - power) * 95.0
	_fly_to = Vector2(_aim_pos.x + drift_x, _aim_pos.y + drop_y)
	_charge = power


func _process(delta: float) -> void:
	var m := _current_mode()
	var spd := float(m.get("target_speed", 48.0))
	var bob := float(m.get("target_bob", 8.0))
	var w := maxf(360.0, _range.size.x if _range.size.x > 0 else 480.0)
	if not _round_finished:
		_time += delta
		var amp_x := minf(128.0, (w - 180.0) * 0.5)
		_target_pos.x = w * 0.5 + sin(_time * (spd / 52.0)) * amp_x
		_target_pos.y = 144.0 + cos(_time * (spd / 36.0)) * bob
	if _charging:
		_charge += delta * 1.15 * _charge_dir
		if _charge >= 1.0:
			_charge = 1.0
			_charge_dir = -1.0
		elif _charge <= 0.1:
			_charge = 0.1
			_charge_dir = 1.0
	if _flying:
		_fly_t += delta * 4.2
		if _fly_t >= 1.0:
			_flying = false
			_resolve_shot(_aim_pos, _charge, false)
	if _last_banner_t > 0.0:
		_last_banner_t = maxf(0.0, _last_banner_t - delta)
	if _range != null:
		_range.queue_redraw()


func _resolve_shot(aim: Vector2, power: float, instant: bool) -> Dictionary:
	var drift_x := _wind * 0.65
	var drop_y := (0.80 - power) * 95.0
	var impact := Vector2(aim.x + drift_x, aim.y + drop_y) if instant else _fly_to
	var offset := impact - _target_pos
	var dist := offset.length()
	var rings := 0
	var comment := "脱靶偏失"
	if dist <= 13.0:
		rings = 10
		comment = "正中红心 · 百步穿杨！"
		_bullseyes_this_round += 1
	elif dist <= 25.0:
		rings = 8
		comment = "劲矢贯靶 · 8环！"
	elif dist <= 38.0:
		rings = 6
		comment = "稳中内圈 · 6环"
	elif dist <= 51.0:
		rings = 4
		comment = "擦中靶盘 · 4环"
	elif dist <= 65.0:
		rings = 2
		comment = "掠过外环 · 2环"
	_arrows_left = maxi(0, _arrows_left - 1)
	_score += rings
	_range.pins.append({"offset": offset, "rings": rings})
	var shot_no := _arrows_max - _arrows_left
	_last_banner = "第%d箭：%d环（%s）" % [shot_no, rings, comment]
	_last_banner_t = 2.0
	_log_label.text = _last_banner
	if _arrows_left <= 0:
		_finish_round()
	else:
		_roll_wind()
		_sync_ui()
	return {"rings": rings, "dist": dist, "score": _score, "arrows_left": _arrows_left}


func _finish_round() -> void:
	_round_finished = true
	var m := _current_mode()
	var mid := String(m.get("id", "novice"))
	var pass_sc := int(m.get("pass_score", 28))
	var master_sc := int(m.get("master_score", 42))
	var st := ensure_archery_state(G)
	st["total_plays"] = int(st.get("total_plays", 0)) + 1
	st["total_bullseyes"] = int(st.get("total_bullseyes", 0)) + _bullseyes_this_round
	var best_map: Dictionary = st["best_scores"]
	var old_best := int(best_map.get(mid, 0))
	if _score > old_best:
		best_map[mid] = _score
	var passed := _score >= pass_sc
	var mastered := _score >= master_sc
	var reward_parts: Array[String] = []
	if passed:
		st["cleared"][mid] = true
		var first_map: Dictionary = st["first_claimed"]
		var is_first := not bool(first_map.get(mid, false))
		var rcfg: Dictionary = m.get("first_reward" if is_first else "repeat_reward", {})
		if is_first:
			first_map[mid] = true
		var gold := int(rcfg.get("gold", 0))
		var exp_coin := int(rcfg.get("expedition", 0))
		var soul := int(rcfg.get("soul", 0))
		var honor := int(rcfg.get("honor", 0))
		if gold > 0 or exp_coin > 0 or soul > 0 or honor > 0:
			G.deposit(gold, exp_coin, soul, honor)
			if gold > 0: reward_parts.append("金币+%d" % gold)
			if exp_coin > 0: reward_parts.append("远征币+%d" % exp_coin)
			if soul > 0: reward_parts.append("魂晶+%d" % soul)
			if honor > 0: reward_parts.append("荣誉+%d" % honor)
		var items_dict: Dictionary = rcfg.get("items", {})
		for iid in items_dict:
			var cnt := int(items_dict[iid])
			if cnt > 0:
				G.grant_item(String(iid), cnt)
				reward_parts.append("%s×%d" % [G.item_name(String(iid)), cnt])
		var title_id := String(rcfg.get("title", ""))
		if not title_id.is_empty() and mastered:
			var titles_st: Dictionary = G.prog.get("titles", {"owned": [], "active": ""})
			var owned: Array = titles_st.get("owned", [])
			if not owned.has(title_id):
				owned.append(title_id)
				titles_st["owned"] = owned
				G.prog["titles"] = titles_st
				reward_parts.append("解锁称号【百步穿杨】")
		# 触发支线/委托事件联动
		G.side_report("archery", mid, "lorin_wilds", false)
		G.save_game()
		var rank_tag := "【神射魁首】" if mastered else "【演武达标】"
		_log_label.text = "%s 总分 %d 环！获赏：%s" % [rank_tag, _score, " · ".join(reward_parts)]
	else:
		G.save_game()
		_log_label.text = "本局总分 %d 环（达标需 %d 环），调整风偏与绿区蓄力再试一次！" % [_score, pass_sc]
	_sync_ui()


func _sync_ui() -> void:
	var m := _current_mode()
	var mid := String(m.get("id", "novice"))
	var st := ensure_archery_state(G)
	var best := int(st["best_scores"].get(mid, 0))
	var pass_sc := int(m.get("pass_score", 28))
	var master_sc := int(m.get("master_score", 42))
	for i in _mode_tabs.get_child_count():
		var b: Button = _mode_tabs.get_child(i)
		b.selected = i == _mode_idx
		b.queue_redraw()
	_status_label.text = "%s ｜ 箭囊：%d/%d ｜ 当前得分：%d环（最高 %d环）" % [
		String(m.get("name", "初试百步")), _arrows_left, _arrows_max, _score, best
	]
	var wind_dir := "东风(左偏)" if _wind < -0.5 else ("西风(右偏)" if _wind > 0.5 else "无风")
	_wind_label.text = "当前风势：%s %.1f ｜ 达标：%d环 · 魁首：%d环" % [wind_dir, absf(_wind), pass_sc, master_sc]
	var first_done := bool(st["first_claimed"].get(mid, false))
	_reward_label.text = "本档状态：%s" % ("首通重赏已领（重开可刷荣誉与铜钱）" if first_done else "首通可获强化石/精炼石与丰厚荣誉")
	_fire_btn.disabled = _round_finished or _arrows_left <= 0


class _RangeCanvas extends Control:
	var panel_ref: ArcheryPanel
	var pins: Array = []

	func _draw() -> void:
		if panel_ref == null:
			return
		var w := size.x
		var h := size.y
		# 1. 暮色天穹与远山剪影
		draw_rect(Rect2(0, 0, w, h), Color("111b2c"))
		draw_rect(Rect2(0, h * 0.52, w, h * 0.48), Color("1f2b1e"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, h * 0.54), Vector2(w * 0.22, h * 0.34), Vector2(w * 0.46, h * 0.48),
			Vector2(w * 0.74, h * 0.30), Vector2(w, h * 0.46), Vector2(w, h * 0.56), Vector2(0, h * 0.56)
		]), Color("182436"))
		# 2. 校场木栏与草坪标线
		draw_rect(Rect2(0, h * 0.54, w, 8), Color("4a321f"))
		for x_step in range(24, int(w), 56):
			draw_rect(Rect2(x_step, h * 0.48, 6, 22), Color("62432a"))
		# 3. 风向旌旗（左上角）
		var wind := panel_ref._wind
		var pole := Vector2(42, 48)
		draw_line(pole, pole + Vector2(0, 56), Color("c9a45c"), 3.0)
		var flag_len := clampf(wind * 0.9, -46.0, 46.0)
		if absf(flag_len) < 8.0:
			flag_len = 8.0
		draw_colored_polygon(PackedVector2Array([
			pole + Vector2(0, 4),
			pole + Vector2(flag_len, 12),
			pole + Vector2(0, 22)
		]), Color("e05a47") if absf(wind) > 25.0 else Color("f2c76a"))

		# 4. 移动同心圆箭靶
		var tp := panel_ref._target_pos
		# 木靶脚架
		draw_line(tp + Vector2(-24, 42), tp + Vector2(-38, 84), Color("5c3d24"), 5.0)
		draw_line(tp + Vector2(24, 42), tp + Vector2(38, 84), Color("5c3d24"), 5.0)
		draw_line(tp + Vector2(0, 44), tp + Vector2(0, 86), Color("472e1a"), 4.0)
		# 靶盘阴影与五色同心环
		draw_circle(tp + Vector2(0, 62), 36.0, Color(0, 0, 0, 0.35))
		draw_circle(tp, 64.0, Color("6e4b2a"))
		draw_circle(tp, 60.0, Color("efe3c8")) # 2环
		draw_circle(tp, 48.0, Color("262930")) # 4环
		draw_circle(tp, 36.0, Color("2f6fa3")) # 6环
		draw_circle(tp, 24.0, Color("c84232")) # 8环
		draw_circle(tp, 12.0, Color("f5c84c")) # 10环靶心
		draw_circle(tp, 3.0, Color("5a1810"))

		# 已命中的箭羽印记
		for pin_v in pins:
			var pin: Dictionary = pin_v
			var hit_p: Vector2 = tp + (pin["offset"] as Vector2)
			draw_circle(hit_p, 3.5, Color("1b110b"))
			draw_line(hit_p, hit_p + Vector2(6, -10), Color("f5e9d0"), 2.0)
			draw_circle(hit_p + Vector2(6, -10), 2.5, Color("e8523f"))

		# 5. 玩家瞄准准星与风偏预判刻度
		var ap := panel_ref._aim_pos
		var aim_col := Color("7fe096")
		draw_arc(ap, 16.0, 0.0, TAU, 24, aim_col, 2.0)
		draw_line(ap + Vector2(-22, 0), ap + Vector2(-6, 0), aim_col, 2.0)
		draw_line(ap + Vector2(6, 0), ap + Vector2(22, 0), aim_col, 2.0)
		draw_line(ap + Vector2(0, -22), ap + Vector2(0, -6), aim_col, 2.0)
		draw_line(ap + Vector2(0, 6), ap + Vector2(0, 22), aim_col, 2.0)
		# 风偏落点虚线提示点
		var pred := Vector2(ap.x + wind * 0.65, ap.y)
		draw_circle(pred, 3.0, Color(1.0, 0.82, 0.38, 0.78))

		# 6. 飞行中的箭矢与底部长弓
		var bow_c := Vector2(w * 0.5, h - 18.0)
		draw_arc(bow_c + Vector2(0, 14), 38.0, PI * 1.15, PI * 1.85, 18, Color("c89646"), 4.0)
		draw_line(bow_c + Vector2(-34, 0), bow_c + Vector2(34, 0), Color("e8dec8"), 1.5)
		if panel_ref._flying:
			var t := panel_ref._fly_t
			var cur := panel_ref._fly_from.lerp(panel_ref._fly_to, t) - Vector2(0, sin(t * PI) * 42.0)
			draw_line(cur + Vector2(0, 18), cur, Color("f6e3ba"), 3.0)
			draw_circle(cur, 4.0, Color("ffd25a"))

		# 7. 右侧蓄力槽（含 72%..88% 黄金甜区）
		var bar_rect := Rect2(w - 30.0, 44.0, 14.0, 176.0)
		draw_rect(bar_rect.grow(2.0), Color("1b110b"))
		draw_rect(bar_rect, Color("2a2421"))
		# 黄金蓄力区（72%..88%）
		var sweet_top := bar_rect.end.y - bar_rect.size.y * 0.88
		var sweet_h := bar_rect.size.y * (0.88 - 0.72)
		draw_rect(Rect2(bar_rect.position.x, sweet_top, bar_rect.size.x, sweet_h), Color(0.32, 0.78, 0.44, 0.65))
		var ch := clampf(panel_ref._charge, 0.0, 1.0)
		if ch > 0.01:
			var fill_h := bar_rect.size.y * ch
			var fill_col := Color("6be088") if (ch >= 0.72 and ch <= 0.88) else Color("f2b84b")
			draw_rect(Rect2(bar_rect.position.x, bar_rect.end.y - fill_h, bar_rect.size.x, fill_h), fill_col)

		# 8. 命中横幅提示
		if panel_ref._last_banner_t > 0.0 and not panel_ref._last_banner.is_empty():
			var fnt: Font = G.font_serif
			draw_string(fnt, Vector2(24, h - 22), panel_ref._last_banner, HORIZONTAL_ALIGNMENT_LEFT, w - 72, G.FS_SM, Color("ffe58f"))
