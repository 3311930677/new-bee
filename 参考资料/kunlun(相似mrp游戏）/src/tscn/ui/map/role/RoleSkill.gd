extends Panel

onready var vbox = $Background / Background2 / ScrollContainer / VBoxContainer

var ScreenUtils
var RoleInfoManage
var StaticGameData

var item_res = preload("res://src/tscn/ui/common/player/RoleSkillItem.tscn")
var skill_id_s = []
var skill_checked_item = null
func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	StaticGameData = Global.get("StaticGameData")
	RoleInfoManage.connect("role_info_result", self, "_on_role_info_result")
	

func _on_role_info_result(data):
	clear_skill_item()
	skill_id_s.clear()
	skill_id_s.append_array(data["skills"])
	
	for sk_id in skill_id_s:
		var item = item_res.instance()
		vbox.add_child(item)
		item.set_skill_id(sk_id)
		item.connect("item_click", self, "skill_item_click")
	pass

func clear_skill_item():
	for item in vbox.get_children():
		item.queue_free()

func skill_item_click(node):
	if skill_checked_item == node:
		_on_Ok_pressed()
		return
	skill_checked_item = node


func _on_Ok_pressed() -> void :
	
	ScreenUtils.show_message_plus(skill_checked_item.get_skill_desc())
