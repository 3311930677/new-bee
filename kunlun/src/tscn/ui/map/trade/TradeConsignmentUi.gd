extends Control


onready var prop_item_res = preload("res://src/tscn/ui/common/bag/ProLabelItem.tscn")

onready var pet_item_res = preload("res://src/tscn/ui/map/pet/PetLabelItem.tscn")

onready var menu = $"Control/PopupMenu"
onready var tab_box = $Head / Tabs / HBoxContainer

onready var container = $"Background/Background2/ScrollContainer/VBoxContainer"


onready var bag_capacity = $"Head/Tabs/Fac/FacNum"

onready var trade_capacity = $"Head/Tabs/Panel3/BagNum"

onready var edit = $Edit

var ScreenUtils
var BagInfoManage
var StaticGameData
var TradeInfoManage

var commom_dic = {
	"1": "寄卖物品", 
	"2": "查看详情"
}
var pets = []
var arts = []
var equis = []
var gems = []
var sell_num = 1
var click_index = 0
var check_node = null

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	BagInfoManage = Global.get("BagInfoManage")
	StaticGameData = Global.get("StaticGameData")
	TradeInfoManage = Global.get("TradeInfoManage")
	BagInfoManage.connect("_bag_data_update_", self, "_on_bag_data_update")
	BagInfoManage.connect("_bagpackdata_num_change_", self, "_bagpackdata_num_change_")
	TradeInfoManage.connect("put_consignment_success", self, "_on_put_consignment_success")
	for i in tab_box.get_children():
		i.connect("tab_click", self, "_on_tab_click")
	BagInfoManage.request_all_data(true)
	hide()


func reload():
	clear_container()
	bag_capacity.text = str("背包容量\n(%d/%d)" % [BagInfoManage.get_bag_amount(), BagInfoManage.get_bag_max_amount()])
	trade_capacity.text = str("寄卖容量\n(%d/%d)" % [BagInfoManage.get_trade_capacity(), BagInfoManage.get_trade_max_capacity()])
	if click_index == 0:
		var load_lis = []
		load_lis.append_array(arts)
		load_lis.append_array(equis)
		load_lis.append_array(gems)
		_private_load_art(load_lis)
	elif click_index == 1:
		_private_load_art(arts)
	elif click_index == 2:
		_private_load_art(equis)
	elif click_index == 3:
		_private_load_pet(pets)
		pass
		
	pass

func clear_container():
	for i in container.get_children():
		i.queue_free()
	pass


func _item_click(node):
	if node == check_node:
		_on_Ok_pressed()
		return
	check_node = node
	pass



func _private_load_pet(items):
	for i in items:
		if i.get("bind", 0) == 1: continue
		var item = pet_item_res.instance()
		container.add_child(item)
		item.connect("item_click", self, "_item_click")
		item.set_data(i)
	pass


func _private_load_art(items):
	for item_data in items:
		if item_data.get("bind", 0) == 1: continue
		var item = prop_item_res.instance()
		item.connect("item_click", self, "_item_click")
		container.add_child(item)
		item.set_data(item_data)
	pass



func _on_tab_click(node):
	click_index = node.tab_index
	reload()

func _on_Cancle_pressed() -> void :
	queue_free()

func _on_bag_data_update():
	
	pets = BagInfoManage.get_all_pets()
	arts = BagInfoManage.get_arts()
	equis = BagInfoManage.get_equs()
	gems = BagInfoManage.get_gems()
	reload()
	show()
	pass


func _on_Ok_pressed() -> void :
	ScreenUtils.build_menu(menu, commom_dic)
	menu.popup_centered()
	pass


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = int(menu.get_item_id(index))
	var data = check_node.data
	
	var item_type = 5
	if data.has("pet_race_id"):
		data["item_type"] = 2
	elif data.has("u_id"):
		data["item_type"] = 1
	item_type = int(data["item_type"])

	if id == 1:
		
		edit.show_pop()
		Global.log_info(str("寄卖弹窗，数量是1的就直接弹出寄卖的类型"))
		pass
	else:
		
		if item_type == 2:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/pet/PetUi.tscn", "load_data", {"pet_type": 1, "id": check_node.data["id"]})
			pass
		elif item_type == 3:
			BagInfoManage.get_equipment_details(check_node.data["id"])
			pass
		elif item_type == 4 or item_type == 5:
			StaticGameData.show_art_data_info(check_node.get_details())
			pass


func _on_Edit_edit_sucess(dic) -> void :
	Global.log_info(dic)
	var data = check_node.data
	var hold_id = data["id"]
	var item_type = data["item_type"]
	var num = dic["con_num"]
	var coin_type = dic["coin_type"]
	var coin_num = dic["price_num"]
	sell_num = num
	TradeInfoManage.put_consignment(hold_id, item_type, num, coin_num, coin_type)



func _on_put_consignment_success():
	ScreenUtils.show_message("寄卖成功")
	check_node.data["count"] = check_node.data.get("count", 1) - sell_num
	check_node._on_reload_data()

func _bagpackdata_num_change_():
	reload()
	pass
