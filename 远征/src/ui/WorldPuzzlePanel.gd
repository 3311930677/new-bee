## 带证据的两选一机关；错误选项只给反证，玩家离开后可重试。
class_name WorldPuzzlePanel
extends Control

signal closed
signal choice_selected(choice: String)

func open_puzzle(row: Dictionary) -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	G.veil(self, 0.78, true)
	var choices: Dictionary = row.get("choices", {})
	var extra := maxf(0, choices.size() - 2) * 62.0
	var paper := G.parchment_box(432, 484 + extra, 18.0)
	paper.position = Vector2(24, 140)
	add_child(paper)
	var title := G.serif_label(String(row.get("name", "碑座")), G.FS_LG + 2, Color("6a4a1e"))
	title.position = Vector2(60, 176)
	title.custom_minimum_size = Vector2(360, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var clue := G.text_label(String(row.get("clue", "先查看附近线索，再决定如何调整。")),
		G.FS_SM, Color("594731"))
	clue.position = Vector2(64, 245)
	clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clue.custom_minimum_size = Vector2(352, 98)
	add_child(clue)
	clue.size = Vector2(352, 98)
	var clue_extra := maxf(0,clue.get_combined_minimum_size().y-98)
	paper.custom_minimum_size.y=484+extra+clue_extra
	var idx := 0
	for key in choices:
		_button(String(choices[key]), 365 + idx * 62 + clue_extra, String(key))
		idx += 1
	_button("再看一眼线索", 536 + extra + clue_extra, "")

func _button(label: String, y: float, choice: String) -> void:
	var button := G.gold_button(label, 320, 46, G.FS_SM)
	button.position = Vector2(80, y)
	button.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if not choice.is_empty(): choice_selected.emit(choice)
			closed.emit()
			queue_free())
	add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
