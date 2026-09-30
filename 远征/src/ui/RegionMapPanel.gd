# RegionMapPanel.gd —— 主世界地区图；地图连线与历练随机路线严格分开。
class_name RegionMapPanel
extends Control

signal closed

const VIEW_W := 480.0
const VIEW_H := 800.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	G.veil(self, 0.72, true)
	var banner := G.banner_box("地区行路图", 260, 46)
	banner.position = Vector2((VIEW_W - 260.0) * 0.5, 53)
	add_child(banner)
	var panel := G.parchment_box(420, 555, 18.0)
	panel.position = Vector2(30, 122)
	add_child(panel)
	var content := Control.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var hint := G.gold_label("沿地图出口步行前往；亮金节点是当前位置", G.FS_XS,
		false, G.TEXT_DARK, false)
	hint.position = Vector2(4, 6)
	hint.size = Vector2(376, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 46)
	scroll.size = Vector2(372, 325)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(scroll)
	var graph := _RegionGraph.new()
	graph.custom_minimum_size = Vector2(900, 470)
	scroll.add_child(graph)
	var cfg := TableCache.main_world_config()
	var rows: Variant = cfg.get("regions", [])
	if rows is Array:
		graph.setup(rows as Array)
		scroll.set_deferred("scroll_horizontal", int(maxf(0, graph.current_point.x - 180)))
		scroll.set_deferred("scroll_vertical", int(maxf(0, graph.current_point.y - 150)))
	var cur: Variant = G.prog.get("main_world", {})
	var map_id := String((cur as Dictionary).get("map_id", "lorin_wilds")) \
		if cur is Dictionary else "lorin_wilds"
	var current_name := String(TableCache.main_world_map(map_id).get("name", "昭元边城"))
	var current := G.gold_label("当前位置 · %s" % current_name, G.FS_SM,
		true, G.TEXT_DARK, false)
	current.position = Vector2(24, 388)
	current.size = Vector2(342, 28)
	content.add_child(current)
	var archive_note := "拖动滚动条查看地区，沿路牌步行切图。\n界碑历练可从边城巡界厅进入。"
	if bool((G.prog.get("flags", {}) as Dictionary).get("act1_stele_repaired", false)):
		var method := String(G.act1_state().get("repair_method", ""))
		var method_note := "石头锻稳铁扣，北路已经重新通行。" if method == "forge" else \
			"青姨拓出旧路标，北路已经重新通行。"
		archive_note = "图志新录 · %s。\n%s" % [G.restored_stele_name(), method_note]
	var note := G.text_label(archive_note,
		G.FS_XS, G.TEXT_DARK)
	note.position = Vector2(24, 421)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size = Vector2(342, 46)
	content.add_child(note)
	var back := G.gold_button("返 回", 150, 42, G.FS_SM)
	back.position = Vector2(117, 475)
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	content.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if G.ui_blocked:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


class _RegionGraph extends Control:
	var _rows: Array = []
	var _current := ""
	var current_point := Vector2.ZERO

	func setup(rows: Array) -> void:
		_rows = rows
		var cur: Variant = G.prog.get("main_world", {})
		_current = String((cur as Dictionary).get("map_id", "")) if cur is Dictionary else ""
		for row_v in rows:
			if not (row_v is Dictionary):
				continue
			var row := row_v as Dictionary
			var point: Variant = row.get("point", [])
			if not (point is Array) or (point as Array).size() < 2:
				continue
			var pos := Vector2(float(point[0]), float(point[1]))
			custom_minimum_size = Vector2(maxf(custom_minimum_size.x, pos.x + 100),
				maxf(custom_minimum_size.y, pos.y + 70))
			var id := String(row.get("id", ""))
			if id == _current:
				current_point = pos
			var name := String(row.get("name", id))
			var button := G.gold_button(name, 142, 36, G.FS_SM) if id == _current \
				else G.ghost_button(name, 142, 36, G.FS_SM)
			button.position = pos - Vector2(71, 18)
			button.gui_input.connect(func(e: InputEvent):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					var info := TableCache.main_world_map(id)
					var levels: Array = row.get("level", [1, 12])
					G.show_info_popup(button, name, [
						"%s · 建议 Lv%d–%d" % [String(row.get("kind", "地区")),
							int(levels[0]), int(levels[1])],
						String(info.get("goal", "沿道路探索")),
						"请从相邻地图的路牌进入。",
					]))
			add_child(button)
			var levels: Array = row.get("level", [1, 12])
			var lv := G.gold_label("Lv%d–%d" % [int(levels[0]), int(levels[1])],
				G.FS_XS, false, G.TEXT_DARK, false)
			lv.position = pos + Vector2(-72, 21)
			lv.size = Vector2(144, 20)
			lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(lv)
		queue_redraw()

	func _draw() -> void:
		var positions: Dictionary = {}
		for row_v in _rows:
			if row_v is Dictionary:
				var row := row_v as Dictionary
				var p: Variant = row.get("point", [])
				if p is Array and (p as Array).size() >= 2:
					positions[String(row.get("id", ""))] = Vector2(float(p[0]), float(p[1]))
		var seen: Dictionary = {}
		for id in positions:
			var map_cfg := TableCache.main_world_map(String(id))
			for exit_v in map_cfg.get("exits", []):
				if not (exit_v is Dictionary):
					continue
				var to := String((exit_v as Dictionary).get("to", ""))
				if not positions.has(to):
					continue
				var key := "%s|%s" % [mini(String(id).hash(), to.hash()),
					maxi(String(id).hash(), to.hash())]
				if seen.has(key):
					continue
				seen[key] = true
				draw_line(positions[id], positions[to], Color("95784e"), 7.0)
				draw_line(positions[id], positions[to], Color("e1c88a"), 3.0)
