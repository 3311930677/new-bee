extends Control

onready var box = $"Background/Background2/ScrollContainer/VBoxContainer"
onready var menu = $"Control/PopupMenu"
onready var item_res = preload("res://src/tscn/ui/common/bag/ProLabelItem.tscn")


onready var coins_num = $"Tabs/Coins/Label/HBoxContainer/YinLiang"

onready var yuanbao_num = $"Tabs/Coins/Label2/HBoxContainer/YuanBao"

onready var yinpiao_num = $"Tabs/Coins/Label3/HBoxContainer/YinPiao"

onready var bag_num = $"Tabs/Panel3/BagNum"

var BagInfoManage
var ShopInfoManage
var ScreenUtils
var StaticGameData


var c_curent_items = []
var tab_index = 0
var check_node = null
var dic_menu = {
	"0": "出售道具", 
	"1": "查看详情"
}

func _ready() -> void :
	BagInfoManage = Global.get("BagInfoManage")
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	ShopInfoManage = Global.get("ShopInfoManage")
	BagInfoManage.connect("_bag_all_data", self, "_on_bag_all_data")
	ShopInfoManage.connect("sell_successed", self, "_on_sell_successed")
	BagInfoManage.request_bag_data()
	hide()
	clear_container()
	pass


func _on_Cancle_pressed() -> void :
	queue_free()

func _item_click(node):
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node
	pass


func _on_Ok_pressed() -> void :
	if check_node == null: return
	ScreenUtils.build_menu(menu, dic_menu)
	menu.popup_centered()

func _on_sell_successed():
	
	BagInfoManage.sub_data(check_node.data, sel_num)
	
	load_basic_data()
	pass


func _on_Article_tab_click(node) -> void :
	tab_index = 0
	load_data()
	pass


func _on_Equipment_tab_click(node) -> void :
	tab_index = 1
	load_data()
	pass



func _on_bag_all_data(data):
	show()
	if tab_index == 0:
		c_curent_items = BagInfoManage.get_arts()
	elif tab_index == 1:
		c_curent_items = BagInfoManage.get_equs()
	load_basic_data()
	load_data()


func clear_container():
	if box == null: return
	for i in box.get_children():
		i.queue_free()

func load_basic_data():
	
	coins_num.text = str(BagInfoManage.get_coins())
	yuanbao_num.text = str(BagInfoManage.get_coupons())
	yinpiao_num.text = str(BagInfoManage.get_silver_coins())
	
	bag_num.text = str("（%d/%d）" % [BagInfoManage.get_bag_amount_local(), BagInfoManage.get_bag_max_amount()])
	pass

func load_data():
	clear_container()
	if BagInfoManage != null:
		if tab_index == 0:
			c_curent_items = BagInfoManage.get_arts()
		elif tab_index == 1:
			c_curent_items = BagInfoManage.get_equs()
	if c_curent_items != null:
		for item_data in c_curent_items:
			var item = item_res.instance()
			item.connect("item_click", self, "_item_click")
			box.add_child(item)
			item.set_data(item_data)
			pass
	pass


func _on_PopupMenu_id_pressed(id: int) -> void :
	var i_id = menu.get_item_id(id)
	match i_id:
		
		0:
			if check_node.data["item_type"] == 3:
				var s_data = StaticGameData.get_equi_data(str(check_node.data["equi_data_id"]))
				ScreenUtils.show_message(str("确定卖出？\n", s_data["name"]), self, "ok_sell")
			elif check_node.data["item_type"] == 5:
				ScreenUtils.show_popup_menu_edit(self, "sell_num", check_node.data["articles_data_id"])
				pass
			else:
				ScreenUtils.show_message("暂时不支持售卖其他道具[等待后期更新]")
			pass
		
		1:
			if check_node.get_type() == 3:
				BagInfoManage.get_equipment_details(check_node.data["id"])
				pass
			else:
				StaticGameData.show_art_data_info(check_node.get_details())
			pass
var sel_num = - 1

func ok_sell():
	var s_data = StaticGameData.get_equi_data(str(check_node.data["equi_data_id"]))
	sel_num = 1
	ShopInfoManage.sell_art(3, check_node.data["id"], 1)
	pass


func ok_sell_art():
	ShopInfoManage.sell_art(5, check_node.data["id"], sel_num)
	pass


func sell_num(id, num):
	if int(num) <= 0: return
	if int(num) > int(check_node.data["count"]): return
	sel_num = int(num)
	var s_data = StaticGameData.get_article_data(id)
	ScreenUtils.show_message(str("确定卖出", sel_num, "个？\n", s_data["name"]), self, "ok_sell_art")
	pass
