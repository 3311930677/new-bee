# TutorialOverlay.gd —— 11 步剧情融合式新手指引浮层（非阻塞高亮框 + 导师指引卡）
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

var _highlight: _HighlightFrame
var _card: Panel
var _vbox: VBoxContainer
var _speaker_l: Label
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
	z_index = 90
	_build()
	get_viewport().size_changed.connect(_relayout)
	refresh()


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
	box.bg_color = Color(0.08, 0.06, 0.05, 0.94)
	box.border_color = Color("d8ab56")
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 8
	_card.add_theme_stylebox_override("panel", box)
	add_child(_card)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 5)
	_card.add_child(_vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(top_row)

	_speaker_l = Label.new()
	_speaker_l.add_theme_font_override("font", G.font_serif)
	_speaker_l.add_theme_font_size_override("font_size", G.FS_XS)
	_speaker_l.add_theme_color_override("font_color", Color("f2c76a"))
	top_row.add_child(_speaker_l)

	_progress_l = Label.new()
	_progress_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_l.add_theme_font_override("font", G.font_reg)
	_progress_l.add_theme_font_size_override("font_size", G.FS_XS)
	_progress_l.add_theme_color_override("font_color", Color("b8a88a"))
	top_row.add_child(_progress_l)

	_skip_btn = Flow.button("跳过", _on_skip)
	_skip_btn.name = "SkipTutorialButton"
	_skip_btn.tooltip_text = "跳过新手引导（可在设置-旅人中随时重温）"
	_skip_btn.custom_minimum_size = Vector2(68, 30)
	_skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_skip_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	top_row.add_child(_skip_btn)

	_title_l = Label.new()
	_title_l.add_theme_font_override("font", G.font_serif)
	_title_l.add_theme_font_size_override("font_size", G.FS_SM)
	_title_l.add_theme_color_override("font_color", Color("fff1d0"))
	_vbox.add_child(_title_l)

	_body_l = Label.new()
	_body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_l.add_theme_font_override("font", G.font_reg)
	_body_l.add_theme_font_size_override("font_size", G.FS_XS)
	_body_l.add_theme_color_override("font_color", Color("e8d8b8"))
	_vbox.add_child(_body_l)

	_hint_l = Label.new()
	_hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_l.add_theme_font_override("font", G.font_reg)
	_hint_l.add_theme_font_size_override("font_size", G.FS_XS)
	_hint_l.add_theme_color_override("font_color", Color("7fe096"))
	_vbox.add_child(_hint_l)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(btn_row)

	_prev_btn = Flow.button("上一步", _on_prev)
	_prev_btn.name = "PrevStepButton"
	_prev_btn.custom_minimum_size = Vector2(88, 36)
	_prev_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	btn_row.add_child(_prev_btn)

	_try_btn = Flow.button("前往体验", _on_try)
	_try_btn.name = "TryStepButton"
	_try_btn.custom_minimum_size = Vector2(104, 36)
	_try_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	btn_row.add_child(_try_btn)

	_next_btn = Flow.button("下一步", _on_next, true)
	_next_btn.name = "NextStepButton"
	_next_btn.custom_minimum_size = Vector2(136, 36)
	_next_btn.caption.add_theme_font_size_override("font_size", G.FS_XS)
	btn_row.add_child(_next_btn)


func refresh() -> void:
	if not Tut.should_show(G):
		visible = false
		return
	visible = true
	var tut := Tut.ensure_state(G)
	var idx := int(tut.get("step_idx", 0))
	var step := Tut.step_at(idx)
	var total := Tut.total_steps()
	_speaker_l.text = "【%s】" % String(step.get("speaker", "引路人"))
	_progress_l.text = "新手指引 %d / %d" % [idx + 1, total]
	_title_l.text = String(step.get("title", ""))
	_body_l.text = String(step.get("body", ""))
	_hint_l.text = "◆ " + String(step.get("action_hint", ""))
	_prev_btn.disabled = idx <= 0
	var is_last := idx >= total - 1
	_next_btn.caption.text = "完成引导 · 领礼" if is_last else "下一步"
	_try_btn.visible = action_router.is_valid() and not is_last
	_relayout()


func _relayout() -> void:
	if not is_inside_tree() or _card == null:
		return
	var vp := get_viewport_rect().size
	var step := Tut.current_step(G)
	var hl: Array = step.get("highlight", [160, 440, 160, 120])
	var extra_y := maxf(vp.y - 800.0, 0.0)
	var hx := float(hl[0]) + (vp.x - 480.0) * 0.5
	var hy := float(hl[1])
	if hy >= 580.0:
		hy += extra_y
	elif hy >= 240.0:
		hy += extra_y * 0.75
	var hw := float(hl[2])
	var hh := float(hl[3])
	_highlight.target_rect = Rect2(hx, hy, hw, hh)
	_highlight.size = vp
	_highlight.queue_redraw()

	var card_w := minf(448.0, vp.x - 24.0)
	var card_x := roundf((vp.x - card_w) * 0.5)
	var card_h := 204.0
	var card_y := 108.0 if hy >= 340.0 else (vp.y - card_h - 108.0)
	_card.position = Vector2(card_x, card_y)
	_card.size = Vector2(card_w, card_h)
	_card.custom_minimum_size = Vector2(card_w, card_h)
	if _vbox != null:
		_vbox.position = Vector2(14, 10)
		_vbox.size = Vector2(card_w - 28.0, card_h - 20.0)


func _on_prev() -> void:
	Audio.sfx("ui_click")
	var res := Tut.prev(G, true)
	refresh()
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
		visible = false
		if bool(res.get("reward_granted", false)):
			reward_claimed.emit(String(res.get("reward_text", "")))
		closed.emit()
		return
	refresh()
	step_changed.emit(int(res.get("step_idx", 0)))


func _on_skip() -> void:
	Audio.sfx("ui_cancel")
	Tut.skip(G, true)
	visible = false
	closed.emit()


class _HighlightFrame extends Control:
	var target_rect := Rect2(160, 440, 160, 120)
	var pulse := 0.0

	func _draw() -> void:
		if not target_rect.has_area():
			return
		var pad := 4.0 + sin(pulse) * 2.5
		var r := target_rect.grow(pad)
		var gold := Color(0.96, 0.80, 0.42, 0.88)
		var glow := Color(0.96, 0.80, 0.42, 0.22)
		draw_rect(r.grow(3.0), glow, false, 4.0)
		draw_rect(r, gold, false, 2.0)
		var cl := 14.0
		# 四角加粗角标
		for corner in [
			[r.position, Vector2(cl, 0), Vector2(0, cl)],
			[Vector2(r.end.x, r.position.y), Vector2(-cl, 0), Vector2(0, cl)],
			[Vector2(r.position.x, r.end.y), Vector2(cl, 0), Vector2(0, -cl)],
			[r.end, Vector2(-cl, 0), Vector2(0, -cl)],
		]:
			var p: Vector2 = corner[0]
			draw_line(p, p + corner[1], Color("fff3c4"), 3.0)
			draw_line(p, p + corner[2], Color("fff3c4"), 3.0)
