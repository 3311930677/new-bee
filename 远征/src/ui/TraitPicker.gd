# TraitPicker.gd —— 战斗胜利词条三选一（玩法文档 §2.4；阶段 2.4）
# 三卡横排：槽1 数值/机制（银/蓝带）· 槽2 流派85%或双刃15%（紫/红带）· 槽3 全池；
# 卡组含双刃时显示"放弃"（双刃可选不选——复杂度不作难度）。
# 素材（ui_panel_card/frame_* ×4/school_* ×6）入库后热替换卡片绘制。
class_name TraitPicker
extends Control

signal picked(tid: String)  # 选中的词条 id；"" = 放弃

const VIEW_W := 480.0
const TYPE_META := {  # type → [类别名, 色带]
	"num": ["数值", Color("c9c9c9")],
	"mech": ["机制", Color("6a9ad0")],
	"link": ["流派", Color("9a6ad0")],
	"double": ["双刃", Color("d05a4a")],
}
const SCHOOL_NAME := {
	"bleed": "流血", "crit": "暴击", "thorn": "反伤",
	"control": "控制", "energy": "能量", "summon": "召唤",
}

var choices: Array = []


func setup(rows: Array) -> void:
	choices = rows
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var title := G.serif_label("选择一份祝福", G.FS_BIG, Color("ffd9a0"))
	title.position = Vector2(0, 140)
	title.custom_minimum_size = Vector2(VIEW_W, 0)
	add_child(title)

	var cw := 138.0
	var gap := 16.0
	for i in mini(3, choices.size()):
		var card := _make_card(choices[i])
		card.position = Vector2(17.0 + float(i) * (cw + gap), 250.0)
		add_child(card)

	# 双刃可选不选：卡组含双刃时提供放弃
	var has_double := false
	for r in choices:
		if String((r as Dictionary).get("type", "")) == "double":
			has_double = true
	if has_double:
		var skip := G.gold_button("放 弃", 160, 42)
		skip.position = Vector2(160, 560)
		skip.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_emit_pick(""))
		add_child(skip)


func _make_card(row: Dictionary) -> Control:
	var t := String(row.get("type", "num"))
	var meta: Array = TYPE_META.get(t, ["？", Color.GRAY])
	var root := Control.new()
	root.custom_minimum_size = Vector2(138, 230)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := G.parchment_box(138, 230, 12.0)
	root.add_child(panel)

	# 类别色带：右端斜切，避免齐刷刷的矩形模板感
	var band := Polygon2D.new()
	band.color = meta[1]
	band.polygon = PackedVector2Array([
		Vector2(10, 10), Vector2(128, 10), Vector2(120, 15), Vector2(10, 15),
	])
	root.add_child(band)

	var school := String(row.get("school", "none"))
	var tag: String = "%s · %s" % [String(meta[0]), SCHOOL_NAME.get(school, "通用")] \
		if school != "none" else String(meta[0])
	var tag_l := G.gold_label(tag, G.FS_XS, false, meta[1], false)
	tag_l.position = Vector2(10, 18)
	root.add_child(tag_l)

	var name_l := G.serif_label(String(row.get("name", "")), G.FS_MD, Color("5a3a1e"))
	name_l.position = Vector2(10, 40)
	root.add_child(name_l)

	var line := ColorRect.new()
	line.color = Color(0.55, 0.42, 0.24, 0.5)
	line.position = Vector2(10, 70)
	line.size = Vector2(118, 1)
	root.add_child(line)

	var desc_l := G.gold_label(String(row.get("desc", "")), G.FS_SM, false, Color("7a5a2e"), false)
	desc_l.position = Vector2(10, 80)
	desc_l.size = Vector2(118, 140)
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(desc_l)

	var tid := String(row.get("id", ""))
	var base_y := 0.0
	root.ready.connect(func(): base_y = root.position.y)
	root.mouse_entered.connect(func():
		var tw := root.create_tween()
		tw.tween_property(root, "position:y", base_y - 6.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT))
	root.mouse_exited.connect(func():
		var tw := root.create_tween()
		tw.tween_property(root, "position:y", base_y, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT))
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_emit_pick(tid))
	return root


func _emit_pick(tid: String) -> void:
	picked.emit(tid)
	queue_free()
