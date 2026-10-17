# ArcheryPanel.gd —— 第一轮内容扩充精修版：边城校场射艺（像素实景演武坪+三帧角弓+风偏轨迹+连中反馈）
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
var _streak := 0
var _wind := 0.0
var _time := 0.0
var _target_pos := Vector2(240, 134)
var _aim_pos := Vector2(240, 134)
var _charging := false
var _charge := 0.0
var _charge_dir := 1.0
var _flying := false
var _fly_t := 0.0
var _fly_from := Vector2(240, 290)
var _fly_to := Vector2(240, 134)
var _hit_shake_t := 0.0
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
	shell = Flow.Shell.new("校场射艺 · 演武靶场", 338)
	shell.closed = _close
	add_child(shell)
	if shell.body is VBoxContainer:
		(shell.body as VBoxContainer).add_theme_constant_override("separation", 5)

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
	_streak = 0
	_round_finished = false
	_charging = false
	_charge = 0.0
	_flying = false
	_hit_shake_t = 0.0
	_range.pins.clear()
	_range.floaters.clear()
	_range.sparks.clear()
	var w := maxf(360.0, shell.stage.size.x if shell.stage.size.x > 0 else 480.0)
	_target_pos = Vector2(w * 0.5, 134.0)
	_aim_pos = _target_pos
	_roll_wind()
	_log_label.text = "点「听风校准」逆风预瞄，按住「蓄力射箭」在右侧翠金甜区松手！"
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
	_aim_pos.y = clampf(_aim_pos.y + delta_v.y, 64.0, 214.0)
	_range.queue_redraw()


func _auto_compensate_wind() -> void:
	if _round_finished or _flying:
		return
	Audio.sfx("ui_click")
	_aim_pos = Vector2(
		clampf(_target_pos.x - _wind * 0.65, 64.0, maxf(360.0, _range.size.x) - 64.0),
		_target_pos.y
	)
	_last_banner = "✦ 已听风校准：准星预偏逆风位"
	_last_banner_t = 1.3
	_range.queue_redraw()


func _on_range_input(event: InputEvent) -> void:
	if _round_finished or _flying:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_aim_pos.x = clampf(event.position.x, 64.0, maxf(360.0, _range.size.x) - 64.0)
		_aim_pos.y = clampf(event.position.y, 64.0, 214.0)
		_range.queue_redraw()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_aim_pos.x = clampf(event.position.x, 64.0, maxf(360.0, _range.size.x) - 64.0)
		_aim_pos.y = clampf(event.position.y, 64.0, 214.0)
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
	if _charging or _flying or _round_finished or _arrows_left <= 0:
		return
	_release_arrow(0.80)


func shoot_with_params(aim: Vector2, charge_power: float) -> Dictionary:
	## 供自动化测试或新手指引一键演练确定性调用
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
	_fly_from = Vector2(w * 0.5, 276.0)
	var drift_x := _wind * 0.65
	var drop_y := (0.80 - power) * 95.0
	_fly_to = Vector2(_aim_pos.x + drift_x, _aim_pos.y + drop_y)
	_charge = power


func _process(delta: float) -> void:
	var m := _current_mode()
	var spd := float(m.get("target_speed", 48.0))
	var bob := float(m.get("target_bob", 8.0))
	var w := maxf(360.0, _range.size.x if _range.size.x > 0 else 480.0)
	_time += delta
	if not _round_finished:
		var amp_x := minf(118.0, (w - 190.0) * 0.5)
		_target_pos.x = w * 0.5 + sin(_time * (spd / 52.0)) * amp_x
		_target_pos.y = 132.0 + cos(_time * (spd / 36.0)) * bob
	if _charging:
		_charge += delta * 1.15 * _charge_dir
		if _charge >= 1.0:
			_charge = 1.0
			_charge_dir = -1.0
		elif _charge <= 0.1:
			_charge = 0.1
			_charge_dir = 1.0
	if _flying:
		_fly_t += delta * 4.0
		if _fly_t >= 1.0:
			_flying = false
			_resolve_shot(_aim_pos, _charge, false)
	if _hit_shake_t > 0.0:
		_hit_shake_t = maxf(0.0, _hit_shake_t - delta)
	if _last_banner_t > 0.0:
		_last_banner_t = maxf(0.0, _last_banner_t - delta)
	if _range != null:
		_range.step_effects(delta)
		_range.queue_redraw()


func _resolve_shot(aim: Vector2, power: float, instant: bool) -> Dictionary:
	var drift_x := _wind * 0.65
	var drop_y := (0.80 - power) * 95.0
	var impact := Vector2(aim.x + drift_x, aim.y + drop_y) if instant else _fly_to
	var offset := impact - _target_pos
	var dist := offset.length()
	var rings := 0
	var comment := "脱靶偏失"
	var pop_col := Color("d0a090")
	if dist <= 13.0:
		rings = 10
		comment = "正中红心 · 百步穿杨！"
		pop_col = Color("ffe478")
		_bullseyes_this_round += 1
		_streak += 1
	elif dist <= 25.0:
		rings = 8
		comment = "劲矢贯靶 · 8环！"
		pop_col = Color("ff9e68")
		_streak += 1
	elif dist <= 38.0:
		rings = 6
		comment = "稳中内圈 · 6环"
		pop_col = Color("7fd4ff")
		_streak = 0
	elif dist <= 51.0:
		rings = 4
		comment = "擦中靶盘 · 4环"
		pop_col = Color("d8ccb8")
		_streak = 0
	elif dist <= 65.0:
		rings = 2
		comment = "掠过外环 · 2环"
		pop_col = Color("b8a890")
		_streak = 0
	else:
		_streak = 0
	_arrows_left = maxi(0, _arrows_left - 1)
	_score += rings
	_hit_shake_t = 0.28 if rings >= 6 else 0.12
	_range.pins.append({"offset": offset, "rings": rings})
	var streak_txt := (" 连中×%d" % _streak) if _streak >= 2 else ""
	_range.spawn_hit_fx(impact, ("+%d环 %s%s" % [rings, comment, streak_txt]) if rings > 0 else "脱靶偏失", pop_col, rings >= 8)
	var shot_no := _arrows_max - _arrows_left
	_last_banner = "第%d箭：%d环（%s）%s" % [shot_no, rings, comment, streak_txt]
	_last_banner_t = 2.2
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
	var wind_dir := "东风(左偏)" if _wind < -0.5 else ("西风(右偏)" if _wind > 0.5 else "微风无偏")
	_wind_label.text = "当前风势：%s %.1f ｜ 达标：%d环 · 魁首：%d环" % [wind_dir, absf(_wind), pass_sc, master_sc]
	var first_done := bool(st["first_claimed"].get(mid, false))
	_reward_label.text = "本档状态：%s" % ("首通重赏已领（重开可刷荣誉与铜钱）" if first_done else "首通可获强化石/精炼石与丰厚荣誉")
	_fire_btn.disabled = _round_finished or _arrows_left <= 0


class _RangeCanvas extends Control:
	var panel_ref: ArcheryPanel
	var pins: Array = []
	var floaters: Array = []
	var sparks: Array = []
	var _tex_bg: Texture2D
	var _tex_target: Texture2D
	var _tex_bow: Texture2D

	static func _load_png_tex(path: String) -> Texture2D:
		if ResourceLoader.exists(path):
			var t := load(path) as Texture2D
			if t != null:
				return t
		var abs_p := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_p):
			var img := Image.load_from_file(abs_p)
			if img != null and not img.is_empty():
				var it := ImageTexture.create_from_image(img)
				it.take_over_path(path)
				return it
		return null

	func _ready() -> void:
		_tex_bg = _load_png_tex("res://assets/ui/minigames/archery_range_bg.png")
		_tex_target = _load_png_tex("res://assets/ui/minigames/archery_target_sprite.png")
		_tex_bow = _load_png_tex("res://assets/ui/minigames/archery_bow_sheet.png")

	func spawn_hit_fx(pos: Vector2, text: String, col: Color, is_bullseye: bool) -> void:
		var y_stagger := -14.0 - float(floaters.size()) * 22.0
		floaters.append({"pos": pos + Vector2(0, y_stagger), "text": text, "col": col, "t": 0.0, "dur": 1.35})
		var count := 14 if is_bullseye else 7
		for i in count:
			var ang := (TAU / float(count)) * float(i) + randf_range(-0.2, 0.2)
			var spd := randf_range(38.0, 96.0 if is_bullseye else 62.0)
			sparks.append({
				"pos": pos,
				"vel": Vector2(cos(ang), sin(ang)) * spd,
				"col": Color("ffe478") if (is_bullseye and i % 2 == 0) else col,
				"t": 0.0,
				"dur": randf_range(0.35, 0.65),
			})

	func step_effects(delta: float) -> void:
		for i in range(floaters.size() - 1, -1, -1):
			var fl: Dictionary = floaters[i]
			fl["t"] = float(fl["t"]) + delta
			fl["pos"] = (fl["pos"] as Vector2) + Vector2(0, -24.0 * delta)
			if float(fl["t"]) >= float(fl["dur"]):
				floaters.remove_at(i)
		for i in range(sparks.size() - 1, -1, -1):
			var sp: Dictionary = sparks[i]
			sp["t"] = float(sp["t"]) + delta
			var v: Vector2 = sp["vel"]
			sp["pos"] = (sp["pos"] as Vector2) + v * delta
			sp["vel"] = v * (1.0 - 3.0 * delta) + Vector2(0, 80.0 * delta)
			if float(sp["t"]) >= float(sp["dur"]):
				sparks.remove_at(i)

	func _draw() -> void:
		if panel_ref == null:
			return
		var w := size.x
		var h := size.y
		var tm := panel_ref._time
		var wind := panel_ref._wind
		var fnt: Font = G.font_serif

		# 1. 绘制像素实景靶场背景（月下边城演武坪 + 拒马 + 铜灯 + 听风铃）
		if _tex_bg != null:
			draw_texture_rect(_tex_bg, Rect2(0, 0, w, h), false)
		else:
			draw_rect(Rect2(0, 0, w, h), Color("14100d"))

		# 2. 动态篝火与铜灯笼暖光呼吸光晕
		var flicker := 0.85 + 0.15 * sin(tm * 7.5)
		draw_circle(Vector2(90, 210), 42.0 * flicker, Color(1.0, 0.58, 0.18, 0.13 * flicker))
		draw_circle(Vector2(w - 42, 74), 34.0 * flicker, Color(1.0, 0.68, 0.24, 0.15 * flicker))

		# 3. 听风铜铃下的动态丝绸风向飘带 + 场地随风流线粒子
		var bell_anchor := Vector2(46, 86)
		var wind_Len := clampf(wind * 1.15, -52.0, 52.0)
		if absf(wind_Len) < 8.0:
			wind_Len = 8.0 if wind >= 0.0 else -8.0
		var wave1 := sin(tm * 6.0) * 4.5
		var wave2 := cos(tm * 8.0) * 6.5
		var p1 := bell_anchor + Vector2(wind_Len * 0.45, 12.0 + wave1)
		var p2 := bell_anchor + Vector2(wind_Len, 22.0 + wave2)
		var ribbon_col := Color("e6523e") if absf(wind) > 22.0 else Color("f4c45e")
		draw_polyline(PackedVector2Array([bell_anchor, p1, p2]), Color("22120b"), 6.0)
		draw_polyline(PackedVector2Array([bell_anchor, p1, p2]), ribbon_col, 3.5)

		# 校场风流粒子丝线
		if absf(wind) > 1.5:
			var dir_sign := 1.0 if wind > 0.0 else -1.0
			for wi in 5:
				var wy := 96.0 + float(wi) * 34.0
				var wx := fposmod(float(wi) * 97.0 + tm * wind * 2.6, w - 80.0) + 40.0
				var streak_len := clampf(absf(wind) * 0.65, 10.0, 32.0) * dir_sign
				draw_line(Vector2(wx, wy), Vector2(wx + streak_len, wy + sin(tm * 3.0 + float(wi)) * 2.0), Color(0.95, 0.88, 0.68, 0.28), 1.5)

		# 4. 移动木架草靶精灵（含命中震颤与嵌入箭羽）
		var shake := Vector2.ZERO
		if panel_ref._hit_shake_t > 0.0:
			var s_amp := panel_ref._hit_shake_t * 18.0
			shake = Vector2(sin(tm * 55.0) * s_amp, cos(tm * 48.0) * s_amp * 0.5)
		var tp := panel_ref._target_pos + shake
		if _tex_target != null:
			# 靶盘中心在贴图 (72, 70) 处（贴图尺寸 144x168）
			draw_texture_rect(_tex_target, Rect2(tp.x - 72.0, tp.y - 70.0, 144.0, 168.0), false)

		# 绘制靶上已命中的雕翎箭矢
		for pin_v in pins:
			var pin: Dictionary = pin_v
			var hit_p: Vector2 = tp + (pin["offset"] as Vector2)
			var tail_p := hit_p + Vector2(10, -15)
			# 箭影
			draw_line(hit_p + Vector2(2, 3), tail_p + Vector2(2, 5), Color(0, 0, 0, 0.45), 2.0)
			# 箭孔与木杆
			draw_circle(hit_p, 3.2, Color("1e110a"))
			draw_line(hit_p, tail_p, Color("e6cfa0"), 2.2)
			# 赤金雕翎尾羽
			var feather_col := Color("ffd45e") if int(pin.get("rings", 0)) == 10 else Color("e45842")
			draw_colored_polygon(PackedVector2Array([
				tail_p + Vector2(-3, 2),
				tail_p + Vector2(3, -4),
				tail_p + Vector2(5, 1),
			]), feather_col)

		# 5. 瞄准准星与风偏落点虚线预判
		var ap := panel_ref._aim_pos
		var drop_preview := (0.80 - (panel_ref._charge if panel_ref._charging else 0.80)) * 95.0
		var pred := Vector2(ap.x + wind * 0.65, ap.y + drop_preview)
		if ap.distance_to(pred) > 3.0:
			for st_i in 6:
				var u0 := float(st_i) / 6.0
				var u1 := (float(st_i) + 0.5) / 6.0
				draw_line(ap.lerp(pred, u0), ap.lerp(pred, u1), Color(1.0, 0.84, 0.42, 0.65), 1.5)
			draw_arc(pred, 7.0, 0.0, TAU, 16, Color(1.0, 0.84, 0.42, 0.85), 1.5)
			draw_circle(pred, 2.5, Color(1.0, 0.88, 0.48, 0.95))

		var in_sweet := panel_ref._charging and panel_ref._charge >= 0.72 and panel_ref._charge <= 0.88
		var aim_col := Color("ffe478") if in_sweet else Color("76e896")
		draw_arc(ap, 17.0, 0.0, TAU, 28, Color("1a100a"), 4.0)
		draw_arc(ap, 17.0, 0.0, TAU, 28, aim_col, 2.0)
		draw_line(ap + Vector2(-23, 0), ap + Vector2(-7, 0), aim_col, 2.0)
		draw_line(ap + Vector2(7, 0), ap + Vector2(23, 0), aim_col, 2.0)
		draw_line(ap + Vector2(0, -23), ap + Vector2(0, -7), aim_col, 2.0)
		draw_line(ap + Vector2(0, 7), ap + Vector2(0, 23), aim_col, 2.0)
		draw_circle(ap, 2.5, aim_col)

		# 6. 底部三帧鎏金反曲角弓与抛物线飞行箭矢
		if _tex_bow != null:
			var bow_frame := 0
			if panel_ref._charging:
				bow_frame = 2 if panel_ref._charge >= 0.68 else 1
			var src_rect := Rect2(bow_frame * 160.0, 0.0, 160.0, 120.0)
			var dst_rect := Rect2(w * 0.5 - 76.0, h - 104.0, 152.0, 114.0)
			draw_texture_rect_region(_tex_bow, dst_rect, src_rect)

		if panel_ref._flying:
			var t := panel_ref._fly_t
			var arc_h := sin(t * PI) * 48.0
			var cur := panel_ref._fly_from.lerp(panel_ref._fly_to, t) - Vector2(0, arc_h)
			var prev_t := maxf(0.0, t - 0.12)
			var prev := panel_ref._fly_from.lerp(panel_ref._fly_to, prev_t) - Vector2(0, sin(prev_t * PI) * 48.0)
			# 破空流光尾迹
			draw_line(prev, cur, Color(1.0, 0.88, 0.48, 0.55), 4.0)
			draw_line(cur + Vector2(0, 16), cur, Color("fff0c2"), 2.8)
			draw_circle(cur, 3.8, Color("ffd65c"))

		# 7. 顶部暗金铭牌 HUD（左：风向仪；右：可视化箭囊与连中）
		var rfnt: Font = G.font_reg
		var hud_l := Rect2(10, 8, 174, 28)
		draw_rect(hud_l, Color(0.11, 0.07, 0.05, 0.88))
		draw_rect(hud_l, Color("c89c52"), false, 1.5)
		var w_txt := "东风 %.1f ◀" % absf(wind) if wind < -0.5 else ("西风 %.1f ▶" % absf(wind) if wind > 0.5 else "微风 0.0 ●")
		var w_col := Color("ff9a76") if absf(wind) > 22.0 else Color("f3d486")
		draw_string_outline(rfnt, Vector2(18, 27), "风势：" + w_txt, HORIZONTAL_ALIGNMENT_LEFT, 158, G.FS_XS, 3, Color(0.05, 0.03, 0.02, 0.95))
		draw_string(rfnt, Vector2(18, 27), "风势：" + w_txt, HORIZONTAL_ALIGNMENT_LEFT, 158, G.FS_XS, w_col)

		var hud_r := Rect2(w - 194, 8, 148, 28)
		draw_rect(hud_r, Color(0.11, 0.07, 0.05, 0.88))
		draw_rect(hud_r, Color("c89c52"), false, 1.5)
		draw_string_outline(rfnt, Vector2(hud_r.position.x + 8, 27), "箭囊：", HORIZONTAL_ALIGNMENT_LEFT, 52, G.FS_XS, 3, Color(0.05, 0.03, 0.02, 0.95))
		draw_string(rfnt, Vector2(hud_r.position.x + 8, 27), "箭囊：", HORIZONTAL_ALIGNMENT_LEFT, 52, G.FS_XS, Color("f3e3c0"))
		for ai in panel_ref._arrows_max:
			var ax := hud_r.position.x + 56.0 + float(ai) * 14.0
			var active_arrow := ai < panel_ref._arrows_left
			var acol := Color("ffd468") if active_arrow else Color(0.35, 0.28, 0.22, 0.65)
			draw_line(Vector2(ax, 29), Vector2(ax + 6, 15), acol, 2.2)
			if active_arrow:
				draw_circle(Vector2(ax + 6, 15), 2.0, Color("ff6b52"))

		# 8. 右侧雕花蓄力槽（含 72%..88% 黄金穿杨甜区）
		var bar_rect := Rect2(w - 32.0, 46.0, 16.0, 186.0)
		draw_rect(bar_rect.grow(3.0), Color("160e09"))
		draw_rect(bar_rect.grow(2.0), Color("c89c52"), false, 1.5)
		draw_rect(bar_rect, Color("261c16"))
		var sweet_top := bar_rect.end.y - bar_rect.size.y * 0.88
		var sweet_h := bar_rect.size.y * (0.88 - 0.72)
		draw_rect(Rect2(bar_rect.position.x, sweet_top, bar_rect.size.x, sweet_h), Color(0.28, 0.82, 0.46, 0.72))
		draw_rect(Rect2(bar_rect.position.x, sweet_top, bar_rect.size.x, sweet_h), Color("98ffB4"), false, 1.0)
		var ch := clampf(panel_ref._charge, 0.0, 1.0)
		if ch > 0.01:
			var fill_h := bar_rect.size.y * ch
			var fill_col := Color("6be88c") if (ch >= 0.72 and ch <= 0.88) else Color("f2b84b")
			draw_rect(Rect2(bar_rect.position.x + 2.0, bar_rect.end.y - fill_h, bar_rect.size.x - 4.0, fill_h), fill_col)
			var py := bar_rect.end.y - fill_h
			draw_line(Vector2(bar_rect.position.x - 4.0, py), Vector2(bar_rect.end.x + 4.0, py), Color("fff4c8"), 2.0)
		for tk in [0.25, 0.50, 0.72, 0.88]:
			var ty: float = bar_rect.end.y - bar_rect.size.y * float(tk)
			draw_line(Vector2(bar_rect.position.x, ty), Vector2(bar_rect.position.x + 5.0, ty), Color(0.85, 0.72, 0.45, 0.65), 1.0)

		# 9. 命中粒子与飘字反馈（居中对齐且限制在画布内）
		for sp_v in sparks:
			var sp: Dictionary = sp_v
			var ratio := 1.0 - float(sp["t"]) / float(sp["dur"])
			var scol: Color = sp["col"]
			scol.a = clampf(ratio, 0.0, 1.0)
			var spos: Vector2 = sp["pos"]
			draw_rect(Rect2(spos.x - 1.5, spos.y - 1.5, 3.0, 3.0), scol)

		for fl_v in floaters:
			var fl: Dictionary = fl_v
			var alpha := clampf(1.0 - (float(fl["t"]) / float(fl["dur"])) * 0.85, 0.0, 1.0)
			var fcol: Color = fl["col"]
			fcol.a = alpha
			var fpos: Vector2 = fl["pos"]
			var box_w := 240.0
			var fx_x := clampf(fpos.x - box_w * 0.5, 8.0, w - box_w - 38.0)
			draw_string_outline(rfnt, Vector2(fx_x, fpos.y), String(fl["text"]), HORIZONTAL_ALIGNMENT_CENTER, box_w, G.FS_SM, 4, Color(0.08, 0.04, 0.02, alpha))
			draw_string(rfnt, Vector2(fx_x, fpos.y), String(fl["text"]), HORIZONTAL_ALIGNMENT_CENTER, box_w, G.FS_SM, fcol)

		# 10. 底部锦缎战报横幅
		if panel_ref._last_banner_t > 0.0 and not panel_ref._last_banner.is_empty():
			var b_rect := Rect2(14, h - 24, w - 28, 22)
			draw_rect(b_rect, Color(0.10, 0.06, 0.04, 0.86))
			draw_rect(b_rect, Color("b88c46"), false, 1.0)
			draw_string_outline(rfnt, Vector2(22, h - 8), panel_ref._last_banner, HORIZONTAL_ALIGNMENT_LEFT, w - 44, G.FS_XS, 3, Color(0.05, 0.03, 0.02, 0.95))
			draw_string(rfnt, Vector2(22, h - 8), panel_ref._last_banner, HORIZONTAL_ALIGNMENT_LEFT, w - 44, G.FS_XS, Color("ffe58f"))
