# TutorialOverlay.gd —— 11 步剧情融合式新手指引浮层（自动切页 + 聚光灯遮罩 + 导师任务卡）
class_name TutorialOverlay
extends Control

signal closed
signal step_changed(step_idx: int)
signal reward_claimed(reward_text: String)

const UI := preload("res://src/ui/TravelChestUI.gd")
const Flow := preload("res://src/ui/FlowChestUI.gd")
const Tut := preload("res://src/world/TutorialService.gd")

var scene_context := "home"
var action_router: Callable = Callable()
var panel_router: Callable = Callable()

var _highlight: _HighlightFrame
var _card: Panel
var _vbox: VBoxContainer
var _speaker_l: Label
var _badge_l: Label
var _progress_l: Label
var _title_l: Label
var _body_l: Label
var _hint_l: Label
var _prev_btn: Button
var _try_btn: Button
var _next_btn: Button
var _skip_btn: Button
var _pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	_build()
	get_viewport().size_changed.connect(_relayout)
	refresh(false)


func _process(delta: float) -> void:
	_pulse += delta * 3.2
	if _highlight != null and _highlight.visible:
		_highlight.pulse = _pulse
		_highlight.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked or not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_skip()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_highlight = _HighlightFrame.new()
	_highlight.name = "TutorialHighlight"
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_highlight)

	_card = Panel.new()
	_card.name = "TutorialCard"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.05, 0.04, 0.96)
	box.border_color = Color("e2b860")
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0, 0, 0, 0.65)
	box.shadow_size = 10
	_card.add_theme_stylebox_override("panel", box)
	add_child(_card)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_card.add_child(_vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	_vbox.add_child(top_row)

	_speaker_l = Label.new()
	_speaker_l.add_theme_font_override("font", G.font_serif)
	_speaker_l.add_theme_font_size_override("font_size", G.FS_XS)
	_speaker_l.add_theme_color_override("font_color", Color("f5cc70"))
	top_row.add_child(_speaker_l)

	_progress_l = Label.new()
	_progress_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_l.add_theme_font_override("font", G.font_reg)
	_progress_l.add_theme_font_size_override("font_size", G.FS_XS)
	_progress_l.add_theme_color_override("font_color", Color("d2c09e"))
	top_row.add_child(_progress_l)

	_skip_btn = Flow.button("跳过", _on_skip)
	_skip_btn.name = "SkipTutorialButton"
	_skip_btn.tooltip_text = "跳过新手引导（可在设置中随时重温）"
	_skip_btn.custom_minimum_size = Vector2(64, 44)
	_skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_skip_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	top_row.add_child(_skip_btn)

	_badge_l = Label.new()
	_badge_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_badge_l.add_theme_font_override("font", G.font_reg)
	_badge_l.add_theme_font_size_override("font_size", G.FS_XS)
	_badge_l.add_theme_color_override("font_color", Color("6fe2b8"))
	_vbox.add_child(_badge_l)

	_title_l = Label.new()
	_title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_l.add_theme_font_override("font", G.font_serif)
	_title_l.add_theme_font_size_override("font_size", G.FS_SM)
	_title_l.add_theme_color_override("font_color", Color("fff3d4"))
	_vbox.add_child(_title_l)

	_body_l = Label.new()
	_body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_l.add_theme_font_override("font", G.font_reg)
	_body_l.add_theme_font_size_override("font_size", G.FS_XS)
	_body_l.add_theme_color_override("font_color", Color("ebe0c6"))
	_vbox.add_child(_body_l)

	_hint_l = Label.new()
	_hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_l.add_theme_font_override("font", G.font_reg)
	_hint_l.add_theme_font_size_override("font_size", G.FS_XS)
	_hint_l.add_theme_color_override("font_color", Color("84e89c"))
	_vbox.add_child(_hint_l)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(btn_row)

	_prev_btn = Flow.button("上一步", _on_prev)
	_prev_btn.name = "PrevStepButton"
	_prev_btn.custom_minimum_size = Vector2(84, 44)
	_prev_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	btn_row.add_child(_prev_btn)

	_try_btn = Flow.button("实操演示", _on_try)
	_try_btn.name = "TryStepButton"
	_try_btn.custom_minimum_size = Vector2(98, 44)
	_try_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	btn_row.add_child(_try_btn)

	_next_btn = Flow.button("下一步", _on_next, true)
	_next_btn.name = "NextStepButton"
	_next_btn.custom_minimum_size = Vector2(124, 44)
	_next_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	btn_row.add_child(_next_btn)


func refresh(sync_panel: bool = false) -> void:
	if not Tut.should_show(G):
		visible = false
		return
	var tut := Tut.ensure_state(G)
	var idx := int(tut.get("step_idx", 0))
	var step := Tut.step_at(idx)
	var total := Tut.total_steps()
	if sync_panel and panel_router.is_valid():
		panel_router.call(String(step.get("panel", "home")), String(step.get("id", "")))
	visible = true
	move_to_front()
	_speaker_l.text = "【%s】" % String(step.get("speaker", "引路人"))
	_badge_l.text = "◆ " + String(step.get("page_badge", "当前页面：主城总览"))
	_progress_l.text = "指引 %d/%d" % [idx + 1, total]
	_title_l.text = String(step.get("title", ""))
	_body_l.text = String(step.get("body", ""))
	_hint_l.text = "▶ " + String(step.get("action_hint", ""))
	_prev_btn.disabled = idx <= 0
	var is_last := idx >= total - 1
	_next_btn.caption.text = "完成引导 · 领礼" if is_last else "下一步"
	_try_btn.visible = action_router.is_valid() and not is_last
	_relayout()
	_relayout.call_deferred()


func _relayout() -> void:
	if not is_inside_tree() or _card == null:
		return
	var vp := get_viewport_rect().size
	var step := Tut.current_step(G)
	var hl: Array = step.get("highlight", [160, 440, 160, 120])
	var extra_y := maxf(vp.y - 800.0, 0.0)
	var hx := float(hl[0]) + (vp.x - 480.0) * 0.5
	var hy := float(hl[1])
	var panel_id := String(step.get("panel", "home"))
	if panel_id == "home":
		if hy >= 580.0:
			hy += extra_y
		elif hy >= 240.0:
			hy += extra_y * 0.75
	else:
		hy += extra_y * 0.5
	var hw := float(hl[2])
	var hh := float(hl[3])
	var target := Rect2(hx, hy, hw, hh)

	var card_w := minf(448.0, vp.x - 24.0)
	var card_x := roundf((vp.x - card_w) * 0.5)
	var inner_w := card_w - 28.0
	if _vbox != null:
		_vbox.custom_minimum_size = Vector2(inner_w, 0)
		_vbox.size = Vector2(inner_w, 0)
	var vbox_h := _vbox.get_combined_minimum_size().y if _vbox != null else 260.0
	var card_h := maxf(264.0, vbox_h + 20.0)
	var target_cy := target.get_center().y
	var card_at_top := target_cy >= vp.y * 0.52
	var card_y := 32.0 if card_at_top else (vp.y - card_h - 12.0)
	_card.position = Vector2(card_x, card_y)
	_card.size = Vector2(card_w, card_h)
	_card.custom_minimum_size = Vector2(card_w, card_h)
	if _vbox != null:
		_vbox.position = Vector2(14, 10)
		_vbox.size = Vector2(inner_w, card_h - 20.0)

	_highlight.target_rect = target
	_highlight.card_at_top = card_at_top
	_highlight.size = vp
	_highlight.queue_redraw()


func _on_prev() -> void:
	Audio.sfx("ui_click")
	var res := Tut.prev(G, true)
	refresh(true)
	step_changed.emit(int(res.get("step_idx", 0)))


func _on_try() -> void:
	Audio.sfx("ui_confirm")
	var step := Tut.current_step(G)
	var sid := String(step.get("id", ""))
	if action_router.is_valid():
		action_router.call(sid)


func _on_next() -> void:
	Audio.sfx("ui_confirm")
	var res := Tut.advance(G, true)
	if bool(res.get("finished", false)):
		if panel_router.is_valid():
			panel_router.call("home", "step_11_goals")
		visible = false
		if bool(res.get("reward_granted", false)):
			reward_claimed.emit(String(res.get("reward_text", "")))
		closed.emit()
		return
	refresh(true)
	step_changed.emit(int(res.get("step_idx", 0)))


func _on_skip() -> void:
	Audio.sfx("ui_cancel")
	Tut.skip(G, true)
	if panel_router.is_valid():
		panel_router.call("home", "skip")
	visible = false
	closed.emit()


class _HighlightFrame extends Control:
	var target_rect := Rect2(160, 440, 160, 120)
	var card_at_top := true
	var pulse := 0.0

	func _draw() -> void:
		if not target_rect.has_area():
			return
		var pad := 4.0 + sin(pulse) * 2.5
		var r := target_rect.grow(pad)
		# 四块半透明暗幕形成聚光灯镂空，让玩家一眼看清当前框选目标
		var mask_col := Color(0.03, 0.02, 0.05, 0.56)
		var top_h := clampf(r.position.y, 0.0, size.y)
		var bot_y := clampf(r.end.y, 0.0, size.y)
		var left_w := clampf(r.position.x, 0.0, size.x)
		var right_x := clampf(r.end.x, 0.0, size.x)
		if top_h > 0.0:
			draw_rect(Rect2(0, 0, size.x, top_h), mask_col, true)
		if bot_y < size.y:
			draw_rect(Rect2(0, bot_y, size.x, size.y - bot_y), mask_col, true)
		if left_w > 0.0 and bot_y > top_h:
			draw_rect(Rect2(0, top_h, left_w, bot_y - top_h), mask_col, true)
		if right_x < size.x and bot_y > top_h:
			draw_rect(Rect2(right_x, top_h, size.x - right_x, bot_y - top_h), mask_col, true)

		var gold := Color(0.98, 0.84, 0.44, 0.96)
		var glow := Color(0.98, 0.80, 0.36, 0.28)
		draw_rect(r.grow(3.5), glow, false, 5.0)
		draw_rect(r, gold, false, 2.5)
		var cl := 16.0
		# 四角加粗鎏金角标
		for corner in [
			[r.position, Vector2(cl, 0), Vector2(0, cl)],
			[Vector2(r.end.x, r.position.y), Vector2(-cl, 0), Vector2(0, cl)],
			[Vector2(r.position.x, r.end.y), Vector2(cl, 0), Vector2(0, -cl)],
			[r.end, Vector2(-cl, 0), Vector2(0, -cl)],
		]:
			var p: Vector2 = corner[0]
			draw_line(p, p + corner[1], Color("fff6d6"), 3.5)
			draw_line(p, p + corner[2], Color("fff6d6"), 3.5)

		# 动态指示箭头（指向框选区中心边沿）
		var bounce := sin(pulse * 1.4) * 5.0
		var cx := r.get_center().x
		if card_at_top:
			# 指引卡在上方，箭头在目标框上沿向下指
			var tip := Vector2(cx, r.position.y - 6.0 + bounce)
			draw_colored_polygon(PackedVector2Array([
				tip,
				tip + Vector2(-11, -16),
				tip + Vector2(11, -16),
			]), Color("ffe89c"))
		else:
			# 指引卡在下方，箭头在目标框下沿向上指
			var tip := Vector2(cx, r.end.y + 6.0 + bounce)
			draw_colored_polygon(PackedVector2Array([
				tip,
				tip + Vector2(-11, 16),
				tip + Vector2(11, 16),
			]), Color("ffe89c"))
