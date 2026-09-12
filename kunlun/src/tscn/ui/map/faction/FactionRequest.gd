extends Control

onready var box = $"Background/Background2/ScrollContainer/VBoxContainer"

var item_res = preload("res://src/tscn/ui/common/player/PlayerLabelItem.tscn")

var ScreenUtils
var FactionInfoManage

var check_node

func load_data(data):
	var info = FactionInfoManage.current_member_info
	
	if info != null and info.get("member_type", 3) < 3:
		hide()
		
		FactionInfoManage.get_requested_join()
	else:
		clear_container()
	pass

func clear_container():
	for i in box.get_children():
		i.queue_free()

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	FactionInfoManage = Global.get("FactionInfoManage")

	FactionInfoManage.connect("faction_member_request_list_loaded", self, "_on_faction_member_request_list_loaded")
	pass

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_Ok_pressed() -> void :
	$Control / PopupMenu.popup_centered()

func _item_click(node):
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node
	pass


func _on_faction_member_request_list_loaded(data):
	clear_container()
	show()
	for i in data:
		var item = item_res.instance()
		item.connect("item_click", self, "_item_click")
		box.add_child(item)
		item.set_data(i)
	pass
	


func _on_PopupMenu_index_pressed(index: int) -> void :
	if index == 0:
		
		Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/role/RoleUi.tscn", "load_data", {"role_type": check_node.data["role_id"]})
		pass
	elif index == 1:
		
		FactionInfoManage.agree_and_inject_faction(check_node.data["id"], check_node.data["faction_id"], 1)
		check_node.queue_free()
		pass
	elif index == 2:
		
		FactionInfoManage.agree_and_inject_faction(check_node.data["id"], check_node.data["faction_id"], 0)
		check_node.queue_free()
		pass
	pass
