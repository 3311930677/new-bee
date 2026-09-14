extends Control

onready var dbox = $Top / Panel / HBoxContainer
onready var ybox = $Top / Panel / HBoxContainer2
onready var base_attr = $Bottom / Panel / BaseAttr
onready var attr = $Bottom / Panel / Attr


var CombatManage
var fight_start_data
var icon_res = preload("res://assets/custom/Info-Point.png")


func _ready() -> void :
	CombatManage = Global.get("CombatManage")
	fight_start_data = CombatManage.fight_start_data
	
	clear_container()
	var p_arr = CombatManage.get_player_position()
	var d_arr = CombatManage.get_player_position(false)
	add_item(ybox, p_arr)
	add_item(dbox, d_arr)
	pass

func add_item(container, arr):
	for info in arr:
		if info == null: continue
		var btn = TextureButton.new()
		btn.set_meta("data", info)
		btn.texture_normal = icon_res
		container.add_child(btn)
		btn.connect("pressed", self, "_on_item_click", [info])
	pass

func clear_container():
	for i in dbox.get_children(): i.queue_free()
	for i in ybox.get_children(): i.queue_free()
	pass




func _on_Cancle_pressed() -> void :
	queue_free()

func _on_item_click(info):

	var entity_info = info
	var info_name = ""
	var race_id = - 1
	var grade_level = - 1
	if entity_info["type"] == 1:
		
		info_name = entity_info["data"]["name"]
		pass
	if entity_info["type"] == 2:
		info_name = entity_info["data"]["name"]
		race_id = entity_info["data"]["race_id"]
		
		pass
	if entity_info["type"] == 3:
		
		race_id = entity_info["id"]
		var static_data = Global.get("StaticGameData").get_pet_data(race_id)
		info_name = static_data["race"]
		grade_level = entity_info["data"]["petGradeType"]
		pass
	show_base_attr(entity_info, info_name, grade_level)
	show_attr(entity_info)

func show_base_attr(entity_info, info_name, grade):
	var top_info = str("名称:", info_name)
	if grade != - 1: top_info = str(top_info, ",品级：", grade, "\n")
	var txt = \
\
\
\
\
\
\
	"\n\t最大生命:{max_hp},当前生命:{hp}\n\t最大魔法:{max_hp},当前魔法:{mp}\n\t基础物攻:{physical_atk},基础法攻:{law_atk}\n\t基础物防:{physical_def},基础法防:{law_def}\n\t基础暴击:{crit},基础闪避:{dodge}\n\t基础命中:{hit},基础速度:{shot_speed}\n\t"
	var all_txt = str(top_info, txt)
	base_attr.clear()
	base_attr.append_bbcode(all_txt.format(entity_info["basic_attr"]))
	pass

func show_attr(entity_info):
	var txt = \
\
\
\
\
\
\
	"\n\t最大生命:{max_hp},当前生命:{hp}\n\t最大魔法:{max_hp},当前魔法:{mp}\n\t最终物攻:{physical_atk},最终法攻:{law_atk}\n\t最终物防:{physical_def},最终法防:{law_def}\n\t最终暴击:{crit},最终闪避:{dodge}\n\t最终命中:{hit},最终速度:{shot_speed}\n\t"
	attr.clear()
	attr.append_bbcode(txt.format(entity_info["attr"]))
	pass
