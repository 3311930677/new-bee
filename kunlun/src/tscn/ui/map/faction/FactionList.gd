extends Control


onready var box = $"Background/Background2/ScrollContainer/VBoxContainer"

var item_res = preload("res://src/tscn/ui/common/faction/FactionListItem.tscn")

var ScreenUtils
var FactionInfoManage

var check_node

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	FactionInfoManage = Global.get("FactionInfoManage")
	FactionInfoManage.connect("faction_list_loaded", self, "_faction_list_loaded")
	pass

func load_data(data):
	
	FactionInfoManage.get_faction_list()
	hide()
	pass

func clear_container():
	for i in box.get_children():
		i.queue_free()


func _faction_list_loaded(faction_list):
	clear_container()
	var index = 1
	for i in faction_list:
		var item = item_res.instance()
		i["index"] = index + 0
		item.set_meta("data", i)
		item.connect("item_click", self, "_item_click")
		box.add_child(item)
		index += 1
	show()


func _item_click(node):
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node
	pass

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_Ok_pressed() -> void :
	$Control / PopupMenu.popup_centered()
	pass


func _on_PopupMenu_index_pressed(index: int) -> void :
	if check_node == null: return
	if index == 0:
		Global.log_info(str("查看信息", check_node.get_meta("data")))
		ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/faction/FactionInfo.tscn", "load_data", check_node.get_meta("data"))
	elif index == 1:
		var info = check_node.get_meta("data")
		ScreenUtils.show_message("确定加入:%s帮派？" % info["name"], self, "_pressed_join_ok")
		
		Global.log_info(str("申请入帮"))
		pass
	

func _pressed_join_ok():
	var info = check_node.get_meta("data")
	FactionInfoManage.request_join_faction(info["id"])
