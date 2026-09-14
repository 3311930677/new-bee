extends Control

class_name MemoUi

var item_tscn = preload("res://src/tscn/ui/map/memo/memoItem.tscn")
var MemoManage
var ScreenUtils


var cur_item
var cur_memo_type = 1

var menu1 = {
	"0": "立即过去", 
	"1": "查看详情", 
	"2": "取消"
}

var menu2 = {
	"0": "立即过去", 
	"2": "取消"
}

var StaticGameData
var MapInfoManage


func _ready():
	clear($content / Background2 / task / VBoxContainer)
	clear($content / Background2 / activity / VBoxContainer)
	clear($content / Background2 / duplicate / VBoxContainer)
	clear($content / Background2 / other / VBoxContainer)
	
	MemoManage = Global.get("MemoManage")
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	MapInfoManage = Global.get("MapInfoManage")
	
	MemoManage.set_memo_ui(self)
	MemoManage.load_memo_data()
	MapInfoManage.connect("map_change_success", self, "_on_change_sucees")
	
	$Head / menus / HBoxContainer / taskbtn.connect("tab_click", self, "show_task")
	$Head / menus / HBoxContainer / activitybtn.connect("tab_click", self, "show_activity")
	$Head / menus / HBoxContainer / duplicatebtn.connect("tab_click", self, "show_duplicate")
	$Head / menus / HBoxContainer / other.connect("tab_click", self, "show_other")

	

func show_task(tab):
	cur_memo_type = 1
	$content / Background2 / task.show()
	$content / Background2 / activity.hide()
	$content / Background2 / duplicate.hide()


func show_activity(tab):
	cur_memo_type = 2
	$content / Background2 / task.hide()
	$content / Background2 / activity.show()
	$content / Background2 / duplicate.hide()


func show_duplicate(tab):
	cur_memo_type = 3
	$content / Background2 / task.hide()
	$content / Background2 / activity.hide()
	$content / Background2 / duplicate.show()


func show_other(tab):
	$content / Background2 / task.hide()
	$content / Background2 / activity.hide()
	$content / Background2 / duplicate.hide()


func load_data(data: Dictionary):
	clear($content / Background2 / task / VBoxContainer)
	clear($content / Background2 / activity / VBoxContainer)
	clear($content / Background2 / duplicate / VBoxContainer)
	
	
	var taskList = data["taskList"]
	var activityList = data["activityList"]
	var duplicateList = data["duplicateList"]
	
	addItems($content / Background2 / task / VBoxContainer, taskList, "show_menu1")
	addItems($content / Background2 / activity / VBoxContainer, activityList, "show_menu1")
	addItems($content / Background2 / duplicate / VBoxContainer, duplicateList, "show_menu1")


func clear(node):
	for child in node.get_children():
		child.queue_free()
		

func addItems(node, list, click_fun):
	for item_data in list:
		var item = item_tscn.instance()
		item.level = item_data["level"]
		item.name = item_data["name"]
		item.star = item_data["star"]
		item.set_id(item_data["id"])
		item.npc_id = item_data["npc_id"]
		
		
		node.add_child(item)
		
		item.connect("item_click", self, click_fun)
		
func show_menu1(item):
	cur_item = item

	ScreenUtils.build_menu($SelectMenu / PopupMenu, menu1)
	$SelectMenu / PopupMenu.popup_centered()
	
func _on_Ok_pressed():
	pass


func _on_Cancle_pressed():
	queue_free()


func show_info(data):
	pass


func _on_PopupMenu_index_pressed(index):
	var id = $SelectMenu / PopupMenu.get_item_id(index)
	
	match id:
		0:
			var npc_id = cur_item.npc_id
			var npc_data
			if cur_memo_type == 1:
				npc_data = StaticGameData.get_npc_id_data(npc_id)
			else:
				npc_data = StaticGameData.get_npc_data(npc_id)
			
			MapInfoManage.change_map_to_npc(npc_data)
			
			pass
		1:
			MemoManage.get_memo_info(cur_memo_type, cur_item.id)
			pass
		2:
			$SelectMenu.hide()
		
func _on_change_sucees(map_id):
	queue_free()
			
