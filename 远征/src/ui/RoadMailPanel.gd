## 归路邮驿：安全驿点接单、结算，并随时翻看最近八封往返信件。
class_name RoadMailPanel
extends Control

const RoadMailServiceScript := preload("res://src/world/RoadMailService.gd")

signal closed
signal action_requested(action: String)

var _archive_index := -1  # 0 是最新一封；-1 是邮驿主页。
var _offset := Vector2.ZERO

func open_board() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_archive_index = -1
	_build()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var viewport_size := get_viewport_rect().size
	_offset = Vector2((viewport_size.x - 480.0) * 0.5, (viewport_size.y - 800.0) * 0.5)
	G.veil(self, 0.76, true)
	var paper := G.parchment_box(432, 620, 18.0)
	paper.position = Vector2(24, 90) + _offset
	add_child(paper)
	var title := G.serif_label("归 路 邮 驿", G.FS_LG + 2, Color("6a4a1e"))
	title.position = Vector2(58, 122) + _offset
	title.custom_minimum_size = Vector2(360, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var state := G.road_mail_state()
	var archive: Array = state.get("archive", [])
	if _archive_index >= 0 and not archive.is_empty():
		_build_archive(archive)
	else:
		_archive_index = -1
		_build_board(state, archive.size())

func _build_board(state: Dictionary, archive_count: int) -> void:
	var day := int(G.economy_state().get("day", 1))
	_add_text("第 %d 日 · 已送达 %d 封\n%s" % [day,
		int(state.get("deliveries", 0)), RoadMailServiceScript.goal(state, day)],
		Vector2(66, 190), Vector2(348, 80), Color("594731"))
	_add_text(RoadMailServiceScript.letter(state), Vector2(66, 292),
		Vector2(348, 80), Color("715439"))
	var status := String(state.get("status", "idle"))
	if status in ["idle", "claimed"] and day > int(state.get("last_claim_day", 0)):
		_add_text("快行须战斗；稳行救信使。付 12 金包扎，或免费护送但少得 20 金。",
			Vector2(66, 372), Vector2(348, 52), Color("725b3d"))
		_button("快行 · 风沙路标", 455, "accept_quick")
		_button("稳行 · 背风驿亭", 508, "accept_safe")
	elif status == "delivered":
		_button("交回平安 · 领取报酬", 485, "claim")
	else:
		_add_text("这趟路仍在进行。地图上会标出下一处目标。",
			Vector2(66, 438), Vector2(348, 54), Color("725b3d"))
	if archive_count > 0:
		_button("翻看路簿 · %d 封" % archive_count, 561, "archive")
	_button("返回", 615, "close")

func _build_archive(archive: Array) -> void:
	_archive_index = clampi(_archive_index, 0, archive.size() - 1)
	var row: Dictionary = archive[archive.size() - 1 - _archive_index]
	var route := "风沙近路" if String(row.get("route", "")) == "quick" else "背风驿路"
	var solution: String = {"observe": "照刻痕辨路", "supply": "驿亭引路"}.get(
		String(row.get("solution", "")), "旧路标通行")
	var encounter: String = {"ambush": "击退伏沙蝎", "help": "包扎信使",
		"escort": "扶信使慢行"}.get(String(row.get("encounter", "")), "")
	_add_text("路簿 %d / %d · 第 %d 日\n%s · %s\n%s" % [
		_archive_index + 1, archive.size(), int(row.get("day", 1)), route, solution,
		encounter],
		Vector2(66, 190), Vector2(348, 76), Color("594731"))
	_add_text("寄出的信\n%s" % String(row.get("letter", "")),
		Vector2(66, 284), Vector2(348, 98), Color("715439"))
	_add_text("收到的回信\n%s" % String(row.get("reply", "")),
		Vector2(66, 398), Vector2(348, 100), Color("594731"))
	if _archive_index < archive.size() - 1:
		_button("更早一封", 526, "older", 152, 80)
	if _archive_index > 0:
		_button("更新一封", 526, "newer", 152, 248)
	_button("返回邮驿", 594, "board")

func _add_text(value: String, pos: Vector2, size: Vector2, ink: Color) -> void:
	var label := G.text_label(value, G.FS_SM, ink)
	label.position = pos + _offset
	label.custom_minimum_size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)

func _button(label: String, y: float, action: String, width := 320, x := 80) -> void:
	var button := G.gold_button(label, width, 46, G.FS_SM)
	button.position = Vector2(x, y) + _offset
	button.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_act(action))
	add_child(button)

func _act(action: String) -> void:
	match action:
		"archive": _archive_index = 0
		"older": _archive_index += 1
		"newer": _archive_index -= 1
		"board": _archive_index = -1
		"close":
			_close()
			return
		_:
			action_requested.emit(action)
			_close()
			return
	_build()

func _close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		if _archive_index >= 0:
			_archive_index = -1
			_build()
		else:
			_close()
		get_viewport().set_input_as_handled()
