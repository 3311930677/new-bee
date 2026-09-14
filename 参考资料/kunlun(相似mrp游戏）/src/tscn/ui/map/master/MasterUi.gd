extends Control

onready var box = $Background / Background2 / ScrollContainer / VBoxContainer
onready var menu = $Control / PopupMenu
onready var title = $Head / XQTitle

onready var item_res = preload("res://src/tscn/ui/common/master/MasterItem.tscn")
var ScreenUtils
var MasterDataManage
var PlayerOperate
var RoleInfoManage

var register_type = 0

var page0 = 0
var page1 = 0

var size = 10

var load_finish_type0 = false
var load_finish_type1 = false

var list_data_type0 = []
var list_data_type1 = []

var check_node = null

var dic_menu_type0 = {
	"1": "查看信息", 
	"2": "查看宠物", 
	"7": "拜师"
}

var dic_menu_type1 = {
	"1": "查看信息", 
	"2": "查看宠物", 
	"8": "收徒"
}

func clear_container():
	for i in box.get_children():
		i.queue_free()


func add_arr(arr):
	for i in arr:
		var item = item_res.instance()
		box.add_child(item)
		item.connect("item_click", self, "_on_item_click")
		item.set_data(i)

func _ready():
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	MasterDataManage = Global.get("MasterDataManage")
	PlayerOperate = Global.get("PlayerOperate")
	
	MasterDataManage.connect("master_register_list_loaded", self, "_on_master_register_list_loaded")
	pass

func _on_item_click(node):
	if node == check_node:
		_on_Ok_pressed()
		return
	check_node = node
	pass


func _on_Cancle_pressed():
	queue_free()


func _on_Ok_pressed():
	if check_node == null: return
	
	var dic_menu = dic_menu_type0
	if register_type == 1:
		dic_menu = dic_menu_type1
	if int(check_node.data["id"]) == int(RoleInfoManage.get_role_id()): return
	ScreenUtils.build_menu(menu, dic_menu)
	menu.popup_centered()


func _on_LoadMore_pressed():
	if register_type == 0 and load_finish_type0:
		ScreenUtils.show_message("已经没有更多数据了")
		return
	if register_type == 1 and load_finish_type1:
		ScreenUtils.show_message("已经没有更多数据了")
		return
	var page = 1
	if register_type == 0:
		page0 += 1
		page = page0
	else:
		page1 += 1
		page = page1
	
	
	Global.get("MasterDataManage").getMasterRegisterListData(register_type, page, size)
	pass


func _on_master_register_list_loaded(data):
	var a = []
	if register_type == 0:
		if data.size() <= 0:
			load_finish_type0 = true
		else:
			list_data_type0.append_array(data)
	if register_type == 1:
		if data.size() <= 0:
			load_finish_type1 = true
		else:
			list_data_type1.append_array(data)
	add_arr(data)
	pass


func _on_PopupMenu_index_pressed(index):
	var id = menu.get_item_id(index)
	
	PlayerOperate.current_player_info = check_node.data
	
	PlayerOperate.menu_item_click(id)
	
	pass


func _on_MasterTab_tab_click(node):
	if register_type != 0:
		clear_container()
		add_arr(list_data_type0)
	register_type = 0
	if list_data_type0.empty():
		if not load_finish_type0:
			_on_LoadMore_pressed()
		pass


func _on_ApprenticeTab_tab_click(node):
	if register_type != 1:
		clear_container()
		add_arr(list_data_type1)
	register_type = 1
	if list_data_type1.empty():
		if not load_finish_type1:
			_on_LoadMore_pressed()
		pass
