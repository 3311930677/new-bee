extends Control
signal closed
const Oaths := preload("res://src/world/OathService.gd")
var _line: Label

func _ready() -> void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	G.veil(self, 0.84)
	var paper := G.parchment_box(444, 684, 16)
	paper.set_meta("dark_frame", true)
	paper.position = Vector2(18, 58)
	add_child(paper)
	var content := Control.new()
	paper.add_child(content)
	var plaque := G.Visuals.header_plaque("守碑出行誓约", 354.0, 38.0)
	plaque.position = Vector2(48, -4)
	content.add_child(plaque)
	G.top_back_button(content, func(): closed.emit(), Vector2(-4, -7))
	_line = G.text_label("三誓约可换；本图当日已锁定的誓约不会随切换重置。每张野外图每日一个目标，报酬不含剧情首通物。", G.FS_XS, Color("c9a45c"))
	_line.position = Vector2(8, 42)
	_line.custom_minimum_size = Vector2(396, 56)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var current_id := String(Oaths.state(G).get("current", ""))
	var current := Oaths.row(current_id)
	if not current.is_empty():
		_line.text = "当前：%s。" % String(current.name) + _line.text
	content.add_child(_line)
	var card_y := 102.0
	for i in Oaths.rows().size():
		var row: Dictionary = Oaths.rows()[i]
		var is_cur := String(row.id) == current_id
		var rewards: Array = []
		for key in row.reward:
			rewards.append("%s × %d" % [G.item_name(String(key).trim_prefix("item:")), int(row.reward[key])])
		var unlocked := bool(G.prog.get("flags", {}).get("oath_pattern_" + String(row.id), false))
		var desc := G.text_label(String(row.desc) + "\n" + ("已记" if unlocked else "可得") + String(row.record) + " · " + " / ".join(rewards), G.FS_SM, G.TEXT_DARK)
		desc.position = Vector2(14, card_y + 58.0)
		desc.custom_minimum_size = Vector2(380, 82.0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var card_h := 150.0
		content.add_child(G.Visuals.parchment_subcard(Vector2(-2, card_y), Vector2(416, card_h)))
		var btn_label := String(row.name) + (" · 已立约" if is_cur else " · 立约")
		var button := G.gold_button(btn_label, 224, 44, G.FS_SM) if not is_cur else G.ghost_button(btn_label, 224, 44, G.FS_SM)
		button.position = Vector2(12, card_y + 8.0)
		button.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var map_id := String(G.prog.get("main_world", {}).get("map_id", "lorin_wilds"))
				_line.text = String(Oaths.choose(G, String(row.id), map_id).line))
		content.add_child(button)
		var seal := preload("res://src/ui/OathPattern.gd").new()
		seal.oath_id = String(row.id)
		seal.earned = unlocked
		seal.position = Vector2(302, card_y + 6.0)
		content.add_child(seal)
		content.add_child(desc)
		card_y += card_h + 10.0
	var total_h := clampf(card_y + 24.0, 580.0, 684.0)
	paper.custom_minimum_size = Vector2(444, total_h)
	paper.size = paper.custom_minimum_size
	paper.position = Vector2(18, roundf((800.0 - total_h) * 0.5))

func _unhandled_input(e: InputEvent) -> void:
	if not G.ui_blocked and e.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
