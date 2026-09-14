extends Control

onready var menu = $Control / PopupMenu


onready var container = $"Background/Background2/ScrollContainer/VBoxContainer"


onready var bag_capacity = $"Head/Tabs/Fac/FacNum"

onready var trade_capacity = $"Head/Tabs/Panel3/BagNum"


onready var item_res = preload("res://src/tscn/ui/common/trade/TradeItem.tscn")

var ScreenUtils
var TradeInfoManage
var BagInfoManage
var StaticGameData
var check_node = null


var dic_data = {
	"1": "取回寄卖", 
	"2": "查看详情"
}

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	TradeInfoManage = Global.get("TradeInfoManage")
	StaticGameData = Global.get("StaticGameData")
	BagInfoManage = Global.get("BagInfoManage")
	BagInfoManage.connect("_bagpackdata_num_change_", self, "_bagpackdata_num_change_")
	TradeInfoManage.connect("self_consignment_success", self, "_on_self_consignment_add")
	TradeInfoManage.connect("take_consignment_success", self, "_on_take_consignment_success")
	TradeInfoManage.get_self_consignemnt()
	clear_container()
	reload()
	hide()


func _on_self_consignment_add(listData):
	show()
	for item_ in listData:
		var item = item_res.instance()
		container.add_child(item)
		item.connect("item_click", self, "_item_click")
		item.set_data(item_)

func _item_click(node):
	if node == check_node:
		_on_Ok_pressed()
		return
	check_node = node

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_Ok_pressed() -> void :
	ScreenUtils.build_menu(menu, dic_data)
	menu.popup_centered()
	pass


func _on_take_consignment_success():
	if check_node != null:
		check_node.queue_free()
	check_node = null
	ScreenUtils.show_message("取回成功!!!")
	BagInfoManage.set_trade_amount(1)
	reload()

func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = menu.get_item_id(index)
	match id:
		1:
			TradeInfoManage.take_consignment(check_node.data["id"])
		2:
			var item_type = check_node.data["type"]
			
			if item_type == 2:
				ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/pet/PetUi.tscn", "load_data", {"pet_type": 1, "id": check_node.data["hold_id"]})
				pass
			elif item_type == 3:
				BagInfoManage.get_equipment_details(check_node.data["hold_id"])
				pass
			elif item_type == 4 or item_type == 5:
				StaticGameData.show_art_data_info(check_node.get_details())
			pass


func _bagpackdata_num_change_():
	reload()

func reload():
	bag_capacity.text = str("背包容量\n(%d/%d)" % [BagInfoManage.get_bag_amount(), BagInfoManage.get_bag_max_amount()])
	trade_capacity.text = str("寄卖容量\n(%d/%d)" % [BagInfoManage.get_trade_capacity(), BagInfoManage.get_trade_max_capacity()])


func clear_container():
	for i in container.get_children():
		i.queue_free()
