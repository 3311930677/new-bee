extends Control

onready var type_option_btn = $Filter / Filter / TypeOptionButton
onready var role_type_option_btn = $Filter / Filter / RoleOptionButton
onready var article_type_option_btn = $Filter / Filter / ArticleOptionButton
onready var equip_option_btn = $Filter / Filter / EquipOptionButton
onready var level_option_btn = $Filter / Filter / LevelOptionButton
onready var edit = $Filter / Filter / Label / TextEdit

onready var menu = $Control / PopupMenu

onready var container = $"Background/Background2/ScrollContainer/VBoxContainer"

onready var yuanbao = $"Head/Tabs/Coins/Label2/HBoxContainer/YuanBao"

onready var yinliang = $"Head/Tabs/Coins/Label/HBoxContainer/YinLiang"

onready var bag_num = $"Head/Tabs/Fac/FacNum"

onready var item_res = preload("res://src/tscn/ui/common/trade/TradeItem.tscn")

var ScreenUtils
var BagInfoManage
var TradeInfoManage
var StaticGameData


var page = 0

var count = 10

var query_dic = {}

var check_node = null

var buy_num = 0

var is_clear_container = false

var menu_dic = {
	"1": "购买道具", 
	"2": "查看详情"
}
func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	BagInfoManage = Global.get("BagInfoManage")
	TradeInfoManage = Global.get("TradeInfoManage")
	StaticGameData = Global.get("StaticGameData")
	
	BagInfoManage.connect("_bagpackdata_num_change_", self, "_on_load_bag_info")
	BagInfoManage.connect("_bag_data_num_change_", self, "_on_load_bag_info")
	TradeInfoManage.connect("query_consignment_success", self, "_on_query_consignment_success")
	TradeInfoManage.connect("buy_consignment_success", self, "_on_buy_consignment_success")
	_on_load_bag_info()
	request_consignment(page)


func _on_load_bag_info():
	yuanbao.text = str(BagInfoManage.get_coupons())
	yinliang.text = str(BagInfoManage.get_coins())
	bag_num.text = str("背包容量\n(%d/%d)" % [BagInfoManage.get_bag_amount(), BagInfoManage.get_bag_max_amount()])
	pass


func _on_query_consignment_success(data):
	page += 1
	show()
	if is_clear_container:
		is_clear_container = false
		clear_container()
	for item_ in data:
		var item = item_res.instance()
		container.add_child(item)
		item.connect("item_click", self, "_item_click")
		item.set_data(item_)
	pass


func _on_Cancle_pressed() -> void :
	queue_free()




func _on_Next_pressed() -> void :
	request_consignment(page + 1)

func _item_click(node):
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node

func _on_Ok_pressed() -> void :
	if check_node == null: return
	ScreenUtils.build_menu(menu, menu_dic)
	menu.popup_centered()
	pass


func _on_buy_consignment_success():
	ScreenUtils.show_message("购买成功")
	check_node.data["num"] = check_node.data.get("num", 1) - buy_num
	buy_num = 0
	check_node.reload()
	check_node = null
	pass

func _on_edit_buy_num(id, num):
	buy_num = int(num)
	if buy_num <= 0 or buy_num > 999:
		ScreenUtils.show_message("数量有误")
		return
	ScreenUtils.show_message(str("确定购买%d件 %s" % [buy_num, check_node.data["good_name"].substr(1)]), self, "_on_ok_buy")

func _on_ok_buy():
	TradeInfoManage.byg_consignment(check_node.data["id"], buy_num)
	pass

func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = menu.get_item_id(index)
	match id:
		1:
			if check_node.data["num"] > 1:
				ScreenUtils.show_popup_menu_edit(self, "_on_edit_buy_num", 0, "请输入购买数量")
			else:
				_on_edit_buy_num(0, 1)
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
	pass


func clear_container():
	for i in container.get_children():
		i.queue_free()


func _on_Search_pressed() -> void :
	page = 0
	is_clear_container = true
	request_consignment(page)


func request_consignment(page_):
	
	
	
	if type_option_btn.visible: query_dic["type"] = type_option_btn.get_selected_id()
	
	if role_type_option_btn.visible: query_dic["equ_job"] = role_type_option_btn.get_selected_id()
	
	if level_option_btn.visible: query_dic["level"] = level_option_btn.get_selected_id()
	
	if article_type_option_btn.visible: query_dic["article_type"] = article_type_option_btn.get_selected_id()
	
	if equip_option_btn.visible: query_dic["equ_wear_index"] = equip_option_btn.get_selected_id()
	
	if edit.text != null and edit.text.length() >= 1:
		query_dic["good_name"] = edit.text
		if edit.text.length() > 12:
			ScreenUtils.show_message("搜索道具名称过长")
			return
	
	TradeInfoManage.query_consignment(page_, count, query_dic)
	pass












































































func _on_TypeOptionButton_item_selected(index: int) -> void :
	is_clear_container = true
	page = 0
	match index:
		0:
			private_option_btn_hide_all()
			pass
		1:
			private_option_btn_show_role()
			pass
		2:
			private_option_btn_show_pet()
			pass
		3:
			private_option_btn_show_equi()
			pass
		4:
			private_option_btn_show_gem()
			pass
		5:
			private_option_btn_show_art()
			pass
	pass
func private_option_btn_hide_all():
	
	equip_option_btn.select(0)
	
	level_option_btn.select(0)
	
	role_type_option_btn.select(0)
	
	article_type_option_btn.select(0)
	
	equip_option_btn.hide()
	level_option_btn.hide()
	article_type_option_btn.hide()
	role_type_option_btn.hide()
	pass

func private_option_btn_show_role():
	
	equip_option_btn.select(0)
	
	level_option_btn.select(0)
	
	role_type_option_btn.select(0)
	article_type_option_btn.select(0)
	
	equip_option_btn.hide()
	level_option_btn.show()
	article_type_option_btn.hide()
	role_type_option_btn.show()


func private_option_btn_show_pet():

	equip_option_btn.select(0)
	equip_option_btn.select(0)
	level_option_btn.select(0)
	article_type_option_btn.select(0)
	role_type_option_btn.hide()
	equip_option_btn.hide()
	article_type_option_btn.hide()
	
	level_option_btn.show()

func private_option_btn_show_equi():
	level_option_btn.show()
	role_type_option_btn.show()
	equip_option_btn.show()
	article_type_option_btn.hide()
	
	level_option_btn.select(0)
	role_type_option_btn.select(0)
	equip_option_btn.select(0)
	article_type_option_btn.select(0)

func private_option_btn_show_gem():
	
	equip_option_btn.select(0)
	
	level_option_btn.select(0)
	
	role_type_option_btn.select(0)
	article_type_option_btn.select(0)
	
	equip_option_btn.hide()
	role_type_option_btn.hide()
	article_type_option_btn.hide()
	pass

func private_option_btn_show_art():
	
	equip_option_btn.select(0)
	
	level_option_btn.select(0)
	
	role_type_option_btn.select(0)
	article_type_option_btn.select(0)
	
	equip_option_btn.hide()
	role_type_option_btn.hide()
	article_type_option_btn.show()
	pass




