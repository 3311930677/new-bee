extends Control

onready var coins_panle = $Head / Tabs / Coins
onready var fac_panle = $Head / Tabs / Fac
onready var container = $Background / Background2 / ScrollContainer / VBoxContainer

onready var yinliang = $Head / Tabs / Coins / Label / HBoxContainer / YinLiang
onready var yuanbao = $Head / Tabs / Coins / Label2 / HBoxContainer / YuanBao
onready var bag_num = $Head / Tabs / Panel3 / BagNum
onready var fac_num = $Head / Tabs / Fac / FacNum

onready var prop_item_res = preload("res://src/tscn/ui/common/bag/ProLabelItem.tscn")
onready var popup_menu_edit = preload("res://src/tscn/ui/common/dialog/PopupPanel.tscn")

var ScreenUtils
var BagInfoManage
var StaticGameData

var load_data_

var tab_model = 0
var check_node = null
var init_loaded = false


var discard_data
var discard_num


var base_menu = {
	"0": "存入仓库", 
	"3": "查看详情", 
	"1": "丢弃道具"
}

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	BagInfoManage = Global.get("BagInfoManage")
	StaticGameData = Global.get("StaticGameData")
	BagInfoManage.connect("_bag_data_update_", self, "_on_bag_data_result")
	BagInfoManage.connect("_bag_data_num_change_", self, "_bag_data_num_change_")
	fac_panle.visible = false
	coins_panle.visible = true

func _on_Cancle_pressed() -> void :
	queue_free()
	pass


func _on_AllTab_tab_click(node) -> void :
	fac_panle.visible = false
	tab_model = 0
	if init_loaded: _on_bag_data_result()
	reload_num()
	pass


func _on_EquiTab_tab_click(node) -> void :
	fac_panle.visible = false
	tab_model = 1
	_on_bag_data_result()
	reload_num()
	pass


func _on_PetTab_tab_click(node) -> void :
	fac_panle.visible = false
	tab_model = 2
	_on_bag_data_result()
	reload_num()
	pass


func _on_HierTab_tab_click(node) -> void :
	fac_panle.visible = false
	tab_model = 3
	_on_bag_data_result()
	reload_num()
	pass


func _on_TaskTab_tab_click(node) -> void :
	fac_panle.visible = false
	tab_model = 4
	_on_bag_data_result()
	reload_num()
	pass


func _on_FacTab_tab_click(node) -> void :
	fac_panle.visible = true
	tab_model = 5
	if init_loaded: _on_bag_data_result()
	reload_num()
	pass


func _on_Ok_pressed() -> void :
	if check_node == null: return
	
	var menu = {}
	if tab_model == 5:
		menu["10"] = "取出物品"
		menu["3"] = "查看详情"
	else:
		match check_node.get_type():
			3:
				menu["4"] = "穿戴装备"
				pass
			4:
				pass
			5:
				match check_node.get_art_type():
					1:


						pass
					2:
						menu["7"] = "打开礼包"
						pass
					3:
						menu["8"] = "使用道具"
						pass
		
		for key in base_menu.keys():
			menu[key] = base_menu[key]
	ScreenUtils.build_menu($Control / PopupMenu, menu)
	$Control / PopupMenu.popup_centered()

func _item_click(node):
	if check_node != null and node == check_node:
		_on_Ok_pressed()
		return
	check_node = node
	
func _ok_discard():
	BagInfoManage.discard_bag_art(discard_data, discard_num)
	discard_data = null
	discard_num = 0
	pass
func reload_num():
	yinliang.text = str(BagInfoManage.get_coins())
	yuanbao.text = str(BagInfoManage.get_coupons())
	bag_num.text = str("(", BagInfoManage.get_bag_amount_local(), "/", BagInfoManage.get_bag_max_amount(), ")")
	fac_num.text = str("(", BagInfoManage.get_store_amount_local(), "/", BagInfoManage.get_store_max_amount(), ")")
	
	pass
func _bag_data_num_change_():
	reload_num()

func _on_bag_data_result():
	if not init_loaded:
		
		if load_data_["type"] == 1:
			$Head / Tabs / HBoxContainer / FacTab.checked()
		else: $Head / Tabs / HBoxContainer / AllTab.checked()
	
	init_loaded = true
	clear_container()
	yinliang.text = str(BagInfoManage.get_coins())
	yuanbao.text = str(BagInfoManage.get_coupons())
	bag_num.text = str("(", BagInfoManage.get_bag_amount_local(), "/", BagInfoManage.get_bag_max_amount(), ")")
	fac_num.text = str("(", BagInfoManage.get_store_amount_local(), "/", BagInfoManage.get_store_max_amount(), ")")
	
	var list_datas = []
	match tab_model:
		0:
			list_datas = BagInfoManage.get_all_bag_datas()
			pass
		1:
			list_datas = BagInfoManage.get_equs()
			pass
		2:
			list_datas = BagInfoManage.get_pets()
			pass
		3:

			pass
		4:
			list_datas = BagInfoManage.get_tasks()
			pass
		5:
			list_datas = BagInfoManage.get_all_store_datas()
			pass
	
	


	
	list_datas.sort_custom(self, "sort_")
	for item_data in list_datas:
		var item = prop_item_res.instance()
		item.connect("item_click", self, "_item_click")
		container.add_child(item)
		item.set_data(item_data)
	show()
	pass

func sort_(a, b):
	var a1 = StaticGameData.get_prop_item_type(a)
	var b1 = StaticGameData.get_prop_item_type(b)
	return a1 > b1


func _popup_menu_edit_result(id, num_text):
	var num = int(num_text)
	if num <= 0:
		ScreenUtils.show_message("数量不符合")
		return
	match id:
		0:
			discard_data = check_node.data
			discard_num = num
			BagInfoManage.move_bag_to_store_house(check_node.data, num, load_data_.get("command", false))
			pass
		1:
			discard_data = check_node.data
			discard_num = num
			ScreenUtils.show_message(str("确定要丢弃%d件物品？\n该操作不可回退" % num), self, "_ok_discard")
			pass
		10:
			discard_data = check_node.data
			discard_num = num
			BagInfoManage.move_store_house_to_bag(check_node.data, num, load_data_.get("command", false))
			pass
	pass


func _popup_menu_use_edit_result(id, num_text):
	var num = int(num_text)
	if num <= 0 or num > 999:
		ScreenUtils.show_message("数量超出范围")
		return
	BagInfoManage.use_prop(check_node.data, num)
	pass

func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = $Control / PopupMenu.get_item_id(index)
	match id:
		0:
			
			if check_node.is_overlay():
				ScreenUtils.show_popup_menu_edit(self, "_popup_menu_edit_result", id, "请输入存入数量：")
			else:
				_popup_menu_edit_result(id, 1)
				pass
			pass
		1:
			
			if check_node.is_overlay():
				ScreenUtils.show_popup_menu_edit(self, "_popup_menu_edit_result", id, "请输入丢弃数量：")
			else:
				_popup_menu_edit_result(id, 1)
			pass
		3:
			if check_node.get_type() == 3:
				BagInfoManage.get_equipment_details(check_node.data["id"])
				pass
			else:
				StaticGameData.show_art_data_info(check_node.get_details())
			pass
		4:
			if check_node.data.is_mar == 1:
				ScreenUtils.show_message("无法穿戴已损坏的装备")
			else:
				BagInfoManage.wear_equipment(check_node.data["id"])
			pass
		5:
			BagInfoManage.use_drug_art(check_node.data, 1, 2)
			pass
		6:
			BagInfoManage.use_drug_art(check_node.data, 1, 1)
			pass
		7:
			BagInfoManage.use_gifpack(check_node.data, 1)
			pass
		8:
			
			if check_node.data.get("count", 1) == 1:
				BagInfoManage.use_prop(check_node.data, 1)
				pass
			else:
				ScreenUtils.show_popup_menu_edit(self, "_popup_menu_use_edit_result", id, "请输使用数量：")
			pass
		10:
			if check_node.is_overlay():
				ScreenUtils.show_popup_menu_edit(self, "_popup_menu_edit_result", id, "请输入取出数量：")
			else:
				_popup_menu_edit_result(id, 1)


func load_data(data):
	hide()
	load_data_ = data
	BagInfoManage.request_data()



func clear_container():
	for item in $Background / Background2 / ScrollContainer / VBoxContainer.get_children():
		item.queue_free()
	check_node = null

