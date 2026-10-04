extends Control
signal closed
const Oaths := preload("res://src/world/OathService.gd")
var _line:Label

func _ready()->void:
	G.center_fixed_page.call_deferred(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	G.veil(self,.84)
	var paper:=G.parchment_box(440,690,16)
	paper.position=Vector2(20,55)
	add_child(paper)
	var content:=Control.new()
	paper.add_child(content)
	var title:=G.serif_label("守碑出行誓约",G.FS_LG,G.TEXT_DARK)
	content.add_child(title)
	_line=G.text_label("三誓约可换；本图当日已锁定的誓约不会随切换重置。每张野外图每日一个目标，报酬不含剧情首通物。",G.FS_SM,G.TEXT_DARK)
	_line.position=Vector2(0,45)
	_line.custom_minimum_size=Vector2(408,96)
	_line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var current:=Oaths.row(String(Oaths.state(G).get("current","")))
	if not current.is_empty(): _line.text="当前：%s。"%String(current.name)+_line.text
	content.add_child(_line)
	for i in Oaths.rows().size():
		var row:Dictionary=Oaths.rows()[i]
		var button:=G.gold_button(String(row.name)+" · 立约",220,44,G.FS_SM)
		button.position=Vector2(0,153+i*140)
		button.gui_input.connect(func(e:InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
				var map_id:=String(G.prog.get("main_world",{}).get("map_id","lorin_wilds"))
				_line.text=String(Oaths.choose(G,String(row.id),map_id).line))
		content.add_child(button)
		var rewards:Array=[]
		for key in row.reward: rewards.append("%s × %d"%[G.item_name(String(key).trim_prefix("item:")),int(row.reward[key])])
		var unlocked:=bool(G.prog.get("flags",{}).get("oath_pattern_"+String(row.id),false))
		var seal:=preload("res://src/ui/OathPattern.gd").new()
		seal.oath_id=String(row.id)
		seal.earned=unlocked
		seal.position=Vector2(298,142+i*140)
		content.add_child(seal)
		var desc:=G.text_label(String(row.desc)+"\n"+("已记" if unlocked else "可得")+String(row.record)+" · "+" / ".join(rewards),G.FS_SM,G.TEXT_DARK)
		desc.position=Vector2(0,204+i*140)
		desc.custom_minimum_size=Vector2(408,80)
		desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc)
	var back:=G.ghost_button("返回",160,44)
	back.position=Vector2(124,605)
	back.gui_input.connect(func(e:InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:closed.emit())
	content.add_child(back)

func _unhandled_input(e:InputEvent)->void:
	if not G.ui_blocked and e.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
