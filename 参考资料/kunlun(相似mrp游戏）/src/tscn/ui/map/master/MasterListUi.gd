extends Control

onready var box = $Background / Background2 / ScrollContainer / VBoxContainer
onready var menu = $Control / PopupMenu

var item_res = preload("res://src/tscn/ui/common/master/MasterListItem.tscn")

var MasterDataManage
var ScreenUtils
var PlayerOperate
var RoleInfoManage

var check_node = null
var dic_menu = {
	"1": "查看信息", 
	"2": "查看宠物", 
}
func _ready():
	MasterDataManage = Global.get("MasterDataManage")
	ScreenUtils = Global.get("ScreenUtils")
	PlayerOperate = Global.get("PlayerOperate")
	RoleInfoManage = Global.get("RoleInfoManage")
	MasterDataManage.connect("master_list_loaded", self, "_on_master_list_data_loaded")
	hide()
	MasterDataManage.getMasterListData()
	pass

func _on_master_list_data_loaded(data):
	clear_container()
	for i in data:
		var item = item_res.instance()
		box.add_child(item)
		item.connect("item_click", self, "_on_item_click")
		item.set_data(i)
	show()
	pass

func _on_item_click(node):
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node
	pass
func _on_Ok_pressed():
	if check_node == null:
		return
	if int(check_node.data["id"]) == int(RoleInfoManage.get_role_id()): return
	
	ScreenUtils.build_menu(menu, dic_menu)
	menu.popup_centered()


func _on_Cancle_pressed():
	queue_free()


func _on_PopupMenu_index_pressed(index):
	var id = menu.get_item_id(index)
	PlayerOperate.current_player_info = check_node.data
	PlayerOperate.menu_item_click(id)

func clear_container():
	for i in box.get_children():
		i.queue_free()
	pass
