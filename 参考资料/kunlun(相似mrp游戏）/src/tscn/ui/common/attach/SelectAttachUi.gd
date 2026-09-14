extends Control

onready var container = $Background / Background2 / ScrollContainer / VBoxContainer

onready var pet_item_res = preload("res://src/tscn/ui/map/pet/PetLabelItem.tscn")
onready var prop_item_res = preload("res://src/tscn/ui/common/bag/ProLabelItem.tscn")
onready var popup_menu_edit = preload("res://src/tscn/ui/common/dialog/PopupPanel.tscn")

var checked_node = null
var show_bind = false
var ScreenUtils
var BagInfoManage
var PetInfoManage

var bag_data
var pet_data
var tab_mode = 0

var result_node
var result_func

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	BagInfoManage = Global.get("BagInfoManage")
	PetInfoManage = Global.get("PetInfoManage")
	BagInfoManage.connect("_bag_data_update_", self, "_on_bag_data_result")
	PetInfoManage.connect("loaded_all_list_pets", self, "_on_loaded_all_list_pets_result")
	pass
func _item_click(node):
	if node == checked_node:
		_on_Ok_pressed()
		return
	checked_node = node

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_ZongTab_tab_click(node) -> void :
	tab_mode = 0
	_on_bag_data_result()
	pass


func _on_QuTab_tab_click(node) -> void :
	tab_mode = 1
	_on_loaded_all_list_pets_result()
	pass

func _on_menu_edit_result(id, txt_num):
	var num = int(txt_num)
	if num <= 0:
		ScreenUtils.show_message("数量不合法")
		return
	if num > checked_node.data.get("count", 1):
		ScreenUtils.show_message("数量超过持有数量")
		return
	
	
	if result_node != null:
		result_node.call(result_func, checked_node.data, num)
	queue_free()


func _on_Ok_pressed() -> void :
	var all_num = checked_node.data.get("count", 1)
	if all_num == 1:
		_on_menu_edit_result(0, 1)
	else:
		ScreenUtils.show_popup_menu_edit(self, "_on_menu_edit_result", 0, "请输入附件数量:")

func _on_bag_data_result():
	clear_container()
	bag_data = Global.get("BagInfoManage").get_all_bag_datas()
	if tab_mode == 0:
		reload_bag_data()
	else:
		reload_pet_data()
	show()
	pass

func _on_loaded_all_list_pets_result():
	pet_data = Global.get("PetInfoManage").list_all_pets
	clear_container()
	if tab_mode == 0:
		reload_bag_data()
	else:
		reload_pet_data()
	show()
	pass

func load_data(data):
	hide()
	BagInfoManage.request_bag_data()
	PetInfoManage.request_data(true, false)
	pass


func reload_bag_data():
	if prop_item_res == null: return
	var list_datas = bag_data
	for item_data in list_datas:
		
		if item_data.get("bind", 1) == 1 and not show_bind: continue
		
		var item = prop_item_res.instance()
		item.connect("item_click", self, "_item_click")
		container.add_child(item)
		item.set_data(item_data)

func reload_pet_data():
	if pet_item_res == null: return
	var list_datas = pet_data
	for item_data in list_datas:
		
		if item_data.get("bind", 1) == 1 and not show_bind: continue
		var item = pet_item_res.instance()
		item.connect("item_click", self, "_item_click")
		container.add_child(item)
		item.set_data(item_data)
	
func clear_container():
	for i in $Background / Background2 / ScrollContainer / VBoxContainer.get_children():
		i.queue_free()

func set_result_node(node):
	result_node = node
func set_result_func(fun):
	result_func = fun
